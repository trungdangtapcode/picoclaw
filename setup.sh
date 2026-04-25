#!/bin/bash
# ============================================================================
# PicoClaw Full Setup Script
# Reproduces the exact PicoClaw setup on a fresh machine.
#
# What this does:
#   1. Builds picoclaw from modified source (requires Go 1.25+)
#   2. Installs binaries to ~/pico_iot/
#   3. Deploys skills, config, and autostart to ~/.picoclaw/
#
# Usage:
#   bash setup.sh              # Full setup (build + deploy)
#   bash setup.sh --deploy     # Deploy only (skip build, use existing binaries)
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PICOCLAW_HOME="${HOME}/.picoclaw"
INSTALL_DIR="${HOME}/pico_iot"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

DEPLOY_ONLY=false
for arg in "$@"; do
    case $arg in
        --deploy)  DEPLOY_ONLY=true ;;
        --help|-h)
            echo "Usage: bash setup.sh [--deploy]"
            echo "  --deploy   Skip build, only deploy skills/config/autostart"
            exit 0
            ;;
    esac
done

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║     🦀 PicoClaw Setup Script         ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: Build from source ──────────────────────────────────────────────
if [ "$DEPLOY_ONLY" = false ]; then
    info "Step 1/3: Building from source..."
    bash "${SCRIPT_DIR}/build.sh" --install
    echo ""
else
    info "Step 1/3: Skipped (--deploy mode)"
    if [ ! -f "${INSTALL_DIR}/picoclaw" ]; then
        warn "No picoclaw binary found at ${INSTALL_DIR}/picoclaw"
        warn "Run without --deploy to build from source"
    fi
fi

# ── Step 2: Deploy skills ─────────────────────────────────────────────────
info "Step 2/3: Deploying skills..."
mkdir -p "${PICOCLAW_HOME}/workspace/skills"
cp -r "${SCRIPT_DIR}/skills/"* "${PICOCLAW_HOME}/workspace/skills/"
info "  ✅ 12 skills deployed to ${PICOCLAW_HOME}/workspace/skills/"

# ── Step 3: Deploy config ─────────────────────────────────────────────────
info "Step 3/3: Deploying configuration..."

if [ ! -f "${PICOCLAW_HOME}/config.json" ]; then
    cp "${SCRIPT_DIR}/config.json" "${PICOCLAW_HOME}/config.json"
    info "  ✅ Config template → ${PICOCLAW_HOME}/config.json"
    warn "  ⚠️  UPDATE YOUR API KEYS in ${PICOCLAW_HOME}/config.json"
else
    info "  ⏭️  Config already exists (skipped)"
fi

if [ ! -f "${PICOCLAW_HOME}/auth.json" ]; then
    cp "${SCRIPT_DIR}/auth.json" "${PICOCLAW_HOME}/auth.json"
    info "  ✅ Auth template → ${PICOCLAW_HOME}/auth.json"
    warn "  ⚠️  UPDATE YOUR API KEYS in ${PICOCLAW_HOME}/auth.json"
else
    info "  ⏭️  Auth already exists (skipped)"
fi

# Autostart (Linux desktop only)
if [ -d "${HOME}/.config" ]; then
    mkdir -p "${HOME}/.config/autostart"
    cp "${SCRIPT_DIR}/autostart/picoclaw-web.desktop" "${HOME}/.config/autostart/"
    # Update desktop file to point to correct binary location
    sed -i "s|Exec=.*|Exec=${INSTALL_DIR}/picoclaw-launcher -no-browser ${PICOCLAW_HOME}/config.json|" \
        "${HOME}/.config/autostart/picoclaw-web.desktop"
    info "  ✅ Autostart entry installed"
fi

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ PicoClaw setup complete!${NC}"
echo ""
echo "  📁 Binaries:  ${INSTALL_DIR}/"
echo "  📁 Config:    ${PICOCLAW_HOME}/config.json"
echo "  📁 Auth:      ${PICOCLAW_HOME}/auth.json"
echo "  📁 Skills:    ${PICOCLAW_HOME}/workspace/skills/"
echo ""
echo "  To run:"
echo "    ${INSTALL_DIR}/picoclaw ${PICOCLAW_HOME}/config.json"
echo ""
echo "  To run web UI:"
echo "    ${INSTALL_DIR}/picoclaw-launcher -no-browser ${PICOCLAW_HOME}/config.json"
echo ""
if [ -f "${PICOCLAW_HOME}/config.json" ]; then
    if grep -q "YOUR_API_KEY_HERE" "${PICOCLAW_HOME}/config.json" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  Don't forget to update API keys in config.json!${NC}"
    fi
fi
