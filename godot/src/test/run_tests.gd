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
	m.swap_to("R08")
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
	Controls.script_input = null
	return report("guard", front_ok and back_ok and pogo_ok, "front blocked=%s | behind hit=%s | pogo hit=%s bounce=%s (hp %d of %d)" % [front_ok, back_ok, pogo_ok, bounced, g.hp, hp0])

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
	var fd := f0.duplicate(true)
	fd[3] = NullBoss.STATES.find("dangling")
	fd[13] = [[roundi((p.x + 5) * 4.0), roundi((p.y + 5) * 4.0)]]
	pup.net_apply(fd)
	var fi := f0.duplicate(true)
	fi[3] = NullBoss.STATES.find("idle")
	fi[13] = []
	p.inv = 0.0
	p.dash_t = 0.0
	var hp0: int = p.hp
	pup.net_apply(fi)
	var blast_hurt: bool = p.hp < hp0
	pup.free()
	return report("nullcoop", picks[0] >= 2 and picks[1] >= 2 and lead_ok and armed and blast_hurt, "targets P1 %d P2 %d, lead x %.0f (from 205), puppet armed %s, blast hurt %s" % [picks[0], picks[1], ap.x, armed, blast_hurt])

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
