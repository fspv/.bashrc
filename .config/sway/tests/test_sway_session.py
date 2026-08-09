"""Runs as root inside the bootc desktop image with the repo mounted at /repo."""

import json
import pwd
import re
import shutil
import subprocess
import time
from collections.abc import Callable, Iterator
from pathlib import Path

import pytest

TEST_USER = "swaytest"


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, check=False)


def sway_user_systemctl(*arguments: str) -> subprocess.CompletedProcess[str]:
    machine = f"{TEST_USER}@.host"
    return run_command(["systemctl", "--user", "--machine", machine, *arguments])


def sway_user_manager_environment() -> dict[str, str]:
    output = sway_user_systemctl("show-environment").stdout
    variables = (line.partition("=") for line in output.splitlines())
    return {name: value for name, _, value in variables}


def sway_user_unit_is_active(unit_name: str) -> bool:
    return sway_user_systemctl("is-active", unit_name).stdout.strip() == "active"


def sway_user_process_running(process_name: str) -> bool:
    pgrep = run_command(["pgrep", "--uid", TEST_USER, "--exact", process_name])
    return pgrep.returncode == 0


def wait_for(condition: Callable[[], bool], description: str) -> None:
    for _ in range(90):
        if condition():
            return
        time.sleep(1)
    raise AssertionError(f"timed out waiting for {description}")


def run_as_sway_user(*command: str) -> subprocess.CompletedProcess[str]:
    user_id = pwd.getpwnam(TEST_USER).pw_uid
    return run_command(
        [
            "runuser",
            "-u",
            TEST_USER,
            "--",
            "env",
            f"XDG_RUNTIME_DIR=/run/user/{user_id}",
            *command,
        ]
    )


def sway_user_gsetting(schema: str, key: str) -> str:
    user_id = pwd.getpwnam(TEST_USER).pw_uid
    bus_address = f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{user_id}/bus"
    return run_as_sway_user(bus_address, "gsettings", "get", schema, key).stdout.strip()


@pytest.fixture(scope="module")
def sway_user_home() -> Path:
    subprocess.run(["useradd", "--no-create-home", TEST_USER], check=True)
    home_directory = Path("/home") / TEST_USER
    shutil.copytree(Path("/repo"), home_directory, symlinks=True)
    subprocess.run(
        ["chown", "--recursive", f"{TEST_USER}:{TEST_USER}", str(home_directory)],
        check=True,
    )
    subprocess.run(["loginctl", "enable-linger", TEST_USER], check=True)
    runtime_bus = Path(f"/run/user/{pwd.getpwnam(TEST_USER).pw_uid}/bus")
    wait_for(runtime_bus.exists, "user manager dbus socket")
    return home_directory


@pytest.fixture(scope="module")
def sway_launcher(sway_user_home: Path) -> Iterator[subprocess.Popen[bytes]]:
    user_id = pwd.getpwnam(TEST_USER).pw_uid
    launcher = subprocess.Popen(
        [
            "runuser",
            "-u",
            TEST_USER,
            "--",
            "env",
            f"XDG_RUNTIME_DIR=/run/user/{user_id}",
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


def test_session_targets_active(sway_launcher: subprocess.Popen[bytes]) -> None:
    assert sway_user_unit_is_active("sway-session.target")
    assert sway_user_unit_is_active("graphical-session.target")


def test_environment_pushed_to_user_manager(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    user_id = pwd.getpwnam(TEST_USER).pw_uid
    environment = sway_user_manager_environment()
    assert environment["XDG_CURRENT_DESKTOP"] == "sway"
    assert environment["XDG_SESSION_DESKTOP"] == "sway"
    assert environment["XDG_SESSION_TYPE"] == "wayland"
    assert environment["DISPLAY"] == ":0"
    assert environment["WAYLAND_DISPLAY"] == "wayland-1"
    assert Path(f"/run/user/{user_id}/wayland-1").is_socket()
    assert re.fullmatch(
        rf"/run/user/{user_id}/sway-ipc\.{user_id}\.[0-9]+\.sock",
        environment["SWAYSOCK"],
    )
    assert Path(environment["SWAYSOCK"]).is_socket()
    assert environment["I3SOCK"] == environment["SWAYSOCK"]
    assert environment["XCURSOR_THEME"] == "Adwaita"
    assert environment["XCURSOR_SIZE"] == "24"
    # sway does not create an xauth file, so XAUTHORITY is never populated
    assert "XAUTHORITY" not in environment
    # the IM variables are pushed by fcitx5 itself, not by the session chain
    wait_for(
        lambda: sway_user_manager_environment().get("GTK_IM_MODULE") == "fcitx",
        "GTK_IM_MODULE pushed by fcitx5",
    )
    assert sway_user_manager_environment()["QT_IM_MODULE"] == "fcitx"
    assert sway_user_manager_environment()["XMODIFIERS"] == "@im=fcitx"


def test_sway_ipc_responds(sway_launcher: subprocess.Popen[bytes]) -> None:
    swaysock = sway_user_manager_environment()["SWAYSOCK"]
    swaymsg = run_as_sway_user(
        f"SWAYSOCK={swaysock}", "swaymsg", "--type", "get_outputs"
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


# window-bound-layout is not asserted: its startup script installs a
# virtualenv from the network, which the test container does not have
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
    reload_result = run_as_sway_user(f"SWAYSOCK={swaysock}", "swaymsg", "reload")
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


def test_teardown_stops_session_and_clears_environment(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    swaysock = sway_user_manager_environment()["SWAYSOCK"]
    # sway dies executing "exit" without sending the IPC reply, so the swaymsg
    # return code is meaningless
    run_as_sway_user(f"SWAYSOCK={swaysock}", "swaymsg", "exit")
    sway_launcher.wait(timeout=60)
    wait_for(
        lambda: not sway_user_unit_is_active("graphical-session.target"),
        "graphical-session.target stopped",
    )
    assert not sway_user_unit_is_active("sway-session.target")
    # the applets race compositor death and can end up "failed" instead of
    # "inactive", both mean stopped
    assert not sway_user_unit_is_active("nm-applet.service")
    assert not sway_user_unit_is_active("blueman-applet.service")
    environment = sway_user_manager_environment()
    assert "DISPLAY" not in environment
    assert "WAYLAND_DISPLAY" not in environment
    assert "SWAYSOCK" not in environment
    assert "I3SOCK" not in environment
    assert "XAUTHORITY" not in environment
    assert "XDG_CURRENT_DESKTOP" not in environment
    assert "XDG_SESSION_DESKTOP" not in environment
    assert "XDG_SESSION_TYPE" not in environment
    assert "XCURSOR_THEME" not in environment
    assert "XCURSOR_SIZE" not in environment
    # the IM variables are not asserted, fcitx5 owns them and outlives the
    # session
