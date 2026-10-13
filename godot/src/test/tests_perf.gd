extends RefCounted
class_name TestsPerf
# The fixes for Zakaria's log of 2026-10-13 ("the phone lags, the PC gets slower the longer we play, going up a shaft crashed") and the
# tools that found them. updoors and perfflags pass or fail (test-all runs them); the perf* ones only measure.
# Frame cost (logic + drawing), headless: the numbers are the process's CPU time (Linux /proc), so they count the _draw calls too.
# A phone runs the web build several times slower.
#   --test=perfrooms  every room (PERF_ROOMS=<prefix> for some), `PERF <room> <ms per frame> logic <ms>`, slowest last
#   --test=perfgrow   the same rooms over and over (PERF_ROOMS=a,b,c, PERF_LAPS): a cost or a node count that grows lap after lap is a leak
#   --test=perfstay   one room (PERF_ROOMS, D05) for PERF_LAPS x 600 frames, nothing rebuilt: the cost must stay flat

const NAMES := ["perfrooms", "perfgrow", "perfstay", "perfflags", "updoors"]
var main
var logic_ms := 0.0

func _init(m) -> void:
	main = m

func run(name: String):
	match name:
		"perfrooms": return await t_perfrooms()
		"perfgrow": return await t_perfgrow()
		"perfstay": return await t_perfstay()
		"perfflags": return t_perfflags()
		"updoors": return await t_updoors()

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
