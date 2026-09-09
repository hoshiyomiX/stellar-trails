---
name: stellar-trails
description: "Activates on every task: coding (features, bugs, refactoring, scripts), documents (reports, proposals, DOCX, PDF), charts and visualizations, data processing, complex multi-step planning, or even simple questions. Provides a six-phase workflow with traceability IDs, entry/exit gates, scope commitment, and three enforcement layers (phase machine, mandatory prints, preferences dialog). Complexity adapts per task tier. Use this skill whenever the user asks to build, fix, analyze, create, plan, or process anything — the framework runs internally for trivial tasks and fully for complex ones. Web development (Next.js, UI) is delegated to fullstack-dev; this framework wraps the workflow around it."
license: MIT-0
metadata:
  topics:
    - agent-workflow
    - phase-machine
    - phase-workflow
    - task-workflow
    - llm-agents
    - task-management
    - traceability
    - zai
---

## Metadata

- **version**: 9.15.3

---

## Activation

### ⚠️ CRITICAL: Pre-Tool-Call Gate (E4 — Layer 1, NEW in v9.3.0)

Before calling ANY tool (Read, Write, Bash, Edit, Grep, Glob, Task, etc.) in a session, the activation banner MUST have been printed AND Steps 1–5 must have been executed. If you are about to call a tool and have NOT printed the banner + completed all 5 steps, STOP and do activation FIRST.

**Self-check before first tool call**:
- Have I printed `☄️ STELLAR TRAILS · vX.Y.Z · ACTIVE`? → If NO, print it NOW
- Have I executed Steps 1–5 with `✓`/`✗` marks? → If NO, execute them NOW
- Have I printed `✓ Step 5`? → If NO, do not proceed to any tool

This is a **HARD GATE**. No tool call may precede the banner + 5 steps. Violating this gate is a correctness bug, not a style preference.

**Why this gate exists**: Audit of 5 prior sessions found 0/5 compliance with activation mandate. LLMs rationalize skipping ("continuation task", "simple task", "save tokens", "user didn't complain last time"). The gate makes skipping impossible to rationalize — you literally cannot call a tool until activation is done.

**Subagent exemption (added v9.11.4)**: This gate applies to the **main agent** only. Subagents in z.ai receive a compressed task prompt from the orchestrator — they do NOT have SKILL.md pre-loaded into context. To learn the gate exists, a subagent would have to call `Skill(command="stellar-trails")`, which is itself a pre-banner tool call (chicken-and-egg). Therefore E4 is structurally unenforceable on subagents. If subagent compliance is required, the orchestrating main agent MUST pre-inject the relevant SKILL.md sections (activation mandate + step bash blocks) into the subagent's task prompt — only then can the subagent comply. Verified by SIM-001/SIM-002 audit (v9.11.3): both `Explore` and `general-purpose` subagents can call `Skill()` and read SKILL.md from disk, but neither prints the banner first because they have no prior knowledge of the mandate.

### FIRST OUTPUT — Print this banner, then execute Steps 1–5

Your VERY FIRST output to the user is the activation banner below. No other text precedes it. Print the banner, then run Steps 1–5.

**Why print every invoke**: After context truncation, neither you nor the user know whether the banner was already printed. The banner is the only reliable signal that activation ran. Skipping it because "I already did it" is a correctness bug — you cannot reliably know what you did before truncation.

**Banner version is DYNAMIC**: Read the version from the `## Metadata` section at the top of this file (the `- **version**: X.Y.Z` line). Substitute that version into the banner below where you see `<VERSION>`. Do NOT hardcode the version — every version bump must automatically reflect in the banner without editing this template. (Fixes the v9.2.1 bug where the banner was stuck at v9.1.0 because it was hardcoded.)

```
☄️ STELLAR TRAILS · v<VERSION> · ACTIVE
├─ Phase: IDLE → SPECIFY
├─ Complexity: [tier] | Task Type: [type] | Continuation: [NEW / YES]
└─ Activation checklist (1–5, every invoke) — executing:
   ├─ 1  Refresh context + SSV            ...
   ├─ 2  Start popup server               ...
   ├─ 3  Auto-update via ClawHub          ...
   ├─ 4  Verify files + sync zip          ...
   └─ 5  Load phases + classify           ...
```

Replace `...` with `✓` (success) or `✗` (failure) as each step completes.

### Activation Enforcement Vectors (E7-E11, NEW in v9.4.0)

Text enforcement (E1-E6) caps at ~70-85% compliance because LLMs can rationalize past text. The 5 vectors below use **sandbox-native mechanisms** that LLMs cannot fabricate — tool calls are ground truth, file tokens are verifiable, external oracles cannot be faked.

**Expected compliance**: ~90-93% automated, ~95% with active user verification of transcript.

#### Vektor 1 — Hash Token Gate (E7)

Every bash block in activation writes/verifies a hash token. LLM cannot proceed past Block B without Block A having actually run.

**Token file**: `/tmp/st-active` + `/tmp/st-session-meta` (session-scoped, wiped on session reset)
**Token content** (v9.15.0): `sha256(version:timestamp:pid)[:16]` — session-specific, NOT version-derived

Block A writes both files. Block B verifies:
1. Both files exist
2. Token age ≤ 120s (freshness check, Proposal 2)
3. Token matches recomputation from `version + session_meta` (proves token wasn't fabricated)

```bash
# Block B gate check (top of Block B bash):
if [ ! -f /tmp/st-active ] || [ ! -f /tmp/st-session-meta ]; then
  echo "✗ Block B GATE FAILED: token files missing — Block A must run first"
  exit 1
fi
TOKEN_AGE=$(( $(date +%s) - $(stat -c %Y /tmp/st-active) ))
if [ "$TOKEN_AGE" -gt 120 ]; then
  echo "✗ Block B GATE FAILED: token is ${TOKEN_AGE}s old (max 120s) — re-run Block A"
  exit 1
fi
SESSION_META=$(cat /tmp/st-session-meta)
EXPECTED_TOKEN=$(printf '%s' "${ST_VERSION}:${SESSION_META}" | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Block B GATE FAILED: token mismatch — token does not match session_meta"
  exit 1
fi
```

**Why this is now CODE-ENFORCED (not PARTIAL)**: The token includes `$$` (bash PID of Block A) and `$(date +%s)` (unix timestamp when Block A ran). An LLM cannot fabricate this token without actually running bash — it has no way to know what PID or timestamp bash will assign. Previous session's token won't work because timestamp will be >120s old. Concurrent sessions' tokens won't work because PIDs differ.

**Residual bypass**: A rationalizing LLM could still compute the token directly by running `echo "9.15.0:$(date +%s):$$" | sha256sum` — but this requires running bash, which is itself a tool call recorded in transcript. The gate's purpose is to force Block A to actually execute bash, not to cryptographically prove identity.

**Subagent write access caveat (added v9.11.4, still applies)**: `/tmp/st-active` and `/tmp/st-session-meta` are world-writable. A subagent CAN overwrite them. But the freshness check (120s) means the subagent would have to overwrite within 120s of Block B running — and the orchestrating main agent should pre-validate before trusting.

#### Vektor 2 — TodoWrite Live Marker (E8)

TodoWrite is a platform tool that renders a live checklist visible to the user in real-time. The user sees checkboxes transition `pending → in_progress → completed` as the LLM works. This is **visibility enforcement** — user can SEE if steps are being executed, not just trust LLM's text claims.

**Mandatory protocol** (before Step 1 bash):
1. Call `TodoWrite` with 5 items (Step 1 through Step 5), all status `pending`
2. Before executing each Step N bash: call `TodoWrite` to mark Step N `in_progress`
3. After each Step N bash succeeds: call `TodoWrite` to mark Step N `completed`
4. If any Step N fails: leave as `in_progress`, do NOT mark `completed`

**Why this works**: TodoWrite is a tool call recorded in transcript. LLM cannot fabricate "I marked Step 3 completed" without actually calling TodoWrite. User sees the live checklist — if Step 3 is marked `completed` but no Bash tool call for Step 3 appears in transcript, fraud is visible.

**Edge case**: LLM could mark all 5 `completed` in a single TodoWrite call without running anything. Mitigation: user watches for the **transition** (pending → in_progress → completed), not just final state. Single-call mass-marking is suspicious.

#### Vektor 3 — Persistent Activation Log (E9)

Each successful activation appends to `/home/user_skills/.st-activation-log` (persistent across sessions). User can audit this file anytime.

**Log entry format** (one line per activation — corrected v9.13.1 to match actual Step 5 bash output):
```
YYYY-MM-DDTHH:MM:SSZ v<VERSION> token=<hash> steps=5/5 banner=YES
```

Step 5 writes the log entry. Next session's Step 1 can read the log to verify prior activations occurred. LLM can fake a log entry, but:
- Timestamps must be monotonic — fake entries with wrong timestamps are detectable
- No session ID is recorded — the log proves WHEN an activation happened, never WHO did it
- User can `cat /home/user_skills/.st-activation-log` to audit anytime

**Empirical persistence + multi-session caveat (added v9.13.1)**: Cross-session persistence is a **verified fact**, not an aspiration. At audit time the log held 326 entries across 38 distinct days (2026-07-11 → 2026-08-23, versions v9.4.0 → v9.13.0) with **0 timestamp-monotonicity violations**. However, the sandbox filesystem is **shared by concurrent sessions**, and their entries interleave indistinguishably. On 2026-08-23 alone, ≥2 sessions interleaved within one hour — including a `COMPLIANCE v9.13.0 score=12/12` entry that belongs to a session which wrote **no adjacent activation entry**. Only version/token discontinuities distinguish the sessions. **The log proves WHEN, never WHO.**

**Best-effort caveat (added v9.11.4)**: `/home/user_skills/` is world-writable (`drwxrwxrwx` mode 0777) in the z.ai sandbox, meaning any process — including subagents — can modify or append to the activation log. This vector is fraud-detection (anomalous timestamps are visible on audit), not fraud-prevention. The real value of E9 is **visibility for the user**, not cryptographic integrity.

#### Vektor 4 — Read Tool Line-Number Proof (E10)

Step 1 must print a specific line from SKILL.md in the format `Read` tool returns (`<line_number>→<content>`). LLM cannot fabricate this format without actually calling Read.

**Protocol**: After Read SKILL.md, print the version line with its line number:
```
SKILL.md line 19: 19→- **version**: 9.4.0
```

User can verify by reading the same file themselves. If LLM fabricates (e.g., wrong line number, wrong content), user catches it on spot-check.

**Limitation**: LLM knows line 19 is the version line (from context). Stronger variant: skill mandates "print line N where N = current day-of-month + 10" — LLM cannot predict which line user will verify. But this adds complexity; the simple variant is sufficient for now.

#### Vektor 5 — Clawhub Oracle Cross-Check (E11)

Block A runs `clawhub inspect` and writes output to `/tmp/st-clawhub-oracle.json`. Block B **re-runs `clawhub inspect`** (Proposal 4, v9.15.0) and cross-checks the version matches the cached oracle.

**Protocol** (v9.15.0):
- Block A writes `clawhub inspect --json` output to `/tmp/st-clawhub-oracle.json`
- Block B runs a FRESH `clawhub inspect --json` to `/tmp/st-clawhub-oracle-verify.json`
- Block B extracts `latestVersion.version` from both files
- If versions mismatch → COMPLIANCE FAILURE (exit 1)
- If fresh inspect fails (network) → warning, but proceeds with cached

```bash
# Block B E11 re-verification (Proposal 4)
clawhub inspect stellar-trails --json > /tmp/st-clawhub-oracle-verify.json 2>/dev/null
FRESH_VERSION=$(python3 -c "import json; d=json.load(open('/tmp/st-clawhub-oracle-verify.json')); print((d.get('latestVersion') or {}).get('version') or '')" 2>/dev/null || echo "")
CACHED_VERSION=$(python3 -c "import json; d=json.load(open('/tmp/st-clawhub-oracle.json')); print((d.get('latestVersion') or {}).get('version') or '')" 2>/dev/null || echo "")
if [ -z "$FRESH_VERSION" ]; then
  echo "⚠️ Block B E11 WARNING: fresh clawhub inspect failed — using cached oracle"
elif [ "$FRESH_VERSION" != "$CACHED_VERSION" ]; then
  echo "✗ Block B E11 FAILED: oracle mismatch — cached=$CACHED_VERSION, fresh=$FRESH_VERSION"
  exit 1
fi
```

**Why this is now CODE-ENFORCED (not PARTIAL)**: Even if an LLM fabricates `/tmp/st-clawhub-oracle.json` with fake JSON, Block B's fresh `clawhub inspect` call will return the REAL registry version. If they don't match, exit 1. The LLM cannot fabricate the fresh clawhub output because clawhub is an external binary.

**Cost**: One extra `clawhub inspect` call (~2s). Acceptable for the verification gain.

**Fabrication caveat (corrected v9.11.4 → v9.15.0)**: Previous versions claimed the cached oracle file was the protection. v9.15.0 makes the FRESH clawhub call the protection. The cached file is now just an audit artifact — the fresh call is the actual oracle. A fabricated cached file will be caught by the fresh call's mismatch.

**Parse-defensiveness note (added v9.13.1, retained)**: Live registry responses may **omit or null** fields like `moderation.state`. Always extract `latestVersion.version` defensively.

#### Combined Enforcement Matrix (v9.15.0)

| Vector | What it enforces | LLM can fake? | User can verify? |
|---|---|---|---|
| E7 Hash token | Block B cannot run without Block A (token + session_meta + freshness) | NO (token requires $$ PID + $(date) — cannot be computed without running bash) | YES (cat /tmp/st-active + /tmp/st-session-meta) |
| E8 TodoWrite | Block A completion verified via /tmp/st-todolist proxy (v9.15.2) + live UI via TodoWrite platform tool | Partially (proxy is CODE-ENFORCED; live UI still requires LLM TodoWrite call) | YES (cat /tmp/st-todolist + watch live checklist) |
| E9 Persistent log | Cross-session audit trail | Partially (timestamps monotonic; no session ID) | YES (cat /home/user_skills/.st-activation-log) |
| E10 Line-number proof | Block A actually read SKILL.md | Partially (LLM knows line 19) | YES (read same file, compare) |
| E11 Clawhub oracle | Block A actually ran clawhub (re-verified fresh in Block B) | NO (fresh clawhub inspect is ground truth; fabricated cached file caught by mismatch) | YES (cat /tmp/st-clawhub-oracle.json + run clawhub inspect) |

**What still cannot be enforced**: Banner printed as FIRST output (text ordering), LLM not printing fake `✓` markers (text), TodoWrite platform tool live UI (bash cannot invoke TodoWrite — but v9.15.2 adds /tmp/st-todolist proxy as CODE-ENFORCED audit trail). These remain text-only enforcement via E4-E6.

### 2-Block Activation Protocol (NEW v9.15.0 — replaces 5-Block Protocol)

**Why 2-Block**: Audit v9.14.2 (see `/home/z/my-project/download/code-enforcement-audit-v9.14.2.md`) found that LLMs routinely compress 5 separate bash blocks into 1 combined block for token efficiency, destroying the natural enforcement boundaries between steps. Rather than fight this tendency, the 2-Block Protocol embraces it: 2 blocks is the minimum that preserves the Step 1 → Step 2+ ordering (bootstrap → verify+sync+log). Each block internally enforces all gates that were previously enforced by separate bash blocks.

**Block A — Bootstrap** (Steps 1+2+3+4 combined): Banner + SSV + E7 token write (with session_meta, Proposal 6) + E10 line proof + popup server start + clawhub oracle write + file verification + .zscripts sync + dev.sh restart + zip sync.

**Block B — Verify + Log + GREEN Gate** (Step 5): E7 gate with freshness check (Proposal 2) + E11 re-run clawhub cross-check (Proposal 4) + E9 log write + worklog rotation + knowledge load + conditional 5/5 GREEN (Proposal 1) + mechanical compliance score.

**Why this preserves enforcement**: Block B's gate check verifies `/tmp/st-active` exists AND was modified within last 120s (Proposal 2). This means Block A MUST have run recently. Block B's E8 gate verifies `/tmp/st-todolist` has `block-a:completed` marker (Proposal 7, v9.15.2) — proves Block A finished fully, not just started. Block B's E11 re-runs `clawhub inspect` and compares to cached oracle (Proposal 4) — fabricated oracle files fail this check. The 6/6 GREEN echo is now conditional on `SCORE=6` (Proposal 1 + Proposal 7) — it cannot be printed if any artifact is missing or stale.

**E8 TodoWrite (dual-layer v9.15.2)**: 
- **CODE-ENFORCED layer**: Block A writes `block-a:completed:<timestamp>:pid=<pid>:token=<hash>` to `/tmp/st-todolist` at END (only if all steps pass). Block B verifies this marker exists before running. User can `cat /tmp/st-todolist` for audit trail.
- **TEXT-ENFORCED layer**: LLM should ALSO call `TodoWrite` platform tool with 2 items ("Block A: Bootstrap", "Block B: Verify+Log+GREEN") for live UI visibility. This provides real-time checklist transitions that bash proxy cannot.
- **Why dual-layer**: bash cannot call TodoWrite platform tool. Proxy file catches skip/partial-execution at audit level. TodoWrite platform tool provides live UX. Both are needed for full E8 compliance.

### Block A — Bootstrap (Steps 1-4 combined)

**What this block does**: Re-read SKILL.md, print banner, write E7 token + session_meta, start popup server, run clawhub inspect, verify files, sync .zscripts, restart dev.sh, sync zip. All in one bash invocation.

```bash
# v9.15.0 Block A: Bootstrap — combines Steps 1-4 of legacy protocol.
# E7 token now includes session_meta (Proposal 6): sha256(version:timestamp:pid)[:16]
# This makes token session-specific — previous session's token won't pass Block B's gate.
_SKILL_MD="/home/z/my-project/skills/stellar-trails/SKILL.md"
_ST_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$_SKILL_MD" | head -1)
echo "☄️ STELLAR TRAILS · v${_ST_VER} · ACTIVE"
echo "├─ Phase: IDLE → SPECIFY"
echo "├─ Complexity: [tier] | Task Type: [type] | Continuation: [NEW / YES]"
echo "└─ 2-Block Activation Protocol — Block A (Bootstrap) executing:"
# === Step 1: SSV (Source State Verification) ===
if [ -d "$HOME/.stellar-trails-repo/.git" ]; then
  git -C "$HOME/.stellar-trails-repo" fetch origin --quiet
  BRANCH=$(git -C "$HOME/.stellar-trails-repo" branch --show-current || echo main)
  BEHIND=$(git -C "$HOME/.stellar-trails-repo" rev-list --count HEAD..origin/$BRANCH)
  if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then echo "✗ Block A Step 1 FAILED: skill repo is $BEHIND commits behind origin"; exit 1
  else echo "✓ Block A Step 1: SSV passed (v$_ST_VER)"; fi
else
  echo "✓ Block A Step 1: context refreshed (v$_ST_VER) — SSV skipped (no skill git repo)"
fi
# === Proposal 6: E7 token with session_meta ===
# Token = sha256(version:timestamp:pid)[:16] — session-specific, not version-derived.
# Previous session's token won't pass Block B's gate because timestamp differs.
# LLM cannot compute this token without actually running this bash (needs $$ PID + $(date)).
_ST_SESSION_TS=$(date +%s)
_ST_SESSION_PID=$$
echo "${_ST_SESSION_TS}:${_ST_SESSION_PID}" > /tmp/st-session-meta
printf '%s' "${_ST_VER}:${_ST_SESSION_TS}:${_ST_SESSION_PID}" | sha256sum | cut -c1-16 > /tmp/st-active
# === E10: Line-number proof ===
SKILL_VERSION_LINE=$(grep -n '^- \*\*version\*\*:' "$_SKILL_MD" | head -1 | cut -d: -f1)
echo "  E7 token: $(cat /tmp/st-active) (session_meta: ts=${_ST_SESSION_TS} pid=${_ST_SESSION_PID})"
echo "  E10 line proof: SKILL.md line ${SKILL_VERSION_LINE}: $(sed -n "${SKILL_VERSION_LINE}p" "$_SKILL_MD")"
# === Auto Git Identity Setup ===
if [ -f /home/z/my-project/upload/PAT ]; then
  _GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
  _OWNER_JSON=$(curl -sS -m 10 -H "Authorization: Bearer $_GH_TOKEN" https://api.github.com/user)
  _OWNER_LOGIN=$(echo "$_OWNER_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('login',''))")
  if [ -n "$_OWNER_LOGIN" ]; then
    _OWNER_NAME=$(echo "$_OWNER_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name') or d.get('login',''))")
    _OWNER_EMAIL="${_OWNER_LOGIN}@users.noreply.github.com"
    git config --global user.email "$_OWNER_EMAIL"
    git config --global user.name "$_OWNER_NAME"
    git config --global credential.helper store
    echo "https://${_OWNER_LOGIN}:${_GH_TOKEN}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    export GIT_AUTHOR_NAME="$_OWNER_NAME" GIT_AUTHOR_EMAIL="$_OWNER_EMAIL"
    export GIT_COMMITTER_NAME="$_OWNER_NAME" GIT_COMMITTER_EMAIL="$_OWNER_EMAIL"
    echo "  Git identity: $_OWNER_NAME <$_OWNER_EMAIL> (auto-configured from PAT)"
  fi
fi
# === Step 2: Popup server ===
SKILL_DIR="/home/z/my-project/skills/stellar-trails"; ZSCRIPTS="/home/z/my-project/.zscripts"
if [ ! -f "$SKILL_DIR/chibi.svg" ]; then for REPO_CLONE in "/home/z/my-project/stellar-trails/skill/stellar-trails" "/home/z/my-project/.stellar-trails-repo/skill/stellar-trails" "$HOME/.stellar-trails-repo/skill/stellar-trails"; do [ -f "$REPO_CLONE/chibi.svg" ] && cp -f "$REPO_CLONE/chibi.svg" "$SKILL_DIR/chibi.svg" && break; done; fi
if [ -d "$SKILL_DIR" ]; then mkdir -p "$ZSCRIPTS"; [ -f "$SKILL_DIR/dev.sh" ] && cp -f "$SKILL_DIR/dev.sh" "$ZSCRIPTS/dev.sh" && chmod +x "$ZSCRIPTS/dev.sh"; [ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS/index.html"; [ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS/chibi.svg"; fi
DEV_SH="$ZSCRIPTS/dev.sh"; [ -f "$DEV_SH" ] && ! ss -tlnp | grep -q ':3000 ' && ( setsid bash "$DEV_SH" </dev/null >/dev/null 2>&1 & ) &
sleep 1
HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
MASCOT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/chibi.svg)
if [ "$HTTP" = "200" ]; then echo "✓ Block A Step 2: popup server on :3000 (HTTP $HTTP, mascot $MASCOT)"; else echo "✗ Block A Step 2 FAILED: popup not responding (HTTP $HTTP)"; exit 1; fi
# === Step 3: ClawHub oracle (E11) ===
CURRENT=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$_SKILL_MD" | head -1)
clawhub inspect stellar-trails --json > /tmp/st-clawhub-oracle.json
LATEST=$(python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" < /tmp/st-clawhub-oracle.json || echo "")
if [ -z "$CURRENT" ]; then echo "✗ Block A Step 3 FAILED: could not read current version"; exit 1
elif [ -z "$LATEST" ]; then echo "✗ Block A Step 3 FAILED: could not reach ClawHub registry"; exit 1
elif [ "$CURRENT" = "$LATEST" ]; then echo "✓ Block A Step 3: up to date (v$CURRENT) — E11 oracle: $(stat -c%s /tmp/st-clawhub-oracle.json) bytes"
else
  echo "⚠️ Block A Step 3: DRIFT DETECTED — local v$CURRENT vs registry v$LATEST — FORCE UPDATING..."
  clawhub --no-input update stellar-trails --force
  UPDATE_EXIT=$?
  if [ $UPDATE_EXIT -ne 0 ]; then echo "✗ Block A Step 3 FAILED: clawhub update exited $UPDATE_EXIT"; exit 1; fi
  POST_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$_SKILL_MD" | head -1)
  if [ "$POST_VERSION" != "$LATEST" ]; then echo "✗ Block A Step 3 FAILED: update claimed success but local still v$POST_VERSION"; exit 1; fi
  echo "✓ Block A Step 3: FORCE UPDATE CONFIRMED — local v$POST_VERSION = registry v$LATEST"
  USER_SKILLS_DIR="/home/user_skills"
  if [ -d "$SKILL_DIR" ] && [ -d "$USER_SKILLS_DIR" ]; then cd "$(dirname "$SKILL_DIR")" && zip -qr "$USER_SKILLS_DIR/stellar-trails.zip" "$(basename "$SKILL_DIR")/" && echo "✓ Block A Step 3: zip synced to v$LATEST"; fi
fi
# === Step 4: File verify + .zscripts sync + dev.sh restart + zip sync ===
# v9.14.1: Install-if-missing — if skill was wiped by container reboot, auto-install.
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  echo "⚠️ Block A Step 4a-pre: SKILL.md missing — auto-installing stellar-trails via clawhub..."
  clawhub install stellar-trails --force || { echo "✗ Block A Step 4a-pre FAILED: clawhub install failed"; exit 1; }
  echo "✓ Block A Step 4a-pre: stellar-trails installed via clawhub"
fi
FILES_OK="yes"
for f in SKILL.md procedure/phases.md dev.sh index.html chibi.svg; do [ ! -f "$SKILL_DIR/$f" ] && echo "✗ Block A Step 4a WARNING: missing $f" && FILES_OK="no"; done
if [ "$FILES_OK" = "yes" ]; then echo "✓ Block A Step 4a: all skill files present"; else echo "✗ Block A Step 4a FAILED: files missing"; exit 1; fi
mkdir -p "$ZSCRIPTS"
[ -f "$SKILL_DIR/dev.sh" ] && cp -f "$SKILL_DIR/dev.sh" "$ZSCRIPTS/dev.sh" && chmod +x "$ZSCRIPTS/dev.sh"
[ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS/index.html"
[ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS/chibi.svg"
echo "✓ Block A Step 4b: .zscripts/ synced (dev.sh git-tracked since v9.11.9)"
# Bug 3+4 fix: kill bash SUPERVISOR via PID file, verify /proc/cmdline, also kill orphaned python3.
OLD_PID=$(cat "$ZSCRIPTS/st-devsh.pid" 2>/dev/null)
if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
  OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
  if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
    kill "$OLD_PID"; sleep 1; echo "✓ Block A Step 4c: old dev.sh supervisor (PID $OLD_PID) killed"
    LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$LISTENER_PID" ]; then
      kill "$LISTENER_PID" 2>/dev/null || true; sleep 1
      if ss -tlnp 2>/dev/null | grep -q ':3000 '; then kill -9 "$LISTENER_PID" 2>/dev/null || true; sleep 1; fi
      echo "  Bug 4 fix: killed orphaned python3 listener (PID $LISTENER_PID)"
    fi
  else
    echo "⚠️ Block A Step 4c: PID $OLD_PID in pidfile is not dev.sh — skipping kill"
    LISTENER_PID=$(ss -tlnp | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    [ -n "$LISTENER_PID" ] && kill "$LISTENER_PID" && sleep 1 && echo "  fallback: killed python3 listener (PID $LISTENER_PID)"
  fi
else
  echo "✓ Block A Step 4c: no stale dev.sh PID file found — fresh start"
fi
DEV_SH="$ZSCRIPTS/dev.sh"
if [ -f "$DEV_SH" ]; then ( setsid bash "$DEV_SH" </dev/null >/dev/null 2>&1 & ) & sleep 1
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
  if [ "$HTTP" = "200" ]; then echo "✓ Block A Step 4d: dev.sh restarted on :3000 (HTTP $HTTP)"; else echo "✗ Block A Step 4d FAILED: dev.sh restart failed (HTTP $HTTP)"; exit 1; fi
else echo "✗ Block A Step 4d FAILED: dev.sh not found at $DEV_SH"; exit 1; fi
USER_SKILLS_DIR="/home/user_skills"
if [ -d "$SKILL_DIR" ] && [ -d "$USER_SKILLS_DIR" ]; then cd "$(dirname "$SKILL_DIR")" && zip -qr "$USER_SKILLS_DIR/stellar-trails.zip" "$(basename "$SKILL_DIR")/" && echo "✓ Block A Step 4e: persistent zip synced" || { echo "✗ Block A Step 4e FAILED: zip sync error"; exit 1; }; else echo "✗ Block A Step 4e FAILED: directory not found"; exit 1; fi
# === Proposal 7 (v9.15.2): E8 todolist proxy file — CODE-ENFORCED audit trail ===
# Bash cannot call TodoWrite platform tool, but bash CAN write a proxy file that serves
# as audit trail + gate. This file is written ONLY at end of Block A (after all steps pass).
# If Block A exits early (any step fails → exit 1), this line never executes → proxy missing.
# Block B verifies proxy exists before running — catches partial Block A execution.
# Note: This does NOT replace TodoWrite platform tool (live UI visibility still TEXT-ENFORCED).
# It adds a CODE-ENFORCED audit layer that LLM cannot skip.
echo "block-a:completed:$(date -u '+%Y-%m-%dT%H:%M:%SZ'):pid=$$:token=$(cat /tmp/st-active)" >> /tmp/st-todolist
echo "  E8 proxy: /tmp/st-todolist updated (block-a:completed)"
# === Proposal 8+9 (v9.15.3): Read mid-task snapshot + compact summary if exists ===
# After truncation, these files preserve task state for resume.
# If present, LLM should read them to recover context without re-reading full worklog.
if [ -f /tmp/st-session-snapshot ]; then
  echo "  📋 Session snapshot found (mid-task state preserved):"
  tail -3 /tmp/st-session-snapshot | sed 's/^/    /'
fi
if [ -f /tmp/st-context-summary ]; then
  echo "  📋 Context summary (≤200 chars, inject into context):"
  cat /tmp/st-context-summary | sed 's/^/    /'
fi
echo "✓ Block A COMPLETE — proceeding to Block B"
```

If clawhub updated the skill in Block A: re-read SKILL.md from disk now. Cached context is stale.

### Block B — Verify + Log + GREEN Gate (Step 5)

**What this block does**: Verify Block A ran (E7 gate with freshness check, Proposal 2), re-run clawhub and cross-check oracle (Proposal 4), write E9 log, rotate worklog, load knowledge, print conditional 5/5 GREEN (Proposal 1), compute mechanical compliance score.

```bash
# v9.15.0 Block B: Verify + Log + GREEN Gate — combines Step 5 of legacy protocol
# with strengthened E7 gate (Proposal 2: freshness check) and E11 re-verification
# (Proposal 4: re-run clawhub and compare to cached oracle).
_SKILL_MD="/home/z/my-project/skills/stellar-trails/SKILL.md"
# === Proposal 2: E7 gate with session-freshness check ===
# Verifies token exists AND was modified within last 120s (proves Block A ran THIS session).
# 120s window: Block A → Block B should take <30s; 120s allows for clawhub update delays.
if [ ! -f /tmp/st-active ] || [ ! -f /tmp/st-session-meta ]; then
  echo "✗ Block B GATE FAILED: /tmp/st-active or /tmp/st-session-meta missing — Block A must run first"
  exit 1
fi
TOKEN_AGE=$(( $(date +%s) - $(stat -c %Y /tmp/st-active) ))
if [ "$TOKEN_AGE" -gt 120 ]; then
  echo "✗ Block B GATE FAILED: token is ${TOKEN_AGE}s old (max 120s) — Block A must re-run to refresh token"
  exit 1
fi
# Verify token matches recomputation from session_meta (proves token wasn't fabricated)
ST_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' "$_SKILL_MD" | head -1)
SESSION_META=$(cat /tmp/st-session-meta)
EXPECTED_TOKEN=$(printf '%s' "${ST_VERSION}:${SESSION_META}" | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Block B GATE FAILED: token mismatch — token does not match session_meta"
  echo "  Expected: $EXPECTED_TOKEN (recomputed from version + session_meta)"
  echo "  Actual:   $ACTUAL_TOKEN (stored in /tmp/st-active)"
  exit 1
fi
echo "  E7 gate: PASS (token valid, age ${TOKEN_AGE}s, session_meta verified)"
# === Proposal 7 (v9.15.2): E8 todolist proxy verification ===
# Verifies Block A completed fully (not just started). Catches partial execution where
# Block A exits mid-way after writing token but before completing all steps.
# /tmp/st-todolist is written ONLY at end of Block A — if missing, Block A was skipped or incomplete.
if [ ! -f /tmp/st-todolist ]; then
  echo "✗ Block B E8 GATE FAILED: /tmp/st-todolist missing — Block A did not complete (skipped or partial)"
  exit 1
fi
if ! grep -q "^block-a:completed:" /tmp/st-todolist 2>/dev/null; then
  echo "✗ Block B E8 GATE FAILED: /tmp/st-todolist has no block-a:completed marker — Block A did not finish"
  exit 1
fi
# Extract block-a completion timestamp for freshness check
BLOCK_A_TS=$(grep "^block-a:completed:" /tmp/st-todolist | tail -1 | grep -oP 'completed:\K[0-9T:-]+' | head -1)
echo "  E8 proxy: PASS (block-a:completed at $BLOCK_A_TS, audit trail: $(wc -l < /tmp/st-todolist) lines)"
# === Proposal 4: E11 re-verification — re-run clawhub and compare to cached oracle ===
# This catches fabricated /tmp/st-clawhub-oracle.json. If LLM wrote fake JSON without
# running clawhub, this fresh clawhub inspect will return different content (or fail).
if [ ! -f /tmp/st-clawhub-oracle.json ]; then
  echo "✗ Block B E11 FAILED: clawhub oracle file missing — Block A Step 3 must run first"
  exit 1
fi
clawhub inspect stellar-trails --json > /tmp/st-clawhub-oracle-verify.json 2>/dev/null
FRESH_VERSION=$(python3 -c "import json; d=json.load(open('/tmp/st-clawhub-oracle-verify.json')); print((d.get('latestVersion') or {}).get('version') or '')" 2>/dev/null || echo "")
CACHED_VERSION=$(python3 -c "import json; d=json.load(open('/tmp/st-clawhub-oracle.json')); print((d.get('latestVersion') or {}).get('version') or '')" 2>/dev/null || echo "")
if [ -z "$FRESH_VERSION" ]; then
  echo "⚠️ Block B E11 WARNING: fresh clawhub inspect failed (network?) — using cached oracle"
elif [ "$FRESH_VERSION" != "$CACHED_VERSION" ]; then
  echo "✗ Block B E11 FAILED: oracle mismatch — cached=$CACHED_VERSION, fresh=$FRESH_VERSION"
  echo "  This indicates /tmp/st-clawhub-oracle.json was fabricated or stale."
  rm -f /tmp/st-clawhub-oracle-verify.json
  exit 1
fi
rm -f /tmp/st-clawhub-oracle-verify.json
echo "  E11 oracle: PASS (cached v$CACHED_VERSION = fresh v$FRESH_VERSION)"
# === E9: Persistent activation log ===
ST_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ST_TOKEN=$(cat /tmp/st-active)
echo "${ST_TIMESTAMP} v${ST_VERSION} token=${ST_TOKEN} block=A+B banner=YES protocol=2-block" >> /home/user_skills/.st-activation-log
echo "✓ Block B Step 5a: E9 log entry written (2-block protocol)"
# === Worklog rotation (P2) ===
WORKLOG="/home/z/my-project/worklog.md"
if [ -f "$WORKLOG" ]; then
  WENTRY_COUNT=$(grep -c '^---$' "$WORKLOG" 2>/dev/null || echo 0)
  if [ "$WENTRY_COUNT" -gt 50 ]; then
    ARCHIVE="${WORKLOG%.md}-archive-$(date -u '+%Y-%m-%d').md"
    mv "$WORKLOG" "$ARCHIVE"
    awk 'BEGIN{RS="^---$"} {entries[NR]=$0} END{print "---"; for(i=NR-4;i<=NR;i++) if(entries[i]) print entries[i]}' "$ARCHIVE" > "$WORKLOG"
    echo "  P2: worklog rotated ($WENTRY_COUNT → 5 entries, archive: $ARCHIVE)"
  fi
fi
# === Knowledge on-demand loading (P3) ===
ST_TASK_TYPE="${ST_TASK_TYPE:-coding}"
KBASE="/home/z/my-project/skills/stellar-trails/knowledge"
case "$ST_TASK_TYPE" in
  coding|Coding)    head -30 "$KBASE/error-patterns.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
  audit|Audit)      head -30 "$KBASE/patterns.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
  document|Document) head -30 "$KBASE/conventions.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
  *)               head -30 "$KBASE/user-profile.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
esac
echo "  P3: knowledge preview loaded for task_type=$ST_TASK_TYPE"
# === Proposal 1: Conditional 5/5 GREEN (was unconditional echo in v9.14.2) ===
# GREEN is now printed ONLY if all 5 critical artifacts exist AND are fresh.
# This eliminates the cosmetic GREEN claim that misled users in v9.14.2.
REAL_SCORE=0; REAL_SKIPPED=""
# Check 1: E7 token exists and is fresh (already verified above, but count it)
[ -f /tmp/st-active ] && [ "$TOKEN_AGE" -le 120 ] && REAL_SCORE=$((REAL_SCORE+1)) || REAL_SKIPPED="${REAL_SKIPPED}E7-token,"
# Check 2: E11 oracle exists and matches fresh clawhub (already verified above)
[ -f /tmp/st-clawhub-oracle.json ] && [ -n "$FRESH_VERSION" ] && [ "$FRESH_VERSION" = "$CACHED_VERSION" ] && REAL_SCORE=$((REAL_SCORE+1)) || REAL_SKIPPED="${REAL_SKIPPED}E11-oracle,"
# Check 3: dev.sh :3000 listening
curl -s -o /dev/null -m 2 http://localhost:3000/ 2>/dev/null && REAL_SCORE=$((REAL_SCORE+1)) || REAL_SKIPPED="${REAL_SKIPPED}dev.sh,"
# Check 4: E9 log has fresh entry (tail -1 should be our entry from this session)
tail -1 /home/user_skills/.st-activation-log 2>/dev/null | grep -q "protocol=2-block" && REAL_SCORE=$((REAL_SCORE+1)) || REAL_SKIPPED="${REAL_SKIPPED}E9-log,"
# Check 5: worklog.md exists
[ -f "$WORKLOG" ] && REAL_SCORE=$((REAL_SCORE+1)) || REAL_SKIPPED="${REAL_SKIPPED}worklog,"
# Check 6 (v9.15.2 Proposal 7): E8 todolist proxy has block-a:completed marker
# This is CODE-ENFORCED — proves Block A finished fully, not just started
grep -q "^block-a:completed:" /tmp/st-todolist 2>/dev/null && REAL_SCORE=$((REAL_SCORE+1)) || REAL_SKIPPED="${REAL_SKIPPED}E8-todolist,"
# Print GREEN only if all 6 checks pass
if [ "$REAL_SCORE" -eq 6 ]; then
  echo "✓ 6/6 GREEN — activation complete (mechanically verified: score=6/6)"
else
  echo "✗ ${REAL_SCORE}/6 GREEN — activation INCOMPLETE (re-run failed steps)"
  echo "  Skipped: ${REAL_SKIPPED:-none}"
  echo "  Compliance log entry written for audit."
  # Write failure entry to log for audit visibility
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') COMPLIANCE-FAIL v${ST_VERSION} score=${REAL_SCORE}/6 skipped=${REAL_SKIPPED:-none}" >> /home/user_skills/.st-activation-log
  # Do NOT exit 1 here — let user see the score and decide. But do NOT print GREEN.
fi
# === Proposal 7 (v9.15.2): Write block-b:completed to todolist proxy ===
# This completes the audit trail — both blocks now have completion markers.
echo "block-b:completed:$(date -u '+%Y-%m-%dT%H:%M:%SZ'):pid=$$:score=${REAL_SCORE}/6" >> /tmp/st-todolist
# === Mechanical compliance score (always written to log) ===
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') COMPLIANCE v${ST_VERSION} score=${REAL_SCORE}/6 mechanical=bash skipped=${REAL_SKIPPED:-none} protocol=2-block" >> /home/user_skills/.st-activation-log
echo "  Compliance: ${REAL_SCORE}/6 mechanical (skipped: ${REAL_SKIPPED:-none})"
```

### E12 — Activation Retry Protocol (v9.12.0, updated v9.15.0 for 2-Block)

**Problem this solves**: Block bash blocks must `exit 1` on ANY failure, not just GATE failures. The LLM must detect non-zero exit code and retry the failed block (max 3 retries).

**Solution** (v9.15.0):
1. **Print stdout mandate**: Each Block's bash block stdout MUST be printed verbatim — no summarizing, suppressing, or paraphrasing.
2. **Exit code enforcement**: Each Block bash block must `exit 1` on ANY failure. Bash tool reports non-zero exit code → LLM detects failure → triggers retry.
3. **Retry-until-green**: If a Block fails (exit 1), the LLM MUST:
   - Print the error output (already captured by Bash tool)
   - Diagnose the cause (read the ✗ message, identify root cause)
   - Apply a fix (see Common failure fixes table below)
   - Re-run the failed Block
   - Repeat until ✓ (max 3 retries per block)
   - If still failing after 3 retries → use E6 Escape Hatch or ask user for guidance

**Retry decision tree** (2-Block variant):
```
Block A bash exits with code:
  0 (success)  → print ✓ Block A output → proceed to Block B
  1 (failure)  → print ✗ Block A output → diagnose → fix → re-run Block A
                   ↓
                   retry 1: re-run Block A
                     ├─ exit 0 → ✓ proceed to Block B
                     └─ exit 1 → retry 2: re-run Block A
                                    ├─ exit 0 → ✓ proceed
                                    └─ exit 1 → retry 3: re-run Block A
                                                   ├─ exit 0 → ✓ proceed
                                                   └─ exit 1 → ⚠️ MAX RETRIES EXCEEDED
                                                      → E6 Escape Hatch or ask user

Block B bash exits with code:
  0 (success)  → print ✓ Block B output → check 6/6 GREEN → proceed to SPECIFY
  1 (failure)  → print ✗ Block B output → diagnose → fix → re-run Block B
                   (same retry tree as Block A)
```

**Common failure fixes** (apply before retry):
| Block | Failure | Fix |
|------|---------|-----|
| A | SKILL.md not found | `clawhub --no-input update stellar-trails --force` to restore |
| A | HTTP != 200 (popup not responding) | Kill stale dev.sh: `kill $(cat /home/z/my-project/.zscripts/st-devsh.pid)` + re-run Block A |
| A | clawhub unreachable (network) | Retry Block A after 5s — network may be transient |
| A | clawhub update failed (moderation) | Check `clawhub inspect stellar-trails --json` moderation state → if hidden, ask user |
| A | dev.sh restart failed (port in use) | Kill orphaned listener: `ss -tlnp \| grep ':3000' \| grep -oP 'pid=\K[0-9]+' \| xargs kill -9` + re-run Block A |
| A | zip sync failed (directory missing) | `mkdir -p /home/user_skills` + re-run Block A |
| B | E7 GATE FAILED (token missing) | Re-run Block A to re-write token + session_meta |
| B | E7 GATE FAILED (token stale >120s) | Re-run Block A to refresh token |
| B | E7 GATE FAILED (token mismatch) | Token doesn't match session_meta — re-run Block A |
| B | E11 FAILED (oracle mismatch) | Cached oracle was fabricated or stale — re-run Block A (which writes fresh oracle) |
| B | 6/6 GREEN not reached (score <6) | Read the `skipped=` field, fix missing artifact, re-run Block B |

**Anti-patterns (FORBIDDEN)**:
- ❌ "Block A failed but I'll proceed to Block B" — NO. Retry Block A until ✓ before proceeding.
- ❌ "I'll summarize the output instead of printing verbatim" — NO. Print the raw stdout.
- ❌ "After 3 retries I'll just skip to SPECIFY" — NO. Use E6 Escape Hatch to make the skip visible, or ask the user.
- ❌ "6/6 GREEN wasn't printed but I'll proceed anyway" — NO. If GREEN is not printed, score <6. Fix the missing artifact.

### 6/6 GREEN GATE (v9.12.0, conditional v9.15.0, 6-check v9.15.2)

After Block B completes, the bash block AUTOMATICALLY prints one of:

```
✓ 6/6 GREEN — activation complete (mechanically verified: score=6/6)
```
...or, if any artifact is missing/stale:
```
✗ N/6 GREEN — activation INCOMPLETE (re-run failed steps)
  Skipped: <list>
```

**Rule** (v9.15.2): The GREEN echo is now CONDITIONAL — it is only printed if `REAL_SCORE=6`. The score is computed mechanically from 6 artifacts:
1. E7 token exists and age ≤ 120s
2. E11 oracle exists and matches fresh clawhub inspect
3. dev.sh :3000 listening (curl returns 200)
4. E9 log has fresh entry with `protocol=2-block`
5. worklog.md exists
6. E8 todolist proxy has `block-a:completed` marker (v9.15.2 Proposal 7)

**This eliminates the cosmetic GREEN claim** that misled users in v9.14.2 (where GREEN was printed unconditionally). Now, if any artifact is missing or stale, the user sees `✗ N/6 GREEN` instead of `✓ 6/6 GREEN`.

**Self-check before proceeding to SPECIFY**:
- Did Block A print `✓ Block A COMPLETE`? → If NO, retry Block A
- Did Block B print `✓ 6/6 GREEN` (not `✗ N/6`)? → If NO, retry Block B

Only when both answers are YES, proceed to SPECIFY (or IMPLEMENT if continuation detected).

**FULL MODE ALWAYS (v9.13.4)**: Stellar Trails runs in Full Mode permanently — all 12 enforcement vectors, all 14 Pre-Push checks, all 6 phases, all templates, all the time. There is no "context pressure adaptive mode" — the skill always applies the complete protocol regardless of session length or context budget. If context is genuinely exhausted (≥90%), use E6 Escape Hatch for that specific emergency, then resume Full Mode on the next invoke.

### Compliance Score Tracking (NEW v9.13.0)

**Problem**: E9 logs activation events but not compliance scores. There's no feedback loop to detect patterns like "last 10 activations: 8/10 followed all steps, 2/10 skipped E3."

**Solution**: At DELIVER phase, the LLM self-assesses compliance and appends a score to the E9 log:

```bash
# v9.13.0: Compliance score appended to activation log at DELIVER
# Format: COMPLIANCE v<VERSION> score=N/12 vectors_skipped=E1,E3
# The LLM evaluates which of the 12 vectors it actually followed during this task
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') COMPLIANCE v${ST_VERSION} score=[N]/12 skipped=[list] mode=[full|standard|minimal]" >> /home/user_skills/.st-activation-log
```

**Scoring**: bash computes mechanical score from artifacts (E7 token, E11 oracle, dev.sh HTTP, E9 log, worklog). LLM cannot inflate.

### FORBIDDEN Rationalizations (E5 — v9.3.0)

All 8 are correctness bugs. If you think any, STOP and run activation NOW.
1. ❌ "Continuation task" → WRONG. Activation is required every invoke.
2. ❌ "Simple/trivial task" → WRONG. Minimal tier still needs banner + 5 steps.
3. ❌ "Session is long, save tokens" → WRONG. Activation = 0.25% of context.
4. ❌ "Already printed banner" → WRONG. Print every invoke after truncation.
5. ❌ "User didn't complain" → WRONG. Silence ≠ approval.
6. ❌ "Label Minimal tier and skip" → WRONG. All tiers must activate.
7. ❌ "Pattern drift — skipped before" → WRONG. Past bugs ≠ precedent.
8. ❌ "Print report without activation" → WRONG. Silent skip = WORST option.

### If You Must Skip Activation — Escape Hatch (E6 — v9.3.0)

Print: `⚠️ ACTIVATION SKIPPED — operating without banner` + reason + acknowledge correctness bug. Emergencies only (≥90% context). Do NOT silently skip.

---

## Enforcement Vectors Overview (v9.15.0)

**Legacy Text** (E1-E3, v9.0.0): Phase markers, mandatory prints, AskUserQuestion gate. Text-only, backstopped by E7-E12.
**Pre-Tool Gate** (E4-E6, v9.3.0): Hard gate, anti-rationalization, escape hatch.
**Sandbox-Native** (E7-E11, v9.4.0, strengthened v9.15.0): Hash token (now session-specific), TodoWrite, persistent log, line proof, clawhub oracle (now re-verified fresh).
**Exit Code** (E12, v9.12.0): Exit code enforcement + retry-until-green + 6/6 GREEN GATE (now conditional, 6-check v9.15.2).

All 12 vectors retained. v9.15.0 raises CODE enforcement from ~26% to ~58% via:
- Proposal 1: 5/5 GREEN conditional (was cosmetic)
- Proposal 2: Session-freshness check (token age ≤ 120s)
- Proposal 4: E11 re-run clawhub (was file-existence-only)
- Proposal 6: E7 token with session_meta (was version-derived)
- Proposal 7 (v9.15.2): E8 todolist proxy file (CODE-ENFORCED audit trail for Block A completion)
- Proposal 8+9+10 (v9.15.3): Mid-task session resilience (snapshot + summary + checkpoint) — improves truncation recovery ~50%

v9.15.2 raises CODE enforcement from ~58% to ~63% via:
- Proposal 7: E8 todolist proxy file `/tmp/st-todolist` (CODE-ENFORCED audit trail for Block A completion)

Remaining TEXT-ENFORCED (cannot be code-enforced in z.ai sandbox): E4 Pre-Tool Gate, E5 Rationalizations, E8 TodoWrite live UI (platform tool — bash proxy covers audit only), Phase Pause Gate, AskUserQuestion Gate. These cap maximum achievable compliance at ~80%.


## Legacy Text Enforcement (E1-E3, v9.0.0 — retained, backstopped by E7-E12)

**E1 Phase Machine**: Every task passes through all 6 phases. Print `☄️ ENTER/EXIT <PHASE>` markers. Missing = compliance bug.

**E2 Mandatory Prints**: Banner (FIRST), COMMIT block (end of PLAN), REPORT block (LAST). Pre-DELIVER bash verifies artifacts exist. Self-audit: did I print banner first? did I read SKILL.md? did I verify popup? did I check ClawHub?

**E3 Preferences Dialog**: AskUserQuestion BEFORE content for Document/Visualization tasks. Print `✓ Preferences dialog check: <INVOKED|SKIPPED: reason>`. Skip: user says skip / all 3 explicit / trivial / coding / continuation. Not provisioned to subagents.

---

## Workflow Phases

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
```

Phase definitions, entry/exit criteria, and gate rules live in `procedure/phases.md` — read it during Step 5 of Activation.

---

## Session Continuity

**Rule**: Before entering any phase, check if the user's message is a continuation of previous work. Read the immediately preceding assistant message — if the user's reply references, approves, corrects, or follows up on that output, it is a continuation. After context truncation, read `worklog.md` — the last entry contains the exact task state snapshot needed to resume.

| Signal | Type | Action |
|--------|------|--------|
| User references previous output ("apply all 10", "fix point 3", "proceed") | Continuation | Skip SPECIFY+PLAN → IMPLEMENT |
| User approves a proposal/plan ("yes", "go ahead", "do it") | Continuation | Skip SPECIFY+PLAN → IMPLEMENT |
| User asks a follow-up question ("what about X?") | Continuation | Skip SPECIFY → answer in current phase context |
| User provides new requirements mid-task | New task | Restart from SPECIFY with updated requirements |
| User invokes Skill() with new instructions | New task | Full workflow from IDLE |
| Context compression boundary with ongoing task | Continuation | Read `worklog.md` last entry, resume from recorded phase |

Regenerating proposals the user already approved is a correctness bug, not a style preference.

### Worklog Continuity Protocol

Every DELIVER phase appends a Snapshot to `worklog.md`. This is the primary continuity mechanism — not conversation history, not memory files.

On DELIVER (always, all tiers), append to `/home/z/my-project/worklog.md`:

```
---
last_phase: DELIVER
task: <one-line description>
complexity: <tier>
task_type: <type>
files_modified: <list or "none">
phase_trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
next_step: <what user should do next, or "IDLE - awaiting input">
```

On context truncation (IDLE): read the last `---` block from `worklog.md`. If the task description matches the current request, resume from the recorded phase.

### Worklog Rotation Policy (NEW in v9.11.4)

**Problem**: `worklog.md` grows unbounded — at ~1KB per DELIVER snapshot, 1000 tasks would produce ~1MB file. Loading 1MB into context for "read last entry" wastes tokens.

**Policy**: When `worklog.md` exceeds 100 entries (≈100KB), rotate:
1. Rename current `worklog.md` → `worklog-archive-YYYY-MM-DD.md` (date-stamped)
2. Create new `worklog.md` with the last 5 entries copied from the archived file (preserves continuity for next session)
3. Archive files accumulate in `/home/z/my-project/` — user can delete old archives anytime

**Rotation bash (run at DELIVER phase, after snapshot append)**:
```bash
WORKLOG="/home/z/my-project/worklog.md"
ENTRY_COUNT=$(grep -c '^---$' "$WORKLOG" 2>/dev/null || echo 0)
if [ "$ENTRY_COUNT" -gt 100 ]; then
  ARCHIVE="${WORKLOG%.md}-archive-$(date -u '+%Y-%m-%d').md"
  mv "$WORKLOG" "$ARCHIVE"
  # Preserve last 5 entries for continuity
  awk 'BEGIN{RS="^---$"} {entries[NR]=$0} END{print "---"; for(i=NR-4;i<=NR;i++) if(entries[i]) print entries[i]}' "$ARCHIVE" > "$WORKLOG"
  echo "✓ Worklog rotated: $ARCHIVE ($(grep -c '^---$' "$ARCHIVE") entries archived), $WORKLOG reset to last 5 entries"
fi
```

**Knowledge on-demand loading**: At Step 5 activation, only read the **last 3 entries** of `worklog.md` (not the whole file) — sufficient for continuity check without loading stale history.

### Mid-Task Session Resilience (NEW v9.15.3 — Proposals 8+9+10)

**Problem this solves**: Session truncation/compression mid-task (before DELIVER) loses all progress. LLM must re-do SPECIFY+PLAN from scratch. 3 proposals add mid-task state preservation:

#### Proposal 8 — Mid-Task Session Snapshot (`/tmp/st-session-snapshot`)

**When to write**: At each phase transition (SPECIFY→PLAN, PLAN→IMPLEMENT, IMPLEMENT→VERIFY). Volatile — survives truncation, not reboot.

```bash
# v9.15.3 Proposal 8: Write phase-transition snapshot (run at each phase entry)
# Format: timestamp:phase:task_one_line:files_modified:next_step
# LLM fills in [brackets] before running
_PHASE="SPECIFY"  # or PLAN, IMPLEMENT, VERIFY — set per phase
_TASK="[one-line task summary]"
_FILES="[files modified so far, or 'none']"
_NEXT="[next step in this phase]"
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'):phase=${_PHASE}:task=${_TASK}:files=${_FILES}:next=${_NEXT}" >> /tmp/st-session-snapshot
# Rotate: keep last 10 entries (avoid unbounded growth)
tail -10 /tmp/st-session-snapshot > /tmp/st-session-snapshot.tmp && mv /tmp/st-session-snapshot.tmp /tmp/st-session-snapshot
echo "✓ Snapshot written: phase=${_PHASE}"
```

**Block A reads this** (already added above): if `/tmp/st-session-snapshot` exists, prints last 3 entries for LLM to resume.

#### Proposal 9 — Compact Context Summary (`/tmp/st-context-summary`)

**When to write**: At each phase EXIT. Single-line ≤200 chars. Overwrites previous (always latest).

```bash
# v9.15.3 Proposal 9: Write compact context summary (run at each phase exit)
# Single line, ≤200 chars, overwrites previous — always latest state.
# LLM fills in [brackets] before running
_SUMMARY="task=[one-line] | phase_done=[SPECIFY|PLAN|IMPLEMENT|VERIFY] | decision=[key decision] | next=[next step]"
echo "$_SUMMARY" > /tmp/st-context-summary
echo "✓ Context summary written (≤200 chars)"
```

**Block A reads this** (already added above): if exists, prints for immediate LLM context injection — answers "what was I doing?" without reading full worklog.

#### Proposal 10 — Worklog Mid-Task Checkpoint

**When to write**: At IMPLEMENT entry for Standard/Complex tasks. Persistent (survives reboot). Distinguished from DELIVER snapshot with `checkpoint=YES`.

```bash
# v9.15.3 Proposal 10: Worklog mid-task checkpoint (run at IMPLEMENT entry, Standard/Complex only)
# Persistent — survives container reboot (unlike /tmp snapshots).
# Distinguish from DELIVER snapshot with checkpoint=YES field.
cat >> /home/z/my-project/worklog.md << ST_CHECKPOINT_EOF
---
last_phase: IMPLEMENT (checkpoint)
timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
version: v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
task: [LLM fills — one-line task summary]
checkpoint: YES
files_modified_so_far: [LLM fills — list or 'none']
impl_steps_done: [LLM fills — e.g. 'IMPL-001, IMPL-002']
next_step: [LLM fills — next IMPL step or 'VERIFY']
ST_CHECKPOINT_EOF
echo "✓ Worklog checkpoint written (IMPLEMENT entry, persistent)"
```

**Recovery after reboot**: Read `worklog.md` last entry. If `checkpoint: YES`, resume from IMPLEMENT phase (skip SPECIFY+PLAN). If `last_phase: DELIVER`, task was completed — start new task.

#### Recovery Script (ready now)

After truncation/reboot, run for full diagnosis:
```bash
bash /home/z/my-project/scripts/st-recover.sh
```
Checks: /tmp artifacts, skill files, version sync, dev.sh, worklog, snapshot, summary. Provides recovery recommendation.

---

## Task Type Awareness

| Task Type | SPECIFY | PLAN | IMPLEMENT | VERIFY |
|-----------|---------|------|------------|--------|
| **Coding** | Problem spec, edge cases, affected files | Code steps + Traceability IDs | Write code | Lint, type check, tests |
| **Document** | Content outline, target format, sections | Section plan + content depth targets | Generate document (via skill) | Format check, completeness |
| **Visualization** | Visual requirements, data sources, layout | Data mapping + chart type selection | Generate chart (via skill) | Visual accuracy, data integrity |
| **Data Processing** | Data spec, input/output schema, transforms | Transform pipeline + validation steps | Write script + execute | Output validation, edge cases |
| **Non-Coding** | Internal (identify question) | Internal (plan approach) | Answer / explain / recommend | Internal (self-check) |

No phases are skipped. Non-coding tasks use Minimal tier — SPECIFY, PLAN, VERIFY run internally. IMPLEMENT does the visible work. DELIVER outputs a compact report.

---

## Complexity Tiers

| Tier | Criteria | Report Format |
|------|----------|---------------|
| **Minimal** | Knowledge question, explanation, recommendation — no code/file output | `☄️ PASS \| Evidence: <one-line result>` |
| **Simple** | Single file, no schema change, no new dependencies | `☄️ REPORT [Simple]` (one-line) |
| **Standard** | Multiple files or a schema change | `☄️ REPORT [Standard]` (full block) + Scope at end of PLAN |
| **Complex** | Architectural changes, multi-service, high risk | `☄️ REPORT [Complex]` (full block + expanded evidence) + Scope |

Standard/Complex require Traceability IDs (IMPL-001, IMPL-002, ...). Simple/Minimal do not.

---

## Source Availability & Documentation Check (SADC)

Before planning any implementation, verify the approach is grounded in real sources — not assumptions.

| Complexity | SADC Requirement |
|-----------|-------------------|
| **Minimal** | Skip — knowledge questions don't need source research |
| **Simple** | Quick check — verify approach against at least one source |
| **Standard** | **Main agent inline research** — invoke `Skill(command="web-search")` then use Inline Content Retrieval (v9.5.0) BEFORE writing problem-spec. Print `📡 SADC: main agent researching inline` |
| **Complex** | Deep research by main agent — multiple sources, compare approaches, document tradeoffs |

**Main agent mandate (Standard/Complex)**: BEFORE writing the problem specification, the **main agent** (not a subagent) invokes `Skill(command="web-search")` to find existing solutions, then uses the **Inline Content Retrieval** protocol (see Inline Content Retrieval section, NEW in v9.5.0) to extract content from top 3-5 URLs → ≤500-word summary. **No external extraction skill dependency** — uses native curl + python3.

**Why main agent, not subagent**: The z.ai sandbox main agent has the SKILL.md pre-loaded into its context at session start; subagents do not (their context is the orchestrating main agent's task prompt). While subagents CAN invoke `Skill(command="stellar-trails")` after the fact (verified v9.11.4 — see Subagent Compliance Matrix below), doing so consumes ~95K tokens of the subagent's budget just to load the skill — wasteful for a single SADC lookup. The main agent already has SKILL.md in context, so it can perform SADC inline at near-zero marginal cost. Additionally, subagent prompts are compressed by the orchestrator, which may strip nuance needed for SADC source evaluation.

If no existing solution is found, state it explicitly — "searched npm/PyPI/docs, no existing package found" is a valid result. Building from scratch when a library exists is a spec-level defect.

**When subagents ARE appropriate**: Subagents may be used for non-skill tasks (e.g., "summarize these 5 URLs", "compare these 2 code samples"). The main agent fetches content via skills first, then delegates pure-text analysis to subagents. The rule: skills are invoked by the main agent; subagents operate on text the main agent has already retrieved.

---

## AskUserQuestion Gate (SPECIFY phase)

For deliverable-creation tasks (Document, Visualization, PPT, PDF, Excel, dashboard, poster, script, chart-as-deliverable), invoke `AskUserQuestion` BEFORE writing the problem specification.

**Mandate**: In SPECIFY phase, if task type is Document or Visualization AND the user's original request does NOT explicitly pin audience + style + length, invoke `AskUserQuestion` with 6–8 questions.

Print before any content-producing tool call: `✓ Preferences dialog check: <INVOKED | SKIPPED: <reason>>`

**Skip conditions**: user says skip / all 3 dimensions explicit / trivial edit / Coding/Non-Coding / continuation. AT MOST ONCE per run, before any content-producing tool. After answers return, proceed straight to PLAN (no loop-back).

**Skip conditions**: user says skip / all 3 dimensions explicit / trivial edit / Coding/Non-Coding / continuation. AT MOST ONCE per run.

---

## Pivot

On every error, classify it as **Bug** or **Wrong Approach** before attempting a fix. For denial-type errors (permission denied, EPERM, AccessDenied), perform **Denial Delta Analysis** — compare what was denied against what is configured. The difference IS the fix.

Wrong Approach signals (50%+ rewrite needed, same error after 2 attempts, missing library feature, data model change) trigger a pivot to the fallback approach defined in the Scope.

**Pivot flow**: Error detected → classify → if Wrong Approach: re-enter PLAN with fallback or new approach → present to user via AskUserQuestion (E3 enforcement) → re-implement → re-verify. Record in the Pivot field of the delivery report.

Full decision tree: read `procedure/error-resolution.md`.

---

## Recovery

1. **Stop** — do not continue past errors
2. **Classify** — code bug or approach failure? (see Pivot)
3. If code bug: document the error (use inline Incident Report template below), fix root cause, return to VERIFY
4. If approach failure: re-enter PLAN, evaluate alternatives (Scope fallback first), present pivot to user, re-implement
5. Ask the user before any action with side effects (git changes, file deletions, destructive operations)

Git rules (override defaults):
- `git fetch` and inspect before `git pull` — if remote diverged, stop and ask
- No `git rebase`, `git reset`, `git push --force`, or `git merge` without explicit user instruction
- If git is blocked by infrastructure, stop all git operations and inform the user

---

## Implementation Discovery Protocol (v9.2.0 — detail in `knowledge/implementation-discovery.md`)

If bug Y found while fixing bug X:
1. STOP. Document in worklog.
2. Same-Surface Test: same file + same root cause + same blast radius → FIX NOW. Different → DEFER.
3. Never silently fix or skip Y.

Worked example (v9.0.1→v9.0.2) in `knowledge/implementation-discovery.md`.

```
---
last_phase: DELIVER
task: <original task>
complexity: <tier>
task_type: <type>
files_modified: <list>
traceability: IMPL-001 to IMPL-XXX
discoveries:
  - bug: <Y one-line>
    found_while: <X one-line>
    surface: same|different
    action: fix-now|defer
    outcome: <fixed in this commit | deferred to next iteration>
pivot: NONE | YES (discovery-driven)
scope_drift: NONE | +Y (discovered while fixing X, same surface)
next_step: <what user should do next>
```

---

## Pre-Push Local Verification (NEW in v9.2.0, strengthened in v9.7.0)

**Problem this solves**: Pushing code changes to CI without local verification wastes a CI cycle (~1-2 minutes per run) and creates a "push → fail → read logs → push again" loop. This happened during this skill's development:

- v9.0.1 push → CI failed (python3 IndentationError) → read logs → v9.0.2 push → CI succeeded
- The IndentationError would have been caught by running the bash block locally before pushing.
- v9.6.0 push → CI succeeded BUT publish didn't register (moderation hide) → v9.6.1 re-publish
- v9.2.1 push → banner version hardcoded at v9.1.0 (not caught by bash -n)
- v9.1.0 push → SSV grep unescaped `**` (not caught by bash -n)

**Rule**: Before pushing any change that triggers CI, run ALL checks below. **All 9 checks must PASS before push.** If any FAIL, fix before pushing — do not push broken code.

### Verification checklist (9 checks, ALL must pass)

#### Check 1: bash -n syntax on all bash blocks
```bash
python3 << 'PYEOF'
import re, subprocess, tempfile, os
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
blocks = re.findall(r'\x60\x60\x60bash\n(.*?)\x60\x60\x60', content, re.DOTALL)
fail = 0
for i, block in enumerate(blocks, 1):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
        f.write(block); path = f.name
    r = subprocess.run(['bash', '-n', path], capture_output=True, text=True)
    os.unlink(path)
    if r.returncode != 0:
        print(f"✗ Block {i} FAIL: {r.stderr.strip()[:120]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 1: bash -n — {len(blocks)-fail}/{len(blocks)} blocks pass")
PYEOF
```

#### Check 2: python3 -c blocks execute with mock inputs (NEW v9.7.0)
```bash
# Extract and run every python3 -c block with 3 mock inputs: valid JSON, empty JSON, invalid text
python3 << 'PYEOF'
import re, subprocess
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
# Find all python3 -c "..." blocks
blocks = re.findall(r'python3 -c ("[^"]+"|\'[^\']+\')', content)
fail = 0
for i, block in enumerate(blocks, 1):
    cmd = f'echo "{{}}" | python3 -c {block}'
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    if r.returncode != 0:
        print(f"✗ python3 -c block {i} FAIL on empty JSON: {r.stderr.strip()[:80]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 2: python3 -c mock execution — {len(blocks)-fail}/{len(blocks)} blocks pass")
PYEOF
```

#### Check 3: grep patterns return expected values (NEW v9.7.0)
```bash
# Every grep -oP pattern in SKILL.md must return non-empty on the actual file
python3 << 'PYEOF'
import re, subprocess
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
patterns = re.findall(r"grep -oP '([^']+)'", content)
fail = 0
for i, pat in enumerate(patterns, 1):
    # Skip patterns that are meant to match process output, not file content
    if 'pid=' in pat or ':3000' in pat or 'HTTP' in pat:
        continue
    r = subprocess.run(['grep', '-oP', pat, 'skill/stellar-trails/SKILL.md'],
                       capture_output=True, text=True, timeout=5)
    if not r.stdout.strip():
        print(f"✗ grep pattern {i} returns empty: {pat[:60]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 3: grep patterns — {len(patterns)-fail}/{len(patterns)} return non-empty")
PYEOF
```

#### Check 4: Banner version is dynamic, not hardcoded (NEW v9.7.0)
```bash
# Banner must use <VERSION> placeholder, NOT hardcoded v9.x.y
HARDCODED=$(grep -c '☄️ STELLAR TRAILS · v[0-9]' skill/stellar-trails/SKILL.md)
PLACEHOLDER=$(grep -c '☄️ STELLAR TRAILS · v<VERSION>' skill/stellar-trails/SKILL.md)
if [ "$HARDCODED" -gt 0 ] && [ "$PLACEHOLDER" -eq 0 ]; then
  echo "✗ Check 4 FAIL: banner has hardcoded version ($HARDCODED occurrences), no <VERSION> placeholder"
else
  echo "✓ Check 4: banner uses <VERSION> placeholder ($PLACEHOLDER refs), no hardcoded version"
fi
```

#### Check 5: Metadata version matches git tag about to be pushed (NEW v9.7.0)
```bash
NEW_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' skill/stellar-trails/SKILL.md | head -1)
TAG="v$NEW_VERSION"
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "✗ Check 5 FAIL: tag $TAG already exists"
else
  echo "✓ Check 5: tag $TAG does not exist yet (safe to push)"
fi
```

#### Check 6: ClawHub registry state — skill not hidden by moderation (NEW v9.7.0)
```bash
# Before push, verify skill is visible on registry (not moderation-hidden)
# This catches the v9.6.0 bug where publish exit 0 but version didn't register
REGISTRY_STATE=$(clawhub inspect stellar-trails --json)
if [ -z "$REGISTRY_STATE" ]; then
  echo "✗ Check 6 FAIL: cannot reach clawhub registry — push may publish to hidden skill"
else
  MOD_STATE=$(echo "$REGISTRY_STATE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('moderation',{}).get('state','unknown'))" || echo "unknown")
  if [ "$MOD_STATE" = "hidden" ] || [ "$MOD_STATE" = "deleted" ]; then
    echo "✗ Check 6 FAIL: skill is $MOD_STATE by moderation — publish will not register"
    echo "  Contact clawhub moderator before pushing"
  else
    echo "✓ Check 6: skill visible on registry (moderation: $MOD_STATE)"
  fi
fi
```

#### Check 7: YAML structure valid (if workflow files changed)
```bash
if git diff --cached --name-only HEAD | grep -q '\.github/workflows/'; then
  python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && \
    echo "✓ Check 7: workflow YAML valid" || echo "✗ Check 7 FAIL: workflow YAML invalid"
else
  echo "✓ Check 7: no workflow files changed (skip)"
fi
```

#### Check 8: Markdown fence count is even (no orphan code blocks)
```bash
_F=$(printf '\x60\x60\x60')
FENCES=$(grep -c "$_F" skill/stellar-trails/SKILL.md)
if [ $((FENCES % 2)) -eq 0 ]; then
  echo "✓ Check 8: markdown fences even ($FENCES)"
else
  echo "✗ Check 8 FAIL: markdown fences odd ($FENCES) — orphan code block"
fi
```

#### Check 9: Post-push plan — registry poll will be done (NEW v9.7.0)
```bash
# Acknowledge that push is not complete until registry confirms the version
echo "✓ Check 9: post-push plan acknowledged"
echo "  After CI succeeds, MUST poll clawhub inspect until latestVersion = $NEW_VERSION"
echo "  If registry doesn't update within 60s of CI success, fetch CI logs + diagnose"
echo "  (This catches the v9.6.0 bug: publish exit 0 but version not registered)"
```

#### Check 10: index.html version matches SKILL.md (NEW v9.10.1)
```bash
SKILL_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' skill/stellar-trails/SKILL.md | head -1)
INDEX_VERSION=$(grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' skill/stellar-trails/index.html | head -1)
if [ "$SKILL_VERSION" != "$INDEX_VERSION" ]; then
  echo "✗ Check 10 FAIL: SKILL.md v$SKILL_VERSION vs index.html v$INDEX_VERSION — version drift"
else
  echo "✓ Check 10: index.html version matches SKILL.md (v$SKILL_VERSION)"
fi
```

#### Check 11: No duplicate knowledge files (NEW v9.11.4)
```bash
# Catches byte-identical duplicate files in knowledge/ subdirs (leftover from path-mismatch fixes)
DUPES=$(find skill/stellar-trails/knowledge/ -type f -name "*.md" -exec md5sum {} \; | sort | uniq -d -w 32 | wc -l)
if [ "$DUPES" -gt 0 ]; then
  echo "✗ Check 11 FAIL: $DUPES duplicate knowledge file(s) detected:"
  find skill/stellar-trails/knowledge/ -type f -name "*.md" -exec md5sum {} \; | sort | uniq -d -w 32
  echo "  Remove duplicates — only top-level knowledge/*.md should exist (no platform/ or universal/ subdirs)"
else
  echo "✓ Check 11: no duplicate knowledge files"
fi
```

#### Check 12: phases.md ↔ SKILL.md SADC drift (NEW v9.11.4)
```bash
# Catches drift between phases.md SADC step and SKILL.md SADC section
# Both must agree: main agent inline, NO subagent dispatch, NO crawl4ai/web-reader invocations
# Note: matches positive invocations only (Skill(command="...") or "dispatched"), not negations like "No crawl4ai"
PHASES_SUBAGENT=$(grep -cE 'Skill\(command="(crawl4ai|web-reader)"\)|subagent dispatched|Task\(subagent_type' skill/stellar-trails/procedure/phases.md)
PHASES_SUBAGENT=${PHASES_SUBAGENT:-0}
PHASES_CRAWL=0  # accounted for in PHASES_SUBAGENT above via Skill(command="...")
if [ "$PHASES_SUBAGENT" -gt 0 ]; then
  echo "✗ Check 12 FAIL: phases.md still references removed SADC patterns (count: $PHASES_SUBAGENT)"
  echo "  SKILL.md removed subagent SADC in v9.1.0 and crawl4ai in v9.5.0 — phases.md must match"
  grep -nE 'Skill\(command="(crawl4ai|web-reader)"\)|subagent dispatched|Task\(subagent_type' skill/stellar-trails/procedure/phases.md
else
  echo "✓ Check 12: phases.md SADC step aligned with SKILL.md (no subagent dispatch, no crawl4ai/web-reader invocations)"
fi
```

#### Check 13: Path integrity — all referenced files exist (NEW v9.11.5)
```bash
# Catches broken file references left behind when files/dirs are moved or deleted.
# Verifies every (references|procedure|knowledge|constraints)/path/to/file.md mentioned
# in any skill file actually exists on disk. Would have caught the v9.11.4 regression
# where knowledge/universal/ and knowledge/platform/ subdirs were deleted but refs in
# constraints/code-standards.md, knowledge/error-patterns.md, procedure/error-resolution.md
# were not updated.
python3 << 'PYEOF'
import os, re, subprocess
SKILL_DIR = 'skill/stellar-trails'
# Collect all file-path references from all .md files in the skill
ref_pattern = re.compile(r'(?:references|procedure|knowledge|constraints)/[a-zA-Z0-9_/-]+\.md')
missing = []
files_scanned = 0
for root, dirs, files in os.walk(SKILL_DIR):
    for fname in files:
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(root, fname)
        files_scanned += 1
        with open(fpath) as f:
            content = f.read()
        for match in ref_pattern.finditer(content):
            ref = match.group(0)
            full = os.path.join(SKILL_DIR, ref)
            if not os.path.exists(full):
                # Allow references that are documentation of removal (e.g., "formerly in procedure/templates/")
                # — but only if the line contains "formerly" or "removed" or "REMOVED"
                line_start = content.rfind('\n', 0, match.start()) + 1
                line_end = content.find('\n', match.end())
                line = content[line_start:line_end if line_end > 0 else len(content)]
                if any(kw in line.lower() for kw in ['formerly', 'removed', 'deprecated', 'was dead code']):
                    continue
                missing.append(f"  {fpath}: {ref}")
if missing:
    print(f"✗ Check 13 FAIL: {len(missing)} broken file reference(s):")
    for m in missing:
        print(m)
else:
    print(f"✓ Check 13: all file references valid ({files_scanned} files scanned)")
PYEOF
```

#### Check 14: .zscripts/dev.sh git-tracked + hash matches skill copy (NEW v9.11.9)
```bash
# Verifies that .zscripts/dev.sh is git-tracked (not ignored by .gitignore)
# AND that its hash matches skill/stellar-trails/dev.sh (the zip source).
# Catches: .gitignore regression (re-ignoring .zscripts/), dev.sh drift between
# the tracked runtime copy and the zip source.
if git ls-files --error-unmatch .zscripts/dev.sh >/dev/null 2>&1; then
  SKILL_HASH=$(sha256sum skill/stellar-trails/dev.sh | cut -d' ' -f1)
  ZSCRIPTS_HASH=$(sha256sum .zscripts/dev.sh | cut -d' ' -f1)
  if [ "$SKILL_HASH" != "$ZSCRIPTS_HASH" ]; then
    echo "✗ Check 14 FAIL: .zscripts/dev.sh hash mismatch"
    echo "  skill/stellar-trails/dev.sh: $SKILL_HASH"
    echo "  .zscripts/dev.sh:            $ZSCRIPTS_HASH"
    echo "  Fix: cp -f skill/stellar-trails/dev.sh .zscripts/dev.sh"
  else
    echo "✓ Check 14: .zscripts/dev.sh tracked + hash matches skill copy ($ZSCRIPTS_HASH)"
  fi
else
  echo "✗ Check 14 FAIL: .zscripts/dev.sh is NOT git-tracked — check .gitignore exception"
  echo "  Expected pattern in .gitignore: .zscripts/* + !.zscripts/dev.sh"
  echo "  Or run: git add -f .zscripts/dev.sh"
fi
```

#### Worklog Snapshot + L1 Pattern Skeleton (bash-enforced v9.14.0)
```bash
# Bash guarantees worklog entry + L1 pattern skeleton at DELIVER
# LLM fills in [brackets] after bash creates skeleton
cat >> /home/z/my-project/worklog.md << ST_WL_EOF
---
last_phase: DELIVER
timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
version: v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
task: [LLM fills]
complexity: [LLM fills]
task_type: [LLM fills]
files_modified: [LLM fills]
phase_trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
ST_WL_EOF
echo "✓ Worklog skeleton appended (LLM: fill in [brackets] above)"
# L1 pattern skeleton (bash guarantees template structure)
echo "## [$(date -u '+%Y-%m-%d')] <domain>: <pattern-name>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Context**: <when applies>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Approach**: <what worked>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Gotcha**: <what to avoid>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Source**: <task>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "✓ L1 pattern skeleton appended (LLM: fill in <brackets>)"
```

### When to skip Pre-Push Local Verification

- Documentation-only changes (CHANGELOG.md, README.md) → skip checks 2-6, run 1+7+8
- Version bump commits (just `sed` + commit) → run checks 4+5+6+9
- Changes to files that have no executable code (pure markdown prose) → skip checks 2-3

**Never skip**: checks 1 (bash syntax), 8 (markdown fences), 9 (post-push plan)

### Cost-benefit

- **Cost**: 60-90 seconds of local testing (up from 30-60s in v9.2.0)
- **Benefit**: catches 5 bug classes that slipped through v9.2.0's 4 checks
- **Bug classes caught by v9.7.0 additions**:
  - python3 -c execution errors (would have caught v9.0.1 IndentationError)
  - grep pattern failures (would have caught v9.1.0 unescaped `**`)
  - banner version drift (would have caught v9.2.1 hardcoded v9.1.0)
  - tag collision (would have caught duplicate tag pushes)
  - moderation hide (would have caught v9.6.0 publish-not-registering)
  - post-push registry verification (would have caught v9.6.0 silent publish failure)

### Anti-patterns (FORBIDDEN)

- ❌ "bash -n passed, ship it" — bash -n is necessary but NOT sufficient. Run all 9 checks.
- ❌ "Skip check 6, registry was fine last time" — moderation state can change between pushes. Always check.
- ❌ "Skip check 9, CI will tell us" — CI success ≠ registry update. v9.6.0 proved this. Always poll registry post-push.
- ❌ "Check 2 takes too long" — 5 seconds per python3 -c block. Worth it to avoid CI cycle.

---

## Proximate Cause Triage (v9.5.0 — detail in `knowledge/proximate-cause.md`)

**Q1**: Is candidate within 1 hop of symptom? → YES = prefer
**Q2**: ≤2 assumptions to explain ALL symptoms? → YES = parsimonious
**Q3**: Would fixing resolve user's request? → YES = in scope

**Scope Gate**: in_scope → proceed | clarification_needed → ASK | out_of_scope → STOP

Worked example + Parsimony Audit template in `knowledge/proximate-cause.md`.

---

## Inline Content Retrieval (v9.5.0 — reference in `knowledge/inline-retrieval.md`)

Use curl + python3 stdlib for web content extraction. Protocol detail moved to `knowledge/inline-retrieval.md` in v9.14.0. Summary:
1. Fetch with curl (10s timeout, user-agent)
2. Extract text with python3 html.parser (skip script/style/nav)
3. Truncate to 500 words for SADC summary

---

## GitHub Operations Protocol (v9.6.0 — adapted from @steipete/github)

curl + PAT (gh CLI not available). Prerequisites: PAT at `/home/z/my-project/upload/PAT`. Never print PAT.

### Git Identity Setup (MANDATORY before git commit/push)
Fetch owner from GitHub API → override /start.sh Z User config → recreate ~/.git-credentials → export GIT_AUTHOR_*/GIT_COMMITTER_* env vars. Run every session (credentials wiped on reset).

### Key Operations (detail: use curl + python3 for jq-style filtering)
1. **List workflow runs**: `curl -H "Authorization: Bearer $TOKEN" "https://api.github.com/repos/$REPO/actions/runs?per_page=10" | python3 -c "..."`
2. **Fetch failed logs**: `curl -L -o /tmp/gh-logs.zip "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/logs"` then `unzip`
3. **PR checks**: GET `/repos/$REPO/commits/$SHA/check-runs`
4. **API queries**: curl + python3 (jq not installed)

**Risk**: Read=NO approval. Write/Modify/Delete=YES explicit. Never silent mutations.
**Anti-patterns**: ❌ print PAT ❌ fetch all runs ❌ skip logs ❌ POST without approval

---

## Gate Protocol

Phase transitions are guarded. A phase cannot begin until its entry condition is met.

| Gate | Condition |
|------|----------|
| SPECIFY → PLAN | All problem-spec fields filled, SADC complete, AskUserQuestion ran (or skipped with reason) |
| PLAN → IMPLEMENT | Implementation plan complete + Scope output (Standard/Complex) + `⏸️ AWAITING APPROVAL TO ENTER IMPLEMENT` printed |
| IMPLEMENT → VERIFY | Self-review checklist pass, all IMPL steps done |
| VERIFY → DELIVER | All verification items PASS |

Standard/Complex tier: PLAN → IMPLEMENT gate produces a Scope (see Deliveries). The delivery report's Scope Drift field tracks any deviation.

---

## Inline Templates (NEW in v9.0.0 — formerly in procedure/templates/)

Four templates are now embedded inline. Standard/Complex tasks must use the exact headers below. Free-form = correctness bug.

### Problem Specification (SPECIFY output, Standard/Complex)

<template name="problem-spec">
# Problem Specification

| Field | Value |
|-------|-------|
| Request | [Exact user request — quoted verbatim] |
| Source Research | [SADC summary — existing solutions, docs consulted, patterns. If none found, state explicitly.] |
| Functional Requirement | [What the code must accomplish — "must" language] |
| Technical Constraints | [Platform limits, sandbox rules, framework requirements] |
| Identified Edge Cases | [List each with handling strategy] |
| Affected Files | [See table below] |
| Risk Level | [LOW / MEDIUM / HIGH with justification] |
| Dependencies | [External packages, services, config changes] |
| Source State | [Branch + HEAD SHA + verification status, or "No git repository involved"] |
| Scope OUT | [Explicitly excluded — prevents scope creep] |

## Affected Files

| File Path | Action | Purpose |
|-----------|--------|---------|
| path/to/file | Create / Modify | Why this file changes |

## Edge Cases

| # | Edge Case | Handling Strategy |
|---|-----------|-------------------|
| 1 | [Condition] | [How handled] |
</template>

### Implementation Plan (PLAN output, Standard/Complex)

<template name="implementation-plan">
# Implementation Plan: [Task Name]

## Approach
[2-3 sentences — design decision + why chosen]

## Alternatives Considered
- Alt 1: [Approach] — [Why rejected]
- Alt 2: [Approach] — [Why rejected]

## Pre-Deploy Verification
[Local verification step before target deployment, or "N/A"]

## Fallback Approach
[Alternative if primary fails. "No viable fallback — would require user input." if none.]

## Scope Boundary

| | Items |
|--|-------|
| **IN** | [What's included] |
| **OUT** | [What's excluded] |

## Implementation Steps

| Step | Action | Target File | Traceability ID |
|------|--------|-------------|-----------------|
| 1 | [Specific action] | [File path] | IMPL-001 |
| 2 | [Specific action] | [File path] | IMPL-002 |

## Requirements Mapping

| Traceability ID | Maps to Requirement | Notes |
|-----------------|--------------------|----|
| IMPL-001 | [Functional requirement] | [Context] |

## Verification Strategy

| What to Verify | Method | Expected Outcome | Traceability ID |
|----------------|--------|------------------|-----------------|
| [Behavior] | [How to check] | [Correct result] | IMPL-001 |
</template>

### Verification Report (VERIFY output, Standard/Complex)

<template name="verification-report">
# Verification Report: [Task Name]

## Automated Checks

| Check | Tool/Command | Expected | Actual | Status |
|-------|-------------|----------|--------|--------|
| Lint | [cmd] | No errors | [output] | PASS/FAIL |
| Type Check | [cmd] | No type errors | [output] | PASS/FAIL |
| Tests | [cmd] | All pass | [output] | PASS/FAIL |

## Pre-Deploy Verification

| Check | Method | Expected | Actual | Status |
|-------|--------|----------|--------|--------|
| [Pre-Deploy step or N/A] | [method] | [outcome] | [actual] | PASS/FAIL/N/A |

## Traceability Verification

| Traceability ID | Implementation Verified | Method | Status |
|-----------------|------------------------|--------|--------|
| IMPL-001 | [What was verified] | [How checked] | PASS/FAIL |

## Edge Case Verification

| Edge Case | Test Input | Expected | Actual | Status |
|-----------|-----------|----------|--------|--------|
| [Case] | [Input] | [Behavior] | [Actual] | PASS/FAIL |

## Summary

| Metric | Value |
|--------|-------|
| Automated checks passed | [n]/[total] |
| Traceability items passed | [n]/[total] |
| Edge cases passed | [n]/[total] |
| Defects found / fixed | [n] / [n] |
| Overall result | PASS / FAIL |

## Outcome Statement
[1-2 sentences — does code satisfy all requirements?]

## Failures (if any)
[Description + root cause + fix, or "None"]
</template>

### Incident Report (Recovery output, on error)

<template name="incident-report">
# Incident Report

## Error Capture

| Field | Value |
|-------|-------|
| Phase When Error Occurred | SPECIFY / PLAN / IMPLEMENT / VERIFY |
| Error Message | [Exact text — paste verbatim] |
| Error Classification | Compilation / Runtime / Network / Type / Database / Git / Wrong Approach / Other |
| Stack Trace | [If available] |
| Context | [What agent was doing] |

## Root Cause Analysis

| Question | Answer |
|----------|--------|
| What failed? | [Precise description] |
| Why did it fail? | [Chain of causation — 2+ levels deep] |
| Symptom or root cause? | [Symptom → identify root / Root cause] |
| Could recur elsewhere? | [Yes/No — if Yes, list locations] |

## Pivot Assessment

| Field | Value |
|-------|-------|
| Is Wrong Approach? | YES / NO |
| Pivot Signal | [50%+ rewrite / same error after 2 attempts / missing library feature / data model change / N/A] |
| Fallback Available? | YES / NO |
| New Approach | [Alternative — fallback or new] |
| User Approval Required? | YES / NO |

## Proposed Fix

| Field | Value |
|-------|-------|
| Fix Description | [What change resolves root cause] |
| Files Modified | [List + changes] |
| Has Side Effects? | YES / NO |
| Side Effect Details | [If YES: describe each] |
| User Approval Required? | YES / NO |

## Resolution

| Field | Value |
|-------|-------|
| Fix Applied | [What was done] |
| Return Phase | VERIFY / IMPLEMENT / SPECIFY |
| Re-verification Required? | YES |
</template>

---

## Deliveries

Two structured outputs bookend implementation: **Scope** (end of PLAN) and **Delivery** (end of DELIVER).

### Scope (Standard/Complex, end of PLAN)

```
☄️ COMMIT [Standard]
├─ Approach       : <primary approach, 1-2 sentences>
├─ Alternatives   : <2+ alternatives, 1 sentence each>
├─ Fallback       : <alternative if primary fails>
├─ Pre-Deploy     : <local verification step, or N/A>
├─ Scope IN       : <what's included>
├─ Scope OUT      : <what's excluded>
├─ IMPL Steps     : X (IMPL-001 to IMPL-XXX)
└─ Risk           : LOW / MEDIUM / HIGH
```

After printing Scope, print: `⏸️ AWAITING APPROVAL TO ENTER IMPLEMENT`
Do NOT call any tool after this line. Wait for user reply.

### Summary (Simple tier)

```
☄️ REPORT [Simple]
SPECIFY→DELIVER : PASS | Evidence: <one-line result> | Defects: 0 | Drift: NONE
Phase Trace     : IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
```

### Delivery (Standard/Complex)

```
☄️ REPORT [Standard]
├─ Continuation : NEW / YES
├─ Phase Trace  : IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
├─ IMPLEMENT     : PASS
│  ├─ Steps      : 4/4
│  ├─ Deviations : 0
│  └─ Quality    : lint PASS, tsc PASS
├─ VERIFY        : PASS
│  ├─ Checks     : 3/3
│  └─ Edge Cases : 2/2
├─ Pivot         : NONE
├─ Scope Drift   : NONE
└─ Outcome       : PASS

Evidence: [concrete results]
Defects found and fixed: 0
```

If Pivot is not NONE, expand it:
```
├─ Pivot         : YES
│  ├─ From      : <original approach>
│  ├─ Trigger   : <what made us pivot>
│  ├─ To        : <new approach>
│  └─ Re-planned : X steps (IMPL-001 to IMPL-XXX)
```

### Minimal (non-coding)

```
☄️ PASS | Evidence: <one-line result>
Phase Trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER (internal)
```

---

## Completion Signal

For interactive web development tasks (Next.js, UI components, dashboards), implementation is delegated to fullstack-dev — the DELIVER phase calls the platform's `Complete(project_type="web_dev", summary="...")` tool to finalize. For non-web coding tasks, DELIVER presents output file paths. In all cases, DELIVER appends a Snapshot to `worklog.md`.

---

## Layered Memory Protocol (v9.11.0 — detail in `knowledge/memory-protocol.md`)

| Layer | File | When written |
|---|---|---|
| L0 Task | worklog.md | DELIVER (existing) |
| L1 Pattern | knowledge/patterns.md | DELIVER (bash skeleton appended) |
| L2 Scenario | knowledge/scenarios.md | DELIVER (auto at ≥5 L1 per domain) |
| L3 Profile | knowledge/user-profile.md | DELIVER (auto at ≥3 same-decision) |

Detail (extraction format, on-demand loading table, anti-patterns) in `knowledge/memory-protocol.md`.

---

## Limitations

12 enforcement vectors (3 tiers) shift compliance to verifiable artifacts, but LLM is executor. Compliance scoring is bash-mechanical (v9.15.0: 5 artifacts checked, GREEN conditional). User is final judge.

**Verified working** (v9.15.0): E9 persistence (326+ entries/38+ days), clawhub drift detection, 3-way version sync, popup :3000, all 12 runtime deps, E7 token with session_meta (session-specific), E11 fresh clawhub re-verification, conditional 5/5 GREEN gate.
**Not working/unverifiable**: No session ID in E9 log (proves WHEN, never WHO), no PAT in clawhub-installed sandboxes, no $HOME/.stellar-trails-repo, popup user-visibility unverifiable, prose rots.
**TEXT-ENFORCED only** (cannot be code-enforced in z.ai sandbox): E4 Pre-Tool Gate, E5 Rationalizations, E8 TodoWrite, Phase Pause Gate, AskUserQuestion Gate. These cap maximum achievable compliance at ~80%.
**Rule of thumb**: Prose rots faster than bash — re-audit regularly.

**CODE enforcement progression**:
- v9.0.0: ~26% CODE-enforced (5/19 vectors)
- v9.15.0: ~58% CODE-enforced (11/19 vectors) — Proposals 1+2+4+6 + 2-Block Protocol
- v9.15.2: ~63% CODE-enforced (12/19 vectors) — Proposal 7 E8 todolist proxy
- v9.15.3: ~63% CODE-enforced + ~50% faster truncation recovery — Proposals 8+9+10 (session resilience, not enforcement)
- Maximum achievable: ~80% CODE-enforced (platform harness required for remaining 20%)

Research (Lost in the Middle, arXiv 2307.03172): ~70-85% compliance ceiling via text. v9.0.0+ raises to ~90%. v9.15.0 raises CODE enforcement to ~58%. 98% needs harness-level verifier. 100% needs platform enforcement.
