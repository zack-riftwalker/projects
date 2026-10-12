extends RefCounted
class_name Tests4b2
# Unit tests of phase 4B-2 (THE NETWORK). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["rooms4b", "w6assets", "curl", "ssh", "net4b", "w6enemies", "firewall", "reviewer2", "plugins4b", "net4b1"]

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
		"net4b": return t_net4b()
		"w6enemies": return t_w6enemies()
		"firewall": return t_firewall()
		"reviewer2": return t_reviewer2()
		"plugins4b": return t_plugins4b()
		"net4b1": return t_net4b1()
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
	await door_walk(res)
	await airgap_falls(res)
	depths_loop(res)
	await secrets4b(res)
	Game.fresh()
	return report("rooms4b", res.ok, res.info)

# MVB2-12 (1): through every N door that can open, the way a player goes: the next room, a body on free ground
func door_walk(res: Dictionary) -> void:
	Game.flags = {}
	for f in ["boss:CRAWLER", "boss:FIREWALL", "boss:REVIEWER2", "wave:N21", "lever:CDN", "lever:D06"]:
		Game.flags[f] = true
	Game.tools = {"bash": true, "catch": true, "sudo": false, "agents": true, "opus": false, "curl": true, "ssh": true}
	var m := new_manager()
	var crossed := 0
	for rid in Game.rooms_meta.rooms:
		if not String(rid).begins_with("N"):
			continue
		var def: Dictionary = Game.rooms_meta.rooms[rid]
		for d in def.doors:
			var to_room := String(d.to).get_slice(":", 0)
			var lock := String(d.get("lock", ""))
			if not Game.rooms_meta.rooms.has(to_room) or lock == "oneway":
				continue
			var pw: float = float(def.size[0]) * 16.0
			var ph: float = float(def.size[1]) * 16.0
			m.swap_to(rid, Vector2(pw / 2.0, ph / 2.0), null, true)
			m.room.ents.clear()
			m.room.update_doors()
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
			for f in range(60):
				Controls.script_input = keys
				m.player.hp = m.player.max_hp
				m.tick(Game.STEP)
				if m.room.id == to_room and not m.trans.on:
					got = f
					break
			Controls.script_input = null
			if got < 0:
				fail(res, "door %s: still in %s after 60 frames" % [d.id, m.room.id])
				continue
			crossed += 1
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
	if crossed < 40:
		fail(res, "only %d doors crossed" % crossed)
	m.queue_free()
	await frames(1)

# MVB2-12 (2): the airgap in N11 drops into H11, N01 or N04, on solid ground, hp unchanged
func airgap_falls(res: Dictionary) -> void:
	Game.flags = {}
	var m := new_manager()
	for pair in [[14, "H11"], [40, "N01"], [80, "N04"]]:
		m.swap_to("N11", Vector2(float(pair[0]) * 16.0, 48.0 * 16.0), null, true)
		m.room.ents.clear()
		m.player.x = float(pair[0]) * 16.0
		m.player.y = 48.0 * 16.0
		m.player.vx = 0.0
		m.player.vy = 200.0
		var hp0: int = m.player.hp
		var in_target := false
		for f in range(240):
			m.tick(Game.STEP)
			if m.room.id == String(pair[1]) and not m.trans.on:
				in_target = true
			if in_target and f > 0 and m.player.on_ground and f > 30:
				pass
			if in_target and m.player.on_ground:
				break
		if m.room.id != String(pair[1]):
			fail(res, "airgap x %d landed in %s, not %s" % [pair[0], m.room.id, pair[1]])
		elif not m.player.on_ground:
			fail(res, "airgap x %d: not on the ground in %s" % [pair[0], pair[1]])
		if m.player.hp != hp0:
			fail(res, "airgap x %d cost hp" % pair[0])
	m.queue_free()
	await frames(1)

# MVB2-12 (5): the DEPTHS loop: N02's lever opens D06's slot gate, without agents
func depths_loop(res: Dictionary) -> void:
	Game.flags = {}
	Game.tools = {"bash": true, "catch": true, "sudo": false, "agents": false, "opus": false, "curl": false, "ssh": false}
	var d6 := new_room("D06")
	if d6.grid.gates_open.agents:
		fail(res, "D06's slot gate was open without the lever")
	d6.queue_free()
	var n2 := new_room("N02")
	if n2.levers.size() != 1:
		fail(res, "N02 has %d levers" % n2.levers.size())
		n2.queue_free()
		return
	var lv: Dictionary = n2.levers[0]
	for e in n2.ents:
		e.queue_free()
	n2.ents.clear()
	var p = n2.player
	p.x = float(lv.x) - 14.0
	p.y = float(lv.y) + 16.0 - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.face = 1.0
	for f in range(16):
		Controls.script_input = {"attack": f < 2}
		Controls.poll()
		n2.step(Game.STEP)
	Controls.script_input = {}
	if not Game.flag("lever:D06"):
		fail(res, "a swipe did not pull N02's lever")
	n2.queue_free()
	var d6b := new_room("D06")
	if not d6b.grid.gates_open.agents:
		fail(res, "D06's slot gate stayed shut after the lever")
	d6b.queue_free()

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

func count_class(r: Room, cls: String) -> int:
	var n := 0
	for e in r.ents:
		if e.get_class() == cls or (e.get_script() != null and String(e.get_script().get_global_name()) == cls):
			n += 1
	return n

# MVB2-05: webs, hooks and scrapers, the loopback lever, quiet dead code, the honeypot, the crawler's passing
func t_net4b() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# N05: a web hurts; after boss:CRAWLER (a rebuilt room) it is air; 4 scrapers hang from the hooks until then
	var n05 := new_room("N05")
	var web: Array = n05.webs[0]
	var p = n05.player
	p.x = float(web[0]) * 16.0 + 3.0
	p.y = float(web[1]) * 16.0 + 3.0
	if n05.hazard_at(p) != "web":
		fail(res, "a web does not hurt (%s)" % n05.hazard_at(p))
	if count_class(n05, "Scraper") != 4 or n05.hooks.size() != 4:
		fail(res, "N05 scrapers %d hooks %d" % [count_class(n05, "Scraper"), n05.hooks.size()])
	if n05.anchors().size() != n05.rings.size():
		fail(res, "hooks are anchors before the crawler")
	# quiet dead code: the /backup ceiling (70,0) has no moths, the 404 floor group has
	var quiet := 0
	var loud := 0
	for g in n05.dead_groups:
		if g.get("quiet", false):
			quiet += 1
		else:
			loud += 1
	if quiet != 1 or loud != 1:
		fail(res, "dead groups quiet %d loud %d" % [quiet, loud])
	n05.queue_free()
	Game.flags["boss:CRAWLER"] = true
	var n05b := new_room("N05")
	var pb = n05b.player
	pb.x = float(web[0]) * 16.0 + 3.0
	pb.y = float(web[1]) * 16.0 + 3.0
	if n05b.hazard_at(pb) != "":
		fail(res, "the web is still there after the crawler")
	if count_class(n05b, "Scraper") != 0 or n05b.anchors().size() != n05b.rings.size() + 4:
		fail(res, "after the crawler: scrapers %d anchors %d" % [count_class(n05b, "Scraper"), n05b.anchors().size()])
	n05b.queue_free()
	Game.flags.erase("boss:CRAWLER")
	# the lever in N02 sets lever:D06 from a swipe and D06's slot gate opens with it
	var n02 := new_room("N02")
	n02.ents.clear()
	var lp = n02.player
	var lv: Dictionary = n02.levers[0]
	lp.x = float(lv.x) - 14.0
	lp.y = float(lv.y) + 16.0 - 10.0
	lp.face = 1.0
	for f in range(14):
		step_keys(n02, {"attack": f < 2})
	Controls.script_input = null
	if not Game.flag("lever:D06"):
		fail(res, "the swipe did not pull the lever")
	n02.queue_free()
	var d06 := new_room("D06")
	d06.update_doors()
	if not d06.grid.gates_open.agents:
		fail(res, "D06's slot gate is shut with the lever pulled")
	d06.queue_free()
	Game.flags.erase("lever:D06")
	var d06b := new_room("D06")
	if d06b.grid.gates_open.agents:
		fail(res, "D06's gate is open without the lever")
	d06b.queue_free()
	# N21: wave 0 within 2 s; the chip is in its case until the flag; killing every bit of all three waves sets it
	var n21 := new_room("N21")
	var chip = null
	for it in n21.items:
		if it.kind == "plugin":
			chip = it
	if chip == null or not n21.item_locked(chip):
		fail(res, "the chip is not locked")
	for f in range(130):
		step_keys(n21, {})
	var bits := count_class(n21, "DdosBit")
	if bits != 2 * 5:
		fail(res, "wave 0 has %d bits (want 10)" % bits)
	for wv in range(3):
		for e in n21.ents.duplicate():
			if e is DdosBit or e is Mitm or e is Botnet or e is Pinger:          # (4B-3: the waves also have a MITM, a BOTNET and a PINGER)
				e.hp = 0
				e.die("swipe")
		for f in range(130):
			step_keys(n21, {})
			if Game.flag("wave:N21"):
				break
	if not Game.flag("wave:N21"):
		fail(res, "the waves did not end (wave %d)" % n21.wave_i)
	if n21.item_locked(chip):
		fail(res, "the chip stays locked")
	n21.queue_free()
	# N08's sighting runs once
	Game.flags.erase("seen:crawler")
	var n08 := new_room("N08")
	n08.ents.clear()
	var sp = n08.player
	sp.x = 100.0
	sp.y = 31.0 * 16.0
	step_keys(n08, {})
	if n08.sight_t >= 0.0 or Game.flag("seen:crawler"):
		fail(res, "the sighting ran below its row")
	sp.y = 20.0 * 16.0
	step_keys(n08, {})
	if n08.sight_t < 0.0 or not Game.flag("seen:crawler"):
		fail(res, "the sighting did not start")
	for f in range(200):
		step_keys(n08, {})
	if n08.sight_t >= 0.0:
		fail(res, "the sighting never ends")
	step_keys(n08, {})
	if n08.sight_t >= 0.0:
		fail(res, "the sighting ran twice")
	Controls.script_input = null
	n08.queue_free()
	Game.fresh()
	return report("net4b", res.ok, res.info)

# a clean copy of a room with nothing alive in it and the player standing at (px, py) (top-left)
func bare_room(room_id: String, px: float, py: float) -> Room:
	var r := new_room(room_id)
	for e in r.ents:
		e.queue_free()
	r.ents.clear()
	r.player.x = px
	r.player.y = py
	r.player.vx = 0.0
	r.player.vy = 0.0
	return r

func run_room(r: Room, frames_n: int, keys := {}) -> void:
	for f in range(frames_n):
		step_keys(r, keys)

# MVB2-06: SCRAPER, WORM, DDOS, SPYWARE
func t_w6enemies() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# SCRAPER: hangs, drops on a player under it, climbs back; no harm while it hangs
	var r := bare_room("R01", 100.0, 192.0)
	var sc := Scraper.new(r, 96, 112)
	r.add_entity(sc)
	if sc.harmboxes().size() != 0:
		fail(res, "a hanging scraper hurts")
	var dropped := false
	var min_len := 1e9
	var max_len := 0.0
	for f in range(240):
		step_keys(r, {})
		r.player.x = 100.0
		r.player.y = 192.0
		r.player.vy = 0.0
		r.player.inv = 99.0
		if sc.state == "drop" or sc.state == "wait":
			dropped = true
		max_len = maxf(max_len, sc.len)
		if sc.state == "tell" and sc.harmboxes().size() != 1:
			fail(res, "a shivering scraper has no harmbox")
	if not dropped or max_len < 40.0:
		fail(res, "the scraper did not drop (max len %.0f)" % max_len)
	r.player.x = 180.0
	run_room(r, 300)
	if sc.state != "hang" or sc.len > 9.0:
		fail(res, "the scraper did not climb back (%s %.0f)" % [sc.state, sc.len])
	r.queue_free()
	# WORM: not hittable in crawl, hittable out; it bites a player next to its membrane
	var rw := bare_room("N13", 0.0, 0.0)
	var wm: Worm = null
	for e in rw.ents:
		pass
	rw.queue_free()
	rw = new_room("N13")
	for e in rw.ents:
		if e is Worm:
			wm = e
	if wm == null:
		fail(res, "N13 has no worm")
	else:
		rw.player.inv = 99.0
		rw.player.x = wm.x - 40.0
		rw.player.y = wm.y + 6.0
		step_keys(rw, {})
		if wm.state != "crawl" or wm.hurtboxes().size() != 0:
			fail(res, "a crawling worm can be hit")
		var bitten := false
		var was_hit_box := false
		for f in range(180):
			rw.player.x = wm.face_x(-1.0) - 14.0
			rw.player.y = wm.y + 6.0
			rw.player.hp = rw.player.max_hp
			rw.player.inv = 0.0
			step_keys(rw, {})
			if wm.state == "out" and wm.hurtboxes().size() == 1:
				was_hit_box = true
			if rw.player.hp < rw.player.max_hp:
				bitten = true
				break
		if not was_hit_box and not bitten:
			fail(res, "the worm never put its head out")
	rw.queue_free()
	# DDOS: a letter makes five bits; a bit that touches the player hurts it and is gone
	var rd := bare_room("R01", 200.0, 192.0)
	var bits := rd.spawn_ddos(120.0, 176.0)
	if bits.size() != 5:
		fail(res, "a DDOS makes %d bits" % bits.size())
	var hp0: int = rd.player.hp
	run_room(rd, 200)
	var left := 0
	for b in bits:
		if is_instance_valid(b) and not b.dead:
			left += 1
	if rd.player.hp >= hp0 or left >= 5:
		fail(res, "the swarm did not reach the player (hp %d/%d, %d left)" % [rd.player.hp, hp0, left])
	rd.queue_free()
	# SPYWARE: the beam angle is fixed from lock to the end of fire; a player who leaves the line is not hurt
	var rs := bare_room("R01", 160.0, 192.0)
	var sw := Spyware.new(rs, 96, 176)
	rs.add_entity(sw)
	rs.player.inv = 0.0
	var angles: Array = []
	var saw_fire := false
	for f in range(240):
		if sw.state == "lock" or sw.state == "fire":
			angles.append(snappedf(sw.angle, 0.0001))
			if sw.state == "lock":
				rs.player.x = 300.0                                  # (steps off the locked line)
				rs.player.y = 40.0
		else:
			rs.player.x = 160.0
			rs.player.y = 192.0
		if sw.state == "fire":
			saw_fire = true
		rs.player.hp = rs.player.max_hp if sw.state != "fire" else rs.player.hp
		step_keys(rs, {})
	if not saw_fire:
		fail(res, "the spyware never fired")
	for a in angles:
		if a != angles[0]:
			fail(res, "the beam angle moved while locked: %s" % str(angles.slice(0, 6)))
			break
	if rs.player.hp < rs.player.max_hp:
		fail(res, "a player off the locked line was hurt")
	rs.queue_free()
	Game.fresh()
	return finish_w6enemies(res)

# (4B-3 adds its checks for the reworked enemies here)
func finish_w6enemies(res: Dictionary) -> bool:
	return report("w6enemies", res.ok, res.info)

func box_key(arr: Array) -> Array:
	var o: Array = []
	for b in arr:
		o.append([roundi(b.x), roundi(b.y), roundi(b.w), roundi(b.h)])
	return o

func same_boxes(a: Array, b: Array) -> bool:
	var ka := box_key(a)
	var kb := box_key(b)
	if ka.size() != kb.size():
		return false
	for i in range(ka.size()):
		for j in range(4):
			if absi(ka[i][j] - kb[i][j]) > 2:
				return false
	return true

# MVB2-07: WEB CRAWLER
# runs the room until the boss's plan reaches `ph` (or ends); the player is kept alive and where it was put
func fw_until(r: Room, fw: FirewallBoss, id: String, ph: String, keep: Vector2, max_f := 600) -> bool:
	for f in range(max_f):
		r.player.inv = 99.0
		r.player.hp = r.player.max_hp
		r.player.x = keep.x
		r.player.y = keep.y
		r.player.vx = 0.0
		r.player.vy = 0.0
		r.step(Game.STEP)
		fw.idle_t = 999.0
		if not fw.plan.is_empty() and String(fw.plan.id) == id and String(fw.plan.ph) == ph:
			return true
	return false

# MVB2-08: THE FIREWALL
func t_firewall() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var r := new_room("N15")
	var fw: FirewallBoss = null
	for e in r.ents:
		if e is FirewallBoss:
			fw = e
	if fw == null or r.boss != fw:
		fail(res, "N15 has no FirewallBoss")
		r.queue_free()
		return report("firewall", false, res.info)
	if fw.max_hp != Game.boss_hp(r.def.boss) or fw.max_hp < 58 or fw.max_hp > 60:
		fail(res, "hp %d" % fw.max_hp)
	r.player.x = 100.0
	r.player.y = 150.0
	var n := 0
	while r.fight.state != "active" and n < 400:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if r.fight.state != "active":
		fail(res, "the fight never started")
	fw.plan = {}
	fw.idle_t = 999.0
	fw.x = 280.0
	fw.y = Boss.FLOOR - fw.h
	fw.face = -1.0
	r.attacker = r.player
	# the shield: a swipe from the front is blocked, from behind it lands, from above (dx 0) it lands
	var hp0 := fw.hpf
	if fw.hit(1, 1.0, 0.0, "swipe", fw) != "block" or fw.hpf != hp0:
		fail(res, "a front swipe was not blocked")
	if fw.hit(1, -1.0, 0.0, "swipe", fw) == "block" or fw.hpf >= hp0:
		fail(res, "a back swipe did not land")
	hp0 = fw.hpf
	fw.hit(1, 0.0, 1.0, "swipe", fw)
	if fw.hpf >= hp0:
		fail(res, "a pogo from above did not land")
	# rule 8: hit from the right while facing left -> after the recovery it faces right
	r.player.x = 340.0
	r.player.y = 146.0
	fw.read.update(0.2)
	fw.face = -1.0
	fw.turn_t = 0.0
	fw.hit(1, -1.0, 0.0, "swipe", fw)
	fw._turn()
	if fw.face != 1.0 or fw.turn_t <= 0.0:
		fail(res, "rule 8: face %s turn %.2f" % [str(fw.face), fw.turn_t])
	fw.turn_t = 0.0
	# throw -> return: the shield is away from the throw's active to the end of the return: a front swipe lands
	fw.face = -1.0
	fw.x = 280.0
	fw.read.last_key = ""
	fw.hpf = float(fw.max_hp)
	var pos := Vector2(120.0, 146.0)
	fw._start("throw", "p1")
	if not fw_until(r, fw, "throw", "active", pos):
		fail(res, "throw never turned active")
	if fw.shield_on or fw.blocks(1.0, 0.0, "swipe"):
		fail(res, "the shield is on during the throw")
	if fw.harmboxes().size() != 1:
		fail(res, "the throw has %d harmboxes" % fw.harmboxes().size())
	var chained := false
	for f in range(400):
		r.player.inv = 99.0
		r.player.hp = r.player.max_hp
		r.player.x = pos.x
		r.player.y = pos.y
		r.step(Game.STEP)
		fw.idle_t = 999.0
		if not fw.plan.is_empty() and String(fw.plan.id) == "return":
			chained = true
			break
	if not chained:
		fail(res, "the throw was not followed by a return")
	if fw.blocks(1.0, 0.0, "swipe"):
		fail(res, "the shield blocks during the return")
	if not fw_until(r, fw, "return", "recover", pos):
		fail(res, "the return never reached recover")
	for f in range(200):
		r.step(Game.STEP)
		fw.idle_t = 999.0
		r.player.inv = 99.0
		if fw.plan.is_empty():
			break
	if not fw.shield_on:
		fail(res, "the shield did not come back after the return")
	# scan: never burns the open lane (>= 96 px); two lanes burn; the open lane is next to the target's lane
	for tx in [60.0, 190.0, 320.0]:
		fw.plan = {}
		fw.x = 280.0
		var spot := Vector2(tx - r.player.w / 2.0, 146.0)
		r.player.x = spot.x
		r.player.y = spot.y
		fw._start("scan", "p1")
		fw.plan.t = 0.01
		if not fw_until(r, fw, "scan", "active", spot):
			fail(res, "scan never active at x %.0f" % tx)
			continue
		var hb := fw.harmboxes()
		var lane: Array = FirewallBoss.LANES[fw.open_lane]
		if hb.size() != 2:
			fail(res, "scan at %.0f burns %d lanes" % [tx, hb.size()])
		for b in hb:
			if b.x < lane[1] and b.x + b.w > lane[0]:
				fail(res, "scan at %.0f burns the open lane" % tx)
		if lane[1] - lane[0] < 96.0:
			fail(res, "open lane %.0f px" % (lane[1] - lane[0]))
		if fw.lane_of(tx) == fw.open_lane:
			fail(res, "scan at %.0f opens the target's own lane" % tx)
		# parity of the boxes mid-active
		var pup = NetClasses.make(31, r)
		NetClasses.apply(pup, JSON.parse_string(JSON.stringify(NetClasses.record(fw))))
		pup.x = fw.x
		pup.y = fw.y
		if not same_boxes(fw.harmboxes(), pup.harmboxes()):
			fail(res, "scan parity at %.0f" % tx)
		pup.free()
	fw.plan = {}
	# a caught packet: 2 damage, the shield is off for 1.6 s
	fw.x = 280.0
	fw.face = -1.0
	fw.shield_on = true
	fw.shield_t = 0.0
	fw.turn_t = 0.0
	hp0 = fw.hpf
	fw.hit(2, 1.0, 0.0, "catch", fw)
	if fw.hpf > hp0 - 2.0 + 0.01 or fw.shield_t < 1.5 or fw.blocks(1.0, 0.0, "swipe"):
		fail(res, "caught packet: hp %.1f -> %.1f shield_t %.2f" % [hp0, fw.hpf, fw.shield_t])
	fw.shield_t = 0.0
	# deny shoots a catchable orb
	fw.plan = {}
	fw._start("deny", "p1")
	fw.plan.t = 0.01
	var before := r.projs.size()
	if not fw_until(r, fw, "deny", "active", Vector2(60.0, 146.0)):
		fail(res, "deny never active")
	var orb := false
	for q in r.projs:
		if q.get("catchable", false) and not q.dead:
			orb = true
	if not orb:
		fail(res, "deny made no catchable orb (%d projs)" % (r.projs.size() - before))
	fw.plan = {}
	for q in r.projs:
		q.dead = true
	# phase (P2): the boss ends up on the other side of a membrane, with a slash at the exit
	fw.hpf = float(fw.max_hp) * 0.5
	fw.on_damage()
	if fw.phase != 2:
		fail(res, "no phase 2 at 50%")
	fw.x = 180.0
	fw.y = Boss.FLOOR - fw.h
	fw.face = 1.0
	var side0 := fw.cx
	fw._start("phase", "p1")
	if not fw_until(r, fw, "phase", "active", Vector2(300.0, 146.0), 900):
		fail(res, "phase never active")
	var mid_boxes := fw.harmboxes().size()
	if not fw_until(r, fw, "phase", "recover", Vector2(300.0, 146.0), 200):
		fail(res, "phase never recovered")
	var crossed: bool = (side0 < 112.0 and fw.cx > 128.0) or (side0 > 128.0 and side0 < 256.0 and (fw.cx > 272.0 or fw.cx < 112.0)) or (side0 > 272.0 and fw.cx < 256.0)
	if not crossed or mid_boxes != 1:
		fail(res, "phase: cx %.0f -> %.0f, %d slash boxes" % [side0, fw.cx, mid_boxes])
	fw.plan = {}
	# the kill: ssh, boss:FIREWALL, N15:E opens
	Game.flags = {}
	Game.tools = {}
	if not r.skip_boss():
		fail(res, "skip boss refused")
	n = 0
	while r.fight.state != "done" and n < 900:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if not Game.flag("ability:ssh") or not Game.flag("boss:FIREWALL") or not Game.tools.get("ssh", false):
		fail(res, "reward missing (state %s)" % r.fight.state)
	r.update_doors()
	for d in r.grid.doors:
		if String(d.to).begins_with("N16") and not d.open:
			fail(res, "N15:E stayed shut")
	r.queue_free()
	Game.fresh()
	return report("firewall", res.ok, res.info)

func on_pad(r: Room) -> void:
	r.player.x = 11.0 * 16.0 + 8.0 - r.player.w / 2.0
	r.player.y = 176.0 - r.player.h
	r.player.vx = 0.0
	r.player.vy = 0.0
	r.player.inv = 99.0

# MVB2-09: THE REVIEWER #2
func t_reviewer2() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	# [up] on the chair without curl/ssh: nothing starts
	var r := new_room("N22")
	var rv: Reviewer2 = null
	for e in r.ents:
		if e is Reviewer2:
			rv = e
	if rv == null or r.boss != rv:
		fail(res, "N22 has no Reviewer2")
		r.queue_free()
		return report("reviewer2", false, res.info)
	if rv.max_hp != Game.boss_hp(r.def.boss) or rv.max_hp < 57 or rv.max_hp > 61:
		fail(res, "hp %d" % rv.max_hp)
	on_pad(r)
	for f in range(6):
		on_pad(r)
		step_keys(r, {"up": true} if f == 3 else {})
	if r.fight.state != "none":
		fail(res, "the fight started without curl/ssh")
	# walking through the arena never starts it
	for f in range(240):
		r.player.x = 20.0 + float(f) * 1.3
		r.player.y = 176.0 - r.player.h
		r.player.inv = 99.0
		step_keys(r, {"up": f % 7 == 0})
	if r.fight.state != "none":
		fail(res, "walking through started the fight")
	# with a tool of the network, [up] on the chair starts the intro
	Game.flags["ability:ssh"] = true
	for f in range(6):
		on_pad(r)
		step_keys(r, {"up": true} if f == 3 else {})
	if r.fight.state != "intro":
		fail(res, "[up] on the chair did not start the intro (%s)" % r.fight.state)
	var n := 0
	while r.fight.state != "active" and n < 400:
		on_pad(r)
		r.step(Game.STEP)
		n += 1
	if r.fight.state != "active":
		fail(res, "the fight never became active")
	rv.plan = {}
	rv.idle_t = 999.0
	rv.x = 250.0
	rv.y = Boss.FLOOR - rv.h
	rv.face = -1.0
	r.attacker = r.player
	# cached: three up-swipes -> the icon is "up"; an up claw is blocked, a side claw lands
	for i in range(3):
		rv.hit(1, 0.0, -1.0, "swipe", rv)
	if rv.last_kind.p1 != "up":
		fail(res, "last kind %s" % rv.last_kind.p1)
	rv.hpf = float(rv.max_hp)
	r.player.x = 150.0
	r.player.y = 150.0
	rv._start("cached", "p1")
	if rv.cached_kind != "up":
		fail(res, "cached shows %s" % rv.cached_kind)
	if not fw_until2(r, rv, "cached", "active", Vector2(150.0, 150.0)):
		fail(res, "cached never active")
	var hp0 := rv.hpf
	if rv.hit(1, 0.0, -1.0, "swipe", rv) != "block" or rv.hpf != hp0:
		fail(res, "an up claw was not blocked")
	if rv.riposte_to != "p1":
		fail(res, "no riposte owed")
	rv.plan = {}
	rv._start("cached", "p1")
	rv.last_kind["p1"] = "up"
	rv.cached_kind = "up"
	if not fw_until2(r, rv, "cached", "active", Vector2(150.0, 150.0)):
		fail(res, "cached (2) never active")
	hp0 = rv.hpf
	rv.hit(1, -1.0, 0.0, "swipe", rv)
	if rv.hpf >= hp0:
		fail(res, "a side claw was blocked by an up cache")
	rv.plan = {}
	rv.riposte_to = ""
	# the riposte follows a block
	rv.riposte_to = "p1"
	rv.idle_t = 0.0
	r.step(Game.STEP)
	if rv.plan.is_empty() or String(rv.plan.id) != "riposte":
		fail(res, "no riposte after a block (%s)" % str(rv.plan.get("id")))
	rv.plan = {}
	# verdict: a diamond (catchable) and a grey orb (not)
	for q in r.projs:
		q.dead = true
	r.projs.clear()
	rv.idle_t = 999.0
	rv._start("verdict", "p1")
	var seen_c := false
	var seen_n := false
	for f in range(60 * 4):
		r.player.inv = 99.0
		r.player.hp = r.player.max_hp
		r.player.x = 150.0
		r.player.y = 150.0
		r.step(Game.STEP)
		rv.idle_t = 999.0
		for q in r.projs:
			if q.get("by_boss", false):
				if q.get("catchable", false):
					seen_c = true
				else:
					seen_n = true
		if rv.plan.is_empty():
			break
	if not seen_c or not seen_n:
		fail(res, "verdict shots: catchable %s, not catchable %s" % [str(seen_c), str(seen_n)])
	if rv.shots != 4:
		fail(res, "verdict fired %d shots" % rv.shots)
	# parity of the boxes: double, cross, signoff
	for id in ["double", "cross", "signoff"]:
		rv.plan = {}
		rv.x = 250.0
		rv._start(id, "p1")
		rv.plan.t = 0.01
		if not fw_until2(r, rv, id, "active", Vector2(150.0, 150.0)):
			fail(res, "%s never active" % id)
			continue
		var pup = NetClasses.make(32, r)
		NetClasses.apply(pup, JSON.parse_string(JSON.stringify(NetClasses.record(rv))))
		pup.x = rv.x
		pup.y = rv.y
		if rv.harmboxes().is_empty() or not same_boxes(rv.harmboxes(), pup.harmboxes()):
			fail(res, "%s parity (%d boxes)" % [id, rv.harmboxes().size()])
		pup.free()
	rv.plan = {}
	# the kill: the plugin flag and the boss flag, but no tool (skip boss from an unstarted pad fight works too)
	r.queue_free()
	Game.flags = {}
	Game.tools = {}
	r = new_room("N22")
	rv = r.boss
	if not r.skip_boss():
		fail(res, "skip boss refused")
	n = 0
	while r.fight.state != "done" and n < 900:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if not Game.flag("plugin:review_cache") or not Game.flag("boss:REVIEWER2"):
		fail(res, "reward flags missing (state %s)" % r.fight.state)
	if not Game.tools.is_empty():
		fail(res, "a tool was given: %s" % str(Game.tools.keys()))
	if r.sign_text(r.def.signs[0]) != "2nd review: approved. LGTM.":
		fail(res, "sign: %s" % r.sign_text(r.def.signs[0]))
	r.queue_free()
	Game.fresh()
	return report("reviewer2", res.ok, res.info)

func fw_until2(r: Room, b, id: String, ph: String, keep: Vector2, max_f := 600) -> bool:
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

# MVB2-10: gzip, sourcemap, rate_limit, review cache
func t_plugins4b() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	for id in ["gzip", "sourcemap", "rate_limit", "review_cache"]:
		if Game.plugin_def(id).is_empty():
			fail(res, "no plugin " + id)
	var rj: Dictionary = Game.rooms_meta.rooms
	for pr in [["H16", "gzip"], ["H14", "sourcemap"], ["N21", "rate_limit"]]:
		if not (rj[pr[0]].get("plugins", []) as Array).has(pr[1]):
			fail(res, "%s does not hold %s" % pr)
	# rate_limit: a second hurt at 2.9 s is ignored, one at 3.1 s lands
	Game.equipped = ["rate_limit"]
	var r := bare_room("R01", 100.0, 150.0)
	var p = r.player
	p.hp = p.max_hp
	p.inv = 0.0
	if not p.hurt(1, p.x - 10.0):
		fail(res, "the first hurt did not land")
	var hp1: int = p.hp
	for f in range(int(2.9 / Game.STEP)):
		p.update(Game.STEP)
		p.inv = 0.0
	if p.hurt(1, p.x - 10.0) or p.hp != hp1:
		fail(res, "a hurt at 2.9 s landed")
	for f in range(int(0.3 / Game.STEP)):
		p.update(Game.STEP)
		p.inv = 0.0
	if not p.hurt(1, p.x - 10.0) or p.hp != hp1 - 1:
		fail(res, "a hurt at 3.2 s was ignored")
	Game.equipped = []
	p.rate_cd = 0.0
	p.inv = 0.0
	p.hurt(1, p.x - 10.0)
	p.inv = 0.0
	var hp2: int = p.hp
	p.hurt(1, p.x - 10.0)
	if p.hp != hp2 - 1:
		fail(res, "without rate_limit two hits in a row should both land")
	# review cache: a catch arms +1 for exactly one hit
	Game.equipped = ["review_cache"]
	p.cache_bonus = false
	var q := {"id": 9001, "x": 120.0, "y": 150.0, "vx": -60.0, "vy": 0.0, "r": 3.0, "kind": "diamond", "col": "#ffd23f", "life": 2.0, "g": 0.0, "dmg": 1, "tile": true, "cut": true, "t": 0.0, "dead": false, "friendly": false, "catchable": true}
	r.catch_proj(q, p)
	if not p.cache_bonus:
		fail(res, "a catch did not arm the review cache")
	p.atk_cd = 0.0
	p.atk_buf = 1.0
	p.atk_t = 0.0
	p.dash_t = 0.0
	p.hurt_t = 0.0
	p.update(Game.STEP)
	if p.atk_dmg != 2:
		fail(res, "the armed swing deals %d" % p.atk_dmg)
	p.on_hit(null, "hit", {"x": 100.0, "y": 150.0, "w": 10.0, "h": 10.0})
	if p.cache_bonus or p.atk_dmg != 1:
		fail(res, "the bonus was not spent (bonus %s, dmg %d)" % [str(p.cache_bonus), p.atk_dmg])
	p.atk_cd = 0.0
	p.atk_buf = 1.0
	p.atk_t = 0.0
	p.update(Game.STEP)
	if p.atk_dmg != 1:
		fail(res, "the next swing still deals %d" % p.atk_dmg)
	Game.equipped = []
	p.cache_bonus = false
	r.catch_proj(q.duplicate(), p)
	if p.cache_bonus:
		fail(res, "a catch armed the cache without the plugin")
	r.queue_free()
	# gzip: two pickups give 3
	Game.equipped = ["gzip"]
	Game.gz_n = 0
	Game.tokens = 0
	var rg := bare_room("R01", 100.0, 150.0)
	rg.collect({"kind": "token", "x": 100.0, "y": 150.0, "id": "item:R01:901", "dead": false})
	rg.collect({"kind": "token", "x": 100.0, "y": 150.0, "id": "item:R01:902", "dead": false})
	if Game.tokens != 3:
		fail(res, "two pickups gave %d" % Game.tokens)
	Game.equipped = []
	Game.tokens = 0
	rg.collect({"kind": "token", "x": 100.0, "y": 150.0, "id": "item:R01:903", "dead": false})
	rg.collect({"kind": "token", "x": 100.0, "y": 150.0, "id": "item:R01:904", "dead": false})
	if Game.tokens != 2:
		fail(res, "without gzip two pickups gave %d" % Game.tokens)
	rg.queue_free()
	# the host counts a guest's gzip: every second one is worth two
	if Game.gz_bonus(0) or not Game.gz_bonus(1) or Game.gz_bonus(2) or not Game.gz_bonus(3):
		fail(res, "gz_bonus pattern")
	# sourcemap: dots in a mapped room, none in an unmapped one, none off-map
	Game.flags = {}
	Game.equipped = ["sourcemap"]
	var mv := MapView.new()
	Game.flags["map:" + Game.zone_of("H16")] = true
	Game.flags["map:" + Game.zone_of("N20")] = true
	var before := mv.sourcemap_list(["H16", "N20"])
	if not before.is_empty():
		fail(res, "dots in an unmapped room")
	Game.flags["mapped:H16"] = true
	Game.flags["mapped:N20"] = true
	var lst := mv.sourcemap_list(["H16", "N20"])
	var kinds := {}
	for mk in lst:
		kinds[mk.kind] = true
		if mk.id == "N20":
			fail(res, "a dot in an off-map room")
	if not kinds.has("plugin"):
		fail(res, "H16 shows no plugin dot (%s)" % str(lst))
	Game.flags["plugin:gzip"] = true
	for mk in mv.sourcemap_list(["H16"]):
		if mk.kind == "plugin":
			fail(res, "a collected plugin still shows")
	Game.equipped = []
	if not mv.sourcemap_list(["H16"]).is_empty():
		fail(res, "dots without the plugin")
	mv.free()
	Game.fresh()
	return report("plugins4b", res.ok, res.info)

# MVB2-11: the 4B-1 systems in THE NETWORK
func t_net4b1() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# every N room is in the zone
	for id in Game.rooms_meta.rooms:
		if id.begins_with("N") and Game.zone_of(id) != "net":
			fail(res, "%s is in zone %s" % [id, Game.zone_of(id)])
	# `tree` in N06 sells map:net
	var menu := IndexMenu.new()
	main.add_child(menu)
	var r6 := new_room("N06")
	if r6.npcs.size() != 1 or r6.npcs[0].zone != "net" or r6.npcs[0].price != 40 or r6.npcs[0].kind != "tree":
		fail(res, "N06 npc: %s" % str(r6.npcs))
	else:
		Game.tokens = 40
		menu.open(r6, r6.npcs[0])
		if menu.rows()[0] != "index /net — 40 tokens":
			fail(res, "row: %s" % str(menu.rows()))
		if not menu.buy() or not Game.owns_map("net") or Game.tokens != 0:
			fail(res, "buying the net index")
		menu.close()
	menu.queue_free()
	r6.queue_free()
	# N20's agent frees with a swipe
	var r20 := new_room("N20")
	if r20.jars.size() != 1:
		fail(res, "N20 has %d jars" % r20.jars.size())
	else:
		for e in r20.ents:
			e.queue_free()
		r20.ents.clear()
		var jar: Dictionary = r20.jars[0]
		var p = r20.player
		p.x = float(jar.x) - 22.0
		p.y = float(jar.y) - p.h
		p.vx = 0.0
		p.vy = 0.0
		p.face = 1.0
		for f in range(16):
			Controls.script_input = {"attack": f < 2}
			Controls.poll()
			r20.step(Game.STEP)
		Controls.script_input = {}
		if not Game.flag("agent:N20"):
			fail(res, "a swipe did not free N20's agent")
	# N19: the page and the fragment
	var r19 := new_room("N19")
	var page_item: Dictionary = {}
	var spark_n := 0
	for it in r19.items:
		if it.kind == "page":
			page_item = it
		if it.kind == "spark":
			spark_n += 1
	if page_item.is_empty() or String(page_item.id) != "page:2":
		fail(res, "N19 page: %s" % str(page_item))
	else:
		r19.collect(page_item)
		if not Game.flag("page:2"):
			fail(res, "page:2 not set")
	if spark_n != 1:
		fail(res, "N19 has %d fragments" % spark_n)
	else:
		for it in r19.items:
			if it.kind == "spark":
				r19.collect(it)
		if String(r19.memory.get("text", "")) != "04:47 — the backup still had last week's working build.":
			fail(res, "memory: %s" % str(r19.memory))
	r19.queue_free()
	# N20 is on no map
	Game.flags["room:N20:visited"] = true
	var v := Game.map_view("net")
	if v.outline.has("N20") or v.filled.has("N20"):
		fail(res, "N20 is on the map")
	if not Game.is_offmap("N20") or Game.commit_rooms(["N20"]) != 0:
		fail(res, "N20 can be committed")
	if Game.zone_counts("net")[1] != v.outline.size() or v.outline.has("N19") or v.outline.has("N21"):
		fail(res, "the net outline shows a secret: %s" % str(v.outline))
	r20.queue_free()
	# N03: a terminal with a bench, nothing near it
	var r3 := new_room("N03")
	if not bool(r3.def.get("terminal", false)) or r3.cps.is_empty():
		fail(res, "N03 is no terminal")
	for c in r3.cps:
		for e in r3.ents:
			var d := Vector2(float(e.x) + float(e.w) / 2.0 - float(c.x), float(e.y) + float(e.h) / 2.0 - float(c.y)).length() / 16.0
			if d < 10.0:
				fail(res, "N03: a %s %.1f tiles from the bench" % [e.get_class(), d])
	r3.queue_free()
	# hooks are curl obstacles; the changelog names /proc/heap and /net after curl
	if Game.OBSTACLES.get("c", "") != "curl":
		fail(res, "c is not a curl obstacle")
	if Game.obstacle_marks("N08").is_empty():
		fail(res, "N08's hooks are not marked")
	Game.flags["map:heap"] = true
	Game.flags["mapped:H01"] = true
	Game.flags["mapped:N08"] = true
	Game.flags["mapped:N05"] = true
	Game.tools["curl"] = true
	var mgr := new_manager()
	mgr.swap_to("N03")
	mgr.rest(mgr.room, 0)
	var said := " | ".join(mgr.changelog_shown)
	if not said.contains("/proc/heap answers to curl") or not said.contains("/net answers to curl"):
		fail(res, "changelog: %s" % said)
	mgr.queue_free()
	Game.fresh()
	return report("net4b1", res.ok, res.info)

# one frame of a small bot: walk to x `tx` (centre), jump while the feet are below `feet_y`; true when it stands there
func bot_step(m: RoomManager, tx: float, feet_y: float, extra := {}) -> bool:
	var p = m.player
	var cxp: float = p.x + p.w / 2.0
	var keys := extra.duplicate()
	if cxp < tx - 3.0:
		keys["right"] = true
	elif cxp > tx + 3.0:
		keys["left"] = true
	var feet: float = p.y + p.h
	if (feet > feet_y + 4.0 and absf(cxp - tx) < 30.0 and p.on_ground) or (not p.on_ground and p.vy < 0.0):
		keys["jump"] = true                                  # (held while it rises: a short press is a short hop)
	Controls.script_input = keys
	p.hp = p.max_hp
	m.tick(Game.STEP)
	return p.on_ground and absf(p.y + p.h - feet_y) < 3.0 and absf(p.x + p.w / 2.0 - tx) < 8.0

func run_keys(m: RoomManager, keys: Dictionary, n: int, stop_room := "") -> void:
	for f in range(n):
		Controls.script_input = keys
		m.player.hp = m.player.max_hp
		m.tick(Game.STEP)
		if stop_room != "" and m.room.id == stop_room and not m.trans.on:
			break
	Controls.script_input = null

# MVB2-12 (3): the secrets of N05 (N19 above, N20 below) and N13 (N21 under the crack)
func secrets4b(res: Dictionary) -> void:
	Game.flags = {}
	Game.tools = {"bash": true, "catch": true, "sudo": false, "agents": true, "opus": false, "curl": false, "ssh": false}
	var m := new_manager()
	# N05 -> N19: a jump from the ledge at (70, 4)
	m.swap_to("N05", Vector2(70.0 * 16.0 + 6.0, 4.0 * 16.0 - 14.0), null, true)
	m.room.ents.clear()
	m.player.vx = 0.0
	m.player.vy = 0.0
	for f in range(30):
		m.tick(Game.STEP)
	var feet0: float = m.player.y + m.player.h
	if m.room.id != "N05" or absf(feet0 - 4.0 * 16.0) > 3.0:
		fail(res, "N05: not standing on the ledge (%s, feet %.0f)" % [m.room.id, feet0])
	run_keys(m, {"jump": true}, 80, "N19")
	if m.room.id != "N19":
		fail(res, "N05: a jump from the ledge did not reach N19 (%s)" % m.room.id)
	else:
		run_keys(m, {"jump": true}, 24)                                   # (the hop out of the doorway: jump stays held, as a player's thumb does)
		run_keys(m, {}, 100)
		if not m.player.on_ground or not Game.flag("dead:N05"):
			fail(res, "N19: arrival (ground %s, dead:N05 %s)" % [str(m.player.on_ground), str(Game.flag("dead:N05"))])
		# dropping through the lid lands back on the ledge
		run_keys(m, {"down": true, "jump": true}, 3)                      # (a short press: a held [down] would also drop through the ledge below)
		for f in range(200):
			Controls.script_input = null
			m.tick(Game.STEP)
			if m.room.id == "N05" and not m.trans.on and f > 40:
				break
		run_keys(m, {}, 60)
		var fy: float = m.player.y + m.player.h
		if m.room.id != "N05" or not m.player.on_ground or absf(fy - 4.0 * 16.0) > 3.0:
			fail(res, "N19: the lid did not drop back onto the ledge (%s feet %.0f)" % [m.room.id, fy])
	# N05 -> N20: down+jump on the lid at (53, 17), then climb out
	m.swap_to("N05", Vector2(53.0 * 16.0 + 3.0, 17.0 * 16.0 - 14.0), null, true)
	m.room.ents.clear()
	m.player.vx = 0.0
	m.player.vy = 0.0
	run_keys(m, {}, 20)
	run_keys(m, {"down": true, "jump": true}, 3)
	run_keys(m, {}, 200, "N20")
	if m.room.id != "N20":
		fail(res, "N05: down+jump on the lid did not reach N20 (%s)" % m.room.id)
	else:
		if not Game.flag("dead:N05"):
			fail(res, "N20 reached without dead:N05")
		run_keys(m, {}, 60)
		var legs := [[136.0, 144.0], [168.0, 144.0], [196.0, 96.0], [224.0, 48.0]]
		var ok := true
		for leg in legs:
			var there := false
			for f in range(240):
				if bot_step(m, leg[0], leg[1]):
					there = true
					break
			if not there:
				ok = false
				fail(res, "N20: the climb stopped before the platform at feet %.0f (player %.0f, %.0f)" % [leg[1], m.player.x, m.player.y + m.player.h])
				break
		if ok:
			for f in range(240):
				var keys := {"jump": f % 12 < 8}
				var cxp: float = m.player.x + m.player.w / 2.0
				if cxp < 221.0:
					keys["right"] = true
				elif cxp > 227.0:
					keys["left"] = true
				Controls.script_input = keys
				m.player.hp = m.player.max_hp
				m.tick(Game.STEP)
				if m.room.id == "N05" and not m.trans.on:
					break
			Controls.script_input = null
			run_keys(m, {}, 60)
			var fy2: float = m.player.y + m.player.h
			if m.room.id != "N05" or not m.player.on_ground or absf(fy2 - 17.0 * 16.0) > 3.0 or absf(m.player.x + 5.0 - 53.0 * 16.0 - 8.0) > 40.0:
				fail(res, "N20: the way out did not land on the lid (%s, %.0f,%.0f)" % [m.room.id, m.player.x, fy2])
	# N13 -> N21: the crack at (35, 21) breaks under a dash down; the door above is shut until wave:N21
	Game.flags.erase("dead:N05")
	m.swap_to("N13", Vector2(35.0 * 16.0 + 3.0, 19.0 * 16.0), null, true)
	m.room.ents.clear()
	m.player.vx = 0.0
	m.player.vy = 0.0
	run_keys(m, {}, 10)
	var broke := false
	for f in range(150):
		var keys2 := {}
		if f < 4:
			keys2["jump"] = true
		keys2["dash"] = f == 8
		keys2["down"] = f >= 7
		Controls.script_input = keys2
		m.player.hp = m.player.max_hp
		m.tick(Game.STEP)
		if Game.flag("crack:N13:35:21") or Game.flag("crack:N13:34:21"):
			broke = true
		if m.room.id == "N21" and not m.trans.on:
			break
	Controls.script_input = null
	if not broke:
		fail(res, "N13: the crack did not break")
	if m.room.id != "N21":
		fail(res, "N13: the crack did not lead into N21 (%s)" % m.room.id)
	else:
		var dn = m.room.grid.door_at("N", 21)
		if dn == null or dn.open:
			fail(res, "N21: the door above is not shut")
		Game.flags["wave:N21"] = true
		m.room.update_doors()
		dn = m.room.grid.door_at("N", 21)
		if dn == null or not dn.open:
			fail(res, "N21: the door above stays shut after wave:N21")
	m.queue_free()
	await frames(1)
