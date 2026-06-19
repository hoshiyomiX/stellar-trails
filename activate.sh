#!/bin/bash
# stellar-trails — Mid-session activator (v5.4.3)
# Loads skill content into context WITHOUT needing a session restart.
#
# How it works:
#   The platform caches available_skills at session start. Skills installed
#   mid-session won't appear in that cache. This script works around that by
#   outputting the full skill content so the assistant can read it directly.
#   The content is IDENTICAL to what Skill() would inject — it's the same file.
#
# Usage (paste into chat):
#   Read the output of: bash ~/my-project/stellar-trails/activate.sh
#   Then follow the stellar-trails instructions manually.
#
# Or have the assistant run:
#   Bash: bash ~/my-project/stellar-trails/activate.sh
#   Then read the printed file paths and follow the instructions.

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
INSTALL_DIR="$PROJECT_ROOT/skills/stellar-trails"

if [ ! -f "$INSTALL_DIR/SKILL.md" ]; then
  echo "[activate] ERROR: Skill not installed. Run boot.sh first:"
  echo "  bash $PROJECT_ROOT/stellar-trails/boot.sh --fast --install-only"
  exit 1
fi

echo "========================================"
echo "  STELLAR-FRAMEWORKS MID-SESSION LOAD"
echo "========================================"
echo ""
echo "The Skill() tool can't find this skill mid-session (platform caches"
echo "available_skills at session start). But the files ARE on disk."
echo ""
echo "To activate NOW, read these files in order:"
echo ""
echo "  1. CORE:  $INSTALL_DIR/SKILL.md"
echo "  2. Phase details:  $INSTALL_DIR/procedure/phases.md"
echo "  3. Error handling:  $INSTALL_DIR/procedure/decision-trees/error-resolution.md"
echo ""
echo "Or just read #1 — SKILL.md references the others as needed."
echo ""
echo "========================================"
echo ""

# Output SKILL.md content directly
cat "$INSTALL_DIR/SKILL.md"
