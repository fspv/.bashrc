#!/bin/bash

virtualenv -p python3 "${HOME}/.config/i3/scripts/window-binded-layout_venv"
# shellcheck disable=SC1091
source "${HOME}/.config/i3/scripts/window-binded-layout_venv/bin/activate"
pip install i3ipc

python "${HOME}/.config/i3/scripts/window-binded-layout.py"
