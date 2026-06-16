---
name: task-metrics
description: Формирование и запись итоговых метрик задачи в metrics.json после ACCEPT или ESCALATE
license: MIT
compatibility: opencode
---

Применяй после ACCEPT или ESCALATE — когда задача достигла финального статуса.
Навык формирует JSON-запись метрик и дописывает её в `work-area/memory/metrics.json`.

# Кто использует

| Агент | Когда |
|-------|-------|
| `team-lead` | После ACCEPT или ESCALATE, перед закрытием задачи |

# Концепция

Метрики задачи — это агрегированная статистика, которая позволяет:
- Отслеживать «стоимость» задач (циклы, вызовы агентов)
- Выявлять узкие места (какие агенты чаще перезапускаются)
- Корректировать оценку сложности на основе historical data

Файл `metrics.json` — один на проект, дополняется новыми записями,
никогда не перезаписывается.

# Процедура

## Шаг 1. Прими входные данные

Team Lead передаёт (собирает из session-файла и отчётов цикла):

```
task_id: "DEV-XXX"
description: "краткое описание задачи"
complexity: 0–10
selected_variant: "A" | "B" | "C"
cycles_count: 1–3
plateau_detected: boolean
final_status: "ACCEPTED" | "ESCALATED"

agents_used: {
  explorer: {calls: N, status: "DONE" | "PARTIAL" | "FAILED"},
  analyst: {calls: N, status: "DONE" | "PARTIAL" | "FAILED"},
  architect: {calls: N, status: "DONE" | "PARTIAL" | "FAILED"},
  coder_front: {calls: N, files_changed: N, status: "DONE" | "PARTIAL" | "BLOCKED"} | null,
  coder_back: {calls: N, files_changed: N, status: "DONE" | "PARTIAL" | "BLOCKED"} | null,
  tester: {calls: N, tests_run: N, status: "DONE" | "PARTIAL" | "FAILED"},
  guardian: {calls: N, verdicts: ["REWORK" | "ACCEPT" | "ESCALATE", ...], status: "DONE"},
  devops: {calls: N, status: "DONE" | "PARTIAL"} | null
}

rework_triggers: [
  {cycle: N, reason: "..."},
  ...
]

started: "ISO timestamp"       // из session-файла (момент Intake)
completed: "ISO timestamp"     // текущее время закрытия
```

## Шаг 2. Сформируй JSON-запись

Шаблон записи:

```json
{
  "task": "DEV-XXX",
  "description": "Добавлен OAuth2-логин",
  "complexity": 6,
  "selected_variant": "B",
  "cycles_count": 2,
  "plateau_detected": false,
  "final_status": "ACCEPTED",
  "agents_used": {
    "explorer": {"calls": 3, "status": "DONE"},
    "analyst": {"calls": 2, "status": "DONE"},
    "architect": {"calls": 2, "status": "DONE"},
    "coder-back": {"calls": 2, "files_changed": 5, "status": "DONE"},
    "tester": {"calls": 2, "tests_run": 16, "status": "DONE"},
    "guardian": {"calls": 2, "verdicts": ["REWORK", "ACCEPT"], "status": "DONE"}
  },
  "rework_triggers": [
    {"cycle": 1, "reason": "TEST-003 regression in payment after auth change"},
    {"cycle": 1, "reason": "Guardian critical: no input validation on email field"}
  ],
  "estimated_tokens": 85000,
  "duration_hours": 0.45,
  "started": "2026-05-14 10:00",
  "completed": "2026-05-14 10:27"
}
```

### Правила заполнения полей

| Поле | Правило |
|------|---------|
| `task` | ID задачи как в task-файлах |
| `complexity` | Оценка 0–10 из Intake |
| `cycles_count` | Финальное количество циклов (включая первый) |
| `plateau_detected` | `true` если сработал Plateau Detection хотя бы раз |
| `final_status` | `"ACCEPTED"` или `"ESCALATED"` |
| `agents_used.[agent].calls` | Сколько раз агент был запущен за всю задачу |
| `agents_used.[agent].status` | Финальный статус последнего запуска агента |
| `coder_*.files_changed` | Суммарное количество изменённых файлов за все циклы |
| `tester.tests_run` | Суммарное количество выполненных тест-кейсов за все циклы |
| `guardian.verdicts` | Массив всех вердиктов Guardian по циклам |
| `rework_triggers` | Причины каждого REWORK-цикла, одна запись на триггер |
| `estimated_tokens` | Примерная оценка, заполняется опционально |
| `duration_hours` | Разница `completed − started` в часах (с одним десятичным знаком) |
| `started` | ISO timestamp из session-файла |
| `completed` | Текущее время |

### Null-поля

Если агент не использовался в задаче — **не включай его** в `agents_used`.
Например, если задача чисто бэкендовая, `coder_front` отсутствует в объекте.

Если `estimated_tokens` не указан — поставь `null`.

## Шаг 3. Допиши в metrics.json

Файл `work-area/memory/metrics.json` — один на проект.

### Если файл существует

1. Прочитай текущее содержимое
2. Допиши новую запись в массив `tasks`
3. Обнови поле `updated` на текущее время
4. Запиши файл

### Если файл НЕ существует

Создай с нуля:

```json
{
  "project": "[извлеки из session-файла или укажи 'unknown']",
  "updated": "2026-05-14 12:00",
  "tasks": [
    { ... новая запись ... }
  ]
}
```

### Важно

- **Никогда не перезаписывай** существующие записи в `tasks`
- Новые записи дописываются в конец массива
- Если задача с тем же `task_id` уже есть (REWORK завершился ACCEPT на более позднем цикле) —
  **замени** старую запись, а не создавай дубликат

## Шаг 4. Верни подтверждение

```
Метрики записаны: DEV-XXX → ACCEPTED
Циклов: 2 | Plateau: нет | Агентов: 5 | Длительность: 0.5h
```

# Ограничения

- Не записывай метрики для задач в статусе IN PROGRESS или REWORK
- Не перезаписывай чужие записи в `tasks` (кроме случая замены того же task_id)
- Не придумывай значения — если данных нет, ставь null или не включай поле

# Self-check

- [ ] Все поля записи заполнены по правилам
- [ ] Файл metrics.json прочитан перед записью (если существовал)
- [ ] Новая запись дописана в конец массива tasks
- [ ] `updated` обновлён на текущее время
- [ ] Подтверждение возвращено Team Lead
