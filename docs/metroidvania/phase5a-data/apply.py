#!/usr/bin/env python3
"""Phase 5A room data (MV5A-01 step 1). Run once from the repo root:  python3 -I docs/metroidvania/phase5a-data/apply.py

- copies rooms/T*.txt (THREAD TOWER, 19 rooms) into godot/src/world/rooms/
- applies room-edits-5a.json to built rooms: N11 loses its end door and gets a one-way lid on its goto hole and a new sign;
  H11's ceiling hatch opens only after the T02 lever (lock until:lever:T02)
- adds / replaces the rooms.json entries of rooms-5a.json (other rooms are kept as they are)
Running it twice is harmless."""
import json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORLD = os.path.join(ROOT, "godot/src/world")
ROOMS = os.path.join(WORLD, "rooms")

for f in sorted(os.listdir(os.path.join(HERE, "rooms"))):
    shutil.copy(os.path.join(HERE, "rooms", f), os.path.join(ROOMS, f))

rf = os.path.join(WORLD, "rooms.json")
data = json.load(open(rf))
edits = json.load(open(os.path.join(HERE, "room-edits-5a.json")))
for rid, e in edits.items():
    m = data["rooms"][rid]
    path = os.path.join(ROOMS, m["file"])
    rows = [list(r) for r in open(path).read().split("\n")]
    for (x, y, txt) in e.get("cells", []):
        for i, ch in enumerate(txt):
            if rows[y][x + i] not in "#D " + ch:      # an end door, a wall cell or already done: anything else moved since the plan
                sys.exit("%s (%d,%d) is %r, not a wall or an end door: stop and report" % (rid, x + i, y, rows[y][x + i]))
            rows[y][x + i] = ch
    open(path, "w").write("\n".join("".join(r) for r in rows))
    have = {d["id"] for d in m["doors"]}
    for d in e.get("doors_add", []):
        if d["id"] not in have:
            m["doors"].append(d)
    for k in e.get("del", []):
        m.pop(k, None)
    for d in m["doors"]:
        if d["id"] in e.get("doors_lock", {}):
            d["lock"] = e["doors_lock"][d["id"]]
    for k, v in e.get("set", {}).items():
        m[k] = v
    if "sign" in e:
        i, text = e["sign"]
        s = m["signs"][i]
        if isinstance(s, dict):
            s["text"] = text
        else:
            m["signs"][i] = text

new = json.load(open(os.path.join(HERE, "rooms-5a.json")))
for rid, m in new.items():
    data["rooms"][rid] = m

# the layout of the hand-written file: one room per entry, the long fields on their own lines
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
assert json.loads(open(rf).read()) == data      # still valid JSON, nothing lost
print("phase 5A rooms applied: %d rooms in rooms.json" % len(ids))
