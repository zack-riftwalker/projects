#!/usr/bin/env python3
# RACE CONDITION's lines (docs/metroidvania/17-race-condition.md, steps 1-2): Piper text-to-speech, then ffmpeg.
# Two clockwork bell-strikers, TICK (young, quick, higher) and TOCK (old, heavy, lower), who say the same words at the same time:
# they start almost together and drift apart because TICK talks faster. That drift IS the race (the subtitles interleave the words).
#   python3 race_voice.py --female <ljspeech.onnx> --male <northern_english_male.onnx> --take a|b|c --out take.mp3 [--piper <bin>]
#   python3 race_voice.py ... --line intro|p2|alone|alone_tock|die --out race_<key>.ogg --json <key>.json   (one game line, and when each word starts)
# The word times come from a speech recognizer (faster-whisper base.en, pip) listening to each voice on its own before the mix; when it
# does not hear the right words, the times are spread over the voice by letters instead (marked "est" in the json).
# Needs ffmpeg and piper-tts (pip). Both voices are shippable: LJ Speech is public domain, northern_english_male is CC BY-SA 4.0.
import argparse, json, re, subprocess, tempfile

# take -> (TICK voice, TICK pitch, TICK length scale, TOCK voice, TOCK pitch, TOCK length scale, clockwork strength 0..1)
TAKES = {
    "a": ("male", 1.14, 0.92, "male", 0.80, 1.08, 0.6),        # one voice, two throats: twins
    "b": ("female", 1.06, 0.92, "male", 0.84, 1.08, 0.6),      # a young woman and an old man
    "c": ("female", 1.20, 0.90, "female", 0.74, 1.12, 1.0),    # one voice, far apart, a strong music-box shimmer
}
# key -> parts. A part is (kind, text(s), pause after, length multiplier). "both": the two say it together (TOCK starts a hair later);
# "tick"/"tock": one alone; "overlap": TICK's line, and TOCK's line starting halfway through it.
KEYS = {
    "intro": [("both", "One at a time, little agent.", 0.0, 1.0)],
    "p2": [("overlap", ("We both read zero.", "We both wrote one."), 0.0, 1.0)],
    # the survivor says it slowly: at speed the speech recognizer heard "he wrote lust"; the second time word by word
    "alone": [("tick", "Who wrote last?", 0.35, 1.25), ("tick", "Who. Wrote. Last?", 0.0, 1.1)],
    "alone_tock": [("tock", "Who wrote last?", 0.35, 1.25), ("tock", "Who. Wrote. Last?", 0.0, 1.1)],        # (the same, when TOCK is the one left)
    "die": [("tick", "After you.", 0.6, 1.0), ("tock", "No... after you.", 0.0, 1.0)],
}
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

def word_times(wav, text):
    """[[word, start s]] of one voice's wav (the words as they will be shown)"""
    shown = text.split()
    n = dur(wav)
    try:
        from faster_whisper import WhisperModel
        import numpy as np, wave
        m = word_times.model = getattr(word_times, "model", None) or WhisperModel("base.en", device="cpu", compute_type="int8")
        w16 = wav + ".16k.wav"
        run(["ffmpeg", "-y", "-i", wav, "-ar", "16000", "-ac", "1", w16])
        with wave.open(w16) as wf:
            audio = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        segs, _ = m.transcribe(audio, language="en", word_timestamps=True, beam_size=5)
        heard = [(re.sub(r"[^a-z0-9']", "", x.word.lower()), x.start) for sg in segs for x in sg.words]
        want = [re.sub(r"[^a-z0-9']", "", x.lower()) for x in shown]
        heard = [h for h in heard if h[0]]
        if [h[0] for h in heard] == [x for x in want if x]:
            out, last = [], -1.0
            for k in range(len(shown)):                       # (the recognizer's word starts jitter: no two words closer than 0.1 s)
                last = max(float(heard[k][1]), last + 0.1)
                out.append([shown[k], round(last, 2)])
            return out, "asr"
    except Exception as e:
        print("no recognizer:", e)
    tot = sum(len(x) + 1 for x in shown)
    t, out = 0.0, []
    for x in shown:
        out.append([x, round(t, 2)])
        t += n * (len(x) + 1) / tot
    return out, "est"

def build(a, key, d):
    """one game line: the audio file and the words of each voice with their start times"""
    parts, tracks, t = [], [], 0.0
    for n, (kind, text, pause, mul) in enumerate(KEYS[key]):
        if kind == "both":
            wa, wb = say(a, "tick", text, a.take, f"{d}/{n}a.wav"), say(a, "tock", text, a.take, f"{d}/{n}b.wav")
            w = mix2(wa, wb, 0.08, f"{d}/{n}.wav")
            tracks += [(0, text, t, wa), (1, text, t + 0.08, wb)]
        elif kind == "overlap":
            wa, wb = say(a, "tick", text[0], a.take, f"{d}/{n}a.wav"), say(a, "tock", text[1], a.take, f"{d}/{n}b.wav")
            w = mix2(wa, wb, dur(wa) * 0.5, f"{d}/{n}.wav")
            tracks += [(0, text[0], t, wa), (1, text[1], t + dur(wa) * 0.5, wb)]
        else:
            w = say(a, kind, text, a.take, f"{d}/{n}.wav", mul)
            tracks.append((0 if kind == "tick" else 1, text, t, w))
        parts += [w, silence(pause + 0.01, f"{d}/{n}s.wav")]
        t += dur(w) + pause + 0.01
    return parts, tracks

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--female", required=True)
    p.add_argument("--male", required=True)
    p.add_argument("--take", default="a", choices=sorted(TAKES))
    p.add_argument("--out", default="race.mp3")
    p.add_argument("--line", choices=sorted(KEYS))
    p.add_argument("--json")
    p.add_argument("--piper", default="piper")
    a = p.parse_args()
    d = tempfile.mkdtemp(prefix="race_voice_")
    parts, meta = [], {}
    for key in ([a.line] if a.line else ["intro", "p2", "alone", "alone_tock", "die"]):
        ps, tracks = build(a, key, f"{d}")
        parts += ps + ([] if a.line else [silence(2.0, f"{d}/{key}_gap.wav")])
        meta[key] = tracks
    lst = f"{d}/list.txt"
    with open(lst, "w") as fh:
        fh.writelines(f"file '{x}'\n" for x in parts)
    codec = ["-c:a", "libvorbis", "-q:a", "4"] if a.out.endswith(".ogg") else ["-q:a", "2"]
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-af",
         "acompressor=threshold=-20dB:ratio=3,loudnorm=I=-16:TP=-1.5", "-ac", "1"] + codec + [a.out])
    if a.json and a.line:
        out = {"len": round(dur(a.out), 2), "words": []}
        how = set()
        for who, text, t0, wav in meta[a.line]:
            ws, h = word_times(wav, text)
            how.add(h)
            out["words"] += [[w, round(t0 + tm, 2), who] for w, tm in ws]
        out["words"].sort(key=lambda w: w[1])
        out["how"] = "/".join(sorted(how))
        json.dump(out, open(a.json, "w"), indent=1)
        print(a.line, out["len"], "s", out["how"], [(w[0], w[1], w[2]) for w in out["words"]])

if __name__ == "__main__":
    main()
