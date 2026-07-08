# offline-devkit

Build a **self-contained, offline-installable** development toolkit for
**airgapped Ubuntu 24+** — a machine with **no internet and no editor** (not
even vim). The bundle reproduces this repo's Neovim (NvChad) + LSP/DAP +
terminal-utility environment with a single offline `install.sh`.

## Idea

The online `make install` path assumes the internet everywhere (apt, GitHub
releases, rustup, npm, Mason registries, lazy.nvim git clones). That can't run
on an airgapped host. Instead:

1. On an **online build machine with Docker**, spin up a container matching the
   target (`ubuntu:24.04`, per arch).
2. Inside, download **everything** and **prewarm Neovim headless** (install
   lazy plugins, Mason LSP/DAP tools, treesitter parsers, CLI tools).
3. **Snapshot** the resulting `~/.local` tree + the `.deb` closure + configs
   into a `.tar.gz`.
4. On the target, `install.sh` only unpacks: `dpkg -i` the debs, drop the
   prewarmed home tree, deploy configs, set zsh. **No network. No compiler.**

```
build machine (Docker, online)             airgapped target (Ubuntu 24+, offline)
  ./build.sh
    └─ ubuntu:24.04 container (per arch)      tar -xzf bundle.tar.gz
         ├─ harvest .deb closure              ./install.sh
         ├─ stage nvim/starship/... binaries    ├─ dpkg -i apt/*.deb
         ├─ prewarm nvim (Lazy + Mason + TS)    ├─ deploy ~/.local (prewarmed)
         └─ snapshot ► dist/*.tar.gz ─────────► ├─ rewrite build HOME -> $HOME
                                                └─ deploy configs, set zsh
                                              exec zsh ; nvim   (works instantly)
```

## Build

Requires a running Docker daemon.

```bash
# both arches, standard scope (default)
./offline-devkit/build.sh

# x86_64 only, full scope (adds Go + Rust toolchains)
./offline-devkit/build.sh --arch amd64 --scope full
```

Output: `offline-devkit/dist/devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz`.

Cross-arch builds (amd64 on Apple Silicon, arm64 on x86_64) run under **QEMU
emulation** — slow, and the artifacts are large (hundreds of MB). Docker Desktop
ships the binfmt handlers; on plain Linux register them once:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

### Scope

| Scope | Contents |
|---|---|
| `standard` (default) | NvChad + core LSP (lua/py/ts·js/html·css/markdown) + formatters/linters (stylua, prettier, eslint_d, ruff) + DAP (debugpy, js-debug-adapter, codelldb) + Node runtime + terminal utils (fzf, fd, bat, ripgrep, btop, lazygit, tmux, starship, zoxide, direnv, zsh plugins). No Go/Rust compilers. |
| `full` | `standard` + Go + rustup, which flips the `condition = executable "go"` guards in `nvim/lua/plugins/init.lua` on (gopls, delve, golangci-lint, goimports, gofumpt) and adds the Rust toolchain (rustfmt, clippy). |

## Install (on the airgapped target)

```bash
tar -xzf devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz
cd devkit-ubuntu24-<arch>-<scope>-<date>
./install.sh
exec zsh
nvim
```

`install.sh` flags:

| Flag | Effect |
|---|---|
| `--with-gitconfig` | also deploy `git/.gitconfig` (contains user identity) |
| `--no-shell` | skip changing the default shell to zsh |
| `--force` | bypass the OS/arch preflight checks |

## Verify (no internet needed)

On the target after install:

```bash
nvim --headless "+checkhealth" "+qa"
```

Or interactively in `nvim`:

- `:Lazy` — all plugins **installed**, none pending download.
- `:Mason` — LSP/DAP/formatters/linters show **installed**.
- `:checkhealth` — no failures that require network.
- Open a `.py`/`.ts`/`.lua` file → LSP attaches; `<F5>` starts a DAP session.
- `telescope` live-grep works (ripgrep present); `lazygit`, `starship`,
  `zoxide` all resolve from `~/.local/bin`.

## Layout

```
offline-devkit/
├── README.md                   # this file
├── manifest.sh                 # version pins + package/tool lists + BUILD_HOME
├── build.sh                    # host entrypoint: orchestrates the docker build
├── docker/
│   ├── Dockerfile              # thin ubuntu:24.04 builder
│   └── build-in-container.sh   # harvest debs → prewarm nvim → snapshot
├── install/
│   └── install.sh              # offline target installer (shipped in each bundle)
└── dist/                       # build output (gitignored)
```

## How the tricky parts work

- **apt `.deb` closure** is harvested with `apt-get install --download-only` on a
  clean `ubuntu:24.04` base *before* installing anything, so it captures every
  not-yet-present dependency. A real Ubuntu server is a superset of this base,
  so the closure is safe. If a target is unusually minimal and a dep is missing,
  rebuild `--no-cache`.
- **Prewarm-then-snapshot** means the target needs no compiler: treesitter
  parsers and `telescope-fzf-native`'s `.so` are built in the container and
  shipped as binaries.
- **Build HOME rewrite**: the container prewarms under `/root`, but Mason bakes
  absolute paths into Python venv shebangs (e.g. debugpy). `install.sh` rewrites
  the recorded `BUILD_HOME` to the target user's `$HOME` across
  `~/.local/share/nvim` (text files only; `grep -I` skips binaries). lazy,
  treesitter, and the nvim binary use runtime-relative paths and need no rewrite.

## Extending to other OSes

Ubuntu 24.04 is the first target. To add another OS later:

- `./build.sh --base <image>` swaps the builder/target base.
- Add an OS-specific package list (and a Dockerfile variant if the download
  tooling differs); the prewarm → snapshot → install flow stays the same.

Keep `NVIM_VERSION` in `manifest.sh` in lockstep with the `Makefile` pin so the
offline path matches the online one.
