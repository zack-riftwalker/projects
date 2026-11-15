#!/usr/bin/env python3
# Design checker for phase 5B (GIT HISTORY), the world department's tool: sizes, door cells, partner doors in world
# coordinates, no overlaps, and reachability with the movement simulator (tools/godot/roomcheck/sim.py, reach.py).
# Reads godot/src/world (live) with docs/metroidvania/phase5b-data laid over it (rooms-5b.json, rooms/, room-edits-5b.json).
# New letters are mapped before the simulator sees them: checkout blocks 6 7 8 by the room's revision, package-lock `_`
# solid (open with --force), plates' gates `4` through the simulator's mutex option (open = a body or a marker holds them).
# Usage: python3 -I docs/metroidvania/phase5b-data/check5b.py [room ids...]
import json, sys, os, copy
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools/godot/roomcheck"))
from sim import Room, T
from reach import explore, entry_state

LIVE = os.path.join(ROOT, "godot/src/world")
OLD = json.load(open(os.path.join(LIVE, "rooms.json")))["rooms"]
STAGED = json.load(open(os.path.join(HERE, "rooms-5b.json")))
EDITS = json.load(open(os.path.join(HERE, "room-edits-5b.json")))
ALL = copy.deepcopy(OLD)
FILES = {rid: open(os.path.join(LIVE, "rooms", m["file"])).read().split("\n") for rid, m in OLD.items()}
for rid, e in EDITS.items():
    rows = [list(r) for r in FILES[rid]]
    for (x, y, txt) in e.get("cells", []):
        for i, ch in enumerate(txt):
            rows[y][x + i] = ch
    FILES[rid] = ["".join(r) for r in rows]
    for k in e.get("del", []):
        ALL[rid].pop(k, None)
for rid, meta in STAGED.items():
    ALL[rid] = meta
    FILES[rid] = open(os.path.join(HERE, "rooms", meta["file"])).read().split("\n")
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
                if rows[y][x] not in " %!&.;8_":
                    bad.append("%s door %s: edge cell (%d,%d) is %r" % (rid, d["id"], x, y, rows[y][x]))
        to = d["to"].split(":")[0]
        if to in ALL:
            td = [q for q in ALL[to]["doors"] if q["id"] == d["to"]]
            if not td:
                bad.append("%s door %s: target door %s missing" % (rid, d["id"], d["to"]))
                continue
            td = td[0]
            if td["to"] != d["id"]:
                bad.append("%s door %s: target %s points back to %s" % (rid, d["id"], d["to"], td["to"]))
            if not d.get("symlink") and world_span(rid, d) != world_span(to, td):
                bad.append("%s door %s: world span %s != %s's %s" % (rid, d["id"], world_span(rid, d), d["to"], world_span(to, td)))
ids = [i for i in ALL if not ALL[i].get("lab")]
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


def rows_for(rid, rev=None, force=False):
    co = ALL[rid].get("checkout")
    rev = rev or (co["start"] if co else None)
    out = []
    for r in FILES[rid]:
        q = []
        for ch in r:
            if co and ch in co["solid"]:
                ch = "#" if rev in co["solid"][ch] else " "
            elif ch == "_":
                ch = " " if force else "#"
            q.append(ch)
        out.append("".join(q))
    return out


def room_for(rid, flags=(), opts=None, rev=None, force=False):
    m = ALL[rid]
    doors = []
    for d in m["doors"]:
        op = d["to"].split(":")[0] in ALL
        lk = d.get("lock", "")
        if lk == "oneway" or (lk.startswith("until:") and not cond(lk[6:], flags)):
            op = False
        doors.append(dict(side=d["side"], a=d["a"], b=d["b"], open=op, id=d["id"]))
    return Room(rows_for(rid, rev, force), doors, dict(opts or {})), doors


def check(rid, frm, ab, want, nowant=(), flags=(), opts=None, rev=None, force=False, label=""):
    rm, doors = room_for(rid, flags, opts, rev, force)
    d = [q for q in doors if q["id"] == frm][0]
    dd, seen = explore(rm, ab, entry_state(rm, d["side"], d, ab))
    got = {[q["id"] for q in doors if q["side"] == s and q["a"] == a][0] for (s, a) in dd}
    miss = [x for x in want if x not in got]
    extra = [x for x in nowant if x in got]
    print("%s %s %s from %s %s%s: reached %s%s%s" % ("ok " if not miss and not extra else "BAD", rid, label, frm, sorted(ab),
                                                 " rev " + rev if rev else "", sorted(got), " MISSING %s" % miss if miss else "",
                                                 " SHOULD NOT %s" % extra if extra else ""))
    if miss or extra:
        bad.append("%s %s from %s: missing %s, unwanted %s" % (rid, label, frm, miss, extra))


def reach_cells(rid, frm, ab, cells, flags=(), opts=None, rev=None, label="", want=True):
    rm, doors = room_for(rid, flags, opts, rev)
    d = [q for q in doors if q["id"] == frm][0]
    _, seen = explore(rm, ab, entry_state(rm, d["side"], d, ab))
    for (x, y) in cells:
        okc = any(abs(c - x) <= 4 and 0 <= (f // T) - 1 - y <= 3 for (c, f) in seen)
        print("%s %s %s cell (%d,%d) %s" % ("ok " if okc == want else "BAD", rid, label, x, y, "reachable" if okc else "not reachable"))
        if okc != want:
            bad.append("%s %s: cell (%d,%d) reachable=%s" % (rid, label, x, y, okc))


G = {"bash", "catch", "ssh"}                 # what every player has in GIT for sure (N17 needs ssh)
CRACK = {"crack_open": True}
SHUT = {"mutex_open": False}                 # no body and no marker on the plates
KEYS = ["branch:a", "branch:b"]

if __name__ == "__main__":
    for b in bad:
        print("STATIC", b)
    only = sys.argv[1:]

    def go(rid):
        return not only or rid in only
    if go("N17"):
        check("N17", "N17:W", G, ["N17:S"], label="down to .git", flags=["rst:N17"])
        check("N17", "N17:S", G, ["N17:W"], label="back up from HEAD", flags=["rst:N17"])
    if go("G01"):
        check("G01", "G01:N", G, ["G01:W"])
        check("G01", "G01:W", G, ["G01:N"], label="back up to 22/tcp")
        reach_cells("G01", "G01:W", G, [(8, 12)], label="bench")
    if go("G02"):
        check("G02", "G02:E", G, ["G02:W"], ["G02:S"])
        check("G02", "G02:W", G, ["G02:E"], label="up the stairs")
        check("G02", "G02:E", G, ["G02:S"], opts=CRACK, label="crack")
        check("G02", "G02:S", G, ["G02:W", "G02:E"], opts=CRACK, label="up from old/")
        reach_cells("G02", "G02:E", G, [(105, 8)], label="tree")
        reach_cells("G02", "G02:E", G, [(6, 1)], label="black agent (out of reach)", want=False)
    if go("G16"):
        check("G16", "G16:N", G, ["G16:E"])
        check("G16", "G16:E", G, ["G16:N"], label="back up")
        reach_cells("G16", "G16:N", G, [(30, 20), (24, 20)], label="plugin, page")
    if go("G03"):
        for frm in ("G03:E", "G03:W", "G03:S"):
            check("G03", frm, G, [x for x in ("G03:E", "G03:W", "G03:S") if x != frm])
        reach_cells("G03", "G03:E", G, [(30, 20)], label="terminal")
    if go("G04"):
        check("G04", "G04:E", G, [], ["G04:S"], rev="b01", label="detached: the - wall")
        check("G04", "G04:E", G, [], ["G04:S"], rev="b02", label="no bridge")
        check("G04", "G04:E", G, ["G04:S"], rev="b03", label="HEAD")
        check("G04", "G04:S", G, ["G04:E"], rev="b03", label="up from checkout")
        check("G04", "G04:S", G, ["G04:N"], flags=["checkout:G04:b02"], rev="b02", label="stash")
        check("G04", "G04:S", G, [], ["G04:N"], rev="b03", label="stash shut at HEAD")
        reach_cells("G04", "G04:E", G, [(75, 12)], rev="b01", label="lever east")
        reach_cells("G04", "G04:S", G, [(22, 12)], rev="b03", label="lever west")
    if go("G05"):
        check("G05", "G05:S", G, ["G05:S"])
        reach_cells("G05", "G05:S", G, [(26, 11), (20, 11)], label="plugin, agent")
    if go("G09"):
        check("G09", "G09:N", G, [], ["G09:E"], rev="a", label="+ floor shut")
        reach_cells("G09", "G09:N", G, [(3, 27)], rev="a", label="lever on the + floor")
        check("G09", "G09:N", G, ["G09:E"], rev="b", label="down")
        reach_cells("G09", "G09:N", G, [(14, 54)], rev="b", label="key A")
        check("G09", "G09:E", G, ["G09:N"], rev="b", label="back up the - ladder")
        check("G09", "G09:E", G, [], ["G09:N"], rev="a", label="no - ladder")
        reach_cells("G09", "G09:E", G, [(5, 54)], rev="a", label="bottom lever")
    if go("G06"):
        check("G06", "G06:N", G, ["G06:E"])
        check("G06", "G06:E", G, ["G06:N"])
    if go("G07"):
        check("G07", "G07:W", G, ["G07:S"])
        check("G07", "G07:S", G, ["G07:W"], label="back up the bisect")
        reach_cells("G07", "G07:W", G, [(29, 39)], label="key B")
    if go("G10"):
        check("G10", "G10:W", G, ["G10:N"], ["G10:S"])
        check("G10", "G10:N", G, ["G10:W"])
        check("G10", "G10:S", G, ["G10:W", "G10:N"], flags=["lever:reflog"], label="up from reflog")
    if go("G08"):
        check("G08", "G08:W", G, ["G08:E"], ["G08:S"], label="no keys")
        check("G08", "G08:E", G, ["G08:W"], ["G08:S"], label="no keys")
        check("G08", "G08:W", G, ["G08:S", "G08:E"], flags=KEYS, label="merged")
        check("G08", "G08:S", G, ["G08:W", "G08:E"], flags=KEYS, label="up from the bench")
    if go("G11"):
        check("G11", "G11:N", G, ["G11:E"])
        check("G11", "G11:E", G, ["G11:N"])
        reach_cells("G11", "G11:N", G, [(8, 12)], label="bench")
    if go("G12"):
        check("G12", "G12:W", G, ["G12:E"], flags=["boss:REGRESSION"])
    if go("G13"):
        check("G13", "G13:W", G, [], ["G13:E", "G13:N"], opts=SHUT, flags=["lever:reflog"], label="plate empty")
        check("G13", "G13:W", G, ["G13:E"], ["G13:N"], label="marker on the plate")
        check("G13", "G13:W", G, ["G13:E", "G13:N"], flags=["lever:reflog"], label="reflog lever pulled")
        check("G13", "G13:E", G, ["G13:W", "G13:N"], flags=["lever:reflog"], label="back (gate latched)")
        check("G13", "G13:N", G, ["G13:W", "G13:E"], flags=["lever:reflog"], label="down the hatch")
        reach_cells("G13", "G13:W", G, [(31, 14), (23, 14)], label="levers")
    if go("G14"):
        reach_cells("G14", "G14:W", G, [(182, 14)], label="end door, plates held")
        reach_cells("G14", "G14:W", G, [(182, 14)], opts=SHUT, label="end door, plates empty", want=False)
        check("G14", "G14:W", G, [], ["G14:S"], label="package-lock shut")
        check("G14", "G14:W", G | {"force"}, ["G14:S"], force=True, label="--force")
        check("G14", "G14:S", G, ["G14:W"], force=True, label="up from initial_commit")
    if go("G15"):
        check("G15", "G15:N", G, ["G15:N"])
        reach_cells("G15", "G15:N", G, [(22, 12), (31, 12), (35, 12)], label="Panel F, fragment")
    print("\n%d problems" % len(bad))
    for b in bad:
        print(" -", b)
