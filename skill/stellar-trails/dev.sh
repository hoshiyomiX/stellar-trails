#!/bin/bash
# stellar-trails dev server v9.17.0 — ClawHub compliant
#
# v9.17.0 compliance fixes:
#   - 127.0.0.1 binding (localhost only) — Fix #5
#   - Port hopping (3000-3003) — Fix #4, no process kill
#   - No self-upgrade (no self-restart) — Fix #3
#   - No auto-install (no clawhub install) — Fix #3
#   - No /proc/ access — Fix #4
#   - No kill of any process — Fix #4
#
# dev.sh is now a SIMPLE popup server: bind localhost, serve files, restart on crash.

set -e

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
LOG_FILE="/tmp/st-devsh.log"
PID_FILE="$ZSCRIPTS_DIR/st-devsh.pid"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# === PID FILE CLEANUP (no /proc/ access, no kill) ===
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ]; then
    # Check if port is serving — if yes, already running
    if curl -s -o /dev/null -m 1 http://127.0.0.1:3000/ 2>/dev/null; then
      log "Already serving on :3000 — not starting"
      exit 0
    fi
    # Port not serving — stale PID, clean up (no kill, just remove file)
    log "Stale PID file — cleaning up (no process kill)"
    rm -f "$PID_FILE"
  fi
fi
echo $$ > "$PID_FILE"
trap 'if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi' EXIT
trap '' SIGHUP

# === PORT HOPPING (Fix #4: no kill, just try next port) ===
PORT=3000
MAX_PORT=3003
while [ "$PORT" -le "$MAX_PORT" ]; do
  if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
    log "Port :$PORT occupied — trying :$((PORT + 1))"
    PORT=$((PORT + 1))
  else
    break
  fi
done
if [ "$PORT" -gt "$MAX_PORT" ]; then
  log "All ports :3000-:$MAX_PORT occupied — cannot start popup server"
  log "  To free a port: identify and stop the process manually"
  ss -tlnp 2>/dev/null | grep -E ':(300[0-3]) ' | while read line; do log "  $line"; done
  if [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi
  exit 0
fi
log "Selected port :$PORT"

# === SYNC FILES FROM SKILL DIR ===
SKILL_DIR="/home/z/my-project/skills/stellar-trails"
[ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS_DIR/index.html"
[ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS_DIR/chibi.svg" 2>/dev/null || true

# === START PYTHON3 SERVER (127.0.0.1 only — Fix #5) ===
log "Serving $ZSCRIPTS_DIR on 127.0.0.1:$PORT (v9.17.0 — ClawHub compliant)"
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
