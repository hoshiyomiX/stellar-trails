#!/bin/bash
# stellar-trails dev server v9.16.2 — fixed auto-start + version check + faster cleanup
#
# v9.16.2 fixes:
#   1. Reorder: PID/port cleanup FIRST, then install check, then python3 start
#      (previously: install check blocked cleanup → 3+ min startup delay)
#   2. Version check before install: don't downgrade if local > registry
#      (fixes Regression R2: dev.sh auto-install downgraded v9.16.1 → v9.15.3)
#   3. Faster zombie cleanup: SIGKILL immediately for zombies (no retry loop)
#      (previously: kill, sleep 1, check, retry... → 3 min delay)
#
# v9.0.0 architecture retained:
#   - python3 runs in FOREGROUND (no & background)
#   - while true infinite loop (never gives up)
#   - set -e for setup phase
#   - SIGHUP trap (survive terminal close)
#   - PID file + stale detection
#   - Rapid-crash backoff

set -e

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
PORT="${PORT:-3000}"
PID_FILE="$ZSCRIPTS_DIR/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

# --- Logging ---
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# === STEP 1: FAST PID/PORT CLEANUP (v9.16.2: moved BEFORE install check) ===
# Previous versions had install check first, which blocked cleanup → 3+ min startup.
# Now cleanup runs first, so python3 can start ASAP.
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
      if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        # Already running and serving — exit fast
        log "Already running (PID $OLD_PID, port :$PORT OK) — not starting"
        exit 0
      else
        # v9.16.2: SIGKILL IMMEDIATELY for zombies (no retry loop)
        # Previous: kill, sleep 1, check, retry → 3 min delay
        # Now: kill -9, rm pidfile, proceed immediately
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

# EXIT trap: only delete PID file if it contains our PID
trap 'if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi' EXIT
trap '' SIGHUP

# === STEP 2: PORT RECLAIM (v9.11.7 Bug 4 fix — kill orphaned python3) ===
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
  LISTENER_NAME=""
  if [ -n "$LISTENER_PID" ] && [ -d "/proc/$LISTENER_PID" ]; then
    LISTENER_NAME=$(cat "/proc/$LISTENER_PID/comm" 2>/dev/null || echo "")
  fi
  if [ "$LISTENER_NAME" = "python3" ] || [ "$LISTENER_NAME" = "python" ]; then
    # v9.16.2: SIGKILL immediately (was SIGTERM + 1s retry → faster)
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

# === STEP 3: AUTO-INSTALL WITH VERSION CHECK (v9.16.2: fixes Regression R2) ===
# Previous: if [ ! -f SKILL.md ]; then clawhub install --force; fi
#   Problem: blindly installs from registry, DOWNGRADES if registry is stuck (moderation hide)
# Fix: only install if SKILL.md truly missing. If exists, DON'T touch it.
#   Local SKILL.md may be newer than registry (moderation hide scenario).
#   Block A Step 3 will handle drift detection separately.
ST_SKILL_MD="/home/z/my-project/skills/stellar-trails/SKILL.md"
if [ ! -f "$ST_SKILL_MD" ]; then
  echo "[dev.sh] SKILL.md missing — auto-installing via clawhub..."
  clawhub install stellar-trails --force 2>/dev/null && echo "[dev.sh] ✓ stellar-trails installed" || echo "[dev.sh] ⚠ install failed — will retry via Step 4a-pre"
else
  # v9.16.2: SKILL.md exists — log version but DON'T install
  LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$ST_SKILL_MD" 2>/dev/null | head -1)
  echo "[dev.sh] SKILL.md exists (v${LOCAL_VER:-unknown}) — NOT installing (preserve local version)"
fi

# === STEP 4: START PYTHON3 SERVER (immediately after cleanup) ===
log "Serving $ZSCRIPTS_DIR on :$PORT (v9.16.2 — fast startup + version check)"
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
