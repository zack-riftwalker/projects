# Design checker for phase 4B-2 (THE NETWORK), Claude's tool: sizes, door cells, partner doors in world coordinates, no
# overlaps, and reachability with the movement simulator (sim.py: a close port of Player movement, plus curl and ssh as
# PLAN-metroidvania-phase4b2.md defines them) for each route the design needs. Reads godot/src/world (live) with
# docs/metroidvania/phase4b2-data laid over it, so it works before and after apply.py.
# Usage: python3 -I tools/godot/roomcheck/check4b2.py [room ids...]   (also runs from docs/metroidvania/phase4b2-data/)
import json, math, sys, os, copy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import Room, T
from reach import explore, entry_state

ROOT = HERE
while not os.path.exists(os.path.join(ROOT, "godot/src/world/rooms.json")):
    ROOT = os.path.dirname(ROOT)
LIVE = os.path.join(ROOT, "godot/src/world")
STAGE = os.path.join(ROOT, "docs/metroidvania/phase4b2-data")
OLD = json.load(open(os.path.join(LIVE, "rooms.json")))["rooms"]
STAGED = json.load(open(os.path.join(STAGE, "rooms-4b2.json")))
EDITS = json.load(open(os.path.join(STAGE, "room-edits-4b2.json")))
ALL = copy.deepcopy(OLD)
FILES = {}
for rid, m in OLD.items():
    FILES[rid] = open(os.path.join(LIVE, "rooms", m["file"])).read().split("\n")
for rid, e in EDITS.items():
    have = {d["id"] for d in ALL[rid]["doors"]}
    if all(d["id"] in have for d in e.get("doors_add", [])):
        continue                                   # apply.py already ran
    rows = [list(r) for r in FILES[rid]]
    for (x, y, txt) in e.get("cells", []):
        for i, ch in enumerate(txt):
            rows[y][x + i] = ch
    FILES[rid] = ["".join(r) for r in rows]
    ALL[rid]["doors"] += e.get("doors_add", [])
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
                if rows[y][x] not in " ;N.":
                    bad.append("%s door %s: edge cell (%d,%d) is %r" % (rid, d["id"], x, y, rows[y][x]))
            if b + 1 < h and rows[b + 1][x] not in "#=" and rows[b + 1][xin] not in "#=":
                bad.append("%s door %s: no floor under it at row %d" % (rid, d["id"], b + 1))
        else:
            y = 0 if s == "N" else h - 1
            for x in range(a, b + 1):
                if rows[y][x] not in " %!&.;":
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


def room_for(rid, flags=(), closed=(), opts=None):
    m = ALL[rid]
    o = dict(opts or {})
    doors = []
    for d in m["doors"]:
        op = d["to"].split(":")[0] in ALL and d["id"] not in closed
        lk = d.get("lock", "")
        if lk == "oneway":
            op = False
        if lk.startswith("until:") and lk[6:] not in flags:
            op = False
        doors.append(dict(side=d["side"], a=d["a"], b=d["b"], open=op, id=d["id"]))
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

if __name__ == "__main__":
    for b in bad:
        print("STATIC", b)
    only = sys.argv[1:]

    def go(rid):
        return not only or rid in only
    if go("N01"):
        check("N01", "N01:W", B, ["N01:E", "N01:S"])
        check("N01", "N01:E", B, ["N01:W", "N01:S"])
        check("N01", "N01:N", B, ["N01:W", "N01:E", "N01:S"], label="airgap landing")
        check("N01", "N01:S", B, ["N01:W", "N01:E"], label="up from the hub")
    if go("N04"):
        check("N04", "N04:W", B, ["N04:E"])
        check("N04", "N04:E", B, ["N04:W"])
        check("N04", "N04:N", B, ["N04:W", "N04:E"], label="airgap landing")
    if go("N05"):
        check("N05", "N05:W", B, ["N05:E", "N05:N", "N05:S"], label="dead code is walkable")
        check("N05", "N05:E", B, ["N05:W"])
        reach_cells("N05", "N05:W", B, [(71, 3), (88, 10)], label="backup ledge, catwalk")
        reach_cells("N05", "N05:W", B, [(53, 18)], label="the nook")
        check("N05", "N05:N", B, ["N05:W", "N05:E"], label="back from /backup")
        check("N05", "N05:S", B, ["N05:W", "N05:E"], label="back from 404")
    if go("N08"):
        check("N08", "N08:W", B, ["N08:W2"], ["N08:E"], label="climb")
        check("N08", "N08:W", BS, ["N08:W2"], ["N08:E"], label="climb sudo")
        check("N08", "N08:W", BC, ["N08:W2", "N08:E"], flags=CR, label="after boss, curl")
        check("N08", "N08:W", B, [], ["N08:E"], flags=CR, label="after boss, no curl")
        check("N08", "N08:E", B, ["N08:W", "N08:W2"], label="from token_ring")
        check("N08", "N08:W2", B, ["N08:W"], label="down from arena")
    if go("N09"):
        check("N09", "N09:E", B, ["N09:W"], flags=CR)
    if go("N10"):
        check("N10", "N10:E", B, [], ["N10:W"], label="no curl")
        check("N10", "N10:E", BC, ["N10:W"], label="curl")
        check("N10", "N10:W", BC, ["N10:E"], label="curl back")
        reach_cells("N10", "N10:E", BC, [(39, 6)], label="token shelf")
        reach_cells("N10", "N10:E", B, [(39, 6)], label="token shelf no curl", want=False)
    if go("N11"):
        check("N11", "N11:E", BC, ["N11:S2"], flags=CR, label="curl")
        reach_cells("N11", "N11:E", BC, [(4, 44)], flags=CR, label="end door (west ledge)")
        reach_cells("N11", "N11:E", B, [(4, 44)], flags=CR, label="no curl", want=False)
        reach_cells("N11", "N11:E", BS | {"curl"}, [(4, 44)], flags=CR, label="curl+sudo")
        check("N11", "N11:W", BC, ["N11:E"], flags=CR, closed=("N11:S1", "N11:S2", "N11:S3"), label="back east (no falling)")
    if go("N03"):
        check("N03", "N03:N", B, ["N03:S"])
        check("N03", "N03:S", B, ["N03:N"], label="up from N22")
        reach_cells("N03", "N03:S", B, [(2, 2)], label="bench")
    if go("N22"):
        check("N22", "N22:W", B, ["N22:E", "N22:N"])
        check("N22", "N22:E", B, ["N22:W", "N22:N"])
        check("N22", "N22:N", B, ["N22:W", "N22:E"])
    if go("N06"):
        check("N06", "N06:E", B, ["N06:S"])
        check("N06", "N06:S", B, ["N06:E"], label="up from ttl")
        reach_cells("N06", "N06:E", B, [(38, 8)], label="tree")
    if go("N07"):
        check("N07", "N07:N", B, ["N07:S"])
        check("N07", "N07:S", B, ["N07:N"], label="climb")
        check("N07", "N07:S", {"bash"}, ["N07:N"], label="climb bash only")
    if go("N02"):
        check("N02", "N02:W", B, ["N02:N"])
        check("N02", "N02:N", B, ["N02:W"])
        reach_cells("N02", "N02:N", B, [(4, 12)], label="lever")
    if go("N12"):
        check("N12", "N12:W", B, ["N12:E"])
        check("N12", "N12:E", B, ["N12:W"])
        check("N12", "N12:W", B, [], ["N12:E"], opts={"ports_open": False}, label="ports shut, no packets")
    if go("N13"):
        check("N13", "N13:W", B, ["N13:E"], ["N13:S"])
        check("N13", "N13:E", B, ["N13:W"])
        check("N13", "N13:W", B, ["N13:S"], opts={"crack_open": True}, label="crack broken")
        reach_cells("N13", "N13:W", B, [(70, 8)], label="ssh vista", want=False)
        reach_cells("N13", "N13:W", BX, [(70, 8)], label="ssh vista")
    if go("N21"):
        check("N21", "N21:N", B, ["N21:N"], flags=["wave:N21"])
        reach_cells("N21", "N21:N", B, [(40, 12)], label="plugin")
    if go("N14"):
        check("N14", "N14:W", B, ["N14:E"], ["N14:N"])
        check("N14", "N14:W", BX, ["N14:E", "N14:N"], label="ssh")
        check("N14", "N14:N", B, ["N14:N"], ["N14:W", "N14:E"], label="down from token_ring, no ssh")
        check("N14", "N14:N", BX, ["N14:W", "N14:E", "N14:N"], label="down from token_ring, ssh")
    if go("N15"):
        check("N15", "N15:W", B, ["N15:E"], flags=FW)
    if go("N16"):
        check("N16", "N16:W", B, [], ["N16:E"], label="no ssh")
        check("N16", "N16:W", BX, ["N16:E"], label="ssh")
        check("N16", "N16:E", BX, ["N16:W"], label="ssh back")
    if go("N17"):
        check("N17", "N17:W", B, ["N17:W"], label="down and back up")
        reach_cells("N17", "N17:W", B, [(20, 80), (21, 36)], label="end door, no-handle sign")
        check("N17", "N17:W", BX, ["N17:W"], label="ssh")
    if go("N18"):
        check("N18", "N18:W", B, ["N18:S", "N18:W"], label="down")
        check("N18", "N18:S", B, ["N18:W"], label="up from dmz")
        reach_cells("N18", "N18:S", B, [(16, 17)], label="token ledge")
    if go("N19"):
        check("N19", "N19:S", B, ["N19:S"])
        reach_cells("N19", "N19:S", B, [(26, 11), (5, 11), (16, 11)], label="fragment, page, sign")
    if go("N20"):
        check("N20", "N20:N", B, ["N20:N"])
        reach_cells("N20", "N20:N", B, [(24, 11)], label="agent")
    if go("H11"):
        check("H11", "H11:N2", BS, ["H11:E"], flags=["hatch:H10N"], label="airgap landing")
        check("H11", "H11:N2", B, ["H11:E"], label="airgap landing, no sudo")
    if go("H01"):
        check("H01", "H01:W", B | {"curl"}, ["H01:N"], label="curl ring (no sudo)")
        check("H01", "H01:W", BS, [], ["H01:N"], label="no curl")
    if go("H12"):
        check("H12", "H12:S", B | {"ssh"}, ["H12:E"], label="ssh to memory_pool")
    if go("H16"):
        check("H16", "H16:W", B | {"ssh"}, ["H16:W"], label="ssh back")
    if go("H03"):
        check("H03", "H03:E3", BS | {"ssh"}, ["H03:SW"], label="ssh to D03 (flood 0)")
    if go("D03"):
        check("D03", "D03:W", B | {"ssh"}, ["D03:E2"], opts={"crack_open": True}, label="ssh to the HEAP")
    if go("D07"):
        check("D07", "D07:E", B, ["D07:W"], label="from loopback")
    print("\n%d problems" % len(bad))
    for b in bad:
        print(" -", b)
