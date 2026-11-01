#!/usr/bin/env python3
# INFINITE LOOP v3 (doc 18): first pixel sketches, made from code so they can be redrawn after a decision changes.
#   python3 docs/metroidvania/18-loop-data/sketch.py      -> loop_body.png, loop_arena.png next to this file
# The body is drawn at its game size (head 40x32, link 16x16, 16 px tiles) and scaled up with nearest-neighbour, so every pixel shows.
# Only a sketch for Zakaria to judge: if he draws the character himself, his pixel art becomes the sprite (boss-design rule).
import json
import math
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# THREAD TOWER palette (godot/assets/theme/w4.json) and the boss's own palette against it
TOWER = {"base": "#a8793a", "dark": "#5f3d1e", "lite": "#dcae5e", "cap": "#f3d58a", "capLo": "#6b4520",
         "plat": "#7a4a5a", "platHi": "#d98a8a", "platLo": "#3c1f33", "accent": "#ff7a59", "glow": "#ffe2a0"}
LOOP = {"vd0": "#0f2a27", "vd1": "#1d4a44", "vd2": "#2f7f6a", "vd3": "#5fc0a0", "vd4": "#b8f0d8",
        "rivet": "#dcae5e", "eye": "#e8f4ee", "ink": "#1b1226", "true": "#b8f0d8", "false": "#ff4d5a",
        "opus": "#9b6bff", "opusHi": "#d6c2ff", "heat": "#ff7a59", "heatHi": "#ffd0a0"}
CLAWD = "#e8784a"
BG = "#2a1a10"

# 3x5 pixel font, only the glyphs the sketch needs
FONT = {
    "t": ["010", "111", "010", "010", "011"], "r": ["000", "101", "110", "100", "100"], "u": ["000", "101", "101", "101", "111"],
    "e": ["000", "010", "111", "100", "011"], "f": ["011", "100", "111", "100", "100"], "a": ["000", "111", "011", "101", "111"],
    "l": ["110", "010", "010", "010", "111"], "s": ["011", "100", "010", "001", "110"], "i": ["010", "000", "010", "010", "010"],
    "+": ["000", "010", "111", "010", "000"], "0": ["111", "101", "101", "101", "111"], "4": ["101", "101", "111", "001", "001"],
    "9": ["111", "101", "111", "001", "111"], "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    " ": ["000", "000", "000", "000", "000"], "(": ["01", "10", "10", "10", "01"], ")": ["10", "01", "01", "01", "10"],
    "{": ["011", "010", "110", "010", "011"], "w": ["000", "101", "101", "111", "101"], "h": ["100", "100", "111", "101", "101"],
}


def ptext(px, x, y, s, col):
    for ch in s:
        g = FONT.get(ch, FONT[" "])
        for j, row in enumerate(g):
            for i, b in enumerate(row):
                if b == "1":
                    px.point((x + i, y + j), fill=col)
        x += len(g[0]) + 1


def link_sprite(kind="p1", hot=0.0, small=False):
    """One chain link, 16x16 (12x12 small): verdigris plate, light top, dark bottom, brass rivets."""
    n = 12 if small else 16
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    body = {"p1": LOOP["vd2"], "p2": LOOP["vd2"], "p3": LOOP["vd2"], "down": LOOP["vd1"]}[kind]
    d.rounded_rectangle([0, 1, n - 1, n - 2], radius=4, fill=C(LOOP["vd0"]))
    d.rounded_rectangle([1, 2, n - 2, n - 3], radius=3, fill=C(body))
    d.line([3, 3, n - 4, 3], fill=C(LOOP["vd3"]))
    d.line([2, 4, 2, n - 6], fill=C(LOOP["vd3"]))
    d.line([3, n - 4, n - 4, n - 4], fill=C(LOOP["vd1"]))
    h = n // 2
    d.rectangle([h - 2, h - 2, h + 1, h + 1], fill=C(LOOP["vd0"]))       # the hole the next link goes through
    d.point((3, h), fill=C(LOOP["rivet"]))
    d.point((n - 4, h), fill=C(LOOP["rivet"]))
    if kind == "p2":
        d.rounded_rectangle([0, 1, n - 1, n - 2], radius=4, outline=C(LOOP["opus"]))
        d.point((h, 2), fill=C(LOOP["opusHi"]))
    if kind == "p3" or hot > 0:
        d.rectangle([0, h - 1, 1, h], fill=C(LOOP["heat"]))
        d.rectangle([n - 2, h - 1, n - 1, h], fill=C(LOOP["heat"]))
        d.point((h - 1, h - 1), fill=C(LOOP["heatHi"]))
    return im


def head_sprite(pose="idle", plate="true", kind="p1"):
    """The head, 40x32, facing right: a brass-riveted verdigris skull, one dial eye, the condition plate on the brow."""
    im = Image.new("RGBA", (40, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o, b, hi, lo = C(LOOP["vd0"]), C(LOOP["vd2"]), C(LOOP["vd3"]), C(LOOP["vd1"])
    if kind == "down":
        b = C(LOOP["vd1"])
    open_j = pose in ("tell", "lunge")
    # skull
    skull = [(2, 12), (8, 7), (22, 6), (33, 9), (39, 14), (38, 17), (26, 18), (4, 20)]
    d.polygon(skull, fill=o)
    d.polygon([(3, 12), (9, 8), (22, 7), (32, 10), (37, 14), (36, 16), (26, 17), (5, 19)], fill=b)
    d.line([(9, 9), (22, 8), (31, 11)], fill=hi)
    # lower jaw: closed sits under the skull; open swings down
    if open_j:
        jaw = [(6, 20), (24, 19), (36, 27), (33, 30), (20, 27), (5, 24)]
        d.polygon(jaw, fill=o)
        d.polygon([(7, 21), (23, 20), (34, 27), (32, 29), (20, 26), (6, 23)], fill=lo)
        d.polygon([(26, 18), (38, 17), (34, 26), (24, 20)], fill=C(LOOP["ink"]))  # the open mouth
        for tx in (28, 32, 36):
            d.line([(tx, 17), (tx - 1, 19)], fill=C(LOOP["rivet"]))
        for tx in (27, 31):
            d.line([(tx, 24), (tx + 1, 22)], fill=C(LOOP["rivet"]))
    else:
        d.polygon([(4, 20), (26, 18), (38, 17), (34, 22), (8, 24)], fill=o)
        d.polygon([(6, 20), (26, 19), (35, 18), (32, 21), (9, 23)], fill=lo)
        for tx in (29, 33):
            d.point((tx, 18), fill=C(LOOP["rivet"]))
    # rivets along the skull seam
    for rx in (6, 12, 18):
        d.point((rx, 16), fill=C(LOOP["rivet"]))
    # the dial eye (a counter): white face, ink hand; lit mint in a cue
    ex, ey = 25, 12
    face = C(LOOP["vd4"]) if pose == "tell" else C(LOOP["eye"])
    d.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=o)
    d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=face)
    if kind == "down":
        d.line([ex - 2, ey - 2, ex + 2, ey + 2], fill=C(LOOP["ink"]))
        d.line([ex - 2, ey + 2, ex + 2, ey - 2], fill=C(LOOP["ink"]))
    else:
        d.line([ex, ey, ex + (2 if pose != "tell" else 0), ey - 2], fill=C(LOOP["ink"]))
    # the condition plate on the brow
    pc = C(LOOP["false"]) if plate == "false" else C(LOOP["true"])
    d.rectangle([5, 0, 22, 7], fill=o)
    d.rectangle([6, 1, 21, 6], fill=C(LOOP["ink"]))
    ptext(d, 7 if plate != "false" else 6, 1, plate[:4] if plate != "false" else "fals", pc)
    if pose == "tell":
        d.rectangle([5, 0, 22, 7], outline=C(LOOP["vd4"]))
    if kind == "p3":
        d.line([(14, 1), (16, 4), (15, 6)], fill=C(LOOP["heat"]))   # the cracked plate
        d.point((12, 12), fill=C(LOOP["heat"]))
        d.point((20, 15), fill=C(LOOP["heat"]))
    if kind == "p2":
        d.line([(9, 8), (22, 7), (32, 10)], fill=C(LOOP["opusHi"]))
    return im


def paste_c(canvas, sp, cx, cy, ang=0.0):
    if ang:
        sp = sp.rotate(-math.degrees(ang), resample=Image.NEAREST, expand=True)
    canvas.alpha_composite(sp, (int(round(cx - sp.width / 2)), int(round(cy - sp.height / 2))))


def resample(curve, n, step):
    """n points at equal arc length `step` along a dense polyline (the body follows the head's path in the game the same way)."""
    out, acc = [curve[0]], 0.0
    for (x0, y0), (x1, y1) in zip(curve, curve[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        while acc + seg >= step and len(out) < n:
            t = (step - acc) / seg
            x0, y0 = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            out.append((x0, y0))
            seg = math.hypot(x1 - x0, y1 - y0)
            acc = 0.0
        acc += seg
    return out


def chain(canvas, pts, kind="p1", head_pose="idle", plate="true", small=False, head_dir=None):
    """pts: link centres from the tail to the neck. The head sits after the last link and faces along the last step,
    snapped to 45 degrees (pixel art is drawn in 8 directions, never rotated freely)."""
    d = ImageDraw.Draw(canvas)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):          # the pins between links
        d.line([x0, y0, x1, y1], fill=C(LOOP["vd0"]), width=5)
        d.line([x0, y0, x1, y1], fill=C(LOOP["rivet"]), width=1)
    for (x, y) in pts:
        paste_c(canvas, link_sprite(kind, small=small), x, y)
    if head_dir is None:
        (x0, y0), (x1, y1) = pts[-2], pts[-1]
        head_dir = math.atan2(y1 - y0, x1 - x0)
    a = round(head_dir / (math.pi / 4)) * (math.pi / 4)
    hx, hy = pts[-1][0] + math.cos(a) * 20, pts[-1][1] + math.sin(a) * 20
    hs = head_sprite(head_pose, plate, kind)
    if math.cos(a) < -1e-6:
        hs = hs.transpose(Image.FLIP_LEFT_RIGHT)
        a = a - math.pi
    paste_c(canvas, hs, hx, hy, a)


def clawd(canvas, x, y, col=CLAWD):
    d = ImageDraw.Draw(canvas)
    d.rectangle([x, y + 3, x + 13, y + 15], fill=C("#1b1226"))
    d.rectangle([x + 1, y + 4, x + 12, y + 14], fill=C(col))
    d.rectangle([x - 2, y + 7, x, y + 10], fill=C(col))
    d.rectangle([x + 13, y + 7, x + 15, y + 10], fill=C(col))
    d.point((x + 4, y + 7), fill=C("#1b1226"))
    d.point((x + 9, y + 7), fill=C("#1b1226"))


CW, CH, FY = 210, 170, 150      # one pose per cell (game pixels); FY = floor line


def cell():
    cv = Image.new("RGBA", (CW, CH), C(BG))
    d = ImageDraw.Draw(cv)
    d.rectangle([0, FY, CW, CH], fill=C(TOWER["dark"]))
    d.line([0, FY, CW, FY], fill=C(TOWER["lite"]))
    return cv


def ring(cx, cy, n, step=14, head_len=44, a0=-90.0):
    """An ouroboros: n links from the tail around to the neck; the radius is chosen so the head (head_len px) closes the gap and bites the tail."""
    r = ((n - 1) * step + head_len) / (2 * math.pi)
    gap = head_len / r
    a0r = math.radians(a0) + gap / 2
    dense = [(cx + r * math.cos(a0r + t / 600 * (2 * math.pi - gap)), cy + r * math.sin(a0r + t / 600 * (2 * math.pi - gap))) for t in range(601)]
    return resample(dense, n, step)


def pose_idle():
    cv = cell()
    pts = ring(96, 74, 14)
    chain(cv, pts, "p1", "idle", head_dir=0.0)
    clawd(cv, 176, FY - 16)
    return cv


def pose_tell():
    cv = cell()
    dense = [(30 + 100 * t / 400 + 22 * math.sin(t / 400 * 2.2 * math.pi), 140 - 95 * t / 400 + 10 * math.sin(t / 400 * 3 * math.pi)) for t in range(401)]
    pts = resample(dense, 12, 14)
    chain(cv, pts, "p1", "tell", head_dir=math.radians(-20))
    clawd(cv, 180, FY - 16)
    return cv


def pose_lunge():
    cv = cell()
    dense = [(4 + 150 * t / 400, 70 + 30 * t / 400) for t in range(401)]
    pts = resample(dense, 10, 14)
    chain(cv, pts, "p1", "lunge")
    d = ImageDraw.Draw(cv)
    for k in range(3):
        d.line([20, 52 + k * 8, 60, 58 + k * 8], fill=C(LOOP["vd3"], 150))
    clawd(cv, 186, FY - 16)
    return cv


def pose_p2():
    cv = cell()
    pts = ring(100, 74, 14)
    chain(cv, pts, "p2", "idle", head_dir=0.0)
    inner = [(100 + 16 * math.cos(k * math.pi / 3), 74 + 16 * math.sin(k * math.pi / 3)) for k in range(6)]
    for x, y in inner:
        paste_c(cv, link_sprite("p2", small=True), x, y)
    return cv


def pose_p3():
    cv = cell()
    dense = [(30 + 120 * t / 400, 120 - 70 * math.sin(t / 400 * math.pi * 1.2)) for t in range(401)]
    pts = resample(dense, 8, 14)
    chain(cv, pts, "p3", "tell")
    for x, y, a in ((150, FY - 6, 0.6), (168, FY - 7, -0.4)):
        paste_c(cv, link_sprite("p3"), x, y, a)
    return cv


def pose_break():
    cv = cell()
    pts = [(10 + k * 13, FY - 8) for k in range(12)]
    chain(cv, pts, "down", "idle", "false", head_dir=0.0)
    clawd(cv, 60, FY - 40)
    return cv


def pose_frozen():
    cv = cell()
    dense = [(120 - 40 * t / 400 + 14 * math.sin(t / 400 * 4), FY - 6 - 100 * t / 400) for t in range(401)]
    pts = resample(dense, 8, 14)
    chain(cv, pts, "p1", "idle", head_dir=math.radians(-45))
    d = ImageDraw.Draw(cv)
    d.rectangle([60, 2, 150, FY - 1], outline=C("#7cc4ff", 160))
    clawd(cv, 96, 72)
    return cv


def palette_strip():
    cv = Image.new("RGBA", (CW * 3, 40), C(BG))
    d = ImageDraw.Draw(cv)
    x = 6
    for name, h in TOWER.items():
        d.rectangle([x, 6, x + 18, 24], fill=C(h))
        x += 21
    x += 12
    for name in ("vd0", "vd1", "vd2", "vd3", "vd4", "rivet", "eye", "true", "false", "opus", "opusHi", "heat", "heatHi"):
        d.rectangle([x, 6, x + 18, 24], fill=C(LOOP[name]))
        x += 21
    d.rectangle([x + 8, 6, x + 26, 24], fill=C(CLAWD))
    return cv


def write_body():
    S = 3
    poses = [(pose_idle, "1 idle: ouroboros, it bites its own tail"), (pose_tell, "2 lunge tell: S-coil, jaw open, eye + plate lit"),
             (pose_lunge, "3 lunge (2 damage)"), (pose_p2, "4 phase 2: escalating (opus violet) + nested ring"),
             (pose_p3, "5 phase 3: short (HP = length), hot joints, cracked plate"), (pose_break, "6 BREAK: condition false, lies on the floor"),
             (pose_frozen, "7 frozen by breakpoint: a walkway to the plate")]
    cols = 3
    rows = (len(poses) + cols - 1) // cols
    LBL = 34
    sheet = Image.new("RGBA", (CW * S * cols, 40 + rows * (CH * S + LBL) + 40 * S + 40), C("#120b06"))
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), "INFINITE LOOP v3 - body sketch, game pixels x3 (head 40x32, links 16x16; Clawd 16 px for scale)", fill=C("#ffffff"), font=font(22))
    for k, (fn, label) in enumerate(poses):
        cx, cy = (k % cols) * CW * S, 40 + (k // cols) * (CH * S + LBL)
        sheet.alpha_composite(fn().resize((CW * S, CH * S), Image.NEAREST), (cx, cy))
        d.rectangle([cx, cy, cx + CW * S - 1, cy + CH * S - 1], outline=C("#120b06"), width=3)
        d.text((cx + 10, cy + CH * S + 6), label, fill=C("#ffe2a0"), font=font(18))
    # the last row's free cells hold the palette
    p = palette_strip()
    py = 40 + rows * (CH * S + LBL)
    sheet.alpha_composite(p.resize((p.width * S, p.height * S), Image.NEAREST), (0, py))
    d.text((10, py + 40 * S + 4), "tower palette (w4.json)   |   LOOP: verdigris body, brass pins, dial eye, plate true / false, opus violet (phase 2), heat (phase 3)   |   Clawd",
           fill=C("#ffe2a0"), font=font(17))
    sheet.convert("RGB").save(os.path.join(HERE, "loop_body.png"))


def font(n):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, n)
    return ImageFont.load_default()


# ---------------------------------------------------------------- arena: T10, 24 x 32 tiles, three phases ----------------------------------------------------------------
W_T, H_T = 24, 32
FLOOR = 29                     # floor tiles are rows 29..31 (the old room's rows 11..13)
DOOR = (25, 28)                # both doors, rows 25..28 (world rows -207..-204, unchanged)
PIT = (6, 17)                  # phase 3: floor and ceiling columns 6..17 open (the vertical wrap seam)
ONEWAY = {"L1": (3, 5, 25), "R1": (18, 20, 25), "M": (9, 14, 21), "L2": (2, 5, 13), "R2": (18, 21, 13), "TOP": (10, 13, 9)}
GANTRY = (8, 15, 4)            # the `while (true) {` beam
GEARS = [(5, 18), (18, 18)]    # centres (tile units), radius 2 tiles; the top tooth is a platform
RINGS = [(6, 7), (17, 7)]      # GET rings (curl)


def arena_panel(phase, T=12):
    cv = Image.new("RGBA", (W_T * T, H_T * T), C("#3a2615"))
    d = ImageDraw.Draw(cv)
    # back wall: brass panels, the big `i` counter
    for y in range(0, H_T, 4):
        d.line([0, y * T, W_T * T, y * T], fill=C("#4a3019"))
    d.text((W_T * T // 2 - 30, 15 * T), "i = 4096", fill=C(TOWER["lite"], 120), font=font(14))

    def tile(x, y, col, hi=None):
        d.rectangle([x * T, y * T, x * T + T - 1, y * T + T - 1], fill=C(col))
        if hi:
            d.line([x * T, y * T, x * T + T - 1, y * T], fill=C(hi))

    for y in range(H_T):
        for x in range(W_T):
            wall = x in (0, W_T - 1) and not (DOOR[0] <= y <= DOOR[1])
            ceil = y == 0 and not (phase == 3 and PIT[0] <= x <= PIT[1])
            flo = y >= FLOOR and not (phase == 3 and PIT[0] <= x <= PIT[1])
            if wall or ceil or flo:
                tile(x, y, TOWER["base"] if (flo and y == FLOOR) else TOWER["dark"], TOWER["cap"] if (flo and y == FLOOR) else None)
    for k, (a, b, y) in ONEWAY.items():
        if phase == 2 and k in ("L1", "R1"):
            continue                                    # phase 2: the low ledges are pulled into the walls
        for x in range(a, b + 1):
            d.rectangle([x * T, y * T, x * T + T - 1, y * T + 3], fill=C(TOWER["plat"]))
            d.line([x * T, y * T, x * T + T - 1, y * T], fill=C(TOWER["platHi"]))
    # the gantry; phase 2 it hangs on two chains and swings
    a, b, y = GANTRY
    off = 2 if phase >= 2 else 0
    if phase >= 2:
        d.line([(a * T + 4, T), (a * T + 4 + off * T, y * T)], fill=C(LOOP["vd3"]), width=2)
        d.line([((b + 1) * T - 4, T), ((b + 1) * T - 4 + off * T, y * T)], fill=C(LOOP["vd3"]), width=2)
    for x in range(a, b + 1):
        d.rectangle([(x + off) * T, y * T, (x + off) * T + T - 1, y * T + 4], fill=C(TOWER["base"]))
    d.text(((a + off) * T + 4, y * T - 16), "while (true) {", fill=C(TOWER["cap"]), font=font(13))
    for gx, gy in GEARS:
        cx, cy, r = gx * T + T // 2, gy * T + T // 2, 2 * T
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C(TOWER["capLo"]), outline=C(TOWER["lite"]))
        for k in range(8):
            ang = k * math.pi / 4 + (math.pi / 8 if phase == 2 else 0)
            tx, ty = cx + (r + 3) * math.cos(ang), cy + (r + 3) * math.sin(ang)
            d.rectangle([tx - 3, ty - 3, tx + 3, ty + 3], fill=C(TOWER["lite"]))
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=C(TOWER["dark"]))
        d.text((cx - 9, cy + r + 4), "<-" if phase == 2 else "->", fill=C(TOWER["glow"]), font=font(12))
    for rx, ry in RINGS:
        cx, cy = rx * T + T // 2, ry * T + T // 2
        d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], outline=C("#7cc4ff"), width=2)
    # the snake (a simplified line of links) and the players
    if phase == 1:
        pts = [(4 + 15 * math.cos(t / 6.0), 14 + 9 * math.sin(t / 6.0)) for t in range(0, 30, 2)]
        pts = [(12 + 7 * math.cos(k * 0.42), 15 + 6 * math.sin(k * 0.42)) for k in range(14)]
    elif phase == 2:
        pts = [(12 + 8 * math.cos(k * 0.40 + 2.0), 16 + 7 * math.sin(k * 0.40 + 2.0)) for k in range(14)]
    else:
        pts = [(11.5 + 0.6 * math.sin(k), 31.5 - k * 1.3) for k in range(8)]
    col = {1: LOOP["vd2"], 2: LOOP["opus"], 3: LOOP["heat"]}[phase]
    for k, (x, y) in enumerate(pts):
        d.ellipse([x * T - 6, y * T - 6, x * T + 6, y * T + 6], fill=C(col), outline=C(LOOP["vd0"]))
    hx, hy = pts[-1]
    d.rectangle([hx * T - 10, hy * T - 8, hx * T + 10, hy * T + 8], fill=C(LOOP["vd3"]), outline=C(LOOP["vd0"]))
    if phase == 2:
        for k in range(6):
            ang = k * math.pi / 3
            x, y = 18 * T + T // 2 + 3.4 * T * math.cos(ang), 18 * T + T // 2 + 3.4 * T * math.sin(ang)
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=C(LOOP["opus"]))
    if phase == 3:
        # the seam: what falls out of the bottom comes back in at the top
        for x in (8, 15):
            d.line([(x * T, (H_T - 1) * T), (x * T, H_T * T - 2)], fill=C("#ffffff"), width=2)
            d.polygon([(x * T - 5, H_T * T - 8), (x * T + 5, H_T * T - 8), (x * T, H_T * T - 1)], fill=C("#ffffff"))
            d.polygon([(x * T - 5, 8), (x * T + 5, 8), (x * T, 15)], fill=C("#ffffff"))
        d.text((PIT[0] * T + 8, (H_T - 2) * T + 2), "pit = wrap (no damage)", fill=C("#ffffff"), font=font(11))
    for (px, py), pc in (((2, 28), CLAWD), ((21, 28), "#7cc4ff")) if phase != 3 else (((2, 28), CLAWD), ((10, 20), "#7cc4ff")):
        d.rectangle([px * T, py * T - 2, px * T + T - 1, py * T + T - 1], fill=C(pc), outline=C("#1b1226"))
    return cv


def map_panel(P=3):
    w = json.load(open(os.path.join(ROOT, "docs", "metroidvania", "world-phase45.json")))
    x0, y0, x1, y1 = 1150, -260, 1320, -120
    cv = Image.new("RGBA", ((x1 - x0) * P, (y1 - y0) * P), C("#120b06"))
    d = ImageDraw.Draw(cv)
    for r in w["rooms"]:
        rx, ry = r["x"], r["y"]
        if rx > x1 or rx + r["w"] < x0 or ry > y1 or ry + r["h"] < y0:
            continue
        col = TOWER["plat"] if r["id"] != "T10" else "#555555"
        d.rectangle([(rx - x0) * P, (ry - y0) * P, (rx + r["w"] - x0) * P - 1, (ry + r["h"] - y0) * P - 1], fill=C(col, 200), outline=C(TOWER["lite"]))
        d.text(((rx - x0) * P + 3, (ry - y0) * P + 2), r["id"], fill=C("#ffffff"), font=font(12))
    nx, ny = 1230, -232
    d.rectangle([(nx - x0) * P, (ny - y0) * P, (nx + 24 - x0) * P - 1, (ny + 32 - y0) * P - 1], outline=C(LOOP["vd3"]), width=3)
    d.text(((nx - x0) * P + 3, (ny - y0) * P + 14), "new T10\n24x32", fill=C(LOOP["vd4"]), font=font(12))
    return cv


def write_arena():
    T = 12
    panels = [arena_panel(p, T) for p in (1, 2, 3)]
    mp = map_panel()
    S = 2
    pw, ph = panels[0].width * S, panels[0].height * S
    W = pw * 3 + 40 * 4 + mp.width
    H = ph + 120
    sheet = Image.new("RGBA", (W, H), C("#120b06"))
    d = ImageDraw.Draw(sheet)
    titles = ["PHASE 1 (100-66%): ledges, gears on the tick",
              "PHASE 2 (66-33%): low ledges in, gantry swings,\ngears reverse, nested ring",
              "PHASE 3 (33-0%): floor + ceiling middle open\n= vertical wrap"]
    for i, p in enumerate(panels):
        x = 40 + i * (pw + 40)
        sheet.alpha_composite(p.resize((pw, ph), Image.NEAREST), (x, 70))
        d.text((x, 28), titles[i], fill=C("#ffe2a0"), font=font(17))
    mx = 40 + 3 * (pw + 40)
    sheet.alpha_composite(mp, (mx, 70))
    d.text((mx, 40), "map: world-phase45.json, T10 grows up", fill=C("#ffe2a0"), font=font(17))
    d.text((40, 6), "INFINITE LOOP v3 - arena T10 (24 x 32 tiles, 16 px; drawn at 12 px x2).  orange = Clawd, blue = Clawd #2, green chain = the loop",
           fill=C("#ffffff"), font=font(20))
    d.text((mx, 70 + mp.height + 10), "one-way ledges = pink; gears = tower tick gears;\nblue rings = GET (curl); doors rows 25-28 both walls",
           fill=C("#ffe2a0"), font=font(15))
    sheet.convert("RGB").save(os.path.join(HERE, "loop_arena.png"))


if __name__ == "__main__":
    write_body()
    write_arena()
    print("wrote", os.path.join(HERE, "loop_body.png"), os.path.join(HERE, "loop_arena.png"))
