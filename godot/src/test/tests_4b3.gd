extends Tests4b2
class_name Tests4b3
# Unit tests of phase 4B-3 (THE NETWORK made hard). run_tests.gd hands names it does not know to run().

const NAMES3 := ["kit4b3", "w6enemies2", "w6enemies"]

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
