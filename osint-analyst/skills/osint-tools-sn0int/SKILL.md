---
name: osint-tools-sn0int
description: Semi-automatic OSINT framework with 150+ modules. Covers email, username, phone, domain, IP, cryptocurrency, and social media analysis. Use as a modular alternative to running individual tools.
---

> ⚠️ **MODULAR FRAMEWORK**: sn0int покрывает широкий спектр OSINT-задач, но требует понимания, какой модуль White, а какой Grey. Ниже — карта модулей с классификацией по методологии.

## Доступность

| Параметр | Значение |
|---|---|
| Проверка | `which sn0int` |
| Если недоступен | Используй отдельные инструменты из других навыков (Sherlock, HIBP, amass, phoneinfoga) |

---

## Карта модулей (White/Grey)

### White-модули (публичные источники, безопасно)

| Модуль | Тип объекта | Назначение |
|--------|-----------|------------|
| `sn0int use pgp/locate` | Email/PGP | Поиск PGP-ключа по email |
| `sn0int use dns/mx` | Домен | MX-записи домена |
| `sn0int use dns/ns` | Домен | NS-серверы домена |
| `sn0int use dns/a` | Домен/IP | A-записи |
| `sn0int use dns/aaaa` | Домен/IP | AAAA-записи (IPv6) |
| `sn0int use dns/txt` | Домен | TXT-записи (SPF, DKIM) |
| `sn0int use dns/soa` | Домен | SOA-запись |
| `sn0int use geoip/asn-lookup` | IP | ASN-поиск по IP |
| `sn0int use geoip/geoip` | IP | Геолокация IP |
| `sn0int use whois/whois` | Домен/IP | WHOIS-информация |

### Grey-модули (утечки, полуоткрытые данные, требуют эскалации)

| Модуль | Тип объекта | Назначение |
|--------|-----------|------------|
| `sn0int use pwned/breached` | Email | Проверка в HIBP |
| `sn0int use otx/ip` | IP | AlienVault OTX — репутация IP |
| `sn0int use otx/domain` | Домен | AlienVault OTX — связанные индикаторы |
| `sn0int use wayback/urls` | Домен | URL из Wayback Machine |
| `sn0int use threatminer/domain` | Домен | ThreatMiner — пассивный DNS |
| `sn0int use virustotal/domain` | Домен | VirusTotal — репутация домена |
| `sn0int use virustotal/ip` | IP | VirusTotal — репутация IP |

**Правило:** Grey-модули требуют эскалации согласно `osint-methodology`. Не запускай Grey-модули без подтверждения пользователя.

---

## Типовые сценарии

### Сценарий 1: Быстрая разведка домена (White)

```bash
# Инициализация рабочей области
sn0int init domain_recon

# Сбор DNS
sn0int run dns/mx --domain domain.com
sn0int run dns/ns --domain domain.com
sn0int run dns/a --domain domain.com
sn0int run dns/txt --domain domain.com
sn0int run whois/whois --domain domain.com

# Экспорт результатов
sn0int export --json domain_recon.json
```

### Сценарий 2: Разведка email (White + Grey после эскалации)

```bash
sn0int init email_recon

# White: PGP-ключи
sn0int run pgp/locate --email target@domain.com

# Grey (только после эскалации):
sn0int run pwned/breached --email target@domain.com
```

### Сценарий 3: Разведка IP (White + Grey после эскалации)

```bash
sn0int init ip_recon

# White:
sn0int run geoip/asn-lookup --ip 185.x.x.x
sn0int run geoip/geoip --ip 185.x.x.x
sn0int run whois/whois --ip 185.x.x.x

# Grey (только после эскалации):
sn0int run otx/ip --ip 185.x.x.x
sn0int run virustotal/ip --ip 185.x.x.x
```

---

## Когда использовать sn0int vs отдельные инструменты

| Ситуация | Что использовать |
|---|---|
| Простой запрос (1 объект, 1 тип данных) | Отдельные инструменты (amass, phoneinfoga, Sherlock) |
| Комплексный запрос (домен + IP + email) | sn0int — единый интерфейс, меньше контекста |
| Нужна кастомизация / скриптинг | Отдельные Python-шаблоны из `osint-tools-scripts` |
| Быстрый триаж (первые результаты за 30 сек) | Отдельные лёгкие инструменты (subfinder, whatweb) |
| Полный automated сбор | sn0int с цепочкой модулей |

---

## Правовая оговорка

- White-модули: без ограничений, публичные данные
- Grey-модули: только после эскалации согласно `osint-methodology`; маркировка `[GREY]` обязательна
- Black OSINT: sn0int не содержит модулей Black OSINT; если обнаружен такой модуль — не использовать
