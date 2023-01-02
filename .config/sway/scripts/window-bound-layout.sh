#!/bin/sh

virtualenv -p python3 ${HOME}/.config/sway/scripts/window-bound-layout_venv
source ${HOME}/.config/sway/scripts/window-bound-layout_venv/bin/activate
pip install i3ipc

python ${HOME}/.config/sway/scripts/window-bound-layout.py
