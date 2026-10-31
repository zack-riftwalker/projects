#!/usr/bin/env python3
"""RACE CONDITION's TICK and TOCK as game sprites, cut from Zakaria's own pixel art (docs/metroidvania/17-race-data/ref/):
tick_tock.webp (the main reference: TICK with the hammer up, TOCK with the hammer on the shoulder), sheet_keys.webp (the poses) and
sheet_4dir.webp (the palette swatches). Play-test 2026-10-31: "I drew the boss in pixels and it looks nothing like it" -- the bodies were drawn
from ~20 rectangles before; now every frame is the drawing itself.

Per pose: the figure is cut out of its source (its blobs on the dark background, the background flood-filled away from the crop's border so the
dark outlines inside stay), mirrored to face right if needed, scaled so a standing body is H px tall (box filter: the images are pixel art blown up
~3x (the sheet) and ~11.5x (the main image), so a box filter lands close to the original pixels), and put on a FW x FH frame with the feet on the
bottom row FH - 2 and the hips on FW / 2. Poses the images do not have are made from the nearest one by moving its pieces (crouch: the legs
folded; hang: the legs drawn up under a raised arm). Each character's frames share one palette (median cut, then snapped to the swatches of
sheet_4dir.webp where a swatch is close), so the sprite is clean pixel art and not the image's soft noise.

Outputs (godot/assets/sprites/):
  race_tick.png / race_tock.png            the frames in one row, in POSES order
  race_tick_hot.png / race_tock_hot.png    phase 2: the bronze heated red (the gold stays gold), the same frames
  race_tick_flash.png / race_tock_flash.png a hit: the frames 75 % white
  race_sprites.json                        frame size, pose order, per frame the eye pixels (lit for the READ, dim otherwise) and the chest clock
Run: python3 -I tools/godot/race_sprites.py [--sheet out.png]   (--sheet: a contact sheet next to the references, for checking by eye)
"""
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF = os.path.join(ROOT, "docs", "metroidvania", "17-race-data", "ref")
OUT = os.path.join(ROOT, "godot", "assets", "sprites")

FW, FH = 64, 80                    # one frame; the feet stand on row FH - 2, the hips on column FW / 2
FOOT_Y = FH - 2
H = {0: 56, 1: 58}                 # a standing body's height in game pixels (TOCK is the bigger one, as in the images)
STAND = {("keys", 0): 188, ("keys", 1): 196, ("main", 0): 665, ("main", 1): 733}     # the same height in each source's pixels
POSES = ["idle", "crouch", "hop", "up", "strike", "stuck", "dazed", "down", "kneel", "swing", "hang", "bow"]
SWATCHES = ["#563131", "#623133", "#ef414b", "#d36046", "#775853", "#516c7b", "#2c98cc",
            "#cc926b", "#865c51", "#824b2b", "#3d2d2e", "#2c4f84", "#4ec3f1", "#ff8e08"]
COLOURS = 20                       # found by median cut, besides the fixed ones below
FIXED = ["#140c0e", "#2a1c1c", "#d6a43e", "#f6d878", "#8a6420", "#e8dcc0", "#c4a37a", "#ff4a3a", "#2ee6d6", "#bff8ff", "#ffd0c0"]   # ink, dark bronze, gold (3), paper, skirt, the trims and the eyes' glow: never merged away

# who -> pose -> (source, box x0 y0 x1 y1 in the source, mirror, x nudge in game px, how)
# sheet_keys.webp: row 1 standing (side, front, back, side), row 2 walking, row 3 hammer up / strike / bowing, row 4 hurt, row 5 kneeling and lying
CUTS = {
    0: {
        "idle": ("keys", (60, 28, 164, 216), False, 0, ""),
        "crouch": ("keys", (60, 28, 164, 216), False, 0, "crouch"),
        "hop": ("keys", (36, 260, 144, 424), False, 0, ""),
        "up": ("main", (270, 20, 700, 955), False, 0, ""),
        "strike": ("keys", (168, 528, 284, 672), False, 0, ""),
        "stuck": ("keys", (288, 552, 392, 672), False, 0, ""),
        "dazed": ("keys", (48, 700, 140, 832), False, 0, ""),
        "down": ("keys", (276, 908, 380, 960), True, 0, "lie"),
        "kneel": ("keys", (40, 872, 136, 968), False, 0, ""),
        "swing": ("keys", (524, 488, 632, 668), True, 0, ""),
        "hang": ("keys", (44, 452, 144, 672), False, 0, "hang"),
        "bow": ("keys", (288, 552, 392, 672), False, 0, ""),
    },
    1: {
        "idle": ("main", (780, 195, 1290, 955), False, 0, ""),
        "crouch": ("main", (780, 195, 1290, 955), False, 0, "crouch"),
        "hop": ("keys", (712, 264, 824, 424), False, 0, ""),
        "up": ("keys", (708, 464, 804, 668), False, 0, ""),
        "strike": ("keys", (984, 564, 1108, 672), False, 0, ""),
        "stuck": ("keys", (1252, 504, 1360, 672), True, 0, ""),
        "dazed": ("keys", (712, 700, 820, 840), False, 0, ""),
        "down": ("keys", (996, 912, 1116, 964), True, 0, "lie"),
        "kneel": ("keys", (700, 868, 804, 972), False, 0, ""),
        "swing": ("keys", (1352, 264, 1488, 424), True, 0, ""),
        "hang": ("keys", (708, 464, 804, 668), False, 0, "hang"),
        "bow": ("keys", (984, 564, 1108, 672), False, 0, ""),
    },
}
EYE = {0: lambda r, g, b: r > 190 and g < 120 and b < 120, 1: lambda r, g, b: b > 170 and g > 150 and r < 170}


def load(name):
    f = {"keys": "sheet_keys.webp", "main": "tick_tock.webp"}[name]
    return np.asarray(Image.open(os.path.join(REF, f)).convert("RGB")).astype(np.int32)


def cut(src, box, pad=10):
    """the figure in box as RGB + a mask: the background is what the crop's border reaches through background-coloured pixels"""
    x0, y0, x1, y1 = box
    hh, ww = src.shape[:2]
    X0, Y0, X1, Y1 = max(0, x0 - pad), max(0, y0 - pad), min(ww, x1 + pad), min(hh, y1 + pad)
    c = src[Y0:Y1, X0:X1]
    bgc = np.median(src[:24, :24].reshape(-1, 3), axis=0)
    near = np.abs(c - bgc).sum(axis=2) < 46
    h, w = near.shape
    bg = np.zeros_like(near)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    fg = ~bg
    # only the blobs that belong to this figure: a blob outside the unpadded box is the neighbour's
    fg = _keep_inside(fg, (x0 - X0, y0 - Y0, x1 - X0, y1 - Y0))
    return c, fg


def _keep_inside(fg, box, k=3):
    h, w = fg.shape
    m = fg[: h // k * k, : w // k * k].reshape(h // k, k, w // k, k).any(axis=(1, 3))
    lab = np.zeros(m.shape, np.int32)
    n = 0
    keep = set()
    bx0, by0, bx1, by1 = box[0] // k, box[1] // k, box[2] // k, box[3] // k
    for y in range(m.shape[0]):
        for x in range(m.shape[1]):
            if m[y, x] and lab[y, x] == 0:
                n += 1
                lab[y, x] = n
                q = deque([(y, x)])
                cells = []
                while q:
                    cy, cx = q.popleft()
                    cells.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = n
                                q.append((ny, nx))
                ys = [c[0] for c in cells]
                xs = [c[1] for c in cells]
                cy, cx = (min(ys) + max(ys)) / 2.0, (min(xs) + max(xs)) / 2.0
                if bx0 <= cx <= bx1 and by0 <= cy <= by1:
                    keep.add(n)
    big = np.zeros((h, w), np.int32)
    big[: h // k * k, : w // k * k] = np.repeat(np.repeat(lab, k, axis=0), k, axis=1)
    return fg & np.isin(big, list(keep))


def shrink(rgb, mask, s):
    """box-filter scale by s; the colour of a pixel is the average of the figure's own pixels under it (never the background's)"""
    h, w = mask.shape
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    m = mask.astype(np.float32)
    out = np.zeros((nh, nw, 3), np.float32)
    for ch in range(3):
        a = Image.fromarray((rgb[:, :, ch] * m).astype(np.float32), mode="F").resize((nw, nh), Image.BOX)
        out[:, :, ch] = np.asarray(a)
    am = np.asarray(Image.fromarray(m, mode="F").resize((nw, nh), Image.BOX))
    col = out / np.maximum(am, 1e-4)[:, :, None]
    # the colour of each pixel is the source pixel at its centre (keeps the thin trims and the eyes saturated; an average greys them),
    # unless that one is background: then the average of the figure's pixels under it
    yy = np.clip(((np.arange(nh) + 0.5) / s).astype(int), 0, h - 1)
    xx = np.clip(((np.arange(nw) + 0.5) / s).astype(int), 0, w - 1)
    cm = mask[yy][:, xx]
    cc = rgb[yy][:, xx]
    col = np.where(cm[:, :, None], cc, col)
    return np.clip(col, 0, 255), am > 0.45


def place(rgb, mask, nudge, how):
    """on a FW x FH frame: feet on FOOT_Y, the hips (the middle of the legs and skirt band) on FW / 2"""
    ys, xs = np.nonzero(mask)
    bottom = ys.max()
    top = ys.min()
    hgt = bottom - top + 1
    band = (ys > bottom - hgt * 0.45) & (ys < bottom - hgt * 0.12)
    cx = np.median(xs[band]) if band.any() else (xs.min() + xs.max()) / 2.0
    if how == "lie":
        cx = (xs.min() + xs.max()) / 2.0
    ox = int(round(FW / 2 - cx)) + nudge
    oy = FOOT_Y - bottom
    frame = np.zeros((FH, FW, 4), np.uint8)
    for y, x in zip(ys, xs):
        fy, fx = y + oy, x + ox
        if 0 <= fy < FH and 0 <= fx < FW:
            frame[fy, fx, :3] = rgb[y, x]
            frame[fy, fx, 3] = 255
    return frame


def fold(frame, lo, hi, n, keep_top):
    """take n rows out of the band [FOOT_Y - hi, FOOT_Y - lo] (the legs), the rest closes up: from above (crouch: the body sinks) or from below
    (hang: the feet are drawn up)"""
    y0, y1 = FOOT_Y - hi, FOOT_Y - lo
    drop = set(int(round(y0 + (y1 - y0) * (k + 0.5) / n)) for k in range(n))
    rows = [y for y in range(FH) if y not in drop]
    out = np.zeros_like(frame)
    if keep_top:
        for i, y in enumerate(rows):
            out[i] = frame[y]
    else:
        for i, y in enumerate(reversed(rows)):
            out[FH - 1 - i] = frame[y]
    return out


def palette_for(frames):
    px = np.concatenate([f[f[:, :, 3] > 0][:, :3] for f in frames])
    side = int(np.ceil(np.sqrt(len(px))))
    pad = np.zeros((side * side, 3), np.uint8)
    pad[: len(px)] = px
    pad[len(px):] = px[0]
    q = Image.fromarray(pad.reshape(side, side, 3)).quantize(colors=COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[: COLOURS * 3]).reshape(-1, 3)
    sw = np.array([[int(s[i:i + 2], 16) for i in (1, 3, 5)] for s in SWATCHES])
    for i, c in enumerate(pal):
        d = np.abs(sw - c).sum(axis=1)
        if d.min() < 30:
            pal[i] = sw[d.argmin()]
    fixed = np.array([[int(s[i:i + 2], 16) for i in (1, 3, 5)] for s in FIXED + SWATCHES])
    keep = [c for c in pal if np.abs(fixed - c).sum(axis=1).min() >= 24]
    return np.concatenate([fixed, np.array(keep).reshape(-1, 3)]).astype(np.int32)


def apply_palette(frame, pal):
    out = frame.copy()
    m = frame[:, :, 3] > 0
    px = frame[m][:, :3].astype(np.int32)
    d = ((px[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2)
    out[m, :3] = pal[d.argmin(axis=1)]
    return out


def outline(frame):
    """a 1 px ink line round the figure (outside it), so it stands off the belfry's dark brick as the old drawing did"""
    a = frame[:, :, 3] > 0
    ring = np.zeros_like(a)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        ring |= np.roll(np.roll(a, dy, axis=0), dx, axis=1)
    ring &= ~a
    out = frame.copy()
    out[ring] = [18, 12, 16, 255]
    return out


def find_eye(frame, who):
    """the eye's pixels: the bright red (TICK) / bright cyan (TOCK) blob highest on the body that is not the cap's band"""
    hits = []
    ys, xs = np.nonzero(frame[:, :, 3])
    top = ys.min()
    for y, x in zip(ys, xs):
        r, g, b = (int(v) for v in frame[y, x, :3])
        if y < top + 22 and EYE[who](r, g, b):
            hits.append((int(x), int(y), r + g + b))
    if not hits:
        return []
    hits.sort(key=lambda h: -h[2])
    best = hits[0]
    return [[h[0], h[1]] for h in hits if abs(h[0] - best[0]) <= 2 and abs(h[1] - best[1]) <= 1 and h[2] > best[2] * 0.75]


def find_clock(frame):
    """the small clock on the chest: the middle of its paper-coloured pixels"""
    m = (frame[:, :, 3] > 0) & (frame[:, :, 0] > 205) & (frame[:, :, 1] > 190) & (frame[:, :, 2] > 160)   # (paper, not the tan skirt)
    ys0 = np.nonzero(frame[:, :, 3])[0]
    m[FOOT_Y - int((FOOT_Y - ys0.min()) * 0.45):, :] = False                                                   # (the chest: above the hips)
    ys, xs = np.nonzero(m)
    if len(xs) < 3:
        return None
    return [int(round(float(np.median(xs)))), int(round(float(np.median(ys))))]


HOT = np.array([224, 71, 44])


def hot_of(frame):
    """phase 2: the dark bronze runs red-hot; gold, paper and the eyes keep their colour"""
    out = frame.copy()
    m = frame[:, :, 3] > 0
    c = frame[:, :, :3].astype(np.float32)
    lum = c.mean(axis=2)
    gold = (c[:, :, 0] > 150) & (c[:, :, 1] > 100) & (c[:, :, 2] < 120)
    k = np.where(gold | (lum > 170) | (lum < 24), 0.0, 0.32)
    hc = c * (1 - k[:, :, None]) + HOT[None, None, :] * k[:, :, None] * np.clip(lum / 90.0, 0.45, 1.0)[:, :, None]
    out[m, :3] = np.clip(hc[m], 0, 255).astype(np.uint8)
    return out


def flash_of(frame):
    out = frame.copy()
    m = frame[:, :, 3] > 0
    out[m, :3] = (frame[m][:, :3] * 0.25 + 255 * 0.75).astype(np.uint8)
    return out


def build():
    srcs = {"keys": load("keys"), "main": load("main")}
    meta = {"frame": [FW, FH], "foot_y": FOOT_Y, "poses": POSES, "who": {}}
    sheets = {}
    for who in (0, 1):
        frames = []
        for pose in POSES:
            sname, box, mirror, nudge, how = CUTS[who][pose]
            rgb, mask = cut(srcs[sname], box)
            if mirror:
                rgb, mask = rgb[:, ::-1], mask[:, ::-1]
            s = H[who] / STAND[(sname, who)]
            r2, m2 = shrink(rgb.astype(np.float32), mask, s)
            fr = place(r2.astype(np.uint8), m2, nudge, how)
            if how == "crouch":
                fr = fold(fr, 6, 22, 7, keep_top=False)
            elif how == "hang":
                fr = fold(fr, 2, 20, 8, keep_top=True)
            frames.append(fr)
        pal = palette_for(frames)
        frames = [apply_palette(f, pal) for f in frames]
        info = []
        for f in frames:
            eye = find_eye(f, who)
            for x, y in eye:                           # the eye is dead until the READ lights it (the game draws the lit pixels on top)
                f[y, x, :3] = (f[y, x, :3] * 0.45).astype(np.uint8)
            info.append({"eye": eye, "clock": find_clock(f)})
        frames = [outline(f) for f in frames]
        meta["who"][str(who)] = {"frames": info, "palette": ["#%02x%02x%02x" % tuple(int(v) for v in c) for c in pal]}
        sheet = np.concatenate(frames, axis=1)
        sheets[who] = sheet
        name = "race_tick" if who == 0 else "race_tock"
        Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)
        Image.fromarray(np.concatenate([hot_of(f) for f in frames], axis=1), "RGBA").save(os.path.join(OUT, name + "_hot.png"), optimize=True)
        Image.fromarray(np.concatenate([flash_of(f) for f in frames], axis=1), "RGBA").save(os.path.join(OUT, name + "_flash.png"), optimize=True)
        print(name, sheet.shape[1], "x", sheet.shape[0], len(pal), "colours")
    with open(os.path.join(OUT, "race_sprites.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
        fh.write("\n")
    return sheets


def contact(sheets, path):
    """the frames at 4x with their names' order, under the two main references (for checking by eye)"""
    z = 4
    rows = []
    for who in (0, 1):
        s = Image.fromarray(sheets[who], "RGBA").resize((sheets[who].shape[1] * z, FH * z), Image.NEAREST)
        bg = Image.new("RGBA", s.size, (40, 26, 20, 255))
        bg.alpha_composite(s)
        rows.append(bg)
    ref = Image.open(os.path.join(REF, "tick_tock.webp")).convert("RGBA")
    ref = ref.resize((int(ref.width * rows[0].height * 1.4 / ref.height), int(rows[0].height * 1.4)), Image.LANCZOS)
    w = max(rows[0].width, ref.width)
    out = Image.new("RGBA", (w, ref.height + rows[0].height * 2), (20, 14, 12, 255))
    out.alpha_composite(ref, (0, 0))
    out.alpha_composite(rows[0], (0, ref.height))
    out.alpha_composite(rows[1], (0, ref.height + rows[0].height))
    out.save(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sh = build()
    if "--sheet" in sys.argv:
        contact(sh, sys.argv[sys.argv.index("--sheet") + 1])
