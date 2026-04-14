#!/usr/bin/env python3

import logging
import os.path
import subprocess
import sys
import time
from collections import OrderedDict
from typing import Any

import i3ipc

log = logging.getLogger()
log_handler = logging.StreamHandler(sys.stdout)
log.addHandler(log_handler)
log.setLevel(logging.DEBUG)

XKBLAYOUT_STATE = os.path.expanduser("~/.config/i3/scripts/xkblayout-state")


class LRU(OrderedDict[int, dict[str, int]]):
    """Limit size, evicting the least recently looked-up key when full.

    Also tracks the previously focused window id so callers don't need a
    separate global.
    """

    prev_window_id: int = 0

    def __init__(self, *args: Any, maxsize: int = 128, **kwds: Any) -> None:
        self.maxsize = maxsize
        super().__init__(*args, **kwds)

    def __getitem__(self, key: int) -> dict[str, int]:
        value = super().__getitem__(key)
        self.move_to_end(key)
        return value

    def __setitem__(self, key: int, value: dict[str, int]) -> None:
        super().__setitem__(key, value)
        if len(self) > self.maxsize:
            oldest = next(iter(self))
            del self[oldest]


WINDOWS = LRU(maxsize=1024)


def run_command(args: list[str]) -> tuple[int, bytes, bytes]:
    """Run a subprocess and return (returncode, stdout, stderr)."""
    log.debug("Trying to run command: %s", args)
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()

    log.debug(out)
    if err:
        log.error(err)

    retcode = process.returncode
    if retcode != 0:
        log.error("Command %s exited with return code %s", args, retcode)

    return retcode, out, err


def get_layout() -> int | None:
    """Return the active xkb layout index, or None on error / unknown layout."""
    retcode, out, _ = run_command([XKBLAYOUT_STATE, "print", "%c"])
    if retcode != 0:
        return None

    layout = int(out.strip())

    if layout in (0, 1):  # 0 = en, 1 = ru
        return layout
    return None


def set_layout(layout: int) -> None:
    """Switch the active xkb layout to the given index."""
    run_command([XKBLAYOUT_STATE, "set", str(layout)])


def window_change(_conn: i3ipc.Connection, event: i3ipc.Event) -> int:
    """i3 window-change handler: persist + restore xkb layout per window."""
    log.debug(vars(event.container))

    if not event.container.focused:
        return 0

    prev_layout = get_layout()
    if prev_layout is None:
        return 0

    if WINDOWS.prev_window_id in WINDOWS:
        WINDOWS[WINDOWS.prev_window_id]["layout"] = prev_layout

    cur_window_id = event.container.id
    if cur_window_id not in WINDOWS:
        # No layout stored for this window yet; initialise with current layout.
        log.debug("Store layout for %s", cur_window_id)
        WINDOWS[cur_window_id] = {"layout": prev_layout}
    elif WINDOWS[cur_window_id]["layout"] != prev_layout:
        log.debug("Restore layout for %s", cur_window_id)
        set_layout(WINDOWS[cur_window_id]["layout"])
    WINDOWS[cur_window_id]["last_access_time"] = int(time.time())

    WINDOWS.prev_window_id = cur_window_id
    log.debug(WINDOWS)

    return 0


def main() -> None:
    """Connect to i3 IPC and listen for window events forever."""
    while True:
        time.sleep(2)  # give i3 time to start
        conn = i3ipc.Connection()
        conn.on("window", window_change)
        conn.main()


if __name__ == "__main__":
    main()
