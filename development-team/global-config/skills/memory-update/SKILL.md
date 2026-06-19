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
          "entry_id": "proc-9f2a1c",
          "agent": "explorer",
          "action": "scanned src/backend/auth/",
          "files_touched": [],
          "artifact": "work-area/docs/explore-report.md",
          "timestamp": "YYYY-MM-DD HH:MM",
          "status": "DONE"
        },
        {
          "entry_id": "proc-3b7e04",
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
- `entry_id` — **стабильный детерминированный ID** записи (WI-2). Это короткий хэш
  (первые 6 hex-символов) от строки `{task}|{cycle}|{agent}|{action}|{files_touched joined}`.
  Один и тот же факт всегда даёт один и тот же ID → находки идентифицируемы между
  циклами (это же закрывает детерминированную идентичность для Plateau Detection).
  Префикс `proc-`.
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
        "by_source": {
          "baseline": { "total": 5, "passed": 5, "failed": 0 },
          "scoped":   { "total": 3, "passed": 1, "failed": 2 }
        },
        "failed_details": [
          {
            "finding_id": "find-a1b2c3",
            "test_id": "TEST-003",
            "source": "scoped",
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
            "finding_id": "find-d4e5f6",
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
- `finding_id` — **стабильный детерминированный ID** находки (WI-2): короткий хэш
  (первые 6 hex) от `{task}|{cycle}|{file}|{rule/category или test_id}|{zone}`. Префикс
  `find-`. На него ссылаются эвристики в `conceptual.json` (поле `evidence`), поэтому он
  обязан быть стабильным и резолвиться линтером `check-memory-provenance.sh`.
- `by_source` — разбивка результатов на **baseline** (стабильный регрессионный якорь,
  WI-1) и **scoped** (тесты, выбранные под текущую задачу/эвристики). Берётся из
  TR-NNN.md, где tester помечает каждый тест `source`. Эта разбивка — основа
  валидации эвристик: подтверждать/опровергать эвристику можно **только по
  baseline-результатам**, scoped игнорируются (их scope продиктовала сама эвристика).
- `failed_details` — бери из TR-NNN.md, секция «Результаты по тест-кейсам», только FAILED.
  Поле `source` (`"baseline"` | `"scoped"`) обязательно у каждой записи теста.
- `affected_zones` — из guardian-NNN.md, секция «Замечания»: выведи имена модулей/директорий из столбца «файл» критических и значимых замечаний
- `category` — "security" / "quality" / "correctness" / "tech_debt" — на основе секции Guardian
- Если Guardian вердикт ACCEPT — `critical_count: 0`, `critical_issues: []`

## Шаг 4. Обновить Conceptual Memory (MALMAS Summary-Agent)

Вместо ручного написания эвристик используй MALMAS-паттерн (Dong et al., 2026, arXiv:2604.20261):
`ConMem = LLM(ProcMem, FeedMem)`.

**Источник истины концептуальной памяти — `conceptual.json` (WI-2), а не Markdown.**
`conceptual.md` — это **генерируемое из JSON представление для людей/агентов** и
вручную не правится. Так provenance становится машинно-проверяемым: каждая эвристика
ссылается на `finding_id` фактических слоёв, а линтер `check-memory-provenance.sh`
ловит висячие ссылки.

1. Подгрузи навык `skill({ name: "memory-summarize" })` (один раз) и примени его процедуру **сам** к данным, которые у тебя уже есть в контексте:
   - `procedural_entries` — записи из procedural.json за текущий цикл (результат Шага 2)
   - `feedback_entries` — записи из feedback.json за текущий цикл (результат Шага 3)
   - `agent_ids` — список агентов, участвовавших в цикле
   - `cycle_number` — номер цикла
   - `task_id` — DEV-XXX
   - `existing_conceptual` — содержимое `conceptual.json` (если существует)
   - `mode` — `incremental` | `recompact` (WI-4). Выбирается по правилу из
     `memory-config.json` → `recompaction`: `recompact`, если с последней рекомпакции
     прошло ≥ `window_N` циклов **или** сработал `drift_trigger`; иначе `incremental`.
     В режиме `recompact` `existing_conceptual` навыку **не передаётся** (stateless-проход).

2. По процедуре навыка `memory-summarize` ты сам сформируешь сжатие ProcMem + FeedMem → эвристики в виде структуры:
   ```
   {
     "conceptual_json": { ... },    // обновлённый объект conceptual.json (источник истины)
     "conceptual_md": "...",        // Markdown, СГЕНЕРИРОВАННЫЙ из conceptual_json
     "global_memory_update": "...", // готовый Markdown для global-memory.md
     "deprecated_heuristics": [...],
     "new_heuristic_count": N,
     "active_heuristic_count": N
   }
   ```

3. Запиши `conceptual_json` в `work-area/memory/conceptual.json`, затем
   `conceptual_md` в `work-area/memory/conceptual.md`. Markdown всегда производный —
   не редактируй его в обход JSON.

### Схема `conceptual.json` (WI-2)

`conceptual.json` — источник истины. Каждая эвристика — объект с полями:

```json
{
  "project": "[название проекта]",
  "updated": "YYYY-MM-DD HH:MM",
  "heuristics": [
    {
      "id": "AUTH-PAYMENT-COUPLING",
      "rule": "любое изменение auth требует регрессионной проверки payment",
      "agent": "coder-back",
      "tier": "active",
      "evidence": ["find-a1b2c3", "find-d4e5f6"],
      "confidence": 0.8,
      "falsification_condition": "baseline-тесты payment проходят при изменении auth в течение K циклов",
      "created_cycle": 1,
      "last_confirmed_cycle": 3,
      "last_tested_cycle": 3,
      "confirm_count": 2,
      "refute_count": 0
    }
  ]
}
```

Правила полей:
- `id` — UPPER-KEBAB-CASE, стабилен на всём жизненном цикле эвристики.
- `agent` — agent_id, к которому привязана эвристика, либо `"<cross-agent>"` для общих.
- `evidence` — массив `finding_id` из `feedback.json` (и/или `entry_id` из
  `procedural.json`). **Каждый ID обязан резолвиться** в существующую запись —
  это проверяет линтер. Эвристик без evidence не бывает.
- `tier` — `active` | `provisional` | `archived` (механика переходов — WI-3).
- `falsification_condition` — какое **baseline**-наблюдение хоронит эвристику (WI-1/WI-3).
- `confidence` — 0..1.
- `created_cycle` / `last_confirmed_cycle` / `last_tested_cycle` — номера циклов.
- `confirm_count` / `refute_count` — счётчики корроборации/опровержения (WI-3/WI-5).
- `type` — (опц.) `"guidance"` (по умолчанию) | `"failure-mode"` (WI-8). failure-mode
  фиксирует провалившийся подход/сигнатуру плато из ESCALATED-задачи.

### Генерация `conceptual.md` из JSON

`conceptual.md` собирается из `conceptual.json` группировкой по `agent`, с разбивкой
по ярусам. Формат (производный, **не источник истины**):

```md
# Концептуальная память проекта

> Сгенерировано из conceptual.json | YYYY-MM-DD | Задача: DEV-XXX | Цикл: N
> ⚠ Не редактировать вручную — источник истины: conceptual.json

## explorer
- **HEURISTIC-ID** [active] — правило. evidence: find-a1b2c3 | confirm:2 refute:0
- ...

## coder-back
- ...

## <cross-agent>
- **GLOBAL-HEURISTIC-ID** [provisional] — правило. evidence: find-... 

## Устаревшие / отозванные (archived)
- **OLD-ID** — архивирована в цикле N: [причина]
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

## Шаг 5.5. Версионирование и журнал мутаций (WI-6)

Память без аудиторского следа нельзя ни проверить, ни откатить. Перед завершением
цикла зафиксируй **снапшот** состояния памяти и **запись в журнал** на каждую
мутацию. Параметры — в `memory-config.json` → `versioning`.

### 5.5a. Снапшот состояния

Скопируй текущие файлы памяти (`snapshot_targets` из конфига — те, что существуют)
в каталог `work-area/memory/snapshots/cycle-NNN-YYYYMMDD-HHMM/`, где NNN — номер
цикла. Снапшоты **append-only**: никогда не перезаписывай существующий снапшот.

- Это даёт точку отката к известному-хорошему состоянию.
- Удерживай не более `snapshot_retention` последних снапшотов; более старые —
  удаляй (память не должна разрастаться бесконечно).

### 5.5b. Журнал мутаций

Допиши в `work-area/memory/changelog.jsonl` **по одной строке-объекту на каждую
мутацию** концептуальной памяти за этот цикл (добавление, промоут, демоут,
архивация, рекомпакция). Формат строки:

```json
{"timestamp":"YYYY-MM-DD HH:MM","cycle":N,"task":"DEV-XXX","mutation":"add|promote|demote|archive|recompact","target_id":"HEURISTIC-ID","from_tier":"provisional","to_tier":"active","rule":"confirm_count>=M","reason":"подтверждена baseline в циклах 2,3","evidence":["finding_id-..."]}
```

Правила:
- `mutation` — тип изменения. `rule` — **детерминированное правило**, по которому
  принято решение (например, `confirm_count>=M`, `refute_count>=K`, `active_cap_overflow`),
  а **не** «на усмотрение LLM». Если правило не формализуемо — это сигнал, что
  мутация неправомерна (см. WI-3).
- `reason` — человекочитаемое пояснение со ссылкой на конкретные циклы/наблюдения.
- `from_tier`/`to_tier` заполняются для промоут/демоут/архив; для `add` — только `to_tier`.
- Журнал **append-only**: старые записи не редактируются и не удаляются.

### 5.5c. Дифф и откат (процедура)

Для аудита деградации памяти доступны две операции (выполняются вручную
сопровождающим или агентом `ai-engineer`, не в рантайме цикла):

- **Дифф между циклами:** сравни `conceptual.json` (или `conceptual.md` до WI-2)
  из двух снапшотов — `diff snapshots/cycle-A.../conceptual.json snapshots/cycle-B.../conceptual.json`.
  Покажет добавленные/удалённые/изменённые эвристики между любыми двумя циклами.
- **Откат:** скопируй файлы из выбранного снапшота `cycle-NNN-.../` обратно в
  `work-area/memory/`, затем допиши в `changelog.jsonl` запись
  `{"mutation":"rollback","reason":"откат к снапшоту cycle-NNN из-за <причина>"}`.
  Откат тоже журналируется — он часть истории, а не её стирание.

## Шаг 6. Связать старый MEMORY.md

Если файл `work-area/memory/MEMORY.md` существует и содержит ценные исторические данные,
не удаляй его. Добавь в начало файла ссылку:

```md
> ⚠ Этот файл заморожен. Актуальная память проекта ведётся в:
> - `work-area/memory/global-memory.md` — точка входа для всех агентов
> - `work-area/memory/conceptual.json` — эвристики (источник истины) + генерируемый `conceptual.md`
> - `work-area/memory/procedural.json` — хронология действий
> - `work-area/memory/feedback.json` — результаты тестов и вердикты
```

Если MEMORY.md не существует — не создавай его. Новая система памяти его заменяет.

# Self-check

- [ ] `procedural.json` дополнен записями текущего цикла
- [ ] `feedback.json` содержит testing + guardian за текущий цикл, у каждой находки есть `finding_id`
- [ ] `procedural.json`: у каждой записи есть `entry_id`
- [ ] `conceptual.json` обновлён (источник истины); `conceptual.md` сгенерирован из него, не правлен вручную
- [ ] Каждая эвристика в `conceptual.json` ссылается в `evidence` на существующие `finding_id`/`entry_id` (проверь `check-memory-provenance.sh`)
- [ ] `global-memory.md` отражает актуальное состояние задачи и ограничения
- [ ] MEMORY.md (если был) помечен как замороженный со ссылками на новые файлы
- [ ] Все 4 файла памяти консистентны между собой (нет противоречий)
- [ ] Снапшот состояния памяти создан в `snapshots/cycle-NNN-.../` (WI-6)
- [ ] Каждая мутация концептуальной памяти отражена строкой в `changelog.jsonl` с правилом и причиной (WI-6)
