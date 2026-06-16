# Changelog — development-team

All notable changes to this configuration are documented here.
Format: [MAJOR.MINOR.PATCH] — YYYY-MM-DD

---

## [1.1.0] — 2026-06-16

### Changed
- `project-config/opencode.json` — converted from Odysseus-specific config to reusable template;
  replaced hardcoded paths and directories with annotated placeholders (`[ЗАПОЛНИТЬ]`)
- `project-config/AGENTS.md` — converted from Odysseus-specific AGENTS to reusable template;
  replaced real directory structure, tech stack, external dependencies with generic placeholders;
  added "КАК АДАПТИРОВАТЬ ЭТОТ ШАБЛОН" section (6-step guide)

### Added
- `VERSION` — machine-readable current version
- `CHANGELOG.md` — this file
- `CHECKLIST.md` — step-by-step adaptation checklist for new projects

---

## [1.0.0] — 2026-06-16

### Added
- Initial upload: complete multi-agent system configuration
- `global-config/opencode.json` — 11 agents with models, permissions, secret deny-lists
- `global-config/AGENTS.md` — agent roster, routing rules, MALMAS pattern documentation
- `global-config/agents/` — 11 agent personality files (team-lead, explorer, analyst,
  architect, coder-front, coder-back, tester, guardian, devops, reviewer, ai-engineer)
- `global-config/skills/` — 22 skills across 6 categories:
  memory (3), process (6), testing/quality (5), documentation (4), confidence/decision (3), metrics (1)
- `project-config/opencode.json` — project-specific overrides (coder zones, LSP servers)
- `project-config/AGENTS.md` — project-specific rules and directory structure
- `README.md` — comprehensive system documentation
