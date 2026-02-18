# dotfiles

Personal development environment configuration for macOS and Ubuntu.

## What's Included

| Directory     | Config                    | Symlink Target                    |
|--------------|--------------------------|-----------------------------------|
| `zsh/`       | Zsh shell configuration   | `~/.zshrc`                        |
| `starship/`  | Starship prompt theme     | `~/.config/starship.toml`         |
| `dircolors/` | GNU ls color scheme       | `~/.dircolors`                    |
| `nvim/`      | NvChad (Neovim) config    | `~/.config/nvim`                  |
| `git/`       | Git configuration         | `~/.gitconfig`                    |
| `tmux/`      | Tmux configuration        | `~/.tmux.conf`                    |
| `ghostty/`   | Ghostty terminal config   | `~/.config/ghostty/config`        |
| `brewfiles/` | Homebrew package lists    | (macOS only, used by `make set-packages`) |
| `packages/`  | apt package list          | (Ubuntu only, used by `make set-apt-packages`) |

## Quick Start

```sh
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
make install
```

This works on both macOS and Ubuntu. The Makefile detects your OS automatically.

### macOS
Installs Xcode CLI tools, Homebrew, packages from the Brewfile, and the Rust toolchain.

### Ubuntu
Installs packages via apt, then Starship, zoxide, uv, ruff, and the Rust toolchain via their official install scripts.

## Targets

| Target                   | macOS | Ubuntu | Description                          |
|--------------------------|-------|--------|--------------------------------------|
| `make install`           | yes   | yes    | Full setup                           |
| `make link`              | yes   | yes    | Create symlinks only                 |
| `make set-packages`      | yes   | --     | Install Homebrew packages            |
| `make set-apt-packages`  | --    | yes    | Install apt packages                 |
| `make set-default-shell` | yes   | yes    | Set zsh as default shell             |
| `make check-plugins`     | yes   | yes    | Verify plugins/tools are installed   |
| `make set-rust`          | yes   | yes    | Install Rust toolchain (rustup + rustfmt + clippy) |
| `make clean`             | yes   | --     | Remove unlisted Homebrew packages    |
| `make unlink`            | yes   | yes    | Remove all symlinks                  |

## Local Overrides

Machine-specific secrets (tokens, SSH agent, private registries) go in
`~/.zshrc.local`, which is sourced at the end of `.zshrc` and is
git-ignored.
