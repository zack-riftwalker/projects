#!/usr/bin/env python3
"""INFINITE LOOP's game sprites, cut from the body sketch docs/metroidvania/18-loop-data/loop_body.png (the design's pixel art, game pixels x3).
Zakaria approved the sketch as the character (2026-11-15) and may draw it himself later: then put his image in place of loop_body.png (or point
--src at it), fix the boxes in CUTS if the poses moved, and run this script again; nothing in the game changes but the pictures.

How it cuts: every pose is a box of game pixels inside one cell of the sheet. A box is read back from the x3 picture by taking the middle pixel
of each 3x3 block (the sheet was scaled with nearest neighbour, so this is exact). What belongs to the piece is found by a stencil: the head's
outline shape (STENCIL_HEAD, the skull and jaw seen in every head pose) or a link's rounded square; the cell's background colour is
transparent. Pieces the sketch does not draw are made from the nearest one (as race_sprites.py does): the closed-jaw head of phase 2 and 3
from phase 1's with the brow and plate of the phase-2 / 3 pose, the half plate `tru_` from `true`.

The plate (the condition on the brow) is cut out as its own sprite and drawn upright over the head in the game, so it stays readable when the
head points up or down. The head itself is turned to 8 directions here (at x3 with nearest neighbour, then read back per 3x3 block by the
most common colour): pixel art drawn in 8 directions, never rotated freely in the game.

Outputs (godot/assets/sprites/):
  loop_head.png     rows = HEADS (idle, tell, open, p2, p2open, p3, p3open, down), 8 columns = the directions 0, 45, ... 315 degrees
                    (screen angles, clockwise from east); each frame FS x FS, the head's centre in the frame's centre
  loop_links.png    LINKS (p1, p2, p3, down, nest) in 16 x 16 frames
  loop_plate.png    PLATES (true, lit, half, false, cracked) in 20 x 10 frames
  loop_sprites.json sizes, orders, the plate's anchor (offset from the head's centre at 0 degrees, turned with the head in the game)
Run: python3 -I tools/godot/loop_sprites.py [--sheet out.png] [--src image.png]
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs", "metroidvania", "18-loop-data", "loop_body.png")
OUT = os.path.join(ROOT, "godot", "assets", "sprites")

S = 3                                   # the sheet's scale
CW, CH, TOP, LBL, COLS = 210, 170, 40, 34, 3       # the sheet's cells (game px), as in sketch.py
BG = (0x2a, 0x1a, 0x10)
FS = 56                                 # a head frame (a 40 x 32 head turned 45 degrees fits)
HW, HH = 40, 32
PLATE_BOX = (5, 0, 23, 8)               # x0, y0, x1, y1 (exclusive) of the plate on a head at 0 degrees
PW_, PH_ = 20, 10

# cell index (0..6, reading order), the head's top-left in the cell (game px), jaw open, the last row that is head (the lying head: the floor under it)
HEAD_CUTS = {"idle": (0, 66, 39, False, 32), "tell": (1, 121, 45, True, 32), "open": (2, 128, 79, True, 32), "p2": (3, 70, 39, False, 32),
             "p3open": (4, 88, 36, True, 32), "down": (5, 153, 126, False, 24)}
# cell, the link's top-left (16 x 16; nest is 12 x 12)
LINK_CUTS = {"p1": (0, 123, 59), "p2": (3, 127, 59), "p3": (4, 28, 99), "down": (5, 54, 134), "nest": (3, 102, 80)}
HEADS = ["idle", "tell", "open", "p2", "p2open", "p3", "p3open", "down"]
LINKS = ["p1", "p2", "p3", "down", "nest"]
PLATES = ["true", "lit", "half", "false", "cracked"]


def cell_origin(k):
    return ((k % COLS) * CW * S, TOP + (k // COLS) * (CH * S + LBL))


def read(src, k, x0, y0, w, h):
    """w x h game pixels from cell k at (x0, y0): the middle pixel of each 3x3 block."""
    ox, oy = cell_origin(k)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = src.load()
    for y in range(h):
        for x in range(w):
            c = px[ox + (x0 + x) * S + 1, oy + (y0 + y) * S + 1][:3]
            out.putpixel((x, y), c + (255,))
    return out


def head_stencil(open_jaw, max_y=HH):
    """The head's own pixels (skull, its jaw, the eye, the plate): everything else in the box is the chain behind it, the floor or the background."""
    m = Image.new("L", (HW, HH), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(m)
    d.polygon([(2, 12), (8, 7), (22, 6), (33, 9), (39, 14), (38, 17), (26, 18), (4, 20)], fill=255)      # skull
    if open_jaw:
        d.polygon([(6, 20), (24, 19), (36, 27), (33, 30), (20, 27), (5, 24)], fill=255)                 # open jaw
        d.polygon([(26, 18), (38, 17), (34, 26), (24, 20)], fill=255)                                  # the open mouth
    else:
        d.polygon([(4, 20), (26, 18), (38, 17), (34, 22), (8, 24)], fill=255)                          # closed jaw
    d.rectangle([PLATE_BOX[0], PLATE_BOX[1], PLATE_BOX[2] - 1, PLATE_BOX[3] - 1], fill=255)
    if max_y < HH:
        d.rectangle([0, max_y, HW - 1, HH - 1], fill=0)
    return m


def link_stencil(n):
    m = Image.new("L", (n, n), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(m).rounded_rectangle([0, 1, n - 1, n - 2], radius=4, fill=255)
    return m


def masked(im, st):
    out = im.copy()
    a = st.load()
    p = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if a[x, y] == 0 or p[x, y][:3] == BG:
                p[x, y] = (0, 0, 0, 0)
    return out


def cut_plate(head):
    pl = Image.new("RGBA", (PW_, PH_), (0, 0, 0, 0))
    pl.alpha_composite(head.crop(PLATE_BOX), (1, 1))
    return pl


def clear_plate(head):
    """The head without its plate (the game draws the plate upright on top). The plate's rows over the skull keep the skull's colour."""
    h = head.copy()
    p = h.load()
    x0, y0, x1, y1 = PLATE_BOX
    for x in range(x0, x1):
        below = None
        for y in range(y1, HH):                       # the skull's first pixel under the plate
            if p[x, y][3] > 0:
                below = p[x, y]
                break
        for y in range(y0, y1):
            p[x, y] = (0, 0, 0, 0)
        if below is not None and 6 <= y1:            # the skull top (rows 6..7) under the plate: filled from the skull below
            for y in range(6, y1):
                if x >= 8 and x <= 22:
                    p[x, y] = below
    return h


def rotate(im, deg):
    """Turn a sprite by a multiple of 45 degrees: nearest neighbour at x3, then each 3x3 block's most common colour."""
    big = im.resize((im.width * S, im.height * S), Image.NEAREST)
    rot = big.rotate(-deg, resample=Image.NEAREST, expand=True)
    w, h = rot.width // S, rot.height // S
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rp = rot.load()
    for y in range(h):
        for x in range(w):
            votes = {}
            for dy in range(S):
                for dx in range(S):
                    c = rp[x * S + dx, y * S + dy]
                    c = c if c[3] > 0 else (0, 0, 0, 0)
                    votes[c] = votes.get(c, 0) + (2 if (dx == 1 and dy == 1) else 1)
            out.putpixel((x, y), max(votes.items(), key=lambda kv: kv[1])[0])
    return out


def frame_of(im, deg):
    """One head frame: facing `deg` (screen degrees, clockwise from east). Left-facing ones are the mirror turned the other way (as the sketch)."""
    rad = deg % 360
    src = im
    a = rad
    if 90 < rad < 270:
        src = im.transpose(Image.FLIP_LEFT_RIGHT)
        a = rad - 180
    r = rotate(src, a) if a % 360 != 0 else src
    fr = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    fr.alpha_composite(r, ((FS - r.width) // 2, (FS - r.height) // 2))
    return fr


def build(src_path, sheet_path=None):
    src = Image.open(src_path).convert("RGB")
    heads = {k: masked(read(src, c, x, y, HW, HH), head_stencil(oj, my)) for k, (c, x, y, oj, my) in HEAD_CUTS.items()}
    # the plates (before they are cleared off the heads)
    plates = {"true": cut_plate(heads["idle"]), "lit": cut_plate(heads["tell"]), "false": cut_plate(heads["down"]), "cracked": cut_plate(heads["p3open"])}
    half = plates["true"].copy()                       # `tru_`: the last letter (columns 15..17 of the plate) gone, an underscore in its place
    hp = half.load()
    for y in range(2, 7):
        for x in range(15, 18):
            hp[x, y] = (0x1b, 0x12, 0x26, 255)
    for x in range(15, 18):
        hp[x, 6] = (0xb8, 0xf0, 0xd8, 255)
    plates["half"] = half
    # the poses the sketch has not drawn: from the nearest ones
    brow = heads["p2"].crop((8, 6, 34, 12))                                    # phase 2's violet brow (the rest of that pose has the nested ring behind it)
    p2 = heads["idle"].copy()
    p2.alpha_composite(brow, (8, 6))
    heads["p2"] = masked(p2, head_stencil(False))
    p2open = heads["open"].copy()
    p2open.alpha_composite(brow, (8, 6))
    heads["p2open"] = masked(p2open, head_stencil(True))
    p3 = heads["idle"].copy()
    hot = heads["p3open"].load()
    pp = p3.load()
    for (x, y) in [(12, 12), (20, 15)]:                                        # phase 3's hot rivets, on the closed head
        pp[x, y] = hot[x, y]
    heads["p3"] = p3
    bare = {k: clear_plate(v) for k, v in heads.items()}
    dirs = [0, 45, 90, 135, 180, 225, 270, 315]
    sheet = Image.new("RGBA", (FS * len(dirs), FS * len(HEADS)), (0, 0, 0, 0))
    for r, k in enumerate(HEADS):
        for c, dg in enumerate(dirs):
            sheet.alpha_composite(frame_of(bare[k], dg), (c * FS, r * FS))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "loop_head.png"), optimize=True)
    lsheet = Image.new("RGBA", (16 * len(LINKS), 16), (0, 0, 0, 0))
    for i, k in enumerate(LINKS):
        c, x, y = LINK_CUTS[k]
        n = 12 if k == "nest" else 16
        lk = masked(read(src, c, x, y, n, n), link_stencil(n))
        lsheet.alpha_composite(lk, (i * 16 + (16 - n) // 2, (16 - n) // 2))
    lsheet.save(os.path.join(OUT, "loop_links.png"), optimize=True)
    psheet = Image.new("RGBA", (PW_ * len(PLATES), PH_), (0, 0, 0, 0))
    for i, k in enumerate(PLATES):
        psheet.alpha_composite(plates[k], (i * PW_, 0))
    psheet.save(os.path.join(OUT, "loop_plate.png"), optimize=True)
    # the plate's centre relative to the head's centre, at 0 degrees (the game turns it with the head)
    pcx = (PLATE_BOX[0] + PLATE_BOX[2]) / 2.0 - HW / 2.0
    pcy = (PLATE_BOX[1] + PLATE_BOX[3]) / 2.0 - HH / 2.0
    meta = {"frame": FS, "heads": HEADS, "dirs": dirs, "links": LINKS, "link": 16, "plates": PLATES, "plate": [PW_, PH_],
            "plate_at": [pcx, pcy], "eye_at": [25 - HW / 2.0, 12 - HH / 2.0]}
    with open(os.path.join(OUT, "loop_sprites.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    if sheet_path:
        contact(src, sheet, lsheet, psheet, sheet_path)


def contact(src, heads, links, plates, path):
    """The cut sprites (x3) beside the sketch's first cell, for checking by eye."""
    k = 3
    ref = src.crop((0, TOP, CW * S, TOP + CH * S))
    w = max(heads.width * k, ref.width)
    out = Image.new("RGBA", (w, ref.height + heads.height * k + links.height * k + plates.height * k + 40), (40, 30, 20, 255))
    out.paste(ref, (0, 0))
    y = ref.height + 10
    out.alpha_composite(heads.resize((heads.width * k, heads.height * k), Image.NEAREST), (0, y))
    y += heads.height * k + 10
    out.alpha_composite(links.resize((links.width * k, links.height * k), Image.NEAREST), (0, y))
    out.alpha_composite(plates.resize((plates.width * k, plates.height * k), Image.NEAREST), (links.width * k + 30, y))
    out.save(path)


if __name__ == "__main__":
    args = sys.argv[1:]
    sp = args[args.index("--sheet") + 1] if "--sheet" in args else None
    s = args[args.index("--src") + 1] if "--src" in args else SRC
    build(s, sp)
    print("loop sprites written to", OUT)
