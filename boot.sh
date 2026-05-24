#!/bin/bash
# stellar-frameworks — Install, self-heal (git-tracked) v5.11.0
# Pure skill installer + popup preview provider. No Next.js bootstrap.
# Self-heal: after first run, adds hook to shell init files.
# Popup preview: creates .zscripts/dev.sh AND launches it for immediate :3000 serving.
# Install:  [ -d ~/.stellar-frameworks-repo ] || git clone https://github.com/hoshiyomiX/stellar-frameworks.git ~/.stellar-frameworks-repo
#           bash ~/.stellar-frameworks-repo/boot.sh
# Invoke:  bash ~/.stellar-frameworks-repo/boot.sh [--fast]
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
#   Layer 0: Install command — conditional clone (skip if exists) + always boot
#   Layer 1: Hook (shell init) — clone-if-missing + git pull + boot --fast
#   Layer 2: Health check — if SKILL.md missing/empty after boot, reinstall
#   Layer 3: repo.tar fallback — copy from git-tracked skill/ if repo clone fails
#   Log: $HOME/.stellar-boot.log (rotated, last 500 lines)

set -euo pipefail

# ── Minimum version guard ──────────────────────────────────────────
# If the LOCAL repo's SKILL.md version is below this threshold,
# --fast mode is overridden to force git pull. This prevents stale
# snapshots (e.g. v5.3.0 baked into repo.tar) from persisting.
# Bump this whenever a new version is released.
MINIMUM_VERSION="5.11.0"

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
    *) echo "[boot] Unknown flag: $arg — ignoring" ;;
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

# ── 1. Force-sync: align repo with remote origin ─────────────────
# This repo is a managed deployment clone — NEVER has intentional local commits.
# Force-sync is safe because:
#   (1) All development happens on GitHub, clone is read-only artifact
#   (2) Platform resets can leave stale files (contamination) or diverged HEAD
#   (3) Old cautious-pull approach blocked updates on dirty state, making
#       contamination permanent until manual intervention
# Replaces v5.11.0's dirty-check + cautious pull (which caused contamination).
SELF_UPDATED=false
if [ -d "$SCRIPT_DIR/.git" ] && ! $FAST_MODE; then
  BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "main")"
  REMOTE="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")"

  if [ -n "$BRANCH" ] && [ -n "$REMOTE" ]; then
    # Snapshot boot.sh before sync to detect self-update
    BOOT_BEFORE="$(md5sum "$SCRIPT_DIR/boot.sh" 2>/dev/null | cut -d' ' -f1)"
    OLD_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"

    if git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet 2>/dev/null; then
      LOCAL="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)"
      REMOTE_SHA="$(git -C "$SCRIPT_DIR" rev-parse "origin/$BRANCH" 2>/dev/null)"

      if [ "$LOCAL" = "$REMOTE_SHA" ]; then
        echo "[boot] Repo already at latest ($OLD_VER)"
      else
        # Force-sync: discard any local state, align to remote exactly
        git -C "$SCRIPT_DIR" reset --hard "origin/$BRANCH" 2>/dev/null
        NEW_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
        BOOT_AFTER="$(md5sum "$SCRIPT_DIR/boot.sh" 2>/dev/null | cut -d' ' -f1)"
        echo "[boot] Force-synced ${OLD_VER} → ${NEW_VER} (aligned to origin/$BRANCH)"
        if [ "$BOOT_BEFORE" != "$BOOT_AFTER" ]; then
          SELF_UPDATED=true
        fi
      fi
    else
      echo "[boot] WARNING: git fetch failed — repo may be stale"
    fi
  fi

  # ── 1b. Force-sync project dir if it IS the stellar-frameworks repo ─
  # Prevents contamination in sandboxes where /home/z/my-project/ is this repo.
  # Only acts if remote URL matches — never touches unrelated project repos.
  if [ -d "$PROJECT_ROOT/.git" ]; then
    PROJECT_REMOTE="$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")"
    # Match by GitHub repo path (strip token for comparison)
    PROJECT_REPO="$(echo "$PROJECT_REMOTE" | sed 's|https://[^@]*@||;s|\.git$||')"
    EXPECTED_REPO="github.com/hoshiyomiX/stellar-frameworks"
    if [ "$PROJECT_REPO" = "$EXPECTED_REPO" ]; then
      PROJECT_BRANCH="$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "main")"
      P_LOCAL="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)"
      P_REMOTE="$(git -C "$PROJECT_ROOT" rev-parse "origin/$PROJECT_BRANCH" 2>/dev/null)"
      if [ "$P_LOCAL" != "$P_REMOTE" ] && [ -n "$P_REMOTE" ]; then
        git -C "$PROJECT_ROOT" fetch origin "$PROJECT_BRANCH" --quiet 2>/dev/null
        git -C "$PROJECT_ROOT" reset --hard "origin/$PROJECT_BRANCH" 2>/dev/null
        git -C "$PROJECT_ROOT" checkout -- . 2>/dev/null
        # Re-sync skills/ from updated project source
        cp -a "$PROJECT_ROOT/skill/stellar-frameworks" "$PROJECT_ROOT/skills/stellar-frameworks"
        cp -- "$PROJECT_ROOT/boot.sh" "$PROJECT_ROOT/skills/stellar-frameworks/boot.sh" 2>/dev/null
        echo "[boot] Project dir force-synced (was contaminated/diverged)"
      fi
    fi
  fi
fi

# Self-re-exec: if boot.sh was updated by git pull above, re-run with
# the new version so all subsequent sections use the latest code.
# Prevents the scenario where boot.sh pulls a fix but runs old code.
if $SELF_UPDATED; then
  # Re-source paths (SCRIPT_DIR may have changed if boot.sh was relocated)
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR/boot.sh")" && pwd)"
  echo "[boot] Re-executing with updated boot.sh..."
  exec bash "$SCRIPT_DIR/boot.sh" "$@"
fi

# ── 2. Install / self-heal: copy skill/ → skills/ ──
# Uses cp -a instead of symlink. Symlinks break on restore because:
#   (1) repo.tar stores symlink but target may not exist after restore
#   (2) git add fails on symlinks ("pathspec beyond symbolic link")
#   (3) .gitignore excludes skills/ — git tracking is impossible
# With real files in skills/, the platform's repo.tar captures them on pre-stop.
# On restore, files exist immediately — no hook timing dependency.
# Update detection: compare SKILL.md version strings (source vs installed).
NEED_INSTALL=false
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/SKILL.md" ] && [ -s "$INSTALL_DIR/SKILL.md" ]; then
  INSTALLED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  SOURCE_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if [ "$INSTALLED_VER" = "$SOURCE_VER" ]; then
    NEED_INSTALL=false
    echo "[boot] Skill files OK (v$INSTALLED_VER)"
  else
    NEED_INSTALL=true
    echo "[boot] Version update: $INSTALLED_VER → $SOURCE_VER"
  fi
elif [ -L "$INSTALL_DIR" ]; then
  # Legacy symlink from v5.4.4–v5.11.1 — replace with real copy
  NEED_INSTALL=true
  echo "[boot] Legacy symlink detected — replacing with real copy"
else
  NEED_INSTALL=true
  echo "[boot] skills/ not found — installing"
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
  echo "[boot] Installing skill files → skills/ (copy)"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  rm -rf "${INSTALL_DIR:?}"
  cp -a "$SOURCE_DIR" "$INSTALL_DIR"

  # Copy boot.sh into skills/ so it's co-located with SKILL.md.
  # This makes boot.sh discoverable in ALL sandboxes where skills/ exists,
  # even when the project root is a different repo (not stellar-frameworks).
  cp -- "$SCRIPT_DIR/boot.sh" "$INSTALL_DIR/boot.sh"

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
    boot.sh \
    CHANGELOG.md; do
    if [ -f "$INSTALL_DIR/$f" ]; then
      : # OK
    else
      echo "[boot] WARNING: $f MISSING"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $ERRORS -eq 0 ]; then
    INSTALLED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "?")"
    echo "[boot] Installed successfully (copy: v$INSTALLED_VER)"
  else
    echo "[boot] WARNING: installed with $ERRORS missing file(s)"
  fi
else
  echo "[boot] Skill files OK"
fi

# ── 3. Popup preview: ensure landing page + dev server ──────────────
mkdir -p "$DOWNLOAD_DIR"

# Always ensure index.html exists — even if dev.sh is already running
# on :3000 from a previous session. The port guard in dev.sh prevents
# re-launch, but the file may have been lost (e.g. download/ wiped).
if [ ! -f "$DOWNLOAD_DIR/index.html" ]; then
  cat > "$DOWNLOAD_DIR/index.html" << 'SPLASH'
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
  echo "[boot] Landing page created"
else
  echo "[boot] Landing page OK"
fi

# Ensure .zscripts/dev.sh exists
DEV_SCRIPT_MARKER="# stellar-frameworks dev server"

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
  while true; do
    cd /home/z/my-project/download && python3 -m http.server 3000
    sleep 1
  done
fi
DEVSH
  chmod +x "$DEV_SCRIPT"
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
  echo "║  ☄️ v5.11.0 installed and ACTIVE — no restart needed!        ║"
  echo "║  Popup preview: LIVE on :3000 (persistent, unkillable).    ║"
  echo "║  Invoke: Skill(command=\"stellar-frameworks\")                 ║"
  echo "║  Repo: $TARGET_DIR"
  echo "║  Auto-heal: hook in 3 init files + health check + log.     ║"
  echo "║  Log: $BOOT_LOG                                          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi

exit 0
