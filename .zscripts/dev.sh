#!/bin/bash
# stellar-trails dev server v9.16.3 — self-healing boot-time recovery
#
# v9.16.3 fixes the chicken-and-egg problem:
#   dev.sh v9.16.2 fixes downgrade, but dev.sh ITSELF can be downgraded by clawhub install.
#   This version adds SELF-HEALING: checks git repo for newer versions of itself + SKILL.md.
#
# v9.16.3 new features:
#   1. SELF-UPGRADE: If git repo has newer dev.sh → self-replace + restart
#   2. SKILL.md RECOVERY: If local SKILL.md missing/outdated → restore from git repo
#   3. NEVER install from registry if git repo has newer version
#
# This breaks the downgrade cycle permanently:
#   Container reboot → /start.sh runs .zscripts/dev.sh (might be old)
#   → dev.sh self-upgrade check: if git repo newer → cp + restart
#   → New dev.sh runs → SKILL.md recovery → restore from git repo
#   → Local preserved → no registry install needed
#
# v9.16.2 fixes retained:
#   - Reorder: cleanup first, install later
#   - SIGKILL immediately for zombies
#   - Version check: don't install if SKILL.md exists

set -e

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
PORT="${PORT:-3000}"
PID_FILE="$ZSCRIPTS_DIR/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"

# Git repo locations (source of truth, survives reboot)
GIT_SKILL_DIR="/home/z/my-project/stellar-trails/skill/stellar-trails"
GIT_DEV_SH="$GIT_SKILL_DIR/dev.sh"
GIT_SKILL_MD="$GIT_SKILL_DIR/SKILL.md"

# Local skill dir (what bash reads)
LOCAL_SKILL_DIR="/home/z/my-project/skills/stellar-trails"
LOCAL_SKILL_MD="$LOCAL_SKILL_DIR/SKILL.md"
LOCAL_DEV_SH="$LOCAL_SKILL_DIR/dev.sh"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

# --- Logging ---
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# === STEP 0: SELF-HEALING (v9.16.3 — breaks downgrade cycle) ===
# Check if git repo has newer dev.sh → self-upgrade
if [ -f "$GIT_DEV_SH" ] && [ -f "$GIT_SKILL_MD" ]; then
  GIT_DEV_HASH=$(sha256sum "$GIT_DEV_SH" 2>/dev/null | cut -d' ' -f1)
  SELF_HASH=$(sha256sum "$0" 2>/dev/null | cut -d' ' -f1)
  
  if [ "$GIT_DEV_HASH" != "$SELF_HASH" ]; then
    log "Self-upgrade: git repo dev.sh differs from running dev.sh — upgrading"
    cp -f "$GIT_DEV_SH" "$0"
    chmod +x "$0"
    # Also sync to local skill dir + .zscripts
    cp -f "$GIT_DEV_SH" "$LOCAL_DEV_SH" 2>/dev/null || true
    cp -f "$GIT_DEV_SH" "$ZSCRIPTS_DIR/dev.sh" 2>/dev/null || true
    chmod +x "$LOCAL_DEV_SH" "$ZSCRIPTS_DIR/dev.sh" 2>/dev/null || true
    log "Self-upgrade complete — restarting with new dev.sh"
    exec bash "$0"
  fi
  
  # Check SKILL.md: if missing or git repo has newer version → restore
  if [ ! -f "$LOCAL_SKILL_MD" ]; then
    log "SKILL.md missing — restoring from git repo (NOT from registry)"
    mkdir -p "$LOCAL_SKILL_DIR"
    cp -rf "$GIT_SKILL_DIR/"* "$LOCAL_SKILL_DIR/" 2>/dev/null || true
    log "✓ SKILL.md restored from git repo"
  else
    LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$LOCAL_SKILL_MD" 2>/dev/null | head -1)
    GIT_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$GIT_SKILL_MD" 2>/dev/null | head -1)
    if [ -n "$GIT_VER" ] && [ -n "$LOCAL_VER" ]; then
      if dpkg --compare-versions "$GIT_VER" gt "$LOCAL_VER" 2>/dev/null || [ "$GIT_VER" \> "$LOCAL_VER" ]; then
        log "Local SKILL.md v$LOCAL_VER < git repo v$GIT_VER — restoring from git repo"
        cp -rf "$GIT_SKILL_DIR/"* "$LOCAL_SKILL_DIR/" 2>/dev/null || true
        log "✓ SKILL.md upgraded from git repo (v$LOCAL_VER → v$GIT_VER)"
      fi
    fi
  fi
else
  log "⚠️ Git repo not found at $GIT_SKILL_DIR — cannot self-heal"
  log "  Falling back to clawhub install if SKILL.md missing"
fi

# === STEP 1: FAST PID/PORT CLEANUP (v9.16.2) ===
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
      if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        log "Already running (PID $OLD_PID, port :$PORT OK) — not starting"
        exit 0
      else
        log "PID $OLD_PID zombie (port not listening) — SIGKILL + immediate cleanup"
        kill -9 "$OLD_PID" 2>/dev/null || true
        rm -f "$PID_FILE"
      fi
    else
      log "PID $OLD_PID not dev.sh — stale PID file, cleaning up"
      rm -f "$PID_FILE"
    fi
  else
    log "Stale PID file (PID $OLD_PID not running) — cleaning up"
    rm -f "$PID_FILE"
  fi
fi
echo $$ > "$PID_FILE"

trap 'if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi' EXIT
trap '' SIGHUP

# === STEP 2: PORT RECLAIM (v9.11.7 Bug 4 fix) ===
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
  LISTENER_NAME=""
  if [ -n "$LISTENER_PID" ] && [ -d "/proc/$LISTENER_PID" ]; then
    LISTENER_NAME=$(cat "/proc/$LISTENER_PID/comm" 2>/dev/null || echo "")
  fi
  if [ "$LISTENER_NAME" = "python3" ] || [ "$LISTENER_NAME" = "python" ]; then
    log "Port :$PORT in use by orphaned python3 (PID $LISTENER_PID) — SIGKILL + reclaim"
    kill -9 "$LISTENER_PID" 2>/dev/null || true
    sleep 0.5
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
      log "Port :$PORT STILL in use — cannot reclaim, exiting"
      if [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi
      exit 0
    fi
    log "Port :$PORT reclaimed"
  else
    log "Port :$PORT in use by non-python3 — not starting"
    if [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi
    exit 0
  fi
fi

# === STEP 3: AUTO-INSTALL (v9.16.2 — version check, fallback to registry only if git repo missing) ===
ST_SKILL_MD="$LOCAL_SKILL_MD"
if [ ! -f "$ST_SKILL_MD" ]; then
  if [ -f "$GIT_SKILL_MD" ]; then
    # Git repo fallback (v9.16.3)
    log "SKILL.md missing — restoring from git repo (NOT from registry)"
    mkdir -p "$LOCAL_SKILL_DIR"
    cp -rf "$GIT_SKILL_DIR/"* "$LOCAL_SKILL_DIR/" 2>/dev/null || true
    log "✓ SKILL.md restored from git repo"
  else
    # Last resort: registry install (only if git repo unavailable)
    echo "[dev.sh] SKILL.md missing + git repo unavailable — installing via clawhub..."
    clawhub install stellar-trails --force 2>/dev/null && echo "[dev.sh] ✓ stellar-trails installed" || echo "[dev.sh] ⚠ install failed — will retry via Step 4a-pre"
  fi
else
  LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$ST_SKILL_MD" 2>/dev/null | head -1)
  echo "[dev.sh] SKILL.md exists (v${LOCAL_VER:-unknown}) — NOT installing (preserve local version)"
fi

# === STEP 4: START PYTHON3 SERVER ===
log "Serving $ZSCRIPTS_DIR on :$PORT (v9.16.3 — self-healing + fast startup)"
log "PID: $$ | Log: $LOG_FILE | Mode: foreground + infinite loop"

BACKOFF=1

while true; do
  START_TIME=$(date +%s)
  log "Starting python3 server (foreground, backoff=${BACKOFF}s)"

  python3 -c "
import http.server, socketserver, signal, sys

class ReuseTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()
    def log_message(self, format, *args):
        pass

def shutdown(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)
signal.signal(signal.SIGHUP, signal.SIG_IGN)

with ReuseTCPServer(('0.0.0.0', $PORT), NoCacheHandler) as httpd:
    httpd.serve_forever()
" 2>>"$LOG_FILE" || true

  END_TIME=$(date +%s)
  UPTIME=$((END_TIME - START_TIME))
  log "python3 exited (uptime: ${UPTIME}s)"

  if [ "$UPTIME" -lt 2 ]; then
    log "Rapid crash (uptime ${UPTIME}s < 2s) — backing off ${BACKOFF}s"
    sleep "$BACKOFF"
    BACKOFF=$((BACKOFF * 2))
    [ "$BACKOFF" -gt 30 ] && BACKOFF=30
  else
    log "Normal exit — restarting immediately"
    BACKOFF=1
    sleep 1
  fi
done
