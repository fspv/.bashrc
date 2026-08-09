"""Runs as root inside the bootc desktop image with the repo mounted at /repo."""

import pwd
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
            f"HOME=/home/{TEST_USER}",
            f"XDG_RUNTIME_DIR=/run/user/{user_id}",
            *command,
        ]
    )


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
            f"HOME={sway_user_home}",
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
    environment = sway_user_manager_environment()
    assert environment["XDG_CURRENT_DESKTOP"] == "sway"
    assert environment["XDG_SESSION_DESKTOP"] == "sway"
    assert environment["XDG_SESSION_TYPE"] == "wayland"
    assert environment["WAYLAND_DISPLAY"]
    assert environment["SWAYSOCK"]
    assert environment["I3SOCK"]


def test_services_wanted_by_session_target(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    dependencies = sway_user_systemctl(
        "list-dependencies", "--plain", "sway-session.target"
    ).stdout
    assert "plasma-polkit-agent.service" in dependencies
    assert "wireplumber.service" in dependencies
    assert "xdg-desktop-portal.service" in dependencies
    assert "xdg-desktop-portal-gtk.service" in dependencies
    assert "xdg-desktop-portal-wlr.service" in dependencies
    assert "nm-applet.service" in dependencies
    assert "blueman-applet.service" in dependencies


# plasma-polkit-agent is not asserted running: it needs a logind session,
# which a lingering user manager in a container does not have.
def test_core_services_running(sway_launcher: subprocess.Popen[bytes]) -> None:
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
    assert "WAYLAND_DISPLAY" not in environment
    assert "SWAYSOCK" not in environment
    assert "XDG_CURRENT_DESKTOP" not in environment
