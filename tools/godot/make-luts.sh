#!/usr/bin/env bash
# Writes the colour-grade LUTs of GFX-N (MVGN-07) of the pure palettes as 256x16 PNG strips to docs/reports/img-gfx-network/luts/ (to look at). The game builds
# the same LUTs at run time with Look.lut_image (a mood mixed over `stable` by k gets its own), so tool and game cannot differ. (Runs as a test so it
# shares the game's compiled classes: a bare `-s` script hangs on the Look <-> PostChain classes.)
HERE=$(cd "$(dirname "$0")" && pwd)
GODOT=$("$HERE/setup-godot.sh" 2>/dev/null | tail -1)
mkdir -p "$HERE/../../docs/reports/img-gfx-network/luts"
LUT_OUT=$(realpath "$HERE/../../docs/reports/img-gfx-network/luts") "$GODOT" --headless --path "$HERE/../../godot" -- --test=luts 2>&1 | grep -E "^TEST"
