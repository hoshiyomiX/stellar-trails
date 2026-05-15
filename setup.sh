#!/usr/bin/env bash
# ============================================================
#  stellar-frameworks v5.4.3
#
#  Install:  cd /home/z/my-project/stellar-frameworks && bash setup.sh
#  Invoke:   Skill(command="stellar-frameworks")
#  Marker:   ☄️
#  Note:     boot.sh is the preferred installer — this file is
#            retained for standalone use.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/skill/stellar-frameworks"
# IMPL-003: Install to project root's skills/ dir where Skill system loads from
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
INSTALL_DIR="${PROJECT_ROOT}/skills/stellar-frameworks"

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
echo "  ☄️ stellar-frameworks v5.4.3"
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

# --- Fresh install ---
mkdir -p "${INSTALL_DIR}"
cp -R "${SOURCE_DIR}" "${INSTALL_DIR}"
ok "Files deployed to ${INSTALL_DIR}"

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

    if grep -q "v5.4.3" "${INSTALL_DIR}/SKILL.md"; then
        ok "Version 5.4.3 confirmed"
    else
        fail "Version mismatch"
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

# --- Self-heal: configure $HOME/.bashrc hook ---
BASHRC="$HOME/.bashrc"
BASHRC_MARKER="# stellar-frameworks auto-heal"
TARGET_DIR="${PROJECT_ROOT}/stellar-frameworks"
# v5.4.3: Synchronous + --fast (no git ops, no background) to avoid race condition
BASHRC_CMD="bash $TARGET_DIR/boot.sh --fast --install-only >/dev/null 2>&1"

# Clean up any old hooks (including v5.4.2 async variant with trailing &)
if [ -f "$BASHRC" ]; then
  if grep -qF "boot.sh" "$BASHRC" 2>/dev/null; then
    sed -i '/# stellar-frameworks auto-heal/d' "$BASHRC"
    sed -i '/boot.sh/d' "$BASHRC"
  fi
  printf '\n%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_CMD" >> "$BASHRC"
  ok "Auto-heal hook updated in $BASHRC"
else
  printf '%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_CMD" > "$BASHRC"
  ok "Auto-heal hook written to $BASHRC"
fi

# Also clean up stale hook from wrong path (v5.4.1 bug)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
if [ -f "$STALE_BASHRC" ] && grep -qF "$BASHRC_MARKER" "$STALE_BASHRC" 2>/dev/null; then
  sed -i '/# stellar-frameworks auto-heal/d' "$STALE_BASHRC"
  sed -i '/boot.sh/d' "$STALE_BASHRC"
  [ ! -s "$STALE_BASHRC" ] && rm -f "$STALE_BASHRC"
  ok "Cleaned stale hook from $STALE_BASHRC"
fi

# --- Done ---
echo ""
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  ☄️ v5.4.3 installed!${NC}"
    echo ""
    echo "  OPTION A — Mid-session (no restart):"
    echo "    Read the skill file: ${INSTALL_DIR}/SKILL.md"
    echo "    Then follow the instructions directly."
    echo ""
    echo "  OPTION B — Full activation (restart session):"
    echo "    After restart, Skill(command=\"stellar-frameworks\") works."
    echo ""
    echo "  Invoke: Skill(command=\"stellar-frameworks\")"
    echo "============================================"
else
    echo -e "${RED}  Install completed with ${ERRORS} error(s)${NC}"
    echo "============================================"
    exit 1
fi
