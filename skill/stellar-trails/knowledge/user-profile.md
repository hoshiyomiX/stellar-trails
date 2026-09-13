# User Profile (L3 Memory)

Stable user preferences and recurring decision patterns.
Auto-extracted when same decision pattern repeats ≥3 times across sessions.

---

## Preferences:
- Prefers direct Edit tool over patch files (patch files are "junk")
- PAT kept permanently at [PAT_PATH] until sandbox closes
- Wants version bumps on every change, even small fixes (patch version)
- Prefers Indonesian language for explanations, English for code/commits
- Wants commits pushed immediately after fix, no waiting for batch
- Prefers orisinil features over wrapper skills (not a wrapper)
- Values honest assessment over optimistic claims (called out overstatement twice)

## Recurring decisions:
- When fixing bugs: fix all same-surface bugs in one commit, defer different-surface
- When CI fails: fetch logs first, apply Proximate Cause Triage, don't rabbit-hole
- When skill version drift: [UPDATE_CMD], then sync zip immediately
- When index.html version stale: Check 10 catches it, fix in same commit

## Working style:
- Tests fixes live before pushing (Pre-Push Local Verification)
- Monitors CI after push (Check 9: registry poll)
- Cleans up work dir after each task
- Appends worklog entry at DELIVER phase
