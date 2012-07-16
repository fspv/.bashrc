red='\e[0;31m'
RED='\e[1;31m'
green='\e[0;32m'
GREEN='\e[1;32m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m'
. ~/.profile
export LS_OPTIONS='-G'
#eval `dircolors`
alias ls='ls $LS_OPTIONS'
alias ll='ls -lA $LS_OPTIONS'
alias vi='vim'
EDITOR=vim
export EDITOR
export PS1="$RED\u$GREEN@$BLUE\h $CYAN\w $BLUE\$ $NC"
