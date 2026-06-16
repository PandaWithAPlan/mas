---
name: osint-tools-grey
description: Use ONLY after Grey escalation is confirmed by the user (see osint-methodology escalation protocol). Covers Darknet monitoring, Telegram OSINT bots (СНГ), Tor-based research, and commercial Grey tools. ALL results must be marked [GREY] with reliability assessment.
---

> ⚠️ **SAFETY GATE**: этот навык загружается только после того, как пользователь явно подтвердил применение Grey-методов через протокол эскалации из `osint-methodology`. Никогда не загружай этот навык для White-only задач.

## Доступность инструментов (Grey-блок)

| Инструмент | Тип доступа | Как проверить | Если недоступен |
|------------|------------|---------------|-----------------|
| **Telegram-боты** | **НЕ АВТОМАТИЗИРУЕМЫ** | Только ручная рекомендация пользователю | Укажи бота, ссылку, что искать; не симулируй результат |
| **Darknet SaaS** (ниже) | **НЕ ДОСТУПНЫ** | Коммерческие продукты | Упомяни как опцию; не симулируй использование |
| **Tor daemon** | CLI | `which tor` | Зафиксируй в «Пробелах»: «Tor не установлен». Не пытайся установить. |
| **OnionSearch** | CLI | `which onionsearch` | Зафиксируй в «Пробелах»; используй Python-запросы как альтернативу. |
| **Python stem** | Python | `python3 -c "import stem"` | Зафиксируй в «Пробелах». |
| **Python socks** | Python | `python3 -c "import socks"` | Зафиксируй в «Пробелах». |

**Правило**: если инструмент недоступен — **не симулируй его использование**. Зафиксируй в «Пробелы», предложи пользователю ручной шаг.

---

## 🌑 Блок 5 — Darknet: мониторинг и разведка

| Инструмент              | Назначение                                          | Метод   |
|-------------------------|-----------------------------------------------------|---------|
| DarkOwl Vision          | Мониторинг Dark Web в реальном времени              | Grey ⚠️ |
| Flare Systems           | Автоматический мониторинг даркнет-форумов           | Grey ⚠️ |
| Recorded Future         | Threat Intelligence + Dark Web индексация           | Grey ⚠️ |
| Liferaft                | Мониторинг соцсетей, Deep Web и Dark Web            | Grey ⚠️ |
| Cobwebs                 | Clearnet + Darknet, финансовый анализ               | Grey ⚠️ |
| Robin (OSINT)           | AI-поиск данных в Dark Web                          | Grey ⚠️ |
| Tor Browser + OnionSearch | Ручной поиск по .onion ресурсам                  | Grey ⚠️ |

**Правовой контекст СНГ:**
- РБ (Закон № 99-З о персональных данных): мониторинг открытых .onion-ресурсов
  не криминализирован; операции с ПД физлиц — требуют правового основания.
- РФ (ФЗ-152): аналогично. Использование данных из утечек в коммерческих целях —
  риск HIGH.
- Рекомендация: использовать только для идентификации угроз и верификации,
  не для построения доказательной базы без юридического сопровождения.

---

## 📱 Блок 6 — Telegram-боты для OSINT [СНГ, Grey]

> ⚠️ **[GREY] Правовой риск: HIGH** (РБ, РФ)
> Достоверность: 60–80%. Кросс-верификация обязательна.

| Бот           | Что ищет                                                   |
|---------------|------------------------------------------------------------|
| Глаз Бога     | Телефон, ФИО, email, Telegram-ник → адрес, соцсети         |
| Quick OSINT   | Телефон → ФИО, оператор, регион, соцсети, маркер утечек    |
| TeleSINT      | Telegram ID → дата рег., история username, публичные чаты  |
| Users Box     | Телефон → ФИО, соцсети, фото, адрес                       |
| OVERLOAD      | Комплекс ИБ+OSINT: утечки, соц. инженерия, группы         |
| Funstat       | Telegram-активность, группы, примерная геолокация          |
| Шерлок (бот)  | Поиск по 300+ платформам прямо в Telegram                  |

**Алгоритм применения (только после эскалации):**
1. Начинать с Quick OSINT или Глаз Бога → получить первичную картину
2. Уточнять через TeleSINT если объект активен в Telegram
3. Верифицировать через White-источники (реестры, соцсети)
4. Зафиксировать: источник = бот, метод = Grey, достоверность = требует проверки

**Важно: Telegram-боты не автоматизируемы.** Ты даёшь пользователю рекомендацию: какого бота использовать, что искать, на что обратить внимание. Не симулируй результат вызова бота.

---

## 📧 Блок 7 — CLI-инструменты Grey: утечки и секреты

> ⚠️ **[GREY] Правовой риск: HIGH** (РБ, РФ, GDPR)
> Достоверность: 60–80%. Кросс-верификация обязательна.

| Инструмент   | Назначение                                          | Доступ |
|-------------|-----------------------------------------------------|--------|
| **h8mail**  | Агрегатор утечек: email → 15+ провайдеров (HIBP, DeHashed, LeakCheck, SnusBase, WeLeakInfo) | CLI, требуется конфиг `~/.config/h8mail/h8mail.ini` с API-ключами |
| **trufflehog** | Сканирование GitHub/GitLab на утекшие API-ключи, пароли, токены | CLI |
| **ghunt**   | OSINT Google-аккаунта: email → Google ID, YouTube, Maps, календарь, Hangouts | CLI, требует авторизации в Google |

**Алгоритм применения (только после эскалации):**
- h8mail — единый вызов к 15+ провайдерам утечек; результат в JSON
- trufflehog — поиск секретов в GitHub/GitLab организации; критично для due diligence
- ghunt — если объект использует Google-сервисы; требует cookies авторизации

**Команды:**
```
# h8mail — агрегация утечек по email:
h8mail -t target@email.com -c ~/.config/h8mail/h8mail.ini --json output.json

# trufflehog — поиск секретов в GitHub организации:
trufflehog github --org="CompanyName" --json --only-verified

# ghunt — проверка Google-аккаунта (требует предварительной авторизации):
ghunt email target@gmail.com
```

**Правовая оговорка [GREY]:**
- h8mail: работа с утечками — ФЗ-152 (РФ), 99-З (РБ), GDPR (ЕС)
- trufflehog: публичные репозитории (White); приватные/утекшие секреты (Grey)
- ghunt: взаимодействие с Google API от имени авторизованного пользователя — проверить Google ToS
- Для всех: только верификация и due diligence; не для построения доказательной базы без юр. сопровождения

---

## 🧅 Блок 8 — Tor-based OSINT (Grey)

> ⚠️ **[GREY] Правовой риск: MEDIUM** (РБ, РФ)
> Tor легален. Риск определяется характером активности:
> - Пассивный сбор .onion-ресурсов (поиск, чтение) — LOW
> - Активный скрапинг .onion — MEDIUM
> - Взаимодействие с нелегальными маркетплейсами — BLACK (запрещено)
> Достоверность данных из .onion: 50–70%. Кросс-верификация через clearnet обязательна.

### Предварительные условия (должны быть установлены заранее)

Перед использованием проверь доступность каждого компонента:

| Компонент | Проверка | Если недоступен |
|-----------|----------|-----------------|
| Tor daemon (SOCKS5 на `127.0.0.1:9050`) | `curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip` — должен вернуть JSON с `"IsTor":true` | Зафиксируй в «Пробелах»: «Tor недоступен». Не пытайся установить. |
| stem (Python) | `python3 -c "import stem"` | Зафиксируй в «Пробелах». |
| PySocks + requests[socks] | `python3 -c "import socks, requests"` | Зафиксируй в «Пробелах». |
| onionsearch (CLI) | `which onionsearch` | Зафиксируй в «Пробелах»; используй Python-запросы к onion-поисковикам как альтернативу. |

**Важно:** torsocks и proxychains4 недоступны в данном окружении. Не пытайся их использовать — работай только через Python (stem + socks).

### Быстрая проверка: Tor жив?

```bash
# Проверка SOCKS-прокси
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('[Tor]', 'OK' if d.get('IsTor') else 'FAIL', '| Exit IP:', d.get('IP','N/A'))"
```

Если проверка зависла >10 сек или вернула `FAIL` — Tor недоступен. Зафиксируй в «Пробелах» и **переходи к другим методам** (не жди Tor).

### Сценарий 1: HTTP-запросы через Tor (Python)

```python
# Используй, когда Tor доступен и нужно скрыть источник запроса
# Правовая оговорка [GREY]: анонимизация через Tor; проверь юрисдикцию

import requests

socks_proxy = "socks5h://127.0.0.1:9050"
target = "https://example.com"

try:
    r = requests.get(
        target,
        proxies={"http": socks_proxy, "https": socks_proxy},
        timeout=30,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0"}
    )
    print(f"[Tor] {target} → {r.status_code} ({len(r.text)} bytes)")
except requests.exceptions.Timeout:
    print("[!] Tor timeout — вероятно, сеть блокирует Tor")
except requests.exceptions.ConnectionError as e:
    print(f"[!] Tor недоступен: {e}")
```

### Сценарий 2: Доступ к .onion-сайтам (Python)

```python
# Правовая оговорка [GREY]: доступ к .onion-ресурсам; не взаимодействуй с нелегальным контентом

import requests

onion_url = "http://checkona4nikrim5gr.onion"  # замени на целевой .onion
socks_proxy = "socks5h://127.0.0.1:9050"

try:
    r = requests.get(onion_url, proxies={"http": socks_proxy, "https": socks_proxy}, timeout=30)
    print(f"[.onion] {r.status_code} ({len(r.text)} bytes)")
except requests.exceptions.Timeout:
    print("[!] .onion timeout — Tor недоступен или сайт не отвечает")
except Exception as e:
    print(f"[!] Ошибка доступа: {e}")
```

### Сценарий 3: Управление Tor через stem

```python
# Позволяет проверить статус, сменить exit-ноду, получить версию
# Правовая оговорка: управление Tor-демоном (White)

from stem.control import Controller
from stem import Signal

try:
    with Controller.from_port(port=9051) as controller:
        controller.authenticate()
        print(f"[Tor] Версия: {controller.get_version()}")

        # Текущий статус bootstrap
        bootstrap = controller.get_info('status/bootstrap-phase')
        print(f"[Tor] Bootstrap: {bootstrap}")

        # Смена exit-ноды (новый IP)
        controller.signal(Signal.NEWNYM)
        print("[Tor] Цепь перестроена")
except Exception as e:
    print(f"[!] Tor controller недоступен (порт 9051): {e}")
```

### Сценарий 4: OnionSearch — поиск .onion-ресурсов (CLI)

```bash
# Требует работающий Tor на 127.0.0.1:9050
# Поиск .onion-сайтов по ключевому слову
onionsearch "company name" --output onion_results.json

# Поиск упоминаний домена в .onion
onionsearch "domain.com" --limit 20
```

Если onionsearch недоступен — ручная рекомендация пользователю: Ahmia, Torch, NotEvil.

### Когда Tor недоступен (fallback)

Если проверка показала, что Tor не работает:

1. **Зафиксируй в «Пробелах»**: «Tor недоступен (сеть блокирует relay'и / не установлен)»
2. **Не пытайся установить или настроить** Tor — это не задача агента
3. **Продолжи расследование** через clearnet-методы (White + другие Grey)
4. **Укажи пользователю** возможность ручного запуска Tor Browser для .onion-разведки

### Что можно / нельзя через Tor

**Можно:**
- Пассивный сбор публичной информации с анонимизацией источника
- Поиск .onion-ресурсов, релевантных объекту
- WHOIS/DNS-запросы с сохранением приватности исследователя

**Нельзя:**
- Покупки на даркнет-маркетплейсах (BLACK)
- Участие в форумах/чатах нелегальной тематики (BLACK)
- Эксплуатация уязвимостей .onion-сайтов (BLACK)
- Сканирование портов .onion-хостов (Grey, высокий риск)

**Не нужно:**
- Для clearnet-ресурсов без риска деанонимизации исследователя
- Для API-запросов с персональным ключом (ключ деанонимизирует)
- Если задержка критична (Tor добавляет 1–5 сек на запрос)
