# THREAD TOWER (phase 5A) room data: draws every room file and its rooms.json entry.
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canvas import C

R = {}


def room(rid, title, w, h, x, y, doors, **kw):
    c = C(w, h)
    meta = {"file": rid + ".txt", "title": title, "size": [w, h], "origin": [x, y], "world": 4, "music": "w4", "zone": "tower",
            "signs": [], "doors": []}
    for d in doors:
        dd = {"id": d[0], "side": d[1], "a": d[2], "b": d[3], "to": d[4]}
        if len(d) > 5 and d[5]:
            dd["lock"] = d[5]
        if len(d) > 6 and d[6]:
            dd["sets"] = d[6]
        meta["doors"].append(dd)
    meta.update(kw)
    R[rid] = (c, meta)
    return c


def ladder(c, steps, ch="="):
    for row, (a, b) in steps.items():
        c.put(a, row, ch * (b - a + 1))


def open_doors(c, meta):
    for d in meta["doors"]:
        s, a, b = d["side"], d["a"], d["b"]
        for i in range(a, b + 1):
            if s == "W" and c.g[i][0] == "#":
                c.g[i][0] = " "
            elif s == "E" and c.g[i][c.w - 1] == "#":
                c.g[i][c.w - 1] = " "
            elif s == "N" and c.g[0][i] == "#":
                c.g[0][i] = " "
            elif s == "S" and c.g[c.h - 1][i] == "#":
                c.g[c.h - 1][i] = " "


JOIN = "until:2of:thread:0,thread:1,thread:2"

# ------------------------------------------------------------------ T01 pthread_create.c (64x20): the tower's foot, bench, tree
c = room("T01", "pthread_create.c", 64, 20, 1176, -72, [
    ("T01:E", "E", 9, 12, "N11:W"), ("T01:W", "W", 9, 12, "T02:E"), ("T01:N", "N", 24, 27, "TC1:S")],
    landmarks=["tower"], npc=[{"kind": "tree", "x": 54, "y": 8, "zone": "tower", "price": 40}],
    decor=[{"kind": "scrap", "x": 50, "y": 12}, {"kind": "scrap", "x": 51, "y": 11}, {"kind": "scrap", "x": 52, "y": 10}])
c.box(top=1, bottom=7)
ladder(c, {10: (20, 24), 7: (26, 30), 4: (21, 25), 2: (23, 28)})
c.put(52, 9, "######").put(40, 12, "C").put(8, 12, "T").put(58, 12, "T")
R["T01"][1]["signs"] = ["pthread_create(): three threads start here. Each climbs on its own; they meet at race_condition.go.",
                        "the clock up there ticks every 0.83 s. so does everything in the tower."]

# ------------------------------------------------------------------ T02 async_await.ts (86x20): await blocks on the tick over spikes
c = room("T02", "async_await.ts", 86, 20, 1090, -72, [
    ("T02:E", "E", 9, 12, "T01:W"), ("T02:S", "S", 30, 33, "H11:N", "until:lever:T02"),
    ("T02:N", "N", 10, 13, "TA1:S"), ("T02:N2", "N", 58, 61, "TB1:S"), ("T02:N3", "N", 40, 43, "T17:S", "oneway")],
    levers=[{"x": 35, "y": 12, "flag": "lever:T02"}],
    variants=[{"if": "boss:RACE", "rect": [0, 0, 86, 20], "from": "1", "to": "#"}, {"if": "boss:RACE", "rect": [0, 0, 86, 20], "from": "2", "to": "#"}])
c.box(top=1, bottom=7)
c.rect(30, 13, 33, 19, " ").put(30, 13, "====")             # the hatch to mmap.c: a lid, then a shaft to the locked trapdoor
c.put(35, 12, "I")
c.put(64, 13, "^" * 13).put(64, 10, "111").put(68, 10, "222").put(72, 10, "111").put(76, 9, "#")
c.put(46, 13, "^" * 10).put(47, 10, "222").put(51, 10, "111").put(54, 10, "2")
ladder(c, {10: (8, 12), 7: (13, 17), 4: (8, 12), 2: (9, 14)})
ladder(c, {10: (62, 63), 7: (56, 60), 4: (61, 65), 2: (57, 62)})
c.put(80, 12, "{").put(24, 12, "{").put(20, 12, "+").put(82, 12, "T").put(37, 12, "T")
R["T02"][1]["signs"] = ["await: the blocks are there on one tick and gone on the next. Count with the clock.",
                        "trapdoor to /proc/heap. pull the lever, then drop."]

# ------------------------------------------------------------------ TA1 thread_0.c (26x44): async blocks up a shaft
c = room("TA1", "thread_0.c", 26, 44, 1090, -116, [
    ("TA1:S", "S", 10, 13, "T02:N"), ("TA1:N", "N", 10, 13, "T04:S", "", "thread:0")],
    variants=[{"if": "boss:RACE", "rect": [0, 0, 26, 44], "from": "1", "to": "#"}, {"if": "boss:RACE", "rect": [0, 0, 26, 44], "from": "2", "to": "#"}])
c.box(top=1, bottom=0).rect(1, 43, 24, 43, "#").rect(10, 43, 13, 43, " ")
c.put(9, 41, "======")
for row, (a, b, ch) in {38: (3, 5, "1"), 35: (9, 11, "2"), 32: (15, 17, "1"), 26: (12, 14, "2"), 23: (6, 8, "1"), 20: (1, 3, "2"),
                        14: (9, 11, "1"), 11: (15, 17, "2"), 8: (20, 22, "1"), 5: (14, 16, "2")}.items():
    c.put(a, row, ch * (b - a + 1))
c.rect(18, 29, 23, 29, "#").rect(2, 17, 7, 17, "#").put(9, 2, "======")
c.put(24, 24, ")").put(1, 12, ")").put(4, 16, "{").put(20, 28, "T")
R["TA1"][1]["signs"] = ["thread_0: waiting on async I/O. the floor comes and goes."]

# ------------------------------------------------------------------ TB1 thread_1.c (26x44): heisenbugs on the ledges
c = room("TB1", "thread_1.c", 26, 44, 1138, -116, [
    ("TB1:S", "S", 10, 13, "T02:N2"), ("TB1:N", "N", 10, 13, "T04:S2", "", "thread:1"), ("TB1:E", "E", 13, 16, "T15:W")])
c.box(top=1, bottom=0).rect(1, 43, 24, 43, "#").rect(10, 43, 13, 43, " ")
ladder(c, {41: (9, 14), 38: (2, 7), 35: (10, 15), 32: (18, 23), 29: (10, 15), 26: (2, 7), 23: (9, 14), 20: (16, 21),
           14: (10, 15), 11: (3, 8), 8: (10, 15), 5: (16, 21), 2: (9, 14)})
c.rect(19, 17, 24, 17, "#").rect(25, 13, 25, 16, "%")
for (x, y) in [(4, 37), (20, 31), (4, 25), (12, 13), (18, 4)]:
    c.put(x, y, "(")
c.put(21, 16, "T")
R["TB1"][1]["signs"] = ["thread_1: a heisenbug. it only moves when nobody is looking. (one is asleep behind the cracked wall.)"]

# ------------------------------------------------------------------ TC1 thread_2.c (26x44): ticking gears
c = room("TC1", "thread_2.c", 26, 44, 1190, -116, [
    ("TC1:S", "S", 10, 13, "T01:N"), ("TC1:N", "N", 10, 13, "T04:S3", "", "thread:2")],
    gears=[{"x": 12, "y": 34, "r": 3, "n": 2}, {"x": 12, "y": 20, "r": 3, "n": 2}])
c.box(top=1, bottom=0).rect(1, 43, 24, 43, "#").rect(10, 43, 13, 43, " ")
c.put(9, 41, "======").put(12, 34, "O").put(12, 20, "O")
c.rect(2, 27, 6, 27, "#").rect(19, 27, 23, 27, "#").rect(8, 13, 15, 13, "#").put(9, 2, "======")
ladder(c, {10: (3, 7), 6: (16, 20), 4: (11, 13)})
c.put(1, 30, ")").put(24, 16, ")").put(10, 12, "{").put(4, 26, "T")
R["TC1"][1]["signs"] = ["thread_2: the gears turn one step per tick. ride them."]

# ------------------------------------------------------------------ T15 heisenbug.log (26x14): secret corridor
c = room("T15", "heisenbug.log", 26, 14, 1164, -110, [("T15:W", "W", 7, 10, "TB1:E")],
         secret=True, plugins=["hot_path"], agents=[[21, 10]])
c.box(top=1, bottom=3).rect(4, 1, 24, 6, "#")
c.put(8, 10, "^^").put(14, 10, "^^").put(19, 10, "^^")
for x in (6, 11, 17, 23):
    c.put(x, 10, "(")
c.put(24, 10, "U").put(2, 10, "T")
R["T15"][1]["signs"] = ["heisenbug.log: they stop when you look at them. you can only look one way."]

# ------------------------------------------------------------------ T04 race_condition.go (150x20): join; bench; races
c = room("T04", "race_condition.go", 150, 20, 1090, -136, [
    ("T04:S", "S", 10, 13, "TA1:N"), ("T04:S2", "S", 58, 61, "TB1:N"), ("T04:S3", "S", 110, 113, "TC1:N"),
    ("T04:S4", "S", 40, 43, "T17:N"), ("T04:N", "N", 10, 13, "TA2:S", JOIN), ("T04:N2", "N", 58, 61, "TB2:S", JOIN)],
    decor=[{"kind": "threads", "x": 60, "y": 2, "w": 40, "if": "!boss:RACE"}])
c.box(top=1, bottom=7)
for a in (10, 58, 110, 40):
    c.rect(a, 13, a + 3, 19, " ").put(a, 13, "====")
c.rect(8, 5, 15, 5, "#")                                    # the sudo ledge under thread_0's way up
ladder(c, {10: (62, 63), 7: (56, 60), 4: (61, 65), 2: (57, 62)})
c.put(75, 12, "C").put(30, 12, "[").put(95, 12, "[").put(125, 12, "+").put(48, 12, "}")
c.put(38, 12, "T").put(70, 12, "T").put(8, 12, "T")
R["T04"][1]["signs"] = ["yield(): drop here to go back down and start another thread. (single core detected: threads run one by one.)",
                        {"text": "join: 0 of 3 threads here. two must join.", "alt": [
                            {"if": "2of:thread:0,thread:1,thread:2", "text": "join: done. the way up is open."}]},
                        "the stairs to thread_0's top are for sudo."]

# ------------------------------------------------------------------ T17 yield() (22x44): a chute back to async_await.ts
c = room("T17", "yield()", 22, 44, 1116, -116, [("T17:N", "N", 14, 17, "T04:S4"), ("T17:S", "S", 14, 17, "T02:N3")])
c.box(top=1, bottom=0).rect(1, 43, 20, 43, "#").rect(14, 43, 17, 43, " ")
c.rect(1, 10, 8, 12, "#").rect(17, 22, 20, 24, "#").rect(1, 32, 9, 34, "#")
for (x, y) in [(15, 16), (8, 26), (16, 37)]:
    c.put(x, y, ")")

# ------------------------------------------------------------------ TA2 deadlock.rs (26x62): sudo climb, deadlock pairs, pistons
c = room("TA2", "deadlock.rs", 26, 62, 1090, -198, [
    ("TA2:S", "S", 10, 13, "T04:N"), ("TA2:W", "W", 35, 38, "T14:E"), ("TA2:N", "N", 10, 13, "T08:S")],
    pistons=[{"x": 17, "y": 30, "len": 3, "w": 1, "ticks": [1, 1, 1, 1]}, {"x": 8, "y": 15, "len": 3, "w": 1, "ticks": [1, 1, 1, 1]}])
c.box(top=1, bottom=0).rect(1, 61, 24, 61, "#").rect(10, 61, 13, 61, " ")
c.put(9, 59, "======")
for row, (a, b) in {54: (2, 8), 49: (16, 23), 44: (5, 12), 39: (1, 6), 34: (14, 21), 29: (4, 10), 24: (14, 20), 19: (5, 11),
                    14: (14, 20), 9: (6, 12)}.items():
    c.rect(a, row, b, row, "#")
c.rect(0, 35, 0, 38, ";").put(9, 4, "======").put(9, 2, "======")
c.put(17, 30, "A").put(8, 15, "A")
c.put(3, 53, "]").put(18, 48, "]").put(6, 18, ")").put(15, 33, "T")
R["TA2"][1]["signs"] = ["deadlock.rs: each one holds what the other needs. stand between them."]

# ------------------------------------------------------------------ TB2 mutex.c (26x62): mutex gates, keys, the arena door
c = room("TB2", "mutex.c", 26, 62, 1138, -198, [
    ("TB2:S", "S", 10, 13, "T04:N2"), ("TB2:E", "E", 55, 58, "T06:W", "fight"), ("TB2:N", "N", 10, 13, "T08:S2")],
    mutex=[{"key": [3, 58], "rows": [45]}, {"key": [22, 43], "rows": [30]}, {"key": [3, 28], "rows": [15]}])
c.box(top=1, bottom=0).rect(1, 59, 24, 61, "#").rect(10, 59, 13, 61, " ").put(10, 59, "====")
c.rect(1, 45, 24, 45, "4").rect(1, 30, 24, 30, "4").rect(1, 15, 24, 15, "4")
ladder(c, {56: (16, 21), 53: (8, 13), 50: (2, 7), 47: (10, 15)})
c.rect(16, 44, 23, 44, "#")
ladder(c, {41: (9, 14), 38: (2, 7), 35: (9, 14), 32: (16, 21)})
c.rect(2, 29, 8, 29, "#")
ladder(c, {26: (10, 15), 23: (17, 22), 20: (10, 15), 17: (3, 8)})
c.rect(8, 14, 17, 14, "#")
ladder(c, {11: (2, 7), 8: (10, 15), 5: (16, 21), 2: (9, 14)})
c.put(3, 58, "Q").put(22, 43, "Q").put(3, 28, "Q")
c.put(24, 50, ")").put(1, 36, ")").put(24, 22, ")").put(12, 13, "{").put(6, 58, "T")
R["TB2"][1]["signs"] = ["mutex.c: hit the key, the lock above is yours for 3.5 s. (two of you: one stands on the key.)"]

# ------------------------------------------------------------------ TC2 semaphore.h (26x62): breakpoint on busy pistons
c = room("TC2", "semaphore.h", 26, 62, 1190, -198, [
    ("TC2:W", "W", 55, 58, "T06:E", "until:boss:RACE"), ("TC2:N", "N", 6, 9, "T09:S")],
    pistons=[{"x": 11, "y": 40, "len": 4, "w": 4, "ticks": [0.25, 0.1, 0.25, 0.1], "busy": True},
             {"x": 11, "y": 20, "len": 4, "w": 4, "ticks": [0.25, 0.1, 0.25, 0.1], "busy": True},
             {"x": 6, "y": 1, "len": 3, "w": 4, "ticks": [0.25, 0.1, 0.25, 0.1], "busy": True}],
    moving_freezable=True)
c.box(top=1, bottom=0).rect(1, 59, 24, 61, "#")
ladder(c, {56: (12, 17), 53: (18, 23), 50: (12, 17), 47: (5, 10)})
c.rect(1, 44, 10, 44, "#").rect(15, 44, 24, 44, "#").rect(10, 41, 10, 44, "#").rect(15, 41, 15, 44, "#")
c.rect(11, 40, 14, 40, "A")
ladder(c, {37: (11, 14), 34: (4, 9), 31: (12, 17), 28: (18, 23), 25: (12, 17)})
c.rect(1, 24, 10, 24, "#").rect(15, 24, 24, 24, "#").rect(10, 21, 10, 24, "#").rect(15, 21, 15, 24, "#")
c.rect(11, 20, 14, 20, "A")
ladder(c, {17: (11, 14), 14: (4, 9), 11: (12, 17), 8: (5, 10)})
c.rect(6, 1, 9, 1, "A").rect(5, 2, 5, 4, "#").rect(10, 2, 10, 4, "#")
c.put(20, 52, "[").put(3, 58, "T")
R["TC2"][1]["signs"] = ["semaphore.h: these pistons never rest (busy-wait). press [special] facing one: breakpoint. it stops for 3.5 s."]

# ------------------------------------------------------------------ T06 RACE CONDITION (26x14)
c = room("T06", "RACE CONDITION", 26, 14, 1164, -150, [
    ("T06:W", "W", 7, 10, "TB2:E", "fight"), ("T06:E", "E", 7, 10, "TC2:W", "until:boss:RACE")],
    boss={"id": "RACE", "class": "RaceBoss", "name": "RACE CONDITION", "sub": "two threads, one variable", "trigger_x": 96,
          "T": 100, "u": 0.9, "reward": "breakpoint", "banner": "breakpoint",
          "banner_sub": "facing a machine or an enemy, press [special]: it stops for 3.5 s", "music": "boss", "drop": 45})
c.box(top=1, bottom=3)
c.put(1, 8, "===").put(22, 8, "===").put(9, 10, "B").put(17, 10, "B")

# ------------------------------------------------------------------ T14 volatile.h (24x14): secret
c = room("T14", "volatile.h", 24, 14, 1066, -170, [("T14:E", "E", 7, 10, "TA2:W")], secret=True, pages=[[4, 10, 3]])
c.box(top=1, bottom=3).put(12, 7, "=====").put(14, 6, "*").put(18, 10, "T")
R["T14"][1]["signs"] = ["volatile: the compiler may not assume this value stays the same. neither should you."]

# ------------------------------------------------------------------ T08 scheduler.c (76x20): terminal; the clock
c = room("T08", "scheduler.c", 76, 20, 1090, -218, [
    ("T08:S", "S", 10, 13, "TA2:N"), ("T08:S2", "S", 58, 61, "TB2:N"), ("T08:E", "E", 7, 10, "T09:W"), ("T08:N", "N", 20, 23, "T18:S")],
    terminal=True, landmarks=["tower"], gears=[{"x": 38, "y": 7, "r": 4, "n": 2, "decor": True}],
    decor=[{"kind": "coffee2", "x": 33, "y": 14}])
c.box(top=1, bottom=5)
c.rect(10, 15, 13, 19, " ").put(10, 15, "====").rect(58, 15, 61, 19, " ").put(58, 15, "====")
c.rect(66, 11, 74, 14, "#").put(62, 13, "===")
ladder(c, {12: (17, 21), 9: (22, 26), 6: (18, 23), 3: (19, 24)})
c.rect(20, 1, 23, 1, "5")
c.put(30, 14, "C").put(36, 14, "T").put(70, 10, "T")
R["T08"][1]["signs"] = ["worker 2 joined. Finally, a second opinion.", "while(true) next door. it does not stop by itself."]

# ------------------------------------------------------------------ T09 while_true.js (64x20): the loop
c = room("T09", "while_true.js", 64, 20, 1166, -218, [
    ("T09:W", "W", 7, 10, "T08:E"), ("T09:S", "S", 30, 33, "TC2:N"), ("T09:E", "E", 11, 14, "T09:W", "", "", )],
    loop={"flag": "break:T09", "after": "T10:W", "iters": [
        {}, {"spawn": [["{", 40, 14], ["{", 52, 14]]}, {"spawn": [["{", 40, 14], ["{", 52, 14], ["(", 24, 14]], "variant": 0},
        {"spawn": [["{", 40, 14], ["{", 52, 14], ["(", 24, 14], ["}", 58, 14]], "variant": 0, "key": True}]},
    variants=[{"if": "iter>=2", "rect": [36, 14, 13, 1], "from": " ", "to": "^"}])
c.box(top=1, bottom=4)
c.rect(1, 11, 20, 15, "#").rect(30, 15, 33, 19, " ").put(30, 15, "====")
ladder(c, {12: (40, 44), 9: (45, 49), 6: (40, 44), 4: (44, 49)})
c.put(46, 3, "F").put(22, 14, "T").put(6, 10, "T")
R["T09"][1]["signs"] = ["while (true) {", "i++; // the room gets a little worse every time. look for break;"]

# ------------------------------------------------------------------ T10 INFINITE LOOP (24x14)
c = room("T10", "INFINITE LOOP", 24, 14, 1230, -214, [
    ("T10:W", "W", 7, 10, "T09:E", "fight"), ("T10:E", "E", 7, 10, "T11:W", "until:boss:LOOP")],
    boss={"id": "LOOP", "class": "LoopBoss", "name": "INFINITE LOOP", "sub": "while (true)", "trigger_x": 80,
          "T": 110, "u": 0.6, "reward": "opus", "banner": "opus",
          "banner_sub": "your claw reaches further and hits twice as hard; it cuts spaghetti cables", "music": "boss", "drop": 50})
c.box(top=1, bottom=3).put(12, 10, "B")

# ------------------------------------------------------------------ T11 busy_wait.c (48x20): opus reward; cable floor; the piston east
c = room("T11", "busy_wait.c", 48, 20, 1254, -218, [
    ("T11:W", "W", 11, 14, "T10:E"), ("T11:S", "S", 24, 27, "T16:N"), ("T11:E", "E", 7, 10, "P01:W")],
    end="to be continued in /var/prod",
    pistons=[{"x": 38, "y": 1, "len": 9, "w": 2, "ticks": [0.25, 0.1, 0.25, 0.1], "busy": True}])
c.box(top=1, bottom=4)
c.rect(24, 15, 27, 19, " ").rect(24, 15, 27, 15, "5")
c.rect(40, 11, 46, 14, "#").rect(36, 11, 39, 14, "#").put(38, 1, "AA").rect(37, 1, 37, 1, "#").rect(40, 1, 40, 1, "#")
c.put(44, 10, "D").put(12, 14, "+").put(30, 14, "T").put(6, 14, "T")
R["T11"][1]["signs"] = ["busy_wait: it never sleeps. (breakpoint)", "spaghetti under your feet: goto, all the way down. (opus)"]

# ------------------------------------------------------------------ T16 goto (26x94): the shortcut down to the airgap
c = room("T16", "goto", 26, 94, 1270, -198, [("T16:N", "N", 8, 11, "T11:S"), ("T16:S", "S", 10, 13, "N11:N")])
c.box(top=1, bottom=0).rect(1, 93, 24, 93, "#")
c.rect(1, 20, 7, 22, "#").rect(15, 40, 24, 42, "#").rect(1, 60, 8, 62, "#").rect(16, 78, 24, 80, "#")
for (x, y) in [(12, 28), (6, 48), (14, 68), (8, 86)]:
    c.put(x, y, ")")
c.put(3, 19, "T")
R["T16"][1]["signs"] = ["goto: considered harmful. considered fast."]

# ------------------------------------------------------------------ T18 lock_order.c (24x14): optional DEADLOCK arena above the terminal
c = room("T18", "lock_order.c", 24, 14, 1100, -232, [("T18:S", "S", 10, 13, "T08:N", "fight")],
         boss={"id": "DEADLOCK", "class": "DeadlockBoss", "name": "DEADLOCK", "sub": "each waits for the other", "trigger": "land",
               "T": 120, "u": 0.8, "reward": "plugin:lock_free", "banner": "lock_free",
               "banner_sub": "plugin - your dash goes through guards and shields", "music": "boss", "drop": 40})
c.box(top=1, bottom=3).rect(10, 11, 13, 13, " ").put(10, 11, "====")
c.put(1, 8, "===").put(20, 8, "===").put(5, 10, "B").put(18, 10, "B")

R["T09"][1]["doors"][2]["wrap"] = True          # leads back into its own west door until break:T09, then to T10:W
for rid, (cv, meta) in R.items():
    open_doors(cv, meta)

# ------------------------------------------------------------------ edits to built rooms
EDITS = {
    "N11": {"cells": [[3, 44, " "]], "del": ["end"], "doors_lock": {"N11:N": "oneway"},
            "sign": [1, "/dev/threads: the tower. GET your way to the foot of it."]},
    "H11": {"doors_lock": {"H11:N": "until:lever:T02"}},
}


def write(out):
    os.makedirs(os.path.join(out, "rooms"), exist_ok=True)
    for rid, (cv, meta) in R.items():
        open(os.path.join(out, "rooms", rid + ".txt"), "w").write("\n".join(cv.rows()))
    json.dump({k: v[1] for k, v in R.items()}, open(os.path.join(out, "rooms-5a.json"), "w"), indent=1, ensure_ascii=False)
    json.dump(EDITS, open(os.path.join(out, "room-edits-5a.json"), "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    write(os.path.dirname(os.path.abspath(__file__)))
    for rid, (cv, meta) in R.items():
        print(rid, meta["size"], len(cv.rows()), set(len(r) for r in cv.rows()))
