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

- **version**: 9.7.0

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

Every bash block in activation writes/verifies a hash token. LLM cannot proceed past Step 2+ without actually running Step 1 (which writes the token).

**Token file**: `/tmp/st-active` (session-scoped, wiped on session reset)
**Token content**: `sha256(version_line_from_SKILL.md)[:16]`

Step 1 writes the token. Steps 2-5 verify it at the top of their bash block:
```bash
# Gate check (top of every Step 2+ bash block):
EXPECTED=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | sha256sum | cut -c1-16)
ACTUAL=$(cat /tmp/st-active 2>/dev/null)
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "✗ GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
```

If LLM skips Step 1, token doesn't exist → Step 2 bash exits 1 → LLM cannot complete task. **LLM cannot fake this** because writing the correct hash requires reading SKILL.md (a tool call recorded in transcript).

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

**Log entry format** (one line per activation):
```
YYYY-MM-DDTHH:MM:SSZ v<VERSION> session=<session_id_short> steps=5/5 banner=YES tokens=YES
```

Step 5 writes the log entry. Next session's Step 1 can read the log to verify prior activations occurred. LLM can fake a log entry, but:
- Timestamps must be monotonic — fake entries with wrong timestamps are detectable
- Session IDs are recorded by platform — fake session IDs mismatch real ones
- User can `cat /home/user_skills/.st-activation-log` to audit anytime

**This is fraud detection, not prevention** — but it raises the cost of fraud (LLM must fabricate consistent timestamps + session IDs).

#### Vektor 4 — Read Tool Line-Number Proof (E10)

Step 1 must print a specific line from SKILL.md in the format `Read` tool returns (`<line_number>→<content>`). LLM cannot fabricate this format without actually calling Read.

**Protocol**: After Read SKILL.md, print the version line with its line number:
```
SKILL.md line 19: 19→- **version**: 9.4.0
```

User can verify by reading the same file themselves. If LLM fabricates (e.g., wrong line number, wrong content), user catches it on spot-check.

**Limitation**: LLM knows line 19 is the version line (from context). Stronger variant: skill mandates "print line N where N = current day-of-month + 10" — LLM cannot predict which line user will verify. But this adds complexity; the simple variant is sufficient for now.

#### Vektor 5 — Clawhub Oracle Cross-Check (E11)

Step 3 runs `clawhub inspect` — output is ground truth from an external binary LLM cannot fabricate. Step 4 re-runs `clawhub inspect` and cross-checks the version matches what Step 3 reported.

**Protocol**:
- Step 3 writes `clawhub inspect --json` output to `/tmp/st-clawhub-oracle.json`
- Step 4 reads `/tmp/st-clawhub-oracle.json`, extracts `latestVersion.version`
- Step 4 compares to what LLM claimed in transcript
- If mismatch → COMPLIANCE FAILURE reported to user

**Why this works**: `clawhub` is a binary outside LLM control. LLM cannot fabricate `/tmp/st-clawhub-oracle.json` without actually running clawhub (which is a tool call recorded in transcript). The file's content is ground truth — LLM's text claims can be verified against it.

#### Combined Enforcement Matrix

| Vector | What it enforces | LLM can fake? | User can verify? |
|---|---|---|---|
| E7 Hash token | Steps 2-5 cannot run without Step 1 | NO (token requires actual file read) | YES (cat /tmp/st-active) |
| E8 TodoWrite | Steps visible in real-time UI | Partially (can mass-mark, but transitions are visible) | YES (watch live checklist) |
| E9 Persistent log | Cross-session audit trail | Partially (timestamps + session IDs must be consistent) | YES (cat /home/user_skills/.st-activation-log) |
| E10 Line-number proof | Step 1 actually called Read | Partially (LLM knows line 19) | YES (read same file, compare) |
| E11 Clawhub oracle | Step 3 actually ran clawhub | NO (external binary output is ground truth) | YES (cat /tmp/st-clawhub-oracle.json) |

**What still cannot be enforced**: Banner printed as FIRST output (text ordering), LLM not printing fake `✓ Step N` markers (text). These remain text-only enforcement via E4-E6.

### Activation Steps

**Step 1 — Refresh context + SSV**: Re-read `/home/z/my-project/skills/stellar-trails/SKILL.md` from disk using the Read tool. Do not trust cached context — the on-disk version is source of truth. If task involves a git repo, run SSV. **E7 (hash token) and E10 (line-number proof) are written by this step** — subsequent steps verify the token to enforce that Step 1 actually ran.

```bash
# SSV only runs if the skill has its own git repo at $HOME/.stellar-trails-repo/.
# In the z.ai sandbox this directory usually does not exist (skill is installed
# via clawhub, not git clone), so SSV is skipped gracefully. Running bare
# `git fetch` from /home/z/my-project/ would operate on the sandbox workspace
# repo — explicitly forbidden by knowledge/platform/zai-sandbox.md.
if [ -d "$HOME/.stellar-trails-repo/.git" ]; then
  git -C "$HOME/.stellar-trails-repo" fetch origin --quiet 2>/dev/null
  BRANCH=$(git -C "$HOME/.stellar-trails-repo" branch --show-current 2>/dev/null || echo main)
  BEHIND=$(git -C "$HOME/.stellar-trails-repo" rev-list --count HEAD..origin/$BRANCH 2>/dev/null)
  if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then echo "✗ Step 1 FAILED: skill repo is $BEHIND commits behind origin — run git -C $HOME/.stellar-trails-repo pull"
  else echo "✓ Step 1: context refreshed + SSV passed (v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null || echo unknown))"; fi
else
  echo "✓ Step 1: context refreshed (v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null || echo unknown)) — SSV skipped (no skill git repo)"
fi
# E7: Write hash token — Steps 2-5 verify this token to prove Step 1 ran.
# Token = sha256(version line)[:16]. LLM cannot fake this without reading SKILL.md.
grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | sha256sum | cut -c1-16 > /tmp/st-active
# E10: Print line-number proof — user can verify by reading same file.
SKILL_VERSION_LINE=$(grep -n '^- \*\*version\*\*:' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1 | cut -d: -f1)
echo "  E7 token: $(cat /tmp/st-active)"
echo "  E10 line proof: SKILL.md line ${SKILL_VERSION_LINE}: $(sed -n "${SKILL_VERSION_LINE}p" /home/z/my-project/skills/stellar-trails/SKILL.md)"
```

**Step 2 — Start popup server + verify mascot**: **E7 gate check at top of bash block** — verifies Step 1 ran by checking hash token.

```bash
# E7 gate check — proves Step 1 actually ran (token requires reading SKILL.md)
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active 2>/dev/null)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 2 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
SKILL_DIR="/home/z/my-project/skills/stellar-trails"; ZSCRIPTS="/home/z/my-project/.zscripts"
if [ ! -f "$SKILL_DIR/chibi.svg" ]; then for REPO_CLONE in "/home/z/my-project/stellar-trails/skill/stellar-trails" "/home/z/my-project/.stellar-trails-repo/skill/stellar-trails" "$HOME/.stellar-trails-repo/skill/stellar-trails"; do [ -f "$REPO_CLONE/chibi.svg" ] && cp -f "$REPO_CLONE/chibi.svg" "$SKILL_DIR/chibi.svg" && break; done; fi
if [ -d "$SKILL_DIR" ]; then mkdir -p "$ZSCRIPTS"; [ -f "$SKILL_DIR/dev.sh" ] && cp -f "$SKILL_DIR/dev.sh" "$ZSCRIPTS/dev.sh" && chmod +x "$ZSCRIPTS/dev.sh"; [ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS/index.html"; [ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS/chibi.svg"; fi
DEV_SH="$ZSCRIPTS/dev.sh"; [ -f "$DEV_SH" ] && ! ss -tlnp 2>/dev/null | grep -q ':3000 ' && ( setsid bash "$DEV_SH" </dev/null >/dev/null 2>&1 & ) &
sleep 1
HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ 2>/dev/null)
MASCOT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/chibi.svg 2>/dev/null)
if [ "$HTTP" = "200" ]; then echo "✓ Step 2: popup server running on :3000 (HTTP $HTTP, mascot $MASCOT)"; else echo "✗ Step 2 FAILED: popup server not responding (HTTP $HTTP)"; fi
```

**z.ai sandbox note**: The popup server runs on `localhost:3000` inside the sandbox, but z.ai does NOT expose raw ports to the user's browser. The popup is only visible through the z.ai preview URL pattern: `https://preview-<bot-id>.space-z.ai/`. If the sandbox exposes a preview panel, the popup appears there; otherwise the popup runs but is invisible to the user (activation still succeeds — the popup is decorative, not functional). See `knowledge/platform/zai-sandbox.md` for details.

**Step 3 — Auto-update via ClawHub**: **E7 gate check + E11 oracle** — clawhub output written to `/tmp/st-clawhub-oracle.json` for Step 4 cross-verification.

```bash
# E7 gate check
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active 2>/dev/null)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 3 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
CURRENT=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | head -1)
# E11: Write clawhub output to oracle file — Step 4 will cross-verify this.
# LLM cannot fabricate this file without actually running clawhub (tool call recorded).
clawhub inspect stellar-trails --json 2>/dev/null > /tmp/st-clawhub-oracle.json
LATEST=$(python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" < /tmp/st-clawhub-oracle.json 2>/dev/null || echo "")
if [ -z "$CURRENT" ]; then echo "✗ Step 3 FAILED: could not read current version from SKILL.md"
elif [ -z "$LATEST" ]; then echo "✗ Step 3 FAILED: could not reach ClawHub registry (network down?)"
elif [ "$CURRENT" = "$LATEST" ]; then echo "✓ Step 3: up to date (v$CURRENT) — E11 oracle: $(stat -c%s /tmp/st-clawhub-oracle.json) bytes"
else
  if clawhub --no-input update stellar-trails --force 2>/dev/null; then
    # Sync the persistent zip immediately after a successful update.
    # Without this, the zip stays stale until Step 4e runs — and if a session
    # reset happens between this update and the next Skill() invoke, the stale
    # zip re-extracts and downgrades skills/ back to the old version.
    # (Fixes P2-NEW-1 from v9.2.0 audit.)
    SKILL_DIR="/home/z/my-project/skills/stellar-trails"
    USER_SKILLS_DIR="/home/user_skills"
    if [ -d "$SKILL_DIR" ] && [ -d "$USER_SKILLS_DIR" ]; then
      cd "$(dirname "$SKILL_DIR")" && zip -qr "$USER_SKILLS_DIR/stellar-trails.zip" "$(basename "$SKILL_DIR")/" 2>/dev/null && echo "✓ Step 3: updated v$CURRENT → v$LATEST (zip synced)" || echo "✓ Step 3: updated v$CURRENT → v$LATEST (zip sync warning)"
    else
      echo "✓ Step 3: updated v$CURRENT → v$LATEST"
    fi
  else
    echo "✗ Step 3 FAILED: clawhub update error"
  fi
fi
```

If clawhub updated the skill: re-read SKILL.md from disk now. Cached context is stale.

**Step 4 — Verify files + force-override .zscripts/ + restart dev.sh + sync zip**: **E7 gate + E11 cross-check** — verifies Step 3 oracle file exists and matches claimed version.

```bash
# E7 gate check
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active 2>/dev/null)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 4 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
# E11 cross-check: verify Step 3 oracle file exists (proves Step 3 ran clawhub)
if [ ! -f /tmp/st-clawhub-oracle.json ]; then
  echo "✗ Step 4 E11 FAILED: clawhub oracle file missing — Step 3 must run first"
  exit 1
fi
ORACLE_VERSION=$(python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" < /tmp/st-clawhub-oracle.json 2>/dev/null || echo "")
echo "  E11 oracle cross-check: registry latest = v${ORACLE_VERSION:-<parse failed>}"
SKILL_DIR="/home/z/my-project/skills/stellar-trails"; USER_SKILLS_DIR="/home/user_skills"; ZSCRIPTS="/home/z/my-project/.zscripts"
FILES_OK="yes"
for f in SKILL.md procedure/phases.md dev.sh index.html chibi.svg; do [ ! -f "$SKILL_DIR/$f" ] && echo "✗ Step 4 WARNING: missing $f" && FILES_OK="no"; done
if [ "$FILES_OK" = "yes" ]; then echo "✓ Step 4a: all skill files present"; else echo "✗ Step 4a FAILED: some files missing — graceful degradation"; fi
mkdir -p "$ZSCRIPTS"
[ -f "$SKILL_DIR/dev.sh" ] && cp -f "$SKILL_DIR/dev.sh" "$ZSCRIPTS/dev.sh" && chmod +x "$ZSCRIPTS/dev.sh"
[ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS/index.html"
[ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS/chibi.svg"
echo "✓ Step 4b: .zscripts/ force-overridden with latest files"
OLD_PID=$(ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | head -1)
if [ -n "$OLD_PID" ]; then kill "$OLD_PID" 2>/dev/null; sleep 1; echo "✓ Step 4c: old dev.sh (PID $OLD_PID) killed"; fi
DEV_SH="$ZSCRIPTS/dev.sh"
if [ -f "$DEV_SH" ]; then ( setsid bash "$DEV_SH" </dev/null >/dev/null 2>&1 & ) & sleep 1
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ 2>/dev/null)
  if [ "$HTTP" = "200" ]; then echo "✓ Step 4d: dev.sh restarted on :3000 (HTTP $HTTP)"; else echo "✗ Step 4d FAILED: dev.sh restart failed (HTTP $HTTP)"; fi
else echo "✗ Step 4d FAILED: dev.sh not found at $DEV_SH"; fi
if [ -d "$SKILL_DIR" ] && [ -d "$USER_SKILLS_DIR" ]; then cd "$(dirname "$SKILL_DIR")" && zip -qr "$USER_SKILLS_DIR/stellar-trails.zip" "$(basename "$SKILL_DIR")/" && echo "✓ Step 4e: persistent zip synced" || echo "✗ Step 4e FAILED: zip sync error"; else echo "✗ Step 4e FAILED: directory not found"; fi
```

**Step 5 — Load phases + classify**: Read `procedure/phases.md` now. Then determine complexity tier (Minimal/Simple/Standard/Complex), task type (Coding/Document/Visualization/Data Processing/Non-Coding), and continuity (NEW or YES — see Session Continuity below). **E7 gate + E9 persistent log** — writes activation record to `/home/user_skills/.st-activation-log` for cross-session audit.

```bash
# E7 gate check
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active 2>/dev/null)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 5 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
# E9: Write persistent activation log — user can audit anytime via:
#   cat /home/user_skills/.st-activation-log
ST_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | head -1)
ST_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ST_TOKEN=$(cat /tmp/st-active)
echo "${ST_TIMESTAMP} v${ST_VERSION} token=${ST_TOKEN} steps=5/5 banner=YES" >> /home/user_skills/.st-activation-log
echo "✓ Step 5: phases loaded + classified: [tier]/[type]/[NEW|YES] — E9 log entry written"
```

**Mandatory TodoWrite protocol (E8)**: Before Step 1 bash, call `TodoWrite` with 5 items (Step 1 through Step 5), all status `pending`. Before each Step N bash, mark Step N `in_progress`. After each Step N bash succeeds, mark Step N `completed`. User sees the live checklist transition in real-time — this is visibility enforcement that text cannot provide.

After Step 5: Begin SPECIFY (or IMPLEMENT if continuation detected).

### FORBIDDEN Rationalizations for Skipping Activation (E5 — Layer 3, NEW in v9.3.0)

The following thoughts are **CORRECTNESS BUGS**, not valid optimizations. If you catch yourself thinking ANY of these, STOP and run activation NOW.

❌ **"This is a continuation task, I don't need to re-activate"**
   → WRONG. Continuation skips SPECIFY+PLAN, NOT activation. Every `Skill()` invoke requires fresh activation — after context truncation, you cannot reliably know what you did before.

❌ **"This is a simple/trivial task, activation is overkill"**
   → WRONG. SKILL.md says "every task gets a delivery report — no exceptions for simplicity." Minimal tier still requires banner + 5 steps + `☄️ PASS` report.

❌ **"The session is already long, I'll save tokens by skipping"**
   → WRONG. Activation takes ~2 seconds and ~500 tokens. From a 200K context budget, that's 0.25% — negligible. User cannot see your context length, so they cannot "understand" why you skipped.

❌ **"I already printed the banner in a previous message"**
   → WRONG. Per SKILL.md: "After context truncation, you cannot reliably know what you did." The banner is the ONLY signal to the user that activation ran. Print it every invoke.

❌ **"The user didn't complain last time I skipped"**
   → WRONG. User silence is not approval. The banner exists for the USER's benefit, not yours. They may have noticed but chosen not to comment, or they may not have realized skipping was a bug.

❌ **"I'll just label it 'Minimal tier' and skip"**
   → WRONG. Minimal tier still requires banner + 5 steps. The complexity tier affects REPORT FORMAT, not ACTIVATION REQUIREMENTS. All tiers must activate.

❌ **"Pattern drift — I've skipped before and it was fine"**
   → WRONG. Past skips were bugs, not precedent. Each invoke is independent; previous bugs do not authorize future bugs.

❌ **"I'll print the report without activation, user won't notice"**
   → WRONG. This is silent skipping — the WORST option. If you must skip (emergency only), use the Escape Hatch (E6 below) to make it visible. Silent skips hide failures from the user.

### If You Must Skip Activation — Escape Hatch (E6 — Layer 5, NEW in v9.3.0)

If you are under extreme context pressure (≥90% context used) and MUST skip activation:

1. Print this EXACT line first: `⚠️ ACTIVATION SKIPPED — operating without banner`
2. State the reason in one sentence (e.g., "Reason: 92% context used, emergency task")
3. Acknowledge: `This is a correctness bug per SKILL.md E4 Pre-Tool-Call Gate.`
4. Proceed with the task

**Do NOT silently skip.** Silent skipping hides the failure from the user. A visible skip at least lets the user know they should verify the output more carefully.

**Escape hatch is for emergencies only** — not for "I'm lazy" or "this is simple". Misusing the escape hatch is itself a correctness bug.

---

## Three Enforcement Layers (NEW in v9.0.0)

This version adds three deterministic enforcement layers that shift compliance from LLM goodwill to verifiable artifacts. Every layer below produces a print, a file, or a turn-ending marker — none rely on the LLM "remembering" to do them.

### E1 — Phase Machine Enforcement

Every task passes through all six phases (IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER). No phase is skipped, even for Minimal tier.

**Mechanism**: Each phase entry requires a phase-marker print of the form `📍 ENTER <PHASE>` before any other phase work. Each phase exit requires `📍 EXIT <PHASE> → <NEXT>`. The DELIVER report's `Phase Trace` field lists every phase-marker pair. Missing markers = compliance bug.

**Why**: Phase skipping is the #1 silent failure mode. The marker print makes skipping visible in the transcript, not invisible in the LLM's hidden reasoning.

### E2 — Mandatory Print Enforcement (Banner / Report / Block)

Three prints are mandatory and have exact syntax. Self-check before DELIVER:

| Print | When | Required Syntax |
|---|---|---|
| Activation banner | FIRST output of session | See Activation section |
| COMMIT [Standard] block | End of PLAN, before IMPLEMENT (Standard/Complex only) | See Deliveries → Scope |
| Delivery REPORT block | LAST output of session | See Deliveries → Delivery/Summary/Minimal |

**Mechanism**: Before printing the Delivery report, print a self-check line:
```
✓ Pre-DELIVER print check: banner=✓ commit=✓/N/A report=✓
```
If any mandatory print was missed, do not print the report — go back and emit it first.

**Pre-DELIVER Self-Audit (E2 expansion — Layer 2, NEW in v9.3.0)**: The single-line `banner=✓` check above is too easy to self-grade as `✓` even when skipped. Before printing the delivery report, answer these 5 questions HONESTLY:

1. Did I print `☄️ STELLAR TRAILS · vX.Y.Z · ACTIVE` as my FIRST output to the user?
2. Did I execute all 5 activation steps with `✓`/`✗` marks visible in the transcript?
3. Did I read SKILL.md from disk in Step 1 (not just trust cached context)?
4. Did I verify the popup server in Step 2 (HTTP 200)?
5. Did I check ClawHub for updates in Step 3?

If ANY answer is NO, append to the delivery report:
```
⚠️ ACTIVATION COMPLIANCE FAILURE:
  - Banner printed as first output: YES/NO
  - Steps executed with visible ✓/✗: n/5
  - Failed steps: [list]
  - Reason: [honest one-line explanation]
```

**Do NOT hide activation failures.** The user deserves to know. Self-grading `banner=✓` when you actually skipped is a lie — and the user can verify by scrolling up in the transcript. If they catch you lying, trust is broken permanently.

**Why**: Bookend prints are the only signal the user has that the workflow ran. Missing any one of them is treated as a correctness bug, not a style preference.

### E3 — Preferences Dialog Enforcement (AskUserQuestion)

For any decision point where the LLM would otherwise guess audience/style/length/format/scope, invoke `AskUserQuestion` BEFORE producing content. This applies to:

- Deliverable-creation tasks (Document, Visualization, PPT, PDF, Excel, dashboard, poster, script) — MANDATORY unless original request pins audience + style + length
- Mid-task scope decisions (e.g., "should I also do X?", "which approach: A or B?") — MANDATORY
- Recovery decisions after Pivot (e.g., "fallback approach A or new approach B?") — MANDATORY
- Simple clarifications ("did you mean X or Y?") — MANDATORY if ambiguity would change output

**Skip conditions** (auto-bypass, no AskUserQuestion needed):
- User explicitly says "skip questions" / "just do it" / "no questions"
- Continuation task where prior turn already approved the approach
- Coding/Data Processing tasks with no design dimensions (e.g., "fix this typo", "run this script")
- Trivial one-shot edits (single number change, single typo fix)

**Mechanism**: Print `✓ Preferences dialog check: <INVOKED | SKIPPED: <reason>>` before any content-producing tool call in SPECIFY. This makes the decision visible.

**Why**: Guessing audience/style/length causes the most expensive rework in document tasks. One batched 30-second question round prevents hours of regeneration.

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

**Why main agent, not subagent**: The z.ai sandbox mandates "Skill invocation and skill-driven file generation MUST be done by the main agent, NEVER by subagents." Subagents in z.ai do not have access to skill instructions, so a subagent that calls `Skill(command="web-search")` will fail silently. (Removed subagent delegation in v9.1.0 — see audit P0-2.)

If no existing solution is found, state it explicitly — "searched npm/PyPI/docs, no existing package found" is a valid result. Building from scratch when a library exists is a spec-level defect.

**When subagents ARE appropriate**: Subagents may be used for non-skill tasks (e.g., "summarize these 5 URLs", "compare these 2 code samples"). The main agent fetches content via skills first, then delegates pure-text analysis to subagents. The rule: skills are invoked by the main agent; subagents operate on text the main agent has already retrieved.

Historical subagent delegation template (deprecated): see `references/sadc-subagent-delegation.md`.

---

## AskUserQuestion Gate (SPECIFY phase)

For deliverable-creation tasks (Document, Visualization, PPT, PDF, Excel, dashboard, poster, script, chart-as-deliverable), invoke `AskUserQuestion` BEFORE writing the problem specification.

**Mandate**: In SPECIFY phase, if task type is Document or Visualization AND the user's original request does NOT explicitly pin audience + style + length, invoke `AskUserQuestion` with 6–8 questions.

Print before any content-producing tool call: `✓ Preferences dialog check: <INVOKED | SKIPPED: <reason>>`

**Skip conditions**: user says skip / all 3 dimensions explicit / trivial edit / Coding/Non-Coding / continuation. AT MOST ONCE per run, before any content-producing tool. After answers return, proceed straight to PLAN (no loop-back).

Full 6-8 question template + skip conditions: read `references/askuserquestion-gate.md` before invoking.

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

## Implementation Discovery Protocol (NEW in v9.2.0)

**Problem this solves**: While implementing a fix for bug X, the agent discovers bug Y in the same area. Two failure modes disrupt the workflow:

- **Silent fix Y** → user sees unexpected changes in the diff, cannot tell what was planned vs. discovered. Scope Drift without acknowledgment.
- **Silent skip Y** → Y is forgotten, surfaces later as a "new" bug, wasting a future audit cycle.

This pattern occurred twice during this skill's own development:
- v9.0.1 task was "fix Step 3 regex + add undelete" → discovered python3 `IndentationError` in the new code I just wrote (same surface, fixed in v9.0.2)
- v9.1.0 audit found 5 bugs → while patching, discovered the v9.0.2 phases.md had 2 additional memory/ references I missed in the initial audit (same surface, fixed in same commit)

**Rule**: Do NOT silently fix Y. Do NOT silently skip Y. Either choice disrupts the workflow.

### Protocol

When you discover bug Y while implementing fix for bug X:

1. **STOP** implementation momentarily. Do not race ahead.

2. **DOCUMENT** the discovery immediately — append to `/home/z/my-project/worklog.md`:
   ```
   discovery: <Y one-line> | found while: <X one-line> | surface: <same|different> | action: <fix-now|defer>
   ```

3. **CLASSIFY** using the Same-Surface Test:
   - **Same surface** (same file, same function, same root cause, same bash block):
     → **FIX NOW** in the same commit
     → Update Scope: add Y to Scope IN
     → Note in delivery report: `Scope Drift: +Y (discovered while fixing X, same surface)`
   - **Different surface** (different file, different system, different root cause):
     → **DEFER** to next iteration
     → Add Y to "Deferred Discoveries" section in delivery report
     → Log Y to worklog with `next_step: investigate Y in next iteration`

4. **RESUME** implementation with updated scope (if fix-now) or original scope (if defer).

5. **NEVER LOSE TRACK** of the original task. The DELIVER worklog snapshot must include BOTH X and Y status:
   - X: completed (in this iteration)
   - Y: completed (fix-now, same commit) OR deferred (next iteration)

### Same-Surface Test Decision Tree

```
Discovered bug Y while fixing bug X
         │
         ├─ Is Y in the same file as X's fix?
         │    ├─ YES → likely same surface
         │    └─ NO  → likely different surface (DEFER)
         │
         ├─ Is Y's root cause the same as X's root cause?
         │    ├─ YES → same surface (FIX NOW)
         │    └─ NO  → different surface (DEFER)
         │
         ├─ Does fixing Y require changing code outside X's blast radius?
         │    ├─ NO  → same surface (FIX NOW)
         │    └─ YES → different surface (DEFER)
         │
         └─ Would deferring Y cause X's fix to fail CI / verification?
              ├─ YES → same surface (FIX NOW, mandatory)
              └─ NO  → defer is safe
```

### Anti-patterns (FORBIDDEN)

- ❌ "I'll just fix Y real quick while I'm here" — no documentation, user sees surprise changes
- ❌ "Y is small, I'll mention it in the commit message" — commit messages are not delivery reports
- ❌ "Y is unrelated, I'll skip it" — without logging, Y is forgotten forever
- ❌ "I found 3 more bugs, let me fix them all" — without classification, scope explodes silently

### Worked example (from this skill's history)

**v9.0.1 → v9.0.2 transition**:
- Original task: "fix Step 3 broken regex + add undelete step"
- Discovery: while writing the new `python3 -c` block for Step 3, used multi-line indented python inside single-quoted bash string → `IndentationError`
- Same-Surface Test: same file (SKILL.md), same bash block (Step 3), same root cause (my new code) → **FIX NOW**
- Action: rewrote python3 -c as one-liner, pushed as v9.0.2
- Delivery report Pivot field: "YES — discovered IndentationError while writing the regex fix"
- Lesson: this protocol did not exist in v9.0.1, so the discovery was handled ad-hoc. v9.2.0 codifies the pattern.

### Worklog entry format (when discovery occurs)

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
blocks = re.findall(r'```bash\n(.*?)```', content, re.DOTALL)
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
    cmd = f'echo "{{}}" | python3 -c {block} 2>/dev/null'
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
REGISTRY_STATE=$(clawhub inspect stellar-trails --json 2>/dev/null)
if [ -z "$REGISTRY_STATE" ]; then
  echo "✗ Check 6 FAIL: cannot reach clawhub registry — push may publish to hidden skill"
else
  MOD_STATE=$(echo "$REGISTRY_STATE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('moderation',{}).get('state','unknown'))" 2>/dev/null || echo "unknown")
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
if git diff --cached --name-only HEAD 2>/dev/null | grep -q '\.github/workflows/'; then
  python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && \
    echo "✓ Check 7: workflow YAML valid" || echo "✗ Check 7 FAIL: workflow YAML invalid"
else
  echo "✓ Check 7: no workflow files changed (skip)"
fi
```

#### Check 8: Markdown fence count is even (no orphan code blocks)
```bash
FENCES=$(grep -c '```' skill/stellar-trails/SKILL.md)
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

## Proximate Cause Triage (NEW in v9.5.0 — orisinil feature)

**Problem this solves**: GLM-5.2 z.ai has a known weakness — when auditing or diagnosing, it tends to trace problems too far down the causal chain, rabbit-holing into deep investigations when the root cause is proximate and simple. This wastes tokens and time, and often loses the user's actual question in the weeds.

**Inspiration**: Combines core concepts from two clawhub skills — `occams-razor` (Parsimony Audit: prefer fewest assumptions) and `aana-task-scope-guardrail` (Scope Gate: classify actions, stop when complete) — into a single orisinil protocol integrated into stellar-trails workflow. **Not a wrapper** — this is a native feature with its own decision tree, tuned for the proximate-cause failure mode.

### When to Apply

**Mandatory trigger** in these phases:
- **SPECIFY**: after identifying the problem, BEFORE writing problem-spec
- **VERIFY**: when tracing a defect, BEFORE going deeper than 2 levels
- **Recovery**: when classifying bug vs wrong approach

**Optional trigger** (LLM should self-check):
- Whenever internal reasoning exceeds 3 "why" levels
- Whenever audit scope expands beyond original request
- Whenever a hypothesis requires >2 unsupported assumptions

### The Proximate Cause Test

Before going deeper into investigation, answer these 3 questions:

**Q1: Is the candidate cause within 1 hop of the symptom?**
- YES → strong proximate candidate, prefer this first
- NO → far cause, only investigate if Q2 fails

**Q2: Does the candidate explain ALL observed symptoms with ≤2 assumptions?**
- YES → parsimonious, prefer this
- NO → needs too many assumptions, defer (likely over-engineering)

**Q3: Would fixing this candidate resolve the user's actual request?**
- YES → in scope, fix it
- NO → out of scope, log to "Deferred Discoveries" and stop

### Decision Tree

```
Symptom observed
   │
   ├─ Q1: Is candidate within 1 hop of symptom?
   │    ├─ YES + Q2 ≤2 assumptions + Q3 fixes user request
   │    │    → FIX NOW (proximate, parsimonious, in-scope)
   │    │
   │    ├─ YES but Q2 >2 assumptions
   │    │    → Look for SIMPLER proximate cause before going deeper
   │    │
   │    └─ NO (far cause)
   │         ├─ Q3 still in scope?
   │         │    ├─ YES → investigate, but time-box (max 1 deeper level)
   │         │    └─ NO  → DEFER (out of scope, log it)
   │         └─ Q2 needs >3 assumptions?
   │              → STOP. Likely over-engineering. Re-state problem to user.
```

### Scope Gate (from aana-task-scope-guardrail, integrated)

Before each investigation step, classify the action:

| Category | Action |
|---|---|
| `in_scope` | Directly requested by user → proceed |
| `necessary_support` | Required to complete request → proceed |
| `clarification_needed` | Ambiguous boundary → ASK user before continuing |
| `optional_followup` | Useful but not required → mention briefly, do NOT do |
| `out_of_scope` | Unrelated/premature → DO NOT do, log to worklog |
| `stop` | Request is complete → STOP, do not keep acting |

**Hard rule**: if proposed action is `out_of_scope` OR request is `stop`, you MUST stop. Continuing is a correctness bug.

### Parsimony Audit (from occams-razor, integrated)

When multiple competing hypotheses exist for a symptom:

```
# Parsimony Audit: <symptom>
## Candidates:
  A: <hypothesis 1>  B: <hypothesis 2>  C: <hypothesis 3>
## Fit check:
  A fits all evidence? <yes/no>  B? <yes/no>  C? <yes/no>
## Assumption load (count unsupported assumptions, NOT words):
  A: <list> → N assumptions
  B: <list> → N assumptions
  C: <list> → N assumptions
## Proximate check:
  A within 1 hop? <yes/no>  B? <yes/no>  C? <yes/no>
## Preferred: <fewest assumptions + most proximate>
## Over-shave check: <preferred still fits all evidence?>
## What would overturn this: <distinguishing evidence>
```

**Key rule**: parsimony counts **unsupported assumptions**, not words. "It's the network" (5 words) posits 1 unobserved failure — high assumption load. "Cache TTL expired at 14:03, as logs show" (10 words) assumes 0 unsupported — low load. Prefer the second.

### Anti-patterns (FORBIDDEN)

- ❌ "Let me trace this deeper to be sure" — if proximate cause found, STOP. Going deeper without evidence of misdiagnosis is scope creep.
- ❌ "There might be a hidden root cause" — without a specific symptom that the proximate cause does NOT explain, this is speculation, not investigation.
- ❌ "I'll fix this AND investigate the deeper cause" — fixing + investigating = two tasks. User asked for one. Log the deeper investigation as `optional_followup`.
- ❌ "Let me check 5 more files just in case" — this is `out_of_scope` unless user asked for full audit. Proximate cause + parsimony audit is sufficient.
- ❌ Applying Parsimony Audit when only 1 hypothesis exists — Occam's Razor chooses AMONG candidates. With 1 candidate, no choice to make.

### Worked Example

**Scenario**: User reports "Step 3 activation fails with '✗ GATE FAILED'".

**Wrong (deep rabbit hole)**:
1. Investigate Step 3 bash block
2. Check clawhub version
3. Inspect sha256 implementation
4. Investigate SKILL.md encoding
5. Check Linux filesystem layer
6. ... (10 levels deep, never finds it)

**Right (Proximate Cause Triage)**:
1. Symptom: `✗ GATE FAILED` means `EXPECTED_TOKEN != ACTUAL_TOKEN`
2. Q1: Is candidate within 1 hop? YES — token mismatch is directly in Step 1 bash
3. Q2: Does it explain all symptoms with ≤2 assumptions?
   - Assumption 1: Step 1 bash didn't run (so token not written)
   - Assumption 2: OR Step 1 ran but wrote wrong hash
   - → 2 assumptions, parsimonious
4. Q3: Would fixing this resolve user's request? YES
5. Action: check if `/tmp/st-active` exists. If missing → Step 1 was skipped. If present but wrong → recompute hash.
6. **STOP** at first resolution. Do not investigate deeper unless fix fails.

### Integration with existing protocols

- **Implementation Discovery Protocol**: Proximate Cause Triage informs the Same-Surface Test. If discovered bug Y is within 1 hop of bug X (proximate), likely same surface → fix-now.
- **Pivot**: when classifying bug vs wrong approach, run Proximate Cause Test first. If proximate cause exists, it's a bug (fix). If no proximate cause after 2 hops, it's likely wrong approach (pivot).
- **Recovery**: Step 1 (Stop) + Step 2 (Classify) must include Proximate Cause Triage before proceeding.

---

## Inline Content Retrieval (NEW in v9.5.0 — orisinil feature)

**Problem this solves**: stellar-trails SADC section previously mandated `Skill(command="crawl4ai")` for content extraction. This creates external dependency — if crawl4ai is not installed, broken, or its API changes, SADC fails. User explicitly requested removing this reliance.

**Solution**: orisinil inline content retrieval using sandbox-native tools (`curl` + `python3`). No external skill dependency. Simpler, more reliable, fully under stellar-trails control.

### When to Use

Replace `Skill(command="crawl4ai")` and `Skill(command="web-reader")` calls with this inline protocol in:
- **SADC** (Standard/Complex tier): extracting content from top URLs returned by web-search
- **VERIFY**: pulling live doc content to confirm claims
- Any phase needing web page text extraction

### The Retrieval Protocol

**Step 1: Fetch with curl** (sandbox-native, no Python dependency)
```bash
# Fetch URL, follow redirects, set user-agent, 10s timeout, capture to file
URL="<url>"
OUTFILE="/tmp/st-retrieval-$(echo "$URL" | sha256sum | cut -c1-8).html"
curl -sSL -m 10 -A "Mozilla/5.0 (compatible; StellarTrails/9.5)" "$URL" -o "$OUTFILE" 2>/dev/null
HTTP_STATUS=$(curl -sSL -m 10 -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
[ "$HTTP_STATUS" = "200" ] || { echo "✗ Retrieval failed: HTTP $HTTP_STATUS"; exit 1; }
echo "✓ Fetched $(stat -c%s "$OUTFILE") bytes from $URL"
```

**Step 2: Extract text with python3** (using only stdlib `html.parser`)
```bash
python3 << 'PYEOF'
import sys, re, html
from html.parser import HTMLParser

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
        self.skip = False  # skip script/style/nav/footer
        self.skip_tags = {'script', 'style', 'nav', 'footer', 'header', 'aside', 'noscript'}
        self.title = ''
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        if tag in self.skip_tags:
            self.skip = True
        if tag == 'title':
            self.in_title = True
        if tag in ('h1','h2','h3','h4','h5','h6','p','li','td','th','div','section','article','pre','code','blockquote'):
            self.text.append('\n')  # block-level: newline before

    def handle_endtag(self, tag):
        if tag in self.skip_tags:
            self.skip = False
        if tag == 'title':
            self.in_title = False
        if tag in ('p','li','div','section','article','pre','blockquote'):
            self.text.append('\n')  # block-level: newline after

    def handle_data(self, data):
        if self.skip:
            return
        if self.in_title:
            self.title += data
        text = data.strip()
        if text:
            self.text.append(text)

with open(sys.argv[1], 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

parser = TextExtractor()
parser.feed(content)
result = ' '.join(parser.text)
# Collapse whitespace
result = re.sub(r'\s+', ' ', result)
result = re.sub(r' \n ', '\n', result)
result = re.sub(r'\n{3,}', '\n\n', result)
# Trim to first 3000 chars (SADC needs summary, not full page)
result = result[:3000]
if parser.title:
    print(f"# {parser.title.strip()}\n")
print(result)
PYEOF
```

**Step 3: Truncate to ≤500 words for SADC summary**
```bash
# After extraction, truncate to 500 words for SADC
TEXT_FILE="${OUTFILE%.html}.txt"
python3 -c "
import sys
text = sys.stdin.read()
words = text.split()[:500]
print(' '.join(words))
" < "$TEXT_FILE" > "${TEXT_FILE}.truncated"
echo "✓ Extracted $(wc -w < "${TEXT_FILE}.truncated") words to ${TEXT_FILE}.truncated"
```

### When to Use Inline vs External Skill

| Situation | Use |
|---|---|
| Static HTML page, public URL | **Inline** (this protocol) |
| Page requires JavaScript rendering | `agent-browser` skill (rendered extraction) |
| Page behind authentication | User-provided content (skip retrieval) |
| Page returns non-HTML (PDF, JSON, etc) | `curl` + appropriate parser inline |
| Bulk crawl (10+ pages) | Loop the inline protocol, OR use crawl4ai if installed |

**Default**: use inline. Only fall back to external skill if inline fails (JS rendering needed, etc.).

### Why Inline Is Better Than crawl4ai Dependency

| Aspect | crawl4ai (external) | Inline (orsinil) |
|---|---|---|
| Dependency | Requires skill installed + Python package | None (curl + python3 stdlib) |
| Failure modes | Package not installed, API changes, async issues | curl fails (network), python3 fails (parsing) |
| Speed | AsyncWebCrawler startup overhead | curl ~1s + python3 ~0.1s |
| Control | External skill controls behavior | stellar-trails controls everything |
| Token cost | Loads crawl4ai SKILL.md (~2K tokens) into context | 0 tokens — protocol is in stellar-trails SKILL.md |
| Maintenance | Dependent on crawl4ai updates | Self-maintained, version-controlled with stellar-trails |

### Anti-patterns (FORBIDDEN)

- ❌ "I'll just invoke crawl4ai, it's easier" — no. User explicitly removed this reliance. Use inline protocol.
- ❌ "Let me fetch 20 pages to be thorough" — Scope Gate says `out_of_scope` unless user asked for bulk crawl. SADC needs 3-5 top URLs, not 20.
- ❌ "The inline extraction missed some content, let me use crawl4ai" — first try `agent-browser` (also installed) for JS rendering. Only escalate to crawl4ai as last resort.
- ❌ "I'll skip retrieval and just use my training knowledge" — SADC mandate exists for a reason. If retrieval fails, state explicitly "could not retrieve, using training knowledge" — do not silently skip.

### Integration with SADC

SADC section (Standard/Complex tier) now reads:
> BEFORE writing the problem specification, the **main agent** invokes `Skill(command="web-search")` to find existing solutions, then uses the **Inline Content Retrieval** protocol (above) to extract content from top 3-5 URLs → ≤500-word summary.

This removes the `Skill(command="crawl4ai")` dependency. web-search is still external (it's the search API, not extraction), but extraction is now inline.

### Worked Example

**Task**: "Build a PDF report — SADC required"

```bash
# 1. web-search returns 5 URLs (still external skill)
# 2. Inline retrieval for top 3 URLs:
for URL in "$URL1" "$URL2" "$URL3"; do
  OUTFILE="/tmp/st-retrieval-$(echo "$URL" | sha256sum | cut -c1-8).html"
  curl -sSL -m 10 -A "Mozilla/5.0 (compatible; StellarTrails/9.5)" "$URL" -o "$OUTFILE" 2>/dev/null
  # ... extract text via python3 (Step 2 above) ...
  # ... truncate to 500 words (Step 3 above) ...
done
# 3. Summarize: combine 3 truncated files into ≤500-word SADC summary
cat /tmp/st-retrieval-*.truncated | python3 -c "
import sys
text = sys.stdin.read()
words = text.split()[:500]
print(' '.join(words))
"
```

---

## GitHub Operations Protocol (NEW in v9.6.0 — adapted from @steipete/github)

**Inspiration**: Adapted from `@steipete/github` clawhub skill (v1.0.0, MIT-0 license) by @steipete. The original skill documents `gh` CLI patterns for PR checks, workflow runs, and API queries. **Not a wrapper** — adapted to stellar-trails' curl-based approach because `gh` CLI is not available in z.ai sandbox.

**Why adapt**: stellar-trails already uses GitHub API for CI polling (Steps 3, 4 in activation), release management (Pre-Push Local Verification), and tag pushing. Currently these are ad-hoc curl calls scattered across phases. Codifying them into a protocol makes GitHub operations consistent, reusable, and safer.

**License attribution**: Original @steipete/github skill is MIT-0 (no attribution required). Adapted patterns retained as orisinil curl-based implementation.

### Why curl + PAT instead of `gh` CLI

| Aspect | `gh` CLI (original skill) | curl + PAT (stellar-trails adaptation) |
|---|---|---|
| Availability | Not installed in z.ai sandbox | curl is sandbox-native |
| Auth | `gh auth login` (interactive browser flow) | PAT in `/home/z/my-project/upload/PAT` (already configured) |
| Token storage | gh's own credential store | File-based, user-controlled |
| Scriptability | Subprocess invocation | Native bash, no subprocess overhead |
| Portability | Requires gh install | Works anywhere curl exists |

### Prerequisites

Before using any GitHub Operations command:

1. **PAT must be present** at `/home/z/my-project/upload/PAT` (user-managed, persistent across sessions)
2. **Validate PAT** before first use:
   ```bash
   GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
   HTTP=$(curl -sS -m 10 -o /tmp/gh_user.json -w "%{http_code}" \
     -H "Authorization: Bearer $GH_TOKEN" https://api.github.com/user)
   [ "$HTTP" = "200" ] || { echo "✗ PAT invalid or expired (HTTP $HTTP)"; exit 1; }
   python3 -c "import json; d=json.load(open('/tmp/gh_user.json')); print(f'✓ Authenticated as: {d.get(\"login\")}')"
   ```
3. **Never print PAT to logs** — always use `tr -d '[:space:]'` to strip, never `echo $GH_TOKEN`

### Operation 1: PR CI Status Check

**Original (@steipete/github)**: `gh pr checks 55 --repo owner/repo`
**Adapted**: curl GitHub API for check runs on a PR's HEAD commit.

```bash
GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
REPO="owner/repo"
PR_NUMBER=55

# Get PR HEAD SHA
PR_JSON=$(curl -sS -m 10 -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER")
HEAD_SHA=$(echo "$PR_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('head',{}).get('sha',''))")
echo "PR #$PR_NUMBER HEAD: $HEAD_SHA"

# Get check runs for that SHA
curl -sS -m 10 -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/repos/$REPO/commits/$HEAD_SHA/check-runs" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for cr in d.get('check_runs', []):
    print(f\"  {cr.get('name')}: {cr.get('status')}/{cr.get('conclusion') or '-'}\")"
```

### Operation 2: List Recent Workflow Runs

**Original**: `gh run list --repo owner/repo --limit 10`
**Adapted**: curl GitHub Actions API.

```bash
GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
REPO="owner/repo"

curl -sS -m 10 -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/repos/$REPO/actions/runs?per_page=10" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"total_count: {d.get('total_count')}\")
for r in d.get('workflow_runs', [])[:10]:
    print(f\"  #{r.get('run_number')} | {r.get('name')} | {r.get('head_branch')} | {r.get('status')}/{r.get('conclusion') or '-'} | {r.get('created_at')}\")
    print(f\"    URL: {r.get('html_url')}\")"
```

### Operation 3: View Failed Step Logs

**Original**: `gh run view <run-id> --repo owner/repo --log-failed`
**Adapted**: curl jobs endpoint, identify failed steps, fetch logs (requires auth + logs API which needs Accept header).

```bash
GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
REPO="owner/repo"
RUN_ID="<run-id>"

# Get jobs in the run, find failed steps
curl -sS -m 10 -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/jobs" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for j in d.get('jobs', []):
    print(f\"JOB: {j.get('name')} - {j.get('conclusion')}\")
    for s in j.get('steps', []):
        if s.get('conclusion') == 'failure':
            print(f\"  FAILED STEP: {s.get('name')}\")
            print(f\"    started: {s.get('started_at')} | completed: {s.get('completed_at')}\")"

# Download full logs zip (authenticated endpoint)
curl -sS -L -m 60 -H "Authorization: Bearer $GH_TOKEN" \
  -o "/tmp/gh-logs-$RUN_ID.zip" \
  "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/logs"
echo "Logs saved to /tmp/gh-logs-$RUN_ID.zip"
unzip -o -q "/tmp/gh-logs-$RUN_ID.zip" -d "/tmp/gh-logs-$RUN_ID/"
# Find the failed step log file
find "/tmp/gh-logs-$RUN_ID/" -name "*Publish*" -o -name "*failed*" 2>/dev/null | head -5
```

### Operation 4: API Queries with jq-style Filtering

**Original**: `gh api repos/owner/repo/pulls/55 --jq '.title, .state, .user.login'`
**Adapted**: curl + python3 (jq may not be installed; python3 is always available).

```bash
GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
REPO="owner/repo"

# Get PR with specific fields (jq-style via python3)
curl -sS -m 10 -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/repos/$REPO/pulls/55" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"title: {d.get('title')}\")
print(f\"state: {d.get('state')}\")
print(f\"user: {d.get('user',{}).get('login')}\")"

# List issues with specific fields (original: --json number,title --jq '.[] | "\(.number): \(.title)"')
curl -sS -m 10 -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/repos/$REPO/issues?state=open&per_page=10" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for i in d:
    print(f\"{i.get('number')}: {i.get('title')}\")"
```

### Risk Mitigation Checklist (from @steipete/github skill-card.md)

Before running ANY GitHub operation, classify the action:

| Action class | Examples | Approval required? |
|---|---|---|
| **Read** | GET issues, PRs, runs, logs, check-runs | NO (safe) |
| **Write** | POST comments, create PRs, push tags/commits | YES (user explicit) |
| **Modify** | PATCH PRs, issues, repo settings | YES (user explicit) |
| **Delete** | DELETE branches, comments, releases | YES (user explicit + confirm) |
| **API mutation** | `gh api -X POST/PATCH/DELETE` equivalent | YES (user explicit) |

**Hard rule**: any non-GET request to GitHub API requires user explicit approval. State the exact mutation (URL + payload) before executing. Silent mutations are correctness bugs.

**Auth scope check** (run once per session, before first write op):
```bash
GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
curl -sSI -m 10 -H "Authorization: Bearer $GH_TOKEN" https://api.github.com/user \
  | grep -i "x-oauth-scopes:" | head -1
# Verify scopes include 'repo' for write operations, 'workflow' for workflow file changes
```

### Integration with stellar-trails phases

- **Pre-Push Local Verification (v9.2.0)**: uses Operation 1 (PR checks) + Operation 2 (run list) before push, Operation 3 (failed logs) if CI fails
- **Pivot (Recovery)**: when CI fails, use Operation 3 to fetch failed step logs → inform Pivot classification (bug vs wrong approach)
- **Proximate Cause Triage (v9.5.0)**: failed step logs are proximate evidence — apply Proximate Cause Test to the failure, don't rabbit-hole into unrelated logs
- **Step 3 activation**: uses `clawhub inspect` (not GitHub API) — different concern, do not conflate

### Anti-patterns (FORBIDDEN)

- ❌ "Let me just call gh CLI" — `gh` is not installed in sandbox. Use curl + PAT.
- ❌ "I'll print the PAT for debugging" — NEVER. Use `tr -d '[:space:]'` and never echo $GH_TOKEN.
- ❌ "Let me fetch all 1000 runs to be thorough" — Scope Gate says `out_of_scope`. 10 most recent is sufficient for diagnosis.
- ❌ "I'll do a POST to fix the issue" — write/modify/delete requires user explicit approval. State the mutation first.
- ❌ "Logs are too big, let me skip them" — failed step logs are critical evidence. Fetch + extract the relevant section, do not skip.

### Worked Example

**Scenario**: CI run #28982551045 failed at "Publish to ClawHub" step.

**Wrong (deep rabbit hole)**:
1. Re-run entire CI
2. Check clawhub.ai status page
3. Investigate npm registry
4. Inspect stellar-trails SKILL.md encoding
5. ... (10 levels, never finds root cause)

**Right (GitHub Operations Protocol + Proximate Cause Triage)**:
1. Use Operation 3 to fetch failed step logs:
   ```bash
   GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
   curl -sS -L -m 60 -H "Authorization: Bearer $GH_TOKEN" \
     -o /tmp/gh-logs.zip \
     "https://api.github.com/repos/hoshiyomiX/stellar-trails/actions/runs/28982551045/logs"
   unzip -o -q /tmp/gh-logs.zip -d /tmp/gh-logs/
   cat "/tmp/gh-logs/build-and-release/10_Publish to ClawHub.txt"
   ```
2. Apply Proximate Cause Triage:
   - Q1: Is "IndentationError" within 1 hop of "Publish failed"? YES (error in the bash block being run)
   - Q2: Does it explain all symptoms with ≤2 assumptions? YES (1 assumption: my new python3 -c code has wrong indentation)
   - Q3: Would fixing this resolve user's request? YES
   - → FIX NOW: rewrite python3 -c as one-liner, push new tag
3. **STOP**. Do not investigate clawhub.ai or npm registry — out_of_scope.

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

## Limitations

This framework is text in a skill file. It relies on the LLM reading it to follow instructions. The three enforcement layers (phase machine, mandatory prints, preferences dialog) shift enforcement from prose to verifiable artifacts, but the LLM is still the executor — a determined LLM can rationalize past any text-based rule. The QA Attestation is self-graded. The user is the final judge of quality.

Research (Lost in the Middle, arXiv 2307.03172) shows inherent ~70-85% compliance ceilings on SOTA models for complex multi-step prompts. The v9.0.0 enforcement layers raise the realistic ceiling to ~90% via text alone. Reaching ~98% requires a harness-level verifier script that scans the transcript for required prints/gates. 100% guaranteed compliance requires platform-level enforcement (ClawHub rejecting non-compliant invocations) — out of scope for skill authoring.
