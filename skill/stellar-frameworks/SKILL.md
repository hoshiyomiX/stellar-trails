---
name: stellar-frameworks
version: 5.3.0
description: "Deterministic coding workflow with phase state machine, traceability IDs, artifact templates, and structured verification."
---
<!-- VERSION SYNC: on bump, update (1) frontmatter above, (2) activation banner below, (3) boot.sh header, (4) setup.sh header -->

## Activation

```
☄️ STELLAR · v5.3.0 · ACTIVE
   Phase State Machine · Traceability IDs · Artifact Templates · SSV · Memory · Continuity
```

This framework structures coding work as a phase machine. It provides templates and traceability tools — use them when they help, abbreviate when they don't. The phases exist because skipping straight to code is how most bugs happen, not because every task needs a formal spec.

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
| SPECIFY | Restate problem, identify constraints and edge cases, list affected files |
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

This framework is not limited to coding tasks. The phase machine adapts to the task type:

| Task Type | SPECIFY | PLAN | IMPLEMENT | VERIFY |
|-----------|---------|------|------------|--------|
| **Coding** (web dev, bug fix, refactor) | Problem spec | Code steps + Traceability IDs | Write code | Lint, type check, tests |
| **Document** (report, proposal, DOCX, PDF) | Content outline | Section plan + structure | Generate document | Format check, completeness |
| **Visualization** (charts, diagrams, dashboards) | Visual requirements | Data mapping + layout | Generate chart | Visual accuracy, data integrity |
| **Data Processing** (ETL, analysis, transform) | Data spec | Transform pipeline | Write script | Output validation, edge cases |

For non-coding tasks: Traceability IDs still apply. Templates adapt — use the same structure but replace code-specific fields with task-appropriate ones.

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

After completing a task, output this block. Phases not applicable to the task are marked N/A.

```
☄️ PCR
├─ Tier         : Simple / Standard / Complex
├─ Continuation : NEW / YES (skipped SPECIFY and/or PLAN)
├─ SPECIFY      : PASS / N/A / SKIP
├─ PLAN         : PASS / N/A / SKIP
├─ IMPLEMENT    : PASS / N/A
├─ VERIFY       : PASS / N/A
└─ OUTCOME      : PASS / FAIL

Evidence: [concrete results — e.g. "lint 0 errors, 4/4 traceability verified"]
Defects found and fixed: [n]
```

Self-graded. The evidence requirement and defect counter make fabrication harder but cannot guarantee independence. A claim of 0 defects means first-attempt correctness. If OUTCOME is FAIL, do not deliver — return to the appropriate phase.

## Completion Signal

For web development tasks (Type 3), the DELIVER phase must call the platform's `Complete(project_type="web_dev", summary="...")` tool to finalize the project. For non-coding tasks, DELIVER presents the output file path directly.
