#!/usr/bin/env bash
# Installs the Godot 4.7.2 web export templates (only the 3 files needed, not the 1.28 GB zip's other platforms).
set -euo pipefail
T="$HOME/.local/share/godot/export_templates/4.7.2.stable"
if [ -f "$T/web_nothreads_release.zip" ] && [ -f "$T/web_nothreads_debug.zip" ] && [ -f "$T/version.txt" ]; then
  echo "templates ok" >&2; exit 0
fi
mkdir -p "$T"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
echo "downloading export templates (~1.28 GB)..." >&2
curl -fSL --retry 3 -o "$TMP/t.tpz" "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz&platform=templates"
unzip -o -j -q "$TMP/t.tpz" templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt -d "$T"
[ "$(tr -d '\r\n' < "$T/version.txt")" = "4.7.2.stable" ] || { echo "ERROR: unexpected templates version" >&2; exit 1; }
echo "templates installed" >&2
