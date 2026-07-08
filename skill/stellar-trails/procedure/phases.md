# Workflow Phases

Each phase produces a concrete artifact that the next phase consumes. Skipping a phase means the next phase has no input to work from — the gap becomes visible and correctable.

## State Diagram

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
```

On error: stop, assess (code bug or approach failure?), fix or pivot, return to VERIFY.

---

## Phase Markers (E1 Enforcement)

Every phase entry requires a phase-marker print before any other phase work. Every phase exit requires the corresponding exit marker.

| Phase | Entry Marker | Exit Marker |
|-------|--------------|-------------|
| IDLE | `📍 ENTER IDLE` | `📍 EXIT IDLE → SPECIFY` |
| SPECIFY | `📍 ENTER SPECIFY` | `📍 EXIT SPECIFY → PLAN` (or `→ IMPLEMENT` if continuation) |
| PLAN | `📍 ENTER PLAN` | `📍 EXIT PLAN → IMPLEMENT` |
| IMPLEMENT | `📍 ENTER IMPLEMENT` | `📍 EXIT IMPLEMENT → VERIFY` |
| VERIFY | `📍 ENTER VERIFY` | `📍 EXIT VERIFY → DELIVER` |
| DELIVER | `📍 ENTER DELIVER` | `📍 EXIT DELIVER → IDLE` |

Missing markers = compliance bug. The DELIVER report's `Phase Trace` field lists every marker pair as evidence.

---

## Gate Protocol

Phase transitions are guarded. A phase cannot begin until its entry condition is met.

| Gate | Condition | Action if not met |
|------|-----------|-------------------|
| SPECIFY → PLAN | All problem-spec fields filled, SADC complete, AskUserQuestion ran (or skipped with reason) | Complete missing fields before proceeding |
| PLAN → IMPLEMENT | Implementation plan complete + Scope output (Standard/Complex) + `⏸️ AWAITING APPROVAL TO ENTER IMPLEMENT` printed | Present plan + Scope to user, wait for approval |
| IMPLEMENT → VERIFY | Self-review checklist pass, all IMPL steps done, pre-output checklist printed | Fix issues before transitioning |
| VERIFY → DELIVER | All verification items PASS | Return to IMPLEMENT (or SPECIFY if spec gap) |

**Simple tier**: Gates run internally — agent validates conditions but doesn't produce formal gate output.
**Standard/Complex tier**: PLAN → IMPLEMENT gate produces a Scope (see SKILL.md Deliveries). The delivery report's Scope Drift field tracks deviations.

---

## Phase 1: IDLE

**Purpose**: Receive the user's request, classify complexity and task type.

**Entry marker**: Print `📍 ENTER IDLE` first.

**Actions**:
1. Receive and acknowledge the request.
2. **Session continuity check** — NEW task or CONTINUATION? Check sources in order:
   a. **Worklog** (`/home/z/my-project/worklog.md`) — read last `---` block. If task description matches current request, resume from `last_phase`.
   b. **Preceding assistant message** — if user's reply references/approves/corrects/follows up, it's a continuation.

   | Continuation signal | Action |
   |---------------------|--------|
   | User references previous output ("apply all 10", "fix point 3", "proceed") | Skip SPECIFY+PLAN, go to IMPLEMENT |
   | User approves a proposal/plan ("yes", "go ahead", "do it") | Skip SPECIFY+PLAN, go to IMPLEMENT |
   | User asks a follow-up question ("what about X?") | Skip SPECIFY, answer in current phase context |
   | User provides new requirements mid-task | Restart from SPECIFY |
   | Context compression boundary with ongoing task | Read worklog.md, resume from last recorded phase |
   | Completely new topic, explicit new instructions, or `Skill()` invoked | Full workflow (continue below) |

   **Critical**: If continuation detected, do NOT re-derive proposals/plans/specifications the user has already seen. Regenerating from scratch is a correctness bug.

3. Classify complexity:
   - **Minimal**: Knowledge question, explanation, recommendation — no code/file output
   - **Simple**: Single file, no schema change, no new dependencies
   - **Standard**: Multiple files or a schema change
   - **Complex**: Architectural changes, multi-service, high risk

4. Classify task type:
   - **Coding**: Web dev, bug fix, refactor, new feature
   - **Document**: Report, proposal, DOCX, PDF, XLSX, PPT
   - **Visualization**: Charts, diagrams, mind maps, dashboards
   - **Data Processing**: ETL, analysis, transform, Python scripts
   - **Non-Coding**: Questions, explanations, recommendations

5. **Memory system initialization (bash gate)** — run before transitioning:
   ```bash
   mkdir -p /home/z/my-project/memory && ([ -f /home/z/my-project/memory/MEMORY.md ] || touch /home/z/my-project/memory/MEMORY.md) && echo "✓ Memory: $(wc -c < /home/z/my-project/memory/MEMORY.md)/3000 chars"
   ```
   This enforces the memory system exists before any phase produces work. The character count check ensures MEMORY.md budget is visible at every IDLE entry.

6. Check `memory/MEMORY.md` for user preferences and key decisions. For context-truncation recovery, worklog (step 2a) takes priority over memory files.

7. If task involves git repository and session was continued from previous conversation (context compression boundary), flag repo as "state-uncertain" and require Source State Verification in SPECIFY.

8. Print `📍 EXIT IDLE → SPECIFY` (or `→ IMPLEMENT`/`→ VERIFY` if continuation detected).

**Artifacts**: None. IDLE is a routing phase.

---

## Phase 2: SPECIFY

**Purpose**: Produce a precise problem specification grounded in real sources, not assumptions.

**Entry marker**: Print `📍 ENTER SPECIFY` first.

**Actions**:
1. **Source Availability & Documentation Check (SADC)** — before anything else:
   - **Minimal tier**: Skip SADC entirely.
   - **Simple tier**: Quick inline check against at least one source.
   - **Standard/Complex tier**: Print `📡 SADC subagent dispatched (Task ID SADC-XXX)` BEFORE writing any problem-spec text. Launch `Task(subagent_type:'general-purpose')` to research existing solutions via `web-search` skill + `crawl4ai`/`web-reader` extraction. Subagent returns ≤500-word summary. The PLAN → IMPLEMENT gate REQUIRES a Task() call in transcript for Standard/Complex tasks.
   - Record all sources checked. If no existing solution found, state explicitly.

2. **AskUserQuestion Gate (E3 Enforcement)** — for deliverable-creation tasks (Document, Visualization, PPT, PDF, Excel, dashboard, poster, script, chart-as-deliverable):
   - Print `✓ Preferences dialog check: <INVOKED | SKIPPED: <reason>>` before any content-producing tool call
   - If task type is Document/Visualization AND user's request does NOT explicitly pin audience + style + length → invoke `AskUserQuestion` with 6–8 questions
   - Skip conditions: user says skip / all 3 dimensions explicit / trivial edit / continuation

3. Restate the request in precise technical terms — informed by sources from step 1.

4. Identify functional requirements.

5. Identify technical constraints. Read `knowledge/architecture.md` for general constraints and `knowledge/zai-sandbox.md` for sandbox-specific rules. Print `✓ Read: knowledge/architecture.md` and `✓ Read: knowledge/zai-sandbox.md`.

6. Enumerate edge cases with handling strategies.

7. List all files to be created or modified with action type (create/modify).

8. Assess risk level (LOW/MEDIUM/HIGH) with justification.

9. Identify dependencies — include required skills if multi-skill orchestration needed.

10. If git repository, perform Source State Verification and record verified state.

11. Fill out the problem specification template (inline in SKILL.md `<template name="problem-spec">`) and present to user.

**Artifact**: Problem Specification (inline template from SKILL.md).

**Exit criteria**: All fields filled. User reviewed and confirmed. SADC complete. AskUserQuestion ran or skipped with reason.

**Exit marker**: Print `📍 EXIT SPECIFY → PLAN` (or `→ IMPLEMENT` if continuation).

---

## Phase 3: PLAN

**Purpose**: Design implementation strategy with traceable steps and a fallback approach.

**Entry marker**: Print `📍 ENTER PLAN` first.

**Actions**:
1. Review the problem specification — confirm all requirements accounted for.
2. Choose a solution approach (2-3 sentences).
3. **Define fallback approach** — alternative if primary fails. If no fallback exists: "No viable fallback — would require user input."
4. Break implementation into ordered steps. Each step gets a Traceability ID (IMPL-001, IMPL-002, etc.).
5. Define verification strategy — what to check, how, expected outcome.
6. Read `knowledge/conventions.md` for coding conventions. Print `✓ Read: knowledge/conventions.md`.
7. **Skill Chain** (if applicable): Identify skills needed and invocation order. Assign skill-level Traceability IDs (SKILL-001, SKILL-002, ...).
8. **TodoWrite Sync** — if TodoWrite tool available, sync IMPL-XXX to TodoWrite items with pending → in_progress → completed transitions. If unavailable, print `✓ TodoWrite unavailable — skipping sync`.
9. Fill out the implementation plan template (inline in SKILL.md `<template name="implementation-plan">`) and present.
10. **Output Scope** (Standard/Complex only) — after plan, output the `☄️ COMMIT [Standard]` block from SKILL.md Deliveries. Then print `⏸️ AWAITING APPROVAL TO ENTER IMPLEMENT`. Do NOT call any tool after this line.

**Artifact**: Implementation Plan (inline template from SKILL.md) + Scope (Standard/Complex).

**Exit criteria**: Every requirement maps to ≥1 step. Every step has Traceability ID. Verification strategy covers all edge cases. Fallback defined. Scope output (Standard/Complex). AWAITING APPROVAL printed.

**Exit marker**: Print `📍 EXIT PLAN → IMPLEMENT` (only after user approval).

---

## Phase 4: IMPLEMENT

**Purpose**: Execute the plan step by step.

**Entry marker**: Print `📍 ENTER IMPLEMENT` first.

**Actions**:
1. For each implementation step:
   a. Reference the Traceability ID in a comment or context note.
   b. Execute the step (write code, generate document, invoke skill, run script).
   c. Follow constraints from `constraints/code-standards.md` and `constraints/type-safety.md` (coding tasks). Print `✓ Read: constraints/code-standards.md` and `✓ Read: constraints/type-safety.md` at first coding step.
   d. If new dependency needed, install it before writing code that uses it.
   e. Update TodoWrite item status if syncing (pending → in_progress → completed).
   f. **Track deviations** — if implementation diverges from plan, note deviation + justification for report Deviations field.
2. If plan includes a Skill Chain, execute each skill invocation in order, passing intermediate artifacts between skills.
3. Self-review using the Review Checklist in the verification report template.
4. **Pre-output checklist (E2 Enforcement)** — print before transitioning:
   ```
   ✓ Pre-VERIFY checklist: template_headers=✓ files_read=✓ traceability_in_code=✓ deviations_tracked=✓
   ```
5. Fix issues found during self-review before transitioning.

**Artifacts**: The output (code, document, chart, script). Inline traceability references.

**Exit criteria**: All steps completed. Self-review passes. Pre-output checklist printed.

**Exit marker**: Print `📍 EXIT IMPLEMENT → VERIFY`.

---

## Phase 5: VERIFY

**Purpose**: Confirm implementation satisfies all requirements — including pre-deployment verification for external targets.

**Entry marker**: Print `📍 ENTER VERIFY` first.

**Actions**:
1. Run automated checks appropriate to task type:
   - Coding: lint, type check, existing tests
   - Document: format validation, content completeness check
   - Visualization: visual accuracy review, data integrity check
   - Data Processing: output validation, edge case testing
2. **Pre-Deployment Verification** — if task targets an external system (Android, remote server, cloud, production), run local verification step exercising same code path BEFORE declaring VERIFY complete. If Scope's Pre-Deploy field is "N/A", skip.
3. If analyzing existing code from git repository, verify analyzed files matched remote state at time of analysis. If discrepancy, return to SPECIFY.
4. Traceability verification — confirm every Traceability ID has corresponding implementation.
5. Edge case verification — test input, expected behavior, actual behavior for each edge case from spec.
6. Fill out the verification report template (inline in SKILL.md `<template name="verification-report">`).

**Artifact**: Verification Report (inline template from SKILL.md).

**Exit criteria**: All checks pass (or failures documented). Every Traceability ID verified. Every edge case confirmed. Pre-Deploy passed (if applicable).

**Exit marker**: Print `📍 EXIT VERIFY → DELIVER`.

---

## Phase 6: DELIVER

**Purpose**: Present completed work with summary and compliance report.

**Entry marker**: Print `📍 ENTER DELIVER` first.

**Actions**:
0. **Pre-DELIVER print check (E2 Enforcement)** — print first, before any other DELIVER work:
   ```
   ✓ Pre-DELIVER print check: banner=✓ commit=✓/N/A report=✓
   ```
   If any mandatory print was missed, go back and emit it before proceeding.

1. **Append Snapshot to worklog** — append to `/home/z/my-project/worklog.md`:
   ```
   ---
   last_phase: DELIVER
   task: <one-line description>
   complexity: <tier>
   task_type: <type>
   files_modified: <list or "none">
   phase_trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
   next_step: <next action or "IDLE - awaiting input">
   ```
   For Standard/Complex, also include: `traceability: IMPL-XXX completed`, `pivot: NONE or brief`, `scope_drift: NONE or brief`.

2. **Write session digest** to `memory/YYYY-MM-DD.md` (file created by IDLE bash gate). Append, don't overwrite:
   - Compact (Simple/Minimal): `[HH:MM] task: <desc> | outcome: PASS/FAIL | files: <count> | incidents: <count>`
   - Rich (Standard/Complex): `[HH:MM] task: <desc> | outcome: PASS/FAIL | files: <count> | incidents: <count>` + `decisions: <key decision>` + `context: <what informed approach>` + `caveats: <things to watch>`

3. **Check MEMORY.md budget** — if `memory/MEMORY.md` exceeds ~3000 chars, note in delivery. Print `✓ Memory budget: $(wc -c < /home/z/my-project/memory/MEMORY.md)/3000 chars`.

4. Summarize what was implemented, referencing Traceability IDs.

5. List files created or modified.

6. Note any dependencies added.

7. Present verification report summary.

8. State caveats or follow-up items.

9. Output **Delivery** — use compact format for Simple tasks, full format for Standard/Complex (see SKILL.md Deliveries). Include Scope Drift + Pivot fields.

10. **Completion signal**: For web development tasks (Coding), call `Complete(project_type="web_dev", summary="...")`. For non-coding tasks, present output file path directly.

**Exit marker**: Print `📍 EXIT DELIVER → IDLE`.

---

## Error Handling

### Pivot

Before attempting any fix, classify the error:

| Signal | Classification | Recovery Path |
|--------|---------------|---------------|
| Fix requires rewriting 50%+ of implementation | Wrong Approach | Re-enter PLAN with fallback |
| Same error recurs after 2 fix attempts | Wrong Approach | Stop fixing, re-evaluate approach |
| Fix requires changing data model / API contract | Wrong Approach | Re-enter PLAN |
| Required library/framework feature doesn't exist | Wrong Approach | Pivot to Scope fallback or new approach |
| Typo, wrong variable, missing null check | Bug | Fix → VERIFY |
| Type mismatch, import error, lint violation | Bug | Fix → VERIFY |

**Pivot flow**: Error → classify → if Wrong Approach: evaluate alternatives (Scope fallback first), present pivot to user via AskUserQuestion (E3 enforcement), re-enter PLAN with new approach, re-implement, re-verify. Record in Pivot field of delivery report.

### Incident Protocol

1. Stop work on current phase.
2. Classify: code bug or approach failure (see table above).
3. Complete incident report template (inline in SKILL.md `<template name="incident-report">`).
4. Follow error resolution decision tree (`procedure/error-resolution.md`).
5. Decision tree determines return phase — default VERIFY, but approach failures return to PLAN, specification gaps return to SPECIFY.
6. **Log incident** to `memory/incidents.md` (append, one line):
   ```
   [YYYY-MM-DD] error: <type> | cause: <one-line root cause> | fix: <one-line fix>
   ```

---

## Quick Reference: Return Phase Decision

| Error During | Root Cause Is | Classification | Return To |
|-------------|---------------|---------------|----------|
| SPECIFY | Incomplete requirements | — | SPECIFY (update spec) |
| PLAN | Specification gap or wrong approach | — | SPECIFY or PLAN |
| IMPLEMENT | Code defect | Bug | VERIFY (re-verify after fix) |
| IMPLEMENT | Fundamental design wrong | Wrong Approach | PLAN (pivot with new approach) |
| IMPLEMENT | Specification gap | Wrong Approach | SPECIFY (update spec, re-plan) |
| VERIFY | Code defect not caught | Bug | IMPLEMENT (fix, then VERIFY) |
| VERIFY | Specification gap | Wrong Approach | SPECIFY (update spec, re-plan, re-implement) |

When uncertain, return to SPECIFY. It is safer to re-confirm requirements than to fix code against a misunderstood specification.
