extends RefCounted
class_name Tests4b2
# Unit tests of phase 4B-2 (THE NETWORK). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["rooms4b", "w6assets", "curl", "ssh"]

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String):
	match name:
		"rooms4b": return await t_rooms4b()
		"w6assets": return await t_w6assets()
		"curl": return t_curl()
		"ssh": return t_ssh()
	return report(name, false, "unknown test")

func checker() -> Dictionary:
	return {"ok": true, "info": ""}

func fail(res: Dictionary, label: String) -> void:
	res.ok = false
	res.info += " BAD:" + label

func frames(n := 2) -> void:
	for i in range(n):
		await main.get_tree().process_frame

func new_room(room_id: String) -> Room:
	var room := Room.new()
	main.world.add_child(room)
	room.load_room(room_id)
	room.build_nodes()
	return room

func new_manager() -> RoomManager:
	var m := RoomManager.new(main.world, null)
	main.add_child(m)
	m.start_game()
	return m

# every N room (22): loads, doors point back, the closed ones are closed, the end doors exist, D07:E is open
func t_rooms4b() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var n := 0
	for id in Game.rooms_meta.rooms:
		if not String(id).begins_with("N"):
			continue
		n += 1
		var m: Dictionary = Game.rooms_meta.rooms[id]
		if Game.zone_of(id) != "net" or int(m.get("world", 0)) != 6:
			fail(res, "%s zone/world" % id)
		for d in m.doors:
			var to_room := String(d.to).get_slice(":", 0)
			if not Game.rooms_meta.rooms.has(to_room):
				continue
			var back := false
			for td in Game.rooms_meta.rooms[to_room].doors:
				if td.id == d.to and td.to == d.id:
					back = true
			if not back:
				fail(res, "%s does not point back" % d.id)
		var r := new_room(id)
		await frames(1)
		r.queue_free()
	if n != 22:
		fail(res, "%d N rooms" % n)
	var n01 := new_room("N01")
	var d1 = n01.grid.door_at("N", int(Game.rooms_meta.rooms.N01.doors.filter(func(d): return d.id == "N01:N")[0].a))
	if d1 == null or d1.open:
		fail(res, "N01:N is not closed")
	n01.queue_free()
	var h11 := new_room("H11")
	var dh = h11.grid.door_at("N", 192)
	if dh == null or dh.open:
		fail(res, "H11:N2 is not closed")
	h11.queue_free()
	for rid in ["N11", "N17"]:
		var rr := new_room(rid)
		if rr.end_door == null or String(rr.def.get("end", "")) == "":
			fail(res, "%s has no end door" % rid)
		rr.queue_free()
	var d07 := new_room("D07")
	var de = d07.grid.door_at("E", 10)
	if de == null or not de.open:
		fail(res, "D07:E is not open")
	d07.queue_free()
	Game.fresh()
	return report("rooms4b", res.ok, res.info)

# MVB2-02: world 6 has its own tiles, theme, song, backdrop and the `ci` landmark
func t_w6assets() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	for f in ["res://assets/tiles/w6_tiles.png", "res://assets/music/w6.ogg", "res://assets/theme/w6.json", "res://assets/sprites/platform_w6.png"]:
		if not ResourceLoader.exists(f):
			fail(res, "missing " + f)
	if Game.vis_world(6) != 6 or String(Game.theme(6).accent) != "#5ad1ff":
		fail(res, "theme 6: " + str(Game.theme(6).get("accent")))
	var n03 := new_room("N03")
	await frames(2)
	var nb = n03.view.get_node_or_null("NetBackdrop")
	if nb == null or nb.draws < 1:
		fail(res, "the backdrop did not draw")
	n03.queue_free()
	var n05 := new_room("N05")
	for f in range(20):
		Controls.script_input = {}
		Controls.poll()
		n05.step(Game.STEP)
	await frames(3)
	var lm = n05.view.get_node_or_null("Landmarks")
	var nb5 = n05.view.get_node_or_null("NetBackdrop")
	if lm == null or lm.draws < 1 or not lm.kinds.has("ci"):
		fail(res, "N05 landmark ci")
	if nb5 == null or nb5.draws < 1:
		fail(res, "N05 backdrop")
	n05.queue_free()
	Game.fresh()
	return report("w6assets", res.ok, res.info)

func step_keys(room: Room, keys: Dictionary) -> void:
	Controls.script_input = keys
	Controls.poll()
	room.step(Game.STEP)

# MVB2-03: curl. N10's three trenches, the pick rules, no zip without the ability, the tap that zips does not cast agents, H01 -> H14
func t_curl() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	Game.tools.curl = true
	var r := new_room("N10")
	for e in r.ents:
		e.queue_free()
	r.ents.clear()
	var p = r.player
	p.x = 81.0 * 16.0
	p.y = 19.0 * 16.0 - 10.0
	p.vx = 0.0
	p.vy = 0.0
	var hp0: int = p.hp
	# each of the three trenches can be crossed by a jump and a curl chain (some press timing works), without touching a spike
	var trenches := [[80, 70], [62, 46], [36, 14]]       # [first floor column on the right edge, first spike column] per trench
	for tr in trenches:
		var ok := false
		for off in range(6, 44, 2):
			var rr := new_room("N10")
			rr.ents.clear()
			var pp = rr.player
			pp.x = float(tr[0]) * 16.0 + 3.0
			pp.y = 19.0 * 16.0 - 10.0
			pp.vx = 0.0
			pp.vy = 0.0
			pp.hp = pp.max_hp
			for f in range(260):
				var keys := {"left": true}
				if f < 14 or (f > 40 and pp.on_ground):
					keys["jump"] = true
				if f >= off and (f - off) % 12 == 0:
					keys["special"] = true
				step_keys(rr, keys)
				if pp.hp < pp.max_hp:
					break
				if f > 20 and pp.on_ground and pp.x < float(tr[1]) * 16.0 - 14.0:
					ok = true
					break
			rr.queue_free()
			if ok:
				break
		if not ok:
			fail(res, "N10: the trench right of column %d cannot be crossed" % tr[1])
	Controls.script_input = null
	# pick rules: from (78*16, 15*16) facing left the nearest ring on that side is the one at (74, 14)
	var r2 := new_room("N10")
	var q = r2.player
	q.x = 78.0 * 16.0
	q.y = 15.0 * 16.0
	q.curl_last = -1
	var i1: int = r2.pick_anchor(q, -1.0)
	var want := -1
	var list := r2.anchors()
	for i in range(list.size()):
		if int(list[i].x) == 74 * 16 + 8 and int(list[i].y) == 14 * 16 + 8:
			want = i
	if want < 0 or i1 != want:
		fail(res, "pick: %d, want %d (%d anchors)" % [i1, want, list.size()])
	q.curl_last = want
	if r2.pick_anchor(q, -1.0) == want:
		fail(res, "the ring just used was picked again")
	q.curl_last = -1
	# a wall between: none
	var ring: Dictionary = list[want]
	var mid_tx := floori((float(ring.x) + q.x + 5.0) / 2.0 / 16.0)
	var mid_ty := floori((float(ring.y) + q.y + 5.0) / 2.0 / 16.0)
	var old: int = r2.grid.tiles[mid_ty * r2.w + mid_tx]
	r2.grid.tiles[mid_ty * r2.w + mid_tx] = TileGrid.SOLID
	if r2.pick_anchor(q, -1.0) == want:
		fail(res, "a wall did not block the line")
	r2.grid.tiles[mid_ty * r2.w + mid_tx] = old
	r.queue_free()
	r2.queue_free()
	# without curl: [special] near a ring does nothing new
	Game.tools.curl = false
	var r3 := new_room("N10")
	var w3 = r3.player
	w3.x = 78.0 * 16.0
	w3.y = 15.0 * 16.0
	for f in range(10):
		step_keys(r3, {"special": f == 2})
	if w3.zip >= 0:
		fail(res, "zipped without curl")
	# agents: a full meter and no ring in range: the tap casts them; with a ring in range the tap zips and casts nothing
	Game.tools.curl = true
	Game.tools.agents = true
	var r4 := new_room("R01")
	r4.ents.clear()
	var a4 = r4.player
	a4.meter = float(Game.METER_MAX)
	for f in range(12):
		step_keys(r4, {"special": f < 3})
	if a4.agents_t <= 0.0:
		fail(res, "the tap did not cast agents with no ring around")
	var r5 := new_room("N10")
	r5.ents.clear()
	var a5 = r5.player
	a5.x = 78.0 * 16.0
	a5.y = 15.0 * 16.0
	a5.meter = float(Game.METER_MAX)
	for f in range(12):
		step_keys(r5, {"special": f < 3})
	if a5.agents_t > 0.0 or a5.meter < float(Game.METER_MAX):
		fail(res, "a zipping tap cast the agents")
	r3.queue_free()
	r4.queue_free()
	r5.queue_free()
	# H01 -> H14 with curl and bash, no sudo: the ring, then a dash up
	Game.tools.agents = false
	Game.tools.bash = true
	Game.tools.sudo = false
	var h1_door_ok := false
	for off in range(4, 24, 2):
		var h1 := new_room("H01")
		h1.ents.clear()
		var hp = h1.player
		hp.x = 16.0 * 16.0 + 3.0
		hp.y = 12.0 * 16.0 - 10.0
		for f in range(200):
			var k := {}
			if f < 30:
				k["jump"] = true
			if f == off:
				k["special"] = true
			if hp.curl_last >= 0:                                   # (after the zip: steer over the hole, dash up at the top of the pop)
				if hp.x > 284.0:
					k["left"] = true
				elif hp.x < 266.0:
					k["right"] = true
				if hp.vy < 0.0 and hp.vy > -70.0 and absf(hp.vx) < 30.0:
					k["dash"] = true
					k["up"] = true
			step_keys(h1, k)
			if hp.y < 0.0 or h1.id != "H01":
				h1_door_ok = true
				break
		h1.queue_free()
		if h1_door_ok:
			break
	Controls.script_input = null
	if not h1_door_ok:
		fail(res, "H01: curl then a dash up did not reach the top")
	Game.fresh()
	return report("curl", res.ok, res.info)

# walk (key `dir`) from a spawn point until the manager is in `to` (a jump now and then); returns the frames it took, or -1
func walk_to(m: RoomManager, from_room: String, spawn: Vector2, key: String, to: String, frames_max := 800) -> int:
	m.swap_to(from_room, spawn, null, true)
	m.room.ents.clear()
	m.room.update_doors()
	m.player.x = spawn.x
	m.player.y = spawn.y
	m.player.vx = 0.0
	m.player.vy = 0.0
	for f in range(frames_max):
		var keys := {key: true}
		if f % 40 < 14:
			keys["jump"] = true
		Controls.script_input = keys
		m.player.hp = m.player.max_hp
		m.tick(Game.STEP)
		if m.room.id == to and not m.trans.on:
			Controls.script_input = null
			return f
	Controls.script_input = null
	return -1

# MVB2-04: ssh. N16's thin and thick walls and its east firewall door, the hold time, a wall that is too thick, the HEAP and DEPTHS firewall doors
func t_ssh() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	Game.tools.bash = true
	Game.tools.catch = true
	Game.flags["boss:FIREWALL"] = true
	# without ssh the thin wall stops the player
	var m := new_manager()
	var n := walk_to(m, "N16", Vector2(24.0, 15.0 * 16.0 - 10.0), "right", "N17", 200)
	if n >= 0 or m.player.x > 12.0 * 16.0:
		fail(res, "without ssh: reached %.0f (%d)" % [m.player.x, n])
	# with ssh: thin wall (col 12), thick wall (cols 22-23), then the stairs and the east door to N17
	Game.tools.ssh = true
	n = walk_to(m, "N16", Vector2(24.0, 15.0 * 16.0 - 10.0), "right", "N17", 900)
	if n < 0:
		fail(res, "with ssh: N16 -> N17 did not work (x %.0f in %s)" % [m.player.x, m.room.id])
	# and back
	n = walk_to(m, "N17", Vector2(6.0 * 16.0, 11.0 * 16.0 - 10.0), "left", "N16", 900)
	if n < 0:
		fail(res, "with ssh: N17 -> N16 did not work (x %.0f in %s)" % [m.player.x, m.room.id])
	m.queue_free()
	# the hold: 0.25 s does nothing, 0.35 s tunnels
	var r := new_room("N16")
	r.ents.clear()
	var p = r.player
	p.x = 11.0 * 16.0 + 4.0
	p.y = 15.0 * 16.0 - 10.0
	for f in range(15):
		step_keys(r, {"right": true})
	if p.ssh_t > 0.0 or p.x > 12.0 * 16.0:
		fail(res, "a 0.25 s push tunnelled")
	for f in range(14):
		step_keys(r, {"right": true})
	var tunnelled: bool = p.x > 13.0 * 16.0 or p.ssh_t > 0.0
	if not tunnelled:
		fail(res, "a 0.4 s push did not tunnel (x %.0f)" % p.x)
	Controls.script_input = null
	r.queue_free()
	# a three-brick wall does not open and says so
	var r3 := new_room("N16")
	r3.ents.clear()
	for ty in range(1, 15):
		for tx in [22, 23, 24]:
			r3.grid.tiles[ty * r3.w + tx] = TileGrid.FIRE
	var p3 = r3.player
	p3.x = 21.0 * 16.0 + 2.0
	p3.y = 15.0 * 16.0 - 10.0
	for f in range(40):
		step_keys(r3, {"right": true})
	if p3.ssh_t > 0.0 or p3.x > 22.0 * 16.0 or not p3.push_warned:
		fail(res, "three bricks: x %.0f warned %s" % [p3.x, p3.push_warned])
	Controls.script_input = null
	r3.queue_free()
	# the HEAP and DEPTHS firewall doors, both ways
	Game.flags["boss:LEAK"] = true
	var m2 := new_manager()
	if walk_to(m2, "H12", Vector2(18.0 * 16.0, 11.0 * 16.0 - 10.0), "right", "H16", 600) < 0:
		fail(res, "H12 -> H16")
	if walk_to(m2, "H16", Vector2(20.0, 11.0 * 16.0 - 10.0), "left", "H12", 600) < 0:
		fail(res, "H16 -> H12")
	if walk_to(m2, "H03", Vector2(4.0 * 16.0, 57.0 * 16.0 - 10.0), "left", "D03", 900) < 0:
		fail(res, "H03 -> D03 (x %.0f y %.0f in %s)" % [m2.player.x, m2.player.y, m2.room.id])
	if walk_to(m2, "D03", Vector2(23.0 * 16.0, 34.0 * 16.0 - 10.0), "right", "H03", 900) < 0:
		fail(res, "D03 -> H03 (x %.0f y %.0f in %s)" % [m2.player.x, m2.player.y, m2.room.id])
	m2.queue_free()
	Game.fresh()
	return report("ssh", res.ok, res.info)
