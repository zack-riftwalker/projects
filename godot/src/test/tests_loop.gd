extends Tests5a
class_name TestsLoop
# INFINITE LOOP v3 (docs/metroidvania/18-loop-build.md): loop3 grows with every milestone; fightsim with BOSS=T10.

const NAMESL := ["loop3"]

func run(name: String):
	match name:
		"loop3": return await t_loop3()
		"fightsim": return await loop_fightsim()
	return await super.run(name)

func loop_setup() -> void:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	Game.tools = {"bash": true, "catch": true, "sudo": true, "agents": false, "opus": false, "curl": true, "ssh": false, "breakpoint": true}

# a T10 with no fight in the way (the trigger far off, the fake loop already seen) and no creatures
func loop_room(fake := false) -> Room:
	var md: Dictionary = Game.rooms_meta.rooms.T10
	var trig: float = float(md.boss.trigger_x)
	md.boss["trigger_x"] = 1e9
	if not fake:
		Game.flags["intro:LOOP"] = true
	var r := new_room("T10")
	md.boss["trigger_x"] = trig
	return r

func plat_rect(m: Dictionary) -> Rect2:
	return Rect2(float(m.x), float(m.y), float(m.w), 6.0)

func tile_rect(a: int, b: int, row: int) -> Rect2:
	return Rect2(float(a * 16), float(row * 16), float((b - a + 1) * 16), 6.0)

# a scripted hop like race_hop, with a second jump (sudo) at frame j2 (-1: none)
func loop_hop(r: Room, from: Vector2, target: Rect2, hold: int, dash_at: int, up: bool, j2: int) -> bool:
	var p = r.player
	p.x = from.x - p.w * 0.5
	p.y = from.y - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.inv = 99.0
	p.zip = -1
	var dir := "right" if target.get_center().x > from.x else "left"
	for f in range(130):
		var keys := {dir: true}
		if f < hold or (j2 >= 0 and f >= j2 and f < j2 + 12):
			keys["jump"] = true
		if dash_at >= 0 and f == dash_at:
			keys["dash"] = true
			if up:
				keys["up"] = true
		step_keys(r, keys)
		p.inv = 99.0
		if p.on_ground and f > 4 and absf(p.y + p.h - target.position.y) < 2.5 and p.x + p.w * 0.5 >= target.position.x and p.x + p.w * 0.5 <= target.end.x:
			return true
	return false

func loop_reach(r: Room, from: Vector2, target: Rect2, sudo: bool) -> bool:
	Game.tools.sudo = sudo
	r.player.tools = Game.tools
	for hold in [10, 14, 18, 22, 26, 30, 40]:
		for dash_at in [-1, 6, 12, 18, 24, 30, 36]:
			for up in [false, true]:
				if up and dash_at < 0:
					continue
				for j2 in ([-1, 16, 22, 28, 34] if sudo else [-1]):
					if loop_hop(r, from, target, hold, dash_at, up, j2):
						Game.tools.sudo = true
						return true
	Game.tools.sudo = true
	return false

# a curl from `from` (feet) to the GET ring above it, then a hop to the target
func loop_curl(r: Room, from: Vector2, target: Rect2) -> bool:
	var p = r.player
	for dash_after in [-1, 2, 6, 10]:
		for toward in ["", "left", "right"]:
			for jump_after in [-1, 0, 4]:
				p.x = from.x - p.w * 0.5
				p.y = from.y - p.h
				p.vx = 0.0
				p.vy = 0.0
				p.zip = -1
				var arrived := -1
				var was_zip := false
				for f in range(140):
					var keys := {}
					if f == 0:
						keys["special"] = true
					if p.zip >= 0:
						was_zip = true
					if was_zip and p.zip < 0 and arrived < 0:
						arrived = f
					if arrived >= 0:
						if toward != "":
							keys[toward] = true
						if jump_after >= 0 and f >= arrived + jump_after and f < arrived + jump_after + 14:
							keys["jump"] = true
						if dash_after >= 0 and f == arrived + dash_after:
							keys["dash"] = true
							keys["up"] = true
					step_keys(r, keys)
					p.inv = 99.0
					if p.on_ground and absf(p.y + p.h - target.position.y) < 2.5 and p.x + p.w * 0.5 >= target.position.x and p.x + p.w * 0.5 <= target.end.x:
						return true
	return false

func t_loop3() -> bool:
	loop_setup()
	var res := checker()
	var info := ""
	# --- M1 -------------------------------------------------------------------------------------------------------------
	# 1. rooms.json: 24 x 32 (it grows upward only), doors on rows 25..28, the hall named, the free camera
	var md: Dictionary = Game.rooms_meta.rooms.T10
	if int(md.size[0]) != 24 or int(md.size[1]) != 32 or int(md.origin[0]) != 1230 or int(md.origin[1]) != -232 or String(md.get("hall", "")) != "loop" or String(md.boss.get("cam", "")) != "free":
		fail(res, "T10 size %s origin %s hall %s cam %s" % [str(md.size), str(md.origin), str(md.get("hall", "")), str(md.boss.get("cam", ""))])
	for d in md.doors:
		if int(d.a) != 25 or int(d.b) != 28:
			fail(res, "door %s rows %d..%d, want 25..28" % [d.id, int(d.a), int(d.b)])
	var r := loop_room()
	if r.pw != 384 or r.ph != 512 or r.shaft == null:
		fail(res, "T10 is %d x %d, shaft %s" % [r.pw, r.ph, str(r.shaft)])
		r.queue_free()
		return report("loop3", false, res.info)
	var hl: LoopHall = r.shaft
	if r.grid.door_at("W", 26) == null or r.grid.door_at("E", 26) == null or r.grid.door_at("W", 8) != null:
		fail(res, "the doors are not on rows 25..28")
	for c in [0, 6, 12, 17, 23]:
		if not r.grid.solid(c, 29) or not r.grid.solid(c, 31) or not r.grid.solid(c, 0):
			fail(res, "the floor (rows 29..31) or the ceiling is not solid at column %d" % c)
	# 2. the pieces: one-way ledges, the hall's low ledges, 8 gear teeth, the gantry
	for lg in [[9, 14, 21, "M"], [2, 5, 13, "L2"], [18, 21, 13, "R2"], [10, 13, 9, "TOP"], [3, 5, 25, "L1"], [18, 20, 25, "R1"]]:
		for tx in range(int(lg[0]), int(lg[1]) + 1):
			if r.grid.tile(tx, int(lg[2])) != TileGrid.ONEWAY:
				fail(res, "%s is not one-way at column %d" % [lg[3], tx])
				break
	var teeth := r.plats.filter(func(m): return m.has("lgear"))
	var gant := r.plats.filter(func(m): return m.has("gantry"))
	if teeth.size() != 8 or gant.size() != 1 or absf(float(gant[0].y) - 64.0) > 0.01 or absf(float(gant[0].x) - 128.0) > 0.01:
		fail(res, "%d teeth, %d gantry" % [teeth.size(), gant.size()])
	# 3. routes (the real physics, step_keys): with bash, jump, dash, and sudo where it is needed. The gears are held still with a tooth on top
	for e in r.ents:
		if not e.get("is_boss"):
			e.queue_free()
	r.ents = r.ents.filter(func(e): return e.get("is_boss"))
	hl.gear_dir = 0
	hl.gear_s0 = 0.0
	hl.move_parts()
	var gl_top := plat_rect(hl.gears_p[0][0])
	var gr_top := plat_rect(hl.gears_p[1][0])
	var gl_side := plat_rect(hl.gears_p[0][1])          # (the tooth at 3 o'clock: the step toward the middle)
	var gr_side := plat_rect(hl.gears_p[1][3])
	var m_r := tile_rect(9, 14, 21)
	var routes := [["floor to L1", Vector2(24.0, 464.0), tile_rect(3, 5, 25)], ["floor to R1", Vector2(360.0, 464.0), tile_rect(18, 20, 25)],
		["L1 to M", Vector2(88.0, 400.0), m_r], ["R1 to M", Vector2(296.0, 400.0), m_r],
		["M to the left gear", Vector2(152.0, 336.0), gl_side], ["M to the right gear", Vector2(232.0, 336.0), gr_side],
		["left gear to L2", Vector2(gl_top.get_center().x, gl_top.position.y), tile_rect(2, 5, 13)], ["right gear to R2", Vector2(gr_top.get_center().x, gr_top.position.y), tile_rect(18, 21, 13)],
		["L2 to TOP", Vector2(88.0, 208.0), tile_rect(10, 13, 9)], ["R2 to TOP", Vector2(296.0, 208.0), tile_rect(10, 13, 9)]]
	var need_sudo: Array = []
	for rt in routes:
		var from: Vector2 = rt[1]
		if loop_reach(r, from, rt[2], false):
			continue
		if loop_reach(r, from, rt[2], true):
			need_sudo.append(rt[0])
		else:
			fail(res, "%s is out of reach (even with sudo)" % rt[0])
	# the side tooth to the top tooth of the same gear (riding: wait for the tick); and TOP to the gantry: sudo, or curl to a GET ring
	var gt := plat_rect(hl.gantry_p)
	if not loop_reach(r, Vector2(176.0, 144.0), gt, true) and not loop_curl(r, Vector2(176.0, 144.0), gt):
		fail(res, "TOP to the gantry is out of reach (sudo and curl)")
	info += "routes ok, sudo needed for %s; " % (", ".join(need_sudo) if not need_sudo.is_empty() else "none")
	# 4. the gears turn one step (45 degrees) per tick, clockwise; a flip at any moment is continuous (the teeth never jump)
	hl.gear_dir = 1
	hl.gear_s0 = 0.0
	hl.gear_k0 = 0.0
	r.time = 10.0 * r.tick_len() + 0.5 * r.tick_len()
	var s1 := hl.gear_steps(r.time)
	if absf(s1 - 11.0) > 0.001:
		fail(res, "gear steps %.3f after 10.5 ticks, want 11 (a step is made in the first 0.3 of each tick)" % s1)
	var before := hl.tooth_pos(0, 0, r.time + 0.01)
	r.time += 0.01
	hl.flip_gears(r.time)
	if hl.tooth_pos(0, 0, r.time).distance_to(before) > 0.01 or hl.gear_dir != -1:
		fail(res, "a flip moves the teeth")
	r.time += r.tick_len()
	if absf(hl.gear_steps(r.time) - 10.0) > 0.001:
		fail(res, "after a flip the gear does not turn back (%.3f)" % hl.gear_steps(r.time))
	# 5. the phases: phase 2 the low ledges slide into the walls (0.6 s, the room side first) and the gantry swings; phase 3 the pit and the seam
	hl.ph = 2
	hl.p2_t0 = 20.0
	r.time = 20.25
	hl.apply()
	if r.grid.tile(5, 25) != TileGrid.E or r.grid.tile(3, 25) != TileGrid.ONEWAY or r.grid.tile(18, 25) != TileGrid.E or r.grid.tile(20, 25) != TileGrid.ONEWAY:
		fail(res, "the low ledges do not retract from the room side (0.25 s)")
	r.time = 20.7
	hl.apply()
	for tx in [3, 4, 5, 18, 19, 20]:
		if r.grid.tile(tx, 25) != TileGrid.E:
			fail(res, "a low ledge still stands at column %d after 0.7 s of phase 2" % tx)
			break
	var per := LoopHall.SWING_TICKS * r.tick_len()
	var off := hl.gantry_off(20.0 + per * 1.25)
	if absf(off.x - 32.0) > 0.5 or off.y > -1.0:
		fail(res, "the gantry swings %.1f / %.1f at a quarter period (want 32 out, a little up)" % [off.x, off.y])
	hl.ph = 3
	hl.p3_t0 = 30.0
	r.time = 30.4
	hl.apply()
	if hl.cracking(r.time) < 0.0 or r.grid.tile(10, 29) != TileGrid.SOLID or hl.pit_open(r.time):
		fail(res, "phase 3 at 0.4 s: the floor should be cracking, still solid")
	r.time = 30.85
	hl.apply()
	for c in [6, 11, 17]:
		if r.grid.tile(c, 29) != TileGrid.E or r.grid.tile(c, 31) != TileGrid.E or r.grid.tile(c, 0) != TileGrid.E or r.grid.tile(c, -1) != TileGrid.E:
			fail(res, "the pit / seam is not open at column %d" % c)
	if r.grid.tile(5, 29) != TileGrid.SOLID or r.grid.tile(18, 29) != TileGrid.SOLID or r.grid.tile(5, -1) != TileGrid.SOLID:
		fail(res, "the pit is wider than columns 6..17")
	r.time = 31.5
	hl.apply()
	if r.grid.tile(3, 25) != TileGrid.ONEWAY or r.grid.tile(5, 25) != TileGrid.ONEWAY:
		fail(res, "phase 3: the low ledges are not back")
	# the same state on a copy of the room (what the guest builds from the snapshot)
	var pack := hl.net_pack()
	var r2 := loop_room()
	r2.time = 31.5
	r2.shaft.net_unpack(JSON.parse_string(JSON.stringify(pack)))
	r2.shaft.apply()
	for tx in range(24):
		for ty in [0, 25, 29, 30, 31]:
			if r2.grid.tile(tx, ty) != r.grid.tile(tx, ty):
				fail(res, "the copy differs at %d, %d" % [tx, ty])
				break
	for k in range(10):
		var tq := 31.5 + float(k) * 0.37
		if r2.shaft.tooth_pos(1, 2, tq).distance_to(hl.tooth_pos(1, 2, tq)) > 0.001 or r2.shaft.gantry_off(tq).distance_to(hl.gantry_off(tq)) > 0.001:
			fail(res, "the copy's gears / gantry differ at %.2f" % tq)
			break
	r2.queue_free()
	# 6. phase 3 routes: from each floor side to L1 / R1 to M without the pit; a fall through the pit comes back in at the top and lands on the gantry
	hl.gear_dir = 0
	if not loop_reach(r, Vector2(24.0, 464.0), tile_rect(3, 5, 25), true) or not loop_reach(r, Vector2(360.0, 464.0), tile_rect(18, 20, 25), true):
		fail(res, "phase 3: a floor side cannot reach its low ledge")
	if not loop_reach(r, Vector2(88.0, 400.0), m_r, true):
		fail(res, "phase 3: L1 to M")
	var p = r.player
	p.x = 186.0
	p.y = 470.0
	p.vx = 0.0
	p.vy = 100.0
	var wrapped := false
	var landed := false
	var cam_jump := 0.0
	var last_cy: float = r.cam.y
	for f in range(240):
		var py0: float = p.y
		step_keys(r, {})
		p.inv = 99.0
		if py0 > 400.0 and p.y < 0.0:
			wrapped = true
			cam_jump = absf(r.cam.y - last_cy)
		last_cy = r.cam.y
		if wrapped and p.on_ground:
			landed = absf(p.y + p.h - hl.gantry_p.y) < 2.5
			break
	if not wrapped or not landed or p.dead or p.hp < p.max_hp:
		fail(res, "a fall through the pit: wrapped %s, on the gantry %s, hp %d" % [str(wrapped), str(landed), p.hp])
	if cam_jump < 100.0:
		fail(res, "the camera pans after the wrap (%.0f px in a frame), it should cut" % cam_jump)
	# outside the pit columns nothing wraps; out of the fight there is no pit
	hl.ph = 1
	hl.p3_t0 = LoopHall.NONE_T
	r.time = 40.0
	hl.apply()
	if r.grid.tile(10, 29) != TileGrid.SOLID or r.grid.tile(10, -1) != TileGrid.SOLID:
		fail(res, "the pit stays open after phase 3")
	r.queue_free()
	# 7. the fake loop (first time only): the east door looks open; whoever goes through comes back in by the west door, 4095 -> 4096, the fight starts
	Game.flags.erase("intro:LOOP")
	var md2: Dictionary = Game.rooms_meta.rooms.T10
	var r3 := new_room("T10")
	var h3: LoopHall = r3.shaft
	var p3 = r3.player
	if not h3.fake_on or h3.counter != 4095:
		fail(res, "the fake loop is not armed (counter %d)" % h3.counter)
	p3.x = 60.0
	p3.y = 454.0
	var walked := 0
	for f in range(400):
		step_keys(r3, {"right": true})
		walked = f
		if r3.fight.state != "none":
			break
	if r3.fight.state != "intro" or h3.counter != 4096 or not Game.flag("intro:LOOP") or p3.x > 40.0 or absf(p3.y + p3.h - 464.0) > 0.5 or p3.face != 1:
		fail(res, "after the east door: state %s counter %d flag %s at %.0f, %.0f" % [r3.fight.state, h3.counter, str(Game.flag("intro:LOOP")), p3.x, p3.y])
	if r3.id != "T10":
		fail(res, "the fake loop left the room")
	r3.step(Game.STEP)
	r3.update_doors()
	if r3.grid.door_at("W", 26).open or r3.grid.door_at("E", 26).open:
		fail(res, "the doors are open in the fight")
	info += "fake loop after %d frames; " % walked
	r3.queue_free()
	# ... and after 8 s nobody went: it happens anyway. The second time: no fake loop, the trigger starts the short intro
	Game.flags.erase("intro:LOOP")
	var r4 := new_room("T10")
	r4.player.x = 30.0
	r4.player.y = 454.0
	for f in range(int(8.3 / Game.STEP)):
		step_keys(r4, {})
	if r4.fight.state != "intro" or r4.shaft.counter != 4096:
		fail(res, "8 s in the room did not start it (state %s)" % r4.fight.state)
	r4.queue_free()
	var r5 := new_room("T10")
	if r5.shaft.fake_on:
		fail(res, "the fake loop again the second time")
	r5.queue_free()
	return report("loop3", res.ok, info + res.info)

func loop_fightsim() -> bool:
	print("TEST fightsim SKIP (INFINITE LOOP: the snake comes in M2)")
	return true
