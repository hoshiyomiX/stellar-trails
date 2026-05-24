<div align="center">

# ☄️ stellar-frameworks

**Universal task workflow for LLM agents**

[![Version](https://img.shields.io/badge/version-5.11.0-blue.svg)](skill/stellar-frameworks/CHANGELOG.md)
[![Language](https://img.shields.io/badge/language-Shell-4EAA25.svg)]()
[![Platform](https://img.shields.io/badge/platform-z.ai-7C3AED.svg)](https://z.ai)

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
[ -d ~/.stellar-frameworks-repo ] || git clone https://github.com/hoshiyomiX/stellar-frameworks.git ~/.stellar-frameworks-repo
bash ~/.stellar-frameworks-repo/boot.sh
```

Invoke: `Skill(command="stellar-frameworks")` — look for `☄️ STELLAR · v5.11.0 · ACTIVE`.

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

| Tier | Criteria | Report Format | Artifacts |
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

---

## Persistence & Recovery

The platform reads `SKILL.md` from disk on every `Skill()` call — updates are effective immediately without restart. The challenge is that the z.ai platform periodically **resets the sandbox**, wiping both the project directory (`/home/z/my-project/`) and the home directory (`$HOME/`).

The framework survives resets through a layered recovery chain:

| Layer | Mechanism | Survives reset? |
|-------|-----------|-----------------|
| **skill/** (git-tracked source) | Platform creates `repo.tar` from working tree before reset, extracts after | Yes |
| **skills/** (platform load path) | `cp -a` from `skill/` — real files, baked into `repo.tar` | Yes |
| **boot.sh** (co-located in `skills/`) | Copied alongside SKILL.md, survives via `repo.tar` | Yes |
| **SKILL.md activation fallback** | 4-layer bootstrap: co-located boot.sh → project boot.sh → home repo → GitHub clone | Yes |
| **$HOME/ repo & hooks** | Auto-heal hook in `.bashrc` clones repo, runs boot.sh | No (volatile) |

**Recovery in practice:**

| Scenario | What happens |
|----------|-------------|
| **Fresh sandbox** (first time) | User runs Quick Start commands. Repo cloned, skill files installed. |
| **Sandbox reset** | `skill/` and `skills/` restored from `repo.tar` automatically. Platform discovers `skills/*/SKILL.md` and registers the skill. On next `Skill()` call, activation fallback runs `boot.sh --fast` (~50ms) to verify and sync files. If files are missing entirely, falls back to GitHub clone. |
| **Stale snapshot contamination** | `boot.sh` force-syncs the home repo with `git reset --hard origin/main`, eliminating diverged branches and uncommitted artifacts from previous sessions. |

The key insight: **the framework is self-healing without relying on persistent hooks**. The git-tracked `skill/` directory and the SKILL.md activation fallback together guarantee recovery even when all volatile state is wiped.

---

## File Structure

```
stellar-frameworks/
├── boot.sh                           # Install + self-heal + force-sync (single entry point)
├── setup.sh                          # [Legacy] Standalone installer — boot.sh handles this now
├── README.md                         # This file
├── .gitignore                        # Excludes skills/ (platform-managed), platform scaffolding
│
├── skill/stellar-frameworks/         # Git-tracked source of truth (survives repo.tar)
│   ├── SKILL.md                      # Core framework (activation, phases, SSV, error recovery)
│   ├── boot.sh                       # Co-located copy — ensures boot.sh is always discoverable
│   ├── CHANGELOG.md                  # Version history (all 25+ versions)
│   ├── README.md                     # Quick-reference README
│   ├── memory-template.md            # Memory system docs & file templates
│   ├── procedure/
│   │   ├── phases.md                 # Phase definitions with entry/exit criteria
│   │   ├── templates/                # Artifact templates (SPECIFY, PLAN, VERIFY, incidents)
│   │   └── decision-trees/
│   │       └── error-resolution.md   # 5-step structured error decision tree
│   ├── constraints/                  # Code quality & type safety standards
│   ├── knowledge/
│   │   ├── universal/                # Platform-agnostic patterns & error catalog
│   │   └── platform/                 # z.ai sandbox constraints
│   └── ...
│
└── skills/stellar-frameworks/        # ⚠️ Gitignored — platform load path
                                    # Populated by boot.sh (cp -a from skill/)
                                    # Survives repo.tar as real files
                                    # This is what the platform scans for SKILL.md
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
| [**v5.11.0**](skill/stellar-frameworks/CHANGELOG.md) | Major refactor: repo-wide version sync, dead asset removal, single-source version extraction |
| **v5.11.x patches** | Force-sync (contamination fix), boot.sh co-location, 3-layer activation fallback, cp-a persistence, cross-trigger guard |
| [**v5.10.0**](skill/stellar-frameworks/CHANGELOG.md) | Skill-creator audit: dead refs, dead asset, description optimization |

> Full changelog with all 25+ versions: [`skill/stellar-frameworks/CHANGELOG.md`](skill/stellar-frameworks/CHANGELOG.md)
