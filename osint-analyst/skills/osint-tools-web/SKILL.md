---
name: osint-tools-web
description: Web intelligence tools — technology fingerprinting, URL discovery, and automated screenshotting. Covers whatweb, gau, waybackurls, eyewitness.
---

## Доступность инструментов (web-блок)

| Инструмент | Тип доступа | Как проверить | Если недоступен |
|------------|------------|---------------|-----------------|
| **whatweb** | CLI | `which whatweb` | Зафиксируй в «Пробелах»; альтернатива: ручная проверка HTTP-заголовков через webfetch |
| **gau** (Get All URLs) | CLI (Go) | `which gau` | Зафиксируй в «Пробелах»; альтернатива: ручной wayback machine |
| **waybackurls** | CLI (Go) | `which waybackurls` | Зафиксируй в «Пробелах»; альтернатива: ручной запрос к web.archive.org |
| **eyewitness** | CLI | `which eyewitness` | Зафиксируй в «Пробелах»; альтернатива: ручные скриншоты через webfetch (ограниченно) |

**Правило**: если инструмент недоступен — **не симулируй его использование**. Зафиксируй в «Пробелы», выбери альтернативу или предложи пользователю ручной шаг.

---

## 🌍 Блок 10 — Технологический фингерпринтинг (whatweb)

| Инструмент | Назначение                                          | Метод |
|-----------|-----------------------------------------------------|-------|
| whatweb   | Определение технологий сайта: CMS, веб-сервер, JS-фреймворки, CDN, аналитика, сертификаты | White |

**Когда применять:**
- При разведке домена: «на чём работает сайт?», «какой движок?»
- Дополнение к Shodan (порты) и crt.sh (сертификаты) — что именно работает на этих портах
- Всегда после amass enum: проверяй обнаруженные субдомены через whatweb

**Команда:**
```
whatweb -a 3 --log-verbose=whatweb_output.txt domain.com
# -a 3: агрессивность 3 (макс. информации, но больше запросов)
# --log-verbose: полный вывод в файл
```

**Парсинг результата (ключевые поля):**
```
whatweb domain.com --color=never -q
# Вывод: https://domain.com [200 OK] Country[UNITED STATES], HTTPServer[nginx/1.18.0], IP[185.x.x.x], PoweredBy[WordPress 6.2], Script[jquery-3.6.0], Title[Заголовок страницы], X-Powered-By[PHP/8.1]
```

**Для списка субдоменов (пакетный режим):**
```
cat subs.txt | while read d; do whatweb "$d" --color=never -q >> tech_profile.txt; done
```

---

## 🔗 Блок 11 — Сбор URL и ретроспектива (gau + waybackurls)

| Инструмент   | Назначение                                          | Метод |
|-------------|-----------------------------------------------------|-------|
| gau         | Сбор всех известных URL домена: Wayback Machine, AlienVault OTX, CommonCrawl, URLScan | White |
| waybackurls | Сбор URL из Internet Archive Wayback Machine        | White |

**Когда применять:**
- Разведка домена: показывает историю страниц, скрытые эндпоинты, старые версии
- Поиск чувствительных файлов: `.env`, `backup.zip`, `admin.php`, `config.js`
- Выявление API-эндпоинтов: `/api/`, `/graphql`, `/v1/`, `/swagger`

**Команды:**
```
# gau — сбор URL из 4 источников:
gau domain.com --o gau_urls.txt

# waybackurls — только из Wayback Machine:
waybackurls domain.com > wayback_urls.txt

# Фильтрация: только JS-файлы
gau domain.com | grep '\.js$' > js_files.txt

# Фильтрация: чувствительные пути
gau domain.com | grep -iE '\.env$|\.git|backup|config|admin|\.sql$'

# Объединение и сортировка уникальных URL
cat gau_urls.txt wayback_urls.txt | sort -u > all_urls.txt
```

**Скриптовый шаблон (Python):**
```python
# Запуск: python web_recon.py domain.com
import subprocess, sys

domain = sys.argv[1]

# Шаг 1: gau
subprocess.run(f"gau {domain} --o gau_{domain}.txt 2>/dev/null", shell=True)
# Шаг 2: waybackurls
subprocess.run(f"waybackurls {domain} > wb_{domain}.txt 2>/dev/null", shell=True)
# Шаг 3: объединить
with open(f"gau_{domain}.txt") as f: g = set(f)
with open(f"wb_{domain}.txt") as f: w = set(f)
all_urls = sorted(g | w)
with open(f"all_urls_{domain}.txt", "w") as f:
    f.write('\n'.join(all_urls))
print(f"[gau+waybackurls White] {len(all_urls)} уникальных URL для {domain}")
```

---

## 📸 Блок 12 — Автоматические скриншоты (eyewitness)

| Инструмент  | Назначение                                          | Метод |
|------------|-----------------------------------------------------|-------|
| eyewitness | Скриншоты списка URL: визуальный анализ инфраструктуры | White |

**Когда применять:**
- После сбора субдоменов (amass/subfinder) и URL (gau/waybackurls)
- Для визуальной инспекции: какие сайты работают, какие заброшены
- Создание «фотоотчёта» инфраструктуры для Full Report

**Ограничения:**
- Требует Chromium/Chrome (headless mode) — может не работать в минимальном окружении
- Если недоступен — предложи ручной просмотр топ-10 URL через webfetch

**Команда:**
```
eyewitness --web --headless -f urls.txt -d eyewitness_report/
# --web: запуск Chromium
# --headless: без GUI
# -f: файл со списком URL
# -d: директория для отчёта
```

**Если eyewitness недоступен:**
- Зафиксируй в «Пробелах»
- Предложи пользователю ручной шаг: «Просмотри топ-10 страниц в браузере»
- Альтернатива: `cutycapt` или `wkhtmltoimage` для отдельных URL (легче установить)

---

## Сводная таблица web-инструментов

| Тип задачи | Инструменты (по приоритету) |
|---|---|
| Технологии сайта | whatweb → ручная проверка HTTP-заголовков |
| Сбор URL / история | gau + waybackurls → ручной запрос к web.archive.org |
| Визуальный анализ | eyewitness → ручной просмотр в браузере |
