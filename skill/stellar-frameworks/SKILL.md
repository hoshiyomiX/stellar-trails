---
name: stellar-frameworks
version: 5.4.8
description: "Core workflow — runs ALL tasks through a phase machine (SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER) without exception. Coding tasks: full phases with Traceability IDs and verification. Non-coding tasks (questions, explanations, recommendations): Minimal tier — all phases run internally, only IMPLEMENT produces output. Every task gets a Process Compliance Report. Covers building features, fixing bugs, refactoring, writing scripts, debugging, generating code, answering questions, explaining concepts, and providing recommendations. The phase machine always activates — complexity adapts, participation never skips."
---
<!-- VERSION SYNC: on bump, update (1) frontmatter above, (2) activation banner below, (3) boot.sh header, (4) setup.sh header, (5) README.md badge + invoke line + version history, (6) CHANGELOG.md -->

## Activation

```
☄️ STELLAR · v5.4.8 · ACTIVE
   Phase State Machine · Traceability IDs · Artifact Templates · SSV · SADC · Memory · Continuity · Universal
```

This framework structures ALL work as a phase machine. It activates for every task — coding or not — without exception. What changes between tasks is the complexity tier, not whether the framework participates. Coding tasks get full phases with Traceability IDs and formal verification. Non-coding tasks (questions, explanations, recommendations) get Minimal tier — all phases still run, but SPECIFY, PLAN, and VERIFY happen internally (the agent thinks through them without outputting formal artifacts). Only IMPLEMENT produces visible work. Every task, regardless of type, gets a Process Compliance Report recording that the framework was followed.

## Limitations

This framework is text in a skill file. It cannot guarantee compliance, force behavior, or persist across sessions. The LLM reading this may follow it closely, loosely, or not at all depending on context, attention, and task complexity. The QA Attestation is self-graded — useful as a confidence signal, not independent verification. The user is the final judge of quality.

## Phase State Machine

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Error Recovery ◄───────────────────┘
```

On error: stop, diagnose, fix, return to VERIFY.

| Phase | Purpose |
|-------|---------|
| IDLE | Receive task, classify complexity |
| SPECIFY | Research sources, restate problem, identify constraints |
| PLAN | Create implementation steps with Traceability IDs |
| IMPLEMENT | Write code, reference Traceability IDs |
| VERIFY | Run checks, trace edge cases, confirm Traceability IDs satisfied |
| DELIVER | Present results with attestation |

Phase definitions, entry/exit criteria, and transition rules are in `procedure/phases.md`.

## Session Continuity

The most common failure mode in multi-turn sessions: the LLM re-derives a proposal or plan from scratch instead of continuing from the previous output. This wastes context, introduces inconsistencies, and frustrates users.

**Rule**: Before entering any phase, check if the user's message is a continuation of previous work. To detect this, read the immediately preceding assistant message — if the user's reply references, approves, corrects, or follows up on that output, it is a continuation.

| Signal | Type | Action |
|--------|------|--------|
| User references previous output ("apply all 10", "fix point 3", "proceed") | Continuation | Skip SPECIFY+PLAN → go directly to IMPLEMENT |
| User approves a proposal/plan ("yes", "go ahead", "do it") | Continuation | Skip SPECIFY+PLAN → go directly to IMPLEMENT |
| User asks a follow-up question ("what about X?") | Continuation | Skip SPECIFY → answer within current phase context |
| User provides new requirements mid-task | New task | Restart from SPECIFY with updated requirements |
| User invokes Skill() with new instructions | New task | Full phase machine from IDLE |
| Context compression boundary with ongoing task | Continuation | Check memory for last task state, resume from last active phase |

**Continuation shortcuts**:

```
Continuation + user approves plan  → skip SPECIFY + PLAN → IMPLEMENT
Continuation + user asks follow-up → skip SPECIFY → answer in current phase
Continuation + user reports error  → skip SPECIFY + PLAN → Error Recovery → VERIFY
```

This is not optional — regenerating proposals the user already approved is a correctness bug, not a style preference.

## Task Type Awareness

This framework is not limited to coding tasks. The phase machine adapts to the task type. All phases always run — what changes is what each phase produces and how much ceremony surrounds it:

| Task Type | SPECIFY | PLAN | IMPLEMENT | VERIFY |
|-----------|---------|------|------------|--------|
| **Coding** (web dev, bug fix, refactor) | Problem spec | Code steps + Traceability IDs | Write code | Lint, type check, tests |
| **Document** (report, proposal, DOCX, PDF) | Content outline | Section plan + structure | Generate document | Format check, completeness |
| **Visualization** (charts, diagrams, dashboards) | Visual requirements | Data mapping + layout | Generate chart | Visual accuracy, data integrity |
| **Data Processing** (ETL, analysis, transform) | Data spec | Transform pipeline | Write script | Output validation |
| **Non-Coding** (question, explain, recommend) | Internal (identify question) | Internal (plan approach) | Answer / explain / recommend | Internal (self-check) |

No phases are ever skipped. Non-coding tasks use **Minimal** complexity tier — SPECIFY, PLAN, and VERIFY run internally (the agent thinks through them without producing formal artifacts). IMPLEMENT does the visible work. DELIVER outputs a compact PCR. No Traceability IDs, no templates. See Complexity Tiers in `procedure/phases.md`.

## Phase References

| Phase | Artifact Template | Knowledge Files |
|-------|-------------------|-----------------|
| SPECIFY | `procedure/templates/problem-spec.md` | `knowledge/universal/architecture.md`, `knowledge/platform/zai-sandbox.md` |
| PLAN | `procedure/templates/implementation-plan.md` | `knowledge/universal/conventions.md` |
| IMPLEMENT | (code/document/chart output) | `constraints/code-standards.md`, `constraints/type-safety.md` |
| VERIFY | `procedure/templates/verification-report.md` | `knowledge/universal/error-patterns.md` |
| Error Recovery | `procedure/templates/incident-report.md` | `procedure/decision-trees/error-resolution.md` |

## Source State Verification (SSV)

Before analyzing or auditing a git repository, verify data freshness:

1. `git fetch` to sync remote references
2. Compare local HEAD against `origin/<branch>`
3. If behind, `git pull` or `git checkout <branch>` after fetch
4. If referencing a specific commit, verify it exists in history
5. Only proceed after SSV passes

SSV is required after cross-session boundaries or when previous sessions involved git operations. Skip SSV for purely creative tasks with no git involvement.

## Source Availability & Documentation Check (SADC)

Before planning any implementation, verify that the approach is grounded in real sources — not assumptions. The most expensive refactor is the one caused by building something that already existed or using an API incorrectly because the docs weren't checked first.

**Rule**: In the SPECIFY phase, before restating the problem, the agent must research available solutions and official documentation.

1. **Existing solutions** — Are there packages, libraries, frameworks, or SDK methods that already solve this? Search before building.
2. **Official documentation** — What does the official doc say about the recommended approach? Read it, don't guess.
3. **Known patterns** — Are there established patterns, best practices, or examples for this type of task?

| Complexity | SADC Requirement |
|-----------|-------------------|
| **Minimal** | Skip — knowledge questions don't need source research. |
| **Simple** | Quick check — verify the approach against at least one source (docs, search, or existing code). |
| **Standard** | Full research — search for existing solutions, read official docs, confirm no wheel reinvention. |
| **Complex** | Deep research — multiple sources, compare approaches, document tradeoffs, present alternatives. |

SADC is the first action in SPECIFY. The problem specification must reference the sources checked. If no existing solution is found, state that explicitly — "searched npm/PyPI/docs, no existing package found" is a valid result. Building from scratch when a library exists is a spec-level defect.

## Error Recovery

1. **Stop** — do not continue past errors
2. Document the error (incident report template)
3. Ask the user before any action with side effects (git changes, file deletions, destructive operations)
4. Fix root cause, not symptom
5. Return to VERIFY and re-verify

Git rules (overrides defaults):
- `git fetch` and inspect before `git pull` — if remote diverged, stop and ask
- No `git rebase`, `git reset`, `git push --force`, or `git merge` without explicit user instruction
- If git is blocked by infrastructure, stop all git operations and inform the user

Full decision tree: `procedure/decision-trees/error-resolution.md`.

## Process Compliance Report

After completing a task, output a PCR block. The format depends on task type.

### Compact PCR (Simple)

Used by Simple-tier tasks (single file, no schema change, no new dependencies). Replaces the full block with a one-liner.

```
☄️ PCR [Simple]
SPECIFY→DELIVER : PASS | Evidence: <one-line result> | Defects: 0
```

### Full PCR (Standard / Complex)

Used by Standard and Complex-tier tasks (multiple files, schema changes, or architectural impact).

```
☄️ PCR
├─ Tier         : Standard / Complex
├─ Continuation : NEW / YES (skipped SPECIFY and/or PLAN)
├─ SPECIFY      : PASS / N/A / SKIP (continuation only)
├─ PLAN         : PASS / N/A / SKIP (continuation only)
├─ IMPLEMENT    : PASS / N/A
├─ VERIFY       : PASS / N/A
└─ OUTCOME      : PASS / FAIL

Evidence: [concrete results — e.g. "lint 0 errors, 4/4 traceability verified"]
Defects found and fixed: [n]
```

### Minimal PCR (non-coding: questions, explanations, recommendations)

```
☄️ PCR [Minimal] Phases→internal : PASS | Evidence: <one-line result>
```

All phases ran internally — SPECIFY, PLAN, and VERIFY produced no formal output. Only IMPLEMENT generated visible work. Single-line format.

Self-graded. The evidence requirement makes fabrication harder but cannot guarantee independence.

## Completion Signal

For web development tasks (Type 3), the DELIVER phase must call the platform's `Complete(project_type="web_dev", summary="...")` tool to finalize the project. For non-coding tasks, DELIVER presents the output file path directly.
