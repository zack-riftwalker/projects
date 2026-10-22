#!/usr/bin/env python3
# RACE CONDITION's lines (docs/metroidvania/17-race-condition.md, steps 1-2): Piper text-to-speech, then ffmpeg.
# Two clockwork bell-strikers, TICK (young, quick, higher) and TOCK (old, heavy, lower), who say the same words at the same time:
# they start almost together and drift apart because TICK talks faster. That drift IS the race (the subtitles interleave the words).
#   python3 race_voice.py --female <ljspeech.onnx> --male <northern_english_male.onnx> --take a|b|c --out take.mp3 [--piper <bin>]
# Needs ffmpeg and piper-tts (pip). Both voices are shippable: LJ Speech is public domain, northern_english_male is CC BY-SA 4.0.
import argparse, subprocess, tempfile

# take -> (TICK voice, TICK pitch, TICK length scale, TOCK voice, TOCK pitch, TOCK length scale, clockwork strength 0..1)
TAKES = {
    "a": ("male", 1.14, 0.92, "male", 0.80, 1.08, 0.6),        # one voice, two throats: twins
    "b": ("female", 1.06, 0.92, "male", 0.84, 1.08, 0.6),      # a young woman and an old man
    "c": ("female", 1.20, 0.90, "female", 0.74, 1.12, 1.0),    # one voice, far apart, a strong music-box shimmer
}
# (kind, text(s), pause after, length multiplier). "both": the two say it together (TOCK starts a hair later); "tick"/"tock": one alone;
# "overlap": TICK's line, and TOCK's line starting halfway through it.
LINES = [
    ("both", "One at a time, little agent.", 2.0, 1.0),
    ("overlap", ("We both read zero.", "We both wrote one."), 2.0, 1.0),
    ("tick", "Who wrote last?", 0.35, 1.25),        # said slowly: at speed the speech recognizer heard "he wrote lust"
    ("tick", "Who. Wrote. Last?", 2.0, 1.1),
    ("tick", "After you.", 0.6, 1.0),
    ("tock", "No... after you.", 0.0, 1.0),
]
TRIM = ("silenceremove=start_periods=1:start_threshold=-40dB,areverse,"
        "silenceremove=start_periods=1:start_threshold=-40dB,areverse")

def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def dur(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
                                capture_output=True, text=True).stdout)

def clockwork(k):
    # a tin automaton: thin highs, a small metal box (short echo), a fast flutter like a spring, a little bit-crush
    return (f"highpass=f=180,equalizer=f=2600:t=q:w=1.2:g={4 * k},flanger=delay=2:depth={2 * k}:speed=6:regen=20,"
            f"tremolo=f=11:d={0.25 * k},acrusher=bits=11:mode=log:aa=1:mix={0.3 * k},aecho=0.8:0.4:18:0.25")

def say(a, who, text, take, out, mul=1.0):
    t = TAKES[take]
    voice, pitch, ls = (t[0], t[1], t[2]) if who == "tick" else (t[3], t[4], t[5])
    ls *= mul
    model = a.female if voice == "female" else a.male
    raw = out + ".raw.wav"
    subprocess.run([a.piper, "-m", model, "-f", raw, "--length-scale", str(ls), "--noise-scale", "0.5"],
                   input=text, text=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run(["ffmpeg", "-y", "-i", raw, "-af", f"aresample=44100,asetrate=44100*{pitch},aresample=44100,{TRIM},{clockwork(t[6])}",
         "-ac", "1", out])
    return out

def mix2(a_wav, b_wav, delay, out, b_db=0):
    ms = int(delay * 1000)
    run(["ffmpeg", "-y", "-i", a_wav, "-i", b_wav, "-filter_complex",
         f"[1]adelay={ms},volume={b_db}dB[b];[0][b]amix=inputs=2:normalize=0:duration=longest", "-ac", "1", out])
    return out

def silence(sec, out):
    run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", str(sec), out])
    return out

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--female", required=True)
    p.add_argument("--male", required=True)
    p.add_argument("--take", default="a", choices=sorted(TAKES))
    p.add_argument("--out", default="race.mp3")
    p.add_argument("--piper", default="piper")
    a = p.parse_args()
    d = tempfile.mkdtemp(prefix="race_voice_")
    parts = []
    for n, (kind, text, pause, mul) in enumerate(LINES):
        if kind == "both":
            w = mix2(say(a, "tick", text, a.take, f"{d}/{n}a.wav"), say(a, "tock", text, a.take, f"{d}/{n}b.wav"), 0.08, f"{d}/{n}.wav")
        elif kind == "overlap":
            ta = say(a, "tick", text[0], a.take, f"{d}/{n}a.wav")
            w = mix2(ta, say(a, "tock", text[1], a.take, f"{d}/{n}b.wav"), dur(ta) * 0.5, f"{d}/{n}.wav")
        else:
            w = say(a, kind, text, a.take, f"{d}/{n}.wav", mul)
        parts += [w, silence(pause + 0.01, f"{d}/{n}s.wav")]
    lst = f"{d}/list.txt"
    with open(lst, "w") as fh:
        fh.writelines(f"file '{x}'\n" for x in parts)
    codec = ["-c:a", "libvorbis", "-q:a", "4"] if a.out.endswith(".ogg") else ["-q:a", "2"]
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-af",
         "acompressor=threshold=-20dB:ratio=3,loudnorm=I=-16:TP=-1.5", "-ac", "1"] + codec + [a.out])

if __name__ == "__main__":
    main()
