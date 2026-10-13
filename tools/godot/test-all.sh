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
run worldcheck python3 -I tools/godot/roomcheck/world.py
run check4b3 python3 -I tools/godot/roomcheck/check4b3.py
run check5a python3 -I tools/godot/roomcheck/check5a.py
# a script that does not parse makes every scenario hang until its timeout: stop at once instead
"$GODOT" --headless --path godot --import > /dev/null 2>&1
if timeout 60 "$GODOT" --headless --path godot --quit-after 3 2>&1 | grep -E "Parse Error|Compile Error|Failed to load script"; then echo "FAIL parse"; exit 1; fi
for t in tiles jump combat hurt soak rooms doors save bench crack platform focus dashhurt guard zombie null nullcoop guestpred parity end relpend misc bossreg rooms3 catch exception reviewer plugins crumble w2enemies fork rooms3b merge agents shop mergeinterp loadout bossstats strikeseen sidunique bossfree skipboss nsdoors tiles4 flood rise plugins4 w3assets w3enemies segfault stackover leak rooms4 lab locks4b signs4b variants4b symlink packets bosskit worlddigest mapdata tree mappage mapoverlay changelog travelp2 logs lostagents decor terminals rooms4b w6assets curl ssh net4b w6enemies plugins4b net4b1 kit4b3 w6enemies2 net4b3 crawler2 firewall2 reviewer2b bosspresets hardrooms rooms5a w4assets tick5a breakpoint w4enemies raceboss loopboss deadlockboss plugins5a tower4b1; do
  timeout 180 "$GODOT" --headless --path godot -- --test=$t > "$TMP/$t.log" 2>&1
  if grep -q "^TEST $t PASS" "$TMP/$t.log" && ! grep -q "SCRIPT ERROR" "$TMP/$t.log"; then rec "test-$t" PASS; else rec "test-$t" FAIL; echo "---- $t ----"; tail -20 "$TMP/$t.log"; fi
done
for tape in tools/godot/parity/tapes/*.json; do
  n=$(basename "$tape" .json)
  node tools/godot/parity/js-trace.js "$tape" > "$TMP/js_$n.csv" 2> "$TMP/js_$n.err"
  timeout 120 "$GODOT" --headless --path godot -- --test=tape:"$ROOT/$tape" > "$TMP/gd_$n.csv" 2>&1
  if python3 tools/godot/parity/compare.py "$TMP/js_$n.csv" "$TMP/gd_$n.csv" > "$TMP/cmp_$n.txt"; then rec "parity-$n" PASS; else rec "parity-$n" FAIL; cat "$TMP/cmp_$n.txt"; fi
done
run etrace bash tools/godot/parity/enemy-cases.sh
run export bash tools/godot/export-web.sh
run web-check node tools/godot/web-check.js
cat "$TMP/web-check.log" 2>/dev/null | grep -E "^(PASS|FAIL)" | sed 's/^/    /'
run relay node tools/coop-harness.js mv-serve mv-coop mv-title mv-phone cache
# two lanes of scenarios (own relay port and code each), so the co-op part takes about half the time
ALLC=$(grep -E '^ALL=' tools/godot/coop-test.sh | sed -e 's/^ALL="//' -e 's/"$//')
LANE1=""; LANE2=""; i=0
for sc in $ALLC; do if [ $((i % 2)) = 0 ]; then LANE1="$LANE1 $sc"; else LANE2="$LANE2 $sc"; fi; i=$((i + 1)); done
COOP_PORT=3120 COOP_CODE=246810 bash tools/godot/coop-test.sh $LANE1 > "$TMP/coop1.log" 2>&1 & P1=$!
COOP_PORT=3121 COOP_CODE=135790 bash tools/godot/coop-test.sh $LANE2 > "$TMP/coop2.log" 2>&1 & P2=$!
if wait $P1 && wait $P2; then rec coop PASS; else rec coop FAIL; grep -hE "^FAIL|COOP|INVARIANT|SCRIPT ERROR" "$TMP/coop1.log" "$TMP/coop2.log" | tail -40; fi

echo
echo "================ summary ================"
bad=0
for i in "${!NAMES[@]}"; do printf '%-26s %s\n' "${NAMES[$i]}" "${RES[$i]}"; [ "${RES[$i]}" = PASS ] || bad=1; done
[ $bad -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $bad
