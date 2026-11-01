extends RefCounted
class_name TestsPerf
# The fixes for Zakaria's log of 2026-10-13 ("the phone lags, the PC gets slower the longer we play, going up a shaft crashed") and the
# tools that found them. updoors and perfflags pass or fail (test-all runs them); the perf* ones only measure.
# Frame cost (logic + drawing), headless: the numbers are the process's CPU time (Linux /proc), so they count the _draw calls too.
# A phone runs the web build several times slower.
#   --test=perfrooms  every room (PERF_ROOMS=<prefix> for some), `PERF <room> <ms per frame> logic <ms>`, slowest last
#   --test=perfgrow   the same rooms over and over (PERF_ROOMS=a,b,c, PERF_LAPS): a cost or a node count that grows lap after lap is a leak
#   --test=perffight  a boss fight in full swing, two players (a partner body stands in for the guest): `PERFFIGHT <room> p<phase> <ms per frame>
#                     logic <ms>` and what the boss's boxes cost; PERF_ROOMS=T06,N09,N15 (default), PERF_N frames per phase
#   --test=perfstay   one room (PERF_ROOMS, D05) for PERF_LAPS x 600 frames, nothing rebuilt: the cost must stay flat

const NAMES := ["perfrooms", "perffight", "perfgrow", "perfstay", "perfflags", "updoors", "perfreport"]
var main
var logic_ms := 0.0

func _init(m) -> void:
	main = m

func run(name: String):
	match name:
		"perfrooms": return await t_perfrooms()
		"perffight": return await t_perffight()
		"perfgrow": return await t_perfgrow()
		"perfstay": return await t_perfstay()
		"perfflags": return t_perfflags()
		"updoors": return await t_updoors()
		"perfreport": return await t_perfreport()

# the process's CPU time: wall time would only show the frame cap, and Godot's own monitors miss the _draw calls
func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	var parts := f.get_line().get_slice(")", 1).split(" ", false)
	return (float(parts[11]) + float(parts[12])) * 10.0

func _bot(mgr: RoomManager, i: int) -> void:
	Controls.script_input = {"right": (i / 90) % 2 == 0, "left": (i / 90) % 2 == 1, "jump": i % 40 == 0, "attack": i % 25 == 0}
	Controls.poll()
	if mgr.player != null and mgr.player.dead:
		mgr.player.dead = false
		mgr.player.hp = mgr.player.max_hp

func _ms_in(mgr: RoomManager, id: String, n: int) -> float:
	mgr.swap_to(id, null, null, true)
	for i in range(10):
		mgr.tick(Game.STEP)
		await main.get_tree().process_frame
	var c0 := _cpu_ms()
	var logic_us := 0
	for i in range(n):
		_bot(mgr, i)
		var t0 := Time.get_ticks_usec()
		mgr.tick(Game.STEP)
		logic_us += Time.get_ticks_usec() - t0
		await main.get_tree().process_frame
	logic_ms = logic_us / 1000.0 / n
	return (_cpu_ms() - c0) / n

func _mgr() -> RoomManager:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Engine.max_fps = 0
	var mgr := RoomManager.new(main.world, null)
	main.add_child(mgr)
	mgr.start_game()
	return mgr

func t_perfrooms() -> bool:
	var mgr := _mgr()
	var out: Array = []
	var only := OS.get_environment("PERF_ROOMS")
	for id in Game.rooms_meta.rooms:
		if only != "" and not String(id).begins_with(only):
			continue
		var ms := await _ms_in(mgr, String(id), 300)
		out.append([String(id), ms, logic_ms])
	out.sort_custom(func(a, b): return a[1] < b[1])
	for o in out:
		print("PERF %s %.2f logic %.2f" % [o[0], o[1], o[2]])
	print("TEST perfrooms PASS %d rooms" % out.size())
	return true

# RACE CONDITION's play-test (2026-10-31, "the frame rate drops badly in the fight"): perfrooms only measures a room with its boss asleep,
# so this one wakes the boss and keeps both players alive in it, phase 1 then phase 2
func t_perffight() -> bool:
	var mgr := _mgr()
	var ids: Array = (OS.get_environment("PERF_ROOMS") if OS.get_environment("PERF_ROOMS") != "" else "T06,N09,N15").split(",")
	var n := int(OS.get_environment("PERF_N")) if OS.get_environment("PERF_N") != "" else 600
	for id in ids:
		mgr.swap_to(String(id), null, null, true)
		var r: Room = mgr.room
		var b = r.boss
		if b == null:
			continue
		var rp := RemotePlayer.new(r)
		r.add_child(rp)
		r.remote_players.append(rp)
		var mid := float(r.pw) * 0.5
		var on := 0
		for f in range(1500):                                       # past the trigger, through the intro, 2 s into the fight
			_keep(mgr, rp, mid, f)
			mgr.tick(Game.STEP)
			await main.get_tree().process_frame
			if r.fight.state == "active" and bool(b.active):
				on += 1
				if on > 120:
					break
		for phase in [1, 2]:
			if phase == 2:
				b.hpf = float(b.max_hp) * (0.45 if String(id) == "T06" else 0.3)
				b.hp = ceili(b.hpf)
				b.on_damage()
				if b.has_method("_begin_trans"):
					b._begin_trans()
				for f in range(300):
					_keep(mgr, rp, mid, f)
					mgr.tick(Game.STEP)
					await main.get_tree().process_frame
			var c0 := _cpu_ms()
			var logic_us := 0
			var walls: Array = []
			var harm_f := 0
			var thirds := [0.0, 0.0, 0.0]                              # (the cost of the first, middle and last third: a cost that grows is a leak)
			for f in range(n):
				_keep(mgr, rp, mid, f)
				var t0 := Time.get_ticks_usec()
				mgr.tick(Game.STEP)
				logic_us += Time.get_ticks_usec() - t0
				await main.get_tree().process_frame
				var w := (Time.get_ticks_usec() - t0) / 1000.0
				if f % 10 == 0 and not b.harmboxes().is_empty():
					harm_f += 10
				walls.append(w)
				thirds[mini(2, f * 3 / n)] += w
			var ms := (_cpu_ms() - c0) / n
			walls.sort()
			print("PERFFIGHT %s p%d frames: median %.2f p99 %.2f max %.2f ms, thirds %.2f %.2f %.2f, harm on %d%% of frames, gfx %s lights %d parts %d nodes %d" % [id, phase, walls[n / 2], walls[n * 99 / 100], walls[n - 1],
				thirds[0] * 3.0 / n, thirds[1] * 3.0 / n, thirds[2] * 3.0 / n, harm_f * 100 / n, Game.GFX_NAMES[Game.gfx_tier], int(Game.gfx_stats.lights), int(Game.gfx_stats.parts), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			var t1 := Time.get_ticks_usec()
			var nb := 0
			for k in range(100):
				nb = b.harmboxes().size() + b.hurtboxes().size()
			var box_us := (Time.get_ticks_usec() - t1) / 100.0
			print("PERFFIGHT %s p%d %.2f logic %.2f boxes %.0f us (%d) state %s alive %s" % [id, phase, ms, logic_us / 1000.0 / n, box_us, nb, r.fight.state, str(not b.dead)])
	print("TEST perffight PASS")
	return true

# the two bodies walk about the middle of the arena and never die
func _keep(mgr: RoomManager, rp, mid: float, i: int) -> void:
	_bot(mgr, i)
	if mgr.player != null:
		mgr.player.inv = 99.0
		mgr.player.hp = mgr.player.max_hp
		if i % 300 == 0:
			mgr.player.x = mid + 60.0 * sin(i * 0.01)
	rp.x = mid - 40.0 + 50.0 * sin(i * 0.013)
	rp.dead = false
	var b = mgr.room.boss                                           # (the guest's page would say it saw each plan: nothing here does)
	if b != null:
		if b.get("th") is Array and not b.th.is_empty() and b.th[0] is Dictionary and b.th[0].has("plan"):
			for q in b.th:
				if not q.plan.is_empty():
					b.plan_seen(int(q.plan.seq))
		elif b.get("plan") is Dictionary and not b.plan.is_empty():
			b.plan_seen(int(b.plan.seq))

func t_perfgrow() -> bool:
	var mgr := _mgr()
	var ids: Array = (OS.get_environment("PERF_ROOMS") if OS.get_environment("PERF_ROOMS") != "" else "N01,N02,N04,N11,T09,T10,T11").split(",")
	for lap in range(int(OS.get_environment("PERF_LAPS")) if OS.get_environment("PERF_LAPS") != "" else 10):
		var tot := 0.0
		for id in ids:
			if Game.rooms_meta.rooms.has(id):
				tot += await _ms_in(mgr, id, 60)
		print("PERFLAP %d ms/frame %.2f nodes %d objects %d orphans %d log %d" % [lap, tot / ids.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Game.log_buf.size()])
	Node.print_orphan_nodes()
	print("TEST perfgrow PASS")
	return true

func t_perfstay() -> bool:
	var mgr := _mgr()
	var id := OS.get_environment("PERF_ROOMS") if OS.get_environment("PERF_ROOMS") != "" else "D05"
	mgr.swap_to(id, null, null, true)
	for lap in range(int(OS.get_environment("PERF_LAPS")) if OS.get_environment("PERF_LAPS") != "" else 8):
		var c0 := _cpu_ms()
		for i in range(600):
			_bot(mgr, i)
			mgr.tick(Game.STEP)
			await main.get_tree().process_frame
		print("PERFSTAY %d ms/frame %.2f room %s" % [lap, (_cpu_ms() - c0) / 600.0, mgr.room.id])
	print("TEST perfstay PASS")
	return true

# --test=perfflags: what the co-op's per-snapshot work over the flags costs with a late-game save (~1000 flags). It runs 30 times a second
# on each page, so it grew with the save: one cause of "the longer we play, the slower it gets".
func t_perfflags() -> bool:
	Game.persist = false
	Game.fresh()
	Game.load_meta()
	for id in Game.rooms_meta.rooms:
		for f in ["room:%s:visited", "mapped:%s", "bench:%s", "item:%s:f0", "item:%s:f1", "item:%s:f2", "dead:%s", "log:%s:0", "log:%s:1", "crack:%s:3:4", "key:%s:0", "switch:%s:1"]:
			Game.flags[f % id] = true
	var n := 200
	var t0 := Time.get_ticks_usec()
	var d := 0
	for i in range(n):
		d = Game.world_digest()
	var dig := (Time.get_ticks_usec() - t0) / float(n)
	t0 = Time.get_ticks_usec()
	for i in range(n):
		Game.flags["changelog:x%d" % (i % 3)] = true          # (a change now and then must still be seen)
		d = Game.world_digest()
	var dig_ch := (Time.get_ticks_usec() - t0) / float(n)
	t0 = Time.get_ticks_usec()
	for i in range(n):
		Game._wd_val = -1                                       # (forced walk: what every call cost before the cache)
		d = Game.world_digest()
	var walk := (Time.get_ticks_usec() - t0) / float(n)
	var ok := d == Game.world_digest() and dig * 5.0 < walk
	var fresh := Game.world_digest()
	Game.flags["lever:QQ:0"] = true
	ok = ok and Game.world_digest() != fresh
	Game.flags["lever:QQ:0"] = false
	ok = ok and Game.world_digest() == fresh
	t0 = Time.get_ticks_usec()
	var gf: Array = []
	for i in range(n):
		gf = Game.room_flags("T09")
	var gfl := (Time.get_ticks_usec() - t0) / float(n)
	print("PERFFLAGS %d flags: world_digest %.0f us (with changes %.0f us, a full walk %.0f us), room flags %.0f us, ok %s" % [Game.flags.size(), dig, dig_ch, walk, gfl, ok])
	print("TEST perfflags %s" % ("PASS" if ok else "FAIL"))
	return ok

# --test=updoors (MV5A fix): every unlocked door in a ceiling, crossed going up, jump let go at once. Where a one-way ledge sits over the
# target's floor door the push must carry the body onto it: before, the tower's shafts (TA1/TB1/TC1 -> T04, TA2/TB2 -> T08, TC2 -> T09)
# dropped it straight back into the room below ("going up to the next room crashed"). Never inside a wall, no script error.
func t_updoors() -> bool:
	var mgr := _mgr()
	Game.tools = {"bash": true, "catch": true, "sudo": true, "agents": true, "opus": true, "curl": true, "ssh": true, "breakpoint": true}
	var bad: Array = []
	var n := 0
	var e0 := Game.errors
	for id in Game.rooms_meta.rooms:
		for d in Game.rooms_meta.rooms[id].doors:
			if String(d.side) != "N" or String(d.get("lock", "")) != "":
				continue
			n += 1
			mgr.swap_to(String(id), Vector2((int(d.a) + int(d.b) + 1) * 8.0 - 5.0, 10.0), null, true)
			for tx in range(int(d.a), int(d.b) + 1):            # (a cracked ceiling: the player has bashed it by now)
				if mgr.room.grid.tile(tx, 0) == TileGrid.CRACK:
					mgr.room.grid.tiles[tx] = TileGrid.E
			mgr.player.vy = -300.0
			mgr.player.jumping = true
			var to := String(d.to).get_slice(":", 0)
			var arrived := false
			var ledge := false
			var stuck := ""
			for f in range(150):
				Controls.script_input = {}
				Controls.poll()
				mgr.tick(Game.STEP)
				if mgr.room.id == to and not mgr.trans.on and not arrived:
					arrived = true
					var g := mgr.room.grid
					var td: Dictionary = {}
					for k in g.doors:
						if String(k.id) == String(d.to):
							td = k
					for ty in range(g.h - 2, maxi(-1, g.h - 2 - RoomManager.PUSH_MAX_ROWS), -1):
						var hit := -1
						for tx in range(int(td.a), int(td.b) + 1):
							if g.tile(tx, ty) != TileGrid.E:
								hit = g.tile(tx, ty)
								break
						if hit >= 0:
							ledge = hit == TileGrid.ONEWAY
							break
				if arrived and mgr.room.id == to and stuck == "":
					var p = mgr.player
					var g2 := mgr.room.grid
					if g2.solid_at(p.x + 1, p.y + 1) and g2.solid_at(p.x + p.w - 1, p.y + 1) and g2.solid_at(p.x + 1, p.y + p.h - 1) and g2.solid_at(p.x + p.w - 1, p.y + p.h - 1):
						stuck = "inside a wall at %d,%d" % [int(p.x), int(p.y)]
			if not arrived:
				bad.append("%s: never reached %s" % [d.id, to])
			elif stuck != "":
				bad.append("%s -> %s: %s" % [d.id, to, stuck])
			elif ledge and mgr.room.id != to:
				bad.append("%s -> %s: fell back to %s past the ledge over the door" % [d.id, to, mgr.room.id])
	Controls.script_input = null
	var ok := bad.is_empty() and Game.errors == e0 and n > 20
	print("TEST updoors %s %d doors up, problems %s, script errors %d" % ["PASS" if ok else "FAIL", n, str(bad), Game.errors - e0])
	return ok

# brief 05: the speed report Zakaria copies from his PC (pause menu, ?debug: Copy log). Each room gets a line with its frame spread,
# a room left after 3 s gets a SPEED line in the log (a guest's reaches the host's log), and a boss fight is counted apart from its room.
func t_perfreport() -> bool:
	var mgr := _mgr()
	for id in ["T02", "H02"]:
		mgr.swap_to(id, null, null, true)
		var t0 := Time.get_ticks_msec()
		var i := 0
		while Time.get_ticks_msec() - t0 < 3500:            # (wall time: a room is logged after 3 s)
			_bot(mgr, i)
			i += 1
			mgr.tick(Game.STEP)
			await main.get_tree().process_frame
	mgr.swap_to("D02", null, null, true)
	for i in range(5):
		mgr.tick(Game.STEP)
		await main.get_tree().process_frame
	var text := Game.log_text()
	var ok := text.contains("SPEED REPORT") and text.contains("  T02 ") and text.contains("  H02 ") and text.contains("SPEED T02 ") and text.contains("SPEED H02 ")
	var m: FrameMeter = Game.perf.get("T02")
	ok = ok and m != null and m.n >= 100 and m.total >= 3000.0
	print(text.substr(0, 600))
	print("TEST perfreport %s" % ("PASS" if ok else "FAIL"))
	return ok
