# Design checker for phase 5A (THREAD TOWER), Claude's tool: sizes, door cells, partner doors in world coordinates, no
# overlaps, and reachability with the movement simulator (sim.py; tower tiles: mutex gates `4`, cables `5`; gears and
# pistons from the room data, optimistic). Reads godot/src/world (live) with docs/metroidvania/phase5a-data laid over it.
# Usage: python3 -I tools/godot/roomcheck/check5a.py [room ids...]
import json, math, sys, os, copy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import Room, T
from reach import explore, entry_state

ROOT = HERE
while not os.path.exists(os.path.join(ROOT, "godot/src/world/rooms.json")):
    if os.path.dirname(ROOT) == ROOT:
        ROOT = os.getcwd()
        break
    ROOT = os.path.dirname(ROOT)
LIVE = os.path.join(ROOT, "godot/src/world")
STAGE = HERE if os.path.exists(os.path.join(HERE, "rooms-5a.json")) else os.path.join(ROOT, "docs/metroidvania/phase5a-data")
OLD = json.load(open(os.path.join(LIVE, "rooms.json")))["rooms"]
STAGED = json.load(open(os.path.join(STAGE, "rooms-5a.json")))
EDITS = json.load(open(os.path.join(STAGE, "room-edits-5a.json")))
ALL = copy.deepcopy(OLD)
FILES = {}
for rid, m in OLD.items():
    FILES[rid] = open(os.path.join(LIVE, "rooms", m["file"])).read().split("\n")
for rid, e in EDITS.items():
    rows = [list(r) for r in FILES[rid]]
    for (x, y, txt) in e.get("cells", []):
        for i, ch in enumerate(txt):
            rows[y][x + i] = ch
    FILES[rid] = ["".join(r) for r in rows]
    for d in ALL[rid]["doors"]:
        if d["id"] in e.get("doors_lock", {}):
            d["lock"] = e["doors_lock"][d["id"]]
for rid, meta in STAGED.items():
    ALL[rid] = meta
    FILES[rid] = open(os.path.join(STAGE, "rooms", meta["file"])).read().split("\n")
NEW = list(STAGED) + list(EDITS)
bad = []


def world_span(rid, d):
    m = ALL[rid]
    ox, oy = m["origin"]
    if d["side"] in ("W", "E"):
        return ("row", oy + d["a"], oy + d["b"], ox if d["side"] == "W" else ox + m["size"][0])
    return ("col", ox + d["a"], ox + d["b"], oy if d["side"] == "N" else oy + m["size"][1])


for rid in NEW:
    m = ALL[rid]
    rows = FILES[rid]
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
                if rows[y][x] not in " ;N.%":
                    bad.append("%s door %s: edge cell (%d,%d) is %r" % (rid, d["id"], x, y, rows[y][x]))
            if b + 1 < h and rows[b + 1][x] not in "#=" and rows[b + 1][xin] not in "#=":
                bad.append("%s door %s: no floor under it at row %d" % (rid, d["id"], b + 1))
        else:
            y = 0 if s == "N" else h - 1
            for x in range(a, b + 1):
                if rows[y][x] not in " %!&.;":
                    bad.append("%s door %s: edge cell (%d,%d) is %r" % (rid, d["id"], x, y, rows[y][x]))
        to = d["to"].split(":")[0]
        if d.get("wrap"):
            continue
        if to in ALL:
            td = [q for q in ALL[to]["doors"] if q["id"] == d["to"]]
            if not td:
                bad.append("%s door %s: target door %s missing" % (rid, d["id"], d["to"]))
            else:
                td = td[0]
                if td["to"] != d["id"] and not (td.get("wrap") and ALL[to].get("loop", {}).get("after") == d["id"]):
                    bad.append("%s door %s: target %s points back to %s" % (rid, d["id"], d["to"], td["to"]))
                if world_span(rid, d) != world_span(to, td):
                    bad.append("%s door %s: world span %s != %s's %s" % (rid, d["id"], world_span(rid, d), d["to"], world_span(to, td)))
ids = list(ALL)
for i in range(len(ids)):
    for j in range(i + 1, len(ids)):
        A, B = ALL[ids[i]], ALL[ids[j]]
        ax, ay = A["origin"]; aw, ah = A["size"]
        bx, by = B["origin"]; bw, bh = B["size"]
        if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
            bad.append("overlap %s %s" % (ids[i], ids[j]))


def cond(s, flags):
    if "of:" in s:
        k, fl = s.split("of:", 1)
        return sum(1 for f in fl.split(",") if f in flags) >= int(k)
    return s in flags


def room_for(rid, flags=(), closed=(), opts=None):
    m = ALL[rid]
    o = dict(opts or {})
    doors = []
    for d in m["doors"]:
        op = d["to"].split(":")[0] in ALL and d["id"] not in closed
        lk = d.get("lock", "")
        if lk == "oneway":
            op = False
        if lk.startswith("until:") and not cond(lk[6:], flags):
            op = False
        doors.append(dict(side=d["side"], a=d["a"], b=d["b"], open=op, id=d["id"]))
    o.setdefault("gears", m.get("gears", []))
    o.setdefault("pistons", [p for p in m.get("pistons", []) if p.get("busy")])
    if "boss:CRAWLER" in flags:
        o.setdefault("webs_off", True)
        o.setdefault("hooks_rings", True)
    return Room(FILES[rid], doors, o), doors


def check(rid, frm, ab, want, nowant=(), flags=(), opts=None, closed=(), label=""):
    rm, doors = room_for(rid, flags, closed, opts)
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


def reach_cells(rid, frm, ab, cells, flags=(), opts=None, label="", want=True):
    rm, doors = room_for(rid, flags, (), opts)
    d = [q for q in doors if q["id"] == frm][0]
    _, seen = explore(rm, ab, entry_state(rm, d["side"], d, ab))
    for (x, y) in cells:
        okc = any(abs(c - x) <= 4 and 0 <= (f // T) - 1 - y <= 3 for (c, f) in seen)
        good = okc == want
        print("%s %s %s cell (%d,%d) %r %s" % ("ok " if good else "BAD", rid, label, x, y, FILES[rid][y][x], "reachable" if okc else "not reachable"))
        if not good:
            bad.append("%s %s: cell (%d,%d) reachable=%s" % (rid, label, x, y, okc))


B = {"bash", "catch"}
BS = B | {"sudo"}
BA = B | {"agents"}
BC = B | {"curl"}
BX = B | {"ssh"}
ALLAB = B | {"sudo", "agents", "curl", "ssh"}
CR = ["boss:CRAWLER"]
FW = ["boss:FIREWALL"]

B = {"bash", "catch", "curl"}
BS = B | {"sudo"}
BP = B | {"breakpoint"}
JOIN2 = ["thread:0", "thread:1"]
SOLID_P = {"pistons_solid": True}

if __name__ == "__main__":
    for b in bad:
        print("STATIC", b)
    only = sys.argv[1:]

    def go(rid):
        return not only or rid in only
    if go("N11"):
        check("N11", "N11:E", B, ["N11:W"], label="to the tower")
    if go("T01"):
        check("T01", "T01:E", B, ["T01:W", "T01:N"])
        check("T01", "T01:W", B, ["T01:E", "T01:N"])
        check("T01", "T01:N", B, ["T01:E", "T01:W"], label="down from thread_2")
        reach_cells("T01", "T01:E", B, [(40, 12), (54, 8)], label="bench, tree")
    if go("T02"):
        check("T02", "T02:E", B, ["T02:N", "T02:N2"], ["T02:S"], label="lever not pulled")
        check("T02", "T02:N3", B, ["T02:E", "T02:N", "T02:N2"], label="from yield()")
        check("T02", "T02:E", B, ["T02:S"], flags=["lever:T02"], label="trapdoor")
        reach_cells("T02", "T02:E", B, [(35, 12)], label="lever")
    if go("TA1"):
        check("TA1", "TA1:S", B, ["TA1:N"])
        check("TA1", "TA1:N", B, ["TA1:S"])
    if go("TB1"):
        check("TB1", "TB1:S", B, ["TB1:N"], ["TB1:E"])
        check("TB1", "TB1:S", B, ["TB1:N", "TB1:E"], opts={"crack_open": True}, label="crack")
        check("TB1", "TB1:N", B, ["TB1:S"])
    if go("TC1"):
        check("TC1", "TC1:S", B, ["TC1:N"])
        check("TC1", "TC1:N", B, ["TC1:S"])
    if go("T15"):
        check("T15", "T15:W", B, ["T15:W"])
        reach_cells("T15", "T15:W", B, [(24, 10), (21, 10)], label="plugin, agent")
    if go("T04"):
        check("T04", "T04:S", B, ["T04:S2", "T04:S3", "T04:S4"], ["T04:N", "T04:N2"], label="not joined")
        check("T04", "T04:S", B, ["T04:N2"], ["T04:N"], flags=JOIN2, label="joined, no sudo")
        check("T04", "T04:S3", BS, ["T04:N", "T04:N2"], flags=JOIN2, label="joined, sudo")
        reach_cells("T04", "T04:S2", B, [(75, 12)], label="bench")
    if go("T17"):
        check("T17", "T17:N", B, ["T17:S"])
    if go("TA2"):
        check("TA2", "TA2:S", BS, ["TA2:N", "TA2:W"], label="sudo")
        check("TA2", "TA2:S", B, [], ["TA2:N"], label="no sudo")
        check("TA2", "TA2:N", BS, ["TA2:S"], label="down")
    if go("TB2"):
        check("TB2", "TB2:S", B, ["TB2:E", "TB2:N"], label="mutex open")
        check("TB2", "TB2:S", B, ["TB2:E"], ["TB2:N"], opts={"mutex_open": False}, label="mutex shut")
        check("TB2", "TB2:N", B, ["TB2:S", "TB2:E"], label="down")
        reach_cells("TB2", "TB2:S", B, [(3, 58)], opts={"mutex_open": False}, label="first key")
        reach_cells("TB2", "TB2:S", B, [(22, 43), (3, 28)], label="keys above their gates")
    if go("TC2"):
        check("TC2", "TC2:W", BP, ["TC2:N"], flags=["boss:RACE"], label="breakpoint")
        check("TC2", "TC2:W", B, [], ["TC2:N"], flags=["boss:RACE"], opts=SOLID_P, label="busy pistons")
        check("TC2", "TC2:N", BP, ["TC2:W"], flags=["boss:RACE"], label="down")
    if go("T06"):
        check("T06", "T06:W", B, ["T06:E"], flags=["boss:RACE"])
    if go("T14"):
        check("T14", "T14:E", B, ["T14:E"])
        reach_cells("T14", "T14:E", B, [(14, 6), (4, 10)], label="fragment, page")
    if go("T08"):
        check("T08", "T08:S", B, ["T08:E", "T08:S2"], ["T08:N"], opts={"cable_cut": False}, label="cable")
        check("T08", "T08:S2", B, ["T08:E", "T08:S", "T08:N"], opts={"cable_cut": True}, label="opus")
        check("T08", "T08:E", B, ["T08:S", "T08:S2"])
        reach_cells("T08", "T08:S", B, [(30, 14)], label="terminal")
    if go("T09"):
        check("T09", "T09:W", B, ["T09:E"])
        check("T09", "T09:S", BP, ["T09:W", "T09:E"], label="from semaphore")
        reach_cells("T09", "T09:W", B, [(46, 3)], label="break; key")
    if go("T10"):
        check("T10", "T10:W", B, ["T10:E"], flags=["boss:LOOP"])
    if go("T11"):
        check("T11", "T11:W", B, [], ["T11:S", "T11:E"], opts=SOLID_P, label="no opus, busy piston")
        check("T11", "T11:W", B, ["T11:S"], opts={"cable_cut": True, "pistons_solid": True}, label="opus")
        reach_cells("T11", "T11:W", BP, [(44, 10)], label="end door (breakpoint)")
        reach_cells("T11", "T11:W", B, [(44, 10)], opts=SOLID_P, label="end door (busy)", want=False)
    if go("T16"):
        check("T16", "T16:N", B, ["T16:S"])
    if go("T18"):
        check("T18", "T18:S", B, ["T18:S"], flags=["boss:DEADLOCK"])
    if go("H11"):
        check("H11", "H11:N", B, ["H11:E"], flags=["lever:T02"], label="down the trapdoor from async_await")
    print("\n%d problems" % len(bad))
    for b in bad:
        print(" -", b)
