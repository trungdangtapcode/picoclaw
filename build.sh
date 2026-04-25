#!/bin/bash
# ============================================================================
# PicoClaw Build Script
# Builds picoclaw + picoclaw-launcher from the modified source code.
#
# Prerequisites:
#   - Go 1.25+ (https://go.dev/dl/)
#   - Node.js 20+ and pnpm (for web frontend, only needed for launcher)
#
# Usage:
#   bash build.sh              # Build picoclaw binary only
#   bash build.sh --all        # Build picoclaw + launcher + TUI
#   bash build.sh --install    # Build + install to pico_iot directory
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
BUILD_OUTPUT="${SCRIPT_DIR}/build-output"
INSTALL_DIR="${HOME}/pico_iot"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check Go
command -v go >/dev/null 2>&1 || error "Go is not installed. Get it from https://go.dev/dl/"

BUILD_ALL=false
DO_INSTALL=false

for arg in "$@"; do
    case $arg in
        --all)     BUILD_ALL=true ;;
        --install) DO_INSTALL=true; BUILD_ALL=true ;;
        --help|-h)
            echo "Usage: bash build.sh [--all] [--install]"
            echo "  --all      Build picoclaw + launcher + TUI"
            echo "  --install  Build all + copy binaries to ~/pico_iot/"
            exit 0
            ;;
    esac
done

mkdir -p "${BUILD_OUTPUT}"

# ── Build picoclaw ──────────────────────────────────────────────────────────
info "Building picoclaw..."
cd "${SRC_DIR}"
make build
cp build/picoclaw "${BUILD_OUTPUT}/picoclaw"
info "✅ picoclaw built → ${BUILD_OUTPUT}/picoclaw"

# ── Build launcher + TUI ───────────────────────────────────────────────────
if [ "$BUILD_ALL" = true ]; then
    # Check for pnpm (needed for web frontend)
    if command -v pnpm >/dev/null 2>&1; then
        info "Building picoclaw-launcher (web UI)..."
        make build-launcher
        cp build/picoclaw-launcher "${BUILD_OUTPUT}/picoclaw-launcher"
        info "✅ picoclaw-launcher built → ${BUILD_OUTPUT}/picoclaw-launcher"
    else
        warn "pnpm not found — skipping picoclaw-launcher build"
        warn "Install pnpm: npm install -g pnpm"
    fi

    info "Building picoclaw-launcher-tui..."
    make build-launcher-tui
    cp build/picoclaw-launcher-tui "${BUILD_OUTPUT}/picoclaw-launcher-tui"
    info "✅ picoclaw-launcher-tui built → ${BUILD_OUTPUT}/picoclaw-launcher-tui"
fi

# ── Install ────────────────────────────────────────────────────────────────
if [ "$DO_INSTALL" = true ]; then
    info "Installing to ${INSTALL_DIR}..."
    mkdir -p "${INSTALL_DIR}"

    for bin in picoclaw picoclaw-launcher picoclaw-launcher-tui; do
        if [ -f "${BUILD_OUTPUT}/${bin}" ]; then
            # Backup existing binary
            if [ -f "${INSTALL_DIR}/${bin}" ]; then
                TIMESTAMP=$(date +%Y%m%d%H%M%S)
                cp "${INSTALL_DIR}/${bin}" "${INSTALL_DIR}/${bin}.bak.${TIMESTAMP}"
                info "  Backed up existing ${bin}"
            fi
            cp "${BUILD_OUTPUT}/${bin}" "${INSTALL_DIR}/${bin}"
            chmod +x "${INSTALL_DIR}/${bin}"
            info "  ✅ Installed ${bin}"
        fi
    done
fi

echo ""
info "=============================="
info "Build complete!"
echo ""
echo "  Binaries: ${BUILD_OUTPUT}/"
ls -lh "${BUILD_OUTPUT}/" | grep -E 'picoclaw'
echo ""
if [ "$DO_INSTALL" != true ]; then
    echo "  To install: bash build.sh --install"
fi
