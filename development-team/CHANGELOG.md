# Changelog — development-team

All notable changes to this configuration are documented here.
Format: [MAJOR.MINOR.PATCH] — YYYY-MM-DD

---

## [1.6.0] — 2026-06-18

### Added
- **Карта навыков (`skills/README.md`)** — единый реестр всех навыков: назначение,
  кто вызывает, триггер, зависимости/порядок, фолбэк. Источник истины по
  диспетчерскому слою, чтобы решения «какой навык когда» не расползались по
  агентам по мере роста их числа. Система остаётся модульной: новые техники
  промптинга добавляются отдельными маленькими навыками, карта удерживает обзор.
  - дисциплина «3 касания» при изменении состава навыков (навык → карта → вызов)
  - `AGENTS.md` (секция «How Skills Work») — указатель на карту
- **Линтер карты (`skills/check-skill-map.sh`)** — POSIX-sh без зависимостей,
  проверяет целостность «каждый навык ↔ строка в карте» в обе стороны. Exit 1
  при расхождении. Пригоден для локального запуска и CI.

### Changed
- **`README.md` (development-team)** актуализирован: новый подраздел «Навыки
  (skills)» (модель исполнения + карта), дерево структуры отражает `skills/README.md`
  и `check-skill-map.sh`, в «Проверку после установки» добавлен прогон линтера карты.

---

## [1.5.0] — 2026-06-18

### Changed
- **Навыки переописаны как инструкции, а не вызываемые функции.** Раньше каждый
  `SKILL.md` был оформлен в RPC-стиле («Шаг 1. Прими вход» → «Шаг N. Верни результат
  `{...}`»), а агенты инструктировались «вызови `skill(...)` передав X → получи из
  навыка Y». Это создавало ложное ожидание возвращаемого значения: в opencode вызов
  навыка лишь подгружает текст `SKILL.md` в контекст вызывающего агента, который сам
  выполняет процедуру. На практике агент-координатор по нескольку раз дёргал
  `psao-annotate`, ожидая возврат `psao_prompt`, получал тот же текст инструкции,
  тратил минуты reasoning и в итоге выполнял аннотирование вручную — недетерминированно
  и с риском молчаливого пропуска на слабых моделях.
  - `AGENTS.md` — новая секция «How Skills Work (execution model) — READ FIRST» как
    единый источник истины по модели исполнения навыков
  - все 22 `skills/*/SKILL.md` — шапка-предохранитель «⚙️ Это навык-инструкция, а не
    функция» сразу после frontmatter
  - секции входа/выхода переописаны: «Прими вход» → «Собери входные данные» (данные
    уже в контексте), «Верни результат» → «Сформируй результат» (встрой в свой ответ,
    повторного вызова нет)
  - `task-delegation-format` (Шаг 3.5.2) — инструкция применения PSAO больше не
    подразумевает возврат значения от `psao-annotate`
  - `team-lead.md`, `tester.md`, `reviewer.md`, `guardian.md`, `memory-update` —
    формулировки «передай навыку X → навык вернёт Y» приведены к in-context модели

## [1.4.0] — 2026-06-16

### Added
- **Функциональный гейт приёмки** — провалившиеся тесты больше не могут пройти в ACCEPT.
  Ранее `guardian-verdict` явно не давал test_outcome переопределять severity-решение,
  поэтому FAILED-тест мог дойти до ACCEPT, если Guardian не зафиксировал отдельный
  CRITICAL-finding (например, при пропуске зоны Test Analysis под context-лимитом).
  - `guardian-verdict` — новое Правило 0: `test_outcome == FAILED` или `p0_failed`
    понижает рекомендацию минимум до REWORK; провал P0 непереопределяем (как BLOCKER).
    Добавлен вход `p0_failed`
  - `guardian.md` — передаёт `p0_failed` в `guardian-verdict`
  - `team-lead.md` — критерий ACCEPT дополнен обязательным предусловием «P0 = 100% PASSED»
  - `README.md` — раздел «Верификация» описывает функциональный гейт
- `test-progress` — новое терминальное решение `STOP_COMPLETE` для случая полного покрытия
  (100% P0+P1+P2). Раньше такой прогон помечался `STOP_PARTIAL` и ошибочно получал
  секцию «PARTIAL COMPLETION» / итог PARTIAL при фактически полном покрытии
  - `tester.md` — добавлено решение STOP_COMPLETE в execution loop

### Changed
- `guardian-scope` — порядок зон анализа приведён к `guardian.md`:
  security → correctness → **test_analysis** → code_quality → tech_debt (раньше test_analysis
  стоял после code_quality, что противоречило агенту и грозило отбрасыванием анализа тестов
  под context-лимитом)
- `guardian.md` — устранён конфликт «confidence понижает severity». Теперь severity и
  confidence ортогональны (как и предписывает `confidence-calibrate` и `guardian-severity`):
  низкая уверенность аннотируется, но НЕ смягчает severity (CRITICAL с confidence 30%
  остаётся CRITICAL с пометкой «требует дорасследования»)

### Fixed
- `tester.md` — уточнена область права edit на `tests/**` (написание автотестов под план;
  запрет на правку исходников «ради зелёного теста»)
- `incident-protocol` — в список критических секций tester'а явно добавлено «P0 < 100% ⇒
  INSUFFICIENT» (KPI Tester'а раньше не был назван в таблице достаточности покрытия)
- `task-metrics` — унифицированы ключи агентов в `agents_used`: дефис (`coder-front`/`coder-back`)
  как в opencode.json, вместо смешения с подчёркиванием

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
