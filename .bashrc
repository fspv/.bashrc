# Idempotent configs

# kube config
if [ "${KUBECONFIG/:*}" = "$HOME/.kube/config" ]
then
    export KUBECONFIG=$HOME/.kube/config
    for file in "$HOME/.kube/configs"/*.yaml; do
      export KUBECONFIG=$KUBECONFIG:$file
    done
    export KUBE_FUZZY_PREVIEW_ENABLED=true
fi

# Prevent double .bashrc sourcing in different files
if { test "${TMUX}" != "" && test "${TMUX_BASHRC_ALREADY_EXECUTED}" = ""; } || test "$BASHRC_ALREADY_EXECUTED" = ""
then
    export PATH="${PATH}:/bin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    case "$-" in
    *i*)
        # Interactive session
        export BASHRC_ALREADY_EXECUTED="yes"
        if test "x${TMUX}" != "x"
        then
            export TMUX_BASHRC_ALREADY_EXECUTED="yes"
        fi
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
if [ "$SSH_AUTH_SOCK" = "" ] ; then
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add >/dev/null 2>&1
fi

if test -f "${HOME}/homebrew/bin/brew"
then
    eval "$(homebrew/bin/brew shellenv)"
fi

# Convert c1.h1.domain.com to c1.h1 except h1
if command -v timeout >/dev/null 2>&1
then
    FQDN=$(timeout -s 9 5 hostname -f)
else
    FQDN=$(hostname -f)
fi
SHORT_HOSTNAME=${FQDN%.[^.]*.[^.]*}

# systemd variables
export SYSTEMD_PAGER=less
export PAGER=less

# Load local rc file for this machine
[ -f ~/.bashrc.local ] && source "${HOME}/.bashrc.local"

# Load git-completion file
# shellcheck source=/dev/null
[ -f "${GIT_COMPLETION_DIR}/git-completion.bash" ] && source "${GIT_COMPLETION_DIR}/git-completion.bash"

# Load completion for kubectl
# shellcheck source=/dev/null
which kubectl >/dev/null 2>&1 && source <(kubectl completion bash)
alias kubie="BASHRC_ALREADY_EXECUTED= kubie"

# Make python poetry work
export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring

# Autocompletion options
set show-all-if-ambiguous on
set show-all-if-unmodified on
set completion-ignore-case on

# Set vim mode
set -o vi
set editing-mode vi
set show-mode-in-prompt on
set vi-ins-mode-string +
set vi-cmd-mode-string :

# Load fzf completion files
# shellcheck source=/dev/null
which fzf >/dev/null 2>&1 && source <(fzf --bash)

FD_CMD="/usr/lib/cargo/bin/fd"
fd () {
    "$FD_CMD" "$@"
}

if test -f "${FD_CMD}"
then
    export FZF_DEFAULT_COMMAND="/usr/lib/cargo/bin/fd --type f --strip-cwd-prefix"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Completion for hosts for ssh
resolv_search_domains=$(grep '^search .*$' /etc/resolv.conf | sed 's/^search //')

_complete_ssh_get_hosts_from_bash_history() {
    grep -Pa '^s [a-zA-Z0-9][a-zA-Z0-9@\.\-]*$' ~/.bash_history | \
        cut -f2 -d' ' | cut -f2 -d'@' | \
        sed -r "s/($(for d in $resolv_search_domains; do echo -n '\.'"$d"'$|'; done))//g" | \
        sort | uniq
}

_complete_ssh() {
    _get_comp_words_by_ref cur prev

    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W \
        "$opts $(_complete_ssh_get_hosts_from_bash_history)" \
        -- "${cur}")
    )
    return 0
}

complete -F _complete_ssh s
complete -F _complete_ssh ssh

# Create alias for sshrc
[ -f ~/.bin/sshrc ] && alias s='~/.bin/sshrc'

# Create systemd aliases
which systemctl >/dev/null 2>&1 && alias sctl='sudo systemctl'
which journalctl >/dev/null 2>&1 && alias jctl='sudo journalctl'

# Ignore duplicates in .bash_history
export HISTCONTROL=ignoredups 2>/dev/null
# The  maximum  number of lines contained in the history file.
export HISTSIZE=99999 2>/dev/null
export HISTFILESIZE=99999 2>/dev/null
# Controls output of `history` command end enables time logging in .bash_history
export HISTTIMEFORMAT="%a, %d %b %Y %T %z " 2>/dev/null

function hs {
    grep -a "$*" "${HISTFILE}"
}

# Disable auto prompt for virtualenv
export VIRTUAL_ENV_DISABLE_PROMPT=yes

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# SSHRC config

# Set vim to /usr/bin/vim, because on some systems /bin/vim is alias for /bin/vi
# shellcheck disable=SC2139
[ "${SSHHOME}" != "" ] && alias vim="/usr/bin/vim -u ${SSHHOME}/.sshrc.d/.vimrc"


case $(uname) in
    FreeBSD)
        export MD5SUM='md5'
        export STAT_TIME='stat -f%m'
        export LS_OPTIONS='-G'
        if command -v dircolors >/dev/null 2>&1
        then
            eval "$(dircolors)"
        fi
        ;;
    Linux)
        export MD5SUM='md5sum'
        export STAT_TIME='stat -c%Z'
        export LS_OPTIONS='--color=auto'
        alias grep='grep --color=auto'
        alias chown='chown --preserve-root'
        alias chmod='chmod --preserve-root'
        alias chgrp='chgrp --preserve-root'
        ;;
    *)
        export MD5SUM='md5sum'
        export STAT_TIME='stat -c%Z'
        ;;
esac

# Aliases
# http://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
alias sudo='sudo '
alias mkdir='mkdir -p -v'
alias ls='ls $LS_OPTIONS'
alias ll='ls -lA $LS_OPTIONS'
if which nvim >/dev/null 2>&1
then
    alias vi='nvim'
    alias vim='nvim'
fi
alias debuild='debuild -i; debuild clean'
alias acp='apt-cache policy'
alias acs='apt-cache show'
alias agi='apt-get -V install'
alias sqlplus='rlwrap sqlplus'
alias str='strace -s 999999999 -f -tt -T -y'
alias ltr='ltrace -s 999999999 -f -tt -T -n 2'
alias sudoe='sudo -E -H'
alias git-sup='git submodule init && git submodule update && git submodule status'

csv_view() {
    column -s, -t  "$1" | less -#2 -N -S
}

mmysql() {
    # MySQL alias
    MYSQL_READ_ONLY=$(
        grep -E '(read[-_]only)' /etc/mysql/my.cnf \
                                 /etc/mysql/conf.d/*.cnf 2>/dev/null \
                                 | tail -n1 | sed 's/ //g' | cut -f2 -d'='
    )

    if [[ "${MYSQL_READ_ONLY}" = "0" ]]
    then
        MYSQL_RW_PROMPT="{>PRIMARY<} "
    else
        MYSQL_RW_PROMPT="{>SECONDARY(?)<} "
    fi

    if [[ "$1" = "root" ]]
    then
        MYSQL_HOME=/root
        MYSQL_SUDO='sudo -E -H'
    else
        MYSQL_HOME=${HOME}
    fi

    if ! ${MYSQL_SUDO} test -f "${MYSQL_HOME}/.editrc"
    then
        echo 'bind "^U" vi-kill-line-prev' | \
            ${MYSQL_SUDO} tee "${MYSQL_HOME}/.editrc"
        echo 'bind "^W" ed-delete-prev-word' | \
            ${MYSQL_SUDO} tee -a "${MYSQL_HOME}/.editrc"
    fi

    ${MYSQL_SUDO} mysql \
        --protocol=TCP \
        --secure-auth \
        --show-warnings \
        --tee=".${USER}.mysql_history" \
        --prompt='[\u@'"${SHORT_HOSTNAME}"'] \d (\R:\m:\s) '"${MYSQL_RW_PROMPT}"'> ' \
        --pager='less --quit-if-one-screen --no-init'
}

plz_path() {
    FILE=$1

    SHORTEST=100000
    SHORTEST_PATH=""

    BASE_DIR="${PLZ_BASE_DIR}"
    BASE_DIR_LEN=${#BASE_DIR}

    # Prune the base dir from the path if absolute
    if [[ "${FILE}" == "${BASE_DIR}"* ]]
    then
        B=${FILE:BASE_DIR_LEN}
    else
        B=${FILE}
    fi;

    for path in $(plz query changes "$B" --include_dependees=transitive | grep -v ":_")
    do
        AC_PATH=$(echo "$path" | tr : /)
        RELATIVE_PATH=$(realpath --relative-to="$BASE_DIR$B" "$BASE_DIR$AC_PATH")
        LENGTH=$(echo "$RELATIVE_PATH" | grep -o "../" | wc -l)
        if (( SHORTEST > LENGTH ));
        then
            SHORTEST=$LENGTH
            SHORTEST_PATH=$path
        fi;
    done

    echo "${SHORTEST_PATH}"
}

plz_build() {
    path=$(plz_path "$1")
    plz build "${path}"
}

plz_test() {
    path=$(plz_path "$1")
    plz test "${path}" "$2"
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
    mkdir "$1"
    cd "$1" || true
}

path_push_left() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        path="$1:${PATH:+"$PATH"}"
        export PATH=${path}
    fi
}

# add -i or -I (for newer coreutils versions) option to /bin/rm command
rmtemp=$(mktemp)
if rm -I "$rmtemp" &>/dev/null; then
    # shellcheck disable=SC2262
    alias rm="rm -I"
else
    alias rm="rm -i"
    rm "$rmtemp";
fi

EDITOR=nvim
export EDITOR

NIX_PATH="$HOME/.nix-defexpr/channels"
export NIX_PATH

if [ "${GOPATH}" = "" ]
then
    [ -d "${HOME}/go" ] && export GOPATH="${HOME}/go"
fi
if [ "${GOBIN}" = "" ]
then
    [ -d "${HOME}/go/bin" ] && export GOBIN="${HOME}/go/bin"
fi

path_push_left "${GOBIN}"
# path_push_left "${HOME}/.local/bin"
path_push_left "${HOME}/.cargo/bin"
path_push_left "${HOME}/snap/rustup/common/rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin"
[ -d "${KREW_ROOT:-$HOME/.krew}/bin" ] && path_push_left "${KREW_ROOT:-$HOME/.krew}/bin"

# Reset
Color_Off='\[\e[0m\]'       # Text Reset

# Bold High Intensity
BIRed='\[\e[1;91m\]'        # Red
BIGreen='\[\e[1;92m\]'      # Green
BIYellow='\[\e[1;93m\]'     # Yellow
BIBlue='\[\e[1;94m\]'       # Blue
BICyan='\[\e[1;96m\]'       # Cyan

# High Intensity backgrounds

if command -v ponysay >/dev/null 2>&1 && \
   command -v fortune >/dev/null 2>&1 && \
   command -v fmt >/dev/null 2>&1 && \
   command -v shuf >/dev/null 2>&1
then
    fortune -a | fmt -80 -s | ponysay -F 2>/dev/null
elif command -v cowsay >/dev/null 2>&1 && \
     command -v fortune >/dev/null 2>&1 && \
     command -v fmt >/dev/null 2>&1 && \
     command -v shuf >/dev/null 2>&1
then
    # shellcheck disable=SC2046
    FORTUNE=$(fortune -a | fmt -80 -s | cowsay -"$(shuf -n 1 -e b d g p s t w y)" -f "$(shuf -n 1 -e $(cowsay -l | tail -n +2))" -n)
    echo -e "\e[1;36m$FORTUNE"
fi

echo -e "\e[1;36m     FQDN: $FQDN"
echo -e "\e[1;36m       LA: $(cut -f 1-4 -d' ' /proc/loadavg 2>/dev/null)"

shell="$(cat /proc/$$/comm 2>&1 || true)"

if [[ "${shell}" != "zsh" ]];
then
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
    # disable linter because the warning is incorrect. With the linter fix it
    # actually causes the wrapping issues, not prevents them
    # shellcheck disable=SC2025
    PS1=$PS1'\[\033]0;'
    PS1=$PS1'${USER}@${SHORT_HOSTNAME} '
    PS1=$PS1': ${PWD}'
    PS1=$PS1'\007\]'
    # Print return code if non-zero at the beginning of line
    PS1=$PS1'$(RET=$?;'
    PS1=$PS1'if ! [[ ${RET} -eq 0 ]];'
    # shellcheck disable=SC2089
    PS1=$PS1"  then echo -ne '[ ${BIRed}'\${RET}' ${BIYellow};( ${Color_Off}]';"
    PS1=$PS1'fi)'
    # Set prompt
    PS1=$PS1"${USERNAME_COLOR}\u${AT_COLOR}@$BICyan${SHORT_HOSTNAME} "
    if which kubectl >/dev/null 2>&1
    then
        PS1=$PS1'$(KUBECTL_CONTEXT=$(kubectl config current-context 2>/dev/null);'
        PS1=$PS1'KUBECTL_NAMESPACE=$(kubectl config view -o jsonpath="{.contexts[?(@.context.cluster == '"'"'${KUBECTL_CONTEXT}'"'"')].context.namespace}" 2>/dev/null);'
        PS1=$PS1'if ! test "x${KUBECTL_CONTEXT}/${KUBECTL_NAMESPACE}" = "x";'
        PS1=$PS1'then'
        PS1=$PS1'    echo -e "'${BIRed}'[k8s:'${BIBlue}
        PS1=$PS1'${KUBECTL_CONTEXT}/${KUBECTL_NAMESPACE}'${BIRed}'] ";'
        PS1=$PS1'fi)'
    fi
    PS1=$PS1'$(if ! test "x${VIRTUAL_ENV}" = "x";'
    PS1=$PS1'then'
    PS1=$PS1'    echo -e "'${BIRed}'[venv:'${BIBlue}
    PS1=$PS1'$(basename ${VIRTUAL_ENV})'${BIRed}'] ";'
    PS1=$PS1'fi)'
    PS1=$PS1"$BIYellow\W "
    PS1=$PS1"$BICyan$PROMPT $Color_Off"

    # Always populate .bash_history
    PS1=$PS1'$(history -a 2>&1 >/dev/null)'

    # Wrong line wrapping? Follow the link:
    # https://unix.stackexchange.com/questions/105958/terminal-prompt-not-wrapping-correctly

    # shellcheck disable=SC2090
    export PS1
fi
