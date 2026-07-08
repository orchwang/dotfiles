#!/usr/bin/env bash
# install.sh — offline installer for the dev-kit bundle.
#
# Runs on the AIRGAPPED Ubuntu 24+ target. No internet, no pre-existing vim.
# It only unpacks what the build container already produced:
#   1. installs the shipped .deb closure (dpkg, offline)
#   2. deploys the prewarmed ~/.local tree (nvim + plugins + Mason tools)
#   3. rewrites the build-time HOME to this user's $HOME (Mason venv shebangs)
#   4. deploys the configs (real copies, since the repo isn't on the target)
#   5. sets zsh as the default shell
#
# Usage (from inside the extracted bundle dir):
#   ./install.sh [--with-gitconfig] [--force] [--no-shell]

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_GITCONFIG=""
FORCE=""
SET_SHELL="yes"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --with-gitconfig) WITH_GITCONFIG="yes"; shift ;;
    --force)          FORCE="yes"; shift ;;
    --no-shell)       SET_SHELL=""; shift ;;
    -h|--help) grep '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -f "$SRC/manifest.env" ] || die "manifest.env not found — run this from inside the extracted bundle"
# shellcheck source=/dev/null
source "$SRC/manifest.env"
: "${ARCH:?}" "${BUILD_HOME:?}" "${UBUNTU_MIN_MAJOR:?}"

# --- preflight ------------------------------------------------------------
log "Preflight checks"

if [ -r /etc/os-release ]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  major="${VERSION_ID%%.*}"
  if [ "${ID:-}" = "ubuntu" ]; then
    [ "${major:-0}" -ge "$UBUNTU_MIN_MAJOR" ] 2>/dev/null \
      || die "Ubuntu $UBUNTU_MIN_MAJOR+ required (found ${VERSION_ID:-unknown}). Override: --force"
  elif [ -z "$FORCE" ]; then
    die "target is '${ID:-unknown}', not Ubuntu. Override: --force"
  fi
  echo "  OS: ${PRETTY_NAME:-unknown}"
else
  [ -n "$FORCE" ] || die "/etc/os-release missing; cannot verify OS. Override: --force"
fi

machine="$(uname -m)"
case "$ARCH:$machine" in
  amd64:x86_64|arm64:aarch64|arm64:arm64) : ;;
  *) [ -n "$FORCE" ] || die "arch mismatch: bundle is '$ARCH' but machine is '$machine'. Override: --force" ;;
esac
echo "  arch: bundle=$ARCH machine=$machine"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  command -v sudo >/dev/null 2>&1 || die "sudo not found and not running as root — cannot install .deb packages"
  SUDO="sudo"
fi
echo "  install HOME: $HOME  (build HOME was $BUILD_HOME)"

# ===========================================================================
# 1. Install the .deb closure (offline)
# ===========================================================================
if compgen -G "$SRC/apt/*.deb" >/dev/null; then
  log "Installing $(find "$SRC/apt" -name '*.deb' | wc -l) .deb packages (offline)"
  $SUDO dpkg -i "$SRC"/apt/*.deb 2>&1 | tail -20 || true
  $SUDO dpkg --configure -a || true
  # Resolve any leftover deps from the shipped set only (never the network).
  $SUDO apt-get -f install -y --no-download 2>/dev/null || true
else
  warn "no apt/*.deb in bundle — skipping package install"
fi

# ===========================================================================
# 2. Deploy the prewarmed home tree
# ===========================================================================
log "Deploying ~/.local (nvim + plugins + Mason tools)"
mkdir -p "$HOME/.local"
cp -R "$SRC/home/.local/." "$HOME/.local/"
# "full" scope extras (present only in full bundles)
for extra in go .cargo .rustup; do
  [ -d "$SRC/home/$extra" ] && { mkdir -p "$HOME/$extra"; cp -R "$SRC/home/$extra/." "$HOME/$extra/"; }
done

# Ensure `node` is on PATH: Mason's node-based tools use `#!/usr/bin/env node`.
# Ubuntu's nodejs package usually installs /usr/bin/node, but if only
# /usr/bin/nodejs exists, link it into ~/.local/bin (which .zshrc adds to PATH).
if ! command -v node >/dev/null 2>&1 && command -v nodejs >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"; ln -sf "$(command -v nodejs)" "$HOME/.local/bin/node"
  echo "  linked node -> $(command -v nodejs)"
fi

# ===========================================================================
# 3. Rewrite build HOME -> target HOME (fixes Mason venv absolute shebangs)
# ===========================================================================
if [ "$BUILD_HOME" != "$HOME" ]; then
  log "Rewriting build paths ($BUILD_HOME -> $HOME)"
  rewrite_dirs="$HOME/.local/share/nvim $HOME/.local/bin"
  [ -d "$HOME/.cargo" ]  && rewrite_dirs="$rewrite_dirs $HOME/.cargo"
  [ -d "$HOME/.rustup" ] && rewrite_dirs="$rewrite_dirs $HOME/.rustup"
  # -I skips binary files; only text (venv shebangs, scripts) is rewritten.
  # shellcheck disable=SC2086
  grep -rIlZ "$BUILD_HOME" $rewrite_dirs 2>/dev/null \
    | xargs -0 -r sed -i "s|$BUILD_HOME|$HOME|g" || true
fi

# ===========================================================================
# 4. Deploy configs (real copies — the repo is not present on the target)
# ===========================================================================
log "Deploying configs"
mkdir -p "$HOME/.config" "$HOME/.local/bin"

backup() { # backup PATH — move a real (non-symlink) file aside once.
  # Must always return 0: under `set -e`, an `&&` chain that ends false (e.g. the
  # target doesn't exist — the common fresh-target case) would abort install.sh.
  if [ -e "$1" ] && [ ! -L "$1" ]; then
    mv "$1" "$1.pre-devkit"; echo "  backed up $1 -> $1.pre-devkit"
  fi
}

# nvim config
backup "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim"
cp -R "$SRC/config/nvim" "$HOME/.config/nvim"
echo "  ~/.config/nvim"

# zsh
backup "$HOME/.zshrc"
cp "$SRC/config/zsh/.zshrc" "$HOME/.zshrc"; echo "  ~/.zshrc"

# starship / dircolors / tmux / ghostty
[ -f "$SRC/config/starship/starship.toml" ] && cp "$SRC/config/starship/starship.toml" "$HOME/.config/starship.toml" && echo "  ~/.config/starship.toml"
[ -f "$SRC/config/dircolors/.dircolors" ]   && cp "$SRC/config/dircolors/.dircolors" "$HOME/.dircolors" && echo "  ~/.dircolors"
[ -f "$SRC/config/tmux/.tmux.conf" ]        && cp "$SRC/config/tmux/.tmux.conf" "$HOME/.tmux.conf" && echo "  ~/.tmux.conf"
if [ -d "$SRC/config/tmux/scripts" ]; then
  cp "$SRC/config/tmux/scripts/tmux-layout.sh"          "$HOME/.local/bin/tmux-layout"          2>/dev/null && chmod +x "$HOME/.local/bin/tmux-layout" || true
  cp "$SRC/config/tmux/scripts/tmux-rebalance-column.sh" "$HOME/.local/bin/tmux-rebalance-column" 2>/dev/null && chmod +x "$HOME/.local/bin/tmux-rebalance-column" || true
  cp "$SRC/config/tmux/scripts/tmux-set-column-widths.sh" "$HOME/.local/bin/tmux-set-column-widths" 2>/dev/null && chmod +x "$HOME/.local/bin/tmux-set-column-widths" || true
  echo "  ~/.local/bin/tmux-* scripts"
fi
if [ -f "$SRC/config/ghostty/config" ]; then
  mkdir -p "$HOME/.config/ghostty"; cp "$SRC/config/ghostty/config" "$HOME/.config/ghostty/config"; echo "  ~/.config/ghostty/config"
fi

# gitconfig only on request (contains user identity)
if [ -n "$WITH_GITCONFIG" ] && [ -f "$SRC/config/git/.gitconfig" ]; then
  backup "$HOME/.gitconfig"; cp "$SRC/config/git/.gitconfig" "$HOME/.gitconfig"; echo "  ~/.gitconfig"
fi

# ===========================================================================
# 5. Set zsh as the default shell (ported from Makefile set-default-shell)
# ===========================================================================
if [ -n "$SET_SHELL" ]; then
  log "Setting zsh as default shell"
  ZSH_PATH="$(command -v zsh || true)"
  if [ -z "$ZSH_PATH" ]; then
    warn "zsh not found — package install may have failed; skipping shell change"
  else
    USER_NAME="${USER:-$(id -un)}"
    CURRENT_SHELL="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f7 || true)"; : "${CURRENT_SHELL:=$SHELL}"
    case "$CURRENT_SHELL" in
      */zsh) echo "  already zsh ($CURRENT_SHELL)" ;;
      *)
        grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null || echo "$ZSH_PATH" | $SUDO tee -a /etc/shells >/dev/null
        if $SUDO chsh -s "$ZSH_PATH" "$USER_NAME" 2>/dev/null || chsh -s "$ZSH_PATH" 2>/dev/null; then
          echo "  default shell -> zsh (effective next login)"
        else
          warn "could not change shell automatically. Run: chsh -s $ZSH_PATH"
        fi ;;
    esac
  fi
fi

# ===========================================================================
# Done
# ===========================================================================
log "Install complete."
cat <<EOF

  Next:
    exec zsh          # switch this shell to zsh now
    nvim              # opens offline — plugins & LSP already installed

  Verify (no internet needed):
    nvim --headless "+checkhealth" "+qa"   # or inside nvim: :Lazy  :Mason  :checkhealth

  Notes:
    - ~/.local/bin must be on PATH (the shipped ~/.zshrc handles this).
    - scope=${SCOPE:-standard}: Go/Rust compiler toolchains are ${SCOPE:-standard}-dependent.
EOF
