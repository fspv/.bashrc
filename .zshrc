# vim: ft=sh

# Block Cursor from injecting shell integration early
if [[ "$TERM_PROGRAM" == "vscode" || "$TERM_PROGRAM" == "Cursor" ]]; then
  export VSCODE_SHELL_INTEGRATION=0
  return
fi

DISABLE_AUTO_TITLE=true

export ZSH_COMPDUMP="${HOME}/.cache/.zcompdump"

autoload -Uz compinit
compinit -d "${ZSH_COMPDUMP}"

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
    forgit
    fzf-tab
    zsh-autosuggestions
    zsh-syntax-highlighting # always last!
)


# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false

# ============================================================================
# Git completion performance optimization for large monorepos
# ============================================================================
# Threshold for considering a repo "large" (number of refs)
__GIT_LARGE_REPO_THRESHOLD=${__GIT_LARGE_REPO_THRESHOLD:-500}
# Cache dir for repo size checks
__GIT_REPO_SIZE_CACHE_DIR="${HOME}/.cache/zsh-git-completion"
mkdir -p "$__GIT_REPO_SIZE_CACHE_DIR" 2>/dev/null

# Check if current repo is large (cached per repo root)
__git_is_large_repo() {
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1

    # Get absolute path for cache key
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    local cache_key="${repo_root//\//_}"
    local cache_file="${__GIT_REPO_SIZE_CACHE_DIR}/${cache_key}"

    # Check cache (valid for 1 hour)
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null) ))
        if (( cache_age < 3600 )); then
            [[ $(cat "$cache_file") == "large" ]] && return 0
            return 1
        fi
    fi

    # Count refs (branches + tags + remotes) with timeout
    local ref_count
    ref_count=$(timeout 2 git for-each-ref --format='x' 2>/dev/null | wc -l | tr -d ' ')

    if (( ref_count > __GIT_LARGE_REPO_THRESHOLD )); then
        echo "large" > "$cache_file"
        return 0
    else
        echo "small" > "$cache_file"
        return 1
    fi
}

# Disable expensive git completions for large repos
__git_completion_setup() {
    local was_disabled=${__git_zsh_completions_disabled:-0}

    if __git_is_large_repo; then
        # Disable branch/tag completion (the main performance killer)
        __git_complete_refs() { return; }
        __git_heads() { return; }
        __git_tags() { return; }
        __git_refs() { return; }
        __gitcomp_direct() { return; }
        # For zsh git completion
        __git_zsh_completions_disabled=1

        # Also disable via zstyle
        zstyle ':completion:*:*:git*:*' tag-order ''
        zstyle ':completion:*:*:git*:*' group-order ''
        zstyle ':completion::complete:git-checkout:argument-rest:' tag-order ''
        zstyle ':completion::complete:git-switch:argument-rest:' tag-order ''
        zstyle ':completion::complete:git-branch:option-d-1:' tag-order ''

        # Log only on state change
        if [[ "$was_disabled" != "1" ]]; then
            echo "\033[33m⚠ Git completion disabled (large repo detected)\033[0m" >&2
        fi
    else
        # Re-enable for normal repos
        unset __git_zsh_completions_disabled
        zstyle -d ':completion:*:*:git*:*' tag-order

        # Log only on state change (and only if we're in a git repo)
        if [[ "$was_disabled" == "1" ]] && git rev-parse --git-dir &>/dev/null; then
            echo "\033[32m✓ Git completion re-enabled\033[0m" >&2
        fi
    fi
}

# Hook into chpwd to detect repo changes
autoload -Uz add-zsh-hook
add-zsh-hook chpwd __git_completion_setup

# Also run on shell startup
__git_completion_setup 2>/dev/null
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

# shellcheck source=/dev/null
[ -f "${HOME}/.zshrc.local" ] && source "${HOME}/.zshrc.local"

setopt inc_append_history
unsetopt share_history

# fixes https://github.com/zsh-users/zsh-autosuggestions/pull/753
unset ZSH_AUTOSUGGEST_USE_ASYNC

which atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"

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
