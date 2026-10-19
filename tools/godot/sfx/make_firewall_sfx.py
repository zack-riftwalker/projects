#!/usr/bin/env python3
# The sounds of THE FIREWALL (docs/metroidvania/16-firewall-build.md, section 6), made from numbers like the game's other sounds:
# fw_ding (a soft hotel bell: the cookies), fw_ok200 (two rising chime notes: the door opens, 200 OK), fw_deny (two short low square beeps: a packet
# is inspected, a 429), fw_tock (a dry stone knock: a hit that does nothing), fw_hiss (steam: an arm, a fist, a gate gets ready),
# fw_whoosh (fire catching: the carpet, the face hops), fw_tapestop (a tone falling in pitch and speed: the music jams).
# Usage: python3 make_firewall_sfx.py <out dir>   (writes 16-bit mono 44.1 kHz WAVs; needs numpy)
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(2007)

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

def ding():
    return bell(1568.0, 0.9, 5.0)

def ok200():
    a = bell(1046.5, 0.45, 7.0)                          # C6, then G6 a step later: a rising "ding-dong" that says yes
    b = bell(1568.0, 0.9, 5.0)
    out = np.zeros(int(SR * 1.3))
    out[:len(a)] += a * 0.8
    i = int(SR * 0.22)
    out[i:i + len(b)] += b
    return out

def deny():
    parts = []
    for k in range(2):
        t = t_(0.13)
        sq = np.sign(np.sin(2 * np.pi * (112.0 - 6.0 * k) * t)) * 0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 168.0 * t))
        parts.append(sq * env(len(t), 0.004, 0.03))
        parts.append(np.zeros(int(SR * 0.08)))
    return np.concatenate(parts)

def tock():
    t = t_(0.09)
    knock = rng.standard_normal(len(t)) * np.exp(-t * 120) * 0.5
    body = np.sin(2 * np.pi * 210 * t) * np.exp(-t * 55) + 0.5 * np.sin(2 * np.pi * 330 * t) * np.exp(-t * 80)
    return (knock + body) * env(len(t), 0.0005, 0.02)

def hiss():
    t = t_(0.5)
    n = rng.standard_normal(len(t))
    hp = n - np.convolve(n, np.ones(8) / 8.0, mode="same")          # a crude high-pass: steam
    swell = np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 0.7
    return hp * swell * 0.7

def whoosh():
    t = t_(0.9)
    n = rng.standard_normal(len(t))
    k = np.cumsum(n) / 80.0                                         # brown-ish noise: the roar of a flame taking
    k -= np.convolve(k, np.ones(2000) / 2000.0, mode="same")
    crack = np.zeros(len(t))
    for _ in range(26):
        i = int(rng.uniform(0.05, 0.85) * SR)
        m = int(SR * 0.012)
        crack[i:i + m] += rng.standard_normal(m) * np.exp(-np.arange(m) / SR * 500) * rng.uniform(0.3, 1.0)
    swell = np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 1.2
    return (k * 1.6 * swell + crack * 0.6) * env(len(t), 0.01, 0.1)

def tapestop():
    t = t_(0.8)
    f = 520.0 * np.exp(-t * 3.2) + 40.0                              # the pitch falls, and slower and slower
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) + 0.35 * np.sign(np.sin(2 * np.pi * ph * 2.0)) * 0.5
    wob = 1.0 - 0.3 * np.sin(2 * np.pi * (12.0 * np.exp(-t * 2.0)) * t)
    return x * wob * (1.0 - t / 0.8) ** 0.6 * env(len(t), 0.003, 0.05)

for name, fn in (("fw_ding", ding), ("fw_ok200", ok200), ("fw_deny", deny), ("fw_tock", tock), ("fw_hiss", hiss), ("fw_whoosh", whoosh), ("fw_tapestop", tapestop)):
    save(name, fn())
    print(name)
