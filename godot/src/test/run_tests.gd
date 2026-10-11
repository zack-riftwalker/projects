extends RefCounted
# Headless test entry. main.gd hands control here when the user arg --test=<name> is present.
# Every test prints `TEST <name> PASS|FAIL <info>`; run() returns true on pass. Tests never wait for real frames.

var main

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func new_room(room_id := "R01") -> Room:
	var room := Room.new()
	main.world.add_child(room)
	room.load_room(room_id)
	room.build_nodes()
	return room

func run(name: String) -> bool:
	if name.begins_with("tape:"):
		return t_tape(name.substr(5))
	if name.begins_with("etrace:"):
		return t_etrace(name.substr(7))
	match name:
		"tiles": return t_tiles()
		"jump": return t_jump()
		"combat": return t_combat()
		"hurt": return t_hurt()
		"soak": return t_soak()
		"rooms": return t_rooms()
		"doors": return t_doors()
		"save": return t_save()
		"crack": return t_crack()
		"end": return t_end()
		"bench": return t_bench()
		"null": return t_null()
		"focus": return t_focus()
		"guard": return t_guard()
		"zombie": return t_zombie()
		"dashhurt": return t_dashhurt()
		"platform": return t_platform()
		"relpend": return t_relpend()
		"misc": return t_misc()
		"nullcoop": return t_nullcoop()
		"guestpred": return t_guestpred()
		"parity": return t_parity()
		"bossreg": return t_bossreg()
		"rooms3": return t_rooms3()
		"catch": return t_catch()
		"exception": return t_exception()
		"reviewer": return t_reviewer()
		"plugins": return t_plugins()
		"crumble": return t_crumble()
		"w2enemies": return t_w2enemies()
		"rooms3b": return t_rooms3b()
		"merge": return t_merge()
		"agents": return t_agents()
		"shop": return t_shop()
		"skipboss": return t_skipboss()
		"bossfree": return t_bossfree()
		"sidunique": return t_sidunique()
		"strikeseen": return t_strikeseen()
		"bossstats": return t_bossstats()
		"loadout": return t_loadout()
		"mergeinterp": return t_mergeinterp()
		"fork": return t_fork()
		"nsdoors": return t_nsdoors()
		"tiles4": return t_tiles4()
		"flood": return t_flood()
		"plugins4": return t_plugins4()
		"rise": return t_rise()
	return report(name, false, "unknown test")

class Box:
	var x := 0.0
	var y := 0.0
	var w := 10.0
	var h := 10.0

func box(x: float, y: float) -> Box:
	var b := Box.new()
	b.x = x
	b.y = y
	return b

func t_tiles() -> bool:
	var room := new_room()
	var g := room.grid
	var ok := true
	var info := ""
	var chk := func(label: String, cond: bool) -> void:
		if not cond:
			ok = false
			info += " BAD:" + label
	chk.call("w=202", room.w == 202)
	chk.call("h=16", room.h == 16)
	chk.call("tile(0,13)", g.tile(0, 13) == TileGrid.SOLID)
	chk.call("tile(-1,5)", g.tile(-1, 5) == TileGrid.SOLID)
	chk.call("tile(5,99)", g.tile(5, 99) == TileGrid.E)
	chk.call("tile(24,12)", g.tile(24, 12) == TileGrid.SOLID)
	chk.call("tile(75,11)", g.tile(75, 11) == TileGrid.ONEWAY)
	var b := box(35, 190)
	var r := g.move_y(b, 20)
	info += " fall y=%s r=%d" % [b.y, r]
	chk.call("fall", b.y == 198.0 and r == 1)
	b = box(35, 198)
	var rx := 0
	var n := 0
	while rx == 0 and n < 400:
		rx = g.move_x(b, 2)
		n += 1
	info += " wall x=%s r=%d" % [b.x, rx]
	chk.call("wall", b.x == 374.0 and rx == 1)
	b = box(1219, 150)
	r = g.move_y(b, 20, false)
	info += " oneway y=%s r=%d" % [b.y, r]
	chk.call("oneway", b.y == 166.0 and r == 1)
	b = box(1219, 150)
	r = g.move_y(b, 20, true)
	info += " nooneway y=%s r=%d" % [b.y, r]
	chk.call("no_oneway", b.y == 170.0 and r == 0)
	room.queue_free()
	return report("tiles", ok, info)

# one fixed step with scripted input (js: G.input.script + G.step(1, true))
func step_with(room: Room, keys: Dictionary) -> void:
	Controls.script_input = keys
	Controls.poll()
	room.step(Game.STEP)

func t_jump() -> bool:
	var room := new_room()
	for e in room.ents:
		e.queue_free()
	room.ents.clear()
	for i in range(60):
		step_with(room, {})
	var p = room.player
	var settle := "settled x=%s y=%s" % [p.x, p.y]
	var min_y: float = p.y
	for f in range(90):
		var keys := {}
		if f <= 59:
			keys["right"] = true
		if f >= 10 and f <= 39:
			keys["jump"] = true
		step_with(room, keys)
		min_y = minf(min_y, p.y)
	var ok := absf(p.x - 151.608) <= 0.001 and absf(min_y - 140.596) <= 0.001
	Controls.script_input = null
	return report("jump", ok, "%s final x=%.3f min y=%.3f" % [settle, p.x, min_y])

func clear_ents(room: Room) -> void:
	for e in room.ents:
		e.queue_free()
	room.ents.clear()

func add_bug(room: Room, bx: float, by: float, fc: float) -> Bug:
	var b := Bug.new(room, 0, 0, false)
	b.x = bx
	b.y = by
	b.face = fc
	room.ents.append(b)
	room.entity_root.add_child(b)
	return b

func loose_tokens(room: Room) -> int:
	var n := 0
	for it in room.items:
		if it.get("loose", false) and not it.get("dead", false):
			n += 1
	return n

func t_combat() -> bool:
	var room := new_room()
	clear_ents(room)
	room.cam.x = 60.0
	var p = room.player
	p.x = 170.0
	p.y = 198.0
	var b := add_bug(room, 200, 199, -1)
	for f in range(25):
		step_with(room, {"attack": f == 5})
	var kills1: int = room.kills
	var tokens1 := loose_tokens(room)
	var slash_ok := kills1 == 1 and tokens1 == 1
	# stomp: drop onto a second bug from 40 px above
	for e in room.ents:
		e.queue_free()
	room.ents.clear()
	var p2 = room.player
	p2.x = 250.0
	p2.y = 158.0
	p2.vy = 0.0
	p2.on_ground = false
	p2.inv = 0.0
	var b2 := add_bug(room, 250, 199, -1)
	b2.speed = 0.0
	var bounced := false
	var killed_by_stomp := false
	for f in range(60):
		step_with(room, {})
		if room.kills == 2:
			killed_by_stomp = true
			bounced = p2.vy < 0.0
			break
	Controls.script_input = null
	var ok := slash_ok and killed_by_stomp and bounced
	return report("combat", ok, "swipe kills=%d tokens=%d | stomp kill=%s bounce vy=%.1f hp=%d" % [kills1, tokens1, killed_by_stomp, p2.vy, p2.hp])

func t_hurt() -> bool:
	var room := new_room()
	clear_ents(room)
	room.cam.x = 0.0
	var p = room.player
	for i in range(30):
		step_with(room, {})
	var ty := Typo.new(room, 0, 0)
	ty.stun = 999.0
	room.ents.append(ty)
	room.entity_root.add_child(ty)
	ty.x = p.x
	ty.y = p.y
	step_with(room, {})
	var hp1: int = p.hp
	var inv1: float = p.inv
	for i in range(60):
		ty.x = p.x
		ty.y = p.y
		step_with(room, {})
	var ok: bool = hp1 == 4 and absf(inv1 - 1.3) < 0.05 and p.hp == 4
	Controls.script_input = null
	return report("hurt", ok, "hp after first touch=%d inv=%.3f hp after 1 s of touching=%d" % [hp1, inv1, p.hp])

# plays a tape (same format as tools/godot/parity/tapes/*.json) and prints frame,x,y,vx,vy,onGround like js-trace.js
func t_tape(path: String) -> bool:
	var tape: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var room_ids := {"1-1": "R01"}
	var room := new_room(room_ids[tape.room])
	clear_ents(room)
	for k in tape.tools:
		Game.tools[k] = tape.tools[k]
	var p = room.player
	# the JS game has already run its first frames when the tape starts: Clawd stands on the ground. Same here.
	for i in range(60):
		step_with(room, {})
	if tape.start != null:
		p.x = float(tape.start[0])
		p.y = float(tape.start[1])
		p.vx = 0.0
		p.vy = 0.0
	for f in range(int(tape.frames)):
		var keys := {}
		for seg in tape.input:
			if f >= int(seg[0]) and f <= int(seg[1]):
				for a in seg[2]:
					keys[a] = true
		step_with(room, keys)
		print("%d,%.6f,%.6f,%.6f,%.6f,%d" % [f, p.x, p.y, p.vx, p.vy, 1 if p.on_ground else 0])
	Controls.script_input = null
	return true

# etrace:<class>:<x>:<y>:<px>:<py>:<frames>: one creature in the NULL arena (R05, boss beaten), the player standing still and unhurtable;
# prints frame,x,y,vx,vy,on_ground like the JS tools/godot/parity/enemy-trace.js
func t_etrace(arg: String) -> bool:
	var a := arg.split(":")
	Game.flags = {"boss:NULL": true}
	var room := new_room("R05")
	clear_ents(room)
	var p = room.player
	for i in range(60):
		p.inv = 99999.0
		step_with(room, {})
	var px_ := float(a[1])
	var py_ := float(a[2])
	var e
	match a[0]:
		"Bug": e = Bug.new(room, px_, py_, false)
		"Mimic": e = Mimic.new(room, px_, py_)
		"Noodle": e = Noodle.new(room, px_, py_)
		"Logger": e = LogEnemy.new(room, px_, py_)
		"Flaky": e = Flaky.new(room, px_, py_)
		_: return report("etrace", false, "unknown class " + a[0])
	add_ent(room, e)
	p.x = float(a[3])
	p.y = float(a[4])
	p.vx = 0.0
	p.vy = 0.0
	for f in range(int(a[5])):
		p.inv = 99999.0
		step_with(room, {})
		print("%d,%.6f,%.6f,%.6f,%.6f,%d" % [f, e.x, e.y, e.vx, e.vy, 1 if e.on_ground else 0])
	Controls.script_input = null
	Game.flags = {}
	return true

# 3600 frames of seeded random input in R01 with its enemies: no script errors, the player stays inside the room
func t_soak() -> bool:
	var room := new_room()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var keys := {}
	var p = room.player
	var min_x := 1e9
	var max_x := -1e9
	var ok := true
	var why := ""
	for f in range(3600):
		if f % 15 == 0:
			keys = {}
			for a in ["left", "right", "up", "down", "jump", "attack", "dash"]:
				if rng.randf() < (0.45 if a == "right" else 0.25):
					keys[a] = true
		step_with(room, keys)
		if p.dead:
			room.events.clear()
			room.death_t = -1.0
			p.dead = false
			p.hp = p.max_hp
			p.x = room.start.x
			p.y = room.start.y
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		if p.x < -1.0 or p.x > room.pw + 1.0 or p.y > room.ph + 40.0 or is_nan(p.x) or is_nan(p.y):
			ok = false
			why = " out of bounds at frame %d x=%.1f y=%.1f" % [f, p.x, p.y]
			break
	Controls.script_input = null
	return report("soak", ok, "3600 frames, x %.0f..%.0f, kills=%d hits=%d tokens=%d%s" % [min_x, max_x, room.kills, room.hits, room.tokens, why])

func new_manager() -> RoomManager:
	var m := RoomManager.new(main.world, null)
	main.add_child(m)
	m.start_game()
	return m

# first solid row below the door in the column of x (so a test can stand Clawd on the floor in front of a door)
func floor_y(room: Room, x: float, from_row: int) -> float:
	var tx := floori(x / 16.0)
	for ty in range(from_row, room.h):
		if room.grid.solid(tx, ty):
			return ty * 16.0 - 10.0
	return room.ph - 26.0

# walk R01 -> R02 -> R03 -> R04 through the east doors
func t_rooms() -> bool:
	var m := new_manager()
	var ok := true
	var info := ""
	var path := ["R01", "R02", "R03", "R04"]
	for i in range(path.size() - 1):
		var r := m.room
		if r.id != path[i]:
			ok = false
			info += " BAD: expected %s but in %s" % [path[i], r.id]
			break
		var d = null
		for dd in r.grid.doors:
			if dd.side == "E":
				d = dd
		var p = m.player
		p.x = r.pw - p.w - 4.0
		p.y = floor_y(r, p.x + 5, d.a)
		p.vx = 0.0
		p.vy = 0.0
		Controls.script_input = {"right": true}
		var n := 0
		while m.room.id == path[i] and n < 300:
			m.tick(Game.STEP)
			n += 1
		var grounded := -1
		for f in range(40):
			m.tick(Game.STEP)
			if p.on_ground and not m.trans.on:
				grounded = f
				break
		var nr := m.room
		var good: bool = nr.id == path[i + 1] and grounded >= 0 and grounded <= 20 and p.y > (nr.grid.doors[0].a - 2) * 16.0
		info += " %s->%s (%d ticks, grounded after %d)" % [path[i], nr.id, n, grounded]
		if not good:
			ok = false
			info += " BAD"
			break
		Controls.script_input = {}
		for f in range(10):
			m.tick(Game.STEP)
	Controls.script_input = null
	Controls.locked = false
	return report("rooms", ok, info)

func t_doors() -> bool:
	Game.flags.erase("boss:NULL")
	var room := new_room("R05")
	room.update_doors()
	var closed: bool = room.grid.tile(room.w, 8) == TileGrid.SOLID
	var w_open: bool = room.grid.tile(-1, 8) == TileGrid.E
	Game.flags["boss:NULL"] = true
	room.update_doors()
	var opened: bool = room.grid.tile(room.w, 8) == TileGrid.E
	var above: bool = room.grid.tile(room.w, 5) == TileGrid.SOLID
	room.fight_active = true
	room.update_doors()
	var w_closed: bool = room.grid.tile(-1, 8) == TileGrid.SOLID
	Game.flags.erase("boss:NULL")
	return report("doors", closed and opened and w_open and above and w_closed, "E closed=%s opened=%s W open=%s W closed in fight=%s wall above=%s" % [closed, opened, w_open, w_closed, above])

func t_save() -> bool:
	Game.persist = true
	Game.save_path = "user://test_save.json"
	Game.new_game()
	var m := new_manager()
	var room := m.room
	var p = m.player
	var c: Dictionary = room.cps[0]
	p.x = c.x - 5.0
	p.y = c.y - 10.0
	var tok := {}
	for it in room.items:
		if it.kind == "token":
			tok = it
			break
	var tok_id: String = tok.id
	room.collect(tok)
	p.hp = 2
	m.rest(room, 0)
	var rested_hp: int = p.hp
	# reload the game from the file
	var tokens_before := Game.tokens
	Game.fresh()
	var loaded := Game.load_save()
	m.queue_free()
	var m2 := new_manager()
	var token_gone := true
	for it in m2.room.items:
		if it.get("id", "") == tok_id:
			token_gone = false
	var at_bench: bool = m2.room.id == "R01" and Game.bench == "R01" and absf(m2.player.x - (c.x - 5.0)) < 1.0
	# die: back on the bench with full hp
	var died := [false]
	m2.restart_requested.connect(func(): died[0] = true)
	m2.player.die()
	Controls.script_input = {}
	for f in range(200):
		m2.tick(Game.STEP)
		if died[0]:
			break
	m2.respawn(true)
	var back: bool = m2.player.hp == m2.player.max_hp and absf(m2.player.x - (c.x - 5.0)) < 1.0 and absf(m2.player.y - (c.y - 10.0)) < 1.0
	var ok: bool = loaded and rested_hp == 5 and token_gone and tokens_before == 1 and Game.tokens == 1 and at_bench and died[0] and back and Game.deaths == 1
	Controls.script_input = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	Game.persist = false
	return report("save", ok, "loaded=%s rested hp=%d token gone=%s tokens=%d at bench=%s died event=%s back on bench full hp=%s deaths=%d" % [loaded, rested_hp, token_gone, Game.tokens, at_bench, died[0], back, Game.deaths])

func t_bench() -> bool:
	Game.persist = false
	Game.fresh()
	Game.bench = ""
	var m := new_manager()
	m.swap_to("R03")
	var room := m.room
	var c: Dictionary = room.cps[0]
	var p = m.player
	p.x = c.x - 5.0
	p.y = floor_y(room, c.x, int(c.y / 16.0) - 2)
	p.vx = 0.0
	p.vy = 0.0
	for f in range(12):
		Controls.script_input = {}
		m.tick(Game.STEP)
	Controls.script_input = null
	return report("bench", Game.bench == "R03", "bench after walking up to it without pressing anything: '%s'" % Game.bench)

func t_end() -> bool:
	Game.persist = false
	Game.flags = {}
	var m := new_manager()
	m.swap_to("H11")
	var room := m.room
	var p = m.player
	var ev := [0]
	m.end_requested.connect(func(): ev[0] += 1)
	var ok_far := true
	for f in range(10):
		Controls.script_input = {"up": f == 4}
		m.tick(Game.STEP)
	ok_far = ev[0] == 0                          # not at the door: nothing
	p.x = room.end_door.x - 5.0
	p.y = floor_y(room, room.end_door.x, int(room.end_door.y / 16.0) - 1)
	p.vx = 0.0
	p.vy = 0.0
	for f in range(12):
		Controls.script_input = {"up": f == 6}
		m.tick(Game.STEP)
	Controls.script_input = null
	return report("end", ok_far and ev[0] == 1, "far press ignored=%s, at the door end_requested=%d" % [ok_far, ev[0]])

func t_crack() -> bool:
	Game.persist = false
	Game.flags = {}
	Game.tools.bash = true
	var m := new_manager()
	m.swap_to("R07")
	var room := m.room
	var p = m.player
	var before := 0
	for ty in range(2, 13):
		for tx in range(37, 40):
			if room.grid.tile(tx, ty) == TileGrid.CRACK:
				before += 1
	p.x = 33.0 * 16.0
	p.y = floor_y(room, p.x + 5, 9)
	p.vx = 0.0
	p.vy = 0.0
	p.on_ground = true
	var n := 0
	for f in range(90):
		var keys := {"right": true}
		if f == 2:
			keys["dash"] = true
		Controls.script_input = keys
		m.tick(Game.STEP)
		n += 1
	var left := 0
	var flagged := 0
	for ty in range(2, 13):
		for tx in range(37, 40):
			if room.grid.tile(tx, ty) == TileGrid.CRACK:
				left += 1
			if Game.flag("crack:R07:%d:%d" % [tx, ty]):
				flagged += 1
	Controls.script_input = null
	Game.tools.bash = false
	return report("crack", before == 33 and left == 0 and flagged == 33, "cracked tiles before=%d left after 1.5 s=%d flags=%d" % [before, left, flagged])

func t_platform() -> bool:
	var room := new_room("R02")
	var plat = null
	for pl in room.plats:
		if pl.ax:
			plat = pl
			break
	if plat == null:
		return report("platform", false, "R02 has no horizontal platform")
	var p = room.player
	step_with(room, {})                 # the platforms jump to their phase on the first step
	p.x = plat.x + 20.0
	p.y = plat.y - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.on_ground = true
	var start_x: float = p.x
	var worst := 0.0
	var fell := false
	for f in range(240):
		step_with(room, {})
		var gap := absf((p.y + p.h) - plat.y)
		worst = maxf(worst, gap)
		if gap > 3.0 or not p.on_ground:
			fell = true
			break
	var moved := absf(p.x - start_x)
	Controls.script_input = null
	return report("platform", not fell and moved > 8.0, "4 s on the platform: max gap %.2f px, moved %.1f px with it, fell=%s" % [worst, moved, fell])

func t_focus() -> bool:
	Game.diff = "normal"
	var room := new_room()
	clear_ents(room)
	var p = room.player
	for i in range(30):
		step_with(room, {})
	p.hp = 3
	p.meter = 40.0
	for f in range(72):                       # hold [special] for 1.2 s
		step_with(room, {"special": true})
	var hp1: int = p.hp
	var meter1: float = p.meter
	# a short press does nothing
	p.hp = 3
	p.meter = 40.0
	p.focus_hold = 0.0
	for f in range(12):                       # 0.2 s
		step_with(room, {"special": true})
	for f in range(10):
		step_with(room, {})
	var short_ok: bool = p.hp == 3 and absf(p.meter - 40.0) < 0.01
	Controls.script_input = null
	return report("focus", hp1 == 4 and absf(meter1 - 7.0) < 0.01 and short_ok, "hold 1.2 s: hp %d meter %.1f | hold 0.2 s: hp %d meter %.1f" % [hp1, meter1, p.hp, p.meter])

func dash_into_bug(diff_name: String, room_mode := "solo", bug_hp := 3) -> Array:
	Game.diff = diff_name
	Game.tools.bash = true
	var room := new_room()
	clear_ents(room)
	room.cam.x = 0.0
	var p = room.player
	for i in range(30):
		step_with(room, {})
	var b := add_bug(room, p.x + p.w + 20.0, 199, -1)
	b.hp = bug_hp
	b.speed = 0.0
	b.kb = 0.0                      # it stays put, so the dash carries Clawd clean through it
	var hp0: int = p.hp
	room.mode = room_mode
	for f in range(20):
		step_with(room, {"right": true, "dash": f == 1})
	var out := [b.hp, hp0, p.hp]
	Controls.script_input = null
	Game.tools.bash = false
	return out

func t_dashhurt() -> bool:
	var n := dash_into_bug("normal")
	var e := dash_into_bug("easy")
	Game.diff = "normal"
	var g := dash_into_bug("normal", "guest", 1)       # a guest's killing dash costs nothing either (the host decides, the guest predicts)
	var ok: bool = n[0] == 2 and n[2] == n[1] - 1 and e[0] == 2 and e[2] == e[1] and g[2] == g[1]
	return report("dashhurt", ok, "normal: bug hp %d, player %d -> %d | easy: bug hp %d, player %d -> %d | guest kill: player %d -> %d" % [n[0], n[1], n[2], e[0], e[1], e[2], g[1], g[2]])

func add_ent(room: Room, e) -> void:
	room.ents.append(e)
	room.entity_root.add_child(e)

func t_guard() -> bool:
	Game.diff = "normal"
	var room := new_room()
	clear_ents(room)
	room.cam.x = 60.0
	var p = room.player
	for i in range(30):
		step_with(room, {})
	# 1. from the front: the guard faces left, Clawd swings right from its left
	p.x = 150.0
	p.face = 1.0
	var g := Guard.new(room, 0, 0)
	g.x = 174.0
	g.y = 192.0
	g.face = -1.0
	g.stun = 999.0
	add_ent(room, g)
	var hp0: int = g.hp
	for f in range(8):
		step_with(room, {"attack": f == 1, "right": false})
	var front_ok: bool = g.hp == hp0
	# 2. from behind: it faces right, Clawd swings right from its left
	g.face = 1.0
	p.x = 150.0
	p.vx = 0.0
	p.atk_cd = 0.0
	p.atk_t = 0.0
	for f in range(20):
		step_with(room, {"attack": f == 1})
	var back_ok: bool = g.hp == hp0 - 1
	# 3. pogo: a down-swipe from above lands whatever it faces
	g.face = -1.0
	p.x = g.x + 2.0
	p.y = g.y - 28.0
	p.vy = 0.0
	p.on_ground = false
	p.atk_cd = 0.0
	p.atk_t = 0.0
	var hp1: int = g.hp
	var bounced := false
	for f in range(60):
		step_with(room, {"down": true, "attack": f == 1})
		if g.hp < hp1:
			bounced = p.vy < 0.0
			break
	var pogo_ok: bool = g.hp == hp1 - 1 and bounced
	# 4. a diagonal dash from the front is blocked as well; one from behind, and a swipe upwards, are not
	g.face = 1.0
	var diag_front: bool = g.blocks(-0.7071, 0.7071, "dash") and g.blocks(-0.7071, -0.7071, "dash")
	var diag_back: bool = not g.blocks(0.7071, 0.7071, "dash")
	var swipe_up: bool = not g.blocks(0.0, -1.0, "swipe")
	var diag_ok: bool = diag_front and diag_back and swipe_up
	Controls.script_input = null
	return report("guard", front_ok and back_ok and pogo_ok and diag_ok, "front blocked=%s | behind hit=%s | pogo hit=%s bounce=%s (hp %d of %d) | diagonal dash from the front blocked=%s, from behind not=%s, swipe up not=%s" % [front_ok, back_ok, pogo_ok, bounced, g.hp, hp0, diag_front, diag_back, swipe_up])

func t_zombie() -> bool:
	Game.diff = "normal"
	var room := new_room()
	clear_ents(room)
	room.cam.x = 60.0
	for i in range(10):
		step_with(room, {})
	var z := Zombie.new(room, 0, 0)
	z.x = 260.0
	z.y = 196.0
	add_ent(room, z)
	z.hit(1, 1.0, 0.0, "swipe")
	z.hit(1, 1.0, 0.0, "swipe")
	var corpse: bool = z.state == "down" and z.passive and not z.dead and room.kills == 0
	for f in range(216):              # 3.6 s: 3 s down + 0.5 s rising
		step_with(room, {})
	var back: bool = z.state == "idle" and z.hp == 2 and not z.passive
	z.hit(1, 1.0, 0.0, "swipe")
	z.hit(1, 1.0, 0.0, "swipe")
	var corpse2: bool = z.state == "down"
	z.hit(1, 0.0, 1.0, "swipe")       # the down-swipe: kill -9
	var tokens := loose_tokens(room)
	Controls.script_input = null
	var ok: bool = corpse and back and corpse2 and z.dead and room.kills == 1 and tokens == 2
	return report("zombie", ok, "corpse=%s back after 3.5 s=%s corpse again=%s dead=%s kills=%d tokens=%d" % [corpse, back, corpse2, z.dead, room.kills, tokens])

func null_setup() -> RoomManager:
	Game.flags = {}
	Game.tools.bash = false
	Game.fights = []
	Game.diff = "normal"
	var m := new_manager()
	m.swap_to("R05")
	var p = m.player
	p.x = 100.0
	p.y = floor_y(m.room, 105.0, 7)
	return m

func t_null() -> bool:
	var m := null_setup()
	var room := m.room
	var p = m.player
	var boss = room.boss
	var seen := {}
	var longest := 0.0
	var cur_state := ""
	var since := 0.0
	var feints := 0
	Controls.script_input = {}
	# A: the boss alone against a bot that stands still and cannot be hurt: phase 1 for 50 s, then phase 2 for 70 s
	var phase2_at := 3000
	for f in range(7200):
		p.inv = 999.0
		p.hp = p.max_hp
		if f == phase2_at:
			boss.hit(1, 0.0, 0.0, "swipe", boss)
			boss.hpf = boss.max_hp / 2.0 - 0.5
			boss.hit(1, 0.0, 0.0, "swipe", boss)
		m.tick(Game.STEP)
		if boss.active:
			var key: String = "%d:%s%s" % [boss.phase, boss.st, (":" + boss.cur.mode) if boss.st == "poke" else ""]
			seen[key] = true
			if boss.feint_done:
				feints += 1
			if key != cur_state:
				cur_state = key
				since = 0.0
			since += Game.STEP
			longest = maxf(longest, since)
	var need := ["1:poke:aim", "1:poke:fly", "1:poke:stuck", "1:rain", "1:sweepPrep", "1:sweep", "1:tired", "2:poke:aim", "2:dangling", "2:sweep", "2:rain", "2:deref", "2:derefStuck"]
	var missing: Array = []
	for k in need:
		if not seen.has(k):
			missing.append(k)
	var a_ok: bool = missing.is_empty() and longest <= 6.0 and feints > 0 and boss.phase == 2
	# B: hit the boss once per 0.5 s until it dies
	var m2 := null_setup()
	room = m2.room
	p = m2.player
	boss = room.boss
	var dead_at := -1
	for f in range(9000):
		p.inv = 999.0
		p.hp = p.max_hp
		if boss.active and f % 30 == 0:
			room.attacker = p
			boss.hit(1, 0.0, 0.0, "swipe", boss)
		m2.tick(Game.STEP)
		if not Game.tools.bash == false:
			dead_at = f
			break
	var door_open: bool = room.grid.tile(room.w, 8) == TileGrid.E
	var b_ok: bool = dead_at > 0 and Game.tools.bash and Game.flag("boss:NULL") and Game.flag("ability:bash") and door_open and Game.fights.size() == 1 and Game.fights[0].won
	Controls.script_input = null
	Game.tools.bash = false
	Game.flags = {}
	return report("null", a_ok and b_ok, "seen %d states, missing %s, longest state %.1f s, feints=%s, phase %d | kill: reward at frame %d, bash=%s door open=%s fights=%s" % [seen.size(), missing, longest, feints > 0, boss.phase, dead_at, Game.tools.bash, door_open, str(Game.fights)])


# MV3-01: the boss comes from rooms.json (class, hp formula), the reward from its entry, and the Fights page shows the list
func t_bossreg() -> bool:
	var m := null_setup()
	var room := m.room
	var ok := true
	var info := ""
	var normal_hp: int = room.boss.max_hp
	var is_null: bool = room.boss is NullBoss and room.boss.boss_name == "NULL"
	Game.diff = "hard"
	var hard_hp: int = Game.boss_hp(room.def.boss)
	Game.diff = "normal"
	info += "normal=%d hard=%d class_ok=%s" % [normal_hp, hard_hp, is_null]
	ok = ok and normal_hp == 60 and hard_hp == 78 and is_null
	room.stats = {"secs": 10.0, "hits": [5, 0], "dmg": [0, 0], "coop": false}
	room._start_reward()
	room._finish_reward()
	var reward_ok: bool = Game.tools.bash and Game.flag("boss:NULL") and Game.flag("ability:bash") and room.boss == null
	info += " reward=%s" % reward_ok
	ok = ok and reward_ok
	var n_fights: int = Game.fights.size()
	ok = ok and n_fights == 1 and room.stats_line.begins_with("NULL 10s")
	Game.fights = [{"boss": "NULL", "secs": 72.0, "hits": [41, 30], "dmg_taken": [3, 2], "won": true, "diff": "normal", "coop": true}]
	var line := PauseMenu.fight_line(Game.fights[0])
	var avg := PauseMenu.fight_average(Game.fights)
	info += " line='%s' avg='%s'" % [line, avg]
	ok = ok and line == "NULL 72s P1 41 P2 30 r 0.49 won normal" and avg == "average r (won fights): 0.49 over 1 fights"
	Game.tools.bash = false
	Game.flags = {}
	Game.fights = []
	return report("bossreg", ok, info)

# walk through the door of `side` that leads to `to_id` (the player is put in front of it); returns true when it arrived
func walk_door(m: RoomManager, to_id: String, side := "E") -> bool:
	var r := m.room
	var d = null
	for dd in r.grid.doors:
		if dd.side == side and String(dd.to).begins_with(to_id):
			d = dd
	var p = m.player
	p.x = r.pw - p.w - 4.0 if side == "E" else 4.0
	p.y = floor_y(r, p.x + 5, d.a)
	p.vx = 0.0
	p.vy = 0.0
	Controls.script_input = {"right": side == "E", "left": side == "W"}
	var n := 0
	while m.room.id != to_id and n < 300:
		m.tick(Game.STEP)
		n += 1
	for f in range(30):
		m.tick(Game.STEP)
	Controls.script_input = {}
	return m.room.id == to_id

# MV3-02: R07 -> R08 -> R09, each ledge of R09 reaches the next with one jump, R09:NE -> R10, R10 -> R11 once the boss flag is set,
# R09:E (to D01, since 3B) is open
func t_rooms3() -> bool:
	Game.flags = {}
	var m := new_manager()
	m.swap_to("R07")
	var ok := true
	var info := ""
	for to_id in ["R08", "R09"]:
		var good := walk_door(m, to_id)
		info += " ->%s %s" % [to_id, good]
		ok = ok and good
	var r9 := m.room
	var p = m.player
	# the ledges of R09, bottom to top: runs of '=' (then the solid shelf in front of the NE door)
	var ledges: Array = []
	for ty in range(r9.h - 1, -1, -1):
		var row := r9.rows[ty]
		var tx := row.find("====")
		if tx >= 0:
			ledges.append([tx, ty])
	ledges.append([19, 9])                              # the shelf: 5 solid tiles at row 9
	var reached := 0
	for i in range(ledges.size() - 1):
		var a: Array = ledges[i]
		var b: Array = ledges[i + 1]
		var fx_: float = a[0] * 16.0 + 32.0 - p.w / 2.0
		p.x = fx_
		p.y = a[1] * 16.0 - p.h
		p.vx = 0.0
		p.vy = 0.0
		for f in range(6):
			Controls.script_input = {}
			m.tick(Game.STEP)
		var goal_x: float = b[0] * 16.0 + (32.0 if b[0] < 19 else 40.0)
		var landed := false
		for f in range(60):
			var dxg: float = goal_x - (p.x + p.w / 2.0)
			Controls.script_input = {"jump": f < 40, "right": dxg > 3.0, "left": dxg < -3.0}
			m.tick(Game.STEP)
			if f > 10 and p.on_ground and absf(p.y + p.h - b[1] * 16.0) < 1.5:
				landed = true
				break
		if landed:
			reached += 1
		else:
			info += " BAD ledge %d (row %d) -> (row %d): ended at %.0f,%.0f" % [i, a[1], b[1], p.x, p.y]
	ok = ok and reached == ledges.size() - 1 and ledges.size() == 7
	info += " ledges %d reached %d" % [ledges.size(), reached]
	# R09:E leads to D01 now (3B): its door is open
	r9.update_doors()
	var e_solid: bool = r9.grid.tile(r9.w, 26) == TileGrid.E
	info += " R09:E open=%s" % e_solid
	ok = ok and e_solid
	var good2 := walk_door(m, "R10")
	info += " ->R10 %s" % good2
	var r10_w_ok: bool = m.room.id == "R10"
	Game.flags["boss:REVIEWER1"] = true
	m.room.update_doors()
	m.room.fight_active = false
	var good3 := false
	if r10_w_ok:
		good3 = walk_door(m, "R11")
	info += " ->R11 %s" % good3
	ok = ok and good2 and good3
	Controls.script_input = null
	Game.flags = {}
	return report("rooms3", ok, info)

# MV3-03: catch. One projectile flies at the player (facing it); the swipe starts at frame 0 and the projectile reaches the claw box at frame k.
# Returns "caught" (friendly, reversed x1.5), "destroyed" (dead, never friendly) or "hurt"
func catch_case(k: int, with_ability: bool, diff_name := "normal") -> String:
	Game.flags = {}
	Game.diff = diff_name
	Game.tools.catch = with_ability
	var m := new_manager()
	m.swap_to("R11")
	var room := m.room
	clear_ents(room)
	var p = m.player
	p.x = 100.0
	p.y = floor_y(room, 105.0, 8)
	p.face = 1.0
	p.hp = p.max_hp
	Controls.script_input = {}
	for f in range(10):
		m.tick(Game.STEP)
	var hp0: int = p.hp
	var sp := 130.0
	var xf: float = p.x + p.w - 4 + 24.0 + 4.0                # the claw box's front edge plus the projectile radius
	var q: Dictionary = room.shoot(xf + float(k) * sp / 60.0, p.y + 5.0, -sp, 0.0, {"kind": "err", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1})
	var out := "hurt"
	for f in range(40):
		Controls.script_input = {"attack": f == 0}
		m.tick(Game.STEP)
		if q.get("friendly", false):
			out = "caught"
			break
		if q.dead:
			out = "destroyed" if p.hp == hp0 else "hurt"
			break
	var vx_ok: bool = out != "caught" or absf(q.vx - 195.0) < 1.0
	Controls.script_input = null
	Game.tools.catch = false
	return out if vx_ok else "wrong speed %.0f" % q.vx

func t_catch() -> bool:
	var ok := true
	var info := ""
	var early := catch_case(2, true)
	var late := catch_case(5, true)
	var none := catch_case(2, false)
	var easy := catch_case(5, true, "easy")        # the easy window (0.14 s) still catches where the normal one (0.10 s) has just closed
	var hard_edge := catch_case(5, true, "nightmare")
	info += "frame2=%s frame5=%s noability=%s easy5=%s nightmare5=%s" % [early, late, none, easy, hard_edge]
	ok = early == "caught" and late == "destroyed" and none == "destroyed" and easy == "caught" and hard_edge == "destroyed"
	# a caught projectile hurts a Bug for 2 and presses the switch; the gate opens and stays open
	Game.flags = {}
	Game.diff = "normal"
	Game.tools.catch = true
	var m := new_manager()
	m.swap_to("R11")
	var room := m.room
	clear_ents(room)
	var p = m.player
	p.x = 40.0
	p.y = floor_y(room, 45.0, 8)
	p.inv = 999.0
	var bug := add_bug(room, 150.0, p.y, -1.0)
	bug.hp = 5
	var q: Dictionary = room.shoot(100.0, p.y + 5.0, -200.0, 0.0, {"kind": "err", "col": "#ffd23f", "r": 4.0, "catchable": true, "life": 3.0, "dmg": 1})
	room.catch_proj(q, p)
	for f in range(40):
		m.tick(Game.STEP)
	var bug_ok: bool = bug.hp == 3
	var sw: Dictionary = room.switches[0]
	var q2: Dictionary = room.shoot(250.0, sw.y + 5.0, -200.0, 0.0, {"kind": "err", "col": "#ffd23f", "r": 4.0, "catchable": true, "life": 3.0, "dmg": 1})
	room.catch_proj(q2, p)
	var closed_before: bool = room.grid.solid(24, 11)
	for f in range(60):
		m.tick(Game.STEP)
	var gate_open: bool = not room.grid.solid(24, 11) and Game.flag("gate:R11:catch") and Game.flag("switch:R11:0")
	var room2 := Room.new()
	main.world.add_child(room2)
	room2.load_room("R11")
	room2.build_nodes()
	room2.update_doors()
	var stays: bool = not room2.grid.solid(24, 11)
	info += " | bug hp 5->%d switch/gate: closed before=%s open=%s after rebuild=%s" % [bug.hp, closed_before, gate_open, stays]
	ok = ok and bug_ok and closed_before and gate_open and stays
	Game.tools.catch = false
	Game.flags = {}
	return report("catch", ok, info)

# MV3-04: EXCEPTION winds up 0.5 s, throws a catchable yellow error, only with a line of sight
func t_exception() -> bool:
	Game.diff = "normal"
	Game.flags = {}
	var info := ""
	var ok := true
	for walled in [false, true]:
		var m := new_manager()
		m.swap_to("R11")
		var room := m.room
		clear_ents(room)
		var p = m.player
		p.x = 40.0
		p.y = floor_y(room, 45.0, 8)
		p.inv = 999.0
		var e := ExceptionFoe.new(room, 0, 0)
		e.x = 140.0
		e.y = p.y - 4.0
		e.nid = 77
		add_ent(room, e)
		if walled:                                   # a solid block on the line between the two
			room.grid.tiles[(floori((p.y + 5.0) / 16.0)) * room.w + 5] = TileGrid.SOLID
			room.grid.tiles[(floori((p.y + 5.0) / 16.0) - 1) * room.w + 5] = TileGrid.SOLID
		var wind_f := -1
		var throw_f := -1
		var prev := ""
		var q = null
		for f in range(300):
			p.hp = p.max_hp
			m.tick(Game.STEP)
			if e.state == "windup" and prev != "windup" and wind_f < 0:
				wind_f = f
			prev = e.state
			if throw_f < 0 and not room.projs.is_empty():
				throw_f = f
				q = room.projs[0]
		if walled:
			var quiet: bool = wind_f < 0 and throw_f < 0
			info += " | walled: no wind-up/throw=%s" % quiet
			ok = ok and quiet
		else:
			var len_f: int = throw_f - wind_f
			var good: bool = wind_f >= 0 and throw_f >= 0 and absf(len_f - 30.0) <= 2.0 and q != null and q.catchable and q.kind == "err" and q.vx < 0.0 and q.col == "#ffd23f"
			info += "wind-up %d frames (want 30), catchable=%s vx=%s" % [len_f, q != null and q.catchable, str(q.vx) if q != null else "-"]
			ok = ok and good
	Controls.script_input = null
	return report("exception", ok, info)

func reviewer_setup() -> RoomManager:
	Game.flags = {}
	Game.tools.catch = false
	Game.fights = []
	Game.diff = "normal"
	var m := new_manager()
	m.swap_to("R10")
	var p = m.player
	p.x = 100.0
	p.y = floor_y(m.room, 105.0, 8)
	return m

# MV3-05: THE REVIEWER. A: every attack of both phases against a bot that stands still; B: a parry staggers; C: the stance blocks and
# answers; D: standing next to him gets shoved; E: dying grants catch and opens the east door
func t_reviewer() -> bool:
	var m := reviewer_setup()
	var room := m.room
	var p = m.player
	var boss: Reviewer = room.boss
	var seen := {}
	var longest := 0.0
	var since := 0.0
	var cur_state := ""
	var slashes := {}
	Controls.script_input = {}
	var hp_ok: bool = boss.max_hp == 49
	for f in range(7200):
		p.inv = 999.0
		p.hp = p.max_hp
		if f == 3000:
			boss.hpf = boss.max_hp / 2.0 - 0.1
			boss.on_damage()
		m.tick(Game.STEP)
		if boss.active:
			var key: String = "%d:%s" % [boss.phase, boss.st]
			seen[key] = true
			if boss.st == "slash":
				slashes[boss.slash] = true
			if key != cur_state:
				cur_state = key
				since = 0.0
			since += Game.STEP
			longest = maxf(longest, since)
	var need: Array = []
	for st_ in ["idle", "lunge_tel", "lunge", "lunge_rec", "comments_tel", "comments_air", "comments_rec", "review", "review_open"]:
		need.append("1:" + st_)
		need.append("2:" + st_)
	for st_ in ["nitpick_tel", "slash", "nitpick_gap", "nitpick_rec", "phase"]:
		need.append("2:" + st_)
	var missing: Array = []
	for k in need:
		if not seen.has(k):
			missing.append(k)
	var a_ok: bool = hp_ok and missing.is_empty() and longest <= 6.0 and slashes.size() == 3 and boss.phase == 2
	var info := "A: %d states, missing %s, longest %.1f s, slashes %s, hp49=%s" % [seen.size(), str(missing), longest, str(slashes.keys()), hp_ok]
	# B: a parry during a lunge staggers him (through the room's own parry code)
	m = reviewer_setup()
	room = m.room
	p = m.player
	boss = room.boss
	Game.tools.catch = true
	var started := false
	for f in range(600):
		p.inv = 999.0
		m.tick(Game.STEP)
		if boss.active and boss.st == "lunge":
			started = true
			break
	var sid0: int = boss.strike_sid
	var hurt_sid := false                                 # (the lunge's strike box carries the id and is catchable)
	for hb in boss.harmboxes():
		if hb is Dictionary and hb.has("sid") and hb.catchable and hb.sid == sid0:
			hurt_sid = true
	p.x = boss.x + boss.w + 2.0 if boss.face > 0.0 else boss.x - 14.0
	p.y = boss.y + 4.0
	p.face = -boss.face
	p.atk_t = 0.16
	p.atk_live = true
	p.atk_dir = "f"
	p.atk_face = p.face
	room.interact_combat(p)
	var parried_ok: bool = started and sid0 > 0 and p.parried.has(sid0) and boss.st == "stagger"
	info += " | B: lunge sid %d, parried=%s st=%s" % [sid0, p.parried.has(sid0), boss.st]
	# C: the stance blocks a swipe and answers with a riposte at the attacker
	boss.set_state("review", 1.2)
	boss.riposted = false
	var hp_c: int = boss.hp
	room.attacker = p
	var res: String = boss.hit(1, 1.0, 0.0, "swipe", boss)
	var rip_box := false
	for hb in boss.harmboxes():
		if hb is Dictionary and hb.has("sid") and not hb.catchable:
			rip_box = true
	var c_ok: bool = res == "block" and boss.hp == hp_c and boss.st == "riposte" and rip_box
	info += " | C: stance hit -> %s, st=%s, riposte box=%s" % [res, boss.st, rip_box]
	# D: standing at his side for 1.2 s gets a shove (he is in the corner and cannot step away)
	m = reviewer_setup()
	room = m.room
	p = m.player
	boss = room.boss
	for f in range(200):
		p.inv = 999.0
		m.tick(Game.STEP)
		if boss.active:
			break
	boss.x = 0.0
	boss.face = 1.0
	boss.set_state("idle", 8.0)
	p.x = 16.0
	p.y = boss.y
	var shoved := false
	for f in range(150):
		p.inv = 999.0
		p.x = 16.0
		p.vx = 0.0
		m.tick(Game.STEP)
		if f % 20 == 0 and OS.get_environment("REV_DEBUG") != "":
			print("D f=%d st=%s st_t=%.2f camp=%.2f x=%.1f px=%.1f py=%.1f by=%.1f active=%s" % [f, boss.st, boss.st_t, boss.camp_t, boss.x, p.x, p.y, boss.y, boss.active])
		if boss.st == "shove_tel" or boss.st == "shove":
			shoved = true
			break
	info += " | D: shove=%s" % shoved
	# E: take the hp down to nothing: kneel, reward catch, flags, the east door opens
	var door_before: bool = room.grid.tile(room.w, 8) == TileGrid.SOLID
	var dead_at := -1
	for f in range(2400):
		p.inv = 999.0
		p.hp = p.max_hp
		if boss.active and not boss.dying and f % 20 == 0:
			room.attacker = p
			boss.hit(3, 0.0, 0.0, "catch", boss)
		m.tick(Game.STEP)
		if Game.tools.catch and Game.flag("boss:REVIEWER1"):
			dead_at = f
			break
	room.update_doors()
	var door_open: bool = room.grid.tile(room.w, 8) == TileGrid.E
	var e_ok: bool = dead_at > 0 and Game.flag("ability:catch") and door_before and door_open and Game.fights.size() == 1 and Game.fights[0].won and Game.fights[0].boss == "REVIEWER1"
	info += " | E: reward at frame %d, door was closed=%s open=%s fights=%d" % [dead_at, door_before, door_open, Game.fights.size()]
	Controls.script_input = null
	Game.tools.catch = false
	Game.flags = {}
	Game.fights = []
	return report("reviewer", a_ok and parried_ok and hurt_sid and c_ok and shoved and e_ok, info)

# MV3-06: plugins. Equipping refuses a 4th notch; each plugin changes exactly its number.
func plug_room() -> Room:
	var room := new_room("R01")
	clear_ents(room)
	var p = room.player
	for i in range(30):
		step_with(room, {})
	return room

func t_plugins() -> bool:
	for d in Game.PLUGINS:
		Game.flags["plugin:" + d.id] = true
	Game.equipped = []
	var info := ""
	# the context window: async/await (2) + cache (1) = 3; nothing else fits; taking one off makes room
	var a1 := Game.toggle_plugin("async_await")
	var a2 := Game.toggle_plugin("cache")
	var a3 := Game.toggle_plugin("eslint_fix")
	var a4 := Game.toggle_plugin("hot_reload")
	var used3: bool = Game.notches_used() == 3
	var off := Game.toggle_plugin("async_await")
	var a5 := Game.toggle_plugin("eslint_fix")
	var notches_ok: bool = a1 and a2 and not a3 and not a4 and used3 and off and a5 and Game.equipped == ["cache", "eslint_fix"]
	info += "notches %s" % notches_ok
	Game.equipped = []
	Game.tools.bash = true
	Game.diff = "normal"
	var res := {}
	for combo in [[], ["async_await"], ["hot_reload"], ["eslint_fix"], ["try_finally"], ["rubber_duck"], ["cache"]]:
		Game.equipped = combo.duplicate()
		var key: String = combo[0] if not combo.is_empty() else "none"
		var room := plug_room()
		var p = room.player
		p.hp = p.max_hp
		match key:
			"none", "async_await":
				step_with(room, {"dash": true, "right": true})
				res[key] = p.dash_cd
			"hot_reload":
				p.hp = p.max_hp - 1
				p.meter = 99.0
				var fr := 0
				while p.hp < p.max_hp and fr < 200:
					step_with(room, {"special": true})
					fr += 1
				res[key] = fr
			"eslint_fix":
				p.meter = 0.0
				p.gain_meter()
				res[key] = p.meter
			"try_finally":
				p.inv = 0.0
				p.hurt(1, p.x + 50.0)
				res[key] = p.inv
			"rubber_duck":
				p.hp = 1
				step_with(room, {"attack": true})
				var d1: int = p.atk_dmg
				res[key] = d1
			"cache":
				var it := {"kind": "token", "x": p.x + 5.0 + 20.0, "y": p.y + 5.0, "id": "item:test:1", "ph": 0.0}
				room.items.append(it)
				var tk0: int = Game.tokens
				for f in range(20):
					step_with(room, {})
				res[key] = it.get("dead", false)
		room.queue_free()
	# the base numbers without a plugin, for the comparison
	Game.equipped = []
	var room0 := plug_room()
	var p0 = room0.player
	p0.hp = p0.max_hp - 1
	p0.meter = 99.0
	var fr0 := 0
	while p0.hp < p0.max_hp and fr0 < 200:
		step_with(room0, {"special": true})
		fr0 += 1
	p0.meter = 0.0
	p0.gain_meter()
	var meter0: float = p0.meter
	p0.inv = 0.0
	p0.hp = p0.max_hp
	p0.hurt(1, p0.x + 50.0)
	var inv0: float = p0.inv
	p0.hp = 1
	p0.atk_cd = 0.0
	p0.atk_t = 0.0
	step_with(room0, {"attack": true})
	var dmg0: int = p0.atk_dmg
	p0.hp = 2
	p0.atk_cd = 0.0
	p0.atk_t = 0.0
	step_with(room0, {})
	step_with(room0, {"attack": true})
	var dmg_hp2: int = p0.atk_dmg
	var tok0 := {"kind": "token", "x": p0.x + 5.0 + 20.0, "y": p0.y + 5.0, "id": "item:test:2", "ph": 0.0}
	room0.items.append(tok0)
	for f in range(20):
		step_with(room0, {})
	var cache_base_no: bool = not tok0.get("dead", false)
	room0.queue_free()
	var dash_diff: float = float(res["none"]) - float(res["async_await"])
	var checks := {
		"dash cd -0.1": absf(dash_diff - 0.1) < 0.011,
		"focus faster (%d vs %d frames)" % [res["hot_reload"], fr0]: absi((fr0 - int(res["hot_reload"])) - 18) <= 2,
		"meter +5 (%.0f vs %.0f)" % [res["eslint_fix"], meter0]: absf(float(res["eslint_fix"]) - meter0 - 5.0) < 0.01,
		"inv +0.4 (%.2f vs %.2f)" % [res["try_finally"], inv0]: absf(float(res["try_finally"]) - inv0 - 0.4) < 0.01,
		"duck x2 at hp 1 only (%d, base %d, hp2 %d)" % [res["rubber_duck"], dmg0, dmg_hp2]: int(res["rubber_duck"]) == 2 and dmg0 == 1 and dmg_hp2 == 1,
		"cache picks a token from 20 px, base does not": bool(res["cache"]) and cache_base_no,
	}
	# the chip in R11: an item `plugin:async_await`; collecting it sets the flag and shows the banner
	Game.flags = {}
	var r11 := new_room("R11")
	var chip = null
	for it in r11.items:
		if it.kind == "plugin":
			chip = it
	var chip_ok: bool = chip != null and chip.id == "plugin:async_await"
	if chip_ok:
		r11.player.inv = 999.0
		r11.collect(chip)
	chip_ok = chip_ok and Game.owns_plugin("async_await") and r11.pick_banner.text == "async/await" and r11.pick_banner.t > 1.9
	info += " | R11 chip collected=%s" % chip_ok
	r11.queue_free()
	var ok: bool = notches_ok and chip_ok
	for k in checks:
		info += " | %s=%s" % [k, checks[k]]
		ok = ok and checks[k]
	Controls.script_input = null
	Game.equipped = []
	Game.flags = {}
	Game.tools.bash = false
	return report("plugins", ok, info)

# MV3-08: crumbling blocks (js: Level.update). Stand on it -> shakes 0.42 s -> gone (not solid) for 2.6 s while nobody stands there -> back.
func t_crumble() -> bool:
	var room := plug_room()
	var p = room.player
	var tx := floori((p.x + 5.0) / 16.0)
	var ty := floori((p.y + p.h + 1.0) / 16.0)
	var i: int = ty * room.w + tx
	room.grid.tiles[i] = TileGrid.CRUMBLE
	room.view.dynamic.set_cell(Vector2i(tx, ty), 0, Vector2i(3, 5))
	var info := ""
	for f in range(3):
		step_with(room, {})
	var started: bool = room.grid.crumble.has(i) and room.grid.crumble[i].s == 1
	var t_fall := -1.0
	var t_back := -1.0
	var elapsed := 0.0
	p.inv = 999.0
	for f in range(600):
		step_with(room, {})
		elapsed += Game.STEP
		var c = room.grid.crumble.get(i)
		if c != null and c.s == 2 and t_fall < 0.0:
			t_fall = elapsed
			# the player falls out of the way (as in the game), so nobody waits on the block
			p.x = 200.0
			p.y = 40.0
		if t_fall > 0.0 and c == null and t_back < 0.0:
			t_back = elapsed
			break
	var solid_after: bool = room.grid.solid(tx, ty)
	# the gap: not solid while state 2
	var gap_ok := true
	var room2 := plug_room()
	var p2 = room2.player
	var j: int = ty * room2.w + tx
	room2.grid.tiles[j] = TileGrid.CRUMBLE
	room2.grid.crumble[j] = {"s": 2, "t": 2.6}
	gap_ok = not room2.grid.solid(tx, ty)
	var fall_ok: bool = t_fall > 0.0 and absf(t_fall - 0.42) < 0.06
	var back_ok: bool = t_back > 0.0 and absf((t_back - t_fall) - 2.6) < 0.1
	info = "started=%s falls after %.2f s (want 0.42), back after %.2f s (want 2.6), solid again=%s, gap not solid=%s" % [started, t_fall, t_back - t_fall, solid_after, gap_ok]
	Controls.script_input = null
	return report("crumble", started and fall_ok and back_ok and solid_after and gap_ok, info)

# MV3-09: the world 2 creatures behave as described
func arena_room() -> Room:
	Game.flags = {"boss:NULL": true}
	var room := new_room("R05")
	clear_ents(room)
	var p = room.player
	p.inv = 99999.0
	p.hp = p.max_hp
	for i in range(30):
		step_with(room, {})
	return room

func t_w2enemies() -> bool:
	Game.diff = "normal"
	var info := ""
	var ok := true
	# Mimic: asleep at 52 px, awake at 40 px with DEPRECATED!
	var room := arena_room()
	var p = room.player
	p.x = 100.0
	p.y = 166.0
	var mm := Mimic.new(room, 0, 0)
	mm.x = 152.0
	mm.y = 162.0
	add_ent(room, mm)
	for f in range(20):
		p.inv = 99999.0
		step_with(room, {})
	var asleep: bool = not mm.awake
	p.x = 112.0
	for f in range(6):
		step_with(room, {})
	var woke: bool = mm.awake
	info += "mimic asleep at 52 px=%s wakes at 40 px=%s" % [asleep, woke]
	ok = ok and asleep and woke
	room.queue_free()
	# Noodle: revs 0.5 s then charges
	room = arena_room()
	p = room.player
	p.x = 260.0
	p.y = 166.0
	var nd := Noodle.new(room, 0, 0)
	nd.x = 200.0
	nd.y = 167.0
	add_ent(room, nd)
	var rev_f := -1
	var charge_f := -1
	for f in range(200):
		p.inv = 99999.0
		step_with(room, {})
		if nd.st == "rev" and rev_f < 0:
			rev_f = f
		if nd.st == "charge" and charge_f < 0:
			charge_f = f
	var nd_ok: bool = rev_f >= 0 and charge_f > rev_f and absf((charge_f - rev_f) - 30.0) <= 2.0
	info += " | noodle rev %d -> charge %d (want 30 frames)" % [rev_f, charge_f]
	ok = ok and nd_ok
	room.queue_free()
	# Logger: fires `log` projectiles
	room = arena_room()
	p = room.player
	p.x = 260.0
	p.y = 166.0
	var lg := LogEnemy.new(room, 0, 0)
	lg.x = 180.0
	lg.y = 161.0
	lg.cd = 0.1
	add_ent(room, lg)
	var logs := 0
	for f in range(240):
		p.inv = 99999.0
		step_with(room, {})
		for q in room.projs:
			if q.kind == "log" and not q.get("seen", false):
				q["seen"] = true
				logs += 1
	info += " | logger fired %d log shots" % logs
	ok = ok and logs >= 2
	room.queue_free()
	# Flaky: hovers, then swoops at a player within 118 px
	room = arena_room()
	p = room.player
	p.x = 200.0
	p.y = 166.0
	var fk := Flaky.new(room, 0, 0)
	fk.x = 140.0
	fk.y = 120.0
	fk.hx = fk.x
	fk.hy = fk.y
	fk.cd = 0.1
	add_ent(room, fk)
	var seen := {}
	for f in range(300):
		p.inv = 99999.0
		step_with(room, {})
		seen[fk.st] = true
	info += " | flaky states %s" % str(seen.keys())
	ok = ok and seen.has("mad") and seen.has("swoop") and seen.has("back")
	room.queue_free()
	Controls.script_input = null
	Game.flags = {}
	return report("w2enemies", ok, info)

func t_fork() -> bool:
	Game.diff = "normal"
	var room := arena_room()
	var p = room.player
	p.x = 260.0
	p.y = 166.0
	var fk := Fork.new(room, 0, 0)
	fk.x = 120.0
	fk.y = 164.0
	fk.cool = 0.2
	add_ent(room, fk)
	var max_kids := 0
	var spawned := 0
	var seen_kids := {}
	for f in range(1800):
		p.inv = 99999.0
		step_with(room, {})
		max_kids = maxi(max_kids, fk.alive_kids())
		for k in fk.kids:
			seen_kids[k.get_instance_id()] = true
		for e in room.ents:                              # (the kids walk about: keep them in the arena, never kill them)
			if e is Bug:
				e.hp = 99
	spawned = seen_kids.size()
	# destroyed: no more bugs
	fk.hit(99, 1.0, 0.0, "swipe", fk)
	var after0: int = room.ents.size()
	for f in range(600):
		p.inv = 99999.0
		step_with(room, {})
	var after1: int = room.ents.size()
	var kid_loot: bool = true
	for k in fk.kids:
		if is_instance_valid(k) and k.loot != 0:
			kid_loot = false
	var ok: bool = max_kids == 4 and spawned >= 4 and fk.dead and after1 <= after0 and kid_loot
	Controls.script_input = null
	Game.flags = {}
	return report("fork", ok, "max kids alive %d (want 4), spawned %d, dead=%s, entities after death %d -> %d, kids drop nothing=%s" % [max_kids, spawned, fk.dead, after0, after1, kid_loot])

# MV3-10: every new door both ways (R09 <-> D01 <-> ... <-> D07); D03 is left at its bottom and reached again by bench travel
func t_rooms3b() -> bool:
	Game.flags = {"boss:MERGE": true, "boss:NULL": true, "boss:REVIEWER1": true}
	var m := new_manager()
	m.swap_to("R09")
	var chain := ["R09", "D01", "D02", "D03", "D04", "D05", "D06", "D07"]
	var ok := true
	var info := ""
	for i in range(chain.size() - 1):
		var fwd := walk_door(m, chain[i + 1], "E")
		var back := walk_door(m, chain[i], "W")
		info += " %s<->%s %s/%s" % [chain[i], chain[i + 1], fwd, back]
		ok = ok and fwd and back
		if not fwd or not back:
			break
		if not walk_door(m, chain[i + 1], "E"):          # back in the next room for the following step
			ok = false
			break
	# terminal travel (D32): D03 is not a terminal, so D04 offers only R08
	Game.flags["bench:D03"] = true
	Game.flags["bench:D04"] = true
	Game.flags["bench:R08"] = true
	m.swap_to("D04")
	var offered: Array = m.travel_targets()
	m.travel("R08")
	for f in range(240):
		m.tick(Game.STEP)
		if m.room.id == "R08" and not m.trans.on:
			break
	var bench_ok: bool = offered == ["R08"] and m.room.id == "R08"
	info += " | terminal travel D04->R08 %s (offered %s)" % [bench_ok, str(offered)]
	Controls.script_input = null
	Game.flags = {}
	return report("rooms3b", ok and bench_ok, info)

func merge_setup() -> RoomManager:
	Game.flags = {}
	Game.tools.agents = false
	Game.fights = []
	Game.diff = "normal"
	var m := new_manager()
	m.swap_to("D05")
	var p = m.player
	p.x = 100.0
	p.y = floor_y(m.room, 105.0, 8)
	return m

func merge_head_hit(boss: MergeBoss, i: int, dmg: int) -> void:
	var hb: Array = boss.hurtboxes()
	for b in hb:
		if b.head == i:
			boss.hit(dmg, 0.0, 0.0, "swipe", b)
			return

# MV3-11: MERGE CONFLICT. The safe band is never H and never hurts; a band hurts when you stand in it; killing a head and waiting 8 s brings it
# back with half hp; killing both within the window ends the fight (agents, flag, east door).
func t_merge() -> bool:
	# A: the fight against a bot that stands still and cannot be hurt: every head attack shows up, nothing stalls
	var m := merge_setup()
	var seen := {}
	var stall := 0.0
	var longest := 0.0
	var snap_state := ""
	for f in range(5400):
		m.player.inv = 999.0
		m.player.hp = m.player.max_hp
		if f == 2700 and m.room.boss.active:                 # from here on one head fights alone (the revert is held back)
			merge_head_hit(m.room.boss, 0, 999)
			m.room.boss.heads[0].rv = 9999.0
		m.tick(Game.STEP)
		var b: MergeBoss = m.room.boss
		if b != null and b.active:
			var key := ""
			for h in b.heads:
				key += h.st + ","
			key += str(b.band_state)
			for h in b.heads:
				seen[h.st] = true
			if key != snap_state:
				snap_state = key
				stall = 0.0
			stall += Game.STEP
			longest = maxf(longest, stall)
	var a_ok: bool = seen.has("lunge") and seen.has("spit") and seen.has("slam") and seen.has("markers") and longest < 9.0
	m.queue_free()
	m = merge_setup()
	var room := m.room
	var p = m.player
	var boss: MergeBoss = room.boss
	var info := "A: heads did %s, longest unchanged state %.1f s | " % [str(seen.keys()), longest]
	var hp_ok: bool = boss.heads[0].max == 45 and boss.heads[1].max == 45 and boss.max_hp == 90
	for f in range(400):
		p.inv = 999.0
		m.tick(Game.STEP)
		if boss.active:
			break
	# 1. the bands: stand in the safe one (never hurt) and in an unsafe one (hurt), ten rounds
	var safe_seen := {}
	var safe_hurt := 0
	var unsafe_hurt := 0
	for round_ in range(10):
		p.inv = 0.0
		p.hp = 50
		boss.band_state = 0
		for h in boss.heads:
			h.st = "rest"
		boss.busy = 99.0
		boss._start_markers()
		safe_seen[boss.safe_band] = true
		# stand in the safe band during the whole attack: floor = L (2), platform = M (1)
		var want_safe: bool = round_ % 2 == 0
		var stand: int = boss.safe_band if want_safe else (1 if boss.safe_band == 2 else 2)
		if stand == 2:
			p.x = 200.0
			p.y = 166.0
		else:
			p.x = 90.0
			p.y = 118.0
		p.vx = 0.0
		p.vy = 0.0
		for f in range(260):
			p.inv = 0.0
			m.tick(Game.STEP)
			p.x = 200.0 if stand == 2 else 90.0
			p.vx = 0.0
			if boss.band_state == 0:
				break
		if OS.get_environment("MERGE_DEBUG") != "":
			print("round %d safe=%d stand=%d hp=%d/%d band_state=%d p=(%.0f,%.0f) frames" % [round_, boss.safe_band, stand, p.hp, p.max_hp, boss.band_state, p.x, p.y])
		if want_safe and p.hp < 50:
			safe_hurt += 1
		if not want_safe and p.hp == 50:
			unsafe_hurt += 1
		p.hp = p.max_hp
	var bands_ok: bool = not safe_seen.has(0) and safe_hurt == 0 and unsafe_hurt == 0 and safe_seen.size() >= 1
	info += "hp 45+45=%s | bands: safe seen %s, hurt in the safe band %d, not hurt in an unsafe band %d" % [hp_ok, str(safe_seen.keys()), safe_hurt, unsafe_hurt]
	# 2. kill head 0, wait 8 s: it is back with half hp
	boss.band_state = 0
	for h in boss.heads:
		h.st = "rest"
	boss.busy = 99.0
	merge_head_hit(boss, 0, 999)
	var dead0: bool = boss.heads[0].dead and boss.phase == 2
	var rv0: float = boss.heads[0].rv
	for f in range(60 * 7):
		p.inv = 999.0
		m.tick(Game.STEP)
	var still_dead: bool = boss.heads[0].dead
	for f in range(90):
		p.inv = 999.0
		m.tick(Game.STEP)
	var back: bool = not boss.heads[0].dead and absf(boss.heads[0].hp - 23.0) < 0.01 and boss.phase == 1
	info += " | head 0 killed=%s countdown %.1f, still dead at 7 s=%s, back with %.0f hp=%s" % [dead0, rv0, still_dead, boss.heads[0].hp, back]
	# 3. kill both inside the window: defeated
	boss.busy = 99.0
	merge_head_hit(boss, 0, 999)
	for f in range(120):
		p.inv = 999.0
		m.tick(Game.STEP)
	merge_head_hit(boss, 1, 999)
	var dead_at := -1
	for f in range(900):
		p.inv = 999.0
		m.tick(Game.STEP)
		if Game.tools.agents and Game.flag("boss:MERGE"):
			dead_at = f
			break
	room.update_doors()
	var door_open: bool = room.grid.tile(room.w, 8) == TileGrid.E
	var end_ok: bool = dead_at > 0 and Game.flag("ability:agents") and door_open and Game.fights.size() == 1 and Game.fights[0].boss == "MERGE"
	info += " | both dead inside the window: reward at frame %d, east door open=%s" % [dead_at, door_open]
	Controls.script_input = null
	Game.tools.agents = false
	Game.flags = {}
	Game.fights = []
	return report("merge", a_ok and hp_ok and bands_ok and dead0 and still_dead and back and end_ok, info)

# MV3-12: agents. A tap of [special] with a full meter sends two helpers, a hold focuses; they kill a Bug, press D06's key (the gate opens);
# the cache station fills the meter once per 20 s.
func t_agents() -> bool:
	Game.diff = "normal"
	Game.flags = {}
	Game.tools.agents = true
	var info := ""
	var room := plug_room()
	var p = room.player
	p.meter = 99.0
	p.hp = p.max_hp
	for f in range(8):                                    # a tap: 8 frames down, then up
		step_with(room, {"special": f < 4})
	var tap_ok: bool = room.agents.size() == 2 and p.meter == 0.0 and p.agents_t > 10.0
	# a second tap while they fly does nothing
	room.queue_free()
	room = plug_room()
	p = room.player
	p.meter = 99.0
	p.hp = p.max_hp - 1
	for f in range(90):                                   # a hold: focus (heals one pip), no agents
		step_with(room, {"special": true})
	step_with(room, {})
	var hold_ok: bool = room.agents.is_empty() and p.hp == p.max_hp
	info += "tap casts=%s hold focuses=%s" % [tap_ok, hold_ok]
	room.queue_free()
	# the agents kill a Bug near their owner
	room = plug_room()
	p = room.player
	p.meter = 99.0
	var bug := add_bug(room, p.x + 50.0, p.y, 1.0)
	bug.speed = 0.0
	for f in range(8):
		step_with(room, {"special": f < 4})
	var killed := false
	for f in range(240):
		step_with(room, {})
		if bug.dead:
			killed = true
			break
	info += " | agents killed the bug=%s" % killed
	room.queue_free()
	# D06: the cache station, the key, the gate
	Game.flags = {}
	var m := new_manager()
	m.swap_to("D06")
	var r6 := m.room
	clear_ents(r6)
	var p6 = m.player
	p6.x = 3.0 * 16 + 3.0                                  # stand in the cache station (letter R at column 3)
	p6.y = floor_y(r6, p6.x + 5, 8)
	p6.meter = 0.0
	p6.inv = 999.0
	Controls.script_input = {}
	for f in range(10):
		m.tick(Game.STEP)
	var filled: bool = p6.meter == float(Game.METER_MAX) and p6.cache_cool > 19.0
	p6.meter = 0.0                                         # 19 s later it does not fill again, 20 s later it does
	var early := false
	for f in range(60 * 19):
		p6.inv = 999.0
		m.tick(Game.STEP)
		if p6.meter > 0.0:
			early = true
	for f in range(90):
		p6.inv = 999.0
		m.tick(Game.STEP)
	var again: bool = p6.meter == float(Game.METER_MAX)
	info += " | cache fills=%s, not early=%s, again after 20 s=%s" % [filled, not early, again]
	# go to the key: it is inside the wall block at column 25, row 6; an agent presses it (the meter is full again)
	p6.meter = float(Game.METER_MAX)
	p6.x = 20.0 * 16
	p6.y = floor_y(r6, p6.x + 5, 8)
	p6.vx = 0.0
	for f in range(8):
		p6.inv = 999.0
		Controls.script_input = {"special": f < 4}
		m.tick(Game.STEP)
	Controls.script_input = {}
	var gate_closed: bool = r6.grid.solid(31, 10)
	var opened := false
	for f in range(400):
		p6.inv = 999.0
		m.tick(Game.STEP)
		if Game.flag("gate:D06:agents"):
			opened = true
			break
	r6.update_doors()
	var gate_open: bool = not r6.grid.solid(31, 10) and Game.flag("key:D06:0")
	info += " | gate was closed=%s, agent pressed the key and it opened=%s %s" % [gate_closed, opened, gate_open]
	Controls.script_input = null
	Game.tools.agents = false
	Game.flags = {}
	return report("agents", tap_ok and hold_ok and killed and filled and not early and again and gate_closed and opened and gate_open, info)

# MV3-13: the stall in D04. Not enough tokens -> refused; a bought item leaves the list and is owned; saved.
func t_shop() -> bool:
	Game.persist = true
	Game.save_path = "user://test_shop_save.json"
	Game.flags = {}
	Game.tokens = 50
	Game.equipped = []
	var m := new_manager()
	m.swap_to("D04")
	var room := m.room
	var p = m.player
	var stall = room.shops[0]
	p.x = stall.x - 5.0
	p.y = floor_y(room, stall.x, 8)
	var asked := [0]
	room.shop_requested.connect(func(): asked[0] += 1)
	for f in range(12):
		Controls.script_input = {"up": f == 5}
		m.tick(Game.STEP)
	Controls.script_input = null
	var shop := ShopMenu.new()
	main.add_child(shop)
	shop.open(room)
	var listed: Array = shop.ids.duplicate()
	var refused: bool = not shop.buy("rubber_duck") and Game.tokens == 50 and not Game.owns_plugin("rubber_duck")
	Game.tokens = 100
	var bought: bool = shop.buy("eslint_fix")
	var paid: bool = Game.tokens == 40 and Game.owns_plugin("eslint_fix")
	shop.ids = shop.stock()
	var gone: bool = not shop.ids.has("eslint_fix") and shop.ids.size() == listed.size() - 1
	var again: bool = not shop.buy("eslint_fix") and Game.tokens == 40
	var saved := false
	if FileAccess.file_exists(Game.save_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path))
		saved = typeof(d) == TYPE_DICTIONARY and d.flags.get("plugin:eslint_fix", false) and int(d.tokens) == 40
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	shop.queue_free()
	Game.persist = false
	Game.save_path = "user://save.json"
	Game.flags = {}
	Game.tokens = 0
	return report("shop", asked[0] == 1 and listed.size() == 4 and refused and bought and paid and gone and again and saved, "up at the stall opens it=%d, stock %s, too poor refused=%s, bought=%s tokens 100 -> %d, left the list=%s, no second purchase=%s, saved=%s" % [asked[0], str(listed), refused, bought, Game.tokens, gone, again, saved])

# a new reliable event must not push back the retransmit of an older unacknowledged one (G14)
func t_relpend() -> bool:
	Net.rel_out.clear()
	Net.rel_next = 1
	Net.rel("a", {})
	var p1: Array = Net._pending_events(0.0)
	Net.rel("b", {})
	var p2: Array = Net._pending_events(0.10)
	var p3: Array = Net._pending_events(0.25)
	Net.rel_out.clear()
	return report("relpend", p1.size() == 1 and p2.size() == 1 and p3.size() == 2, "send a: %d, send b at 0.10: %d, at 0.25 (a is 0.25 s old, unacked): %d events (want 2)" % [p1.size(), p2.size(), p3.size()])


# ?diff= beats the save and an unknown value is ignored / harmless (G12, G13)
func t_misc() -> bool:
	Game.persist = true
	Game.save_path = "user://misc_save.json"
	Game.new_game()
	Game.diff = "easy"
	Game.write_save()
	Game.diff = "hard"
	Game.diff_from_url = true            # ?diff=hard
	Game.load_save()
	var kept: String = Game.diff
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://misc_save.json"))
	Game.persist = false
	Game.diff_from_url = false
	Game.diff = "bogus"
	var v = Game.dv("start_hp")
	Game.diff = "normal"
	return report("misc", kept == "hard" and v == 5, "?diff=hard with an easy save -> %s; dv with an unknown diff -> %s" % [kept, str(v)])

# NULL in co-op: both players are targeted in turns, the partner is aimed at ahead, and the guest's puppet of NULL hurts (body, blasts)
func t_nullcoop() -> bool:
	var m := null_setup()
	var room := m.room
	var p = m.player
	var boss = room.boss
	var r2 := RemotePlayer.new(room)
	room.remote_players.append(r2)
	room.add_child(r2)
	Controls.script_input = {}
	var picks := [0, 0]
	var last = null
	for f in range(3600):
		p.inv = 999.0
		p.hp = p.max_hp
		r2.report(200.0, floor_y(room, 205.0, 7), 0.0, 0.0, 1.0, room.time)
		r2.follow(room.time)
		m.tick(Game.STEP)
		if boss.active and boss.target != last:
			last = boss.target
			picks[1 if last == r2 else 0] += 1
	Net.rtt = 0.1
	r2.vx = 100.0
	var ap: Vector2 = boss.aim_point(r2)
	var lead_ok: bool = ap.x > 205.0 + 20.0
	# the guest's puppet
	var pup = NetClasses.make(5, room)
	var f0: Array = boss.net_fields()
	pup.net_apply(f0)
	var armed: bool = not pup.passive and not pup.harmboxes().is_empty()
	# the blasts: a harm zone on the host (the guest checks its own body against it); a direct hurt of the partner becomes one too
	room.mode = "host"
	room.zones.clear()
	boss.dmarks = [Vector2(r2.x + 5, r2.y + 5)]
	boss.blow_dangling()
	var zone_blast: bool = room.zones.size() == 1 and room.zones[0].kind == "c"
	r2.hurt(2, r2.x)
	var zone_net: bool = room.zones.size() == 2 and room.zones[1].dmg == 2
	# the guest's side: a zone hurts once, and is gone after 0.25 s (it used to stay forever)
	room.mode = "guest"
	room.zones = [{"id": 900, "kind": "c", "x": p.x + 5, "y": p.y + 5, "a": 20.0, "b": 0.0, "dmg": 1, "until": 0.25}]
	room.zones_hit.clear()
	p.inv = 0.0
	p.dead = false
	var hp0: int = p.hp
	room.step_guest(Game.STEP)
	var blast_hurt: bool = p.hp == hp0 - 1
	for f in range(40):                  # (the hurt's hitstop holds the room for a few frames)
		room.step_guest(Game.STEP)
	var expired: bool = room.zones.is_empty()
	room.mode = "solo"
	pup.free()
	return report("nullcoop", picks[0] >= 2 and picks[1] >= 2 and lead_ok and armed and zone_blast and zone_net and blast_hurt and expired, "targets P1 %d P2 %d, lead x %.0f (from 205), puppet armed %s, blast zone %s, direct hurt -> zone %s, guest hurt by the zone %s, zone expired %s" % [picks[0], picks[1], ap.x, armed, zone_blast, zone_net, blast_hurt, expired])

# the guest's page (as the JS game): a creature my swipe kills cannot hurt me while the host's word is on its way; on a bad
# line a creature whose place is only guessed does not hurt either; every stomp is its own attack
func t_guestpred() -> bool:
	Game.diff = "normal"
	var room := new_room()
	clear_ents(room)
	room.cam.x = 0.0
	var p = room.player
	for i in range(30):
		step_with(room, {})
	room.mode = "guest"
	var b := add_bug(room, p.x + p.w + 6.0, 199, -1)
	b.hp = 1
	b.speed = 0.0
	b.nid = 7
	var sent: Array = []
	room.net_hit.connect(func(nid, how, dmg, dx, dy, atk): sent.append([how, atk]))
	p.face = 1.0
	step_with(room, {"attack": true})
	for f in range(6):
		step_with(room, {})
	var predicted: bool = room.pred_dead(b)
	b.x = p.x                           # the (not yet removed) creature now overlaps the guest
	b.y = p.y
	var hp0: int = p.hp
	for f in range(10):
		step_with(room, {})
	var safe: bool = p.hp == hp0
	# lenient: a guessed creature does not hurt
	var b2 := add_bug(room, p.x, p.y, -1)
	b2.speed = 0.0
	b2.set_meta("ex", true)
	room.lenient = true
	p.inv = 0.0
	for f in range(10):
		step_with(room, {})
	var lenient_ok: bool = p.hp == hp0
	room.lenient = false
	for f in range(10):
		step_with(room, {})
	var strict_hurts: bool = p.hp < hp0
	# two stomps: two different attack numbers
	var n0: int = room.stomp_n
	room._hit_entity(b2, 1, 0.0, 1.0, "stomp", b2)
	room._hit_entity(b2, 1, 0.0, 1.0, "stomp", b2)
	var stomps: Array = sent.filter(func(x): return x[0] == "stomp")
	var stomp_ok: bool = room.stomp_n == n0 + 2 and stomps.size() == 2 and stomps[0][1] != stomps[1][1]
	Controls.script_input = null
	return report("guestpred", predicted and safe and lenient_ok and strict_hurts and stomp_ok, "kill predicted %s, safe from it %s, guessed creature forgiven %s (hurts when not lenient %s), stomp ids %s" % [predicted, safe, lenient_ok, strict_hurts, str(stomps)])

# The JS game's netfields idea, for Godot. Every creature of every room is played on the host with a bot beside it, and every
# frame its snapshot record goes into a puppet exactly as on the guest (NetClasses.record / apply). What the guest's combat
# reads from the puppet must match the original: harm and hurt boxes, passive, dmg, dashable, stompable, no_hit (and for a
# boss active, dying). A mismatch is a field the guest needs that is not sent: NULL's `passive` once was, so its copy on the
# phone hurt nobody.
func _boxes(arr: Array) -> Array:
	var out: Array = []
	for b in arr:
		out.append([roundi(b.x), roundi(b.y), roundi(b.w), roundi(b.h)])
	return out

func _near_boxes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		for k in range(4):
			if absi(int(a[i][k]) - int(b[i][k])) > 1:
				return false
	return true

func _parity_diff(e, q) -> String:
	for f in ["passive", "dmg", "dashable", "stompable", "no_hit"]:
		if e.get(f) != q.get(f):
			return f
	if e.get("is_boss"):
		for f in ["active", "dying", "phase"]:
			if e.get(f) != q.get(f):
				return f
	if not _near_boxes(_boxes(e.harmboxes()), _boxes(q.harmboxes())):
		return "harmboxes"
	if not _near_boxes(_boxes(e.hurtboxes()), _boxes(q.hurtboxes())):
		return "hurtboxes"
	return ""

func t_parity() -> bool:
	var m := new_manager()
	var frames := {}
	var bad := {}
	var keys := ["right", "jump", "attack", "dash", "left", "down", "up"]
	var rooms: Array = Game.rooms_meta.rooms.keys()
	rooms.sort()
	for rid in rooms:
		Game.flags = {}
		Game.diff = "normal"
		m.swap_to(rid, null, null, true)
		var room := m.room
		var p = m.player
		var pups := {}
		var visits: Array = room.ents.filter(func(e): return not e.dead)
		var total := 1500 if room.boss != null else maxi(300, visits.size() * 120)
		for i in range(total):
			var inp := {"right": (i >> 6) % 2 == 0}
			inp[keys[(i >> 4) % keys.size()]] = true
			Controls.script_input = inp
			p.inv = 99.0
			p.hp = p.max_hp
			if room.boss == null and not visits.is_empty() and i % 120 == 0:
				var e0 = visits[(i / 120) % visits.size()]
				if not e0.dead:
					p.x = e0.x - 24.0
					p.y = e0.y - 6.0
					p.vx = 0.0
					p.vy = 0.0
			if room.boss != null and i == 700 and room.boss.active:
				room.boss.hpf = room.boss.max_hp / 2.0 - 0.5         # on to phase 2
				room.boss.hit(1, 0.0, 0.0, "swipe", room.boss)
			m.tick(Game.STEP)
			for e in room.ents:
				if e.dead or NetClasses.cls_of(e) < 0:
					continue
				var key: String = "%s:%s" % [rid, NetClasses.NAMES[NetClasses.cls_of(e)]]
				var q = pups.get(e.get_instance_id())
				if q == null:
					q = NetClasses.make(NetClasses.cls_of(e), room)
					pups[e.get_instance_id()] = q
				NetClasses.apply(q, JSON.parse_string(JSON.stringify(NetClasses.record(e))))
				q.x = e.x
				q.y = e.y
				frames[key] = int(frames.get(key, 0)) + 1
				var d := _parity_diff(e, q)
				if d != "" and OS.get_environment("PARITY_DEBUG") != "" and int(bad.get(key + ":" + d, 0)) < 3:
					print("PARITY %s %s st=%s mode=%s host=%s pup=%s dmg %s/%s" % [key, d, e.get("st"), e.get("cur").mode if e.get("cur") != null else "", str(_boxes(e.harmboxes())), str(_boxes(q.harmboxes())), e.dmg, q.dmg])
				if d != "":
					var bk: String = key + ":" + d
					bad[bk] = int(bad.get(bk, 0)) + 1
				q.t += Game.STEP                  # (then the guest's own frame: the next record overwrites what it guessed)
				if q.has_method("puppet_tick"):
					q.puppet_tick(Game.STEP)
		for q in pups.values():
			q.free()
	Controls.script_input = null
	var fails: Array = []
	for bk in bad:
		var parts: PackedStringArray = String(bk).split(":")
		var n: int = int(frames.get(parts[0] + ":" + parts[1], 1))
		if float(bad[bk]) / n > 0.01:
			fails.append("%s %d/%d" % [bk, bad[bk], n])
	return report("parity", fails.is_empty() and frames.size() >= 5, "checked %s | over 1 %%: %s | all mismatches: %s" % [str(frames), str(fails), str(bad)])

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

# The dead boss is freed by the room (queue_free) before the next frame: the reward must still run out, set the flag and open the door
func t_bossfree() -> bool:
	var m := null_setup()
	var room := m.room
	var p = m.player
	var freed := false
	var state := ""
	for f in range(14000):
		p.inv = 999.0
		p.hp = p.max_hp
		if room.boss != null and is_instance_valid(room.boss) and room.boss.active and not room.boss.dying:
			room.attacker = p
			p.x = room.boss.x - 30.0
			Controls.script_input = {"attack": f % 6 < 3}
		m.tick(Game.STEP)
		if not freed and is_instance_valid(room.boss) and room.boss.dead:
			room.boss.free()                 # what the frame loop does with the dead boss before the next tick (the tests tick without frames)
			freed = true
		state = String(room.fight.state)
		if state == "done":
			break
	room.update_doors()
	var door_open: bool = room.grid.tile(room.w, 8) == TileGrid.E
	var ok: bool = freed and state == "done" and Game.flag("boss:NULL") and not p.frozen and door_open
	var info := "boss freed %s, fight %s (want done), flag %s, player frozen %s, door open %s" % [freed, state, Game.flag("boss:NULL"), p.frozen, door_open]
	Controls.script_input = null
	Game.tools.bash = false
	Game.flags = {}
	return report("bossfree", ok, info)

# the temporary pause-menu "Skip boss": offered only in a fight, ends it with the normal reward (flag, ability, door)
func t_skipboss() -> bool:
	var m := null_setup()
	var room := m.room
	var p = m.player
	var pause := PauseMenu.new()
	pause.manager = m
	var before: bool = pause.can_skip_boss()
	for f in range(600):
		p.inv = 999.0
		m.tick(Game.STEP)
		if room.fight.state == "active":
			break
	var during: bool = pause.can_skip_boss()
	var did: bool = room.skip_boss()
	var state := ""
	for f in range(900):
		p.inv = 999.0
		m.tick(Game.STEP)
		state = String(room.fight.state)
		if state == "done":
			break
	room.update_doors()
	var door_open: bool = room.grid.tile(room.w, 8) == TileGrid.E
	var after: bool = pause.can_skip_boss()
	var ok: bool = not before and during and did and state == "done" and Game.flag("boss:NULL") and Game.flag("ability:bash") and door_open and not after
	var info := "offered before the fight %s (want false), in it %s, skipped %s, fight %s, flag %s, door %s, offered after %s (want false)" % [before, during, did, state, Game.flag("boss:NULL"), door_open, after]
	pause.free()
	Game.tools.bash = false
	Game.flags = {}
	return report("skipboss", ok, info)

# MV4-01: N/S doors, `sets` doors, the east-wall trap, terminal travel
func t_nsdoors() -> bool:
	Game.persist = false
	Game.flags = {}
	var res := {"ok": true, "info": ""}          # (a lambda copies plain locals: results go through a dictionary)
	var chk := func(label: String, cond: bool) -> void:
		if not cond:
			res.ok = false
			res.info += " BAD:" + label
	# 1. the grid
	var r10 := new_room("H10")
	chk.call("H10 N open", r10.grid.tile(51, -1) == TileGrid.E)
	chk.call("H10 N wall", r10.grid.tile(20, -1) == TileGrid.SOLID)
	chk.call("H10 S door", r10.grid.tile(41, 16) == TileGrid.E)
	chk.call("H10 pit", r10.grid.tile(20, 16) == TileGrid.E)
	chk.call("H10 E door", r10.grid.tile(64, 10) == TileGrid.E)
	chk.call("H10 E wall", r10.grid.tile(64, 5) == TileGrid.SOLID)
	r10.queue_free()
	var r3 := new_room("H03")
	chk.call("H03 S door does not open the east wall", r3.grid.tile(32, 15) == TileGrid.SOLID)
	r3.queue_free()
	var r11 := new_room("H11")
	chk.call("H11 hatch closed", r11.grid.tile(51, 16) == TileGrid.SOLID)
	Game.flags["hatch:H10N"] = true
	r11.update_doors()
	chk.call("H11 hatch open", r11.grid.tile(51, 16) == TileGrid.E)
	r11.queue_free()
	Game.flags = {}
	# 2. up through a hatch (sudo)
	Game.tools.sudo = true
	var m := new_manager()
	m.swap_to("H10")
	var p = m.player
	p.x = 51 * 16 + 3.0
	p.y = 6 * 16 - 10.0
	p.vx = 0.0
	p.vy = 0.0
	for f in range(20):
		m.tick(Game.STEP)                      # (land on the ledge first)
	for f in range(120):
		Controls.script_input = {"jump": f <= 12 or f >= 20}
		m.tick(Game.STEP)
		if m.room.id == "H11" and not m.trans.on:
			break
	Controls.script_input = {}
	chk.call("up: in H11", m.room.id == "H11")
	chk.call("up: hatch flag", Game.flag("hatch:H10N"))
	chk.call("up: x", m.player.x >= 50 * 16 - 10 and m.player.x <= 54 * 16)
	for f in range(90):
		Controls.script_input = {"left": true, "jump": true}            # (jump stays held, as a player would; the push upward lands you in the hole: step onto the lip beside it to stay up)
		m.tick(Game.STEP)
	Controls.script_input = {}
	chk.call("up: lands", m.player.on_ground and m.player.y + m.player.h <= 16 * 16)
	res.info += " up y=%.0f" % m.player.y
	# 3. down through the hatch
	m.player.x = 51 * 16 + 3.0
	m.player.y = 14 * 16.0
	m.player.vx = 0.0
	m.player.vy = 0.0
	var first_y := 999.0
	for f in range(60):
		m.tick(Game.STEP)
		if m.room.id == "H10" and not m.trans.on:
			first_y = m.player.y
			break
	chk.call("down: in H10", m.room.id == "H10")
	chk.call("down: arrives at the top", first_y < 32.0)
	res.info += " first_y=%.0f" % first_y
	# 4. the floor drop
	Game.flags = {}
	m.swap_to("H10")
	m.player.x = 41 * 16 + 3.0
	m.player.y = 13 * 16 - 10.0
	m.player.vx = 0.0
	m.player.vy = 0.0
	for f in range(120):
		Controls.script_input = {"down": f < 4, "jump": f == 1}
		m.tick(Game.STEP)
		if m.room.id == "H04" and not m.trans.on:
			break
	Controls.script_input = {}
	chk.call("drop: in H04", m.room.id == "H04")
	chk.call("drop: flag", Game.flag("hatch:H10S"))
	m.room.update_doors()
	var hn = m.room.grid.door_at("N", 107)
	chk.call("drop: H04 N open", hn != null and hn.open)
	# 5. travel
	Game.flags = {"bench:R08": true, "bench:H03": true, "bench:D03": true}
	m.swap_to("D03")
	var bm := BenchMenu.new()
	bm.manager = m
	chk.call("D03 has no Travel", not ("Travel" in bm.main_options()))
	m.swap_to("R08")
	chk.call("R08 targets", m.travel_targets() == ["H03"])
	chk.call("R08 has Travel", "Travel" in bm.main_options())
	bm.free()
	Game.flags = {}
	Game.tools.sudo = false
	m.queue_free()
	Controls.script_input = null
	return report("nsdoors", res.ok, res.info)

# MV4-02: dead code, firewall bricks, bulkheads, Room.blast
func t_tiles4() -> bool:
	Game.persist = false
	Game.flags = {}
	var res := {"ok": true, "info": ""}          # (a lambda copies plain locals: results go through a dictionary)
	var chk := func(label: String, cond: bool) -> void:
		if not cond:
			res.ok = false
			res.info += " BAD:" + label
	var r3 := new_room("H03")
	chk.call("dead code is walkable", not r3.grid.solid(31, 5))
	chk.call("dead code has a TileMap cell", r3.view.tiles.get_cell_source_id(Vector2i(31, 5)) != -1)
	r3.queue_free()
	var r12 := new_room("H12")
	chk.call("firewall brick solid", r12.grid.solid(23, 8))
	r12.queue_free()
	var r5 := new_room("H05")
	chk.call("bulkhead solid", r5.grid.solid(44, 11))
	r5.blast(44 * 16 + 8, 11 * 16 + 8, 34)
	chk.call("blast opens it", not r5.grid.solid(44, 11) and Game.flag("crack:H05:44:11"))
	chk.call("blast leaves the wall above", r5.grid.solid(44, 6))
	r5.queue_free()
	var r5b := new_room("H05")
	chk.call("stays open after a rebuild", not r5b.grid.solid(44, 11))
	r5b.queue_free()
	Game.flags = {}
	# walking into the dead code reveals it, and the door behind it leads on
	var m := new_manager()
	m.swap_to("H03")
	var p = m.player
	p.x = 31 * 16 - 14.0
	p.y = 8 * 16 - 10.0
	p.vx = 0.0
	p.vy = 0.0
	var found := -1
	for f in range(120):
		Controls.script_input = {"right": true}
		m.tick(Game.STEP)
		if found < 0 and Game.flag("dead:H03"):
			found = f
		if m.room.id == "H13" and not m.trans.on:
			break
	Controls.script_input = {}
	chk.call("reveal within 30 frames", found >= 0 and found <= 30)
	chk.call("walks on into H13", m.room.id == "H13")
	res.info += " found at frame %d" % found
	m.queue_free()
	# a room built with the flag has no wall drawn over its dead code
	var r3b := new_room("H03")
	chk.call("revealed room draws no wall", r3b.view.tiles.get_cell_source_id(Vector2i(31, 5)) == -1)
	r3b.queue_free()
	Game.flags = {}
	return report("tiles4", res.ok, res.info)

func _dry_room(room_id: String) -> Room:
	var r := new_room(room_id)
	for e in r.ents:
		e.queue_free()
	r.ents.clear()
	r.player.inv = 0.0
	return r

# MV4-03: the three flood levels, the water follows them, the valve
func t_flood() -> bool:
	Game.persist = false
	Game.flags = {}
	var res := {"ok": true, "info": ""}
	var chk := func(label: String, cond: bool) -> void:
		if not cond:
			res.ok = false
			res.info += " BAD:" + label
	chk.call("level 2", Game.heap_flood() == 2)
	Game.flags["gate:H07:catch"] = true
	chk.call("level 1", Game.heap_flood() == 1)
	Game.flags["boss:LEAK"] = true
	chk.call("level 0", Game.heap_flood() == 0)
	Game.flags = {}
	var r := _dry_room("H03")
	chk.call("H03 water at level 2", r.liquid_y == 23 * 16 + 6.0)
	var p = r.player
	p.x = 20 * 16.0
	p.y = 30 * 16.0
	p.vx = 0.0
	p.vy = 0.0
	var hp0: int = p.hp
	step_with(r, {})
	chk.call("the water hurts and the body comes back dry", p.hp == hp0 - 1 and p.y + 10 < r.liquid_y)
	chk.call("E2 closed at level 2", r.grid.tile(32, 37) == TileGrid.SOLID)
	Game.flags["gate:H07:catch"] = true
	for f in range(120):
		p.inv = 5.0
		step_with(r, {})
	chk.call("draining after 2 s", r.liquid_y > 374.0 and r.liquid_y < 726.0)
	chk.call("E2 open at level 1", r.grid.tile(32, 37) == TileGrid.E)
	for f in range(60 * 20):
		p.inv = 5.0
		step_with(r, {})
	chk.call("level 1 water after 20 s", r.liquid_y == 45 * 16 + 6.0)
	res.info += " liquid_y=%.0f" % r.liquid_y
	r.queue_free()
	Game.flags = {}
	# the valve
	var v := _dry_room("H07")
	v.press_switch(0)
	chk.call("valve sets the flag", Game.flag("gate:H07:catch") and Game.heap_flood() == 1)
	v.queue_free()
	Game.flags = {}
	return report("flood", res.ok, res.info)

# MV4-03: H06's water rises after the players
func t_rise() -> bool:
	Game.persist = false
	Game.flags = {"gate:H07:catch": true}
	var res := {"ok": true, "info": ""}
	var chk := func(label: String, cond: bool) -> void:
		if not cond:
			res.ok = false
			res.info += " BAD:" + label
	var r := _dry_room("H06")
	var p = r.player
	chk.call("level 1 start", r.liquid_y == 59 * 16 + 6.0 and not r.rise_on)
	p.x = 10 * 16.0
	p.y = 40 * 16.0
	p.vx = 0.0
	p.vy = 0.0
	step_with(r, {})
	chk.call("rise starts above the trigger", r.rise_on)
	for f in range(120):
		p.inv = 5.0
		p.y = 40 * 16.0
		p.vy = 0.0
		step_with(r, {})
	chk.call("water climbs", r.liquid_y < 59 * 16 + 6.0 - 30.0)
	var before: float = r.liquid_y
	p.inv = 0.0
	p.y = r.liquid_y + 2.0
	p.x = 10 * 16.0
	p.vy = 0.0
	step_with(r, {})
	chk.call("a slip pushes the tide back", r.liquid_y > before + 60.0)
	res.info += " before %.0f after %.0f" % [before, r.liquid_y]
	r.queue_free()
	Game.flags = {"boss:LEAK": true, "gate:H07:catch": true}
	var r0 := _dry_room("H06")
	r0.player.y = 10 * 16.0
	step_with(r0, {})
	chk.call("level 0 is dry and does not rise", r0.liquid_y == null and not r0.rise_on)
	r0.queue_free()
	Game.flags = {}
	return report("rise", res.ok, res.info)

# MV4-04: --verbose shows the dead code near you; restart: always fills the meter after a bench respawn
func t_plugins4() -> bool:
	Game.persist = false
	Game.flags = {"plugin:verbose": true, "plugin:restart_always": true}
	var res := {"ok": true, "info": ""}
	var chk := func(label: String, cond: bool) -> void:
		if not cond:
			res.ok = false
			res.info += " BAD:" + label
	Game.equipped = ["restart_always"]
	var m := new_manager()
	m.respawn(false)
	chk.call("meter full with restart: always", m.player.meter == 99.0)
	Game.equipped = []
	m.respawn(false)
	chk.call("meter empty without it", m.player.meter == 0.0)
	m.queue_free()
	var r := new_room("H03")
	r.player.x = 28 * 16.0
	r.player.y = 8 * 16 - 10.0
	Game.equipped = ["verbose"]
	var cells: Array = r.verbose_cells()
	var want := [[31, 4], [31, 5], [31, 6], [31, 7]]
	chk.call("verbose lists the dead cells", cells == want)
	res.info += " cells=" + str(cells)
	Game.equipped = []
	chk.call("nothing without it", r.verbose_cells().is_empty())
	Game.equipped = ["verbose"]
	Game.flags["dead:H03"] = true
	chk.call("nothing once revealed", r.verbose_cells().is_empty())
	r.queue_free()
	Game.equipped = []
	Game.flags = {}
	return report("plugins4", res.ok, res.info)
