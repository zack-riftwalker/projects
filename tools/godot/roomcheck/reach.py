# Reachability search over a room with the movement simulator: which doors (and which standing cells) a player reaches
# from an entry, with a given ability set. Optimistic in a few places (moving platforms as fixed floors, crumbles solid).
import math
from sim import Room, P, step, hazard, door_exit, T, JUMP

MAXF = 170


def entry_state(rm, side, d, ab):
    """Where the room manager puts a player coming through door d (side = the side of THIS room's door)."""
    w = rm.w * T
    if side in ("W", "E"):
        y = (d["b"] + 1) * T - 10.0
        x = 1.0 if side == "W" else w - 11.0
        return [(x, y, 0.0, 0.0)]
    cx = (d["a"] + d["b"] + 1) / 2 * T - 5
    if side == "S":      # coming up from the room below: bottom edge, an upward push
        return [(cx + o, rm.h * T - 11.0, 0.0, -JUMP) for o in (-24, -8, 8, 24) if d["a"] * T <= cx + o + 5 <= (d["b"] + 1) * T]
    return [(cx + o, 1.0, 0.0, 60.0) for o in (-24, -8, 8, 24) if d["a"] * T <= cx + o + 5 <= (d["b"] + 1) * T]


def run(rm, ab, x, y, vx, vy, policy, ground=False):
    """policy(f, p) -> input dict. Returns ('land', p) | ('door', side, d, p) | ('haz', kind) | ('none', p)."""
    p = P(x, y)
    p.vx, p.vy = vx, vy
    p.on_ground = ground
    air = 0
    for f in range(MAXF):
        inp = policy(f, p)
        step(rm, p, inp, ab)
        de = door_exit(rm, p)
        if de:
            return ("door", de[0], de[1], p)
        hz = hazard(rm, p)
        if hz:
            return ("haz", hz, None, p)
        if p.on_ground:
            if air >= 2:
                return ("land", None, None, p)
            air = 0
        else:
            air += 1
    return ("none", None, None, p)


def key(p):
    return (math.floor((p.x + 5) / T), round(p.y + p.h))


def programs(ab):
    progs = []
    for d in (-1, 0, 1):
        for hold in (8, 40):
            progs.append(("jump", d, hold, None))
        progs.append(("walk", d, 0, None))
        progs.append(("drop", d, 0, None))
        if "sudo" in ab:
            for k in (14, 22, 30):
                progs.append(("djump", d, 40, k))
        if "bash" in ab:
            for k in (5, 18):
                for dd in ((0, -1), (-1, -1), (1, -1), (-1, 0), (1, 0)):
                    progs.append(("dash", d, 40, (k, dd)))
            if "sudo" in ab:
                for dd in ((0, -1), (-1, -1), (1, -1)):
                    progs.append(("djdash", d, 40, dd))
        progs.append(("wall", d, 40, "toward"))
        progs.append(("wall", d, 40, "away"))
    return progs


def policy_for(prog):
    kind, d, hold, extra = prog
    state = {"last": -99, "wd": 0}

    def pol(f, p):
        inp = {"mx": d}
        if kind == "walk":
            return inp
        if kind == "drop":
            inp["my"] = 1 if f < 4 else 0
            inp["jp"] = f == 0
            inp["jump"] = f < 4
            return inp
        inp["jump"] = f < hold
        inp["jp"] = f == 0
        if kind == "djump" and f == extra:
            inp["jp"] = True
            inp["jump"] = True
        if kind == "dash" and f == extra[0]:
            inp["dash"] = True
            inp["mx"], inp["my"] = extra[1]
        if kind == "djdash":
            if f == 24:
                inp["jp"] = True
                inp["jump"] = True
            if f == 44:
                inp["dash"] = True
                inp["mx"], inp["my"] = extra
        if kind == "wall":
            if p.wall_dir != 0 and not p.on_ground and f - state["last"] > 8:
                state["last"] = f
                state["wd"] = p.wall_dir
                inp["jp"] = True
                inp["jump"] = True
            if state["wd"] != 0 and f - state["last"] > 9:
                inp["mx"] = state["wd"] if extra == "toward" else -state["wd"]
                inp["jump"] = True
            elif state["wd"] != 0:
                inp["mx"] = -state["wd"]
                inp["jump"] = True
        return inp
    return pol


def explore(rm, ab, starts, max_states=4000):
    """starts: list of (x, y, vx, vy). Returns (doors reached {(side,a)}, standing keys reached)."""
    progs = programs(ab)
    seen = {}
    queue = []
    doors = set()
    hazards = 0
    # the entry flight itself
    for (x, y, vx, vy) in starts:
        for d in (0, -1, 1):
            p = P(x, y)
            p.vx, p.vy = vx, vy
            for f in range(MAXF):
                step(rm, p, {"mx": d, "jump": True}, ab)
                de = door_exit(rm, p)
                if de and f > 2:
                    doors.add((de[0], de[1]["a"]))
                    break
                if hazard(rm, p):
                    break
                if p.on_ground:
                    k = key(p)
                    if k not in seen:
                        seen[k] = (p.x, p.y)
                        queue.append((p.x, p.y))
                    break
    while queue and len(seen) < max_states:
        x, y = queue.pop()
        for prog in progs:
            res = run(rm, ab, x, y, 0.0, 0.0, policy_for(prog), ground=True)
            _take(res, seen, queue, doors)
        # walking: every cell of this floor in both directions (and off its ends)
        for d in (-1, 1):
            p = P(x, y)
            p.on_ground = True
            for f in range(400):
                step(rm, p, {"mx": d}, ab)
                de = door_exit(rm, p)
                if de:
                    doors.add((de[0], de[1]["a"]))
                    break
                if hazard(rm, p):
                    break
                if not p.on_ground:
                    res = run(rm, ab, p.x, p.y, p.vx, p.vy, lambda f2, q, d=d: {"mx": d})
                    _take(res, seen, queue, doors)
                    break
                k = key(p)
                if k not in seen:
                    seen[k] = (p.x, p.y)
                    if k[0] % 2 == 0:
                        queue.append((p.x, p.y))
                if p.vx == 0 and f > 5:
                    break
    return doors, seen


def _take(res, seen, queue, doors):
    kind, side, d, p = res
    if kind == "door":
        doors.add((side, d["a"]))
    elif kind == "land":
        k = key(p)
        if k not in seen:
            seen[k] = (p.x, p.y)
            queue.append((p.x, p.y))
