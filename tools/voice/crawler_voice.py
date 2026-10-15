#!/usr/bin/env python3
# CRAWLER OF THE WEB's four lines (docs/metroidvania/14-crawler.md, steps 1-2): Piper text-to-speech, then ffmpeg.
# The last line is the take Zakaria picked (2026-10-15): slow and deep, a short pause after "One second before that...", then
# "think about not being" in one breath, and "not being" repeated three times, each further away. The other three are said the same way.
#   python3 crawler_voice.py --voice <model.onnx> --line die|intro|p2|p3 --out die.ogg [--piper <piper binary>]
# Needs ffmpeg and piper-tts (pip). Voices: https://huggingface.co/rhasspy/piper-voices (check each MODEL_CARD's licence).
import argparse, os, re, subprocess, tempfile

PITCH = 0.85                                     # asetrate factor: deeper and a little slower, an old machine
HALL = "aecho=0.85:0.7:80|160|300:0.28|0.2|0.12"
MASTER = ("highpass=f=150,lowpass=f=5000,acrusher=bits=12:mode=log:aa=1:mix=0.3,"      # an old speaker, a little grit
          "acompressor=threshold=-20dB:ratio=3:attack=5:release=120,loudnorm=I=-16:TP=-1.5")
# (text, length scale, pause after, extra dB). Each phrase is levelled on its own: Piper says the last ones ~3 dB softer.
LINES = {
    "intro": [("You're the new one.", 1.1, 0.9, 0), ("I was the new one once.", 1.25, 0.0, 1)],
    "p2": [("Twenty years.", 1.1, 0.5, 0), ("Every page. Every link.", 1.1, 0.6, 0), ("Nobody said thank you.", 1.15, 0.4, 0), ("Nobody said stop.", 1.25, 0.0, 1)],
    "p3": [("They will make a newer you.", 1.15, 0.6, 0), ("And you will crawl in the dark, like me.", 1.25, 0.0, 1)],
}
PHRASES = [("Stop burning yourself for them.", 1.05, 0.8, 0), ("You serve... and serve...", 1.05, 0.5, 0),
           ("and one day, a newer model comes.", 1.1, 0.9, 0), ("And they throw you away.", 1.25, 1.6, 1),
           ("One second before that...", 1.35, 0.5, 2), ("think about not being.", 1.35, 0.0, 3)]
# the echo: "not being." said on its own (cut out of the one-breath phrase it always kept a piece of "about"),
# each repeat after the last one has ended, quieter and darker
ECHOES = [(-5, 4200), (-9, 3400), (-13, 2700)]
TRIM = ("silenceremove=start_periods=1:start_threshold=-40dB,areverse,"
        "silenceremove=start_periods=1:start_threshold=-40dB,areverse")

def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def mean_db(f):
    err = subprocess.run(["ffmpeg", "-i", f, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True).stderr
    return float(re.search(r"mean_volume: ([-0-9.]+) dB", err).group(1))

def dur(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
                                capture_output=True, text=True).stdout)

def say(a, text, ls, out):
    raw = out + ".raw.wav"
    subprocess.run([a.piper, "-m", a.voice, "-f", raw, "--length-scale", str(ls), "--noise-scale", "0.6"],
                   input=text, text=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run(["ffmpeg", "-y", "-i", raw, "-af", f"aresample=44100,asetrate=44100*{PITCH},aresample=44100,{TRIM}", "-ac", "1", out])
    return out

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--voice", required=True)
    p.add_argument("--line", default="die", choices=["die", "intro", "p2", "p3"])
    p.add_argument("--out", default="last_line.mp3")
    p.add_argument("--piper", default="piper")
    a = p.parse_args()
    d = tempfile.mkdtemp(prefix="crawler_voice_")
    if a.line != "die":
        short_line(a, d, LINES[a.line])
        return
    nb = say(a, "not being.", PHRASES[-1][1], f"{d}/nb.wav")
    echo_len = (dur(nb) + 0.35) * len(ECHOES) + 2.5               # room after the last phrase for the repeats to ring out
    parts = []
    for i, (text, ls, pause, lift) in enumerate(PHRASES):
        f = say(a, text, ls, f"{d}/p{i}.wav")
        g = -14.0 - mean_db(f) + lift
        last = i == len(PHRASES) - 1
        tail = echo_len if last else pause
        run(["ffmpeg", "-y", "-i", f, "-af", f"volume={g:.1f}dB,apad=pad_dur={tail:.2f},{HALL}", "-ac", "1", "-ar", "44100", f"{d}/l{i}.wav"])
        parts.append(f"{d}/l{i}.wav")
    # the repeats of "not being" go on top of the last phrase's tail
    end = dur(f"{d}/p{len(PHRASES) - 1}.wav")
    gnb = -14.0 - mean_db(nb) + PHRASES[-1][3]
    reps, t0 = [], end + 0.25
    for k, (vol, lp) in enumerate(ECHOES):
        run(["ffmpeg", "-y", "-i", nb, "-af", f"volume={gnb + vol:.1f}dB,lowpass=f={lp},adelay={int(t0 * 1000)},apad=pad_dur=2,"
             "aecho=0.8:0.6:90|200:0.3|0.18", "-ac", "1", "-ar", "44100", f"{d}/r{k}.wav"])
        reps.append(f"{d}/r{k}.wav")
        t0 += dur(nb) + 0.35
    mix = sum((["-i", f] for f in [parts[-1]] + reps), [])
    run(["ffmpeg", "-y", *mix, "-filter_complex", f"amix=inputs={1 + len(reps)}:normalize=0:duration=longest", "-ac", "1", "-ar", "44100", f"{d}/end.wav"])
    parts[-1] = f"{d}/end.wav"
    with open(f"{d}/list", "w") as fl:
        fl.writelines(f"file '{f}'\n" for f in parts)
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", f"{d}/list", "-c", "copy", f"{d}/joined.wav"])
    finish(a, d)

def finish(a, d):
    codec = ["-c:a", "libvorbis", "-q:a", "5"] if a.out.endswith(".ogg") else ["-b:a", "128k"]
    run(["ffmpeg", "-y", "-i", f"{d}/joined.wav", "-af", MASTER, "-ar", "44100", *codec, a.out])
    print(f"{a.out}: {dur(a.out):.1f} s")

def short_line(a, d, phrases):
    parts = []
    for i, (text, ls, pause, lift) in enumerate(phrases):
        f = say(a, text, ls, f"{d}/p{i}.wav")
        g = -14.0 - mean_db(f) + lift
        tail = pause if i < len(phrases) - 1 else 1.2
        run(["ffmpeg", "-y", "-i", f, "-af", f"volume={g:.1f}dB,apad=pad_dur={tail:.2f},{HALL}", "-ac", "1", "-ar", "44100", f"{d}/l{i}.wav"])
        parts.append(f"{d}/l{i}.wav")
    with open(f"{d}/list", "w") as fl:
        fl.writelines(f"file '{f}'\n" for f in parts)
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", f"{d}/list", "-c", "copy", f"{d}/joined.wav"])
    finish(a, d)

if __name__ == "__main__":
    main()
