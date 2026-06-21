<div align="center">

<img src="skill/stellar-trails/chibi.png" alt="Stellar Frameworks mascot" width="180">

# ☄️ stellar-trails

**Universal task workflow for LLM agents**

[![Version](https://img.shields.io/badge/version-7.2.5-blue.svg)](skill/stellar-trails/CHANGELOG.md)
[![Latest](https://img.shields.io/badge/tag-latest-brightgreen.svg)](https://github.com/hoshiyomiX/stellar-trails/releases/tag/latest)
[![Language](https://img.shields.io/badge/language-Markdown-4EAA25.svg)]()
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

### Install (recommended — via ClawHub)

Stellar Trails is published to [ClawHub](https://clawhub.ai/skills/stellar-trails), the official z.ai skill marketplace. Install with one command:

```bash
clawhub install stellar-trails
```

**Why this is the best method:**
- ✓ `clawhub` is a native z.ai CLI tool (pre-installed in all sandboxes)
- ✓ Install from ClawHub registry (official, verified, moderated)
- ✓ No `curl` from external URLs — no agent refusal
- ✓ No manual file writes to `/home/user_skills/`
- ✓ No `.usermark` creation (no skill-hijack pattern)
- ✓ ClawHub handles storage, extraction, and version tracking
- ✓ Moderation status: CLEAN (no suspicious patterns)

**After install:** Invoke via `Skill(command="stellar-trails")` — banner `☄️ STELLAR TRAILS · v7.2.5 · ACTIVE`.

**Update to latest version:**
```bash
clawhub update stellar-trails
```

**Uninstall:**
```bash
clawhub uninstall stellar-trails
```

### Alternative: Manual install (for non-ClawHub environments)

If `clawhub` is not available, download the zip from GitHub Releases and place it in `/home/user_skills/`:

```bash
curl -sL https://github.com/hoshiyomiX/stellar-trails/releases/latest/download/stellar-trails.zip -o /home/user_skills/stellar-trails.zip && echo "✓ installed — restart sandbox to apply"
```

**Note:** This method may be refused by security-conscious agents because it downloads from an external URL. Use `clawhub install` whenever possible.

### Persistence Model

| Layer | Mechanism | Survives reset? |
|---|---|---|
| ClawHub registry | Official z.ai skill marketplace | ✓ |
| `clawhub install` | Tracks installation, handles updates | ✓ |
| ZAI service auto-extract | Extracts skill to `skills/stellar-trails/` at session start | ✓ (re-extracted every session) |

**No boot.sh. No shell execution in Skill() invoke. Pure markdown data, stateless skill.**

### CI/CD — Automated Release

Setiap push tag `v*.*.*` ke repo akan trigger GitHub Actions workflow (`.github/workflows/release.yml`) yang otomatis:

1. **Build zip** dari `skill/stellar-trails/` directory
2. **Generate SHA-256 checksum** file (.zip.sha256)
3. **Create GitHub Release** dengan zip + checksum sebagai release assets
4. **Move `latest` tag** ke commit tersebut (stable releases only, bukan pre-release)
5. **Generate release body** dengan install instructions + checksum

**Untuk maintainer** — release baru:
```bash
# 1. Edit skill files (SKILL.md, CHANGELOG.md, dll), bump version metadata
# 2. Commit
git add -A && git commit -m "feat(v7.X.Y): ..."
# 3. Tag dengan format v*.*.*
git tag -a v7.X.Y -m "v7.X.Y — description"
# 4. Push tag (trigger workflow)
git push origin refs/tags/v7.X.Y
```

Workflow akan handle sisanya. Release asset + `latest` tag update otomatis dalam ~30 detik.

### What's New

- **v7.2.0**: `boot.sh` deleted entirely (was 852 lines, 8 red flag patterns: self-re-exec, submodule purge, force-sync git, 15+ rm -rf, network ops, shell hooks, clone→exec pattern, remote URL query). Replaced dengan `dev.sh` standalone (60 lines, no-cache HTTP server, no destructive/git/network ops). Path B one-liner revisi: download zip + extract + cp files + chmod dev.sh.
- **v7.1.4**: New landing page (cosmic glassmorphism + phase flow diagram). Dead code cleanup (setup.sh, activate.sh, page.tsx, .bashrc — 386 lines removed).
- **v7.1.3**: One-liner install (`curl ... -o /home/user_skills/stellar-trails.zip && touch .usermark`). No shell execution, agent-friendly.
- **v7.1.2**: Stable asset name `stellar-trails.zip` (no version suffix) — `releases/latest/download/stellar-trails.zip` URL work
- **v7.1.1**: CI/CD GitHub Actions workflow + simplified install (download dari release, bukan build manual)
- **v7.1.0**: Stateless skill — hapus `bash boot.sh` bootstrap dari SKILL.md, ganti dengan `test -f` check. Fix: v7.0.0 ditolak security-conscious agents
- **v7.0.0**: Rebrand `stellar-frameworks` → `stellar-trails`

See [CHANGELOG.md](skill/stellar-trails/CHANGELOG.md) untuk full history & forensic details.

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

The framework survives resets through a layered recovery chain (v6.4.0 simplified model — no more shell init hooks):

| Layer | Mechanism | Survives reset? |
|-------|-----------|-----------------|
| **skill/** (git-tracked source in stellar repo) | Platform creates `repo.tar` from working tree before reset, extracts after | Yes |
| **skills/stellar-trails/** (project repo, git-tracked) | v6.4.0: `.gitignore` exception (`skills/*` + `!skills/stellar-trails/`) makes 18 load-path files git-tracked — survives via git tree AND `repo.tar` | Yes (dual-guarantee) |
| **boot.sh** (co-located in `skills/`) | Copied alongside SKILL.md during install, baked into `repo.tar` AND git tree | Yes |
| **SKILL.md 4-layer bootstrap** | Sole heal mechanism (v6.4.0): co-located `boot.sh` → project-local repo `boot.sh` → home repo → GitHub fresh clone | Yes (layer 1 always fires) |
| **$HOME/ repo & shell hooks** | v6.3.0 used `.bashrc` hooks — **REMOVED in v6.4.0**. No more shell init file modifications. | N/A (mechanism deleted) |

**Recovery in practice:**

| Scenario | What happens |
|----------|-------------|
| **Fresh sandbox** (first time) | User runs Quick Start commands. Repo cloned to a single location, `boot.sh` installs `skills/stellar-trails/` via `cp -a`. No shell hooks written. |
| **Sandbox reset** | `skill/` and `skills/stellar-trails/` restored from `repo.tar` (working-tree snapshot). Additionally, `skills/stellar-trails/` is in the project git tree (v6.4.0 dual-guarantee). On next `Skill()` invoke, SKILL.md bootstrap layer 1 fires: runs `skills/stellar-trails/boot.sh --fast --audited` (~50ms) to verify and sync files. Falls back to layers 2-4 only if layer 1 fails. |
| **v6.3.0 → v6.4.0 migration** | First `boot.sh` run after upgrade detects legacy `.bashrc/.bash_profile/.profile` hooks and strips them via `python3` in-place edit. Logged as `Cleaned N legacy shell hook(s)`. Shell startup becomes faster post-migration. |
| **Stale snapshot contamination** | `boot.sh --offline` skips upstream check entirely. Without `--offline`, `boot.sh` force-syncs via `git reset --hard origin/main` if upstream diverged AND no unpushed commits exist. All operations audited. |

The key insight: **the framework is self-healing via the SKILL.md 4-layer bootstrap alone**. The git-tracked `skills/stellar-trails/` directory and the co-located `boot.sh` together guarantee recovery even when all volatile state (home dir, shell init files) is wiped.

---

## File Structure

```
stellar-trails/                   # The stellar-trails repo itself
├── boot.sh                           # Install + self-heal + force-sync (single entry point)
├── README.md                         # This file
├── .gitignore                        # Excludes /skills/ (runtime-generated in stellar repo for testing)
├── .checksums                        # SHA-256 of 20 critical files (verified by --verify)
│
├── skill/stellar-trails/         # Git-tracked source of truth (19 files)
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
└── skills/stellar-trails/        # ⚠️ Gitignored IN STELLAR REPO (runtime copy)
                                    # Populated by boot.sh (cp -a from skill/)
                                    #
                                    # IN PROJECT REPO (where skill is installed):
                                    # This dir IS git-tracked via .gitignore exception:
                                    #   skills/*
                                    #   !skills/stellar-trails/
                                    # That's the v6.4.0 dual-guarantee persistence model.
```

**Note on dual `.gitignore`**: The stellar repo's own `.gitignore` excludes `/skills/` (because `skills/` is runtime-generated when boot.sh is tested inside the stellar repo). The **project repo's** `.gitignore` (where the skill is installed for actual use) uses `skills/*` + `!skills/stellar-trails/` exception to git-track the 18 load-path files. Both behaviors are correct for their respective contexts.

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
| [**v7.1.0**](skill/stellar-trails/CHANGELOG.md) | Stateless skill. SKILL.md bootstrap dihapus (no shell execution). Install jadi 2-path: Path A (ZAI platform, zip upload) + Path B (standalone, optional boot.sh). Fix: v7.0.0 install command ditolak security-conscious agents karena pola supply-chain attack. |
| [**v7.0.0**](skill/stellar-trails/CHANGELOG.md) | **BREAKING** — Rebrand `stellar-frameworks` → `stellar-trails`. Repo renamed di GitHub (soft migration via auto-redirect). Skill name, directory names, log file path semua berubah. Existing user perlu manual migration. |
| [**v6.4.3**](skill/stellar-trails/CHANGELOG.md) | Collapsed SKILL.md bootstrap dari 5-layer ke 2-layer (hapus 3 layer yang terbukti gagal survive reset). `latest` mutable tag ditambahkan untuk konsistensi install. |
| [**v6.4.2**](skill/stellar-trails/CHANGELOG.md) | Dual-location install — `skills/stellar-trails/` (platform discovery) + `.zscripts/stellar-trails/` (persistent backup yang reliably survive sandbox reset). SKILL.md bootstrap 5-layer dengan `.zscripts/` sebagai layer 1. |
| [**v6.4.1**](skill/stellar-trails/CHANGELOG.md) | README documentation update (PINNED_SHA fix, .checksums count, audit log sample, persistence table, file structure, version history). |
| [**v6.4.0**](skill/stellar-trails/CHANGELOG.md) | Single-clone model (no `$HOME` re-clone), shell init hooks removed (SKILL.md bootstrap is sole heal mechanism), co-located `boot.sh` support, baked skill files git-tracked in project repo (dual-guarantee persistence) |
| [**v6.3.0**](skill/stellar-trails/CHANGELOG.md) | Loud Sterilization: audit logging for all destructive ops, `--audited` flag, `.zscripts/` popup assets (context pollution fix) |
| [**v6.2.0**](skill/stellar-trails/CHANGELOG.md) | Popup assets moved to `.zscripts/` (hidden from platform scanner) |
| [**v6.1.0**](skill/stellar-trails/CHANGELOG.md) | Upstream-always-check + unpushed-commit safety net |
| [**v6.0.0**](skill/stellar-trails/CHANGELOG.md) | Version reset, chibi mascot, transparent background, force-sync, co-location, activation fallback, README overhaul |
| [**v5.11.0**](skill/stellar-trails/CHANGELOG.md) | setup.sh version sync fix |
| [**v5.10.0**](skill/stellar-trails/CHANGELOG.md) | Skill-creator audit: dead refs, dead asset, description optimization |

> Full changelog with all 25+ versions: [`skill/stellar-trails/CHANGELOG.md`](skill/stellar-trails/CHANGELOG.md)
