[ -f ~/.zshrc.local ] && source "${HOME}/.zshrc.local"

setopt inc_append_history

# Path to your oh-my-zsh installation.
if [[ (-n "$ZSH" && -f "$ZSH/oh-my-zsh.sh") || -f "$HOME/.local/share/oh-my-zsh/oh-my-zsh.sh" ]]; then
    export ZSH="${ZSH:-$HOME/.local/share/oh-my-zsh}"
    export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.local/share/oh-my-zsh/custom}"
fi

if [[ -n "$ZSH_PLUGIN_DIRS" && -n "${ZSH_CUSTOM}" ]]; then
    IFS=":" read -r DIRS <<< "$ZSH_PLUGIN_DIRS"
    for dir in "${DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            for item in "$dir"/*; do
                ln -sf "$item" "${ZSH_CUSTOM}/plugins/"
            done
        else
            echo "zsh plugin linker: directory '$dir' does not exist."
        fi
    done
fi

plugins=(
    git
    kubectl
    kubectx
    virtualenv
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
    forgit
    you-should-use
    fzf-tab
)

zstyle ':completion:*:*:git:*' script "${HOME}/.git-completion.zsh"

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
# shellcheck disable=SC2086
# shellcheck disable=SC2296
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with exa when completing cd
# shellcheck disable=SC2016
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

FZF_BASE="$(which fzf)"
export FZF_BASE


function zvm_config() {
    ZVM_CURSOR_STYLE_ENABLE=false
}


# Bind for fzf history search
(( ! ${+ZSH_FZF_HISTORY_SEARCH_BIND} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_BIND='^r'

# Args for fzf
(( ! ${+ZSH_FZF_HISTORY_SEARCH_FZF_ARGS} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_FZF_ARGS='+s +m -x -e --preview-window=hidden'

# Extra args for fzf
(( ! ${+ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS=''

# Cursor to end-of-line
(( ! ${+ZSH_FZF_HISTORY_SEARCH_END_OF_LINE} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_END_OF_LINE=''

# Include event numbers
(( ! ${+ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS=1

# Include full date timestamps in ISO8601 `yyyy-mm-dd hh:mm' format
(( ! ${+ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH=1

# Remove duplicate entries in history
(( ! ${+ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES=''

fzf_history_search() {
  setopt extendedglob

  FC_ARGS="-l"
  CANDIDATE_LEADING_FIELDS=2

  if (( ! $ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS )); then
    FC_ARGS+=" -n"
    ((CANDIDATE_LEADING_FIELDS--))
  fi

  if (( $ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH )); then
    FC_ARGS+=" -i"
    ((CANDIDATE_LEADING_FIELDS+=2))
  fi

  history_cmd="fc ${=FC_ARGS} -1 0"

  if [ -n "${ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES}" ];then
    if (( $+commands[awk] )); then
      history_cmd="$history_cmd | awk '!seen[\$0]++'"
    else
      # In case awk is not installed fallback to uniq. It will only remove commands that are repeated consecutively.
      history_cmd="$history_cmd | uniq"
    fi
  fi

  candidates=(${(f)"$(eval $history_cmd | fzf ${=ZSH_FZF_HISTORY_SEARCH_FZF_ARGS} ${=ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS} -q "$BUFFER")"})
  local ret=$?
  if [ -n "$candidates" ]; then
    if (( ! $CANDIDATE_LEADING_FIELDS == 1 )); then
      BUFFER="${candidates[@]/(#m)[0-9 \-\:]##/${${(As: :)MATCH}[${CANDIDATE_LEADING_FIELDS},-1]}}"
    else
      BUFFER="${candidates[@]}"
    fi
    BUFFER=$(printf "${BUFFER[@]//\\\\n/\\\\\\n}")
    zle vi-fetch-history -n $BUFFER
    if [ -n "${ZSH_FZF_HISTORY_SEARCH_END_OF_LINE}" ]; then
      zle end-of-line
    fi
  fi
  zle reset-prompt
  return $ret
}

autoload fzf_history_search
zle -N fzf_history_search

bindkey $ZSH_FZF_HISTORY_SEARCH_BIND fzf_history_search

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(forward-char end-of-line vi-forward-char)

ZSH_THEME="powerlevel10k/powerlevel10k"

[[ -n "$ZSH" && -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f "${HOME}/.p10k.zsh" ]] && source "${HOME}/.p10k.zsh"

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# kube config
if [ "${KUBECONFIG/:*}" = "$HOME/.kube/config" ]
then
    export KUBECONFIG=$HOME/.kube/config
    for file in "$HOME/.kube/configs"/*.yaml; do
      export KUBECONFIG=$KUBECONFIG:$file
    done
    export KUBE_FUZZY_PREVIEW_ENABLED=true
fi

# Prevent double .zshrc sourcing in different files
if (test "x${TMUX}" != "x" && test "x${TMUX_ZSHRC_ALREADY_EXECUTED}" = "x") || test "x$ZSHRC_ALREADY_EXECUTED" = "x"
then
    export PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    case "$-" in
    *i*)
        # Interactive session
        export ZSHRC_ALREADY_EXECUTED="yes"
        if test "x${TMUX}" != "x"
        then
            export TMUX_ZSHRC_ALREADY_EXECUTED="yes"
        fi
        test -f /etc/profile && source /etc/profile
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
SHORT_HOSTNAME=$(echo $FQDN | sed "s/\.[^\.]*\.[^\.]*$//g")

# systemd variables
export SYSTEMD_PAGER=less
export PAGER=less

which kubectl >/dev/null 2>&1 && source <(kubectl completion bash)
alias kubie="ZSHRC_ALREADY_EXECUTED= kubie"

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

# Completion for hosts for ssh
resolv_search_domains=$(grep '^search .*$' /etc/resolv.conf | sed 's/^search //')

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

# SSHRC config

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
if which nvim >/dev/null 2>&1
then
    alias vi='nvim'
    alias vim='nvim'

fi
export EDITOR=nvim
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

path_push_left() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        path="$1:${PATH:+"$PATH"}"
        export PATH=${path}
    fi
}

[ -d "${HOME}/.cargo/bin" ] && path_push_left "${HOME}/.cargo/bin"

if test -f ${HOME}/zshrc.local
then
    . "${HOME}/zshrc.local"
fi

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
    FORTUNE=$(fortune -a | fmt -80 -s | cowsay -$(shuf -n 1 -e b d g p s t w y) -f $(shuf -n 1 -e $(cowsay -l | tail -n +2)) -n)
    echo -e "\e[1;36m$FORTUNE"
fi

echo -e "\e[1;36m     FQDN: "$FQDN
echo -e "\e[1;36m       LA: "$(cat /proc/loadavg 2>/dev/null | cut -f 1-4 -d' ')
