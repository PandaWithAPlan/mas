# Changelog — development-team

All notable changes to this configuration are documented here.
Format: [MAJOR.MINOR.PATCH] — YYYY-MM-DD

---

## [1.3.1] — 2026-06-16

### Fixed
- `CHECKLIST.md` drifted from the actual `project-config/AGENTS.md` template and configs;
  realigned end-to-end:
  - Step 1 — copy path corrected to project **root** (`./opencode.json`, `./AGENTS.md`)
    instead of nesting under `.opencode/project-config/`
  - Step 3 — section names and `[ЗАПОЛНИТЬ]` markers now match the real template
    («Назначение директорий», «Технологический стек и ключевые подсистемы»,
    «Ключевые внешние зависимости», «Зоны ответственности», «Применение глобального процесса»)
  - Step 4 — test-results path corrected to `work-area/reports/test-results/`; added
    creation of `work-area/docs/` and `work-area/reports/`; added `metrics.json` init
  - Step 5 — clarified JSONC validation for the project config; added the critical
    coder-permission-merge verification step
  - checklist version bumped to 1.3.1 (was stale at 1.1.0)
- `README.md` — security-model section now accurately describes `sudo` (deny for all
  executors except `devops` = ask) and `git commit` handling (coders = ask,
  tester/guardian/devops = deny); post-install JSON-validation note distinguishes
  strict JSON (global) from JSONC (project).

---

## [1.3.0] — 2026-06-16

### Added
- Documentation-debt handling for pre-existing undocumented modules not touched
  by the current task (previously such modules stayed undocumented indefinitely
  with no rule obliging Team Lead to close the gap).
  - `doc-scan-rules` — each gap now gets a deterministic priority (HIGH/MED/LOW)
    based on coupling and critical zone; priority surfaced in the doc index table
  - `team-lead.md` — new "Документационный долг" rule with deterministic thresholds:
    HIGH gap → dedicated doc-task this cycle; 3+ MED in task zones → one doc-task;
    isolated LOW/MED → deferred and logged in session (no scope bloat)

---

## [1.2.0] — 2026-06-16

### Changed
- Documentation skills reworked to stop proliferation of duplicate docs files.
  Root cause: `[module-name]` had no deterministic generation rule, so each run
  invented a new filename and created a new doc instead of updating the existing one.
  - `doc-update-module` — introduced deterministic `canonical_path` rule
    (source path → `docs/<path-with-dashes>.md`), mandatory existence check before
    create, explicit ban on creating a second doc for the same source file
  - `doc-scan-rules` — now emits a "Индекс документации" table (source → canonical_path
    → status) so coders look up the name instead of guessing; added duplicate detection
  - `doc-update-arch` — explicit single-file rule for `full-project-architecture-note.md`,
    ban on creating a second architecture file
  - `doc-consistency-check` — added duplicate/orphan detection as BLOCKER (step 0)

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
