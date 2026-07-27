#!/usr/bin/env sh
# check-artifact-permissions.sh — проверяет, что каждый агент физически может
# записать тот артефакт, который ему предписан.
#
# Этот линтер закрывает класс дефектов «описанный процесс не исполним при
# заданных правах»: агенту предписано создать файл, а движок ему это запретит.
# Такие расхождения не ловятся ни валидацией JSON, ни картой навыков — они
# всплывают только в рантайме, часто на последних шагах конвейера.
#
# Проверяются два инварианта:
#   A. Реестр ролей (AGENTS.md, колонка Owns) ↔ agent.<name>.permission.edit
#      Каждый артефакт из колонки Owns обязан попадать под allow-glob владельца.
#   B. Декларация навыка (front-matter `writes:`) ↔ права ВСЕХ его вызывающих
#      (карта навыков skills/README.md, колонка «Вызывает»).
#      Навык, который пишет файл, не должен быть назначен агенту без прав на него.
#
# Навыки без поля `writes:` считаются непишущими и пропускаются.
#
# Зависимости: POSIX sh + python3. Exit 0 — согласовано, иначе 1.
# Запуск: sh check-artifact-permissions.sh   (из любого каталога или в CI).

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/.." && pwd)

CONFIG="$ROOT/opencode.json" AGENTS_MD="$ROOT/AGENTS.md" SKILLS_DIR="$DIR" \
python3 - <<'PY'
import json, os, re, sys

config_path = os.environ["CONFIG"]
agents_md = os.environ["AGENTS_MD"]
skills_dir = os.environ["SKILLS_DIR"]

status = 0

def fail(msg):
    global status
    print("FAIL: " + msg, file=sys.stderr)
    status = 1

# Исключения из проверки. Важное различие, на котором держится корректность линтера:
# исключать нужно ПУТЬ, а не АГЕНТА.
#
#   EXEMPT_AGENTS  — роли, у которых edit вообще не привязан к путям (строковое "ask"),
#                    проверять нечего ни по какому пути.
#   PROJECT_SCOPED — роли, часть путей которых определяет проектный opencode.json.
#                    Их зоны исходников в глобальном слое действительно непроверяемы —
#                    но только они. Всё, что лежит под work-area/, задано глобально,
#                    от проекта не зависит и обязано проверяться у всех без изъятия.
#
# Раньше здесь было одно множество на всех, и кодеры выпадали из проверки целиком —
# включая work-area/. Из-за этого предписанный кодеру отчёт, писать который движок ему
# запрещал, три диагностики подряд проходил мимо линтера, написанного ровно для этого
# класса дефектов.
EXEMPT_AGENTS = {"ai-engineer"}
PROJECT_SCOPED = {"coder-front", "coder-back"}
GLOBAL_PREFIX = "work-area/"


def skip(agent, spec):
    """Нужно ли пропустить пару (агент, путь) как непроверяемую в глобальном слое."""
    if agent in EXEMPT_AGENTS:
        return True
    return agent in PROJECT_SCOPED and not spec.startswith(GLOBAL_PREFIX)

try:
    with open(config_path, encoding="utf-8") as fh:
        config = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    print("FAIL: не удалось прочитать %s: %s" % (config_path, exc), file=sys.stderr)
    sys.exit(1)

agents = config.get("agent", {})

def allow_globs(agent):
    """Список allow-шаблонов edit у агента."""
    edit = agents.get(agent, {}).get("permission", {}).get("edit", {})
    if isinstance(edit, str):
        return ["**"] if edit in ("allow", "ask") else []
    return [g for g, v in edit.items() if v == "allow"]

def glob_to_re(pattern):
    """Семантика движка opencode, а НЕ стандартный glob.

    opencode использует простое wildcard-сопоставление: `*` разворачивается в
    `.*` (то есть пересекает `/`), `?` — ровно один любой символ. Отдельной
    конструкции globstar (`**`) нет — две звезды подряд ведут себя как одна.
    Поэтому здесь не должно быть `[^/]*`: линтер, моделирующий glob строже
    движка, даёт неверную картину широты выданных прав.
    """
    out, i = "", 0
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            out += ".*"
            i += 1
        elif c == "?":
            out += "."
            i += 1
        else:
            out += re.escape(c)
            i += 1
    # схлопываем `.*.*`, полученные из `**`, — на результат не влияет, но
    # упрощает отладку скомпилированного шаблона
    out = re.sub(r"(?:\.\*){2,}", ".*", out)
    return re.compile("^" + out + "$")

def matches(path, pattern):
    return glob_to_re(pattern).match(path) is not None

def sample_path(spec):
    """Превращает запись артефакта в конкретный путь для проверки."""
    p = spec.strip().strip("`").strip()
    p = p.replace("NNN", "001").replace("YYYY-MM-DD", "2026-01-01")
    if p.endswith("/**"):
        return p[:-3] + "/sub/sample.md"
    if p.endswith("/*"):
        return p[:-2] + "/sample.md"
    if p.endswith("/"):
        return p + "sample.md"
    return p

def writable_by(agent, spec):
    path = sample_path(spec)
    return any(matches(path, g) for g in allow_globs(agent)), path

# ─────────────────────────────────────────────────────────────────────────
# A. Реестр ролей (AGENTS.md, колонка Owns) ↔ права
# ─────────────────────────────────────────────────────────────────────────
try:
    with open(agents_md, encoding="utf-8") as fh:
        roster_src = fh.read()
except OSError as exc:
    print("FAIL: не удалось прочитать %s: %s" % (agents_md, exc), file=sys.stderr)
    sys.exit(1)

checked_a = 0
row_re = re.compile(r"^\|\s*`([a-z0-9-]+)`\s*\|\s*(primary|subagent)\s*\|[^|]*\|([^|]*)\|")
for line in roster_src.splitlines():
    m = row_re.match(line)
    if not m:
        continue
    agent, _, owns = m.group(1), m.group(2), m.group(3)
    if agent in EXEMPT_AGENTS:
        continue
    if agent not in agents:
        fail("реестр AGENTS.md содержит агента '%s', которого нет в opencode.json" % agent)
        continue
    for spec in owns.split(","):
        spec = spec.strip().strip("`").strip()
        if not spec or spec in ("—", "-"):
            continue
        if skip(agent, spec):
            continue
        ok, path = writable_by(agent, spec)
        checked_a += 1
        if not ok:
            fail("агент '%s' владеет '%s', но не может туда писать: "
                 "путь '%s' не покрыт ни одним allow-шаблоном %s"
                 % (agent, spec, path, allow_globs(agent) or "(пусто)"))

# Агенты в конфиге, отсутствующие в реестре
for agent in agents:
    if agent in EXEMPT_AGENTS:
        continue
    if not re.search(r"^\|\s*`" + re.escape(agent) + r"`\s*\|", roster_src, re.M):
        fail("агент '%s' есть в opencode.json, но отсутствует в реестре AGENTS.md" % agent)

# ─────────────────────────────────────────────────────────────────────────
# B. Декларация навыка (`writes:`) ↔ права всех вызывающих
# ─────────────────────────────────────────────────────────────────────────
skill_map = os.path.join(skills_dir, "README.md")
try:
    with open(skill_map, encoding="utf-8") as fh:
        map_src = fh.read()
except OSError as exc:
    print("FAIL: не удалось прочитать карту навыков %s: %s" % (skill_map, exc), file=sys.stderr)
    sys.exit(1)

callers = {}
for line in map_src.splitlines():
    m = re.match(r"^\|\s*`([a-z0-9-]+)`\s*\|[^|]*\|([^|]*)\|", line)
    if m:
        callers[m.group(1)] = re.findall(r"`([a-z0-9-]+)`", m.group(2))

checked_b = 0
for name in sorted(os.listdir(skills_dir)):
    skill_file = os.path.join(skills_dir, name, "SKILL.md")
    if not os.path.isfile(skill_file):
        continue
    with open(skill_file, encoding="utf-8") as fh:
        head = fh.read(2000)
    m = re.search(r"^writes:\s*(.+)$", head, re.M)
    if not m:
        continue
    targets = [t.strip() for t in m.group(1).split(",") if t.strip()]
    who = callers.get(name)
    if who is None:
        fail("навык '%s' объявляет writes, но отсутствует в карте навыков" % name)
        continue
    if not who:
        fail("навык '%s' объявляет writes, но в карте не указан ни один вызывающий агент" % name)
        continue
    for agent in who:
        if agent not in agents:
            continue
        for spec in targets:
            if skip(agent, spec):
                continue
            ok, path = writable_by(agent, spec)
            checked_b += 1
            if not ok:
                fail("навык '%s' пишет в '%s', но его вызывающий '%s' не имеет такого права "
                     "(путь '%s' не покрыт %s)"
                     % (name, spec, agent, path, allow_globs(agent) or "(пусто)"))

if status == 0:
    print("OK: права на запись согласованы — реестр (%d проверок) и навыки (%d проверок)."
          % (checked_a, checked_b))
sys.exit(status)
PY
