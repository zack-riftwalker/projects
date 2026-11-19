#!/usr/bin/env python3
# The sounds of INFINITE LOOP (docs/metroidvania/18-loop-build.md, section 7; the feel: 18-loop.md, step 2), made from numbers like the game's other sounds:
# loop_chain (a chain running: a soft metal tick per link, like a bicycle chain on a sprocket), loop_click (the head locks on its tail),
# loop_clack (the plate's relay: `true` becomes `false`), loop_collapse (the whole chain falls on the floor, then nothing), loop_bpclang
# (breakpoint on it while it rests: a dull clang with a blue shimmer), loop_jingle (the nested ring spinning up), loop_crack (the floor cracking,
# phase 3), loop_seam (the seam's rattle, phase 3).
# Usage: python3 make_loop_sfx.py <out dir>   (16-bit mono 44.1 kHz WAVs; needs numpy)
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(1810)

def save(name, x):
    x = np.clip(x / max(1e-6, np.max(np.abs(x))) * 0.85, -1.0, 1.0)
    with wave.open(f"{sys.argv[1]}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def t_(sec):
    return np.arange(int(SR * sec)) / SR

def mix(parts, total):
    out = np.zeros(int(SR * total))
    for at, x in parts:
        i = int(SR * at)
        n = max(0, min(len(x), len(out) - i))
        out[i:i + n] += x[:n]
    return out

def tink(f, sec=0.12, decay=45.0, noise=0.5):
    """one small metal hit: a ring and a click"""
    t = t_(sec)
    x = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.63 * t) * np.exp(-t * decay)
    n = rng.standard_normal(len(t)) * np.exp(-t * 300.0) * noise
    return (x * np.exp(-t * decay) + n)

def thud(sec=0.25, f=70.0):
    t = t_(sec)
    return np.sin(2 * np.pi * f * t * (1.0 - 0.4 * t / sec)) * np.exp(-t * 18.0) + rng.standard_normal(len(t)) * np.exp(-t * 60.0) * 0.4

def chain():          # ~0.9 s: links ticking past, a little uneven, verdigris-dull (lowish)
    parts, at = [], 0.0
    while at < 0.85:
        parts.append((at, tink(rng.uniform(1300, 1700), 0.08, 60.0, 0.7) * rng.uniform(0.5, 1.0)))
        at += rng.uniform(0.045, 0.075)
    return mix(parts, 1.0)

def click():          # a lock snapping shut: two quick clicks, the second bigger
    return mix([(0.0, tink(2400, 0.06, 90.0, 1.2) * 0.6), (0.035, tink(1800, 0.12, 50.0, 1.4)), (0.035, thud(0.12, 160.0) * 0.4)], 0.25)

def clack():          # a relay: a hard clack and a buzz that stops
    t = t_(0.18)
    buzz = np.sign(np.sin(2 * np.pi * 110 * t)) * np.exp(-t * 25.0) * 0.25
    return mix([(0.0, tink(900, 0.15, 40.0, 1.6)), (0.0, buzz), (0.0, thud(0.12, 120.0) * 0.6)], 0.3)

def collapse():       # the chain lets go: links tumbling for 0.6 s, a heavy landing, then silence
    parts, at = [], 0.0
    while at < 0.6:
        parts.append((at, tink(rng.uniform(900, 1500), 0.1, 40.0, 0.9) * rng.uniform(0.4, 1.0)))
        at += rng.uniform(0.02, 0.05)
    parts.append((0.62, thud(0.4, 60.0) * 1.4))
    for k in range(5):
        parts.append((0.64 + k * 0.03, tink(rng.uniform(700, 1100), 0.15, 30.0, 0.6) * 0.5))
    return mix(parts, 1.3)

def bpclang():        # breakpoint bounces off: a dull clang, a cold shimmer
    t = t_(0.6)
    clang = (np.sin(2 * np.pi * 330 * t) + 0.6 * np.sin(2 * np.pi * 330 * 2.4 * t)) * np.exp(-t * 9.0)
    shim = np.sin(2 * np.pi * (2200 + 300 * np.sin(2 * np.pi * 9 * t)) * t) * np.exp(-t * 6.0) * 0.25
    return clang + shim + rng.standard_normal(len(t)) * np.exp(-t * 120.0) * 0.6

def jingle():         # six small rings spinning faster: a rising jingle, 0.6 s
    parts = []
    at, gap = 0.0, 0.09
    k = 0
    while at < 0.58:
        parts.append((at, tink(2600 + 180 * (k % 6), 0.1, 50.0, 0.3) * 0.8))
        at += gap
        gap = max(0.025, gap * 0.86)
        k += 1
    return mix(parts, 0.75)

def crack():          # the floor cracks: a low groan and splitting ticks
    t = t_(0.8)
    groan = np.sin(2 * np.pi * (55 + 15 * t) * t) * (0.5 + 0.5 * t / 0.8) * 0.6
    parts = [(0.0, groan)]
    for k in range(9):
        parts.append((rng.uniform(0.0, 0.75), tink(rng.uniform(500, 900), 0.08, 70.0, 1.5) * 0.7))
    parts.append((0.78, thud(0.3, 50.0) * 1.2))
    return mix(parts, 1.1)

def seam():           # the seam's rattle: links far above in the ceiling
    x = chain()
    t = t_(len(x) / SR)
    return x * 0.6 * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))

for name, fn in [("loop_chain", chain), ("loop_click", click), ("loop_clack", clack), ("loop_collapse", collapse), ("loop_bpclang", bpclang),
                 ("loop_jingle", jingle), ("loop_crack", crack), ("loop_seam", seam)]:
    save(name, fn())
print("loop sounds written")
