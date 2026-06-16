---
name: guardian-verdict
description: Decision engine: severity findings + test results → structured recommendation (RECOMMEND ACCEPT/REWORK/ESCALATE) с обязательным reasoning для Team Lead
license: MIT
compatibility: opencode
---

Применяй после завершения анализа всех зон (или после STOP_PARTIAL). Навык сводит
severity-классификацию и результаты тестов в формальную рекомендацию для Team Lead.

# Кто использует

| Агент | Когда |
|-------|-------|
| `guardian` | После классификации всех findings через guardian-severity, перед записью финального вердикта в guardian-NNN.md |

# Концепция

Guardian — эксперт, не руководитель. Его вердикт — **рекомендация** Team Lead,
а не приказ. Навык формализует decision logic: при каком сочетании severity
и test results какую рекомендацию выдать. Team Lead получает не просто «REWORK»,
а structured reasoning: почему, на основе каких finding'ов, какие альтернативы.

# Процедура

## Шаг 0. Входные данные

Guardian передаёт:

```
severity_summary: {
  blocker_count: 0,
  critical_count: 2,
  significant_count: 3,
  minor_count: 5,
  info_count: 1
}

findings: [
  {severity: "CRITICAL", zone: "correctness", file: "...", description: "...", recommendation: "..."},
  ...
]

test_outcome: "PASSED" | "FAILED" | "PARTIAL"

p0_failed: boolean                             // есть ли хотя бы один FAILED тест с приоритетом P0 (из TR-NNN.md)

analysis_complete: boolean                     // true если все 5 зон покрыты, false если PARTIAL

cycle_number: 1–3

plateau_indicators: {
  same_critical_as_previous: boolean,          // те же CRITICAL что в прошлом цикле?
  affected_zones_expanding: boolean            // affected zones растут?
}
```

## Шаг 1. Примени decision rules

### Правило 0: Функциональный гейт — FAILED тесты блокируют ACCEPT

Этот гейт применяется **до** severity-правил и не зависит от findings Guardian.

Если `test_outcome === "FAILED"` ИЛИ `p0_failed === true`:

```
recommendation: МИНИМУМ "RECOMMEND REWORK" (никогда не ACCEPT)
reasoning: "Функциональное тестирование выявило провалы (p0_failed=[..]). 
  Приёмка невозможна до прохождения тестов, независимо от инженерных findings."
```

- При `p0_failed === true` гейт **непереопределяем** (`overridable: false`) — провал критического теста эквивалентен BLOCKER по последствиям для приёмки.
- При `test_outcome === "FAILED"` без P0-провалов гейт переопределяем (`overridable: true`) на тех же условиях, что и CRITICAL (см. Правило 2).
- Этот гейт закрывает дыру: ранее FAILED-тест мог пройти в ACCEPT, если Guardian не зафиксировал отдельный CRITICAL-finding (например, при пропуске зоны Test Analysis под context-лимитом).

Если гейт сработал — итоговая рекомендация формируется как **максимум по строгости** между этим гейтом и результатом severity-правил 1–5 (BLOCKER/ESCALATE сохраняют приоритет).

### Правило 1: BLOCKER → RECOMMEND REWORK (автоматически)

Если `severity_summary.blocker_count > 0`:

```
recommendation: "RECOMMEND REWORK"
reasoning: "Обнаружен BLOCKER: [перечислить]. Дальнейшая приёмка невозможна до устранения."
overridable: false
```

Team Lead **не может** принять ACCEPT при наличии BLOCKER. Это единственное непереопределяемое правило.

### Правило 2: CRITICAL → RECOMMEND REWORK (переопределяемо)

Если `severity_summary.blocker_count === 0` И `severity_summary.critical_count > 0`:

```
recommendation: "RECOMMEND REWORK"
reasoning: "Обнаружено N критических замечаний: [перечислить]. Рекомендуется доработка."
overridable: true
override_conditions: "Team Lead может принять ACCEPT только с явным документированием: 
  1) проблема будет исправлена отдельной задачей (укажите номер)
  2) принят бизнес-риск (дедлайн, заказчик в курсе)
  3) проблема не воспроизводится в production-окружении"
```

### Правило 3: SIGNIFICANT → RECOMMEND REWORK при накоплении

Если `severity_summary.blocker_count === 0` И `severity_summary.critical_count === 0`:

| significant_count | Решение |
|---|---|
| ≥3 | **RECOMMEND REWORK** — накопление значимых замечаний снижает качество до неприемлемого уровня |
| 1–2 | **RECOMMEND ACCEPT** — с документированием значимых замечаний в отчёте |
| 0 | Перейти к Правилу 4 |

### Правило 4: MINOR/INFO → RECOMMEND ACCEPT

Если `severity_summary.critical_count === 0` И `severity_summary.significant_count === 0`:

```
recommendation: "RECOMMEND ACCEPT"
reasoning: "Изменения соответствуют инженерным стандартам. Критические и значимые замечания отсутствуют."
overridable: false
```

### Правило 5: ESCALATE trigger

Если `severity_summary.blocker_count > 0` ИЛИ `severity_summary.critical_count > 0`:

И одно из условий:

- `cycle_number >= 3` — третий цикл с критическими проблемами → **RECOMMEND ESCALATE**
- `plateau_indicators.same_critical_as_previous === true` — те же CRITICAL второй цикл подряд → **RECOMMEND ESCALATE**
- `plateau_indicators.affected_zones_expanding === true` — зона поражения растёт → **RECOMMEND ESCALATE**

```
recommendation: "RECOMMEND ESCALATE"
reasoning: "[конкретная причина]. Задача не прогрессирует в рамках стандартного цикла доработки.
  Рекомендуется пересмотреть требования или архитектурный подход."
overridable: false
```

## Шаг 2. Учти test_outcome

Test outcome обрабатывается **функциональным гейтом (Правило 0)** — FAILED не может дать ACCEPT.
Помимо гейта, outcome влияет на reasoning остальных решений:

| test_outcome | Эффект |
|---|---|
| `FAILED` | Гейт Правила 0 уже понизил рекомендацию до REWORK. В reasoning добавить: «Тестирование выявило функциональные проблемы. Требуется доработка и повторное тестирование.» |
| `PARTIAL` | Добавить в reasoning: «Тестирование выполнено частично. Непокрытые зоны: [перечислить]. Рекомендуется полное тестирование после доработки.» |
| `PASSED` | При RECOMMEND REWORK: «Тесты пройдены, но инженерные проблемы (см. замечания) требуют исправления.» |

## Шаг 3. Учти analysis_complete

Если `analysis_complete === false` (Guardian остановился PARTIAL):

Добавить в reasoning:
```
"Анализ выполнен частично. Покрытые зоны: [перечислить]. Непокрытые зоны: [перечислить].
Team Lead должен учесть, что непокрытые зоны могут содержать необнаруженные проблемы."
```

При этом recommendation формируется на основе **уже обнаруженных** findings —
если среди них есть CRITICAL, recommendation остаётся RECOMMEND REWORK.

## Шаг 4. Сформируй финальный verdict-блок

```markdown
## Итоговая рекомендация

**Рекомендация:** RECOMMEND {ACCEPT / REWORK / ESCALATE}

### Обоснование

{reasoning — 2–4 предложения, суммирующих ключевые finding'и и логику решения}

### Состав замечаний

| Severity | Количество | Ключевые |
|----------|-----------|----------|
| BLOCKER | {N} | {если >0: перечислить} |
| CRITICAL | {N} | {перечислить} |
| SIGNIFICANT | {N} | {перечислить} |
| MINOR | {N} | — |
| INFO | {N} | — |

### Условия переопределения (только для CRITICAL)

{если overridable: условия, при которых Team Lead может принять ACCEPT}
{если не overridable: «Не переопределяется» — для BLOCKER или чистого ACCEPT}

### Рекомендации для следующего цикла (только при RECOMMEND REWORK)

{конкретные вводные для проектной команды: что исправлять, в каком порядке, какие зоны под риском}

### Сигналы для Team Lead

- **Plateau risk:** {если plateau_indicators активны — предупреждение}
- **Анализ полный:** {да / нет — coverage}
- **Тестирование:** {outcome}
```

## Шаг 5. Верни результат

```
{
  recommendation: "RECOMMEND ACCEPT" | "RECOMMEND REWORK" | "RECOMMEND ESCALATE",
  reasoning: "...",
  overridable: boolean,
  override_conditions: "..." | null,
  verdict_markdown: "## Итоговая рекомендация\n\n...",
  severity_summary: {...},
  rework_instructions: "..." | null
}
```

# Ограничения

- Не говори «ACCEPT» или «REWORK» — всегда «RECOMMEND ACCEPT» / «RECOMMEND REWORK»
- BLOCKER всегда RECOMMEND REWORK, не предлагай ACCEPT
- Не скрывай plateau_indicators — Team Lead должен знать о риске плато
- Не выдавай ESCALATE без указания конкретной причины и предлагаемой альтернативы
- Всегда указывай, какие зоны покрыты анализом, а какие нет

# Self-check

- [ ] Recommendation prefix — всегда RECOMMEND (рекомендательный характер)
- [ ] Функциональный гейт (Правило 0) проверен: FAILED/p0_failed → не ACCEPT
- [ ] Decision rules применены в порядке 0→1→2→3→4→5
- [ ] Test outcome учтён, но не переопределяет severity-решение
- [ ] analysis_complete отражён в reasoning
- [ ] Plateau indicators проверены
- [ ] Verdict-блок сформирован полностью
