#!/usr/bin/env python3
"""Compares two traces (frame,x,y,vx,vy,onGround). Prints the first frame that differs by more than 0.01 in x, y, vx or vy (or in onGround), or PARITY OK <frames>."""
import sys

def load(p):
    rows = []
    for line in open(p):
        line = line.strip()
        if line and line[0].isdigit() and line.count(",") == 5:
            f = line.split(",")
            rows.append((int(f[0]), float(f[1]), float(f[2]), float(f[3]), float(f[4]), int(f[5])))
    return rows

a, b = load(sys.argv[1]), load(sys.argv[2])
if not a or len(a) != len(b):
    print("PARITY FAIL: different frame counts (%d vs %d)" % (len(a), len(b)))
    sys.exit(1)
for ra, rb in zip(a, b):
    if any(abs(ra[k] - rb[k]) > 0.01 for k in (1, 2, 3, 4)) or ra[5] != rb[5]:
        print("PARITY FAIL at frame %d: js x=%.4f y=%.4f vx=%.3f vy=%.3f g=%d | godot x=%.4f y=%.4f vx=%.3f vy=%.3f g=%d" % (ra[0], ra[1], ra[2], ra[3], ra[4], ra[5], rb[1], rb[2], rb[3], rb[4], rb[5]))
        sys.exit(1)
print("PARITY OK %d" % len(a))
