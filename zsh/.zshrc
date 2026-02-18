# --- Platform detection ---
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    alias ls='gls --color=auto'
    eval "$(gdircolors ~/.dircolors)"
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else
    alias ls='ls --color=auto'
    eval "$(dircolors ~/.dircolors)"
    [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
        source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
        source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    # Ghostty terminal
    [[ "$TERM_PROGRAM" == "ghostty" ]] && export TERM=xterm-256color
    # Ubuntu renames fd and bat
    command -v fdfind > /dev/null && alias fd='fdfind'
    command -v batcat > /dev/null && alias bat='batcat'
fi

export PATH="$HOME/.local/bin:$PATH"

# Rust
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

alias ll='ls -alF'

# Starship
export STARSHIP_CONFIG=~/.config/starship.toml
export STARSHIP_CACHE=~/.starship/cache

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# Github
# eval $(ssh-agent -s) ; ssh-add ~/.ssh/<your-key> > /dev/null
# export GITHUB_TOKEN=<set-in-~/.zshrc.local>

# uv
# export UV_DEFAULT_INDEX=<set-in-~/.zshrc.local>

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Local overrides (secrets, machine-specific config)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
