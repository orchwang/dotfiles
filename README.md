# dotfiles

Personal development environment configuration for macOS, Ubuntu, and
Omarchy (Arch Linux).

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
| `packages/`  | apt + pacman package lists | (Linux only, used by `make set-apt-packages` / `make set-pacman-packages`) |
| `offline-devkit/` | Airgapped bundle builder  | (builds an offline NvChad + LSP/DAP + utils installer; see below) |

## Quick Start

```sh
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
make install
```

This works on macOS, Ubuntu, and Omarchy (Arch Linux). The Makefile detects
your OS automatically — and on Linux, detects Arch vs Debian by the presence
of `pacman`.

### macOS
Installs Xcode CLI tools, Homebrew, packages from the Brewfile, and the Rust toolchain.

### Ubuntu
Installs packages via apt, then Starship, zoxide, uv, ruff, and the Rust toolchain via their official install scripts.

### Omarchy (Arch Linux)
Installs packages via `pacman` from `packages/pacman-packages.txt`. Arch's
official repos already carry recent Starship, zoxide, uv, ruff, lazygit and
Go, so those come from pacman rather than the curl installers used on Ubuntu.
Neovim is still pinned to v0.11.6 via tarball (the repo build rolls forward to
0.12+, which breaks nvim-treesitter master), and Rust still comes from rustup.
`make set-pacman-packages` runs a full `pacman -Syu` first to avoid Arch
partial-upgrade breakage.

### Offline / airgapped (Ubuntu 24+)

For a target with **no internet and no editor**, `offline-devkit/` builds a
self-contained `.tar.gz` on an online machine (with Docker) that installs the
whole NvChad + LSP/DAP + terminal-utility environment offline:

```sh
./offline-devkit/build.sh                 # both arches, standard scope
# → offline-devkit/dist/devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz
```

On the airgapped target: extract, run `./install.sh`, `exec zsh`, `nvim`. See
[`offline-devkit/README.md`](offline-devkit/README.md). This is also driven by
the `offline-devkit` Claude Code skill.

## Targets

| Target                     | macOS | Ubuntu | Omarchy | Description                          |
|----------------------------|-------|--------|---------|--------------------------------------|
| `make install`             | yes   | yes    | yes     | Full setup                           |
| `make install-nvchad`      | yes   | yes    | yes     | Install NvChad + LSP/formatter deps only |
| `make link`                | yes   | yes    | yes     | Create symlinks only                 |
| `make set-packages`        | yes   | --     | --      | Install Homebrew packages            |
| `make set-apt-packages`    | --    | yes    | --      | Install apt packages                 |
| `make set-pacman-packages` | --    | --     | yes     | Install pacman packages              |
| `make set-default-shell`   | yes   | yes    | yes     | Set zsh as default shell             |
| `make check-plugins`       | yes   | yes    | yes     | Verify plugins/tools are installed   |
| `make set-rust`            | yes   | yes    | yes     | Install Rust toolchain (rustup + rustfmt + clippy) |
| `make clean`               | yes   | --     | --      | Remove unlisted Homebrew packages    |
| `make unlink`              | yes   | yes    | yes     | Remove all symlinks                  |

## Tmux

### Pane labels

Every pane shows a status line above it (`pane-border-status top`) with its
index and a label — either a manually-assigned name or, by default, the
pane's running command. This is meant for identifying panes at a glance,
e.g. distinguishing several Claude Code agent panes in the same window.

- `prefix + R`: prompt for a label and assign it to the current pane.
- Labels are stored as a pane-scoped `@label` option, not the terminal
  title, so they survive whatever OSC title escape sequences the running
  program (nvim, Claude Code, etc.) sends — unlike `select-pane -T`, which
  gets overwritten by those programs.

### Predefined session layouts

`tmux/scripts/tmux-layout.sh` (symlinked to `~/.local/bin/tmux-layout` by
`make link`) builds a named tmux session with a fixed pane arrangement,
independent of tmux-resurrect/continuum (which just replays whatever panes
happened to be open at last save). If the session already exists it's left
alone and just attached/switched to.

```sh
tmux-layout synapse-monorepo [path]   # defaults to ~/Projects/synapse
```

This builds: left 50% running nvim; right 50% split into a 3-row column
(`agent-1`, `agent-2`, `agent-3` — plain shells, ready for `claude`) and a
2-row column (`lazygit`, `shell`).

Add more layouts by writing a `layout_<name>` function in the script and
registering it in `main()`'s case statement.

### Rebalancing a column

`prefix + =` evenly redistributes pane heights within the current pane's
column (the vertical stack of panes sharing its left edge) — e.g. after
opening a few more shells stacked in a 25%-wide column, this squares them
back up to equal height without disturbing the 50|25|25 horizontal split or
any other column. Mnemonic: vim's `<C-w>=`.

Runs `tmux/scripts/tmux-rebalance-column.sh` (symlinked to
`~/.local/bin/tmux-rebalance-column`), which can also be called directly
with a pane id (`tmux-rebalance-column %12`).

### Fixing the 50|25|25 split itself

If the columns themselves have drifted (e.g. dragging a border narrows the
left 50% pane, or the two 25% columns end up 15|35 instead of 25|25),
`prefix + |` resets the window's top-level column widths back to 50|25|25
in one shot. Row heights inside each column are untouched — run this first,
then `prefix + =` per column if rows also need rebalancing.

This runs `tmux-set-column-widths` (from
`tmux/scripts/tmux-set-column-widths.sh`), which takes percentages
left-to-right and can be called directly for other ratios:

```sh
tmux-set-column-widths 50 25 25          # current window
tmux-set-column-widths -t <window-id> 60 20 20
```

Only the first N-1 columns are explicitly resized; the last one absorbs
whatever's left, the same trick `tmux-rebalance-column.sh` uses on the
vertical axis.

## Local Overrides

Machine-specific secrets (tokens, SSH agent, private registries) go in
`~/.zshrc.local`, which is sourced at the end of `.zshrc` and is
git-ignored.
