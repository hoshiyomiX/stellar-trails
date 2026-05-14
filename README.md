<div align="center">

# ☄️ stellar-frameworks

**Universal task workflow for LLM agents**

[![Version](https://img.shields.io/badge/version-5.4.1-blue.svg)](skill/stellar-frameworks/CHANGELOG.md)

Structures ALL tasks — coding and non-coding — as a **phase state machine** with traceability IDs, artifact templates, source state verification, and file-based agent memory. For coding tasks, full phases with verification. For non-coding tasks, phases run internally (Minimal tier) but the framework still activates for traceability. Designed for the [z.ai](https://z.ai) platform.

```text
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Error Recovery ◄───────────────────┘
```

</div>

---

## Quick Start

```bash
cd ~/my-project && git clone https://github.com/hoshiyomiX/stellar-frameworks.git 2>/dev/null; bash stellar-frameworks/boot.sh
```

Invoke: `Skill(command="stellar-frameworks")` — look for `☄️ STELLAR · v5.4.1 · ACTIVE`.

---

## How It Works

The framework provides **tools, not rules**. Each phase produces an artifact the next phase consumes, creating a chain that prevents skipping straight to code.

### Phase State Machine

| Phase | Output | Why |
|-------|--------|-----|
| **IDLE** | Complexity classification | Routes the task to the right verbosity level |
| **SPECIFY** | Problem specification + source research | Grounds the spec in real docs, not assumptions |
| **PLAN** | Implementation plan with Traceability IDs | Maps requirements to code locations |
| **IMPLEMENT** | Annotated code | Each block references its Traceability ID |
| **VERIFY** | Evidence-based report | Automated checks + edge case tracing |
| **DELIVER** | Summary + compliance report | Traceable record of what was done |

### Complexity Tiers

Not every task needs the same ceremony. The framework always runs all six phases, but adjusts verbosity:

| Tier | Criteria | PCR Format | Artifacts |
|------|----------|-----------|-----------|
| **Minimal** | Non-coding (question, explain, recommend) | 1-line compact | Internal (no templates) |
| **Simple** | Single file, no schema change | 1-line compact | Abbreviated (no templates) |
| **Standard** | Multiple files or schema change | Full block | Full templates + Traceability IDs |
| **Complex** | Architectural, multi-service | Full block + detailed evidence | Full templates + extra detail |

Error recovery always uses full ceremony regardless of tier.

### Task Type Awareness

The phase machine adapts beyond coding tasks:

| Task Type | SPECIFY | PLAN | IMPLEMENT | VERIFY |
|-----------|---------|------|------------|--------|
| **Coding** | Problem spec | Code steps + Traceability IDs | Write code | Lint, type check, tests |
| **Document** | Content outline | Section plan + structure | Generate document | Format check, completeness |
| **Visualization** | Visual requirements | Data mapping + layout | Generate chart | Visual accuracy, data integrity |
| **Data Processing** | Data spec | Transform pipeline | Write script | Output validation, edge cases |
| **Non-Coding** | Internal | Internal | Answer / explain / recommend | Internal |

### Traceability IDs

`IMPL-001`, `IMPL-002`, ... chain through every phase — requirement → code → verification. If something is dropped, the gap is visible.

### Source State Verification (SSV)

Before analyzing git repositories, the framework verifies data freshness:

```bash
git fetch → compare HEAD to origin → sync if behind → proceed
```

Prevents stale-checkout analysis (the failure that inspired this feature).

### Source Availability & Documentation Check (SADC)

Before planning any implementation, the framework verifies the approach is grounded in real sources — not assumptions:

```text
Search existing packages → Read official docs → Check patterns → Proceed
```

Prevents reinventing existing wheels or using APIs incorrectly. Tier-specific depth: Minimal (skip), Simple (quick check), Standard (full research), Complex (deep multi-source comparison).

### Agent Memory

File-based memory system inspired by [Hermes](https://github.com/NousResearch/hermes-agent) and [Memweave](https://github.com/sachinsharma9780/memweave):

```
memory/
├── MEMORY.md          ← Evergreen: preferences, patterns (~3K char budget)
├── decisions.md       ← Evergreen: architectural decisions with rationale
├── incidents.md       ← Evergreen: error patterns and fixes
└── YYYY-MM-DD.md      ← Dated: session digest (auto-created daily)
```

- **Evergreen files** are permanent — loaded during IDLE for session continuity
- **Dated files** capture what happened and why — preserving decision rationale across sessions
- **Bounded budget** (~3,000 chars for MEMORY.md) with agent-driven curation — the LLM decides what to keep/evict
- **Phase-transition reminders** keep memory active throughout the entire phase machine

### Error Recovery

Structured 5-step decision tree: **capture → classify → identify actions → fix → re-verify**. Covers Compilation, Type, Runtime, Network/Gateway, Database, Git, AI/SDK errors. Git operations have explicit safety rules — `git fetch` before `git pull`, no force push without user instruction, stop all git ops if infrastructure blocks.

### Session Persistence

The z.ai platform may wipe the `skills/` directory on session reset. Recovery depends on whether this is a **fresh sandbox** (never ran boot.sh) or an **existing sandbox** (boot.sh ran before):

| Scenario | Solution | What happens |
|----------|----------|-------------|
| **Fresh sandbox** (first time) | Run the Quick Start one-liner | Clones repo, installs skill, sets up `.bashrc` hook for future auto-heal |
| **Existing sandbox** (boot.sh ran before) | `.bashrc` hook auto-triggers | Next shell command auto-runs `boot.sh --install-only` in background (non-blocking) |

**Important**: The `.bashrc` hook is a secondary safety net for mid-session skill wipes. It does NOT solve the cold-start problem — in a truly fresh sandbox, you must run the one-liner at least once to set everything up. After that, the hook handles subsequent resets automatically.

---

## File Structure

```
stellar-frameworks/
├── boot.sh                           # Install + session bootstrap (single entry point)
├── setup.sh                          # [Legacy] Standalone installer — boot.sh handles this now
├── README.md                         # This file
├── skill/stellar-frameworks/         # Git-tracked source (copied to skills/ on install)
│   ├── SKILL.md                      # Core framework (phases, SSV, error recovery, PCR)
│   ├── CHANGELOG.md                  # Version history
│   ├── memory-template.md            # Memory system docs & file templates
│   ├── procedure/
│   │   ├── phases.md                 # Phase definitions with entry/exit criteria
│   │   ├── templates/
│   │   │   ├── problem-spec.md       # SPECIFY artifact
│   │   │   ├── implementation-plan.md # PLAN artifact (Traceability IDs)
│   │   │   ├── verification-report.md # VERIFY artifact (evidence capture)
│   │   │   └── incident-report.md    # Error documentation
│   │   └── decision-trees/
│   │       └── error-resolution.md   # 5-step structured decision tree
│   ├── constraints/
│   │   ├── code-standards.md         # Function, file, import, quality standards
│   │   └── type-safety.md            # Type system constraints with examples
│   ├── knowledge/
│   │   ├── universal/                # Platform-agnostic coding knowledge
│   │   │   ├── architecture.md       # Runtime environment, directory layout, service topology
│   │   │   ├── conventions.md        # Coding conventions, state management, import order
│   │   │   └── error-patterns.md     # Common errors with cause → fix mapping
│   │   └── platform/                 # Platform-specific constraints
│   │       └── zai-sandbox.md        # z.ai sandbox limitations (gateway, routes, SDK)
│   └── assets/
│       └── page.tsx                  # Custom splash page (closeable + minimizable)
└── skills/stellar-frameworks/        # Platform-managed (auto-healed by boot.sh)
```

---

## Philosophy

> **Stop telling the LLM what it MUST do. Start giving it tools it WANTS to use.**

- **What works**: Traceability IDs, templates, SSV, error decision tree — they work because they're useful, not because they're mandatory
- **What doesn't work**: Compliance enforcement language ("must", "mandatory", "do not skip") — has no measurable effect on LLM behavior regardless of wording
- **What's honest**: The framework cannot guarantee compliance, force behavior, or persist across sessions. It's text in a skill file. The user is the final judge of quality.

---

## Version History

| Version | Summary |
|---------|---------|
| [**v5.4.1**](skill/stellar-frameworks/CHANGELOG.md) | Source Availability & Documentation Check (SADC) — mandatory research before SPECIFY. Prevents building from assumptions. |
| [**v5.4.0**](skill/stellar-frameworks/CHANGELOG.md) | Adaptive complexity tiers — Minimal/Simple/Standard/Complex. All phases always run, no SKIP. Non-coding tasks use Minimal tier (phases internal, only IMPLEMENT visible). |
| [**v5.3.1**](skill/stellar-frameworks/CHANGELOG.md) | Skill description optimized for aggressive triggering (eval 5/20 → 20/20). setup.sh version confirmation fix. |
| [**v5.3.0**](skill/stellar-frameworks/CHANGELOG.md) | Task type awareness, knowledge restructure (universal/platform), skill chain orchestration, memory hardening, compact verification, PCR tier, TodoWrite integration, AI/SDK error path, completion signal, boot.sh auto-bootstrap, session continuity. |
| [**v5.2.0**](skill/stellar-frameworks/CHANGELOG.md) | Agent memory system (Hermes+Memweave inspired), complexity tiers, compact PCR, path safety, triggering improvements. |
| [**v5.1.0**](skill/stellar-frameworks/CHANGELOG.md) | Completion signal moved to high-attention zone, abbreviation floor added. |
| [v5.0.0](skill/stellar-frameworks/CHANGELOG.md) | Philosophical reset. Removed compliance theater, kept useful tools. Added `boot.sh` self-heal. |
| [v4.6.0](skill/stellar-frameworks/CHANGELOG.md) | Source State Verification (SSV). Evidence tiers in attestation. |
| [v4.5.0](skill/stellar-frameworks/CHANGELOG.md) | Coexistence mode with fullstack-dev. *(Removed in v5.0.0)* |
| [v4.4.2](skill/stellar-frameworks/CHANGELOG.md) | QA Attestation required for all tasks (not just coding). |
| [v4.0.0](skill/stellar-frameworks/CHANGELOG.md) | Complete redesign: phase state machine, artifact templates, traceability IDs. |
