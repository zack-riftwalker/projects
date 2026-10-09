#!/usr/bin/env bash
# Installs Godot 4.7.2 (idempotent). Last stdout line = binary path.
set -euo pipefail
VER=4.7.2
DIR="${CLAWD_GODOT_DIR:-$HOME/.cache/clawd-godot}/$VER"
BIN="$DIR/Godot_v${VER}-stable_linux.x86_64"
URL="https://downloads.godotengine.org/?version=$VER&flavor=stable&slug=linux.x86_64.zip"

if [ -x "$BIN" ] && "$BIN" --version 2>/dev/null | grep -q "^$VER\.stable"; then
  echo "godot $VER already installed" >&2
  echo "$BIN"; exit 0
fi

for t in curl unzip sha256sum; do
  command -v "$t" >/dev/null || { echo "ERROR: $t is required" >&2; exit 1; }
done
mkdir -p "$DIR"
TMP=$(mktemp -d "$DIR/.dl.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

echo "downloading godot $VER (~78 MB)..." >&2
curl -fSL --retry 3 -o "$TMP/godot.zip" "$URL" || { echo "ERROR: download failed ($URL)" >&2; exit 1; }
echo "zip size: $(stat -c %s "$TMP/godot.zip") bytes, sha256: $(sha256sum "$TMP/godot.zip" | cut -d' ' -f1)" >&2

# Official checksums, when the host publishes them next to the zip.
if curl -fsSL -o "$TMP/sums.txt" "https://downloads.godotengine.org/?version=$VER&flavor=stable&slug=SHA512-SUMS.txt" 2>/dev/null \
   && grep -q "linux.x86_64.zip" "$TMP/sums.txt"; then
  want=$(grep "Godot_v${VER}-stable_linux.x86_64.zip" "$TMP/sums.txt" | cut -d' ' -f1)
  got=$(sha512sum "$TMP/godot.zip" | cut -d' ' -f1)
  [ "$want" = "$got" ] || { echo "ERROR: SHA-512 mismatch" >&2; exit 1; }
  echo "SHA-512 verified against published sums" >&2
else
  echo "no published checksum found; record the sha256 above in the report" >&2
fi

unzip -q "$TMP/godot.zip" -d "$TMP/x"
[ -f "$TMP/x/$(basename "$BIN")" ] || { echo "ERROR: binary not in zip" >&2; exit 1; }
chmod +x "$TMP/x/$(basename "$BIN")"
mv -f "$TMP/x/$(basename "$BIN")" "$BIN"
"$BIN" --version 2>/dev/null | grep -q "^$VER\.stable" || { echo "ERROR: installed binary does not report $VER.stable" >&2; exit 1; }
echo "$BIN"
