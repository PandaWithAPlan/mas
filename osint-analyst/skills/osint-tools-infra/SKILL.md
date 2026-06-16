---
name: osint-tools-infra
description: Use when investigating domains, IPs, or company infrastructure. Covers OSINT frameworks and network reconnaissance tools: Shodan, crt.sh, SecurityTrails, DNSDumpster, BGPView, theHarvester, Maltego, SpiderFoot, Recon-ng, FOFA, Censys, ZoomEye.
---

## Доступность инструментов (инфраструктурный блок)

Перед использованием любого инструмента проверь его доступность:

| Инструмент | Тип доступа | Как проверить | Если недоступен |
|------------|------------|---------------|-----------------|
| **amass** | CLI | `which amass` | Зафиксируй в «Пробелах»; альтернатива: theHarvester + crt.sh + subfinder |
| **dnsrecon** | CLI | `which dnsrecon` | Используй amass -passive |
| **subfinder** | CLI | `which subfinder` | Используй amass или crt.sh напрямую |
| **assetfinder** | CLI | `which assetfinder` | Используй amass или crt.sh напрямую |
| **theHarvester** | CLI | `which theHarvester` или `python3 -m theHarvester` | Пропусти; используй crt.sh + Google Dorks |
| **Recon-ng** | CLI | `which recon-ng` | Пропусти; используй SpiderFoot HX (если есть) |
| **Shodan** | Web API (oss-план, бесплатный) | `SHODAN_API_KEY` в env | Зафиксируй в «Пробелах»; альтернатива: crt.sh + DNSDumpster |
| **Censys** | Web API | `CENSYS_API_ID` + `CENSYS_API_SECRET` в env | Зафиксируй; альтернатива: Shodan |
| **SecurityTrails** | Web API | `SECURITYTRAILS_API_KEY` в env | Используй crt.sh (бесплатно, без API-ключа) |
| **crt.sh** | Web (public) | Всегда доступен | — |
| **BGPView** | Web (public) | **⚠️ Возможна DNS-блокировка** (проверь: `nslookup bgpview.io`). Если недоступен — зафиксируй в «Пробелах»; используй Shodan для AS-lookup |
| **DNSDumpster** | Web (public) | Всегда доступен | — |
| **FOFA** | Web API | `FOFA_KEY` в env | Зафиксируй в «Пробелах» |
| **ZoomEye** | Web API | `ZOOMEYE_KEY` в env | Зафиксируй в «Пробелах» |
| **Maltego, SpiderFoot** | Desktop | Требуют GUI/установки | Пропусти в headless-окружении |
| **EGR Беларусь** | Web (public) | Всегда доступен через `webfetch` / requests | ⚠️ **Требует `verify=False`** — сертификат Национального удостоверяющего центра РБ. Для Python-скриптов: `requests.get(..., verify=False, ...)` с `urllib3.disable_warnings()` |

**Правило**: если инструмент недоступен — **не симулируй его использование**. Зафиксируй в «Пробелы», выбери альтернативу из этого SKILL или предложи пользователю ручной шаг.

---

## 🔭 Блок 1 — Фреймворки и агрегаторы

| Инструмент      | Назначение                           | Тип          | Метод |
| --------------- | ------------------------------------ | ------------ | ----- |
| **amass (OWASP)** | Пассивная разведка: субдомены, DNS, WHOIS, сертификаты, ASN из 50+ источников | CLI | White |
| Maltego         | Граф связей: домены, IP, люди, орги  | Desktop/SaaS | White |
| SpiderFoot      | Авто-сбор OSINT по 100+ источникам   | CLI/Web UI   | White |
| Recon-ng        | Модульный разведывательный фреймворк | CLI          | White |
| OSINT Framework | Навигатор по OSINT-ресурсам          | Web          | White |
| theHarvester    | Email, субдомены, IP, открытые порты | CLI          | White |

**Когда применять:**
- amass enum -passive → **первый шаг** при разведке домена/организации: заменяет ручной whois+crt.sh+DNS одним вызовом
- amass intel -org "Company" → разведка по организации: ищет все связанные домены и IP-диапазоны
- Maltego — задачи с большим графом связей (компания + люди + инфраструктура)
- SpiderFoot — быстрый полный скан по одному идентификатору (email, домен, IP)
- Recon-ng — когда нужна модульная кастомизация под конкретный источник
- theHarvester — первый шаг при разведке по домену/организации

**amass — приоритетный инструмент для доменов:**
```
# Пассивная разведка (White, 50+ источников):
amass enum -passive -d domain.com -o amass_domain.txt

# Разведка по организации:
amass intel -org "Company Name" -o amass_org.txt

# Проверка доступности: which amass
```

---

## 🌐 Блок 2 — Сетевая разведка и инфраструктура

| Инструмент      | Назначение                              | URL                    | Метод |
|-----------------|-----------------------------------------|------------------------|-------|
| Shodan          | IoT, серверы, камеры в интернете        | shodan.io              | White |
| Censys          | Глубокий TLS-анализ, сканирование сети  | censys.io              | White |
| FOFA            | Аналог Shodan, шире по охвату           | fofa.info              | White |
| ZoomEye         | Уязвимые сервисы и устройства           | zoomeye.org            | White |
| SecurityTrails  | История DNS/WHOIS, Passive DNS          | securitytrails.com     | White |
| BGPView         | BGP-маршруты и AS-номера                | bgpview.io             | White |
| crt.sh          | Certificate Transparency Log            | crt.sh                 | White |
| DNSDumpster     | DNS-разведка, картирование поддоменов   | dnsdumpster.com        | White |
| **dnsrecon**    | Комплексная DNS-разведка: зонный трансфер, брутфорс субдоменов, reverse DNS | CLI | White |
| **subfinder**   | Быстрый пассивный поиск субдоменов (легче amass) | CLI | White |
| **assetfinder** | Поиск субдоменов и связанных доменов через crt.sh, DNSDB, HackerTarget, AlienVault | CLI | White |

**Когда применять:**
- Shodan/Censys — разведка инфраструктуры домена/компании
- FOFA/ZoomEye — если объект связан с азиатским или СНГ-сегментом
- SecurityTrails + crt.sh — история изменений DNS и смены владельцев доменов
- BGPView — связь IP-диапазонов с организацией (AS lookup)
- dnsrecon — когда amass недоступен; специализированная DNS-разведка (зонный трансфер, брут-форс)
- subfinder + assetfinder — лёгкие и быстрые альтернативы amass для поиска субдоменов

**dnsrecon — команды:**
```
# Полная пассивная + активная разведка:
dnsrecon -d domain.com -j dns_output.json
# Проверка доступности: which dnsrecon
```

**subfinder / assetfinder — быстрый поиск субдоменов:**
```
subfinder -d domain.com -o subs.txt
assetfinder --subs-only domain.com >> subs.txt
which subfinder
which assetfinder
```
