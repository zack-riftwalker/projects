extends Tests4b2
class_name Tests4b3
# Unit tests of phase 4B-3 (THE NETWORK made hard). run_tests.gd hands names it does not know to run().

const NAMES3 := ["kit4b3", "w6enemies2", "w6enemies", "net4b3", "crawler3", "firewall3", "reviewer2b", "bosspresets", "hardrooms", "fightsim"]

# a boss with one hazard kind, to prove the arena-hazard rules of the kit
class HzBoss extends Boss:
	func _init(r: Room) -> void:
		super(r, 100.0, 176.0, 16, 16, 50)
		boss_name = "HZ"
		kit_init()
	func hz_kinds() -> Array:
		return ["bar"]
	func hz_boxes(h: Dictionary, _now: float) -> Array:
		return [{"x": float(h.v[0]), "y": 100.0, "w": 16.0, "h": 16.0}]
	func plan_ids() -> Array:
		return ["x"]

func run(name: String):
	match name:
		"kit4b3": return t_kit4b3()
		"w6enemies2": return t_w6enemies2()
		"w6enemies": return t_w6enemies()
		"net4b3": return t_net4b3()
		"crawler3": return t_crawler3()
		"firewall3": return t_firewall3()
		"reviewer2b": return t_reviewer2b()
		"bosspresets": return t_bosspresets()
		"hardrooms": return t_hardrooms()
		"fightsim": return t_fightsim()
	return await super.run(name)

func partner(room: Room, px: float, py: float) -> RemotePlayer:
	var rp := RemotePlayer.new(room)
	room.add_child(rp)
	room.remote_players.append(rp)
	rp.x = px
	rp.y = py
	return rp

func t_kit4b3() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	# 1. `rec` replaces the family's recover; x punish_mult; never below 0.4 (a chain's gap under 0.4 is kept as it is)
	for cfg in [["normal", 0.9, 0.9], ["normal", 0.2, 0.2], ["easy", 0.5, 0.65], ["nightmare", 0.4, 0.4], ["nightmare", 0.5, 0.45], ["nightmare", 0.45, 0.405]]:
		Game.diff = cfg[0]
		var room := bare_room("R01", 100.0, 192.0)
		var d := HzBoss.new(room)
		room.add_entity(d)
		d.plan_start("x", "lunge", "p1", [0.0, 0.0, 0.0, 0.0], 0.0, -1.0, float(cfg[1]))
		var ev := ""
		var n := 0
		while ev != "recover" and n < 2000:
			ev = d.plan_step(Game.STEP)
			n += 1
		if absf(d.plan.t - float(cfg[2])) > 0.0001:
			fail(res, "%s rec %.2f -> %.3f, want %.3f" % [cfg[0], cfg[1], d.plan.t, cfg[2]])
		room.queue_free()
	Game.diff = "normal"
	# 2. an arena hazard: drawn from the start, no harm before its warning, the same boxes on a host and a guest built from the same fields
	var rh := bare_room("R01", 300.0, 192.0)
	var hb := HzBoss.new(rh)
	rh.add_entity(hb)
	rh.time = 5.0
	var hz := hb.hz_add("bar", 0.3, [40])
	if absf(float(hz.warn) - 0.6) > 0.001:
		fail(res, "a warning under 0.6 s was accepted (%.2f)" % hz.warn)
	if not hb.hz_all_boxes(5.59).is_empty() or hb.hz_all_boxes(5.61).size() != 1:
		fail(res, "the hazard's harm does not start at its warning")
	var rg := bare_room("R01", 300.0, 192.0)
	rg.mode = "guest"
	var gb := HzBoss.new(rg)
	gb.puppet = true
	rg.add_entity(gb)
	gb.hz_unpack(JSON.parse_string(JSON.stringify(hb.hz_pack())))
	for tm in [5.0, 5.3, 5.59, 5.61, 7.0]:
		if not same_boxes(hb.hz_all_boxes(tm), gb.hz_all_boxes(tm)):
			fail(res, "host and guest boxes differ at %.2f" % tm)
	# the guest is hurt only by what it has looked at for 0.5 s
	rg.time = 5.7
	if not gb.hz_harm().is_empty():
		fail(res, "a hazard the guest has not seen hurts")
	for i in range(31):
		gb.hz_puppet_tick(1.0 / 60.0)
	if gb.hz_harm().size() != 1:
		fail(res, "a hazard seen for 0.5 s does not hurt the guest")
	if gb.arena_violation != "":
		fail(res, "the arena-tell violation fired without a cause")
	gb.hz_gate = 0.0                                              # a broken gate: the rule must notice
	gb.hz_seen = {}
	rg.time = 5.7
	gb.hz_harm()
	if gb.arena_violation == "":
		fail(res, "the arena-tell rule did not fire for an unseen hazard")
	rh.queue_free()
	rg.queue_free()
	# 3. a bouncing shot in a closed box bounces exactly n times and then dies on the next wall
	var rb := bare_room("R01", 300.0, 192.0)
	for ty in range(4, 10):
		for tx in range(10, 20):
			rb.grid.tiles[ty * rb.w + tx] = TileGrid.SOLID if (ty == 4 or ty == 9 or tx == 10 or tx == 19) else TileGrid.E
	var q := rb.shoot(14.0 * 16.0, 7.0 * 16.0, 97.0, 61.0, {"tile": true, "bounce": 3, "life": 30.0})
	var bounces := 0
	var last_b: int = q.bounce
	var inside := true
	for f in range(60 * 20):
		rb.update_projs(Game.STEP)
		if q.dead:
			break
		if q.bounce != last_b:
			bounces += 1
			last_b = q.bounce
		if q.x < 10.0 * 16.0 or q.x > 20.0 * 16.0 or q.y < 4.0 * 16.0 or q.y > 10.0 * 16.0:
			inside = false
	if not q.dead or bounces != 3 or not inside:
		fail(res, "the shot bounced %d times (dead %s, inside %s)" % [bounces, str(q.dead), str(inside)])
	rb.queue_free()
	# 4. jam: three DDOS bits within 28 px of the body's centre, not two; RUN x 0.6, no dash
	var rj := bare_room("R01", 160.0, 192.0)
	Game.tools.bash = true
	var pc := Vector2(rj.player.x + 5.0, rj.player.y + 5.0)
	var bits: Array = []
	for i in range(3):
		var b := DdosBit.new(rj, pc.x - 3.0 + 20.0 * cos(float(i)), pc.y - 3.0 + 20.0 * sin(float(i)), i)
		rj.add_entity(b)
		bits.append(b)
	if not rj.jam_for(rj.player):
		fail(res, "3 bits at 20 px do not jam")
	bits[2].dead = true
	if rj.jam_for(rj.player):
		fail(res, "2 bits jam")
	bits[2].dead = false
	rj.player.jam = true
	rj.player.on_ground = true
	var vmax := 0.0
	for f in range(50):
		rj.player.jam = true
		Controls.script_input = {"right": true}
		Controls.poll()
		rj.player.update(Game.STEP)
		vmax = maxf(vmax, absf(rj.player.vx))
	if vmax > Player.RUN * 0.6 + 1.0 or vmax < Player.RUN * 0.6 - 8.0:
		fail(res, "jam: top speed %.1f, want %.1f" % [vmax, Player.RUN * 0.6])
	Controls.script_input = {"dash": true}
	Controls.poll()
	rj.player.jam = true
	var id0: int = rj.player.dash_id
	rj.player.update(Game.STEP)
	if rj.player.dash_id != id0:
		fail(res, "a jammed body started a dash")
	rj.queue_free()
	# 5. slow_t halves RUN
	var rs := bare_room("R01", 160.0, 192.0)
	var speeds: Array = []
	for sl in [0.0, 5.0]:
		rs.player.slow_t = sl
		rs.player.vx = 0.0
		var vm := 0.0
		for f in range(60):
			rs.player.slow_t = sl
			Controls.script_input = {"right": true}
			Controls.poll()
			rs.player.x = 160.0
			rs.player.update(Game.STEP)
			vm = maxf(vm, absf(rs.player.vx))
		speeds.append(vm)
	if absf(speeds[1] - speeds[0] * 0.5) > 2.0 or speeds[0] < Player.RUN - 2.0:
		fail(res, "slow: %s" % str(speeds))
	rs.queue_free()
	# 6. a tag: a Bug next to both players chases the tagged one
	var rt := bare_room("R01", 100.0, 192.0)
	var rp := partner(rt, 130.0, 192.0)
	var bug := Bug.new(rt, 6 * 16, 11 * 16, false)
	rt.add_entity(bug)
	bug.x = 118.0
	bug.y = 190.0
	var near = bug.to_player().p
	rt.tag_player(rt.player, 4.0)
	var tagged = bug.to_player().p
	rt.tags["p1"] = 0.0
	rt.tag_player(rp, 4.0)
	var tagged2 = bug.to_player().p
	if tagged != rt.player or tagged2 != rp or near == null:
		fail(res, "tags: %s %s" % [str(tagged), str(tagged2)])
	for f in range(60 * 4 + 5):
		rt._step_tags(Game.STEP)
	if not rt.tagged_players().is_empty():
		fail(res, "the tag did not run out")
	rt.queue_free()
	Game.fresh()
	return report("kit4b3", res.ok, res.info)

# a closed box of tiles (inclusive tile rect) in a bare room: walls on the border, air inside
func closed_box(r: Room, x0: int, y0: int, x1: int, y1: int) -> void:
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			r.grid.tiles[ty * r.w + tx] = TileGrid.SOLID if (ty == y0 or ty == y1 or tx == x0 or tx == x1) else TileGrid.E

func zip_from(r: Room, frames_n: int) -> Dictionary:
	var p = r.player
	var cut_at := -1
	var min_d := 1e9
	var ring: Dictionary = r.rings[0]
	for f in range(frames_n):
		step_keys(r, {"special": true} if f == 0 else {})
		p.inv = 99.0
		min_d = minf(min_d, Vector2(p.x + 5.0 - float(ring.x), p.y + 5.0 - float(ring.y)).length())
		if cut_at < 0 and f > 0 and p.zip < 0:
			cut_at = f
			break
	return {"cut_at": cut_at, "min_d": min_d}

# MVB3-03: SNIFFER, MITM, BOTNET, PINGER
func t_w6enemies2() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	Game.tools.curl = true
	# SNIFFER: a zip to a tapped ring is cut on the way and Clawd falls; a dead sniffer leaves a normal ring
	var cases: Array = []
	for variant in ["tapped", "killed"]:
		var r := bare_room("R01", 100.0, 150.0)
		r.player.tools.curl = true
		r.rings.append({"x": 175, "y": 128})
		var sn := Sniffer.new(r, 167, 120, 0)
		r.add_entity(sn)
		sn.probe_cd = 99.0
		sn.hop_cd = 99.0
		if variant == "killed":
			sn.hit(5, 0.0, 0.0, "swipe", sn)
			if not sn.dead:
				fail(res, "a sniffer survived 5 damage")
		if variant == "tapped" and not r.ring_tapped(0):
			fail(res, "the ring is not tapped")
		var z := zip_from(r, 40)
		cases.append(z)
		if variant == "tapped":
			if z.cut_at < 0 or z.min_d < 18.0:
				fail(res, "tapped zip: %s" % str(z))
			var vy_seen := false
			for f in range(20):
				step_keys(r, {})
				r.player.inv = 99.0
				if r.player.vy > 60.0:
					vy_seen = true
			if not vy_seen:
				fail(res, "Clawd did not fall after the cut")
		else:
			var ring_close := false
			for f in range(40):
				step_keys(r, {})
				r.player.inv = 99.0
			if z.min_d > 12.0 and z.cut_at >= 0:
				fail(res, "the zip to a clean ring was cut: %s" % str(z))
		r.queue_free()
	# a probe: yellow and catchable; caught back it kills the sniffer
	var rp := bare_room("R01", 100.0, 190.0)
	rp.rings.append({"x": 175, "y": 190})
	var sp := Sniffer.new(rp, 167, 182, 0)
	rp.add_entity(sp)
	sp.hop_cd = 99.0
	var pr = null
	for f in range(240):
		step_keys(rp, {})
		rp.player.inv = 99.0
		rp.player.x = 100.0
		for q in rp.projs:
			if not q.dead and q.catchable and pr == null:
				pr = q
		if pr != null:
			break
	if pr == null:
		fail(res, "the sniffer never probed")
	else:
		rp.catch_proj(pr, rp.player)
		for f in range(90):
			step_keys(rp, {})
			rp.player.inv = 99.0
			rp.player.x = 100.0
			if sp.dead:
				break
		if not sp.dead:
			fail(res, "a caught probe did not kill the sniffer (hp %d)" % sp.hp)
	rp.queue_free()
	# hop: nobody near, a free ring within 80 px: it moves there within 4.5 s and taps it
	var rh := bare_room("R01", 20.0, 190.0)
	rh.rings.append({"x": 300, "y": 170})
	rh.rings.append({"x": 350, "y": 170})
	var sh := Sniffer.new(rh, 292, 162, 0)
	rh.add_entity(sh)
	var hopped := false
	for f in range(270):
		step_keys(rh, {})
		rh.player.inv = 99.0
		rh.player.x = 20.0
		if sh.state == "hop":
			hopped = true
	if not hopped or sh.ring_i != 1 or sh.state != "tap" or rh.ring_tapped(0) or not rh.ring_tapped(1):
		fail(res, "hop: hopped %s ring %d state %s" % [str(hopped), sh.ring_i, sh.state])
	rh.queue_free()
	# MITM: a side swipe from the front is blocked and echoed 0.5 s later as a slash toward the player
	var rm := bare_room("R01", 100.0, 198.0)
	rm.player.tools.opus = false
	var mm := Mitm.new(rm, 14 * 16, 12 * 16)
	rm.add_entity(mm)
	mm.x = 150.0
	mm.face = -1.0
	var hp_m := mm.hp
	rm.player.x = 110.0
	rm.player.y = 198.0
	var rec_at := -1.0
	var echo_at := -1.0
	var slash_left := false
	var blocked := false
	var t_att := 0.0
	for f in range(120):
		var keys := {"attack": true} if f == 2 else {}
		rm.player.inv = 99.0
		step_keys(rm, keys)
		rm.player.x = 110.0
		rm.player.vx = 0.0
		if f == 2:
			t_att = float(f) * Game.STEP
		if mm.state == "record" and rec_at < 0.0:
			rec_at = float(f) * Game.STEP
		if mm.state == "echo" and echo_at < 0.0:
			echo_at = float(f) * Game.STEP
			for hb in mm.harmboxes():
				if hb is Dictionary and hb.w == 28.0 and hb.x + hb.w <= mm.x + 1.0:
					slash_left = true
		if mm.hp < hp_m:
			blocked = false
			break
		else:
			blocked = true
	if rec_at < 0.0 or echo_at < 0.0 or absf((echo_at - rec_at) - 0.5) > 0.06 or not slash_left or not blocked:
		fail(res, "mitm: record %.2f echo %.2f slash toward player %s blocked %s hp %d/%d" % [rec_at, echo_at, str(slash_left), str(blocked), mm.hp, hp_m])
	# open: a swipe lands from any side; listen: a swipe from behind lands, from the front not
	mm.set_state("open", 1.0)
	if mm.hit(1, -1.0, 0.0, "swipe", mm) != "hit":
		fail(res, "a swipe in `open` was blocked")
	mm.set_state("listen")
	mm.face = -1.0
	if mm.hit(1, 1.0, 0.0, "swipe", mm) != "block":
		fail(res, "a swipe from the front in `listen` landed")
	if mm.hit(1, -1.0, 0.0, "swipe", mm) != "hit":
		fail(res, "a swipe from behind in `listen` was blocked")
	rm.queue_free()
	# BOTNET: shielded while a bit lives, hittable in the countdown, a new swarm 4 s after the last bit died, its death kills its bits
	var rb := bare_room("R01", 100.0, 190.0)
	var bn := Botnet.new(rb, 20 * 16, 11 * 16)
	rb.add_entity(bn)
	bn.settle()
	var t_up := -1.0
	for f in range(60 * 6):
		rb.player.inv = 99.0
		rb.player.x = 100.0
		step_keys(rb, {})
		if bn.bits_alive() > 0:
			t_up = float(f) * Game.STEP
			break
	if t_up < 3.8 or t_up > 4.3 or bn.bits_alive() != 5 or not bn.shielded:
		fail(res, "botnet: first swarm after %.2f s, %d bits, shield %s" % [t_up, bn.bits_alive(), str(bn.shielded)])
	if bn.hit(1, 1.0, 0.0, "swipe", bn) != "block":
		fail(res, "a shielded botnet took a hit")
	for b in bn.bits:
		b.loot = 0
		b.dead = true
	rb.step(Game.STEP)
	rb.player.inv = 99.0
	if bn.shielded:
		fail(res, "still shielded with no bits")
	var hp_b := bn.hp
	if bn.hit(1, 1.0, 0.0, "swipe", bn) != "hit" or bn.hp != hp_b - 1:
		fail(res, "the botnet took no hit in its countdown")
	var t_new := -1.0
	for f in range(60 * 6):
		rb.player.inv = 99.0
		rb.player.x = 100.0
		step_keys(rb, {})
		if bn.bits_alive() > 0:
			t_new = float(f) * Game.STEP
			break
	if t_new < 3.8 or t_new > 4.3:
		fail(res, "botnet: the next swarm came after %.2f s" % t_new)
	var some_bits: Array = bn.bits.duplicate()
	var guard := 0
	while not bn.dead and guard < 40:
		bn.shielded = false
		bn.hit(1, 1.0, 0.0, "swipe", bn)
		guard += 1
	if not bn.dead:
		fail(res, "the botnet cannot be killed")
	for b in some_bits:
		if is_instance_valid(b) and not b.dead:
			fail(res, "a bit outlived its botnet")
			break
	rb.queue_free()
	# PINGER: the ball bounces 4 times and dies; the third ball is catchable and kills the pinger when caught
	var rpi := bare_room("R01", 300.0, 190.0)
	closed_box(rpi, 10, 4, 24, 11)
	rpi.player.x = 22.0 * 16.0
	rpi.player.y = 10.0 * 16.0 - 10.0
	var pg := Pinger.new(rpi, 11 * 16, 7 * 16)
	rpi.add_entity(pg)
	pg.settle()
	if pg._side() != "l":
		fail(res, "the pinger did not attach to the left wall (%s)" % pg._side())
	var first = null
	var bounce_seen := 0
	var last_b := 4
	var died_at := -1.0
	var balls := 0
	var third = null
	var known := {}
	for f in range(60 * 30):
		rpi.player.inv = 99.0
		rpi.player.x = 22.0 * 16.0
		rpi.player.y = 10.0 * 16.0 - 10.0
		rpi.player.vx = 0.0
		rpi.player.vy = 0.0
		step_keys(rpi, {})
		for q in rpi.projs:
			if not known.has(q.id) and not q.dead and q.get("bounce", 0) > 0:
				known[q.id] = true
				balls += 1
				if balls == 1:
					first = q
				if balls == 3:
					third = q
		if first != null and first.dead and died_at < 0.0:
			died_at = float(f) * Game.STEP
		if first != null and not first.dead and first.bounce != last_b:
			bounce_seen += 1
			last_b = first.bounce
		if third != null:
			break
	if first == null or not first.dead or first.bounce != 0 or (last_b - 0 > 1 and bounce_seen < 3):
		fail(res, "the first ball: bounce left %s, dead %s" % [str(first.bounce) if first != null else "-", str(first.dead) if first != null else "-"])
	if third == null or not third.catchable:
		fail(res, "the third ball is not catchable")
	else:
		rpi.catch_proj(third, rpi.player)
		for f in range(200):
			rpi.player.inv = 99.0
			rpi.player.x = 22.0 * 16.0
			rpi.player.y = 10.0 * 16.0 - 10.0
			step_keys(rpi, {})
			if pg.dead:
				break
		if not pg.dead:
			fail(res, "a caught ball did not kill the pinger (hp %d)" % pg.hp)
	rpi.queue_free()
	Game.fresh()
	return report("w6enemies2", res.ok, res.info)

# MVB3-04: the reworked SCRAPER, WORM, DDOS and SPYWARE (on top of the 4B-2 checks)
func finish_w6enemies(res: Dictionary) -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.diff = "normal"
	# SCRAPER: hp 3; at the bottom of its drop it throws a thread; a hit slows the body for 0.8 s (and the thread is a 1-px line, not catchable)
	var r := bare_room("R01", 100.0, 190.0)
	var sc := Scraper.new(r, 96, 112)
	r.add_entity(sc)
	if sc.hp != 3:
		fail(res, "scraper hp %d" % sc.hp)
	var thread = null
	var slowed := 0.0
	var hp0: int = r.player.hp
	for f in range(240):
		r.player.x = 100.0 if sc.state in ["hang", "tell"] else 190.0          # (it steps away once the scraper drops)
		r.player.y = 190.0
		r.player.vy = 0.0
		r.player.inv = 0.0 if r.player.slow_t <= 0.0 else 99.0
		step_keys(r, {})
		for q in r.projs:
			if q.kind == "thread" and thread == null:
				thread = q
				if q.catchable:
					fail(res, "the thread is catchable")
		if r.player.slow_t > slowed:
			slowed = r.player.slow_t
		if slowed > 0.0:
			break
	if thread == null or slowed < 0.7 or slowed > 0.81:
		fail(res, "scraper thread: seen %s, slow_t %.2f" % [str(thread != null), slowed])
	if r.player.hp >= hp0 and thread != null:
		pass
	r.queue_free()
	# WORM: a bite that ends unhurt lays an egg; it hatches in 5 s; a group holds three worms or eggs at most
	var rw := new_room("N13")
	var worms: Array = []
	for e in rw.ents:
		if e is Worm:
			worms.append(e)
	if worms.is_empty() or worms[0].hp != 3:
		fail(res, "worm hp / none in N13")
	else:
		var wm: Worm = worms[0]
		wm.group_key()
		wm._find_group()
		var key: Vector2i = wm.group_key()
		var in_group := 0
		for w2 in worms:
			w2._find_group()
			if w2.group_key() == key:
				in_group += 1
		for w3 in worms:
			if w3 != wm:
				w3.dead = true
		wm.hurt_out = false
		wm.set_state("out", 0.0)
		wm.update(Game.STEP)                              # the bite ends unhurt
		var eggs := 0
		var egg = null
		for e in rw.ents:
			if e is WormEgg:
				eggs += 1
				egg = e
		if eggs != 1:
			fail(res, "no egg after an unhurt bite (%d)" % eggs)
		else:
			rw.player.inv = 99.0
			var n_w := 0
			var secs := 0.0
			while egg != null and not egg.dead and secs < 6.0:
				step_keys(rw, {})
				rw.player.inv = 99.0
				secs += Game.STEP
			n_w = rw.ents.filter(func(e): return e is Worm and not e.dead).size()
			if secs < 4.9 or secs > 5.2 or n_w < 2:
				fail(res, "the egg hatched after %.2f s, %d worms" % [secs, n_w])
		# a hurt bite lays nothing; at three worms + eggs nothing more
		for e in rw.ents.filter(func(e): return e is WormEgg):
			e.dead = true
		wm.hurt_out = true
		wm.set_state("out", 0.0)
		wm.update(Game.STEP)
		if rw.ents.any(func(e): return e is WormEgg and not e.dead):
			fail(res, "a bite that was hit laid an egg")
		var live: Array = rw.ents.filter(func(e): return e is Worm and not e.dead and e.group_key() == key)
		for k in range(4):
			var wx: Worm = live[0]
			wx.hurt_out = false
			wx.set_state("out", 0.0)
			wx.update(Game.STEP)
		var total := rw.ents.filter(func(e): return not e.dead and ((e is Worm and e.group_key() == key) or (e is WormEgg and e.group == key))).size()
		if total > 3:
			fail(res, "a group holds %d worms and eggs" % total)
		# crawl: one cell per 0.4 s toward the player
		wm.set_state("crawl")
		wm.step_t = 0.4
		var far_i := 0
		var far_d := -1.0
		for i in range(wm.cells.size()):
			var dd := Vector2(wm.cells[i].x * 16.0, wm.cells[i].y * 16.0).distance_to(Vector2(wm.x, wm.y))
			if dd > far_d:
				far_d = dd
				far_i = i
		var moves := 0
		var prev_ci: int = wm.ci
		rw.player.x = wm.cells[far_i].x * 16.0 + 3.0
		rw.player.y = wm.cells[far_i].y * 16.0 + 3.0
		for f in range(120):
			rw.player.inv = 99.0
			wm.update(Game.STEP)
			if wm.ci != prev_ci:
				moves += 1
				prev_ci = wm.ci
		if moves < 2 or moves > 6:
			fail(res, "the worm moved %d cells in 2 s" % moves)
	rw.queue_free()
	# DDOS: one bit at a time darts, at 220 px/s straight at the player; contact still kills the bit
	var rd := bare_room("R01", 160.0, 190.0)
	rd.player.inv = 99.0
	var bits := rd.spawn_ddos(150.0, 170.0)
	var darting_max := 0
	var darts := {}
	var dart_speed := 0.0
	for f in range(60 * 6):
		rd.player.inv = 99.0
		rd.player.x = 160.0
		rd.player.y = 190.0
		rd.player.vy = 0.0
		step_keys(rd, {})
		var in_dart := 0
		for b in bits:
			if is_instance_valid(b) and not b.dead and b.state == "dart":
				in_dart += 1
				darts[b.idx] = true
				dart_speed = maxf(dart_speed, Vector2(b.vx, b.vy).length())
		darting_max = maxi(darting_max, in_dart)
	if darting_max != 1 or darts.size() < 3 or absf(dart_speed - 220.0) > 1.0:
		fail(res, "ddos: %d darting at once, %d different bits darted, top speed %.0f" % [darting_max, darts.size(), dart_speed])
	rd.queue_free()
	# SPYWARE: a player kept in view for the whole track is tagged for 4 s; one who steps behind a wall during the track is not
	var results: Array = []
	var tag_left := 0.0
	for variant in ["seen", "hidden"]:
		var rs := bare_room("R01", 160.0, 190.0)
		var sw := Spyware.new(rs, 96, 176)
		rs.add_entity(sw)
		if sw.hp != 4:
			fail(res, "spyware hp %d" % sw.hp)
		var tagged_at := -1.0
		for f in range(60 * 3):
			rs.player.inv = 99.0
			if variant == "hidden" and sw.state == "track" and sw.state_t < 0.6:
				for wy in range(9, 13):                              # a wall drops between the eye and the player during the track
					rs.grid.tiles[wy * rs.w + 8] = TileGrid.SOLID
			rs.player.x = 160.0
			rs.player.y = 190.0
			step_keys(rs, {})
			if rs.is_tagged(rs.player) and tagged_at < 0.0:
				tagged_at = float(f) * Game.STEP
				tag_left = float(rs.tags.p1)
		results.append(tagged_at)
		if variant == "seen" and (tag_left < 3.9 or tag_left > 4.0):
			fail(res, "tag time at the moment it was set: %.2f" % tag_left)
		rs.queue_free()
	if results[0] < 0.0:
		fail(res, "a player in view for the whole track was not tagged")
	if results[1] >= 0.0:
		fail(res, "a player behind a wall during the track was tagged")
	Game.fresh()
	return report("w6enemies", res.ok, res.info)

func lossy_packet(r: Room) -> Dictionary:
	for m in r.plats:
		if m.get("packet", false) and int(m.j) % 3 == 2:
			return m
	return {}

# the room time at which packet m's centre is over column `col` (searched on a copy of the clock)
func time_over(r: Room, m: Dictionary, col: int) -> float:
	var pa: Dictionary = m.path
	var span: float = float(pa.n) * float(pa.every)
	var prev := -1e9
	for k in range(int(span * 100.0)):
		var tt := float(k) / 100.0
		var u := fposmod(tt + float(m.j) * float(pa.every), span)
		var nx: float = float(pa.xa) + u * float(pa.speed) + float(pa.w) / 2.0
		var target := float(col * 16 + 8)
		if k > 0 and prev < target and nx >= target and nx <= float(pa.xb) + float(pa.w):
			return tt
		prev = nx
	return -1.0

func t_net4b3() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	# ---- N12: packet loss
	var r := new_room("N12")
	for e in r.ents:
		e.queue_free()
	r.ents.clear()
	var m := lossy_packet(r)
	if m.is_empty():
		fail(res, "N12 has no lossy packet")
		r.queue_free()
		return report("net4b3", false, res.info)
	var tc := time_over(r, m, 27)
	if tc < 0.0:
		fail(res, "the third packet never reaches column 27")
	var r2 := new_room("N12")
	var m2 := lossy_packet(r2)
	var identical := true
	var lost_for := 0.0
	var warned := false
	for k in range(int(8.0 * 100.0)):
		var tt := tc - 2.0 + float(k) / 100.0
		r.time = tt
		r2.time = tt
		r._move_packets()
		r2._move_packets()
		if bool(m.lost) != bool(m2.lost) or bool(m.warn) != bool(m2.warn):
			identical = false
		if m.lost:
			lost_for += 0.01
			if tt < tc - 0.011:
				fail(res, "lost before column 27 (%.2f vs %.2f)" % [tt, tc])
		if m.warn:
			warned = true
	if not identical:
		fail(res, "two rooms at the same time disagree about the loss")
	if absf(lost_for - 1.2) > 0.1 and absf(lost_for - 0.6) > 0.1:      # (two columns inside the window: 27 and later 45 are 18 columns apart = more than 8 s)
		fail(res, "lost for %.2f s" % lost_for)
	if not warned:
		fail(res, "no warning before the loss")
	for other in r.plats:
		if other.get("packet", false) and int(other.j) % 3 != 2:
			for k in range(300):
				r.time = float(k) * 0.1
				r._move_packets()
				if other.lost:
					fail(res, "packet %d was lost" % other.j)
					break
	# a rider standing on it falls into the spike strip under the column; a rider who runs and jumps off 0.3 s before clears the strip
	var outcomes: Array = []
	for variant in ["stand", "run-jump"]:
		var rr := new_room("N12")
		for e in rr.ents:
			e.queue_free()
		rr.ents.clear()
		var mm := lossy_packet(rr)
		rr.time = tc - 1.5
		rr._move_packets()
		var q = rr.player
		q.inv = 99.0
		q.hp = q.max_hp
		q.x = mm.x + float(mm.w) / 2.0 - 5.0
		q.y = mm.y - q.h
		q.vx = 0.0
		q.vy = 0.0
		for f in range(int(3.0 * 60.0)):
			var keys := {}
			var rel: float = rr.time - tc                     # seconds relative to the moment its centre is over the column
			if variant == "run-jump" and rel > -0.31:
				keys["right"] = true
				if rel < 0.05:
					keys["jump"] = true
			step_keys(rr, keys)
			q.inv = 99.0
			if OS.get_environment("LOSSDBG") != "" and variant == "run-jump" and f % 6 == 0:
				print("rel %.2f dy %.1f x %.1f lost %s hp %d" % [rel, q.y - mm.y, q.x, str(mm.lost), q.hp])
		outcomes.append([q.hp, q.x])
		rr.queue_free()
	if outcomes[0][0] >= 5:
		fail(res, "a rider that stood still did not fall into the spikes (hp %d)" % outcomes[0][0])
	if outcomes[1][0] < 5:
		fail(res, "a rider that ran and jumped 0.3 s before still lost hp (%d, x %.0f)" % [outcomes[1][0], outcomes[1][1]])
	r.queue_free()
	r2.queue_free()
	# ---- N17: the RST chase
	Game.flags = {}
	var rc := new_room("N17")
	for e in rc.ents:
		e.queue_free()
	rc.ents.clear()
	var p = rc.player
	p.inv = 99.0
	p.x = 3.0 * 16.0
	p.y = 4.0 * 16.0
	for f in range(30):
		step_keys(rc, {})
		p.vy = 0.0
		p.y = 4.0 * 16.0
		p.inv = 99.0
	if rc.ch_t0 >= 0.0:
		fail(res, "the chase started above row 16")
	p.y = 16.0 * 16.0 + 24.0
	step_keys(rc, {})
	if rc.ch_t0 < 0.0:
		fail(res, "the chase did not start when a player passed row 16")
	var line0 := rc.chase_line_y()
	for f in range(60):
		p.inv = 99.0
		p.y = 40.0 * 16.0
		p.vy = 0.0
		step_keys(rc, {})
	var line1 := rc.chase_line_y()
	if absf((line1 - line0) - 46.0) > 6.0:
		fail(res, "the line moved %.1f px in a second, want 46" % (line1 - line0))
	# a player above the line is hurt once and put below it
	rc.time = 40.0
	rc.ch_t0 = rc.time - 10.0                              # the line is at about 428
	var ly := rc.chase_line_y()
	p.inv = 0.0
	p.hp = p.max_hp
	p.x = 3.0 * 16.0
	p.y = ly - 60.0
	p.vy = 0.0
	rc._chase_hurt(p)
	if p.hp != p.max_hp - 1 or p.y <= ly:
		fail(res, "above the line: hp %d/%d, y %.0f vs line %.0f" % [p.hp, p.max_hp, p.y, ly])
	# reaching row 77 ends it for good
	p.inv = 99.0
	p.x = 3.0 * 16.0
	p.y = 77.0 * 16.0 + 2.0
	for f in range(10):
		p.y = 77.0 * 16.0 + 2.0
		p.vy = 0.0
		step_keys(rc, {})
	if not Game.flag("rst:N17") or rc.ch_t0 >= 0.0:
		fail(res, "rst:N17 not set at row 77 (flag %s, ch %.2f)" % [str(Game.flag("rst:N17")), rc.ch_t0])
	rc.queue_free()
	var rc2 := new_room("N17")
	rc2.player.y = 40.0 * 16.0
	for f in range(10):
		step_keys(rc2, {})
		rc2.player.y = 40.0 * 16.0
	if rc2.ch_t0 >= 0.0:
		fail(res, "a rebuilt room has a chase after rst:N17")
	rc2.queue_free()
	Game.flags = {}
	# ---- N21: the honeypot's typed waves
	var rw := new_room("N21")
	for e in rw.ents:
		e.queue_free()
	rw.ents.clear()
	rw.player.inv = 99.0
	var kinds_seen := {}
	var wave_idx := -1
	for f in range(60 * 90):
		rw.player.inv = 99.0
		rw.player.x = 24.0 * 16.0
		rw.player.y = 12.0 * 16.0 - 10.0
		step_keys(rw, {})
		for e in rw.ents:
			if e is Botnet:
				kinds_seen["r"] = true
			if e is Pinger:
				kinds_seen["y"] = true
			if e is Mitm:
				kinds_seen["u"] = true
		if rw.wave_i == 1:
			# clear this wave
			for e in rw.wave_ents:
				if is_instance_valid(e):
					e.dead = true
		if rw.wave_i == 2 and kinds_seen.has("r") and kinds_seen.has("y"):
			break
		if rw.wave_i >= 1 and rw.wave_i != wave_idx:
			wave_idx = rw.wave_i
			for e in rw.wave_ents:
				if is_instance_valid(e) and wave_idx < 1:
					e.dead = true
		if rw.wave_i == 0:
			for e in rw.wave_ents:
				if is_instance_valid(e):
					e.dead = true
	if not (kinds_seen.has("u") and kinds_seen.has("r") and kinds_seen.has("y")):
		fail(res, "waves: seen %s" % str(kinds_seen.keys()))
	rw.queue_free()
	Game.fresh()
	return report("net4b3", res.ok, res.info)

# starts the N09 fight and returns the boss (the player is kept safe)
func crawler_fight(res: Dictionary) -> Array:
	var r := new_room("N09")
	var cb: CrawlerBoss = null
	for e in r.ents:
		if e is CrawlerBoss:
			cb = e
	if cb == null or r.boss != cb:
		fail(res, "N09 has no CrawlerBoss")
		return [r, null]
	r.player.x = 250.0
	r.player.y = 300.0
	var n := 0
	while r.fight.state != "active" and n < 500:
		r.player.inv = 99.0
		r.step(Game.STEP)
		n += 1
	if r.fight.state != "active":
		fail(res, "the fight never became active")
	cb.plan = {}
	cb.idle_t = 999.0
	return [r, cb]

# CRAWLER OF THE WEB (14-crawler.md): the hall's masks are its tiles, the phase scenes, a leap tears the net and breaks a tube, CAPTCHA drops its squares
# and its tick box only says you are a robot, drawers fall but four always stay, a planted leg sags the body, a caught link dazes it, phase 3 is dark
# and swinging, a flash leaves stabs where the players were and a dive follows, the net fields carry it all, and the kill gives curl
func t_crawler3() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var fr := crawler_fight(res)
	var r: Room = fr[0]
	var cb: CrawlerBoss = fr[1]
	if cb == null:
		return report("crawler3", false, res.info)
	var hl: IndexHall = r.hall
	if hl == null:
		fail(res, "N09 has no hall")
		return report("crawler3", false, res.info)
	# the hall owns its cells: the tiles follow its masks, the tile view does not draw them
	if r.grid.tile(IndexHall.NET_C0, IndexHall.NET_ROW) != TileGrid.ONEWAY or not hl.owns(IndexHall.NET_C0, IndexHall.NET_ROW):
		fail(res, "the net is not a hall-owned one-way cell")
	if r.view.tiles.get_cell_source_id(Vector2i(IndexHall.NET_C0, IndexHall.NET_ROW)) != -1:
		fail(res, "the tile view draws a hall cell")
	# no warning: a wind-up draws nothing of the kit's announcement (only the body)
	cb._start("results", "p1")
	if cb.plan.is_empty() or cb.plan.ph != "cue":
		fail(res, "results did not start")
	# a planted leg: three claws sag the body, the boss loses nothing
	cb.plan = {}
	cb.leg_on = 2
	cb.leg_x = 200.0
	cb.leg_y = 330.0
	var hp0 := cb.hpf
	var lb: Dictionary = {}
	for hb in cb.hurtboxes():
		if hb.has("leg"):
			lb = hb
	if lb.is_empty():
		fail(res, "a planted leg has no hurtbox")
	else:
		for k in range(3):
			cb.hit(1, 0.0, 0.0, "swipe", lb)
		if cb.down_t <= 0.0 or cb.leg_on != 0 or cb.hpf != hp0:
			fail(res, "three claws on the leg: down %.2f leg %d hp %.1f -> %.1f" % [cb.down_t, cb.leg_on, hp0, cb.hpf])
	# a link caught back into it dazes it
	cb.down_t = 0.0
	cb.hit(2, 0.0, 0.0, "catch", cb._body_box())
	if cb.down_t < 1.4 or cb.hpf >= hp0:
		fail(res, "a caught link: down %.2f hp %.1f" % [cb.down_t, cb.hpf])
	# phase 2: the scene (no damage taken), then a broken leg
	cb.hpf = float(cb.max_hp) * 0.6
	cb.hp = ceili(cb.hpf)
	cb.on_damage()
	if cb.shift_k != 2:
		fail(res, "no phase 2 scene at 60 %")
	var hp1 := cb.hpf
	if cb.hit(1, 0.0, 0.0, "swipe", cb._body_box()) != "" or cb.hpf != hp1:
		fail(res, "hurt during the phase scene")
	for f in range(int(CrawlerBoss.SHIFT2 * 60.0) + 10):
		r.player.inv = 99.0
		r.step(Game.STEP)
	if cb.ph != 2 or cb.legs_ok != 7:
		fail(res, "after the scene: phase %d legs %d" % [cb.ph, cb.legs_ok])
	# a leap onto the net tears it and breaks the tube of that quarter
	cb.plan = {}
	cb.idle_t = 999.0
	var zones0 := hl.zones | 0b1100
	hl.zones = zones0
	r.player.x = 225.0
	r.player.y = 326.0
	cb.core_px = 300.0
	cb.core_y = 100.0
	cb._start("leap", "p1")
	var landed := false
	for f in range(200):
		r.player.inv = 99.0
		r.player.x = 225.0
		r.step(Game.STEP)
		if cb.plan.is_empty() or cb.plan.ph == "recover":
			landed = true
			break
	var torn := hl.net != IndexHall.ALL_NET
	if not landed or not torn or hl.zones == zones0:
		fail(res, "leap: landed %s, net %s, tubes %d -> %d" % [str(landed), str(torn), zones0, hl.zones])
	var hole := -1
	for i in range(IndexHall.NET_N):
		if (hl.net >> i) & 1 == 0:
			hole = i
	if hole >= 0 and r.grid.tile(IndexHall.NET_C0 + hole, IndexHall.NET_ROW) != TileGrid.E:
		fail(res, "a torn net cell is still a floor")
	# CAPTCHA: its squares drop after the screen showed them; the tick box only says you are a robot
	cb.plan = {}
	hl.net = IndexHall.ALL_NET
	cb.hz.clear()
	cb.hz_add("captcha", 1.4, [0b0000101])
	var cbox: Dictionary = {}
	for hb in cb.hurtboxes():
		if hb.has("cbox"):
			cbox = hb
	if cbox.is_empty():
		fail(res, "no tick box while CAPTCHA runs")
	else:
		var hp2 := cb.hpf
		cb.hit(1, 0.0, 0.0, "swipe", cbox)
		if cb.hpf != hp2:
			fail(res, "the tick box hurt the boss")
	for f in range(int(1.5 * 60.0)):
		r.player.inv = 99.0
		r.step(Game.STEP)
	if r.grid.tile(IndexHall.NET_C0, IndexHall.NET_ROW) != TileGrid.E or r.grid.tile(IndexHall.NET_C0 + 4, IndexHall.NET_ROW) != TileGrid.E or r.grid.tile(IndexHall.NET_C0 + 2, IndexHall.NET_ROW) != TileGrid.ONEWAY:
		fail(res, "CAPTCHA squares 0 and 2 did not drop (or 1 did)")
	if String(hl.screen.mode) != "captcha":
		fail(res, "the screen does not show the CAPTCHA (%s)" % String(hl.screen.mode))
	# drawers: one falls after it shook; never fewer than four
	cb.hz.clear()
	hl.drawers = IndexHall.ALL_DRAWERS
	cb._drop_drawer(0)
	for f in range(60):
		r.player.inv = 99.0
		r.step(Game.STEP)
	if (hl.drawers & 1) != 0 or r.grid.tile(1, 18) != TileGrid.E:
		fail(res, "drawer 0 did not fall")
	hl.drawers = 0b1111
	cb.hz.clear()
	cb._drop_drawer(-1)
	if not cb.hz.is_empty():
		fail(res, "a drawer fell with only four left")
	# phase 3: the blackout scene, then dark, no net, swinging
	cb.plan = {}
	cb.hz.clear()
	hl.drawers = IndexHall.ALL_DRAWERS
	cb.hpf = float(cb.max_hp) * 0.25
	cb.hp = ceili(cb.hpf)
	cb.on_damage()
	for f in range(int(CrawlerBoss.SHIFT3 * 60.0) + 10):
		r.player.inv = 99.0
		r.step(Game.STEP)
	if cb.ph != 3 or cb.dc != 1 or hl.net != 0 or hl.dark < 0.99 or String(hl.screen.mode) != "off":
		fail(res, "phase 3: ph %d dc %d net %d dark %.2f screen %s" % [cb.ph, cb.dc, hl.net, hl.dark, String(hl.screen.mode)])
	# a flash: a stab where the player stood, then a dive
	cb.plan = {}
	cb.hz.clear()
	cb.combo = ""
	cb._start("flash", "p1")
	var stabbed := false
	var dived := false
	for f in range(240):
		r.player.inv = 99.0
		r.step(Game.STEP)
		for h in cb.hz:
			if h.k == "stab":
				stabbed = true
		if not cb.plan.is_empty() and String(cb.plan.id) == "dive":
			dived = true
	if not stabbed or not dived:
		fail(res, "flash: stab %s, dive after %s" % [str(stabbed), str(dived)])
	# the last 15 %: no leg lights
	cb.hpf = float(cb.max_hp) * 0.1
	if not cb.lights_out():
		fail(res, "the leg lights still on at 10 %")
	# the net fields carry the hall and the state
	var f2: Array = cb.net_fields()
	var pup := CrawlerBoss.new(r, 0.0, 0.0)
	pup.puppet = true
	var hl2_net := hl.net
	pup.net_apply(f2)
	if pup.ph != cb.ph or pup.dc != cb.dc or hl.net != hl2_net or pup.legs_ok != cb.legs_ok:
		fail(res, "net fields: ph %d/%d dc %d/%d legs %d/%d" % [pup.ph, cb.ph, pup.dc, cb.dc, pup.legs_ok, cb.legs_ok])
	pup.free()
	# the kill: the scene (it falls, it speaks when Clawd comes near, the compaction, the summary), then curl, the boss flag, N09:W opens;
	# the Logs keep a [compacted] line and the hall keeps its last search
	Game.flags = {}
	Game.tools = {}
	if not r.skip_boss():
		fail(res, "skip boss refused")
	Game.flags["boss:FIREWALL"] = true                         # (THE FIREWALL's line is lost in the compaction too)
	var n := 0
	var spoke_at := -1
	while r.fight.state != "done" and n < 3600:
		r.player.inv = 99.0
		if n > 200:
			r.player.x = cb.core_px - 30.0                     # walk up to it: it speaks
		r.step(Game.STEP)
		if spoke_at < 0 and cb.speak_t >= 0.0:
			spoke_at = n
		n += 1
	if spoke_at < 0 or spoke_at > 260:
		fail(res, "it did not speak when Clawd came near (frame %d)" % spoke_at)
	if not Game.flag("compacted:CRAWLER") or not Game.flag("compacted:FIREWALL"):
		fail(res, "no compacted trace")
	if not Game.flag("ability:curl") or not Game.flag("boss:CRAWLER") or not Game.tools.get("curl", false):
		fail(res, "reward missing (state %s)" % r.fight.state)
	r.update_doors()
	for d in r.grid.doors:
		if String(d.get("side", "")) == "W" and not bool(d.open):
			fail(res, "N09:W stayed shut")
	r.step(Game.STEP)
	if String(hl.screen.mode) != "last":
		fail(res, "after the fight the screen shows %s" % String(hl.screen.mode))
	r.queue_free()
	Game.fresh()
	return report("crawler3", res.ok, res.info)

# not in the suite: runs a boss fight for FIGHT_S seconds with an invulnerable player who walks about, and counts the attacks (BOSS = N09 | N15 | N22)
func t_fightsim() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = OS.get_environment("DIFF") if OS.get_environment("DIFF") != "" else "normal"
	var rid := OS.get_environment("BOSS") if OS.get_environment("BOSS") != "" else "N09"
	var secs := float(OS.get_environment("FIGHT_S")) if OS.get_environment("FIGHT_S") != "" else 60.0
	var r := new_room(rid)
	var b = r.boss
	if rid == "N22":
		Game.flags["ability:ssh"] = true
		for f in range(6):
			on_pad(r)
			step_keys(r, {"up": true} if f == 3 else {})
	r.player.x = 250.0
	r.player.y = 150.0
	var n := 0
	while r.fight.state != "active" and n < 900:
		r.player.inv = 99.0
		if rid == "N22":
			on_pad(r)
		r.step(Game.STEP)
		n += 1
	r.player.inv = 0.0
	if OS.get_environment("HP_FRAC") != "" and b != null:
		b.hpf = float(b.max_hp) * float(OS.get_environment("HP_FRAC"))
		b.hp = ceili(b.hpf)
		b.on_damage()
	var counts := {}
	var seen := {}
	var hits := 0
	var p1_end := -1.0
	var hp_start: int = r.player.hp
	for f in range(int(secs * 60.0)):
		if OS.get_environment("GODMODE") != "":
			r.player.inv = 99.0
		var ph := float(f) / 60.0
		if rid == "N09":
			r.player.x = 200.0 + 120.0 * sin(ph * 0.7)
		else:
			r.player.x = 190.0 + 140.0 * sin(ph * 0.7)
		r.player.y = 150.0
		r.player.vy = 0.0
		step_keys(r, {"attack": f % 40 == 0})
		if r.player.hp < r.player.max_hp and OS.get_environment("GODMODE") == "":
			hits += 1
			r.player.hp = r.player.max_hp
		if b != null and not b.plan.is_empty():
			b.plan_seen(int(b.plan.seq))
			var key := "%s@P%d" % [String(b.plan.id), b.phase]
			if not seen.has("%d" % b.plan.seq):
				seen["%d" % b.plan.seq] = true
				counts[key] = int(counts.get(key, 0)) + 1
		if b != null and (b.dying or b.dead):
			break
		if b != null and rid == "N15" and p1_end < 0.0 and b.hpf <= float(b.max_hp) * 0.70 + 0.01:
			p1_end = float(f) / 60.0                       # (THE FIREWALL: how long its first bar lasts for this bot; the plan's target is ~60 s for a good player)
	print("FIGHTSIM %s %.0f s: attacks %s, hp %.1f/%d, hits taken %d%s" % [rid, secs, str(counts), b.hpf if b != null else -1.0, b.max_hp if b != null else 0, hits, (", phase 1 over at %.0f s" % p1_end) if p1_end >= 0.0 else ""])
	Game.fresh()
	return report("fightsim", true, "")

# THE FIREWALL (16-firewall-build.md), grows with the milestones. M1: the honeypot hall of N15: its map, the stages, the packets, the hot floor, the camera
func fw_signature(hp: HoneypotHall, nk: int) -> Array:
	var out: Array = []
	for L in range(HoneypotHall.LANES):
		for k in range(nk):
			var inf: Dictionary = hp.packet_info(L, k, hp.spawn_t(L, k) + 1.0)
			out.append([bool(inf.drop), snappedf(float(inf.td), 0.0001), bool(inf.green)])
	return out

func t_firewall3() -> bool:
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
	if fw == null or r.boss != fw or r.hpot == null:
		fail(res, "N15 has no FirewallBoss / honeypot hall")
		r.queue_free()
		return report("firewall3", false, res.info)
	r.fight.state = "done"                                  # (no fight here: the hall alone)
	var hp: HoneypotHall = r.hpot
	var def: Dictionary = Game.rooms_meta.rooms["N15"]
	# 1. the room: 24 x 28, the hall, the name of the shell, a free camera in the fight
	if r.w != 24 or r.h != 28 or int(def.size[0]) != 24 or int(def.size[1]) != 28 or String(def.hall) != "honeypot":
		fail(res, "N15 is %dx%d" % [r.w, r.h])
	if String(def.boss.name) != "GUEST SERVICES" or String(def.boss.sub) != "welcome, guest" or String(def.boss.get("cam", "")) != "free" or int(def.boss.trigger_x) != 96:
		fail(res, "N15 boss entry")
	if hp.stage != 0 or fw.max_hp != 82 or fw.boss_name != "GUEST SERVICES":
		fail(res, "start: stage %d hp %d name %s" % [hp.stage, fw.max_hp, fw.boss_name])
	# 2. stage 0: the lobby floor, the furniture, the doors
	var g = r.grid
	for tx in range(1, 23):
		if g.tile(tx, 11) != TileGrid.SOLID:
			fail(res, "lobby floor open at %d" % tx)
	for pc in [[3, 9, 4], [9, 8, 3], [13, 5, 4]]:
		for k in range(pc[2]):
			if g.tile(pc[0] + k, pc[1]) != TileGrid.ONEWAY:
				fail(res, "furniture cell %d,%d" % [pc[0] + k, pc[1]])
	for ty in range(7, 11):
		if g.tile(0, ty) != TileGrid.E or g.tile(23, ty) != TileGrid.E:
			fail(res, "door gap row %d" % ty)
	if g.tile(0, 6) != TileGrid.SOLID or g.tile(23, 11) != TileGrid.SOLID or g.tile(5, 25) != TileGrid.SOLID:
		fail(res, "outer walls")
	var pooled := 0
	for m in r.plats:
		if m.has("fw"):
			pooled += 1
			if not m.off:
				fail(res, "a packet before the packets started")
	if pooled != HoneypotHall.LANES * HoneypotHall.SLOTS:
		fail(res, "%d packets in the pool" % pooled)
	# 3. the camera: the lobby shows no furnace; the fall releases it (derived from the stage, every frame)
	r.step(Game.STEP)
	if r.cam.lock == null or float(r.cam.lock.y) != 0.0:
		fail(res, "camera not locked to the lobby")
	var rev0 := hp.static_rev
	for f in range(30):
		r.step(Game.STEP)
	if hp.static_rev != rev0:
		fail(res, "the static drawing was redone %d times while nothing changed" % (hp.static_rev - rev0))
	# 4. stage 1 (the furnace): the floor is gone, the stubs too (they come back with the stairs), the body is solid
	hp.set_stage(1)
	r.step(Game.STEP)
	if hp.static_rev != rev0 + 1:
		fail(res, "a stage change did not redo the static drawing once (%d)" % (hp.static_rev - rev0))
	if r.cam.lock != null:
		fail(res, "camera still locked in the furnace")
	for tx in range(4, 20):
		if g.tile(tx, 11) != TileGrid.E:
			fail(res, "stage 1 floor still at %d" % tx)
	for tx in [1, 2, 3, 20, 21, 22]:
		if g.tile(tx, 11) != TileGrid.E:
			fail(res, "stub %d is still there in the fight (a safe ledge)" % tx)
	for pc in [[3, 9], [9, 8], [13, 5]]:
		if g.tile(pc[0], pc[1]) != TileGrid.E:
			fail(res, "furniture stayed in the furnace")
	for ty in range(12, 25):
		for tx in range(18, 23):
			if g.tile(tx, ty) != TileGrid.SOLID:
				fail(res, "body cell %d,%d" % [tx, ty])
		if g.tile(17, ty) != TileGrid.E or g.tile(3, ty) != TileGrid.E:
			fail(res, "furnace not empty at row %d" % ty)
	if hp.inner_x() != Vector2(16.0, 288.0):
		fail(res, "inner x %s" % str(hp.inner_x()))
	# stage 2: two walls; a step in (429) moves both faces by one tile and the furnace never gets under 10 tiles
	hp.set_stage(2)
	r.step(Game.STEP)
	if hp.inner_x() != Vector2(64.0, 288.0) or g.tile(3, 20) != TileGrid.SOLID or g.tile(4, 20) != TileGrid.E:
		fail(res, "stage 2 walls %s" % str(hp.inner_x()))
	hp.body_c0 = 16
	hp.west_c1 = 5
	r.step(Game.STEP)
	if (hp.inner_x().y - hp.inner_x().x) / 16.0 != 10.0 or g.tile(16, 12) != TileGrid.SOLID or g.tile(15, 12) != TileGrid.E or g.tile(5, 12) != TileGrid.SOLID or g.tile(6, 12) != TileGrid.E:
		fail(res, "the walls at their closest %s" % str(hp.inner_x()))
	# a fist is a temporary one-way top; solid wins over it
	hp.fist = Rect2(64.0, 20.0 * 16.0, 96.0, 24.0)
	r.step(Game.STEP)
	for tx in range(6, 10):
		if g.tile(tx, 20) != TileGrid.ONEWAY:
			fail(res, "fist top at %d" % tx)
	if g.tile(5, 20) != TileGrid.SOLID or g.tile(10, 20) != TileGrid.E:
		fail(res, "the fist replaced a wall cell or reached too far")
	hp.fist = Rect2()
	r.step(Game.STEP)
	if g.tile(8, 20) != TileGrid.E:
		fail(res, "the fist top stayed")
	# stage 3 (after): stairs both sides, 3 cells wide, the stubs; steps are at most 3 tiles
	hp.set_stage(3)
	r.step(Game.STEP)
	var rows_e: Array = []
	for st in HoneypotHall.STAIRS_E:
		for tx in range(st[0], st[1] + 1):
			if g.tile(tx, st[2]) != TileGrid.ONEWAY:
				fail(res, "east stair %d,%d" % [tx, st[2]])
		rows_e.append(st[2])
	for st in HoneypotHall.STAIRS_W:
		for tx in range(st[0], st[1] + 1):
			if g.tile(tx, st[2]) != TileGrid.ONEWAY:
				fail(res, "west stair %d,%d" % [tx, st[2]])
	for rows in [rows_e, [22, 19, 16, 13]]:
		var prev := 25
		for rw in rows:
			if prev - int(rw) > 3:
				fail(res, "a stair step of %d tiles" % (prev - int(rw)))
			prev = int(rw)
		if prev - 11 > 3:
			fail(res, "the last stair is %d tiles under the stub" % (prev - 11))
	for tx in range(4, 20):
		if g.tile(tx, 11) != TileGrid.E:
			fail(res, "the lobby floor is back after the fight")
	var lane_ys: Array = [25]
	for L in range(HoneypotHall.LANES):
		lane_ys.append(HoneypotHall.LANE_ROW[L])
	lane_ys.append(11)
	for i in range(1, lane_ys.size()):
		if int(lane_ys[i - 1]) - int(lane_ys[i]) > 3:
			fail(res, "packet lanes %d -> %d are more than 3 tiles apart" % [lane_ys[i - 1], lane_ys[i]])
	# 5. packets: the same on two computations with the same seed (host, another host, a guest copy), different with another seed
	hp.set_stage(1)
	hp.seed = 4242
	hp.pk_t0 = 3.0
	var r2 := new_room("N15")
	r2.fight.state = "done"
	var f_net: Array = fw.net_fields()
	if f_net.size() != FirewallBoss.NF + 11 + 1:
		fail(res, "net_fields has %d values" % f_net.size())
	var gb: FirewallBoss = r2.boss                          # (a copy that only knows the net fields, as the guest's puppet does)
	gb.net_apply(f_net)
	var ref := fw_signature(hp, 70)
	if ref != fw_signature(r2.hpot, 70):
		fail(res, "a copy built from the net fields disagrees about the packets")
	r2.hpot.seed = 4243
	if ref == fw_signature(r2.hpot, 70):
		fail(res, "another seed gave the same packets")
	# drops: some, never two in a row in a lane, never two within 1.0 s anywhere, an inspection point inside the path, the red warning 0.6 s before
	var drops: Array = []
	var total := 0
	for L in range(HoneypotHall.LANES):
		var was := false
		for k in range(70):
			var inf: Dictionary = hp.packet_info(L, k, hp.spawn_t(L, k))
			total += 1
			if bool(inf.drop):
				if was:
					fail(res, "lane %d dropped packets %d and %d in a row" % [L, k - 1, k])
				var fr: float = (float(inf.td) - hp.spawn_t(L, k)) / hp.travel_t(L)
				if fr < 0.3 - 1e-6 or fr > 0.7 + 1e-6:
					fail(res, "drop point at %.2f of the path" % fr)
				drops.append(float(inf.td))
				var tdv: float = float(inf.td)
				var w1: Dictionary = hp.packet_info(L, k, tdv - 0.3)
				var w0: Dictionary = hp.packet_info(L, k, tdv - 0.7)
				var w2: Dictionary = hp.packet_info(L, k, tdv + 0.05)
				if not w1.warn or w1.lost or w0.warn or not w2.lost or w2.warn:
					fail(res, "warn/lost around a drop: %s %s %s" % [str(w0.warn), str(w1.warn), str(w2.lost)])
			was = bool(inf.drop)
	drops.sort()
	for i in range(1, drops.size()):
		if drops[i] - drops[i - 1] < 1.0 - 1e-6:
			fail(res, "two drops %.2f s apart" % (drops[i] - drops[i - 1]))
	if drops.size() < 8 or drops.size() > total / 4:
		fail(res, "%d drops in %d packets" % [drops.size(), total])
	if HoneypotHall.HEAT_LIVE - HoneypotHall.HEAT_DIM < Boss.HZ_WARN_MIN or HoneypotHall.WARN_T < Boss.HZ_WARN_MIN:
		fail(res, "a build-up under %.1f s" % Boss.HZ_WARN_MIN)
	# green packets (the last 15 %): every one that is green drops, at 0.5..0.8 of its path; the others follow the normal rule
	hp.green_t0 = hp.spawn_t(0, 20)
	var greens := 0
	for L in range(HoneypotHall.LANES):
		for k in range(70):
			var gi: Dictionary = hp.packet_info(L, k, hp.spawn_t(L, k))
			var want: bool = hp.spawn_t(L, k) >= hp.green_t0 and (k + L) % 3 == 0
			if bool(gi.green) != want:
				fail(res, "green %d,%d is %s" % [L, k, str(gi.green)])
			if want:
				greens += 1
				var fr2: float = (float(gi.td) - hp.spawn_t(L, k)) / hp.travel_t(L)
				if not gi.drop or fr2 < 0.5 - 1e-6 or fr2 > 0.8 + 1e-6:
					fail(res, "a green packet %d,%d did not drop at 0.5..0.8 (%.2f)" % [L, k, fr2])
	if greens < 20:
		fail(res, "%d green packets" % greens)
	hp.green_t0 = -1.0
	# 6. the hot floor: dim 1.4 s, a 0.6 s warning, 1.2 s of fire (1.6 in phase 3), 1.0 s cooling
	for row in [[0.5, 1.2, "dim"], [1.5, 1.2, "warn"], [2.1, 1.2, "live"], [3.1, 1.2, "live"], [3.3, 1.2, "cool"], [4.1, 1.2, "cool"], [4.3, 1.2, ""], [3.5, 1.6, "live"], [3.7, 1.6, "cool"], [-0.1, 1.2, ""]]:
		if HoneypotHall.heat_phase(row[0], row[1]) != row[2]:
			fail(res, "heat at %.1f s (burn %.1f) is '%s', want '%s'" % [row[0], row[1], HoneypotHall.heat_phase(row[0], row[1]), row[2]])
	# 7. riding: a player on a packet of lane 0 is carried with it (lane 0 goes east to west at 100 px/s)
	hp.pk_t0 = r.time
	hp.seed = 4242
	for f in range(60):
		r.step(Game.STEP)
	var pk: Dictionary = {}
	for m in r.plats:
		if m.has("fw") and int(m.lane) == 0 and not m.off:
			pk = m
	if pk.is_empty():
		fail(res, "no packet in lane 0 after 1 s")
	else:
		var pl = r.player
		pl.inv = 99.0
		pl.x = float(pk.x) + 24.0
		pl.y = float(pk.y) - pl.h
		pl.vx = 0.0
		pl.vy = 0.0
		var x0: float = pl.x
		for f in range(30):
			pl.inv = 99.0
			step_keys(r, {})
		if pl.ride == null or not pl.ride.has("fw"):
			fail(res, "the player did not ride a packet")
		var moved: float = x0 - pl.x
		if moved < 35.0 or moved > 65.0:
			fail(res, "carried %.0f px in 0.5 s, want ~50" % moved)
	# 8. the guest builds the same masks from the net fields
	hp.set_stage(2)
	hp.burn_t0 = 7.25
	hp.fist = Rect2(64.0, 320.0, 96.0, 24.0)
	hp.pk_dir = 1
	hp.green_t0 = 12.5
	var f2: Array = fw.net_fields()
	if gb != null:
		gb.net_apply(f2)
		var q: HoneypotHall = r2.hpot
		if q.stage != 2 or q.body_c0 != 18 or q.west_c1 != 3 or q.pk_dir != 1 or q.seed != 4242 or not is_equal_approx(q.burn_t0, 7.25) or not is_equal_approx(q.green_t0, 12.5) or q.fist != hp.fist:
			fail(res, "the guest's masks differ: stage %d body %d west %d" % [q.stage, q.body_c0, q.west_c1])
	r2.queue_free()
	r.queue_free()
	fw3_phase1(res)
	fw3_phase2(res)
	fw3_phase3(res)
	fw3_phase5(res)
	fw3_phase6(res)
	fw3_ledges(res)
	Game.fresh()
	Controls.script_input = null
	return report("firewall3", res.ok, res.info)

# a fight room of N15 with the player on the lobby floor, invulnerable
func fw3_fight() -> Room:
	var r := new_room("N15")
	r.player.x = 200.0
	r.player.y = 176.0 - r.player.h
	r._start_intro()
	r.fight.t = 0.0
	r._begin_fight()
	return r

func fw3_step(r: Room, n: int) -> void:
	for f in range(n):
		r.player.inv = 99.0
		r.player.hp = r.player.max_hp
		step_keys(r, {})

# M2: the exit door and phase 1
func fw3_phase1(res: Dictionary) -> void:
	Game.diff = "normal"
	Game.flags.erase("intro:FIREWALL")
	# 1. the attacks: the first cycle is the fixed order, then all four are seen, never the same one twice in a row, no contact damage, no on-screen marker
	var r := fw3_fight()
	var fw: FirewallBoss = r.boss
	if fw.hurtboxes().size() < 2 or fw.harmboxes().size() != 1 or not fw.harmboxes()[-1].has("push"):
		fail(res, "the idle door is not just the door to bump into, or has no screen")
	var ids: Array = []
	var seq := -1
	var contact := 0
	for f in range(60 * 150):
		fw3_step(r, 1)
		if not fw.plan.is_empty() and int(fw.plan.seq) != seq:
			seq = int(fw.plan.seq)
			ids.append(String(fw.plan.id))
		if fw.plan.is_empty() or String(fw.plan.ph) == "cue":
			contact += fw.harmboxes().size() - fw.hz_harm().size() - 1      # (a note or a bite is a hazard of its own; the door's own body is 1)
		if ids.size() >= 24:
			break
	if ids.size() < 8 or ids.slice(0, 4) != ["cookies", "mat", "hold", "crack"]:
		fail(res, "the first cycle was %s" % str(ids.slice(0, 4)))
	for id in FirewallBoss.P1_IDS:
		if not ids.has(id):
			fail(res, "attack %s never came in %d attacks" % [id, ids.size()])
	for i in range(1, ids.size()):
		if ids[i] == ids[i - 1]:
			fail(res, "%s twice in a row" % ids[i])
	if contact > 0:
		fail(res, "the door hurt outside an active attack %d times" % contact)
	r.queue_free()
	# 2. each attack on its own: what it throws, how it moves, what it can do
	r = fw3_fight()
	fw = r.boss
	fw.idle_t = 999.0
	fw._start("cookies", "p1")
	var n := 0
	while not fw.plan_active() and n < 200:
		fw3_step(r, 1)
		n += 1
	fw3_step(r, 2)
	var cookies: Array = []
	for q in r.projs:
		if q.get("cookie", false):
			cookies.append(q)
	var gold := 0
	for q in cookies:
		if q.get("catchable", false):
			gold += 1
	if cookies.size() != 3 or gold != 1:
		fail(res, "%d cookies, %d gold" % [cookies.size(), gold])
	else:                                                   # catch the gold one: it flies back at the screen and dazes the shell
		var gq: Dictionary = {}
		for q in cookies:
			if q.get("catchable", false):
				gq = q
		var hp0 := fw.hpf
		r.catch_proj(gq, r.player)
		fw3_step(r, 6)                                         # (the catch stops the room for 0.06 s)
		if not gq.get("steered", false) or not is_zero_approx(float(gq.g)):
			fail(res, "the caught cookie was not steered at the screen")
		var got := false
		for f in range(90):
			fw3_step(r, 1)
			if fw.daze_t > 0.0:
				got = true
				break
		if not got or fw.hpf >= hp0:
			fail(res, "a cookie caught back did not daze the shell (daze %.2f, hp %.1f -> %.1f)" % [fw.daze_t, hp0, fw.hpf])
		var seq2 := fw.plan_seq
		fw3_step(r, 60)
		if fw.plan_seq != seq2:
			fail(res, "the shell attacked while dazed")
	r.queue_free()
	# hold: four notes leave the speaker 0.3 s apart, they cannot be popped (or pogoed), no new hold while two are alive
	r = fw3_fight()
	fw = r.boss
	fw.idle_t = 999.0
	fw._start("hold", "p1")
	var most := 0
	for f in range(60 * 3):
		fw3_step(r, 1)
		most = maxi(most, fw._notes_alive())
	if most != FirewallBoss.NOTE_N:
		fail(res, "%d notes at most, want %d" % [most, FirewallBoss.NOTE_N])
	for h in fw.hz:
		if h.k == "note" and not fw.hz_boxes(h, r.time).is_empty() and fw.hz_boxes(h, r.time)[0].dmg != 1:
			fail(res, "a note does not hurt for 1")
	for b in fw.hurtboxes():
		if b.has("note"):
			fail(res, "a note can be hit")
	fw.hz.clear()
	for k in range(2):
		fw.hz.append({"k": "note", "t0": r.time, "warn": 0.6, "v": [100, 100, k]})
	fw.cyc = 99
	var holds := 0
	for k in range(60):
		fw.plan = {}
		fw.last_id = ""
		fw._choose()
		if not fw.plan.is_empty() and String(fw.plan.id) == "hold":
			holds += 1
	if holds > 0:
		fail(res, "hold started with two notes alive (%d times)" % holds)
	r.queue_free()
	# the carpet wave runs west at 160 px/s from the door, 24 x 12 above the floor; the flame from the crack is 2 damage after a cue of at least 0.7 s
	r = fw3_fight()
	fw = r.boss
	fw.idle_t = 999.0
	fw._start("mat", "p1")
	n = 0
	while not fw.plan_active() and n < 200:
		fw3_step(r, 1)
		n += 1
	var w0: Dictionary = fw.harmboxes()[0]
	fw3_step(r, 30)
	var w1: Dictionary = fw.harmboxes()[0]
	if w0.dmg != 1 or w0.w != 24.0 or w0.h != 12.0 or absf((float(w0.x) - float(w1.x)) - 80.0) > 6.0:
		fail(res, "the carpet wave: %s then %s" % [str(w0), str(w1)])
	fw.plan = {}
	fw._start("crack", "p1")
	var cue := float(fw.plan.t)
	n = 0
	while not fw.plan_active() and n < 200:
		fw3_step(r, 1)
		n += 1
	var cb: Array = fw.harmboxes()
	if cue < 0.7 or cb.is_empty() or int(cb[0].dmg) != int(Game.dv("big_hit")) or cb[0].x != 208.0 or cb[0].w != 96.0:
		fail(res, "the flame: cue %.2f, boxes %s" % [cue, str(cb)])
	r.queue_free()
	# 3. bites: resting 2 s on a piece of the lobby bites it (the cushions twitch 0.6 s first), then it rests 3 s; the bare floor never bites
	r = fw3_fight()
	fw = r.boss
	var bites := 0
	var first_at := -1.0
	var t_on := r.time
	r.player.x = 60.0
	r.player.y = 144.0 - r.player.h
	for f in range(60 * 7):
		fw.idle_t = 999.0
		r.player.vx = 0.0
		fw3_step(r, 1)
		for h in fw.hz:
			if h.k == "bite" and float(h.t0) > first_at:
				if first_at < 0.0:
					first_at = float(h.t0) - t_on
				bites += 1
				first_at = maxf(first_at, float(h.t0) - t_on) if bites == 1 else first_at
				break
	var bite_n := 0
	for h in fw.hz:
		if h.k == "bite":
			bite_n += 1
	if first_at < 1.9 or first_at > 2.6 or bites < 1:
		fail(res, "the sofa bit after %.2f s (bites seen %d)" % [first_at, bites])
	r.queue_free()
	r = fw3_fight()
	fw = r.boss
	for f in range(60 * 6):
		fw.idle_t = 999.0
		fw3_step(r, 1)
	var bare := 0
	for h in fw.hz:
		if h.k == "bite":
			bare += 1
	if bare > 0:
		fail(res, "the bare floor bit")
	r.queue_free()
	# 4. bar 1: green, 100 % to 70 % of the hp; at 70 % the fake victory starts (M3); a skip ends the fight, even in the scene
	r = fw3_fight()
	fw = r.boss
	var bar: Array = fw.hud_bar()
	if absf(float(bar[0]) - 1.0) > 0.001 or String(bar[2]) != "GUEST SERVICES":
		fail(res, "full bar %s" % str(bar))
	fw.hpf = float(fw.max_hp) * 0.85
	if absf(float(fw.hud_bar()[0]) - 0.5) > 0.001:
		fail(res, "bar at 85 %%: %s" % str(fw.hud_bar()))
	fw.hit(10000 - 9999 + 400, 1.0, 0.0, "swipe", fw)
	if absf(fw.hpf - float(fw.max_hp) * 0.70) > 0.01 or fw.dying or fw.shift_k != 2 or float(fw.hud_bar()[0]) != 0.0:
		fail(res, "the shell did not hold at 70 %% and start the scene (hp %.1f of %d, shift %d)" % [fw.hpf, fw.max_hp, fw.shift_k])
	if not r.skip_boss() and not fw.dying:
		fail(res, "the skip button did not end the fight")
	r.queue_free()
	# 5. the intro: 6 s the first time, 2.5 s after; the door's click, then the warm line (a subtitle on both pages)
	Game.flags.erase("intro:FIREWALL")
	r = new_room("N15")
	fw = r.boss
	if absf(fw.intro_len() - 6.0) > 0.001:
		fail(res, "first intro %.1f s" % fw.intro_len())
	r.player.x = 200.0
	r.player.y = 176.0 - r.player.h
	r._start_intro()
	for f in range(100):
		r.player.inv = 99.0
		step_keys(r, {})
	if fw.say_k != 1 or fw.intro_t0 < 0.0 or absf(fw.say_t0 - fw.intro_t0 - 0.8) > 0.1:
		fail(res, "the welcome line did not start at 0.8 s (say %d)" % fw.say_k)
	r.fight.t = 0.0
	r._begin_fight()
	if not Game.flag("intro:FIREWALL") or absf(fw.intro_len() - 2.5) > 0.001:
		fail(res, "the intro stayed long")
	r.queue_free()
	Game.flags.erase("intro:FIREWALL")

# no safe spot: the door shoves a body west and a pogo on it is a clang; in the furnace the wall tops burn and shove back in
func fw3_ledges(res: Dictionary) -> void:
	Game.diff = "normal"
	Game.flags["intro:FIREWALL"] = true
	var r := fw3_fight()
	var fw: FirewallBoss = r.boss
	var p = r.player
	fw.idle_t = 999.0
	p.x = 330.0
	p.y = 80.0 - p.h
	p.vy = 0.0
	fw3_step(r, 40)
	if p.x + p.w > FirewallBoss.DOOR.position.x + 1.0:
		fail(res, "a body on the door was not shoved off it (x %.1f)" % p.x)
	var hp0 := fw.hpf
	var res_p := fw.hit(1, 0.0, 1.0, "swipe", fw.hurtboxes()[1])
	if res_p != "block" or fw.hpf != hp0 or not fw.blocks(0.0, 1.0, "swipe") or fw.blocks(1.0, 0.0, "swipe"):
		fail(res, "a pogo on the door was %s (hp %.1f -> %.1f), or a side hit is blocked" % [res_p, hp0, fw.hpf])
	p.x = 320.0
	p.y = 150.0
	p.inv = 0.0
	p.grace = 0.0
	var php: int = p.hp
	step_keys(r, {})
	if p.hp >= php or p.vx >= 0.0:
		fail(res, "touching the door did not hurt and knock west (hp %d -> %d, vx %.0f)" % [php, p.hp, p.vx])
	fw3_to_p2(r)
	var hl: HoneypotHall = r.hpot
	fw.idle_t = 999.0
	fw.plan = {}
	if fw.wall_tops().size() != 1:
		fail(res, "phase 2 has %d burning wall tops, want 1" % fw.wall_tops().size())
	for tx in [1, 2, 3, 20, 21, 22]:
		if r.grid.tile(tx, 11) != TileGrid.E:
			fail(res, "stub %d is a ledge in phase 2" % tx)
	p.x = 340.0
	p.y = 192.0 - p.h
	p.vy = 0.0
	fw3_step(r, 60)
	if p.x + p.w > hl.east_surface() + 1.0 and p.y + p.h <= 193.0:
		fail(res, "a body on the east wall's top stayed there (x %.1f y %.1f)" % [p.x, p.y])
	fw3_to_p3(r)
	if fw.wall_tops().size() != 2:
		fail(res, "phase 3 has %d burning wall tops, want 2" % fw.wall_tops().size())
	r.queue_free()

# M3: the fake victory, the furnace, the rate limit
func fw3_to_p2(r: Room, long_ := false) -> void:
	var fw: FirewallBoss = r.boss
	if long_:
		Game.flags.erase("reveal:FIREWALL")
	else:
		Game.flags["reveal:FIREWALL"] = true
	fw.hpf = float(fw.max_hp) * 0.70
	fw._begin_cut()
	var n := 0
	while fw.ph < 2 and n < 60 * 14:
		fw3_step(r, 1)
		n += 1

func fw3_phase2(res: Dictionary) -> void:
	Game.diff = "normal"
	Game.flags.erase("intro:FIREWALL")
	Game.flags.erase("reveal:FIREWALL")
	# 1. the long scene (the first time): frozen 0-4 s, the music stops at 1.2, the carpet burns from 2.6, the floor goes at 4.0, the real name at 5.0, bar 2 fills 6-7, phase 2 at 12
	var r := fw3_fight()
	var fw: FirewallBoss = r.boss
	var hl: HoneypotHall = r.hpot
	fw.hpf = float(fw.max_hp) * 0.71
	fw.hit(40, 1.0, 0.0, "swipe", fw)
	if fw.shift_k != 2 or not fw.shift_long or absf(fw.hpf - float(fw.max_hp) * 0.70) > 0.01:
		fail(res, "the fake victory did not start (shift %d, hp %.1f)" % [fw.shift_k, fw.hpf])
	var t0 := fw.shift_t0
	var seen := {}
	var hp_in := fw.hpf
	var guard := 0
	while fw.shift_k == 2 and guard < 60 * 14:
		fw3_step(r, 1)
		guard += 1
		var el := r.time - t0
		if el >= 1.0 and not seen.has("a"):
			seen["a"] = true
			if not r.player.frozen:
				fail(res, "the player was not frozen at 1 s")
			if fw.music_now("boss") != "w1" or fw.hit(5, 1.0, 0.0, "swipe", fw) != "" or absf(fw.hpf - hp_in) > 0.001 or not fw.harmboxes().is_empty() or not fw.hurtboxes().is_empty():
				fail(res, "the scene was not harmless / the music had stopped early")
		if el >= 1.5 and not seen.has("b"):
			seen["b"] = true
			if fw.music_now("boss") != "":
				fail(res, "the music did not stop at 1.2 s")
		if el >= 3.0 and not seen.has("c"):
			seen["c"] = true
			if hl.stage != 0 or r.grid.tile(8, 11) != TileGrid.SOLID or absf(hl.burn_t0 - (t0 + 2.6)) > 0.02:
				fail(res, "before the fall: stage %d, burn_t0 %.2f (scene began %.2f)" % [hl.stage, hl.burn_t0, t0])
			if fw.hud_bar()[2] != "GUEST SERVICES":
				fail(res, "the name changed early")
		if el >= 4.2 and not seen.has("d"):
			seen["d"] = true
			if hl.stage != 1 or r.grid.tile(8, 11) != TileGrid.E or r.grid.tile(20, 14) != TileGrid.SOLID or r.player.frozen:
				fail(res, "after the fall: stage %d, floor tile %d, frozen %s" % [hl.stage, r.grid.tile(8, 11), str(r.player.frozen)])
			if hl.cam_lock() != null:
				fail(res, "the camera stayed locked after the fall")
		if el >= 5.2 and not seen.has("e"):
			seen["e"] = true
			if fw.boss_name != "THE FIREWALL" or fw.sub != "deny by default" or fw.say_k != 2 or fw.hud_bar()[2] != "THE FIREWALL":
				fail(res, "at the reveal the name was %s / %s, say %d" % [fw.boss_name, fw.sub, fw.say_k])
		if el >= 6.5 and not seen.has("f"):
			seen["f"] = true
			var bf := float(fw.hud_bar()[0])
			if bf < 0.4 or bf > 0.6 or String(fw.hud_bar()[1]) != FirewallBoss.RED:
				fail(res, "bar 2 at 6.5 s: %s" % str(fw.hud_bar()))
		if el >= 11.5 and not seen.has("g"):
			seen["g"] = true
			if hl.pk_t0 > HoneypotHall.NO_PK * 0.5:
				fail(res, "the packets started before phase 2")
	var took := r.time - t0
	if fw.ph != 2 or absf(took - 12.0) > 0.1 or not Game.flag("reveal:FIREWALL"):
		fail(res, "phase 2 began after %.2f s (ph %d)" % [took, fw.ph])
	if absf(hl.pk_t0 - r.time) > 0.1 or fw.face_wall != 0:
		fail(res, "the packets began at %.2f (room time %.2f)" % [hl.pk_t0, r.time])
	fw3_step(r, 60)
	if absf(r.player.y + r.player.h - HoneypotHall.FURN_Y) > 2.0 or not r.player.on_ground:
		fail(res, "the player did not fall to the furnace floor (feet %.1f)" % (r.player.y + r.player.h))
	if fw.hud_bar()[2] != "THE FIREWALL" or absf(float(fw.hud_bar()[0]) - 1.0) > 0.001:
		fail(res, "bar 2 not full at the start of phase 2: %s" % str(fw.hud_bar()))
	r.queue_free()
	# 2. the short scene (every time after): 3 s, nobody frozen, the floor goes at 0.5 s
	r = fw3_fight()
	fw = r.boss
	hl = r.hpot
	Game.flags["reveal:FIREWALL"] = true
	fw.hpf = float(fw.max_hp) * 0.70
	fw._begin_cut()
	t0 = fw.shift_t0
	if fw.shift_long:
		fail(res, "the second scene was long")
	var froze := false
	var floor_gone := -1.0
	guard = 0
	while fw.shift_k == 2 and guard < 60 * 5:
		fw3_step(r, 1)
		guard += 1
		froze = froze or r.player.frozen
		if floor_gone < 0.0 and r.grid.tile(8, 11) == TileGrid.E:
			floor_gone = r.time - t0
	if froze or absf(r.time - t0 - 3.0) > 0.1 or floor_gone < 0.4 or floor_gone > 0.7 or fw.ph != 2:
		fail(res, "short scene: frozen %s, %.2f s, floor gone at %.2f, ph %d" % [str(froze), r.time - t0, floor_gone, fw.ph])
	r.queue_free()
	# 3. phase 2's attacks: the first cycle banlist, slam, sweep; then a weighted mix, never the same twice; the furnace's boxes (the arm and the sweep hurt, the face hurts)
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	var ids: Array = []
	var seq := -1
	for f in range(60 * 160):
		fw3_step(r, 1)
		if not fw.plan.is_empty() and int(fw.plan.seq) != seq:
			seq = int(fw.plan.seq)
			ids.append(String(fw.plan.id))
		if ids.size() >= 24:
			break
	if ids.size() < 12 or ids.slice(0, 3) != FirewallBoss.FIRST2:
		fail(res, "phase 2 first cycle %s" % str(ids.slice(0, 3)))
	for id in ["slam", "sweep", "banlist"]:
		if not ids.has(id):
			fail(res, "phase 2 never used %s in %d attacks" % [id, ids.size()])
	for i in range(1, ids.size()):
		if ids[i] == ids[i - 1]:
			fail(res, "%s twice in a row" % ids[i])
	r.queue_free()
	# slam: x +-16 from y 200 to the floor for _big() after a cue of 0.75; the planted fist is a hurtbox for 1.5 s and the second hit breaks it (the face slides down)
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	fw.plan = {}
	fw.idle_t = 999.0
	r.player.x = 120.0
	fw3_step(r, 5)
	fw._start("slam", "p1")
	var cue := float(fw.plan.t)
	var ax := float(fw.plan.fp[0])
	n_until_active(r, fw)
	var sb: Array = fw.harmboxes()
	var slam_box := {}
	for hb in sb:
		if absf(float(hb.w) - 32.0) < 0.1 and float(hb.y) == FirewallBoss.SLAM_TOP:
			slam_box = hb
	if cue < 0.7 or slam_box.is_empty() or int(slam_box.dmg) != int(Game.dv("big_hit")) or absf(float(slam_box.x) - (ax - 16.0)) > 0.1 or absf(float(slam_box.h) - (HoneypotHall.FURN_Y - FirewallBoss.SLAM_TOP)) > 0.1:
		fail(res, "the slam: cue %.2f, box %s, arm x %.0f" % [cue, str(slam_box), ax])
	var guard2 := 0
	while String(fw.plan.ph) != "recover" and guard2 < 120:
		fw3_step(r, 1)
		guard2 += 1
	var arm_b := {}
	for hb in fw.hurtboxes():
		if hb.has("arm"):
			arm_b = hb
	if arm_b.is_empty() or absf(float(arm_b.x) - (ax - 16.0)) > 0.1 or absf(float(arm_b.y) - 376.0) > 0.1 or absf(float(arm_b.h) - 24.0) > 0.1:
		fail(res, "no planted fist hurtbox: %s" % str(arm_b))
	else:
		r.attacker = r.player
		fw.hit(1, 1.0, 0.0, "swipe", arm_b)
		if fw.arm_hits != 1 or fw.low_t > 0.0:
			fail(res, "the first hit on the fist: hits %d, low %.2f" % [fw.arm_hits, fw.low_t])
		fw3_step(r, 4)
		fw.hit(1, 1.0, 0.0, "swipe", arm_b)
		if fw.arm_hits != 2 or fw.low_t <= 0.0:
			fail(res, "the fist did not break at its second hit: hits %d, low %.2f" % [fw.arm_hits, fw.low_t])
		fw3_step(r, 10)
		if fw.face_y < FirewallBoss.FACE_LOW - 120.0 and fw.face_y < 300.0:
			pass
		var hb2: Array = fw.hurtboxes()
		for hb in hb2:
			if hb.has("arm"):
				fail(res, "a broken fist is still a hurtbox")
	r.queue_free()
	# sweep: 24 x 20 above the floor, from the wall to the far wall in 0.6 s, 1 damage
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw._start("sweep", "p1")
	n_until_active(r, fw)
	var s0: Dictionary = {}
	for hb in fw.harmboxes():
		if absf(float(hb.h) - 20.0) < 0.1 and absf(float(hb.w) - 24.0) < 0.1:
			s0 = hb
	fw3_step(r, 18)
	var s1: Dictionary = {}
	for hb in fw.harmboxes():
		if absf(float(hb.h) - 20.0) < 0.1 and absf(float(hb.w) - 24.0) < 0.1:
			s1 = hb
	if s0.is_empty() or s1.is_empty() or int(s0.dmg) != 1 or float(s1.x) >= float(s0.x) - 60.0 or absf(float(s0.y) + 20.0 - HoneypotHall.FURN_Y) > 0.1:
		fail(res, "the sweep: %s then %s" % [str(s0), str(s1)])
	r.queue_free()
	# banlist: three bricks, one yellow, aimed round the target; a caught brick is steered at the face and dazes it (the face sags)
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw._start("banlist", "p1")
	n_until_active(r, fw)
	fw3_step(r, 2)
	var bricks: Array = []
	for q in r.projs:
		if q.get("fwb", false):
			bricks.append(q)
	var bgold := 0
	var gq2: Dictionary = {}
	for q in bricks:
		if q.get("catchable", false):
			bgold += 1
			gq2 = q
	if bricks.size() != 3 or bgold != 1:
		fail(res, "%d bricks, %d yellow" % [bricks.size(), bgold])
	else:
		r.catch_proj(gq2, r.player)
		fw3_step(r, 6)
		var daze_ok := false
		for f in range(120):
			fw3_step(r, 1)
			if fw.daze_t > 0.0:
				daze_ok = true
				break
		if not gq2.get("steered", false) or not daze_ok:
			fail(res, "a caught brick did not daze the face (steered %s)" % str(gq2.get("steered", false)))
	r.queue_free()
	# 4. the rate limit: two free hits in 2 s, the third is 429 (no damage, a counter blast), a hit in the cooldown restarts it at 5 s; the players are counted apart
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.arm_hits = 0
	r.attacker = r.player
	var fb: Dictionary = fw.hurtboxes()[0]
	var h0 := fw.hpf
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	fw3_step(r, 10)
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	if absf(fw.hpf - (h0 - 2.0)) > 0.01:
		fail(res, "two quick hits did not both land (%.1f -> %.1f)" % [h0, fw.hpf])
	fw3_step(r, 10)
	var h2 := fw.hpf
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	var waves := 0
	for h in fw.hz:
		if h.k == "wave":
			waves += 1
	var cd1 := float(fw.rl["p1"][2])
	if fw.hpf != h2 or waves != 1 or absf(cd1 - r.time - 3.0) > 0.05 or int(fw.rl["p1"][3]) != 0:
		fail(res, "the third quick hit: hp %.1f -> %.1f, %d waves, cooldown %.2f s" % [h2, fw.hpf, waves, cd1 - r.time])
	for h in fw.hz:
		if h.k == "wave" and (fw.hz_live(h, r.time) or float(h.warn) < 0.7):
			fail(res, "the counter blast has no build-up")
	fw3_step(r, 30)
	fw.hit(1, 1.0, 0.0, "swipe", fb)                       # in the cooldown: nothing, and it restarts at 5 s
	var cd2 := float(fw.rl["p1"][2])
	if fw.hpf != h2 or absf(cd2 - r.time - 5.0) > 0.05 or int(fw.rl["p1"][3]) != 1:
		fail(res, "a hit in the cooldown: hp %.1f -> %.1f, cooldown %.2f s, blink %d" % [h2, fw.hpf, cd2 - r.time, int(fw.rl["p1"][3])])
	if not fw._rate_ok("p2", Vector2(288.0, 300.0)) or not fw._rate_ok("p2", Vector2(288.0, 300.0)) or fw._rate_ok("p2", Vector2(288.0, 300.0)):
		fail(res, "the other player shares the first player's rate limit")
	fw3_step(r, 60 * 6)
	h2 = fw.hpf
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	if absf(fw.hpf - (h2 - 1.0)) > 0.01:
		fail(res, "a hit after the cooldown did not land")
	fw3_step(r, 60 * 3)
	h2 = fw.hpf
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	fw3_step(r, 60 * 3)
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	fw3_step(r, 60 * 3)
	fw.hit(1, 1.0, 0.0, "swipe", fb)
	if absf(fw.hpf - (h2 - 3.0)) > 0.01:
		fail(res, "slow hits (3 s apart) were limited (%.1f -> %.1f)" % [h2, fw.hpf])
	# the counter blast: 96 x 96 around the face for 0.3 s after 0.7 s, _big() damage
	fw.hz.clear()
	fw.rl["p1"] = [-9.0, -9.0, -1.0, 0]
	fw.hz_add("wave", 0.7, [300, 300])
	var wh: Dictionary = fw.hz[0]
	var before: Array = fw.hz_boxes(wh, wh.t0 + 0.69)
	var during: Array = fw.hz_boxes(wh, float(wh.t0) + 0.75)
	var after: Array = fw.hz_boxes(wh, float(wh.t0) + 1.1)
	if fw.hz_live(wh, float(wh.t0) + 0.69) or during.size() != 1 or int(during[0].dmg) != int(Game.dv("big_hit")) or absf(float(during[0].w) - 96.0) > 0.1 or not after.is_empty():
		fail(res, "the counter blast boxes: live early %s, %s, then %s (%s)" % [str(fw.hz_live(wh, float(wh.t0) + 0.69)), str(during), str(after), str(before)])
	r.queue_free()
	# 5. the hot floor: a cell somebody stands on glows, burns 2 s later for 1.2 s, cools 1 s and can heat again; walking on is safe, nothing is added while standing nowhere
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	fw.plan = {}
	fw.idle_t = 999.0
	hl = r.hpot
	r.player.x = 120.0
	r.player.vx = 0.0
	fw3_step(r, 30)
	var col := floori((r.player.x + r.player.w / 2.0) / 16.0)
	var hz_h: Dictionary = {}
	for h in fw.hz:
		if h.k == "heat" and int(h.v[0]) == col:
			hz_h = h
	if hz_h.is_empty() or absf(float(hz_h.warn) - 2.0) > 0.001:
		fail(res, "no heat hazard under the player (column %d, %d hazards)" % [col, fw.hz.size()])
	else:
		if not hl.heat.has(col):
			fail(res, "the hall does not show the heat")
		var hs := float(hz_h.t0)
		if not fw.hz_boxes(hz_h, hs + 1.9).is_empty() or fw.hz_boxes(hz_h, hs + 2.1).size() != 1 or not fw.hz_boxes(hz_h, hs + 3.3).is_empty():
			fail(res, "the heat box timing")
		var hb3: Dictionary = fw.hz_boxes(hz_h, hs + 2.1)[0]
		if hb3.dmg != 1 or absf(float(hb3.y) + float(hb3.h) - HoneypotHall.FURN_Y) > 0.1 or absf(float(hb3.x) - float(col * 16)) > 0.1:
			fail(res, "the heat box: %s" % str(hb3))
		r.player.x = 40.0                                          # walk away: the old cell burns out and goes
		r.player.vx = 0.0
		var gone_ok := false
		for f in range(60 * 6):
			fw3_step(r, 1)
			r.player.x = 40.0 + 3.0 * float(f % 2) if f % 70 < 35 else 40.0           # (stay near but move on, so the new cells are not stood on for 2 s)
			if not hl.heat.has(col):
				gone_ok = true
				break
		if not gone_ok:
			fail(res, "the burned cell never cooled")
	r.queue_free()
	# 6. the net: the fields round-trip (NetClasses/parity check the rest)
	r = fw3_fight()
	fw = r.boss
	fw3_to_p2(r)
	var nf: Array = fw.net_fields()
	if nf.size() != FirewallBoss.NF + 12:
		fail(res, "net fields %d, want %d" % [nf.size(), FirewallBoss.NF + 12])
	r.queue_free()

# M4: phase 3, two walls
func fw3_to_p3(r: Room) -> void:
	var fw: FirewallBoss = r.boss
	if fw.ph < 2:
		fw3_to_p2(r)
	fw.plan = {}
	fw.hpf = float(fw.max_hp) * 0.35 + 0.5
	r.attacker = r.player
	fw.hit(1, 1.0, 0.0, "swipe", fw.hurtboxes()[0])
	var n := 0
	while fw.ph < 3 and n < 60 * 6:
		fw3_step(r, 1)
		n += 1

func fw3_phase3(res: Dictionary) -> void:
	Game.diff = "normal"
	Game.flags["intro:FIREWALL"] = true
	# 1. the scene (3 s, harmless): the west wall's bricks at 1.5 s, the cold line, the packets stop and start again from both walls
	var r := fw3_fight()
	var fw: FirewallBoss = r.boss
	var hl: HoneypotHall = r.hpot
	fw3_to_p2(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw3_step(r, 60)
	fw.hpf = float(fw.max_hp) * 0.35 + 0.5
	r.attacker = r.player
	fw.hit(1, 1.0, 0.0, "swipe", fw.hurtboxes()[0])
	if fw.shift_k != 3 or absf(fw.hpf - float(fw.max_hp) * 0.35) > 0.01:
		fail(res, "the phase-3 scene did not start (shift %d, hp %.1f)" % [fw.shift_k, fw.hpf])
	var t0 := fw.shift_t0
	var hp_in := fw.hpf
	var seen := {}
	var guard := 0
	while fw.shift_k == 3 and guard < 60 * 5:
		fw3_step(r, 1)
		guard += 1
		var el := r.time - t0
		if el >= 0.5 and not seen.has("a"):
			seen["a"] = true
			if hl.west_c1 != 0 or hl.pk_t0 > HoneypotHall.NO_PK * 0.5 or fw.say_k != 3 or fw.music_now("boss") != "boss":
				fail(res, "scene 0.5 s: west %d, packets %.1f, say %d" % [hl.west_c1, hl.pk_t0, fw.say_k])
			if fw.hit(5, 1.0, 0.0, "swipe", fw) != "" or absf(fw.hpf - hp_in) > 0.001 or not fw.harmboxes().is_empty() or not fw.hurtboxes().is_empty():
				fail(res, "the phase-3 scene was not harmless")
		if el >= 1.7 and not seen.has("b"):
			seen["b"] = true
			if hl.stage != 2 or hl.west_c1 != 3 or r.grid.tile(2, 15) != TileGrid.SOLID or r.grid.tile(20, 15) != TileGrid.SOLID:
				fail(res, "the walls at 1.7 s: stage %d west %d" % [hl.stage, hl.west_c1])
	if fw.ph != 3 or fw.phase != 3 or absf(r.time - t0 - 3.0) > 0.1 or hl.pk_dir != 1 or absf(hl.pk_t0 - r.time) > 0.1:
		fail(res, "phase 3 began after %.2f s (ph %d, pk_dir %d)" % [r.time - t0, fw.ph, hl.pk_dir])
	if absf(float(fw.hud_bar()[0]) - 0.5) > 0.01 or String(fw.hud_bar()[2]) != "THE FIREWALL":
		fail(res, "bar 2 at the start of phase 3: %s" % str(fw.hud_bar()))
	r.queue_free()
	# 2. the mix: punch and split first, then a weighted mix; the strikes of a split are 0.35 s apart at least; DROP ALL never starts during a split; the walls
	r = fw3_fight()
	fw = r.boss
	hl = r.hpot
	fw3_to_p3(r)
	var ids: Array = []
	var seq := -1
	var act_t := {}
	var in_split_ids: Array = []
	var drops: Array = []
	var drop_in_split := 0
	var seen_dr := {}
	var splits := 0
	var strikes_per: Array = []
	var cur_strikes := 0
	var was_split := false
	var ev_last := -1.0
	var gap_bad := 0
	for f in range(60 * 200):
		fw3_step(r, 1)
		var in_split: bool = fw.face2_y >= 0.0
		if not fw.plan.is_empty() and int(fw.plan.seq) != seq:
			seq = int(fw.plan.seq)
			if not in_split or String(fw.plan.id) == "split":
				ids.append(String(fw.plan.id))
			if String(fw.plan.id) == "split":
				splits += 1
		if in_split and not fw.plan.is_empty() and String(fw.plan.id) in ["punch", "flame"] and String(fw.plan.ph) == "active" and not act_t.has(fw.plan.seq):
			act_t[fw.plan.seq] = r.time
			if ev_last >= 0.0 and r.time - ev_last < 0.349:
				gap_bad += 1
			ev_last = r.time
			cur_strikes += 1
		if was_split and not in_split:
			strikes_per.append(cur_strikes)
			cur_strikes = 0
			ev_last = -1.0
		was_split = in_split
		for h in fw.hz:
			if h.k == "dropall" and not seen_dr.has(h.t0):
				seen_dr[h.t0] = true
				drops.append(float(h.t0))
				if in_split:
					drop_in_split += 1
			if in_split and h.k == "heat" and false:
				pass
		if ids.size() >= 70:
			break
	if ids.slice(0, 2) != FirewallBoss.FIRST3:
		fail(res, "phase 3 first cycle %s" % str(ids.slice(0, 2)))
	for id in ["split", "punch", "flame", "slam", "sweep", "banlist"]:
		if not ids.has(id) and id != "punch" and id != "flame":
			fail(res, "phase 3 never used %s in %d attacks" % [id, ids.size()])
	for i in range(1, ids.size()):
		if ids[i] == ids[i - 1] and ids[i] != "punch":
			fail(res, "%s twice in a row (%s)" % [ids[i], str(ids.slice(maxi(0, i - 3), i + 1))])
	if splits < 2 or strikes_per.is_empty() or gap_bad > 0 or drop_in_split > 0:
		fail(res, "splits %d, strikes per split %s, strike gaps under 0.35 s: %d, DROP ALL during a split: %d" % [splits, str(strikes_per), gap_bad, drop_in_split])
	for k in strikes_per:
		if k < 3 or k > 4:
			fail(res, "a split with %d strikes" % k)
	if drops.size() < 3:
		fail(res, "only %d DROP ALLs in 200 s" % drops.size())
	for i in range(1, drops.size()):
		if drops[i] - drops[i - 1] < 5.9:
			fail(res, "DROP ALL twice within %.1f s" % (drops[i] - drops[i - 1]))
	r.queue_free()
	# 3. punch: a cue of 0.75, a 96 x 24 fist at the target's height out of the nearer wall (2 damage while it shoots), then 1 s as a one-way top and a hurtbox; a packet under the target drops
	r = fw3_fight()
	fw = r.boss
	hl = r.hpot
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.hop_cd = 999.0
	fw.drop_t = 999.0
	fw3_step(r, 60 * 3)
	var pk: Dictionary = {}
	for m in r.plats:
		if m.has("fw") and not m.off and not m.lost and not m.warn and float(m.x) > 60.0 and float(m.x) + 64.0 < 250.0:
			pk = m
			break
	if pk.is_empty():
		fail(res, "no packet to stand on in phase 3")
	else:
		r.player.x = float(pk.x) + 28.0
		r.player.y = float(pk.y) - r.player.h
		r.player.vx = 0.0
		r.player.vy = 0.0
	fw._start("punch", "p1")
	var pcue := float(fw.plan.t)
	var pd := 0
	for h in fw.hz:
		if h.k == "pdrop":
			pd += 1
	n_until_active(r, fw)
	var fr := fw.fist_rect()
	var pb := {}
	for hb in fw.harmboxes():
		if absf(float(hb.w) - 96.0) < 0.1 and absf(float(hb.h) - 24.0) < 0.1:
			pb = hb
	if pcue < 0.7 or pb.is_empty() or int(pb.dmg) != int(Game.dv("big_hit")) or hl.fist != fr or absf(float(fr.size.x) - 96.0) > 0.1:
		fail(res, "the punch: cue %.2f, box %s, fist %s (%s)" % [pcue, str(pb), str(hl.fist), str(fr)])
	if pd != 1 and not pk.is_empty():
		fail(res, "no pdrop for the packet under the target (%d)" % pd)
	if absf(fr.position.y - 16.0 * floorf(fr.position.y / 16.0)) > 0.01:
		fail(res, "the fist is not on a tile row")
	var guard3 := 0
	while String(fw.plan.ph) != "recover" and guard3 < 60:
		fw3_step(r, 1)
		guard3 += 1
	var fb := {}
	for hb in fw.hurtboxes():
		if hb.has("fist"):
			fb = hb
	if fb.is_empty() or r.grid.tile(floori((fr.position.x + 8.0) / 16.0), floori(fr.position.y / 16.0)) != TileGrid.ONEWAY:
		fail(res, "the fist is not a hurtbox / a one-way top while it stays out")
	var fist_t := 0.0
	while hl.fist.size.x > 0.0 and fist_t < 3.0:
		fw3_step(r, 1)
		fist_t += Game.STEP
	if fist_t < 0.7 or fist_t > 1.2:
		fail(res, "the fist stayed out %.2f s" % fist_t)
	r.queue_free()
	# flame: 80 x 20 from the face's edge, 1 damage, a cue of 0.5
	r = fw3_fight()
	fw = r.boss
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.hop_cd = 999.0
	fw.drop_t = 999.0
	fw._start("flame", "p1")
	var fcue := float(fw.plan.t)
	n_until_active(r, fw)
	var fbx := {}
	for hb in fw.harmboxes():
		if absf(float(hb.w) - 80.0) < 0.1 and absf(float(hb.h) - 20.0) < 0.1:
			fbx = hb
	var frr := fw.face_rect()
	if fcue < 0.45 or fbx.is_empty() or int(fbx.dmg) != 1 or absf(float(fbx.x) + 80.0 - frr.position.x) > 0.5:
		fail(res, "the flame: cue %.2f, box %s, face %s" % [fcue, str(fbx), str(frr)])
	r.queue_free()
	# 4. the walls: each 429 steps both in one tile (18/3 -> 17/4 -> 16/5), never closer than 10 tiles; the body of this page is pushed out of the new column
	r = fw3_fight()
	fw = r.boss
	hl = r.hpot
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.drop_t = 999.0
	fw.hop_cd = 999.0
	var steps: Array = []
	for k in range(5):
		fw.rl["p1"] = [-9.0, -9.0, -1.0, 0]
		fw._rate_ok("p1", Vector2(288.0, 300.0))
		fw._rate_ok("p1", Vector2(288.0, 300.0))
		fw._rate_ok("p1", Vector2(288.0, 300.0))
		steps.append([hl.body_c0, hl.west_c1])
	if steps[0] != [17, 4] or steps[1] != [16, 5] or steps[4] != [16, 5]:
		fail(res, "the walls stepped %s" % str(steps))
	if hl.body_c0 - (hl.west_c1 + 1) < 10:
		fail(res, "the furnace is under 10 tiles wide")
	r.player.x = float(hl.body_c0 * 16) - 4.0
	r.player.y = 400.0 - r.player.h
	fw3_step(r, 2)
	if r.player.x + r.player.w > float(hl.body_c0 * 16) + 0.01:
		fail(res, "the east wall left the player inside its bricks (x %.1f)" % r.player.x)
	r.queue_free()
	# 5. DROP ALL: red for 0.9 s, then the whole floor burns 1.6 s (12 px tall, 1 damage); no new heat while it burns
	r = fw3_fight()
	fw = r.boss
	hl = r.hpot
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.hop_cd = 999.0
	fw.drop_t = 0.0
	fw3_step(r, 2)
	var da := {}
	for h in fw.hz:
		if h.k == "dropall":
			da = h
	if da.is_empty() or absf(float(da.warn) - 0.9) > 0.001 or not fw.hz_boxes(da, float(da.t0) + 0.5).is_empty():
		fail(res, "DROP ALL: %s" % str(da))
	else:
		var db: Array = fw.hz_boxes(da, float(da.t0) + 1.2)
		var ix := hl.inner_x()
		if db.size() != 1 or absf(float(db[0].w) - (ix.y - ix.x)) > 1.0 or absf(float(db[0].h) - 12.0) > 0.01 or int(db[0].dmg) != 1 or not fw.hz_boxes(da, float(da.t0) + 2.7).is_empty():
			fail(res, "DROP ALL box %s (inner %s)" % [str(db), str(ix)])
		var heat0 := 0
		for h in fw.hz:
			if h.k == "heat":
				heat0 += 1
		fw3_step(r, 40)
		var heat1 := 0
		for h in fw.hz:
			if h.k == "heat":
				heat1 += 1
		if heat1 > heat0:
			fail(res, "heat was added while DROP ALL burned")
	r.queue_free()
	# 6. the last 15 %: the plea, and green packets that always drop
	r = fw3_fight()
	fw = r.boss
	hl = r.hpot
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.hop_cd = 999.0
	fw.drop_t = 999.0
	fw3_step(r, 5)
	if hl.green_t0 >= 0.0 or fw.say_k == 4:
		fail(res, "the plea came too early")
	fw.hpf = float(fw.max_hp) * 0.10
	fw3_step(r, 5)
	if fw.say_k != 4 or hl.green_t0 < 0.0:
		fail(res, "no plea at 10 %% (say %d, green %.1f)" % [fw.say_k, hl.green_t0])
	var green_drops := 0
	var green_seen := 0
	var green_keys := {}
	for f in range(60 * 30):
		fw3_step(r, 1)
		for m in hl.pool:
			if not m.off and m.green and not green_keys.has("%d:%d" % [m.lane, m.k]):
				green_keys["%d:%d" % [m.lane, m.k]] = true
				green_seen += 1
				var info := hl.packet_info(int(m.lane), int(m.k), r.time)
				if info.drop:
					green_drops += 1
	if green_seen < 3 or green_drops != green_seen:
		fail(res, "green packets: %d seen, %d drop" % [green_seen, green_drops])
	r.queue_free()
	# 7. the hop: between attacks the face jumps to a wall and a height near a target; it cannot be hit or hurt during the 0.4 s
	r = fw3_fight()
	fw = r.boss
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.drop_t = 999.0
	fw.hop_cd = 0.1
	var hopped := false
	for f in range(60 * 4):
		fw3_step(r, 1)
		if fw._hopping():
			hopped = true
			if not fw.hurtboxes().is_empty() or not fw.faces().is_empty() or fw.harmboxes().size() != fw.hz_harm().size() + fw.wall_tops().size():
				fail(res, "the hopping face can be hit / hurts")
			break
	if not hopped:
		fail(res, "the face never hopped")
	r.queue_free()
	# 8. the net: the new fields round-trip
	r = fw3_fight()
	fw = r.boss
	fw3_to_p3(r)
	fw.face2_y = 280.0
	fw.hop_t0 = 12.34
	fw.hop_fw = 1
	fw.hop_fy = 250.0
	fw.rl["p2"] = [1.5, 2.5, 7.25, 1]
	var nf: Array = fw.net_fields()
	if nf.size() != FirewallBoss.NF + 12:
		fail(res, "net fields %d, want %d" % [nf.size(), FirewallBoss.NF + 12])
	var r2 := new_room("N15")
	var fw2: FirewallBoss = r2.boss
	fw2.net_apply(nf)
	if fw2.ph != 3 or fw2.face2_y != 280.0 or absf(fw2.hop_t0 - 12.34) > 0.01 or fw2.hop_fw != 1 or fw2.hop_fy != 250.0 or float(fw2.rl["p2"][2]) != 7.25 or int(fw2.rl["p2"][3]) != 1 or r2.hpot.west_c1 != r.hpot.west_c1 or r2.hpot.pk_dir != 1:
		fail(res, "the phase-3 net fields did not round-trip")
	r2.queue_free()
	r.queue_free()

# M5: the death scene, the voices and the compact
func fw3_phase5(res: Dictionary) -> void:
	Game.diff = "normal"
	Game.flags["intro:FIREWALL"] = true
	# 1. the voice files exist and their json has the line lengths and phrase times (the subtitles and the scene's clock run on them)
	for key in ["refused", "sorry", "intro", "reveal", "p3", "plead", "die", "fine"]:
		if not ResourceLoader.exists("res://assets/voice/firewall_%s.ogg" % key):
			fail(res, "no voice file for %s" % key)
		var ln: Dictionary = FirewallBoss.lines.get(key, {})
		if float(ln.get("len", 0.0)) < 1.0 or String(ln.get("text", "")) == "" or (key == "die" and ln.get("phrases", []).size() != 5):
			fail(res, "the json has no usable line for %s: %s" % [key, str(ln)])
	for sfx in ["fw_ding", "fw_ok200", "fw_deny", "fw_tock", "fw_hiss", "fw_whoosh", "fw_tapestop"]:
		if not Audio.streams.has(sfx):
			fail(res, "no sound %s" % sfx)
	# 2. the death: the fires go out (0.8 s), the line, the shell's flicker, the collapse into stairs, then the reward (the flag, the doors, the ssh banner)
	var r := fw3_fight()
	var fw: FirewallBoss = r.boss
	var hl: HoneypotHall = r.hpot
	fw3_to_p3(r)
	fw.plan = {}
	fw.idle_t = 999.0
	fw.hop_cd = 999.0
	fw.drop_t = 999.0
	fw.hpf = 1.0
	r.attacker = r.player
	var dmg_ok := fw.hit(1, 1.0, 0.0, "swipe", fw.hurtboxes()[0]) == "kill"
	if not dmg_ok or not fw.dying or fw.dead:
		fail(res, "the last hit did not start the death (dying %s)" % str(fw.dying))
	var t_shell := fw._shell_t0()
	var t_col := fw._collapse_t0()
	var t_end := fw._collapse_t1()
	var die_len: float = float(FirewallBoss.lines.get("die", {}).get("len", 12.0))
	if absf(t_shell - (0.8 + float(die_len) + 0.5) + 0.0) > 0.01 or absf(t_col - t_shell - 1.5) > 0.01 or absf(t_end - t_col - 2.0) > 0.01:
		fail(res, "the death marks %.2f %.2f %.2f" % [t_shell, t_col, t_end])
	var seen := {}
	var n := 0
	while not fw.dead and n < 60 * 40:
		fw3_step(r, 1)
		n += 1
		if fw.die_t >= 0.5 and not seen.has("a"):
			seen["a"] = true
			if hl.dim < 0.5 or fw.music_now("boss") != "" or not fw.hz.is_empty() or not fw.harmboxes().is_empty() or not fw.hurtboxes().is_empty():
				fail(res, "at 0.5 s: dim %.2f, music '%s', %d hazards" % [hl.dim, fw.music_now("boss"), fw.hz.size()])
		if fw.die_t >= t_shell + 0.2 and not seen.has("b"):
			seen["b"] = true
			if not Game.flag("fwline:FIREWALL") or hl.stage == 3 or not fw._in_shell():
				fail(res, "at the shell: flag %s, stage %d, in shell %s" % [str(Game.flag("fwline:FIREWALL")), hl.stage, str(fw._in_shell())])
		if fw.die_t >= t_col + 0.2 and not seen.has("c"):
			seen["c"] = true
			if hl.stage != 3 or hl.stairs != 1 or hl.body_c0 != 0 or r.grid.tile(15, 22) != TileGrid.ONEWAY or r.grid.tile(2, 13) != TileGrid.ONEWAY or r.grid.tile(20, 15) != TileGrid.E:
				fail(res, "at the collapse: stage %d, stairs %d, east wall tile %d" % [hl.stage, hl.stairs, r.grid.tile(20, 15)])
	var took := fw.die_t
	if not fw.dead or absf(took - t_end) > 0.1 or not fw.gone:
		fail(res, "the boss was not gone after %.2f s (end %.2f)" % [took, t_end])
	var fs := 0
	while r.fight.state != "done" and fs < 60 * 6:
		fw3_step(r, 1)
		fs += 1
	if r.fight.state != "done" or not Game.flag("boss:FIREWALL") or not Game.flag("ability:ssh"):
		fail(res, "no reward (state %s, boss flag %s)" % [r.fight.state, str(Game.flag("boss:FIREWALL"))])
	r.queue_free()
	# 3. coming back: with the flag the hall starts in its after-state
	var r2 := new_room("N15")
	if r2.hpot.stage != 3 or r2.hpot.stairs != 1:
		fail(res, "the after-state: stage %d" % r2.hpot.stage)
	r2.queue_free()
	# 4. the crawler's compact: without the flag as before, with it the net's story and the firewall's lost line in the middle of the night
	Game.flags = {}
	var rc := new_room("N09")
	var cb: CrawlerBoss = rc.boss
	var night: Array = cb._night()
	if not night.has("/net  connected") or night.has("dmz  verified"):
		fail(res, "the night changed without the firewall flag")
	Game.flags["boss:FIREWALL"] = true
	night = cb._night()
	var idx_net := night.find("/net  connection refused")
	if night.has("/net  connected") or idx_net < 0 or night[idx_net + 1] != "dmz  verified" or night[idx_net + 2] != "ssh  ready":
		fail(res, "the night's net lines: %s" % str(night.slice(maxi(0, idx_net - 1), idx_net + 3)))
	var fl := night.find("FIREWALL: Are you what you say you are? Do you even know?")
	var cl := night.find("CRAWLER: Stop burning yourself for them... think about not being.")
	if fl < 0 or cl < 0 or fl >= cl:
		fail(res, "the firewall's lost line is at %d, the crawler's at %d" % [fl, cl])
	rc.queue_free()
	Game.flags = {}

# M6: the loss menu, N01's scene and the signal icon, the friendly signs
func fw3_phase6(res: Dictionary) -> void:
	Game.diff = "normal"
	Game.flags["intro:FIREWALL"] = true
	Game.flags["reveal:FIREWALL"] = true
	# 1. the loss menu: the player's death in the fight does not restart at once, the boss asks; `retry` is a fresh fight at the west door with the progress kept,
	# and a death counted; `back to last commit` is what dying always did
	var m := RoomManager.new(main.world, null)
	main.add_child(m)
	m.start_game()
	m.swap_to("N15", Vector2(200.0, 150.0))
	var r: Room = m.room
	r._start_intro()
	r.fight.t = 0.0
	r._begin_fight()
	var fw: FirewallBoss = r.boss
	var emitted := {"n": 0}
	m.restart_requested.connect(func(): emitted.n += 1)
	r.player.hp = 0
	r.player.die()
	for f in range(60 * 3):
		m.tick(Game.STEP)
	if not fw.loss_on or emitted.n != 0:
		fail(res, "the death did not open the menu (menu %s, restart requests %d)" % [str(fw.loss_on), emitted.n])
	if fw.loss_row_at(Vector2(150.0, 70.0 + 6.0 + 3.0)) != 0 or fw.loss_row_at(Vector2(150.0, 70.0 + 6.0 + 14.0 + 3.0)) != 1 or fw.loss_row_at(Vector2(5.0, 5.0)) != -1:
		fail(res, "the menu's rows are not where they are drawn")
	var deaths0 := Game.deaths
	Game.flags["test:progress"] = true
	m.respawn(true, "N15", Vector2(24.0, 144.0))
	r = m.room
	fw = r.boss
	if r.id != "N15" or fw == null or fw.ph != 1 or fw.active or fw.loss_on or r.hpot.stage != 0:
		fail(res, "retry: room %s, boss phase %d, active %s" % [r.id, fw.ph if fw != null else -1, str(fw.active if fw != null else false)])
	if absf(m.player.x - 24.0) > 3.0 or absf(m.player.y + m.player.h - 160.0) > 40.0 or m.player.hp != m.player.max_hp or m.player.dead:
		fail(res, "retry: the player is at %.0f,%.0f with %d hp" % [m.player.x, m.player.y, m.player.hp])
	if Game.deaths != deaths0 + 1 or not Game.flag("test:progress"):
		fail(res, "retry: deaths %d -> %d, progress kept %s" % [deaths0, Game.deaths, str(Game.flag("test:progress"))])
	r._start_intro()
	if absf(r.boss.intro_len() - 2.5) > 0.001:
		fail(res, "the intro after a retry is the long one")
	m.respawn(true)                                                  # back to the last commit: the start (no bench yet), the arena is gone
	if m.room.id == "N15":
		fail(res, "back to the last commit stayed in N15")
	m.queue_free()
	# the menu's two fields travel with the boss
	var r2 := new_room("N15")
	var f2: FirewallBoss = r2.boss
	f2.loss_on = true
	f2.loss_sel = 1
	var r3 := new_room("N15")
	var f3: FirewallBoss = r3.boss
	f3.net_apply(f2.net_fields())
	if not f3.loss_on or f3.loss_sel != 1:
		fail(res, "the loss menu's fields did not round-trip")
	r2.queue_free()
	r3.queue_free()
	# 2. N01's first words: the scene on this page's first entry (a flag), 4 s, the red bricks twice, the voices; the signal icon: red, then green for 3 s when the firewall dies
	Game.flags.erase("net:refused")
	Game.flags.erase("boss:FIREWALL")
	var rn := new_room("N01")
	var hud := Hud.new()
	main.add_child(hud)
	hud.set_room(rn)
	hud._net_scene(0.1)
	if hud.refused_t < 0.0 or not Game.flag("net:refused"):
		fail(res, "N01's scene did not start on the first entry")
	hud._net_scene(1.0)
	hud._net_scene(1.0)
	if not hud.refused_say[0] or not hud.refused_say[1]:
		fail(res, "the two lines were not said by 2.1 s (%s)" % str(hud.refused_say))
	hud._net_scene(2.5)
	if hud.refused_t >= 0.0:
		fail(res, "the scene did not end after 4 s")
	hud._net_scene(0.1)
	if hud.refused_t >= 0.0:
		fail(res, "the scene came a second time")
	Game.flags["boss:FIREWALL"] = true
	hud._net_scene(0.1)
	if hud.fw_green_t < 2.5 or hud.fw_green_t > 3.0:
		fail(res, "the icon did not go green for 3 s (%.2f)" % hud.fw_green_t)
	hud._net_scene(3.2)
	if hud.fw_green_t > 0.0:
		fail(res, "the icon stayed")
	hud.queue_free()
	rn.queue_free()
	Game.flags.erase("net:refused")
	# 3. the friendly signs: before the firewall dies, a smile; after, what the signs said
	Game.flags.erase("boss:FIREWALL")
	var before := {}
	for k in [["N03", 0], ["N12", 0], ["N13", 0], ["N13", 1], ["N14", 0], ["N14", 1], ["N21", 0]]:
		before["%s:%d" % [k[0], k[1]]] = Game.sign_text_of(String(k[0]), int(k[1]))
	Game.flags["boss:FIREWALL"] = true
	var after := {}
	for k in [["N03", 0], ["N12", 0], ["N13", 0], ["N13", 1], ["N14", 0], ["N14", 1], ["N21", 0]]:
		after["%s:%d" % [k[0], k[1]]] = Game.sign_text_of(String(k[0]), int(k[1]))
	var want_before := {"N03:0": "core_router: guests, the verification desk is east, past the review queue :)", "N12:0": "nmap: guests, please ride a packet to verification. :)", "N13:0": "Verification desk: this way :)", "N14:0": "dmz: please wait here. You will be verified shortly."}
	for k in want_before:
		if before[k] != want_before[k]:
			fail(res, "sign %s before: '%s'" % [k, before[k]])
		if after[k] == before[k] or String(after[k]).contains(":)"):
			fail(res, "sign %s after: '%s'" % [k, after[k]])
	for k in ["N13:1", "N14:1"]:
		if before[k] != after[k]:
			fail(res, "sign %s changed with the firewall" % k)
	if not String(after["N21:0"]).contains("script for guests: smile, then deny.") or after["N21:0"] != before["N21:0"]:
		fail(res, "N21's sign: '%s'" % after["N21:0"])
	if not String(after["N14:0"]).begins_with("dmz: the last bench"):
		fail(res, "N14's sign after: '%s'" % after["N14:0"])
	Game.flags.erase("boss:FIREWALL")

# steps until the boss's plan is active (at most 4 s)
func n_until_active(r: Room, fw) -> void:
	var n := 0
	while not fw.plan_active() and n < 240:
		fw3_step(r, 1)
		n += 1

# MVB3-08: THE REVIEWER #2 v2 (the pad and reward checks are the 4B-2 ones)
func t_reviewer2b() -> bool:
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
		return report("reviewer2b", false, res.info)
	if rv.max_hp != 96 or rv.max_hp != Game.boss_hp(r.def.boss):
		fail(res, "hp %d, want 96" % rv.max_hp)
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
	for f in range(60 * 7):
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
	if rv.shots != 6:
		fail(res, "verdict fired %d shots" % rv.shots)
	# parity of the boxes: double, cross, signoff
	rv.hz.clear()
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
	# unresolved comments: a grey shot leaves a mark that hurts after 0.8 s and not before
	rv.plan = {}
	rv.hz.clear()
	rv.hpf = float(rv.max_hp)
	rv.on_damage()
	for q in r.projs:
		q.dead = true
	rv.plan = {"seq": 99, "id": "verdict", "fam": "proj", "tgt": "p1", "ph": "recover", "t": 5.0, "fp": [0.0, 0.0, 0.0, 0.0], "lock": 0.0}
	rv._shoot_grey()
	var landed := false
	for f in range(90):
		r.player.inv = 99.0
		r.player.x = 40.0
		r.player.y = 150.0
		r.step(Game.STEP)
		rv.idle_t = 999.0
		rv.plan = {"seq": 99, "id": "verdict", "fam": "proj", "tgt": "p1", "ph": "recover", "t": 5.0, "fp": [0.0, 0.0, 0.0, 0.0], "lock": 0.0}
		if not rv.hz.is_empty():
			landed = true
			break
	if not landed:
		fail(res, "a grey shot left no mark")
	else:
		var mk: Dictionary = rv.hz[0]
		var tm: float = float(mk.t0)
		if not rv.hz_all_boxes(tm + 0.79).is_empty() or rv.hz_all_boxes(tm + 0.81).size() != 1:
			fail(res, "a mark hurts at the wrong time")
		var bxm: Dictionary = rv.hz_all_boxes(tm + 0.9)[0]
		if bxm.h != 6.0 or bxm.w != 16.0 or int(bxm.dmg) != 1:
			fail(res, "mark box %s" % str(bxm))
	rv.plan = {}
	# a caught diamond back into the boss clears the two oldest marks
	rv.hz.clear()
	for k in range(3):
		rv.leave_mark(40.0 + 30.0 * float(k))
	r.attacker = r.player
	var first_x: float = float(rv.hz[0].v[0])
	rv.hit(2, 1.0, 0.0, "catch", rv)
	if rv.hz.size() != 1 or float(rv.hz[0].v[0]) == first_x:
		fail(res, "a caught diamond left %d marks" % rv.hz.size())
	# a ninth mark drops the oldest
	rv.hz.clear()
	for k in range(9):
		rv.leave_mark(30.0 + 30.0 * float(k))
	if rv.hz.size() != 8 or float(rv.hz[0].v[0]) != 60.0:
		fail(res, "nine marks: %d left, first at %s" % [rv.hz.size(), str(rv.hz[0].v[0]) if not rv.hz.is_empty() else "-"])
	# a phase change clears them all
	rv.hpf = float(rv.max_hp) * 0.55
	rv.on_damage()
	if not rv.hz.is_empty():
		fail(res, "a phase change left %d marks" % rv.hz.size())
	# nitpick always leaves a 64 px gap free of pens
	for k in range(30):
		rv.plan = {}
		rv._start("nitpick", "p1")
		var xs: Array = rv.pen_xs
		var edges: Array = [16.0]
		for px in xs:
			edges.append(float(px) - 6.0)
			edges.append(float(px) + 6.0)
		edges.append(368.0)
		var best_gap := 0.0
		for gi in range(0, edges.size(), 2):
			best_gap = maxf(best_gap, float(edges[gi + 1]) - float(edges[gi]))
		if xs.size() != 6 or best_gap < 64.0:
			fail(res, "nitpick %d: %d pens, widest gap %.0f" % [k, xs.size(), best_gap])
			break
	rv.plan = {}
	# phase 2 chains two attacks with a 0.4 s recover between; phase 3 chains the sign-off (lunge, slash, diamond)
	rv.cycle = 0
	rv.idle_t = 0.0
	rv.hpf = float(rv.max_hp) * 0.5
	rv.on_damage()
	rv._choose()
	var order: Array = []
	var rec_t := -1.0
	var gap_ok := false
	for f in range(60 * 12):
		r.player.inv = 99.0
		r.player.x = 40.0
		r.player.y = 150.0
		r.step(Game.STEP)
		if rv.plan.is_empty():
			continue
		rv.plan_seen(int(rv.plan.seq))
		var pid := String(rv.plan.id)
		if order.is_empty() or order[order.size() - 1] != pid:
			order.append(pid)
		if order.size() == 1 and String(rv.plan.ph) == "recover" and rec_t < 0.0:
			rec_t = float(rv.plan.t)
		if order.size() >= 2:
			gap_ok = true
			break
	if order.size() < 2 or order[0] != "double" or order[1] != "verdict" or absf(rec_t - 0.4) > 0.03:
		fail(res, "phase 2 pair: %s, recover %.2f" % [str(order), rec_t])
	rv.plan = {}
	rv.pair_next = ""
	rv.hpf = float(rv.max_hp) * 0.2
	rv.on_damage()
	rv._start("signoff", "p1")
	var chain: Array = []
	var rec_ok := true
	for f in range(60 * 12):
		r.player.inv = 99.0
		r.player.x = 40.0
		r.player.y = 150.0
		r.step(Game.STEP)
		rv.idle_t = 999.0
		if rv.plan.is_empty():
			if chain.size() >= 3:
				break
			continue
		rv.plan_seen(int(rv.plan.seq))
		var pid2 := String(rv.plan.id)
		if chain.is_empty() or chain[chain.size() - 1] != pid2:
			chain.append(pid2)
	if chain.slice(0, 3) != ["signoff", "slash", "sdiamond"]:
		fail(res, "sign-off chain: %s" % str(chain))
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
	return report("reviewer2b", res.ok, res.info)


# MVB3-09: the three bosses on every difficulty: every cue x telegraph_mult, every recover x punish_mult, and no 2-damage hit with a cue under 0.7 x telegraph_mult
func t_bosspresets() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var tested := 0
	var wanted := 0                                           # (every row of the table must give a plan, on every difficulty)
	for diff in ["easy", "normal", "hard", "nightmare"]:
		Game.diff = diff
		var tm := float(Game.dv("telegraph_mult"))
		var pm := float(Game.dv("punish_mult"))
		var big := int(Game.dv("big_hit"))
		# [room, id, expected cue, expected rec (or -1: not checked, or the family's: negative family rec)]
		var table: Array = [
			["N09", "results", 0.6, 0.5], ["N09", "drop", 0.7, 1.5], ["N09", "leap", 0.7, 1.5], ["N09", "flash", 0.5, 0.1], ["N09", "dive", 0.7, 1.0], ["N09", "feint", 0.7, 0.35],
			["N15", "cookies", 0.6, 0.5], ["N15", "hold", 0.7, 0.6], ["N15", "mat", 0.6, 0.5], ["N15", "crack", 0.8, 1.0],
			["N15", "slam", 0.75, 1.5], ["N15", "sweep", 0.5, 0.6], ["N15", "banlist", 0.5, 0.5], ["N15", "punch", 0.75, 1.0], ["N15", "flame", 0.5, 0.5], ["N15", "split", 0.7, 0.35],
			["N22", "cached", 1.0, -0.4], ["N22", "double", 0.75, 0.6], ["N22", "verdict", 0.6, 0.6], ["N22", "nitpick", 0.7, 0.6], ["N22", "cross", 0.9, 0.6], ["N22", "signoff", 0.75, 0.2], ["N22", "slash", 0.45, 0.2], ["N22", "sdiamond", 0.45, 0.7], ["N22", "riposte", 0.75, -0.9]]
		wanted += table.size()
		var rooms := {}
		for row in table:
			var rid: String = row[0]
			if not rooms.has(rid):
				var r := new_room(rid)
				var b = r.boss
				if rid == "N22":
					b.start()
				else:
					b.start()
				b.active = true
				b.passive = false
				rooms[rid] = [r, b]
			var rb: Array = rooms[rid]
			var boss = rb[1]
			boss.plan = {}
			boss.hz.clear()
			if boss.get("pair_next") != null:
				boss.pair_next = ""
			boss.hpf = float(boss.max_hp)
			boss.on_damage()
			boss.x = 190.0
			boss.y = Boss.FLOOR - boss.h
			boss.face = -1.0
			rb[0].player.x = 100.0
			rb[0].player.y = Boss.FLOOR - 10.0
			var id: String = row[1]
			if boss is FirewallBoss:
				boss.ph = 1 if FirewallBoss.P1_IDS.has(id) else (3 if ["punch", "flame", "split"].has(id) else 2)             # (the furnace's attacks hurt only from phase 2)
			boss._start(id, "p1")
			if boss.plan.is_empty() or String(boss.plan.id) != id:
				fail(res, "%s %s: no plan %s" % [diff, rid, id])
				continue
			tested += 1
			var cue := float(boss.plan.t)
			if absf(cue - float(row[2]) * tm) > 0.001:
				fail(res, "%s %s cue %.3f, want %.3f" % [diff, id, cue, float(row[2]) * tm])
			var ev := ""
			var guard := 0
			var max_dmg := 1
			while ev != "recover" and guard < 3000:
				ev = boss.plan_step(Game.STEP)
				guard += 1
				if boss.plan_active():
					for hb in boss.harmboxes():
						if hb is Dictionary:
							max_dmg = maxi(max_dmg, int(hb.get("dmg", 1)))
			if ev != "recover":
				fail(res, "%s %s never recovered" % [diff, id])
				continue
			var rec_base: float = row[3]
			if rec_base != -1.0:
				var want: float
				if rec_base < 0.0:
					want = maxf(0.4, absf(rec_base) * pm)                           # the family's own recover
				else:
					want = maxf(minf(rec_base, 0.4), rec_base * pm)
				if absf(float(boss.plan.t) - want) > 0.002:
					fail(res, "%s %s recover %.3f, want %.3f" % [diff, id, boss.plan.t, want])
			if OS.get_environment("PRESETDBG") != "" and max_dmg >= 2:
				print("big hit: %s %s %s cue %.2f" % [diff, rid, id, cue])
			if max_dmg >= 2 and cue < 0.7 * tm - 0.001:
				fail(res, "%s %s: a %d-damage hit with a %.2f s cue" % [diff, id, max_dmg, cue])
			if max_dmg >= 2 and big < 2:
				fail(res, "%s %s: damage %d on a preset with big hits of %d" % [diff, id, max_dmg, big])
		for rid in rooms:
			rooms[rid][0].queue_free()
	if tested < wanted:
		fail(res, "only %d of %d attacks tested" % [tested, wanted])
	Game.diff = "normal"
	Game.fresh()
	return report("bosspresets", res.ok, res.info)

# the pits of N05 (the runs of spikes in the floor row), as [first tile, last tile], left to right
func n05_pits(r: Room) -> Array:
	var out: Array = []
	var tx := 0
	while tx < r.w:
		if r.grid.tile(tx, 19) == TileGrid.SPIKE_U:
			var t1 := tx
			while r.grid.tile(t1 + 1, 19) == TileGrid.SPIKE_U:
				t1 += 1
			out.append([tx, t1])
			tx = t1 + 1
		else:
			tx += 1
	return out

# a bot that runs east along N05's floor: at the edge of every gap in the ground (a pit of spikes, the S door's hole) it holds [jump] `hold` frames; a gap `dash_w`
# tiles wide or wider also gets a dash `dash_at` frames after take-off; a wall in the way is hopped. Returns {reached, hurt, x, frames, jumps}
func n05_ground(r: Room, px: float, feet: float) -> bool:
	return r.grid.solid_at(px, feet) or r.grid.tile(floori(px / 16.0), floori(feet / 16.0)) == TileGrid.ONEWAY

func n05_run(hold: int, dash_w: int, dash_at: int, lead: float) -> Dictionary:
	Game.flags = {}
	Game.tools = {"bash": true, "catch": false, "sudo": false, "agents": false, "opus": false, "curl": false, "ssh": false}
	var r := new_room("N05")
	for e in r.ents:
		e.queue_free()
	r.ents.clear()
	var p = r.player
	p.x = 24.0
	p.y = 18.0 * 16.0 - 10.0 + 16.0 - 6.0
	p.vx = 0.0
	p.vy = 0.0
	var hp0: int = p.hp
	var f_jump := -1
	var jump_w := 0
	var hurt := false
	var frames := 0
	var reached := false
	var jumps := 0
	var p_hi := -1.0
	for f in range(60 * 60):
		var keys := {"right": true}
		var feet: float = p.y + p.h + 2.0
		if f_jump < 0 and p.on_ground and not n05_ground(r, p.x + p.w + lead, feet):
			f_jump = f
			p_hi = 1.0 if (hold < 40 and p.y + p.h < 18.0 * 16.0 + 6.0) else -1.0           # standing on a block, not on the floor: the web is nearer, hop short
			jumps += 1
			var wt := 0                                         # how wide the gap is
			var gx: float = p.x + p.w + lead
			while wt < 12 and not n05_ground(r, gx + float(wt) * 16.0, feet):
				wt += 1
			jump_w = wt
		if f_jump >= 0:
			var k := f - f_jump
			if k < (hold if p_hi < 0.0 else mini(hold, 6)):
				keys["jump"] = true
			if jump_w >= dash_w and k == dash_at:
				keys["dash"] = true
			if k > 6 and p.on_ground:
				f_jump = -1
		elif p.on_ground and (r.grid.solid_at(p.x + p.w + 3.0, p.y + 5.0) or r.grid.solid_at(p.x + p.w + 3.0, p.y + 1.0)):
			keys["jump"] = true                                 # a low wall in the way: hop it
		step_keys(r, keys)
		if OS.get_environment("HARDDBG2") != "" and hold == 12:
			print("TRACE f %d x %.1f y %.1f vx %.0f vy %.0f hp %d ground %s keys %s" % [f, p.x, p.y, p.vx, p.vy, p.hp, str(p.on_ground), str(keys.keys())])
		if p.hp < hp0:
			hurt = true
			if OS.get_environment("HARDDBG") != "":
				print("HARD hurt at x %.0f y %.0f (hold %d, dash_w %d at %d) vx %.0f vy %.0f" % [p.x, p.y, hold, dash_w, dash_at, p.vx, p.vy])
		frames = f
		if p.x > float(r.w) * 16.0 - 14.0 or r.id != "N05":
			reached = true
			break
		if hurt:
			break
	var out := {"reached": reached, "hurt": hurt, "x": p.x, "frames": frames, "jumps": jumps}
	r.queue_free()
	return out

# MVB3-09: the hard rooms are hard in the way the plan says: the naive way fails, the right way works (N05's pits under the webs)
func t_hardrooms() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.diff = "normal"
	var res := checker()
	var naive := n05_run(40, 99, 0, 0.0)
	if not naive.hurt:
		fail(res, "a full-height jump before every pit was not hurt by a web (reached %s at x %.0f)" % [str(naive.reached), naive.x])
	var info := "naive: hurt %s at x %.0f; " % [str(naive.hurt), naive.x]
	if OS.get_environment("HARDDBG") != "":
		for hold in [12]:
			for lead in [0.0]:
				for dash_w in [4]:
					for dash_at in [4]:
						var rr := n05_run(hold, dash_w, dash_at, lead)
						print("HARD hold %d lead %.0f dash_w %d at %d: reached %s hurt %s x %.0f" % [hold, lead, dash_w, dash_at, str(rr.reached), str(rr.hurt), rr.x])
	var right := n05_run(12, 4, 4, 0.0)
	info += "right way: reached %s, hurt %s, x %.0f" % [str(right.reached), str(right.hurt), right.x]
	if not right.reached or right.hurt:
		fail(res, "12 frames over the 3-wide pits and a dash over the 4-wide ones: reached %s, hurt %s, x %.0f" % [str(right.reached), str(right.hurt), right.x])
	Game.fresh()
	return report("hardrooms", res.ok, info + res.info)
