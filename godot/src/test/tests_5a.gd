extends Tests4b3
class_name Tests5a
# Unit tests of phase 5A (THREAD TOWER). run_tests.gd hands names it does not know to run().

const NAMES5 := ["rooms5a", "w4assets", "tick5a"]

func run(name: String):
	match name:
		"rooms5a": return await t_rooms5a()
		"w4assets": return await t_w4assets()
		"tick5a": return await t_tick5a()
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
