#!/bin/zsh
# Sync pane context (path, git branch, k8s) into tmux pane-local variables
# Receives $1 = current working directory from the precmd hook
if [[ -n "$TMUX" ]]; then
    { tmux-info "$1" } &!
fi