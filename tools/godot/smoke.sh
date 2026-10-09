#!/usr/bin/env bash
# Runs the Godot probe headless and under xvfb. Exit non-zero on any failure.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
GODOT=$("$HERE/setup-godot.sh" | tail -1) || { echo "FAIL setup"; exit 1; }
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
rc=0

"$GODOT" --headless --audio-driver Dummy --quit-after 600 --path "$HERE/smoke" >"$OUT/h.log" 2>&1
if [ $? -eq 0 ] && grep -q "^smoke: done" "$OUT/h.log"; then echo "PASS headless"; else echo "FAIL headless"; tail -20 "$OUT/h.log"; rc=1; fi

xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$HERE/smoke" --rendering-driver opengl3 \
  --resolution 640x360 --audio-driver Dummy -- "$OUT/shot.png" >"$OUT/x.log" 2>&1
if [ -f "$OUT/shot.png" ] && [ "$(stat -c %s "$OUT/shot.png")" -gt 1024 ]; then
  echo "PASS screenshot ($(stat -c %s "$OUT/shot.png") bytes)"
  [ -n "${SMOKE_KEEP_PNG:-}" ] && cp "$OUT/shot.png" "$SMOKE_KEEP_PNG"
else echo "FAIL screenshot"; tail -20 "$OUT/x.log"; rc=1; fi
exit $rc
