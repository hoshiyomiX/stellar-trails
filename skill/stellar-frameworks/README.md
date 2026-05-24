# Stellar Frameworks

Structured development framework for GLM — a phase state machine with traceability IDs, phase gates, scope commitment, and adaptive complexity.

## Quick Start

```bash
[ -d ~/.stellar-frameworks-repo ] || git clone https://github.com/hoshiyomiX/stellar-frameworks.git ~/.stellar-frameworks-repo
bash ~/.stellar-frameworks-repo/boot.sh
```

After install, the skill triggers automatically on every task. Manual activation:

```
Skill(command="stellar-frameworks")
```

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 5.11.0 | 2026-05-21 | Major refactor: repo-wide version sync, dead asset removal, single-source version extraction |
| 5.11.x patches | 2026-05-24 | Force-sync (contamination fix), boot.sh co-location, 3-layer activation fallback, cp-a persistence, cross-trigger guard |
| 5.10.0 | 2026-05-21 | Skill-creator audit: dead refs, dead asset, description optimization, README created |
| 5.9.0 | 2026-05-19 | Hook silent error fix, empty SKILL.md detection, health check fallback, git staging for repo.tar |

See [CHANGELOG.md](CHANGELOG.md) for full history.

## Architecture

```
stellar-frameworks/               (repo root)
├── boot.sh                        # Self-heal installer (clone, cp-a, hook, force-sync)
└── skill/stellar-frameworks/
    ├── SKILL.md                   # Skill definition (activation + framework reference)
    ├── boot.sh                    # Co-located copy — ensures boot.sh is always discoverable
    ├── memory-template.md         # Memory system templates & storage rules
    ├── procedure/
    │   ├── phases.md              # 6-phase state machine definitions + gates
    │   ├── templates/             # Output templates (problem-spec, implementation-plan, incident-report, verification-report)
    │   └── decision-trees/        # Error resolution + pivot assessment
    ├── knowledge/
    │   ├── platform/              # Z.ai sandbox constraints
    │   └── universal/             # Architecture, conventions, error patterns
    ├── constraints/               # Code standards + type safety rules
    └── CHANGELOG.md               # Detailed version history
```

## Phase Machine

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Error Recovery ◄───────────────────┘
```

## License

MIT
