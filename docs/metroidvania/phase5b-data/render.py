#!/usr/bin/env python3
"""Picture of the GIT HISTORY drafts in world coordinates (with the built rooms next to them, greyed).
python3 -I docs/metroidvania/phase5b-data/render.py  ->  docs/metroidvania/phase5b-data/git-history.png"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
S = 5                                                     # px per tile
X0, Y0, X1, Y1 = 1262, 60, 1620, 232
LIVE = json.load(open(os.path.join(ROOT, "godot/src/world/rooms.json")))["rooms"]
NEW = json.load(open(os.path.join(HERE, "rooms-5b.json")))
COL = {"#": (112, 86, 60), "=": (214, 190, 140), "%": (230, 140, 60), "6": (70, 190, 90), "7": (210, 70, 60),
       "8": (150, 110, 200), "~": (190, 160, 110), "^": (240, 240, 240), "4": (80, 200, 220), "N": (200, 50, 40),
       "_": (120, 120, 140), "Q": (80, 200, 220), "9": (255, 210, 40), "C": (255, 170, 60), "T": (240, 230, 200),
       "I": (255, 255, 255), "U": (120, 220, 255), "*": (255, 120, 220), "H": (220, 180, 80), "D": (255, 255, 255),
       "B": (255, 60, 60), "o": (255, 220, 120)}
FOE = set("ZbatZ<>")
img = Image.new("RGB", ((X1 - X0) * S, (Y1 - Y0) * S + 70), (24, 20, 16))
dr = ImageDraw.Draw(img)
f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)


def P(x, y):
    return ((x - X0) * S, (y - Y0) * S)


def draw(rid, m, rows, grey):
    ox, oy = m["origin"]
    w, h = m["size"]
    if ox + w < X0 or ox > X1 or oy + h < Y0 or oy > Y1:
        return
    dr.rectangle([P(ox, oy), P(ox + w, oy + h)], fill=(40, 34, 28) if not grey else (30, 30, 34))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = (220, 80, 220) if ch in FOE else COL.get(ch)
            if c is None:
                continue
            if grey:
                g = sum(c) // 3 // 2 + 20
                c = (g, g, g + 6)
            px, py = P(ox + x, oy + y)
            dr.rectangle([px, py, px + S - 1, py + S - 1], fill=c)
    dr.rectangle([P(ox, oy), P(ox + w, oy + h)], outline=(90, 90, 100) if grey else (240, 200, 140))
    tx, ty = P(ox, oy)
    dr.text((tx + 3, ty + 2), "%s %s" % (rid, m["title"]), font=f, fill=(150, 150, 160) if grey else (255, 235, 200))


for rid, m in LIVE.items():
    if m.get("lab"):
        continue
    draw(rid, m, open(os.path.join(ROOT, "godot/src/world/rooms", m["file"])).read().split("\n"), True)
for rid, m in NEW.items():
    draw(rid, m, open(os.path.join(HERE, "rooms", m["file"])).read().split("\n"), False)
leg = [("#", "wall"), ("6", "+ block (checkout)"), ("7", "- block (checkout)"), ("8", "stash plug (b02)"), ("%", "crack (bash)"),
       ("N", "firewall (ssh)"), ("~", "crumble bridge"), ("4", "gate + plate (revert)"), ("_", "package-lock (--force)"),
       ("9", "branch key"), ("C", "bench"), ("Z", "enemy")]
y = (Y1 - Y0) * S + 10
dr.text((10, y), "GIT HISTORY (.git) - draft, world department, proposal (doc 19)", font=fb, fill=(255, 235, 200))
x = 10
for ch, name in leg:
    c = (220, 80, 220) if ch in FOE else COL[ch]
    dr.rectangle([x, y + 30, x + 12, y + 42], fill=c)
    dr.text((x + 16, y + 28), name, font=f, fill=(230, 220, 200))
    x += 26 + int(dr.textlength(name, font=f))
img.save(os.path.join(HERE, "git-history.png"))
print("saved", img.size)
