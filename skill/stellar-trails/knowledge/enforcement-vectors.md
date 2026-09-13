# Enforcement Vectors E7-E11 Detail (moved from SKILL.md v9.16.0)

Detailed descriptions of sandbox-native enforcement vectors.
SKILL.md keeps only the summary matrix table.

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

