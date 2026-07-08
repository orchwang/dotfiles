---
name: offline-devkit
description: Build a self-contained, offline-installable development toolkit bundle for airgapped machines. Use when the user asks to "build an offline devkit", "make an airgapped nvchad bundle", "오프라인 개발환경 번들 만들기", "airgapped ubuntu nvim 설치 세트", "offline install package", or to package NvChad + LSP/DAP + terminal utilities for a no-internet target.
argument-hint: "[--arch amd64,arm64] [--scope standard|full] [--base ubuntu:24.04]"
allowed-tools: Read, Bash(./offline-devkit/build.sh *), Bash(offline-devkit/build.sh *), Bash(docker *), Bash(uname *), Bash(ls *), Bash(cat *), Bash(du *), Bash(find offline-devkit/dist *)
---

# Offline Dev-Kit Builder

Build a **self-contained bundle** that reproduces this repo's Neovim (NvChad) +
LSP/DAP + terminal-utility environment on an **airgapped Ubuntu 24+** machine —
one with **no internet and no pre-installed editor**.

The tooling lives at **`$DEVKIT_DIR/offline-devkit/`** (the repo root's
`offline-devkit/` directory). This skill drives it.

## How it works

An online build machine with Docker runs a container matching the *target*
(`ubuntu:24.04`, per arch). Inside, it downloads everything (apt `.deb` closure,
Neovim, Mason LSP/DAP tools, lazy.nvim plugins, treesitter parsers, CLI tools)
and **prewarms Neovim headless**, then snapshots the result into a `.tar.gz`.
On the target, `install.sh` only unpacks — `dpkg -i` the debs, drop the
prewarmed `~/.local` tree, deploy configs, set the shell. Fully offline.

```
build machine (Docker)                  airgapped target (Ubuntu 24+)
  build.sh ──► ubuntu:24.04 container      tar -xzf bundle.tar.gz
             harvest debs + prewarm nvim   ./install.sh   (dpkg + deploy, no net)
             snapshot ► *.tar.gz  ───────► exec zsh ; nvim   (works instantly)
```

## Bundle scope

- **standard** (default): NvChad + core LSP (lua/py/ts·js/html·css/markdown) +
  formatters/linters (stylua, prettier, eslint_d, ruff) + DAP (debugpy,
  js-debug-adapter, codelldb) + Node runtime + terminal utils (fzf, fd, bat,
  ripgrep, btop, lazygit, tmux, starship, zoxide, direnv, zsh plugins).
  No Go/Rust compiler toolchains — the `condition = executable "go"` guards in
  `nvim/lua/plugins/init.lua` auto-skip gopls/delve/golangci-lint/goimports/
  gofumpt; rust-analyzer installs (standalone) but rustfmt formatting is absent.
- **full**: additionally installs Go + rustup in the build container, flipping
  those guards on and bundling the Go/Rust toolchains and their tools.

## Prerequisites

- **Docker daemon running** on the build machine (`docker info` must succeed).
- Cross-arch builds use QEMU emulation (amd64 on Apple Silicon, or arm64 on
  x86_64). Docker Desktop ships the binfmt handlers; on plain Linux register
  them once: `docker run --privileged --rm tonistiigi/binfmt --install all`.
- Emulated builds are **slow** (nvim headless + Mason under QEMU) and produce
  **large** artifacts (hundreds of MB). Warn the user before kicking one off.

## Workflow

1. **Confirm Docker** is running: `docker info` (non-destructive; run freely).
   If not, tell the user to start Docker and stop.
2. **Confirm arch + scope** if not given in `$ARGUMENTS`. Defaults: both arches
   (`amd64,arm64`), `standard` scope. Building both arches doubles time/size.
3. **Confirm before building** — this is long-running and writes large files.
   Show the exact command, then run:
   ```bash
   ./offline-devkit/build.sh --arch <arches> --scope <scope>
   ```
4. **Report** the produced bundle path(s) under `offline-devkit/dist/` and their
   sizes (`ls -lh offline-devkit/dist/`).
5. **Explain deployment** on the target (see below). Do NOT attempt to run the
   target install here — it belongs on the airgapped machine.

## Handling arguments

Pass `$ARGUMENTS` straight through to `build.sh`. Common forms:

| Argument | Meaning |
|---|---|
| `--arch amd64` | x86_64 only |
| `--arch arm64` | arm64 only |
| `--scope full` | include Go + Rust toolchains |
| `--no-cache` | rebuild the builder image from scratch |
| `--base ubuntu:24.04` | override the builder/target base image |

## Deploying on the airgapped target

Transfer the `.tar.gz` (USB, internal mirror, etc.), then on the target:

```bash
tar -xzf devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz
cd devkit-ubuntu24-<arch>-<scope>-<date>
./install.sh              # offline: dpkg + deploy + set zsh
exec zsh
nvim                      # opens instantly; :Lazy / :Mason / :checkhealth all OK offline
```

`install.sh` flags: `--with-gitconfig` (deploy `.gitconfig` identity too),
`--no-shell` (skip the default-shell change), `--force` (bypass OS/arch checks).

## Extending to other OSes later

Ubuntu is the first target; the design is pluggable:
- `build.sh --base <image>` swaps the builder/target base.
- Add an OS-specific package list and, if needed, a Dockerfile variant; keep the
  prewarm/snapshot/install flow identical.
Keep `NVIM_VERSION` in `offline-devkit/manifest.sh` in sync with the Makefile's
pin so the offline path matches the online one.

## Important notes

- The bundle is **arch-specific and Ubuntu-24+-specific**. `install.sh` refuses
  a mismatched target unless `--force`.
- The build container prewarms under `/root`; `install.sh` rewrites that path to
  the target user's `$HOME` so Mason's Python venv shebangs keep working. This is
  automatic — don't bypass it.
- The apt `.deb` closure is computed against a clean `ubuntu:24.04` base, which a
  real Ubuntu server is a superset of, so the closure is safe. If a target is
  unusually minimal and a dependency is missing, rebuild `--no-cache`.
