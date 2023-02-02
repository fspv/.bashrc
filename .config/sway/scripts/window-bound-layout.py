#!/usr/bin/env python3

# This script keeps track of active keyboard layouts per window.
#
# This script requires i3ipc-python package (install it from a system package
# manager or pip).

import logging
import sys
import time
from typing import Any, Callable, Dict, Optional, TypeVar

import i3ipc

WINDOW_PREV_FOCUSED: Optional[int] = None

_T = TypeVar("_T")


def log_params_and_output(func: Callable[..., _T]) -> Callable[..., _T]:
    """
    Decorator to log function params and output for debugging purposes
    """

    def wrapped(*args: Any, **kwargs: Any) -> _T:
        result = func(*args, **kwargs)

        logging.debug("%s(%s, %s) -> %s", func, args, kwargs, result)

        return result

    return wrapped


class LayoutCache:
    """
    Just a wrapper around a dict, which provides a singleton to store
    window layouts and additional logging.

    Also makes a code for saving/restoring layout a bit more readable
    """

    _cache: Dict[int, Dict[str, int]] = {}

    @log_params_and_output
    def has_saved(self, window_id: int) -> bool:
        return window_id in self._cache

    @log_params_and_output
    def save(self, window_id: int, layout: Dict[str, int]) -> None:
        self._cache[window_id] = layout

    @log_params_and_output
    def retrieve(self, window_id: int) -> Dict[str, int]:
        return self._cache[window_id]

    @log_params_and_output
    def discard(self, window_id: int) -> None:
        if window_id in self._cache:
            del self._cache[window_id]


@log_params_and_output
def current_layout(ipc: i3ipc.Connection) -> Dict[str, int]:
    """
    Just get a current global layout and return it
    """

    layouts: Dict[str, int] = {}
    for ipc_input in ipc.get_inputs():
        layouts[ipc_input.identifier] = ipc_input.xkb_active_layout_index

    return layouts


@log_params_and_output
def restore_layout(ipc: i3ipc.Connection, layout: Dict[str, int]) -> None:
    """
    Sets global layout, provided in the argument
    """
    for input_id, layout_index in layout.items():
        ipc.command(f'input "{input_id}" xkb_switch_layout {layout_index}')


@log_params_and_output
def on_window_focus(ipc: i3ipc.Connection, event: i3ipc.Event) -> None:
    """
    When window focus changes this callback remembers the layout for the previous window
    and restores a layout if it was in the cache
    """

    global WINDOW_PREV_FOCUSED

    current_window = event.container.id
    prev_window = WINDOW_PREV_FOCUSED

    layout_cache = LayoutCache()

    # Save layout for the previous focused window if there was such a window before
    if prev_window is not None:
        layout_cache.save(prev_window, current_layout(ipc))

    # Restore layout for a new window if saved previously
    if layout_cache.has_saved(current_window):
        restore_layout(ipc, layout_cache.retrieve(current_window))

    WINDOW_PREV_FOCUSED = current_window


@log_params_and_output
def on_window_close(_: i3ipc.Connection, event: i3ipc.Event) -> None:
    """
    Cleanup cache when window is closed
    """
    LayoutCache().discard(event.container.id)


@log_params_and_output
def on_window(ipc: i3ipc.Connection, event: i3ipc.Event) -> None:
    """
    Route window callback events to corresponding handlers
    """
    logging.debug("Processing event %s", event.change)
    if event.change == "focus":
        on_window_focus(ipc, event)
    elif event.change == "close":
        on_window_close(ipc, event)


def main() -> None:
    global WINDOW_PREV_FOCUSED

    logging.getLogger().setLevel(logging.DEBUG)

    while True:
        try:
            ipc_connection = i3ipc.Connection()

            # Edge case:
            # Init prev window with currently focused window as there is
            # no initial focus change event for that one and its layout
            # won't be preserved on the first focus change otherwise
            window_focused = ipc_connection.get_tree().find_focused()

            if window_focused is not None:
                WINDOW_PREV_FOCUSED = window_focused.id

            # Init callback handler and start the main loop
            ipc_connection.on("window", on_window)
            ipc_connection.main()
        except KeyboardInterrupt:
            logging.exception("Stopping application")
            sys.exit(1)
        finally:
            logging.exception("Restarting program")
            time.sleep(1)


if __name__ == "__main__":
    main()
