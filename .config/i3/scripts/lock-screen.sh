#!/bin/bash

# This script forces i3lock to switch keyboard to $DEFAULT_LAYOUT and then
# after unlock swith layout back to saved

DEFAULT_LAYOUT=0

PREV_LAYOUT=$(${HOME}/.config/i3/scripts/xkblayout-state print %c)

${HOME}/.config/i3/scripts/xkblayout-state set ${DEFAULT_LAYOUT}

i3lock --nofork -c 000000

${HOME}/.config/i3/scripts/xkblayout-state set ${PREV_LAYOUT}

setxkbmap -model pc105 -layout us,ru -option grp:ctrl_shift_toggle,grp_led:caps,lv3:lalt_switch,ctrl:nocaps
