---
name: report-data-extract
description: Извлечение структурированных данных из всех артефактов задачи в единый data-объект для последующей генерации отчёта
license: MIT
compatibility: opencode
---

> ⚙️ **Это навык-инструкция, а не функция.** Вызов `skill({ name: "report-data-extract" })` один раз подгружает этот текст в твой контекст — у навыка нет отдельного исполнения, входных аргументов и возвращаемого значения. Прочитав процедуру, выполни её сам и встрой результат прямо в свой ответ или артефакт. Повторный вызов ради получения вывода — ошибка: ты снова получишь этот же текст.

Применяй в начале работы reviewer, до формирования отчёта. Навык читает
все артефакты задачи (session, requirements, design, DEV-отчёты, test results,
guardian) и извлекает из них структурированные данные, готовые для подстановки
в HTML-шаблон.

# Кто использует

| Агент | Когда |
|-------|-------|
| `reviewer` | Pre-flight: после получения команды от Team Lead, перед генерацией отчёта |

# Концепция

Reviewer на модели minimax-m2.7 не должен читать 7 артефактов и держать их
в контексте — это перегружает модель и приводит к потере деталей. `report-data-extract`
берёт эту работу на себя: читает все файлы, извлекает ключевые факты и возвращает
компактный data-объект. Reviewer только подставляет данные в HTML-шаблон.

# Процедура

## Шаг 0. Получи пути от reviewer

Reviewer передаёт:
```
task_name: "[краткое название]"     // из команды Team Lead
cycle: N                            // номер финального цикла
session_path: "work-area/sessions/session-YYYY-MM-DD.md"
requirements_path: "work-area/docs/requirements.md"
design_path: "work-area/docs/design.md"
dev_front_path: "work-area/tasks/DEV-FRONT-NNN.md" | null
dev_back_path: "work-area/tasks/DEV-BACK-NNN.md" | null
tr_path: "work-area/reports/test-results/TR-NNN.md"
guardian_path: "work-area/reports/guardian-NNN.md"
```

## Шаг 1. Прочитай все источники

Для каждого файла из входных данных:
- Если путь не null и файл существует → прочитай
- Если null или не существует → пропусти, в data-объекте поставь `null`

## Шаг 2. Извлеки данные

### Из session-файла

```
session: {
  task_description: "[из метаданных]",
  complexity_score: "[N/10 — обоснование]",
  selected_variant: "A" | "B" | "C",
  started_at: "YYYY-MM-DD HH:MM",
  incident_count: N,
  incidents: [{time: "...", agent: "...", problem: "..."}] | []
}
```

### Из requirements.md

```
requirements: {
  goal: "[одно предложение — что нужно было сделать]",
  business_context: "[зачем, какую проблему решает]",
  affected_modules: ["auth", "payment"],
  constraints: ["не трогать payment.py"],
  risks_identified: [{risk: "...", source: "...", severity: "high/medium/low"}],
  open_questions: ["..."] | []
}
```

### Из design.md

```
design: {
  selected_variant: "A" | "B" | "C",
  variant_label: "Минимально-инвазивный" | "Умеренный" | "Глубокий рефакторинг",
  approach_summary: "[2–3 предложения: как решается задача]",
  files_touched: [
    {path: "src/backend/auth/login.py", change_type: "modify"},
    {path: "src/frontend/components/Login.tsx", change_type: "create"}
  ],
  reversibility: "высокая" | "средняя" | "низкая",
  risk_summary: "[1 предложение — главный риск]",
  reason_for_choice: "[почему выбран именно этот вариант]"
}
```

### Из DEV-отчётов (FRONT + BACK)

```
implementation: {
  front: {
    status: "DONE" | "PARTIAL" | "BLOCKED" | null,
    files_changed: N | null,
    deviations: ["описание отклонения от задания"] | [],
    discovered_issues: ["..."] | [],
    api_contracts_documented: boolean | null
  } | null,
  back: {
    status: "DONE" | "PARTIAL" | "BLOCKED" | null,
    files_changed: N | null,
    deviations: ["..."] | [],
    discovered_issues: ["..."] | [],
    api_contracts: [{endpoint: "...", method: "...", ...}] | null
  } | null
}
```

### Из test-results (TR-NNN.md)

```
testing: {
  outcome: "PASSED" | "FAILED" | "PARTIAL",
  summary: {
    p0: {total: N, passed: N, failed: N, skipped: N},
    p1: {total: N, passed: N, failed: N, skipped: N},
    p2: {total: N, passed: N, failed: N, skipped: N},
    overall: {total: N, passed: N, failed: N, skipped: N}
  },
  failed_tests: [
    {id: "TEST-003", name: "...", priority: "P1", reason: "..."}
  ],
  regression_checks: "[кратко: что проверено на регрессию]",
  observations: ["..."] | [],
  partial_completion: {
    was_partial: boolean,
    p0_completed: "N/N",
    p1_completed: "N/N",
    p2_completed: "N/N",
    reason: "..." | null
  } | null
}
```

### Из guardian-NNN.md

```
guardian: {
  verdict: "ACCEPT",
  correctness: "✓" | "⚠" | "✗",
  code_quality: "✓" | "⚠" | "✗",
  security: "✓" | "⚠" | "✗",
  tech_debt: "✓" | "⚠" | "✗",
  critical_issues: [
    {file: "...", problem: "...", justification: "..."}
  ],
  significant_issues: [
    {file: "...", problem: "...", recommendation: "..."}
  ],
  minor_notes: [
    {file: "...", observation: "..."}
  ]
}
```

## Шаг 3. Сформируй сводные данные

На основе данных из шага 2 вычисли:

```
{
  report_title: "Итоговый отчёт — [task_name]",
  generated_at: "YYYY-MM-DD HH:MM",
  data_sources_used: ["requirements.md", "design.md", ...],   // какие файлы реально прочитаны
  data_sources_missing: ["session-YYYY-MM-DD.md"] | [],      // какие не найдены

  // Было ли несколько циклов?
  multi_cycle: boolean,        // true если complexity и testing.partial_completion намекают на >1 цикла

  // Статус документации — placeholder, reviewer дополнит через doc-consistency-check
  doc_status: null
}
```

## Шаг 4. Сформируй результат

Сформируй следующее **сам** и встрой в свой ответ/артефакт (это шаблон того, что ты пишешь, а не возвращаемое значение функции — повторно навык не вызывается):

```json
{
  "report_title": "Итоговый отчёт — Добавление OAuth2-логина",
  "generated_at": "2026-05-14 15:30",
  "data_sources_used": ["requirements.md", "design.md", "DEV-BACK-001.md", "TR-002.md", "guardian-002.md"],
  "data_sources_missing": [],
  
  "summary": {
    "goal": "Добавить OAuth2-логин через Google и GitHub",
    "business_context": "Пользователи хотят входить без отдельной регистрации",
    "selected_variant_label": "Умеренный (B)",
    "outcome": "Успешно реализовано и принято",
    "duration": "1 цикл, ~25 минут"
  },

  "requirements": { ... },
  "design": { ... },
  "implementation": { ... },
  "testing": { ... },
  "guardian": { ... },
  "session": { ... }
}
```

# Ограничения

- Не модифицируй исходные артефакты — только читай
- Если файл не найден — явно укажи в data_sources_missing, не «додумывай» данные
- Извлекай факты, не интерпретации — guardian.verdict = "ACCEPT", а не «всё хорошо»
- Все числовые значения из тестов — как в источнике, не округляй

# Self-check

- [ ] Все переданные reviewer пути обработаны
- [ ] Каждый файл дал структурированные данные (или null если не найден)
- [ ] Тестовые метрики разбиты по P0/P1/P2
- [ ] Guardian замечания разделены на critical/significant/minor
- [ ] data_sources_used и data_sources_missing заполнены
- [ ] Результат возвращён как JSON, готовый к подстановке в HTML
