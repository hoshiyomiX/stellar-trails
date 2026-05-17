#!/bin/bash
# stellar-frameworks — Install, self-heal (git-tracked) v5.5.1
# Pure skill installer + popup preview provider. No Next.js bootstrap.
# Self-heal: after first run, adds two-phase hook to shell init files.
# Popup preview: creates .zscripts/dev.sh AND launches it for immediate :3000 serving.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/hoshiyomiX/stellar-frameworks/main/boot.sh)
#    or: bash ~/my-project/stellar-frameworks/boot.sh
#    or: bash stellar-frameworks/boot.sh [--install-only] [--fast]
#
# Flags:
#   --fast         Skip git operations (pure local copy ~50ms). Used by hook Phase 1.
#                   OVERridden if local repo version < MINIMUM_VERSION (stale snapshot).
#   --install-only Accepted for compatibility; no-op since v5.4.4.

set -euo pipefail

# ── Minimum version guard ──────────────────────────────────────────
# If the LOCAL repo's SKILL.md version is below this threshold,
# --fast mode is overridden to force git pull. This prevents stale
# snapshots (e.g. v5.3.0 baked into repo.tar) from persisting.
# Bump this whenever a new version is released.
MINIMUM_VERSION="5.5.1"

# Semantic version comparison: returns 0 (true) if $1 < $2
version_lt() {
  local a1 a2 a3 b1 b2 b3
  IFS='.' read -r a1 a2 a3 <<< "$1"
  IFS='.' read -r b1 b2 b3 <<< "$2"
  [[ $a1 -lt $b1 ]] || { [[ $a1 -eq $b1 ]] && [[ $a2 -lt $b2 ]]; } || \
  { [[ $a1 -eq $b1 ]] && [[ $a2 -eq $b2 ]] && [[ $a3 -lt $b3 ]]; }
}

# Parse flags
FAST_MODE=false
for arg in "$@"; do
  case "$arg" in
    --fast) FAST_MODE=true ;;
    --install-only) : ;; # no-op: kept for backwards compatibility
  esac
done

# ── 0. Auto-clone: if running from a one-liner, SCRIPT_DIR is a temp dir ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/hoshiyomiX/stellar-frameworks.git"
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
TARGET_DIR="$PROJECT_ROOT/stellar-frameworks"

if [ ! -f "$TARGET_DIR/boot.sh" ]; then
  echo "[boot] Repo not found at $TARGET_DIR — cloning..."
  mkdir -p "$PROJECT_ROOT"
  git clone "$REPO_URL" "$TARGET_DIR" 2>/dev/null || {
    echo "[boot] ERROR: git clone failed. Check network or run manually:"
    echo "  cd $PROJECT_ROOT && git clone $REPO_URL"
    exit 1
  }
  echo "[boot] Cloned successfully"
  SCRIPT_DIR="$TARGET_DIR"
elif [ "$(basename "$SCRIPT_DIR")" != "stellar-frameworks" ]; then
  SCRIPT_DIR="$TARGET_DIR"
fi

SOURCE_DIR="$SCRIPT_DIR/skill/stellar-frameworks"

# Detect project root — repo may be a subdirectory of /home/z/my-project/
if [ -f "$PROJECT_ROOT/package.json" ] && [ -d "$PROJECT_ROOT/src/app" ]; then
  : # PROJECT_ROOT explicitly set or detected
else
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

INSTALL_DIR="$PROJECT_ROOT/skills/stellar-frameworks"
OBSOLETE_DIR="$PROJECT_ROOT/skills/stellar-coding-agent"
ZSCRIPTS="$PROJECT_ROOT/.zscripts"
DEV_SCRIPT="$ZSCRIPTS/dev.sh"
DOWNLOAD_DIR="$PROJECT_ROOT/download"

# ── 0b. Stale snapshot override ───────────────────────────────────
# Even in --fast mode, if the local repo itself is outdated (from a stale
# snapshot), we MUST git pull to get the latest version. Otherwise both
# SOURCE and INSTALLED are the same stale version -> no upgrade detected.
if $FAST_MODE && [ -f "$SOURCE_DIR/SKILL.md" ]; then
  LOCAL_REPO_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if version_lt "$LOCAL_REPO_VER" "$MINIMUM_VERSION"; then
    echo "[boot] Local repo $LOCAL_REPO_VER < minimum $MINIMUM_VERSION — overriding --fast"
    FAST_MODE=false
  fi
fi

# ── 1. Auto-update: pull if remote has newer skill files ──────────
# Non-fatal: any git failure just skips the update and proceeds.
# SKIP in --fast mode UNLESS overridden by stale snapshot guard above.
if [ -d "$SCRIPT_DIR/.git" ] && ! $FAST_MODE; then
  BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "")"
  REMOTE="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")"

  if [ -n "$BRANCH" ] && [ -n "$REMOTE" ]; then
    if git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet 2>/dev/null; then
      LOCAL="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)"
      REMOTE_SHA="$(git -C "$SCRIPT_DIR" rev-parse "origin/$BRANCH" 2>/dev/null)"

      if [ "$LOCAL" != "$REMOTE_SHA" ]; then
        BEHIND="$(git -C "$SCRIPT_DIR" rev-list --count HEAD.."origin/$BRANCH" 2>/dev/null || echo "0")"
        AHEAD="$(git -C "$SCRIPT_DIR" rev-list --count "origin/$BRANCH"..HEAD 2>/dev/null || echo "0")"

        if [ "$AHEAD" = "0" ] && [ "$BEHIND" -gt 0 ]; then
          if [ -z "$(git -C "$SCRIPT_DIR" status --porcelain -- skill/ setup.sh boot.sh README.md 2>/dev/null)" ]; then
            OLD_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
            if git -C "$SCRIPT_DIR" pull --ff-only --quiet origin "$BRANCH" 2>/dev/null; then
              NEW_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
              echo "[boot] Updated ${OLD_VER} → ${NEW_VER} ($BEHIND commits)"
            else
              echo "[boot] WARNING: git pull failed — skipping update"
            fi
          else
            echo "[boot] Skipping update — local changes detected in tracked files"
          fi
        elif [ "$AHEAD" -gt 0 ]; then
          echo "[boot] Skipping update — local commits ahead of remote (diverged)"
        fi
      fi
    fi
  fi
fi

# ── 2. Install / self-heal: copy git-tracked skill/ → platform skills/ ──
NEED_INSTALL=false
if [ ! -f "$INSTALL_DIR/SKILL.md" ]; then
  NEED_INSTALL=true
else
  INSTALLED_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  SOURCE_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if [ "$INSTALLED_VER" != "$SOURCE_VER" ]; then
    NEED_INSTALL=true
    echo "[boot] Version mismatch: installed $INSTALLED_VER → source $SOURCE_VER"
  fi
fi

# Clean up predecessor skill (stellar-coding-agent v5.0.0)
if [ -d "$OBSOLETE_DIR" ]; then
  rm -rf "${OBSOLETE_DIR:?}"
  echo "[boot] Removed predecessor skill: stellar-coding-agent"
fi

if $NEED_INSTALL; then
  if [ ! -d "$SOURCE_DIR" ]; then
    echo "[boot] ERROR: skill/ not found. Is this the repo root?"
    exit 1
  fi
  echo "[boot] Installing skill files → skills/"
  mkdir -p "$INSTALL_DIR"
  rm -rf "${INSTALL_DIR:?}"
  cp -R "$SOURCE_DIR" "$INSTALL_DIR"

  # Verify critical files
  ERRORS=0
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
    if [ -f "$INSTALL_DIR/$f" ]; then
      : # OK
    else
      echo "[boot] WARNING: $f MISSING"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $ERRORS -eq 0 ]; then
    echo "[boot] Installed successfully"
  else
    echo "[boot] WARNING: installed with $ERRORS missing file(s)"
  fi
else
  echo "[boot] Skill files OK"
fi

# ── 3. Popup preview: ensure .zscripts/dev.sh exists ──────────────
# The platform's start.sh auto-executes .zscripts/dev.sh if it exists.
# This provides popup preview on :3000 without fullstack-dev.
#
# Persistent (unkillable) dev.sh:
#   - Wraps server in while-loop → auto-restarts if killed
#   - Next.js project exists → bun run dev
#   - Otherwise → python3 static server serving /download/ on :3000
#
# NOTE: fullstack-dev's init-fullstack.sh also checks for dev.sh existence.
# If dev.sh is present, init-fullstack.sh skips tarball download and runs it.
# This is intentional — our dev.sh handles both cases intelligently.
# To force fullstack-dev setup: rm .zscripts/dev.sh && invoke fullstack-dev.

DEV_SCRIPT_MARKER="# stellar-frameworks dev server"
DEV_SH_CREATED=false

if [ ! -f "$DEV_SCRIPT" ]; then
  echo "[boot] Creating dev.sh for popup preview..."
  mkdir -p "$ZSCRIPTS"
  cat > "$DEV_SCRIPT" << 'DEVSH'
#!/bin/bash
# stellar-frameworks dev server — persistent popup preview
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
  DEV_SH_CREATED=true
  echo "[boot] dev.sh created"
elif ! grep -qF "$DEV_SCRIPT_MARKER" "$DEV_SCRIPT" 2>/dev/null; then
  echo "[boot] dev.sh already exists (external) — keeping it"
else
  echo "[boot] dev.sh OK (managed by stellar-frameworks)"
fi

# ── 3b. Launch popup preview server (immediate, not deferred) ──────
# BUGFIX: /start.sh auto-executes .zscripts/dev.sh at SESSION START.
# On fresh install, dev.sh doesn't exist yet when /start.sh runs →
# server never starts → port :3000 empty → Caddy :81 shows 502.
# Fix: boot.sh itself launches the server after creating dev.sh.
# Port guard (inside dev.sh) prevents duplicate launches.

if [ -f "$DEV_SCRIPT" ]; then
  if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    echo "[boot] Popup preview already running on :3000"
  else
    mkdir -p "$DOWNLOAD_DIR"
    bash "$DEV_SCRIPT" >/dev/null 2>&1 &
    echo "[boot] Popup preview launched on :3000"
  fi
fi

# ── 4. Self-heal persistence (hook) ─────────────────────────────
# Ensures stellar-frameworks auto-recovers after sandbox resets.
# Writes hook to MULTIPLE shell init files for redundancy:
#   $HOME/.bashrc       — interactive non-login shells
#   $HOME/.bash_profile  — login shells (bash)
#   $HOME/.profile       — login shells (POSIX fallback)
#
# CRITICAL: The hook must git pull BEFORE running boot.sh.
# In a stale snapshot, both the local repo AND boot.sh are outdated.
# If boot.sh runs first (even without --fast), it uses the OLD logic.
# By pulling first, we ensure boot.sh itself is updated before execution.
# When already up-to-date, git pull --ff-only is nearly instant (~0.1s).

BASHRC_MARKER="# stellar-frameworks auto-heal"
BASHRC_PHASE1="(cd $TARGET_DIR && git pull --ff-only --quiet 2>/dev/null); bash $TARGET_DIR/boot.sh --fast --install-only >/dev/null 2>&1"

# Clean up stale hook from wrong path (v5.4.1 bug)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
if [ -f "$STALE_BASHRC" ] && grep -qF "$BASHRC_MARKER" "$STALE_BASHRC" 2>/dev/null; then
  sed -i '/# stellar-frameworks auto-heal/d' "$STALE_BASHRC"
  sed -i '/boot.sh/d' "$STALE_BASHRC"
  [ ! -s "$STALE_BASHRC" ] && rm -f "$STALE_BASHRC"
  echo "[boot] Cleaned stale hook from $STALE_BASHRC"
fi

# Write hook to all three init files
HOOK_TARGETS=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
HOOKS_WRITTEN=0

for HOOK_FILE in "${HOOK_TARGETS[@]}"; do
  # Remove any existing hooks (including old single-phase and async variants)
  if [ -f "$HOOK_FILE" ]; then
    if grep -qF "boot.sh" "$HOOK_FILE" 2>/dev/null; then
      sed -i '/# stellar-frameworks auto-heal/d' "$HOOK_FILE"
      sed -i '/boot.sh/d' "$HOOK_FILE"
    fi
    printf '\n%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_PHASE1" >> "$HOOK_FILE"
  else
    printf '%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_PHASE1" > "$HOOK_FILE"
  fi
  HOOKS_WRITTEN=$((HOOKS_WRITTEN + 1))
done

echo "[boot] Auto-heal hook written to $HOOKS_WRITTEN/3 init files (git-pull-then-boot)"

# ── 5. Post-install notice ─────────────────────────────────────
# Platform reads SKILL.md from disk on each Skill() call (NOT cached).
# So updates are effective immediately — no restart needed.

if $NEED_INSTALL; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  ☄️ v5.5.1 installed and ACTIVE — no restart needed!         ║"
  echo "║  Popup preview: LIVE on :3000 (persistent, unkillable).    ║"
  echo "║  Invoke: Skill(command=\"stellar-frameworks\")                 ║"
  echo "║  Auto-heal: two-phase hook in 3 init files.                  ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi

# ── 6. Done ──
exit 0
