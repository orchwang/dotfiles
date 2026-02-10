# Dotfiles: Multi-Platform Support (macOS + Ubuntu)

## Context

The dotfiles repo is currently macOS-only (Homebrew, cask, gls/gdircolors from coreutils, /opt/homebrew paths). This refactor adds Ubuntu support while preserving existing macOS behavior. It also adds NvChad configuration to the repo, replacing the outdated LunarVim config.

---

## Changes Summary

| File | Action |
|------|--------|
| `zsh/.zshrc` | **Modify** — wrap platform-specific lines in `uname` conditional |
| `Makefile` | **Modify** — add OS detection, conditional targets, new Linux targets, NvChad symlink |
| `README.md` | **Modify** — document both platforms and NvChad |
| `packages/apt-packages.txt` | **Create** — Ubuntu package list (mirrors Brewfile) |
| `nvim/` | **Create** — NvChad config (copy from `~/.config/nvim/`) |
| `lvim/` | **Remove** — replaced by NvChad |

**No changes** to: `brewfiles/`, `starship/`, `dircolors/`, `git/`, `tmux/`, `iterm/`, `.gitignore`

---

## Step 1: Create `packages/apt-packages.txt`

New file — Ubuntu equivalent of the Brewfile for core tools:

```
# Core
zsh
tmux
git
curl
wget
unzip
build-essential

# CLI tools
fzf
fd-find
bat
neovim

# Zsh plugins
zsh-autosuggestions
zsh-syntax-highlighting
```

Notes:
- `starship` and `zoxide` are NOT listed here — installed via curl scripts (apt versions are stale)
- `coreutils` not needed (Ubuntu has native GNU coreutils)
- `fd-find`/`bat` are the Ubuntu package names (binaries are `fdfind`/`batcat`)

## Step 2: Add NvChad config, remove LunarVim

### Remove `lvim/` directory

LunarVim (`lvim/config.lua`) is no longer used — replaced by NvChad.

### Create `nvim/` directory

Copy the current NvChad config from `~/.config/nvim/` into the repo. The config is cross-platform (no macOS/Linux differences).

```
nvim/
├── init.lua                    # Entry point: bootstraps lazy.nvim, loads NvChad v2.5
├── lazy-lock.json              # Plugin version locks (29 plugins)
├── .stylua.toml                # Lua formatter config
└── lua/
    ├── chadrc.lua              # Theme: aquarium
    ├── options.lua             # Editor options (defaults from nvchad)
    ├── mappings.lua            # Custom keys: ; → cmd, jk → esc, s/S/gw → hop
    ├── autocmds.lua            # Autocommands (defaults from nvchad)
    ├── plugins/
    │   └── init.lua            # Plugins: conform.nvim, nvim-lspconfig, hop.nvim
    └── configs/
        ├── lazy.lua            # Lazy.nvim settings (disabled builtin plugins)
        ├── lspconfig.lua       # LSP servers: html, cssls
        └── conform.lua         # Formatters: stylua (lua)
```

Files to **exclude** (auto-generated, not tracked):
- `~/.config/nvim/.git/` — NvChad source repo
- `~/.config/nvim/README.md`, `LICENSE` — NvChad boilerplate
- `~/.local/share/nvim/` — plugin cache, installed at runtime

## Step 3: Modify `zsh/.zshrc`

Wrap the 5 platform-specific lines in a `uname` conditional. Everything else stays shared.

```zsh
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
    # Ubuntu renames fd and bat
    command -v fdfind > /dev/null && alias fd='fdfind'
    command -v batcat > /dev/null && alias bat='batcat'
fi

alias ll='ls -alF'

# Starship (cross-platform)
export STARSHIP_CONFIG=~/.config/starship.toml
export STARSHIP_CACHE=~/.starship/cache
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# ... rest unchanged (NVM, commented secrets, ~/.zshrc.local) ...
```

Key: macOS branch is identical to current behavior. Linux branch uses native `ls`, `dircolors`, apt plugin paths, and adds `fd`/`bat` aliases.

## Step 4: Rewrite `Makefile`

Major changes:
- `SHELL := /bin/bash` (not `/bin/zsh` — zsh may not exist on fresh Ubuntu)
- `OS := $(shell uname -s)` for detection
- Remove global `BREW_PREFIX` (fails on Linux at parse time)
- Conditional `install` chains via `ifeq($(OS),Darwin)`
- New targets: `set-apt-packages`, `set-starship`, `set-zoxide`
- Replace `link-lvim` with `link-nvim` (symlink `nvim/` → `~/.config/nvim`)

```
macOS install chain:  set-xcode → set-brew → set-packages → link → set-default-shell
Ubuntu install chain: set-apt-packages → set-starship → set-zoxide → link → set-default-shell
```

Symlink changes:
- **Remove**: `link-lvim` (`lvim/config.lua` → `~/.config/lvim/config.lua`)
- **Add**: `link-nvim` (`nvim/` → `~/.config/nvim`) — symlinks the entire directory

Other symlink targets (`link-*`) are identical on both platforms.

`check-plugins` becomes platform-aware:
- macOS: checks `gls`, `gdircolors`, brew plugin paths
- Ubuntu: checks `ls`, `dircolors`, `/usr/share/` plugin paths

## Step 5: Update `README.md`

- Change subtitle to "macOS and Ubuntu"
- Replace `lvim/` row with `nvim/` (NvChad) in directory table
- Add `packages/` row to directory table
- Add platform matrix for make targets
- Document that `make install` auto-detects OS

---

## Verification

1. **macOS** — Run `make check-plugins` (should still pass, no regressions)
2. **Ubuntu** — On an Ubuntu VM/container:
   - `git clone && cd dotfiles && make install`
   - Verify: zsh is default, starship renders, zoxide works, plugins load
   - `make check-plugins` passes
3. **NvChad** — After `make link`, run `nvim`:
   - Lazy.nvim should bootstrap and install plugins automatically
   - Aquarium theme loads, hop.nvim keybindings work (s/S/gw)
   - `:Mason` available for installing LSP servers
4. **Both** — `git diff` shows no secrets, `.zshrc` sources `~/.zshrc.local` on both platforms
