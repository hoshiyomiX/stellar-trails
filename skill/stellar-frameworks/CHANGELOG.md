# Changelog

## [5.4.3] — 2026-05-15

### Fixed

- **Critical: Race condition in .bashrc auto-heal hook** — The .bashrc hook used `&` (background/async) and ran `--install-only` which still performed git fetch/pull (~5-10s network delay). The platform sources `.bashrc` then immediately scans `skills/` for available skills. If the hook hadn't finished copying files by the time the scan ran, the skill was invisible for the entire session. Fixed with two changes: (1) New `--fast` flag skips ALL git operations, reducing hook execution from ~5-10s to ~0.1s (pure local file copy). (2) Removed `&` from hook command — hook now runs synchronously so the platform always sees the restored files before scanning.
- **Stale .bashrc hook cleanup** — boot.sh now removes old async hooks (v5.4.2 with trailing `&`) and stale hooks from wrong path (`$PROJECT_ROOT/.bashrc`, v5.4.1 bug). Both boot.sh and setup.sh rewrite the hook on every run to ensure it's always the latest version.

### Added

- **Mid-session activation** — `activate.sh` script reads SKILL.md directly and outputs its content. Since `Skill()` caches `available_skills` at session start (platform limitation), skills installed mid-session can't be invoked via `Skill()`. However, `Read(path="skills/stellar-frameworks/SKILL.md")` accesses the exact same file and produces identical content. The post-install message in both boot.sh and setup.sh now presents two options: (A) read SKILL.md directly for immediate mid-session use, or (B) restart session for native `Skill()` support.

### Why

Timestamp analysis proved sandbox resets restore `skills/` from a base snapshot (all 51 built-in skills share identical May 11 10:01 timestamp). Custom-installed skills like stellar-frameworks are wiped on reset. The .bashrc auto-heal hook was the correct recovery strategy, but the async+git combination created a race condition: platform scans skills/ before the background hook finishes copying files. With `--fast` (no git, pure local copy ~0.1s) + synchronous execution, the hook completes before the platform scans, eliminating the race.

## [5.4.2] — 2026-05-15

### Fixed

- **Critical: .bashrc auto-heal hook written to wrong path** — boot.sh and setup.sh wrote the auto-heal hook to `$PROJECT_ROOT/.bashrc` (`/home/z/my-project/.bashrc`), which is **never sourced by the platform**. The platform sources `$HOME/.bashrc` (`/home/z/.bashrc`). This meant the entire self-heal mechanism was non-functional: after sandbox resets, the skill files were wiped and never auto-recovered. Fixed by writing to `$HOME/.bashrc` in both boot.sh and setup.sh.
- **Old wrong .bashrc cleanup** — boot.sh now removes any stale `.bashrc` hook from the project root (`$PROJECT_ROOT/.bashrc`) if it exists from a previous installation.

### Added

- **Post-install restart notice** — boot.sh now displays a clear warning box after fresh install: "Skill installed but NOT yet available in this session. Please RESTART this session to activate stellar-frameworks." The platform loads `available_skills` at session start; skills installed mid-session are invisible until the next session. This prevents user confusion when `Skill(command="stellar-frameworks")` fails immediately after running the one-liner.
- **setup.sh auto-heal hook** — setup.sh now also writes the `$HOME/.bashrc` auto-heal hook, not just boot.sh. Previously only boot.sh configured persistence.

### Why

User reported persistent bug: after running the one-liner in a fresh sandbox and leaving for hours, `stellar-frameworks` disappeared from `available_skills`. The root cause was a one-line path error: `.bashrc` hook was written to `/home/z/my-project/.bashrc` (never sourced) instead of `/home/z/.bashrc` (sourced by platform on shell open). The self-heal mechanism added in v5.4.1 was completely non-functional due to this path mistake.

## [5.4.1] — 2026-05-14

### Added

- **Source Availability & Documentation Check (SADC)** — new mandatory step as the first action (action 1) in SPECIFY phase. Before restating the problem, the agent must research: (1) existing packages/libraries/frameworks that already solve the task, (2) official documentation for the recommended approach, (3) established patterns and best practices. Tier-specific depth: Minimal (skip), Simple (quick check against one source), Standard (full research — search + docs + confirm no wheel reinvention), Complex (deep research — multiple sources, compare approaches, document tradeoffs). New section in SKILL.md with full specification.
- **Source Research field** in problem-spec template — new required field documenting what sources were checked, what was found, and if nothing was found, an explicit statement. "Building from scratch when a library exists is a spec-level defect."

### Changed

- **SPECIFY phase purpose** — updated from "removes ambiguity" to "removes ambiguity — grounded in real sources, not assumptions."
- **SPECIFY phase actions** — renumbered with SADC as action 1 (was implicitly action 0). Problem restatement now explicitly notes it must be "informed by the sources found in step 1."

### Why

The framework had a fatal gap: SPECIFY jumped straight to "restate the problem" without checking if a solution already existed or what the official docs recommended. This caused agents to build from assumptions, use APIs incorrectly, or reinvent existing wheels — leading to massive refactoring when the correct approach was discovered later. SADC closes this gap by making source research the first thing that happens in SPECIFY, before any planning begins. It is to implementation what SSV is to analysis: a freshness check that prevents working from stale assumptions.

## [5.4.0] — 2026-05-13

### Changed

- **No SKIP — only internal**: The "Non-Coding → SKIP" concept is replaced with a **Minimal** complexity tier. All six phases always run for ALL tasks — no exceptions. For non-coding tasks (questions, explanations, recommendations), SPECIFY, PLAN, and VERIFY run internally (the agent thinks through them without producing formal artifacts). IMPLEMENT produces the visible output. This means the framework's participation is binary: always on. The dial that turns is ceremony, not presence.
- **Minimal PCR format**: New compact format `☄️ PCR [Minimal] Phases→internal : PASS | Evidence: <one-line result>` replaces the old `☄️ PCR [Non-Coding] SPECIFY→SKIP PLAN→SKIP IMPLEMENT→PASS VERIFY→SKIP` format. No phase is labeled SKIP — all phases ran, just internally.
- **Task Type Awareness table**: Non-Coding row changed from `SKIP` across SPECIFY/PLAN/VERIFY to `Internal (identify question)`, `Internal (plan approach)`, `Internal (self-check)`. Explicit statement added: "No phases are ever skipped."
- **phases.md Task Type Adaptation**: Non-Coding column added to the adaptation table. Traceability IDs now explicitly scoped to Simple/Standard/Complex tiers (Minimal does not use them).
- **Skill description**: Rewritten to emphasize "without exception" and "complexity adapts, participation never skips." Removes all SKIP language from the trigger description.
- **Complexity Tiers**: Four tiers now — Minimal, Simple, Standard, Complex. Minimal is the floor, not a bypass.

### Why

The v5.3.2 approach of marking phases as "SKIP" for non-coding tasks created an ambiguity: does SKIP mean "the phase didn't run" or "the phase ran but produced no output"? This matters because a phase that truly doesn't run means the agent didn't think through the problem before answering. By making all phases always run (even if internally), the framework ensures structured thinking happens for every interaction — the difference is just whether the thinking is visible.

## [5.3.2] — 2026-05-13

### Added

- **Non-Coding task type** — new row in Task Type Awareness: questions, explanations, and recommendations now trigger the framework with SPECIFY, PLAN, and VERIFY all SKIPPED. IMPLEMENT does the actual work (answering, explaining). DELIVER outputs a compact `[Non-Coding]` PCR. This gives every interaction a traceable record, not just coding tasks.
- **Non-Coding PCR format** — single-line compact format: `☄️ PCR [Non-Coding] SPECIFY→SKIP PLAN→SKIP IMPLEMENT→PASS VERIFY→SKIP | Evidence: <one-line result>`.

### Changed

- **Skill description: universal activation** — framework now triggers for ALL tasks, not just coding. Description rewritten to cover coding tasks (full phases) and non-coding tasks (SKIP phases with PCR traceability). "Core workflow that structures ALL tasks through a phase machine" replaces "Core coding workflow."
- **Activation banner** — added "Universal" to feature list.

## [5.3.1] — 2026-05-13

### Changed

- **Skill description rewritten for aggressive triggering** — replaced abstract jargon ("deterministic coding workflow with phase state machine, traceability IDs, artifact templates, and structured verification") with action-oriented trigger description (~75 words). Explicitly enumerates task types (features, bugs, refactoring, scripts, debugging, code generation) and includes universal catch-all closing phrase. Manual eval score: 5/20 → 20/20. The phase machine is now described as non-optional ("always runs — adapts verbosity to complexity but never skips") per user requirement that all code tasks use the framework.

### Fixed

- **setup.sh version confirmation message** — grep pattern was updated to match the new version string but the confirmation message was not, causing it to report "Version 5.3.0 confirmed" when checking for v5.3.1.

## [5.3.0] — 2026-05-11

### Added

- **Task Type Awareness** — new section in SKILL.md and phases.md extending the phase machine beyond coding tasks. Four task types (Coding, Document, Visualization, Data Processing) each have adapted SPECIFY/PLAN/IMPLEMENT/VERIFY behaviors. Traceability IDs apply to all types.
- **Multi-Skill Orchestration (Skill Chain)** — PLAN phase now supports defining skill invocation sequences with SKILL-level Traceability IDs (SKILL-001, SKILL-002, ...). Enables orchestrating multi-skill workflows (e.g., web-search → charts → PDF).
- **TodoWrite Integration** — PLAN phase recommends syncing IMPL-XXX steps to the platform's native TodoWrite tool for real-time progress visibility.
- **Compact Verification Template** — verification-report.md now includes a 5-row compact variant for Simple tasks, alongside the existing full template for Standard/Complex.
- **AI/SDK Error Diagnostic Path** — new category in error-resolution.md covering SDK invocation failures, rate limiting, timeout, image generation errors, and web search failures.
- **Phase-Transition Memory Reminders** — memory-template.md now defines a one-line memory check at each phase transition, not just IDLE. Ensures memory stays active throughout the entire phase machine.
- **Completion Signal** — DELIVER phase now explicitly references the platform's `Complete` tool for web development tasks.
- **boot.sh auto-bootstrap** — when `.zscripts/dev.sh` is missing, boot.sh automatically creates it and initializes a minimal Next.js project (package.json, tsconfig, Tailwind v4, layout, page). No separate `fullstack-dev init` step needed. `--install-only` flag skips dev server entirely.
- **Session Continuity** — new section in SKILL.md and continuation check in IDLE phase (phases.md). Prevents the LLM from regenerating proposals, plans, or specifications the user has already seen. Continuation signals (user approves plan, references previous output, follow-up question) cause SPECIFY and/or PLAN to be skipped. PCR block gains `Continuation` field (NEW/YES) and SKIP status for bypassed phases.

### Changed

- **boot.sh version check** — replaced weak `grep "Phase State Machine"` with semantic version comparison. Fixes the critical bug where v5.2.0 features were not installed because the check passed for both v5.0.0 and v5.2.0.
- **boot.sh dev server is now optional** — missing `.zscripts/dev.sh` no longer causes `exit 1`. boot.sh auto-creates it and bootstraps a Next.js project if needed. Dev server failure is the only condition that returns exit 1.
- **boot.sh knowledge file paths** — updated to match new `knowledge/universal/` and `knowledge/platform/` directory structure.
- **Knowledge directory restructured** — split into `knowledge/universal/` (architecture, conventions, error-patterns) and `knowledge/platform/zai-sandbox.md`. Universal files are portable across platforms; platform file contains z.ai-specific constraints. All internal references updated.
- **Skill description shortened** — removed verbose trigger phrases from frontmatter (was ~600 chars, now ~120 chars). Improves skill triggering accuracy on the platform.
- **PCR block enhanced** — added `Tier` field (Simple/Standard/Complex) and `Continuation` field (NEW/YES) with SKIP status for bypassed phases.
- **Memory budget increased** — MEMORY.md soft budget raised from ~2,000 to ~3,000 characters to accommodate meaningful preference entries.
- **Error resolution references updated** — all knowledge file references now point to `knowledge/universal/` and `knowledge/platform/zai-sandbox.md`.

### Fixed

- **boot.sh auto-update failure** — the `NEED_INSTALL` check used `grep -q "Phase State Machine"` which matched both v5.0.0 and v5.2.0, preventing auto-update from v5.0.0 to v5.2.0. Now uses version tag comparison.

### Rebranded

- **stellar-coding-agent → stellar-frameworks** — project, skill, directory, and all internal references renamed. GitHub repo URL, `Skill()` invocation command, install paths, and documentation all updated. Historical CHANGELOG entries preserved as-is (they reference the old name at time of writing).

## [5.2.0] — 2026-05-10

### Added

- **Memory directory architecture** — replaced flat `memory.md` with a structured `memory/` directory containing evergreen files (`MEMORY.md`, `decisions.md`, `incidents.md`) and dated session logs (`YYYY-MM-DD.md`). Inspired by Memweave's design: plain Markdown files as source of truth, filename convention determines lifecycle (evergreen vs dated).
- **Bounded memory budget** — MEMORY.md has a ~2,000 character soft budget with agent-driven curation. When exceeded, DELIVER flags it for consolidation. Inspired by Hermes's philosophy: let the LLM decide what to keep/evict rather than relying on mechanical eviction algorithms.
- **Rich session summary** — Standard/Complex tasks now capture decisions, context, and caveats in addition to the compact task/outcome format. Preserves decision rationale across sessions for pre-compaction knowledge extraction.
- **Complexity Tiers & PCR Format** — new section in phases.md defining Simple (compact PCR, abbreviated artifacts), Standard (full PCR), and Complex (full PCR + detailed evidence). The phase machine always runs; what changes is verbosity, not rigor.
- **Compact PCR for Simple tasks** — single-line format `☄️ PCR [Simple] SPECIFY→DELIVER : PASS | Evidence: ... | Defects: 0` replaces the full 6-row block for trivial tasks.

### Changed

- **Skill description expanded** — added explicit trigger phrases ("build", "implement", "fix bugs", "refactor", "audit", "follow the process", "use stellar", "phase machine", "structured workflow") and auto-abbreviate clause for trivial fixes. Skill-creator audit score improved from 2/10 to 8/10 for triggering.
- **DELIVER phase** — action 1 now writes to `memory/YYYY-MM-DD.md` (dated file, append-only). New action 2 checks MEMORY.md budget. Rich format for Standard/Complex captures decisions, context, caveats.
- **Error Handling** — incident logging now writes to `memory/incidents.md` instead of a shared `memory.md` Patterns section.
- **IDLE phase** — action 3 now reads `memory/MEMORY.md` with graceful handling when `memory/` directory doesn't exist yet.

### Fixed

- **boot.sh path resolution** — added `PROJECT_ROOT` detection so the repo can live as a subdirectory of `/home/z/my-project/`. All paths (page.tsx, dev.sh, database, logs) now resolve to the project root, not the repo directory.
- **setup.sh install path** — `INSTALL_DIR` now uses `$PROJECT_ROOT/skills/` instead of repo-relative path, ensuring the skill installs to the platform's load path.

## [5.1.0] — 2026-04-19

### Added

- **"When Active" section** — placed in high-attention zone (after Activation, before Preview Bootstrap). Defines what a "task" is (code/file changes vs conversation), connects task-start to phase declaration, and connects task-end to PCR output. Addresses the failure mode where the LLM loads the skill, understands the framework, but skips it entirely because the PCR block was in the low-attention tail of SKILL.md.
- **Cross-reference** in Process Compliance Report section pointing back to "When Active."

### Changed

- **Abbreviation guidance** — "abbreviate when they don't" → "abbreviate when the task is simple, but never skip entirely." The v5.0.0 permissive language was too loose; the LLM interpreted "simple task" as "zero phases." Adding a floor: SPECIFY+PLAN combined into one paragraph, PCR always output.

### Why

Commit edb092c (boot.sh auto-update) was implemented without following the framework — no SPECIFY, no PLAN, no PCR. Root cause: the PCR block at lines 89-103 of SKILL.md was in the LLM's low-attention zone, and the v5.0.0 language gave too much room to rationalize skipping. The fix moves the completion signal to high-attention territory (lines 17-21) and adds a concrete abbreviation floor. This does not guarantee compliance (nothing in a text file can) but makes the tools visible when they're needed.

## [5.0.0] — 2026-04-13

### Philosophy Change

v5.0.0 is a philosophical reset based on an honest audit of the framework's effectiveness. The audit found that compliance enforcement language ("Do not skip phases", "mandatory", "must") has no measurable effect on LLM behavior — the same LLM follows or ignores the framework regardless of how strongly it's worded. Meanwhile, the tools that work (traceability IDs, templates, SSV) work because they're useful, not because they're mandatory.

**Design principle**: Stop telling the LLM what it MUST do. Start giving it tools it WANTS to use.

### Removed
- **Coexistence with fullstack-dev** — 18-line section that the user explicitly rejected as "nonsense" because it doesn't solve the persistence problem. The framework is technology-agnostic; whether fullstack-dev is active or not is the LLM's concern, not this file's.
- **Implementation Rules** — Duplicated knowledge/constraints files when standalone and conflicted with fullstack-dev when coexisting. The Phase References table and constraints/ directory already serve this purpose.
- **Complexity Tiers** — A classification table that prescribed workflow abbreviations based on file count. In practice, the agent already adapts naturally. Formal tiers added rules that were sometimes followed and sometimes ignored, with no quality difference.
- **Scope section** — Five rules about what the framework "does not" do. Unnecessary boundary declaration — the framework's scope is self-evident from its content.
- **QA Attestation → Process Compliance Report (PCR)** — Renamed to be honest about what it is. "QA" implies independent quality assurance; the attestation is self-graded. The honesty note (retained) already acknowledged this, but the name contradicted it.
- **Evidence tiers, status value definitions, delivery gate rules** — Detailed specification of attestation mechanics that added 30+ lines. The attestation block format is self-explanatory; surrounding it with rules didn't improve accuracy.

### Changed
- SKILL.md rewritten: 181 lines → ~95 lines (~48% reduction)
- Activation banner updated to v5.0.0, replaced phase/template counts with feature names
- New "Limitations" section at top: explicitly states what the framework cannot do (guarantee compliance, force behavior, persist across sessions)
- Compliance language removed: "Do not skip phases", "mandatory", "Do not omit" replaced with "use them when they help, abbreviate when they don't"
- Phase descriptions condensed from full paragraphs to single-purpose sentences
- Error recovery section simplified from numbered sub-steps to essential rules
- Git rules retained but shortened — removed redundant decision tree reference when the full tree already exists in the referenced file

### Fixed
- **State diagram inconsistency** — phases.md had error arrow from VERIFY→SPECIFY; SKILL.md had DELIVER→SPECIFY. Consolidated to one canonical version: "On error: stop, diagnose, fix, return to VERIFY" with SPECIFY as the alternative for specification gaps.
- **memory-template.md path mismatch** — Template referenced `~/code/memory.md` but phases.md referenced `skills/stellar-frameworks/memory.md`. Fixed to single canonical path: `/home/z/my-project/skills/stellar-frameworks/memory.md`.
- **phases.md path reference** — Changed `Check memory.md in this skill directory` to avoid future path drift.

### Honest Assessment
This refactor does not solve the persistence problem (impossible within platform architecture). It does not improve compliance rates (nothing in a text file can). What it does is: stop lying about what the framework can do, remove 86 lines of dead weight that diluted attention from the parts that actually work, and make the framework shorter and clearer so the useful tools (traceability IDs, templates, SSV, decision tree) are more likely to be read and used.

## [4.6.0] — 2026-04-13

### Added
- Source State Verification (SSV) — new section in SKILL.md mandating git fetch + comparison before any analysis/audit task on git repositories
- Source State field in problem-spec template — records branch, HEAD SHA, and verification status
- Source integrity check in verification-report Review Checklist
- Stale Local Data error pattern in error-patterns.md ([CRITICAL] severity)
- Stale-data recovery path (#5) in error-resolution decision tree Git section
- Cross-session git state awareness flag in IDLE phase (action 3.5)
- Evidence tiers in QA Attestation — code-creation vs code-analysis/audit tasks have different evidence requirements; analysis tasks must include source state verification

### Changed
- SPECIFY phase: entry criteria now includes source state verification; action 7.5 added for SSV
- VERIFY phase: action 1b added for source integrity check on analysis tasks
- IDLE phase: action 3.5 added for cross-session git state uncertainty flag

### Why
A stale local git clone caused a false-negative audit — the agent analyzed outdated files, claimed 20 applied fixes were absent, and delivered a confidently incorrect report. SSV closes this gap at every level: SKILL.md (mandate), SPECIFY (gate), VERIFY (defense-in-depth), templates (record), knowledge base (pattern recognition), and decision tree (recovery path).

## [4.5.0] — 2026-04-12

### Added
- Coexistence Mode — new "Coexistence with fullstack-dev" section defining how this framework layers with the platform-provided fullstack-dev skill
- IMPLEMENT phase defers technology-specific decisions to fullstack-dev when it is active; falls back to own `constraints/` and `knowledge/` files when standalone

### Why
fullstack-dev persists across sessions (system prompt level) and provides deep Next.js technical expertise. This framework provides orthogonal process governance. Rather than duplicating fullstack-dev's technical rules and risking conflicting instructions, the framework recognized fullstack-dev's presence and deferred to it for IMPLEMENT-phase decisions. (Removed in v5.0.0 — user identified this as unnecessary and the section was removed.)

## [4.4.2] — 2026-04-11

### Changed
- QA Attestation is now required after every task, not just coding tasks
- Non-coding tasks (conversation, questions, feedback) mark phases as N/A but still output the attestation block

### Why
The Activation section had an escape hatch: "If the user's request is not a coding task, the phase machine does not apply." This allowed skipping the attestation entirely on non-coding tasks — the exact failure mode the user wanted to detect. Making it mandatory for all tasks means: no attestation = framework was not followed.
