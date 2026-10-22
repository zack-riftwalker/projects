#!/usr/bin/env python3
"""RACE CONDITION's back wall: the two reference images (docs/metroidvania/17-race-data/ref/background_p1.webp / _p2.webp) as game files.
Each is resized to exactly 416 x 480 (T06's size, LANCZOS) and quantized to at most 48 colours without dithering (the pixel look), then saved to
godot/assets/bg/race_p1.png / race_p2.png (the hall draws them once as the room's back layer; plan 17-race-build.md section 4.4)."""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF = os.path.join(ROOT, "docs", "metroidvania", "17-race-data", "ref")
OUT = os.path.join(ROOT, "godot", "assets", "bg")
COLOURS = 48

for name in ("p1", "p2"):
    im = Image.open(os.path.join(REF, "background_%s.webp" % name)).convert("RGB")
    im = im.resize((416, 480), Image.LANCZOS)
    q = im.quantize(colors=COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    path = os.path.join(OUT, "race_%s.png" % name)
    q.save(path, optimize=True)
    print(path, os.path.getsize(path), "bytes", len(q.getcolors()), "colours")
