---
name: osint-tools-identity
description: Use when investigating persons, usernames, emails, or phone numbers. Covers social media search, breach/leak checking, and registration verification: Sherlock, Snoop Project, HIBP, Holehe, LeakCheck, IntelX, DeHashed.
---

## Доступность инструментов (identity-блок)

Перед использованием любого инструмента проверь его доступность:

| Инструмент | Тип доступа | Как проверить | Если недоступен |
|------------|------------|---------------|-----------------|
| **Sherlock** | CLI | `which sherlock` или `pip show sherlock-project` | Пропусти; используй namechk.com вручную |
| **Snoop Project** | CLI (standalone скрипт) | Наличие `~/osint/tools/snoop-project/snoop.py` | Пропусти; используй Sherlock (глобальный охват) |
| **Holehe** | CLI | `which holehe` | Пропусти; используй namechk.com |
| **Have I Been Pwned** | Web API | `HIBP_API_KEY` в env | Используй k-anonymity range API (публичный endpoint) |
| **HIBP k-anonymity** | Web (public) | Всегда доступен | — |
| **LeakCheck** | Web API | `LEAKCHECK_API_KEY` в env | Зафиксируй в «Пробелах» |
| **IntelX (Intelligence X)** | Web API | `INTELX_API_KEY` в env | Упомяни как опцию; не симулируй |
| **DeHashed** | Web API | `DEHASHED_API_KEY` + `DEHASHED_EMAIL` в env | Упомяни как опцию; не симулируй |

**Правило**: если инструмент недоступен — **не симулируй его использование**. Зафиксируй в «Пробелы», выбери альтернативу или предложи пользователю ручной шаг.

---

## 📱 Блок 2.5 — Разведка по телефону (White)

| Инструмент   | Назначение                                          | Метод |
|-------------|-----------------------------------------------------|-------|
| phoneinfoga | Страна, оператор, регион, online footprints         | White |
| numverify   | Базовая проверка номера (API)                       | White |

**Когда применять:**
- Всегда первый шаг при наличии номера телефона объекта
- До Grey-эскалации (Telegram-боты): сначала собери максимум через White
- phoneinfoga использует публичные API (numverify.com, Google) — не требует ключа

**Как проверить доступность:**
```
which phoneinfoga
```

**Если недоступен:**
- Зафиксируй в «Пробелах»: «phoneinfoga не установлен»
- Альтернативы: ручная проверка через numverify.com (webfetch), поиск в Google/Yandex дорках «"номер" в кавычках»

**Команда:**
```
phoneinfoga scan -n <номер>
```

---

## 👤 Блок 3 — Разведка по личности и соцсетям

| Инструмент      | Назначение                                        | Метод |
|-----------------|---------------------------------------------------|-------|
| Sherlock        | Поиск username в 300+ платформах                  | White |
| Snoop Project   | Аналог Sherlock, акцент на СНГ-платформах         | White |
| Creepy          | Геолокационная разведка из соцсетей               | White |
| Social-Analyzer | Поиск аккаунтов по имени на 1000+ сайтах          | White |
| Namechk         | Проверка занятости никнейма                       | White |

**Когда применять:**
- Sherlock → первичный поиск никнейма (глобальный охват)
- Snoop Project → если объект из СНГ (VK, OK, TenChat, региональные форумы)
- Creepy → геолокация по публикациям в Twitter/Instagram (требует GUI; в headless — пропустить)
- Social-Analyzer → широкий перебор при неизвестной платформе объекта

---

## 📧 Блок 4 — Email, утечки и пароли

| Инструмент            | Назначение                                          | Метод       |
|-----------------------|-----------------------------------------------------|-------------|
| Have I Been Pwned     | Проверка email на компрометацию                     | White       |
| Holehe                | Проверка email на регистрацию в 120+ сервисах       | White       |
| LeakCheck             | API-поиск по утечкам: email, телефон, пароль        | Grey ⚠️     |
| h8mail                | Агрегатор утечек: email → 15+ провайдеров (HIBP, DeHashed, LeakCheck, SnusBase) | Grey ⚠️ |
| IntelX (Intelligence X) | Поиск по утечкам, Dark Web, Tor, I2P               | Grey ⚠️     |
| DeHashed              | Расширенная база утечек с API                       | Grey ⚠️     |

**Когда применять:**
- HIBP + Holehe — всегда первый шаг при наличии email объекта
- LeakCheck / h8mail — когда HIBP дал hits или требуется углублённый поиск; **Grey, обязательна кросс-верификация**
- h8mail — единый интерфейс к 15+ провайдерам утечек; конфиг: `~/.config/h8mail/h8mail.ini`
- IntelX / DeHashed — углублённый поиск, Grey; обязательна кросс-верификация
- ⚠️ Достоверность Grey-утечек: 60–80%. Никогда не строить выводы на одном источнике.
