#!/bin/bash
# stellar-frameworks — Install, self-heal, audited (git-tracked) v6.4.0
# Pure skill installer + popup preview provider. No Next.js bootstrap.
# Self-heal: SKILL.md bootstrap (4-layer fallback) is the ONLY heal mechanism.
#            No shell init hooks (v6.4.0 removed ~/.bashrc/.bash_profile/.profile hooks).
# Popup preview: creates .zscripts/dev.sh AND launches it for immediate :3000 serving.
# v6.4.0: Single-clone model — boot.sh uses its own dir as repo root. No $HOME re-clone.
# Install:  git clone https://github.com/hoshiyomiX/stellar-frameworks.git <path>
#           bash <path>/boot.sh
# Invoke:   bash <path>/boot.sh [--fast] [--audited] [--offline] [--clean]
#
# Flags:
#   --fast              Skip file copy if already installed and version matches.
#                       Does NOT skip upstream check — upstream is ALWAYS probed.
#   --audited           Verbose logging to ~/.stellar-boot.log (timestamps + reasons).
#   --offline           Skip upstream check entirely (no git fetch). For air-gapped
#                       environments. Overrides --fast behavior to pure local.
#   --clean             Nuke ALL generated files before install (skills/, .zscripts/,
#                       dev.sh, hooks). Full uninstall + reinstall. Uses SIGTERM.
#   --keep-submodules   Skip submodule purge in $PROJECT_ROOT/.git (opt-out).
#   --verify            Check .checksums file, exit 0 if all match.
#   --dry-run           Print all actions without executing.
#   --pinned <sha>      Verify local HEAD matches pinned SHA before install.
#   --stop-dev-server   Kill running dev.sh (was impossible in v6.2.0).
#   --install-only      Accepted for compatibility; no-op since v5.4.4.
#
# Upstream guarantee (v6.1.0, preserved in v6.3.0):
#   Every invocation checks remote for updates via git fetch (~200ms).
#   If remote has new commits, force-sync + reinstall happens regardless of --fast.
#   --fast only skips file copy when already at latest version.
#   Use --offline to truly skip all network operations.
#
# v6.3.0 — Loud Sterilization:
#   All destructive operations (git reset --hard, submodule purge, dev server kill)
#   now log to ~/.stellar-boot.log with ISO-8601 timestamps + before/after state.
#   Silent 2>/dev/null replaced with loud logging. Audit trail always available.
#   Skill description and trigger behavior UNCHANGED (universal activation preserved).
#
# Path architecture (v5.9.0):
#   GIT_REPO   = SCRIPT_DIR (dir of boot.sh itself — no separate home clone)
#   INSTALL    = $PROJECT_ROOT/skills/stellar-frameworks  (platform load path)
#   Hook lives in $HOME init files (survives project resets)
#   If repo is missing, hook auto-clones from GitHub before booting.
#
# Resilience layers (v6.1.0):
#   Layer 0: Install command — conditional clone (skip if exists) + always boot
#   Layer 1: Hook (shell init) — clone-if-missing + boot.sh --fast (upstream check built-in)
#   Layer 2: Health check — if SKILL.md missing/empty after boot, reinstall
#   Layer 3: repo.tar fallback — copy from git-tracked skill/ if repo clone fails
#   Log: $HOME/.stellar-boot.log (rotated, last 500 lines, audited in v6.3.0)

set -euo pipefail

# ── Minimum version guard ──────────────────────────────────────────
MINIMUM_VERSION="6.1.0"

# Semantic version comparison: returns 0 (true) if $1 < $2
version_lt() {
  local a1 a2 a3 b1 b2 b3
  IFS='.' read -r a1 a2 a3 <<< "$1"
  IFS='.' read -r b1 b2 b3 <<< "$2"
  [[ $a1 -lt $b1 ]] || { [[ $a1 -eq $b1 ]] && [[ $a2 -lt $b2 ]]; } || \
  { [[ $a1 -eq $b1 ]] && [[ $a2 -eq $b2 ]] && [[ $a3 -lt $b3 ]]; }
}

# ── Parse flags ────────────────────────────────────────────────────
FAST_MODE=false
CLEAN_MODE=false
OFFLINE_MODE=false
AUDITED_MODE=false
DRY_RUN=false
KEEP_SUBMODULES=false
VERIFY_MODE=false
STOP_DEV_SERVER=false
PINNED_SHA=""

args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  arg="${args[$i]}"
  case "$arg" in
    --fast) FAST_MODE=true ;;
    --clean) CLEAN_MODE=true ;;
    --offline) OFFLINE_MODE=true ;;
    --audited) AUDITED_MODE=true ;;
    --dry-run) DRY_RUN=true ;;
    --keep-submodules) KEEP_SUBMODULES=true ;;
    --verify) VERIFY_MODE=true ;;
    --stop-dev-server) STOP_DEV_SERVER=true ;;
    --pinned) PINNED_SHA="${args[$((i+1))]:-}"; ((i++)) ;;
    --install-only) : ;; # no-op: kept for backwards compatibility
    *) ;; # ignore unknown flags
  esac
done

# ── 0. Path configuration ──────────────────────────────────────────
REPO_URL="https://github.com/hoshiyomiX/stellar-frameworks.git"
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
# v6.4.0: Single-clone model — boot.sh uses its own directory as the repo root.
# No separate $HOME/.stellar-frameworks-repo clone. Eliminates triple-clone redundancy.
# SCRIPT_DIR is authoritative; STELLAR_REPO_PATH override kept for edge cases only.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${STELLAR_REPO_PATH:-$SCRIPT_DIR}"

# If boot.sh is co-located inside skills/stellar-frameworks/ (post-install copy),
# walk up to find the actual git repo root.
if [ ! -d "$SCRIPT_DIR/.git" ] && [ -d "$SCRIPT_DIR/../../.git" ]; then
  candidate="$(cd "$SCRIPT_DIR/../.." && pwd)"
  # Only adopt if this parent looks like the stellar-frameworks repo
  if [ -d "$candidate/skill/stellar-frameworks" ] || [ -d "$candidate/.stellar-frameworks-repo" ]; then
    SCRIPT_DIR="$candidate"
    TARGET_DIR="$SCRIPT_DIR"
  fi
fi

SOURCE_DIR="$SCRIPT_DIR/skill/stellar-frameworks"
if [ ! -d "$SOURCE_DIR" ] && [ -f "$SCRIPT_DIR/SKILL.md" ]; then
  SOURCE_DIR="$SCRIPT_DIR"
fi

INSTALL_DIR="$PROJECT_ROOT/skills/stellar-frameworks"
OBSOLETE_DIR="$PROJECT_ROOT/skills/stellar-coding-agent"
ZSCRIPTS="$PROJECT_ROOT/.zscripts"
DEV_SCRIPT="$ZSCRIPTS/dev.sh"
DOWNLOAD_DIR="$PROJECT_ROOT/download"
BOOT_LOG="$HOME/.stellar-boot.log"

# ── Logging utilities (v6.3.0 — Loud Sterilization) ────────────────
# All operations log with ISO-8601 timestamps. AUDITED_MODE adds stdout echo.
# Non-audited mode still logs to file (just doesn't echo to stdout).
log_line() {
  local msg="$1"
  local ts
  ts="$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
  local line="[boot $ts] $msg"
  mkdir -p "$(dirname "$BOOT_LOG")" 2>/dev/null || true
  echo "$line" >> "$BOOT_LOG" 2>/dev/null || true
  if $AUDITED_MODE; then
    echo "$line"
  fi
}

# Convenience wrappers
log_info()  { log_line "INFO: $*"; }
log_warn()  { log_line "WARN: $*"; }
log_error() { log_line "ERROR: $*"; }
log_step()  { log_line "STEP: $*"; }

# Loud error wrapper — replaces silent 2>/dev/null pattern
loud_run() {
  local desc="$1"; shift
  log_step "$desc"
  if $DRY_RUN; then
    log_info "DRY-RUN: skipped: $*"
    return 0
  fi
  if "$@" >> "$BOOT_LOG" 2>&1; then
    log_info "OK: $desc"
    return 0
  else
    local rc=$?
    log_error "FAILED (rc=$rc): $desc — command: $*"
    return $rc
  fi
}

# ── Verify mode (checksum verification) ────────────────────────────
if $VERIFY_MODE; then
  log_info "VERIFY MODE — checking .checksums"
  CHECKSUMS_FILE="$SCRIPT_DIR/.checksums"
  if [ ! -f "$CHECKSUMS_FILE" ]; then
    log_error ".checksums file not found at $CHECKSUMS_FILE"
    exit 1
  fi
  # Verify each entry
  ERRORS=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" =~ ^# ]] && continue
    expected_hash="$(echo "$line" | awk '{print $1}')"
    file_path="$(echo "$line" | awk '{print $2}')"
    full_path="$SCRIPT_DIR/$file_path"
    if [ ! -f "$full_path" ]; then
      log_error "MISSING: $file_path"
      ERRORS=$((ERRORS + 1))
      continue
    fi
    actual_hash="$(sha256sum "$full_path" | awk '{print $1}')"
    if [ "$expected_hash" != "$actual_hash" ]; then
      log_error "MISMATCH: $file_path (expected ${expected_hash:0:12}, got ${actual_hash:0:12})"
      ERRORS=$((ERRORS + 1))
    else
      log_info "OK: $file_path"
    fi
  done < "$CHECKSUMS_FILE"
  if [ $ERRORS -eq 0 ]; then
    log_info "All checksums verified"
    exit 0
  else
    log_error "$ERRORS checksum mismatch(es)"
    exit 1
  fi
fi

# ── Stop dev server mode ───────────────────────────────────────────
if $STOP_DEV_SERVER; then
  log_info "STOP-DEV-SERVER MODE — killing any running dev.sh"
  # Kill bash dev.sh PARENT first (so while-true loop stops spawning new children)
  if pkill -TERM -f '.zscripts/dev.sh' 2>/dev/null; then
    log_info "SIGTERM sent to bash dev.sh parent process(es)"
  fi
  sleep 0.5
  # Now kill any orphaned python child on :3000
  if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      log_info "SIGTERM to python pid $pid"
      kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 1
    # Second pass — SIGKILL only if SIGTERM didn't work
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      log_warn "SIGKILL python pid $pid (did not respond to SIGTERM)"
      kill -9 "$pid" 2>/dev/null || true
    done
  fi
  # Final verification
  if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    log_error "Dev server still running on :3000 after stop attempt"
  else
    log_info "Dev server stopped cleanly"
  fi
  exit 0
fi

# ── Dry-run mode (v6.3.0) — print all actions, exit before any side effects ──
if $DRY_RUN; then
  log_info "DRY-RUN MODE — no actions will be executed, printing plan only"
  log_info "Would: clean stale install (if --clean also set)"
  log_info "Would: use SCRIPT_DIR as repo root: $SCRIPT_DIR"
  log_info "Would: git fetch origin (unless --offline)"
  log_info "Would: git reset --hard origin/<branch> (if upstream diverged AND no unpushed commits)"
  log_info "Would: purge submodules in $PROJECT_ROOT/.git (unless --keep-submodules)"
  log_info "Would: cp -a skill/stellar-frameworks → $INSTALL_DIR"
  log_info "Would: copy boot.sh → $INSTALL_DIR/boot.sh"
  log_info "Would: write $ZSCRIPTS/index.html + chibi.png"
  log_info "Would: write $DEV_SCRIPT (with SIGTERM trap)"
  log_info "Would: launch bash \$DEV_SCRIPT & (if :3000 free)"
  log_info "Would: CLEAN legacy v6.3.0 hooks from ~/.bashrc, ~/.bash_profile, ~/.profile (no new hooks written)"
  log_info "DRY-RUN complete — no files modified, no processes spawned"
  exit 0
fi

# ── Pinned SHA verification ────────────────────────────────────────
if [ -n "$PINNED_SHA" ] && [ -d "$SCRIPT_DIR/.git" ]; then
  CURRENT_SHA="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo "")"
  if [ "$CURRENT_SHA" != "$PINNED_SHA" ]; then
    log_error "PINNED: local HEAD ($CURRENT_SHA) does not match pinned SHA ($PINNED_SHA)"
    log_error "  To fix: cd $SCRIPT_DIR && git checkout $PINNED_SHA"
    exit 1
  else
    log_info "PINNED: HEAD matches $PINNED_SHA"
  fi
fi

# ── 0-pre. Clean mode: nuke ALL generated files ────────────────────
if $CLEAN_MODE; then
  log_info "CLEAN MODE — nuking all generated files"
  # Kill dev server if running (SIGTERM first, SIGKILL fallback)
  if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    log_step "Stopping dev server on :3000"
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      log_info "SIGTERM pid $pid"
      kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 1
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      log_warn "SIGKILL pid $pid (did not respond to SIGTERM)"
      kill -9 "$pid" 2>/dev/null || true
    done
  fi
  pkill -TERM -f '.zscripts/dev.sh' 2>/dev/null || true
  sleep 0.5

  # Remove skill install
  if [ -d "$INSTALL_DIR" ]; then
    log_step "Removing $INSTALL_DIR"
    rm -rf "${INSTALL_DIR:?}" 2>/dev/null
  fi
  # Remove popup preview files
  rm -f "$DOWNLOAD_DIR/index.html" "$DOWNLOAD_DIR/chibi.png" 2>/dev/null
  rm -f "$ZSCRIPTS/index.html" "$ZSCRIPTS/chibi.png" 2>/dev/null
  log_info "Removed popup preview files"
  # Remove managed dev.sh
  if [ -f "$DEV_SCRIPT" ] && grep -qF "# stellar-frameworks dev server" "$DEV_SCRIPT" 2>/dev/null; then
    rm -f "$DEV_SCRIPT"
    log_info "Removed .zscripts/dev.sh"
  fi
  # Remove hooks from init files
  for HOOK_FILE in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$HOOK_FILE" ] && grep -qF "stellar-frameworks" "$HOOK_FILE" 2>/dev/null; then
      log_step "Cleaning hook from $HOOK_FILE"
      sed -i '/# stellar-frameworks auto-heal/d' "$HOOK_FILE"
      sed -i '/stellar-frameworks.*boot\.sh/d' "$HOOK_FILE"
      sed -i '/stellar-frameworks-repo/d' "$HOOK_FILE"
      [ ! -s "$HOOK_FILE" ] && rm -f "$HOOK_FILE"
    fi
  done
  log_info "Removed hooks from init files"
  # Remove predecessor
  rm -rf "${OBSOLETE_DIR:?}" 2>/dev/null
  rm -rf "${PROJECT_ROOT:?}/skill" 2>/dev/null
  rm -f "$BOOT_LOG" 2>/dev/null
  log_info "Nuke complete — proceeding with fresh install"
fi

# ── 0a. v6.4.0: No auto-clone (single-clone model) ────────────────
# boot.sh uses SCRIPT_DIR (its own location) as repo root. If not a git repo,
# user must clone manually. No silent $HOME re-clone (eliminates triple-clone).
OLD_REPO_DIR="$PROJECT_ROOT/stellar-frameworks"

if [ ! -d "$SCRIPT_DIR/.git" ]; then
  # boot.sh not in a git repo — try migration from old path, else error out
  if [ -d "$OLD_REPO_DIR/.git" ]; then
    log_info "Migrating repo: $OLD_REPO_DIR → $SCRIPT_DIR"
    mv "$OLD_REPO_DIR" "$SCRIPT_DIR" 2>/dev/null || {
      log_error "Could not migrate $OLD_REPO_DIR → $SCRIPT_DIR"
      log_error "Clone manually: git clone $REPO_URL <path> && bash <path>/boot.sh"
      exit 1
    }
    SOURCE_DIR="$SCRIPT_DIR/skill/stellar-frameworks"
  else
    log_error "boot.sh is not inside a git repo. Clone first:"
    log_error "  git clone $REPO_URL <path>"
    log_error "  bash <path>/boot.sh"
    exit 1
  fi
fi

# ── 0b. Stale install cleanup ──────────────────────────────────────
STALE_SKILL_DIR="$PROJECT_ROOT/skill/stellar-frameworks"
if [ -d "$STALE_SKILL_DIR" ]; then
  log_step "Removing stale skill/ (singular) install"
  rm -rf "${STALE_SKILL_DIR:?}"
  rmdir "$PROJECT_ROOT/skill" 2>/dev/null || true
fi
if [ -f "$INSTALL_DIR/chibi.png" ]; then
  rm -f "$INSTALL_DIR/chibi.png"
fi
rm -f "$DOWNLOAD_DIR/index.html" "$DOWNLOAD_DIR/chibi.png" 2>/dev/null

# ── 0c. Submodule purge: prevent git submodule contamination ───────
# Default behavior preserved (v6.2.0). v6.3.0 adds: opt-out via --keep-submodules
# or STELLAR_KEEP_SUBMODULES=1 env var. All purge actions now logged.
if [ "${STELLAR_KEEP_SUBMODULES:-0}" = "1" ]; then
  KEEP_SUBMODULES=true
fi

if [ -d "$PROJECT_ROOT/.git" ] && ! $KEEP_SUBMODULES; then
  HAS_GITMODULES=false
  HAS_STAGE_160000=false

  if [ -f "$PROJECT_ROOT/.gitmodules" ]; then
    HAS_GITMODULES=true
  fi
  if git -C "$PROJECT_ROOT" ls-files --stage 2>/dev/null | grep -q '^160000 '; then
    HAS_STAGE_160000=true
  fi

  if $HAS_GITMODULES || $HAS_STAGE_160000; then
    PROJECT_REMOTE="$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")"
    PROJECT_REPO="$(echo "$PROJECT_REMOTE" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
    EXPECTED_REPO="github.com/hoshiyomiX/stellar-frameworks"

    if [ "$PROJECT_REPO" != "$EXPECTED_REPO" ]; then
      log_step "Submodule contamination detected in project repo — purging (audited)"
      SUB_COUNT=0
      if $HAS_STAGE_160000; then
        SUB_COUNT="$(git -C "$PROJECT_ROOT" ls-files --stage 2>/dev/null | grep '^160000 ' | wc -l)"
      fi
      log_info "Found ${SUB_COUNT} submodule(s) + .gitmodules file"

      # Detect submodules sharing parent's remote
      if [ -f "$PROJECT_ROOT/.gitmodules" ] && [ -n "$PROJECT_REMOTE" ]; then
        while IFS= read -r line; do
          if echo "$line" | grep -qP '^\s*url\s*='; then
            SUB_URL="$(echo "$line" | grep -oP '=\s*\K.*' | tr -d ' "')"
            SUB_REPO="$(echo "$SUB_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
            if [ "$SUB_REPO" = "$PROJECT_REPO" ]; then
              log_warn "submodule shares parent remote (${SUB_REPO}) — double-push bug"
            fi
          fi
        done < "$PROJECT_ROOT/.gitmodules"
      fi

      log_step "Running git submodule deinit --all --force"
      git -C "$PROJECT_ROOT" submodule deinit --all --force >> "$BOOT_LOG" 2>&1 || true
      log_step "Removing .gitmodules from git index"
      git -C "$PROJECT_ROOT" rm -f --cached '.gitmodules' >> "$BOOT_LOG" 2>&1 || true
      rm -f "$PROJECT_ROOT/.gitmodules"
      log_step "Cleaning .git/modules/ cache"
      rm -rf "$PROJECT_ROOT/.git/modules/" 2>/dev/null || true
      if $HAS_STAGE_160000; then
        git -C "$PROJECT_ROOT" ls-files --stage 2>/dev/null | grep '^160000 ' | awk '{print $4}' | while read -r mod; do
          log_step "Removing submodule: $mod"
          git -C "$PROJECT_ROOT" rm -f --cached "$mod" >> "$BOOT_LOG" 2>&1 || true
          if [ -d "$PROJECT_ROOT/$mod/.git" ] || [ -f "$PROJECT_ROOT/$mod/.git" ]; then
            rm -rf "$PROJECT_ROOT/$mod" 2>/dev/null || true
          fi
        done
      fi
      find "$PROJECT_ROOT" -maxdepth 3 -name '.git' -type f -exec rm -f {} \; 2>/dev/null || true
      log_info "Submodules purged — project repo is clean"
    fi
  fi
elif $KEEP_SUBMODULES; then
  log_info "Submodule purge SKIPPED (--keep-submodules or STELLAR_KEEP_SUBMODULES=1)"
fi

# ── 0d. Upstream probe: ALWAYS check for remote updates ────────────
# v6.3.0: git reset --hard PRESERVED (user constraint #1), but now audited.
# Safety net for unpushed commits PRESERVED (v6.1.0).
UPSTREAM_CURRENT=true
SELF_UPDATED=false

if ! $OFFLINE_MODE && [ -d "$SCRIPT_DIR/.git" ]; then
  BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "main")"
  REMOTE_URL="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")"

  if [ -n "$BRANCH" ] && [ -n "$REMOTE_URL" ]; then
    log_step "Upstream probe: git fetch origin $BRANCH"
    if git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet >> "$BOOT_LOG" 2>&1; then
      LOCAL_SHA="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)"
      REMOTE_SHA="$(git -C "$SCRIPT_DIR" rev-parse "origin/$BRANCH" 2>/dev/null)"

      if [ "$LOCAL_SHA" != "$REMOTE_SHA" ] && [ -n "$REMOTE_SHA" ]; then
        # Check for unpushed local commits BEFORE force-sync (v6.1.0 safety net)
        UNPUSHED="$(git -C "$SCRIPT_DIR" log --oneline "origin/$BRANCH..HEAD" 2>/dev/null)"
        if [ -n "$UNPUSHED" ]; then
          log_warn "${LOCAL_SHA:0:7} has unpushed commits — skipping force-sync to prevent data loss"
          log_warn "  (push your commits first, or use --offline to suppress this check)"
          log_warn "  Unpushed:"
          echo "$UNPUSHED" | head -3 | while read -r line; do log_warn "    $line"; done
          UPSTREAM_CURRENT=false
        else
          UPSTREAM_CURRENT=false
          OLD_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
          BOOT_BEFORE="$(md5sum "$SCRIPT_DIR/boot.sh" 2>/dev/null | cut -d' ' -f1)"

          # ── STERILIZATION (audited, v6.3.0) ──────────────────────
          # git reset --hard PRESERVED per user constraint #1.
          # Audit log: timestamp + reason + before/after SHA.
          log_step "STERILIZE: git reset --hard origin/$BRANCH"
          log_info "  reason: upstream divergence (local: ${LOCAL_SHA:0:7}, remote: ${REMOTE_SHA:0:7})"
          log_info "  before: $(git -C "$SCRIPT_DIR" log --oneline -1 2>/dev/null)"

          git -C "$SCRIPT_DIR" reset --hard "origin/$BRANCH" >> "$BOOT_LOG" 2>&1

          log_info "  after:  $(git -C "$SCRIPT_DIR" log --oneline -1 2>/dev/null)"
          log_info "STERILIZE complete"

          NEW_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
          BOOT_AFTER="$(md5sum "$SCRIPT_DIR/boot.sh" 2>/dev/null | cut -d' ' -f1)"
          log_info "Upstream update: ${OLD_VER} → ${NEW_VER} (force-synced)"

          if [ "$BOOT_BEFORE" != "$BOOT_AFTER" ]; then
            SELF_UPDATED=true
          fi
        fi
      else
        OLD_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
        log_info "Upstream current ($OLD_VER)"
      fi
    else
      log_warn "git fetch failed — skipping upstream check"
    fi
  fi
fi

# ── 1. Force-sync project dir if it IS the stellar-frameworks repo ──
if [ -d "$PROJECT_ROOT/.git" ]; then
  PROJECT_REMOTE="$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")"
  PROJECT_REPO="$(echo "$PROJECT_REMOTE" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
  EXPECTED_REPO="github.com/hoshiyomiX/stellar-frameworks"
  if [ "$PROJECT_REPO" = "$EXPECTED_REPO" ]; then
    PROJECT_BRANCH="$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "main")"
    P_LOCAL="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)"
    P_REMOTE="$(git -C "$PROJECT_ROOT" rev-parse "origin/$PROJECT_BRANCH" 2>/dev/null)"
    if [ "$P_LOCAL" != "$P_REMOTE" ] && [ -n "$P_REMOTE" ]; then
      P_UNPUSHED="$(git -C "$PROJECT_ROOT" log --oneline "origin/$PROJECT_BRANCH..HEAD" 2>/dev/null)"
      if [ -z "$P_UNPUSHED" ]; then
        log_step "Project dir matches stellar-frameworks remote — force-syncing"
        git -C "$PROJECT_ROOT" fetch origin "$PROJECT_BRANCH" --quiet >> "$BOOT_LOG" 2>&1
        git -C "$PROJECT_ROOT" reset --hard "origin/$PROJECT_BRANCH" >> "$BOOT_LOG" 2>&1
        git -C "$PROJECT_ROOT" checkout -- . 2>/dev/null
        cp -a "$PROJECT_ROOT/skill/stellar-frameworks" "$PROJECT_ROOT/skills/stellar-frameworks"
        cp -- "$PROJECT_ROOT/boot.sh" "$PROJECT_ROOT/skills/stellar-frameworks/boot.sh" 2>/dev/null
        log_info "Project dir force-synced (was contaminated/diverged)"
      else
        log_warn "project dir has unpushed commits — skipping force-sync"
      fi
    fi
  fi
fi

# Self-re-exec: if boot.sh was updated by upstream sync, re-run with new version.
# v6.3.0: SELF_UPDATED still triggers re-exec (user constraint #2 + #3), but logged.
if $SELF_UPDATED; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR/boot.sh")" && pwd)"
  log_step "SELF-UPDATE: boot.sh changed upstream — re-executing with new version"
  log_info "  old md5: $BOOT_BEFORE"
  log_info "  new md5: $BOOT_AFTER"
  exec bash "$SCRIPT_DIR/boot.sh" "$@"
fi

# ── 2. Install / self-heal: copy skill/ → skills/ ──────────────────
NEED_INSTALL=false

if $UPSTREAM_CURRENT && $FAST_MODE && [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/SKILL.md" ] && [ -s "$INSTALL_DIR/SKILL.md" ]; then
  INSTALLED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  SOURCE_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if [ "$INSTALLED_VER" = "$SOURCE_VER" ]; then
    NEED_INSTALL=false
    log_info "Skill files OK (v$INSTALLED_VER, upstream current, --fast skip)"
  else
    NEED_INSTALL=true
    log_info "Version update: $INSTALLED_VER → $SOURCE_VER"
  fi
else
  NEED_INSTALL=true
  if ! $UPSTREAM_CURRENT; then
    log_info "Force-reinstalling skill files (upstream update detected)"
  elif [ -L "$INSTALL_DIR" ]; then
    log_info "Legacy symlink detected — replacing with real copy"
  elif [ -d "$INSTALL_DIR" ]; then
    log_info "Force-copying skill files (normal mode — ensures content freshness)"
  else
    log_info "skills/ not found — installing"
  fi
fi

# Clean up predecessor skill
if [ -d "$OBSOLETE_DIR" ]; then
  log_step "Removing predecessor skill: stellar-coding-agent"
  rm -rf "${OBSOLETE_DIR:?}"
fi

if $NEED_INSTALL; then
  if [ ! -d "$SOURCE_DIR" ] || [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
    TARBALL_SOURCE="$PROJECT_ROOT/skill/stellar-frameworks"
    if [ -d "$TARBALL_SOURCE" ] && [ -f "$TARBALL_SOURCE/SKILL.md" ]; then
      log_warn "Repo source unavailable — falling back to repo.tar source (skill/)"
      SOURCE_DIR="$TARBALL_SOURCE"
    else
      log_error "skill/ not found in repo or project dir"
      exit 1
    fi
  fi
  log_step "Installing skill files → skills/ (copy)"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  rm -rf "${INSTALL_DIR:?}"
  cp -a "$SOURCE_DIR" "$INSTALL_DIR"

  # Copy boot.sh into skills/ so it's co-located with SKILL.md
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
    if [ ! -f "$INSTALL_DIR/$f" ]; then
      log_warn "$f MISSING"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $ERRORS -eq 0 ]; then
    INSTALLED_VER="$(grep -oP 'version\*{2}:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "?")"
    rm -f "$INSTALL_DIR/chibi.png"
    log_info "Installed successfully (copy: v$INSTALLED_VER)"
  else
    log_warn "installed with $ERRORS missing file(s)"
  fi
else
  log_info "Skill files OK"
fi

# ── 3. Popup preview: ensure landing page + dev server ──────────────
mkdir -p "$ZSCRIPTS"

# Copy chibi mascot
if [ -f "$SOURCE_DIR/chibi.png" ]; then
  cp -- "$SOURCE_DIR/chibi.png" "$ZSCRIPTS/chibi.png"
  log_info "Chibi mascot copied"
fi

# Always overwrite index.html — popup-only artifact
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
  <div class="version">v6.3.0</div>
  <p><span>Phase State Machine</span> &middot; Traceability IDs &middot; Adaptive Complexity<br>Send a message to start building.</p>
  <div class="badge"><span class="dot"></span> Dev server running</div>
</div>
</body>
</html>
SPLASH
log_info "Landing page created"

# ── Ensure .zscripts/dev.sh exists and is up-to-date (v6.3.0: killable) ──
DEV_SCRIPT_MARKER="# stellar-frameworks dev server"

write_dev_sh() {
  cat > "$DEV_SCRIPT" << 'DEVSH'
#!/bin/bash
# stellar-frameworks dev server v6.3.0 — persistent + killable
# Auto-restarts on crash (preserved from v6.2.0).
# Killable via SIGTERM/SIGINT (NEW in v6.3.0): pkill -f dev.sh now works.
# All output logged to ~/.stellar-boot.log (audited).
# Created by boot.sh — do not edit manually.

DEV_LOG="$HOME/.stellar-boot.log"

dev_log() {
  local ts
  ts="$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
  echo "[dev.sh $ts] $*" >> "$DEV_LOG" 2>/dev/null || true
}

# Trap SIGTERM/SIGINT — exit cleanly instead of requiring SIGKILL
cleanup() {
  dev_log "received signal — exiting cleanly"
  exit 0
}
trap cleanup SIGTERM SIGINT

# Port guard — exit gracefully if already in use
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ':3000 '; then
  dev_log "Port :3000 already in use — not starting"
  exit 0
fi

# Detect actual Next.js project
if [ -f /home/z/my-project/next.config.js ] || [ -f /home/z/my-project/next.config.mjs ] || [ -f /home/z/my-project/next.config.ts ]; then
  dev_log "Next.js project detected — running bun run dev (persistent)"
  while true; do
    cd /home/z/my-project && bun run dev >> "$DEV_LOG" 2>&1 || true
    sleep 2
    dev_log "bun run dev exited — restarting (crash recovery)"
  done
else
  mkdir -p /home/z/my-project/.zscripts
  dev_log "Static project — running python3 http.server :3000 (persistent)"
  while true; do
    cd /home/z/my-project/.zscripts && python3 -m http.server 3000 >> "$DEV_LOG" 2>&1 || true
    sleep 1
    dev_log "http.server exited — restarting (crash recovery)"
  done
fi
DEVSH
  chmod +x "$DEV_SCRIPT"
}

if [ ! -f "$DEV_SCRIPT" ]; then
  log_step "Creating dev.sh for popup preview"
  mkdir -p "$ZSCRIPTS"
  write_dev_sh
  log_info "dev.sh created (persistent + killable)"
elif ! grep -qF "$DEV_SCRIPT_MARKER" "$DEV_SCRIPT" 2>/dev/null; then
  log_info "dev.sh already exists (external) — keeping it"
else
  if $FAST_MODE; then
    log_info "dev.sh OK (managed by stellar-frameworks, --fast skip)"
  else
    log_step "Overwriting dev.sh (managed, normal mode — ensures content freshness)"
    mkdir -p "$ZSCRIPTS"
    write_dev_sh
  fi
fi

# Launch dev server
if [ -f "$DEV_SCRIPT" ]; then
  if $CLEAN_MODE; then
    # After --clean: SIGTERM anything on :3000, then relaunch
    ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | while read -r pid; do
      log_info "SIGTERM pid $pid (clean relaunch)"
      kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 0.5
    bash "$DEV_SCRIPT" >> "$BOOT_LOG" 2>&1 &
    log_info "Popup preview force-relaunched on :3000"
  elif ss -tlnp 2>/dev/null | grep -q ':3000 '; then
    log_info "Popup preview already running on :3000"
  else
    bash "$DEV_SCRIPT" >> "$BOOT_LOG" 2>&1 &
    log_info "Popup preview launched on :3000"
  fi
fi

# ── 4. Self-heal: SKILL.md bootstrap is the ONLY heal mechanism ──
# v6.4.0: Shell init hooks REMOVED. No more ~/.bashrc, ~/.bash_profile,
# ~/.profile modifications. Healing happens exclusively via the 4-layer
# bootstrap in SKILL.md (skills/stellar-frameworks/boot.sh → project boot.sh
# → home repo → fresh clone).
#
# This block now does CLEANUP ONLY: strips any legacy v6.3.0 hooks from
# shell init files so upgrades from v6.3.0 → v6.4.0 are clean.
BASHRC_MARKER="# stellar-frameworks auto-heal"

# Clean up legacy hooks from all shell init files (v6.3.0 → v6.4.0 migration)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
HOOK_TARGETS=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$STALE_BASHRC")
HOOKS_CLEANED=0

for HOOK_FILE in "${HOOK_TARGETS[@]}"; do
  if [ -f "$HOOK_FILE" ] && grep -qF "$BASHRC_MARKER" "$HOOK_FILE" 2>/dev/null; then
    log_step "Cleaning legacy v6.3.0 hook from $HOOK_FILE"
    # Strip the entire hook block: from marker line to end of file (hook was appended at EOF)
    # Use python for safe in-place edit (sed -i /pattern/,$d has portability quirks)
    python3 -c "
import sys
path = '$HOOK_FILE'
with open(path) as fh:
    content = fh.read()
marker = '$BASHRC_MARKER'
idx = content.find(marker)
if idx >= 0:
    new_content = content[:idx].rstrip() + '\n'
    with open(path, 'w') as fh:
        fh.write(new_content)
    print(f'  cleaned: {path}')
" && HOOKS_CLEANED=$((HOOKS_CLEANED + 1))
    # Remove now-empty file (only if it had ONLY the hook)
    [ ! -s "$HOOK_FILE" ] && rm -f "$HOOK_FILE" 2>/dev/null
  fi
done

if [ $HOOKS_CLEANED -gt 0 ]; then
  log_info "Cleaned $HOOKS_CLEANED legacy shell hook(s) — healing now via SKILL.md bootstrap only"
else
  log_info "No legacy shell hooks found — healing via SKILL.md bootstrap only"
fi

if $NEED_INSTALL; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  ☄️ v6.4.0 installed and ACTIVE — no restart needed!        ║"
  echo "║  Popup preview: LIVE on :3000 (persistent, killable).       ║"
  echo "║  Invoke: Skill(command=\"stellar-frameworks\")                 ║"
  echo "║  Repo: $TARGET_DIR"
  echo "║  Self-heal: SKILL.md 4-layer bootstrap (no shell hooks).   ║"
  echo "║  Audit log: $BOOT_LOG                          ║"
  echo "║  Stop server: boot.sh --stop-dev-server                    ║"
  echo "║  Verify:     boot.sh --verify                              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi

exit 0
