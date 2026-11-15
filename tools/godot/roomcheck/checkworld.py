# Whole-game reachability checker (Claude's tool, not part of test-all). The regional checkers (check4a..check5a) test
# routes inside one region; this one walks the whole built world from R01's spawn with the movement simulator (sim.py,
# reach.py) and the abilities the player has at each moment, and says:
#   - in story order (every reachable boss is beaten as soon as it is reached): which rooms and bosses each new ability opens;
#   - in EVERY order of getting the abilities (the map's order is free): which rooms a player can enter but not leave again
#     (no walking way back to R01; a rested terminal is shown as the only way out, since travel needs one);
#   - which rooms / ways back depend on the simulator's optimism (crumbles stay solid, moving platforms are fixed floors,
#     blinking blocks are both on, ports open, mutex gates open, breakpoint freezes every busy piston, bulkheads blown):
#     each room with such cells is explored a second time without them, and what only the optimistic pass finds is "uncertain".
# Flags the player sets by playing are derived, latched, until nothing changes: door `sets` (hatches, threads), levers
# (their cell within a jump), catch / agents gates (the room reached with the ability: optimistic, the projectile or the
# agents are not simulated), bulkheads `0` (the room reached: a SEGFAULT blows them), wave rooms (reached = cleared),
# the loop room's `break;` key (cell reachable with the worst pass's spikes), HEAP flood levels (game.gd heap_flood).
# Not simulated, only listed: rising water (H06), chases (N17), enemies, fights (every boss is assumed beaten).
#
# Usage: python3 -I tools/godot/roomcheck/checkworld.py [--stage DIR]... [--story] [--wall CHARS] [--no-cache] [-v]
#   --stage DIR   lay a draft region over the live world, like check5a.py: DIR/rooms-*.json (new rooms, files in DIR/rooms/)
#                 and DIR/room-edits-*.json (cells, doors_add, doors_lock, del, set on built rooms). Repeatable.
#   --story       only the story-order pass (fast); the default also runs every order.
#   --wall CHARS  tile letters to treat as walls (a draft's new obstacle the simulator does not know; it reads them as air).
#   -v            list every room of every step, and the uncertain edges.
# Explore results are cached in the temp folder (keyed by the room's cells, doors, options and sim.py / reach.py), so a
# second run takes seconds; the first takes about 20 minutes on 4 cores (--story alone about 8).
import json, os, sys, copy, glob, hashlib, pickle, tempfile, argparse, inspect, time
from multiprocessing import Pool
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import Room, T
from sim import P, step, hazard, door_exit
from reach import entry_state, programs, policy_for, run, key, MAXF

ROOT = HERE
while not os.path.exists(os.path.join(ROOT, "godot/src/world/rooms.json")):
    if os.path.dirname(ROOT) == ROOT:
        ROOT = os.getcwd()
        break
    ROOT = os.path.dirname(ROOT)
LIVE = os.path.join(ROOT, "godot/src/world")
MOVE_AB = ("bash", "sudo", "curl", "ssh")              # the abilities sim.py / reach.py read; the rest act through room options
OPTIMISTIC = {"~": "crumble", "M": "platform", "V": "platform", "J": "platform", "1": "blink", "2": "blink"}


# ---------------------------------------------------------------- data
def load(stages, walls):
    meta = json.load(open(os.path.join(LIVE, "rooms.json")))
    rooms = copy.deepcopy(meta["rooms"])
    files = {rid: open(os.path.join(LIVE, "rooms", m["file"])).read().split("\n") for rid, m in rooms.items()}
    known = set("".join("".join(r) for r in files.values()))
    staged, warn = [], []
    for st in stages:
        for f in sorted(glob.glob(os.path.join(st, "room-edits-*.json"))):
            for rid, e in json.load(open(f)).items():
                if rid not in rooms:
                    warn.append("%s: edit for unknown room %s" % (os.path.basename(f), rid))
                    continue
                rows = [list(r) for r in files[rid]]
                for (x, y, txt) in e.get("cells", []):
                    for i, ch in enumerate(txt):
                        rows[y][x + i] = ch
                files[rid] = ["".join(r) for r in rows]
                have = {d["id"] for d in rooms[rid]["doors"]}
                rooms[rid]["doors"] += [d for d in e.get("doors_add", []) if d["id"] not in have]
                for d in rooms[rid]["doors"]:
                    if d["id"] in e.get("doors_lock", {}):
                        d["lock"] = e["doors_lock"][d["id"]]
                for k in e.get("del", []):
                    rooms[rid].pop(k, None)
                for k, v in e.get("set", {}).items():
                    rooms[rid][k] = v
        for f in sorted(glob.glob(os.path.join(st, "rooms-*.json"))):
            for rid, m in json.load(open(f)).items():
                p = [q for q in (os.path.join(st, "rooms", m["file"]), os.path.join(st, m["file"])) if os.path.exists(q)]
                if not p:
                    warn.append("%s: no file %s" % (rid, m["file"]))
                    continue
                rooms[rid] = m
                files[rid] = open(p[0]).read().split("\n")
                staged.append(rid)
                odd = sorted(set("".join(files[rid])) - known - set(walls))
                if odd:
                    warn.append("%s: letters no built room uses (the simulator reads them as air; --wall makes them walls): %s" % (rid, " ".join(odd)))
    for rid in files:
        # a worm in a brick (`W`) is a firewall brick in the game (room.gd); sim.py does not know the letter
        files[rid] = ["".join("#" if c in walls else ("N" if c == "W" else c) for c in r) for r in files[rid]]
    world = {rid: m for rid, m in rooms.items() if not m.get("lab")}
    return meta.get("start", {"room": "R01"}), world, files, staged, warn


# ---------------------------------------------------------------- the game's rules
def flood(flags):
    """game.gd heap_flood"""
    if "boss:LEAK" in flags:
        return 0
    if "gate:H07:catch" in flags:
        return 1
    return 2


def cond(s, flags, it=3):
    """game.gd cond / room.gd _until_open and _cond (`iter>=N`: the loop room, its worst pass)"""
    if s.startswith("!"):
        return not cond(s[1:], flags, it)
    if "of:" in s and s.split("of:")[0].isdigit():
        k, fl = s.split("of:", 1)
        return sum(1 for f in fl.split(",") if f in flags) >= int(k)
    if s == "flood>0":
        return flood(flags) > 0
    if s == "flood==0":
        return flood(flags) == 0
    if s.startswith("iter>="):
        return it >= int(s[6:])
    return s in flags


class World:
    def __init__(self, start, rooms, files):
        self.start, self.rooms, self.files = start, rooms, files
        self.door = {d["id"]: (rid, d) for rid, m in rooms.items() for d in m["doors"]}

    def target(self, did, flags):
        """the entry a door leads to (None: a room that does not exist yet)"""
        rid, d = self.door[did]
        if d.get("wrap"):
            lp = self.rooms[rid].get("loop", {})
            return lp.get("after") if lp.get("flag") in flags and lp.get("after") in self.door else d["to"]
        return d["to"] if d["to"] in self.door else None

    def cfg(self, rid, ab, flags, pess=False):
        """(rows, doors, opts, features) of a room as the player finds it"""
        m = self.rooms[rid]
        rows = [list(r) for r in self.files[rid]]
        for v in m.get("variants", []):
            if cond(v["if"], flags):
                x0, y0, w, h = v["rect"]
                for y in range(y0, min(y0 + h, len(rows))):
                    for x in range(x0, min(x0 + w, len(rows[y]))):
                        if rows[y][x] == v["from"]:
                            rows[y][x] = v["to"]
        doors = []
        for d in m["doors"]:
            op = d["to"] in self.door
            lk = d.get("lock", "")
            if lk == "oneway":
                op = False
            elif lk.startswith("until:"):
                op = op and cond(lk[6:], flags)
            elif lk.startswith("flood:"):
                op = op and flood(flags) <= int(lk[6:])
            doors.append(dict(side=d["side"], a=d["a"], b=d["b"], open=op, id=d["id"]))
        o = {"crack_open": "bash" in ab, "gate_c": "gate:%s:catch" % rid in flags,
             "gate_a": "gate:%s:agents" % rid in flags or m.get("gate_lever", "-") in flags,
             "thick_open": "blast:%s" % rid in flags, "cable_cut": "opus" in ab,
             "gears": m.get("gears", []), "pistons": [p for p in m.get("pistons", []) if p.get("busy")],
             "pistons_solid": "breakpoint" not in ab}
        if "boss:CRAWLER" in flags:
            o["webs_off"] = o["hooks_rings"] = True
        fl = m.get("flood")
        if fl is not None and fl[2 - flood(flags)] is not None:
            o["liquid_y"] = fl[2 - flood(flags)] * T + 6
        feats = set()
        text = "".join("".join(r) for r in rows)
        for ch, name in OPTIMISTIC.items():
            if ch in text:
                feats.add(name)
        if "3" in text:
            feats.add("port")
        if "4" in text:
            feats.add("mutex")
        if any(not g.get("decor") for g in o["gears"]):
            feats.add("gear")
        if o["pistons"] and not o["pistons_solid"]:
            feats.add("breakpoint")
        if "0" in text and o["thick_open"]:
            feats.add("blast")
        if pess:
            rows = [[" " if c in OPTIMISTIC else c for c in r] for r in rows]
            o.update(ports_open=False, mutex_open=False, gears=[], pistons_solid=True, thick_open=False)
        return ["".join(r) for r in rows], doors, o, feats


# ---------------------------------------------------------------- exploring (parallel, cached)
def _job(args):
    """Explore one room from all its entries at once. reach.explore walks a standing-cell graph from one entry; the moves
    out of a standing cell do not depend on the entry, so the graph is built once for every entry and each entry's doors
    and cells are a search over it (the same programs, flights and walking as reach.explore; a cell's position is the
    first one found, so a result can differ from explore's by a pixel)."""
    rows, doors, opts, ab, entries = args
    doors = [dict(d) for d in doors]
    ab = set(ab)
    rm = Room(list(rows), doors, dict(opts))
    progs = programs(ab)
    pos, trans, queue, queued = {}, {}, [], set()

    def node(p, expand=True):
        k = key(p)
        if k not in pos:
            pos[k] = (p.x, p.y)
        if expand and k not in queued:
            queued.add(k)
            queue.append(k)
        return ("k", k)

    def take(res, out):
        kind, side, d, p = res
        if kind == "door":
            out.add(("d", (side, d["a"])))
        elif kind == "land":
            out.add(node(p))

    flights = [lambda f, p, d=d: {"mx": d, "jump": True} for d in (0, -1, 1)]
    for d in (-1, 1):
        for how in ("toward", "away"):
            flights.append(("wall", d, how))
        if "curl" in ab:
            flights.append(lambda f, p, d=d: {"mx": d, "jump": True, "sp": f % 10 == 3})
    first = {}
    for e in entries:
        if e is None:                                   # the spawn `P`
            sy = [y for y, r in enumerate(rows) if "P" in r][0]
            starts = [(rows[sy].index("P") * T + 3.0, sy * T + 6.0, 0.0, 0.0)]
        else:
            dd = [q for q in doors if q["id"] == e][0]
            starts = entry_state(rm, dd["side"], dd, ab)
        out = set()
        for (x, y, vx, vy) in starts:
            for fl in flights:
                pol = policy_for(("wall", fl[1], 999, fl[2])) if isinstance(fl, tuple) else fl
                p = P(x, y)
                p.vx, p.vy = vx, vy
                for f in range(MAXF * 2):
                    step(rm, p, pol(f, p), ab)
                    de = door_exit(rm, p)
                    if de and f > 2:
                        out.add(("d", (de[0], de[1]["a"])))
                        break
                    if hazard(rm, p):
                        break
                    if p.on_ground:
                        out.add(node(p))
                        break
        first[e] = out
    while queue and len(pos) < 12000:
        k = queue.pop()
        x, y = pos[k]
        out = set()
        for prog in progs:
            take(run(rm, ab, x, y, 0.0, 0.0, policy_for(prog), ground=True), out)
        for d in (-1, 1):
            p = P(x, y)
            p.on_ground = True
            for f in range(400):
                step(rm, p, {"mx": d}, ab)
                de = door_exit(rm, p)
                if de:
                    out.add(("d", (de[0], de[1]["a"])))
                    break
                if hazard(rm, p):
                    break
                if not p.on_ground:
                    take(run(rm, ab, p.x, p.y, p.vx, p.vy, lambda f2, q, d=d: {"mx": d}), out)
                    if "curl" in ab:
                        take(run(rm, ab, p.x, p.y, p.vx, p.vy, lambda f2, q, d=d: {"mx": d, "sp": f2 % 10 == 2, "jump": True}), out)
                    break
                out.add(node(p, key(p)[0] % 2 == 0))
                if p.vx == 0 and f > (30 if "ssh" in ab else 5):
                    break
        trans[k] = out
    res = {}
    for e, out in first.items():
        seen, ds, st = set(), set(), list(out)
        while st:
            t = st.pop()
            if t[0] == "d":
                ds.add(t[1])
            elif t[1] not in seen:
                seen.add(t[1])
                st.extend(trans.get(t[1], ()))
        got = sorted({[q["id"] for q in doors if q["side"] == sd and q["a"] == a][0] for (sd, a) in ds})
        res[e] = (got, sorted(seen))
    return res


class Explorer:
    def __init__(self, use_cache=True):
        src = "".join(open(os.path.join(HERE, f)).read() for f in ("sim.py", "reach.py")) + inspect.getsource(_job)
        self.salt = hashlib.sha1(src.encode()).hexdigest()
        self.path = os.path.join(tempfile.gettempdir(), "clawd-checkworld-cache.pkl")
        self.mem = {}
        if use_cache and os.path.exists(self.path):
            try:
                self.mem = pickle.load(open(self.path, "rb"))
            except Exception:
                self.mem = {}
        self.use_cache = use_cache
        self.new = 0
        self.pool = None
        self.running = {}
        self.saved = time.time()

    def key(self, job):
        rows, doors, opts, ab, entry = job
        return hashlib.sha1(repr((self.salt, rows, doors, sorted(opts.items()), ab, entry)).encode()).hexdigest()

    def submit(self, job):
        """start a job (unless cached or running); returns its key"""
        k = self.key(job)
        if k not in self.mem and k not in self.running:
            if self.pool is None:
                self.pool = Pool(max(1, os.cpu_count() or 1))
            self.running[k] = self.pool.apply_async(_job, (job,))
        return k

    def ready(self, k):
        if k in self.mem:
            return True
        r = self.running[k]
        if not r.ready():
            return False
        self.mem[k] = r.get()
        del self.running[k]
        self.new += 1
        if time.time() - self.saved > 60:
            self.save()
        return True

    def save(self):
        self.saved = time.time()
        if self.use_cache:
            tmp = self.path + ".%d" % os.getpid()
            pickle.dump(self.mem, open(tmp, "wb"))
            os.replace(tmp, self.path)

    def close(self):
        self.save()
        if self.pool:
            self.pool.close()


def near(seen, x, y):
    """reach.py's item test (check5a reach_cells): a standing spot within a jump of cell (x, y)"""
    return any(abs(c - x) <= 4 and 0 <= (f // T) - 1 - y <= 3 for (c, f) in seen)


# ---------------------------------------------------------------- one state of the game
class State:
    """Everything reachable with ability set `ab` and the bosses in `beaten`, the flags the player sets on the way,
    the door graph (node = the entry door a player comes in by; "*" = the spawn), and which edges are sure."""
    def __init__(self, W, X, ab, beaten):
        self.W, self.X, self.ab, self.beaten = W, X, frozenset(ab), frozenset(beaten)
        flags = {"boss:" + b for b in beaten} | {"ability:" + a for a in ab}
        self.edges, self.sure, self.seen, self.feats, self.memo = {}, {}, {}, {}, {}
        while True:
            self.flags = frozenset(flags)
            self._walk()
            new = self._flags() - flags
            if not new:
                break
            flags |= new
        self.rooms = {}
        for n in self.nodes:
            self.rooms.setdefault(self.room_of(n), []).append(n)

    def room_of(self, n):
        return self.W.start["room"] if n == "*" else self.W.door[n][0]

    def entries(self, rid):
        """every way into a room (a door whose other side exists; the spawn), whatever the locks on this side"""
        m = self.W.rooms[rid]
        out = [d["id"] for d in m["doors"] if d["to"] in self.W.door or any(
            self.W.rooms[r].get("loop", {}).get("after") == d["id"] for r in self.W.rooms)]
        return ([None] if rid == self.W.start["room"] else []) + out

    def _job(self, rid, pess):
        rows, doors, o, feats = self.W.cfg(rid, self.ab, self.flags, pess)
        text = "".join(rows)
        # curl needs a ring in the room, ssh a firewall brick: without one the simulator's result is the same, so the
        # ability is left out of the job and the cached result of the smaller set is reused
        mab = tuple(a for a in MOVE_AB if a in self.ab and (a != "curl" or "@" in text or "j" in text or ("c" in text and o.get("hooks_rings")))
                    and (a != "ssh" or "N" in text))
        return (tuple(rows), tuple(tuple(sorted(d.items())) for d in doors), o, mab, tuple(self.entries(rid))), feats

    def _walk(self):
        """the door graph from the spawn; each room is explored once per configuration, from all its entries; rooms are
        explored in parallel as soon as the search reaches them"""
        self.nodes = {"*"}
        self.edges, self.sure, self.seen, self.feats = {}, {}, {}, {}
        jobs, waiting = {}, {}

        def want(n):
            r = self.room_of(n)
            if r not in jobs:
                j, feats = self._job(r, False)
                jobs[r] = (self.X.submit(j), self.X.submit(self._job(r, True)[0]) if feats else None, feats)
            waiting.setdefault(r, []).append(n)
        want("*")
        while waiting:
            got_one = False
            for r in list(waiting):
                k, pk, feats = jobs[r]
                if not (self.X.ready(k) and (pk is None or self.X.ready(pk))):
                    continue
                got_one = True
                res, pres = self.X.mem[k], self.X.mem[pk] if pk else None
                for n in waiting.pop(r):
                    e = None if n == "*" else n
                    got, seen = res[e]
                    self.edges[n] = got
                    self.seen[n] = seen
                    self.feats[n] = feats
                    self.sure[n] = set(pres[e][0]) if pres else set(got)
                    for did in got:
                        t = self.W.target(did, self.flags)
                        if t and t not in self.nodes:
                            self.nodes.add(t)
                            want(t)
            if not got_one:
                time.sleep(0.01)

    def _flags(self):
        W, out = self.W, set()
        reached = {}
        for n in self.nodes:
            reached.setdefault(self.room_of(n), []).append(n)
        for n in self.nodes:
            for did in self.edges[n]:
                s = W.door[did][1].get("sets")
                if s:
                    out.add(s)
        for rid, ns in reached.items():
            m = W.rooms[rid]
            seen = [c for n in ns for c in self.seen[n]]
            text = "".join(W.files[rid])
            for lv in m.get("levers", []):
                if near(seen, lv["x"], lv["y"]):
                    out.add(lv["flag"])
            if "catch" in self.ab and "!" in text:
                out.add("gate:%s:catch" % rid)
            if "agents" in self.ab and ("&" in text or "k" in text):
                out.add("gate:%s:agents" % rid)
            if "0" in text:
                out.add("blast:%s" % rid)
            if m.get("wave"):
                out.add(m["wave"]["flag"])
            lp = m.get("loop")
            if lp:
                rows = W.files[rid]
                fy = [y for y, r in enumerate(rows) if "F" in r]
                if fy and near(seen, rows[fy[0]].index("F"), fy[0]):
                    out.add(lp["flag"])
        return out

    def bosses(self):
        """bosses in reached rooms, not beaten yet, that can start: [(id, reward, room)]"""
        out = []
        for rid in self.rooms:
            b = self.W.rooms[rid].get("boss")
            if b and b["id"] not in self.beaten and (not b.get("pad_needs") or cond(b["pad_needs"], self.flags)):
                out.append((b["id"], b.get("reward", ""), rid))
        return sorted(out)

    def out(self, n, sure_room=None):
        """the entries a walk from entry n leads to; in room `sure_room` only what the pessimistic pass also found"""
        ds = self.sure[n] if sure_room is not None and self.room_of(n) == sure_room else self.edges[n]
        return [t for t in (self.W.target(d, self.flags) for d in ds) if t in self.nodes]

    def back(self, sure_room=None):
        """(entries a walk leads back to R01 from, the same with a rested terminal as a way out too)"""
        k = ("back", sure_room)
        if k in self.memo:
            return self.memo[k]
        home = {n for n in self.nodes if self.room_of(n) == self.W.start["room"]}
        term = {n for n in self.nodes if self.W.rooms[self.room_of(n)].get("terminal")}
        rev = {}
        for n in self.nodes:
            for t in self.out(n, sure_room):
                rev.setdefault(t, set()).add(n)

        def closure(seed):
            out, st = set(seed), list(seed)
            while st:
                for p in rev.get(st.pop(), ()):
                    if p not in out:
                        out.add(p)
                        st.append(p)
            return out
        self.memo[k] = (closure(home), closure(home | term))
        return self.memo[k]

    def fwd(self, n0):
        out, st = {n0}, [n0]
        while st:
            for t in self.out(st.pop()):
                if t not in out:
                    out.add(t)
                    st.append(t)
        return out

    def unsure(self):
        """{room: (features, [entry->exit crossings only the optimistic pass found])}"""
        out = {}
        for n in self.nodes:
            extra = sorted(set(self.edges[n]) - self.sure[n])
            if extra:
                r = self.room_of(n)
                out.setdefault(r, (self.feats[n], []))[1].extend("%s->%s" % (n.split(":")[-1] if n != "*" else "spawn", d.split(":")[-1]) for d in extra)
        return out


# ---------------------------------------------------------------- report
AB_ORDER = ("bash", "catch", "agents", "sudo", "curl", "ssh", "breakpoint", "opus")


def fmt_ab(ab):
    return "[" + ", ".join([a for a in AB_ORDER if a in ab] + sorted(a for a in ab if a not in AB_ORDER)) + "]"


def minimal(sets):
    sets = set(sets)
    return sorted((x for x in sets if not any(y < x for y in sets)), key=lambda x: (len(x), fmt_ab(x)))


def maximal(sets):
    sets = set(sets)
    return sorted((x for x in sets if not any(y > x for y in sets)), key=lambda x: (len(x), fmt_ab(x)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", action="append", default=[])
    ap.add_argument("--story", action="store_true")
    ap.add_argument("--wall", default="")
    ap.add_argument("--no-cache", action="store_true")
    ap.add_argument("-v", action="store_true")
    a = ap.parse_args()
    start, rooms, files, staged, warn = load([os.path.abspath(s) for s in a.stage], a.wall)
    W = World(start, rooms, files)
    X = Explorer(not a.no_cache)
    order_ix = {r: i for i, r in enumerate(rooms)}

    def rs(it):
        return " ".join(sorted(set(it), key=lambda r: order_ix[r]))
    problems = []
    print("CLAWD world check: %d rooms%s, start %s" % (len(rooms), " (%d staged: %s)" % (len(staged), " ".join(staged)) if staged else "", start["room"]))
    for w in warn:
        print("WARN", w)
    timed = [r for r in rooms if rooms[r].get("rise") or rooms[r].get("chase")]
    if timed:
        print("not simulated (timed): " + ", ".join("%s %s" % (r, "rising water" if rooms[r].get("rise") else "chase") for r in timed))
    reward = {m["boss"]["id"]: m["boss"].get("reward", "") for m in rooms.values() if m.get("boss")}
    giver = {rw: b for b, rw in reward.items() if rw and not rw.startswith("plugin:")}

    # ---- story order
    print("\n== story order: every boss is beaten as soon as it is reached ==")
    ab, beaten, steps, seen_rooms, seen_unsure, seen_loc = set(), set(), [], set(), set(), set()
    while True:
        st = State(W, X, ab, beaten)
        steps.append(st)
        new = set(st.rooms) - seen_rooms
        seen_rooms |= new
        bs = st.bosses()
        print("\nstep %d %s: %d rooms (+%d)" % (len(steps), fmt_ab(ab), len(st.rooms), len(new)))
        print("  new: " + (rs(new) if new else "-"))
        un = st.unsure()
        nu = {r: v for r, v in un.items() if (r, tuple(sorted(v[1]))) not in seen_unsure}
        for r, v in un.items():
            seen_unsure.add((r, tuple(sorted(v[1]))))
        if nu:
            print("  uncertain crossings (only with the optimistic simulator): " + "; ".join(
                "%s %s [%s]" % (r, " ".join(sorted(set(v[1]))), ",".join(sorted(v[0]))) for r, v in sorted(nu.items(), key=lambda x: order_ix[x[0]])))
        home, term = st.back()
        tonly = {st.room_of(n) for n in st.nodes if n not in home and n in term}
        if tonly:
            print("  walk back to R01 only by terminal travel: " + rs(tonly))
        lost = [n for n in st.nodes if n not in term]
        if lost:
            print("  no walk back (yet): " + " ".join(sorted(lost, key=lambda n: order_ix[st.room_of(n)])))
        loc = sorted({st.room_of(n) for n in st.nodes if n in term and n not in st.back(st.room_of(n))[1]} - seen_loc, key=lambda r: order_ix[r])
        seen_loc |= set(loc)
        if loc:
            print("  way back uncertain (needs the optimistic crossing of its own room): " + " ".join(loc))
        if bs:
            print("  bosses: " + ", ".join("%s in %s -> %s" % (b, r, rw or "-") for b, rw, r in bs))
        if a.v:
            print("  all: " + rs(st.rooms))
        if not bs:
            break
        for b, rw, r in bs:
            beaten.add(b)
            if rw in giver:
                ab.add(rw)
    # an entry with no walk back in a step: back once a later step's bosses are beaten, or never
    print()
    for i, st in enumerate(steps):
        for n in sorted((n for n in st.nodes if n not in st.back()[1]), key=lambda n: order_ix[st.room_of(n)]):
            later = [j for j in range(i + 1, len(steps)) if n in steps[j].back()[1]]
            if later:
                j = later[0]
                bb = sorted(b for k in range(i, j) for b, _, _ in steps[k].bosses())
                print("step %d: %s (in %s) leads back once %s %s beaten" % (i + 1, n, st.room_of(n), ", ".join(bb), "is" if len(bb) == 1 else "are"))
            else:
                print("TRAP step %d: %s (in %s) never leads back" % (i + 1, n, st.room_of(n)))
                problems.append("trap: %s entered by %s with %s" % (st.room_of(n), n, fmt_ab(st.ab)))
    never = set(rooms) - seen_rooms
    allb = {m["boss"]["id"] for m in rooms.values() if m.get("boss")}
    print("\nbosses: " + ", ".join("%s->%s (step %d)" % (b, reward[b], next(i + 1 for i, st in enumerate(steps) if b in {x for x, _, _ in st.bosses()}))
                                  for b in sorted(beaten, key=lambda b: next(i for i, st in enumerate(steps) if b in {x for x, _, _ in st.bosses()}))))
    if allb - beaten:
        print("BOSSES NEVER REACHED: " + " ".join(sorted(allb - beaten)))
        problems.append("bosses never reached: " + " ".join(sorted(allb - beaten)))
    if never:
        print("ROOMS NEVER REACHED: " + rs(never))
        problems.append("rooms never reached: " + rs(never))
    else:
        print("every room is reached (%d)" % len(rooms))

    # ---- every order
    if not a.story:
        print("\n== every order of the abilities: rooms you can enter but not leave ==")
        cache = {}

        def state(abs_):
            """the abilities abs_; beaten: their bosses and every reachable boss that gives none"""
            if abs_ not in cache:
                bt = {giver[x] for x in abs_ if x in giver}
                while True:
                    s = State(W, X, abs_, bt)
                    more = {b for b, rw, r in s.bosses() if rw not in giver}
                    if not more:
                        break
                    bt |= more
                cache[abs_] = s
            return cache[abs_]
        todo, done = [frozenset()], set()
        while todo:
            abs_ = todo.pop()
            if abs_ in done:
                continue
            done.add(abs_)
            for b, rw, r in state(abs_).bosses():
                if rw in giver and rw not in abs_:
                    todo.append(abs_ | {rw})
        print("%d ability sets can happen" % len(done))
        memo = {}

        def trapped(abs_, n, local):
            """entry n reached with abs_ leads to no walk back to R01 or a terminal, now or after any boss it can reach
            (local: the crossings of its own room only as the pessimistic pass found them)"""
            k = (abs_, n, local)
            if k not in memo:
                memo[k] = False
                s = cache[abs_]
                if n in s.back(s.room_of(n) if local else None)[1]:
                    return False
                res = True
                for nn in s.fwd(n):
                    b = W.rooms[s.room_of(nn)].get("boss")
                    rw = b.get("reward", "") if b else ""
                    if b and b["id"] not in s.beaten and rw in giver and (abs_ | {rw}) in cache and n in cache[abs_ | {rw}].nodes \
                            and not trapped(abs_ | {rw}, n, local):
                        res = False
                        break
                memo[k] = res
            return memo[k]
        traps, utraps, tonly = {}, {}, {}
        for abs_ in done:
            s = cache[abs_]
            home, term = s.back()
            for n in s.nodes:
                if trapped(abs_, n, False):
                    traps.setdefault(n, []).append(abs_)
                elif trapped(abs_, n, True):
                    utraps.setdefault(n, []).append(abs_)
                if n in term and n not in home:
                    tonly.setdefault(s.room_of(n), []).append(abs_)
        for n in sorted(traps, key=lambda n: order_ix[W.door[n][0]]):
            print("TRAP %s entered by %s: no walk back with %s" % (W.door[n][0], n, " or ".join(fmt_ab(x) for x in minimal(traps[n]))))
            problems.append("trap: %s entered by %s" % (W.door[n][0], n))
        if not traps:
            print("no traps: in every order, from every room, a walk leads back to R01 or to a terminal")
        for n in sorted(utraps, key=lambda n: order_ix[W.door[n][0]]):
            s = cache[minimal(utraps[n])[0]]
            print("uncertain trap %s entered by %s with %s: the way out of %s needs %s" % (
                W.door[n][0], n, " or ".join(fmt_ab(x) for x in minimal(utraps[n])), W.door[n][0], ",".join(sorted(s.feats[n])) or "?"))
        # what lifts it: the most abilities with which the walk back is still missing
        groups = {}
        for r, sets in tonly.items():
            groups.setdefault(tuple(maximal(sets)), []).append(r)
        if groups:
            print("walk back to R01 only by terminal travel (room: the most abilities with which this still happens):")
        for g, rr in sorted(groups.items(), key=lambda x: order_ix[x[1][0]]):
            print("  %s: %s" % (rs(rr), " or ".join(fmt_ab(x) for x in g)))
    X.close()
    print("\nexplored %d new room configurations (cache %s)" % (X.new, X.path if X.use_cache else "off"))
    print("%d problems" % len(problems))
    for p in problems:
        print(" -", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
