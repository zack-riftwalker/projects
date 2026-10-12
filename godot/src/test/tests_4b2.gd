extends RefCounted
class_name Tests4b2
# Unit tests of phase 4B-2 (THE NETWORK). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["rooms4b", "w6assets", "curl", "ssh", "net4b", "w6enemies"]

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
			if e is DdosBit:
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
	return report("w6enemies", res.ok, res.info)
