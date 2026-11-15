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

# a T10 in the fight (phase 1, the intro skipped), the player at (px, feet py)
func loop_fight(px := 60.0, py := 464.0) -> Room:
	Game.flags["intro:LOOP"] = true
	Game.flags["intro:LOOP_SEEN"] = true
	var r := new_room("T10")
	r.player.x = px
	r.player.y = py - r.player.h
	r._start_intro()
	r.fight.t = 0.0
	r._begin_fight()
	return r

# run the room n frames with the player held (immortal) at its spot
func loop_run(r: Room, n: int, keys := {}) -> void:
	var p = r.player
	for f in range(n):
		p.inv = 99.0
		p.hp = p.max_hp
		step_keys(r, keys)

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
	var fast := OS.get_environment("LOOP_FAST") != ""            # (LOOP_FAST=1: skip the slow route checks while working on later milestones)
	for rt in ([] if fast else routes):
		var from: Vector2 = rt[1]
		if loop_reach(r, from, rt[2], false):
			continue
		if loop_reach(r, from, rt[2], true):
			need_sudo.append(rt[0])
		else:
			fail(res, "%s is out of reach (even with sudo)" % rt[0])
	# the side tooth to the top tooth of the same gear (riding: wait for the tick); and TOP to the gantry: sudo, or curl to a GET ring
	var gt := plat_rect(hl.gantry_p)
	if not fast and not loop_reach(r, Vector2(176.0, 144.0), gt, true) and not loop_curl(r, Vector2(176.0, 144.0), gt):
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
	if not fast and (not loop_reach(r, Vector2(24.0, 464.0), tile_rect(3, 5, 25), true) or not loop_reach(r, Vector2(360.0, 464.0), tile_rect(18, 20, 25), true)):
		fail(res, "phase 3: a floor side cannot reach its low ledge")
	if not fast and not loop_reach(r, Vector2(88.0, 400.0), m_r, true):
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
	# --- M2 -------------------------------------------------------------------------------------------------------------
	# 1. the long intro (first time): the chain comes down at x 228 and coils once round the gantry, the head meets its tail at 3.0 s; the line
	Game.flags["intro:LOOP"] = true
	Game.flags.erase("intro:LOOP_SEEN")
	var ri := new_room("T10")
	ri.player.x = 60.0
	ri.player.y = 454.0
	ri._start_intro()
	var bi: LoopBoss = ri.boss
	var il := bi.intro_len()
	if il < 7.0 or il > 11.0:
		fail(res, "the long intro is %.1f s" % il)
	var cam_up := false
	for f in range(int(1.5 / Game.STEP)):
		step_keys(ri, {})
		if ri.cam.lock != null and float(ri.cam.lock.y) < 20.0:
			cam_up = true
	if bi.mode != "descend" or bi.hy > 101.0 or bi.links.size() != 14:
		fail(res, "intro at 1.5 s: mode %s head y %.0f" % [bi.mode, bi.hy])
	for f in range(int(1.7 / Game.STEP)):
		step_keys(ri, {})
	var tail_gap: float = Vector2(bi.hx, bi.hy).distance_to(bi.tail_point())
	if tail_gap > 30.0 or Vector2(bi.hx, bi.hy).distance_to(LoopBoss.COIL_C) > LoopBoss.COIL_RR + 1.0:
		fail(res, "after the descent the head is %.0f px from its tail, %.0f from the gantry" % [tail_gap, Vector2(bi.hx, bi.hy).distance_to(LoopBoss.COIL_C)])
	for f in range(int(0.4 / Game.STEP)):
		step_keys(ri, {})
	if bi.say_k != 1 or not cam_up:
		fail(res, "the intro line %d, the camera looked up %s" % [bi.say_k, str(cam_up)])
	if not bi.touch_boxes().is_empty() or not bi.harmboxes().is_empty():
		fail(res, "the body hurts in the intro")
	for f in range(int((il - 3.6 + 0.3) / Game.STEP)):
		step_keys(ri, {})
	if ri.fight.state != "active" or not bi.active or bi.mode != "swim" or ri.cam.lock != null:
		fail(res, "after the intro: state %s mode %s" % [ri.fight.state, bi.mode])
	ri.queue_free()
	var rs := new_room("T10")
	if (rs.boss as LoopBoss).intro_len() > 2.01:
		fail(res, "the second time the intro is %.1f s" % (rs.boss as LoopBoss).intro_len())
	rs.queue_free()
	# 2. the body: 14 links, the first 24 px behind the head and 14 px apart along its path; it swims (90 px/s, turning <= 140 deg/s)
	var rf := loop_fight(60.0, 464.0)
	var b: LoopBoss = rf.boss
	b.queue = []
	b.gap_t = 999.0
	b.hx = 200.0
	b.hy = 300.0
	b.ang = 0.0
	b._seed_trail(Vector2(200.0, 300.0), Vector2(-1.0, 0.0))
	loop_run(rf, 1)
	var hp0 := Vector2(b.hx, b.hy)
	if b.links.size() != 14 or absf(Vector2(b.hx, b.hy).distance_to(b.links[0]) - 24.0) > 1.5 or absf((b.links[1] as Vector2).distance_to(b.links[2]) - 14.0) > 0.6:
		fail(res, "links: %d, neck %.1f, gap %.1f" % [b.links.size(), Vector2(b.hx, b.hy).distance_to(b.links[0]), (b.links[1] as Vector2).distance_to(b.links[2])])
	var max_turn := 0.0
	for f in range(60):
		var aa := b.ang
		loop_run(rf, 1)
		max_turn = maxf(max_turn, absf(wrapf(b.ang - aa, -PI, PI)) / Game.STEP)
	var moved := Vector2(b.hx, b.hy).distance_to(hp0)
	if moved < 60.0 * 0.95 * 0.9 or moved > 92.0 * 1.0 + 2.0 or max_turn > deg_to_rad(141.0):
		fail(res, "swim: %.0f px in 1 s, turn %.0f deg/s" % [moved, rad_to_deg(max_turn)])
	# the links follow the head's path: after a turn the old path still holds the tail
	# 3. touch: the head and every link hurt 1 with a knock-back from their side; none while hidden or in the intro (checked above)
	var tb: Array = b.touch_boxes()
	if tb.size() != 15:
		fail(res, "%d touch boxes, want 15" % tb.size())
	for t in tb:
		if int(t.dmg) != 1 or not t.has("sx"):
			fail(res, "a touch box without 1 damage and a side")
			break
	var pp = rf.player
	pp.inv = 0.0
	pp.grace = 0.0
	pp.hp = pp.max_hp
	var lk: Vector2 = b.links[6]
	pp.x = lk.x - 5.0
	pp.y = lk.y - 5.0
	b.gap_t = 999.0
	var hp_before: int = pp.hp
	rf.step(Game.STEP)
	if pp.hp != hp_before - 1:
		fail(res, "touching a link took %d hp, want 1" % (hp_before - pp.hp))
	pp.inv = 99.0
	# 4. hits: the tail tip takes full damage and flicks; a middle link and the head block
	var hp_b := b.hpf
	rf.attacker = pp
	var hr1: String = b.hit(2, 1.0, 0.0, "swipe", {"link": 13})
	var hr2: String = b.hit(2, 1.0, 0.0, "swipe", {"link": 6})
	var hr3: String = b.hit(2, 1.0, 0.0, "swipe", {"head": 1})
	if hr1 != "hit" or absf(hp_b - b.hpf - 2.0) > 0.01 or hr2 != "block" or hr3 != "block" or rf.time - b.flick_t > 0.1:
		fail(res, "hits: tail %s (%.1f), link %s, head %s" % [hr1, hp_b - b.hpf, hr2, hr3])
	var hb: Array = b.hurtboxes()
	if hb.size() != 15:
		fail(res, "%d hurt boxes, want 15 (head + 14 links)" % hb.size())
	# 5. the lunge: 0.75 s cue (no harm), straight 160 px at 420 px/s at the target locked at the cue's start, 2 damage; into a wall: stuck 0.6 s
	b.hx = 120.0
	b.hy = 380.0
	b.ang = PI
	b._seed_trail(Vector2(120.0, 380.0), Vector2(1.0, 0.0))
	pp.x = 40.0
	pp.y = 454.0
	b._start("lunge", "p1")
	var cue_t := 0.0
	var harm_in_cue := false
	var big := 0
	var stuck := false
	var start_pt := Vector2.ZERO
	for f in range(240):
		var was := b.plan_phase()
		loop_run(rf, 1)
		if b.plan_phase() == "cue":
			cue_t += Game.STEP
			if not b.attack_boxes().is_empty():
				harm_in_cue = true
		if was == "cue" and b.plan_phase() == "active":
			start_pt = Vector2(b.hx, b.hy)
		for hb2 in b.attack_boxes():
			big = maxi(big, int(hb2.dmg))
		if b.mode == "stuck":
			stuck = true
			break
	if cue_t < 0.74 or harm_in_cue or big != 2 or not stuck or absf(b.stuck_t - 0.6) > 0.05 + Game.STEP:
		fail(res, "lunge: cue %.2f, harm in the cue %s, damage %d, stuck %s (%.2f)" % [cue_t, str(harm_in_cue), big, str(stuck), b.stuck_t])
	# 6. the dive: the head goes over the target, points down, drops to the floor: stuck 0.8 s, 1 damage
	b.mode = "swim"
	b.hx = 200.0
	b.hy = 250.0
	pp.x = 115.0
	pp.y = 454.0
	b._start("dive", "p1")
	var dmax := 0
	var dstuck := false
	for f in range(240):
		loop_run(rf, 1)
		for hb3 in b.attack_boxes():
			dmax = maxi(dmax, int(hb3.dmg))
		if b.mode == "stuck":
			dstuck = true
			break
	if not dstuck or dmax != 1 or b.hy < 430.0 or absf(b.hx - 120.0) > 12.0 or absf(b.stuck_t - 0.8) > 0.05 + Game.STEP:
		fail(res, "dive: stuck %s at %.0f, %.0f (%.2f s), damage %d" % [str(dstuck), b.hx, b.hy, b.stuck_t, dmax])
	# 7. the spit: three brass rings at the target, the middle one yellow and catchable
	b.mode = "swim"
	b.hx = 250.0
	b.hy = 300.0
	rf.projs.clear()
	b._start("spit", "p1")
	loop_run(rf, int(0.7 / Game.STEP))
	var rings := rf.projs.filter(func(q): return q.get("kind", "") == "ring" and not q.dead)
	var yellow := rings.filter(func(q): return bool(q.catchable))
	if rings.size() != 3 or yellow.size() != 1 or String(yellow[0].col) != LoopBoss.YELLOW:
		fail(res, "spit: %d rings, %d catchable" % [rings.size(), yellow.size()])
	# 8. the coil: 1.0 s closing round the target (the ring is the body: touch hurts), then it squeezes
	b.mode = "swim"
	b.hx = 280.0
	b.hy = 380.0
	pp.x = 180.0
	pp.y = 444.0
	b._start("coil", "p1")
	loop_run(rf, int(1.0 / Game.STEP))
	var near_n := 0
	for c in b.links:
		if (c as Vector2).distance_to(b.coil_c) < 75.0:
			near_n += 1
	if near_n < 8:
		fail(res, "coil: only %d links round the target after the cue" % near_n)
	# 9. choosing: the first cycle spit, lunge, calm; then weighted, never the same twice; a camper gets the coil
	var rc := loop_fight(60.0, 464.0)
	var bc: LoopBoss = rc.boss
	var ids: Array = []
	var rep := 0
	var counts := {}
	var last := ""
	for f in range(int(70.0 / Game.STEP)):
		var pc = rc.player
		pc.x = 60.0 + 260.0 * (0.5 + 0.5 * sin(float(f) * 0.004))
		pc.y = 454.0
		pc.vx = 0.0
		pc.vy = 0.0
		loop_run(rc, 1)
		if not bc.plan.is_empty() and (ids.is_empty() or int(ids[ids.size() - 1][1]) != int(bc.plan.seq)):
			var pid := String(bc.plan.id)
			ids.append([pid, int(bc.plan.seq)])
			counts[pid] = int(counts.get(pid, 0)) + 1
			if pid == last:
				rep += 1
			last = pid
	var first: Array = []
	for k in range(mini(3, ids.size())):
		first.append(ids[k][0])
	if first != ["spit", "lunge", "calm"] or rep > 0 or ids.size() < 12:
		fail(res, "choice: first %s, repeats %d, %d plans" % [str(first), rep, ids.size()])
	for k in ["lunge", "dive", "coil", "spit"]:
		if int(counts.get(k, 0)) == 0:
			fail(res, "%s never chosen in 70 s (%s)" % [k, str(counts)])
	info += "70 s: %s; " % str(counts)
	bc.queue = []
	bc.last_id = "spit"
	bc.mode = "swim"
	bc.plan = {}
	bc.gap_t = 0.0
	bc.camp_cd = 0.0
	bc.camp["p1"] = [70.0, 459.0, rc.time - 3.0]
	rc.player.x = 65.0
	rc.player.y = 454.0
	loop_run(rc, 2)
	if bc.plan.is_empty() or String(bc.plan.id) != "coil":
		fail(res, "a camper did not get the coil (%s)" % ("none" if bc.plan.is_empty() else String(bc.plan.id)))
	rc.queue_free()
	# 10. the guest's copy: the same head, links, plan and boxes from the net fields
	b.mode = "swim"
	b.plan = {}
	b.hx = 150.0
	b.hy = 200.0
	loop_run(rf, 30)
	var rec := NetClasses.record(b)
	var rg := new_room("T10")
	var pup = NetClasses.make(int(rec[1]), rg)
	NetClasses.apply(pup, JSON.parse_string(JSON.stringify(rec)))
	pup.net_sample(1.0)
	pup.puppet_follow_parts(1.0)
	var tb1: Array = b.touch_boxes()
	var tb2: Array = pup.touch_boxes()
	var same: bool = tb1.size() == tb2.size()
	for k in range(mini(tb1.size(), tb2.size())):
		same = same and absf(float(tb1[k].x) - float(tb2[k].x)) < 0.6 and absf(float(tb1[k].y) - float(tb2[k].y)) < 0.6
	if not same:
		fail(res, "the guest's touch boxes differ (%d / %d)" % [tb1.size(), tb2.size()])
	pup.free()
	rg.queue_free()
	rf.queue_free()
	loop3_m3(res)
	loop3_m4(res)
	return report("loop3", res.ok, info + res.info)

func loop_fightsim() -> bool:
	# Two bots against the real boss (its real choices, cues, windows), no damage taken: the floor of the fight's length. "bp" freezes it when it
	# can (6 s cooldown, ~0.8 s to get in reach and face it), climbs (1.0 s) and claws the plate, then claws the lying body at the claw's rate
	# (0.4 s); "nobp" never freezes: it claws the plate of a stuck head (a half, 0.25 s to react) and catches some yellow rings (half). Both claw
	# the tail when it comes low. Prints the time of each phase.
	loop_setup()
	var secs := float(OS.get_environment("FIGHT_S")) if OS.get_environment("FIGHT_S") != "" else 400.0
	var out := {}
	for mode_ in ["bp", "nobp"]:
		var r := loop_fight(60.0, 464.0)
		var b: LoopBoss = r.boss
		var p = r.player
		var t_ph := {1: 0.0}
		var counts := {}
		var seen := {}
		var bp_ready := 0.0
		var want_bp := -1.0
		var climb := -1.0
		var next_claw := 0.0
		var stuck_seen := -1.0
		var ring_seen := {}
		var breaks := 0
		var was_broken := false
		var tail_ready := 0.0
		var f := 0
		var now := 0.0
		while f < int(secs * 60.0) and not b.dying and b.hpf > 0.0:
			f += 1
			now = float(f) / 60.0
			p.inv = 999.0
			p.hp = p.max_hp
			p.x = 40.0 if b.hx > 192.0 else 330.0
			p.y = 454.0
			step_keys(r, {})
			if not b.plan.is_empty() and not seen.has(int(b.plan.seq)):
				seen[int(b.plan.seq)] = true
				counts[String(b.plan.id)] = int(counts.get(String(b.plan.id), 0)) + 1
			if not t_ph.has(b.ph):
				t_ph[b.ph] = now
			if b.mode == "broken":
				if not was_broken:
					breaks += 1
					next_claw = now + 0.3
				was_broken = true
				if now >= next_claw:
					next_claw = now + 0.4
					r.attacker = p
					b.hit(1, 1.0, 0.0, "swipe", {"link": room_link(b)})
				continue
			was_broken = false
			if b.bp_t > 0.0:
				if climb < 0.0:
					climb = now + 1.0
				if now >= climb:
					climb = -1.0
					r.attacker = p
					b.hit(1, 1.0, 0.0, "swipe", {"head": 1})
				continue
			climb = -1.0
			if mode_ == "bp":
				if b.bp and now >= bp_ready and now >= b.immune_until - r.time + now:
					if want_bp < 0.0:
						want_bp = now + 0.8
					if now >= want_bp:
						want_bp = -1.0
						if r.bp_apply("c", b.nid):
							bp_ready = now + Game.BP_COOLDOWN
				else:
					want_bp = -1.0
			else:
				if b.mode == "stuck":
					if stuck_seen < 0.0:
						stuck_seen = now
					if now - stuck_seen >= 0.25 and now >= next_claw:
						next_claw = now + 0.4
						r.attacker = p
						b.hit(1, 1.0, 0.0, "swipe", {"head": 1})
				else:
					stuck_seen = -1.0
				for q in r.projs:
					if not q.dead and q.get("catchable", false) and not ring_seen.has(int(q.id)):
						ring_seen[int(q.id)] = true
						if ring_seen.size() % 2 == 0:            # (half of the yellow rings are caught and thrown back at the plate)
							q.dead = true
							r.attacker = p
							b.hit(1, 1.0, 0.0, "catch", {"head": 1})
			var tp: Vector2 = b.tail_point()
			if (b.mode == "swim" or b.mode == "plan" or b.mode == "stuck") and tp.y > 420.0 and now >= next_claw and now >= tail_ready and b.bp_t <= 0.0:
				next_claw = now + 0.4
				tail_ready = now + 1.2                            # (the tail flicks the claw away: one hit, then it has to come back)
				r.attacker = p
				b.hit(1, 1.0, 0.0, "swipe", {"link": b.links.size() - 1})
		var end := now
		var p1: float = float(t_ph.get(2, end))
		var p2: float = float(t_ph.get(3, end)) - p1
		var p3: float = end - float(t_ph.get(3, end))
		print("FIGHTSIM T10 %s: phase 1 %.0f s, phase 2 %.0f s, phase 3 %.0f s, total %.0f s (hp %d, %s), breaks %d, plans %s" % [mode_, p1, p2, p3, end, b.max_hp, "dead" if (b.dying or b.hpf <= 0.0) else "ALIVE", breaks, str(counts)])
		out[mode_] = end if (b.dying or b.hpf <= 0.0) else 1e9
		r.queue_free()
	var ok: bool = out.bp < 1e8 and out.nobp < 2.0 * out.bp
	print("TEST fightsim %s bp %.0f s, without breakpoint %.0f s (must be < 2x)" % ["PASS" if ok else "FAIL", out.bp, out.nobp])
	return ok

# the link nearest the middle of the body (the bot claws the lying chain)
func room_link(b: LoopBoss) -> int:
	return clampi(b.links.size() / 2, 0, b.links.size() - 1)

func loop3_m3(res: Dictionary) -> void:
	# --- M3 -------------------------------------------------------------------------------------------------------------
	var r3m := loop_fight(60.0, 464.0)
	var bm: LoopBoss = r3m.boss
	var pm = r3m.player
	bm.queue = []
	bm.gap_t = 999.0
	bm.hx = 120.0
	bm.hy = 330.0
	bm.ang = 0.0
	bm._seed_trail(Vector2(120.0, 330.0), Vector2(0.0, 1.0))
	loop_run(r3m, 2)
	# 1. breakpoint takes when it is not in an active part: frozen 3.5 s, every link a one-way platform, no touch, nothing moves
	if not bm.bp:
		fail(res, "breakpoint does not take on a swimming snake")
	if not r3m.bp_apply("c", bm.nid) or absf(bm.bp_t - Game.BP_TIME) > 0.01:
		fail(res, "the freeze did not take (bp_t %.2f)" % bm.bp_t)
	loop_run(r3m, 1)
	var l5: Vector2 = bm.links[5]
	if r3m.bp_plats.size() != 15 or not bm.touch_boxes().is_empty() or not bm.harmboxes().is_empty():
		fail(res, "frozen: %d platforms, %d touch boxes" % [r3m.bp_plats.size(), bm.touch_boxes().size()])
	# a player put on link 5 stands on it
	pm.x = l5.x - 5.0
	pm.y = l5.y - 7.0 - pm.h - 1.0
	pm.vx = 0.0
	pm.vy = 0.0
	loop_run(r3m, 30)
	if not pm.on_ground or absf(pm.y + pm.h - (l5.y - 7.0)) > 1.5 or (bm.links[5] as Vector2).distance_to(l5) > 0.01:
		fail(res, "a frozen link is no platform (on ground %s, feet %.1f, link top %.1f)" % [str(pm.on_ground), pm.y + pm.h, l5.y - 7.0])
	# the guest's copy builds the same platforms
	var recm := NetClasses.record(bm)
	var rgm := new_room("T10")
	var pupm = NetClasses.make(int(recm[1]), rgm)
	rgm.ents.append(pupm)
	NetClasses.apply(pupm, JSON.parse_string(JSON.stringify(recm)))
	pupm.net_sample(1.0)
	pupm.puppet_follow_parts(1.0)
	rgm._rebuild_bp_plats()
	if rgm.bp_plats.size() != 15 or absf(float(rgm.bp_plats[5].y) - float(r3m.bp_plats[5].y)) > 0.6:
		fail(res, "the guest's frozen platforms differ (%d)" % rgm.bp_plats.size())
	rgm.ents.erase(pupm)
	pupm.free()
	rgm.queue_free()
	# 2. one hit on the plate while frozen: `false`, it lets go and lies on the floor 2.0 s, every link takes full damage, no touch; then i++
	var hl3: LoopHall = r3m.shaft
	var cnt0 := hl3.counter
	var hp3 := bm.hpf
	var hr3: String = bm.hit(1, 1.0, 0.0, "swipe", {"head": 1})
	if hr3 != "hit" or bm.mode != "broken" or bm.bp_t > 0.0 or absf(hp3 - bm.hpf) > 0.01:
		fail(res, "a hit on the frozen plate: %s, mode %s" % [hr3, bm.mode])
	loop_run(r3m, int(0.6 / Game.STEP))
	var low := 0
	for c in bm.links:
		if (c as Vector2).y > 440.0:
			low += 1
	var hp4 := bm.hpf
	var hl4: String = bm.hit(2, 1.0, 0.0, "swipe", {"link": 4})
	if low < 10 or hl4 != "hit" or absf(hp4 - bm.hpf - 2.0) > 0.01 or not bm.touch_boxes().is_empty():
		fail(res, "broken: %d links on the floor, a link hit %s (%.1f)" % [low, hl4, hp4 - bm.hpf])
	loop_run(r3m, int((2.0 - 0.6 + 0.1) / Game.STEP))
	if bm.mode != "recoil" or bm.hit(1, 1.0, 0.0, "swipe", {"link": 3}) != "block":
		fail(res, "after 2.0 s: mode %s (want recoil, invulnerable)" % bm.mode)
	loop_run(r3m, int(0.55 / Game.STEP))
	if bm.mode != "swim" or bm.iter != 1 or hl3.counter != cnt0 + 1 or bm.say_k != 4:
		fail(res, "after the recoil: mode %s, i %d, counter %d -> %d, line %d" % [bm.mode, bm.iter, cnt0, hl3.counter, bm.say_k])
	if absf(bm._speed() - 90.0 * 1.06) > 0.01:
		fail(res, "speed after one break %.1f, want %.1f" % [bm._speed(), 90.0 * 1.06])
	# 3. after a freeze breakpoint rests 4 s (it shivers, nothing stops); then it takes again
	bm.gap_t = 999.0
	bm.immune_until = -10.0                                   # (the freeze that ended in the break above left it resting too)
	loop_run(r3m, 1)
	r3m.bp_apply("c", bm.nid)
	loop_run(r3m, int((Game.BP_TIME + 0.2) / Game.STEP))
	if bm.bp_t > 0.0 or bm.immune_until < r3m.time + 3.5:
		fail(res, "after a freeze: bp_t %.2f, immune until %.2f (now %.2f)" % [bm.bp_t, bm.immune_until, r3m.time])
	if r3m.bp_apply("c", bm.nid) or r3m.time - bm.shiver_t0 > 0.05:
		fail(res, "breakpoint took while it rests, or no shiver")
	loop_run(r3m, int(4.0 / Game.STEP))
	if not r3m.bp_apply("c", bm.nid):
		fail(res, "breakpoint does not take again after 4 s")
	loop_run(r3m, int((Game.BP_TIME + 0.2) / Game.STEP))
	# 4. never in an active part
	bm.immune_until = -10.0
	bm.hx = 300.0
	bm.hy = 300.0
	bm._start("lunge", "p1")
	var bp_in_active := false
	for f in range(120):
		loop_run(r3m, 1)
		if bm.plan_phase() == "active" and bm.bp:
			bp_in_active = true
	if bp_in_active:
		fail(res, "breakpoint can take in the lunge's active part")
	# 5. half hits: a stuck head's plate flickers (`tru_`); a second within 3 s breaks; later than 3 s it starts over. A caught yellow ring is a half
	bm.mode = "stuck"
	bm.stuck_t = 5.0
	bm.plan = {}
	bm.half_t0 = -10.0
	bm.hit(1, 1.0, 0.0, "swipe", {"head": 1})
	if bm.mode != "stuck" or bm.half_t0 < r3m.time - 0.01 or bm._plate_i() not in [0, 2]:
		fail(res, "the first half hit: mode %s" % bm.mode)
	r3m.time += 3.2
	bm.hit(1, 1.0, 0.0, "swipe", {"head": 1})
	if bm.mode != "stuck":
		fail(res, "two half hits 3.2 s apart broke the condition")
	bm.hit(1, 1.0, 0.0, "catch", {"head": 1})
	if bm.mode != "broken":
		fail(res, "a stuck half then a caught yellow ring within 3 s did not break it")
	# a swimming head just clangs
	loop_run(r3m, int(2.6 / Game.STEP))
	bm.half_t0 = -10.0
	if bm.mode != "swim" or bm.hit(1, 1.0, 0.0, "swipe", {"head": 1}) != "block":
		fail(res, "a swimming head does not clang (mode %s)" % bm.mode)
	# 6. phase 2: every i++ flips the gears
	bm.ph = 2
	var gd0 := hl3.gear_dir
	bm._break()
	loop_run(r3m, int(2.5 / Game.STEP))
	if hl3.gear_dir != -gd0:
		fail(res, "phase 2: the gears did not turn the other way at i++")
	r3m.queue_free()

func loop3_m4(res: Dictionary) -> void:
	# --- M4 -------------------------------------------------------------------------------------------------------------
	var r := loop_fight(60.0, 464.0)
	var b: LoopBoss = r.boss
	var hl: LoopHall = r.shaft
	b.queue = []
	b.gap_t = 999.0
	# 1. 66 %: phase 2, a 2.0 s change: invulnerable, no touch; the low ledges go, the gantry swings, the nested ring splits off; then recursion, escalate
	b.hpf = float(b.max_hp) * 0.67
	b.hit(2, 1.0, 0.0, "swipe", {"link": b.links.size() - 1})
	if b.mode != "trans" or b.ph != 2 or hl.ph != 2 or hl.p2_t0 < 0.0:
		fail(res, "66 %%: mode %s, phase %d / hall %d" % [b.mode, b.ph, hl.ph])
	if b.hit(2, 1.0, 0.0, "swipe", {"link": b.links.size() - 1}) != "block" or not b.touch_boxes().is_empty():
		fail(res, "the phase change is not invulnerable / harmless")
	loop_run(r, int(2.05 / Game.STEP))
	if b.mode != "swim" or not b.nest_on:
		fail(res, "after the change to phase 2: mode %s, nest %s" % [b.mode, str(b.nest_on)])
	b.gap_t = 0.0
	var firsts: Array = []
	var seen := {}
	var esc_seen := false
	var esc2_seen := false
	var esc2_dmg := 0
	var esc2_cue := 0.0
	var two_big := false
	var copy_harm := false
	for f in range(int(16.0 / Game.STEP)):
		loop_run(r, 1)
		if not b.plan.is_empty() and not seen.has(int(b.plan.seq)):
			seen[int(b.plan.seq)] = true
			firsts.append(String(b.plan.id))
			if String(b.plan.id) == "esc2":
				esc2_seen = true
				esc2_cue = float(b.plan.t)
		if not b.plan.is_empty() and String(b.plan.id) == "esc2" and b.plan_active():
			for hb in b.attack_boxes():
				esc2_dmg = maxi(esc2_dmg, int(hb.dmg))
		var big := 0
		for hb2 in b.harmboxes():
			if int(hb2.get("dmg", 1)) >= 2:
				big += 1
		if big > 1:
			two_big = true
		for hb3 in b.pressure_boxes(r.time):
			if hb3.has("copy"):
				copy_harm = true
	if firsts.size() < 3 or firsts[0] != "recursion" or firsts[1] != "escalate" or firsts[2] != "esc2":
		fail(res, "phase 2's first cycle: %s" % str(firsts.slice(0, 4)))
	if not esc2_seen or esc2_dmg != 1 or esc2_cue < 0.45 * float(Game.dv("telegraph_mult")) - 0.01:
		fail(res, "escalate's second lunge: seen %s, damage %d, cue %.2f" % [str(esc2_seen), esc2_dmg, esc2_cue])
	if not copy_harm or two_big:
		fail(res, "recursion's copy hurt %s; two 2-damage boxes at once %s" % [str(copy_harm), str(two_big)])
	# 2. the nested ring: round a gear (1 damage), a 0.6 s spin-up (its cue) and over M to the other gear; a break drops it 4 s
	b.nest_base = r.time
	b.nest_g0 = 0
	var g0 := b.nest_gear(r.time + 1.0)
	var g1 := b.nest_gear(r.time + LoopBoss.NEST_PER + 0.5)
	var c_or := b.nest_center(r.time + 2.0)
	var c_x := b.nest_center(r.time + LoopBoss.NEST_ORBIT + LoopBoss.NEST_SPIN + LoopBoss.NEST_CROSS * 0.5)
	if g0 != 0 or g1 != 1 or absf(c_or.distance_to(LoopHall.GEAR_C[0]) - LoopBoss.NEST_R) > 0.5 or absf(c_x.x - 192.0) > 20.0 or c_x.y > 260.0:
		fail(res, "nest: gears %d -> %d, orbit %.1f, crossing at %.0f, %.0f" % [g0, g1, c_or.distance_to(LoopHall.GEAR_C[0]), c_x.x, c_x.y])
	var spin := 0.0
	for k in range(200):
		if b.nest_spinup(r.time + float(k) * 0.05) >= 0.0:
			spin += 0.05
	if spin < 0.55:
		fail(res, "the ring's spin-up lasts %.2f s (want >= 0.6)" % spin)
	var nb := 0
	for hb4 in b.pressure_boxes(r.time + 1.0):
		if hb4.has("nest"):
			nb += 1
			if int(hb4.dmg) != 1:
				fail(res, "a nest link hurts %d" % int(hb4.dmg))
	if nb != 6:
		fail(res, "%d nest boxes" % nb)
	b.mode = "swim"
	b.plan = {}
	b._break()
	var dropped := true
	for hb5 in b.pressure_boxes(r.time + 1.0):
		if hb5.has("nest"):
			dropped = false
	if not dropped or b.pressure_boxes(r.time + 4.2).filter(func(q): return q.has("nest")).is_empty():
		fail(res, "a break does not drop the ring for 4 s")
	loop_run(r, int(2.6 / Game.STEP))
	# 3. 33 %: phase 3, a 2.5 s change: the plate cracks, the floor cracks 0.8 s and falls away, the ceiling opens, the ring is gone
	b.mode = "swim"
	b.hpf = float(b.max_hp) * 0.34
	b.hit(2, 1.0, 0.0, "swipe", {"link": b.links.size() - 1})
	if b.mode != "trans" or b.ph != 3 or b.nest_on:
		fail(res, "33 %%: mode %s phase %d nest %s" % [b.mode, b.ph, str(b.nest_on)])
	loop_run(r, int(1.0 / Game.STEP))
	if not hl.pit_open(r.time):
		fail(res, "phase 3: the pit is not open 1.0 s into the change")
	loop_run(r, int(1.6 / Game.STEP))
	if b.mode != "swim" or b._plate_i() != 4:
		fail(res, "after the change to phase 3: mode %s, plate %d" % [b.mode, b._plate_i()])
	# 4. the wrap dive: a 0.75 s cue (into the pit, in at the top seam over the target's column), down the column, 2 damage; on the gantry: stuck
	b.gap_t = 999.0
	b.queue = []
	var pq = r.player
	pq.x = 180.0
	pq.y = 30.0
	pq.vx = 0.0
	b.hx = 100.0
	b.hy = 300.0
	b._start("wrap_dive", "p1")
	var wcue := float(b.plan.t)
	var top_seen := false
	var wdmg := 0
	var wstuck := false
	for f in range(200):
		var gl_y: float = float(hl.gantry_p.y)
		loop_run(r, 1)
		pq.x = 180.0
		pq.y = gl_y - pq.h
		if b.plan_phase() == "cue" and b.hy < 0.0:
			top_seen = true
		for hb6 in b.attack_boxes():
			wdmg = maxi(wdmg, int(hb6.dmg))
		if b.mode == "stuck":
			wstuck = true
			break
	if wcue < 0.749 or not top_seen or wdmg != 2 or not wstuck or absf(b.hy - (float(hl.gantry_p.y) - 14.0)) > 1.0:
		fail(res, "wrap dive: cue %.2f, at the top %s, damage %d, stuck %s at %.0f (gantry %.0f)" % [wcue, str(top_seen), wdmg, str(wstuck), b.hy, float(hl.gantry_p.y)])
	# a feint only adds 0.25 s to a full cue
	b.mode = "swim"
	b._start("lunge", "p1")
	var c0 := float(b.plan.t)
	b._feint()
	if absf(float(b.plan.t) - c0 - 0.25 * float(Game.dv("telegraph_mult"))) > 0.001:
		fail(res, "a feint adds %.2f s" % (float(b.plan.t) - c0))
	# 5. hp = length: phase 3's hp lost in eighths sheds links (14 -> 6), they lie on the floor
	b.plan = {}
	b.mode = "swim"
	var n0 := b.links.size()
	b.hpf = b.p3_hp0 * 0.5
	b.on_damage()
	var n1 := b.links.size()
	b.hpf = b.p3_hp0 * 0.01
	b.on_damage()
	if n0 != 14 or n1 != 10 or b.links.size() != 7 or b.shed.size() != 7:          # (the eighth link goes with the last hit)
		fail(res, "shedding: %d -> %d -> %d links, %d shed" % [n0, n1, b.links.size(), b.shed.size()])
	# 6. the guest's copy: the ring and the copy are pure functions of the fields
	b.nest_on = true
	b.nest_base = r.time - 2.0
	b._make_copy()
	var rec := NetClasses.record(b)
	var rg := new_room("T10")
	var pup = NetClasses.make(int(rec[1]), rg)
	NetClasses.apply(pup, JSON.parse_string(JSON.stringify(rec)))
	rg.time = r.time
	var pa: Array = b.pressure_boxes(r.time + 0.5)
	var pb: Array = pup.pressure_boxes(r.time + 0.5)
	var same: bool = pa.size() == pb.size()
	for k in range(mini(pa.size(), pb.size())):
		same = same and absf(float(pa[k].x) - float(pb[k].x)) < 1.5 and absf(float(pa[k].y) - float(pb[k].y)) < 1.5
	if not same or pup.links.size() != 7 or pup.shed.size() != 7:
		fail(res, "the guest's ring / copy / length differ (%d / %d boxes) %s / %s" % [pa.size(), pb.size(), str(pa.slice(0, 2)), str(pb.slice(0, 2))])
	pup.free()
	rg.queue_free()
	r.queue_free()
