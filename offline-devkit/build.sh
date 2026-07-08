#!/usr/bin/env bash
# offline-devkit/build.sh
#
# Host orchestrator. Builds a self-contained, offline-installable dev-kit
# bundle for airgapped Ubuntu 24+ by driving a matching-arch Docker container
# (see docker/build-in-container.sh) and packing its output into a .tar.gz.
#
# Usage:
#   ./offline-devkit/build.sh [--arch amd64,arm64] [--scope standard|full]
#                             [--base ubuntu:24.04] [--no-cache]
#
# Output: offline-devkit/dist/devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz
#
# Requires: Docker daemon running. Cross-arch builds (amd64 on Apple Silicon,
# or arm64 on x86_64) use QEMU emulation — slower, but produced natively-runnable
# bundles. Docker Desktop ships the required binfmt handlers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/manifest.sh"

ARCHES="amd64 arm64"
SCOPE="$DEVKIT_SCOPE_DEFAULT"
BASE="$DEVKIT_BASE_DEFAULT"
NO_CACHE=""
DATE="$(date +%Y%m%d)"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Build an offline-installable dev-kit bundle for airgapped Ubuntu 24+.

Usage:
  ./offline-devkit/build.sh [options]

Options:
  --arch amd64,arm64     target arch(es), comma-separated  (default: both)
  --scope standard|full  toolset scope                     (default: standard)
  --base ubuntu:24.04    builder/target base image         (default: ubuntu:24.04)
  --no-cache             rebuild the builder image from scratch
  -h, --help             show this help

Output: offline-devkit/dist/devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz
EOF
  exit "${1:-0}"
}

# --- arg parsing ----------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --arch)     ARCHES="$(echo "$2" | tr ',' ' ')"; shift 2 ;;
    --scope)    SCOPE="$2"; shift 2 ;;
    --base)     BASE="$2"; shift 2 ;;
    --no-cache) NO_CACHE="--no-cache"; shift ;;
    -h|--help)  usage 0 ;;
    *) die "unknown argument: $1  (try --help)" ;;
  esac
done

case "$SCOPE" in standard|full) ;; *) die "invalid --scope: $SCOPE (standard|full)" ;; esac
for a in $ARCHES; do
  case "$a" in amd64|arm64) ;; *) die "invalid --arch: $a (amd64|arm64)" ;; esac
done

# --- preflight ------------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "docker not found on PATH"
docker info >/dev/null 2>&1 || die "docker daemon not running — start Docker and retry"
BUILDX=""
docker buildx version >/dev/null 2>&1 && BUILDX="yes"

DIST_DIR="$SCRIPT_DIR/dist"
mkdir -p "$DIST_DIR"

build_one() { # build_one ARCH
  local arch="$1"
  local platform="linux/$arch"
  local img="offline-devkit-builder:${arch}"
  local name="devkit-ubuntu24-${arch}-${SCOPE}-${DATE}"
  local stage="$DIST_DIR/$name"
  local tarball="$DIST_DIR/$name.tar.gz"

  log "[$arch] Building builder image ($BASE)"
  # shellcheck disable=SC2086  # $NO_CACHE is an intentional optional flag
  if [ -n "$BUILDX" ]; then
    docker buildx build $NO_CACHE --platform "$platform" --build-arg "BASE=$BASE" \
      --load -t "$img" -f "$SCRIPT_DIR/docker/Dockerfile" "$SCRIPT_DIR/docker" || return 1
  else
    DOCKER_BUILDKIT=1 docker build $NO_CACHE --platform "$platform" --build-arg "BASE=$BASE" \
      -t "$img" -f "$SCRIPT_DIR/docker/Dockerfile" "$SCRIPT_DIR/docker" || return 1
  fi

  log "[$arch] Running in-container build (scope=$SCOPE) — slow under emulation"
  rm -rf "$stage"; mkdir -p "$stage"
  if ! docker run --rm --platform "$platform" \
        -e "ARCH=$arch" -e "SCOPE=$SCOPE" \
        -v "$REPO_DIR:/repo:ro" -v "$stage:/out" \
        "$img" /repo/offline-devkit/docker/build-in-container.sh; then
    warn "[$arch] container run failed. If this is a cross-arch (QEMU) run, register emulators:"
    warn "  docker run --privileged --rm tonistiigi/binfmt --install all"
    rm -rf "$stage"
    return 1
  fi

  log "[$arch] Packing bundle"
  cp "$SCRIPT_DIR/install/install.sh" "$stage/install.sh" || return 1
  chmod +x "$stage/install.sh"
  # COPYFILE_DISABLE=1: on macOS, bsdtar otherwise embeds AppleDouble (._*)
  # sidecars for files carrying xattrs. bsdtar hides them from `tar -tzf`, but
  # GNU tar on the Linux target extracts them as junk ._*.lua / ._*.deb files
  # that break Neovim's module loader and choke `dpkg -i apt/*.deb`.
  find "$stage" -name '._*' -delete 2>/dev/null || true
  COPYFILE_DISABLE=1 tar --no-xattrs -czf "$tarball" -C "$DIST_DIR" "$name" 2>/dev/null \
    || COPYFILE_DISABLE=1 tar -czf "$tarball" -C "$DIST_DIR" "$name" || return 1
  rm -rf "$stage"
  printf '\033[1;32m    ✔ %s (%s)\033[0m\n' "$tarball" "$(du -h "$tarball" | cut -f1)"
}

log "offline-devkit build: arches=[$ARCHES] scope=$SCOPE base=$BASE"
BUILT=""
FAILED=""
for arch in $ARCHES; do
  if build_one "$arch"; then BUILT="$BUILT $arch"; else FAILED="$FAILED $arch"; fi
done

log "Summary"
[ -n "$BUILT" ]  && printf '  \033[1;32mbuilt:\033[0m%s\n' "$BUILT"
[ -n "$FAILED" ] && printf '  \033[1;31mfailed:\033[0m%s\n' "$FAILED"

if [ -n "$BUILT" ]; then
  echo ""
  echo "Transfer a bundle to the airgapped target, then:"
  cat <<'EOF'
    tar -xzf devkit-ubuntu24-<arch>-<scope>-<date>.tar.gz
    cd devkit-ubuntu24-<arch>-<scope>-<date> && ./install.sh
    exec zsh   # then run: nvim
EOF
fi

[ -z "$FAILED" ]   # exit non-zero iff any arch failed
