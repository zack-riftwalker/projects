#!/usr/bin/env bash
# Co-op scenarios: one relay (node server.js on port 3120), a host and a guest Godot process per scenario.
# usage: coop-test.sh <scenario|all>   (scenario names as in src/test/coop_scenarios.gd, e.g. co-connect)
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
GODOT=$(bash tools/godot/setup-godot.sh | tail -1) || { echo "FAIL setup"; exit 1; }
PORT=3120; CODE=246810
TMP=$(mktemp -d)
SRV=0
stop_srv() { if [ "$SRV" != 0 ]; then kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; SRV=0; fi; }
trap 'stop_srv; [ -n "${KEEP:-}" ] && cp "$TMP"/*.log "$KEEP"/ 2>/dev/null; rm -rf "$TMP"' EXIT
start_srv() { stop_srv; env PORT=$PORT CODE=$CODE NO_OPEN=1 "$@" node server.js > "$TMP/srv.log" 2>&1 & SRV=$!; sleep 1; }

one() { # scenario [env...]
  local s=$1; shift
  if [ "$s" = co-netfields ]; then
    timeout 60 "$GODOT" --headless --path godot -- --scenario=$s > "$TMP/$s.log" 2>&1
    grep -q "COOP $s .* PASS" "$TMP/$s.log"; return
  fi
  start_srv "$@"
  timeout 150 "$GODOT" --headless --path godot -- --net=host --port=$PORT --code=$CODE --scenario=$s > "$TMP/$s.host.log" 2>&1 &
  local h=$!
  sleep 1.5
  timeout 150 "$GODOT" --headless --path godot -- --net=guest --port=$PORT --code=$CODE --scenario=$s > "$TMP/$s.guest.log" 2>&1 &
  local g=$!
  wait $h; wait $g
  stop_srv
  grep -q "COOP $s host PASS" "$TMP/$s.host.log" && grep -q "COOP $s guest PASS" "$TMP/$s.guest.log"
}

ALL="co-connect co-hit co-rooms co-summon co-revive co-wipe co-crack co-resume co-rejoin co-hostgone co-hostdown co-return co-netfields co-badline"
list=${1:-all}; [ "$list" = all ] && list=$ALL
bad=0
for s in $list; do
  if [ "$s" = co-badline ]; then
    ok=1; export SCN_SLOW=1
    for sub in co-hit co-summon; do
      one $sub SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5 SCN_SLOW=1 || { ok=0; cp "$TMP/$sub.host.log" "$TMP/bad.$sub.host.log"; cp "$TMP/$sub.guest.log" "$TMP/bad.$sub.guest.log"; echo "  badline $sub failed"; tail -15 "$TMP/$sub.host.log" "$TMP/$sub.guest.log"; }
    done
    unset SCN_SLOW
    [ $ok = 1 ] && echo "PASS co-badline" || { echo "FAIL co-badline"; bad=1; }
    continue
  fi
  if one "$s"; then echo "PASS $s"; else echo "FAIL $s"; bad=1; grep -hE "COOP|SCRIPT ERROR|ERROR" "$TMP/$s.host.log" "$TMP/$s.guest.log" 2>/dev/null | tail -20; fi
done
exit $bad
