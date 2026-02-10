---
name: apply-dotfiles
description: Apply dotfiles to the current machine. Use when the user asks to "apply dotfiles", "install dotfiles", "set up dotfiles", "bootstrap environment", "link configs", "set up my machine", or "configure this system".
argument-hint: "[target: install | link | packages | plugins | unlink | clean | rust | others]"
allowed-tools: Read, Bash(make *), Bash(uname *), Bash(brew *), Bash(apt *), Bash(which *), Bash(command -v *), Bash(ls *), Bash(cat /etc/*release*)
---

# Apply Dotfiles

You are helping apply this dotfiles repository to the current machine.
The dotfiles repo is located at: **$DOTFILES_DIR** (the directory containing this `.claude/` folder).

## Platform Detection

First, detect the platform:

```bash
uname -s
```

- **Darwin** = macOS
- **Linux** = Ubuntu/Debian

## Available Make Targets

| Target | macOS | Linux | Description |
|---|---|---|---|
| `make install` | yes | yes | Full setup (packages + symlinks + default shell) |
| `make link` | yes | yes | Create all symlinks only |
| `make set-packages` | yes | -- | Install Homebrew packages from Brewfile |
| `make set-apt-packages` | -- | yes | Install apt packages from apt-packages.txt |
| `make check-plugins` | yes | yes | Verify all plugins/tools are installed |
| `make install-rust` | yes | yes | Install Rust toolchain |
| `make install-others` | yes | -- | Install extra Homebrew packages (BrewFile.others) |
| `make clean` | yes | -- | Remove unlisted Homebrew packages |
| `make unlink` | yes | yes | Remove all symlinks |
| `make set-default-shell` | yes | yes | Set zsh as the default shell |

## Symlinks Created by `make link`

| Source | Target |
|---|---|
| `zsh/.zshrc` | `~/.zshrc` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `dircolors/.dircolors` | `~/.dircolors` |
| `git/.gitconfig` | `~/.gitconfig` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `nvim/` | `~/.config/nvim` |

## Workflow

When the user asks to apply dotfiles, follow this process:

1. **Detect platform** (`uname -s`)
2. **Ask what to apply** if no specific `$ARGUMENTS` target was given:
   - Full install (`make install`) - installs packages + creates symlinks + sets default shell
   - Symlinks only (`make link`) - just create config symlinks
   - Packages only (`make set-packages` or `make set-apt-packages`)
   - Check status (`make check-plugins`) - verify everything is installed
3. **Confirm before running** - Always show the user what `make` target will be executed and get confirmation before running destructive or system-modifying commands (e.g., `make install`, `make set-packages`, `make set-default-shell`). Non-destructive targets like `make check-plugins` can run without confirmation.
4. **Run the target** from the dotfiles repo directory
5. **Verify** by running `make check-plugins` after installation
6. **Report results** - summarize what was installed/linked and any errors

## Handling Arguments

If `$ARGUMENTS` is provided, map it to the correct target:

| Argument | Target |
|---|---|
| `install` | `make install` |
| `link` | `make link` |
| `packages` | `make set-packages` (macOS) or `make set-apt-packages` (Linux) |
| `plugins` or `check` | `make check-plugins` |
| `unlink` | `make unlink` |
| `clean` | `make clean` |
| `rust` | `make install-rust` |
| `others` | `make install-others` |

## Important Notes

- On macOS, `make install` runs: xcode-select, brew install, brew bundle, symlinks, default shell
- On Linux, `make install` runs: apt packages, starship install, zoxide install, symlinks, default shell
- The `iterm/` profile must be imported manually in iTerm2 preferences
- Machine-specific secrets belong in `~/.zshrc.local` (git-ignored, sourced by `.zshrc`)
- If `make check-plugins` reports missing tools, suggest running `make install` or the specific target
