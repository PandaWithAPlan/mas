---
name: guardian-scope
description: Pre-flight: формирование приоритизированного плана анализа Guardian с учётом affected zones и истории критических замечаний
license: MIT
compatibility: opencode
---

Применяй в начале работы Guardian, после memory-retrieve и чтения входных артефактов,
до начала анализа кода. Навык формирует приоритизированный план проверки —
аналог test-plan, но для инженерного аудита.

# Кто использует

| Агент | Когда |
|-------|-------|
| `guardian` | Pre-flight: после memory-retrieve, до анализа файлов |

# Концепция

Guardian читает до 8 артефактов + дифф кода и проверяет 5 зон анализа.
Без приоритизации он может потратить контекст на tech_debt, не дойдя до security.
`guardian-scope` гарантирует: security всегда первый. Остальное — по убыванию
потенциального вреда.

# Процедура

## Шаг 0. Входные данные

Guardian передаёт:

```
cycle_number: 1–3
affected_zones: ["auth", "payment"]        // из feedback.json, предыдущий цикл
previous_critical_categories: ["security"]  // из feedback.json, категории прошлых критических замечаний
files_to_analyze_count: 5                  // сколько файлов в диффе
has_frontend: boolean
has_backend: boolean
is_partial_tested: boolean                 // TR-NNN.md PARTIAL COMPLETION?
```

## Шаг 1. Определи порядок зон анализа

Фиксированный приоритет (от наиболее критичного к наименее):

| Порядок | Зона | Почему первый |
|---------|------|---------------|
| 1 | **Security** | BLOCKER/CRITICAL — могут требовать немедленной остановки |
| 2 | **Correctness** | Несоответствие design.md/контрактам — системная ошибка |
| 3 | **Code Quality** | Влияет на maintainability, но не ломает продукт |
| 4 | **Test Analysis** | Оценка результатов Tester — на основе уже собранных данных |
| 5 | **Tech Debt** | Долгосрочные риски — наименее срочно |

## Шаг 2. Усиль зоны на основе памяти

### Если affected_zones не пусты

Зоны, совпадающие с `affected_zones`, получают повышенный приоритет:
- **Security** в affected zone → проверяется первым в рамках Security
- **Correctness** в affected zone → проверяется первым в рамках Correctness
- Файлы из affected zones анализируются до остальных файлов диффа

### Если previous_critical_categories содержит категорию

Зона этой категории проверяется с удвоенной тщательностью:
- `"security"` → проверить каждый изменённый файл на все пункты BLOCKER-матрицы
- `"code_quality"` → проверить каждую изменённую функцию на complexity/duplication
- `"correctness"` → проверить каждый контракт на соответствие design.md

### Если is_partial_tested === true

Test Analysis становится приоритетом 3 (сразу после Correctness):
- Критически важно оценить: покрыл ли частичный тест зоны, где могут быть инженерные проблемы

## Шаг 3. Сформируй план анализа

```markdown
## План анализа — цикл [N]

### Приоритеты зон

| # | Зона | Усилена | Причина усиления |
|---|------|---------|------------------|
| 1 | Security | ✅ | previous_critical: security — полный аудит всех изменённых файлов на BLOCKER |
| 2 | Correctness | — | Стандартная проверка контрактов |
| 3 | Test Analysis | ✅ | PARTIAL COMPLETION — оценка покрытия критических зон |
| 4 | Code Quality | — | Стандартный аудит |
| 5 | Tech Debt | — | Оценка обратимости и новых зависимостей |

### Стратегия выполнения

1. **Security first:** проверить каждый файл диффа на все пункты BLOCKER-матрицы.
   При обнаружении BLOCKER — немедленно остановить анализ, вердикт REWORK.
2. **Correctness:** сверить реализацию с design.md, проверить контракты, проверить scope.
3. **Test Analysis:** оценить TR-NNN.md — нет ли скрытых проблем в наблюдениях.
4. **Code Quality:** если контекст позволяет — соглашения, сложность, документация.
5. **Tech Debt:** только при достаточном контексте после всех предыдущих зон.

### Оценка сложности анализа

| Параметр | Значение |
|-----------|----------|
| Файлов в диффе | {files_to_analyze_count} |
| Зон анализа | {если всё поместится: 5, иначе: до исчерпания контекста} |
| Ожидаемое покрытие | {security + correctness гарантированы, остальное — по контексту} |
```

## Шаг 4. Верни план

```
{
  plan: {
    zones: [
      {priority: 1, zone: "security", enhanced: true, reason: "previous_critical: security"},
      {priority: 2, zone: "correctness", enhanced: false},
      {priority: 3, zone: "test_analysis", enhanced: true, reason: "is_partial_tested"},
      {priority: 4, zone: "code_quality", enhanced: false},
      {priority: 5, zone: "tech_debt", enhanced: false}
    ],
    files_priority: ["src/backend/auth/login.py", "src/backend/auth/oauth.py", ...],
    stop_on_blocker: true,
    strategy: "Выполнять зоны по порядку. При обнаружении BLOCKER в security — немедленно STOP_PARTIAL с REWORK."
  }
}
```

# Ограничения

- Порядок зон фиксирован — security всегда первый
- При BLOCKER в security — остановка обязательна, не переходи к correctness
- Не меняй приоритеты зон произвольно — только по правилам усиления из памяти

# Self-check

- [ ] Все 5 зон учтены в плане
- [ ] Affected zones из feedback.json применены к усилению
- [ ] Previous critical categories учтены
- [ ] is_partial_tested проверен — Test Analysis повышен при необходимости
- [ ] План возвращён Guardian для исполнения
