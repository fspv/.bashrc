xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command -t string -sa i3
xfconf-query -c xfce4-session -p /sessions/Failsafe/Client1_Command -t string -sa ''
xfconf-query -c xfce4-session -p /sessions/Failsafe/Client2_Command -t string -sa ''
xfconf-query -c xfce4-session -p /sessions/Failsafe/Client3_Command -t string -sa ''
xfconf-query -c xfce4-session -p /sessions/Failsafe/Client4_Command -t string -sa ''
xfconf-query -c xfce4-session -p /sessions/Failsafe/Count -t int -s 1


# Keyboard config
xfconf-query -c xfce4-session -p /keyboard/KeyRepeat/Delay -t int -s 200 --create
xfconf-query -c xfce4-session -p /keyboard/KeyRepeat/Rate -t int -s 100 --create
xfconf-query -c keyboard-layout -p /Default/XkbLayout -t string -s us,ru --create
xfconf-query -c keyboard-layout -p /Default/XkbOptions/Group -t string -s grp:lctrl_lshift_toggle --create

# Lock on lid close
xfconf-query -c xfce4-session -p /shutdown/LockScreen -s true
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/hibernate-button-action -t int -s 1 --create
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lid-action-on-ac -t int -s 0 --create
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lid-action-on-battery -t int -s 1 --create
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate -t bool -s true --create
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/logind-handle-lid-switch -t bool -s true --create
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/show-tray-icon -t int -s 1 --create
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/sleep-button-action -t int -s 1 --create
