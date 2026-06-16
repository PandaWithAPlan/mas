---
name: osint-tools-scripts
description: Use ONLY when the agent decides to run an automated script (Python). Contains ready-to-use templates for username search, email leak check, DNS/WHOIS recon, EGR Belarus parsing, and correlation graph building. Load lazily — do not load unless a script is actually needed.
---

> ⚠️ **LAZY LOAD**: загружай этот навык только когда принято решение запустить один или несколько скриптов. Не загружай для задач, выполняемых через webfetch/bash без скриптов.

---

## Правила скриптинга

- Перед запуском проверь доступность зависимостей: `pip show <package>`
- Каждый скрипт содержит правовую оговорку
- Скрипт должен выполняться в `~/osint/output/` (рабочая директория для результатов)
- Обрабатывай ошибки:
  - network timeout → повтори 1 раз через 5 сек
  - tool not found / API key missing → зафиксируй, используй альтернативу
  - 403/429 → зафиксируй в «Пробелах», переходи к следующему

---

## Шаблон 1: Поиск никнейма (Sherlock + Snoop)

```python
# Зависимости: pip install sherlock-project
# Snoop Project предустановлен в ~/osint/tools/snoop-project/
# Запуск: python osint_username.py TARGET_USERNAME

import subprocess, sys, os

if len(sys.argv) < 2:
    print("Usage: python osint_username.py <username>")
    sys.exit(1)

username = sys.argv[1]

def run_tool(cmd, label):
    print(f"[*] {label}: поиск {username}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode != 0 and "not found" not in result.stderr.lower():
            print(f"[!] {label}: exit code {result.returncode} — {result.stderr[:200]}")
        else:
            print(f"[+] {label}: завершён")
    except FileNotFoundError:
        print(f"[!] {label}: инструмент не найден в PATH — установите или пропустите")
    except subprocess.TimeoutExpired:
        print(f"[!] {label}: превышен лимит времени (120с)")

# Sherlock — глобальный поиск (pip install sherlock-project)
run_tool(["sherlock", username, "--output", f"{username}_sherlock.txt"], "Sherlock")

# Snoop Project — СНГ-поиск (установлен в ~/osint/tools/snoop-project/)
run_tool(["python3", os.path.expanduser("~/osint/tools/snoop-project/snoop.py"), username], "Snoop Project")
# Правовая оговорка: только публично доступные платформы (White)
```

---

## Шаблон 2: Email → утечки (HIBP + LeakCheck API)

```python
# Зависимости: pip install requests
# Запуск: python leak_check.py target@email.com YOUR_LEAKCHECK_API_KEY

import requests, sys
from requests.exceptions import RequestException, Timeout

if len(sys.argv) < 3:
    print("Usage: python leak_check.py <email> <leakcheck_api_key>")
    sys.exit(1)

email = sys.argv[1]
api_key = sys.argv[2]

def safe_get(url, headers=None, params=None):
    try:
        return requests.get(url, headers=headers, params=params, timeout=15)
    except Timeout:
        print(f"[!] Timeout: {url}")
        return None
    except RequestException as e:
        print(f"[!] Request failed: {url} — {e}")
        return None

# White: Have I Been Pwned
hibp = safe_get(
    f"https://haveibeenpwned.com/api/v3/breachedaccount/{email}",
    headers={"hibp-api-key": "YOUR_HIBP_KEY", "User-Agent": "OSINT-Script"}
)
if hibp:
    print(f"[HIBP White] {hibp.status_code}: {hibp.text[:500]}")
else:
    print("[HIBP White] Не удалось выполнить запрос")

# Grey: LeakCheck
lc = safe_get(
    f"https://leakcheck.io/api/public",
    params={"key": api_key, "check": email}
)
if lc:
    print(f"[LeakCheck Grey] Достоверность ~70%: {lc.json()}")
else:
    print("[LeakCheck Grey] Не удалось выполнить запрос")
# Правовая оговорка [GREY]: проверить применимость ФЗ-152 / Закона РБ №99-З
```

---

## Шаблон 3: DNS/WHOIS разведка домена

```python
# Зависимости: pip install python-whois dnspython requests
# Запуск: python dns_recon.py target.com

import whois, dns.resolver, requests, sys
from requests.exceptions import RequestException, Timeout

if len(sys.argv) < 2:
    print("Usage: python dns_recon.py <domain>")
    sys.exit(1)

domain = sys.argv[1]

# WHOIS
try:
    w = whois.whois(domain)
    print(f"[WHOIS] Registrar: {w.registrar} | Created: {w.creation_date}")
except Exception as e:
    print(f"[WHOIS] Ошибка: {e}")

# DNS записи
for rtype in ["A", "MX", "NS", "TXT"]:
    try:
        answers = dns.resolver.resolve(domain, rtype, lifetime=10)
        print(f"[DNS {rtype}] {[str(r) for r in answers]}")
    except dns.resolver.NoAnswer:
        print(f"[DNS {rtype}] Нет записей")
    except dns.resolver.NXDOMAIN:
        print(f"[DNS {rtype}] Домен не существует")
        break
    except Exception as e:
        print(f"[DNS {rtype}] Ошибка: {e}")

# Certificate Transparency (crt.sh)
try:
    r = requests.get(f"https://crt.sh/?q=%.{domain}&output=json", timeout=15)
    r.raise_for_status()
    certs = r.json()
    print(f"[crt.sh] Найдено сертификатов: {len(certs)}")
    if certs:
        print(f"[crt.sh] Последние: {[c['name_value'] for c in certs[:5]]}")
except Timeout:
    print("[crt.sh] Timeout")
except RequestException as e:
    print(f"[crt.sh] Ошибка запроса: {e}")
except ValueError:
    print("[crt.sh] Некорректный JSON в ответе (возможно, crt.sh недоступен)")
```

---

## Шаблон 4: Парсинг реестра EGR Беларусь

```python
# Зависимости: pip install requests beautifulsoup4 urllib3
# Запуск: python egr_by.py "ООО Название"
# ⚠️ Сертификат Национального удостоверяющего центра РБ не входит в стандартные CA-бандлы.
# Требуется verify=False + urllib3.disable_warnings()
# Правовая оговорка: публичный реестр (White), данные для верификации

import requests
import urllib3
from bs4 import BeautifulSoup
import sys
from requests.exceptions import RequestException, Timeout

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

if len(sys.argv) < 2:
    print("Usage: python egr_by.py \"ООО Название\"")
    sys.exit(1)

query = sys.argv[1]
url = "https://egr.gov.by/egrn/index.jsp"
params = {"setl": 1, "nameOrg": query}

try:
    r = requests.get(url, params=params, timeout=15, verify=False,
                     headers={"User-Agent": "Mozilla/5.0"})
    r.raise_for_status()
except Timeout:
    print("[!] Timeout: egr.gov.by не отвечает")
    sys.exit(1)
except RequestException as e:
    print(f"[!] Request failed: {e}")
    sys.exit(1)

soup = BeautifulSoup(r.text, "html.parser")
rows = soup.find_all("tr", class_="tableEGRText")
if not rows:
    print("[!] Ничего не найдено (возможно, изменилась структура сайта или нет результатов)")
    sys.exit(0)

for row in rows[:10]:
    cols = row.find_all("td")
    if cols and len(cols) >= 3:
        print(f"УНП: {cols[0].text.strip()} | Название: {cols[1].text.strip()} | Статус: {cols[2].text.strip()}")
```

---

## Шаблон 5: Корреляция данных → граф связей

```python
# Зависимости: pip install networkx matplotlib
# Запуск: python build_graph.py
# Перед запуском замени edges на свои реальные данные

import networkx as nx
import sys

# Добавляй найденные связи: (объект_A, тип_связи, объект_B)
edges = [
    ("ФИО_объекта", "владеет", "ООО_Компания"),
    ("ООО_Компания", "использует", "domain.by"),
    ("domain.by", "IP", "185.x.x.x"),
    ("ФИО_объекта", "телефон", "+375XXXXXXXXX"),
]

if not edges:
    print("[!] Нет данных для построения графа")
    sys.exit(0)

G = nx.DiGraph()
for src, rel, dst in edges:
    G.add_edge(src, dst, label=rel)

print(f"[*] Граф: {len(G.nodes())} узлов, {len(G.edges())} рёбер")
for src, dst, data in G.edges(data=True):
    print(f"  {src} --[{data['label']}]--> {dst}")

# Визуализация (может не работать в headless-окружении)
try:
    import matplotlib
    matplotlib.use("Agg")  # headless mode
    import matplotlib.pyplot as plt
    pos = nx.spring_layout(G, k=2, seed=42)
    nx.draw(G, pos, with_labels=True, node_color="lightblue",
            node_size=2000, font_size=8, arrows=True)
    edge_labels = {(u, v): d["label"] for u, v, d in G.edges(data=True)}
    nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, font_size=7)
    plt.savefig("osint_graph.png", dpi=150, bbox_inches="tight")
    print("[*] Граф сохранён: osint_graph.png")
except ImportError:
    print("[!] matplotlib не установлен — граф сохранён только в текстовом виде")
except Exception as e:
    print(f"[!] Ошибка визуализации: {e} — граф доступен в текстовом виде выше")
```

---

## Шаблон 6: Holehe — проверка регистраций email (White)

```python
# Зависимости: pip install holehe
# Запуск: python holehe_check.py target@email.com

import subprocess, sys, json

if len(sys.argv) < 2:
    print("Usage: python holehe_check.py <email>")
    sys.exit(1)

email = sys.argv[1]

def run_holehe(target):
    print(f"[*] Holehe: проверка {target} в 120+ сервисах")
    try:
        result = subprocess.run(
            ["holehe", target, "--only-used", "--no-color"],
            capture_output=True, text=True, timeout=90
        )
        if result.returncode != 0:
            print(f"[!] Holehe: exit code {result.returncode} — {result.stderr[:200]}")
            return

        # Парсим результат: строки с "[+]" = зарегистрирован
        registered = []
        for line in result.stdout.split('\n'):
            if '[+]' in line:
                registered.append(line.strip())
                print(f"  [REGISTERED] {line.strip()}")

        if not registered:
            print("[Holehe White] Email не найден ни на одном сервисе")
        else:
            print(f"[Holehe White] Найдено регистраций: {len(registered)}")
    except FileNotFoundError:
        print("[!] Holehe: инструмент не найден — pip install holehe")
    except subprocess.TimeoutExpired:
        print("[!] Holehe: превышен лимит времени (90с)")

run_holehe(email)
# Правовая оговорка: публичные данные о регистрации (White)
```

---

## Шаблон 7: Разведка по телефону — phoneinfoga (White)

```python
# Требуется: phoneinfoga (CLI, бинарник с GitHub Releases)
# Запуск: python phone_check.py +375****4567

import subprocess, sys, re

if len(sys.argv) < 2:
    print("Usage: python phone_check.py <номер>")
    sys.exit(1)

phone = sys.argv[1]

# Нормализация номера: оставляем + и цифры
phone_clean = phone if phone.startswith('+') else f"+{phone}"

print(f"[*] phoneinfoga: разведка номера {phone_clean}")

try:
    result = subprocess.run(
        ["phoneinfoga", "scan", "-n", phone_clean],
        capture_output=True, text=True, timeout=60
    )
    if result.returncode != 0:
        print(f"[!] phoneinfoga: exit code {result.returncode} — {result.stderr[:300]}")
    else:
        stdout = result.stdout
        # Извлекаем ключевые строки
        key_fields = {
            'country': 'Страна', 'carrier': 'Оператор',
            'location': 'Регион', 'line_type': 'Тип линии',
            'international': 'Международный формат', 'local': 'Локальный формат'
        }
        found = []
        for field, label in key_fields.items():
            match = re.search(rf'{field}[:\s]+(.+)', stdout, re.IGNORECASE)
            if match:
                found.append(f"[phoneinfoga White] {label}: {match.group(1).strip()}")
                print(found[-1])

        # Online footprints
        if 'footprints' in stdout.lower() or 'disposable' in stdout.lower():
            for line in stdout.split('\n'):
                if any(kw in line.lower() for kw in ['google', 'ovh', 'skype', 'whatsapp', 'disposable']):
                    print(f"[phoneinfoga White] Footprint: {line.strip()}")

        if not found:
            print("[phoneinfoga White] Результат получен, см. полный вывод выше")
            print(stdout[:1500])

except FileNotFoundError:
    print("[!] phoneinfoga не установлен")
except subprocess.TimeoutExpired:
    print("[!] phoneinfoga: превышен лимит времени (60с)")
# Правовая оговорка: публичный API numverify.com / Google; данные оператора открыты (White)
```

---

## Шаблон 8: Агрегатор утечек — h8mail (Grey)

```python
# Зависимости: pip install h8mail
# Конфиг: ~/.config/h8mail/h8mail.ini (API-ключи: HIBP, DeHashed, LeakCheck, SnusBase)
# Запуск: python h8mail_check.py target@email.com
# ⚠️ [GREY] Запускать ТОЛЬКО после Grey-эскалации и подтверждения пользователем!

import subprocess, sys, json, os

if len(sys.argv) < 2:
    print("Usage: python h8mail_check.py <email>")
    sys.exit(1)

email = sys.argv[1]
config_path = os.path.expanduser("~/.config/h8mail/h8mail.ini")

if not os.path.exists(config_path):
    print(f"[!] h8mail: конфиг не найден — {config_path}")
    print("[!] Создай конфиг с API-ключами: https://github.com/khast3x/h8mail")
    sys.exit(1)

print(f"[*] h8mail: агрегация утечек для {email} [GREY]")
print(f"[GREY] Правовой риск: HIGH — ФЗ-152 / 99-З")
print(f"[GREY] Достоверность результатов: 60-80%")

try:
    result = subprocess.run(
        ["h8mail", "-t", email, "-c", config_path, "--json", os.path.expanduser("~/osint/output/h8mail_output.json"), "--local-only"],
        capture_output=True, text=True, timeout=120
    )
    if result.returncode != 0:
        print(f"[!] h8mail: exit code {result.returncode} — {result.stderr[:300]}")

    # Парсим JSON-результат
    json_path = os.path.expanduser("~/osint/output/h8mail_output.json")
    if os.path.exists(json_path):
        with open(json_path) as f:
            data = json.load(f)
        breaches = data.get('targets', [{}])[0].get('data', [])
        print(f"[h8mail Grey] Найдено утечек: {len(breaches)}")
        for b in breaches[:15]:
            name = b.get('breach', 'unknown')
            pwned_date = b.get('date', 'N/A')
            print(f"  [GREY] {name} | {pwned_date}")
        if len(breaches) > 15:
            print(f"  ... и ещё {len(breaches) - 15} (полный список в {json_path})")
    else:
        print("[h8mail Grey] JSON-отчёт не сгенерирован; см. stdout выше")
        print(result.stdout[:1500])

except FileNotFoundError:
    print("[!] h8mail не установлен — pip install h8mail")
except subprocess.TimeoutExpired:
    print("[!] h8mail: превышен лимит времени (120с)")
# Правовая оговорка [GREY]: работа с утечками; проверить применимость ФЗ-152 / Закона РБ №99-З / GDPR
# Кросс-верификация обязательна: минимум 2 источника для каждого факта из утечек
```

---

## Шаблон 9: Metagoofil — сбор метаданных с сайта (White)

```python
# Зависимости: pip install metagoofil (или git clone https://github.com/laramies/metagoofil)
# Запуск: python metagoofil_scan.py company.com
# Правовая оговорка: публичные документы на сайте (White), право на парсинг открытых данных

import subprocess, sys, os, glob

if len(sys.argv) < 2:
    print("Usage: python metagoofil_scan.py <domain>")
    sys.exit(1)

domain = sys.argv[1]
workdir = os.path.expanduser(f"~/osint/output/metagoofil_{domain.replace('.', '_')}")
os.makedirs(workdir, exist_ok=True)

print(f"[*] Metagoofil: сбор метаданных с {domain} [White]")
print(f"[*] Рабочая директория: {workdir}")

doc_types = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]

for dtype in doc_types:
    print(f"[*] Поиск: *.{dtype}")
    try:
        result = subprocess.run(
            ["metagoofil", "-d", domain, "-t", dtype, "-l", "50", "-n", "10",
             "-o", workdir, "-f", f"results_{dtype}.html"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode != 0:
            print(f"[!] Metagoofil ({dtype}): exit code {result.returncode} — {result.stderr[:200]}")
        else:
            # Проверяем, нашлись ли файлы
            downloaded = glob.glob(f"{workdir}/*.{dtype}")
            print(f"[Metagoofil White] {dtype}: скачано {len(downloaded)} файлов")
            if downloaded:
                # Анализируем метаданные через exiftool
                for fpath in downloaded[:5]:
                    try:
                        meta = subprocess.run(
                            ["exiftool", "-Author", "-Creator", "-Title", "-CreateDate", fpath],
                            capture_output=True, text=True, timeout=10
                        )
                        if meta.stdout.strip():
                            print(f"  [META] {os.path.basename(fpath)}: {meta.stdout.strip()[:200]}")
                    except (FileNotFoundError, subprocess.TimeoutExpired):
                        pass
    except FileNotFoundError:
        print(f"[!] Metagoofil не установлен — pip install metagoofil")
        break
    except subprocess.TimeoutExpired:
        print(f"[!] Metagoofil ({dtype}): превышен лимит времени (120с)")

print(f"[Metagoofil White] Завершено. Результаты: {workdir}")
print("[*] Для ручного анализа: exiftool *.pdf | grep -E 'Author|Creator'")
# Правовая оговорка: только публично доступные документы на сайте (White)
```
