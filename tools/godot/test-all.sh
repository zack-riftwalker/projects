#!/usr/bin/env bash
# One command proves the Godot build: smoke, every --test, the parity tapes, the web export, the web checks and the relay tests.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
GODOT=$(bash tools/godot/setup-godot.sh | tail -1) || { echo "FAIL setup"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
declare -a NAMES RES
rec() { NAMES+=("$1"); RES+=("$2"); }
run() { local name=$1; shift; if "$@" > "$TMP/$name.log" 2>&1; then rec "$name" PASS; else rec "$name" FAIL; echo "---- $name ----"; tail -25 "$TMP/$name.log"; fi; }

run smoke bash tools/godot/smoke.sh
"$GODOT" --headless --path godot --import > /dev/null 2>&1
for t in tiles jump combat hurt soak; do
  timeout 180 "$GODOT" --headless --path godot -- --test=$t > "$TMP/$t.log" 2>&1
  if grep -q "^TEST $t PASS" "$TMP/$t.log" && ! grep -q "SCRIPT ERROR" "$TMP/$t.log"; then rec "test-$t" PASS; else rec "test-$t" FAIL; echo "---- $t ----"; tail -20 "$TMP/$t.log"; fi
done
for tape in tools/godot/parity/tapes/*.json; do
  n=$(basename "$tape" .json)
  node tools/godot/parity/js-trace.js "$tape" > "$TMP/js_$n.csv" 2> "$TMP/js_$n.err"
  timeout 120 "$GODOT" --headless --path godot -- --test=tape:"$ROOT/$tape" > "$TMP/gd_$n.csv" 2>&1
  if python3 tools/godot/parity/compare.py "$TMP/js_$n.csv" "$TMP/gd_$n.csv" > "$TMP/cmp_$n.txt"; then rec "parity-$n" PASS; else rec "parity-$n" FAIL; cat "$TMP/cmp_$n.txt"; fi
done
run export bash tools/godot/export-web.sh
run web-check node tools/godot/web-check.js
cat "$TMP/web-check.log" 2>/dev/null | grep -E "^(PASS|FAIL)" | sed 's/^/    /'
run relay node tools/coop-harness.js mv-serve cache

echo
echo "================ summary ================"
bad=0
for i in "${!NAMES[@]}"; do printf '%-26s %s\n' "${NAMES[$i]}" "${RES[$i]}"; [ "${RES[$i]}" = PASS ] || bad=1; done
[ $bad -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $bad
