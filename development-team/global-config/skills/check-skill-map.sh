#!/usr/bin/env sh
# check-skill-map.sh — проверяет целостность карты навыков (README.md).
#
# Гарантирует «каждый навык ↔ строка в карте» в обе стороны:
#   1. у каждого каталога skills/<name>/SKILL.md есть строка в README.md;
#   2. каждое имя навыка, упомянутое в таблице README.md, существует как каталог.
#
# Зависимостей нет (POSIX sh + grep). Exit 0 — карта согласована, иначе 1.
# Запуск: sh check-skill-map.sh   (можно из любого каталога или в CI).

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MAP="$DIR/README.md"
status=0

if [ ! -f "$MAP" ]; then
  echo "FAIL: карта навыков не найдена: $MAP" >&2
  exit 1
fi

# 1. Каждый навык на диске должен иметь строку в карте.
for skill_md in "$DIR"/*/SKILL.md; do
  [ -e "$skill_md" ] || continue
  name=$(basename "$(dirname "$skill_md")")
  # Ищем строку таблицы, начинающуюся с | `<name>` |
  if ! grep -q "^| \`$name\`" "$MAP"; then
    echo "FAIL: навык '$name' есть на диске, но отсутствует в карте (README.md)" >&2
    status=1
  fi
done

# 2. Каждое имя в первом столбце таблицы должно существовать как каталог.
#    Берём строки таблицы вида: | `name` | ... и вытаскиваем name.
grep -oE '^\| `[a-z0-9-]+`' "$MAP" | sed -e 's/^| `//' -e 's/`$//' | while IFS= read -r name; do
  if [ ! -f "$DIR/$name/SKILL.md" ]; then
    echo "FAIL: карта ссылается на навык '$name', но каталог skills/$name/SKILL.md не найден" >&2
    # Завершаем сам скрипт с ошибкой (подкоманда while в pipe — отдельный процесс).
    exit 1
  fi
done || status=1

if [ "$status" -eq 0 ]; then
  echo "OK: карта навыков согласована с каталогами skills/*."
fi
exit "$status"
