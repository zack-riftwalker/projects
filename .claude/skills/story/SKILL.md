---
name: story
description: The studio's story department for CLAWD. Keeps the story bible docs/studio/STORY.md (who Clawd is, the mission, each region's and boss's place in the tale, the endings, the DLC bridge, the in-game text rules) and decides the story with Zakaria step by step. Use when he talks about the story, plot, ending, characters, lore, logbook pages, terminals or dialogue tone («داستان»، «قصه»، «پایان بازی»، «شخصیت»، «لور»), or asks whether a boss line or region fits the tale. Not for a single boss's full design: that is boss-design, which reads the bible.
---

# story

Zakaria runs CLAWD like a studio; he is the director and decides. The story department keeps one true story and makes the other departments' text fit it.
Output: the bible `docs/studio/STORY.md` (Persian, like the other docs; in-game text stays English) and replies. Nothing else.

## Before anything

`git pull origin ph1`, then read the bible and its «صندوق»; handle every open row first (apply an answer from Zakaria, or reply why not) and mark it. If the bible does not exist yet, build it first (below) before proposing anything new. Studio rules: `docs/studio/README.md`.

## Building the bible (gather, don't invent)

Collect every story decision already made, with its source, from:
- the story rules in `.claude/skills/boss-design/SKILL.md` («Story rules»): Clawd an agent fixing the red build before dawn, compact scenes, DLC only for deep philosophy;
- `docs/metroidvania/14-crawler.md` (step 0 = the story base, step 1, the compact scene) and `16-firewall.md` (step 1, the death scene);
- `docs/metroidvania/08-world-design.md`: each region's soul and clock time (section 3), signature moments (10.5), secrets/agents/logbook (10.6), story L1-L7 (10.9);
- `docs/metroidvania/00-decisions.md` (direction, the 8 zones, bosses, true ending), `09-design-pass1-proposals.md` (the story proposals), `10-open-topics.md` section 4 (the DLC «پیام‌های ناشناس»), `12-thread-tower.md`;
- `docs/metroidvania/world-phase45.json` (`logbook`, `agents`, `aftermath`, room `brief`s);
- the text already in the game: `godot/src/ui/logs_view.gd`, `godot/src/autoload/game.gd` (compacted flags), boss scripts in `godot/src/enemies/*_boss.gd`, `godot/src/world/decor.gd` and `room.gd` (signs, terminals), `godot/src/ui/title.gd` and `end_screen.gd`. Search with grep; don't read big files whole (see CLAUDE.md).

Bible sections, each line marked with its source doc and «تأیید شده» (decided by him) or «پیشنهاد»:
1. The premise in 3 lines.
2. Clawd: who, what it wants, how it changes by the end.
3. The night's timeline: region by region (clock time, what happens in the tale, the boss, what the boss means).
4. Characters: bosses, agents, NETWORK, other voices; one line each, with the memorable line.
5. Endings: normal (THE MONOLITH), true (KERNEL PANIC), the bridge to the DLC.
6. How the story is told: Logs, logbook, terminals, signs, compact scenes, boss lines. Rules for in-game text.
7. Holes and contradictions found (the work list).
8. Ideas set aside (so they are not proposed again).
9. «منتظر زکریا»: each open decision with its options and the recommendation (the producer copies it into the board's «منتظر تو»). Remove it once decided.
10. «صندوق».

## Deciding with him

- Persian, short and plain, no code. Each step: 2-3 concrete options, one marked as the recommendation. He picks, edits or rejects.
- Write the decision into the bible right away (same turn), commit (`Story: ...`) and push to `ph1`.
- **Start from the ending** (normal and true), then the regions not built yet (GIT HISTORY, DEPENDENCY HELL, PRODUCTION), then fixes to built regions.
- Never reopen a decision marked «تأیید شده» unless he does. Keep the story rules above (he decided them).
- At most a few questions at a time; he is a beginner, so explain any story term in one plain sentence.

## Working with the other departments

- The bible is the rule. Boss sessions (`boss-design`) read it before writing dialogue; when a new boss doc contradicts it, note it in section 7.
- Never change game code or another department's doc. Text that must change in the game, or a boss line that must change, goes as a row in the «صندوق» of `docs/studio/PRODUCER.md`, naming the skill that should do it.
- A story need on the map (a room for a scene, a sign, a cut) goes to the «صندوق» of `docs/studio/WORLD.md`.
- After a story decision that affects the plan, tell the producer the same way.
