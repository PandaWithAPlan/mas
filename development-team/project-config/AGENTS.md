# AGENTS.md — локальная карта проекта

Этот файл описывает структуру именно этого проекта и уточняет,
как глобальная агентная схема применяется к данному репозиторию.

Глобальные правила orchestration, handoff, ролей и жизненного цикла задачи
задаются корневым `AGENTS.md`.
Если локальный файл не переопределяет правило явно, действует глобальная схема.

## Назначение директорий

```text
odysseus/
├── app.py                              ← точка входа FastAPI (владелец: coder-back)
├── pyproject.toml                      ← конфигурация pytest (владелец: coder-back / devops)
├── package.json                        ← JS-зависимости (владелец: coder-front)
├── requirements.txt                    ← Python-зависимости (владелец: coder-back / devops)
├── docker-compose.yml                  ← основной Docker Compose (владелец: devops)
├── docker-compose.gpu-nvidia.yml       ← NVIDIA GPU-профиль (владелец: devops)
├── docker-compose.gpu-amd.yml          ← AMD GPU-профиль (владелец: devops)
├── Dockerfile                          ← образ приложения (владелец: devops)
├── opencode.json                       ← локальные переопределения конфигурации проекта
├── docs/                               ← пользовательская и проектная документация
├── tests/                              ← исходники автоматических тестов (pytest + bombadil)
├── src/                                ← Python-бэкенд: 83 модуля (владелец: coder-back)
│   ├── agent_loop.py                   ← основной цикл агента, MCP-роутинг
│   ├── tool_execution.py               ← исполнение инструментов, форматирование
│   ├── mcp_manager.py                  ← MCP-клиент, вызовы, coercion
│   └── ...
├── core/                               ← ядро: модели БД, авторизация, middleware (владелец: coder-back)
├── routes/                             ← API-эндпоинты: 48 модулей (владелец: coder-back)
├── services/                           ← бизнес-логика: search, memory, hwfit, stt, tts, youtube (владелец: coder-back)
├── companion/                          ← модуль companion-приложения (владелец: coder-back)
├── mcp_servers/                        ← встроенные MCP-серверы: email, image_gen, memory, rag (владелец: coder-back)
├── static/                             ← vanilla JS frontend (владелец: coder-front)
│   ├── app.js                          ← основное приложение
│   ├── style.css                       ← стили
│   ├── js/                             ← модули: chat.js, markdown.js, ...
│   └── lib/                            ← внешние библиотеки
├── scripts/                            ← CLI-утилиты (владелец: devops / coder-back)
├── docker/                             ← Docker-конфиги: entrypoint, GPU-профили (владелец: devops)
├── config/                             ← конфигурация: searxng (владелец: devops)
├── data/                               ← runtime-данные: app.db, chroma/, presets.json, ... (владелец: devops / runtime)
├── logs/                               ← директория логов (владелец: devops / runtime)
├── licenses/                           ← лицензии third-party компонентов
└── work-area/
    ├── memory/
    │   ├── global-memory.md             ← точка входа: контекст задачи для всех агентов (владелец: team-lead)
    │   ├── conceptual.md                ← сжатые эвристики и уроки (≤10 активных) (владелец: team-lead)
    │   ├── procedural.json              ← хронология действий агентов (владелец: team-lead)
    │   ├── feedback.json                ← результаты тестов и вердикты Guardian (владелец: team-lead)
    │   └── metrics.json                 ← итоговые метрики закрытых задач (владелец: team-lead)
    ├── docs/
    │   ├── explore-report.md            ← артефакт explorer
    │   ├── requirements.md              ← артефакт analyst
    │   └── design.md                    ← артефакт architect
    ├── tasks/
    │   ├── DEV-FRONT-NNN.md             ← team-lead → coder-front
    │   ├── DEV-BACK-NNN.md              ← team-lead → coder-back
    │   └── TEST-NNN.md                  ← team-lead → tester
    ├── reports/
    │   ├── test-results/
    │   │   └── TR-NNN.md                ← tester, цикл N
    │   ├── guardian-NNN.md              ← guardian, цикл N
    │   ├── devops-status.md             ← devops, preflight gate / инфраструктурные изменения
    │   └── final-report-NNN.md          ← reviewer, итоговый отчёт
    └── sessions/
        └── session-YYYY-MM-DD.md        ← журнал текущей и прошлых сессий (владелец: team-lead)
```

## Технологический стек и ключевые подсистемы

| Слой | Технология | Специфика |
|------|-----------|-----------|
| Бэкенд | Python 3.11 + FastAPI + uvicorn | `src/`, `core/`, `routes/`, `services/` |
| Фронтенд | Vanilla JavaScript (без фреймворков) | `static/app.js`, `static/js/*` |
| База данных | SQLite (`app.db`) + JSON-файлы | `data/app.db`, `data/sessions.json`, `data/settings.json` |
| Векторная БД | ChromaDB (встроенная) | `data/chroma/` — известная проблема: частые падения |
| Локальные модели | Ollama (native + API) | `src/agent_loop.py:_is_api_model` — native модели полагаются на `_MCP_KEYWORDS` |
| MCP-интеграция | streamable-http + fenced-block | `src/mcp_manager.py`, `mcp_servers/` |
| RAG | ChromaDB + FastEmbed | `src/rag_manager.py`, `src/rag_vector.py` |
| Workflow Engine | Встроенный планировщик цепочек | `src/workflow_engine.py` |
| Тестирование | pytest (`asyncio_mode=auto`) + bombadil | `tests/`, `pyproject.toml` |
| Контейнеризация | Docker Compose (3 профиля: default, nvidia, amd) | `docker-compose.yml`, `docker/` |

### Ключевые внешние зависимости

- **Zabbix MCP Server** — внешний MCP-сервер (44 инструмента), подключается через streamable-http. Критичен для задач мониторинга. Требует explicit whitelist для type coercion параметров (эвристика `CODER-USE-EXPLICIT-WHITELIST-FOR-COERCION`).
- **Ollama** — локальный inference-сервер. Модели: gemma4, qwen3.5, deepseek-v4, kimi-k2.6, glm5.1, minimax-m3. Native-модели (`is_api_model=False`) требуют русских + английских keywords в `_MCP_KEYWORDS` (эвристика `GLOBAL-LOCAL-MODEL-KEYWORD-FRAGILITY`).
- **ChromaDB** — встроенная векторная БД. Известная проблема: частые падения (эвристика `GLOBAL-CHROMADB-OFTEN-DOWN`). При недоступности ChromaDB система деградирует до keyword-fallback.

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

## Локальные правила проекта

### Память (MALMAS-паттерн)

Базовые MALMAS-правила (memory-retrieve первым шагом, memory-update после цикла, проверка procedural.json, использование feedback.json, эвристики conceptual.md) — см. глобальный `~/.config/opencode/AGENTS.md`, секция «MALMAS Rules».

Локальное дополнение:
- `MEMORY.md` заморожен. Новые знания фиксируются через MALMAS-слои.

### Приоритет правил

При конфликте инструкций применяется следующий порядок:

1. Глобальные правила (`~/.config/opencode/AGENTS.md`) — orchestration, handoff, роли, жизненный цикл задачи.
2. Локальные правила (этот файл) — зоны ответственности, конвенции, ограничения проекта.
3. **Эвристики `conceptual.md`** — извлечённые уроки из предыдущих циклов. При конфликте с общим правилом эвристика имеет приоритет (например, `CODER-USE-EXPLICIT-WHITELIST-FOR-COERCION` переопределяет общую практику pattern matching для type coercion).
4. **Контекст `global-memory.md`** — рекомендации для конкретных агентов на основе последнего цикла (секция «Для следующего агента»).

### Зоны ответственности

- `work-area/tasks/*.md` создаёт и актуализирует только `team-lead`.
- `work-area/docs/*.md` принадлежат соответствующим агентам проектной команды.
- `work-area/reports/test-results/TR-NNN.md` создаёт только `tester`.
- `work-area/reports/guardian-NNN.md` создаёт только `guardian`.
- `work-area/reports/devops-status.md` создаёт и обновляет `devops` в режиме Preflight Gate.
- `work-area/reports/final-report-NNN.md` создаёт только `reviewer`.
- `work-area/memory/*` (все файлы памяти, кроме MEMORY.md) — владелец `team-lead`.
- Другие агенты могут читать артефакты, но не должны изменять их без явного указания Team Lead.

### DevOps Gate

DevOps Gate обязателен согласно глобальным Routing Rules и Critical Gotchas (`~/.config/opencode/AGENTS.md`).

Локальные уточнения:
- Подключение — только через навык `devops-gate-check`. Безусловный вызов @devops **не допускается**.
- Навык проверяет 4 критерия (окружение, БД/кэш/очереди, env-переменные, сервисы) и принимает решение: gate required / not required.

### Конвенция именования артефактов

- **Все новые артефакты используют строго 3-значный номер цикла (`NNN`):**
  - `DEV-FRONT-NNN.md`, `DEV-BACK-NNN.md`, `TEST-NNN.md`
  - `TR-NNN.md`, `guardian-NNN.md`, `final-report-NNN.md`
  - `session-YYYY-MM-DD.md` (без номера цикла)
- **Legacy-артефакты с 1-значным номером (`TR-1.md`, `guardian-2.md`) не удаляются, но новые НЕ создаются в этом формате.**
- **Суффиксы `-retry`, `-chromadb`, `-diagnostic` и даты в именах отчётов запрещены.** При повторном запуске агента в том же цикле — перезапись существующего артефакта (с пометкой в `procedural.json`).
- **`work-area/docs/` содержит только 3 канонических файла:** `explore-report.md`, `requirements.md`, `design.md`. Task-specific варианты (`design-mcp-chain.md`, `explore-report-chromadb.md`) — legacy, новые не создаются. При параллельных задачах Team Lead создаёт отдельные сессии.

### Протокол инцидентов

При зависании субагента или PARTIAL COMPLETION Team Lead вызывает `skill({ name: "incident-protocol" })` согласно глобальным Routing Rules (`~/.config/opencode/AGENTS.md`). Навык классифицирует инцидент и выдаёт решение SUFFICIENT / INSUFFICIENT / ESCALATE.

## Разграничение артефактов

- `docs/` — документация проекта и продукта.
- `tests/` — тестовый код проекта.
- `work-area/docs/` — служебные артефакты проектного цикла.
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
- Не сохранять служебные артефакты в `src/`, `docs/` или `tests/`.
- Все промежуточные материалы агентного цикла сохранять только в `work-area/`.
- Не считать папку `tests/` заменой отчётам Tester.
- Не считать папку `docs/` заменой артефактам `work-area/docs/`.
- Не дублировать действия из `procedural.json` со статусом FAILED.
- Не вызывать @devops напрямую — только через `devops-gate-check`.

## Применение глобального процесса

Базовый процесс (Routing Rules, Critical Gotchas, DevOps Modes, MALMAS Rules, Team Lead Quick Reference)
задан в глобальном `~/.config/opencode/AGENTS.md` и **не дублируется** здесь.

Ниже — только локальные уточнения и переопределения для данного проекта:

- **Конвенция нумерации:** все артефакты используют строго 3-значный номер цикла (`NNN`) — см. секцию «Конвенция именования артефактов».
- **Зоны ответственности:** `coder-front` → `static/`; `coder-back` → `src/`, `core/`, `routes/`, `services/`, `companion/`, `mcp_servers/` — см. секцию «Назначение директорий».
- **DevOps Gate:** обязателен для team-lead, coder-front, coder-back, tester — через `devops-gate-check` — см. секцию «DevOps Gate».
- **Максимум 3 REWORK-цикла**, Plateau Detection на cycle ≥2, эскалация при достижении лимита.
- **Scope discipline:** кодеры — только файлы из DEV-задачи; Guardian проверяет Scope Compliance.
- **Cross-stack API contracts:** Architect → «Сводка API-контрактов»; Team Lead верифицирует перед созданием task-файлов.
