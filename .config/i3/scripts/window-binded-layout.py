#!/usr/bin/env python3

import logging
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


class LRU(OrderedDict[int, dict[str, int]]):
    """Limit size, evicting the least recently looked-up key when full"""

    def __init__(self, maxsize: int = 128, *args: Any, **kwds: Any) -> None:
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


class State:
    """Holds module-level mutable state to avoid `global` statements."""

    windows: LRU = LRU(1024)
    prev_window_id: int = 0


def run_shell_return_output(command: str) -> tuple[int, bytes, bytes]:
    log.debug("Trying to run command: %s", command)
    p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()

    log.debug(out)
    if err:
        log.error(err)

    retcode = p.returncode

    if retcode != 0:
        log.error("Command '%s' exited with return code %s", command, retcode)

    return retcode, out, err


def get_layout() -> int | None:
    retcode, out, _ = run_shell_return_output("~/.config/i3/scripts/xkblayout-state print %c")
    if retcode != 0:
        return None

    layout = int(out.strip())

    if layout in (0, 1):  # 0 = en, 1 = ru
        return layout
    return None


def set_layout(layout: int) -> None:
    run_shell_return_output(f"~/.config/i3/scripts/xkblayout-state set {layout}")


def window_change(_conn: i3ipc.Connection, e: i3ipc.Event) -> int:
    log.debug(vars(e.container))

    if not e.container.focused:
        return 0

    prev_layout = get_layout()
    if prev_layout is None:
        return 0

    if State.prev_window_id in State.windows:
        State.windows[State.prev_window_id]["layout"] = prev_layout

    cur_window_id = e.container.id
    if cur_window_id not in State.windows:
        # No layout stored for this window yet; initialise with current layout.
        log.debug("Store layout for %s", cur_window_id)
        State.windows[cur_window_id] = {"layout": prev_layout}
    elif State.windows[cur_window_id]["layout"] != prev_layout:
        log.debug("Restore layout for %s", cur_window_id)
        set_layout(State.windows[cur_window_id]["layout"])
    State.windows[cur_window_id]["last_access_time"] = int(time.time())

    State.prev_window_id = cur_window_id
    log.debug(State.windows)

    return 0


def main() -> None:
    while True:
        time.sleep(2)  # give i3 time to start
        conn = i3ipc.Connection()
        conn.on("window", window_change)
        conn.main()


if __name__ == "__main__":
    main()
