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

- **version**: 9.2.2

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

## Activation

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

### Activation Steps

**Step 1 — Refresh context + SSV**: Re-read `/home/z/my-project/skills/stellar-trails/SKILL.md` from disk using the Read tool. Do not trust cached context — the on-disk version is source of truth. If task involves a git repo, run SSV:

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
```

**Step 2 — Start popup server + verify mascot**:

```bash
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

**Step 3 — Auto-update via ClawHub**:

```bash
CURRENT=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | head -1)
# Use --json for robust parsing. The previous text-output regex
# `^Latest:\s*\K[0-9.]+` never matched the real output format
# `│ Latest   X.Y.Z` (no colon, box-drawing prefix, multiple spaces).
# Single-line python3 -c to avoid IndentationError from bash quote preservation.
LATEST=$(clawhub inspect stellar-trails --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" 2>/dev/null || echo "")
if [ -z "$CURRENT" ]; then echo "✗ Step 3 FAILED: could not read current version from SKILL.md"
elif [ -z "$LATEST" ]; then echo "✗ Step 3 FAILED: could not reach ClawHub registry (network down?)"
elif [ "$CURRENT" = "$LATEST" ]; then echo "✓ Step 3: up to date (v$CURRENT)"
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

**Step 4 — Verify files + force-override .zscripts/ + restart dev.sh + sync zip**:

```bash
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

**Step 5 — Load phases + classify**: Read `procedure/phases.md` now. Then determine complexity tier (Minimal/Simple/Standard/Complex), task type (Coding/Document/Visualization/Data Processing/Non-Coding), and continuity (NEW or YES — see Session Continuity below).

Print: `✓ Step 5: phases loaded + classified: [tier]/[type]/[NEW|YES]`

After Step 5: Begin SPECIFY (or IMPLEMENT if continuation detected).

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
| **Standard** | **Main agent inline research** — invoke `Skill(command="web-search")` then `Skill(command="crawl4ai")` or `web-reader` BEFORE writing problem-spec. Print `📡 SADC: main agent researching inline` |
| **Complex** | Deep research by main agent — multiple sources, compare approaches, document tradeoffs |

**Main agent mandate (Standard/Complex)**: BEFORE writing the problem specification, the **main agent** (not a subagent) invokes `Skill(command="web-search")` to find existing solutions, then `Skill(command="crawl4ai")` (preferred) or `Skill(command="web-reader")` to extract content from top URLs → ≤500-word summary.

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

## Pre-Push Local Verification (NEW in v9.2.0)

**Problem this solves**: Pushing code changes to CI without local verification wastes a CI cycle (~1-2 minutes per run) and creates a "push → fail → read logs → push again" loop. This happened during this skill's development:

- v9.0.1 push → CI failed (python3 IndentationError) → read logs → v9.0.2 push → CI succeeded
- The IndentationError would have been caught by running the bash block locally before pushing.

**Rule**: Before pushing any change that triggers CI (especially workflow file changes or SKILL.md bash block changes), run the new code locally in the sandbox.

### Verification checklist

1. **SKILL.md bash block changes** — copy the new bash block to a temp script, execute it, verify the output matches expectations:
   ```bash
   # Extract the bash block from SKILL.md and run it
   awk '/^```bash$/,/^```$/' skill/stellar-trails/SKILL.md | \
     sed '1d;$d' > /tmp/test-skill-bash.sh
   bash /tmp/test-skill-bash.sh
   ```

2. **Workflow file changes** (`.github/workflows/*.yml`) — simulate the bash locally:
   - For `clawhub skill publish` calls: run `clawhub skill publish --dry-run` first
   - For `python3 -c` blocks: run them with mock inputs (`echo '{}' | python3 -c '...'`)
   - For YAML structure: `python3 -c "import yaml; yaml.safe_load(open('release.yml'))"`

3. **Code changes that import new modules** — verify imports work locally:
   ```bash
   python3 -c "import <module>" || echo "MISSING: <module>"
   ```

4. **Schema/migration changes** — dry-run on local copy before pushing.

### When to skip Pre-Push Local Verification

- Documentation-only changes (CHANGELOG.md, README.md)
- Version bump commits (just `sed` + commit)
- Changes to files that have no executable code (pure markdown prose)

### Cost-benefit

- **Cost**: 30-60 seconds of local testing
- **Benefit**: saves 1-2 minutes of CI cycle time per caught bug, plus the cognitive cost of context-switching back to fix the bug
- **Break-even**: catches 1 bug per ~10 pushes → worth it for any non-trivial change

### Worked example

Before pushing v9.0.2 (the IndentationError fix), the agent should have run:

```bash
# Test the new python3 -c block locally with 3 input cases
echo '{"latestVersion":{"version":"9.0.2"}}' | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')"
# Expected: 9.0.2

echo '{}' | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')"
# Expected: (empty string)

echo "Skill not found" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" 2>/dev/null || echo ""
# Expected: (empty string, with the || echo "" fallback)
```

If all 3 cases pass, push. If any fails, fix before pushing.

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
