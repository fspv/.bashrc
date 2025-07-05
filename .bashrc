# vim: ft=bash
# shellcheck shell=bash

source "${HOME}/.shrc"

case "$-" in
*i*)
    ;;
*)
    # nothing more to do for non-interactive session
    return
    ;;
esac

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Load local rc file for this machine
[ -f ~/.bashrc.local ] && source "${HOME}/.bashrc.local"

# Non-idempotent configs

# Convert c1.h1.domain.com to c1.h1 except h1
if command -v timeout >/dev/null 2>&1
then
    FQDN=$(timeout -s 9 5 hostname -f)
else
    FQDN=$(hostname -f)
fi
SHORT_HOSTNAME=${FQDN%.[^.]*.[^.]*}

# Load git-completion file
# shellcheck source=/dev/null
[ -f "${GIT_COMPLETION_DIR}/git-completion.bash" ] && source "${GIT_COMPLETION_DIR}/git-completion.bash"

# Load completion for kubectl
# shellcheck source=/dev/null
which kubectl >/dev/null 2>&1 && source <(kubectl completion bash 2>/dev/null)

# Load fzf completion files
# shellcheck source=/dev/null
which fzf >/dev/null 2>&1 && source <(fzf --bash 2>/dev/null)

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

# Prevent double .bashrc sourcing in different files
if { test "${TMUX}" != "" && test "${TMUX_BASHRC_ALREADY_EXECUTED}" = ""; } || test "$BASHRC_ALREADY_EXECUTED" = ""
then
    # Interactive session
    export BASHRC_ALREADY_EXECUTED="yes"
    if test "x${TMUX}" != "x"
    then
        export TMUX_BASHRC_ALREADY_EXECUTED="yes"
    fi
    test -f /etc/profile && source /etc/profile
else
    return
fi

# Reset
Color_Off='\[\e[0m\]'       # Text Reset

# Bold High Intensity
BIRed='\[\e[1;91m\]'        # Red
BIGreen='\[\e[1;92m\]'      # Green
BIYellow='\[\e[1;93m\]'     # Yellow
BIBlue='\[\e[1;94m\]'       # Blue
BICyan='\[\e[1;96m\]'       # Cyan

funsay

echo -e "\e[1;36m     FQDN: $FQDN"
echo -e "\e[1;36m       LA: $(cut -f 1-4 -d' ' /proc/loadavg 2>/dev/null)"

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
    PS1=$PS1'if ! test "x${KUBECTL_CONTEXT}/${KUBECTL_NAMESPACE}" = "x/";'
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
PS1=$PS1'$(if ! test "x${IN_NIX_SHELL}" = "x";'
PS1=$PS1'then'
PS1=$PS1'    NIX_SHELL_LEVEL=${SHLVL:-1};'
PS1=$PS1'    if [ -n "${NIX_SHELL_BASE_LEVEL}" ]; then'
PS1=$PS1'        NIX_SHELL_LEVEL=$((NIX_SHELL_LEVEL - NIX_SHELL_BASE_LEVEL));'
PS1=$PS1'    else'
PS1=$PS1'        NIX_SHELL_LEVEL=1;'
PS1=$PS1'    fi;'
PS1=$PS1'    echo -e "'${BIRed}'[nix:'${BIBlue}
PS1=$PS1'${IN_NIX_SHELL}'${BIYellow}'(${NIX_SHELL_LEVEL})'${BIRed}'] ";'
PS1=$PS1'fi)'
PS1=$PS1"$BIYellow\W "
PS1=$PS1"$BICyan$PROMPT $Color_Off"

# Always populate .bash_history
PS1=$PS1'$(history -a 2>&1 >/dev/null)'

# Wrong line wrapping? Follow the link:
# https://unix.stackexchange.com/questions/105958/terminal-prompt-not-wrapping-correctly

# shellcheck disable=SC2090
export PS1
