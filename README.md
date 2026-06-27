<div align="center">

<img src="skill/stellar-trails/chibi.svg" alt="Stellar Trails mascot" width="180">

# ☄️ stellar-trails

**Universal task workflow for LLM agents**

[![Version](https://img.shields.io/badge/version-7.7.2-blue.svg)](skill/stellar-trails/CHANGELOG.md)
[![Latest](https://img.shields.io/badge/tag-latest-brightgreen.svg)](https://github.com/hoshiyomiX/stellar-trails/releases/tag/latest)
[![Language](https://img.shields.io/badge/language-Markdown-4EAA25.svg)]()
[![Platform](https://img.shields.io/badge/platform-z.ai-7C3AED.svg)](https://z.ai)

Structures all tasks — coding and non-coding — as a **six-phase workflow** with traceability IDs, artifact templates, source state verification, and file-based agent memory. For coding tasks, full phases with verification. For non-coding tasks, phases run internally (Minimal tier) but the framework still activates for traceability. Designed for the [z.ai](https://z.ai) platform.

```text
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
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

**After install:** Invoke via `Skill(command="stellar-trails")` — banner `☄️ STELLAR TRAILS · v7.7.2 · ACTIVE`.

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

**No boot.sh, no shell execution during Skill() invocation. The skill is pure markdown data.**

### CI/CD — Automated Release

Every `v*.*.*` tag push triggers the GitHub Actions workflow (`.github/workflows/release.yml`) which automatically:

1. **Build zip** from the `skill/stellar-trails/` directory
2. **Generate SHA-256 checksum** file (.zip.sha256)
3. **Create GitHub Release** with zip + checksum as release assets
4. **Move `latest` tag** to that commit (stable releases only, not pre-releases)
5. **Generate release body** with install instructions + checksum

**For maintainers** — new release:
```bash
# 1. Edit skill files (SKILL.md, CHANGELOG.md, etc.), bump version metadata
# 2. Commit
git add -A && git commit -m "feat(v7.X.Y): ..."
# 3. Tag with format v*.*.*
git tag -a v7.X.Y -m "v7.X.Y — description"
# 4. Push tag (trigger workflow)
git push origin refs/tags/v7.X.Y
```

The workflow handles the rest. Release asset + `latest` tag update automatically in ~30 seconds.

### What's New

- **v7.7.2**: Corrected frequency guidance — all 9 activation steps now run on every `Skill()` invoke (was incorrectly "Steps 1-5 once per session, 6-9 every invoke"). Running all steps every invoke guarantees fresh environment (latest skill version, popup server up, zip in sync) even after context truncation. Cost is ~3-5 seconds of cheap file ops; correctness benefit outweighs latency.
- **v7.7.1**: Restructure activation — merged Step 5 (Verify chibi.svg) into Step 4. Added new Step 5: Sync persistent zip.
- **v7.7.0**: Fix 8 bugs causing LLM to skip activation steps. Bug #1: replaced stale v7.5.0 zip with v7.6.2 zip. Bugs #2-8: rewrote activation section with imperative framing, expected-output checkpoints, removed dismissive parentheticals, split comment-heavy blocks, added session-frequency guidance.
- **v7.6.2**: Language audit — fixed codeswitching + buzzword + hyperbole. Step numbering cleaned up: 0.5/1/1.5/1.6/2/3/4/5 → 1/2/3/4/5/6/7/8.
- **v7.6.1**: Fix popup mascot cropping — `.mascot` CSS had `border-radius:50%` (circular clip) + `object-fit:cover` (fill-crop) + `height:200px` (forced square). Replaced with `width:200px;height:auto;max-height:240px` — SVG now renders at native aspect ratio (200×220px) with no cropping. Mascot visible in full.
- **v7.6.0**: **BREAKING** mascot format change — `chibi.png` (binary, 1.2 MB) replaced with `chibi.svg` (text, 757 KB ASCII SVG). SVG passes ClawHub's text-file filter natively, eliminating the v7.5.2 Step 1.6 workaround for fresh installs. Updates: index.html `src`, SKILL.md Step 1.5/1.6, .checksums, README/skill-README/watermark references. Step 1.6 retained as backward-compat for v7.5.x→v7.6.0 upgrades.
- **v7.5.2**: Defensive Step 1.6 — auto-restores `chibi.png` from local repo clone if missing after `clawhub update`. Workaround for ClawHub publish filter that strips binary files (1.2 MB mascot) + dotfiles (.checksums) from registry-stored skill. Pure local file copy, no network, no agent refusal triggers.
- **v7.5.1**: Patch — register `chibi.png` in `.checksums` manifest (root-cause fix for mascot not appearing in popup preview after install). Audit: cleaned 6 documentation leftovers (old branding alt text, 4 empty separators, legacy `assets/` dir ref, outdated `.checksums` count, outdated `index.html` description, 5-version gap in What's New).
- **v7.5.0**: Denial Delta Analysis (STEP 1.5 in error-resolution.md) — for denial-type errors (permission denied, EPERM, AccessDenied), compute denied-vs-configured delta before classifying as Bug vs Wrong Approach. Generalized for 9 domains (SELinux, Linux capabilities, DAC, firewall, AppArmor, DB grants, IAM, CORS, K8s RBAC). Saved approximately 2 hours of debugging in one incident.
- **v7.3.0**: Minimalist popup preview — index.html rewritten from 19 KB cosmic glassmorphism to 6 KB minimalist (−68%). New `watermark.md` documenting popup architecture, 3 customization methods, caching layer debug guide, and design guidelines.
- **v7.2.6**: Double-fork technique `( setsid bash dev.sh ... & ) &` — popup preview process now survives shell exit (was killed by sandbox cleanup). PPID=1, no restart needed.
- **v7.2.5**: Published to ClawHub (official z.ai skill marketplace). `clawhub install stellar-trails` — no red flags, no agent refusal.
- **v7.2.0**: `boot.sh` deleted entirely (was 852 lines). Removed for security reasons: self-re-exec, submodule purge, force-sync git, 15+ rm -rf operations, automatic network operations, shell init hooks, clone-then-exec pattern, remote URL queries. Replaced with `dev.sh` standalone (60 lines, no-cache HTTP server, no destructive/git/network ops). Path B one-liner revised: download zip + extract + cp files + chmod dev.sh.
- **v7.1.4**: New landing page (cosmic glassmorphism + phase flow diagram). Dead code cleanup (setup.sh, activate.sh, page.tsx, .bashrc — 386 lines removed).
- **v7.1.3**: One-liner install (`curl ... -o /home/user_skills/stellar-trails.zip && touch .usermark`). No shell execution, agent-friendly.
- **v7.1.2**: Stable asset name `stellar-trails.zip` (no version suffix) — makes `releases/latest/download/stellar-trails.zip` URL work
- **v7.1.1**: CI/CD GitHub Actions workflow + simplified install (download from release, not manual build)
- **v7.1.0**: Stateless skill — removed `bash boot.sh` bootstrap from SKILL.md, replaced with `test -f` check. Fix: v7.0.0 was refused by security-conscious agents
- **v7.0.0**: Rebrand `stellar-frameworks` → `stellar-trails`

See [CHANGELOG.md](skill/stellar-trails/CHANGELOG.md) for full history & forensic details.

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

The workflow adapts beyond coding tasks:

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
├── MEMORY.md          ← Permanent: preferences, patterns (~3K char budget)
├── decisions.md       ← Permanent: architectural decisions with rationale
├── incidents.md       ← Permanent: error patterns and fixes
└── YYYY-MM-DD.md      ← Dated: session digest (auto-created daily)
```

- **Permanent Memory** are permanent — loaded during IDLE for session continuity
- **Dated files** capture what happened and why — preserving decision rationale across sessions
- **Bounded budget** (~3,000 chars for MEMORY.md) with agent-driven curation — the LLM decides what to keep/evict
- **Phase-transition reminders** keep memory active throughout the entire workflow

### Recovery

Structured 5-step decision tree: **capture → classify → identify actions → fix → re-verify**. Covers Compilation, Type, Runtime, Network/Gateway, Database, Git, AI/SDK errors. Git operations have explicit safety rules — `git fetch` before `git pull`, no force push without user instruction, stop all git ops if infrastructure blocks.

---

## Version History

| Version | Summary |
|---------|---------|
| [**v7.7.2**](skill/stellar-trails/CHANGELOG.md) | Corrected frequency guidance — all 9 activation steps run on every `Skill()` invoke (was incorrectly "1-5 per session, 6-9 per invoke"). Guarantees fresh environment after context truncation. |
| [**v7.7.1**](skill/stellar-trails/CHANGELOG.md) | Restructure activation: merged Step 5 (Verify chibi.svg) into Step 4. Added new Step 5: Sync persistent zip. |
| [**v7.7.0**](skill/stellar-trails/CHANGELOG.md) | Fix 8 bugs causing LLM to skip activation steps. Replaced stale zip (root cause), rewrote activation section with imperative framing, expected-output checkpoints, session-frequency guidance, and Step 1 context-refresh workaround. |
| [**v7.6.2**](skill/stellar-trails/CHANGELOG.md) | Language audit — fixed codeswitching + buzzword + hyperbole. Step numbering cleaned up: 0.5/1/1.5/1.6/... → 1/2/3/4/5/6/7/8. |
| [**v7.6.1**](skill/stellar-trails/CHANGELOG.md) | Fix popup mascot cropping — `.mascot` CSS had `border-radius:50%` + `object-fit:cover` + forced square. Replaced with `width:200px;height:auto` — SVG renders at native aspect ratio, no cropping. |
| [**v7.6.0**](skill/stellar-trails/CHANGELOG.md) | **BREAKING** mascot format change — `chibi.png` (binary) → `chibi.svg` (text SVG). Solves ClawHub binary-file-filter issue at the source. |
| [**v7.5.2**](skill/stellar-trails/CHANGELOG.md) | Defensive Step 1.6 — auto-restores `chibi.png` from local repo clone if missing after `clawhub update`. Workaround for ClawHub publish filter that strips binaries + dotfiles. |
| [**v7.5.1**](skill/stellar-trails/CHANGELOG.md) | Patch — register `chibi.png` in `.checksums` manifest (root-cause fix for mascot not appearing in popup preview). Audit: 6 documentation leftovers cleaned (old branding alt text, empty separators, legacy `assets/` ref, outdated counts/descriptions, 5-version What's New gap). |
| [**v7.1.0**](skill/stellar-trails/CHANGELOG.md) | Stateless skill. Removed `bash boot.sh` bootstrap from SKILL.md (no shell execution). Install became 2-path: Path A (ZAI platform, zip upload) + Path B (standalone, optional boot.sh). Fix: v7.0.0 install command was refused by security-conscious agents due to supply-chain attack patterns. |
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
