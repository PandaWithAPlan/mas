---
name: osint-tools-registries
description: State registries and public databases of CIS countries — legal entities, courts, debts, financial reporting. Use when investigating companies in СНГ (Russia, Belarus, Ukraine, Kazakhstan, Uzbekistan). All White (public) sources.
---

## Доступность инструментов (registries-блок)

Перед использованием любого реестра проверь его доступность:

| Реестр | Страна | URL | Тип доступа | Как проверить | Если недоступен |
|--------|--------|-----|------------|---------------|-----------------|
| **ЕГР** | 🇧🇾 | egr.gov.by | Web (public) | `webfetch` к egr.gov.by | ⚠️ Требует `verify=False` — сертификат НУЦ РБ. Для Python: `requests.get(..., verify=False)` |
| **ЕГРЮЛ/ЕГРИП** | 🇷🇺 | egrul.nalog.gov.ru | Web (public) | `webfetch` к nalog.gov.ru | Используй Контур.Фокус или Rusprofile как альтернативу |
| **КАД** (Картотека арбитражных дел) | 🇷🇺 | kad.arbitr.ru | Web (public) | `webfetch` к kad.arbitr.ru | Арбитражные споры юрлиц; может требовать капчу |
| **ФССП** | 🇷🇺 | fssp.gov.ru | Web (public) | `webfetch` к fssp.gov.ru | Исполнительные производства физлиц и юрлиц |
| **Федресурс** | 🇷🇺 | fedresurs.ru | Web (public) | `webfetch` к fedresurs.ru | Банкротства, значимые события юрлиц |
| **ГИР БО / БФО** | 🇷🇺 | bo.nalog.gov.ru | Web (public) | `webfetch` к bo.nalog.gov.ru | Бухгалтерская финотчётность юрлиц |
| **Реестр банкротств** | 🇧🇾 | bankrot.gov.by | Web (public) | `webfetch` к bankrot.gov.by | Банкротства в Беларуси |
| **ЕДР** | 🇺🇦 | usr.minjust.gov.ua | Web (public) | `webfetch` к usr.minjust.gov.ua | Полный аналог ЕГРЮЛ, публичный доступ |
| **Реестр ГКС** | 🇰🇿 | e.gov.kz | Web (public) | `webfetch` к e.gov.kz | БИН, статус, участники, руководитель |
| **Реестр Госкомстата** | 🇺🇿 | registr.stat.uz | Web (public) | `webfetch` к registr.stat.uz | Аналог ЕГРЮЛ; реестр НДС: my.soliq.uz |
| **OpenCorporates** | 🌍 | opencorporates.com | Web (public) | `webfetch` к opencorporates.com | 187 млн компаний; РБ и UA есть, РФ — частично |
| **Контур.Фокус** | 🇷🇺 | focus.kontur.ru | Web (коммерческий) | Платный; рекомендовать пользователю | Агрегатор 60+ источников: арбитраж, ФССП, банкротства, связи |
| **Rusprofile** | 🇷🇺 | rusprofile.ru | Web (public) | `webfetch` к rusprofile.ru | Финансовая отчётность, связанные лица, история |

**Правило**: если реестр недоступен или требует капчу — зафиксируй в «Пробелах» и предложи пользователю ручной шаг: «Открой <URL> в браузере и введи <ИНН/УНП/название>».

---

## Алгоритм: Проверка юридического лица СНГ

```
ВХОД: Название / ИНН / УНП / БИН / домен
      |
      v
[1] Реестр → ЕГР (BY), ЕГРЮЛ/ФНС (RU), ЕДР (UA), registr.stat.uz (UZ)
      |
      v
[2] Агрегатор → Контур.Фокус / Rusprofile (RU), legat.by (BY), OpenCorporates
      |
      v
[3] Финансы → ГИР БО / БФО (RU), бухотчётность
      |
      v
[4] Суды / долги → КАД (арбитраж RU), ФССП (RU), Федресурс, bankrot.gov.by (BY)
      |
      v
[5] Домен → WHOIS, crt.sh, Shodan (из osint-tools-infra)
      |
      v
[6] Персонал → LinkedIn, HH.ru, сайт компании, TGStat (упоминания в TG)
      |
      v
[7] Репутация → Яндекс.Новости, Google News, TGStat, отраслевые СМИ
      |
      v
ВЫХОД: Досье компании + Граф аффилированных лиц (Mermaid / Maltego)
```

---

## Быстрые команды (webfetch)

### Беларусь — ЕГР (поиск по названию)

```
webfetch "https://egr.gov.by/egrn/index.jsp?setl=1&nameOrg=НАЗВАНИЕ"
```
⚠️ Сертификат НУЦ РБ не входит в стандартные CA-бандлы. Для Python-скриптов используй `verify=False` + `urllib3.disable_warnings()`.
Если webfetch не справляется с сертификатом — сообщи пользователю: «Открой egr.gov.by в браузере, введи название компании».

### Беларусь — Реестр банкротств

```
webfetch "https://bankrot.gov.by"
```
Поиск по УНП или названию. Проверь наличие организации в реестре.

### Россия — ЕГРЮЛ (поиск по ИНН/ОГРН/названию)

```
webfetch "https://egrul.nalog.gov.ru/search/index.html?q=ИНН"
```
Альтернатива: Rusprofile (публичный, без капчи):
```
webfetch "https://www.rusprofile.ru/search?query=ИНН"
```

### Россия — КАД (арбитражные дела)

```
webfetch "https://kad.arbitr.ru/?query=НАЗВАНИЕ+КОМПАНИИ"
```

### Россия — ФССП (исполнительные производства)

```
webfetch "https://fssp.gov.ru/iss/ip/search?query=ФИО+ИЛИ+НАЗВАНИЕ"
```

### Украина — ЕДР

```
webfetch "https://usr.minjust.gov.ua/ua/freesearch"
```

### OpenCorporates (международный поиск)

```
webfetch "https://opencorporates.com/companies?q=НАЗВАНИЕ"
```

---

## Pre-sales применение (Беларусь) — из методологии

При проверке потенциального заказчика в РБ выполни:

1. ЕГР (egr.gov.by) → УНП, директор, дата регистрации, статус
2. Реестр банкротств (bankrot.gov.by) → наличие угрозы банкротства
3. legat.by — мультиреестровая проверка контрагентов из BY/RU/UA/UZ/KZ (рекомендовать пользователю)
4. Анализ субдоменов целевой компании (crt.sh + Amass) → понимание ИТ-инфраструктуры перед пресейлом

---

## Правовая оговорка

Все перечисленные реестры — публичные государственные базы данных (White). Сбор данных из них легален во всех юрисдикциях СНГ. Однако:

- Для РБ: не используй собранные ПД физлиц без правового основания (Закон № 99-З).
- Для РФ: обработка ПД в коммерческих целях требует соблюдения ФЗ-152.
- Реестры могут содержать устаревшие данные — всегда указывай дату запроса.
