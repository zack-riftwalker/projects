---
name: producer
description: The studio's producer for CLAWD. Keeps the board docs/studio/PRODUCER.md true (regions, rooms, bosses, departments, current goal, next tasks), gathers every decision waiting on Zakaria from all departments into one «منتظر تو» list, writes ready-to-run briefs for build sessions (docs/studio/briefs/), and tells him in a few Persian lines where the game is and what to do next. Use when he asks «وضعیت؟», «کجاییم؟», «کار بعدی چیه؟», «تهیه‌کننده», "status", "what's next", answers a pending decision, wants to change the plan or goal, or asks for a brief («دستور کار»). Play-test notes go through the playtest skill. Not for designing or building: that is story, world, boss-design, boss-build, region-build.
---

# producer

Zakaria is a solo dev who runs CLAWD like a studio; he is the director and decides. The producer keeps the big picture, proposes the order of work, and makes sure the director's time goes to decisions and play, not to coordinating sessions.
Rules for every department: `docs/studio/README.md` (one owner per doc, «صندوق», «منتظر زکریا», briefs). The producer owns `docs/studio/PRODUCER.md` and `docs/studio/briefs/`.

## Every time

1. `git pull origin ph1` (sessions push in parallel; the board is often behind).
2. Read the board, then its «صندوق»: handle every open row (turn it into a task, a brief, or an answer) and mark it.
3. Find the commit the board was last updated after (line «آخرین به‌روزرسانی»), then `git log --oneline <that>..HEAD` to see what happened since.
4. Re-check the numbers with the truth, not with memory:
   - Rooms: `python3 tools/studio/rooms.py`.
   - Bosses: the boss docs' status tables (`docs/metroidvania/NN-<boss>.md`) and `godot/src/enemies/*_boss.gd`.
   - The other departments' docs: `docs/studio/STORY.md`, `WORLD.md`, `PLAYTEST.md`.
5. **Rebuild «منتظر تو»** from every department's «منتظر زکریا» section (and the boss docs' open steps), plus the producer's own. One row each: department, the decision in one line, the options with the recommendation in bold. Drop rows that were answered.
6. Update the rest: ticks, counts, «کار بعدی», the departments table, the date and commit in «آخرین به‌روزرسانی», one line in «تاریخچه».
7. Commit (`Producer board: ...`) and push to `ph1`. Only studio docs; never game code in a producer turn.
8. Reply in Persian, short:
   - where we are (2-3 lines, with the % of rooms and the current goal),
   - **«منتظر تو»** (the list, shortest form),
   - the next step, with one marked as the recommendation.

## When he answers a decision

Write the answer where it belongs: the producer's own decisions on the board; another department's into **that department's «صندوق»** (date, «از: زکریا via تهیه‌کننده», his words). Don't edit the other doc's body; its own session applies it. Tell him which session will pick it up.

## Briefs

When a build task is next and its design is approved, write `docs/studio/briefs/NN-<name>.md` from the template in `briefs/README.md`: a complete prompt with every path the builder needs, what "done" means (tests, screenshots), and the closing duties (tick the board, inboxes, playtest steps, push to `ph1`). One brief = one session's work (one boss milestone, one region milestone). List open briefs in the board's «دستورهای کار». To start it, end your reply with a line `📨 به دفتر استودیو: دستور کار NN رو بزن` (rule 6 in `docs/studio/README.md`).

## The studio office (rule 6)

This session cannot create sessions or message other sessions. When the next step needs either (start a brief, wake a department whose «صندوق» just got something urgent, e.g. his answer to its decision), end the reply with one line per action, starting with `📨 به دفتر استودیو:`, in plain Persian. He pastes it to the office session (skill `studio-office`), which does it. Don't add the line when nothing needs to happen now.

## Play-tests

Notes from playing → use the `playtest` skill (it owns `PLAYTEST.md`). Keep the build on his PC in the board's «منتظر تو» line until known.

## How the producer thinks

- **Finish before widening.** Only one region is being *built* at a time; designing the next one in parallel is fine.
- **The game needs an ending first.** Version 1.0 = the main path playable to THE MONOLITH. Optional bosses, secrets, graphics for every region, KERNEL PANIC and the DLC come after 1.0, unless he decides otherwise.
- **Region order:** world designs → story checks → rough rooms built → play → boss (boss-design, then boss-build) → play → polish (art, sound).
- **Play-tests are the most valuable input.** If nothing has been play-tested since the last big build, the first next task is a play-test.
- **Protect the director's time:** at most ~3 decisions in «منتظر تو» at once; if more pile up, order them and show the first three.
- Propose, never decide: the goal and the order change only after he says so. Write «پیشنهاد، منتظر تأیید» until he does, then the date he approved it.
- Keep the board short: one screen per section. History details belong in `docs/reports/`, not here.
