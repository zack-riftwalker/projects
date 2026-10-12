extends Tests4b2
class_name Tests4b3
# Unit tests of phase 4B-3 (THE NETWORK made hard). run_tests.gd hands names it does not know to run().

const NAMES3 := ["kit4b3"]

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
