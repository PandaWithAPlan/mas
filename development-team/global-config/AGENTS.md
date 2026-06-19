# Agent Roster

| Agent | Type | Role | Owns |
|---|---|---|---|
| `team-lead` | primary | Gate-keeper, coordinator, escalation | `work-area/sessions/`, `work-area/tasks/*`, `work-area/memory/*` |
| `explorer` | subagent | Codebase mapping, dependency graph | `work-area/docs/explore-report.md` |
| `analyst` | subagent | Requirements, acceptance criteria, gaps | `work-area/docs/requirements.md` |
| `architect` | subagent | Solution design, decomposition, contracts | `work-area/docs/design.md` |
| `coder-front` | subagent | Frontend implementation | `src/frontend/` |
| `coder-back` | subagent | Backend implementation | `src/backend/` |
| `tester` | subagent | Functional testing, regression, boundary | `work-area/reports/test-results/TR-NNN.md` |
| `guardian` | subagent | Quality, security, correctness audit | `work-area/reports/guardian-NNN.md` |
| `devops` | subagent | Infrastructure consultant + executor | `work-area/reports/devops-status.md` |
| `reviewer` | subagent | Final user-facing HTML report | `work-area/reports/final-report-NNN.md` |
| `ai-engineer` | primary | System debugger, RCA (NOT in pipeline) | — |

**Owns-директории `coder-front` и `coder-back` в этой таблице — значения по умолчанию.** Точные зоны ответственности для конкретного проекта заданы в локальном `AGENTS.md` (секция «Назначение директорий»). Кодеры обязаны сверить свои Owns с локальным `AGENTS.md` перед началом работы.

# Artifact Ownership

One artifact — one owner. Other agents may read, but must not modify without explicit Team Lead permission.

**Task file ownership note:** Architect writes recommendations in `design.md`. Team Lead creates the actual `work-area/tasks/DEV-*.md` and `TEST-*.md` files. Architect must NOT create task files directly.

# How Skills Work (execution model) — READ FIRST

Навыки (`skills/*/SKILL.md`) — это **инструкции, которые подгружаются в твой контекст, а не вызываемые функции**. Когда ты делаешь `skill({ name: "X" })`, среда один раз вставляет текст `SKILL.md` в твой контекст. У навыка **нет** отдельного исполнения, входных аргументов и возвращаемого значения.

Из этого следуют правила:

- **Навык ничего не «возвращает».** Формулировки вида «передай X», «навык вернёт Y», «Прими вход», «Верни результат» — это сокращение. Читай их так: *входные данные у тебя уже есть в контексте; результат ты формируешь сам по процедуре навыка и встраиваешь в свой ответ или артефакт.*
- **Не вызывай навык повторно, чтобы «получить вывод».** Повторный вызов вернёт тот же текст инструкции — это типичная ошибка, ведущая к зацикливанию и лишнему расходу токенов. Вызвал один раз → выполнил процедуру сам.
- **Каждый `SKILL.md` начинается с напоминания об этом** (блок «⚙️ Это навык-инструкция, а не функция»). Если ты ждёшь от навыка структурированный возврат — перечитай это напоминание.

**Карта навыков:** полный реестр навыков (назначение, кто вызывает, триггер, порядок, фолбэк) — в `skills/README.md`. Это источник истины по диспетчерскому слою; при добавлении/удалении навыка обнови карту (целостность проверяет `skills/check-skill-map.sh`).

# Routing Rules (non-obvious constraints)

- Team Lead is the single entry point for ALL user tasks.
- Project cycle is **mandatory every time**: Explorer → Analyst → Architect, even on REWORK.
- On the **first cycle only**, Architect proposes 2–3 variants; Team Lead must present them to the user for explicit selection.
- On REWORK cycles, Architect corrects the already-chosen variant; do NOT re-ask the user.
- **DevOps Preflight Gate** is mandatory before coders start whenever the task touches: env, services, DB, caches, queues, or external dependencies. Coders and Tester do NOT start until DevOps confirms readiness.
- DevOps fallback: if unreachable for 5 min, Team Lead pauses and escalates to user with 3 options (continue without, defer, user validates).
- **Tester always runs before Guardian.** Guardian never starts without `TR-NNN.md` or an explicit partial-coverage note.
- If Tester hangs or completes partially, Team Lead reads the partial artifact and decides SUFFICIENT/INSUFFICIENT via `incident-protocol` before handing to Guardian.
- **Reviewer runs only after Guardian verdict ACCEPT + Team Lead decision.** Reviewer does not make quality/architecture decisions.
- Maximum **3 REWORK cycles** per task. On cycle 3, Team Lead escalates to user instead of starting another cycle.
- **Plateau Detection** overrides the cycle counter: if cycle ≥2 shows stagnant tests, repeated critical findings, expanding affected zones, or no metric progress → switch variant or escalate immediately.
- **Scope discipline:** coders may ONLY touch files listed in their DEV task. Extra changes outside the plan = scope creep. Guardian checks this via the Scope Compliance section.
- **Team Lead role boundary:** Team Lead NEVER executes code, tests, or infrastructure changes — it ONLY delegates via `skill({ name: "task-delegation-format" })`. Any direct execution by Team Lead is a system failure.
- **Cross-stack API contracts:** if a task touches both frontend and backend, Architect MUST produce a "Сводка API-контрактов" table (C-001, C-002, ...). Team Lead MUST verify DEV-FRONT, DEV-BACK, and TEST all reference the same contracts before creating task files.

# Critical Gotchas (agent would miss without reading the full agent file)

- **Architect** must call `skill({ name: "confidence-calibrate" })` for every significant estimate (risks, change volume, reversibility). Estimates without a confidence % are insufficient.
- **Architect** must include a "Procedural Reflection" section in design.md — a meta-analysis of *how* the design was reached, not just what was designed.
- **Coders (front/back)** have a SCOPE GATE: (1) touch only files listed in the task, (2) report but don't fix issues outside scope, (3) no "while I'm here" improvements, (4) honor the change budget exactly. Violation = scope creep caught by Guardian.
- **Coders and Tester** must each call `skill({ name: "devops-gate-check" })` before starting work. This is separate from the Team Lead's devops-gate-check.
- **Coders** must verify API contracts from design.md before implementing. If the task file lacks a "Контракты" field, they must request it from Team Lead.
- **Coders** must check the local `AGENTS.md` (section «Назначение директорий») for their actual Owns directories. The global Agent Roster shows defaults (`src/frontend/`, `src/backend/`); the local AGENTS.md may override them (e.g., `static/` for vanilla JS, `src/` + `core/` + `routes/` for backend). Working outside the local Owns = scope creep.
- **Coders have NO code edit permissions in the global config.** Each project MUST define coder edit paths in its local `opencode.json` (`agent.coder-front.permission.edit` and `agent.coder-back.permission.edit`). Without local overrides, coders cannot edit any project files — this is a fail-fast design: if a new project forgets to define coder permissions, the system will refuse edits rather than silently allowing writes to wrong directories.
- **Tester** must call `skill({ name: "test-progress" })` every 3 test cases. P0 tests must reach 100% coverage regardless of overall status (PASSED/FAILED/PARTIAL).
- **Guardian** stops immediately on finding any BLOCKER in the security zone. The analysis is truncated with PARTIAL COMPLETION and verdict RECOMMEND REWORK.
- **Guardian** always issues a RECOMMEND (ACCEPT/REWORK/ESCALATE), never a command. Final decision is Team Lead's.
- **DevOps** in executor mode has a defined DoD: all requested files changed + `devops-status.md` updated + explicit "Окружение готово" / "Окружение не готово" message to Team Lead.
- **ai-engineer** is a debugger, not in the pipeline. Invoke it for RCA when the system exhibits unexplained failures, loops, or incorrect routing. Provide traces, logs, prompts, and expected vs actual behavior.
- **PSAO (prompt annotation):** when delegating with complexity ≥5, REWORK cycles, or critical constraints, Team Lead MUST apply PSAO annotations via `skill({ name: "psao-annotate" })` through `task-delegation-format`. PSAO wraps the delegation message in soft directives (`[критически важно]`, `[контекст: ...]`) that prevent semantic drift — loss of key constraints when an agent reads a long prompt. This is integrated at Step 3.5 (PSAO Gate) of `task-delegation-format`. Simple tasks (complexity 1-3, first cycle, no criticals) skip PSAO.
- **Coders with change budget** always trigger PSAO Gate — their file boundary annotations prevent scope creep at the attention level, not just Guardian's retroactive check.

# DevOps Modes

- **Consultant** (no changes): any agent may call `@devops` for infrastructure questions.
- **Executor** (with changes): only Team Lead tasks DevOps with explicit infrastructure file changes (`docker-compose.yml`, `.env`, `nginx.conf`, `Makefile`, etc.).

# Memory (MALMAS Pattern)

Three-layer project memory, updated by Team Lead via `memory-update` → `memory-summarize` after each cycle:

| Layer | File | Content |
|---|---|---|
| Procedural | `work-area/memory/procedural.json` | Agent action chronology: who, what, which files |
| Feedback | `work-area/memory/feedback.json` | Test results + Guardian verdicts, machine-readable |
| Conceptual | `work-area/memory/conceptual.json` (source of truth) → `conceptual.md` (generated) | Compressed heuristics with structured provenance: `evidence` → `finding_id`/`entry_id`. Integrity enforced by `check-memory-provenance.sh` (WI-2) |

**Global Memory** (`work-area/memory/global-memory.md`) — consolidated task context read by all agents before starting. Generated by `memory-summarize`.

**Versioning & audit (WI-6):** every `memory-update` writes an append-only snapshot to `work-area/memory/snapshots/cycle-NNN-.../` and one line per mutation to `work-area/memory/changelog.jsonl` (what was added/promoted/demoted/archived and the deterministic rule + reason). This enables diffing memory between any two cycles and rollback to a known-good state. Numeric thresholds and modes for the whole memory subsystem live in `memory-config.json` (a standalone file, not part of the opencode schema).

# MALMAS Rules

- **Every agent** calls `skill({ name: "memory-retrieve" })` as their first action upon receiving a task.
- Team Lead calls `memory-retrieve` at Intake and uses Routing Intelligence from `global-memory.md` + `conceptual.md` to adapt routing decisions.
- After each cycle, Team Lead calls `memory-update` (which delegates to `memory-summarize` for LLM compression).
- Agents check `procedural.json` for duplicate/failed actions and do NOT repeat them.
- Tester and Guardian use `feedback.json` from prior cycles to expand check scope (affected zones).
- **Objective anchor (WI-1):** Tester always runs the fixed baseline set (`work-area/memory/baseline/manifest.json`) every cycle, independent of Router/heuristics. Each test record in `feedback.json` carries `source: "baseline" | "scoped"`. Heuristics are validated **only** against baseline results (scoped is what the heuristic itself dictated). Baseline is never disabled by scope reduction or ε-exploration.
- Heuristics in `conceptual.json` that are disproven by baseline get demoted to `archived` (WI-3).
- **ε-exploration (WI-5):** with small probability `ε` (`exploration.epsilon`) Team Lead routes as if the chosen `active` heuristic were false — i.e. skips its discretionary scope expansion — and records the outcome as counter-evidence into `confirm_count`/`refute_count`. ε never disables baseline, P0 tests, or non-overridable gates (BLOCKER / P0 FAILED).

# Team Lead Quick Reference

Key skill calls in order:
1. `session-init` — create session journal
2. `complexity-parallel` — parallelization config
3. `task-delegation-format` — format for each delegation
4. `devops-gate-check` — before coders start
5. `memory-update` — after Tester + Guardian results
6. `incident-protocol` — on subagent hang or PARTIAL
7. `task-metrics` — on ACCEPT or ESCALATE

# Agent Permissions (from opencode.json)

| Agent | Model | Edit | Bash | Webfetch |
|---|---|---|---|---|
| `team-lead` | ollama-cloud/nemotron-3-ultra | deny (work-area/) | deny | deny |
| `explorer` | ollama-cloud/deepseek-v4-flash | deny (explore-report.md) | deny | deny |
| `analyst` | ollama-cloud/qwen3.5:397b | deny (requirements.md) | deny | deny |
| `architect` | ollama-cloud/deepseek-v4-pro | deny (design.md) | deny | deny |
| `coder-front` | ollama-cloud/kimi-k2.7-code | deny (project-specific — see local opencode.json) | allow (restricted) | deny |
| `coder-back` | ollama-cloud/kimi-k2.7-code | deny (project-specific — see local opencode.json) | allow (restricted) | deny |
| `tester` | ollama-cloud/glm-5.1 | deny (test-results/**, tests/**) | allow (restricted) | deny |
| `guardian` | ollama-cloud/minimax-m3 | deny (guardian-*.md) | allow (restricted) | deny |
| `devops` | ollama-cloud/gemini-3-flash-preview | deny (devops-status.md, docker*, nginx.conf, Makefile, .env*) | allow (restricted) | deny |
| `reviewer` | ollama-cloud/minimax-m2.7 | deny (final-report-*.md) | deny | deny |
| `ai-engineer` | ollama-cloud/deepseek-v4-pro | ask | ask | ask |

Agent definitions live in `agents/*.md`. Skills live in `skills/*/SKILL.md`.
