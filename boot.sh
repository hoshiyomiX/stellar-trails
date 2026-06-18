#!/bin/bash
# stellar-frameworks — Install, self-heal (git-tracked) v6.2.0
# Pure skill installer + popup preview provider. No Next.js bootstrap.
# Self-heal: after first run, adds hook to shell init files.
# Popup preview: creates .zscripts/dev.sh AND launches it for immediate :3000 serving.
# Install:  [ -d ~/.stellar-frameworks-repo ] || git clone https://github.com/hoshiyomiX/stellar-frameworks.git ~/.stellar-frameworks-repo
#           bash ~/.stellar-frameworks-repo/boot.sh
# Invoke:  bash ~/.stellar-frameworks-repo/boot.sh [--fast] [--offline] [--clean]
#
# Flags:
#   --fast         Skip file copy if already installed and version matches.
#                   Does NOT skip upstream check — upstream is ALWAYS probed.
#   --offline      Skip upstream check entirely (no git fetch). For air-gapped
#                   environments. Overrides --fast behavior to pure local.
#   --clean        Nuke ALL generated files before install (skills/, .zscripts/,
#                   dev.sh, hooks). Full uninstall + reinstall.
#   --install-only Accepted for compatibility; no-op since v5.4.4.
#
# Upstream guarantee (v6.1.0):
#   Every invocation checks remote for updates via git fetch (~200ms).
#   If remote has new commits, force-sync + reinstall happens regardless of --fast.
#   --fast only skips file copy when already at latest version.
#   Use --offline to truly skip all network operations.
#
# Path architecture (v5.9.0):
#   GIT_REPO   = $HOME/.stellar-frameworks-repo   (survives project resets)
#   INSTALL    = $PROJECT_ROOT/skills/stellar-frameworks  (platform load path)
#   Hook lives in $HOME init files (survives project resets)
#   If repo is missing, hook auto-clones from GitHub before booting.
#
# Resilience layers (v6.1.0):
#   Layer 0: Install command — conditional clone (skip if exists) + always boot
#   Layer 1: Hook (shell init) — clone-if-missing + boot.sh --fast (upstream check built-in)
#   Layer 2: Health check — if SKILL.md missing/empty after boot, reinstall
#   Layer 3: repo.tar fallback — copy from git-tracked skill/ if repo clone fails
#   Log: $HOME/.stellar-boot.log (rotated, last 500 lines)

set -euo pipefail

# ── Minimum version guard ──────────────────────────────────────────
# If the LOCAL repo's SKILL.md version is below this threshold,
# --fast mode is overridden to force git pull. This prevents stale
# snapshots (e.g. v5.3.0 baked into repo.tar) from persisting.
# Bump this whenever a new version is released.
MINIMUM_VERSION="6.1.0"

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
CLEAN_MODE=false
OFFLINE_MODE=false
for arg in "$@"; do
  case "$arg" in
    --fast) FAST_MODE=true ;;
    --clean) CLEAN_MODE=true ;;
    --offline) OFFLINE_MODE=true ;;
    --install-only) : ;; # no-op: kept for backwards compatibility
    *) ;; # ignore unknown flags (forwarded via self-re-exec if boot.sh was stale)
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
# When boot.sh is co-located in skills/ (not the repo), it IS the source.
# skills/stellar-frameworks/ is a copy of skill/stellar-frameworks/ — no /skill/ sub-dir.
if [ ! -d "$SOURCE_DIR" ] && [ -f "$SCRIPT_DIR/SKILL.md" ]; then
  SOURCE_DIR="$SCRIPT_DIR"
fi
INSTALL_DIR="$PROJECT_ROOT/skills/stellar-frameworks"
OBSOLETE_DIR="$PROJECT_ROOT/skills/stellar-coding-agent"
ZSCRIPTS="$PROJECT_ROOT/.zscripts"
DEV_SCRIPT="$ZSCRIPTS/dev.sh"
DOWNLOAD_DIR="$PROJECT_ROOT/download"
BOOT_LOG="$HOME/.stellar-boot.log"

# ── 0-pre. Clean mode: nuke ALL generated files ───────────────────
# --clean removes everything boot.sh has ever created, then reinstall.
# Use when contamination is suspected or a fresh start is needed.
if $CLEAN_MODE; then
  echo "[boot] CLEAN MODE — nuking all generated files"
  # Kill dev server if running (aggressive — -9 to ensure death)
  if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      kill -9 "$pid" 2>/dev/null || true
    done
    sleep 0.5
    # Second pass — kill anything that survived
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      kill -9 "$pid" 2>/dev/null || true
    done
  fi
  # Remove skill install
  rm -rf "${INSTALL_DIR:?}" 2>/dev/null
  echo "[boot] Removed skills/stellar-frameworks/"
  # Remove popup preview files from old location (download/)
  rm -f "$DOWNLOAD_DIR/index.html" "$DOWNLOAD_DIR/chibi.png" 2>/dev/null
  # Remove popup preview files from current location (.zscripts/)
  rm -f "$ZSCRIPTS/index.html" "$ZSCRIPTS/chibi.png" 2>/dev/null
  echo "[boot] Removed popup preview files (download/ + .zscripts/)"
  # Remove managed dev.sh (only if it has our marker)
  if [ -f "$DEV_SCRIPT" ] && grep -qF "# stellar-frameworks dev server" "$DEV_SCRIPT" 2>/dev/null; then
    rm -f "$DEV_SCRIPT"
    echo "[boot] Removed .zscripts/dev.sh"
  fi
  # Remove hooks from init files
  for HOOK_FILE in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$HOOK_FILE" ] && grep -qF "stellar-frameworks" "$HOOK_FILE" 2>/dev/null; then
      sed -i '/# stellar-frameworks auto-heal/d' "$HOOK_FILE"
      sed -i '/stellar-frameworks.*boot\.sh/d' "$HOOK_FILE"
      sed -i '/stellar-frameworks-repo/d' "$HOOK_FILE"
      [ ! -s "$HOOK_FILE" ] && rm -f "$HOOK_FILE"
    fi
  done
  echo "[boot] Removed hooks from init files"
  # Remove predecessor
  rm -rf "${OBSOLETE_DIR:?}" 2>/dev/null
  # Remove stale skill/ (singular) from pre-v5.8.0 installs
  rm -rf "${PROJECT_ROOT:?}/skill" 2>/dev/null
  # Remove boot log
  rm -f "$BOOT_LOG" 2>/dev/null
  echo "[boot] Nuke complete — proceeding with fresh install"
fi

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

# ── 0b. Stale install cleanup ──────────────────────────────────
# v6.2.0: Remove legacy skill/ (singular) dir from pre-v5.8.0 installs.
# Also remove chibi.png from skills/ (moved to .zscripts/ in v6.2.0).
# Also clean up download/ popup artifacts from v6.0.0–v6.1.0.
STALE_SKILL_DIR="$PROJECT_ROOT/skill/stellar-frameworks"
if [ -d "$STALE_SKILL_DIR" ]; then
  rm -rf "${STALE_SKILL_DIR:?}"
  # Remove empty parent if nothing else in it
  rmdir "$PROJECT_ROOT/skill" 2>/dev/null || true
  echo "[boot] Removed stale skill/ (singular) install"
fi
# Remove chibi.png from skills/ if present (no longer needed there)
if [ -f "$INSTALL_DIR/chibi.png" ]; then
  rm -f "$INSTALL_DIR/chibi.png"
fi
# Remove old popup files from download/ (now live in .zscripts/)
rm -f "$DOWNLOAD_DIR/index.html" "$DOWNLOAD_DIR/chibi.png" 2>/dev/null

# (handled by 0d upstream probe — versions below MINIMUM_VERSION will
#  trigger force-sync when remote is checked)

# ── 0d. Upstream probe: ALWAYS check for remote updates ─────────
# v6.1.0: This is the core upstream guarantee. Every boot.sh invocation
# probes the remote for new commits (~200ms). If behind, force-sync and
# reinstall regardless of --fast. --offline skips this entirely.
#
# Why unconditional: --fast used to skip git fetch entirely, meaning
# new skill versions would never arrive until manual intervention.
# The fix: always fetch, only skip file-copy when already current.
#
# CRITICAL: Before force-sync, check for unpushed local commits.
# This prevents the self-destruction bug where boot.sh running from
# its own repo would reset --hard and lose unpushed work.
#
# Result flags:
#   UPSTREAM_CURRENT=true  → local matches remote, no sync needed
#   UPSTREAM_CURRENT=false → remote has new commits, force-sync required
UPSTREAM_CURRENT=true
SELF_UPDATED=false

if ! $OFFLINE_MODE && [ -d "$SCRIPT_DIR/.git" ]; then
  BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "main")"
  REMOTE_URL="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")"

  if [ -n "$BRANCH" ] && [ -n "$REMOTE_URL" ]; then
    if git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet 2>/dev/null; then
      LOCAL_SHA="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)"
      REMOTE_SHA="$(git -C "$SCRIPT_DIR" rev-parse "origin/$BRANCH" 2>/dev/null)"

      if [ "$LOCAL_SHA" != "$REMOTE_SHA" ] && [ -n "$REMOTE_SHA" ]; then
        # Check for unpushed local commits BEFORE force-sync
        UNPUSHED="$(git -C "$SCRIPT_DIR" log --oneline "origin/$BRANCH..HEAD" 2>/dev/null)"
        if [ -n "$UNPUSHED" ]; then
          echo "[boot] WARNING: ${LOCAL_SHA:0:7} has unpushed commits — skipping force-sync to prevent data loss"
          echo "[boot]   (push your commits first, or use --offline to suppress this check)"
          echo "[boot]   Unpushed:"
          echo "$UNPUSHED" | head -3 | while read -r line; do echo "[boot]     $line"; done
          UPSTREAM_CURRENT=false
        else
          UPSTREAM_CURRENT=false
          OLD_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
          BOOT_BEFORE="$(md5sum "$SCRIPT_DIR/boot.sh" 2>/dev/null | cut -d' ' -f1)"

          # Force-sync: discard any local state, align to remote exactly
          git -C "$SCRIPT_DIR" reset --hard "origin/$BRANCH" 2>/dev/null

          NEW_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
          BOOT_AFTER="$(md5sum "$SCRIPT_DIR/boot.sh" 2>/dev/null | cut -d' ' -f1)"
          echo "[boot] Upstream update: ${OLD_VER} → ${NEW_VER} (force-synced)"

          if [ "$BOOT_BEFORE" != "$BOOT_AFTER" ]; then
            SELF_UPDATED=true
          fi
        fi
      else
        OLD_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
        echo "[boot] Upstream current ($OLD_VER)"
      fi
    else
      echo "[boot] WARNING: git fetch failed — skipping upstream check"
    fi
  fi
fi

# ── 0c. Submodule purge: prevent git submodule contamination ──────
# Submodules in the project repo break Stellar Frameworks commit protocol
# (VERIFY/DELIVER phases) with "staged but uncommitted" errors, and can
# cause non-fast-forward push failures when parent and submodule share the
# same remote (double-push problem).
# In z.ai sandboxes, submodules are NEVER intentional — they are artifacts
# from platform resets, tool contamination, or misconfigured clones.
# Safety: only acts on PROJECT_ROOT, never touches TARGET_DIR (stellar repo).
if [ -d "$PROJECT_ROOT/.git" ]; then
  # Check for submodule contamination (tracked or untracked)
  HAS_GITMODULES=false
  HAS_STAGE_160000=false

  if [ -f "$PROJECT_ROOT/.gitmodules" ]; then
    HAS_GITMODULES=true
  fi
  if git -C "$PROJECT_ROOT" ls-files --stage 2>/dev/null | grep -q '^160000 '; then
    HAS_STAGE_160000=true
  fi

  if $HAS_GITMODULES || $HAS_STAGE_160000; then
    # Verify this is NOT the stellar-frameworks repo itself
    PROJECT_REMOTE="$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")"
    PROJECT_REPO="$(echo "$PROJECT_REMOTE" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
    EXPECTED_REPO="github.com/hoshiyomiX/stellar-frameworks"

    if [ "$PROJECT_REPO" != "$EXPECTED_REPO" ]; then
      echo "[boot] Submodule contamination detected in project repo — purging"
      # Log what we found
      SUB_COUNT=0
      if $HAS_STAGE_160000; then
        SUB_COUNT="$(git -C "$PROJECT_ROOT" ls-files --stage 2>/dev/null | grep '^160000 ' | wc -l)"
      fi
      echo "[boot] Found ${SUB_COUNT} submodule(s) + .gitmodules file"

      # Detect submodules sharing parent's remote (critical bug)
      if [ -f "$PROJECT_ROOT/.gitmodules" ] && [ -n "$PROJECT_REMOTE" ]; then
        while IFS= read -r line; do
          if echo "$line" | grep -qP '^\s*url\s*='; then
            SUB_URL="$(echo "$line" | grep -oP '=\s*\K.*' | tr -d ' "')"
            SUB_REPO="$(echo "$SUB_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
            if [ "$SUB_REPO" = "$PROJECT_REPO" ]; then
              echo "[boot] WARNING: submodule shares parent remote (${SUB_REPO}) — double-push bug"
            fi
          fi
        done < "$PROJECT_ROOT/.gitmodules"
      fi

      # Deinit all submodules (clean worktrees)
      git -C "$PROJECT_ROOT" submodule deinit --all --force 2>/dev/null || true
      # Remove .gitmodules tracking
      git -C "$PROJECT_ROOT" rm -f --cached '.gitmodules' 2>/dev/null || true
      rm -f "$PROJECT_ROOT/.gitmodules"
      # Clean up .git/modules/ cache
      rm -rf "$PROJECT_ROOT/.git/modules/" 2>/dev/null || true
      # Remove submodule directories from working tree AND git index
      if $HAS_STAGE_160000; then
        git -C "$PROJECT_ROOT" ls-files --stage 2>/dev/null | grep '^160000 ' | awk '{print $4}' | while read -r mod; do
          # Remove from git index
          git -C "$PROJECT_ROOT" rm -f --cached "$mod" 2>/dev/null || true
          # Remove directory (only if it looks like a submodule, not user code)
          if [ -d "$PROJECT_ROOT/$mod/.git" ] || [ -f "$PROJECT_ROOT/$mod/.git" ]; then
            rm -rf "$PROJECT_ROOT/$mod" 2>/dev/null || true
          fi
        done
      fi
      # Remove any empty .git file left behind (gitlink marker)
      find "$PROJECT_ROOT" -maxdepth 3 -name '.git' -type f -exec rm -f {} \; 2>/dev/null || true
      echo "[boot] Submodules purged — project repo is clean"
    fi
  fi
fi

# ── 1. Force-sync project dir if it IS the stellar-frameworks repo ──
# Prevents contamination in sandboxes where /home/z/my-project/ is this repo.
# Only acts if remote URL matches — never touches unrelated project repos.
# Note: The stellar-frameworks repo itself was already synced in Section 0d.
if [ -d "$PROJECT_ROOT/.git" ]; then
  PROJECT_REMOTE="$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")"
  # Match by GitHub repo path (strip token for comparison)
  PROJECT_REPO="$(echo "$PROJECT_REMOTE" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
  EXPECTED_REPO="github.com/hoshiyomiX/stellar-frameworks"
  if [ "$PROJECT_REPO" = "$EXPECTED_REPO" ]; then
    PROJECT_BRANCH="$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "main")"
    P_LOCAL="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)"
    P_REMOTE="$(git -C "$PROJECT_ROOT" rev-parse "origin/$PROJECT_BRANCH" 2>/dev/null)"
    if [ "$P_LOCAL" != "$P_REMOTE" ] && [ -n "$P_REMOTE" ]; then
      # Check for unpushed commits before force-sync
      P_UNPUSHED="$(git -C "$PROJECT_ROOT" log --oneline "origin/$PROJECT_BRANCH..HEAD" 2>/dev/null)"
      if [ -z "$P_UNPUSHED" ]; then
        git -C "$PROJECT_ROOT" fetch origin "$PROJECT_BRANCH" --quiet 2>/dev/null
        git -C "$PROJECT_ROOT" reset --hard "origin/$PROJECT_BRANCH" 2>/dev/null
        git -C "$PROJECT_ROOT" checkout -- . 2>/dev/null
        # Re-sync skills/ from updated project source
        cp -a "$PROJECT_ROOT/skill/stellar-frameworks" "$PROJECT_ROOT/skills/stellar-frameworks"
        cp -- "$PROJECT_ROOT/boot.sh" "$PROJECT_ROOT/skills/stellar-frameworks/boot.sh" 2>/dev/null
        echo "[boot] Project dir force-synced (was contaminated/diverged)"
      else
        echo "[boot] WARNING: project dir has unpushed commits — skipping force-sync"
      fi
    fi
  fi
fi

# Self-re-exec: if boot.sh was updated by upstream sync in Section 0d,
# re-run with the new version so all subsequent sections use latest code.
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
#
# v6.1.0 install logic:
#   If upstream had updates (UPSTREAM_CURRENT=false): ALWAYS force-copy
#   If --fast AND upstream current AND installed: version-comparison (skip if same)
#   Otherwise (normal mode or not installed): ALWAYS force-copy
NEED_INSTALL=false

if $UPSTREAM_CURRENT && $FAST_MODE && [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/SKILL.md" ] && [ -s "$INSTALL_DIR/SKILL.md" ]; then
  # Fast path: upstream is current, --fast requested, and skills/ exists
  INSTALLED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  SOURCE_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if [ "$INSTALLED_VER" = "$SOURCE_VER" ]; then
    NEED_INSTALL=false
    echo "[boot] Skill files OK (v$INSTALLED_VER, upstream current, --fast skip)"
  else
    NEED_INSTALL=true
    echo "[boot] Version update: $INSTALLED_VER → $SOURCE_VER"
  fi
else
  NEED_INSTALL=true
  if ! $UPSTREAM_CURRENT; then
    echo "[boot] Force-reinstalling skill files (upstream update detected)"
  elif [ -L "$INSTALL_DIR" ]; then
    echo "[boot] Legacy symlink detected — replacing with real copy"
  elif [ -d "$INSTALL_DIR" ]; then
    echo "[boot] Force-copying skill files (normal mode — ensures content freshness)"
  else
    echo "[boot] skills/ not found — installing"
  fi
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
    # Remove popup assets from skills/ — they live in .zscripts/ (v6.2.0)
    rm -f "$INSTALL_DIR/chibi.png"
    echo "[boot] Installed successfully (copy: v$INSTALLED_VER)"
  else
    echo "[boot] WARNING: installed with $ERRORS missing file(s)"
  fi
else
  echo "[boot] Skill files OK"
fi

# ── 3. Popup preview: ensure landing page + dev server ──────────────
# v6.2.0: Popup assets live in .zscripts/ (hidden from platform file scanner),
# NOT in download/ (user output dir) or skills/ (LLM context dir).
# This prevents chibi.png (1.2 MB) and index.html from polluting
# "All files in task" and wasting context tokens.
mkdir -p "$ZSCRIPTS"

# Copy chibi mascot image to .zscripts/ (popup-only artifact)
if [ -f "$SOURCE_DIR/chibi.png" ]; then
  cp -- "$SOURCE_DIR/chibi.png" "$ZSCRIPTS/chibi.png"
  echo "[boot] Chibi mascot copied"
fi

# Always overwrite index.html in .zscripts/ — popup-only artifact.
cat > "$ZSCRIPTS/index.html" << 'SPLASH'
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
.chibi-wrap{display:inline-block;margin-bottom:1.5rem}
.chibi-img{height:180px;width:auto;
  filter:drop-shadow(0 0 24px rgba(139,92,246,0.25)) drop-shadow(0 4px 16px rgba(0,0,0,0.4));
  animation:float 4s ease-in-out infinite}
@keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-8px)}}
h1{font-size:1.35rem;font-weight:600;color:#f4f4f5;margin-bottom:0.35rem;letter-spacing:-0.01em}
.version{font-size:0.7rem;color:#71717a;margin-bottom:1rem;letter-spacing:0.04em}
p{font-size:0.875rem;color:#71717a;line-height:1.6;margin-bottom:1.5rem}
p span{color:#a78bfa}
.badge{display:inline-flex;align-items:center;gap:0.4rem;padding:0.3rem 0.7rem;
  border:1px solid #27272a;border-radius:9999px;font-size:0.75rem;color:#a1a1aa}
.badge .dot{width:6px;height:6px;border-radius:50%;background:#34d399;animation:pulse 2s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}}
</style>
</head>
<body>
<div class="container">
  <div class="chibi-wrap">
    <img class="chibi-img" src="chibi.png" alt="Stellar Frameworks mascot"
         loading="eager"
         onerror="this.style.display='none';this.nextElementSibling.style.display='block'">
    <div style="display:none;font-size:3.5rem;filter:drop-shadow(0 0 20px rgba(139,92,246,0.4))">&#9732;&#65039;</div>
  </div>
  <h1>Welcome to Stellar Frameworks</h1>
  <div class="version">v6.2.0</div>
  <p><span>Phase State Machine</span> &middot; Traceability IDs &middot; Adaptive Complexity<br>Send a message to start building.</p>
  <div class="badge"><span class="dot"></span> Dev server running</div>
</div>
</body>
</html>
SPLASH
echo "[boot] Landing page created"

# Ensure .zscripts/dev.sh exists and is up-to-date
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

# Detect actual Next.js project (next.config.js/mjs must exist — just having
# 'next' in package.json is not enough, e.g. Android apps with NextAuth dep)
if [ -f /home/z/my-project/next.config.js ] || [ -f /home/z/my-project/next.config.mjs ] || [ -f /home/z/my-project/next.config.ts ]; then
  while true; do
    cd /home/z/my-project && bun run dev
    sleep 2
  done
else
    mkdir -p /home/z/my-project/.zscripts
    while true; do
      cd /home/z/my-project/.zscripts && python3 -m http.server 3000
      sleep 1
    done
fi
DEVSH
  chmod +x "$DEV_SCRIPT"
  echo "[boot] dev.sh created"
elif ! grep -qF "$DEV_SCRIPT_MARKER" "$DEV_SCRIPT" 2>/dev/null; then
  echo "[boot] dev.sh already exists (external) — keeping it"
else
  # Managed dev.sh exists but may be outdated — always overwrite in normal mode
  if $FAST_MODE; then
    echo "[boot] dev.sh OK (managed by stellar-frameworks, --fast skip)"
  else
    echo "[boot] Overwriting dev.sh (managed, normal mode — ensures content freshness)"
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

# Detect actual Next.js project (next.config.js/mjs must exist)
if [ -f /home/z/my-project/next.config.js ] || [ -f /home/z/my-project/next.config.mjs ] || [ -f /home/z/my-project/next.config.ts ]; then
  while true; do
    cd /home/z/my-project && bun run dev
    sleep 2
  done
else
    mkdir -p /home/z/my-project/.zscripts
    while true; do
      cd /home/z/my-project/.zscripts && python3 -m http.server 3000
      sleep 1
    done
fi
DEVSH
    chmod +x "$DEV_SCRIPT"
  fi
fi

if [ -f "$DEV_SCRIPT" ]; then
  if $CLEAN_MODE; then
    # After --clean: always kill + relaunch fresh (old server may serve stale files)
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      kill -9 "$pid" 2>/dev/null || true
    done
    sleep 0.3
    bash "$DEV_SCRIPT" >/dev/null 2>&1 &
    echo "[boot] Popup preview force-relaunched on :3000"
  elif ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    echo "[boot] Popup preview already running on :3000"
  else
    bash "$DEV_SCRIPT" >/dev/null 2>&1 &
    echo "[boot] Popup preview launched on :3000"
  fi
fi

# ── 4. Self-heal persistence (hook) ─────────────────────────────
BASHRC_MARKER="# stellar-frameworks auto-heal"
BOOT_LOG="$HOME/.stellar-boot.log"
BASHRC_PHASE1="BOOT_LOG=$HOME/.stellar-boot.log; mkdir -p $HOME; [ -d $TARGET_DIR/.git ] || git clone $REPO_URL $TARGET_DIR 2>/dev/null; bash $TARGET_DIR/boot.sh --fast >>$BOOT_LOG 2>&1; [ -s $PROJECT_ROOT/skills/stellar-frameworks/SKILL.md ] || bash $TARGET_DIR/boot.sh >>$BOOT_LOG 2>&1; tail -500 $BOOT_LOG > $BOOT_LOG.tmp && mv $BOOT_LOG.tmp $BOOT_LOG 2>/dev/null || true"

# Clean up stale hook from wrong path (v5.4.1 bug)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
if [ -f "$STALE_BASHRC" ] && grep -qF "$BASHRC_MARKER" "$STALE_BASHRC" 2>/dev/null; then
  sed -i '/# stellar-frameworks auto-heal/d' "$STALE_BASHRC"
  sed -i '/stellar-frameworks.*boot\.sh/d' "$STALE_BASHRC"
  [ ! -s "$STALE_BASHRC" ] && rm -f "$STALE_BASHRC"
  echo "[boot] Cleaned stale hook from $STALE_BASHRC"
fi

HOOK_TARGETS=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
HOOKS_WRITTEN=0

for HOOK_FILE in "${HOOK_TARGETS[@]}"; do
  if [ -f "$HOOK_FILE" ]; then
    if grep -qF "boot.sh" "$HOOK_FILE" 2>/dev/null; then
      sed -i '/# stellar-frameworks auto-heal/d' "$HOOK_FILE"
      sed -i '/stellar-frameworks.*boot\.sh/d' "$HOOK_FILE"
    fi
    printf '\n%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_PHASE1" >> "$HOOK_FILE"
  else
    printf '%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_PHASE1" > "$HOOK_FILE"
  fi
  HOOKS_WRITTEN=$((HOOKS_WRITTEN + 1))
done

echo "[boot] Auto-heal hook written to $HOOKS_WRITTEN/3 init files (clone + upstream-check + boot + health-check + log)"

if $NEED_INSTALL; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  ☄️ v6.2.0 installed and ACTIVE — no restart needed!        ║"
  echo "║  Popup preview: LIVE on :3000 (persistent, unkillable).    ║"
  echo "║  Invoke: Skill(command=\"stellar-frameworks\")                 ║"
  echo "║  Repo: $TARGET_DIR"
  echo "║  Auto-heal: hook in 3 init files + health check + log.     ║"
  echo "║  Log: $BOOT_LOG                                          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi

exit 0
