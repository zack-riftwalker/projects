extends Tests4b3
class_name Tests5a
# Unit tests of phase 5A (THREAD TOWER). run_tests.gd hands names it does not know to run().

const NAMES5 := ["rooms5a", "w4assets", "tick5a", "breakpoint", "w4enemies", "race3", "loopboss", "deadlockboss", "plugins5a", "tower4b1"]

func run(name: String):
	match name:
		"rooms5a": return await t_rooms5a()
		"w4assets": return await t_w4assets()
		"tick5a": return await t_tick5a()
		"breakpoint": return await t_breakpoint()
		"w4enemies": return await t_w4enemies()
		"race3": return await t_race3()
		"loopboss": return await t_loopboss()
		"deadlockboss": return await t_deadlockboss()
		"plugins5a": return await t_plugins5a()
		"tower4b1": return await t_tower4b1()
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
	await walk5a(res)
	Game.fresh()
	return report("rooms5a", res.ok, "%d tower rooms%s" % [ids.size(), res.info])

# MV5A-10 (1): through every tower door that can open, the way a player goes: the next room, a body on free ground; the fork/join, the yield chute, the goto drop
func walk5a(res: Dictionary) -> void:
	Game.flags = {}
	for f in ["lever:T02", "thread:0", "thread:1", "thread:2", "boss:RACE", "boss:LOOP", "break:T09", "boss:DEADLOCK"]:
		Game.flags[f] = true
	Game.tools = {"bash": true, "catch": true, "sudo": true, "agents": true, "opus": true, "curl": true, "ssh": true, "breakpoint": true}
	var crows := FileAccess.get_file_as_string("res://src/world/rooms/TB1.txt").split("\n")
	for cy in range(crows.size()):                               # TB1's cracked wall to heisenbug.log is bashed through
		for cx in range(crows[cy].length()):
			if crows[cy][cx] == "%":
				Game.flags["crack:TB1:%d:%d" % [cx, cy]] = true
	var m := new_manager()
	var crossed := 0
	var ids: Array = tower_ids()
	ids.append("H11")
	ids.append("N11")
	for rid in ids:
		var def: Dictionary = Game.rooms_meta.rooms[rid]
		for d in def.doors:
			var to_room := String(d.to).get_slice(":", 0)
			var lock := String(d.get("lock", ""))
			if not Game.rooms_meta.rooms.has(to_room) or lock == "oneway" or bool(d.get("wrap", false)):
				continue
			if rid == "H11" and d.id != "H11:N":
				continue
			if rid == "N11" and d.id != "N11:W":
				continue
			var pw: float = float(def.size[0]) * 16.0
			var ph: float = float(def.size[1]) * 16.0
			var wait := 0
			while m.trans.on and wait < 60:
				m.tick(Game.STEP)
				wait += 1
			m.swap_to(rid, Vector2(pw / 2.0, ph / 2.0), null, true)
			m.room.ents.clear()
			m.room.update_doors()
			for ty in range(int(d.a), int(d.b) + 1):                 # (a cracked wall at the door: the player has bashed it by now)
				for tx in range(m.room.w):
					if (String(d.side) == "W" or String(d.side) == "E") and m.room.grid.tile(tx, ty) == TileGrid.CRACK:
						m.room.grid.tiles[ty * m.room.w + tx] = TileGrid.E
			var q = m.player
			var side := String(d.side)
			var mid_row := float(int(d.a) + int(d.b) + 1) * 8.0
			var keys := {}
			q.vx = 0.0
			q.vy = 0.0
			match side:
				"W":
					q.x = 2.0
					q.y = float(int(d.b) + 1) * 16.0 - q.h
					keys = {"left": true}
				"E":
					q.x = pw - q.w - 2.0
					q.y = float(int(d.b) + 1) * 16.0 - q.h
					keys = {"right": true}
				"N":
					q.x = mid_row - q.w / 2.0
					q.y = 2.0
					q.vy = -300.0
				"S":
					q.x = mid_row - q.w / 2.0
					q.y = ph - q.h - 2.0
					q.vy = 200.0
			var got := -1
			var trail := ""
			for f in range(60):
				Controls.script_input = keys
				m.player.hp = m.player.max_hp
				m.player.inv = 99.0
				m.tick(Game.STEP)
				if trail.get_slice(" ", trail.count(" ")) != m.room.id:
					trail += " " + m.room.id
				if m.room.id == to_room and not m.trans.on:
					got = f
					break
			Controls.script_input = null
			if got < 0:
				fail(res, "door %s: still in %s after 60 frames (player %.0f,%.0f, in %s -> %s, trans %s, trail%s)" % [d.id, m.room.id, m.player.x, m.player.y, rid, to_room, str(m.trans.on), trail])
				continue
			crossed += 1
			m.player.vx = 0.0
			for f in range(4):
				m.tick(Game.STEP)
			var b = m.player
			var inside := false
			for ty in range(floori(b.y / 16.0), floori((b.y + b.h - 0.01) / 16.0) + 1):
				for tx in range(floori(b.x / 16.0), floori((b.x + b.w - 0.01) / 16.0) + 1):
					if m.room.grid.solid(tx, ty):
						inside = true
			if inside or (m.room.hazard_at(b) != "" and m.room.hazard_at(b) != "pit"):
				fail(res, "door %s: the body arrived in a wall or a hazard (%s)" % [d.id, m.room.hazard_at(b)])
	res.info += " doors %d" % crossed
	if crossed < 30:
		fail(res, "only %d tower doors crossed" % crossed)
	# the fork/join: two of the three threads open T04's way up, one does not
	Game.flags = {"thread:0": true}
	var t04 := new_room("T04")
	var dn = t04.grid.door_at("N", 59)
	if dn == null or dn.open:
		fail(res, "T04:N2 is open with one thread")
	t04.queue_free()
	Game.flags = {"thread:0": true, "thread:1": true}
	var t04b := new_room("T04")
	var dn2 = t04b.grid.door_at("N", 59)
	if dn2 == null or not dn2.open:
		fail(res, "T04:N2 is shut with two threads")
	t04b.queue_free()
	Game.flags = {"thread:0": true, "thread:2": true}
	var t04c := new_room("T04")
	var dn3 = t04c.grid.door_at("N", 11)
	if dn3 == null or not dn3.open:
		fail(res, "T04:N is shut with threads 0 and 2")
	t04c.queue_free()
	# the yield chute: a body in T04's yield shaft ends up in T02, standing
	Game.flags = {}
	m.swap_to("T04", Vector2(41.0 * 16.0 + 3.0, 14.0 * 16.0), null, true)
	m.room.ents.clear()
	var landed := false
	for f in range(1800):
		m.player.inv = 99.0
		m.player.hp = m.player.max_hp
		if m.room.id == "T17":
			m.room.ents.clear()
		m.tick(Game.STEP)
		if m.room.id == "T02" and not m.trans.on and m.player.on_ground:
			landed = true
			break
	if not landed:
		fail(res, "the yield chute: ended in %s (on ground %s)" % [m.room.id, str(m.player.on_ground)])
	# the goto drop: T16 -> N11 -> the airgap fall -> N01
	m.swap_to("T16", Vector2(11.0 * 16.0 + 3.0, 88.0 * 16.0), null, true)
	m.room.ents.clear()
	var ended := false
	for f in range(3000):
		m.player.inv = 99.0
		m.player.hp = m.player.max_hp
		if m.room.id == "T16" or m.room.id == "N11":
			m.room.ents.clear()
		m.tick(Game.STEP)
		if m.room.id == "N11" and not m.trans.on and m.player.on_ground:
			ended = true                                          # (from there it is the airgap fall: rooms4b walks it)
			break
	if not ended:
		fail(res, "the goto drop: ended in %s" % m.room.id)
	m.queue_free()
	await frames(1)

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
		rb.time = rb.tick_len() * 1.5                                # an odd tick: `1` is off
		rb.tower.step(0.0, [])
		if rb.grid.solid(ga.tx, ga.ty):
			fail(res, "a `1` block is solid on an odd tick")
		rb.player.x = float(ga.tx * 16 + 3)
		rb.player.y = float(ga.ty * 16 + 3)
		rb.player.vx = 0.0
		rb.player.vy = 0.0
		rb.time = rb.tick_len() * 2.2                                # the next even tick: `1` would turn on under the body
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

# ---------------------------------------------------------------- RACE CONDITION v3 (docs/metroidvania/17-race-build.md): race3 grows with every milestone
func race_setup() -> void:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"

# a scripted hop: the player stands at `from` (feet), runs toward the target, holds jump `hold` frames, dashes at frame `dash_at` (towards the target, up when `up`),
# then waits to land. True when it ends standing on the target's top (x inside its width). `min_d` collects the closest the body came to `near` (for a curl pop)
func race_hop(r: Room, from: Vector2, target: Rect2, hold: int, dash_at: int, up: bool) -> bool:
	var p = r.player
	p.x = from.x - p.w * 0.5
	p.y = from.y - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.inv = 99.0
	var dir := "right" if target.get_center().x > from.x else "left"
	var done := false
	for f in range(110):
		var keys := {dir: true}
		if f < hold:
			keys["jump"] = true
		if dash_at >= 0 and f == dash_at:
			keys["dash"] = true
			if up:
				keys["up"] = true
		step_keys(r, keys)
		p.inv = 99.0
		if p.on_ground and f > 4 and absf(p.y + p.h - target.position.y) < 2.5 and p.x + p.w * 0.5 >= target.position.x and p.x + p.w * 0.5 <= target.end.x:
			done = true
			break
	return done

func race_reach(r: Room, from: Vector2, target: Rect2) -> bool:
	for hold in [10, 14, 18, 22, 26, 30, 40]:
		for dash_at in [-1, 6, 12, 18, 24, 30, 36]:
			for up in [false, true]:
				if up and dash_at < 0:
					continue
				if race_hop(r, from, target, hold, dash_at, up):
					return true
	return false

# a curl from a bell to the ring above it, then a dash at the bob: how close the body gets to the bob's rest place (claw 24 + body 5 + bob 9 = 38 px is a hit)
func race_bob_try(r: Room, from: Vector2, toward: String, dash_after: int, up: bool) -> float:
	var p = r.player
	p.x = from.x - p.w * 0.5
	p.y = from.y - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.zip = -1
	p.inv = 99.0
	var bob := BelfryHall.PIVOT + Vector2(0.0, BelfryHall.ROD)
	var best := 1e9
	var arrived := -1
	var was_zip := false
	for f in range(70):
		var keys := {}
		if f == 0:
			keys["special"] = true
		if toward != "":
			keys[toward] = true
		if p.zip >= 0:
			was_zip = true
		if was_zip and p.zip < 0 and arrived < 0:
			arrived = f
		if arrived >= 0 and f == arrived + dash_after:
			keys["dash"] = true
			if up:
				keys["up"] = true
		step_keys(r, keys)
		p.inv = 99.0
		best = minf(best, Vector2(p.x + p.w * 0.5, p.y + p.h * 0.5).distance_to(bob))
	return best

func race_bob_reach(r: Room, from: Vector2, toward: String) -> float:
	var best := 1e9
	for da in [0, 2, 4, 6, 9, 12, 16, 20]:
		for up in [false, true]:
			best = minf(best, race_bob_try(r, from, toward, da, up))
	return best

func race_plat(r: Room, i: int) -> Rect2:
	var m: Dictionary = r.belfry.pool[i]
	return Rect2(float(m.x), float(m.y), float(m.w), 6.0)

# MV5A-06 / 17-race-build.md: RACE CONDITION
func t_race3() -> bool:
	race_setup()
	var res := checker()
	var info := ""
	# --- M1 -------------------------------------------------------------------------------------------------------------
	# 1. the map: 26 x 30 (it grows upward), doors on rows 23..26, the hall named, the ticks per room
	var md: Dictionary = Game.rooms_meta.rooms.T06
	if int(md.size[0]) != 26 or int(md.size[1]) != 30 or int(md.origin[0]) != 1164 or int(md.origin[1]) != -166 or String(md.get("hall", "")) != "belfry":
		fail(res, "T06 size %s origin %s hall %s" % [str(md.size), str(md.origin), str(md.get("hall", ""))])
	for d in md.doors:
		if int(d.a) != 23 or int(d.b) != 26:
			fail(res, "door %s rows %d..%d, want 23..26" % [d.id, int(d.a), int(d.b)])
	Game.tools = {"bash": true, "catch": false, "sudo": false, "agents": false, "opus": false, "curl": true, "ssh": false}       # what the player surely has (curl: nobody reaches the tower without it)
	var trig: float = float(md.boss.trigger_x)
	md.boss["trigger_x"] = 1e9                              # (the intro must not freeze the players while the arena is measured)
	var r := new_room("T06")
	md.boss["trigger_x"] = trig
	if r.pw != 416 or r.ph != 480 or r.belfry == null:
		fail(res, "T06 is %d x %d, belfry %s" % [r.pw, r.ph, str(r.belfry)])
		r.queue_free()
		return report("race3", false, res.info)
	var hl: BelfryHall = r.belfry
	if r.grid.door_at("W", 24) == null or r.grid.door_at("E", 24) == null or r.grid.door_at("W", 8) != null:
		fail(res, "the doors are not on rows 23..26")
	for c in [0, 13, 25]:
		if not r.grid.solid(c, 27) or not r.grid.solid(c, 29) or r.grid.solid(13, 26):
			fail(res, "the floor is not rows 27..29")
	# 2. the bells are five platforms with the plan's tops, widths and notes
	var want_tops := [384.0, 384.0, 336.0, 272.0, 272.0]
	var want_w := [80.0, 80.0, 64.0, 48.0, 48.0]
	var bells := r.plats.filter(func(m): return m.has("bell"))
	if bells.size() != 5:
		fail(res, "%d bells in plats" % bells.size())
	for i in range(mini(5, bells.size())):
		var rc := race_plat(r, i)
		if absf(rc.position.y - want_tops[i]) > 0.01 or absf(rc.size.x - want_w[i]) > 0.01:
			fail(res, "bell %d is at y %.0f w %.0f" % [i, rc.position.y, rc.size.x])
	# 3. routes without sudo and catch (bash, curl): floor -> bell 1/2 -> bell 3 -> bell 4/5; also with bells 3 and 4 fallen (phase 2's worst case)
	for e in r.ents:
		e.queue_free()
	r.ents.clear()
	var pairs := [["floor to bell 1", Vector2(24.0, 432.0), 0], ["floor to bell 2", Vector2(400.0, 432.0), 1], ["bell 1 to bell 3", Vector2(100.0, 384.0), 2],
		["bell 2 to bell 3", Vector2(316.0, 384.0), 2], ["bell 3 to bell 4", Vector2(184.0, 336.0), 3], ["bell 3 to bell 5", Vector2(232.0, 336.0), 4]]
	for pr in pairs:
		if not race_reach(r, pr[1], race_plat(r, int(pr[2]))):
			fail(res, "%s is out of reach" % pr[0])
	info += "routes ok; "
	# the bob (the lock): from bell 5 / bell 4 by curl to the ring and a dash
	var d5 := race_bob_reach(r, Vector2(280.0, 272.0), "left")
	var d4 := race_bob_reach(r, Vector2(136.0, 272.0), "right")
	if d5 > 38.0 or d4 > 38.0:
		fail(res, "the bob is out of reach from bell 5 (%.0f px) or bell 4 (%.0f px)" % [d5, d4])
	info += "bob %.0f/%.0f px; " % [d5, d4]
	# phase 2's worst case: two bells down. The middle bell (the climb) never falls in phase 2 and never both small ones: the way up always stays
	hl.ph = 2
	hl.p2_t0 = 0.0
	hl.step_host(r.time)
	r.time = 100.0
	var okf := 0
	for i in range(5):
		if hl.can_fall(i, r.time):
			okf += 1
	if hl.can_fall(2, r.time):
		fail(res, "bell 3 can fall in phase 2 (the climb is gone)")
	if not (hl.drop(0) and hl.drop(3)):
		fail(res, "bells 1 and 4 cannot fall together in phase 2")
	r.time = 110.0
	if hl.can_fall(4, r.time) or hl.can_fall(1, r.time):
		fail(res, "a third bell can fall in phase 2 (two down: %d)" % hl.fallen_count(r.time))
	r.step(Game.STEP)
	if not race_reach(r, Vector2(400.0, 432.0), race_plat(r, 1)) or not race_reach(r, Vector2(316.0, 384.0), race_plat(r, 2)) or not race_reach(r, Vector2(232.0, 336.0), race_plat(r, 4)):
		fail(res, "with bells 1 and 4 down the way up (floor, bell 2, bell 3, bell 5) is gone")
	var d5b := race_bob_reach(r, Vector2(280.0, 272.0), "left")
	if d5b > 38.0:
		fail(res, "with bells 1 and 4 down the bob is out of reach from bell 5 (%.0f px)" % d5b)
	r.queue_free()
	# 4. the hall's own rules on a fresh room (no player in the way)
	var r2 := new_room("T06")
	var h2: BelfryHall = r2.belfry
	r2.time = 10.0
	# the swing is a pure function: a strike at t0 with amp 4 gives dx = amp sin(2 pi age / 1.2) e^(-age / 0.8); a bell on a puppet copy agrees
	h2.strike(0)
	var dx := h2.swing_dx(0, 10.3)
	var want_dx := 4.0 * sin(TAU * 0.3 / 1.2) * exp(-0.3 / 0.8)
	if absf(dx - want_dx) > 0.001:
		fail(res, "swing dx %.4f, want %.4f" % [dx, want_dx])
	if absf(h2.swing_dx(0, 10.0)) > 0.001 or absf(h2.swing_dx(0, 20.0)) > 0.02:
		fail(res, "a bell does not start and end at rest")
	h2.strike(3)
	if absf(float(h2.amp[3]) - 5.0) > 0.001 or absf(float(h2.amp[0]) - 4.0) > 0.001:
		fail(res, "strike amplitudes %s / %s, want 5 (small) / 4 (big)" % [str(h2.amp[3]), str(h2.amp[0])])
	var pack := h2.net_pack()
	var r3 := new_room("T06")
	r3.time = 10.0
	r3.belfry.net_unpack(JSON.parse_string(JSON.stringify(pack)))               # (what the wire does to it)
	for k in range(20):
		var tt := 10.0 + float(k) * 0.13
		for i in range(5):
			var a := h2.bell_pose(i, tt)
			var b := r3.belfry.bell_pose(i, tt)
			if absf(float(a.x) - float(b.x)) > 0.0001 or absf(float(a.y) - float(b.y)) > 0.0001 or a.mode != b.mode:
				fail(res, "bell %d differs between host and a copy at %.2f" % [i, tt])
				break
	r3.queue_free()
	# crack -> rattle 0.8 s -> fall -> lie -> (phase 1) fade after 8.0 s -> a new bell lowers 1.5 s -> hangs again
	h2.reset()
	r2.time = 20.0
	if not h2.crack(2):
		fail(res, "bell 3 does not crack")
	var fdist := h2.fall_dist(2)
	var ft := h2.fall_time(2)
	if absf(fdist - 64.0) > 0.01 or absf(ft - sqrt(2.0 * 64.0 / 900.0)) > 0.0001:
		fail(res, "bell 3 falls %.1f px in %.3f s" % [fdist, ft])
	var modes := {}
	for tq in [[20.5, "crack"], [20.79, "crack"], [20.81, "fall"], [20.8 + ft - 0.02, "fall"], [20.8 + ft + 0.02, "lie"], [20.8 + ft + 7.9, "lie"], [20.8 + ft + 8.1, "fade"], [20.8 + ft + 8.6, "fade"]]:
		var mm := h2.bell_mode(2, float(tq[0]))
		if mm != tq[1]:
			fail(res, "bell 3 at %.2f is %s, want %s" % [tq[0], mm, tq[1]])
	r2.time = 20.8 + ft + 8.55
	h2.step_host(r2.time)
	if float(h2.rehang_t0[2]) < 0.0:
		fail(res, "the fallen bell was not re-hung after lying and fading")
	var rh0: float = h2.rehang_t0[2]
	if h2.bell_mode(2, rh0 + 0.7) != "rehang" or absf(float(h2.bell_pose(2, rh0 + 0.75).y) - lerpf(BelfryHall.BEAM_Y - BelfryHall.BODY_H, 336.0, 0.5)) > 0.01:
		fail(res, "the new bell does not lower from the beam over 1.5 s")
	if h2.bell_standable(2, rh0 + 0.7) or not h2.bell_standable(2, rh0 + 1.6):
		fail(res, "the new bell is standable too early or never")
	r2.time = rh0 + 1.6
	h2.step_host(r2.time)
	if h2.bell_mode(2, r2.time) != "hang" or float(h2.fall_t0[2]) >= 0.0 or h2.fallen[2]:
		fail(res, "the re-hung bell is not a plain hanging bell again")
	# at least 3 hang always: a third bell will not fall; a fallen bell in phase 1 is a one-way top at the floor
	h2.reset()
	r2.time = 50.0
	var ok1 := h2.crack(0)
	var ok2 := h2.crack(1)
	var ok3 := h2.crack(4)
	if not ok1 or not ok2 or ok3:
		fail(res, "two bells may fall, the third not (got %s %s %s)" % [str(ok1), str(ok2), str(ok3)])
	r2.time = 52.0
	h2.step_host(r2.time)
	if h2.hanging_count(r2.time) != 3 or not h2.fallen[0] or h2.bell_standable(0, 52.0) != true:
		fail(res, "two fallen bells: %d hang, fallen %s" % [h2.hanging_count(r2.time), str(h2.fallen)])
	h2.move_bells()
	var lm: Dictionary = h2.pool[0]
	if absf(float(lm.y) - 400.0) > 0.01 or lm.off:
		fail(res, "a lying bell's top is at %.1f (off %s), want 400 and standable in phase 1" % [float(lm.y), str(lm.off)])
	# 5. the buffer floor: both threads in one cell within 4 s -> a 0.6 s build-up, then a hurt band 6 s (phase 1; at most 4); phase 2: a hole 4 s (at most 2, never neighbours)
	h2.reset()
	r2.time = 60.0
	h2.paint(3, 0, 60.0)
	h2.paint(3, 1, 63.9)
	r2.time = 63.9
	h2.step_buffer(r2.time)
	if float(h2.corrupt_t0[3]) < 0.0:
		fail(res, "two writes within 4 s did not corrupt the cell")
	var c0: float = h2.corrupt_t0[3]
	if h2.corrupt_state(3, c0 + 0.3) != 1 or h2.corrupt_state(3, c0 + 0.7) != 2 or h2.corrupt_state(3, c0 + 6.5) != 2 or h2.corrupt_state(3, c0 + 6.7) != 0:
		fail(res, "corrupt timings: %d %d %d %d" % [h2.corrupt_state(3, c0 + 0.3), h2.corrupt_state(3, c0 + 0.7), h2.corrupt_state(3, c0 + 6.5), h2.corrupt_state(3, c0 + 6.7)])
	h2.paint(5, 0, 70.0)
	h2.paint(5, 1, 75.0)
	r2.time = 75.0
	h2.step_buffer(r2.time)
	if float(h2.corrupt_t0[5]) >= 0.0:
		fail(res, "writes 5 s apart corrupted a cell")
	h2.reset()
	r2.time = 80.0
	for c in range(7):
		h2.paint(c, 0, 80.0)
		h2.paint(c, 1, 80.5)
	h2.step_buffer(80.6)
	if h2.corrupt_count(80.7) != 4:
		fail(res, "%d corrupt cells at once, want at most 4" % h2.corrupt_count(80.7))
	h2.reset()
	h2.ph = 2
	r2.time = 90.0
	for c in [1, 2, 4, 6]:
		h2.paint(c, 0, 90.0)
		h2.paint(c, 1, 90.5)
	h2.step_buffer(90.6)
	if h2.hole_count(90.7) != 2 or h2.hole_state(1, 90.7) == 0 or h2.hole_state(2, 90.7) != 0 or h2.hole_state(4, 90.7) == 0:
		fail(res, "holes: %d open (cells 1 %d, 2 %d, 4 %d, 6 %d), want 1 and 4 only" % [h2.hole_count(90.7), h2.hole_state(1, 90.7), h2.hole_state(2, 90.7), h2.hole_state(4, 90.7), h2.hole_state(6, 90.7)])
	var hc0: float = h2.hole_t0[1]
	if h2.hole_state(1, hc0 + 0.3) != 1 or h2.hole_state(1, hc0 + 0.7) != 2 or h2.hole_state(1, hc0 + 4.5) != 2 or h2.hole_state(1, hc0 + 4.7) != 0:
		fail(res, "hole timings are not 0.6 s build-up and 4 s open")
	r2.time = hc0 + 1.0
	h2.apply()
	if r2.grid.solid(1 + 3, 27) or r2.grid.solid(1 + 3, 28) or not r2.grid.solid(1 + 3, 29) or not r2.grid.solid(1 + 3 * 5, 27):
		fail(res, "an open cell is not a 2-tile pit over row 29 (and its neighbours stay floor)")
	h2.clear_buffer()
	h2.apply()
	if not r2.grid.solid(4, 27) or h2.hole_count(r2.time) != 0:
		fail(res, "clearing the buffer did not close the holes")
	# 6. a lying bell in phase 2 is solid cover (2 tiles high), in phase 1 a one-way top
	h2.reset()
	h2.ph = 2
	r2.time = 120.0
	if not h2.drop(0):
		fail(res, "bell 1 cannot be dropped in phase 2")
	r2.time = 122.0
	h2.step_host(r2.time)
	h2.apply()
	if not r2.grid.solid(3, 25) or not r2.grid.solid(3, 26) or r2.grid.solid(3, 24):
		fail(res, "a fallen bell is not a 2-tile block in phase 2")
	if not h2.cover_between(Vector2(60.0, 420.0), Vector2(150.0, 420.0), r2.time):
		fail(res, "a fallen bell gives no cover")
	r2.queue_free()
	# 7. the tick per room and the beat clock of T06
	var want_tick := {"T01": 1.0, "T02": 1.0, "TB2": 0.7, "TA1": Tower.TICK, "TC2": Tower.TICK}
	Game.flags.erase("boss:RACE")
	for id in want_tick:
		var rt := new_room(id)
		if absf(rt.tick_len() - float(want_tick[id])) > 0.0001 or absf(rt.tower.tick - float(want_tick[id])) > 0.0001:
			fail(res, "%s ticks %.4f, want %.4f" % [id, rt.tick_len(), float(want_tick[id])])
		if rt.tick_i() != floori(rt.time / float(want_tick[id])):
			fail(res, "%s tick index" % id)
		rt.queue_free()
	Game.flags["boss:RACE"] = true
	for id in ["T01", "T02", "TB2", "TA1", "T06"]:
		var rt2 := new_room(id)
		if absf(rt2.tick_len() - Tower.TICK) > 0.0001:
			fail(res, "%s ticks %.4f after the fight, want 0.8333" % [id, rt2.tick_len()])
		rt2.queue_free()
	Game.flags.erase("boss:RACE")
	var r4 := new_room("T06")
	var h4: BelfryHall = r4.belfry
	if absf(h4.tick_len() - 0.7) > 0.0001:
		fail(res, "T06 ticks %.4f in phase 1, want 0.7" % h4.tick_len())
	r4.time = 10.0
	var i_before := h4.tick_i_at(10.0)
	h4.set_tick(0.6, 10.0)                                    # phase 2: from the next boundary on
	var tb := float(h4.segs[h4.segs.size() - 1][0])
	if tb < 10.0 or tb > 10.0 + 0.7 + 0.01 or absf(fposmod(tb, 0.7)) > 0.011 and absf(fposmod(tb, 0.7) - 0.7) > 0.011:
		fail(res, "the new length starts at %.3f, not on a 0.7 boundary after 10.0" % tb)
	if h4.tick_i_at(tb - 0.001) != h4.tick_i_at(tb) - 1 or h4.tick_i_at(10.0) != i_before:
		fail(res, "the tick index jumps at the length change")
	if h4.tick_f_at(tb + 0.3) < 0.49 or h4.tick_f_at(tb + 0.3) > 0.51 or h4.tick_i_at(tb + 0.65) != h4.tick_i_at(tb) + 1:
		fail(res, "the beat clock does not follow 0.6 s ticks after the change")
	r4.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("race3", res.ok, info + res.info)

# MV5A-07: INFINITE LOOP
func t_loopboss() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var r := new_room("T10")
	var b: LoopBoss = r.boss as LoopBoss
	if b == null:
		fail(res, "T10 has no LoopBoss")
		r.queue_free()
		return report("loopboss", false, res.info)
	if b.max_hp != 66:
		fail(res, "hp %d, want 66" % b.max_hp)
	if not start_fight(r):
		fail(res, "the fight never started")
	b.plan = {}
	b.idle_t = 999.0
	r.attacker = r.player
	# 1. only the tail takes damage
	b._start("lap")
	if not rb_until(r, b, "lap", "active", Vector2(192.0, 150.0)):
		fail(res, "the lap never became active")
	var hp0 := b.hpf
	var boxes := b.hurtboxes()
	if boxes.size() != 1 or not boxes[0].has("tail"):
		fail(res, "hurtboxes in a lap: %s" % str(boxes))
	if b.hit(1, 1.0, 0.0, "swipe", {"x": 0.0, "y": 0.0, "w": 12.0, "h": 12.0}) != "" or b.hpf != hp0:
		fail(res, "a hit that was not on the tail did damage")
	if b.hit(1, 1.0, 0.0, "swipe", boxes[0]) == "" or b.hpf >= hp0:
		fail(res, "a tail hit did no damage")
	# 2. the attacks always come in the order lap, nested, recursion, rest
	var order := []
	b.plan = {}
	b.cycle = 0
	for k in range(8):
		b.plan = {}
		b._choose()
		order.append(String(b.plan.id))
	if order != ["lap", "nested", "recursion", "rest", "lap", "nested", "recursion", "rest"]:
		fail(res, "order " + str(order))
	# 3. every iteration is 15 % faster; the head covers speed x 1 s
	b.plan = {}
	b.iter = 0
	b.spd = b._speed_k()
	b.mode = "lap"
	b.path_t = 0.0
	var h0: Vector2 = b.seg_points()[0]
	b.path_t = 0.5
	var h1: Vector2 = b.seg_points()[0]
	var d0 := h0.distance_to(h1)
	b.iter = 1
	b.spd = b._speed_k()
	b.path_t = 0.0
	var g0: Vector2 = b.seg_points()[0]
	b.path_t = 0.5
	var g1: Vector2 = b.seg_points()[0]
	var d1 := g0.distance_to(g1)
	if absf(d1 / d0 - 1.15) > 0.01 or absf(d0 - 75.0) > 1.0:
		fail(res, "iteration speed: %.1f then %.1f px in 0.5 s" % [d0, d1])
	# the extras from i = 2: a fourth copy, the inner ring turns the other way, a head lunge
	b.iter = 2
	b.spd = b._speed_k()
	b.mode = "recursion"
	b.path_t = 3.0
	var back_low := false
	for segs in b.copies():
		if absf(segs[0].y - 170.0) < 1.0 and segs[0].x > segs[1].x:
			back_low = true
	if not back_low:
		fail(res, "no fourth copy (the low one running the other way) at i = 2")
	b.iter = 0
	b.spd = 1.0
	b.path_t = 3.0
	for segs in b.copies():
		if absf(segs[0].y - 170.0) < 1.0 and segs[0].x > segs[1].x:
			fail(res, "a fourth copy at i = 0")
	b.mode = "idle"
	# 4. the panel: a hit freezes the snake for 3 s with its tail on the floor by the panel, free hits, then it goes on
	b.plan = {}
	b.iter = 0
	b.hz.clear()
	b._start("rest")
	if not rb_until(r, b, "rest", "active", Vector2(192.0, 150.0)):
		fail(res, "the rest never became active")
	if b.panel_t <= 0.0 or b.hurtboxes().size() != 2:
		fail(res, "the panel is not lit (%.2f, %d boxes)" % [b.panel_t, b.hurtboxes().size()])
	var panel_box := {}
	for hb in b.hurtboxes():
		if hb.has("panel"):
			panel_box = hb
	b.hit(1, 0.0, -1.0, "swipe", panel_box)
	if absf(b.freeze_t - 3.0) > 0.01 or not b.harmboxes().is_empty():
		fail(res, "the panel did not freeze (freeze %.2f, %d harm)" % [b.freeze_t, b.harmboxes().size()])
	var tp: Vector2 = b.tail_point()
	if absf(tp.y - 170.0) > 1.0 or absf(tp.x - 204.0) > 1.0:
		fail(res, "the tail is at %s" % str(tp))
	var hp1 := b.hpf
	r.player.x = tp.x - 20.0
	r.player.y = 150.0
	b.hit(1, 1.0, 0.0, "swipe", b.hurtboxes()[0])
	if b.hpf >= hp1:
		fail(res, "a frozen tail takes no hits")
	for f in range(int(3.1 * 60.0)):
		r.player.inv = 99.0
		r.player.x = 40.0
		r.player.y = 150.0
		r.step(Game.STEP)
		b.idle_t = 999.0
	if b.freeze_t > 0.0:
		fail(res, "the freeze did not end")
	b.plan = {}
	b.mode = "idle"
	# 5. the arena loops: a body leaving through the portal comes out on the other side
	r.player.x = -9.0
	r.player.y = 160.0
	r.player.vx = 0.0
	r.step(Game.STEP)
	if r.player.x < float(r.pw) - 40.0:
		fail(res, "a body at x < 0 did not come out on the right (x %.0f)" % r.player.x)
	r.player.x = float(r.pw) - 1.0
	r.player.y = 160.0
	r.step(Game.STEP)
	if r.player.x > 40.0:
		fail(res, "a body past the right edge did not come out on the left (x %.0f)" % r.player.x)
	# 6. phase 3: the strips hurt and the floor is a conveyor towards the head
	b.hpf = float(b.max_hp) * 0.2
	b.hp = ceili(b.hpf)
	b.mode = "rest"
	r.player.x = 300.0
	r.player.y = 160.0
	r.player.vx = 0.0
	r.player.vy = 0.0
	r.player.inv = 99.0
	for f in range(10):
		r.player.x = 300.0
		r.player.vy = 0.0
		r.step(Game.STEP)
	if not b.strips_on:
		fail(res, "the side strips did not come")
	var px0: float = r.player.x
	b.mode = "rest"
	for f in range(30):
		r.step(Game.STEP)
	if absf(r.player.x - px0) < 5.0:
		fail(res, "the conveyor did not move the player (%.1f -> %.1f)" % [px0, r.player.x])
	b.hpf = float(b.max_hp)
	# 7. a puppet from the record has the same boxes and fields
	b.mode = "idle"
	b.plan = {}
	b.iter = 0
	b._start("nested")
	rb_until(r, b, "nested", "active", Vector2(192.0, 150.0))
	var rec: Array = JSON.parse_string(JSON.stringify(NetClasses.record(b)))
	var pup = NetClasses.make(NetClasses.cls_of(b), r)
	NetClasses.apply(pup, rec)
	pup.hz_gate = 0.0                                          # (the guest's own rule: a hazard hurts after 0.5 s on screen; the test skips the wait)
	if not same_boxes(b.harmboxes(), pup.harmboxes()) or not same_boxes(b.hurtboxes(), pup.hurtboxes()):
		fail(res, "the puppet's boxes differ from the host's (%d/%d harm, %d/%d hurt, mode %s/%s)" % [b.harmboxes().size(), pup.harmboxes().size(), b.hurtboxes().size(), pup.hurtboxes().size(), b.mode, pup.mode])
	var fa: Array = JSON.parse_string(JSON.stringify(pup.net_fields()))
	var fb: Array = JSON.parse_string(JSON.stringify(b.net_fields()))
	if JSON.stringify(fa) != JSON.stringify(fb):
		fail(res, "the puppet's fields differ")
	pup.free()
	# 8. the kill gives opus and sets boss:LOOP; T10:E opens
	b.plan = {}
	Game.tools.opus = false
	r.attacker = r.player
	if not r.skip_boss():
		fail(res, "skip boss did not work")
	var guard := 0
	while r.fight.state != "done" and guard < 900:
		r.player.inv = 99.0
		r.step(Game.STEP)
		guard += 1
	if r.fight.state != "done" or not Game.tools.get("opus", false) or not Game.flag("boss:LOOP"):
		fail(res, "the reward: state %s, opus %s" % [r.fight.state, str(Game.tools.get("opus", false))])
	r.update_doors()
	var de = r.grid.door_at("E", 8)
	if de == null or not de.open:
		fail(res, "T10:E stays closed after the fight")
	r.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("loopboss", res.ok, res.info)

# MV5A-08: DEADLOCK
func t_deadlockboss() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var r := new_room("T18")
	var b: DeadlockBoss = r.boss as DeadlockBoss
	if b == null:
		fail(res, "T18 has no DeadlockBoss")
		r.queue_free()
		return report("deadlockboss", false, res.info)
	if b.max_hp != 96 or b.halves[0].hp != 48.0 or b.halves[1].hp != 48.0:
		fail(res, "hp %d, want 48 + 48" % b.max_hp)
	# the land trigger: nothing on the lid, the fight starts after 0.5 s on the floor
	r.player.x = 11.0 * 16.0
	r.player.y = 11.0 * 16.0 - 10.0
	for f in range(60):
		r.player.x = 11.0 * 16.0 + 4.0
		r.player.y = 11.0 * 16.0 - 10.0
		r.player.vx = 0.0
		r.player.vy = 0.0
		r.player.inv = 99.0
		r.step(Game.STEP)
	if r.fight.state != "none":
		fail(res, "the fight started with the player on the lid of the hole (%s)" % r.fight.state)
	var n := 0
	while r.fight.state == "none" and n < 120:
		r.player.x = 4.0 * 16.0
		r.player.y = 11.0 * 16.0 - 10.0 - (0.0 if n > 0 else 20.0)
		r.player.vx = 0.0
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if r.fight.state == "none" or n < 25 or n > 80:
		fail(res, "the land trigger: state %s after %d frames (want about 30)" % [r.fight.state, n])
	n = 0
	while r.fight.state != "active" and n < 400:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if r.fight.state != "active":
		fail(res, "the fight never became active")
	b.plan = {}
	b.idle_t = 999.0
	r.attacker = r.player
	# the commit rule: one hit alone rolls back after 2 s; the other half hit inside the window commits both
	var hp_a: float = b.halves[0].hp
	b.hit(1, 1.0, 0.0, "swipe", b.hurtboxes()[0])
	if b.halves[0].hp != hp_a or b.halves[0].pend <= 0.0:
		fail(res, "a lone hit changed hp at once (%.1f, pending %.1f)" % [b.halves[0].hp, b.halves[0].pend])
	for f in range(int(2.2 * 60.0)):
		r.player.inv = 99.0
		r.step(Game.STEP)
		b.idle_t = 999.0
	if b.halves[0].hp != hp_a or b.halves[0].pend != 0.0:
		fail(res, "the pending hit did not roll back (hp %.1f, pending %.1f)" % [b.halves[0].hp, b.halves[0].pend])
	b.hit(1, 1.0, 0.0, "swipe", b.hurtboxes()[0])
	for f in range(60):
		r.player.inv = 99.0
		r.step(Game.STEP)
		b.idle_t = 999.0
	b.hit(1, 1.0, 0.0, "swipe", b.hurtboxes()[1])
	if b.halves[0].hp != hp_a - 1.0 or b.halves[1].hp != 47.0:
		fail(res, "the pair did not commit (%.1f / %.1f)" % [b.halves[0].hp, b.halves[1].hp])
	# swap: invulnerable for 1.5 s, hits are blocked
	b._start("swap")
	if not rb_until(r, b, "swap", "active", Vector2(192.0, 150.0)):
		fail(res, "the swap never became active")
	if b.hit(1, 1.0, 0.0, "swipe", b.hurtboxes()[0]) != "block":
		fail(res, "a half took a hit during the swap")
	b.plan = {}
	b.inv_t = 0.0
	# breakpoint freezes one half: it does not move, the other does
	Game.tools.breakpoint = true
	b.halves[0].x = 100.0
	b.halves[1].x = 250.0
	b.halves[0].home_x = 60.0
	b.halves[1].home_x = 320.0
	r.player.x = 40.0
	r.player.y = 150.0
	r.player.face = 1.0
	if not r.bp_apply("h", b.nid * 2):
		fail(res, "breakpoint could not stop half A")
	var ax: float = b.halves[0].x
	var bx0: float = b.halves[1].x
	for f in range(60):
		r.player.inv = 99.0
		r.step(Game.STEP)
		b.idle_t = 999.0
	if absf(b.halves[0].x - ax) > 0.01 or absf(b.halves[1].x - bx0) < 5.0:
		fail(res, "the stopped half moved or the free one did not (A %.1f -> %.1f, B %.1f -> %.1f)" % [ax, b.halves[0].x, bx0, b.halves[1].x])
	b.halves[0].bpt = 0.0
	# the chain sweeps: boxes along the line, a grab hurts for 2
	b._start("chain")
	if not rb_until(r, b, "chain", "active", Vector2(192.0, 150.0)):
		fail(res, "the chain never became active")
	if b.harmboxes().size() < 10:
		fail(res, "the chain has %d boxes" % b.harmboxes().size())
	b.plan = {}
	b.hz.clear()
	b.halves[0].y = Boss.FLOOR
	b.halves[1].y = Boss.FLOOR
	b._start("grab")
	if absf(float(b.plan.t) - 0.75) > 0.001:
		fail(res, "grab cue %.2f" % float(b.plan.t))
	if not rb_until(r, b, "grab", "active", Vector2(192.0, 150.0)):
		fail(res, "the grab never became active")
	var gdmg := 0
	for hb in b.harmboxes():
		gdmg = maxi(gdmg, int(hb.get("dmg", 1)))
	if gdmg != 2:
		fail(res, "a grab does %d" % gdmg)
	b.plan = {}
	# a puppet from the record has the same boxes and fields
	var rec: Array = JSON.parse_string(JSON.stringify(NetClasses.record(b)))
	var pup = NetClasses.make(NetClasses.cls_of(b), r)
	NetClasses.apply(pup, rec)
	pup.hz_gate = 0.0
	if not same_boxes(b.hurtboxes(), pup.hurtboxes()):
		fail(res, "the puppet's hurtboxes differ")
	var fa: Array = JSON.parse_string(JSON.stringify(pup.net_fields()))
	var fb: Array = JSON.parse_string(JSON.stringify(b.net_fields()))
	if JSON.stringify(fa) != JSON.stringify(fb):
		fail(res, "the puppet's fields differ")
	pup.free()
	# the kill gives lock_free
	r.attacker = r.player
	if not r.skip_boss():
		fail(res, "skip boss did not work")
	var guard := 0
	while r.fight.state != "done" and guard < 900:
		r.player.inv = 99.0
		r.step(Game.STEP)
		guard += 1
	if r.fight.state != "done" or not Game.flag("plugin:lock_free") or not Game.flag("boss:DEADLOCK"):
		fail(res, "the reward: state %s, lock_free %s" % [r.fight.state, str(Game.flag("plugin:lock_free"))])
	r.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("deadlockboss", res.ok, res.info)

# MV5A-08: the plugins hot_path and lock_free
func t_plugins5a() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	for pid in ["hot_path", "lock_free"]:
		if Game.plugin_def(pid).is_empty():
			fail(res, "no plugin " + pid)
	Game.flags["plugin:hot_path"] = true
	Game.flags["plugin:lock_free"] = true
	Game.tools.bash = true
	# hot_path: a dash that hits a creature is ready again at once
	Game.equipped = ["hot_path"]
	var r := bare_room("R01", 100.0, 192.0)
	var bug := add_bug(r, 130.0, 192.0, -1.0)
	bug.hp = 5
	var p = r.player
	p.inv = 99.0
	p.face = 1.0
	step_keys(r, {})
	step_keys(r, {"dash": true, "right": true})
	var recharged := false
	for f in range(20):
		step_keys(r, {"right": true})
		p.inv = 99.0
		if p.dash_t > 0.0 and p.can_dash and p.dash_cd <= 0.0 and bug.hp < 5:
			recharged = true
	if not recharged:
		fail(res, "hot_path: the dash was not recharged by a hit (hp %d, can %s)" % [bug.hp, str(p.can_dash)])
	Game.equipped = []
	# lock_free: the claw goes through a Guard's front, not a boss's shield
	var r2 := bare_room("R01", 100.0, 192.0)
	var gd := Guard.new(r2, 7 * 16, 11 * 16)
	r2.add_entity(gd)
	gd.face = -1.0
	r2.attacker = r2.player
	if gd.hit(1, 1.0, 0.0, "swipe", gd) != "block":
		fail(res, "a guard's front did not block without the plugin")
	Game.equipped = ["lock_free"]
	r2.attacker = r2.player
	if gd.hit(1, 1.0, 0.0, "swipe", gd) == "block":
		fail(res, "lock_free: a guard's front still blocks a claw")
	if gd.hit(1, 1.0, 0.0, "agent", gd) != "block":
		fail(res, "lock_free let an agent through")
	Game.equipped = []
	r.queue_free()
	r2.queue_free()
	Controls.script_input = null
	Game.fresh()
	return report("plugins5a", res.ok, res.info)

func logs_text5(lv: LogsView) -> String:
	var out := ""
	for l in lv.lines:
		out += String(l.text) + "\n"
	return out

# MV5A-09: the 4B-1 systems in the tower
func t_tower4b1() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# the cartographer in T01 sells the index of /dev/threads for 40 tokens
	var menu := IndexMenu.new()
	main.add_child(menu)
	var t01 := new_room("T01")
	if t01.npcs.size() != 1 or t01.npcs[0].zone != "tower" or t01.npcs[0].price != 40:
		fail(res, "T01 npc")
	else:
		menu.open(t01, t01.npcs[0])
		if menu.rows()[0] != "index /dev/threads — 40 tokens":
			fail(res, "offer " + str(menu.rows()))
		Game.tokens = 40
		if not menu.buy() or not Game.owns_map("tower") or Game.tokens != 0:
			fail(res, "buying map:tower")
		menu.close()
	var scraps := 0
	for d in t01.decor_items:
		if String(d.kind) == "scrap":
			scraps += 1
	if scraps != 3:
		fail(res, "%d paper scraps lead to the tree, want 3" % scraps)
	t01.queue_free()
	menu.queue_free()
	# T15: the lost agent in its jar is freed by a swipe
	var t15 := new_room("T15")
	for e in t15.ents:
		e.queue_free()
	t15.ents.clear()
	if t15.jars.size() != 1:
		fail(res, "T15 has no jar")
	else:
		var jar: Dictionary = t15.jars[0]
		var p = t15.player
		p.x = float(jar.x) + 12.0                                  # (the spikes are to the left of the jar: swipe from the right)
		p.y = float(jar.y) - p.h
		p.vx = 0.0
		p.vy = 0.0
		p.face = -1.0
		for f in range(12):
			Controls.script_input = {"attack": f < 2}
			Controls.poll()
			t15.step(Game.STEP)
		Controls.script_input = {}
		for f in range(4):
			Controls.poll()
			t15.step(Game.STEP)
		if not Game.flag("agent:T15"):
			fail(res, "a swipe did not free T15's agent")
	t15.queue_free()
	# T14: logbook page 3 and the memory fragment
	var t14 := new_room("T14")
	for e in t14.ents:
		e.queue_free()
	t14.ents.clear()
	var page_it = null
	var spark = null
	for it in t14.items:
		if it.kind == "page":
			page_it = it
		if it.kind == "spark":
			spark = it
	if page_it == null or int(String(page_it.id).get_slice(":", 1)) != 3:
		fail(res, "T14 has no page 3")
	else:
		var pp = t14.player
		pp.x = float(page_it.x) - 5.0
		pp.y = float(page_it.y) - 5.0
		pp.vx = 0.0
		pp.vy = 0.0
		Controls.script_input = {}
		Controls.poll()
		t14.step(Game.STEP)
		if not Game.flag("page:3"):
			fail(res, "touching the page did not collect it")
	if spark == null:
		fail(res, "T14 has no fragment")
	else:
		t14.collect(spark)
		if t14.memory.text != "05:12 — two threads wrote the same line at once.":
			fail(res, "memory line " + str(t14.memory.text))
	t14.queue_free()
	# the terminal: no creature within 10 tiles of T08's bench; secrets
	var t08 := new_room("T08")
	if t08.cps.is_empty() or not bool(Game.rooms_meta.rooms.T08.get("terminal", false)):
		fail(res, "T08 is no terminal")
	for c in t08.cps:
		for e in t08.ents:
			var d := Vector2(float(e.x) + float(e.w) / 2.0 - float(c.x), float(e.y) + float(e.h) / 2.0 - float(c.y)).length() / 16.0
			if d < 10.0:
				fail(res, "T08: a %s %.1f tiles from the bench" % [e.get_class(), d])
	t08.queue_free()
	for id in ["T14", "T15"]:
		if not Game.is_secret(id):
			fail(res, "%s is not a secret" % id)
	# the tower's signs are listed under THREAD TOWER
	var lv := LogsView.new()
	main.add_child(lv)
	var t04 := new_room("T04")
	if t04.signs.is_empty():
		fail(res, "T04 has no sign")
	else:
		var sg: Dictionary = t04.signs[0]
		var p4 = t04.player
		p4.x = float(sg.x) - p4.w / 2.0
		p4.y = float(sg.y) - p4.h
		Controls.script_input = {}
		Controls.poll()
		t04.step(Game.STEP)
		lv.open()
		if not logs_text5(lv).contains("THREAD TOWER"):
			fail(res, "the tower's sign is not under THREAD TOWER: " + logs_text5(lv).left(200))
	t04.queue_free()
	lv.queue_free()
	# the changelog: busy pistons and cables are obstacles (breakpoint, opus), an ordinary piston is not
	var busy := 0
	for g in Game.obstacle_groups("TC2"):
		if g.ability == "breakpoint":
			busy += 1
	var plain := 0
	for g in Game.obstacle_groups("TA2"):
		if g.ability == "breakpoint":
			plain += 1
	var cab := 0
	for g in Game.obstacle_groups("T11"):
		if g.ability == "opus":
			cab += 1
	if busy != 3 or plain != 0 or cab < 1:
		fail(res, "obstacles: %d busy pistons in TC2, %d in TA2, %d cables in T11" % [busy, plain, cab])
	Game.fresh()
	return report("tower4b1", res.ok, res.info)
