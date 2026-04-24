setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt AUTO_CD
setopt CORRECT
setopt INTERACTIVE_COMMENTS

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

autoload -Uz compinit && compinit
zstyle ":completion:*" matcher-list "m:{a-z}={A-Z}"
zstyle ":completion:*" menu select
zstyle ":completion:*" list-colors "${(s.:.)LS_COLORS}"

alias ls="ls --color=auto"
alias ll="ls -lah --color=auto"
alias la="ls -a --color=auto"
alias grep="grep --color=auto"
alias ..="cd .."
alias ...="cd ../.."
alias c="clear"

if command -v bat &>/dev/null; then
    alias cat="bat --style=plain"
fi

cd() {
    builtin cd "$@" && ls
}

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export EDITOR=vim

if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

if command -v fzf &>/dev/null; then
    source <(fzf --zsh) 2>/dev/null
fi

if command -v fastfetch &>/dev/null; then
    fastfetch
fi
