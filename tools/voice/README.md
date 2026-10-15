# صدای باس‌ها

`crawler_voice.py` جمله‌ی آخر CRAWLER OF THE WEB رو می‌سازه ([`docs/metroidvania/14-crawler.md`](../../docs/metroidvania/14-crawler.md)، گام ۲): تبدیل متن به صدا با Piper، بعد ffmpeg (بم‌تر و کندتر، بلندگوی قدیمی، طنین، و سه بار تکرار «not being»).

```
python3 -m venv venv && ./venv/bin/pip install piper-tts
curl -L -O https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alan/medium/en_GB-alan-medium.onnx
curl -L -O https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alan/medium/en_GB-alan-medium.onnx.json
./venv/bin/python crawler_voice.py --voice en_GB-alan-medium.onnx --piper ./venv/bin/piper --out last_line.mp3
```

**مجوز:** صدای `alan` (همونی که زکریا انتخاب کرد) مجوزش «All Rights Reserved» ـه (Mycroft AI)، پس توی بازی منتشرشده نمی‌شه ازش استفاده کرد و فایل صداش توی مخزن نیست. قبل از انتشار یا یه صدای آزاد با همین دستور ساخته می‌شه (مثلاً `en_GB-northern_english_male-medium`، داده‌ی CC-BY-SA 4.0)، یا صدا ضبط می‌شه.
