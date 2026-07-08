#!/usr/bin/env bash
# offline-devkit/docker/build-in-container.sh
#
# Runs INSIDE the ubuntu:24.04 build container (matching the target arch). It:
#   1. harvests the target's .deb closure   (must happen before installing)
#   2. installs those packages for the prewarm
#   3. stages ~/.local/bin tools from GitHub releases (nvim, starship, ...)
#   4. prewarms Neovim headless (lazy plugins + Mason tools + treesitter)
#   5. snapshots ~/.local and the configs into /out
#
# Everything network-dependent happens here, where the container has internet.
# The resulting /out tree is fully offline-installable on the target.
#
# Env (set by build.sh via `docker run -e`):
#   ARCH   = amd64 | arm64   (the target arch; container runs on this platform)
#   SCOPE  = standard | full
# Mounts: /repo (repo, read-only), /out (bundle staging, writable). HOME=/root.

set -euo pipefail

REPO="/repo"
OUT="/out"
ARCH="${ARCH:?ARCH must be set (amd64|arm64)}"
SCOPE="${SCOPE:-standard}"

# shellcheck source=/dev/null
source "$REPO/offline-devkit/manifest.sh"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$HOME" = "$BUILD_HOME" ] || die "container HOME ($HOME) != manifest BUILD_HOME ($BUILD_HOME)"

# --- arch name maps -------------------------------------------------------
case "$ARCH" in
  amd64) RUST_ARCH="x86_64"; NVIM_ARCH="x86_64"; LG_ARCH="x86_64"; GO_ARCH="amd64" ;;
  arm64) RUST_ARCH="aarch64"; NVIM_ARCH="arm64"; LG_ARCH="arm64"; GO_ARCH="arm64" ;;
  *) die "unsupported ARCH: $ARCH (expected amd64|arm64)" ;;
esac

# --- helpers --------------------------------------------------------------
dl() { # dl URL OUTFILE
  local url="$1" out="$2" n=1
  until curl -fSL --retry 3 --retry-delay 2 -o "$out" "$url"; do
    [ "$n" -ge 3 ] && die "download failed: $url"
    n=$((n + 1)); echo "  retry $n/3: $url"; sleep 2
  done
}

gh_latest_tag() { # gh_latest_tag owner/repo  ->  vX.Y.Z
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -Po '"tag_name":\s*"\K[^"]+' | head -1
}

# install_bins_from_tar URL bin1 [bin2 ...] : download a .tar.gz, find each named
# binary anywhere inside, and install it into ~/.local/bin.
install_bins_from_tar() {
  local url="$1"; shift
  local tmp; tmp="$(mktemp -d)"
  dl "$url" "$tmp/pkg.tar.gz"
  tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"
  local bin path
  for bin in "$@"; do
    path="$(find "$tmp" -type f -name "$bin" | head -1)"
    [ -n "$path" ] || die "binary '$bin' not found in $url"
    install -Dm755 "$path" "$HOME/.local/bin/$bin"
    echo "  installed $bin -> ~/.local/bin/$bin"
  done
  rm -rf "$tmp"
}

# gh_release_path VERSION -> "latest/download" or "download/<tag>"
gh_release_path() {
  if [ "$1" = "latest" ]; then echo "latest/download"; else echo "download/$1"; fi
}

mkdir -p "$OUT/apt" "$OUT/home" "$OUT/config" "$HOME/.local/bin" "$HOME/.config"

# ===========================================================================
# 1. Harvest the target .deb closure  (BEFORE installing anything extra)
# ===========================================================================
log "Resolving target apt package list"
APT_PKGS="$(grep -v '^#' "$REPO/packages/apt-packages.txt" | grep -v '^[[:space:]]*$' | tr '\n' ' ')"
APT_PKGS="$APT_PKGS $EXTRA_APT_PKGS"
echo "  packages: $APT_PKGS"

log "apt-get update"
apt-get update

log "Harvesting .deb closure into /out/apt (download-only)"
# On a clean base image, --download-only fetches the packages plus every
# not-yet-installed dependency. A real Ubuntu server is a superset of this
# base, so the closure is safe (see README).
# shellcheck disable=SC2086  # intentional word-splitting of the package list
apt-get install -y --download-only $APT_PKGS
cp -n /var/cache/apt/archives/*.deb "$OUT/apt/" 2>/dev/null || true
echo "  harvested $(find "$OUT/apt" -name '*.deb' | wc -l) .deb files"

# ===========================================================================
# 2. Install the target packages (needed to prewarm: node, python, lua, ...)
# ===========================================================================
log "Installing target packages for prewarm"
# shellcheck disable=SC2086  # intentional word-splitting of the package list
apt-get install -y $APT_PKGS

# ===========================================================================
# 3. Stage ~/.local/bin tools + Neovim from GitHub releases
# ===========================================================================
log "Installing Neovim $NVIM_VERSION ($NVIM_ARCH)"
NVIM_TARBALL="nvim-linux-${NVIM_ARCH}.tar.gz"
NVIM_DIR="nvim-linux-${NVIM_ARCH}"
dl "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${NVIM_TARBALL}" /tmp/nvim.tar.gz
tar -xzf /tmp/nvim.tar.gz -C /tmp
# Merge CONTENTS into ~/.local (the trailing /. matters: ~/.local/bin already
# exists, so `cp -R src/bin ~/.local/` would nest to ~/.local/bin/bin).
mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/lib"
cp -R "/tmp/${NVIM_DIR}/bin/."   "$HOME/.local/bin/"
[ -d "/tmp/${NVIM_DIR}/lib" ] && cp -R "/tmp/${NVIM_DIR}/lib/." "$HOME/.local/lib/" || true
cp -R "/tmp/${NVIM_DIR}/share/." "$HOME/.local/share/"
rm -rf "/tmp/${NVIM_DIR}" /tmp/nvim.tar.gz
"$HOME/.local/bin/nvim" --version | head -1

log "Installing starship"
# starship ships musl for BOTH arches (aarch64 has no -gnu asset); musl is a
# portable static build that also runs on glibc systems.
install_bins_from_tar \
  "https://github.com/starship/starship/releases/$(gh_release_path "$STARSHIP_VERSION")/starship-${RUST_ARCH}-unknown-linux-musl.tar.gz" \
  starship

log "Installing zoxide"
ZOXIDE_TAG="$ZOXIDE_VERSION"; [ "$ZOXIDE_TAG" = "latest" ] && ZOXIDE_TAG="$(gh_latest_tag ajeetdsouza/zoxide)"
install_bins_from_tar \
  "https://github.com/ajeetdsouza/zoxide/releases/download/${ZOXIDE_TAG}/zoxide-${ZOXIDE_TAG#v}-${RUST_ARCH}-unknown-linux-musl.tar.gz" \
  zoxide

log "Installing lazygit"
LAZYGIT_TAG="$LAZYGIT_VERSION"; [ "$LAZYGIT_TAG" = "latest" ] && LAZYGIT_TAG="$(gh_latest_tag jesseduffield/lazygit)"
install_bins_from_tar \
  "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_TAG}/lazygit_${LAZYGIT_TAG#v}_Linux_${LG_ARCH}.tar.gz" \
  lazygit

log "Installing uv + ruff"
install_bins_from_tar \
  "https://github.com/astral-sh/uv/releases/$(gh_release_path "$UV_VERSION")/uv-${RUST_ARCH}-unknown-linux-gnu.tar.gz" \
  uv uvx
install_bins_from_tar \
  "https://github.com/astral-sh/ruff/releases/$(gh_release_path "$RUFF_VERSION")/ruff-${RUST_ARCH}-unknown-linux-gnu.tar.gz" \
  ruff

export PATH="$HOME/.local/bin:$PATH"

# --- "full" scope: Go + Rust toolchains (flips the executable-"go" guards) ---
if [ "$SCOPE" = "full" ]; then
  log "SCOPE=full: installing Go + Rust toolchains"
  GO_TAG="$GO_VERSION"; [ "$GO_TAG" = "latest" ] && GO_TAG="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"
  dl "https://go.dev/dl/${GO_TAG}.linux-${GO_ARCH}.tar.gz" /tmp/go.tar.gz
  rm -rf "$HOME/.local/go"; tar -C "$HOME/.local" -xzf /tmp/go.tar.gz; rm -f /tmp/go.tar.gz
  export PATH="$HOME/.local/go/bin:$HOME/go/bin:$PATH"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
  rustup component add rustfmt clippy
fi

# ===========================================================================
# 4. Prewarm Neovim headless (mirrors the proven `make set-nvim-tools` path)
# ===========================================================================
log "Prewarming Neovim: config, plugins, Mason tools, treesitter"
rm -rf "$HOME/.config/nvim"
cp -R "$REPO/nvim" "$HOME/.config/nvim"   # writable working copy (Lazy writes lock)

NVIM="$HOME/.local/bin/nvim"
echo "  :Lazy sync (plugins + build hooks incl. treesitter :TSUpdate)"
"$NVIM" --headless "+Lazy! sync" "+qa"
echo "  :MasonToolsInstallSync (LSP/DAP/formatters/linters)"
"$NVIM" --headless "+MasonToolsInstallSync" "+qa"
echo "  :TSUpdateSync (best-effort parser top-up)"
"$NVIM" --headless "+silent! TSUpdateSync" "+qa" || true

# ===========================================================================
# 5. Snapshot into /out
# ===========================================================================
log "Snapshotting ~/.local -> /out/home/.local"
mkdir -p "$OUT/home/.local"
# nvim binary + libs + share/nvim (lazy plugins, mason, treesitter parsers, base46)
cp -R "$HOME/.local/bin"   "$OUT/home/.local/"
[ -d "$HOME/.local/lib" ] && cp -R "$HOME/.local/lib" "$OUT/home/.local/" || true
cp -R "$HOME/.local/share" "$OUT/home/.local/"
[ "$SCOPE" = "full" ] && { cp -R "$HOME/.local/go" "$OUT/home/.local/" 2>/dev/null || true; }
# Full scope: Go-installed binaries live in ~/go/bin; Rust in ~/.cargo, ~/.rustup
if [ "$SCOPE" = "full" ]; then
  mkdir -p "$OUT/home/go"; [ -d "$HOME/go/bin" ] && cp -R "$HOME/go/bin" "$OUT/home/go/" || true
  [ -d "$HOME/.cargo" ]  && cp -R "$HOME/.cargo"  "$OUT/home/" || true
  [ -d "$HOME/.rustup" ] && cp -R "$HOME/.rustup" "$OUT/home/" || true
fi

log "Copying pristine configs -> /out/config"
for d in $DEVKIT_CONFIG_DIRS; do
  [ -e "$REPO/$d" ] && cp -R "$REPO/$d" "$OUT/config/" || echo "  (skip missing $d)"
done

log "Writing /out/manifest.env"
cat > "$OUT/manifest.env" <<EOF
DEVKIT_OS=$DEVKIT_OS
ARCH=$ARCH
SCOPE=$SCOPE
NVIM_VERSION=$NVIM_VERSION
BUILD_HOME=$BUILD_HOME
UBUNTU_MIN_MAJOR=$UBUNTU_MIN_MAJOR
EOF

# Ownership: files created as root inside the container. Best-effort make them
# world-readable so a non-root host user can tar them without sudo.
chmod -R a+rX "$OUT" 2>/dev/null || true

log "In-container build complete for $ARCH/$SCOPE"
