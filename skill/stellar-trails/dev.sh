#!/bin/bash
# stellar-trails dev server v9.16.4 — clawhub-preferred, no git dependency
#
# v9.16.4 changes from v9.16.3:
#   - REMOVED: git repo dependency (user preference: "jangan ketergantungan git, prefer clawhub")
#   - ADDED: clawhub inspect version check (bidirectional)
#   - ADDED: /home/user_skills/ persistent backup as clawhub-managed fallback
#
# Self-healing strategy (clawhub-preferred):
#   1. Check local SKILL.md version
#   2. Check clawhub registry version (clawhub inspect)
#   3. Bidirectional compare:
#      - local == registry → up to date, do nothing
#      - local < registry → clawhub install (upgrade from registry)
#      - local > registry → preserve local (moderation hide, don't downgrade)
#      - local missing → clawhub install
#   4. After install: sync dev.sh from skill dir to .zscripts/
#   5. Self-upgrade: if .zscripts/dev.sh differs from skill dir dev.sh → sync
#
# Persistent backup:
#   - /home/user_skills/stellar-trails.zip is clawhub-managed persistent storage
#   - If local skill dir wiped but zip exists → extract from zip
#   - This survives reboot (PolarFS persistent)

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

# Version comparison helper (returns: gt, lt, eq, unknown)
version_compare() {
  local v1="$1" v2="$2"
  if [ -z "$v1" ] || [ -z "$v2" ]; then echo "unknown"; return; fi
  if [ "$v1" = "$v2" ]; then echo "eq"; return; fi
  # Use sort -V for comparison
  local higher=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | tail -1)
  if [ "$higher" = "$v1" ]; then echo "gt"; else echo "lt"; fi
}

# === STEP 0: SELF-UPGRADE — sync .zscripts/dev.sh from skill dir ===
# If skill dir has dev.sh and it differs from .zscripts/dev.sh → sync
# This ensures .zscripts/dev.sh always matches the installed skill version
if [ -f "$LOCAL_DEV_SH" ] && [ -f "$0" ]; then
  SKILL_DEV_HASH=$(sha256sum "$LOCAL_DEV_SH" 2>/dev/null | cut -d' ' -f1)
  SELF_HASH=$(sha256sum "$0" 2>/dev/null | cut -d' ' -f1)
  if [ "$SKILL_DEV_HASH" != "$SELF_HASH" ]; then
    log "Self-upgrade: skill dir dev.sh differs — syncing to .zscripts/"
    cp -f "$LOCAL_DEV_SH" "$0"
    chmod +x "$0"
    log "Self-upgrade complete — restarting with skill dir dev.sh"
    exec bash "$0"
  fi
fi

# === STEP 1: SKILL VERSION CHECK (clawhub-preferred, bidirectional) ===
# Get local version
LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$LOCAL_SKILL_MD" 2>/dev/null | head -1)

# Get registry version via clawhub inspect
REG_VER=""
if command -v clawhub >/dev/null 2>&1; then
  REG_VER=$(clawhub inspect stellar-trails --json 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print((d.get('latestVersion') or {}).get('version') or '')
except: print('')
" 2>/dev/null || echo "")
fi

log "Version check: local=${LOCAL_VER:-missing} registry=${REG_VER:-unreachable}"

# Decision matrix
if [ -z "$LOCAL_VER" ]; then
  # Local SKILL.md missing — try persistent zip, then clawhub install
  if [ -f "$PERSISTENT_ZIP" ]; then
    log "SKILL.md missing — extracting from persistent zip ($PERSISTENT_ZIP)"
    mkdir -p "$LOCAL_SKILL_DIR"
    cd "$(dirname "$LOCAL_SKILL_DIR")"
    unzip -qo "$PERSISTENT_ZIP" 2>/dev/null || true
    cd "$ZSCRIPTS_DIR"
    LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$LOCAL_SKILL_MD" 2>/dev/null | head -1)
    log "Restored from zip: v${LOCAL_VER:-unknown}"
  fi
  
  if [ -z "$LOCAL_VER" ] && [ -n "$REG_VER" ]; then
    log "SKILL.md missing — installing from clawhub registry (v$REG_VER)"
    clawhub install stellar-trails --force 2>/dev/null && log "✓ installed v$REG_VER" || log "⚠ install failed"
    LOCAL_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$LOCAL_SKILL_MD" 2>/dev/null | head -1)
  fi
elif [ -n "$REG_VER" ]; then
  CMP=$(version_compare "$LOCAL_VER" "$REG_VER")
  case "$CMP" in
    eq)
      log "Local v$LOCAL_VER = registry v$REG_VER — up to date"
      ;;
    lt)
      log "Local v$LOCAL_VER < registry v$REG_VER — upgrading via clawhub"
      clawhub install stellar-trails --force 2>/dev/null && log "✓ upgraded to v$REG_VER" || log "⚠ upgrade failed"
      ;;
    gt)
      log "Local v$LOCAL_VER > registry v$REG_VER — PRESERVING local (registry may be stuck/moderation hide)"
      log "  Do NOT downgrade. Local is newer."
      ;;
    unknown)
      log "Version comparison inconclusive — preserving local"
      ;;
  esac
else
  log "Registry unreachable — preserving local v$LOCAL_VER"
fi

# === STEP 2: FAST PID/PORT CLEANUP ===
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
      if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        log "Already running (PID $OLD_PID, port :$PORT OK) — not starting"
        exit 0
      else
        log "PID $OLD_PID zombie — SIGKILL + immediate cleanup"
        kill -9 "$OLD_PID" 2>/dev/null || true
        rm -f "$PID_FILE"
      fi
    else
      log "PID $OLD_PID not dev.sh — cleaning up"
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

# === STEP 3: PORT RECLAIM ===
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
  LISTENER_NAME=""
  if [ -n "$LISTENER_PID" ] && [ -d "/proc/$LISTENER_PID" ]; then
    LISTENER_NAME=$(cat "/proc/$LISTENER_PID/comm" 2>/dev/null || echo "")
  fi
  if [ "$LISTENER_NAME" = "python3" ] || [ "$LISTENER_NAME" = "python" ]; then
    log "Port :$PORT in use by orphaned python3 — SIGKILL + reclaim"
    kill -9 "$LISTENER_PID" 2>/dev/null || true
    sleep 0.5
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
      log "Port :$PORT STILL in use — exiting"
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

# === STEP 4: SYNC .zscripts/ FROM SKILL DIR ===
# After version check, sync dev.sh + index.html + chibi.svg to .zscripts/
[ -f "$LOCAL_DEV_SH" ] && cp -f "$LOCAL_DEV_SH" "$ZSCRIPTS_DIR/dev.sh" && chmod +x "$ZSCRIPTS_DIR/dev.sh"
[ -f "$LOCAL_SKILL_DIR/index.html" ] && cp -f "$LOCAL_SKILL_DIR/index.html" "$ZSCRIPTS_DIR/index.html"
[ -f "$LOCAL_SKILL_DIR/chibi.svg" ] && cp -f "$LOCAL_SKILL_DIR/chibi.svg" "$ZSCRIPTS_DIR/chibi.svg" 2>/dev/null || true

# === STEP 5: START PYTHON3 SERVER ===
log "Serving $ZSCRIPTS_DIR on :$PORT (v9.16.4 — clawhub-preferred, no git dependency)"
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
