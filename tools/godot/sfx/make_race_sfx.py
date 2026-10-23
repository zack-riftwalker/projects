#!/usr/bin/env python3
# The sounds of RACE CONDITION (docs/metroidvania/17-race-build.md, section 6), made from numbers like the game's other sounds:
# rc_bell1/2/3 (a big, a middle and a small bronze bell), rc_crash (a cracked bell: two strikes that do not agree), rc_rattle (a cracking chain-hung bell),
# rc_fall (a bell letting go and landing), rc_chain (a chain running), rc_whirr (a hammer going up), rc_thunk (a hammer stuck in the floor), rc_shot (a
# clapper leaving), rc_creak (a rope), rc_eye (a tiny tick: an eye opens), rc_key (a wind-up key, a ratchet), rc_lock (the escapement clanging shut),
# rc_anchor (the anchor creaks), rc_pin (the pin clicks in). (The tower's tick and tock are the game's own tick.wav / tock.wav.)
# Usage: python3 make_race_sfx.py <out dir>   (writes 16-bit mono 44.1 kHz WAVs; needs numpy)
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(1707)

def save(name, x):
    x = np.clip(x / max(1e-6, np.max(np.abs(x))) * 0.85, -1.0, 1.0)
    with wave.open(f"{sys.argv[1]}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def t_(sec):
    return np.arange(int(SR * sec)) / SR

def env(n, a=0.005, r=0.05):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] = np.linspace(1, 0, nr)
    return e

def bell(f, sec, decay):
    t = t_(sec)
    x = np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * decay * 1.7) + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * decay * 3.0)
    return x * np.exp(-t * decay) * env(len(t), 0.002, 0.03)

def bronze(f, sec, decay, detune=1.0):
    t = t_(sec)
    x = (np.sin(2 * np.pi * f * t) + 0.55 * np.sin(2 * np.pi * f * 2.0 * detune * t) * np.exp(-t * decay * 1.4)
         + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * decay * 1.8) + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * decay * 3.5))
    hit = rng.standard_normal(len(t)) * np.exp(-t * 90) * 0.4
    return (x * np.exp(-t * decay) + hit) * env(len(t), 0.001, 0.05)

def noise_burst(sec, decay, lo=1):
    t = t_(sec)
    n = rng.standard_normal(len(t))
    if lo > 1:
        n = n - np.convolve(n, np.ones(lo) / lo, mode="same")
    return n * np.exp(-t * decay)

def mix(parts, total):
    out = np.zeros(int(SR * total))
    for at, x in parts:
        i = int(SR * at)
        out[i:i + len(x)] += x[:max(0, len(out) - i)]
    return out

def bell1(): return bronze(196.0, 1.6, 3.2)
def bell2(): return bronze(294.0, 1.3, 4.0)
def bell3(): return bronze(440.0, 1.0, 5.5)
def crash(): return mix([(0.0, bronze(233.0, 1.0, 5.0, 1.03)), (0.012, bronze(247.0, 1.0, 5.0, 0.97)), (0.0, noise_burst(0.3, 18, 6) * 0.5)], 1.0)

def rattle():
    parts = []
    for k in range(9):
        parts.append((k * 0.045 + rng.uniform(0, 0.015), bronze(rng.uniform(900, 1500), 0.12, 38) * rng.uniform(0.3, 0.8)))
    return mix(parts, 0.6)

def fall():
    t = t_(0.5)
    whistle = np.sin(2 * np.pi * np.cumsum(300.0 + 500.0 * t) / SR) * 0.15 * t / 0.5
    thud = bronze(110.0, 0.9, 6.0) * 1.3 + noise_burst(0.9, 14, 12) * 0.8
    return mix([(0.0, whistle), (0.46, thud)], 1.3)

def chain():
    parts = []
    for k in range(14):
        parts.append((k * 0.035 + rng.uniform(0, 0.01), noise_burst(0.04, 90, 4) * rng.uniform(0.3, 1.0)))
    return mix(parts, 0.6)

def whirr():
    t = t_(0.25)
    f = 140.0 + 700.0 * t / 0.25
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 * (1 + 0.5 * np.sin(2 * np.pi * 60 * t))
    return x * np.sin(np.pi * np.clip(t / 0.25, 0, 1)) ** 0.5

def thunk():
    t = t_(0.2)
    return (np.sin(2 * np.pi * 85 * t) * np.exp(-t * 28) + noise_burst(0.2, 60, 10) * 0.6) * env(len(t), 0.0005, 0.03)

def shot():
    t = t_(0.3)
    f = 900.0 * np.exp(-t * 9) + 140.0
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 10) * env(len(t), 0.0008, 0.05) + noise_burst(0.3, 30, 6) * 0.2

def creak():
    t = t_(0.7)
    f = 95.0 + 25.0 * np.sin(2 * np.pi * 3.0 * t) + 30.0 * t
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 * (1 + 0.6 * rng.standard_normal(len(t)) * 0.2)
    return x * np.sin(np.pi * np.clip(t / 0.7, 0, 1)) * 0.8

def eye():
    t = t_(0.05)
    return np.sin(2 * np.pi * 3200 * t) * np.exp(-t * 80) * 0.8

def key():
    parts = []
    for k in range(10):
        parts.append((k * 0.07, noise_burst(0.025, 160, 3) * 0.9 + 0.0 * np.zeros(int(SR * 0.025))))
        parts.append((k * 0.07 + 0.035, np.sin(2 * np.pi * (1500 + 40 * k) * t_(0.02)) * np.exp(-t_(0.02) * 200) * 0.4))
    return mix(parts, 0.8)

def lock():
    return mix([(0.0, bronze(130.0, 0.8, 7.0) * 1.2), (0.0, noise_burst(0.25, 30, 5) * 0.7), (0.1, bronze(520.0, 0.4, 14.0) * 0.6)], 0.9)

def anchor():
    t = t_(0.9)
    f = 70.0 + 18.0 * np.sin(2 * np.pi * 2.0 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.6 * np.sin(np.pi * np.clip(t / 0.9, 0, 1)) + noise_burst(0.9, 3, 30) * 0.05

def pin():
    return mix([(0.0, np.sin(2 * np.pi * 2400 * t_(0.04)) * np.exp(-t_(0.04) * 120)), (0.06, np.sin(2 * np.pi * 1700 * t_(0.12)) * np.exp(-t_(0.12) * 50) * 0.8),
                (0.0, noise_burst(0.1, 80, 4) * 0.4)], 0.3)

for name, fn in (("rc_bell1", bell1), ("rc_bell2", bell2), ("rc_bell3", bell3), ("rc_crash", crash), ("rc_rattle", rattle), ("rc_fall", fall), ("rc_chain", chain),
                 ("rc_whirr", whirr), ("rc_thunk", thunk), ("rc_shot", shot), ("rc_creak", creak), ("rc_eye", eye), ("rc_key", key), ("rc_lock", lock),
                 ("rc_anchor", anchor), ("rc_pin", pin)):
    save(name, fn())
    print(name)
