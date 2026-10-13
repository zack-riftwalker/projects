# Movement simulator for room validation: a close port of Player.update's movement (player.gd) and TileGrid collision.
# Used to search which doors / cells are reachable in a room with a given ability set.
import math

T = 16
RUN, ACC, DEC, AIR_ACC, AIR_DEC = 118.0, 1150.0, 1500.0, 840.0, 480.0
JUMP, G_UP, G_DOWN, MAXFALL = 300.0, 830.0, 1250.0, 310.0
COYOTE, BUFFER, WALL_SLIDE = 0.1, 0.12, 52.0
WJ_X, WJ_Y, WJ_LOCK = 165.0, 285.0, 0.15
DASH_SPEED, DASH_T, DJUMP = 320.0, 0.15, 272.0
DT = 1.0 / 60.0

E, SOLID, ONEWAY, SPU, SPD, CRACK, CRUMBLE, BA, BB, LIQ, GC, GA, DEAD, FIRE, THICK, PORT, WEB, MUTEX, CABLE = range(19)
CH = {"#": SOLID, "=": ONEWAY, "^": SPU, "v": SPD, "%": CRACK, "~": CRUMBLE, "1": BA, "2": BB, "w": LIQ,
      "!": GC, "&": GA, ";": DEAD, "N": FIRE, "0": THICK, "3": PORT, "h": WEB, "4": MUTEX, "5": CABLE}
# phase 4B (design values, see PLAN-metroidvania-phase4b2.md)
CURL_RANGE, CURL_SPEED, CURL_POP, CURL_EXIT_VX = 104.0, 400.0, 300.0, 210.0
SSH_HOLD, SSH_MAX = 0.3, 2


class Room:
    """rows: list of strings; doors: list of {side, a, b, open}; opts: which gates count as open."""
    def __init__(self, rows, doors, opts=None):
        self.h = len(rows)
        self.w = max(len(r) for r in rows)
        self.rows = [r.ljust(self.w) for r in rows]
        self.doors = doors
        o = opts or {}
        self.crack_open = o.get("crack_open", False)     # bash breaks cracks: treat as air
        self.thick_open = o.get("thick_open", False)
        self.gate_c = o.get("gate_c", False)
        self.gate_a = o.get("gate_a", False)
        self.fire_open = o.get("fire_open", False)
        self.liquid_y = o.get("liquid_y")                # px, or None
        self.ports_open = o.get("ports_open", True)      # optimistic: ports open (riding is checked by its own timed sim)
        self.webs_off = o.get("webs_off", False)
        self.hooks_rings = o.get("hooks_rings", False)   # boss:CRAWLER: scraper hooks `c` are GET rings
        self.mutex_open = o.get("mutex_open", True)      # phase 5A: mutex gates `4` (open while a key is active)
        self.cable_cut = o.get("cable_cut", False)       # phase 5A: spaghetti cables `5` (opus)
        self.pistons_solid = o.get("pistons_solid", False)
        self.gears = o.get("gears", [])                  # [{x, y, r, n}] cells; platforms 3 wide at 8 positions (optimistic)
        self.pistons = o.get("pistons", [])              # [{x, y, len, w}] the column under a housing `A`
        self.t = [[CH.get(c, E) for c in r] for r in self.rows]
        self.springs = []
        self.plats = []      # treated as one-way floors along their path (optimistic)
        self.rings = []
        for ty, r in enumerate(self.rows):
            for tx, c in enumerate(r):
                if c in "@j" or (c == "c" and self.hooks_rings):
                    self.rings.append((tx * T + 8.0, ty * T + 8.0))
                if c == "S":
                    self.springs.append((tx * T + 2, ty * T + 9, 12, 7))
                if c in "MVJ":
                    self.plats.append((tx, ty, c))
        self.extra_oneway = set()
        self.extra_solid = set()
        for g in self.gears:
            for k in range(8):
                a = k * math.pi / 4
                cx = g["x"] + g["r"] * math.cos(a)
                cy = g["y"] + g["r"] * math.sin(a)
                tx, ty = int(round(cx)), int(round(cy))
                for i in (-1, 0, 1):
                    if 0 <= ty < self.h and 0 <= tx + i < self.w:
                        self.extra_oneway.add((tx + i, ty))
        if self.pistons_solid:
            for pz in self.pistons:
                for j in range(1, pz["len"] + 1):
                    for i in range(pz.get("w", 1)):
                        self.extra_solid.add((pz["x"] + i, pz["y"] + j))
        for tx, ty, c in self.plats:
            r = self.rows[ty]
            if c in "MJ":
                end = None
                for i in range(tx + 1, len(r)):
                    if r[i] == "|":
                        end = i; break
                rng = range(tx, (end + 1) if end else tx + 3)
                for i in rng:
                    self.extra_oneway.add((i, ty))
            else:
                end = None
                for j in range(ty + 1, self.h):
                    if self.rows[j][tx] == "|":
                        end = j; break
                for j in range(ty, (end + 1) if end else ty + 1):
                    for i in range(tx, tx + 3):
                        self.extra_oneway.add((i, j))

    def door_open_at(self, side, idx):
        for d in self.doors:
            if d["side"] == side and d["a"] <= idx <= d["b"] and d.get("open", True):
                return d
        return None

    def tile(self, tx, ty):
        if ty < 0:
            return E if self.door_open_at("N", tx) else SOLID
        if tx < 0 or tx >= self.w:
            if ty < self.h and self.door_open_at("W" if tx < 0 else "E", ty):
                return E
            return SOLID
        if ty >= self.h:
            d = None
            for dd in self.doors:
                if dd["side"] == "S" and dd["a"] <= tx <= dd["b"]:
                    d = dd
            if d is not None and not d.get("open", True):
                return SOLID
            return E
        v = self.t[ty][tx]
        if v == E and (tx, ty) in self.extra_solid:
            return SOLID
        if v == E and (tx, ty) in self.extra_oneway:
            return ONEWAY
        return v

    def solid(self, tx, ty):
        v = self.tile(tx, ty)
        if v == SOLID:
            return True
        if v == CRACK:
            return not self.crack_open
        if v == THICK:
            return not self.thick_open
        if v == FIRE:
            return not self.fire_open
        if v == GC:
            return not self.gate_c
        if v == GA:
            return not self.gate_a
        if v in (CRUMBLE, BA, BB):
            return True
        if v == PORT:
            return not self.ports_open
        if v == MUTEX:
            return not self.mutex_open
        if v == CABLE:
            return not self.cable_cut
        return False

    def box_hits(self, x, y, w, h):
        for ty in range(math.floor(y / T), math.floor((y + h - 0.001) / T) + 1):
            for tx in range(math.floor(x / T), math.floor((x + w - 0.001) / T) + 1):
                if self.solid(tx, ty):
                    return True
        return False


class P:
    __slots__ = ("x", "y", "w", "h", "vx", "vy", "on_ground", "coyote", "jump_buf", "jumping", "wall_dir", "wall_coy",
                 "last_wall", "lock", "dash_t", "dash_cd", "can_dash", "dash_dx", "dash_dy", "can_double", "drop_t", "face",
                 "zip", "zip_dx", "reuse", "push_t", "blocked")

    def __init__(self, x, y):
        self.x, self.y, self.w, self.h = x, y, 10.0, 10.0
        self.vx = self.vy = 0.0
        self.on_ground = False
        self.coyote = self.jump_buf = 0.0
        self.jumping = False
        self.wall_dir = self.last_wall = 0
        self.wall_coy = self.lock = 0.0
        self.dash_t = self.dash_cd = 0.0
        self.can_dash = True
        self.dash_dx, self.dash_dy = 1.0, 0.0
        self.can_double = True
        self.drop_t = 0.0
        self.face = 1.0
        self.zip = None
        self.zip_dx = 0.0
        self.reuse = {}
        self.push_t = 0.0
        self.blocked = 0


def approach(v, t, s):
    return min(v + s, t) if v < t else max(v - s, t)


def move_x(rm, e, dx):
    e.x += dx
    if dx == 0:
        return 0
    y0, y1 = math.floor(e.y / T), math.floor((e.y + e.h - 0.001) / T)
    if dx > 0:
        tx = math.floor((e.x + e.w - 0.001) / T)
        for ty in range(y0, y1 + 1):
            if rm.solid(tx, ty):
                e.x = tx * T - e.w
                return 1
    else:
        tx = math.floor(e.x / T)
        for ty in range(y0, y1 + 1):
            if rm.solid(tx, ty):
                e.x = (tx + 1) * T
                return -1
    return 0


def move_y(rm, e, dy, no_oneway=False):
    prev_bottom = e.y + e.h
    e.y += dy
    if dy == 0:
        return 0
    x0, x1 = math.floor(e.x / T), math.floor((e.x + e.w - 0.001) / T)
    if dy > 0:
        ty = math.floor((e.y + e.h - 0.001) / T)
        for tx in range(x0, x1 + 1):
            if rm.solid(tx, ty) or ((not no_oneway) and rm.tile(tx, ty) == ONEWAY and prev_bottom <= ty * T + 0.01):
                e.y = ty * T - e.h
                return 1
    else:
        ty = math.floor(e.y / T)
        for tx in range(x0, x1 + 1):
            if rm.solid(tx, ty):
                e.y = (ty + 1) * T
                return -1
    return 0


def hazard(rm, p):
    x0, x1 = math.floor((p.x + 1) / T), math.floor((p.x + p.w - 1) / T)
    y0, y1 = math.floor((p.y + 1) / T), math.floor((p.y + p.h - 1) / T)
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            t = rm.tile(tx, ty)
            if t == SPU and p.y + p.h > ty * T + 9 and p.x + p.w > tx * T + 2 and p.x < tx * T + 14:
                return "spike"
            if t == SPD and p.y < ty * T + 7 and p.x + p.w > tx * T + 2 and p.x < tx * T + 14:
                return "spike"
            if t == LIQ and p.y + p.h > ty * T + 6:
                return "liq"
            if t == WEB and not rm.webs_off and p.x + p.w > tx * T + 3 and p.x < tx * T + 13 and p.y + p.h > ty * T + 3 and p.y < ty * T + 13:
                return "web"
    if rm.liquid_y is not None and p.y + p.h > rm.liquid_y + 5:
        return "liq"
    if p.y > rm.h * T + 24:
        return "pit"
    return ""


def line_clear(rm, x0, y0, x1, y1):
    n = max(1, int(math.ceil(max(abs(x1 - x0), abs(y1 - y0)) / 8.0)))
    for i in range(1, n):
        k = i / n
        if rm.solid(math.floor((x0 + (x1 - x0) * k) / T), math.floor((y0 + (y1 - y0) * k) / T)):
            return False
    return True


def pick_ring(rm, p, mx):
    cx, cy = p.x + p.w / 2, p.y + p.h / 2
    cands = []
    for i, (rx, ry) in enumerate(rm.rings):
        if p.reuse.get("last") == i:          # the ring just used: not again until Clawd lands or uses another
            continue
        dx, dy = rx - cx, ry - cy
        dist = math.hypot(dx, dy)
        if dist > CURL_RANGE or not line_clear(rm, cx, cy, rx, ry):
            continue
        cands.append((dist, i, dx))
    if not cands:
        return None
    side = [c for c in cands if mx == 0 or c[2] * mx > 0 or abs(c[2]) < 12]
    pool = side if side else cands
    return min(pool)[1]


def curl_step(rm, p):
    rx, ry = rm.rings[p.zip]
    cx, cy = p.x + p.w / 2, p.y + p.h / 2
    dx, dy = rx - cx, ry - cy
    dist = math.hypot(dx, dy)
    if dist <= CURL_SPEED * DT + 0.5:
        hx = move_x(rm, p, dx)
        hy = move_y(rm, p, dy, True)
        p.vy = -CURL_POP
        p.vx = (1 if p.zip_dx > 0 else -1) * CURL_EXIT_VX if abs(p.zip_dx) > 4 else 0.0
        p.can_double = True
        p.can_dash = True
        p.jumping = False
        p.reuse["last"] = p.zip
        p.zip = None
        p.on_ground = False
        return
    vx, vy = dx / dist * CURL_SPEED, dy / dist * CURL_SPEED
    bx = move_x(rm, p, vx * DT)
    by = move_y(rm, p, vy * DT, True)
    if bx or by:
        p.blocked += 1
        if p.blocked >= 2:
            p.zip = None
            p.vx, p.vy = 0.0, 0.0
    else:
        p.blocked = 0


def fire_ahead(rm, p, d):
    """the body touches FIRE cells on side d (all of its rows that are blocked are FIRE)"""
    x = p.x + p.w + 0.5 if d > 0 else p.x - 0.5
    tx = math.floor(x / T)
    rows = range(math.floor(p.y / T), math.floor((p.y + p.h - 0.001) / T) + 1)
    kinds = [rm.tile(tx, ty) for ty in rows]
    return any(k == FIRE for k in kinds) and all(k in (FIRE, E, DEAD, WEB) for k in kinds)


def ssh_tunnel(rm, p, d):
    x0 = p.x
    for k in range(1, SSH_MAX + 2):
        if d > 0:
            nx = (math.floor((p.x + p.w + 0.5) / T) + k) * T + 1
        else:
            nx = (math.floor((p.x - 0.5) / T) - k + 1) * T - p.w - 1
        rows = range(math.floor(p.y / T), math.floor((p.y + p.h - 0.001) / T) + 1)
        span = range(math.floor(min(x0, nx) / T), math.floor((max(x0, nx) + p.w) / T) + 1)
        if any(rm.tile(tx, ty) == SOLID for tx in span for ty in rows):
            return False
        if not rm.box_hits(nx, p.y, p.w, p.h) and not any(rm.tile(tx, ty) == FIRE for tx in range(math.floor(nx / T), math.floor((nx + p.w - 0.001) / T) + 1) for ty in rows):
            p.x = nx
            return True
    return False


def step(rm, p, inp, ab):
    """inp: dict mx (-1/0/1), my (-1 up / 1 down), jump (held), jp (pressed), dash (pressed), sp (special pressed). ab: set of abilities."""
    mx, my = inp.get("mx", 0), inp.get("my", 0)
    if p.on_ground:
        p.reuse.pop("last", None)
    if inp.get("sp") and "curl" in ab and p.zip is None:
        i = pick_ring(rm, p, mx)
        if i is not None:
            p.zip = i
            p.zip_dx = rm.rings[i][0] - (p.x + p.w / 2)
            p.blocked = 0
            p.dash_t = 0
    if p.zip is not None:
        if inp.get("dash"):
            p.zip = None
        else:
            curl_step(rm, p)
            p.wall_dir = 0
            return
    if "ssh" in ab and mx != 0 and p.dash_t <= 0 and fire_ahead(rm, p, mx):
        p.push_t += DT
        if p.push_t >= SSH_HOLD - 1e-6:
            p.push_t = 0
            ssh_tunnel(rm, p, mx)
    else:
        p.push_t = 0
    p.lock = max(0.0, p.lock - DT)
    if p.dash_cd > 0:
        p.dash_cd -= DT
    if p.drop_t > 0:
        p.drop_t -= DT
    if mx != 0 and p.dash_t <= 0:
        p.face = mx
    if inp.get("dash") and "bash" in ab and p.can_dash and p.dash_cd <= 0:
        ddx, ddy = mx, my
        if p.on_ground and ddy > 0:
            ddy = 0
        if ddx == 0 and ddy == 0:
            ddx = p.face
        n = math.sqrt(ddx * ddx + ddy * ddy)
        p.dash_dx, p.dash_dy = ddx / n, ddy / n
        p.dash_t = DASH_T
        p.dash_cd = DASH_T
        p.can_dash = False
        p.jumping = False
    was_ground = p.on_ground
    if p.dash_t > 0:
        p.dash_t -= DT
        p.vx = p.dash_dx * DASH_SPEED
        p.vy = p.dash_dy * DASH_SPEED
        if p.dash_t <= 0:
            p.vx = p.dash_dx * RUN * 1.1
            p.vy = p.dash_dy * 130.0 if p.dash_dy < 0 else p.dash_dy * RUN
    else:
        target = mx * RUN
        acc = (ACC if mx != 0 else DEC) if p.on_ground else (AIR_ACC if mx != 0 else AIR_DEC)
        if p.lock > 0 and not p.on_ground:
            acc *= 0.2
        if abs(p.vx) > RUN and (1 if p.vx > 0 else -1) == mx:
            acc = 260.0
        p.vx = approach(p.vx, target, acc * DT)
        gr = G_UP if p.vy < 0 else G_DOWN
        if abs(p.vy) < 38 and inp.get("jump") and not p.on_ground:
            gr *= 0.55
        p.vy += gr * DT
        if not p.on_ground and p.wall_dir != 0 and mx == p.wall_dir and p.vy > 0:
            p.vy = min(p.vy, WALL_SLIDE)
        if p.vy > MAXFALL:
            p.vy = MAXFALL
    if p.on_ground:
        p.coyote = COYOTE
    else:
        p.coyote -= DT
    if inp.get("jp"):
        p.jump_buf = BUFFER
    elif p.jump_buf > 0:
        p.jump_buf -= DT
    if p.wall_dir != 0 and not p.on_ground:
        p.wall_coy = 0.09
        p.last_wall = p.wall_dir
    else:
        p.wall_coy -= DT
    if p.jump_buf > 0:
        if my > 0 and p.on_ground and on_oneway(rm, p):
            p.drop_t = 0.2
            p.jump_buf = 0
            p.on_ground = False
            p.coyote = 0
            p.y += 1
        elif p.coyote > 0:
            p.vy = -JUMP
            p.coyote = 0
            p.jump_buf = 0
            p.jumping = True
            p.on_ground = False
            p.dash_t = 0
        elif p.wall_coy > 0 and p.dash_t <= 0:
            d = p.last_wall
            p.vx = -d * WJ_X
            p.vy = -WJ_Y
            p.lock = WJ_LOCK
            p.face = -d
            p.jumping = True
            p.jump_buf = 0
            p.wall_coy = 0
        elif "sudo" in ab and p.can_double and p.dash_t <= 0:
            p.vy = -DJUMP
            p.can_double = False
            p.jumping = True
            p.jump_buf = 0
    if p.jumping and p.vy < 0 and not inp.get("jump"):
        p.vy *= 0.45
        p.jumping = False
    if p.vy >= 0:
        p.jumping = False
    prev_bottom = p.y + p.h
    hx = move_x(rm, p, p.vx * DT)
    if hx != 0:
        if p.dash_t > 0 and p.dash_dy == 0:
            p.dash_t = min(p.dash_t, 0.02)
        p.vx = 0
    hy = move_y(rm, p, p.vy * DT, p.drop_t > 0)
    if hy < 0:
        slipped = False
        for o in range(1, 5):
            for s in (1, -1):
                if not rm.box_hits(p.x + s * o, p.y - 2, p.w, p.h):
                    p.x += s * o
                    slipped = True
                    break
            if slipped:
                break
        if not slipped:
            p.vy = 0
            p.jumping = False
    p.on_ground = hy > 0
    if p.on_ground:
        p.vy = 0
        p.can_dash = True
        p.can_double = True
    # springs
    for (sx, sy, sw, sh) in rm.springs:
        if p.vy >= 0 and p.x < sx + sw and p.x + p.w > sx and p.y < sy + sh and p.y + p.h > sy and p.dash_t <= 0:
            p.vy = -470.0
            p.jumping = False
            p.can_dash = True
            p.can_double = True
            p.on_ground = False
            p.dash_t = 0
    p.wall_dir = 0
    if not p.on_ground:
        if rm.box_hits(p.x + p.w, p.y + 2, 2, p.h - 4):
            p.wall_dir = 1
        elif rm.box_hits(p.x - 2, p.y + 2, 2, p.h - 4):
            p.wall_dir = -1


def on_oneway(rm, p):
    ty = math.floor((p.y + p.h + 1) / T)
    anyo = False
    for tx in range(math.floor(p.x / T), math.floor((p.x + p.w - 0.01) / T) + 1):
        if rm.solid(tx, ty):
            return False
        if rm.tile(tx, ty) == ONEWAY:
            anyo = True
    return anyo


def door_exit(rm, p):
    """The door the player is crossing (new rule: W/E centre past the edge; N head above 0 going up; S feet below ph)."""
    mid_x = p.x + p.w / 2
    mid_row = math.floor((p.y + p.h / 2) / T)
    col = math.floor(mid_x / T)
    if mid_x < 0:
        d = rm.door_open_at("W", mid_row)
        return ("W", d) if d else None
    if mid_x > rm.w * T:
        d = rm.door_open_at("E", mid_row)
        return ("E", d) if d else None
    if p.y < 0 and p.vy < 0:
        d = rm.door_open_at("N", col)
        return ("N", d) if d else None
    if p.y + p.h > rm.h * T and p.vy >= 0:
        for d in rm.doors:
            if d["side"] == "S" and d["a"] <= col <= d["b"] and d.get("open", True):
                return ("S", d)
    return None
