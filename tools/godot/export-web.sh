#!/usr/bin/env bash
# Exports godot/ to public/mv/ (web, single-threaded) and gzips the big files. Run from anywhere.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
GODOT=$(bash tools/godot/setup-godot.sh | tail -1)
bash tools/godot/setup-templates.sh
rm -rf public/mv && mkdir -p public/mv
BR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)
echo "$BR $(git rev-parse --short HEAD 2>/dev/null || echo 0000000) $(date -u '+%Y-%m-%d %H:%M')" > godot/build.txt
"$GODOT" --headless --path godot --import >/dev/null 2>&1 || echo "import returned non-zero (continuing)" >&2
"$GODOT" --headless --path godot --export-release "Web" ../public/mv/index.html
for f in index.html index.js index.wasm index.pck; do
  [ -f "public/mv/$f" ] || { echo "ERROR: public/mv/$f missing" >&2; exit 1; }
done
find public/mv -maxdepth 1 -type f -size +256k ! -name '*.gz' -print0 | while IFS= read -r -d '' f; do gzip -9 -n -f "$f"; done
cp godot/build.txt public/mv/build.txt
ls -l public/mv | awk 'NR>1{printf "%10d  %s\n",$5,$9}'
