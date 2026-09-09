# Pre-Push Local Verification (moved from SKILL.md v9.16.0)

Run before pushing any change that triggers CI. All checks must PASS.

## Pre-Push Local Verification (NEW in v9.2.0, strengthened in v9.7.0)

**Problem this solves**: Pushing code changes to CI without local verification wastes a CI cycle (~1-2 minutes per run) and creates a "push → fail → read logs → push again" loop. This happened during this skill's development:

- v9.0.1 push → CI failed (python3 IndentationError) → read logs → v9.0.2 push → CI succeeded
- The IndentationError would have been caught by running the bash block locally before pushing.
- v9.6.0 push → CI succeeded BUT publish didn't register (moderation hide) → v9.6.1 re-publish
- v9.2.1 push → banner version hardcoded at v9.1.0 (not caught by bash -n)
- v9.1.0 push → SSV grep unescaped `**` (not caught by bash -n)

**Rule**: Before pushing any change that triggers CI, run ALL checks below. **All 9 checks must PASS before push.** If any FAIL, fix before pushing — do not push broken code.

### Verification checklist (9 checks, ALL must pass)

#### Check 1: bash -n syntax on all bash blocks
```bash
python3 << 'PYEOF'
import re, subprocess, tempfile, os
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
blocks = re.findall(r'\x60\x60\x60bash\n(.*?)\x60\x60\x60', content, re.DOTALL)
fail = 0
for i, block in enumerate(blocks, 1):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
        f.write(block); path = f.name
    r = subprocess.run(['bash', '-n', path], capture_output=True, text=True)
    os.unlink(path)
    if r.returncode != 0:
        print(f"✗ Block {i} FAIL: {r.stderr.strip()[:120]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 1: bash -n — {len(blocks)-fail}/{len(blocks)} blocks pass")
PYEOF
```

#### Check 2: python3 -c blocks execute with mock inputs (NEW v9.7.0)
```bash
# Extract and run every python3 -c block with 3 mock inputs: valid JSON, empty JSON, invalid text
python3 << 'PYEOF'
import re, subprocess
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
# Find all python3 -c "..." blocks
blocks = re.findall(r'python3 -c ("[^"]+"|\'[^\']+\')', content)
fail = 0
for i, block in enumerate(blocks, 1):
    cmd = f'echo "{{}}" | python3 -c {block}'
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    if r.returncode != 0:
        print(f"✗ python3 -c block {i} FAIL on empty JSON: {r.stderr.strip()[:80]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 2: python3 -c mock execution — {len(blocks)-fail}/{len(blocks)} blocks pass")
PYEOF
```

#### Check 3: grep patterns return expected values (NEW v9.7.0)
```bash
# Every grep -oP pattern in SKILL.md must return non-empty on the actual file
python3 << 'PYEOF'
import re, subprocess
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
patterns = re.findall(r"grep -oP '([^']+)'", content)
fail = 0
for i, pat in enumerate(patterns, 1):
    # Skip patterns that are meant to match process output, not file content
    if 'pid=' in pat or ':3000' in pat or 'HTTP' in pat:
        continue
    r = subprocess.run(['grep', '-oP', pat, 'skill/stellar-trails/SKILL.md'],
                       capture_output=True, text=True, timeout=5)
    if not r.stdout.strip():
        print(f"✗ grep pattern {i} returns empty: {pat[:60]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 3: grep patterns — {len(patterns)-fail}/{len(patterns)} return non-empty")
PYEOF
```

#### Check 4: Banner version is dynamic, not hardcoded (NEW v9.7.0)
```bash
# Banner must use <VERSION> placeholder, NOT hardcoded v9.x.y
HARDCODED=$(grep -c '☄️ STELLAR TRAILS · v[0-9]' skill/stellar-trails/SKILL.md)
PLACEHOLDER=$(grep -c '☄️ STELLAR TRAILS · v<VERSION>' skill/stellar-trails/SKILL.md)
if [ "$HARDCODED" -gt 0 ] && [ "$PLACEHOLDER" -eq 0 ]; then
  echo "✗ Check 4 FAIL: banner has hardcoded version ($HARDCODED occurrences), no <VERSION> placeholder"
else
  echo "✓ Check 4: banner uses <VERSION> placeholder ($PLACEHOLDER refs), no hardcoded version"
fi
```

#### Check 5: Metadata version matches git tag about to be pushed (NEW v9.7.0)
```bash
NEW_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' skill/stellar-trails/SKILL.md | head -1)
TAG="v$NEW_VERSION"
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "✗ Check 5 FAIL: tag $TAG already exists"
else
  echo "✓ Check 5: tag $TAG does not exist yet (safe to push)"
fi
```

#### Check 6: ClawHub registry state — skill not hidden by moderation (NEW v9.7.0)
```bash
# Before push, verify skill is visible on registry (not moderation-hidden)
# This catches the v9.6.0 bug where publish exit 0 but version didn't register
REGISTRY_STATE=$(clawhub inspect stellar-trails --json)
if [ -z "$REGISTRY_STATE" ]; then
  echo "✗ Check 6 FAIL: cannot reach clawhub registry — push may publish to hidden skill"
else
  MOD_STATE=$(echo "$REGISTRY_STATE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('moderation',{}).get('state','unknown'))" || echo "unknown")
  if [ "$MOD_STATE" = "hidden" ] || [ "$MOD_STATE" = "deleted" ]; then
    echo "✗ Check 6 FAIL: skill is $MOD_STATE by moderation — publish will not register"
    echo "  Contact clawhub moderator before pushing"
  else
    echo "✓ Check 6: skill visible on registry (moderation: $MOD_STATE)"
  fi
fi
```

#### Check 7: YAML structure valid (if workflow files changed)
```bash
if git diff --cached --name-only HEAD | grep -q '\.github/workflows/'; then
  python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && \
    echo "✓ Check 7: workflow YAML valid" || echo "✗ Check 7 FAIL: workflow YAML invalid"
else
  echo "✓ Check 7: no workflow files changed (skip)"
fi
```

#### Check 8: Markdown fence count is even (no orphan code blocks)
```bash
_F=$(printf '\x60\x60\x60')
FENCES=$(grep -c "$_F" skill/stellar-trails/SKILL.md)
if [ $((FENCES % 2)) -eq 0 ]; then
  echo "✓ Check 8: markdown fences even ($FENCES)"
else
  echo "✗ Check 8 FAIL: markdown fences odd ($FENCES) — orphan code block"
fi
```

#### Check 9: Post-push plan — registry poll will be done (NEW v9.7.0)
```bash
# Acknowledge that push is not complete until registry confirms the version
echo "✓ Check 9: post-push plan acknowledged"
echo "  After CI succeeds, MUST poll clawhub inspect until latestVersion = $NEW_VERSION"
echo "  If registry doesn't update within 60s of CI success, fetch CI logs + diagnose"
echo "  (This catches the v9.6.0 bug: publish exit 0 but version not registered)"
```

#### Check 10: index.html version matches SKILL.md (NEW v9.10.1)
```bash
SKILL_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' skill/stellar-trails/SKILL.md | head -1)
INDEX_VERSION=$(grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' skill/stellar-trails/index.html | head -1)
if [ "$SKILL_VERSION" != "$INDEX_VERSION" ]; then
  echo "✗ Check 10 FAIL: SKILL.md v$SKILL_VERSION vs index.html v$INDEX_VERSION — version drift"
else
  echo "✓ Check 10: index.html version matches SKILL.md (v$SKILL_VERSION)"
fi
```

#### Check 11: No duplicate knowledge files (NEW v9.11.4)
```bash
# Catches byte-identical duplicate files in knowledge/ subdirs (leftover from path-mismatch fixes)
DUPES=$(find skill/stellar-trails/knowledge/ -type f -name "*.md" -exec md5sum {} \; | sort | uniq -d -w 32 | wc -l)
if [ "$DUPES" -gt 0 ]; then
  echo "✗ Check 11 FAIL: $DUPES duplicate knowledge file(s) detected:"
  find skill/stellar-trails/knowledge/ -type f -name "*.md" -exec md5sum {} \; | sort | uniq -d -w 32
  echo "  Remove duplicates — only top-level knowledge/*.md should exist (no platform/ or universal/ subdirs)"
else
  echo "✓ Check 11: no duplicate knowledge files"
fi
```

#### Check 12: phases.md ↔ SKILL.md SADC drift (NEW v9.11.4)
```bash
# Catches drift between phases.md SADC step and SKILL.md SADC section
# Both must agree: main agent inline, NO subagent dispatch, NO crawl4ai/web-reader invocations
# Note: matches positive invocations only (Skill(command="...") or "dispatched"), not negations like "No crawl4ai"
PHASES_SUBAGENT=$(grep -cE 'Skill\(command="(crawl4ai|web-reader)"\)|subagent dispatched|Task\(subagent_type' skill/stellar-trails/procedure/phases.md)
PHASES_SUBAGENT=${PHASES_SUBAGENT:-0}
PHASES_CRAWL=0  # accounted for in PHASES_SUBAGENT above via Skill(command="...")
if [ "$PHASES_SUBAGENT" -gt 0 ]; then
  echo "✗ Check 12 FAIL: phases.md still references removed SADC patterns (count: $PHASES_SUBAGENT)"
  echo "  SKILL.md removed subagent SADC in v9.1.0 and crawl4ai in v9.5.0 — phases.md must match"
  grep -nE 'Skill\(command="(crawl4ai|web-reader)"\)|subagent dispatched|Task\(subagent_type' skill/stellar-trails/procedure/phases.md
else
  echo "✓ Check 12: phases.md SADC step aligned with SKILL.md (no subagent dispatch, no crawl4ai/web-reader invocations)"
fi
```

#### Check 13: Path integrity — all referenced files exist (NEW v9.11.5)
```bash
# Catches broken file references left behind when files/dirs are moved or deleted.
# Verifies every (references|procedure|knowledge|constraints)/path/to/file.md mentioned
# in any skill file actually exists on disk. Would have caught the v9.11.4 regression
# where knowledge/universal/ and knowledge/platform/ subdirs were deleted but refs in
# constraints/code-standards.md, knowledge/error-patterns.md, procedure/error-resolution.md
# were not updated.
python3 << 'PYEOF'
import os, re, subprocess
SKILL_DIR = 'skill/stellar-trails'
# Collect all file-path references from all .md files in the skill
ref_pattern = re.compile(r'(?:references|procedure|knowledge|constraints)/[a-zA-Z0-9_/-]+\.md')
missing = []
files_scanned = 0
for root, dirs, files in os.walk(SKILL_DIR):
    for fname in files:
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(root, fname)
        files_scanned += 1
        with open(fpath) as f:
            content = f.read()
        for match in ref_pattern.finditer(content):
            ref = match.group(0)
            full = os.path.join(SKILL_DIR, ref)
            if not os.path.exists(full):
                # Allow references that are documentation of removal (e.g., "formerly in procedure/templates/")
                # — but only if the line contains "formerly" or "removed" or "REMOVED"
                line_start = content.rfind('\n', 0, match.start()) + 1
                line_end = content.find('\n', match.end())
                line = content[line_start:line_end if line_end > 0 else len(content)]
                if any(kw in line.lower() for kw in ['formerly', 'removed', 'deprecated', 'was dead code']):
                    continue
                missing.append(f"  {fpath}: {ref}")
if missing:
    print(f"✗ Check 13 FAIL: {len(missing)} broken file reference(s):")
    for m in missing:
        print(m)
else:
    print(f"✓ Check 13: all file references valid ({files_scanned} files scanned)")
PYEOF
```

#### Check 14: .zscripts/dev.sh git-tracked + hash matches skill copy (NEW v9.11.9)
```bash
# Verifies that .zscripts/dev.sh is git-tracked (not ignored by .gitignore)
# AND that its hash matches skill/stellar-trails/dev.sh (the zip source).
# Catches: .gitignore regression (re-ignoring .zscripts/), dev.sh drift between
# the tracked runtime copy and the zip source.
if git ls-files --error-unmatch .zscripts/dev.sh >/dev/null 2>&1; then
  SKILL_HASH=$(sha256sum skill/stellar-trails/dev.sh | cut -d' ' -f1)
  ZSCRIPTS_HASH=$(sha256sum .zscripts/dev.sh | cut -d' ' -f1)
  if [ "$SKILL_HASH" != "$ZSCRIPTS_HASH" ]; then
    echo "✗ Check 14 FAIL: .zscripts/dev.sh hash mismatch"
    echo "  skill/stellar-trails/dev.sh: $SKILL_HASH"
    echo "  .zscripts/dev.sh:            $ZSCRIPTS_HASH"
    echo "  Fix: cp -f skill/stellar-trails/dev.sh .zscripts/dev.sh"
  else
    echo "✓ Check 14: .zscripts/dev.sh tracked + hash matches skill copy ($ZSCRIPTS_HASH)"
  fi
else
  echo "✗ Check 14 FAIL: .zscripts/dev.sh is NOT git-tracked — check .gitignore exception"
  echo "  Expected pattern in .gitignore: .zscripts/* + !.zscripts/dev.sh"
  echo "  Or run: git add -f .zscripts/dev.sh"
fi
```

#### Worklog Snapshot + L1 Pattern Skeleton (bash-enforced v9.14.0)
```bash
# Bash guarantees worklog entry + L1 pattern skeleton at DELIVER
# LLM fills in [brackets] after bash creates skeleton
cat >> /home/z/my-project/worklog.md << ST_WL_EOF
---
last_phase: DELIVER
timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
version: v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
task: [LLM fills]
complexity: [LLM fills]
task_type: [LLM fills]
files_modified: [LLM fills]
phase_trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
ST_WL_EOF
echo "✓ Worklog skeleton appended (LLM: fill in [brackets] above)"
# L1 pattern skeleton (bash guarantees template structure)
echo "## [$(date -u '+%Y-%m-%d')] <domain>: <pattern-name>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Context**: <when applies>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Approach**: <what worked>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Gotcha**: <what to avoid>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Source**: <task>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "✓ L1 pattern skeleton appended (LLM: fill in <brackets>)"
```

### When to skip Pre-Push Local Verification

- Documentation-only changes (CHANGELOG.md, README.md) → skip checks 2-6, run 1+7+8
- Version bump commits (just `sed` + commit) → run checks 4+5+6+9
- Changes to files that have no executable code (pure markdown prose) → skip checks 2-3

**Never skip**: checks 1 (bash syntax), 8 (markdown fences), 9 (post-push plan)

### Cost-benefit

- **Cost**: 60-90 seconds of local testing (up from 30-60s in v9.2.0)
- **Benefit**: catches 5 bug classes that slipped through v9.2.0's 4 checks
- **Bug classes caught by v9.7.0 additions**:
  - python3 -c execution errors (would have caught v9.0.1 IndentationError)
  - grep pattern failures (would have caught v9.1.0 unescaped `**`)
  - banner version drift (would have caught v9.2.1 hardcoded v9.1.0)
  - tag collision (would have caught duplicate tag pushes)
  - moderation hide (would have caught v9.6.0 publish-not-registering)
  - post-push registry verification (would have caught v9.6.0 silent publish failure)

### Anti-patterns (FORBIDDEN)

- ❌ "bash -n passed, ship it" — bash -n is necessary but NOT sufficient. Run all 9 checks.
- ❌ "Skip check 6, registry was fine last time" — moderation state can change between pushes. Always check.
- ❌ "Skip check 9, CI will tell us" — CI success ≠ registry update. v9.6.0 proved this. Always poll registry post-push.
- ❌ "Check 2 takes too long" — 5 seconds per python3 -c block. Worth it to avoid CI cycle.

---

