#!/usr/bin/env sh
# check-memory-provenance.sh — линтер целостности provenance концептуальной памяти (WI-2).
#
# Гарантирует, что каждая ссылка эвристики (conceptual.json → heuristics[].evidence)
# резолвится в реальную запись фактических слоёв:
#   - finding_id из feedback.json (failed_details[].finding_id, guardian.critical_issues[].finding_id)
#   - entry_id   из procedural.json (history[].entries[].entry_id)
# Висячая (dangling) ссылка → exit 1. Дополнительно: эвристики ярусов active/provisional
# обязаны иметь непустой evidence.
#
# Использование:
#   sh check-memory-provenance.sh [MEMORY_DIR]
#   MEMORY_DIR по умолчанию: ./work-area/memory
#
# Зависимости: POSIX sh + python3 (python3 уже требуется для развёртывания, см. README).
# Если concept-памяти ещё нет (первый запуск проекта) — exit 0 (нечего проверять).

set -eu

MEMORY_DIR="${1:-work-area/memory}"
CONCEPTUAL="$MEMORY_DIR/conceptual.json"
FEEDBACK="$MEMORY_DIR/feedback.json"
PROCEDURAL="$MEMORY_DIR/procedural.json"

if [ ! -f "$CONCEPTUAL" ]; then
  echo "SKIP: $CONCEPTUAL не найден — концептуальной памяти ещё нет, проверять нечего."
  exit 0
fi

MEMORY_DIR="$MEMORY_DIR" CONCEPTUAL="$CONCEPTUAL" FEEDBACK="$FEEDBACK" PROCEDURAL="$PROCEDURAL" \
python3 - <<'PY'
import json, os, sys

conceptual = os.environ["CONCEPTUAL"]
feedback = os.environ["FEEDBACK"]
procedural = os.environ["PROCEDURAL"]

def load(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"FAIL: не удалось прочитать {path}: {exc}", file=sys.stderr)
        sys.exit(1)

conc = load(conceptual)
fb = load(feedback)
proc = load(procedural)

# Собираем множество всех известных ID фактических слоёв.
known = set()
if fb:
    for rec in fb.get("history", []):
        testing = rec.get("testing", {}) or {}
        for fd in testing.get("failed_details", []) or []:
            if fd.get("finding_id"):
                known.add(fd["finding_id"])
        guardian = rec.get("guardian", {}) or {}
        for ci in guardian.get("critical_issues", []) or []:
            if ci.get("finding_id"):
                known.add(ci["finding_id"])
if proc:
    for rec in proc.get("history", []):
        for entry in rec.get("entries", []) or []:
            if entry.get("entry_id"):
                known.add(entry["entry_id"])

status = 0
heuristics = conc.get("heuristics", [])
if not isinstance(heuristics, list):
    print("FAIL: conceptual.json: поле 'heuristics' должно быть массивом", file=sys.stderr)
    sys.exit(1)

for h in heuristics:
    hid = h.get("id", "<no-id>")
    tier = h.get("tier", "active")
    evidence = h.get("evidence", []) or []
    if tier in ("active", "provisional") and not evidence:
        print(f"FAIL: эвристика '{hid}' (tier={tier}) не имеет evidence", file=sys.stderr)
        status = 1
    for ev in evidence:
        if ev not in known:
            print(f"FAIL: эвристика '{hid}' ссылается на несуществующий evidence '{ev}' (dangling provenance)", file=sys.stderr)
            status = 1

if status == 0:
    print(f"OK: provenance целостен — все evidence резолвятся ({len(heuristics)} эвристик).")
sys.exit(status)
PY
