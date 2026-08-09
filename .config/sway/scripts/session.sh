#!/bin/sh
# Session integration, adapted from sway-systemd's session.sh

# Force session identity regardless of launch path (a tty login has
# XDG_SESSION_TYPE=tty — importing that was a live bug in the old line)
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-sway}"
export XDG_SESSION_TYPE=wayland

# Refuse to clobber a running session's env (nested sway, double launch)
if systemctl --user -q is-active sway-session.target; then
    echo "session target already active; refusing to overwrite environment"
    exit 1
fi

VARIABLES="XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE DISPLAY WAYLAND_DISPLAY SWAYSOCK I3SOCK XCURSOR_THEME XCURSOR_SIZE GTK_IM_MODULE QT_IM_MODULE XMODIFIERS"

# One call updates BOTH the D-Bus activation env and the systemd manager env
# shellcheck disable=SC2086
dbus-update-activation-environment --systemd $VARIABLES

systemctl --user reset-failed
systemctl --user start sway-session.target

# Stay alive as the teardown watcher: block until sway exits, then
# stop everything session-bound and clear the stale env.
cleanup() {
    systemctl --user start --job-mode=replace-irreversibly sway-session-shutdown.target
    # shellcheck disable=SC2086
    systemctl --user unset-environment $VARIABLES
}
trap cleanup INT TERM
swaymsg -t subscribe '["shutdown"]'
cleanup
