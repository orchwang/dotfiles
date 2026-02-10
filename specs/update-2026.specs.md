# Dotfiles: Migrate from Oh My Zsh to Starship

## Context

The live system (`~/.zshrc`) already uses Starship + Homebrew-managed zsh plugins, but the dotfiles repo still has the old Oh My Zsh + Powerlevel10k + Zinit setup. This plan brings the repo in sync with the live system and adds proper automation (symlinks, plugin install, default shell).

**Security note:** The live `~/.zshrc` contains a GitHub PAT and a private registry URL. These will be excluded from the repo and moved to a `~/.zshrc.local` pattern.

---

## Files to Modify

| File | Action |
|------|--------|
| `zsh/.zshrc` | Replace with sanitized version of current `~/.zshrc` |
| `Makefile` | Rewrite: remove ohmyzsh/zinit, add symlink/shell/plugin targets |
| `brewfiles/Brewfile` | Add `starship`, `zoxide`, `coreutils`, `zsh-autosuggestions`, `zsh-syntax-highlighting` |
| `.gitignore` | Add `.zshrc.local` |

## Files to Create

| File | Source |
|------|--------|
| `starship/starship.toml` | Copy from `~/.config/starship.toml` |
| `dircolors/.dircolors` | Copy from `~/.dircolors` |

---

## Step 1: Update `brewfiles/Brewfile`

Add these lines under `# Terminal tools`:

```
brew "starship"
brew "zoxide"
brew "coreutils"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
brew "fzf"
```

## Step 2: Replace `zsh/.zshrc`

Replace entire contents with sanitized version of the live config:

```zsh
export PATH="/opt/homebrew/bin:$PATH"

# Terminal
alias ls='gls --color=auto'
alias ll='ls -alF'

# Starship
export STARSHIP_CONFIG=~/.config/starship.toml
export STARSHIP_CACHE=~/.starship/cache

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(gdircolors ~/.dircolors)"

# Github
# eval $(ssh-agent -s) ; ssh-add ~/.ssh/<your-key> > /dev/null
# export GITHUB_TOKEN=<set-in-~/.zshrc.local>

# uv
# export UV_DEFAULT_INDEX=<set-in-~/.zshrc.local>

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Zsh Plugins (installed via Homebrew)
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Local overrides (secrets, machine-specific config)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Secrets (`GITHUB_TOKEN`, `UV_DEFAULT_INDEX`, `ssh-add`) are commented out with instructions to put them in `~/.zshrc.local`.

## Step 3: Copy config files into repo

- `starship/starship.toml` - copy from `~/.config/starship.toml` (Catppuccin Mocha theme, ~5KB)
- `dircolors/.dircolors` - copy from `~/.dircolors` (solarized dark, ~7KB)

## Step 4: Rewrite `Makefile`

Remove `set-ohmyzsh`, `set-zinit`. New structure:

```makefile
SHELL := /bin/zsh
DOTFILES_DIR := $(shell pwd)

install: set-xcode set-brew set-packages link set-default-shell

set-xcode:       # install xcode CLI tools if missing
set-brew:        # install homebrew if missing
set-packages:    # brew bundle --file=brewfiles/Brewfile

# Symlinks
link: link-zshrc link-starship link-dircolors link-gitconfig link-tmux link-lvim
link-zshrc:      # ln -sf zsh/.zshrc ~/.zshrc
link-starship:   # ln -sf starship/starship.toml ~/.config/starship.toml
link-dircolors:  # ln -sf dircolors/.dircolors ~/.dircolors
link-gitconfig:  # ln -sf git/.gitconfig ~/.gitconfig
link-tmux:       # ln -sf tmux/.tmux.conf ~/.tmux.conf
link-lvim:       # ln -sf lvim/config.lua ~/.config/lvim/config.lua

set-default-shell:  # chsh -s $(which zsh) if not already zsh

check-plugins:   # verify all tools/plugins from .zshrc are installed
clean:           # brew bundle cleanup
unlink:          # remove all symlinks

install-others:  # brew bundle for BrewFile.others
install-rust:    # brew bundle for BrewFile.rust + rustup-init
```

Key changes:
- `install` flow: xcode -> brew -> packages -> symlinks -> default shell
- Symlink targets for all config files
- `check-plugins` validates that starship, zoxide, gls, gdircolors, and both zsh plugins are available
- `unlink` target for clean removal
- Removed `sudo -v` (not needed on Apple Silicon Homebrew)

## Step 5: Update `.gitignore`

Add `.zshrc.local` to prevent accidental secret commits.

## Step 6: Update `README.md`

Brief rewrite documenting the new structure, quick start (`make install`), available targets, and the `~/.zshrc.local` pattern for secrets.

---

## Verification

1. Run `make check-plugins` - should report all tools as OK
2. Run `make link` - verify symlinks point correctly (`ls -la ~/.zshrc ~/.config/starship.toml ~/.dircolors`)
3. Open a new terminal - Starship prompt should render, zsh plugins should work (autosuggestions, syntax highlighting)
4. Run `git diff` - confirm no secrets in tracked files
