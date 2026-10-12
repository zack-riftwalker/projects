#!/usr/bin/env python3
"""Writes godot/assets/audio/amb_fan.wav: the fan of a terminal. A 4 s seamless loop of soft low noise with a faint 120 Hz hum.
Standard library only (wave, math, random). Run: python3 -I tools/godot/make-ambience.py"""
import math, os, random, struct, wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot/assets/audio/amb_fan.wav")
RATE = 22050
SECS = 4.0
N = int(RATE * SECS)
XF = int(RATE * 0.4)               # the end is crossfaded into the start so the loop has no seam

random.seed(1234)
raw = []                          # noise through a one-pole low-pass, a little longer than the loop for the crossfade
y = 0.0
for _ in range(N + XF):
    y += 0.07 * (random.uniform(-1.0, 1.0) - y)
    raw.append(y)
noise = raw[:N]
for i in range(XF):                # the first XF samples start from the continuation of the end, so the wrap N-1 -> 0 is continuous
    k = i / XF
    noise[i] = raw[i] * k + raw[N + i] * (1.0 - k)
peak = max(abs(v) for v in noise) or 1.0
out = []
for i in range(N):
    hum = 0.06 * math.sin(2.0 * math.pi * 120.0 * i / RATE)      # 480 whole cycles in 4 s: seamless
    v = 0.30 * noise[i] / peak + hum
    out.append(max(-1.0, min(1.0, v)))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in out))
print("wrote", OUT, len(out), "samples")
