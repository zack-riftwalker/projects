# World layout check (MVB0-02): the built rooms (godot/src/world/rooms.json + room files) together with the phase 4-5
# design (docs/metroidvania/world-phase45.json):
#   1. no two rooms overlap
#   2. every door lines up exactly with the door of the room next to it (same world rows for W/E doors, same world
#      columns for N/S doors); a symlink door (`"symlink": true` in rooms.json, gate `symlink` in the design) is exempt
#      but must pair an E door with a W door
#   3. there is ground to stand on under every door
#   4. gates are known, every one-way drop lands in a room with another exit (W5)
# Usage: python3 -I tools/godot/roomcheck/world.py [repo root] [design json]. Exit 0 = no errors.
import json
import sys
from itertools import combinations

import os
REPO = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
DESIGN = sys.argv[2] if len(sys.argv) > 2 else REPO + "/docs/metroidvania/world-phase45.json"
BUILT = REPO + "/godot/src/world/rooms.json"
ROOMDIR = REPO + "/godot/src/world/rooms/"

STAND = set("#=%0")          # solid, one-way, crack, thick: you can stand on these
PASS = set(" ;!&") | set("TCo*@YkSUDBR$Hn")   # open, dead code, closed gates, objects
OPP = {"E": "W", "W": "E", "N": "S", "S": "N"}
# gates that do not need a physical neighbour door
SPECIAL = {"wrap", "symlink"}

errors, warns, notes = [], [], []


def err(m):
    errors.append(m)


def warn(m):
    warns.append(m)


# ---------- rooms ----------
built = json.load(open(BUILT, encoding="utf-8"))["rooms"]
design = json.load(open(DESIGN, encoding="utf-8"))
rooms = {}
for rid, r in built.items():
    tiles = open(ROOMDIR + r["file"], encoding="utf-8").read().split("\n")
    w, h = r["size"]
    if len(tiles) != h or any(len(t) != w for t in tiles):
        err("%s: room file is not %dx%d" % (rid, w, h))
    rooms[rid] = {"id": rid, "x": r["origin"][0], "y": r["origin"][1], "w": w, "h": h,
                  "built": True, "tiles": tiles, "doors": [], "zone": {"R": "src", "D": "dep", "H": "heap", "Z": "lab"}.get(rid[0], "built")}
for r in design["rooms"]:
    if r["id"] in rooms:
        b = rooms[r["id"]]
        if (b["x"], b["y"], b["w"], b["h"]) != (r["x"], r["y"], r["w"], r["h"]):
            err("%s: design %s differs from built %s" % (r["id"], (r["x"], r["y"], r["w"], r["h"]), (b["x"], b["y"], b["w"], b["h"])))
        b["zone"] = r["zone"]
        b["design_doors"] = r["doors"]
        continue
    rooms[r["id"]] = {"id": r["id"], "x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"],
                      "built": False, "tiles": None, "doors": [], "design_doors": r["doors"], "zone": r["zone"]}

# ---------- 1. overlaps ----------
for a, b in combinations(rooms.values(), 2):
    if a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]:
        err("OVERLAP %s %s" % (a["id"], b["id"]))


# ---------- links ----------
def world_span(room, side, a, b):
    off = room["y"] if side in "WE" else room["x"]
    return off + a, off + b


links = []      # each: a, side, b, lo, hi, gate, note, src, (b_lo, b_hi for symlinks)
seen = set()
for rid, r in built.items():
    for d in r.get("doors", []):
        tid, tdoor = d["to"].split(":")
        lo, hi = world_span(rooms[rid], d["side"], d["a"], d["b"])
        if tid not in built:
            if tid in rooms:
                continue    # a planned room: the design link covers it
            notes.append("sealed door %s -> %s (room not designed yet)" % (d["id"], d["to"]))
            continue
        td = next((x for x in built[tid]["doors"] if x["id"] == d["to"]), None)
        if td is None:
            err("%s: target door %s missing" % (d["id"], d["to"]))
            continue
        if td["to"] != d["id"]:
            err("%s -> %s but %s -> %s" % (d["id"], d["to"], td["id"], td["to"]))
        key = tuple(sorted([d["id"], td["id"]]))
        if key in seen:
            continue
        seen.add(key)
        tlo, thi = world_span(rooms[tid], td["side"], td["a"], td["b"])
        gate = "symlink" if (d.get("symlink") or td.get("symlink")) else d.get("lock", "")
        links.append({"a": rid, "side": d["side"], "b": tid, "lo": lo, "hi": hi, "tlo": tlo, "thi": thi,
                      "tside": td["side"], "gate": gate, "note": "", "src": "built"})

for l in design["links"]:
    a, b = l["a"], l["b"]
    if a in built and b in built:
        same = [x for x in links if {x["a"], x["b"]} == {a, b} and x["src"] == "built"]
        if not same:
            warn("design link %s %s %s not built yet (both rooms are built)" % (a, l["side"], b))
        else:
            x = same[0]
            sp = (x["lo"], x["hi"]) if x["a"] == a else (x["tlo"], x["thi"])
            if l.get("gate") != "symlink" and (l["lo"], l["hi"]) != sp:
                err("design link %s-%s span %s differs from built %s" % (a, b, (l["lo"], l["hi"]), sp))
            continue
    links.append(dict(l, tlo=l.get("b_lo", l["lo"]), thi=l.get("b_hi", l["hi"]), tside=l.get("b_side", OPP[l["side"]]), src="design"))

# design door records must match the links
for r in design["rooms"]:
    for d in r["doors"]:
        lo, hi = world_span(rooms[r["id"]], d["side"], d["a"], d["b"])
        ok = False
        for l in links:
            if l["a"] == r["id"] and l["b"] == d["to"] and l["side"] == d["side"] and (l["lo"], l["hi"]) == (lo, hi):
                ok = True
            if l["b"] == r["id"] and l["a"] == d["to"] and l["tside"] == d["side"] and (l["tlo"], l["thi"]) == (lo, hi):
                ok = True
        if not ok:
            err("design door %s %s %d..%d -> %s has no matching link" % (r["id"], d["side"], d["a"], d["b"], d["to"]))
for l in links:
    if l["src"] != "design":
        continue
    ends = [(l["a"], l["side"], l["b"], l["lo"], l["hi"])]
    if l["gate"] != "wrap":     # a wrap door leads back into its own room: one record only
        ends.append((l["b"], l["tside"], l["a"], l["tlo"], l["thi"]))
    for rid, side, other, lo, hi in ends:
        room = rooms.get(rid)
        if room is None or room["built"]:
            continue
        lo_l, hi_l = (lo - room["y"], hi - room["y"]) if side in "WE" else (lo - room["x"], hi - room["x"])
        if not any(d["side"] == side and d["to"] == other and (d["a"], d["b"]) == (lo_l, hi_l) for d in room["design_doors"]):
            err("link %s %s %s: room %s lacks door %s %d..%d -> %s" % (l["a"], l["side"], l["b"], rid, side, lo_l, hi_l, other))


# ---------- 2. alignment ----------
def edge_ok(room, side, lo, hi, tag):
    if side in "WE":
        if lo < room["y"] + 1 or hi > room["y"] + room["h"] - 2:
            err("%s: door rows %d..%d leave no wall/floor row in %s (y %d..%d)" % (tag, lo, hi, room["id"], room["y"], room["y"] + room["h"] - 1))
    else:
        if lo < room["x"] or hi > room["x"] + room["w"] - 1:
            err("%s: door cols %d..%d outside %s (x %d..%d)" % (tag, lo, hi, room["id"], room["x"], room["x"] + room["w"] - 1))


for l in links:
    A, B = rooms.get(l["a"]), rooms.get(l["b"])
    tag = "%s %s %s" % (l["a"], l["side"], l["b"])
    if A is None or B is None:
        err("%s: unknown room" % tag)
        continue
    if l["gate"] == "wrap":
        edge_ok(A, l["side"], l["lo"], l["hi"], tag)
        continue
    if l["gate"] == "symlink":
        if {l["side"], l["tside"]} != {"E", "W"}:
            err("%s: a symlink must join an E door with a W door" % tag)
        edge_ok(A, l["side"], l["lo"], l["hi"], tag)
        edge_ok(B, l["tside"], l["tlo"], l["thi"], tag)
        if (l["hi"] - l["lo"]) != (l["thi"] - l["tlo"]):
            warn("%s: symlink ends have different heights" % tag)
        continue
    s = l["side"]
    if l["tside"] != OPP[s]:
        err("%s: sides %s/%s do not face each other" % (tag, s, l["tside"]))
    if (l["lo"], l["hi"]) != (l["tlo"], l["thi"]):
        if l["src"] == "built" and s in "WE" and l["hi"] == l["thi"]:
            # built in phase 3: the engine keeps the player's height above the door's bottom row
            notes.append("%s: built doors share the bottom row %d, heights differ %s vs %s" % (tag, l["hi"], (l["lo"], l["hi"]), (l["tlo"], l["thi"])))
        else:
            err("%s: spans differ %s vs %s" % (tag, (l["lo"], l["hi"]), (l["tlo"], l["thi"])))
    if s == "E" and A["x"] + A["w"] != B["x"]:
        err("%s: not touching (A right edge %d, B left %d)" % (tag, A["x"] + A["w"], B["x"]))
    if s == "W" and B["x"] + B["w"] != A["x"]:
        err("%s: not touching (B right edge %d, A left %d)" % (tag, B["x"] + B["w"], A["x"]))
    if s == "S" and A["y"] + A["h"] != B["y"]:
        err("%s: not touching (A bottom %d, B top %d)" % (tag, A["y"] + A["h"], B["y"]))
    if s == "N" and B["y"] + B["h"] != A["y"]:
        err("%s: not touching (B bottom %d, A top %d)" % (tag, B["y"] + B["h"], A["y"]))
    edge_ok(A, s, l["lo"], l["hi"], tag)
    edge_ok(B, OPP[s], l["tlo"], l["thi"], tag)


# ---------- 3. ground under every door ----------
def tile(room, col, row):
    return room["tiles"][row][col]


def ground_we(room, side, lo, hi, tag):
    """W/E door: the row under the door, at the wall column, must be standable."""
    row = hi + 1 - room["y"]
    if row > room["h"] - 1:
        err("%s: nothing under the door in %s" % (tag, room["id"]))
        return
    if not room["built"]:
        return      # design room: the floor row exists (edge_ok); its tiles are drawn later
    col = 0 if side == "W" else room["w"] - 1
    t = tile(room, col, row)
    if t not in STAND:
        err("%s: tile under the door in %s is %r (row %d col %d)" % (tag, room["id"], t, row, col))
    shut = [tile(room, col, rr - room["y"]) for rr in range(lo, hi + 1)]
    if any(c == "#" for c in shut):
        notes.append("%s: %s door cells are wall today (planned change to a built room)" % (tag, room["id"]))


def ground_ns(upper, lower, lo, hi, tag):
    """N/S door: the upper room needs floor beside the hole (you arrive from below, pushed up,
    and land next to it); the lower room needs ground somewhere under the hole."""
    for room, row in ((upper, upper["h"] - 1), (lower, 0)):
        if room["built"] and any(tile(room, c - room["x"], row) == "#" for c in range(lo, hi + 1)):
            notes.append("%s: %s hole cells are wall today (planned change to a built room)" % (tag, room["id"]))
    left, right = lo - 1 >= upper["x"], hi + 1 <= upper["x"] + upper["w"] - 1
    if not (left or right):
        err("%s: the hole fills the whole floor of %s" % (tag, upper["id"]))
    if upper["built"]:
        row = upper["h"] - 1
        sides = []
        if left:
            sides.append(tile(upper, lo - 1 - upper["x"], row))
        if right:
            sides.append(tile(upper, hi + 1 - upper["x"], row))
        if not any(t in STAND for t in sides):
            err("%s: no standable floor beside the hole in %s (%s)" % (tag, upper["id"], sides))
    if lower["built"]:
        for c in range(lo, hi + 1):
            col = c - lower["x"]
            if not any(tile(lower, col, r) in STAND or tile(lower, col, r) in "w^" for r in range(1, lower["h"])):
                err("%s: column %d of %s has no ground under the hole" % (tag, c, lower["id"]))


for l in links:
    A, B = rooms.get(l["a"]), rooms.get(l["b"])
    if A is None or B is None:
        continue
    tag = "%s %s %s" % (l["a"], l["side"], l["b"])
    s = l["side"]
    if s in "WE" or l["gate"] == "symlink":
        ground_we(A, s, l["lo"], l["hi"], tag)
        if l["gate"] != "wrap":
            ground_we(B, l["tside"], l["tlo"], l["thi"], tag)
    else:
        if l["gate"] == "wrap":
            continue
        upper, lower = (B, A) if s == "N" else (A, B)
        ground_ns(upper, lower, l["lo"], l["hi"], tag)

# ---------- 4. gates, one-way exits (W5), terminals ----------
GATES = {"", "catch", "bash", "agents", "sudo", "curl", "ssh", "breakpoint", "revert", "force", "opus", "dead",
         "flood0", "flood1", "fight", "boss", "drop", "lever", "mutex", "wrap", "break", "merge",
         "symlink", "join", "checkout",
         "until:boss:NULL", "until:boss:REVIEWER1", "until:boss:MERGE", "until:boss:LEAK", "flood:0", "flood:1",
         "until:hatch:H10S", "until:hatch:H10N", "until:link:lab", "until:2of:lab:a,lab:b,lab:c"}
for l in links:
    if l["gate"] not in GATES:
        err("%s %s %s: unknown gate %r" % (l["a"], l["side"], l["b"], l["gate"]))
doors_of = {}
for l in links:
    doors_of.setdefault(l["a"], []).append(l)
    doors_of.setdefault(l["b"], []).append(l)
for l in links:
    if l["gate"] == "drop" or l["note"] in ("trapdoor", "hatch"):
        upper, lower = (l["b"], l["a"]) if l["side"] == "N" else (l["a"], l["b"])
        if l["gate"] == "sudo":          # a hatch you open from below: the one-way is upward
            upper, lower = lower, upper
        others = [x for x in doors_of.get(lower, []) if x is not l]
        if not others:
            err("one-way %s %s %s: %s has no other exit (W5)" % (l["a"], l["side"], l["b"], lower))
        else:
            notes.append("one-way %s %s %s: lands in %s, %d other exit(s)" % (l["a"], l["side"], l["b"], lower, len(others)))
terms = {}
for r in design["rooms"]:
    if "terminal" in r["feats"]:
        terms.setdefault(r["zone"], []).append(r["id"])
for rid, r in built.items():
    if r.get("terminal") and rid not in [x for v in terms.values() for x in v]:
        terms.setdefault(rooms[rid]["zone"], []).append(rid)
notes.append("terminals: %s" % ", ".join("%s=%s" % (k, "/".join(v)) for k, v in sorted(terms.items())))

# ---------- report ----------
print("rooms %d (built %d, design %d), links %d" % (len(rooms), sum(r["built"] for r in rooms.values()),
                                                  sum(not r["built"] for r in rooms.values()), len(links)))
for m in notes:
    print("note:", m)
for m in warns:
    print("WARN:", m)
for m in errors:
    print("ERROR:", m)
print("errors %d, warnings %d" % (len(errors), len(warns)))
sys.exit(1 if errors else 0)
