#!/usr/bin/env python3
"""Phase 4B-3 room data (MVB3-01 step 1). Run once from the repo root:  python3 -I docs/metroidvania/phase4b3-data/apply.py

- copies the redrawn NETWORK room files (rooms/*.txt) into godot/src/world/rooms/
- merges the new keys of rooms-4b3.json into the live rooms.json entries: N12 packets (lossy), N17 chase, N21 wave
  (every other key, door and size stays exactly as it is)
Running it twice is harmless."""
import json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORLD = os.path.join(ROOT, "godot/src/world")
REDRAWN = ["N01", "N02", "N04", "N05", "N06", "N07", "N08", "N10", "N11", "N12", "N13", "N16", "N17", "N18"]
KEYS = {"N12": ["packets"], "N17": ["chase"], "N21": ["wave"]}

new = json.load(open(os.path.join(HERE, "rooms-4b3.json")))
rf = os.path.join(WORLD, "rooms.json")
text = open(rf).read()
data = json.loads(text)
for rid in REDRAWN:
    live = data["rooms"][rid]
    if (live["size"], [d["id"] for d in live["doors"]]) != (new[rid]["size"], [d["id"] for d in new[rid]["doors"]]):
        sys.exit("%s: size or doors differ from the 4B-3 data: stop and report" % rid)
    shutil.copy(os.path.join(HERE, "rooms", rid + ".txt"), os.path.join(WORLD, "rooms", live["file"]))
for rid, keys in KEYS.items():
    for k in keys:
        data["rooms"][rid][k] = new[rid][k]

# rewrite only the changed entries' long-key lines, keeping the file's layout: re-dump the whole file in its own style
SHORT = ("file", "title", "size", "origin", "world", "music", "zone", "terminal", "secret", "offmap", "lab", "end")
out = ['{', '  "start": %s,' % json.dumps(data["start"], ensure_ascii=False).replace("{", "{ ").replace("}", " }"), '  "rooms": {']
ids = list(data["rooms"])
for i, rid in enumerate(ids):
    m = data["rooms"][rid]
    head = ", ".join("%s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)) for k, v in m.items() if k in SHORT)
    pad = " " * (len(rid) + 10)
    lines = ['    "%s": { %s' % (rid, head)]
    for k, v in m.items():
        if k in SHORT or k == "doors":
            continue
        lines[-1] += ","
        lines.append("%s%s: %s" % (pad, json.dumps(k), json.dumps(v, ensure_ascii=False)))
    if "doors" in m:
        lines[-1] += ","
        ds = ",\n".join(pad + "    " + json.dumps(d, ensure_ascii=False) for d in m["doors"])
        lines.append('%s"doors": [\n%s\n%s]' % (pad, ds, pad))
    lines[-1] += " }" + ("," if i < len(ids) - 1 else "")
    out.extend(lines)
out += ["  }", "}", ""]
open(rf, "w").write("\n".join(out))
assert json.loads(open(rf).read()) == data
print("phase 4B-3 rooms applied: %d room files, keys %s" % (len(REDRAWN), KEYS))
