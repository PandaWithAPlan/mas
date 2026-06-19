---
name: memory-summarize
description: MALMAS Summary-Agent: сжатие ProcMem + FeedMem → ConMem (conceptual.md) + GlobalMem (global-memory.md) через LLM
license: MIT
compatibility: opencode
---

> ⚙️ **Это навык-инструкция, а не функция.** Вызов `skill({ name: "memory-summarize" })` один раз подгружает этот текст в твой контекст — у навыка нет отдельного исполнения, входных аргументов и возвращаемого значения. Прочитав процедуру, выполни её сам и встрой результат прямо в свой ответ или артефакт. Повторный вызов ради получения вывода — ошибка: ты снова получишь этот же текст.

Применяй после завершения Guardian в каждом цикле, **перед** финальной записью
в conceptual.md и global-memory.md. Навык заменяет ручное написание эвристик
автоматическим сжатием через LLM — как предписано MALMAS-паттерном (Section 4.2.3):
`ConMem = LLM(ProcMem, FeedMem)`.

# Кто использует

| Агент | Когда |
|-------|-------|
| `team-lead` | При вызове `skill({ name: "memory-update" })` — вместо ручного написания conceptual.md |

# Концепция

В MALMAS-паттерне (Zhang et al., 2024) Summary-Agent выполняет три функции:
1. **Сжатие:** ProcMem (сырая хронология) + FeedMem (результаты тестов и вердикты) → ConMem (сжатые эвристики)
2. **Агрегация:** per-agent ConMem + FeedMem → GlobalMem (общий контекст для всех агентов)
3. **Cross-agent knowledge transfer:** эвристики одного агента становятся доступны другим через GlobalMem

Ручное написание эвристик team-lead'ом заменяется вызовом LLM,
который объективно извлекает паттерны из сырых данных.

# Входные данные

Навык получает от `memory-update`:
- `procedural_entries` — записи из procedural.json за текущий цикл (агент, действие, файлы, статус)
- `feedback_entries` — записи из feedback.json за текущий цикл (тесты: passed/failed, guardian: вердикт/affected_zones/critical_issues)
- `agent_ids` — список агентов, участвовавших в цикле (explorer, coder-back, tester, guardian, ...)
- `cycle_number` — номер цикла (1, 2, 3)
- `task_id` — идентификатор задачи (DEV-XXX)
- `existing_conceptual` — содержимое `conceptual.json` (если существует) для дополнения, а не перезаписи (источник истины — JSON, не Markdown; WI-2)

# Процедура

## Шаг 1. Извлеки значимые события из ProcMem

Из `procedural_entries` выбери записи, заслуживающие сохранения в эвристиках:
- Действия со статусом FAILED
- Действия, изменявшие одни и те же файлы несколько раз (признак нестабильного модуля)
- Действия, затрагивающие неожиданные зоны (coder-back изменил frontend-файл — признак скрытой зависимости)

Игнорируй: рутинные действия со статусом DONE, однократные чтения.

## Шаг 2. Извлеки паттерны из FeedMem

Из `feedback_entries` выдели:
- **Проваленные тесты:** test_id, причина провала, severity
- **Критические замечания Guardian:** файл, категория (security/correctness/quality/tech_debt), severity
- **Affected zones:** модули, задетыe критическими замечаниями
- **Cross-cycle patterns:** если провалы повторяются из цикла в цикл — это системная проблема

## Шаг 2.5. Baseline-валидация эвристик (WI-1)

Эвристику нельзя валидировать против поведения, которое она сама и продиктовала.
Поэтому корроборация/опровержение считаются **только по baseline-результатам**
(`feedback_entries[].testing.by_source.baseline` и `failed_details` с `source:"baseline"`),
а scoped-результаты для счётчиков игнорируются.

Для каждой существующей эвристики, чья зона затронута в этом цикле:
- Если baseline-наблюдение **соответствует** правилу эвристики (предсказание сбылось)
  → инкрементируй `confirm_count`, обнови `last_confirmed_cycle`.
- Если выполнено `falsification_condition` эвристики **по baseline** → инкрементируй
  `refute_count`.
- В любом случае обнови `last_tested_cycle`.
- Запиши изменения счётчиков в `changelog.jsonl` (WI-6) с `rule` и ссылкой на
  baseline-finding в `evidence`/`reason`.

Эти счётчики — вход для детерминированных правил перехода ярусов (WI-3).

### Манифест baseline (`work-area/memory/baseline/manifest.json`)

Схема (источник истины по составу якоря; версионируется, ведётся вручную/Team Lead):
```json
{
  "project": "[название проекта]",
  "updated": "YYYY-MM-DD",
  "test_ids": ["BASE-001", "BASE-002"],
  "description": "стабильный регрессионный набор; меняется осознанно, не под задачу"
}
```

### Процедура «проверить эвристику X против baseline-only за N циклов»

`N` = `baseline.validation_window_cycles` из `memory-config.json`.
1. Собери записи `feedback.json` за последние N циклов.
2. Отфильтруй тесты с `source:"baseline"` (scoped отбрось).
3. Сопоставь baseline-исходы в зоне эвристики X с её `rule` и `falsification_condition`.
4. Вывод: подтверждена (рост `confirm_count`), опровергнута (рост `refute_count`)
   или нейтральна. Это и есть ground-truth проверка эвристики, не зависящая от Router.

## Шаг 3. Сгенерируй эвристики через LLM (ConMem)

Источник истины — `conceptual.json` (WI-2). Вызови LLM со следующим промптом:

```
Ты — Summary-Agent в MALMAS-системе. Твоя задача — проанализировать сырые данные
цикла и сформулировать СЖАТЫЕ, ПЕРЕИСПОЛЬЗУЕМЫЕ эвристики в виде conceptual.json.

## Сырые данные

### Procedural Memory (что делали агенты):
[procedural_entries — в формате: entry_id | agent | action | files_touched | status]

### Feedback Memory (результаты тестов и аудита):
[feedback_entries — testing: finding_id, passed/failed, source(baseline/scoped);
 guardian: finding_id, verdict, critical_issues]

## Существующие эвристики (НЕ дублировать, дополнять или опровергать):
[existing_conceptual — объект conceptual.json, если есть]

## Требования к эвристикам:
1. Одна эвристика = одно атомарное правило (что делать / чего избегать)
2. id в UPPER-KEBAB-CASE, стабилен на весь жизненный цикл эвристики
3. Каждая эвристика привязана к agent (agent_id) либо "<cross-agent>"
4. Если эвристика уже существует — ОБНОВИ её поля, НЕ создавай дубль с тем же смыслом
5. `evidence` — массив РЕАЛЬНЫХ finding_id/entry_id из сырых данных выше.
   Эвристик без evidence не бывает. Висячих ссылок не бывает.
6. У каждой эвристики обязателен `falsification_condition` — какое BASELINE-наблюдение
   её хоронит. Без него эвристика не может быть tier:"active" (см. WI-3).
7. Новая эвристика, индуцированная из n=1 (один цикл) → tier:"provisional" (WI-3).
8. НЕ объединяй похожие эвристики (слияние запрещено, WI-3). Кап действует только
   на active; механику ярусов применяет memory-summarize по правилам WI-3.
9. Не пиши очевидное («надо тестировать код», «надо документировать»)

## Формат вывода — объект conceptual.json:
{
  "heuristics": [
    {
      "id": "HEURISTIC-ID",
      "rule": "...",
      "agent": "coder-back",
      "tier": "active|provisional|archived",
      "evidence": ["find-...", "proc-..."],
      "confidence": 0.0,
      "falsification_condition": "...",
      "created_cycle": N,
      "last_confirmed_cycle": N,
      "last_tested_cycle": N,
      "confirm_count": 0,
      "refute_count": 0
    }
  ]
}
```

## Шаг 4. Обнови GlobalMem (Global Conceptual Memory)

На основе сгенерированных эвристик и результатов цикла сформируй обновление для global-memory.md:

```
Ты — Summary-Agent. Сформируй обновление для global-memory.md
(точка входа для ВСЕХ агентов перед началом работы).

## Входные данные
- Сгенерированные эвристики (из Шага 3)
- Результаты цикла: тесты passed/failed, вердикт Guardian
- Статус задачи: ACCEPTED / REWORK / ESCALATED

## Требования к GlobalMem:
1. Секция «Текущая задача» — актуальный статус, цикл, сложность, вариант
2. Секция «Ограничения (на основе опыта)» — не более 5 пунктов, каждый со ссылкой на эвристику
3. Секция «Что сработало» — стратегии, которые дали результат в этом цикле
4. Секция «Что не сработало» — подходы, которые привели к проблемам
5. Секция «Для следующего агента» — что важно знать агенту, который будет работать следующим
6. Файл должен читаться за 60 секунд

## Формат вывода:
Выдай готовое содержимое global-memory.md (полный Markdown).
```

## Шаг 5. Сформируй результат

Сформируй следующее **сам** и встрой в свой ответ/артефакт (это шаблон того, что ты пишешь, а не возвращаемое значение функции — повторно навык не вызывается):
```
{
  "conceptual_json": { "heuristics": [ ... ] },   // источник истины (WI-2)
  "conceptual_md": "# Концептуальная память...",   // СГЕНЕРИРОВАН из conceptual_json
  "global_memory_update": "# Глобальная память проекта\n...",
  "deprecated_heuristics": ["OLD-ID", ...],         // переведены в tier:"archived"
  "new_heuristic_count": N,
  "active_heuristic_count": N
}
```

`conceptual_md` — производное представление: собери его из `conceptual_json`
группировкой по `agent` и ярусам (формат — см. memory-update, Шаг 4). Источник
истины — `conceptual_json`. Этот результат используется `memory-update` для записи
в conceptual.json (→ conceptual.md) и global-memory.md.

# Ограничения

- Не перезаписывай conceptual.md глобально — дополняй и обновляй существующие эвристики
- Не теряй историю: опровергнутые эвристики → в «Устаревшие / отозванные», не удаляй
- Не создавай эвристик без источника (цикл + агент + finding)
- Не превышай 10 активных эвристик — объединяй похожие
- Если задача ESCALATED — не генерируй новых эвристик (недостаточно данных)
- Результат всегда должен быть machine-actionable (чёткий формат для записи в файлы)

# Self-check

- [ ] ProcMem проанализирован на FAILED-действия и повторы
- [ ] FeedMem извлечены провалы, affected_zones, критические замечания
- [ ] LLM-промпт содержит все 4 секции (ProcMem, FeedMem, existing_conceptual, требования)
- [ ] Эвристики привязаны к agent_id (per-agent ConMem)
- [ ] У каждой эвристики `evidence` ссылается на реальные finding_id/entry_id (нет висячих ссылок, WI-2)
- [ ] GlobalMem обновлён со статусом задачи и рекомендациями
- [ ] Опровергнутые эвристики переведены в tier:"archived"
- [ ] Результат в формате {conceptual_json, conceptual_md, global_memory_update, ...}
