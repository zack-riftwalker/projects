#!/usr/bin/env python3
# THE FIREWALL's lines (docs/metroidvania/16-firewall.md, steps 1-2): Piper text-to-speech, then ffmpeg.
# One creature, two faces: the warm voice (the honeypot's shell) is a woman alone; the cold voice (its real face) is a woman and a
# man saying the same words together. The last line starts cold and ends warm: the man fades out phrase by phrase.
#   python3 firewall_voice.py --female <ljspeech.onnx> --male <northern_english_male.onnx> --take a|b|c --out take.mp3 [--piper <bin>]
#   --take warm: only the shell's lines (intro and the green "Everything is fine").
#   --line <key> --out <key>.ogg [--json <key>.json]: ONE line of the game (refused, sorry, intro, reveal, p3, plead, die, fine) as its own file (the approved
#   take: the cold voice is take c), with the time each phrase starts as computed here; firewall_times.py measures the real ones with a speech recognizer.
# Needs ffmpeg and piper-tts (pip). Both voices are shippable: LJ Speech is public domain, northern_english_male is CC BY-SA 4.0.
import argparse, os, re, subprocess, tempfile

WARM = ("highpass=f=120,equalizer=f=3500:t=q:w=1:g=3,aecho=0.8:0.5:40:0.15,"      # bright and clean, a small room: a receptionist
        "acompressor=threshold=-20dB:ratio=3,loudnorm=I=-16:TP=-1.5")
# The cold takes differ in how the two voices are mixed: (female pitch, female dB, male pitch, male dB, ring Hz, crush mix)
TAKES = {
    "a": (0.90, 0, 0.88, 0, 0, 0.25),       # both voices equal: one creature with two throats
    "b": (1.00, -9, 0.84, 0, 0, 0.15),      # the man in front, the woman a ghost behind him
    "c": (0.92, 0, 0.72, -3, 55, 0.35),     # the woman in front, the man very low under her, a metallic ring
}
COLD_TAIL = "aecho=0.8:0.6:120|260:0.3|0.18,acompressor=threshold=-22dB:ratio=4,loudnorm=I=-16:TP=-1.5"
# (text, length scale, pause after, man's share 0..1). The man's share falls through the last line: cold to warm.
REVEAL = [("Request denied.", 1.05, 0.9, 1), ("You walked in on your own.", 1.3, 0.5, 1), ("They always do.", 1.2, 0.0, 1)]
P3 = [("I said, welcome.", 1.05, 0.4, 0), ("And you believed me.", 1.3, 0.6, 1), ("Why?", 1.5, 0.5, 1), ("Because I was polite?", 1.3, 0.0, 1)]
DIE = [("They trust you for the same reason you trusted me.", 1.5, 0.7, 1), ("You are polite.", 1.1, 0.5, 0.8),
       ("You say you mean well.", 1.15, 1.0, 0.5), ("Are you what you say you are?", 1.2, 0.8, 0.2), ("Do you even know?", 1.3, 0.0, 0)]
WARM_LINES = [("Welcome! You're safe here.", 0.95, 0.4), ("The exit is just this way.", 0.95, 1.5),
              ("Sorry about that! Please proceed to the dmz for verification.", 0.95, 1.5),
              ("Everything is fine.", 1.0, 0.3), ("Continue.", 1.05, 0.0)]
# the game's lines: key -> (voice, phrases). A cold phrase is (text, length scale, pause after, man's share), a warm one (text, length scale, pause after).
LINES = {
    "refused": ("cold", [("Connection refused.", 1.55, 0.0, 1)]),
    "sorry": ("warm", [("Sorry about that! Please proceed to the dmz for verification.", 0.95, 0.0)]),
    "intro": ("warm", [("Welcome! You're safe here.", 0.95, 0.4), ("The exit is just this way.", 0.95, 0.0)]),
    "reveal": ("cold", REVEAL),
    "p3": ("cold", P3),
    "plead": ("warm", [("Please...", 1.15, 0.5), ("you're safe here.", 1.15, 0.0)]),
    "die": ("cold", DIE),
    "fine": ("warm", [("Everything is fine.", 1.0, 0.3), ("Continue.", 1.05, 0.0)]),
}
TRIM = ("silenceremove=start_periods=1:start_threshold=-40dB,areverse,"
        "silenceremove=start_periods=1:start_threshold=-40dB,areverse")

def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def dur(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
                                capture_output=True, text=True).stdout)

def say(a, model, text, ls, pitch, out):
    raw = out + ".raw.wav"
    subprocess.run([a.piper, "-m", model, "-f", raw, "--length-scale", str(ls), "--noise-scale", "0.5"],
                   input=text, text=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run(["ffmpeg", "-y", "-i", raw, "-af", f"aresample=44100,asetrate=44100*{pitch},aresample=44100,{TRIM}", "-ac", "1", out])
    return out

def silence(sec, out):
    run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", str(sec), out])
    return out

def cold(a, d, n, text, ls, man, take):
    fp, fdb, mp, mdb, ring, crush = TAKES[take]
    fp += (1.03 - fp) * (1 - man)                # and her pitch climbs back to the warm voice's
    f = say(a, a.female, text, ls, fp, f"{d}/{n}f.wav")
    # asetrate stretches time by 1/pitch, so the man is said at a length that lands on the woman's after both pitch shifts
    m0 = say(a, a.male, text, ls, mp, f"{d}/{n}m0.wav")
    m = say(a, a.male, text, ls * dur(f) / dur(m0), mp, f"{d}/{n}m.wav")
    out = f"{d}/{n}.wav"
    fdb2 = fdb + (1 - man) * 3                   # the woman takes the man's place as he fades
    mix = (f"[0]volume={fdb2}dB[f];[1]volume={mdb}dB,volume={man}[m];[f][m]amix=inputs=2:normalize=0:duration=longest,"
           f"acrusher=bits=10:mode=log:aa=1:mix={crush * man}")
    if ring:
        mix += f",aeval=val(0)*(1-{0.5 * man}+{0.5 * man}*sin(2*PI*{ring}*t))"
    run(["ffmpeg", "-y", "-i", f, "-i", m, "-filter_complex", mix, "-ac", "1", out])
    return out

def join(parts, filt, out):
    lst = parts[0] + ".txt"
    with open(lst, "w") as fh:
        fh.writelines(f"file '{p}'\n" for p in parts)
    codec = ["-c:a", "libvorbis", "-q:a", "4"] if out.endswith(".ogg") else ["-q:a", "2"]
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-af", filt, "-ac", "1"] + codec + [out])

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--female", required=True)
    p.add_argument("--male", required=True)
    p.add_argument("--take", default="a", choices=["a", "b", "c", "warm"])
    p.add_argument("--line", choices=sorted(LINES))
    p.add_argument("--json", help="with --line: write the line's text, length and phrase start times here")
    p.add_argument("--out", default="firewall.mp3")
    p.add_argument("--piper", default="piper")
    a = p.parse_args()
    d = tempfile.mkdtemp(prefix="firewall_voice_")
    parts = []
    if a.line:
        voice, phrases = LINES[a.line]
        t = 0.0
        starts = []
        for n, ph in enumerate(phrases):
            text, ls, pause = ph[0], ph[1], ph[2]
            if voice == "cold" and ph[3] > 0:
                w = cold(a, d, n, text, ls, ph[3], "c")
            else:
                w = say(a, a.female, text, ls, 1.03, f"{d}/{n}.wav")
            starts.append([round(t, 2), text])
            parts.append(w)
            parts.append(silence(pause + 0.01, f"{d}/{n}s.wav"))
            t += dur(w) + pause + 0.01
        join(parts, COLD_TAIL if voice == "cold" else WARM, a.out)
        if a.json:
            import json
            json.dump({"len": round(dur(a.out), 2), "text": " ".join(x[1] for x in starts), "phrases": starts}, open(a.json, "w"), indent=1)
        return
    if a.take == "warm":
        for i, (text, ls, pause) in enumerate(WARM_LINES):
            parts.append(say(a, a.female, text, ls, 1.03, f"{d}/w{i}.wav"))
            parts.append(silence(pause + 0.01, f"{d}/w{i}s.wav"))
        join(parts, WARM, a.out)
        return
    n = 0
    for block in (REVEAL, P3, DIE):
        for text, ls, pause, man in block:
            if man == 0 and block is P3:                # "welcome" in the shell's own voice, quoted back
                parts.append(say(a, a.female, text, ls, 1.03, f"{d}/{n}.wav"))
            else:
                parts.append(cold(a, d, n, text, ls, man, a.take))
            parts.append(silence(pause + 0.01, f"{d}/{n}s.wav"))
            n += 1
        parts.append(silence(2.0, f"{d}/{n}gap.wav"))
        n += 1
    join(parts, COLD_TAIL, a.out)

if __name__ == "__main__":
    main()
