---
name: guardian-severity
description: Severity scoring matrix для находок Guardian: 5 уровней (BLOCKER/CRITICAL/SIGNIFICANT/MINOR/INFO) с формальными критериями по каждой зоне анализа
license: MIT
compatibility: opencode
---

Применяй для каждой находки Guardian — после того как проблема обнаружена и описана,
до присвоения severity. Навык классифицирует проблему по формальным критериям,
устраняя ad-hoc severity и делая решения предсказуемыми.

# Кто использует

| Агент | Когда |
|-------|-------|
| `guardian` | Для каждого finding — после обнаружения и описания проблемы, перед записью в guardian-NNN.md |

# Концепция

Сейчас Guardian присваивает severity интуитивно. Два одинаковых finding'а
в разных циклах могут получить разный severity — от этого зависит REWORK/ACCEPT.
Матрица формализует критерии: Guardian больше не гадает, а подставляет finding
под правила и получает объективный severity.

# 5 уровней severity

| Уровень | Семантика | Влияние на вердикт |
|---------|-----------|-------------------|
| **BLOCKER** | Немедленная остановка — нельзя продолжать | Автоматический REWORK, нельзя ACCEPT ни при каких условиях |
| **CRITICAL** | Блокирует приёмку — нарушает требования или безопасность | REWORK, если не перекрыто бизнес-решением Team Lead |
| **SIGNIFICANT** | Требует исправления — снижает качество или создаёт риск | REWORK при накоплении ≥3 SIGNIFICANT или в комбинации с CRITICAL |
| **MINOR** | Можно исправить позже — не влияет на работоспособность | ACCEPT допустим с документированием |
| **INFO** | Наблюдение или предложение — не проблема как таковая | Не влияет на вердикт, остаётся в отчёте для сведения |

# Процедура

## Шаг 0. Входные данные

Guardian передаёт для каждого finding:

```
finding: {
  zone: "correctness" | "code_quality" | "security" | "tech_debt" | "test_analysis",
  description: "SQL injection vulnerability in login.py:25 — user input concatenated into query",
  file: "src/backend/auth/login.py",
  line: "25",
  evidence: "query = f\"SELECT * FROM users WHERE email = '{email}'\"",
  potential_impact: "полная компрометация БД через входные данные пользователя"
}
```

## Шаг 1. Определи зону

finding попадает ровно в одну из 5 зон. Если затрагивает несколько —
выбери **зону с наивысшим потенциальным severity** (security > correctness > code_quality > tech_debt > test_analysis).

## Шаг 2. Примени матрицу

### BLOCKER — немедленная остановка

Присвой BLOCKER если finding в зоне **security** И соответствует любому из:

- SQL injection (конкатенация/интерполяция пользовательского ввода в SQL)
- Hardcoded секрет/ключ/токен/пароль в коде (не в .env)
- Remote Code Execution (eval, exec, system с пользовательским вводом)
- Authentication bypass (отсутствует или можно обойти проверку)
- Authorization bypass (доступ к чужим данным без проверки прав)
- Data exposure (персональные данные, PII, credentials в логах/ответах)
- Insecure dependency с known CVE severity ≥ 9.0

**Действие:** Guardian немедленно останавливает анализ, присваивает BLOCKER,
рекомендация автоматически REWORK. Team Lead не может ACCEPT.

### CRITICAL — блокирует приёмку

Присвой CRITICAL если finding **не подпадает под BLOCKER**, но:

**В зоне correctness:**
- Изменение не соответствует выбранному варианту из design.md
- Изменение вышло за пределы scope задачи без явного указания
- Нарушен интерфейсный контракт между фронтом и бэком
- Отклонение кодера создаёт новую проблему (а не просто отличается от задания)

**В зоне security (ниже BLOCKER):**
- Отсутствует валидация пользовательского ввода на новом эндпоинте
- XSS: пользовательский ввод рендерится без экранирования
- CSRF: state-changing операция без токена
- Insecure dependency с known CVE severity 7.0–8.9
- Weak cryptography (MD5, SHA1 для паролей, ECB mode)
- Missing rate limiting на аутентификационном эндпоинте

**В зоне code_quality (только если влияет на работоспособность):**
- Отсутствует обработка ошибок в critical path (try/except пустой или pass)
- Race condition в многопоточном/асинхронном коде
- Memory/resource leak в цикле или рекурсии

**В зоне test_analysis:**
- FAILED тест в affected zone из предыдущего цикла
- FAILED тест с приоритетом P0

**Действие:** Рекомендация REWORK. Team Lead может принять ACCEPT
только с явным документированным обоснованием (например: дедлайн,
проблема будет исправлена отдельной задачей).

### SIGNIFICANT — требует исправления

Присвой SIGNIFICANT если finding **не подпадает под CRITICAL**, но:

**В зоне code_quality:**
- Нарушены принятые соглашения проекта (именование, структура, стиль)
- Цикломатическая сложность функции > 15
- Дублирование кода: >10 одинаковых строк в двух местах
- Отсутствуют type hints в новой функции с >2 параметрами
- Отсутствует документация (docstring) у публичной функции/класса
- Закомментированный код объёмом >5 строк (без пояснения почему)
- Debug-вывод (print/console.log/logger.debug без guard'а) в production path

**В зоне correctness:**
- Отклонение кодера не создаёт проблему, но отличается от задания без обоснования

**В зоне tech_debt:**
- Изменение создаёт циклическую зависимость между модулями
- Обратимость ниже заявленной в design.md (реально низкая, заявлена средняя)

**В зоне test_analysis:**
- FAILED тест с приоритетом P1
- Наблюдение Tester, которое указывает на скрытую инженерную проблему
- PASSED тест с признаками ложного срабатывания (проверял не то)

**Действие:** Рекомендация REWORK при накоплении ≥3 SIGNIFICANT
или при наличии хотя бы 1 CRITICAL. Иначе — ACCEPT с документированием.

### MINOR — можно исправить позже

Присвой MINOR если finding **не подпадает под SIGNIFICANT**, но:

**В любой зоне:**
- Стиль именования не соответствует соглашениям (camelCase vs snake_case)
- Отсутствует type hint у простой (1 параметр) функции
- Закомментированный код <5 строк
- TODO/FIXME без номера задачи
- Незначительное дублирование (<10 строк)
- Импорт не наверху файла
- Missing trailing newline
- Minor deviation от style guide

**В зоне test_analysis:**
- FAILED тест с приоритетом P2

**Действие:** Не влияет на вердикт. Остаётся в отчёте для сведения.
Team Lead может включить в scope следующей задачи.

### INFO — наблюдение

Присвой INFO если finding — не проблема, а наблюдение или предложение:

- «Рекомендуется добавить интеграционный тест для этого сценария»
- «Этот паттерн можно вынести в общую утилиту в будущем»
- «Архитектурно возможно улучшить, но текущее решение приемлемо»
- «Документация затронутого модуля может быть расширена»

**Действие:** Не влияет на вердикт. Остаётся в примечаниях.

## Шаг 3. Зафиксируй результат

Для каждого finding верни:

```
{
  severity: "BLOCKER" | "CRITICAL" | "SIGNIFICANT" | "MINOR" | "INFO",
  zone: "security",
  finding: {
    file: "src/backend/auth/login.py",
    line: "25",
    description: "SQL injection vulnerability",
    evidence: "query = f\"SELECT * FROM users WHERE email = '{email}'\"",
    potential_impact: "полная компрометация БД"
  },
  rule_applied: "BLOCKER: Security — SQL injection (пользовательский ввод в SQL-запросе)",
  recommendation: "Использовать параметризованные запросы: cursor.execute(\"SELECT * FROM users WHERE email = %s\", (email,))"
}
```

## Шаг 4. Сгруппируй по severity (для guardian-NNN.md)

После классификации всех findings сгруппируй:

```
summary: {
  blocker_count: 0,
  critical_count: 2,
  significant_count: 3,
  minor_count: 5,
  info_count: 1
}
```

# Ограничения

- Не смягчай severity — если finding подпадает под BLOCKER, это BLOCKER
- Если finding граничный между двумя уровнями — выбирай **более высокий**
- Не пропускай finding'и — классифицируй всё, что обнаружено
- Для каждого finding обязан выдать recommendation (как исправить)

# Self-check

- [ ] Каждый finding классифицирован по формальным критериям матрицы
- [ ] BLOCKER/CRITICAL имеют явное указание на критерий
- [ ] Для каждого finding есть recommendation
- [ ] Summary по severity подсчитан
- [ ] Нет «интуитивных» severity без привязки к правилу матрицы
