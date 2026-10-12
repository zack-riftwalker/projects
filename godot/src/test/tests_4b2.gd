extends RefCounted
class_name Tests4b2
# Unit tests of phase 4B-2 (THE NETWORK). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["rooms4b", "w6assets", "curl", "ssh", "net4b", "w6enemies", "crawler", "firewall"]

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
		"crawler": return t_crawler()
		"firewall": return t_firewall()
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
func t_crawler() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var r := new_room("N09")
	var cb: CrawlerBoss = null
	for e in r.ents:
		if e is CrawlerBoss:
			cb = e
	if cb == null or r.boss != cb:
		fail(res, "N09 has no CrawlerBoss")
		r.queue_free()
		return report("crawler", false, res.info)
	if cb.max_hp != 56:
		fail(res, "hp %d" % cb.max_hp)
	# intro only when a centre is below x 304
	r.player.x = 340.0
	r.player.y = 150.0
	r.player.inv = 99.0
	for f in range(30):
		r.step(Game.STEP)
	if r.fight.state != "none":
		fail(res, "intro started with the player east of 304")
	r.player.x = 250.0
	r.step(Game.STEP)
	if r.fight.state != "intro":
		fail(res, "intro did not start below 304 (%s)" % r.fight.state)
	var n := 0
	while r.fight.state != "active" and n < 400:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if r.fight.state != "active":
		fail(res, "the fight never became active")
	# harm only in an active phase; the core is out of reach until a recovery; rule 8 picks the node above who stood under it
	var harm_bad := false
	var saw := {}
	var pup = NetClasses.make(30, r)
	var cue_ok := false
	var act_ok := false
	var hurt_in_recover := false
	for f in range(60 * 60):
		r.player.inv = 99.0
		r.player.hp = r.player.max_hp
		r.player.x = 80.0 if (f / 240) % 2 == 0 else 250.0
		r.step(Game.STEP)
		if not cb.plan.is_empty():
			saw[String(cb.plan.id)] = true
			cb.plan_seen(int(cb.plan.seq))
		if not cb.harmboxes().is_empty() and not cb.plan_active():
			harm_bad = true
		if not cb.plan.is_empty() and (cb.plan.ph == "cue" or cb.plan.ph == "active") and cb.plan.id in ["drop", "sweep", "back"]:
			NetClasses.apply(pup, JSON.parse_string(JSON.stringify(NetClasses.record(cb))))
			var same := same_boxes(cb.harmboxes(), pup.harmboxes())
			if cb.plan.ph == "cue":
				cue_ok = same or cue_ok
			elif same and not cb.harmboxes().is_empty():
				act_ok = true
		if cb.plan_phase() == "recover" and cb.plan.id == "drop":
			hurt_in_recover = hurt_in_recover or cb.hurtboxes().size() >= 1
		if act_ok and cue_ok and saw.has("move") and saw.has("drop") and saw.has("volley"):
			break
	pup.free()
	if harm_bad:
		fail(res, "harm outside the active phase")
	if not cue_ok or not act_ok:
		fail(res, "parity cue %s active %s" % [str(cue_ok), str(act_ok)])
	if not (saw.has("move") and saw.has("drop") and saw.has("volley")):
		fail(res, "attacks seen: %s" % str(saw.keys()))
	# rule 8: a long stay under the core makes `move` go to the node above that player
	cb.read.samples = cb.read.samples
	cb.plan = {}
	cb.node = 0
	cb.idle_t = 5.0
	var q = cb.kit_body("p1")
	r.player.x = float(CrawlerBoss.NODES[2].x) - r.player.w / 2.0
	r.player.y = 100.0
	for f in range(70):
		r.player.inv = 99.0
		r.player.vy = 0.0
		r.player.y = 100.0
		cb.read.update(Game.STEP)
		r.step(Game.STEP)
		cb.idle_t = 5.0
	var picked := cb._pick_node()
	if picked == 0:
		fail(res, "rule 8: picked the node the core is on")
	# a jump and an up-swipe hit the core in a drop recovery; a caught packet takes 2 and brings the core down
	cb.plan = {}
	cb.idle_t = 5.0
	cb.hpf = float(cb.max_hp)
	cb.hp = cb.max_hp
	cb.down_t = 0.0
	cb.core_y = float(Boss.FLOOR - 70.0)
	var hp0 := cb.hpf
	r.attacker = r.player
	cb.hit(1, 0.0, -1.0, "swipe", cb)
	if cb.hpf >= hp0:
		fail(res, "a swipe did no damage to the core")
	hp0 = cb.hpf
	cb.hit(2, 0.0, 0.0, "catch", cb)
	if cb.hpf > hp0 - 2.0 + 0.01 or cb.down_t <= 0.0:
		fail(res, "a caught packet: hp %.1f -> %.1f, down %.1f" % [hp0, cb.hpf, cb.down_t])
	# phases at 60% and 25%
	cb.hpf = float(cb.max_hp) * 0.59
	cb.on_damage()
	if cb._phase_now() != 2 or cb.phase != 2:
		fail(res, "no phase 2 at 59%")
	cb.hpf = float(cb.max_hp) * 0.24
	cb.on_damage()
	if cb.phase != 3:
		fail(res, "no phase 3 at 24%")
	# the kill: curl, boss flag, N09:W opens
	Game.flags = {}
	Game.tools = {}
	if not r.skip_boss():
		fail(res, "skip boss refused")
	n = 0
	while r.fight.state != "done" and n < 900:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if not Game.flag("ability:curl") or not Game.flag("boss:CRAWLER") or not Game.tools.get("curl", false):
		fail(res, "reward missing (state %s)" % r.fight.state)
	var w_open := true
	r.update_doors()
	for d in r.grid.doors:
		if String(d.to).begins_with("N08") or String(d.get("side", "")) == "W":
			w_open = w_open and bool(d.open)
	if not w_open:
		fail(res, "N09:W stayed shut")
	r.queue_free()
	Game.fresh()
	return report("crawler", res.ok, res.info)

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
