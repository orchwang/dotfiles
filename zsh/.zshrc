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
    # zsh plugins live under different prefixes per distro:
    #   Arch/Omarchy: /usr/share/zsh/plugins/<plugin>/<plugin>.zsh
    #   Ubuntu:       /usr/share/<plugin>/<plugin>.zsh
    for _zplug in \
        /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
        /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
        [ -f "$_zplug" ] && source "$_zplug" && break
    done
    for _zplug in \
        /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
        /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
        [ -f "$_zplug" ] && source "$_zplug" && break
    done
    unset _zplug
    # Set TERM outside tmux/screen (SSH sessions, Ghostty, etc.)
    [[ -z "$TMUX" && -z "$STY" ]] && export TERM=xterm-256color
    # Ubuntu renames fd and bat; Arch ships them as fd/bat (these become no-ops)
    command -v fdfind > /dev/null && alias fd='fdfind'
    command -v batcat > /dev/null && alias bat='batcat'
fi

export PATH="$HOME/.local/bin:$PATH"

# Go
[ -d "$HOME/.local/go/bin" ] && export PATH="$HOME/.local/go/bin:$PATH"
command -v go > /dev/null && export PATH="$PATH:$(go env GOPATH)/bin"

# Rust
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

alias ll='ls -alF'

# Starship
export STARSHIP_CONFIG=~/.config/starship.toml
export STARSHIP_CACHE=~/.starship/cache

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
command -v direnv > /dev/null && eval "$(direnv hook zsh)"

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
