#!/usr/bin/env bash
# INFINITE LOOP's phase-3 music (docs/metroidvania/18-loop-build.md section 7): the boss track that gets stuck. Its 36 s are 24 bars of 1.5 s
# (160 bpm); in every 8 bars the last bar plays twice, like a scratched record: 3 x 13.5 s = 40.5 s, a seamless loop like the original.
# Then add it to godot/assets/music/index.json: "loop_stutter": {"len": 40.5, "loop_start": 0, "once": false}.
set -e
D=$(cd "$(dirname "$0")/../.." && pwd)/godot/assets/music
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ffmpeg -y -loglevel error -i "$D/boss.ogg" -ac 2 -ar 44100 "$T/src.wav"
n=0; : > "$T/list.txt"
for c in 0 1 2; do
  s=$(echo "$c * 12" | bc)
  ffmpeg -y -loglevel error -i "$T/src.wav" -ss "$s" -t 12 "$T/c$c.wav"
  ffmpeg -y -loglevel error -i "$T/src.wav" -ss "$(echo "$s + 10.5" | bc)" -t 1.5 "$T/r$c.wav"
  echo "file '$T/c$c.wav'" >> "$T/list.txt"; echo "file '$T/r$c.wav'" >> "$T/list.txt"
done
ffmpeg -y -loglevel error -f concat -safe 0 -i "$T/list.txt" -c:a libvorbis -q:a 0 "$D/loop_stutter.ogg"
