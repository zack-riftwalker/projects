#!/usr/bin/env python3
"""GIT HISTORY (phase 5B) room drafts, drawn in code: writes rooms/G*.txt and rooms-5b.json.
Design: docs/metroidvania/19-git-history.md (world department proposal, not approved yet).
Run from anywhere: python3 -I docs/metroidvania/phase5b-data/rooms.py

New letters (the build gives them meaning; the checker treats them as below):
  6  checkout block `+` (green)   solid in the revisions listed in the room's "checkout" data
  7  checkout block `-` (red)     solid in the revisions listed in the room's "checkout" data
  8  stash plug (G04 ceiling)     solid except at revision b02
  9  branch key (pickup, sets the room's "key" flag)
  _  package-lock floor           solid until --force (not in the game yet)
  <  POLYMORPHIC   >  STASH       enemies (new)
Reused: `4` gate + `Q` key look = a revert plate (open while a body or a revert marker stands on the plate; "plates" data),
`~` crumble bridge (grows back after 2.6 s, as built), `I` lever, `C` bench, `T` sign, `U` plugin, `*` memory fragment, `H` chest,
`o` token, `D` end door, `B` boss spawn, `Z` ZOMBIE PROCESS, `b`/`a`/`t` Bug v0.1 and Typo (old SOURCE TREE enemies, sepia)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from canvas import C

ROOMS = {}
META = {}


def door(c, side, a, b):            # opens the edge cells; a gate drawn there (crack, firewall, plug) stays
    for i in range(a, b + 1):
        x, y = {"W": (0, i), "E": (c.w - 1, i), "N": (i, 0), "S": (i, c.h - 1)}[side]
        if c.g[y][x] == "#":
            c.g[y][x] = " "


def plat(c, y, x0, x1, ch="="):
    return c.rect(x0, y, x1, y, ch)


def room(rid, title, size, origin, doors, c, **meta):
    w, h = size
    assert (c.w, c.h) == (w, h), rid
    for d in doors:
        door(c, d["side"], d["a"], d["b"])
    ROOMS[rid] = c.rows()
    m = {"file": rid + ".txt", "title": title, "size": [w, h], "origin": origin, "world": 7, "music": "w7", "zone": "git"}
    m.update(meta)
    m["doors"] = doors
    META[rid] = m


def D(rid, side, a, b, to, **kw):
    d = {"id": "%s:%s" % (rid, side), "side": side, "a": a, "b": b, "to": to}
    d.update(kw)
    return d


# ---------------------------------------------------------------- G01 HEAD (entry, bench) 48x16
c = C(48, 16).box(top=1, bottom=3)
plat(c, 10, 18, 23); plat(c, 7, 30, 35); plat(c, 4, 23, 30)      # back up to N17
c.put(8, 12, "C").put(14, 12, "T").put(40, 12, "T")
room("G01", "HEAD", (48, 16), [1540, 76], [D("G01", "N", 26, 29, "N17:S"), D("G01", "W", 9, 12, "G02:E")], c,
     signs=["HEAD -> main. Everything that ever was is still down here.",
            "rollback machinery: out of order. (needs revert)"],
     landmarks=["rollback"])

# ---------------------------------------------------------------- G02 git_log (the night's commits, tree) 140x24
c = C(140, 24).box(top=1, bottom=1)
c.rect(132, 9, 138, 22, "#")                                   # the newest commit under the E door
x, y = 131, 9
steps = []
while y < 21:                                                   # commit stones down to the west, 2 rows a step
    y += 2
    x0 = x - 9
    c.rect(x0, y, x, 22, "#")
    steps.append((x0, y))
    x = x0 - 1
c.rect(1, 23, 138, 23, "#")                                     # west of the stairs: the floor (W door)
c.rect(20, 23, 23, 23, "%")                                    # a cracked floor: sepia light (bash) to G16
plat(c, 12, 96, 100); plat(c, 9, 103, 108)                      # a side commit for `tree`
plat(c, 2, 4, 9)                                                # the top commit nobody reaches (the black agent)
sx = [s for s in steps]
for k, (x0, yy) in enumerate(sx[:6]):
    c.put(x0 + 3, yy - 1, "T")
c.put(28, 22, "b").put(steps[3][0] + 4, steps[3][1] - 1, "b").put(steps[1][0] + 4, steps[1][1] - 1, "t")
room("G02", "git_log", (140, 24), [1400, 80],
     [D("G02", "E", 5, 8, "G01:W"), D("G02", "S", 20, 23, "G16:N"), D("G02", "W", 19, 22, "G03:E")], c,
     signs=["log: your night, one commit per stone. (S6: the text comes from the flags)",
            "fix: NULL pointer dereference -- Clawd, 02:51",
            "b02: add stash door",
            "b03: remove stash door (oops)",
            "# TODO: an optional review you skipped",
            "Co-authored-by: Clawd #2"],
     npc=[{"kind": "tree", "x": 105, "y": 8, "zone": "git", "price": 40}],
     decor=[{"kind": "shadow", "x": 6, "y": 1, "flag": "shadow:git"}],
     variants={"b": "v0.1", "t": "v0.1"})

# ---------------------------------------------------------------- G16 old/hello_world.py (secret, symlink home) 46x24
c = C(46, 24).box(top=1, bottom=3)
for (yy, x0, x1) in [(18, 22, 27), (15, 12, 17), (12, 20, 25), (9, 11, 16), (6, 18, 23), (3, 14, 20)]:
    plat(c, yy, x0, x1)
c.put(5, 20, "T").put(30, 20, "U").put(38, 20, "T")
room("G16", "old/hello_world.py", (46, 24), [1404, 104],
     [D("G16", "N", 16, 19, "G02:S"), D("G16", "E", 17, 20, "R06:W", symlink=True, sets="link:src")], c,
     secret=True, plugins=["blame"], pages=[[24, 20, 4]],
     signs=["hello_world.py, three commits ago. // TODO: add a boss",
            "ln -s ../../src : the way home, if you remember it."],
     decor=[{"kind": "cursor", "x": 9, "y": 20}, {"kind": "cursor", "x": 11, "y": 20}])

# ---------------------------------------------------------------- G03 branch (hub, terminal) 40x40
c = C(40, 40).box(top=1, bottom=1)
c.rect(30, 7, 38, 8, "#")                                      # the ledge under the E door
c.rect(1, 21, 12, 22, "#").rect(22, 21, 38, 22, "#")          # the middle floor (W door), hole 13-21 down
for (yy, x0, x1) in [(18, 24, 29), (15, 17, 22), (12, 23, 28), (10, 26, 29)]:
    plat(c, yy, x0, x1)
for (yy, x0, x1) in [(36, 20, 24), (33, 12, 16), (30, 19, 23), (27, 12, 16), (24, 15, 20)]:
    plat(c, yy, x0, x1)
c.put(30, 20, "C").put(6, 20, "T").put(34, 20, "T")
room("G03", "branch", (40, 40), [1360, 96],
     [D("G03", "E", 3, 6, "G02:W"), D("G03", "W", 17, 20, "G04:E"), D("G03", "S", 16, 19, "G06:N")], c,
     terminal=True,
     signs=["feature/a <- west.  feature/b: down.  merge needs both.",
            "git graph: a branch turns green when its key is found."],
     decor=[{"kind": "graph", "x": 4, "y": 4, "w": 22, "h": 12}])

# ---------------------------------------------------------------- G04 feature/a (checkout lever, stash door) 90x20
c = C(90, 20).box(top=1, bottom=1)
c.rect(1, 13, 88, 18, "#")
c.rect(10, 13, 13, 18, " ")                                     # the shaft down to G09
c.rect(0, 9, 1, 12, "N")                                        # firewall brick to vendor/ (ssh)
c.rect(40, 13, 60, 18, " ").rect(40, 18, 60, 18, "^")           # the pit
c.rect(42, 13, 58, 13, "6")                                     # + bridge (HEAD)
c.rect(30, 6, 30, 12, "7")                                      # - wall (b01)
c.rect(10, 1, 13, 1, "8")                                       # the stash plug (open at b02)
for (yy, x0, x1) in [(10, 15, 19), (7, 6, 10), (4, 13, 17)]:
    plat(c, yy, x0, x1)
c.put(75, 12, "I").put(22, 12, "I").put(72, 12, "T").put(25, 12, "T").put(84, 12, "T")
c.put(66, 12, "Z").put(35, 12, "Z")
room("G04", "feature/a", (90, 20), [1270, 104],
     [D("G04", "E", 9, 12, "G03:W"), D("G04", "N", 10, 13, "G05:S", lock="until:checkout:G04:b02"),
      D("G04", "S", 10, 13, "G09:N"), D("G04", "W", 9, 12, "X12:E")], c,
     checkout={"start": "b01", "order": ["b01", "b02", "b03"], "solid": {"6": ["b03"], "7": ["b01"], "8": ["b01", "b03"]}},
     signs=["You are in 'detached HEAD' state. git checkout <rev>: pull the lever.",
            "git stash list: 1 entry",
            "feature/a: three revisions of one room. HEAD is the newest."])

# ---------------------------------------------------------------- G05 stash@{0} (secret) 40x14
c = C(40, 14).box(top=1, bottom=2)
c.rect(10, 12, 13, 13, " ")
c.put(26, 11, "U").put(32, 11, "H").put(5, 11, "T")
room("G05", "stash@{0}", (40, 14), [1270, 90], [D("G05", "S", 10, 13, "G04:N")], c,
     secret=True, plugins=["nohup"], agents=[[20, 11]],
     signs=["stash@{0}: WIP on feature/a. Somebody meant to come back."])

# ---------------------------------------------------------------- G09 checkout (shaft, key A) 30x60
c = C(30, 60).box(top=1, bottom=5)
for (yy, x0, x1) in [(25, 5, 10), (22, 13, 18), (19, 5, 10), (16, 13, 18), (13, 5, 10), (10, 13, 18), (7, 5, 10), (4, 9, 14)]:
    plat(c, yy, x0, x1)
c.rect(1, 28, 5, 28, "#")                                       # the lever ledge (always there)
c.rect(6, 28, 28, 28, "6")                                      # + floor: the way down is shut in state a
for (yy, x0, x1) in [(52, 20, 25), (49, 12, 17), (46, 20, 25), (43, 12, 17), (40, 20, 25), (37, 12, 17),
                     (34, 5, 10), (31, 6, 11)]:
    plat(c, yy, x0, x1, "7")                                    # - ladder: there in state b
c.put(3, 27, "I").put(5, 54, "I").put(8, 27, "T").put(14, 54, "9")
c.put(22, 54, "b").put(18, 44, "a")
room("G09", "checkout", (30, 60), [1270, 124], [D("G09", "N", 10, 13, "G04:S"), D("G09", "E", 51, 54, "G08:W")], c,
     checkout={"start": "a", "order": ["a", "b"], "solid": {"6": ["a"], "7": ["b"]}}, key="branch:a",
     signs=["checkout: + is the way down, - is the way back up."])

# ---------------------------------------------------------------- G06 feature/b (old enemies) 90x20
c = C(90, 20).box(top=1, bottom=1)
c.rect(1, 13, 88, 18, "#")
c.rect(34, 13, 37, 18, " ").rect(34, 18, 37, 18, "^")
c.rect(60, 13, 64, 18, " ").rect(60, 18, 64, 18, "^")
for (yy, x0, x1) in [(10, 20, 24), (7, 12, 16), (4, 15, 20)]:
    plat(c, yy, x0, x1)
plat(c, 9, 46, 52)
c.put(8, 12, "T").put(28, 12, "Z").put(44, 12, "b").put(50, 12, "t").put(70, 12, "Z").put(78, 12, "b").put(49, 8, "o")
room("G06", "feature/b", (90, 20), [1360, 136], [D("G06", "N", 16, 19, "G03:S"), D("G06", "E", 9, 12, "G07:W")], c,
     signs=["feature/b: old code, old bugs. They were never really fixed."], variants={"b": "v0.1", "t": "v0.1"})

# ---------------------------------------------------------------- G07 bisect (key B) 64x48
c = C(64, 48).box(top=1, bottom=1)
c.rect(1, 21, 62, 22, "#")                                      # level 1
c.rect(20, 21, 23, 22, " ").rect(40, 21, 43, 22, " ")
c.rect(17, 23, 17, 27, "#").rect(26, 23, 26, 27, "#").rect(17, 27, 26, 27, "#")   # wrong pit 1
plat(c, 24, 19, 22)
c.rect(1, 31, 62, 32, "#")                                      # level 2
c.rect(12, 31, 15, 32, " ").rect(50, 31, 53, 32, " ")
c.rect(47, 33, 47, 37, "#").rect(56, 33, 56, 37, "#").rect(47, 37, 56, 37, "#")   # wrong pit 2
plat(c, 34, 49, 52)
plat(c, 29, 37, 40); plat(c, 26, 42, 45); plat(c, 23, 39, 42)   # back up to level 1
c.rect(1, 40, 62, 41, "#")                                      # level 3
c.rect(30, 40, 33, 41, " ").rect(46, 40, 49, 41, " ")
c.rect(43, 42, 43, 45, "#").rect(52, 42, 52, 45, "#").rect(43, 45, 52, 45, "#")   # wrong pit 3
plat(c, 43, 45, 48)
plat(c, 37, 9, 12); plat(c, 34, 14, 17)                         # back up to level 2
c.rect(29, 42, 29, 46, "#").rect(34, 42, 34, 46, "#")           # the shaft to G10
plat(c, 45, 30, 33); plat(c, 42, 30, 33)
c.put(29, 39, "9")
for (x0, yy) in [(5, 20), (18, 20), (38, 20), (10, 30), (48, 30), (26, 39), (44, 39)]:
    c.put(x0, yy, "T")
c.put(8, 30, ">").put(58, 39, "<").put(55, 20, ">")
room("G07", "bisect", (64, 48), [1450, 128], [D("G07", "W", 17, 20, "G06:E"), D("G07", "S", 30, 33, "G10:N")], c,
     key="branch:b",
     signs=["git bisect start. Fall through the good half; the first bad commit holds the key.",
            "bad: tests fail below", "good: tests pass below",
            "good: tests pass below", "bad: tests fail below",
            "found it: a1b2c3d is the first bad commit. Take it down.", "bad: tests fail below"])

# ---------------------------------------------------------------- G10 cherry-pick (corridor; reflog hatch below) 154x16
c = C(154, 16).box(top=1, bottom=1)
c.rect(1, 13, 152, 14, "#")
c.rect(1, 9, 6, 12, "#")                                        # the ledge under the W door
plat(c, 11, 7, 10)
c.rect(34, 13, 37, 14, " ")                                     # the reflog hatch shaft (to G13)
c.rect(60, 13, 63, 14, " ").rect(60, 14, 63, 14, "^")
c.rect(95, 13, 99, 14, " ").rect(95, 14, 99, 14, "^")
for (yy, x0, x1) in [(10, 112, 117), (7, 124, 129), (4, 117, 122)]:
    plat(c, yy, x0, x1)
c.put(80, 12, "H").put(20, 12, "T").put(70, 12, "<").put(105, 12, ">").put(140, 12, "<")
room("G10", "cherry-pick", (154, 16), [1360, 176],
     [D("G10", "W", 5, 8, "G08:E"), D("G10", "N", 120, 123, "G07:S"), D("G10", "S", 34, 37, "G13:N", lock="until:lever:reflog")], c,
     signs=["cherry-pick: take only the commit you want."])

# ---------------------------------------------------------------- G08 merge (two keys) 60x24
c = C(60, 24).box(top=1, bottom=4)
c.rect(1, 9, 14, 19, "#")                                       # W ledge
c.rect(40, 15, 58, 19, "#")                                     # E floor
c.rect(16, 20, 19, 23, " ")                                     # the merge hatch (both keys)
for (yy, x0, x1) in [(17, 15, 19), (14, 20, 24), (11, 15, 19)]:
    plat(c, yy, x0, x1)
plat(c, 18, 34, 39)
c.put(26, 19, "T").put(30, 19, "T").put(36, 19, "T")
room("G08", "merge", (60, 24), [1300, 170],
     [D("G08", "W", 5, 8, "G09:E"), D("G08", "E", 11, 14, "G10:W"), D("G08", "S", 16, 19, "G11:N", lock="until:2of:branch:a,branch:b")], c,
     signs=["merge: two keys, two branches, one way down.",
            {"text": "CONFLICT: waiting for feature/a and feature/b", "alt": [{"if": "branch:a", "text": "waiting for feature/b"}]},
            "Merge branch 'feature/b'"],
     decor=[{"kind": "pedestal", "x": 24, "y": 19, "flag": "branch:a"}, {"kind": "pedestal", "x": 34, "y": 19, "flag": "branch:b"}])

# ---------------------------------------------------------------- G11 regression_test (bench, mirror) 40x16
c = C(40, 16).box(top=1, bottom=3)
for (yy, x0, x1) in [(10, 20, 24), (7, 12, 16), (4, 15, 20)]:
    plat(c, yy, x0, x1)
c.put(8, 12, "C").put(30, 12, "T")
room("G11", "regression_test", (40, 16), [1300, 194], [D("G11", "N", 16, 19, "G08:S"), D("G11", "E", 9, 12, "G12:W", lock="fight")], c,
     signs=["regression_test: everything passed yesterday."],
     decor=[{"kind": "mirror", "x": 33, "y": 8, "w": 4, "h": 5}])

# ---------------------------------------------------------------- G12 REGRESSION (arena placeholder; boss-design draws it) 24x14
c = C(24, 14).box(top=1, bottom=3)
c.put(12, 10, "B")
room("G12", "REGRESSION", (24, 14), [1340, 196], [D("G12", "W", 7, 10, "G11:E", lock="fight"), D("G12", "E", 7, 10, "G13:W", lock="until:boss:REGRESSION")], c,
     signs=[])

# ---------------------------------------------------------------- G13 reflog (revert tutorial) 60x20
c = C(60, 20).box(top=1, bottom=1)
c.rect(1, 15, 58, 18, "#")
c.rect(20, 1, 20, 14, "4")                                      # gate held by the plate at (8, 14)
for (yy, x0, x1) in [(12, 26, 29), (9, 33, 36), (6, 26, 29), (3, 30, 34)]:
    plat(c, yy, x0, x1)
c.rect(42, 14, 52, 18, " ").rect(42, 18, 52, 18, "^")
c.rect(38, 14, 41, 14, "#")
c.rect(42, 14, 52, 14, "~")                                     # crumble bridge
c.rect(53, 11, 58, 18, "#")
c.put(8, 14, "Q").put(23, 14, "I").put(31, 14, "I").put(4, 14, "T").put(26, 14, "T").put(36, 14, "T")
room("G13", "reflog", (60, 20), [1364, 192],
     [D("G13", "W", 11, 14, "G12:E"), D("G13", "E", 7, 10, "G14:W"), D("G13", "N", 30, 33, "G10:S", lock="until:lever:reflog")], c,
     plates=[{"key": [8, 14], "cols": [20], "latch": [23, 14]}],
     signs=["revert: [down]+[special] drops a marker. [special] takes you back to it.",
            "the plate holds the gate while something stands on it. A marker counts.",
            "git reflog: every place HEAD has been. The lever opens a way back up."])

# ---------------------------------------------------------------- G14 revert.sh (final puzzle) 188x20
c = C(188, 20).box(top=1, bottom=1)
c.rect(1, 11, 30, 18, "#")
c.rect(31, 13, 186, 18, "#")
plat(c, 12, 30, 31, "#")
c.rect(46, 13, 49, 18, " ").rect(46, 13, 49, 13, "_")          # package-lock floor over the G15 shaft (--force)
c.rect(60, 13, 76, 18, " ").rect(60, 18, 76, 18, "^").rect(60, 13, 76, 13, "~")    # bridge 1
c.rect(80, 1, 80, 12, "4")                                      # gate 1 (plate at 55)
c.rect(100, 13, 118, 18, " ").rect(100, 18, 118, 18, "^").rect(100, 13, 118, 13, "~")  # bridge 2
c.rect(130, 1, 130, 12, "4")                                    # gate 2 (plate at 94)
c.rect(140, 13, 158, 18, " ").rect(140, 18, 158, 18, "^").rect(140, 13, 158, 13, "~")  # bridge 3
c.rect(170, 1, 170, 12, "4")                                    # gate 3 (plate at 135)
c.rect(171, 13, 186, 14, " ")
c.put(55, 12, "Q").put(94, 12, "Q").put(135, 12, "Q")
c.put(84, 12, "I").put(134, 12, "I").put(174, 14, "I")
c.put(182, 14, "D").put(44, 12, "T").put(52, 12, "T").put(178, 14, "T")
c.put(90, 12, ">").put(124, 12, "<")
room("G14", "revert.sh", (188, 20), [1424, 192],
     [D("G14", "W", 7, 10, "G13:E"), D("G14", "S", 46, 49, "G15:N"), D("G14", "E", 11, 14, "P07:W")], c,
     end="to be continued in /var/prod",
     plates=[{"key": [55, 12], "cols": [80], "latch": [84, 12]}, {"key": [94, 12], "cols": [130], "latch": [134, 12]},
            {"key": [135, 12], "cols": [170], "latch": [174, 14]}],
     signs=["revert.sh: every bridge falls behind you. Every gate wants a plate held.",
            "initial (package-lock: locked)",
            "rollback.sh -> /var/prod"])

# ---------------------------------------------------------------- G15 initial_commit (secret, --force; Panel F) 40x16
c = C(40, 16).box(top=1, bottom=3)
for (yy, x0, x1) in [(10, 6, 10), (7, 13, 17), (4, 8, 12)]:
    plat(c, yy, x0, x1)
c.put(22, 12, "I").put(25, 12, "I").put(28, 12, "I").put(31, 12, "I").put(35, 12, "*").put(3, 12, "T")
room("G15", "initial_commit", (40, 16), [1460, 212], [D("G15", "N", 10, 13, "G14:S")], c,
     secret=True, panel={"levers": [[22, 12], [25, 12], [28, 12], [31, 12]], "order": [3, 1, 4, 2]},
     signs=["Initial commit. Panel F: four relays. The logbook knows the order."])

if __name__ == "__main__":
    os.makedirs(os.path.join(HERE, "rooms"), exist_ok=True)
    for rid, rows in ROOMS.items():
        open(os.path.join(HERE, "rooms", rid + ".txt"), "w").write("\n".join(rows))
    json.dump(META, open(os.path.join(HERE, "rooms-5b.json"), "w"), ensure_ascii=False, indent=1)
    print("%d rooms written" % len(ROOMS))
