#!/usr/bin/env bash
# The GFX-N tests that need a real renderer (xvfb + opengl3): gfx-tests.sh [names...]. Prints `TEST <name> PASS|FAIL` lines, exit 1 on any failure.
# gfxother: worlds 1-4 must render byte for byte as the golden captures (tools/godot/golden/, taken from the code before GFX-N with the same
# command). shot.sh runs Godot with --fixed-fps 60, so a frame always advances the game by the same step and two runs give the same picture.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GODOT=$("$HERE/setup-godot.sh" 2>/dev/null | tail -1) || { echo "FAIL setup"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
NAMES=("$@"); [ ${#NAMES[@]} -eq 0 ] && NAMES=(gfxother gfxcontrast normals post gloss rim shadows gfxprobe)
rc=0
for t in "${NAMES[@]}"; do
  case "$t" in
    gfxother)
      bad=""
      for r in R03 D01 D02 D05 H05 T04; do
        bash "$HERE/shot.sh" "$TMP/$r.png" "room:$r"
        n=$(compare -metric AE "$TMP/$r.png" "$HERE/golden/$r.png" null: 2>&1 | grep -oE "^[0-9]+" | head -1)
        [ "${n:-99999}" -eq 0 ] || bad="$bad $r($n)"
      done
      if [ -z "$bad" ]; then echo "TEST gfxother PASS"; else echo "TEST gfxother FAIL differs:$bad"; rc=1; fi ;;
    RENDER_TESTS) ;;
    *)
      out=$(timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$ROOT/godot" --rendering-driver opengl3 --audio-driver Dummy --resolution 768x432 -- --test="$t" 2>&1)
      echo "$out" | grep -E "^TEST $t |^PERF|^GFX" 
      if echo "$out" | grep -q "^TEST $t PASS" && ! echo "$out" | grep -q "SCRIPT ERROR"; then :; else echo "$out" | tail -15; rc=1; fi ;;
  esac
done
exit $rc
