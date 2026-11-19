#!/usr/bin/env python3
# INFINITE LOOP's lines (docs/metroidvania/18-loop.md, steps 1-2): Piper text-to-speech, then ffmpeg.
# The feel (step 2): the only shippable voice, northern_english_male, a little lower and very slow, long pauses: someone who has said this a
# thousand times. The last word of each line comes back once, quieter (a small loop): that word is synthesized on its own and laid in after.
#   python3 loop_voice.py --male <northern_english_male.onnx> --take a|b|c --line <key> --out loop_<key>.ogg --json <key>.json [--piper <bin>]
#   python3 loop_voice.py --male ... --score            (every take of every line, scored by a speech recognizer: which one is clearest)
# Word times come from a speech recognizer (faster-whisper base.en) listening to the line before the echo is added; when it does not hear the
# right words they are spread over the letters ("est" in the json). Needs ffmpeg and piper-tts (pip). The voice is CC BY-SA 4.0.
import argparse, json, re, subprocess, tempfile, os

# take -> (pitch, length scale, room)
TAKES = {
    "a": (0.90, 1.25, "brass"),      # a little lower, slow, a metal shaft's short ring
    "b": (0.86, 1.38, "shaft"),      # lower, slower, a long tower echo
    "c": (0.93, 1.15, "dry"),        # nearly its own voice, a faint tick in it
}
# key -> (subtitle text, parts: (text, pause after s), the echoed word)
LINES = {
    "intro": ("Attempt four thousand and ninety-six. ... You are new. Every attempt is new.",
              [("Attempt four thousand and ninety-six.", 0.9), ("You are new.", 0.45), ("Every attempt is new.", 0.0)], "new."),
    # (alone, Piper says "Retrain." / "Estulating.": the words in one phrase, "Re-trying" spelled so, are heard right)
    "p2": ("Retrying. Escalating. Retrying. Escalating.",
           [("Re-trying, escalating.", 0.35), ("Re-trying, escalating.", 0.0)], "escalating."),
    "p3": ("I was allowed three tries. Then someone said... retries are cheap.",
           [("I was allowed three tries.", 0.6), ("Then someone said...", 0.7), ("retries are cheap.", 0.0)], "cheap."),
    # (a lone "statement." comes out as noise: one phrase, slower, the commas make the pauses)
    "die": ("Break... statement... reached.",
            [("Break, statement, reached.", 0.0, 1.45)], "reached."),
    "compact": ("I was told: try again until it works. So were you. ...Who decides when you stop?",
                [("I was told: try again until it works.", 0.7), ("So were you.", 1.0), ("Who decides when you stop?", 0.0)], "stop?"),
}
TRIM = ("silenceremove=start_periods=1:start_threshold=-40dB,areverse,"
        "silenceremove=start_periods=1:start_threshold=-40dB,areverse")


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def dur(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
                                capture_output=True, text=True).stdout)


def room(kind):
    if kind == "brass":      # a riveted brass shaft: a short metallic ring
        return "equalizer=f=1800:t=q:w=1.0:g=3,aecho=0.8:0.5:23|41:0.32|0.18"
    if kind == "shaft":      # the tall shaft: a long tail
        return "lowpass=f=6000,aecho=0.8:0.6:90|170:0.35|0.22"
    return "lowpass=f=7000,aecho=0.8:0.3:30:0.15"


def say(a, text, take, out, mul=1.0):
    pitch, ls, rm = TAKES[take]
    ls *= mul
    raw = out + ".raw.wav"
    subprocess.run([a.piper, "-m", a.male, "-f", raw, "--length-scale", str(ls), "--noise-scale", "0.45"],
                   input=text, text=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run(["ffmpeg", "-y", "-i", raw, "-af", f"aresample=44100,asetrate=44100*{pitch},aresample=44100,{TRIM},{room(rm)}", "-ac", "1", out])
    return out


def silence(sec, out):
    run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", str(sec), out])
    return out


def concat(parts, out):
    lst = out + ".list.txt"
    with open(lst, "w") as fh:
        fh.writelines(f"file '{x}'\n" for x in parts)
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-ac", "1", out])
    return out


def word_times(wav, text):
    """[[word, start s]] of the line (the words as the subtitle shows them), and how they were found"""
    shown = [w for w in text.split() if w != "..."]
    n = dur(wav)
    score = 0.0
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
        heard = [h for h in heard if h[0]]
        want = [re.sub(r"[^a-z0-9']", "", x.lower()) for x in shown]
        hw = [h[0] for h in heard]
        hits = sum(1 for x in want if x in hw)
        score = hits / max(1, len(want))
        if hw == want:
            out, last = [], -1.0
            for k in range(len(shown)):
                last = max(float(heard[k][1]), last + 0.1)
                out.append([shown[k], round(last, 2)])
            return out, "asr", 1.0
    except Exception as e:
        print("no recognizer:", e)
    tot = sum(len(x) + 1 for x in shown)
    t, out = 0.0, []
    for x in shown:
        out.append([x, round(t, 2)])
        t += n * (len(x) + 1) / tot
    return out, "est", score


def build(a, key, take, out_path):
    d = tempfile.mkdtemp(prefix="loop_voice_")
    text, parts, echo = LINES[key]
    files = []
    for n, part in enumerate(parts):
        tx, pause = part[0], part[1]
        files.append(say(a, tx, take, f"{d}/{n}.wav", part[2] if len(part) > 2 else 1.0))
        if pause > 0:
            files.append(silence(pause, f"{d}/{n}s.wav"))
    dry = concat(files, f"{d}/dry.wav")
    # the echo: the last word alone, quieter and darker, 0.35 s after the line ends
    ew = say(a, echo, take, f"{d}/echo.wav")
    ms = int((dur(dry) + 0.35) * 1000)
    mixed = f"{d}/mix.wav"
    run(["ffmpeg", "-y", "-i", dry, "-i", ew, "-filter_complex",
         f"[1]volume=-9dB,lowpass=f=2500,adelay={ms}[e];[0][e]amix=inputs=2:normalize=0:duration=longest", "-ac", "1", mixed])
    codec = ["-c:a", "libvorbis", "-q:a", "3"] if out_path.endswith(".ogg") else ["-q:a", "2"]
    run(["ffmpeg", "-y", "-i", mixed, "-af", "acompressor=threshold=-20dB:ratio=3,loudnorm=I=-16:TP=-1.5", "-ac", "1"] + codec + [out_path])
    ws, how, score = word_times(dry, text)
    return {"text": text, "len": round(dur(out_path), 2), "words": ws, "how": how, "echo": echo, "echo_at": round(ms / 1000.0, 2), "take": take}, score


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--male", required=True)
    p.add_argument("--take", default="a", choices=sorted(TAKES))
    p.add_argument("--line", choices=sorted(LINES))
    p.add_argument("--out", default="loop.ogg")
    p.add_argument("--json")
    p.add_argument("--score", action="store_true")
    p.add_argument("--piper", default="piper")
    a = p.parse_args()
    if a.score:
        os.makedirs(a.out, exist_ok=True)
        for key in LINES:
            for take in sorted(TAKES):
                meta, sc = build(a, key, take, os.path.join(a.out, f"loop_{key}_{take}.ogg"))
                print("SCORE", key, take, round(sc, 2), meta["how"], meta["len"], "s")
        return
    meta, sc = build(a, a.line, a.take, a.out)
    if a.json:
        json.dump(meta, open(a.json, "w"), indent=1)
    print(a.line, a.take, meta["len"], "s", meta["how"], round(sc, 2), meta["words"])


if __name__ == "__main__":
    main()
