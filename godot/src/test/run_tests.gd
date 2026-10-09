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
	room.auto_step = false
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
