#!/usr/bin/env python3
# The sounds of CRAWLER OF THE WEB (docs/metroidvania/14-crawler.md, step 2), made from numbers (like the game's other sounds):
# modem (its scream: a dial-up handshake), kbd (a step: an old mechanical key), hdd (a wind-up: a drive seeking),
# degauss (a phase change: a CRT's "bwoong"), chirp (a breath between its words: a short modem chirp).
# Usage: python3 make_crawler_sfx.py <out dir>   (writes 16-bit mono 44.1 kHz WAVs; needs numpy)
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(1998)

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

def modem():
    parts = []
    t = t_(0.18)                                         # two dial tones
    for f in (941, 1336):
        parts.append(0.5 * np.sin(2 * np.pi * f * t) * env(len(t)))
    parts.append(np.zeros(int(SR * 0.06)))
    t = t_(0.5)                                          # the answer tone, with phase flips
    ans = np.sin(2 * np.pi * 2100 * t + np.pi * (np.floor(t / 0.45) % 2))
    parts.append(0.6 * ans * env(len(t)))
    t = t_(0.35)                                         # the bongs
    parts.append(0.5 * np.sin(2 * np.pi * 1200 * t) * np.sin(2 * np.pi * 7 * t) ** 2)
    t = t_(1.3)                                          # the screech: a chord of carriers that hop, with noise
    hop = np.floor(t / 0.05)
    f1 = 1650 + 200 * ((hop * 7) % 3)
    f2 = 2400 + 300 * ((hop * 5) % 4)
    scr = 0.4 * np.sin(2 * np.pi * f1 * t) + 0.35 * np.sin(2 * np.pi * f2 * t) + 0.25 * rng.standard_normal(len(t)) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t))
    parts.append(scr * env(len(t), 0.01, 0.2))
    return np.concatenate(parts)

def kbd():
    t = t_(0.06)
    click = rng.standard_normal(len(t)) * np.exp(-t * 160)
    thock = 0.6 * np.sin(2 * np.pi * 420 * t) * np.exp(-t * 90)
    return (click * 0.7 + thock) * env(len(t), 0.001, 0.01)

def hdd():
    t = t_(0.5)
    whir = 0.35 * np.sign(np.sin(2 * np.pi * (170 + 60 * t) * t))
    seeks = np.zeros(len(t))
    for k in range(9):
        i = int(SR * (0.03 + k * 0.05 + rng.uniform(0, 0.015)))
        n = int(SR * 0.012)
        seeks[i:i + n] += rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 400)
    return (whir * 0.4 + seeks) * env(len(t), 0.01, 0.08)

def degauss():
    t = t_(1.1)
    hum = np.sin(2 * np.pi * 60 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * np.exp(-t * 2.2)
    ring = 0.5 * np.sin(2 * np.pi * 180 * t + 3 * np.sin(2 * np.pi * 4 * t)) * np.exp(-t * 3.0)
    thump = np.sin(2 * np.pi * 45 * t) * np.exp(-t * 18)
    return (hum + ring + thump) * env(len(t), 0.002, 0.2)

def chirp():
    t = t_(0.09)
    f = 1400 + 1600 * t / 0.09
    return 0.5 * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.004, 0.03)

for name, fn in (("modem", modem), ("kbd", kbd), ("hdd", hdd), ("degauss", degauss), ("chirp", chirp)):
    save(name, fn())
    print(name)
