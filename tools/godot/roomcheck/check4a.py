# Design-time room checker (Claude's tool, not part of test-all): sizes, door cells, partner doors in world coordinates,
# no overlaps, and reachability with the movement simulator (sim.py, a close port of Player movement) for each route
# the phase 4A design needs. Reads godot/src/world (live) with docs/metroidvania/phase4a-data laid over it, so it works
# before and after apply.py.  Usage: python3 -I tools/godot/roomcheck/check4a.py [room ids...]
import json, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim import Room, T
from reach import explore, entry_state

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
LIVE = os.path.join(ROOT, "godot/src/world")
STAGE = os.path.join(ROOT, "docs/metroidvania/phase4a-data")
OLD = json.load(open(os.path.join(LIVE, "rooms.json")))["rooms"]
NEW = json.load(open(os.path.join(STAGE, "rooms-4a.json")))
EXTRA = {}
ALL = dict(OLD)
ALL.update(NEW)
bad = []


def rows_of(rid):
    for p in (os.path.join(STAGE, "rooms", rid + ".txt"), os.path.join(STAGE, rid + ".txt"), os.path.join(STAGE, "expected", rid + ".txt"),
              os.path.join(LIVE, "rooms", ALL[rid]["file"])):
        if os.path.exists(p):
            return open(p).read().split("\n")


def world_span(rid, d):
    m = ALL[rid]
    ox, oy = m["origin"]
    if d["side"] in ("W", "E"):
        return ("row", oy + d["a"], oy + d["b"], ox if d["side"] == "W" else ox + m["size"][0])
    return ("col", ox + d["a"], ox + d["b"], oy if d["side"] == "N" else oy + m["size"][1])


# ---- static checks
for rid in list(NEW):
    m = ALL[rid]
    rows = rows_of(rid)
    w, h = m["size"]
    if len(rows) != h or any(len(r) != w for r in rows):
        bad.append("%s: size %dx%d but file %dx%d" % (rid, w, h, max(len(r) for r in rows), len(rows)))
        continue
    for d in m["doors"]:
        s, a, b = d["side"], d["a"], d["b"]
        if s in ("W", "E"):
            x = 0 if s == "W" else w - 1
            xin = 1 if s == "W" else w - 2
            for y in range(a, b + 1):
                if rows[y][x] not in " ;N.":
                    bad.append("%s door %s: edge cell (%d,%d) is %r" % (rid, d["id"], x, y, rows[y][x]))
            if b + 1 < h and rows[b + 1][x] not in "#=" and rows[b + 1][xin] not in "#=":
                bad.append("%s door %s: no floor under it at row %d" % (rid, d["id"], b + 1))
        else:
            y = 0 if s == "N" else h - 1
            for x in range(a, b + 1):
                if rows[y][x] not in " %!&.":
                    bad.append("%s door %s: edge cell (%d,%d) is %r" % (rid, d["id"], x, y, rows[y][x]))
        to = d["to"].split(":")[0]
        if to in ALL:
            td = [q for q in ALL[to]["doors"] if q["id"] == d["to"]]
            if not td:
                bad.append("%s door %s: target door %s missing" % (rid, d["id"], d["to"]))
            else:
                td = td[0]
                if td["to"] != d["id"]:
                    bad.append("%s door %s: target %s points back to %s" % (rid, d["id"], d["to"], td["to"]))
                a1 = world_span(rid, d)
                a2 = world_span(to, td)
                if a1 != a2:
                    bad.append("%s door %s: world span %s != %s's %s" % (rid, d["id"], a1, d["to"], a2))
# overlaps
ids = list(ALL)
for i in range(len(ids)):
    for j in range(i + 1, len(ids)):
        A, B = ALL[ids[i]], ALL[ids[j]]
        ax, ay = A["origin"]; aw, ah = A["size"]
        bx, by = B["origin"]; bw, bh = B["size"]
        if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
            bad.append("overlap %s %s" % (ids[i], ids[j]))


# ---- reachability
def room_for(rid, opts=None, closed=()):
    m = ALL[rid]
    o = dict(opts or {})
    fl = m.get("flood")
    lvl = o.pop("level", None)
    if fl is not None and lvl is not None and fl[2 - lvl] is not None:
        o["liquid_y"] = fl[2 - lvl] * T + 6
    doors = []
    for d in m["doors"]:
        op = d["to"].split(":")[0] in ALL and d["id"] not in closed
        lk = d.get("lock", "")
        if lk.startswith("flood:") and lvl is not None:
            op = op and lvl <= int(lk[6:])
        if lk.startswith("until:") and lk[6:] not in o.get("flags", ()):
            op = False
        doors.append(dict(side=d["side"], a=d["a"], b=d["b"], open=op, id=d["id"]))
    o.pop("flags", None)
    return Room(rows_of(rid), doors, o), doors


def check(rid, frm, ab, want, nowant=(), opts=None, closed=(), label=""):
    rm, doors = room_for(rid, opts, closed)
    d = [q for q in doors if q["id"] == frm][0]
    dd, seen = explore(rm, ab, entry_state(rm, d["side"], d, ab))
    got = {[q["id"] for q in doors if q["side"] == s and q["a"] == a][0] for (s, a) in dd}
    miss = [x for x in want if x not in got]
    extra = [x for x in nowant if x in got]
    st = "ok " if not miss and not extra else "BAD"
    print("%s %s %s from %s %s: reached %s%s%s" % (st, rid, label, frm, sorted(ab), sorted(got), " MISSING %s" % miss if miss else "",
                                              " SHOULD NOT %s" % extra if extra else ""))
    if miss or extra:
        bad.append("%s %s from %s: missing %s, unwanted %s" % (rid, label, frm, miss, extra))
    return seen


def reach_cells(rid, frm, ab, cells, opts=None, label=""):
    """cells: list of (x, y) item tiles that must be touchable: some standing spot within a jump of it"""
    rm, doors = room_for(rid, opts)
    d = [q for q in doors if q["id"] == frm][0]
    _, seen = explore(rm, ab, entry_state(rm, d["side"], d, ab))
    for (x, y) in cells:
        okc = any(abs(c - x) <= 4 and 0 <= (f // T) - 1 - y <= 3 for (c, f) in seen)
        print("%s %s %s cell (%d,%d) %r" % ("ok " if okc else "BAD", rid, label, x, y, rows_of(rid)[y][x]))
        if not okc:
            bad.append("%s %s: cell (%d,%d) not reachable" % (rid, label, x, y))


if __name__ == "__main__":
    bad = [b for b in bad if not b.startswith(("R01 door R01:W: edge", "D03 door D03:W: world", "D03 door D03:E: world", "D04 door D04:W: world"))]
    for b in bad:
        print("STATIC", b)
    only = sys.argv[1:]
    B = {"bash"}
    BS = {"bash", "sudo"}

    def go(rid):
        return not only or rid in only
    if go("H01"):
        check("H01", "H01:W", B, ["H01:E"], ["H01:N"])
        check("H01", "H01:E", BS, ["H01:W"], ["H01:N"])
    if go("H02"):
        check("H02", "H02:W", B, ["H02:E"])
        check("H02", "H02:E", B, ["H02:W"])
        check("H02", "H02:W", B, ["H02:N"], opts={"crack_open": True}, label="crack")
    if go("H04"):
        check("H04", "H04:W", B, ["H04:E"])
        check("H04", "H04:E", B, ["H04:W"])
        check("H04", "H04:N", B, ["H04:E", "H04:W"], opts={"flags": ["hatch:H10S"]})
    if go("H03"):
        check("H03", "H03:W", B, ["H03:E", "H03:NE"], ["H03:E2", "H03:E3", "H03:S"], opts={"level": 2}, label="L2")
        check("H03", "H03:E", B, ["H03:W", "H03:NE"], opts={"level": 2}, label="L2")
        check("H03", "H03:W", B, ["H03:E2"], ["H03:E3", "H03:S"], opts={"level": 1}, label="L1")
        check("H03", "H03:E2", B, ["H03:W", "H03:E"], opts={"level": 1}, label="L1")
        check("H03", "H03:W", B, ["H03:E3", "H03:S"], opts={"level": 0}, label="L0")
        check("H03", "H03:E3", B, ["H03:W", "H03:E", "H03:E2"], opts={"level": 0}, label="L0")
        check("H03", "H03:E3", BS, ["H03:W"], ["H03:SW"], opts={"level": 0}, label="L0 fire")
    if go("H13"):
        check("H13", "H13:W", B, ["H13:W"])
        reach_cells("H13", "H13:W", B, [(40, 3), (58, 12)])
    if go("H07"):
        check("H07", "H07:W", B, ["H07:E"], opts={"level": 2})
        check("H07", "H07:E", B, ["H07:W"], opts={"level": 2})
        reach_cells("H07", "H07:W", B, [(33, 9)], opts={"level": 2}, label="pillar")
    if go("H05"):
        check("H05", "H05:W", B, [], ["H05:E"], opts={"level": 1}, label="wall")
        check("H05", "H05:W", B, ["H05:E"], opts={"level": 1, "thick_open": True}, label="blown")
        check("H05", "H05:E", B, [], ["H05:W"], opts={"level": 1}, label="wall")
    if go("H15"):
        reach_cells("H15", "H15:W", B, [(47, 5)], opts={"level": 0})
    if go("H06"):
        check("H06", "H06:W", B, ["H06:NW", "H06:W2"], opts={"level": 1}, label="L1")
        check("H06", "H06:W2", B, ["H06:NW", "H06:W"], opts={"level": 1}, label="L1")
        check("H06", "H06:NW", B, ["H06:W", "H06:W2"], opts={"level": 1}, label="L1")
        check("H06", "H06:W2", B, ["H06:NW"], opts={"level": 2}, label="L2")
        check("H06", "H06:W", B, ["H06:NW", "H06:W2"], opts={"level": 0}, label="L0")
    if go("H08"):
        check("H08", "H08:E", B, ["H08:W"])
        check("H08", "H08:W", B, ["H08:E"])
    if go("H09"):
        check("H09", "H09:E", B, ["H09:W"], opts={"flags": ["boss:LEAK"]})
    if go("H10"):
        check("H10", "H10:E", BS, ["H10:N", "H10:S"])
        check("H10", "H10:E", B, ["H10:S"], label="nosudo")
        reach_cells("H10", "H10:E", BS, [(6, 3)], label="token ledge")
    if go("H11"):
        check("H11", "H11:S", BS, [], ["H11:N"], opts={"flags": ["hatch:H10N"]})
        reach_cells("H11", "H11:S", BS, [(194, 12), (8, 3), (98, 4), (144, 4)], opts={"flags": ["hatch:H10N"]})
        check("H11", "H11:E", BS, ["H11:S"], opts={"flags": ["hatch:H10N"]}, closed=(), label="from E")
    if go("H12"):
        check("H12", "H12:S", B, ["H12:S"], ["H12:E"])
        reach_cells("H12", "H12:S", B, [(3, 5)])
        check("H12", "H12:S", B, ["H12:E"], opts={"fire_open": True}, label="ssh")
    if go("H16"):
        reach_cells("H16", "H16:W", B, [(46, 7), (27, 5)], opts={"fire_open": True})
    if go("H14"):
        reach_cells("H14", "H14:S", B, [(6, 7), (25, 8)])
    if go("R01"):
        check("R01", "R01:E", {"bash"}, ["R01:W"], ["R01:N"], opts={"crack_open": True}, label="gate shut")
        check("R01", "R01:W", {"bash"}, ["R01:N", "R01:E"], opts={"gate_c": True, "crack_open": True}, label="gate open")
        reach_cells("R01", "R01:E", set(), [(50, 6)], label="ledge")
    if go("R02"):
        check("R02", "R02:W", {"bash"}, ["R02:E"], ["R02:N"], label="bash only")
        check("R02", "R02:W", set(), ["R02:E"], ["R02:N"], label="start")
        check("R02", "R02:W", BS, ["R02:N", "R02:E"], label="sudo")
    if go("R03"):
        check("R03", "R03:W", set(), ["R03:E"], ["R03:N"], label="gate shut")
        check("R03", "R03:W", {"bash"}, ["R03:N", "R03:E"], opts={"gate_a": True}, label="gate open")
    if go("R11"):
        check("R11", "R11:W", B, [], ["R11:E"], label="gate shut")
        check("R11", "R11:W", B, ["R11:E"], opts={"gate_c": True}, label="gate open")
        check("R11", "R11:E", B, ["R11:W"], opts={"gate_c": True}, label="back")
    if go("D03"):
        check("D03", "D03:W", B, ["D03:E"], ["D03:E2"], opts={"crack_open": True})
        check("D03", "D03:E2", B, ["D03:E"], opts={"crack_open": True, "fire_open": True}, label="from heap")
    if go("D04"):
        check("D04", "D04:N", B, ["D04:W", "D04:E"], opts={"level": 0}, label="drop")

        check("D04", "D04:W", BS, ["D04:E", "D04:N"], opts={"level": 0}, label="up with sudo")
        check("D04", "D04:W", BS, ["D04:E"], ["D04:N"], opts={"level": 1}, label="shut before LEAK")
        check("H03", "H03:S", BS, ["H03:W", "H03:E3"], opts={"level": 0}, label="from below")
    if go("R13"):
        reach_cells("R13", "R13:S", B, [(5, 7), (27, 5)])
        check("R13", "R13:S", B, ["R13:S"])
    if go("R12"):
        reach_cells("R12", "R12:S", B, [(25, 8), (5, 8)])
        check("R12", "R12:S", B, ["R12:S"])
    if go("R15"):
        reach_cells("R15", "R15:S", B, [(32, 8), (5, 8)])
        check("R15", "R15:S", B, ["R15:S"])
    print("\n%d problems" % len(bad))
    for b in bad:
        print(" -", b)
