#!/usr/bin/env bash
# The tower theme at the tower's two other ticks (RACE CONDITION, docs/metroidvania/17-race-build.md 5.12): ffmpeg atempo keeps the pitch.
# w4_slow = x0.8333 (tick 1.0, T01 and T02), w4_fast = x1.1905 (tick 0.7, TB2). Then add them to godot/assets/music/index.json (len = the new length).
set -e
D=$(cd "$(dirname "$0")/../.." && pwd)/godot/assets/music
ffmpeg -y -loglevel error -i "$D/w4.ogg" -af atempo=0.8333 -c:a libvorbis -q:a 0 "$D/w4_slow.ogg"
ffmpeg -y -loglevel error -i "$D/w4.ogg" -af atempo=1.1905 -c:a libvorbis -q:a 0 "$D/w4_fast.ogg"
