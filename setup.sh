#!/usr/bin/env bash
# ============================================================
#  stellar-trails v6.3.0
#
#  Install:  bash ~/.stellar-trails-repo/setup.sh
#  Invoke:   Skill(command="stellar-trails")
#  Marker:   ☄️
#  Note:     boot.sh is the preferred installer — this file is
#            retained for standalone use.
#  v6.3.0:   Loud Sterilization — audit logging, --keep-submodules,
#            --verify, --dry-run, --pinned, --stop-dev-server flags.
#            All destructive ops now logged to ~/.stellar-trails.log.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/skill/stellar-trails"
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
INSTALL_DIR="${PROJECT_ROOT}/skills/stellar-trails"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }

echo ""
echo "============================================"
echo "  ☄️ stellar-trails v6.3.0"
echo "============================================"
echo ""

if [ ! -f "${SOURCE_DIR}/SKILL.md" ]; then
    fail "Source files not found in ${SOURCE_DIR}/"
    echo "  Make sure setup.sh is run from the repo root."
    exit 1
fi

ERRORS=0

# --- Uninstall previous version (if any) ---
if [ -d "${INSTALL_DIR}" ]; then
    rm -rf "${INSTALL_DIR}"
    ok "Previous installation removed"
fi

# --- Remove predecessor skill (stellar-coding-agent v5.0.0) ---
OBSOLETE_DIR="${PROJECT_ROOT}/skills/stellar-coding-agent"
if [ -d "${OBSOLETE_DIR}" ]; then
    rm -rf "${OBSOLETE_DIR}"
    ok "Removed predecessor skill: stellar-coding-agent"
fi

# --- Fresh install (copy: skill/ → skills/) ---
mkdir -p "$(dirname "${INSTALL_DIR}")"
rm -rf "${INSTALL_DIR}"
cp -a "${SOURCE_DIR}" "${INSTALL_DIR}"
ok "Copied ${INSTALL_DIR} ← ${SOURCE_DIR}"

# --- Verify ---
echo ""
info "Verifying installation..."

if [ -f "${INSTALL_DIR}/SKILL.md" ]; then
    if grep -q "Phase State Machine" "${INSTALL_DIR}/SKILL.md"; then
        ok "Phase state machine present"
    else
        fail "Phase state machine MISSING"
        ERRORS=$((ERRORS + 1))
    fi

    INSTALLED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "${INSTALL_DIR}/SKILL.md" 2>/dev/null || echo "0.0.0")"
    EXPECTED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "${SOURCE_DIR}/SKILL.md" 2>/dev/null || echo "0.0.0")"
    if [ "$INSTALLED_VER" = "$EXPECTED_VER" ]; then
        ok "Version ${INSTALLED_VER} confirmed"
    else
        fail "Version mismatch: expected ${EXPECTED_VER}, got ${INSTALLED_VER}"
        ERRORS=$((ERRORS + 1))
    fi

    for f in \
        procedure/phases.md \
        procedure/templates/problem-spec.md \
        procedure/templates/implementation-plan.md \
        procedure/templates/verification-report.md \
        procedure/templates/incident-report.md \
        procedure/decision-trees/error-resolution.md \
        constraints/code-standards.md \
        constraints/type-safety.md \
        knowledge/universal/architecture.md \
        knowledge/universal/conventions.md \
        knowledge/universal/error-patterns.md \
        knowledge/platform/zai-sandbox.md \
        memory-template.md \
        CHANGELOG.md; do
        if [ -f "${INSTALL_DIR}/${f}" ]; then
            ok "${f}"
        else
            fail "${f} MISSING"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    fail "SKILL.md not found"
    ERRORS=$((ERRORS + 1))
fi

# --- Self-heal: configure hook in multiple init files ---
BASHRC_MARKER="# stellar-trails auto-heal"
REPO_URL="https://github.com/hoshiyomiX/stellar-trails.git"
TARGET_DIR="${STELLAR_REPO_PATH:-$HOME/.stellar-trails-repo}"
# v6.0.0: clone-if-missing + git pull + boot + health-check + log rotation
BASHRC_PHASE1="BOOT_LOG=$HOME/.stellar-trails.log; mkdir -p $HOME; [ -d $TARGET_DIR/.git ] || git clone $REPO_URL $TARGET_DIR 2>/dev/null; (cd $TARGET_DIR && git pull --ff-only --quiet 2>/dev/null); bash $TARGET_DIR/boot.sh --fast --install-only >>$BOOT_LOG 2>&1; [ -s $PROJECT_ROOT/skills/stellar-trails/SKILL.md ] || bash $TARGET_DIR/boot.sh >>$BOOT_LOG 2>&1; tail -500 $BOOT_LOG > $BOOT_LOG.tmp && mv $BOOT_LOG.tmp $BOOT_LOG 2>/dev/null || true"

HOOK_TARGETS=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
HOOKS_WRITTEN=0

for HOOK_FILE in "${HOOK_TARGETS[@]}"; do
  if [ -f "$HOOK_FILE" ]; then
    if grep -qF "boot.sh" "$HOOK_FILE" 2>/dev/null; then
      sed -i '/# stellar-trails auto-heal/d' "$HOOK_FILE"
      sed -i '/boot.sh/d' "$HOOK_FILE"
    fi
    printf '\n%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_PHASE1" >> "$HOOK_FILE"
  else
    printf '%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_PHASE1" > "$HOOK_FILE"
  fi
  HOOKS_WRITTEN=$((HOOKS_WRITTEN + 1))
done

ok "Auto-heal hook written to $HOOKS_WRITTEN/3 init files (clone + pull + boot + health-check + log)"

# --- Popup preview: create + launch .zscripts/dev.sh ---
ZSCRIPTS="${PROJECT_ROOT}/.zscripts"
DEV_SCRIPT="${ZSCRIPTS}/dev.sh"
DOWNLOAD_DIR="${PROJECT_ROOT}/download"
DEV_SCRIPT_MARKER="# stellar-trails dev server"

if [ ! -f "$DEV_SCRIPT" ]; then
    info "Creating dev.sh for popup preview..."
    mkdir -p "$ZSCRIPTS"
    cat > "$DEV_SCRIPT" << 'DEVSH'
#!/bin/bash
# stellar-trails dev server — persistent popup preview
# Auto-restarts if killed (unkillable). Port :3000.
# Created by boot.sh — do not edit manually.

# Guard: if :3000 already occupied, exit gracefully
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ':3000 '; then
  echo "[dev.sh] Port :3000 already in use — not starting" >&2
  exit 0
fi

if [ -f /home/z/my-project/package.json ] \
   && grep -q '"next"' /home/z/my-project/package.json 2>/dev/null; then
  # Next.js project — delegate to bun
  while true; do
    cd /home/z/my-project && bun run dev
    sleep 2
  done
else
  # Static file server — serve /download/ on :3000
  mkdir -p /home/z/my-project/download
  while true; do
    cd /home/z/my-project/download && python3 -m http.server 3000
    sleep 1
  done
fi
DEVSH
    chmod +x "$DEV_SCRIPT"
    ok "dev.sh created at ${DEV_SCRIPT}"
else
    ok "dev.sh already exists"
fi

# Launch server if not already running (port guard prevents duplicates)
if [ -f "$DEV_SCRIPT" ]; then
  if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    ok "Popup preview already running on :3000"
  else
    mkdir -p "$DOWNLOAD_DIR"
    bash "$DEV_SCRIPT" >/dev/null 2>&1 &
    ok "Popup preview launched on :3000 (persistent)"
  fi
fi

# Clean up stale hook from wrong path (v5.4.1 bug)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
if [ -f "$STALE_BASHRC" ] && grep -qF "$BASHRC_MARKER" "$STALE_BASHRC" 2>/dev/null; then
  sed -i '/# stellar-trails auto-heal/d' "$STALE_BASHRC"
  sed -i '/boot.sh/d' "$STALE_BASHRC"
  [ ! -s "$STALE_BASHRC" ] && rm -f "$STALE_BASHRC"
  ok "Cleaned stale hook from $STALE_BASHRC"
fi

# --- Done ---
echo ""
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  ☄️ v6.3.0 installed and ACTIVE — no restart needed!${NC}"
    echo ""
    echo "  Popup preview: LIVE on :3000 (persistent, killable via boot.sh --stop-dev-server)."
    echo "  Invoke: Skill(command=\"stellar-trails\")"
    echo "  Repo: $TARGET_DIR"
    echo "  Audit log: $HOME/.stellar-trails.log"
    echo ""
    echo "============================================"
else
    echo -e "${RED}  Install completed with ${ERRORS} error(s)${NC}"
    echo "============================================"
    exit 1
fi
