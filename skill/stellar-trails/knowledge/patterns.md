# Pattern Library (L1 Memory)

Auto-extracted reusable patterns from stellar-trails tasks.
Adapted from TencentDB-Agent-Memory L1 Atom concept.

---

## [2026-07-08] ci: Python3 -c IndentationError from bash single-quote preservation
**Context**: Writing python3 -c blocks inside bash single-quoted strings in SKILL.md
**Approach**: Use single-line python3 -c with double quotes, not multi-line with single quotes
**Gotcha**: Bash single quotes preserve ALL whitespace literally — Python IndentationError on indented first line
**Source**: v9.0.1 → v9.0.2 transition (CI run #58 failed)

## [2026-07-08] clawhub: Soft-deleted slug blocks publish registration
**Context**: Running `clawhub delete` locally then expecting CI publish to work
**Approach**: Always run `clawhub undelete --yes` before publish in CI workflow
**Gotcha**: `clawhub skill publish` exits 0 even when slug is hidden — version never appears on registry
**Source**: v9.0.0 → v9.0.1 transition (CI runs #56, #57 failed)

## [2026-07-09] git: Z User identity override requires env vars, not just config
**Context**: /start.sh sets global git config to Z User — commits show wrong author
**Approach**: Override with `# git config (removed in v9.18.0)` + `GIT_AUTHOR_*` + `GIT_COMMITTER_*` env vars
**Gotcha**: `git -c` flags only set per-command config, committer falls back to global Z User
**Source**: v9.9.0 Git Identity Setup

## [2026-07-09] git: [CREDENTIAL_FILE] not in repo.tar, wiped each session
**Context**: Git credentials stored in $HOME, not in /home/z/my-project/
**Approach**: Re-create [CREDENTIAL_FILE] from PAT at each session start (auto in Step 1 since v9.10.1)
**Gotcha**: repo.tar only archives /home/z/my-project/ — anything in $HOME is lost on session reset
**Source**: v9.9.0 Git Identity Setup

## [2026-07-10] dev.sh: Background python3 + wait causes SIGHUP race condition
**Context**: dev.sh v8.0.0 used `python3 &` + `wait $CHILD_PID` for crash recovery
**Approach**: Keep python3 in FOREGROUND (v7.2.2 architecture) — no &, no wait
**Gotcha**: Background python3 in different process group gets killed by SIGHUP while bash wrapper survives
**Source**: v9.10.0 dev.sh v9.0.0 (improved from v7.2.2, rejected v8.0.0 bugs)

## [2026-07-26] markdown: Literal triple-backticks inside bash blocks cause fence self-reference
**Context**: Check 8 bash block contained `grep -c '```'` which inflated fence count
**Approach**: Use `printf '\x60\x60\x60'` hex escape instead of literal backticks
**Gotcha**: Markdown parser counts ``` inside code blocks as fence delimiters → odd count → orphan blocks
**Source**: v9.10.2 markdown fence self-reference fix
