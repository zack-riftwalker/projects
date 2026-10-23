# Voice credits

`crawler_*.ogg` (CRAWLER OF THE WEB) are made with the Piper text-to-speech voice
`en_GB-northern_english_male-medium`, trained on the OpenSLR 83 dataset
("Crowdsourced high-quality UK and Ireland English Dialect speech data set",
Google), licensed CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/

The lines were processed (pitch, echo, resonance) by `tools/voice/crawler_voice.py`.
These audio files are shared under the same license, CC BY-SA 4.0.

`firewall_*.ogg` (THE FIREWALL) are made with two Piper text-to-speech voices: the warm one (a woman) is
`en_US-ljspeech-high`, trained on the LJ Speech dataset, which is in the public domain
(https://keithito.com/LJ-Speech-Dataset/); the cold one (a woman and a man together) adds
`en_GB-northern_english_male-medium`, CC BY-SA 4.0 like the CRAWLER's voice (see above).

The lines were processed (pitch, echo, ring, bit-crush) by `tools/voice/firewall_voice.py`; the phrase times in
`firewall.json` come from `tools/voice/firewall_times.py`. These audio files are shared under the same license,
CC BY-SA 4.0.

`race_*.ogg` (RACE CONDITION) are made with one Piper text-to-speech voice, `en_GB-northern_english_male-medium`
(CC BY-SA 4.0, see above), said twice (TICK higher and faster, TOCK lower and slower). The lines were processed (pitch,
clockwork filter) by `tools/voice/race_voice.py`; the word times in `race.json` come from the same script (a speech
recognizer listening to each voice on its own). These audio files are shared under the same license, CC BY-SA 4.0.
