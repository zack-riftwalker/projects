# PLAN · Phase 3 fixes (MV3-FIX-1 … MV3-FIX-9)

For the executing agent. Phase 3 (3A + 3B) is built and its suite passes. A code review found nine defects; this plan fixes them **one at a time, in order, one commit per fix**. Every step below says exactly what to change. Do not redesign, do not "improve" anything else, do not touch files not named here.

Severity order (same numbering as the review given to Zakaria): FIX-1 high · FIX-2, FIX-3, FIX-4 medium · FIX-5 … FIX-9 low.

---

## 0. Rules of engagement

1. Branch **`ph1`** only. Pull it first (`git fetch origin ph1 && git checkout ph1 && git merge --ff-only origin/ph1`). Push to `ph1`. **Never** merge into or push to `main`. Never open a pull request.
2. Read `CLAUDE.md` (section "Godot version") once before starting. Its co-op rules apply to every fix.
3. One fix = one commit, message `MV3-FIX-<n>: <what>`. Each commit must leave the build green for the tests named in that fix.
4. Every fix adds a test that **fails on the old code and passes on the new code**. Before writing the fix, write the test and run it on the old code: confirm it fails. Then fix, then confirm it passes. Say so in the report (old: FAIL, new: PASS).
5. Godot: `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`. One unit test: `$GODOT --headless --path godot -- --test=<name>`. One co-op scenario: `bash tools/godot/coop-test.sh co-<name>`. Bad line: `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-<name>`.
6. A new unit test is registered in **two** places: the `match name:` block in `godot/src/test/run_tests.gd` (`"<name>": return t_<name>()`) and the `for t in …` list on line 16 of `tools/godot/test-all.sh`. A new co-op scenario is a `func sc_co_<name>() -> Array` in `godot/src/test/coop_scenarios.gd` and is added to the `ALL=` list in `tools/godot/coop-test.sh`.
7. Never kill processes you did not start. `pkill -f "node server.js"` can kill your own shell.
8. Match the surrounding style: compact GDScript, comments explain *why*, no new dependencies.
9. After all nine fixes: full suite, bad-line co-op, web export as its own last commit, report, push (section "FINAL").

---

## MV3-FIX-1 · The guest's agents work only once per connection (HIGH)

**Bug.** `godot/src/net/coop.gd`, `_host_rel`, branch `"agents":`

```gdscript
		"agents":
			var ar := _remote_room()
			if ar != null and remote.agents_t <= 0.0:
				remote.agents_t = 11.0
				ar.cast_agents(remote)
```

`remote.agents_t` is set to 11.0 and **never decremented anywhere**, so every later `agents` event from the guest is refused for the rest of the connection. The guest has already emptied its meter locally, so it loses a full meter each time and sees no agents.

**Fix.**
1. Replace the branch above with:

```gdscript
		"agents":                                # the guest spent a full meter (its own check): its two agents, replacing any it still has here
			var ar := _remote_room()
			if ar != null:
				ar.agents = ar.agents.filter(func(a): return a.owner_p != remote)
				ar.cast_agents(remote)
				log_("host: guest agents cast in %s" % ar.id)
```

2. In `godot/src/player/remote_player.gd` delete the line `var agents_t := 0.0                # host: seconds its agents still have (the host simulates them)`. Grep `remote.agents_t` and `agents_t` in `coop.gd` afterwards: no use of `remote.agents_t` may remain. (`Player.agents_t` in `player.gd` and `hud.gd` stays: it is the local player's own timer.)

**Test (extend `sc_co_agents` in `coop_scenarios.gd`).** Make it cast **twice**.
- Host branch: after the existing `var key := await wait_until(...)` line and before `await wait_secs(1.0)`, add:

```gdscript
		var gone := await wait_until(func(): return r.agents.is_empty(), 15.0 * slow)          # the first two expire (11 s)
		var again := await wait_until(func(): return r.agents.size() == 2 and r.agents[0].owner_p.get("is_remote") == true, 12.0 * slow)
```
  and change the return to `[there and agents_seen and key and gone and again, "... first cast gone %s, second cast on the host %s" % [..., gone, again]]` (keep the existing message parts, append the two new ones).
- Guest branch: after the existing `var gate := await wait_until(...)` line add:

```gdscript
	var view_gone := await wait_until(func(): return r2.agent_view.is_empty() and g.agents_t <= 0.0, 15.0 * slow)
	g.meter = float(Game.METER_MAX)
	Controls.script_input = {"special": true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	Controls.script_input = {}
	var view2 := await wait_until(func(): return r2.agent_view.size() == 2, 6.0 * slow)
```
  and add `view_gone and view2` to the returned boolean and message.
- If `coop-test.sh` or the scenario runner has a per-scenario time limit that this exceeds, raise that limit for `co-agents` only.

**Check.** Old code: `co-agents` FAILS (second cast never appears on the host). New code: PASS, also with `BADLINE_ALL=1`. Commit `MV3-FIX-1: the guest's agents work on every cast (host no longer keeps a timer that never ran down)`.

---

## MV3-FIX-2 · MERGE CONFLICT's heads jump on the guest (MEDIUM)

**Bug.** `godot/src/enemies/merge_boss.gd`, `net_apply` writes each head's `h.x / h.y` straight from the snapshot (10–15 per second). Every other creature goes through the guest's interpolation buffer (`Coop._puppet_follow`), the heads do not: a lunge at 460 px/s jumps 30–46 px per snapshot, and the guest's own body check (it checks its own body against `harmboxes()`) uses those jumping positions.

**Fix: the same buffer for the heads.** Keep `net_fields()` and the existing assignments in `net_apply()` unchanged (the `parity` test applies records without following, and must still pass).

1. `merge_boss.gd`: add a member next to `var last = null`:

```gdscript
var hsamp := [[], []]              # guest: per head [[tm, x, y], ...] from the snapshots, followed like any creature's position
```

2. `merge_boss.gd`, in `net_apply`, inside the `for i in range(2):` loop, in the existing `if was_dead and not h.dead:` block, add `hsamp[i].clear()` as its first line (a reverted head jumps back to its rest spot; it must not slide there).

3. `merge_boss.gd`: add two functions after `net_apply`:

```gdscript
# guest: the snapshot that was just applied, at host time tm (Coop._apply_snapshot)
func net_sample(tm: float) -> void:
	for i in range(2):
		var s: Array = hsamp[i]
		s.append([tm, heads[i].x, heads[i].y])
		while s.size() > 8:
			s.pop_front()

# guest: put each head where it was at render time rt, as Coop._puppet_follow does for whole creatures (a dead head falls: no guessing ahead)
func puppet_follow_parts(rt: float) -> void:
	for i in range(2):
		var s: Array = hsamp[i]
		if s.is_empty():
			continue
		var h: Dictionary = heads[i]
		var last: Array = s[s.size() - 1]
		if rt >= last[0]:
			var vx := 0.0
			var vy := 0.0
			if s.size() >= 2 and not h.dead:
				var prev: Array = s[s.size() - 2]
				var dt_: float = maxf(0.0001, last[0] - prev[0])
				vx = (last[1] - prev[1]) / dt_
				vy = (last[2] - prev[2]) / dt_
			var ex := minf(rt - last[0], 0.1)
			h.x = last[1] + vx * ex
			h.y = last[2] + vy * ex
			continue
		var done := false
		for k in range(s.size() - 1):
			if s[k][0] <= rt and rt <= s[k + 1][0]:
				var u: float = (rt - s[k][0]) / maxf(0.0001, s[k + 1][0] - s[k][0])
				h.x = lerpf(s[k][1], s[k + 1][1], u)
				h.y = lerpf(s[k][2], s[k + 1][2], u)
				done = true
				break
		if not done:
			h.x = s[0][1]
			h.y = s[0][2]
```

4. `godot/src/net/coop.gd`, `_apply_snapshot`: right after the line `NetClasses.apply(e, rec)` add:

```gdscript
		if e.has_method("net_sample"):
			e.net_sample(tm)                  # (parts that move on their own: MERGE CONFLICT's heads)
```
   Use the same `tm` variable that the next line already puts into `samples`.

5. `coop.gd`, `_puppet_follow`: right after the `if e.has_method("puppet_tick"): e.puppet_tick(dt)` lines add:

```gdscript
	if e.has_method("puppet_follow_parts"):
		e.puppet_follow_parts(rt)
```

**Test: new unit test `mergeinterp`** in `run_tests.gd`:

```gdscript
# MV3-FIX-2: the guest follows MERGE CONFLICT's heads through a buffer (between two snapshots: in between; after the last: a short guess)
func t_mergeinterp() -> bool:
	var room := new_room("D05")
	var host := MergeBoss.new(room, 0, 0)
	var pup := MergeBoss.new(room, 0, 0)
	pup.puppet = true
	host.heads[0].x = 100.0
	host.heads[0].y = 90.0
	pup.net_apply(host.net_fields())
	pup.net_sample(0.0)
	host.heads[0].x = 140.0
	pup.net_apply(host.net_fields())
	pup.net_sample(0.1)
	pup.puppet_follow_parts(0.05)
	var mid: float = pup.heads[0].x
	pup.puppet_follow_parts(0.15)
	var ahead: float = pup.heads[0].x
	pup.puppet_follow_parts(0.5)
	var capped: float = pup.heads[0].x
	var ok: bool = absf(mid - 120.0) < 0.5 and absf(ahead - 160.0) < 0.5 and absf(capped - 180.0) < 0.5
	room.queue_free()
	host.free()
	pup.free()
	return report("mergeinterp", ok, "between %.1f (want 120), 0.05 s ahead %.1f (want 160), capped %.1f (want 180)" % [mid, ahead, capped])
```
Register it (rule 6).

**Check.** Old code: `mergeinterp` FAILS (no `net_sample`). New code: `mergeinterp`, `parity`, `merge` PASS; `co-merge` PASS, also with `BADLINE_ALL=1`. Commit `MV3-FIX-2: MERGE CONFLICT's heads go through the guest's interpolation buffer`.

---

## MV3-FIX-3 · A menu on one page freezes the world (MEDIUM)

**Bug.** `godot/src/main.gd`, `_physics_process`:

```gdscript
	if bench_menu.active:
		Controls.poll()
		bench_menu.update()
		return
	if shop_menu.active:
		Controls.poll()
		shop_menu.update()
		return
	manager.tick(Game.STEP)
```

While the bench menu or the shop is open, `manager.tick` never runs. On the **host** that stops every room it simulates: if the guest is fighting in another room (MERGE in D05 while the host shops in D04), its creatures and boss freeze. On the **guest** its own body stops being simulated, so nothing can hurt it while its shop is open. Alone (no co-op) freezing is right and must stay.

**Fix.**
1. `godot/src/player/player.gd`: add a member after `var frozen := false`:

```gdscript
var in_menu := false            # a bench menu or the shop is open on this page while the co-op world goes on: no input, the body stands
```

2. `player.gd`, top of `update()`: replace

```gdscript
	var down: Dictionary = {} if frozen else Controls.down
	var pressed: Dictionary = {} if frozen else Controls.pressed
```
with
```gdscript
	var down: Dictionary = {} if frozen or in_menu else Controls.down
	var pressed: Dictionary = {} if frozen or in_menu else Controls.pressed
```

3. `player.gd`, the agents block (`# --- agents: a TAP of [special] ...`): change `if not frozen and Controls.down.get("special", false):` to `if not frozen and not in_menu and Controls.down.get("special", false):` and `elif not frozen and Controls.released.get("special", false):` to `elif not frozen and not in_menu and Controls.released.get("special", false):`.

4. `godot/src/world/room.gd`, first line of `func interact_goals(p) -> void:` body: add

```gdscript
	if p.get("in_menu") == true:
		return                                 # (a menu is open: its up/down presses must not open a bench, the shop or the end)
```

5. `main.gd`, replace the two menu blocks quoted above with:

```gdscript
	if bench_menu.active or shop_menu.active:
		Controls.poll()
		if bench_menu.active:
			bench_menu.update()
		else:
			shop_menu.update()
		if not Net.is_active() or manager.player == null:
			return                              # alone the world waits while a menu is open
		# co-op: the partner's world goes on (the host simulates it); this body stands still and takes no input
		manager.player.in_menu = true
		manager.tick(Game.STEP)
		if manager.player != null:
			manager.player.in_menu = false
			if manager.player.dead:              # hurt to death while choosing: the menu goes away
				if shop_menu.active:
					shop_menu.close()
				if bench_menu.active:
					bench_menu.close()
		return
	manager.tick(Game.STEP)
```
   Keep the lines that follow `manager.tick(Game.STEP)` (the pause check) as they are.

**Test: new co-op scenario `co-menutick`** in `coop_scenarios.gd`:

```gdscript
# MV3-FIX-3: an open bench menu / shop does not stop the co-op world (host: its rooms; guest: its own body), and the body takes no input
func sc_co_menutick() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("D04", Vector2(60.0, 100.0))
		var p = mgr().player
		p.x = 60.0
		p.y = floor_y(mgr().room, 60.0, 8)
		await wait_secs(1.0)
		var r: Room = mgr().room
		main.shop_menu.open(r)
		var t0: float = r.time
		var x0: float = p.x
		Controls.script_input = {"right": true}
		await wait_secs(1.5)
		Controls.script_input = {}
		var ran: float = r.time - t0
		var moved: float = absf(mgr().player.x - x0)
		main.shop_menu.close()
		await wait_secs(2.0)
		return [ran > 1.0 and moved < 1.0, "host room ran %.2f s with the shop open (want > 1), body moved %.1f px (want 0)" % [ran, moved]]
	await wait_secs(1.0)
	mgr().swap_to("D04", Vector2(120.0, 100.0))
	var g = mgr().player
	g.x = 120.0
	g.y = floor_y(mgr().room, 120.0, 8)
	await wait_secs(3.0)
	var r2: Room = mgr().room
	main.shop_menu.open(r2)
	var t1: float = r2.time
	var gx: float = g.x
	Controls.script_input = {"right": true}
	await wait_secs(1.5)
	Controls.script_input = {}
	var ran2: float = r2.time - t1
	var moved2: float = absf(mgr().player.x - gx)
	main.shop_menu.close()
	return [ran2 > 1.0 and moved2 < 1.0, "guest room ran %.2f s with the shop open (want > 1), body moved %.1f px (want 0)" % [ran2, moved2]]
```
Add `co-menutick` to `ALL=` in `coop-test.sh`. Before running it, confirm that `Room.time` advances in both `step()` and `step_guest()`; if `step_guest()` does not advance `time`, measure `Game.play_time` on the guest instead (it is advanced in `RoomManager.tick`). Note the shop's own key handling: `"right"` is not a shop key, so holding it must not change the menu.

**Check.** Old code: `co-menutick` FAILS (room time does not advance). New code: PASS, and `--test=shop`, `--test=bench`, `co-shop`, `co-bench` still PASS (alone the world still waits: `shop`/`bench` unit tests run without co-op). Commit `MV3-FIX-3: in co-op a bench menu or the shop no longer stops the world; the body just takes no input`.

---

## MV3-FIX-4 · The guest's loadout is not checked against owned plugins (MEDIUM)

**Bug.** `godot/src/autoload/game.gd`, `load_profile()` keeps every plugin of the guest's `user://profile.json` that fits the notches, **owned or not**, and the host's `"loadout":` branch in `coop.gd` does the same. A guest who owned plugins in another world (or before the host started a new game) keeps them on and gets their effects.

**Fix: one filter used everywhere.**
1. `game.gd`: add after `notches_used()`:

```gdscript
# the loadout that may really be on: known, owned (flag plugin:<id>, shared by both players) and within the context window, in order
func filter_loadout(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var d := plugin_def(String(id))
		if d.size() > 0 and owns_plugin(String(id)) and not out.has(String(id)) and notches_used(out) + int(d.cost) <= NOTCHES:
			out.append(String(id))
	return out
```

2. `game.gd`, `load_profile()`: replace the block

```gdscript
		equipped = []
		for id in d.equipped:
			if plugin_def(String(id)).size() > 0 and notches_used() + int(plugin_def(String(id)).cost) <= NOTCHES:
				equipped.append(String(id))
```
with `equipped = filter_loadout(d.equipped)`.

3. `game.gd`, the save loader: replace the three lines `equipped = []` / `for id in d.get("equipped", []):` / `if plugin_def(...) and owns_plugin(...) ...: equipped.append(...)` (just before `return true`) with the single line `equipped = filter_loadout(d.get("equipped", []))`.

4. `coop.gd`, `_host_rel` branch `"loadout":`: replace the `var ids` loop with `var ids: Array = Game.filter_loadout(d.get("ids", []))` and keep `remote.loadout = ids` and the log line.

5. `coop.gd`, `_guest_start`: `Game.flags = sv.flags` must run before `Game.load_profile()` (it does today; keep that order). Right after `Game.load_profile()` add the line `Game.save_profile()` (so a dropped plugin is also gone from the guest's file; it returns early in tests).

**Test: new unit test `loadout`:**

```gdscript
# MV3-FIX-4: only owned plugins that fit the context window stay on (guest profile, save, the host judging the guest)
func t_loadout() -> bool:
	Game.flags = {"plugin:async_await": true}
	var a: Array = Game.filter_loadout(["async_await", "cache", "bogus"])
	Game.flags = {"plugin:async_await": true, "plugin:cache": true, "plugin:hot_reload": true}
	var b: Array = Game.filter_loadout(["async_await", "hot_reload", "cache", "cache"])
	Game.flags = {}
	var c: Array = Game.filter_loadout(["async_await"])
	var ok: bool = a == ["async_await"] and b == ["async_await", "cache"] and c.is_empty()
	return report("loadout", ok, "owned only %s, notches + no duplicates %s, nothing owned %s" % [str(a), str(b), str(c)])
```
Register it (rule 6).

**Check.** Old code: `loadout` FAILS (no `filter_loadout`). New code: `loadout`, `plugins`, `save`, `co-plugins` PASS. Commit `MV3-FIX-4: a loadout keeps only owned plugins (guest profile, save, host check)`.

---

## MV3-FIX-5 · A guest purchase can stay "asking the host…" forever (LOW)

**Bug.** `godot/src/ui/shop_menu.gd`: `buy()` refuses while `pending != ""`. If the connection is reset before the host's answer arrives (a reload of the link starts a fresh reliable channel), `pending` is never cleared, so that page can never buy again.

**Fix.** `coop.gd`, `_guest_start`: right after `Game.load_profile()` (and the `save_profile` from FIX-4) add:

```gdscript
	if main.shop_menu.pending != "":                 # a purchase asked on the old link gets no answer: ask again from scratch
		main.shop_menu.pending = ""
		main.shop_menu.msg = ""
```

**Test: extend `sc_co_rejoin`**, guest branch: before `Net.ws.close(4000, "test")` add `main.shop_menu.pending = "hot_reload"`. After the line `var again := await wait_until(func(): return coop().started, 8.0)` add `var unstuck: bool = main.shop_menu.pending == ""`. Add `unstuck` to the returned boolean and message.

**Check.** Old code: `co-rejoin` FAILS. New code: `co-rejoin`, `co-shop` PASS. Commit `MV3-FIX-5: a fresh start clears a purchase that was asked on the old link`.

---

## MV3-FIX-6 · The Fights page counts agent, catch and dash damage as claw hits (LOW, but it skews R_PLAYER)

**Bug.** `godot/src/world/room.gd`, `boss_damage()` adds 1 to `stats.hits` for **every** damage event. `R_PLAYER` is "claw hits per player per second": agents (about 2 hits/s for 11 s), caught projectiles and dashes inflate it.

**Fix.**
1. `room.gd`: change the function to

```gdscript
func boss_damage(_boss, d: float, how := "swipe") -> void:
	if attacker == null:
		return
	dmg_log.append({"t": time, "who": attacker, "d": d})
	if fight.state == "active":
		var i: int = 1 if (attacker in remote_players) else 0
		if how == "swipe":
			stats.hits[i] += 1                 # R_PLAYER counts claw hits only
		else:
			stats.other[i] += 1                # agents, caught projectiles, dashes: shown apart
```

2. `room.gd`, `_begin_fight()`: the `stats = {...}` line gets `"other": [0, 0]` added.
3. `room.gd`, `_start_reward()` and `record_loss()`: add `"other": stats.get("other", [0, 0]).duplicate()` to the dictionary appended to `Game.fights`. In `_start_reward()` append ` | other damage P1 %d P2 %d` (with `stats.other[0], stats.other[1]`) to the `Game.dlog(...)` line.
4. Pass `how` from both callers: `godot/src/enemies/boss.gd` `room.boss_damage(self, dmg)` → `room.boss_damage(self, dmg, how)`; `godot/src/enemies/merge_boss.gd` `room.boss_damage(self, dm)` → `room.boss_damage(self, dm, how)`.

**Test: new unit test `bossstats`:**

```gdscript
# MV3-FIX-6: only claw swipes count as hits on the Fights page (agents, catches, dashes are counted apart)
func t_bossstats() -> bool:
	var m := reviewer_setup()
	var room := m.room
	var p = m.player
	for f in range(900):
		p.inv = 999.0
		m.tick(Game.STEP)
		if room.fight.state == "active":
			break
	var boss: Reviewer = room.boss
	boss.set_state("idle", 5.0)
	room.attacker = p
	boss.hit(1, 1.0, 0.0, "agent", null)
	boss.hit(1, 1.0, 0.0, "catch", null)
	boss.hit(1, 1.0, 0.0, "swipe", null)
	var ok: bool = room.fight.state == "active" and room.stats.hits[0] == 1 and room.stats.other[0] == 2
	var info := "fight %s, hits %s (want [1, 0]), other %s (want [2, 0])" % [room.fight.state, str(room.stats.hits), str(room.stats.get("other"))]
	m.queue_free()
	return report("bossstats", ok, info)
```
Register it (rule 6). If 900 frames are not enough for the intro to finish in `reviewer_setup()`, read how `t_reviewer` reaches the active fight and use the same.

**Check.** Old code: `bossstats` FAILS. New code: `bossstats`, `null`, `reviewer`, `merge`, `bossreg` PASS. Commit `MV3-FIX-6: the Fights page counts claw hits only; other boss damage is counted apart`.

---

## MV3-FIX-7 · The host forgets strikes too early and refuses a late guest parry (LOW)

**Bug.** `room.gd`, `record_hist()`:

```gdscript
		if e.strike_seen.size() > 8:
			e.strike_seen.clear()
```
runs right after the current strike was recorded, so every ninth strike the host forgets the strike that just ended (and the current one, for a frame). A guest parry of the previous strike that arrives late on a bad line is refused.

**Fix.** Replace those two lines with:

```gdscript
		if e.strike_seen.size() > 8:                     # keep the last second: a late parry from the guest is judged against it
			for sk in e.strike_seen.keys():
				if time - float(e.strike_seen[sk]) > 1.0:
					e.strike_seen.erase(sk)
```

**Test: new unit test `strikeseen`:**

```gdscript
# MV3-FIX-7: a strike that ended a moment ago is still known when the ninth one starts (the guest's late parry is judged against it)
func t_strikeseen() -> bool:
	var m := reviewer_setup()
	var room := m.room
	var boss: Reviewer = room.boss
	boss.active = true
	for sid in range(1, 10):
		boss.strike_sid = sid
		boss.st = "lunge"
		room.time += 0.05
		room.record_hist()
	var ok: bool = boss.strike_seen.has(8) and boss.strike_seen.has(9)
	var info := "known strikes %s (want 8 and 9 among them)" % str(boss.strike_seen.keys())
	m.queue_free()
	return report("strikeseen", ok, info)
```
Register it (rule 6). (`record_hist()` reads `hurtboxes()` too; if it needs `remote_players` to be non-empty, read the function and set up only what it needs.)

**Check.** Old code: `strikeseen` FAILS. New code: `strikeseen`, `reviewer`, `co-reviewer` (also `BADLINE_ALL=1`) PASS. Commit `MV3-FIX-7: the host keeps a second of strikes for the guest's parry`.

---

## MV3-FIX-8 · A new REVIEWER reuses strike ids a player already parried (LOW)

**Bug.** `godot/src/enemies/reviewer.gd`: `sid_seq` starts at 0 in every new `Reviewer`, but `Player.parried` (strike ids the player parried, which can no longer hurt it) is only cleared when it passes 64 entries. A boss built again (Refight bosses, a rebuilt room) without the player dying makes its first strikes harmless to that player.

**Fix: strike ids unique for the whole session, and a clean list per fight.**
1. `godot/src/autoload/game.gd`: add near the boss section:

```gdscript
var strike_seq := 0                   # strike ids (catchable boss strikes): unique for the session, so a new boss never reuses a parried one
func next_strike_id() -> int:
	strike_seq += 1
	return strike_seq
```
2. `reviewer.gd`, `_new_strike()`: replace the body with `strike_sid = Game.next_strike_id()`. Delete `var sid_seq := 0`.
3. `room.gd`, `_begin_fight()`: in the existing `for q in ps:` loop (the one setting `q.frozen = false`) add:

```gdscript
		if q.get("parried") != null:
			q.parried.clear()
```
4. `coop.gd`, `_guest_start`: after `p.hp = int(you.hp)` add `p.parried.clear()` (a new host session restarts its strike ids).

**Test: new unit test `sidunique`:**

```gdscript
# MV3-FIX-8: a second REVIEWER never hands out a strike id the first one used
func t_sidunique() -> bool:
	var room := new_room("R10")
	var a := Reviewer.new(room, 100, 100)
	var used := {}
	for k in range(3):
		a._new_strike()
		used[a.strike_sid] = true
	var b := Reviewer.new(room, 100, 100)
	b._new_strike()
	var ok: bool = not used.has(b.strike_sid) and b.strike_sid > 0
	var info := "first boss %s, second boss %d" % [str(used.keys()), b.strike_sid]
	a.free()
	b.free()
	room.queue_free()
	return report("sidunique", ok, info)
```
Register it (rule 6).

**Check.** Old code: `sidunique` FAILS. New code: `sidunique`, `reviewer`, `catch`, `co-reviewer` PASS. Commit `MV3-FIX-8: strike ids are unique per session; the parried list is cleared when a fight begins`.

---

## MV3-FIX-9 · The snapshot can touch a freed agent owner (LOW, defensive)

**Bug.** `coop.gd`, `_send_snapshot()`:

```gdscript
	for a in r.agents:
		ag.append([2 if a.owner_p.get("is_remote") == true else 1, NetClasses.x4(a.x), NetClasses.x4(a.y)])
```
If the host respawns (its `Player` is `queue_free`d) while its agents still fly in the guest's room, a snapshot sent before that room's next step calls `get` on a freed object (a `SCRIPT ERROR`).

**Fix.** Replace with:

```gdscript
	for a in r.agents:
		if not is_instance_valid(a.owner_p):
			continue                        # (its owner was just freed; the room drops the agent on its next step)
		ag.append([2 if a.owner_p.get("is_remote") == true else 1, NetClasses.x4(a.x), NetClasses.x4(a.y)])
```

**Test.** No new test (the failing path needs a node freed between two physics steps). `co-agents` and `co-soak` must stay free of `SCRIPT ERROR`. Commit `MV3-FIX-9: the snapshot skips agents whose owner is gone`.

---

## FINAL

1. `bash tools/godot/test-all.sh` → must end `ALL PASS`. The `relay` group (headless browser) is timing-sensitive: if only it fails, re-run once before calling it real.
2. `BADLINE_ALL=1 bash tools/godot/coop-test.sh all` → every scenario PASS.
3. `test-all.sh` re-exports the web build into `public/mv`. Commit **only** `public/mv` as the last commit: `Export public/mv (phase 3 fixes)`.
4. Update the status table at the top of `docs/PLAN-metroidvania-phase3-fixes.md` (add one if missing: fix, commit, old test result, new test result).
5. Write `docs/reports/metroidvania-phase3-fixes.md` **in Persian**, short: one line per fix (what was wrong, what changed, which test proves it: old FAIL → new PASS), the suite results, and any deviation from this plan with the reason. Commit it before the export commit.
6. `git push -u origin ph1` (on a network error retry up to 4 times: 2 s, 4 s, 8 s, 16 s). Do not merge into `main`.

## Status

| fix | commit | old | new |
|---|---|---|---|
| FIX-1 | 9c609ec | FAIL (second cast missing) | PASS |
| FIX-2 | f71b7ad | FAIL (no net_sample) | PASS |
| FIX-3 | d560af7 | FAIL (host room did not run) | PASS |
| FIX-4 | 1232179 | FAIL (no filter_loadout) | PASS |
| FIX-5 | e2e584b | FAIL (purchase stayed pending) | PASS |
| FIX-6 | a60e153 | FAIL (hits [3,0]) | PASS |
| FIX-7 | 04d5dcb | FAIL (strikes forgotten) | PASS |
| FIX-8 | 91e7240 | FAIL (id reused) | PASS |
| FIX-9 | bcc3403 | — | — |
