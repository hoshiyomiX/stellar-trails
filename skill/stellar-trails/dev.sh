#!/bin/bash
# stellar-trails dev server v9.18.1 — clarified design
#
# Structure:
#   Phase 1 (run once): Skill restore + clawhub install if missing
#   Phase 2 (infinite loop): python3 popup server on 127.0.0.1:3000
#
# Called by: /start.sh at container boot (line 333: sudo -u z bash .zscripts/dev.sh)
# Also called by: Block A Step 2 in SKILL.md (if port not serving)

set -e

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
PORT="${PORT:-3000}"
PID_FILE="$ZSCRIPTS_DIR/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"
SKILL_DIR="/home/z/my-project/skills/stellar-trails"
SKILL_MD="$SKILL_DIR/SKILL.md"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# === PHASE 1: SKILL RESTORE (run once) ===
# Instruction #2: Restore skill stellar-trails if missing, skip if complete
# Instruction #3: Self-update = clawhub install (not dev.sh self-replace)

if [ ! -f "$SKILL_MD" ]; then
  log "SKILL.md missing — restoring stellar-trails via clawhub..."
  # FIX v9.18.2: clawhub install uses CWD for skills/ dir.
  # Must run from /home/z/my-project/ so it installs to skills/stellar-trails/
  # NOT from .zscripts/ (which would create .zscripts/skills/stellar-trails/)
  cd /home/z/my-project
  if clawhub install stellar-trails --force 2>/dev/null; then
    RESTORED_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$SKILL_MD" 2>/dev/null | head -1 || echo 'unknown')
    if [ -f "$SKILL_MD" ]; then
      log "✓ Skill restored: v${RESTORED_VER} at $SKILL_MD"
    else
      log "✗ Skill restore: clawhub exited 0 but SKILL.md not found at $SKILL_MD"
      log "  Check if clawhub installed to wrong directory"
    fi
  else
    log "✗ Skill restore FAILED (clawhub install failed — network or account issue)"
  fi
  cd "$ZSCRIPTS_DIR"
else
  LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$SKILL_MD" 2>/dev/null | head -1)
  log "✓ Skill present: v${LOCAL_VER:-unknown} — skip restore"
fi

# === PID CLEANUP (smart: only kill verified dev.sh) ===
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
      if curl -s -o /dev/null -m 1 "http://127.0.0.1:$PORT/" 2>/dev/null; then
        log "Already serving on :$PORT (PID $OLD_PID) — skip start"
        exit 0
      else
        log "Stale dev.sh PID $OLD_PID (not serving) — cleaning up"
        kill "$OLD_PID" 2>/dev/null || true
        sleep 0.5
        if [ -d "/proc/$OLD_PID" ]; then
          STILL=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
          if echo "$STILL" | grep -q 'dev\.sh'; then
            kill -9 "$OLD_PID" 2>/dev/null || true
            sleep 0.5
          fi
        fi
        rm -f "$PID_FILE"
      fi
    else
      log "PID $OLD_PID is not dev.sh — skip, clean PID file"
      rm -f "$PID_FILE"
    fi
  else
    log "Stale PID file — cleaning up"
    rm -f "$PID_FILE"
  fi
fi
echo $$ > "$PID_FILE"
trap 'if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi' EXIT
trap '' SIGHUP

# === PORT CHECK (report conflict, try next port) ===
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
  LISTENER_NAME=""
  if [ -n "$LISTENER_PID" ] && [ -d "/proc/$LISTENER_PID" ]; then
    LISTENER_NAME=$(cat "/proc/$LISTENER_PID/comm" 2>/dev/null || echo "")
  fi
  if [ "$LISTENER_NAME" = "python3" ] || [ "$LISTENER_NAME" = "python" ]; then
    log "Port :$PORT occupied by python3 (likely our orphan) — reclaiming"
    kill "$LISTENER_PID" 2>/dev/null || true
    sleep 0.5
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
      kill -9 "$LISTENER_PID" 2>/dev/null || true
      sleep 0.5
    fi
  else
    log "Port :$PORT occupied by ${LISTENER_NAME:-unknown} — trying :$((PORT + 1))"
    PORT=$((PORT + 1))
  fi
fi

# === SYNC FILES ===
[ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS_DIR/index.html"
[ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS_DIR/chibi.svg" 2>/dev/null || true

# === PHASE 2: POPUP SERVER (infinite loop + ) ===
# Instruction #1: Running di localhost:3000
# Instruction #4: Infinite loop needed (auto-restart on crash)
# Instruction #5: SIGHUP trap handles terminal close

log "Serving on 127.0.0.1:$PORT (v9.18.1 — restore + localhost + smart kill + loop)"
log "PID: $$ | Phase 2: popup server (infinite loop)"

BACKOFF=1
while true; do
  START_TIME=$(date +%s)
  log "Starting python3 (backoff=${BACKOFF}s, port=$PORT)"

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

with ReuseTCPServer(('127.0.0.1', $PORT), NoCacheHandler) as httpd:
    httpd.serve_forever()
" 2>>"$LOG_FILE" || true

  END_TIME=$(date +%s)
  UPTIME=$((END_TIME - START_TIME))
  log "python3 exited (uptime: ${UPTIME}s)"

  if [ "$UPTIME" -lt 2 ]; then
    log "Rapid crash — backing off ${BACKOFF}s"
    sleep "$BACKOFF"
    BACKOFF=$((BACKOFF * 2))
    [ "$BACKOFF" -gt 30 ] && BACKOFF=30
  else
    log "Normal exit — restarting"
    BACKOFF=1
    sleep 1
  fi
done
