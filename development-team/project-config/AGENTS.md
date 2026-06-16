# AGENTS.md — локальная карта проекта

Этот файл описывает структуру конкретного проекта и уточняет,
как глобальная агентная схема применяется к данному репозиторию.

Глобальные правила orchestration, handoff, ролей и жизненного цикла задачи
задаются корневым `AGENTS.md` (`global-config/AGENTS.md`).
Если локальный файл не переопределяет правило явно, действует глобальная схема.

---

## КАК АДАПТИРОВАТЬ ЭТОТ ШАБЛОН

1. Заполни **«Назначение директорий»** — структуру репозитория проекта.
2. Заполни **«Технологический стек»** — языки, фреймворки, БД, внешние сервисы.
3. Заполни **«Ключевые внешние зависимости»** — если есть MCP-серверы, очереди, внешние API.
4. В **«Зоны ответственности»** укажи конкретные директории `coder-front` и `coder-back`
   (должны совпадать с `project-config/opencode.json`).
5. Удали все блоки с пометкой `[ЗАПОЛНИТЬ]` после заполнения.
6. Не трогай разделы без пометок — они содержат универсальную логику.

---

## Назначение директорий

<!-- [ЗАПОЛНИТЬ] Замени дерево ниже на реальную структуру репозитория проекта.
     Обязательно укажи владельца (coder-front / coder-back / devops / team-lead)
     для каждой ключевой директории. work-area/ не трогай — он стандартный. -->

```text
PROJECT_ROOT/
├── [ТОЧКА ВХОДА]                       ← [владелец: coder-back / devops]
├── [КОНФИГ ЗАВИСИМОСТЕЙ]               ← [владелец: coder-back / devops]
├── [ФРОНТЕНД ДИРЕКТОРИЯ]/              ← [владелец: coder-front]
├── [БЭКЕНД ДИРЕКТОРИЯ]/                ← [владелец: coder-back]
├── [ТЕСТЫ]/                            ← [владелец: tester / coder-back]
├── [ДОКУМЕНТАЦИЯ]/                     ← [владелец: coder-back / reviewer]
├── [ИНФРАСТРУКТУРА]/                   ← [владелец: devops]
└── work-area/                          ← служебные артефакты агентного цикла
    ├── memory/
    │   ├── global-memory.md            ← точка входа: контекст задачи (владелец: team-lead)
    │   ├── conceptual.md               ← сжатые эвристики и уроки ≤10 (владелец: team-lead)
    │   ├── procedural.json             ← хронология действий агентов (владелец: team-lead)
    │   ├── feedback.json               ← результаты тестов и вердикты Guardian (владелец: team-lead)
    │   └── metrics.json                ← итоговые метрики закрытых задач (владелец: team-lead)
    ├── docs/
    │   ├── explore-report.md           ← артефакт explorer
    │   ├── requirements.md             ← артефакт analyst
    │   └── design.md                   ← артефакт architect
    ├── tasks/
    │   ├── DEV-FRONT-NNN.md            ← team-lead → coder-front
    │   ├── DEV-BACK-NNN.md             ← team-lead → coder-back
    │   └── TEST-NNN.md                 ← team-lead → tester
    ├── reports/
    │   ├── test-results/
    │   │   └── TR-NNN.md               ← tester, цикл N
    │   ├── guardian-NNN.md             ← guardian, цикл N
    │   ├── devops-status.md            ← devops, preflight gate / инфраструктурные изменения
    │   └── final-report-NNN.md         ← reviewer, итоговый отчёт
    └── sessions/
        └── session-YYYY-MM-DD.md       ← журнал текущей и прошлых сессий (владелец: team-lead)
```

---

## Технологический стек и ключевые подсистемы

<!-- [ЗАПОЛНИТЬ] Заполни таблицу под свой проект. Удали неиспользуемые строки. -->

| Слой | Технология | Специфика (директории, файлы, особенности) |
|------|-----------|---------------------------------------------|
| Бэкенд | [язык + фреймворк] | [директории] |
| Фронтенд | [язык + фреймворк / vanilla] | [директории] |
| База данных | [СУБД] | [путь к файлу БД или хост] |
| Тестирование | [фреймворк] | [директория тестов, конфиг] |
| Контейнеризация | [Docker / compose / k8s / нет] | [файлы конфигурации] |
| [Другой слой] | [технология] | [специфика] |

### Ключевые внешние зависимости

<!-- [ЗАПОЛНИТЬ] Опиши внешние MCP-серверы, API, очереди, inference-серверы.
     Для каждого укажи: назначение, критичность, известные проблемы и связанные эвристики.
     Если внешних зависимостей нет — удали этот подраздел. -->

- **[Зависимость 1]** — [описание, назначение, критичность].
  Известная проблема / ограничение: [описание]. Эвристика: `[НАЗВАНИЕ-ЭВРИСТИКИ]`.

- **[Зависимость 2]** — [описание].

---

## Навыки (skills)

Навыки загружаются агентами через `skill({ name: "..." })`. Живут в `global-config/skills/`.

### Навыки памяти (MALMAS-паттерн)

| Навык | Потребители | Когда |
|-------|------------|-------|
| `memory-retrieve` | Все агенты (explorer, analyst, architect, coder-front, coder-back, tester, guardian, reviewer, devops, team-lead) | Первым шагом при получении задачи |
| `memory-update` | `team-lead` | После завершения Guardian в каждом цикле |
| `memory-summarize` | `team-lead` (вызывается из `memory-update`) | Сжатие ProcMem + FeedMem → ConMem + GlobalMem через LLM (MALMAS Summary-Agent) |

### Навыки процесса

| Навык | Потребители | Когда |
|-------|------------|-------|
| `session-init` | `team-lead` | Intake: создание session-YYYY-MM-DD.md |
| `complexity-parallel` | `team-lead` | После оценки сложности: конфигурация параллелизации агентов |
| `devops-gate-check` | `team-lead`, `tester`, `coder-front`, `coder-back` | Перед операциями, потенциально зависящими от инфраструктуры |
| `incident-protocol` | `team-lead` | При зависании субагента или PARTIAL COMPLETION |
| `task-delegation-format` | `team-lead` | При каждой постановке задачи подчинённому агенту |
| `psao-annotate` | `team-lead` | При делегировании с complexity ≥5, REWORK-циклах или critical constraints: PSAO-аннотирование промпта для предотвращения семантического дрейфа (Step 3.5 PSAO Gate внутри task-delegation-format) |
| `task-metrics` | `team-lead` | После ACCEPT или ESCALATE: запись метрик в metrics.json |
| `test-plan` | `tester` | Pre-flight: приоритизация тест-кейсов (P0/P1/P2) на основе affected zones и истории провалов |
| `test-progress` | `tester` | После каждого тест-кейса / группы: самодиагностика — CONTINUE / SCOPE_REDUCE / STOP_PARTIAL |
| `guardian-scope` | `guardian` | Pre-flight: приоритизированный план анализа (security → correctness → code_quality → tech_debt) |
| `guardian-severity` | `guardian` | Для каждого finding: severity scoring по матрице BLOCKER/CRITICAL/SIGNIFICANT/MINOR/INFO |
| `guardian-verdict` | `guardian` | Post-analysis: formal recommendation engine — RECOMMEND ACCEPT/REWORK/ESCALATE с reasoning |
| `confidence-calibrate` | `guardian`, `architect` | Для каждого значимого finding/оценки: формальная калибровка уверенности 0–100% по 4 критериям |
| `report-data-extract` | `reviewer` | Pre-flight: извлечение структурированных данных из всех артефактов задачи |
| `html-report` | `reviewer` | После extract и doc-check: генерация HTML-отчёта с CSS, таблицами и Mermaid-диаграммами |

### Навыки документирования

| Навык | Потребители | Когда |
|-------|------------|-------|
| `doc-scan-rules` | `explorer` | При наличии папки `docs/`: сканирование состояния документации |
| `doc-update-arch` | `architect` | После финализации design.md: обновление архитектурной документации |
| `doc-update-module` | `coder-front`, `coder-back` | После завершения реализации: обновление документации изменённых модулей |
| `doc-consistency-check` | `reviewer` | Перед финальным отчётом: проверка согласованности документации |

---

## Локальные правила проекта

### Память (MALMAS-паттерн)

Базовые MALMAS-правила (memory-retrieve первым шагом, memory-update после цикла, проверка
procedural.json, использование feedback.json, эвристики conceptual.md) — см. глобальный
`global-config/AGENTS.md`, секция «MALMAS Rules».

Локальное дополнение:
- `work-area/memory/MEMORY.md` заморожен. Новые знания фиксируются только через MALMAS-слои.

### Приоритет правил

При конфликте инструкций применяется следующий порядок:

1. Глобальные правила (`global-config/AGENTS.md`) — orchestration, handoff, роли, жизненный цикл задачи.
2. Локальные правила (этот файл) — зоны ответственности, конвенции, ограничения проекта.
3. **Эвристики `conceptual.md`** — извлечённые уроки из предыдущих циклов. При конфликте с общим правилом эвристика имеет приоритет.
4. **Контекст `global-memory.md`** — рекомендации для конкретных агентов на основе последнего цикла (секция «Для следующего агента»).

### Зоны ответственности

<!-- [ЗАПОЛНИТЬ] Строки с FRONTEND_DIR и BACKEND_DIR замени на реальные директории.
     Должны совпадать с project-config/opencode.json → agent.coder-*.permission.edit. -->

- `work-area/tasks/*.md` создаёт и актуализирует только `team-lead`.
- `work-area/docs/*.md` принадлежат соответствующим агентам проектной команды.
- `work-area/reports/test-results/TR-NNN.md` создаёт только `tester`.
- `work-area/reports/guardian-NNN.md` создаёт только `guardian`.
- `work-area/reports/devops-status.md` создаёт и обновляет `devops` в режиме Preflight Gate.
- `work-area/reports/final-report-NNN.md` создаёт только `reviewer`.
- `work-area/memory/*` (все файлы памяти, кроме MEMORY.md) — владелец `team-lead`.
- `coder-front` работает исключительно в: `[FRONTEND_DIR]/` (и только там).
- `coder-back` работает исключительно в: `[BACKEND_DIR_1]/`, `[BACKEND_DIR_2]/`, ... (и только там).
- Другие агенты могут читать артефакты, но не должны изменять их без явного указания Team Lead.

### DevOps Gate

DevOps Gate обязателен согласно глобальным Routing Rules и Critical Gotchas (`global-config/AGENTS.md`).

Локальные уточнения:
- Подключение — только через навык `devops-gate-check`. Безусловный вызов @devops **не допускается**.
- Навык проверяет 4 критерия (окружение, БД/кэш/очереди, env-переменные, сервисы) и принимает решение: gate required / not required.

### Конвенция именования артефактов

- **Все новые артефакты используют строго 3-значный номер цикла (`NNN`):**
  - `DEV-FRONT-NNN.md`, `DEV-BACK-NNN.md`, `TEST-NNN.md`
  - `TR-NNN.md`, `guardian-NNN.md`, `final-report-NNN.md`
  - `session-YYYY-MM-DD.md` (без номера цикла)
- **Суффиксы `-retry`, `-diagnostic` и даты в именах отчётов запрещены.** При повторном запуске агента в том же цикле — перезапись существующего артефакта (с пометкой в `procedural.json`).
- **`work-area/docs/` содержит только 3 канонических файла:** `explore-report.md`, `requirements.md`, `design.md`. При параллельных задачах Team Lead создаёт отдельные сессии.

### Протокол инцидентов

При зависании субагента или PARTIAL COMPLETION Team Lead вызывает `skill({ name: "incident-protocol" })` согласно глобальным Routing Rules. Навык классифицирует инцидент и выдаёт решение SUFFICIENT / INSUFFICIENT / ESCALATE.

---

## Разграничение артефактов

<!-- Этот раздел не требует адаптации — он описывает стандартную структуру work-area. -->

- `[DOCS_DIR]/` — документация проекта и продукта (не артефакты агентного цикла).
- `[TESTS_DIR]/` — тестовый код проекта (не отчёты Tester).
- `work-area/docs/` — служебные артефакты проектного цикла (explore-report, requirements, design).
- `work-area/tasks/` — задачи на реализацию и тестирование.
- `work-area/reports/test-results/` — результаты функционального тестирования.
- `work-area/reports/guardian-NNN.md` — инженерное заключение по качеству и безопасности.
- `work-area/reports/devops-status.md` — статус инфраструктуры (Preflight Gate / изменения).
- `work-area/reports/final-report-NNN.md` — пользовательский итоговый отчёт.
- `work-area/sessions/` — журнал решений, циклов и инцидентов.
- `work-area/memory/global-memory.md` — точка входа: контекст задачи, ограничения, уроки.
- `work-area/memory/conceptual.md` — сжатые эвристики и извлечённые уроки.
- `work-area/memory/procedural.json` — машиночитаемая хронология действий агентов.
- `work-area/memory/feedback.json` — связка тест→вердикт→зоны в машиночитаемой форме.
- `work-area/memory/metrics.json` — агрегированные метрики закрытых задач.
- `work-area/memory/MEMORY.md` — ⚠ ЗАМОРОЖЕН (заменён MALMAS-слоями).

## Локальные ограничения

- Не перемещать и не переименовывать корневые директории без явной задачи.
- Не сохранять служебные артефакты в директориях проекта (бэкенд, фронтенд, тесты, документация).
- Все промежуточные материалы агентного цикла сохранять только в `work-area/`.
- Не считать директорию тестов заменой отчётам Tester (`work-area/reports/test-results/`).
- Не считать директорию документации заменой артефактам `work-area/docs/`.
- Не дублировать действия из `procedural.json` со статусом FAILED.
- Не вызывать @devops напрямую — только через `devops-gate-check`.

---

## Применение глобального процесса

Базовый процесс (Routing Rules, Critical Gotchas, DevOps Modes, MALMAS Rules, Team Lead Quick Reference)
задан в глобальном `global-config/AGENTS.md` и **не дублируется** здесь.

Ниже — только локальные уточнения и переопределения:

<!-- [ЗАПОЛНИТЬ] После заполнения разделов выше — кратко перечисли здесь ключевые локальные уточнения.
     Шаблон строк уже готов, подставь реальные значения. -->

- **Зоны ответственности:** `coder-front` → `[FRONTEND_DIR]/`; `coder-back` → `[BACKEND_DIRS]` — см. секцию «Зоны ответственности».
- **Конвенция нумерации:** все артефакты используют строго 3-значный номер цикла (`NNN`) — см. секцию «Конвенция именования артефактов».
- **DevOps Gate:** обязателен для team-lead, coder-front, coder-back, tester — через `devops-gate-check`.
- **Максимум 3 REWORK-цикла**, Plateau Detection на cycle ≥2, эскалация при достижении лимита.
- **Scope discipline:** кодеры — только файлы из DEV-задачи; Guardian проверяет Scope Compliance.
- **Cross-stack API contracts:** Architect → «Сводка API-контрактов»; Team Lead верифицирует перед созданием task-файлов.
