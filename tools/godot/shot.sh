#!/usr/bin/env bash
# One screenshot of the 384x216 picture under xvfb with a real renderer: shot.sh <out.png> <scene> [extra user args, e.g. gfx=ultra]
HERE=$(cd "$(dirname "$0")" && pwd)
GODOT=$("$HERE/setup-godot.sh" 2>/dev/null | tail -1) || exit 1
OUT=$(realpath -m "$1"); SCENE=$2; shift 2
timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$HERE/../../godot" --rendering-driver opengl3 --audio-driver Dummy --resolution 768x432 --fixed-fps 60 -- --shot="$OUT" --scene="$SCENE" --wait="${WAIT:-30}" "$@" > "${OUT%.png}.log" 2>&1
[ -f "$OUT" ] && rm -f "${OUT%.png}.log"
