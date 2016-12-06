#!/usr/bin/env python3

import sys
import logging
import subprocess
import time
import i3ipc

log = logging.getLogger()
log_handler = logging.StreamHandler(sys.stdout)
log.addHandler(log_handler)
log.setLevel(logging.INFO)

windows = {}
prev_window_id = 0


def run_shell_return_output(command):
    log.debug("Trying to run command: {0}".format(command))
    p = subprocess.Popen(command, shell=True,
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE)
    out, err = p.communicate()

    log.debug(out)
    if err:
        log.error(err)

    retcode = p.returncode

    # Print error if return code is not 0
    if retcode != 0:
        e = "Command '{0}' exited with return code {1}".format(command, retcode)
        log.error(e)

    return retcode, out, err


def get_layout():
    retcode, out, err = run_shell_return_output(
                            "~/.config/i3/scripts/xkblayout-state print %c"
                        )
    layout = int(out.strip())

    if retcode == 0 and (
                layout in [
                    0, # en
                    1, # ru
                ]
            ):
        return layout
    else:
        return False

def set_layout(layout):
    run_shell_return_output(
        "~/.config/i3/scripts/xkblayout-state set {}".format(layout))

def window_change(conn, e):
    global windows
    global prev_window_id

    log.debug(vars(e.container))

    if e.container.focused:
        # Update layout for previous window
        prev_layout = get_layout()
        if prev_window_id in windows:
            windows[prev_window_id]['layout'] = prev_layout

        # Restore layout to current window
        cur_window_id = e.container.id
        if not cur_window_id in windows:
            # If there was no layout for this window
            # before = not doing anything, just create
            # new key for it
            windows[cur_window_id] = {}
            windows[cur_window_id]['layout'] = prev_layout
        elif windows[cur_window_id]['layout'] != prev_layout:
            # Try to set layout to saved
            set_layout(windows[cur_window_id]['layout'])
        windows[cur_window_id]['last_access_time'] = int(time.time())

        # Current window become previous for next window change focus
        prev_window_id = cur_window_id
        log.debug(windows)


def main():
    conn = i3ipc.Connection()
    conn.on('window', window_change)
    conn.main()


if __name__ == "__main__":
    main()
