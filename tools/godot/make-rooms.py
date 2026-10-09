#!/usr/bin/env python3
"""Builds the slice's room files from the captured levels (tools/godot/capture/out/levels, run capture.js levels first)
by applying godot/src/world/room_edits.json. Each edit is [x, y, expected_old_char, new_char]; a mismatch stops the script.
The new rooms (R04, R06, R07, R08) are written by hand and are not touched. Run: python3 -I tools/godot/make-rooms.py"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVELS = os.path.join(ROOT, "tools/godot/capture/out/levels")
OUT = os.path.join(ROOT, "godot/src/world/rooms")
edits = json.load(open(os.path.join(ROOT, "godot/src/world/room_edits.json")))
meta = json.load(open(os.path.join(ROOT, "godot/src/world/rooms.json")))["rooms"]
for rid, spec in edits.items():
    rows = [list(r) for r in open(os.path.join(LEVELS, spec["from"] + ".txt")).read().split("\n")]
    for x, y, old, new in spec["edits"]:
        if y >= len(rows) or x >= len(rows[y]) or rows[y][x] != old:
            got = rows[y][x] if y < len(rows) and x < len(rows[y]) else "<outside>"
            sys.exit("%s: edit at (%d,%d) expected %r but found %r" % (rid, x, y, old, got))
        rows[y][x] = new
    w, h = meta[rid]["size"]
    if len(rows) != h or any(len(r) != w for r in rows):
        sys.exit("%s: size mismatch (rooms.json says %dx%d, file is %dx%d)" % (rid, w, h, len(rows[0]), len(rows)))
    open(os.path.join(OUT, rid + ".txt"), "w").write("\n".join("".join(r) for r in rows))
    print("wrote", rid)
