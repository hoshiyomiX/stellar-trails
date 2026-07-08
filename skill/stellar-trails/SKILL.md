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

- **version**: 9.0.2

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

```
☄️ STELLAR TRAILS · v9.0.0 · ACTIVE
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
git fetch origin --quiet 2>/dev/null
BEHIND=$(git rev-list --count HEAD..origin/$(git branch --show-current 2>/dev/null || echo main) 2>/dev/null)
if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then echo "✗ Step 1 FAILED: local is $BEHIND commits behind origin — run git pull first"
else echo "✓ Step 1: context refreshed + SSV passed (v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null || echo unknown))"; fi
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

**Step 3 — Auto-update via ClawHub**:

```bash
CURRENT=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' /home/z/my-project/skills/stellar-trails/SKILL.md 2>/dev/null | head -1)
LATEST=$(clawhub inspect stellar-trails 2>/dev/null | grep -oP '^Latest:\s*\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$CURRENT" ]; then echo "✗ Step 3 FAILED: could not read current version from SKILL.md"
elif [ -z "$LATEST" ]; then echo "✗ Step 3 FAILED: could not reach ClawHub registry (network down?)"
elif [ "$CURRENT" = "$LATEST" ]; then echo "✓ Step 3: up to date (v$CURRENT)"
else clawhub --no-input update stellar-trails --force 2>/dev/null && echo "✓ Step 3: updated v$CURRENT → v$LATEST" || echo "✗ Step 3 FAILED: clawhub update error"; fi
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
| **Standard** | Subagent delegation — launch `Task(subagent_type:'general-purpose')` BEFORE writing problem-spec. Print `📡 SADC subagent dispatched (Task ID SADC-XXX)` |
| **Complex** | Deep research via subagent — multiple sources, compare approaches, document tradeoffs |

**Subagent mandate (Standard/Complex)**: Launch the SADC subagent BEFORE writing the problem specification. The subagent invokes `Skill(command="web-search")` to find existing solutions, then `Skill(command="crawl4ai")` (preferred) or `Skill(command="web-reader")` to extract content from top URLs → returns ≤500-word summary.

If no existing solution is found, state it explicitly — "searched npm/PyPI/docs, no existing package found" is a valid result. Building from scratch when a library exists is a spec-level defect.

Full subagent delegation template: read `references/sadc-subagent-delegation.md` when launching.

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
