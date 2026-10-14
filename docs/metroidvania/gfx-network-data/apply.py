#!/usr/bin/env python3
"""MVGN-02: adds the `mood` field to the NETWORK's rooms.json entries and copies palettes.json to godot/assets/theme/moods.json.
Run from the repo root:  python3 -I docs/metroidvania/gfx-network-data/apply.py [repo root]
Only text of the entries is touched (the file keeps its layout). Running it twice is harmless."""
import json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(HERE, "..", "..", ".."))
rf = os.path.join(ROOT, "godot/src/world/rooms.json")
moods = json.load(open(os.path.join(HERE, "moods.json")))
text = open(rf).read()
for rid, (name, k) in moods.items():
    # `"N08": { "file": "N08.txt", ` -> the same plus `"mood": ["lair", 0.6], ` (nothing is added when the entry has a mood already)
    pat = re.compile(r'("%s": \{ "file": "[^"]+", )(?!"mood")' % rid)
    text, n = pat.subn(lambda m: '%s"mood": %s, ' % (m.group(1), json.dumps([name, k])), text, count=1)
    if n == 0 and '"%s": {' % rid not in text:
        sys.exit("room %s is not in rooms.json: stop and report" % rid)
data = json.loads(text)                              # still valid JSON
for rid, (name, k) in moods.items():
    assert data["rooms"][rid]["mood"] == [name, k], rid
open(rf, "w").write(text)
shutil.copy(os.path.join(HERE, "palettes.json"), os.path.join(ROOT, "godot/assets/theme/moods.json"))
print("moods applied to %d rooms" % len(moods))
