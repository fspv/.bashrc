"""Integration test for the sway systemd session wiring.

Runs as root inside the bootc desktop image with the repo mounted at /repo.
It creates a user, installs the dotfiles into its home, launches sway headless
via sway-run and verifies that the session target, the environment push and the
teardown all work.
"""

import pwd
import shutil
import subprocess
import time
from collections.abc import Callable, Iterator
from pathlib import Path

import pytest

TEST_USER = "swaytest"
REPO_ROOT = Path("/repo")

WANTED_SERVICES = [
    "plasma-polkit-agent.service",
    "wireplumber.service",
    "xdg-desktop-portal.service",
    "xdg-desktop-portal-gtk.service",
    "xdg-desktop-portal-wlr.service",
    "nm-applet.service",
    "blueman-applet.service",
]


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, check=False)


def user_systemctl(*arguments: str) -> subprocess.CompletedProcess[str]:
    machine = f"{TEST_USER}@.host"
    return run_command(["systemctl", "--user", "--machine", machine, *arguments])


def user_manager_environment() -> dict[str, str]:
    output = user_systemctl("show-environment").stdout
    variables = (line.partition("=") for line in output.splitlines())
    return {name: value for name, _, value in variables}


def unit_is_active(unit_name: str) -> bool:
    return user_systemctl("is-active", unit_name).stdout.strip() == "active"


def wait_for(condition: Callable[[], bool], description: str) -> None:
    for _ in range(90):
        if condition():
            return
        time.sleep(1)
    raise AssertionError(f"timed out waiting for {description}")


def run_as_test_user(*command: str) -> subprocess.CompletedProcess[str]:
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
def session_user_home() -> Path:
    subprocess.run(["useradd", "--no-create-home", TEST_USER], check=True)
    home_directory = Path("/home") / TEST_USER
    home_directory.mkdir()
    shutil.copytree(REPO_ROOT / ".config", home_directory / ".config", symlinks=True)
    shutil.copytree(REPO_ROOT / ".local", home_directory / ".local", symlinks=True)
    subprocess.run(
        ["chown", "--recursive", f"{TEST_USER}:{TEST_USER}", str(home_directory)],
        check=True,
    )
    subprocess.run(["loginctl", "enable-linger", TEST_USER], check=True)
    runtime_bus = Path(f"/run/user/{pwd.getpwnam(TEST_USER).pw_uid}/bus")
    wait_for(runtime_bus.exists, "user manager dbus socket")
    return home_directory


@pytest.fixture(scope="module")
def sway_launcher(session_user_home: Path) -> Iterator[subprocess.Popen[bytes]]:
    user_id = pwd.getpwnam(TEST_USER).pw_uid
    launcher = subprocess.Popen(
        [
            "runuser",
            "-u",
            TEST_USER,
            "--",
            "env",
            f"HOME={session_user_home}",
            f"XDG_RUNTIME_DIR=/run/user/{user_id}",
            "WLR_BACKENDS=headless",
            "WLR_RENDERER=pixman",
            "WLR_LIBINPUT_NO_DEVICES=1",
            str(session_user_home / ".local/share/bin/sway-run"),
        ]
    )
    wait_for(lambda: unit_is_active("sway-session.target"), "sway-session.target")
    yield launcher
    launcher.kill()


def test_session_targets_active(sway_launcher: subprocess.Popen[bytes]) -> None:
    assert unit_is_active("sway-session.target")
    assert unit_is_active("graphical-session.target")


def test_environment_pushed_to_user_manager(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    environment = user_manager_environment()
    assert environment["XDG_CURRENT_DESKTOP"] == "sway"
    assert environment["XDG_SESSION_DESKTOP"] == "sway"
    assert environment["XDG_SESSION_TYPE"] == "wayland"
    assert environment["WAYLAND_DISPLAY"]
    assert environment["SWAYSOCK"]
    assert environment["I3SOCK"]


def test_wanted_services_pulled_in_by_session_target(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    dependencies = user_systemctl(
        "list-dependencies", "--plain", "sway-session.target"
    ).stdout
    for service in WANTED_SERVICES:
        assert service in dependencies, f"{service} not wanted by sway-session.target"


# plasma-polkit-agent is asserted only as wired, not as running: it needs a
# logind session to register itself, which a lingering user manager in a
# container does not have.
def test_core_services_running(sway_launcher: subprocess.Popen[bytes]) -> None:
    wait_for(lambda: unit_is_active("wireplumber.service"), "wireplumber active")
    wait_for(
        lambda: unit_is_active("xdg-desktop-portal.service"),
        "xdg-desktop-portal active",
    )
    wait_for(
        lambda: unit_is_active("xdg-desktop-portal-gtk.service"),
        "xdg-desktop-portal-gtk active",
    )
    wait_for(
        lambda: unit_is_active("xdg-desktop-portal-wlr.service"),
        "xdg-desktop-portal-wlr active",
    )
    wait_for(lambda: unit_is_active("nm-applet.service"), "nm-applet active")
    wait_for(lambda: unit_is_active("blueman-applet.service"), "blueman-applet active")


def test_teardown_stops_session_and_clears_environment(
    sway_launcher: subprocess.Popen[bytes],
) -> None:
    swaysock = user_manager_environment()["SWAYSOCK"]
    # sway dies executing "exit" and never sends the IPC reply, so the return
    # code of swaymsg is meaningless here.
    run_as_test_user(f"SWAYSOCK={swaysock}", "swaymsg", "exit")
    sway_launcher.wait(timeout=60)
    wait_for(
        lambda: not unit_is_active("graphical-session.target"),
        "graphical-session.target stopped",
    )
    assert not unit_is_active("sway-session.target")
    # The applets race compositor death and can exit nonzero before their stop
    # job lands, ending up "failed" instead of "inactive". Both mean stopped,
    # and the next session start clears failed state with reset-failed.
    assert not unit_is_active("nm-applet.service")
    assert not unit_is_active("blueman-applet.service")
    environment = user_manager_environment()
    assert "WAYLAND_DISPLAY" not in environment
    assert "SWAYSOCK" not in environment
    assert "XDG_CURRENT_DESKTOP" not in environment
