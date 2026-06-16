---
name: html-report
description: Генерация красивого HTML-отчёта для пользователя на основе структурированных данных из report-data-extract
license: MIT
compatibility: opencode
---

Применяй после `report-data-extract`. Навык берёт структурированный data-объект
и генерирует полноценный HTML-документ с CSS-стилизацией, таблицами, цветовой
кодировкой статусов и Mermaid-диаграммами.

# Кто использует

| Агент | Когда |
|-------|-------|
| `reviewer` | После получения data-объекта от report-data-extract и doc-consistency-check |

# Концепция

Пользователь не должен читать Markdown с техническими артефактами. Он должен
получить красивый, информативный документ, который можно открыть в браузере,
распечатать или приложить к PR/MR.

Отчёт использует:
- Чистый HTML5 + встроенный CSS (без внешних зависимостей)
- Mermaid.js через CDN для диаграмм
- Цветовое кодирование: зелёный/красный/янтарный для статусов
- Адаптивную вёрстку (читается на десктопе и планшете)

# Процедура

## Шаг 0. Входные данные

Reviewer передаёт data-объект от `report-data-extract` + результат doc-consistency-check:

```
data: { ... }          // полный объект из report-data-extract
doc_check: {
  status: "ok" | "issues",
  issues: [{file: "...", problem: "...", status: "fixed" | "needs_attention"}] | []
} | null
```

## Шаг 1. Выбери вариант HTML-шаблона

Используй **полный шаблон** если:
- data-объект содержит implementation.front ИЛИ implementation.back
- testing.summary.overall.total > 0
- guardian.verdict присутствует

Используй **сокращённый шаблон** (без implementation/testing/guardian секций) если:
- Это pre-implementation отчёт (только требования + дизайн)
- Либо если соответствующие данные = null

## Шаг 2. Сгенерируй HTML

### CSS-фреймворк (всегда включён)

```html
<style>
  :root {
    --bg: #0f1117;
    --surface: #1a1d27;
    --surface2: #232733;
    --border: #2a2f3d;
    --text: #e1e4ed;
    --text2: #8b8fa8;
    --green: #22c55e;
    --green-bg: rgba(34,197,94,0.12);
    --red: #ef4444;
    --red-bg: rgba(239,68,68,0.12);
    --amber: #f59e0b;
    --amber-bg: rgba(245,158,11,0.12);
    --blue: #3b82f6;
    --blue-bg: rgba(59,130,246,0.12);
    --purple: #a855f7;
    --radius: 8px;
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    padding: 24px;
  }
  .container { max-width: 960px; margin: 0 auto; }
  .header { text-align: center; padding: 48px 0 32px; border-bottom: 1px solid var(--border); margin-bottom: 32px; }
  .header h1 { font-size: 28px; font-weight: 700; margin-bottom: 8px; }
  .header .meta { color: var(--text2); font-size: 14px; }
  .badge { display: inline-block; padding: 4px 12px; border-radius: 100px; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
  .badge-success { background: var(--green-bg); color: var(--green); }
  .badge-warn { background: var(--amber-bg); color: var(--amber); }
  .badge-danger { background: var(--red-bg); color: var(--red); }
  .badge-info { background: var(--blue-bg); color: var(--blue); }
  .hero { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 32px; margin-bottom: 24px; }
  .hero-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; }
  .hero-card { text-align: center; }
  .hero-card .value { font-size: 32px; font-weight: 700; }
  .hero-card .label { font-size: 12px; color: var(--text2); text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px; }
  section { margin-bottom: 24px; }
  section h2 { font-size: 20px; font-weight: 600; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 10px; }
  section h2 .icon { font-size: 18px; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 24px; margin-bottom: 16px; }
  .card p { margin-bottom: 8px; color: var(--text2); }
  .card p strong { color: var(--text); }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  table th { text-align: left; padding: 10px 14px; background: var(--surface2); color: var(--text2); font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid var(--border); }
  table td { padding: 10px 14px; border-bottom: 1px solid var(--border); }
  table tr:last-child td { border-bottom: none; }
  .tag { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
  .tag-p0 { background: var(--red-bg); color: var(--red); }
  .tag-p1 { background: var(--amber-bg); color: var(--amber); }
  .tag-p2 { background: var(--blue-bg); color: var(--blue); }
  .tag-pass { background: var(--green-bg); color: var(--green); }
  .tag-fail { background: var(--red-bg); color: var(--red); }
  .tag-skip { background: rgba(139,143,168,0.12); color: var(--text2); }
  .tag-create { background: var(--green-bg); color: var(--green); }
  .tag-modify { background: var(--amber-bg); color: var(--amber); }
  .tag-delete { background: var(--red-bg); color: var(--red); }
  .check-row { display: flex; align-items: flex-start; gap: 12px; padding: 10px 0; border-bottom: 1px solid var(--border); }
  .check-row:last-child { border-bottom: none; }
  .check-icon { font-size: 18px; flex-shrink: 0; margin-top: 2px; }
  .check-pass { color: var(--green); }
  .check-warn { color: var(--amber); }
  .check-fail { color: var(--red); }
  .issues-list { list-style: none; }
  .issues-list li { padding: 8px 0; border-bottom: 1px solid var(--border); font-size: 14px; display: flex; align-items: flex-start; gap: 8px; }
  .issues-list li:last-child { border-bottom: none; }
  .issues-list .sev { flex-shrink: 0; font-size: 12px; font-weight: 600; padding: 2px 6px; border-radius: 4px; }
  .sev-critical { background: var(--red-bg); color: var(--red); }
  .sev-significant { background: var(--amber-bg); color: var(--amber); }
  .sev-minor { background: rgba(139,143,168,0.12); color: var(--text2); }
  .mermaid-wrapper { background: var(--surface2); border-radius: var(--radius); padding: 24px; margin: 16px 0; overflow-x: auto; }
  .file-list { font-family: 'SF Mono', 'JetBrains Mono', 'Fira Code', monospace; font-size: 13px; }
  .callout { border-left: 3px solid var(--blue); padding: 12px 16px; background: var(--blue-bg); border-radius: 0 var(--radius) var(--radius) 0; margin: 16px 0; font-size: 14px; color: var(--text2); }
  .footer { text-align: center; padding: 32px 0 16px; color: var(--text2); font-size: 12px; border-top: 1px solid var(--border); margin-top: 48px; }
  .progress-bar { height: 8px; background: var(--surface2); border-radius: 4px; margin: 8px 0; overflow: hidden; }
  .progress-fill { height: 100%; border-radius: 4px; }
  .fill-green { background: var(--green); }
  .fill-red { background: var(--red); }
  .fill-amber { background: var(--amber); }
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
  @media (max-width: 640px) { .grid-2 { grid-template-columns: 1fr; } .hero-grid { grid-template-columns: 1fr 1fr; } }
</style>
```

### HTML-структура

```html
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{data.report_title}</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
  <script>mermaid.initialize({startOnLoad:true, theme:'dark', themeVariables:{primaryColor:'#3b82f6',primaryTextColor:'#fff',lineColor:'#8b8fa8',tertiaryColor:'#1a1d27'}});</script>
  {CSS}
</head>
<body>
  <div class="container">

    <!-- HEADER -->
    <div class="header">
      <h1>{data.summary.goal}</h1>
      <div class="meta">Сгенерирован: {data.generated_at}{data.summary.duration ? ' • Длительность: ' + data.summary.duration : ''}</div>
    </div>

    <!-- HERO -->
    <div class="hero">
      <div class="hero-grid">
        <div class="hero-card">
          <div class="value" style="color: var(--green)">{data.testing?.outcome === 'PASSED' ? '✓' : data.testing?.outcome === 'FAILED' ? '✗' : '~'}</div>
          <div class="label">Итог</div>
        </div>
        <div class="hero-card">
          <div class="value">{data.design?.selected_variant || '—'}</div>
          <div class="label">Вариант решения</div>
        </div>
        <div class="hero-card">
          <div class="value">{data.testing?.summary?.overall?.total || '—'}</div>
          <div class="label">Тестов выполнено</div>
        </div>
        <div class="hero-card">
          <div class="value" style="color: var(--blue)">{data.session?.complexity_score || '—'}</div>
          <div class="label">Сложность</div>
        </div>
      </div>
    </div>

    <!-- 1. РЕЗУЛЬТАТ -->
    <section>
      <h2><span class="icon">📋</span> Результат</h2>
      <div class="card">
        <p>{data.summary.outcome}</p>
        <p>{data.requirements?.business_context}</p>
      </div>
    </section>

    <!-- 2. ЧТО ИЗМЕНИЛОСЬ -->
    <section>
      <h2><span class="icon">🔧</span> Что изменилось</h2>
      <div class="card">
        {перечислить из data.design.approach_summary + affected_modules}
        <div class="callout">
          <strong>Выбранный подход:</strong> {data.design.variant_label} ({data.design.selected_variant})<br>
          <strong>Обоснование:</strong> {data.design.reason_for_choice}<br>
          <strong>Обратимость:</strong> {data.design.reversibility}
        </div>
      </div>
    </section>

    <!-- 3. ЗАТРОНУТЫЕ ФАЙЛЫ -->
    <section>
      <h2><span class="icon">📁</span> Затронутые компоненты</h2>
      <div class="card">
        <table>
          <thead><tr><th>Файл</th><th>Тип изменения</th></tr></thead>
          <tbody>
            {data.design.files_touched.map(f => `<tr><td class="file-list">${f.path}</td><td><span class="tag tag-${f.change_type}">${f.change_type}</span></td></tr>`)}
          </tbody>
        </table>
      </div>
    </section>

    <!-- 4. ТЕСТИРОВАНИЕ -->
    <section>
      <h2><span class="icon">🧪</span> Результаты тестирования</h2>
      <div class="card">
        <table>
          <thead><tr><th>Приоритет</th><th>Всего</th><th>Пройдено</th><th>Провалено</th><th>Пропущено</th><th>Покрытие</th></tr></thead>
          <tbody>
            {для P0, P1, P2, overall: строка таблицы с progress-bar}
          </tbody>
        </table>
      </div>

      {если есть failed_tests: таблица проваленных тестов}
      {если есть partial_completion: блок о частичном покрытии}
    </section>

    <!-- 5. ОЦЕНКА КАЧЕСТВА -->
    <section>
      <h2><span class="icon">🛡</span> Оценка качества и безопасности</h2>
      <div class="card">
        <div class="grid-2">
          <div class="check-row"><span class="check-icon check-{guardian.correctness}">{иконка}</span><div><strong>Корректность</strong><br><span style="color:var(--text2);font-size:13px;">Соответствие проектному решению</span></div></div>
          <div class="check-row"><span class="check-icon check-{guardian.code_quality}">{иконка}</span><div><strong>Качество кода</strong><br><span style="color:var(--text2);font-size:13px;">Стиль, читаемость, документация</span></div></div>
          <div class="check-row"><span class="check-icon check-{guardian.security}">{иконка}</span><div><strong>Безопасность</strong><br><span style="color:var(--text2);font-size:13px;">Уязвимости, секреты, OWASP</span></div></div>
          <div class="check-row"><span class="check-icon check-{guardian.tech_debt}">{иконка}</span><div><strong>Технический долг</strong><br><span style="color:var(--text2);font-size:13px;">Новые долги и обратимость</span></div></div>
        </div>
      </div>

      {если есть замечания: секция «Замечания» с разделением на критические/значимые/минорные}
    </section>

    <!-- 6. ДИАГРАММА АРХИТЕКТУРЫ -->
    <section>
      <h2><span class="icon">🗺</span> Архитектурная схема</h2>
      <div class="card">
        <p style="color:var(--text2);margin-bottom:16px;">Визуализация затронутых компонентов и их связей в контексте данного изменения.</p>
        <div class="mermaid-wrapper">
          <div class="mermaid">
graph TD
    subgraph "Фронтенд"
        A[Login.tsx] --> B[OAuth Button]
    end
    subgraph "Бэкенд"
        C[auth/login.py] --> D[OAuth Provider]
        D --> E[Token Service]
        C --> F[User DB]
    end
    A -->|POST /auth/login| C
    style A fill:#3b82f6,stroke:#3b82f6,color:#fff
    style C fill:#22c55e,stroke:#22c55e,color:#fff
    style D fill:#a855f7,stroke:#a855f7,color:#fff
          </div>
        </div>
      </div>
    </section>

    <!-- 7. ДОКУМЕНТАЦИЯ -->
    <section>
      <h2><span class="icon">📚</span> Состояние документации</h2>
      <div class="card">
        {doc_check.status === 'ok' 
          ? '<p style="color:var(--green)">✓ Документация обновлена и согласована</p>'
          : '<table>... таблица проблем ...</table>'}
      </div>
    </section>

    <!-- 8. СЛЕДУЮЩИЕ ШАГИ -->
    <section>
      <h2><span class="icon">➡</span> Следующие шаги</h2>
      <div class="card">
        {если есть minor_notes: «Обратить внимание на минорные замечания (см. выше)»}
        {если partial_completion: «Выполнить непокрытые тесты в следующем цикле»}
        {иначе: «Изменения готовы к эксплуатации. При возникновении вопросов — обратиться к документации.»}
      </div>
    </section>

    <!-- FOOTER -->
    <div class="footer">
      Отчёт подготовлен автоматически агентной системой разработки.<br>
      {data.generated_at} • {data.data_sources_used.length} источников данных
    </div>

  </div>
</body>
</html>
```

## Шаг 3. Адаптируй Mermaid-диаграмму под реальные данные

### Правила построения диаграммы

1. **Извлеки модули** из `data.design.files_touched` — сгруппируй по фронтенд/бэкенд
2. **Определи связи:**
   - Фронтенд-компоненты → API-эндпоинты (из `implementation.back.api_contracts`)
   - Бэкенд-модули → зависимости (из `explore-report.md` если доступен, иначе пропусти)
3. **Цветовое кодирование:**
   - `create` → синий
   - `modify` → зелёный
   - `delete` → красный
4. **Не усложняй:** если файлов >8 — покажи только ключевые, сгруппировав остальные в `...`

### Если данных недостаточно для диаграммы

Если `data.design.files_touched` содержит <2 файлов или нет `api_contracts` —
пропусти секцию с диаграммой. Не придумывай схему из головы.

## Шаг 4. Запиши HTML-файл

Путь: `work-area/reports/final-report-N.html` (где N — номер цикла из data).

Формат: полный HTML-документ с инлайн-CSS. Файл самодостаточен: все стили внутри,
Mermaid подгружается с CDN, никаких внешних зависимостей кроме CDN-скрипта.

## Шаг 5. Верни подтверждение

```
HTML-отчёт сгенерирован: work-area/reports/final-report-N.html
Размер: ~X KB | Секций: Y | Диаграмма: включена / пропущена
```

# Ограничения

- Не изменяй CSS-фреймворк без необходимости — он оттестирован на тёмную тему
- Не вставляй реальные секреты, токены или пароли в HTML
- Mermaid-диаграмма должна отражать реальные файлы из data, не абстракцию
- Если данных для секции нет (null) — пропусти секцию, не пиши «данные отсутствуют»
- HTML должен быть валидным и открываться в браузере без ошибок

# Self-check

- [ ] CSS-фреймворк включён полностью
- [ ] Все секции заполнены данными (или пропущены если данных нет)
- [ ] Цветовое кодирование в таблицах соответствует статусам
- [ ] Mermaid-диаграмма отражает реальные затронутые файлы
- [ ] HTML сохранён в work-area/reports/final-report-N.html
- [ ] Нет placeholder'ов вида `{data.xxx}` в финальном HTML
