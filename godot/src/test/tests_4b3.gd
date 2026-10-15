extends Tests4b2
class_name Tests4b3
# Unit tests of phase 4B-3 (THE NETWORK made hard). run_tests.gd hands names it does not know to run().

const NAMES3 := ["kit4b3", "w6enemies2", "w6enemies", "net4b3", "crawler3", "firewall2", "reviewer2b", "bosspresets", "hardrooms", "fightsim"]

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
		"firewall2": return t_firewall2()
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
	if not Game.flag("compacted:CRAWLER"):
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
	print("FIGHTSIM %s %.0f s: attacks %s, hp %.1f/%d, hits taken %d" % [rid, secs, str(counts), b.hpf if b != null else -1.0, b.max_hp if b != null else 0, hits])
	Game.fresh()
	return report("fightsim", true, "")

# MVB3-07: THE FIREWALL v2
func t_firewall2() -> bool:
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
		return report("firewall2", false, res.info)
	if fw.max_hp != 82:
		fail(res, "hp %d, want 82" % fw.max_hp)
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
	# throw -> return: out along the low band (jump it), back along the high band (stay low); the shield is away from the throw's active to the return's end
	fw.face = -1.0
	fw.x = 280.0
	fw.read.last_key = ""
	fw.hpf = float(fw.max_hp)
	var stand := {"x": 100.0, "y": Boss.FLOOR - 10.0, "w": 8.0, "h": 9.0}                 # a standing player
	var jump_ := {"x": 100.0, "y": Boss.FLOOR - 40.0, "w": 8.0, "h": 9.0}                 # one in the air
	r.player.x = 40.0
	r.player.y = 146.0
	fw._start("throw", "p1")
	if absf(float(fw.plan.t) - 0.75) > 0.001:
		fail(res, "throw cue %.2f" % fw.plan.t)
	var out_stand := false
	var out_jump := false
	var back_stand := false
	var back_jump := false
	var dmg_out := 0
	var chained := false
	var pos := Vector2(40.0, 146.0)
	for f in range(600):
		r.player.inv = 99.0
		r.player.x = pos.x
		r.player.y = pos.y
		r.step(Game.STEP)
		fw.idle_t = 999.0
		if fw.plan.is_empty():
			continue
		fw.plan_seen(int(fw.plan.seq))
		if fw.plan_active():
			if OS.get_environment("FWDBG") != "":
				print("fw ", fw.plan.id, " t=", fw.plan.t, " boxes ", fw.harmboxes().map(func(b): return [roundi(b.x), roundi(b.y), roundi(b.w), roundi(b.h)]))
			for hb in fw.harmboxes():
				if String(fw.plan.id) == "throw":
					out_stand = out_stand or Game.overlap(stand, hb)
					out_jump = out_jump or Game.overlap(jump_, hb)
					dmg_out = maxi(dmg_out, int(hb.get("dmg", 1)))
				elif String(fw.plan.id) == "return":
					back_stand = back_stand or Game.overlap(stand, hb)
					back_jump = back_jump or Game.overlap(jump_, hb)
			if fw.shield_on or fw.blocks(1.0, 0.0, "swipe"):
				fail(res, "the shield is on while thrown")
		if String(fw.plan.id) == "return":
			chained = true
		if chained and fw.plan.is_empty():
			break
	if not (out_stand and not out_jump and back_jump and not back_stand) or dmg_out != 2:
		fail(res, "throw/return: out hits stand %s jump %s, back hits stand %s jump %s, throw damage %d" % [str(out_stand), str(out_jump), str(back_stand), str(back_jump), dmg_out])
	if not chained:
		fail(res, "the throw was not followed by a return")
	for f in range(200):
		r.step(Game.STEP)
		fw.idle_t = 999.0
		r.player.inv = 99.0
		if fw.plan.is_empty():
			break
	if not fw.shield_on:
		fail(res, "the shield did not come back after the return")
	# scan: the three lanes burn in order, away from the boss, 0.6 s apart in phase 1 and 0.35 s in phase 2
	for cfg in [[1, 0.6, 330.0], [2, 0.35, 330.0], [2, 0.35, 40.0]]:
		fw.plan = {}
		fw.hpf = float(fw.max_hp) * (1.0 if cfg[0] == 1 else 0.5)
		fw.on_damage()
		fw.x = float(cfg[2]) - fw.w / 2.0
		fw.y = Boss.FLOOR - fw.h
		fw._start("scan", "p1")
		var want: Array = [0, 1, 2] if cfg[2] < 100.0 else [2, 1, 0]
		if fw.scan_order != want or absf(fw.scan_gap - float(cfg[1])) > 0.001:
			fail(res, "scan order %s gap %.2f at boss x %.0f (want %s, %.2f)" % [str(fw.scan_order), fw.scan_gap, cfg[2], str(want), cfg[1]])
		fw.plan.t = 0.001
		fw.plan_step(Game.STEP * 2.0)
		if not fw.plan_active():
			fail(res, "scan did not turn active")
			continue
		var burn_times := {}
		var guard := 0
		while fw.plan_active() and guard < 400:
			var el := fw._scan_elapsed()
			for i in range(3):
				var l: Array = FirewallBoss.LANES[i]
				for hb in fw.harmboxes():
					if hb.x < l[1] and hb.x + hb.w > l[0] and hb.h > 100.0 and not burn_times.has(i):
						burn_times[i] = el
			fw.plan_step(Game.STEP)
			guard += 1
		var order_seen: Array = []
		for i in want:
			order_seen.append(burn_times.get(i, -1.0))
		if burn_times.size() != 3 or not (order_seen[0] < order_seen[1] and order_seen[1] < order_seen[2]) or absf((order_seen[1] - order_seen[0]) - float(cfg[1])) > 0.05:
			fail(res, "scan burn starts %s (want gap %.2f)" % [str(order_seen), cfg[1]])
	fw.plan = {}
	# a caught packet: 2 damage, the shield is off for 2 s
	fw.hpf = float(fw.max_hp)
	fw.on_damage()
	fw.x = 280.0
	fw.face = -1.0
	fw.shield_on = true
	fw.shield_t = 0.0
	fw.turn_t = 0.0
	hp0 = fw.hpf
	fw.hit(2, 1.0, 0.0, "catch", fw)
	if fw.hpf > hp0 - 2.0 + 0.01 or fw.shield_t < 1.99 or fw.blocks(1.0, 0.0, "swipe"):
		fail(res, "caught packet: hp %.1f -> %.1f shield_t %.2f" % [hp0, fw.hpf, fw.shield_t])
	fw.shield_t = 0.0
	# deny: one catchable orb in phase 1, two later
	for ph in [1, 2]:
		fw.plan = {}
		fw.hpf = float(fw.max_hp) * (1.0 if ph == 1 else 0.5)
		fw.on_damage()
		for q in r.projs:
			q.dead = true
		fw._start("deny", "p1")
		fw.plan.t = 0.01
		if not fw_until(r, fw, "deny", "active", Vector2(60.0, 146.0)):
			fail(res, "deny never active")
		var orbs := 0
		for q in r.projs:
			if q.get("catchable", false) and not q.dead:
				orbs += 1
		if orbs != ph:
			fail(res, "deny in phase %d made %d orbs" % [ph, orbs])
	fw.plan = {}
	for q in r.projs:
		q.dead = true
	# phase 2: the deny walls stop at 96 and 288 and push inward; the boxes are the same on a guest
	fw.hz.clear()
	fw.walls_on = false
	for i in range(30):
		r.player.inv = 99.0
		r.step(Game.STEP)
		fw.idle_t = 999.0
	if not fw.walls_on or fw.hz.size() < 2:
		fail(res, "no deny walls in phase 2 (%d hazards)" % fw.hz.size())
	var t_end: float = r.time + 8.5
	var left_front := -1.0
	var right_front := -1.0
	for hb in fw.hz_all_boxes(t_end):
		if hb.x + hb.w <= 200.0:
			left_front = hb.x + hb.w
		else:
			right_front = hb.x
	if absf(left_front - 96.0) > 0.5 or absf(right_front - 288.0) > 0.5:
		fail(res, "the deny walls end at %.1f and %.1f" % [left_front, right_front])
	r.player.inv = 0.0
	r.player.hp = r.player.max_hp
	r.player.x = 100.0
	r.player.y = 150.0
	r.player.hurt(1, 88.0)                                # the left wall's middle is at x 88: the player on its inner side is pushed inward
	if r.player.vx <= 0.0:
		fail(res, "the wall pushes the wrong way (vx %.0f)" % r.player.vx)
	r.player.inv = 99.0
	# DROP ALL: the port is announced 0.9 s before, everything but the port burns for 0.4 s
	fw.hpf = float(fw.max_hp) * 0.2
	fw.on_damage()
	fw.hz = fw.hz.filter(func(h): return h.k == "deny")
	var tn := r.time
	if OS.get_environment("FWDBG") != "":
		print("DROPDBG phase ", fw._phase_now(), " walls ", fw.walls_on, " active ", fw.active, " dying ", fw.dying, " hpf ", fw.hpf)
	fw.drop_cd = 0.0
	fw.plan = {}
	fw.idle_t = 999.0
	var drop: Dictionary = {}
	for f in range(30):
		r.step(Game.STEP)
		fw.idle_t = 999.0
		for h in fw.hz:
			if h.k == "drop":
				drop = h
		if not drop.is_empty():
			break
	if drop.is_empty() or absf(float(drop.warn) - 0.9) > 0.001:
		fail(res, "no DROP ALL announced (%s)" % str(drop))
	else:
		var tt: float = float(drop.t0)
		if not fw.hz_all_boxes(tt + 0.89).filter(func(b): return b.y > Boss.FLOOR - 8.0).is_empty():
			fail(res, "DROP ALL burns before the 0.9 s are over")
		var bn := fw.bounds(tt + 1.0)
		var px: float = FirewallBoss.PORT_X[int(drop.v[0])]
		var covered := 0.0
		var port_hit := false
		for b in fw.hz_all_boxes(tt + 1.0):
			if b.y > Boss.FLOOR - 8.0:
				covered += b.w
				if b.x < px + 32.0 and b.x + b.w > px - 32.0:
					port_hit = true
		if port_hit or absf(covered - ((bn.y - bn.x) - 64.0)) > 1.0:
			fail(res, "DROP ALL covers %.0f px (want %.0f), port hit %s" % [covered, (bn.y - bn.x) - 64.0, str(port_hit)])
		if not fw.hz_all_boxes(tt + 1.5).filter(func(b): return b.y > Boss.FLOOR - 8.0).is_empty():
			fail(res, "DROP ALL still burns after 0.4 s")
	# phase 3: the shield turns on its own every 1.5 s
	fw.plan = {}
	fw.shield_on = true
	fw.face = -1.0
	fw.auto_t = 1.5
	fw.hz = fw.hz.filter(func(h): return h.k == "deny")
	var turns := 0
	var last_face: float = fw.face
	for f in range(int(5.0 / Game.STEP)):
		r.player.inv = 99.0
		fw.drop_cd = 99.0
		fw.idle_t = 999.0
		fw.plan = {}
		r.step(Game.STEP)
		if fw.face != last_face:
			turns += 1
			last_face = fw.face
	if turns != 3:
		fail(res, "the shield turned %d times in 5 s" % turns)
	fw.plan = {}
	# rule: a 16x32 block slides at 200 px/s from the boss's side; two of them, 0.5 s apart, in phase 2+
	fw.hz.clear()
	fw.walls_on = true
	fw.x = 300.0
	fw.hpf = float(fw.max_hp) * 0.5
	fw.on_damage()
	fw._start("rule", "p1")
	var blocks: Array = fw.hz.filter(func(h): return h.k == "block")
	if blocks.size() != 2 or absf((float(blocks[1].warn) - float(blocks[0].warn)) - 0.5) > 0.001 or float(blocks[0].warn) < 0.69:
		fail(res, "rule made %d blocks" % blocks.size())
	else:
		var tb: float = float(blocks[0].t0) + float(blocks[0].warn)
		var b0: float = fw.block_x(blocks[0], tb + 0.5)
		var b1: float = fw.block_x(blocks[0], tb + 1.5)
		if absf(absf(b1 - b0) - 200.0) > 1.0 or fw.hz_all_boxes(tb - 0.01).size() != 0:
			fail(res, "block speed %.1f" % absf(b1 - b0))
		var bx: Array = fw.hz_boxes(blocks[0], tb + 0.5)
		if bx.size() != 1 or bx[0].w != 16.0 or bx[0].h != 32.0:
			fail(res, "block box %s" % str(bx))
	fw.hz.clear()
	fw.plan = {}
	# phase (P2): the boss ends up on the other side of a membrane, with a 2 damage slash at the exit
	fw.x = 180.0
	fw.y = Boss.FLOOR - fw.h
	fw.face = 1.0
	var side0 := fw.cx
	fw._start("phase", "p1")
	if absf(float(fw.plan.t) - 0.75) > 0.001:
		fail(res, "phase cue %.2f" % fw.plan.t)
	if not fw_until(r, fw, "phase", "active", Vector2(300.0, 146.0), 900):
		fail(res, "phase never active")
	var mid_boxes: Array = fw.harmboxes().filter(func(b): return b.has("sid"))
	if not fw_until(r, fw, "phase", "recover", Vector2(300.0, 146.0), 200):
		fail(res, "phase never recovered")
	var crossed: bool = (side0 < 112.0 and fw.cx > 128.0) or (side0 > 128.0 and side0 < 256.0 and (fw.cx > 272.0 or fw.cx < 112.0)) or (side0 > 272.0 and fw.cx < 256.0)
	if not crossed or mid_boxes.size() != 1 or int(mid_boxes[0].dmg) != 2:
		fail(res, "phase: cx %.0f -> %.0f, %d slash boxes" % [side0, fw.cx, mid_boxes.size()])
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
	return report("firewall2", res.ok, res.info)

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
	for diff in ["easy", "normal", "hard", "nightmare"]:
		Game.diff = diff
		var tm := float(Game.dv("telegraph_mult"))
		var pm := float(Game.dv("punish_mult"))
		var big := int(Game.dv("big_hit"))
		# [room, id, expected cue, expected rec (or -1: not checked, or the family's: negative family rec)]
		var table: Array = [
			["N09", "results", 0.6, 0.5], ["N09", "drop", 0.7, 1.5], ["N09", "leap", 0.7, 1.5], ["N09", "flash", 0.5, 0.1], ["N09", "dive", 0.7, 1.0], ["N09", "feint", 0.7, 0.35],
			["N15", "throw", 0.75, 0.1], ["N15", "return", 0.25, 0.7], ["N15", "rule", 0.7, 0.6], ["N15", "scan", 0.6, 0.6], ["N15", "deny", 0.6, 0.7], ["N15", "phase", 0.75, 0.7], ["N15", "bash", 0.45, 0.6],
			["N22", "cached", 1.0, -0.4], ["N22", "double", 0.75, 0.6], ["N22", "verdict", 0.6, 0.6], ["N22", "nitpick", 0.7, 0.6], ["N22", "cross", 0.9, 0.6], ["N22", "signoff", 0.75, 0.2], ["N22", "slash", 0.45, 0.2], ["N22", "sdiamond", 0.45, 0.7], ["N22", "riposte", 0.75, -0.9]]
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
	if tested < 84:
		fail(res, "only %d attacks tested" % tested)
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
