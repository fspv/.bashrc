#!/bin/bash

virtualenv -p python3 "${HOME}/.config/sway/scripts/window-bound-layout_venv"
# shellcheck disable=SC1091
source "${HOME}/.config/sway/scripts/window-bound-layout_venv/bin/activate"
pip install i3ipc

python "${HOME}/.config/sway/scripts/window-bound-layout.py"
