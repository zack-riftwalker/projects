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
		"focus": return t_focus()
		"dashhurt": return t_dashhurt()
		"platform": return t_platform()
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

func dash_into_bug(diff_name: String) -> Array:
	Game.diff = diff_name
	Game.tools.bash = true
	var room := new_room()
	clear_ents(room)
	room.cam.x = 0.0
	var p = room.player
	for i in range(30):
		step_with(room, {})
	var b := add_bug(room, p.x + p.w + 20.0, 199, -1)
	b.hp = 3
	b.speed = 0.0
	b.kb = 0.0                      # it stays put, so the dash carries Clawd clean through it
	var hp0: int = p.hp
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
	var ok: bool = n[0] == 2 and n[2] == n[1] - 1 and e[0] == 2 and e[2] == e[1]
	return report("dashhurt", ok, "normal: bug hp %d, player %d -> %d | easy: bug hp %d, player %d -> %d" % [n[0], n[1], n[2], e[0], e[1], e[2]])
