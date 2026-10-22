---
name: playtest
description: The studio's play-test department for CLAWD. Prepares a play session for Zakaria (PC host) and his friend (Android, P2) — which build, what to try, the sheet — and turns their raw notes into sorted tasks sent to the right department. Keeps docs/studio/PLAYTEST.md. Use when he says he will play («می‌خوایم بازی کنیم»، «چی رو تست کنیم؟») or brings notes from playing («بازی کردیم»، «یادداشت تست»، a list of complaints or bugs, a pasted LOG). Runs inside the producer's session.
---

# playtest

Play-tests are the studio's most valuable input: each one so far found something the automated tests could not (THE FIREWALL's safe spot).
Doc: `docs/studio/PLAYTEST.md` (owned by this department; the rules in `docs/studio/README.md` apply). Persian, short and plain.

## Before a play session

1. `git pull origin ph1`. Read `PLAYTEST.md` («منتظر تست» = built but not yet played).
2. Check his build: the 7-letter commit his `update.bat` printed must be `ph1`'s newest web export (`git log --oneline -- public/mv | head -1`). If he doesn't know it, ask for it once. If `update-branch.txt` isn't `ph1`, he is on `main`, which is far behind: tell him how to fix it (a text file `update-branch.txt` next to the game holding `ph1`). Write the build into «نسخه‌ای که روی کامپیوتر زکریاست».
3. Give him a short plan for this session: the items in «منتظر تست» (with their steps, taken from the builder's notes or `docs/reports/*.md` «playtest steps»), at most ~45 minutes of play, and remind him of the sheet. Point at the sheet; don't repeat it.

## After a play session (his notes)

1. Write every note into «تست‌های انجام‌شده», **in his words**, one row each, with the emoji type from the sheet (😕 😴 😤 🐛 🤩 📱). Don't drop the 🤩 notes: they say what must not be broken.
2. For each note, decide where it goes:
   - 🐛 bug → a task on the producer board (and a brief if it is more than a line), with the room and the LOG if given;
   - 😤 unfair / 😴 boring in a boss → the boss's doc owner: add a row to the inbox of `docs/studio/PRODUCER.md` naming the boss, for the next boss-design/boss-build session;
   - 😕 lost / 😴 boring in a region → the inbox of `docs/studio/WORLD.md`;
   - story didn't make sense → the inbox of `docs/studio/STORY.md`;
   - 📱 phone only → a task on the board (speed rules in CLAUDE.md).
   Fill «رفت به».
3. Move the played items out of «منتظر تست».
4. Commit (`Playtest: ...`) and push to `ph1`. Never fix code in this turn.
5. Reply: what you heard (grouped, 3-5 lines), where each group went, and the one thing you'd fix first.

## Ask, don't guess

If a note is unclear in a way that changes where it goes (which room? did it happen every time?), ask one short question; otherwise write it as he said it and move on.
