# Phase 2 report — difficulty settings (solo + co-op)

| Task | Done | Test |
|---|---|---|
| P2-01 | Flat keys in `opt` (`diffPreset, bossPct, npcExtra, npcMult`), separate `coopDiff` profile (default `coop`: boss +50%), merged by the save loader, kept on "erase save" like options. Presets easy/normal/coop/hard/nightmare/custom | — |
| P2-02 | `G.diff` (own script block before co-op): `cfgFor(L)` (host → co-op profile, guest → none, solo → options), idempotent `scale`, applied at the start of `Level.update` so runtime spawns (slime splits, Leak/Monolith minions) are covered. Normal enemies: `ceil(hp·mult/100)+extra`, loot scales with hp. Bosses: hp/maxHp ×(1+pct), Merge heads too, death drop via `dropN` (24 → ×k) in all three boss death paths | diff-boss (39/39, drop 36), diff-merge (28+28=56, phase 2 after one head), diff-loot (3 tokens), diff-coop |
| P2-03 | Stomp calls `e.hit(max(1, hp), …)`: always a one-hit kill | diff-solo |
| P2-04 | Options rows difficulty / boss HP / enemy hits / enemy HP (left/right cycles, editing a number → `custom`), compact row height, footer "applies from the next level / restart". Hidden while a co-op connection is open (the co-op profile is used then) | screenshot checked |
| P2-05 | 2P panel (host, friend connected): preset select + 3 sliders → `coopDiff`; settings travel in `start` (and a `cfg` message when changed) → HUD line at level start and on the guest's wait screen. Server: `BOSS_HP / NPC_HITS / NPC_MULT / LOCK`, `coop-config.json`, local-only `GET /config`; LOCK disables the inputs and wins. README + start.bat documented | diff-lock |
| P2-06 | Scenarios `diff-solo diff-boss diff-merge diff-loot diff-coop diff-lock` all PASS; `smoke` PASS | — |

## Notes
- If the friend joins a level that is already running (P1-11), creatures that already exist keep the solo scaling; the co-op profile applies to everything created afterwards and from the next level.
- Server env values (without `LOCK`) are applied to the host's profile each time the host connects.
