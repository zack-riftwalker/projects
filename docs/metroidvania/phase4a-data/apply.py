#!/usr/bin/env python3
"""Phase 4A room data (MV4-01 step 1). Run once from the repo root:  python3 -I docs/metroidvania/phase4a-data/apply.py

- copies rooms/*.txt (the HEAP H01-H16 and the SOURCE TREE secrets R12, R13, R15) into godot/src/world/rooms/
- replaces the hand-made R11.txt and D04.txt
- appends room-edits-4a.json to godot/src/world/room_edits.json (R01, R02, R03, D03 are generated from the JS levels)
- regenerates the generated rooms (capture.js levels + make-rooms.py) and checks them against expected/
- adds / replaces the rooms.json entries of rooms-4a.json (other rooms are kept as they are)
Running it twice is harmless."""
import json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORLD = os.path.join(ROOT, "godot/src/world")
ROOMS = os.path.join(WORLD, "rooms")

for f in sorted(os.listdir(os.path.join(HERE, "rooms"))):
    shutil.copy(os.path.join(HERE, "rooms", f), os.path.join(ROOMS, f))
for f in ("R11.txt", "D04.txt"):
    shutil.copy(os.path.join(HERE, f), os.path.join(ROOMS, f))

ef = os.path.join(WORLD, "room_edits.json")
edits = json.load(open(ef))
add = json.load(open(os.path.join(HERE, "room-edits-4a.json")))
for rid, lst in add.items():
    have = edits[rid]["edits"]
    for e in lst:
        if e not in have:
            have.append(e)
open(ef, "w").write(json.dumps(edits, indent=1))

levels = os.path.join(ROOT, "tools/godot/capture/out/levels")
if not os.path.isdir(levels):
    subprocess.run(["node", os.path.join(ROOT, "tools/godot/capture/capture.js"), "levels"], check=True)
subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools/godot/make-rooms.py")], check=True)
for f in sorted(os.listdir(os.path.join(HERE, "expected"))):
    got = open(os.path.join(ROOMS, f)).read()
    want = open(os.path.join(HERE, "expected", f)).read()
    if got != want:
        sys.exit("make-rooms.py made a different %s than expected/%s: stop and report" % (f, f))

rf = os.path.join(WORLD, "rooms.json")
data = json.load(open(rf))
new = json.load(open(os.path.join(HERE, "rooms-4a.json")))
for rid, m in new.items():
    data["rooms"][rid] = m

# same layout as the hand-written file: one room per entry, the long fields on their own lines
LONG = ("signs", "plugins", "flood", "rise", "boss", "doors")
out = ['{', '  "start": %s,' % json.dumps(data["start"], ensure_ascii=False).replace("{", "{ ").replace("}", " }"), '  "rooms": {']
ids = list(data["rooms"])
for i, rid in enumerate(ids):
    m = data["rooms"][rid]
    head = ", ".join("%s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)) for k, v in m.items() if k not in LONG)
    pad = " " * (len(rid) + 10)
    lines = ['    "%s": { %s' % (rid, head)]
    for k in LONG:
        if k in m:
            lines[-1] += ","
            if k == "doors":
                ds = ",\n".join(pad + "    " + json.dumps(d, ensure_ascii=False) for d in m[k])
                lines.append('%s"doors": [\n%s\n%s]' % (pad, ds, pad))
            else:
                lines.append("%s%s: %s" % (pad, json.dumps(k), json.dumps(m[k], ensure_ascii=False)))
    lines[-1] += " }" + ("," if i < len(ids) - 1 else "")
    out.extend(lines)
out += ["  }", "}", ""]
open(rf, "w").write("\n".join(out))
json.loads(open(rf).read())      # still valid JSON
print("phase 4A rooms applied: %d rooms in rooms.json" % len(ids))
