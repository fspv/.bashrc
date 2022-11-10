#!/bin/sh

while true
do
   setxkbmap -model pc105 -layout us,ru -option grp:ctrl_shift_toggle,grp_led:caps,lv3:lalt_switch,ctrl:nocaps
   sleep 1
done
