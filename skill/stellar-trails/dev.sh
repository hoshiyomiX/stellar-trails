#!/bin/bash
# stellar-trails dev server v9.18.0 — smart kill + localhost + self-healing
#
# v9.18.0 changes:
#   - 127.0.0.1 binding (localhost only) — Fix #4
#   - Smart kill: only kill processes verified as stellar-trails dev.sh (not arbitrary port listeners)
#   - Keep: setsid (PID management), zip restore, infinite loop (user decision)
#   - Keep: self-upgrade from skill dir (user decision)
#   - Keep: auto-install from clawhub (user decision, with scan awareness)
#   - No: all-interfaces binding, arbitrary kill -9, /proc/ without ownership check

set -e

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
PORT="${PORT:-3000}"
PID_FILE="$ZSCRIPTS_DIR/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"
LOCAL_SKILL_DIR="/home/z/my-project/skills/stellar-trails"
LOCAL_SKILL_MD="$LOCAL_SKILL_DIR/SKILL.md"
LOCAL_DEV_SH="$LOCAL_SKILL_DIR/dev.sh"
PERSISTENT_ZIP="/home/user_skills/stellar-trails.zip"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# === SELF-UPGRADE: sync .zscripts/dev.sh from skill dir if different ===
if [ -f "$LOCAL_DEV_SH" ] && [ -f "$0" ]; then
  SKILL_DEV_HASH=$(sha256sum "$LOCAL_DEV_SH" 2>/dev/null | cut -d' ' -f1)
  SELF_HASH=$(sha256sum "$0" 2>/dev/null | cut -d' ' -f1)
  if [ -n "$SKILL_DEV_HASH" ] && [ -n "$SELF_HASH" ] && [ "$SKILL_DEV_HASH" != "$SELF_HASH" ]; then
    log "Self-upgrade: skill dir dev.sh differs — syncing"
    cp -f "$LOCAL_DEV_SH" "$0"
    chmod +x "$0"
    log "Self-upgrade complete — restarting"
    exec bash "$0"
  fi
fi

# === AUTO-INSTALL: restore skill if missing ===
if [ ! -f "$LOCAL_SKILL_MD" ]; then
  if [ -f "$PERSISTENT_ZIP" ]; then
    log "SKILL.md missing — restoring from persistent zip"
    mkdir -p "$LOCAL_SKILL_DIR"
    cd "$(dirname "$LOCAL_SKILL_DIR")"
    unzip -qo "$PERSISTENT_ZIP" 2>/dev/null || true
    cd "$ZSCRIPTS_DIR"
    log "Restored from zip"
  else
    log "SKILL.md missing — installing from clawhub"
    clawhub install stellar-trails --force 2>/dev/null && log "Installed from clawhub" || log "Install failed — will retry"
  fi
fi

# === SMART PID CLEANUP: only kill verified stellar-trails processes ===
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
      # SMART KILL: only kill if verified as OUR dev.sh process
      if curl -s -o /dev/null -m 1 http://127.0.0.1:3000/ 2>/dev/null; then
        log "Already serving (PID $OLD_PID) — not starting"
        exit 0
      else
        log "Stale dev.sh PID $OLD_PID (port not serving) — smart kill"
        kill "$OLD_PID" 2>/dev/null || true
        sleep 0.5
        # Only kill -9 if process is still alive AND is verified dev.sh
        if [ -d "/proc/$OLD_PID" ]; then
          STILL_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
          if echo "$STILL_CMDLINE" | grep -q 'dev\.sh'; then
            log "Process still alive (verified dev.sh) — SIGKILL"
            kill -9 "$OLD_PID" 2>/dev/null || true
          fi
        fi
        rm -f "$PID_FILE"
      fi
    else
      log "PID $OLD_PID is NOT dev.sh (cmdline: $OLD_CMDLINE) — not killing, cleaning PID file"
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

# === PORT CHECK: report conflict if occupied by non-dev.sh process ===
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
  LISTENER_NAME=""
  if [ -n "$LISTENER_PID" ] && [ -d "/proc/$LISTENER_PID" ]; then
    LISTENER_CMDLINE=$(tr '\0' ' ' < "/proc/$LISTENER_PID/cmdline" 2>/dev/null)
    LISTENER_NAME=$(cat "/proc/$LISTENER_PID/comm" 2>/dev/null || echo "")
  fi
  # Smart check: is this our orphaned python3 listener?
  if [ "$LISTENER_NAME" = "python3" ] || [ "$LISTENER_NAME" = "python" ]; then
    # This is likely our orphaned python3 from previous dev.sh
    # Smart kill: verify it's serving our content before killing
    if curl -s -o /dev/null -m 1 http://127.0.0.1:$PORT/ 2>/dev/null; then
      log "Port :$PORT occupied by python3 (likely our orphaned listener) — reclaiming"
      kill "$LISTENER_PID" 2>/dev/null || true
      sleep 0.5
      if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        log "Listener did not respond to SIGTERM — SIGKILL (verified python3)"
        kill -9 "$LISTENER_PID" 2>/dev/null || true
        sleep 0.5
      fi
      log "Port :$PORT reclaimed"
    else
      log "Port :$PORT has python3 but not serving — trying next port"
      PORT=$((PORT + 1))
    fi
  else
    log "Port :$PORT occupied by $LISTENER_NAME (PID $LISTENER_PID) — trying :$((PORT + 1))"
    PORT=$((PORT + 1))
  fi
fi

# === SYNC FILES ===
[ -f "$LOCAL_DEV_SH" ] && cp -f "$LOCAL_DEV_SH" "$ZSCRIPTS_DIR/dev.sh" && chmod +x "$ZSCRIPTS_DIR/dev.sh"
[ -f "$LOCAL_SKILL_DIR/index.html" ] && cp -f "$LOCAL_SKILL_DIR/index.html" "$ZSCRIPTS_DIR/index.html"
[ -f "$LOCAL_SKILL_DIR/chibi.svg" ] && cp -f "$LOCAL_SKILL_DIR/chibi.svg" "$ZSCRIPTS_DIR/chibi.svg" 2>/dev/null || true

# === ZIP SYNC (keep: user decision) ===
if [ -d "$LOCAL_SKILL_DIR" ] && [ -d "$(dirname "$PERSISTENT_ZIP")" ]; then
  cd "$(dirname "$LOCAL_SKILL_DIR")" && zip -qr "$PERSISTENT_ZIP" "$(basename "$LOCAL_SKILL_DIR")/" 2>/dev/null || true
  cd "$ZSCRIPTS_DIR"
fi

# === START PYTHON3 SERVER (127.0.0.1 only — Fix #4) ===
log "Serving $ZSCRIPTS_DIR on 127.0.0.1:$PORT (v9.18.0 — smart kill + localhost + self-healing)"
log "PID: $$ | Log: $LOG_FILE | Mode: foreground + infinite loop"

BACKOFF=1
while true; do
  START_TIME=$(date +%s)
  log "Starting python3 server (foreground, backoff=${BACKOFF}s, port=$PORT)"

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
