---
name: Stellar Trails
tagline: Structured six-phase workflow for LLM agents
topics:
  - agent-workflow
  - phase-machine
  - llm-agents
  - task-management
  - traceability
  - zai
---

# Stellar Trails

Structured six-phase workflow for LLM agents. Traceability IDs, entry/exit gates, scope
commitment, and adaptive complexity — without shell execution or persistent hooks.

## What It Does

Structures every task as a **six-phase workflow**:

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
```

- **Coding tasks**: full phases with Traceability IDs (IMPL-001, IMPL-002...)
- **Non-coding tasks** (questions, explanations): Minimal tier — phases run
  internally, only IMPLEMENT produces visible output
- **Adaptive complexity**: Minimal, Simple, Standard, Complex — all 6 phases
  always run, only ceremony adjusts

## Key Features

| Feature | Description |
|---------|-------------|
| Workflow Phases | IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER |
| Traceability IDs | IMPL-001 chains through every phase — gaps are visible |
| Adaptive Complexity | Minimal/Simple/Standard/Complex tiers |
| Source Verification | SSV (git fetch before analysis) + SADC (research before planning) |
| File-based Memory | Permanent Memory + dated files for cross-session continuity |
| Error Decision Tree | 5-step: capture → classify → identify → fix → re-verify |
| Pure Markdown by Design | No shell execution in Skill() invoke — pure markdown data |

## Install

```bash
clawhub install stellar-trails
```

## Invoke

```
Skill(command="stellar-trails")
```

## Source

- **ClawHub**: https://clawhub.ai/hoshiyomix/stellar-trails
- **GitHub**: https://github.com/hoshiyomiX/stellar-trails
- **Changelog**: https://github.com/hoshiyomiX/stellar-trails/blob/main/skill/stellar-trails/CHANGELOG.md

## License

MIT-0 (Free to use, modify, and redistribute. No attribution required.)
