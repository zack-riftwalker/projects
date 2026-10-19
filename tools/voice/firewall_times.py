#!/usr/bin/env python3
# Writes godot/assets/voice/firewall.json: each line's text, its length and the time each phrase starts (the game shows its subtitles phrase by phrase
# on these). The times are the ones firewall_voice.py built the file with (it joins phrases of known length and pauses, so they are exact); a speech
# recognizer (faster-whisper base.en, one phrase at a time) then listens to every phrase and says which ones it could not understand: those are the
# phrases to make slower in firewall_voice.py (and to listen to). The cold voice is metallic on purpose, so the recognizer is a harsh judge of it.
#   python3 firewall_times.py <dir with firewall_<key>.ogg and <key>.json from firewall_voice.py> <out firewall.json> [--strict]
# Needs ffmpeg and faster-whisper (pip). The audio is decoded with ffmpeg to 16 kHz mono first: faster-whisper's own decoder can fail.
import json, os, re, subprocess, sys, tempfile, wave
import numpy as np
from faster_whisper import WhisperModel

# what the game shows as each line's subtitle (the cold lines in the game's own punctuation; the phrases below are what is SAID)
SHOWN = {
    "refused": "Connection refused.",
    "sorry": "Sorry about that! Please proceed to the dmz for verification.",
    "intro": "Welcome! You're safe here. The exit is just this way.",
    "reveal": "Request denied. ...You walked in on your own. They always do.",
    "p3": "I said \"welcome\" and you believed me. Why? Because I was polite?",
    "plead": "Please... you're safe here.",
    "die": "They trust you for the same reason you trusted me. You are polite. You say you mean well. ...Are you what you say you are? Do you even know?",
    "fine": "Everything is fine. Continue.",
}

def words(t):
    return re.findall(r"[a-z0-9']+", t.lower())

def main():
    src, out = sys.argv[1], sys.argv[2]
    model = WhisperModel("base.en", device="cpu", compute_type="int8")
    res = {"_": "THE FIREWALL's lines: the text shown, the length (s) of each voice file (firewall_<key>.ogg, made by tools/voice/firewall_voice.py) and the time (s) each spoken phrase starts, measured with a speech recognizer (tools/voice/firewall_times.py). Remake both together."}
    bad = 0
    for key in SHOWN:
        meta = json.load(open(f"{src}/{key}.json"))
        wav = tempfile.mktemp(suffix=".wav")
        subprocess.run(["ffmpeg", "-y", "-i", f"{src}/firewall_{key}.ogg", "-ar", "16000", "-ac", "1", wav], check=True, capture_output=True)
        with wave.open(wav) as wf:                      # (the samples go in as an array: faster-whisper's own decoder can fail)
            audio = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        # each phrase on its own, from where firewall_voice.py put it to where the next one begins: the recognizer drops whole phrases of a long
        # metallic line, and one phrase at a time it either hears it or the phrase is not intelligible
        phrases = []
        edges = [float(t0) for t0, _ in meta["phrases"]] + [len(audio) / 16000.0]
        for i, (t0, text) in enumerate(meta["phrases"]):
            lo = max(0, int((edges[i] - 0.15) * 16000))
            hi = min(len(audio), int((edges[i + 1] + 0.1) * 16000))
            clip = np.concatenate([np.zeros(8000, dtype=np.float32), audio[lo:hi], np.zeros(8000, dtype=np.float32)])
            segs, _ = model.transcribe(clip, word_timestamps=True, language="en", beam_size=5, condition_on_previous_text=False, vad_filter=False,
                                       no_speech_threshold=None, log_prob_threshold=None, compression_ratio_threshold=None)
            heard = []
            for sg in segs:
                for w in sg.words:
                    for tok in words(w.word):
                        heard.append((tok, w.start))
            want = words(text)
            got = [h for h in heard if h[0] in want]
            ok = len(got) >= max(1, int(len(want) * 0.7 + 0.999))
            if not ok:
                bad += 1
                print(f"NOT RECOGNIZED  {key}: '{text}' (heard: {' '.join(h[0] for h in heard)})")
            phrases.append([round(float(t0), 2), text])
        print(f"{key}: {meta['len']} s, phrases at {[p[0] for p in phrases]} (computed {[p[0] for p in meta['phrases']]})")
        res[key] = {"len": meta["len"], "text": SHOWN[key], "phrases": phrases}
    json.dump(res, open(out, "w"), indent=1, ensure_ascii=False)
    print("every phrase was understood" if bad == 0 else f"{bad} phrases the recognizer could not understand (listen to them)")
    sys.exit(1 if bad and "--strict" in sys.argv else 0)

main()
