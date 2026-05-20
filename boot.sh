#!/bin/bash
# stellar-frameworks — Install, self-heal (git-tracked) v5.9.0
# Pure skill installer + popup preview provider. No Next.js bootstrap.
# Self-heal: after first run, adds hook to shell init files.
# Popup preview: creates .zscripts/dev.sh AND launches it for immediate :3000 serving.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/hoshiyomiX/stellar-frameworks/main/boot.sh)
#    or: bash ~/.stellar-frameworks-repo/boot.sh
#    or: bash stellar-frameworks/boot.sh [--install-only] [--fast]
#
# Flags:
#   --fast         Skip git operations (pure local copy ~50ms). Used by hook.
#                   OVERridden if local repo version < MINIMUM_VERSION (stale snapshot).
#   --install-only Accepted for compatibility; no-op since v5.4.4.
#
# Path architecture (v5.9.0):
#   GIT_REPO   = $HOME/.stellar-frameworks-repo   (survives project resets)
#   INSTALL    = $PROJECT_ROOT/skills/stellar-frameworks  (platform load path)
#   Hook lives in $HOME init files (survives project resets)
#   If repo is missing, hook auto-clones from GitHub before booting.
#
# Resilience layers (v5.9.1):
#   Layer 1: Hook (shell init) — clone-if-missing + git pull + boot --fast
#   Layer 2: Health check — if SKILL.md missing/empty after boot, force reinstall
#   Layer 3: repo.tar fallback — copy from git-tracked skill/ if repo clone fails
#   Log: $HOME/.stellar-boot.log (rotated, last 500 lines)

set -euo pipefail

# ── Minimum version guard ──────────────────────────────────────────
# If the LOCAL repo's SKILL.md version is below this threshold,
# --fast mode is overridden to force git pull. This prevents stale
# snapshots (e.g. v5.3.0 baked into repo.tar) from persisting.
# Bump this whenever a new version is released.
MINIMUM_VERSION="5.9.0"

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

# ── 0. Path configuration ──────────────────────────────────────────
REPO_URL="https://github.com/hoshiyomiX/stellar-frameworks.git"
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
# v5.8.0+: repo lives in $HOME, not inside project dir.
# This survives platform resets that wipe /home/z/my-project/.
TARGET_DIR="${STELLAR_REPO_PATH:-$HOME/.stellar-frameworks-repo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If boot.sh is running from a location OTHER than the repo (e.g. old path),
# redirect to the canonical repo location.
if [ "$(basename "$SCRIPT_DIR")" != ".stellar-frameworks-repo" ] && \
   [ "$(basename "$SCRIPT_DIR")" != "stellar-frameworks" ]; then
  SCRIPT_DIR="$TARGET_DIR"
fi

SOURCE_DIR="$SCRIPT_DIR/skill/stellar-frameworks"
INSTALL_DIR="$PROJECT_ROOT/skills/stellar-frameworks"
OBSOLETE_DIR="$PROJECT_ROOT/skills/stellar-coding-agent"
ZSCRIPTS="$PROJECT_ROOT/.zscripts"
DEV_SCRIPT="$ZSCRIPTS/dev.sh"
DOWNLOAD_DIR="$PROJECT_ROOT/download"
BOOT_LOG="$HOME/.stellar-boot.log"

# ── 0a. Auto-clone: ensure repo exists ─────────────────────────────
OLD_REPO_DIR="$PROJECT_ROOT/stellar-frameworks"

if [ ! -d "$TARGET_DIR/.git" ]; then
  if [ -d "$OLD_REPO_DIR/.git" ]; then
    echo "[boot] Migrating repo: $OLD_REPO_DIR → $TARGET_DIR"
    mkdir -p "$HOME"
    mv "$OLD_REPO_DIR" "$TARGET_DIR"
    SCRIPT_DIR="$TARGET_DIR"
    SOURCE_DIR="$TARGET_DIR/skill/stellar-frameworks"
  else
    echo "[boot] Repo not found — cloning from GitHub..."
    mkdir -p "$HOME"
    git clone "$REPO_URL" "$TARGET_DIR" 2>/dev/null || {
      echo "[boot] ERROR: git clone failed. Check network or run manually:"
      echo "  git clone $REPO_URL $TARGET_DIR"
      exit 1
    }
    echo "[boot] Cloned successfully"
    SCRIPT_DIR="$TARGET_DIR"
    SOURCE_DIR="$TARGET_DIR/skill/stellar-frameworks"
  fi
elif [ "$(basename "$SCRIPT_DIR")" != ".stellar-frameworks-repo" ]; then
  SCRIPT_DIR="$TARGET_DIR"
  SOURCE_DIR="$TARGET_DIR/skill/stellar-frameworks"
fi

# ── 0b. Stale snapshot override ───────────────────────────────────
if $FAST_MODE && [ -f "$SOURCE_DIR/SKILL.md" ]; then
  LOCAL_REPO_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if version_lt "$LOCAL_REPO_VER" "$MINIMUM_VERSION"; then
    echo "[boot] Local repo $LOCAL_REPO_VER < minimum $MINIMUM_VERSION — overriding --fast"
    FAST_MODE=false
  fi
fi

# ── 1. Auto-update: pull if remote has newer skill files ──────────
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
            OLD_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
            if git -C "$SCRIPT_DIR" pull --ff-only --quiet origin "$BRANCH" 2>/dev/null; then
              NEW_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
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

# ── 2. Install / self-heal: symlink skill/ → skills/ ──
# Uses symlink instead of copy. This means skills/ always reflects the
# git-tracked source (skill/) — including after git push updates.
# Detects: missing, empty, stale user_skills extract, broken symlink.
NEED_INSTALL=false
INSTALL_IS_SYMLINK=false
if [ -L "$INSTALL_DIR" ]; then
  # Already a symlink — check if it points to the correct target
  CURRENT_TARGET="$(readlink -f "$INSTALL_DIR" 2>/dev/null || echo "")"
  EXPECTED_TARGET="$(readlink -f "$SOURCE_DIR" 2>/dev/null || echo "")"
  if [ "$CURRENT_TARGET" = "$EXPECTED_TARGET" ]; then
    INSTALL_IS_SYMLINK=true
    NEED_INSTALL=false
  else
    NEED_INSTALL=true
    echo "[boot] Symlink points to wrong target ($CURRENT_TARGET) — reinstalling"
  fi
elif [ -d "$INSTALL_DIR" ]; then
  # Regular directory (stale user_skills extract or old cp-based install)
  if [ -f "$INSTALL_DIR/SKILL.md" ] && [ -s "$INSTALL_DIR/SKILL.md" ]; then
    echo "[boot] Replacing stale directory with symlink"
  else
    echo "[boot] Corrupt install directory — replacing with symlink"
  fi
  NEED_INSTALL=true
else
  NEED_INSTALL=true
  echo "[boot] skills/ not found — creating symlink"
fi

# Clean up predecessor skill (stellar-coding-agent v5.0.0)
if [ -d "$OBSOLETE_DIR" ]; then
  rm -rf "${OBSOLETE_DIR:?}"
  echo "[boot] Removed predecessor skill: stellar-coding-agent"
fi

if $NEED_INSTALL; then
  if [ ! -d "$SOURCE_DIR" ] || [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
    # Fallback: try repo.tar source (git-tracked skill/ in project root)
    TARBALL_SOURCE="$PROJECT_ROOT/skill/stellar-frameworks"
    if [ -d "$TARBALL_SOURCE" ] && [ -f "$TARBALL_SOURCE/SKILL.md" ]; then
      echo "[boot] Repo source unavailable — falling back to repo.tar source (skill/)"
      SOURCE_DIR="$TARBALL_SOURCE"
    else
      echo "[boot] ERROR: skill/ not found in repo or project dir"
      exit 1
    fi
  fi
  echo "[boot] Installing skill files → skills/ (symlink)"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  rm -rf "${INSTALL_DIR:?}"
  ln -s "$SOURCE_DIR" "$INSTALL_DIR"

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
    echo "[boot] Installed successfully (symlink: skills/ → skill/)"
  else
    echo "[boot] WARNING: installed with $ERRORS missing file(s)"
  fi
else
  echo "[boot] Skill files OK"
fi

# ── 3. Popup preview: ensure .zscripts/dev.sh exists ──────────────
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

if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ':3000 '; then
  echo "[dev.sh] Port :3000 already in use — not starting" >&2
  exit 0
fi

if [ -f /home/z/my-project/package.json ] \
   && grep -q '"next"' /home/z/my-project/package.json 2>/dev/null; then
  while true; do
    cd /home/z/my-project && bun run dev
    sleep 2
  done
else
  mkdir -p /home/z/my-project/download
  # Ensure landing page exists (auto-healed each boot)
  if [ ! -f /home/z/my-project/download/index.html ]; then
    cat > /home/z/my-project/download/index.html << 'SPLASH'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Stellar Frameworks</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
  background:#0a0a0f;color:#e4e4e7;display:flex;align-items:center;justify-content:center;min-height:100vh}
.container{text-align:center;padding:2rem;max-width:420px}
.emoji{font-size:3.5rem;margin-bottom:1.5rem;filter:drop-shadow(0 0 20px rgba(139,92,246,0.4))}
h1{font-size:1.35rem;font-weight:600;color:#f4f4f5;margin-bottom:0.5rem;letter-spacing:-0.01em}
p{font-size:0.875rem;color:#71717a;line-height:1.6;margin-bottom:1.5rem}
.badge{display:inline-flex;align-items:center;gap:0.4rem;padding:0.3rem 0.7rem;
  border:1px solid #27272a;border-radius:9999px;font-size:0.75rem;color:#a1a1aa}
.badge .dot{width:6px;height:6px;border-radius:50%;background:#34d399;animation:pulse 2s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}}
</style>
</head>
<body>
<div class="container">
  <div class="emoji">☄️</div>
  <h1>Welcome to Stellar Frameworks</h1>
  <p>Phase State Machine &middot; Traceability IDs &middot; Adaptive Complexity<br>Send a message to start building.</p>
  <div class="badge"><span class="dot"></span> Dev server running</div>
</div>
</body>
</html>
SPLASH
  fi
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
BASHRC_MARKER="# stellar-frameworks auto-heal"
BOOT_LOG="$HOME/.stellar-boot.log"
BASHRC_PHASE1="BOOT_LOG=$HOME/.stellar-boot.log; mkdir -p $HOME; [ -d $TARGET_DIR/.git ] || git clone $REPO_URL $TARGET_DIR 2>/dev/null; (cd $TARGET_DIR && git pull --ff-only --quiet 2>/dev/null); bash $TARGET_DIR/boot.sh --fast --install-only >>$BOOT_LOG 2>&1; [ -s $PROJECT_ROOT/skills/stellar-frameworks/SKILL.md ] || bash $TARGET_DIR/boot.sh >>$BOOT_LOG 2>&1; tail -500 $BOOT_LOG > $BOOT_LOG.tmp && mv $BOOT_LOG.tmp $BOOT_LOG 2>/dev/null || true"

# Clean up stale hook from wrong path (v5.4.1 bug)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
if [ -f "$STALE_BASHRC" ] && grep -qF "$BASHRC_MARKER" "$STALE_BASHRC" 2>/dev/null; then
  sed -i '/# stellar-frameworks auto-heal/d' "$STALE_BASHRC"
  sed -i '/boot.sh/d' "$STALE_BASHRC"
  [ ! -s "$STALE_BASHRC" ] && rm -f "$STALE_BASHRC"
  echo "[boot] Cleaned stale hook from $STALE_BASHRC"
fi

HOOK_TARGETS=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
HOOKS_WRITTEN=0

for HOOK_FILE in "${HOOK_TARGETS[@]}"; do
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

echo "[boot] Auto-heal hook written to $HOOKS_WRITTEN/3 init files (clone + pull + boot + health-check + log)"

if $NEED_INSTALL; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  ☄️ v5.9.0 installed and ACTIVE — no restart needed!         ║"
  echo "║  Popup preview: LIVE on :3000 (persistent, unkillable).    ║"
  echo "║  Invoke: Skill(command=\"stellar-frameworks\")                 ║"
  echo "║  Repo: $TARGET_DIR"
  echo "║  Auto-heal: hook in 3 init files + health check + log.     ║"
  echo "║  Log: $BOOT_LOG                                          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi

exit 0
