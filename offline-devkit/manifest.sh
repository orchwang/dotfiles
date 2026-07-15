#!/usr/bin/env bash
# shellcheck disable=SC2034  # sourced config: vars are consumed by build.sh / build-in-container.sh
# offline-devkit/manifest.sh
#
# Single source of truth for the offline dev-kit bundle: version pins, the
# package/tool lists, and shared constants. Sourced by both the host
# orchestrator (build.sh) and the in-container builder (build-in-container.sh),
# so keep it POSIX-friendly and side-effect free (definitions only).
#
# Bump a version here and rebuild to roll the bundle forward.

# ---------------------------------------------------------------------------
# Target OS
# ---------------------------------------------------------------------------
# First supported target. Other OSes plug in later via build.sh --base plus an
# OS-specific package list (see README "확장").
DEVKIT_OS="ubuntu"
DEVKIT_BASE_DEFAULT="ubuntu:24.04"
# Minimum Ubuntu major version the install.sh will accept on the target.
UBUNTU_MIN_MAJOR="24"

# Default build scope. "standard" = NvChad + core LSP/DAP + formatters/linters
# + terminal utils (no Go/Rust compiler toolchains). "full" additionally
# installs Go + rustup in the build container, which flips the
# `condition = executable "go"` guards in nvim/lua/plugins/init.lua on and pulls
# in gopls/delve/golangci-lint/goimports/gofumpt (+ rust toolchain).
DEVKIT_SCOPE_DEFAULT="standard"

# ---------------------------------------------------------------------------
# Version pins
# ---------------------------------------------------------------------------
# Neovim is pinned exactly (must match Makefile's NVIM_VERSION for parity with
# the online install path). nvim-treesitter master was archived; 0.12+ breaks
# the set-lang-from-info-string! injection directive, so stay on 0.11.x.
NVIM_VERSION="${NVIM_VERSION:-v0.11.6}"

# The ~/.local/bin tools are fetched from GitHub releases in the build
# container. "latest" resolves at build time (container has internet); pin an
# exact tag (e.g. STARSHIP_VERSION=v1.21.1) for a reproducible bundle.
STARSHIP_VERSION="${STARSHIP_VERSION:-latest}"
ZOXIDE_VERSION="${ZOXIDE_VERSION:-latest}"
LAZYGIT_VERSION="${LAZYGIT_VERSION:-latest}"
UV_VERSION="${UV_VERSION:-latest}"
RUFF_VERSION="${RUFF_VERSION:-latest}"
# mermaid-ascii: Mermaid → ASCII 렌더 백엔드(정적 Go 바이너리). nvim <leader>mm에서 사용.
# 두 스코프 모두 프리빌트 릴리스 바이너리를 ~/.local/bin에 번들한다(Go 툴체인 불필요).
MERMAID_ASCII_VERSION="${MERMAID_ASCII_VERSION:-latest}"

# "full" scope only.
GO_VERSION="${GO_VERSION:-latest}"   # resolved from go.dev/VERSION when "latest"

# ---------------------------------------------------------------------------
# apt packages installed on the TARGET (shipped as .deb closure)
# ---------------------------------------------------------------------------
# The base list is packages/apt-packages.txt (reused verbatim, minus comments)
# so the offline path stays in lockstep with the online apt path. These extras
# are appended because the online path gets them elsewhere (or not at all):
#   ripgrep       - telescope live_grep/vimgrep needs `rg` (not in apt-packages.txt)
#   xz-utils      - extract .tar.xz release tarballs
#   ca-certificates - TLS roots for the build-time downloads
#   python3-pip   - Mason bootstraps debugpy's venv with pip
EXTRA_APT_PKGS="ripgrep xz-utils ca-certificates python3-pip"

# ---------------------------------------------------------------------------
# Config directories shipped into the bundle (copied, then deployed by
# install.sh). Paths are relative to the repo root.
# ---------------------------------------------------------------------------
DEVKIT_CONFIG_DIRS="nvim zsh starship tmux git dircolors ghostty"

# The build container prewarms Neovim under this HOME. install.sh rewrites this
# exact string to the target user's $HOME across ~/.local/share/nvim so Mason's
# absolute venv shebangs (debugpy etc.) keep working. Must match the container's
# actual HOME (root's home).
BUILD_HOME="/root"
