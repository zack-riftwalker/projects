#!/usr/bin/env bash
# The five enemy traces of MV3-09: JS game vs Godot, every frame within 0.01 px. Usage: enemy-cases.sh   (prints PASS/FAIL per creature)
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT"
GODOT=$(bash tools/godot/setup-godot.sh | tail -1)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
bad=0
while read -r cls x y px py frames; do
  node tools/godot/parity/enemy-trace.js "$cls" "$x" "$y" "$px" "$py" "$frames" > "$TMP/js.csv" 2> "$TMP/js.err"
  timeout 120 "$GODOT" --headless --path godot -- --test=etrace:"$cls:$x:$y:$px:$py:$frames" > "$TMP/gd.csv" 2>&1
  if python3 tools/godot/parity/compare.py "$TMP/js.csv" "$TMP/gd.csv" > "$TMP/cmp.txt"; then echo "PASS etrace-$cls $(cat "$TMP/cmp.txt")"; else echo "FAIL etrace-$cls"; cat "$TMP/cmp.txt"; bad=1; fi
done <<'CASES'
Bug 96 160 300 166 240
Mimic 192 160 230 166 240
Noodle 96 160 260 166 300
Logger 80 160 240 166 300
Flaky 144 112 260 166 300
CASES
exit $bad
