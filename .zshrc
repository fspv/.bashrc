# vim: ft=sh

# Block Cursor from injecting shell integration early
if [[ "$TERM_PROGRAM" == "vscode" || "$TERM_PROGRAM" == "Cursor" ]]; then
  export VSCODE_SHELL_INTEGRATION=0
  return
fi

export ZSH_COMPDUMP="${HOME}/.cache/.zcompdump"

autoload -Uz compinit
compinit -d "${ZSH_COMPDUMP}"

# shellcheck source=/dev/null
[ -f ~/.zshrc.local ] && source "${HOME}/.zshrc.local"

if [[ -n "$FPATH_CUSTOM" ]]
then
    FPATH_CUSTOM_ARRAY=("${(@s/:/)FPATH_CUSTOM}")
    for f in "${FPATH_CUSTOM_ARRAY[@]}"/*; do
        fpath+=($f)
    done
fi

# shellcheck source=/dev/null
which plz >/dev/null 2>&1 && source <(plz --completion_script)

# shellcheck source=/dev/null
which fzf >/dev/null 2>&1 && source <(fzf --zsh 2>/dev/null)

# shellcheck source=/dev/null
which kubectl >/dev/null 2>&1 && source <(kubectl completion zsh 2>/dev/null)

if [[ -f "${GIT_COMPLETION_DIR}/git-completion.zsh" ]]
then
    zstyle ':completion:*:*:git:*' script "${GIT_COMPLETION_DIR}/git-completion.zsh"
fi

# TODO: have no idea how this works, hence added it twice
compinit -d "${ZSH_COMPDUMP}"

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
    zsh-autosuggestions
    zsh-syntax-highlighting
    forgit
    you-should-use
    fzf-tab
)

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

source "${HOME}/.shrc"

setopt inc_append_history
unsetopt share_history

case "$-" in
*i*)
    ;;
*)
    # nothing more to do for non-interactive session
    return
    ;;
esac

if { test "${TMUX}" != "" && test "${TMUX_ZSHRC_ALREADY_EXECUTED}" = ""; } || test "$ZSHRC_ALREADY_EXECUTED" = ""
then
    export ZSHRC_ALREADY_EXECUTED="yes"
    if test "x${TMUX}" != "x"
    then
        export TMUX_ZSHRC_ALREADY_EXECUTED="yes"
    fi
    test -f /etc/profile && source /etc/profile
    funsay
else
    return
fi
