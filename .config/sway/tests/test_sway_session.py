"""Runs as root inside the bootc desktop image with the repo mounted at /repo."""

import json
import shutil
import subprocess
import time
from collections.abc import Callable, Iterator
from pathlib import Path

import pytest


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, check=False)


def sway_user_systemctl(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    return run_command(
        ["systemctl", "--user", "--machine", "swaytest@.host", *arguments]
    )


def sway_user_manager_environment() -> dict[str, str]:
    output = sway_user_systemctl(["show-environment"]).stdout
    variables = (line.partition("=") for line in output.splitlines())
    return {name: value for name, _, value in variables}


def sway_user_unit_is_active(unit_name: str) -> bool:
    return sway_user_systemctl(["is-active", unit_name]).stdout.strip() == "active"


def sway_user_process_running(process_name: str) -> bool:
    pgrep = run_command(["pgrep", "--uid", "swaytest", "--exact", process_name])
    return pgrep.returncode == 0


def wait_for(condition: Callable[[], bool], description: str) -> None:
    for _ in range(90):
        if condition():
            return
        time.sleep(1)
    raise AssertionError(f"timed out waiting for {description}")


def run_as_sway_user(command: list[str]) -> subprocess.CompletedProcess[str]:
    return run_command(
        [
            "runuser",
            "-u",
            "swaytest",
            "--",
            "env",
            "XDG_RUNTIME_DIR=/run/user/30033",
            *command,
        ]
    )


def sway_user_gsetting(schema: str, key: str) -> str:
    bus_address = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/30033/bus"
    gsettings = run_as_sway_user([bus_address, "gsettings", "get", schema, key])
    return gsettings.stdout.strip()


@pytest.fixture(scope="module")
def sway_user_home() -> Path:
    subprocess.run(
        ["useradd", "--no-create-home", "--uid", "30033", "swaytest"], check=True
    )
    home_directory = Path("/home/swaytest")
    shutil.copytree(Path("/repo"), home_directory, symlinks=True)
    subprocess.run(
        ["chown", "--recursive", "swaytest:swaytest", str(home_directory)],
        check=True,
    )
    subprocess.run(["loginctl", "enable-linger", "swaytest"], check=True)
    wait_for(Path("/run/user/30033/bus").exists, "user manager dbus socket")
    return home_directory


@pytest.fixture(scope="module")
def environment_before_session(sway_user_home: Path) -> dict[str, str]:
    return sway_user_manager_environment()


@pytest.fixture(scope="module")
def sway_launcher(
    sway_user_home: Path, environment_before_session: dict[str, str]
) -> Iterator[subprocess.Popen[bytes]]:
    launcher = subprocess.Popen(
        [
            "runuser",
            "-u",
            "swaytest",
            "--",
            "env",
            "XDG_RUNTIME_DIR=/run/user/30033",
            "WLR_BACKENDS=headless",
            "WLR_RENDERER=pixman",
            "WLR_LIBINPUT_NO_DEVICES=1",
            str(sway_user_home / ".config/sway/tests/sway-run"),
        ]
    )
    wait_for(
        lambda: sway_user_unit_is_active("sway-session.target"), "sway-session.target"
    )
    yield launcher
    launcher.kill()


# The baseline values are not owned by the session: set by the user manager
# itself (HOME, PATH, ...), by environment generators (XDG_DATA_DIRS) and by
# .config/environment.d/apps.conf
def test_environment_before_session(
    environment_before_session: dict[str, str],
) -> None:
    assert environment_before_session == {
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/30033/bus",
        "ECORE_EVAS_ENGINE": "wayland_egl",
        "ELM_ENGINE": "wayland_egl",
        "GTK_IM_MODULE": "fcitx",
        "HOME": "/var/home/swaytest",
        "LANG": "en_US.UTF-8",
        "LOGNAME": "swaytest",
        "MOZ_ENABLE_WAYLAND": "1",
        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/bin:/var/lib/snapd/snap/bin",
        "QT_IM_MODULE": "fcitx",
        "QT_QPA_PLATFORM": "wayland",
        "QT_QPA_PLATFORMTHEME": "gtk3",
        "SDL_VIDEODRIVER": "wayland",
        "SHELL": "/bin/bash",
        "USER": "swaytest",
        "XDG_DATA_DIRS": ":".join(
            [
                "/var/home/swaytest/.local/share/flatpak/exports/share",
                "/var/lib/flatpak/exports/share",
                "/usr/local/share/",
                "/usr/share/",
                "/var/lib/snapd/desktop",
            ]
        ),
        "XDG_RUNTIME_DIR": "/run/user/30033",
        "XMODIFIERS": "@im=fcitx",
        "_JAVA_AWT_WM_NONREPARENTING": "1",
    }


def test_session_targets_active(sway_launcher: subprocess.Popen[bytes]) -> None:
    assert sway_user_unit_is_active("sway-session.target")
    assert sway_user_unit_is_active("graphical-session.target")


def test_environment_pushed_to_user_manager(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    sway_pid = run_command(["pgrep", "--uid", "swaytest", "--exact", "sway"])
    swaysock = f"/run/user/30033/sway-ipc.30033.{sway_pid.stdout.strip()}.sock"
    assert Path(swaysock).is_socket()
    assert Path("/run/user/30033/wayland-1").is_socket()
    assert sway_user_manager_environment() == {
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/30033/bus",
        "DISPLAY": ":0",
        "ECORE_EVAS_ENGINE": "wayland_egl",
        "ELM_ENGINE": "wayland_egl",
        "GTK_IM_MODULE": "fcitx",
        "HOME": "/var/home/swaytest",
        "I3SOCK": swaysock,
        "LANG": "en_US.UTF-8",
        "LOGNAME": "swaytest",
        "MOZ_ENABLE_WAYLAND": "1",
        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/bin:/var/lib/snapd/snap/bin",
        "QT_IM_MODULE": "fcitx",
        "QT_QPA_PLATFORM": "wayland",
        "QT_QPA_PLATFORMTHEME": "gtk3",
        "SDL_VIDEODRIVER": "wayland",
        "SHELL": "/bin/bash",
        "SWAYSOCK": swaysock,
        "USER": "swaytest",
        "WAYLAND_DISPLAY": "wayland-1",
        "XCURSOR_SIZE": "24",
        "XCURSOR_THEME": "Adwaita",
        "XDG_CURRENT_DESKTOP": "sway",
        "XDG_DATA_DIRS": ":".join(
            [
                "/var/home/swaytest/.local/share/flatpak/exports/share",
                "/var/lib/flatpak/exports/share",
                "/usr/local/share/",
                "/usr/share/",
                "/var/lib/snapd/desktop",
            ]
        ),
        "XDG_RUNTIME_DIR": "/run/user/30033",
        "XDG_SESSION_DESKTOP": "sway",
        "XDG_SESSION_TYPE": "wayland",
        "XMODIFIERS": "@im=fcitx",
        "_JAVA_AWT_WM_NONREPARENTING": "1",
    }


def test_sway_ipc_responds(sway_launcher: subprocess.Popen[bytes]) -> None:
    swaysock = sway_user_manager_environment()["SWAYSOCK"]
    swaymsg = run_as_sway_user(
        [f"SWAYSOCK={swaysock}", "swaymsg", "--type", "get_outputs"]
    )
    outputs = json.loads(swaymsg.stdout)
    assert [output["name"] for output in outputs] == ["HEADLESS-1"]


# plasma-polkit-agent is wanted by the target too, but is not asserted here:
# it needs a logind session to register itself, which a lingering user manager
# in a container does not have
def test_wanted_services_running(sway_launcher: subprocess.Popen[bytes]) -> None:
    wait_for(lambda: sway_user_unit_is_active("wireplumber.service"), "wireplumber")
    wait_for(
        lambda: sway_user_unit_is_active("xdg-desktop-portal.service"),
        "xdg-desktop-portal",
    )
    wait_for(
        lambda: sway_user_unit_is_active("xdg-desktop-portal-gtk.service"),
        "xdg-desktop-portal-gtk",
    )
    wait_for(
        lambda: sway_user_unit_is_active("xdg-desktop-portal-wlr.service"),
        "xdg-desktop-portal-wlr",
    )
    wait_for(lambda: sway_user_unit_is_active("nm-applet.service"), "nm-applet")
    wait_for(lambda: sway_user_unit_is_active("blueman-applet.service"), "blueman")
    wait_for(lambda: sway_user_unit_is_active("dunst.service"), "dunst")
    wait_for(lambda: sway_user_unit_is_active("fcitx5.service"), "fcitx5")
    wait_for(
        lambda: sway_user_unit_is_active("window-bound-layout.service"),
        "window-bound-layout",
    )


# the window-bound-layout process is not asserted: its startup script installs
# a virtualenv from the network, which the test container does not have
def test_desktop_processes_running(sway_launcher: subprocess.Popen[bytes]) -> None:
    wait_for(lambda: sway_user_process_running("sway"), "sway")
    wait_for(lambda: sway_user_process_running("Xwayland"), "Xwayland")
    wait_for(lambda: sway_user_process_running("waybar"), "waybar")
    wait_for(lambda: sway_user_process_running("dunst"), "dunst")
    wait_for(lambda: sway_user_process_running("fcitx5"), "fcitx5")
    wait_for(lambda: sway_user_process_running("swayidle"), "swayidle")


def test_desktop_survives_config_reload(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    swaysock = sway_user_manager_environment()["SWAYSOCK"]
    reload_result = run_as_sway_user([f"SWAYSOCK={swaysock}", "swaymsg", "reload"])
    assert reload_result.returncode == 0, reload_result.stderr
    # give the pkill --older 5 window time to pass before asserting, otherwise
    # a still-running old instance can produce a false pass
    time.sleep(10)
    wait_for(lambda: sway_user_process_running("waybar"), "waybar after reload")
    wait_for(lambda: sway_user_process_running("dunst"), "dunst after reload")
    wait_for(lambda: sway_user_process_running("fcitx5"), "fcitx5 after reload")
    wait_for(lambda: sway_user_process_running("swayidle"), "swayidle after reload")


def test_gsettings_applied(sway_launcher: subprocess.Popen[bytes]) -> None:
    interface = "org.gnome.desktop.interface"
    wait_for(
        lambda: sway_user_gsetting(interface, "color-scheme") == "'prefer-dark'",
        "gsettings color-scheme",
    )
    assert sway_user_gsetting(interface, "gtk-theme") == "'Adwaita-dark'"
    assert sway_user_gsetting(interface, "cursor-theme") == "'Adwaita'"
    assert sway_user_gsetting(interface, "font-name") == "'Ubuntu 11'"
    assert sway_user_gsetting(interface, "monospace-font-name") == "'Ubuntu Mono 11'"


def test_teardown_stops_session_and_restores_environment(
    sway_launcher: subprocess.Popen[bytes],
    environment_before_session: dict[str, str],
) -> None:
    swaysock = sway_user_manager_environment()["SWAYSOCK"]
    # sway dies executing "exit" without sending the IPC reply, so the swaymsg
    # return code is meaningless
    run_as_sway_user([f"SWAYSOCK={swaysock}", "swaymsg", "exit"])
    sway_launcher.wait(timeout=60)
    wait_for(
        lambda: not sway_user_unit_is_active("graphical-session.target"),
        "graphical-session.target stopped",
    )
    assert not sway_user_unit_is_active("sway-session.target")
    assert not sway_user_unit_is_active("nm-applet.service")
    assert not sway_user_unit_is_active("blueman-applet.service")
    assert not sway_user_unit_is_active("dunst.service")
    assert not sway_user_unit_is_active("fcitx5.service")
    assert not sway_user_unit_is_active("window-bound-layout.service")
    wait_for(
        lambda: sway_user_manager_environment() == environment_before_session,
        "environment restored to the pre-session baseline",
    )
