---
name: memory-update
description: Обновление трёхслойной памяти проекта после завершения цикла
license: MIT
compatibility: opencode
---

> ⚙️ **Это навык-инструкция, а не функция.** Вызов `skill({ name: "memory-update" })` один раз подгружает этот текст в твой контекст — у навыка нет отдельного исполнения, входных аргументов и возвращаемого значения. Прочитав процедуру, выполни её сам и встрой результат прямо в свой ответ или артефакт. Повторный вызов ради получения вывода — ошибка: ты снова получишь этот же текст.

Применяй после завершения Guardian в каждом цикле (основном и повторных).
Навык превращает сырые артефакты цикла в структурированную,
машиночитаемую память для переиспользования в следующих циклах и другими агентами.

# Кто использует

| Агент | Роль | Когда |
|-------|------|-------|
| `team-lead` | Исполнитель | После получения вердикта Guardian, перед принятием решения ACCEPT/REWORK/ESCALATE |

# Концепция

MALMAS-паттерн: память не пассивный журнал, а активный вход для следующего раунда.
Три слоя памяти закрывают три вопроса:

| Слой | Вопрос | Формат |
|------|--------|--------|
| Procedural | Что делали? | JSON — машиночитаемая хронология |
| Feedback | Что сработало? | JSON — связка тест→вердикт→зоны |
| Conceptual | Какие уроки извлечены? | Markdown — сжатые эвристики |

Плюс Global Memory — консолидированный контекст, который читается всеми агентами
перед началом работы.

# Процедура

## Шаг 1. Прочитать исходные данные

Прочитай:
- `work-area/sessions/session-YYYY-MM-DD.md` — хронология цикла
- `work-area/tasks/DEV-FRONT-NNN.md` и `work-area/tasks/DEV-BACK-NNN.md` — отчёты кодеров
- `work-area/reports/test-results/TR-NNN.md` — результаты тестирования
- `work-area/reports/guardian-NNN.md` — заключение Guardian

## Шаг 2. Обновить Procedural Memory

Файл: `work-area/memory/procedural.json`

Если файла нет — создай с нуля. Если есть — дополни.

```json
{
  "project": "[название проекта]",
  "updated": "YYYY-MM-DD HH:MM",
  "history": [
    {
      "task": "DEV-XXX",
      "cycle": 1,
      "complexity": 6,
      "entries": [
        {
          "agent": "explorer",
          "action": "scanned src/backend/auth/",
          "files_touched": [],
          "artifact": "work-area/docs/explore-report.md",
          "timestamp": "YYYY-MM-DD HH:MM",
          "status": "DONE"
        },
        {
          "agent": "coder-back",
          "action": "modified login handler",
          "files_touched": ["src/backend/auth/login.py"],
          "change_type": "modify",
          "timestamp": "YYYY-MM-DD HH:MM",
          "status": "DONE"
        }
      ]
    }
  ]
}
```

Правила заполнения:
- `agent` — имя агента как в opencode.json
- `action` — что делал (одна строка, глагол + объект)
- `files_touched` — всегда массив, даже если пустой
- `change_type` — "create" / "modify" / "delete" / "none"
- `status` — "DONE" / "PARTIAL" / "FAILED"
- В одном объекте `task` может быть несколько `cycle` объектов (для REWORK)
- Новые записи дописываются в конец массива `history`

## Шаг 3. Обновить Feedback Memory

Файл: `work-area/memory/feedback.json`

```json
{
  "project": "[название проекта]",
  "updated": "YYYY-MM-DD HH:MM",
  "history": [
    {
      "task": "DEV-XXX",
      "cycle": 1,
      "testing": {
        "report": "work-area/reports/test-results/TR-001.md",
        "total": 8,
        "passed": 6,
        "failed": 2,
        "failed_details": [
          {
            "test_id": "TEST-003",
            "reason": "regression in payment module after auth change",
            "severity": "high"
          }
        ]
      },
      "guardian": {
        "report": "work-area/reports/guardian-001.md",
        "verdict": "REWORK",
        "critical_count": 1,
        "critical_issues": [
          {
            "file": "src/backend/auth/login.py",
            "category": "security",
            "issue": "no input validation on email field"
          }
        ],
        "affected_zones": ["auth", "payment"]
      }
    }
  ]
}
```

Правила заполнения:
- `failed_details` — бери из TR-NNN.md, секция «Результаты по тест-кейсам», только FAILED
- `affected_zones` — из guardian-NNN.md, секция «Замечания»: выведи имена модулей/директорий из столбца «файл» критических и значимых замечаний
- `category` — "security" / "quality" / "correctness" / "tech_debt" — на основе секции Guardian
- Если Guardian вердикт ACCEPT — `critical_count: 0`, `critical_issues: []`

## Шаг 4. Обновить Conceptual Memory (MALMAS Summary-Agent)

Вместо ручного написания эвристик используй MALMAS-паттерн (Zhang et al., 2024):
`ConMem = LLM(ProcMem, FeedMem)`.

1. Подгрузи навык `skill({ name: "memory-summarize" })` (один раз) и примени его процедуру **сам** к данным, которые у тебя уже есть в контексте:
   - `procedural_entries` — записи из procedural.json за текущий цикл (результат Шага 2)
   - `feedback_entries` — записи из feedback.json за текущий цикл (результат Шага 3)
   - `agent_ids` — список агентов, участвовавших в цикле
   - `cycle_number` — номер цикла
   - `task_id` — DEV-XXX
   - `existing_conceptual` — содержимое conceptual.md (если существует)

2. По процедуре навыка `memory-summarize` ты сам сформируешь сжатие ProcMem + FeedMem → эвристики в виде структуры:
   ```
   {
     "conceptual_update": "...",    // готовый Markdown для conceptual.md
     "global_memory_update": "...", // готовый Markdown для global-memory.md
     "deprecated_heuristics": [...],
     "new_heuristic_count": N,
     "active_heuristic_count": N
   }
   ```

3. Запиши `conceptual_update` в `work-area/memory/conceptual.md`

### Per-agent секции (MALMAS ConMem)

Навык `memory-summarize` генерирует эвристики, сгруппированные по agent_id:
```md
# Концептуальная память проекта

> Последнее обновление: YYYY-MM-DD | Задача: DEV-XXX | Цикл: N | Summary-Agent

## explorer
- **HEURISTIC-ID** — правило. Источник: цикл N, ...
- ...

## coder-back
- **HEURISTIC-ID** — правило. Источник: цикл N, ...
- ...

## <cross-agent>
- **GLOBAL-HEURISTIC-ID** — правило. Источник: цикл N, ...

## Устаревшие / отозванные
- **OLD-ID** — отозвана в цикле N: [причина]
```

Это per-agent ConMem: каждый агент при `memory-retrieve` читает свою секцию.

## Шаг 5. Обновить Global Memory (MALMAS GlobalMem)

Используй результат Шага 4: запиши `global_memory_update` в `work-area/memory/global-memory.md`.

Навык `memory-summarize` генерирует GlobalMem с учётом:
- Новых эвристик из conceptual.md
- Результатов цикла (тесты, вердикт Guardian)
- Статуса задачи (ACCEPTED / REWORK / ESCALATED)
- Рекомендаций для следующего агента

Файл `global-memory.md` — точка входа для всех агентов перед началом работы.
Содержит сжатый контекст текущей задачи и ключевые ограничения из накопленного опыта.

Формат (генерируется автоматически):
```md
# Глобальная память проекта

> Последнее обновление: YYYY-MM-DD | Team Lead | Summary-Agent

## Текущая задача
[статус, цикл, сложность, выбранный вариант]

## Ограничения (на основе опыта)
[не более 5 пунктов, каждый со ссылкой на эвристику]

## Что сработало
[стратегии, давшие результат]

## Что не сработало
[подходы, приведшие к проблемам]

## Для следующего агента
[рекомендация]
```

Пример:

```md
# Глобальная память проекта

> Последнее обновление: 2026-05-14 12:00 | Team Lead

## Текущая задача

- **Задача:** DEV-001 — Добавить OAuth2-логин
- **Выбранный вариант:** B (умеренный)
- **Цикл:** 1/3
- **Сложность:** 6/10
- **Статус:** IN PROGRESS

## Ограничения (на основе опыта)

- **AUTH-PAYMENT-COUPLING** (→conceptual.md): любое изменение auth ломает payment.
  При работе с `src/backend/auth/` проверить регрессию `src/backend/payment/`.
- DevOps должен подтвердить доступность Redis перед стартом тестов.

## Что сработало

- Параллельный coder-front + coder-back в прошлой задаче
- Предварительный вызов @devops для env-переменных

## Что не сработало

- Пропуск Explorer на повторном цикле → скрытые конфликты

## Для следующего агента

- coder-back: не трогать payment.py без явного указания
- tester: тест-кейс на регрессию payment обязателен
```

Правила:
- «Ограничения» — не более 5 пунктов, каждый со ссылкой на эвристику
- «Для следующего агента» — обновляется перед запуском каждого агента, а не только в конце цикла
- Если задача ACCEPTED — секция «Текущая задача» остаётся, но `Статус: ACCEPTED`
- Файл всегда должен оставаться читаемым за 60 секунд

## Шаг 6. Связать старый MEMORY.md

Если файл `work-area/memory/MEMORY.md` существует и содержит ценные исторические данные,
не удаляй его. Добавь в начало файла ссылку:

```md
> ⚠ Этот файл заморожен. Актуальная память проекта ведётся в:
> - `work-area/memory/global-memory.md` — точка входа для всех агентов
> - `work-area/memory/conceptual.md` — эвристики и уроки
> - `work-area/memory/procedural.json` — хронология действий
> - `work-area/memory/feedback.json` — результаты тестов и вердикты
```

Если MEMORY.md не существует — не создавай его. Новая система памяти его заменяет.

# Self-check

- [ ] `procedural.json` дополнен записями текущего цикла
- [ ] `feedback.json` содержит testing + guardian за текущий цикл
- [ ] `conceptual.md` обновлён: новые эвристики добавлены, опровергнутые — в архив
- [ ] `global-memory.md` отражает актуальное состояние задачи и ограничения
- [ ] MEMORY.md (если был) помечен как замороженный со ссылками на новые файлы
- [ ] Все 4 файла памяти консистентны между собой (нет противоречий)
