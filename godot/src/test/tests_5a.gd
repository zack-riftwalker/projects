extends Tests4b3
class_name Tests5a
# Unit tests of phase 5A (THREAD TOWER). run_tests.gd hands names it does not know to run().

const NAMES5 := ["rooms5a", "w4assets", "tick5a", "breakpoint", "w4enemies", "raceboss"]

func run(name: String):
	match name:
		"rooms5a": return await t_rooms5a()
		"w4assets": return await t_w4assets()
		"tick5a": return await t_tick5a()
		"breakpoint": return await t_breakpoint()
		"w4enemies": return await t_w4enemies()
		"raceboss": return await t_raceboss()
	return await super.run(name)

func tower_ids() -> Array:
	var out: Array = []
	for id in Game.rooms_meta.rooms:
		if String(id).begins_with("T"):
			out.append(String(id))
	return out

# MV5A-01: the 19 tower rooms load, their doors point back (the loop room's wrap door points at its own room),
# N11's west door is open and its end door is gone, H11's hatch waits for the T02 lever
func t_rooms5a() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var ids := tower_ids()
	if ids.size() != 19:
		fail(res, "%d T rooms, want 19" % ids.size())
	for id in ids:
		var m: Dictionary = Game.rooms_meta.rooms[id]
		if Game.zone_of(id) != "tower" or int(m.get("world", 0)) != 4 or String(m.get("music", "")) != "w4":
			fail(res, "%s zone/world/music" % id)
		for d in m.doors:
			var to_room := String(d.to).get_slice(":", 0)
			if to_room == "P01" and m.has("end"):
				continue                                       # T11's end door ("to be continued in /var/prod")
			if not Game.rooms_meta.rooms.has(to_room):
				fail(res, "%s leads to the missing room %s" % [d.id, to_room])
				continue
			var back := false
			for td in Game.rooms_meta.rooms[to_room].doors:
				if td.id == d.to and (td.to == d.id or td.get("wrap", false)):
					back = true                                # (T10:W leads to the loop room's wrap door, which leads to its own W)
			if d.get("wrap", false):
				back = String(d.to) == String(d.id).get_slice(":", 0) + ":W"
			if not back:
				fail(res, "%s does not point back" % d.id)
		var r := new_room(id)
		await frames(1)
		if r.w != int(m.size[0]) or r.h != int(m.size[1]):
			fail(res, "%s size" % id)
		r.queue_free()
	var n11 := new_room("N11")
	var dw = n11.grid.door_at("W", int(Game.rooms_meta.rooms.N11.doors.filter(func(d): return d.id == "N11:W")[0].a))
	if dw == null or not dw.open:
		fail(res, "N11:W is not open")
	if n11.end_door != null or Game.rooms_meta.rooms.N11.has("end"):
		fail(res, "N11 still has an end door")
	n11.queue_free()
	var h11 := new_room("H11")
	var dh = h11.grid.door_at("N", 60)
	if dh == null or dh.open:
		fail(res, "H11:N is open without the lever")
	h11.queue_free()
	Game.flags["lever:T02"] = true
	var h11b := new_room("H11")
	var dh2 = h11b.grid.door_at("N", 60)
	if dh2 == null or not dh2.open:
		fail(res, "H11:N stays closed with the lever")
	h11b.queue_free()
	Game.fresh()
	return report("rooms5a", res.ok, "%d tower rooms%s" % [ids.size(), res.info])

# MV5A-02: world 4's art, theme and music exist and a tower room builds its view from them
func t_w4assets() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	for path in ["res://assets/tiles/w4_tiles.png", "res://assets/bg/w4.png", "res://assets/theme/w4.json", "res://assets/sprites/platform_w4.png", "res://assets/music/w4.ogg"]:
		if not ResourceLoader.exists(path):
			fail(res, path)
	if String(Game.theme(4).name) != "THREAD TOWER":
		fail(res, "theme name " + String(Game.theme(4).name))
	var r := new_room("T04")
	await frames(2)
	if r.view == null or r.view.tiles == null or r.world != 4:
		fail(res, "T04 builds no view")
	if main.song_for(r) != "w4":
		fail(res, "T04 plays " + String(main.song_for(r)))
	r.queue_free()
	Game.fresh()
	return report("w4assets", res.ok, res.info)

func clean_room(room_id: String, px: float, py: float) -> Room:
	var r := bare_room(room_id, px, py)
	r.player.inv = 99.0
	return r

func add_bug(room: Room, bx: float, by: float, fc: float) -> Bug:
	var b := Bug.new(room, 0, 0, false)
	b.x = bx
	b.y = by
	b.face = fc
	room.ents.append(b)
	room.entity_root.add_child(b)
	return b

func gear_xy(r: Room) -> Array:
	var out: Array = []
	for pl in r.plats:
		if pl.has("gear"):
			out.append([snappedf(pl.x, 0.001), snappedf(pl.y, 0.001)])
	return out

# MV5A-03: the tick and the tower's machines
func t_tick5a() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# 1. two rooms given the same clock show the same blink, gear and piston states
	for rid in ["T02", "TC1", "TC2"]:
		var a := clean_room(rid, 40.0, 40.0)
		var b := clean_room(rid, 40.0, 40.0)
		for tm in [0.4, 3.77, 12.3]:
			a.time = tm
			b.time = tm
			a.tower.step(0.0, [])
			b.tower.step(0.0, [])
			if gear_xy(a) != gear_xy(b) or a.grid.blink_ph != b.grid.blink_ph:
				fail(res, "%s differs at %.2f" % [rid, tm])
			for i in range(a.tower.pistons.size()):
				if a.tower.pistons[i].rows != b.tower.pistons[i].rows:
					fail(res, "%s piston %d differs at %.2f" % [rid, i, tm])
		a.queue_free()
		b.queue_free()
	# 2. a blink cell does not close on a body; `1` cells are on during even ticks, `2` during odd ticks
	var rb := clean_room("T02", 40.0, 40.0)
	var ga: Dictionary = {}
	for g in rb.tower.bgroups:
		for c in g.cells:
			if rb.grid.tile(c[0], c[1]) == TileGrid.BLINK_A and ga.is_empty():
				ga = {"tx": c[0], "ty": c[1]}
	if ga.is_empty():
		fail(res, "T02 has no blink block")
	else:
		rb.time = Tower.TICK * 1.5                                # an odd tick: `1` is off
		rb.tower.step(0.0, [])
		if rb.grid.solid(ga.tx, ga.ty):
			fail(res, "a `1` block is solid on an odd tick")
		rb.player.x = float(ga.tx * 16 + 3)
		rb.player.y = float(ga.ty * 16 + 3)
		rb.player.vx = 0.0
		rb.player.vy = 0.0
		rb.time = Tower.TICK * 2.2                                # the next even tick: `1` would turn on under the body
		rb.tower.step(0.0, [rb.player])
		if rb.grid.solid(ga.tx, ga.ty):
			fail(res, "a blink block closed on a body")
		rb.player.x = float(ga.tx * 16 + 3)
		rb.player.y = float(ga.ty * 16 - 40)                      # the body leaves
		rb.tower.step(0.0, [rb.player])
		if not rb.grid.solid(ga.tx, ga.ty):
			fail(res, "the blink block never closed after the body left")
	rb.queue_free()
	# 3. a rider on a gear platform is carried through 8 ticks
	var rg := clean_room("TC1", 0.0, 0.0)
	var pl0: Dictionary = rg.plats[0]
	rg.player.x = pl0.x + 19.0
	rg.player.y = pl0.y - 10.0
	var x0: float = rg.player.x
	var moved := 0.0
	var off_plat := 0
	for f in range(int(Tower.TICK * 8.0 * 60.0)):
		step_keys(rg, {})
		rg.player.inv = 99.0
		moved = maxf(moved, absf(rg.player.x - x0))
		if rg.player.ride == null:
			off_plat += 1
	if moved < 30.0 or off_plat > 40:
		fail(res, "the rider moved %.0f px and was off the platform %d frames" % [moved, off_plat])
	rg.queue_free()
	# 4. a busy piston is clear only while it waits (0.1 of a tick per cycle)
	var rp := clean_room("TC2", 0.0, 0.0)
	var pz: Dictionary = rp.tower.pistons[0]
	var total := 0.7 * Tower.TICK
	var clear := 0.0
	for i in range(10000):
		if rp.tower.piston_rows_at(pz, float(i) * total / 10000.0) == 0:
			clear += total / 10000.0
	if absf(clear - 0.1 * Tower.TICK) > 0.004:
		fail(res, "a busy piston is clear %.3f s of %.3f, want %.3f" % [clear, total, 0.1 * Tower.TICK])
	# 5. a body caught by an extending head takes 1 damage and is put at its safe spot
	var cx_: float = float(pz.x * 16 + 20)
	var cy_: float = float((pz.y + 2) * 16)
	rp.player.safe = {"x": 20.0, "y": 20.0}
	var hp0: int = rp.player.hp
	var hurt := false
	for f in range(240):
		rp.player.x = cx_
		rp.player.y = cy_
		rp.player.vx = 0.0
		rp.player.vy = 0.0
		rp.player.inv = 0.0
		rp.player.gone = false
		step_keys(rp, {})
		if rp.player.hp < hp0:
			hurt = true
			break
	if not hurt or rp.player.hp != hp0 - 1 or absf(rp.player.x - 20.0) > 2.0:
		fail(res, "the piston did not crush: hp %d -> %d at x %.0f" % [hp0, rp.player.hp, rp.player.x])
	rp.queue_free()
	# 6. TB2: the first key opens row 45 for 3.5 s, a body on the key keeps it open, a closed gate never closes on a body
	var rm := clean_room("TB2", 16.0 * 3 + 3.0, 16.0 * 58 + 4.0)
	var gate_idx: int = rm.tower.mutex[0].cells[0]
	var gtx: int = gate_idx % rm.w
	var gty: int = gate_idx / rm.w
	if gty != 45 or not rm.grid.solid(gtx, gty):
		fail(res, "TB2 row 45 is not a closed gate")
	step_keys(rm, {})
	if rm.grid.solid(gtx, gty) or absf(float(rm.tower.mutex[0].t) - Tower.MUTEX_T) > 0.05:
		fail(res, "standing on the key did not open the gate (t %.2f)" % float(rm.tower.mutex[0].t))
	for f in range(60 * 6):                                      # standing keeps refreshing it
		rm.player.x = 16.0 * 3 + 3.0
		rm.player.y = 16.0 * 58 + 4.0
		rm.player.vy = 0.0
		step_keys(rm, {})
	if rm.grid.solid(gtx, gty):
		fail(res, "the gate closed while a body stood on the key")
	rm.player.x = float(gtx * 16 + 3)                            # now the body is in the gate cell itself
	rm.player.y = float(gty * 16 + 3)
	rm.player.vx = 0.0
	rm.player.vy = 0.0
	for f in range(60 * 5):
		rm.player.x = float(gtx * 16 + 3)
		rm.player.y = float(gty * 16 + 3)
		rm.player.vy = 0.0
		step_keys(rm, {})
	if rm.grid.solid(gtx, gty):
		fail(res, "a gate closed on a body")
	rm.player.x = 16.0 * 12
	rm.player.y = 16.0 * 40
	rm.player.vy = 0.0
	run_room(rm, 10)
	if not rm.grid.solid(gtx, gty):
		fail(res, "the gate never closed after the body left")
	rm.queue_free()
	# 7. cables: 1 damage clangs, 2 (opus) cuts the whole cable and sets its flag; a rebuilt room loads it cut
	var rc := clean_room("T11", 40.0, 40.0)
	var cab: Dictionary = {}
	for g in rc.tower.cables:
		cab = g
	var c0: Array = cab.cells[0]
	var cbox := {"x": float(c0[0] * 16), "y": float(c0[1] * 16), "w": 16.0, "h": 16.0}
	rc.player.tools = {"opus": false}
	rc.player.atk_dmg = 1
	rc.player.atk_id += 1
	rc.tower.claw(rc.player, cbox)
	if cab.cut or rc.grid.tile(c0[0], c0[1]) != TileGrid.CABLE:
		fail(res, "a 1-damage hit cut a cable")
	rc.player.tools = {"opus": true}
	rc.player.atk_dmg = 2
	rc.player.atk_id += 1
	rc.tower.claw(rc.player, cbox)
	var all_air := true
	for c in cab.cells:
		if rc.grid.tile(c[0], c[1]) != TileGrid.E:
			all_air = false
	var fkey := "cable:T11:%d:%d" % [c0[0], c0[1]]
	if not cab.cut or not all_air or not Game.flag(fkey):
		fail(res, "an opus hit did not cut the whole cable (cut %s, air %s, flag %s)" % [cab.cut, all_air, Game.flag(fkey)])
	rc.queue_free()
	var rc2 := new_room("T11")
	if rc2.grid.tile(c0[0], c0[1]) != TileGrid.E:
		fail(res, "a rebuilt T11 has its cable back")
	rc2.queue_free()
	Game.flags.erase(fkey)
	# 8. T09: the wrap door raises the pass to 3 at most, the third pass has the `break;` key, touching it sends the next crossing to T10
	Game.fresh()
	Game.load_meta()
	var m := new_manager()
	m.swap_to("T09", null, null, true)
	var seen: Array = []
	for pass_n in range(5):
		var q = m.player
		q.x = 64.0 * 16.0 - 14.0
		q.y = 15.0 * 16.0 - 10.0
		q.vx = 0.0
		q.vy = 0.0
		var room_before: String = m.room.id
		for f in range(240):
			q.inv = 99.0
			q.hp = q.max_hp
			Controls.script_input = {"right": true}
			m.tick(Game.STEP)
			if m.room.id != room_before or (not m.trans.on and f > 40 and q.x < 400.0):
				break
		while m.trans.on:
			m.tick(Game.STEP)
		Controls.script_input = null
		seen.append("%s:%d" % [m.room.id, m.room.iter])
		if m.room.id != "T09":
			break
		if seen.size() == 4 and m.room.iter == 3 and m.room.loop_key_on() and not Game.flag("break:T09"):
			var kq = m.player
			kq.x = m.room.loop_key.x + 3.0
			kq.y = m.room.loop_key.y + 3.0
			m.tick(Game.STEP)
			if not Game.flag("break:T09"):
				fail(res, "touching the key did not set break:T09")
	if seen != ["T09:1", "T09:2", "T09:3", "T09:3", "T10:0"]:
		fail(res, "loop crossings went " + str(seen))
	Controls.script_input = null
	Game.fresh()
	return report("tick5a", res.ok, res.info)

# MV5A-04: breakpoint
func t_breakpoint() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	Game.tools.breakpoint = true
	# 1. TC2's busy piston: stopped while it waits (retracted), a body can stand in its shaft for 3 s
	var r := clean_room("TC2", 0.0, 0.0)
	var pz: Dictionary = r.tower.pistons[0]
	var total := 0.7 * Tower.TICK
	var t_wait := 0.0
	while not (r.tower.piston_rows_at(pz, t_wait) == 0 and r.tower.piston_rows_at(pz, t_wait + 0.03) == 0 and r.tower.piston_rows_at(pz, t_wait - 0.03) != 0):
		t_wait += 0.001
	r.time = t_wait + total * 3.0 + 0.0
	r.tower.step(0.0, [])
	if pz.rows != 0:
		fail(res, "the piston is not in its wait phase (rows %d)" % pz.rows)
	var p = r.player
	p.x = float(pz.x * 16 + 19)
	p.y = float(37 * 16 - 10)
	p.face = 1.0
	p.vx = 0.0
	p.vy = 0.0
	p.bp_cd = 0.0
	var pk := r.bp_pick(p)
	if pk.is_empty() or String(pk.kind) != "p":
		fail(res, "no piston target: %s" % str(pk))
	else:
		step_keys(r, {"special": true})
		if not r.tower.is_frozen(String(pk.id)):
			fail(res, "the press did not freeze the piston")
		var open_all := true
		for f in range(60 * 3):
			step_keys(r, {})
			p.inv = 99.0
			p.x = float(pz.x * 16 + 19)
			p.y = float(37 * 16 - 10)
			for c in pz.cells:
				if r.grid.solid(c[0], c[1]):
					open_all = false
		if not open_all or pz.rows != 0:
			fail(res, "a frozen retracted piston closed its shaft")
		for f in range(60):
			step_keys(r, {})
			p.inv = 99.0
		if r.tower.is_frozen(String(pk.id)):
			fail(res, "the freeze did not end after 3.5 s")
	# 2. the cooldown blocks a second press for 6 s
	var pk2 := r.bp_pick(p)
	if not pk2.is_empty():
		p.bp_cd = 0.0
	p.bp_cd = Game.BP_COOLDOWN
	step_keys(r, {"special": true})
	if r.tower.fz.size() > 0:
		fail(res, "a press during the cooldown froze something")
	r.queue_free()
	# 3. a frozen gear resumes from the same angle
	var rg := clean_room("TC1", 0.0, 0.0)
	var g0: Dictionary = rg.tower.gears[0]
	rg.time = Tower.TICK * 5.0 + 0.1
	rg.tower.step(0.0, [])
	var before := Vector2(g0.plats[0].x, g0.plats[0].y)
	var t_freeze: float = rg.time
	rg.tower.freeze(g0.key)
	for f in range(int(Game.BP_TIME * 60.0) + 2):
		rg.time += 1.0 / 60.0
		rg.tower.step(1.0 / 60.0, [])
		if f < 100 and Vector2(g0.plats[0].x, g0.plats[0].y).distance_to(before) > 0.01:
			fail(res, "a frozen gear moved")
			break
	var _t0 := t_freeze
	var after := Vector2(g0.plats[0].x, g0.plats[0].y)
	var want_pos: Vector2 = rg.tower.gear_pos(g0, 0, rg.time - float(rg.tower.offs.get(g0.key, 0.0)))
	if after.distance_to(want_pos - Vector2(24.0, 3.0)) > 0.01 or absf(float(rg.tower.offs.get(g0.key, 0.0)) - Game.BP_TIME) > 0.05:
		fail(res, "the gear did not resume (offset %.2f)" % float(rg.tower.offs.get(g0.key, 0.0)))
	rg.queue_free()
	# 4. a frozen creature does not hurt, can be stood on, and its freeze travels in the snapshot record
	var rb := clean_room("R01", 100.0, 150.0)
	rb.player.inv = 0.0
	var bug := add_bug(rb, 100.0, 180.0, -1.0)
	bug.nid = 777
	rb.player.x = 60.0
	rb.player.y = 180.0
	rb.player.face = 1.0
	rb.player.bp_cd = 0.0
	if not rb.bp_apply("c", 777):
		fail(res, "the creature was not frozen")
	var hp_b: int = rb.player.hp
	rb.player.x = bug.x
	rb.player.y = bug.y
	for f in range(30):
		step_keys(rb, {})
	if rb.player.hp != hp_b:
		fail(res, "a frozen creature hurt")
	rb.player.x = bug.x + 1.0
	rb.player.y = bug.y - 40.0
	rb.player.vy = 0.0
	var stood := false
	for f in range(60):
		step_keys(rb, {})
		if rb.player.y + rb.player.h <= bug.y + 2.0 and rb.player.y + rb.player.h >= bug.y - 2.0 and rb.player.on_ground:
			stood = true
	if not stood:
		fail(res, "a player could not stand on a frozen creature (y %.1f, bug %.1f)" % [rb.player.y, bug.y])
	var rec: Array = JSON.parse_string(JSON.stringify(NetClasses.record(bug)))
	var pup = NetClasses.make(NetClasses.cls_of(bug), rb)
	NetClasses.apply(pup, rec)
	if absf(pup.bp_t - bug.bp_t) > 0.011 or absf(pup.bp_off - bug.bp_off) > 0.011 or pup.bp_t <= 0.0:
		fail(res, "the freeze is not in the creature's record (%.2f / %.2f)" % [pup.bp_t, pup.bp_off])
	pup.free()
	rb.queue_free()
	# 5. a ring in reach takes priority over a piston in reach, and a tap that stops something does not cast agents
	Game.tools.curl = true
	Game.tools.agents = true
	var rr := clean_room("TC2", 0.0, 0.0)
	var pz2: Dictionary = rr.tower.pistons[0]
	rr.player.x = float(pz2.x * 16 + 19)
	rr.player.y = float(37 * 16 - 10)
	rr.player.face = 1.0
	rr.player.meter = float(Game.METER_MAX)
	rr.rings.append({"x": rr.player.x + 40.0, "y": rr.player.y - 10.0})
	step_keys(rr, {"special": true})
	if rr.player.zip < 0 or rr.tower.fz.size() > 0:
		fail(res, "the ring did not win over the piston (zip %d, frozen %d)" % [rr.player.zip, rr.tower.fz.size()])
	rr.queue_free()
	var ra := clean_room("TC2", 0.0, 0.0)
	var pz3: Dictionary = ra.tower.pistons[0]
	ra.player.x = float(pz3.x * 16 + 19)
	ra.player.y = float(37 * 16 - 10)
	ra.player.face = 1.0
	step_keys(ra, {})                                          # (release: a press needs a new edge)
	ra.player.meter = float(Game.METER_MAX)
	step_keys(ra, {"special": true})
	step_keys(ra, {})
	step_keys(ra, {})
	if ra.tower.fz.size() != 1 or ra.player.agents_t > 0.0 or ra.player.meter < float(Game.METER_MAX) - 0.5:
		fail(res, "a breakpoint tap with a full meter cast agents (frozen %d, agents %.1f)" % [ra.tower.fz.size(), ra.player.agents_t])
	ra.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("breakpoint", res.ok, res.info)

func run_for(r: Room, secs: float, keys := {}) -> void:
	for f in range(int(secs * 60.0)):
		step_keys(r, keys)
		r.player.inv = 99.0

# MV5A-05: the seven native enemies of the tower
func t_w4enemies() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	# HEISENBUG: looked at it freezes, looked away from it flies at the player
	var r := bare_room("R01", 100.0, 192.0)
	var hb := Heisenbug.new(r, 160, 176)
	r.add_entity(hb)
	r.player.face = 1.0                                     # looks away (the bug is to its right: facing it is +1) -> set below
	r.player.x = 100.0
	r.player.face = 1.0
	run_for(r, 0.5)
	if not hb.observed:
		fail(res, "a bug in front of the player is not observed")
	var hx0 := hb.x
	run_for(r, 1.0)
	if absf(hb.x - hx0) > 0.5:
		fail(res, "an observed heisenbug moved")
	r.player.x = 100.0
	r.player.face = -1.0
	var came := false
	for f in range(60):
		r.player.face = -1.0
		step_keys(r, {})
		r.player.inv = 99.0
		r.player.x = 100.0
		r.player.y = 192.0
		if hb.x < hx0 - 20.0 and not hb.observed:
			came = true
	if not came:
		fail(res, "a heisenbug did not come at a player looking away (x %.0f -> %.0f)" % [hx0, hb.x])
	var rec_h := NetClasses.record(hb)
	if rec_h.size() != 9 + 2 + 3:
		fail(res, "heisenbug record size %d" % rec_h.size())
	r.queue_free()
	# DATA RACE: a lone hit rolls back, two hits inside 0.5 s commit
	var r2 := bare_room("R01", 20.0, 192.0)
	var a := DataRace.new(r2, 200, 192, false)
	var b := DataRace.new(r2, 264, 192, true)
	a.pair_with(b)
	r2.add_entity(a)
	r2.add_entity(b)
	var hp0: int = a.hp
	a.hit(1, 1.0, 0.0, "swipe", a)
	run_for(r2, 0.7)
	if a.hp != hp0 or b.hp != hp0 or a.pend_d != 0:
		fail(res, "a lone hit on a twin did not roll back (hp %d/%d pend %d)" % [a.hp, b.hp, a.pend_d])
	a.hit(1, 1.0, 0.0, "swipe", a)
	b.hit(1, 1.0, 0.0, "swipe", b)
	if a.hp != hp0 - 2 or b.hp != hp0 - 2:
		fail(res, "two hits inside the window did not commit (hp %d/%d)" % [a.hp, b.hp])
	var mx0 := a.cx + b.cx
	run_for(r2, 1.0)
	if absf((a.cx + b.cx) - mx0) > 3.0 or absf(a.cx - 200.0) < 4.0:
		fail(res, "the twins do not mirror (sum moved %.1f)" % (a.cx + b.cx - mx0))
	r2.queue_free()
	# DEADLOCK pair: linked guards block, a player on the line breaks the chain
	var r3 := bare_room("R01", 20.0, 192.0)
	var g1 := DeadlockGuard.new(r3, 200, 192, false)
	var g2 := DeadlockGuard.new(r3, 296, 192, true)
	g1.pair_with(g2)
	r3.add_entity(g1)
	r3.add_entity(g2)
	run_for(r3, 0.3)
	if not g1.linked or g1.hit(1, 1.0, 0.0, "swipe", g1) != "block":
		fail(res, "a linked guard took a hit")
	r3.player.x = 250.0
	r3.player.y = 192.0
	for f in range(10):
		r3.player.x = 250.0
		r3.player.y = 190.0
		step_keys(r3, {})
		r3.player.inv = 99.0
	if g1.linked or g1.hit(1, 1.0, 0.0, "swipe", g1) == "block":
		fail(res, "a player on the line did not break the chain")
	r3.queue_free()
	# SPINLOCK: hittable only on its stop tick, dashes 48 px out the tick after
	var r4 := bare_room("T04", 20.0, 20.0)
	var sp := Spinlock.new(r4, 8 * 16, 8 * 16)
	r4.add_entity(sp)
	var hittable := []
	var max_out := 0.0
	var base_c := Vector2(sp.base)
	for k in range(8):
		r4.time = Tower.TICK * (float(k) + 0.5)
		sp.update(0.0)
		hittable.append(sp.stopped_now())
		max_out = maxf(max_out, Vector2(sp.cx, sp.cy).distance_to(base_c))
		if k % 4 == 0:
			r4.time = Tower.TICK * (float(k) + 0.5)
			sp.update(0.0)
			if Vector2(sp.cx, sp.cy).distance_to(base_c) < 40.0:
				fail(res, "the spinlock did not dash out on tick %d" % k)
	if hittable != [false, false, false, true, false, false, false, true] or max_out < 44.0 or max_out > 50.0:
		fail(res, "spinlock stop ticks %s, out %.1f" % [str(hittable), max_out])
	r4.time = Tower.TICK * 3.5
	if sp.hit(1, 1.0, 0.0, "swipe", sp) == "block":
		fail(res, "a stopped spinlock blocked a claw")
	r4.time = Tower.TICK * 1.5
	if sp.hit(1, 1.0, 0.0, "swipe", sp) != "block":
		fail(res, "a spinning blade took a claw")
	r4.queue_free()
	# TICKER: one cell per tick, turns at an edge, hops every 4th tick
	var r5 := bare_room("R01", 20.0, 192.0)
	var tk := Ticker.new(r5, 20 * 16, 12 * 16)
	r5.add_entity(tk)
	var cells := []
	for k in range(6):
		r5.time = Tower.TICK * (float(k) + 0.9)
		tk.update(0.0)
		cells.append(tk.cell_x)
	var diffs := []
	for i in range(1, cells.size()):
		diffs.append(absi(int(cells[i]) - int(cells[i - 1])))
	for dv_ in diffs:
		if dv_ > 1:
			fail(res, "the ticker moved more than a cell in a tick: %s" % str(cells))
			break
	if cells[0] == cells[5]:
		fail(res, "the ticker did not move: %s" % str(cells))
	r5.queue_free()
	# ORPHAN: the children orbit; once the parent is dead they dash at the player
	var r6 := bare_room("R01", 20.0, 192.0)
	var grp := r6.spawn_group("+", 200, 192)
	for e in grp:
		r6.add_entity(e)
	var par: Orphan = grp[0]
	var kid: OrphanChild = grp[1]
	run_for(r6, 0.5)
	var orbit_d: float = Vector2(kid.cx - par.cx, kid.cy - par.cy).length()
	if absf(orbit_d - 18.0) > 2.5 or kid.orphan:
		fail(res, "a child is not orbiting (distance %.1f)" % orbit_d)
	par.hit(99, 1.0, 0.0, "swipe", par)
	run_for(r6, 0.2)
	if not kid.orphan:
		fail(res, "the children did not become orphans")
	var dashed := false
	for f in range(150):
		step_keys(r6, {})
		r6.player.inv = 99.0
		if kid.state == "dash":
			dashed = true
	if not dashed:
		fail(res, "an orphan never dashed")
	r6.queue_free()
	# PRIORITY INVERSION: asleep freezes a ticker 100 px away; a hit wakes both
	var r7 := bare_room("R01", 20.0, 192.0)
	var pi_ := PriorityInversion.new(r7, 220, 176)
	var tk2 := Ticker.new(r7, 320, 192)
	r7.add_entity(pi_)
	r7.add_entity(tk2)
	run_for(r7, 0.5)
	if tk2.bp_t <= 0.0 or tk2.bp_k != 2:
		fail(res, "a sleeping priority did not freeze a ticker near it")
	if not pi_.harmboxes().is_empty():
		fail(res, "a sleeping giant hurts")
	pi_.hit(1, 1.0, 0.0, "swipe", pi_)
	run_for(r7, 0.6)
	if not pi_.awake or tk2.bp_t > 0.0:
		fail(res, "a hit did not wake the giant and its neighbours (awake %s, frozen %.2f)" % [pi_.awake, tk2.bp_t])
	run_for(r7, 7.0)
	if pi_.awake:
		fail(res, "the giant did not fall asleep again")
	r7.queue_free()
	# parity of the records for every new class
	var rp := bare_room("R01", 20.0, 192.0)
	for ch in ["(", "[", "]", ")", "{", "+", "}"]:
		var list: Array = rp.spawn_group(ch, 200, 192) if ch in ["[", "]", "+"] else [rp.spawn_enemy(ch, 200, 192)]
		for e in list:
			rp.add_entity(e)
			var rec: Array = JSON.parse_string(JSON.stringify(NetClasses.record(e)))
			var pup = NetClasses.make(NetClasses.cls_of(e), rp)
			if pup == null:
				fail(res, "no puppet class for %s" % ch)
				continue
			NetClasses.apply(pup, rec)
			if JSON.stringify(pup.net_fields()) != JSON.stringify(e.net_fields()):
				fail(res, "%s: fields differ %s vs %s" % [ch, str(pup.net_fields()), str(e.net_fields())])
			pup.free()
	rp.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("w4enemies", res.ok, res.info)

# runs a room until the boss's plan reaches `ph` (or `max_f` frames pass); the player stays where it was put, the boss does not start another attack
func rb_until(r: Room, b, id: String, ph: String, keep: Vector2, max_f := 700) -> bool:
	for f in range(max_f):
		r.player.inv = 99.0
		r.player.hp = r.player.max_hp
		r.player.x = keep.x
		r.player.y = keep.y
		r.player.vx = 0.0
		r.player.vy = 0.0
		r.step(Game.STEP)
		b.idle_t = 999.0
		if not b.plan.is_empty() and String(b.plan.id) == id and String(b.plan.ph) == ph:
			return true
	return false

func start_fight(r: Room, px := 100.0) -> bool:
	r.player.x = px
	r.player.y = 150.0
	var n := 0
	while r.fight.state != "active" and n < 400:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	return r.fight.state == "active"

# MV5A-06: RACE CONDITION
func t_raceboss() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var r := new_room("T06")
	var b: RaceBoss = r.boss as RaceBoss
	if b == null:
		fail(res, "T06 has no RaceBoss")
		r.queue_free()
		return report("raceboss", false, res.info)
	if b.max_hp != 90 or b.th[0].hp != 45.0 or b.th[1].hp != 45.0:
		fail(res, "hp %d (%s/%s), want 45 + 45" % [b.max_hp, str(b.th[0].hp), str(b.th[1].hp)])
	if not start_fight(r):
		fail(res, "the fight never started")
	b.plan = {}
	b.idle_t = 999.0
	r.attacker = r.player
	# 1. the write lands on the READ position, not the current one
	r.player.x = 100.0
	b._start("rw")
	var read_x: float = b.gx[int(b.plan.a_i)]
	if absf(read_x - 105.0) > 12.0:
		fail(res, "the ghost is at %.0f, the player at 105" % read_x)
	if not rb_until(r, b, "rw", "active", Vector2(330.0, 150.0)):
		fail(res, "the write never came")
	var on_ghost := false
	var on_player := false
	var hb: Dictionary = r.player.hurtbox()
	for bx in b.harmboxes():
		if absf(float(bx.x) + 16.0 - read_x) < 1.0:
			on_ghost = true
		if Game.overlap(bx, {"x": 330.0, "y": 150.0, "w": 8.0, "h": 9.0}):
			on_player = true
	if not on_ghost or on_player:
		fail(res, "write boxes: on the ghost %s, on the player's new place %s" % [on_ghost, on_player])
	b.plan = {}
	b.gx = [-1.0, -1.0]
	# 2. two writes into one segment within 4 s corrupt it: a warning, then the floor band hurts
	r.time = 50.0
	b._paint(0, 100.0)
	b._paint(1, 110.0)
	if b.hz.size() != 1:
		fail(res, "no corrupt segment (%d)" % b.hz.size())
	else:
		if not b.hz_all_boxes(50.3).is_empty() or b.hz_all_boxes(50.7).size() != 1:
			fail(res, "the corrupt segment hurts too early or never")
		var hzb: Dictionary = b.hz_all_boxes(50.7)[0]
		if absf(float(hzb.y) - (Boss.FLOOR - 6.0)) > 0.1 or absf(float(hzb.w) - 48.0) > 0.1:
			fail(res, "the corrupt band is %s" % str(hzb))
	b.hz.clear()
	r.time = 70.0
	b._paint(0, 200.0)
	r.time = 76.0
	b._paint(1, 205.0)
	if not b.hz.is_empty():
		fail(res, "writes 6 s apart corrupted a segment")
	# at most 4 at once
	r.time = 90.0
	for sg in range(6):
		b._paint(0, 20.0 + float(sg) * 48.0)
		b._paint(1, 25.0 + float(sg) * 48.0)
	if b.hz.size() != 4:
		fail(res, "%d corrupt segments, at most 4" % b.hz.size())
	# 3. the lock serializes (one writer, corrupt segments clear) and then rests 10 s
	if b._lock_hit() != "hit" or b.serial_t <= 0.0 or not b.hz.is_empty():
		fail(res, "the lock did not serialize and clear (serial %.1f, hz %d)" % [b.serial_t, b.hz.size()])
	b._start("rw")
	var ghosts := 0
	for gv in b.gx:
		if gv >= 0.0:
			ghosts += 1
	if ghosts != 1:
		fail(res, "serialized: %d ghosts, want 1" % ghosts)
	b.plan = {}
	b.gx = [-1.0, -1.0]
	b.serial_t = 0.05
	b.update(0.1)
	if b.lock_cd < 9.0 or b._lock_hit() != "block":
		fail(res, "the lock has no cooldown (%.1f)" % b.lock_cd)
	b.lock_cd = 0.0
	# 4. contend: both dash through the lock; when they meet they stun each other for 2 s
	b.th[0].x = 130.0
	b.th[1].x = 286.0
	b._start("contend")
	var stunned := false
	if rb_until(r, b, "contend", "active", Vector2(40.0, 150.0)):
		for f in range(60):
			r.player.inv = 99.0
			r.player.x = 40.0
			r.player.y = 150.0
			r.step(Game.STEP)
			if b.th[0].stun > 1.0 and b.th[1].stun > 1.0:
				stunned = true
				break
	if not stunned:
		fail(res, "the threads did not stun each other on meeting")
	b.plan = {}
	for q in b.th:
		q.stun = 0.0
		q.y = Boss.FLOOR
	# 5. rule 8: the ghost goes to the player who moved least
	var rp := partner(r, 300.0, 150.0)
	rp.samples.clear()
	for f in range(14):
		r.player.x = 80.0 + float(f) * 6.0
		b._track(0.11)
		rp.x = 300.0
		b._track(0.0)
	b.mv_acc = 0.2
	b._track(0.0)
	var least := b._least_moved()
	if least != "p2" and rp.get_parent() != null:
		fail(res, "the ghost goes to %s, the moving player is p1" % least)
	r.remote_players.erase(rp)
	rp.queue_free()
	# 6. the last thread alive is enraged: cues x0.85, never below 0.70 for the big write
	b.th[0].hp = 0.5
	b.th[0].hp = 0.5
	r.attacker = r.player
	b.hit(1, 1.0, 0.0, "swipe", {"x": b.th[0].x - 8.0, "y": b.th[0].y - 24.0, "w": 16.0, "h": 24.0, "head": 0})
	if not b.th[0].dead or b._enr() != 0.85:
		fail(res, "thread A did not die or B is not enraged")
	b.plan = {}
	b._start("rw")
	if float(b.plan.t) < 0.70 or absf(float(b.plan.t) - 0.765) > 0.01:
		fail(res, "enraged cue %.3f, want 0.765" % float(b.plan.t))
	b.plan = {}
	b.gx = [-1.0, -1.0]
	# 7. net fields: a puppet built from the record has the same boxes and plan
	b.th[0].dead = false
	b.th[0].hp = 20.0
	b._sums()
	b.plan = {}
	b._start("rw")
	rb_until(r, b, "rw", "active", Vector2(330.0, 150.0))
	var rec: Array = JSON.parse_string(JSON.stringify(NetClasses.record(b)))
	var pup = NetClasses.make(NetClasses.cls_of(b), r)
	NetClasses.apply(pup, rec)
	if not same_boxes(b.harmboxes(), pup.harmboxes()) or not same_boxes(b.hurtboxes(), pup.hurtboxes()):
		fail(res, "the puppet's boxes differ from the host's")
	var fa: Array = JSON.parse_string(JSON.stringify(pup.net_fields()))
	var fb: Array = JSON.parse_string(JSON.stringify(b.net_fields()))
	if JSON.stringify(fa) != JSON.stringify(fb):
		var which := []
		for i in range(mini(fa.size(), fb.size())):
			if JSON.stringify(fa[i]) != JSON.stringify(fb[i]):
				which.append("%d:%s/%s" % [i, JSON.stringify(fa[i]).left(30), JSON.stringify(fb[i]).left(30)])
		fail(res, "the puppet's fields differ %s" % str(which))
	pup.free()
	# 8. the kill gives breakpoint and opens T06:E
	b.plan = {}
	var i0 := 0
	r.attacker = r.player
	if not r.skip_boss():
		fail(res, "skip boss did not work")
	var guard := 0
	while r.fight.state != "done" and guard < 900:
		r.player.inv = 99.0
		r.step(Game.STEP)
		guard += 1
	if r.fight.state != "done" or not Game.tools.get("breakpoint", false) or not Game.flag("boss:RACE"):
		fail(res, "the reward: state %s, breakpoint %s" % [r.fight.state, str(Game.tools.get("breakpoint", false))])
	r.update_doors()
	var de = r.grid.door_at("E", 8)
	if de == null or not de.open:
		fail(res, "T06:E stays closed after the fight")
	r.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("raceboss", res.ok, res.info)
