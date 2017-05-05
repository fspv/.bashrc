# Prevent double .bashrc sourcing in different files
if test "x$BASHRC_ALREADY_EXECUTED" = "x"
then
    export PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    case "$-" in
    *i*)
        # Interactive session
        export BASHRC_ALREADY_EXECUTED="yes"
        test -f /etc/profile && source /etc/profile
#        (test -f ~/.bash_profile && source ~/.bash_profile) || \
#        (test -f ~/.bash_login && source ~/.bash_login) || \
#        (test -f ~/.profile && source ~/.profile)
        ;;
    *)
        # Non-interactive session
        return
        ;;
    esac
else
    return
fi

# Remove note about using sudo
test -f ~/.sudo_as_admin_successful || touch ~/.sudo_as_admin_successful

# setup SSH agent
if [ "x$SSH_AUTH_SOCK" = "x" ] ; then
    eval $(ssh-agent -s) >/dev/null
    ssh-add >/dev/null 2>&1
fi

# Convert c1.h1.domain.com to c1.h1 except h1
if command -v timeout >/dev/null 2>&1
then
    FQDN=$(timeout -s 9 5 hostname -f)
else
    FQDN=$(hostname -f)
fi
SHORT_HOSTNAME=$(echo $FQDN | sed "s/\.[^\.]*\.[^\.]*$//g")

# systemd variables
export SYSTEMD_PAGER=less
export PAGER=less

# Load local rc file for this machine
[ -f ~/.bashrc.local ] && source ~/.bashrc.local

# Load git-completion file
[ -f ~/.git-completion.bash ] && source ~/.git-completion.bash

# Autocompletion options
set show-all-if-ambiguous on
set show-all-if-unmodified on
set completion-ignore-case on

# Fix upstart completion (autocomplete all jobs to all states)
_upstart_all() {
    find /etc/init/ -name '*.conf' -printf '%f\n' | sed 's/\.conf$//'
}

_upstart_complete_new() {
    _get_comp_words_by_ref cur prev

    case "$prev" in
        --help|--version)
            COMPREPLY=()
            return 0
            ;;
        status)
            opts="--help --version -q --quiet -v --verbose --session --system \
                  --dest= -n --no-wait"
            ;;
        start|stop|restart|reload)
            opts="--help --version -q -d --detail -e --enumerate --quiet \
                  -v --verbose --session --system --dest="
            ;;
    esac

    COMPREPLY=( $(compgen -W "$opts $(_upstart_all)" -- ${cur}) )
    return 0
}

complete -F _upstart_complete_new reload
complete -F _upstart_complete_new stop
complete -F _upstart_complete_new start
complete -F _upstart_complete_new restart
complete -F _upstart_complete_new status

# Completion for hosts for ssh
resolv_search_domains=$(grep '^search .*$' /etc/resolv.conf | sed 's/^search //')

_complete_ssh_get_hosts_from_bash_history() {
    grep -Pa '^s [a-zA-Z0-9][a-zA-Z0-9@\.\-]*$' ~/.bash_history | \
        cut -f2 -d' ' | cut -f2 -d'@' | \
        sed -r "s/($(for d in $resolv_search_domains; do echo -n '\.'$d'$|'; done))//g" | \
        sort | uniq
}

_complete_ssh() {
    _get_comp_words_by_ref cur prev

    COMPREPLY=( $(compgen -W \
        "$opts $(_complete_ssh_get_hosts_from_bash_history)" \
        -- ${cur})
    )
    return 0
}

complete -F _complete_ssh s
complete -F _complete_ssh ssh

# Create alias for sshrc
[ -f /usr/bin/sshrc ] && alias s='sshrc'

# Create systemd aliases
which systemctl 2>&1 >/dev/null && alias sctl='sudo systemctl'
which journalctl 2>&1 >/dev/null && alias jctl='sudo journalctl'

# Ignore duplicates in .bash_history
export HISTCONTROL=ignoredups 2>/dev/null
# The  maximum  number of lines contained in the history file.
export HISTFILESIZE=99999 2>/dev/null
# Controls output of `history` command end enables time logging in .bash_history
export HISTTIMEFORMAT="%a, %d %b %Y %T %z" 2>/dev/null

function hs {
    grep -a "$*" $HISTFILE
}

# Disable auto prompt for virtualenv
VIRTUAL_ENV_DISABLE_PROMPT=yes

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# SSHRC config

# Set vim to /usr/bin/vim, because on some systems /bin/vim is alias for /bin/vi
[ "x${SSHHOME}" != "x" ] && alias vim="/usr/bin/vim -u ${SSHHOME}/.sshrc.d/.vimrc"

case $(uname) in
    FreeBSD)
        MD5SUM='md5'
        STAT_TIME='stat -f%m'
        export LS_OPTIONS='-G'
        if command -v dircolors >/dev/null 2>&1
        then
            eval $(dircolors)
        fi
        ;;
    Linux)
        MD5SUM='md5sum'
        STAT_TIME='stat -c%Z'
        LS_OPTIONS='--color=auto'
        alias grep='grep --color=auto'    
        alias chown='chown --preserve-root'
        alias chmod='chmod --preserve-root'
        alias chgrp='chgrp --preserve-root'
        ;;
    *)
        MD5SUM='md5sum'
        STAT_TIME='stat -c%Z'
        ;;
esac

# Aliases
# http://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
alias sudo='sudo '
alias mkdir='mkdir -p -v'
alias ls='ls $LS_OPTIONS'
alias ll='ls -lA $LS_OPTIONS'
alias vi='vim'
alias debuild='debuild -i; debuild clean'
alias acp='apt-cache policy'
alias acs='apt-cache show'
alias agi='apt-get -V install'
alias sqlplus='rlwrap sqlplus'
alias str='strace -s 999999999 -f -tt -T -y'
alias ltr='ltrace -s 999999999 -f -tt -T -n 2'
alias sudoe='sudo -E -H'

mmysql() {
    # MySQL alias
    MYSQL_READ_ONLY=$(
        grep -E '(read[-_]only)' /etc/mysql/my.cnf \
                                 /etc/mysql/conf.d/*.cnf 2>/dev/null \
                                 | tail -n1 | sed 's/ //g' | cut -f2 -d'='
    )

    if [[ "x${MYSQL_READ_ONLY}" = "x0" ]]
    then
        MYSQL_RW_PROMPT="{>MASTER<} "
    fi

    if [[ "x$1" = "xroot" ]]
    then
        MYSQL_HOME=/root
        MYSQL_SUDO='sudo -E -H'
    else
        MYSQL_HOME=${HOME}
    fi

    if ! ${MYSQL_SUDO} test -f ${MYSQL_HOME}/.editrc
    then
        echo 'bind "^U" vi-kill-line-prev' | \
            ${MYSQL_SUDO} tee ${MYSQL_HOME}/.editrc
        echo 'bind "^W" ed-delete-prev-word' | \
            ${MYSQL_SUDO} tee -a ${MYSQL_HOME}/.editrc
    fi

    ${MYSQL_SUDO} mysql \
        --protocol=TCP \
        --secure-auth \
        --show-warnings \
        --tee=.${USER}.mysql_history \
        --prompt='[\u@'"${SHORT_HOSTNAME}"'] \d (\R:\m:\s) '"${MYSQL_RW_PROMPT}"'> ' \
        --pager='less --quit-if-one-screen --no-init'
}

# safety features
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

# Less options
LESS=' '
LESS=${LESS}'--line-numbers --ignore-case --underline-special '
LESS=${LESS}'--RAW-CONTROL-CHARS --chop-long-lines'
export LESS

# some functions
function mkdircd {
    mkdir $1
    cd $1
}

# add -i or -I (for newer coreutils versions) option to /bin/rm command
rmtemp=$(mktemp)
if rm -I $rmtemp &>/dev/null; then
    alias rm="rm -I"
else
    alias rm="rm -i"
    rm $rmtemp;
fi

EDITOR=vim
export EDITOR

# Reset
Color_Off='\[\e[0m\]'       # Text Reset

# Regular Colors
Black='\[\e[0;30m\]'        # Black
Red='\[\e[0;31m\]'          # Red
Green='\[\e[0;32m\]'        # Green
Yellow='\[\e[0;33m\]'       # Yellow
Blue='\[\e[0;34m\]'         # Blue
Purple='\[\e[0;35m\]'       # Purple
Cyan='\[\e[0;36m\]'         # Cyan
White='\[\e[0;37m\]'        # White

# Bold
BBlack='\[\e[1;30m\]'       # Black
BRed='\[\e[1;31m\]'         # Red
BGreen='\[\e[1;32m\]'       # Green
BYellow='\[\e[1;33m\]'      # Yellow
BBlue='\[\e[1;34m\]'        # Blue
BPurple='\[\e[1;35m\]'      # Purple
BCyan='\[\e[1;36m\]'        # Cyan
BWhite='\[\e[1;37m\]'       # White

# Underline
UBlack='\[\e[4;30m\]'       # Black
URed='\[\e[4;31m\]'         # Red
UGreen='\[\e[4;32m\]'       # Green
UYellow='\[\e[4;33m\]'      # Yellow
UBlue='\[\e[4;34m\]'        # Blue
UPurple='\[\e[4;35m\]'      # Purple
UCyan='\[\e[4;36m\]'        # Cyan
UWhite='\[\e[4;37m\]'       # White

# Background
On_Black='\[\e[40m\]'       # Black
On_Red='\[\e[41m\]'         # Red
On_Green='\[\e[42m\]'       # Green
On_Yellow='\[\e[43m\]'      # Yellow
On_Blue='\[\e[44m\]'        # Blue
On_Purple='\[\e[45m\]'      # Purple
On_Cyan='\[\e[46m\]'        # Cyan
On_White='\[\e[47m\]'       # White

# High Intensity
IBlack='\[\e[0;90m\]'       # Black
IRed='\[\e[0;91m\]'         # Red
IGreen='\[\e[0;92m\]'       # Green
IYellow='\[\e[0;93m\]'      # Yellow
IBlue='\[\e[0;94m\]'        # Blue
IPurple='\[\e[0;95m\]'      # Purple
ICyan='\[\e[0;96m\]'        # Cyan
IWhite='\[\e[0;97m\]'       # White

# Bold High Intensity
BIBlack='\[\e[1;90m\]'      # Black
BIRed='\[\e[1;91m\]'        # Red
BIGreen='\[\e[1;92m\]'      # Green
BIYellow='\[\e[1;93m\]'     # Yellow
BIBlue='\[\e[1;94m\]'       # Blue
BIPurple='\[\e[1;95m\]'     # Purple
BICyan='\[\e[1;96m\]'       # Cyan
BIWhite='\[\e[1;97m\]'      # White

# High Intensity backgrounds
On_IBlack='\[\e[0;100m\]'   # Black
On_IRed='\[\e[0;101m\]'     # Red
On_IGreen='\[\e[0;102m\]'   # Green
On_IYellow='\[\e[0;103m\]'  # Yellow
On_IBlue='\[\e[0;104m\]'    # Blue
On_IPurple='\[\e[10;95m\]'  # Purple
On_ICyan='\[\e[0;106m\]'    # Cyan
On_IWhite='\[\e[0;107m\]'   # White


if command -v ponysay >/dev/null 2>&1 && \
   command -v fortune >/dev/null 2>&1 && \
   command -v fmt >/dev/null 2>&1 && \
   command -v shuf >/dev/null 2>&1
then
    fortune -a | fmt -80 -s | ponysay -F $(shuf -n 1 -e $(ls /usr/share/ponysay/ponies/ | sed s/\.pony//g | tail -n +2))
elif command -v cowsay >/dev/null 2>&1 && \
     command -v fortune >/dev/null 2>&1 && \
     command -v fmt >/dev/null 2>&1 && \
     command -v shuf >/dev/null 2>&1
then
    FORTUNE=$(fortune -a | fmt -80 -s | cowsay -$(shuf -n 1 -e b d g p s t w y) -f $(shuf -n 1 -e $(cowsay -l | tail -n +2)) -n)
    echo -e "\e[1;36m$FORTUNE"
fi

echo -e "\e[1;36m     FQDN: "$FQDN
echo -e "\e[1;36m       LA: "$(cat /proc/loadavg | cut -f 1-4 -d' ')

if [[ $UID -ne 0 ]]
then
    PROMPT='$'
    USERNAME_COLOR=$BIGreen
    AT_COLOR=$BIRed
else
    PROMPT='#'
    USERNAME_COLOR=$BIRed
    AT_COLOR=$BIGreen
fi

# Move cursor to the begining of the next line.
# This is a hack! Will break on lines longer than 999999
#LINE_BREAK='\n\[\033[1B\]\[\033[999D\]'
#LINE_BREAK='\n\n'

# Help with <ESC> codes http://www.termsys.demon.co.uk/vtansi.htm
PS1=""
# Set terminal header
# http://tldp.org/HOWTO/Xterm-Title-3.html
PS1=$PS1'\[\033]0;'
PS1=$PS1'${USER}@${SHORT_HOSTNAME} '
PS1=$PS1': ${PWD}'
PS1=$PS1'\007\]'
# Print return code if non-zero at the beginning of line
PS1=$PS1'$(RET=$?;'
PS1=$PS1'if ! [[ ${RET} -eq 0 ]];'
PS1=$PS1"  then echo -ne '[ "${BIRed}"'\${RET}'"" ${BIYellow};( "${Color_Off}"]""';"
PS1=$PS1'fi)'
# Set prompt
PS1=$PS1"${USERNAME_COLOR}\u${AT_COLOR}@$BICyan${SHORT_HOSTNAME} "
PS1=$PS1'$(if ! test "x${VIRTUAL_ENV}" = "x";'
PS1=$PS1'then'
PS1=$PS1'    echo -e "'${BIRed}'[venv:'${BIBlue}
PS1=$PS1'$(basename ${VIRTUAL_ENV})'${BIRed}'] ";'
PS1=$PS1'fi)'
PS1=$PS1"$BIYellow\W "
PS1=$PS1"$BICyan$PROMPT $Color_Off"
# Allways populate .bash_history
PS1=$PS1'$(history -a 2>&1 >/dev/null)'

# Wrong line wrapping? Follow the link:
# https://unix.stackexchange.com/questions/105958/terminal-prompt-not-wrapping-correctly

export PS1
