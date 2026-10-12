class_name CrawlerBoss
extends Boss
# WEB CRAWLER v2 (MVB3-06): a spider on a ceiling graph of four nodes that fills the arena with web. Its core hangs on a thread under a node, out of
# reach, and only comes down in the recovery of a fetch, a back or a skitter, or when a yellow packet is caught back into it.
# The environment is the web (an arena hazard, see Boss.hz_*): every `spin` pulls a strand from where the crawler hangs to a knot of the room; strands
# stay, hurt (1) once their dotted warning is over, and at most four exist. Hit a knot with a claw, or catch a packet back across a strand, and it snaps.
# Phase 3 is the deep crawl: all strands are cut, the nodes go dark, the crawler swings from the middle of the ceiling like a pendulum
# (the swing is a pure function of the room clock, so the guest computes the same one).
# A kit boss: every attack is announced (cue), harm exists only in an active phase, an arena hazard or the deep crawl's body, and comes from the plan and
# the net fields; the guest builds the same boxes. Rule 8: after each attack it walks to the node above whoever stood under the core longest.

const IDS := ["fetch", "spin", "volley", "skitter", "back"]
const NODES := [Vector2(56, 40), Vector2(144, 32), Vector2(240, 32), Vector2(328, 40)]
# the knots of the web: ceiling x3, walls x4, floor x4. (The plan puts the ceiling knots at y 0 and the wall knots at x 0 and 384: those points are inside the
# wall tiles, where nobody can reach them, so the ceiling knots hang at y 32 and the wall knots stand at x 16 and 368.)
const KNOTS := [Vector2(96, 32), Vector2(192, 32), Vector2(288, 32), Vector2(16, 64), Vector2(16, 128), Vector2(368, 64), Vector2(368, 128),
				Vector2(48, 176), Vector2(144, 176), Vector2(240, 176), Vector2(336, 176)]
const THREAD := 18.0
const LEG_W := 12.0
const MAX_STRANDS := 4
const PEND_A := Vector2(192, 0)
const PEND_LEN := 120.0
const PEND_T := 3.2
const PEND_AMP := 0.9
const SK_SPEED := 300.0
const BRASS := "#5ad1ff"
const INK := "#1b1226"
const P1_SEQ := ["fetch", "spin", "volley", "fetch"]
const P2_SEQ := ["fetch", "skitter", "spin", "volley"]

var node := 1
var prev_node := 0
var core_px := 144.0              # the core's x (it follows its node)
var core_y := 50.0                # the core's centre y
var down := false                 # the core is coming down (or is down) because of a recovery
var down_t := 0.0                 # caught packet: down for this long
var leg_x := 0.0                  # the x of the leg / the middle of `back`
var leg_top := 16.0               # a leg comes down from here
var leg_on := 0                   # a leg is in the floor (the last of a fetch stays: pogo it)
var leg_i := 0                    # which leg of the fetch (0 = the first, the 2-damage one)
var leg_n := 1                    # how many legs this fetch has
var move_to := 1
var cycle := 0
var idle_t := 0.0
var volley_n := 0
var volley_t := 0.0
var volley_cnt := 3
var strike_sid := 0
var sk_state := 0                 # skitter: 0 none, 1 landing, 2 running, 3 climbing, 4 still on the wall, 5 going back up
var sk_x := 0.0                   # where it lands
var sk_dir := 1.0                 # the way it runs
var sk_t := 0.0
var dc := 0                       # 1: the deep crawl (phase 3) is on
var sw_t0 := 0.0                  # the room time the swing began (angle 0)
var sw_x0 := 0.0                  # where the core was when the swing began (it eases to the pendulum for a second)
var sw_y0 := 0.0
var dc_fetch_cd := 0.0
var dc_volley_cd := 1.5
var dc_swing := 0                 # half swings seen (a spin every second swing)
var dc_end := false               # the last frame was inside a swing's end
var dc_toggle := false
var ghosts: Array = []            # cut strands fading (0.3 s): {a, b, t}; each page's own picture
var scr_spawned := 0              # the phases whose scrapers are out

func _init(r: Room, bx: float, by: float, base_hp := 82) -> void:
	super(r, bx, by, 24, 16, base_hp)
	boss_name = "WEB CRAWLER"
	sub = "it follows every link"
	col = BRASS
	kit_init()
	node = 1
	core_px = NODES[1].x
	core_y = NODES[1].y + THREAD
	_place()

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["strand"]

func _big() -> int:
	return int(Game.dv("big_hit"))

func _place() -> void:
	x = core_px - w / 2.0
	y = core_y - h / 2.0

func _rest_y() -> float:
	return float(NODES[node].y) + THREAD

# ---- the web: strands are hazards {k "strand", v [knot, start x, start y]} ----
func knot_box(i: int) -> Dictionary:
	var p: Vector2 = KNOTS[i]
	return {"x": p.x - 6.0, "y": p.y - 6.0, "w": 12.0, "h": 12.0}

func strand_a(h: Dictionary) -> Vector2:
	return Vector2(float(h.v[1]), float(h.v[2]))

func strand_b(h: Dictionary) -> Vector2:
	return KNOTS[clampi(int(h.v[0]), 0, KNOTS.size() - 1)]

# 8x8 boxes every 8 px along the strand (1 damage)
func hz_boxes(h: Dictionary, _now: float) -> Array:
	var a := strand_a(h)
	var b := strand_b(h)
	var n := maxi(1, ceili(a.distance_to(b) / 8.0))
	var out: Array = []
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / float(n))
		out.append({"x": p.x - 4.0, "y": p.y - 4.0, "w": 8.0, "h": 8.0, "dmg": 1})
	return out

func strand_at_knot(i: int) -> bool:
	for h in hz:
		if int(h.v[0]) == i:
			return true
	return false

func _snap(h: Dictionary) -> void:
	ghosts.append({"a": strand_a(h), "b": strand_b(h), "t": 0.3})
	hz.erase(h)
	var b := strand_b(h)
	room.burst(b.x, b.y, 6, ["#d6f6ff", BRASS], 90.0, 100.0)
	Audio.sfx("tick", {"vol": 0.6})

func cut_knot(i: int) -> bool:
	var cut := false
	for h in hz.duplicate():
		if int(h.v[0]) == i:
			_snap(h)
			cut = true
	return cut

func cut_all() -> void:
	for h in hz.duplicate():
		_snap(h)

# a packet caught back across a strand cuts it
func _cut_by_packets() -> void:
	for q in room.projs:
		if q.dead or not q.get("friendly", false):
			continue
		for h in hz.duplicate():
			if _dist_seg(Vector2(q.x, q.y), strand_a(h), strand_b(h)) <= 8.0:
				_snap(h)

static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.01:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# the strand a `spin` pulls: from where the crawler hangs to the knot nearest the target on the far side of it from the boss (a free knot)
func _spin_knot(ap: Vector2, from: Vector2) -> int:
	var best := -1
	var bd := 1e9
	for pass_n in range(2):
		for i in range(KNOTS.size()):
			if strand_at_knot(i):
				continue
			var k: Vector2 = KNOTS[i]
			if pass_n == 0 and (k.x - ap.x) * (ap.x - from.x) <= 0.0:
				continue
			var d := k.distance_to(ap)
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			break
	return best

func _add_strand(knot: int, from: Vector2, warn: float) -> void:
	if knot < 0:
		return
	if hz.size() >= MAX_STRANDS:
		_snap(hz[0])                                    # a fifth strand cuts the oldest
	hz_add("strand", warn, [knot, roundi(from.x), roundi(from.y)])

# ---- the body ----
func _core_box() -> Dictionary:
	return {"x": core_px - 12.0, "y": core_y - 8.0, "w": 24.0, "h": 16.0}

func _body_box() -> Dictionary:
	return {"x": core_px - 16.0, "y": core_y - 9.0, "w": 32.0, "h": 18.0}

func hurtboxes() -> Array:
	var b: Array = []
	if sk_state >= 2 and sk_state <= 4:
		b.append(_body_box())                            # running, climbing, still: the body itself (pogo off it)
	else:
		b.append(_core_box())
	if leg_on == 1 and plan_phase() == "recover" and String(plan.get("id", "")) == "fetch":      # the planted leg's lower 48 px hurt it too
		b.append({"x": leg_x - LEG_W / 2.0, "y": Boss.FLOOR - 48.0, "w": LEG_W, "h": 48.0})
	for h in hz:                                         # a knot with a strand on it can be cut with the claw
		var kb := knot_box(int(h.v[0]))
		kb["knot"] = int(h.v[0])
		b.append(kb)
	return b

# only the plan hurts and only while it is active; the web hurts through its hazards; the deep crawl's body and the running skitter hurt by touch
func harmboxes() -> Array:
	var b: Array = []
	if plan_active():
		match String(plan.id):
			"fetch":
				b.append({"x": leg_x - LEG_W / 2.0, "y": leg_top, "w": LEG_W, "h": Boss.FLOOR - leg_top, "sid": strike_sid, "catchable": false, "dmg": _big() if leg_i == 0 else 1})
			"skitter":
				if sk_state == 1:
					b.append({"x": core_px - 16.0, "y": Boss.FLOOR - 24.0, "w": 32.0, "h": 24.0, "dmg": _big()})
			"back":
				b.append({"x": leg_x - 52.0, "y": 0.0, "w": 24.0, "h": Boss.FLOOR, "dmg": _big()})
				b.append({"x": leg_x + 28.0, "y": 0.0, "w": 24.0, "h": Boss.FLOOR, "dmg": _big()})
	if sk_state == 2:
		b.append({"x": core_px - 16.0, "y": Boss.FLOOR - 18.0, "w": 32.0, "h": 18.0, "dmg": 1})
	if dc == 1 and active and not dying:
		b.append(_core_box_dmg())
	b.append_array(hz_harm())
	return b

func _core_box_dmg() -> Dictionary:
	var c := _core_box()
	c["dmg"] = 1
	return c

func _phase_now() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.30 else (2 if f <= 0.65 else 1)

func on_damage() -> void:
	var p := _phase_now()
	if p != phase:
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if b is Dictionary and b.has("knot"):                 # a claw (or a dash) on a knot: the strand snaps, the boss takes nothing
		if active and not dying and cut_knot(int(b.knot)):
			return "hit"
		return ""
	if active and not dying and how == "catch":
		down_t = 1.6                                      # a packet caught back into the core: the core comes down
		room.burst(core_px, core_y - 10.0, 8, [BRASS, "#d6f6ff"], 90.0, 100.0)
		Audio.sfx("clang")
	return super.hit(d, dx, dy, how, b)

func start() -> void:
	super.start()
	idle_t = 1.0

func _scrapers(n_pair: int) -> void:
	# two scrapers drop from ceiling knots (no hook: they hang on a thread from the knot)
	var picks := [0, 2] if n_pair % 2 == 0 else [1, 2]
	for ki in picks:
		var k: Vector2 = KNOTS[ki]
		var sc := Scraper.new(room, k.x - 8.0, k.y - 8.0)
		room.add_entity(sc)
	room.pop(192.0, 60.0, "scrapers", "#c3bccd", true)

func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	for g in ghosts:
		g.t -= dt
	ghosts = ghosts.filter(func(g): return g.t > 0.0)
	if dying:
		down = true
		sk_state = 0
		dc = 0
		hz.clear()
		death_rattle(dt, 2.4, ["#ffffff", "#d6f6ff", BRASS, "#2a6fa8"])
		_ease(dt)
		_place()
		return
	if not active:
		_place()
		return
	_ease(dt)
	if scr_spawned < _phase_now() - 1:
		scr_spawned += 1
		if scr_spawned == 2:
			cut_all()                                     # the deep crawl: every strand snaps and the nodes go dark
			dc = 1
			sw_t0 = snappedf(room.time, 0.01)
			sw_x0 = core_px
			sw_y0 = core_y
			down = false
			dc_fetch_cd = 1.5
			dc_volley_cd = 2.0
			dc_swing = 0
		_scrapers(scr_spawned)
	if down_t > 0.0:
		down_t -= dt
	_cut_by_packets()
	if plan.is_empty():
		idle_t -= dt
		plan_clock += dt
		if dc == 1:
			dc_fetch_cd -= dt
			dc_volley_cd -= dt
		if idle_t <= 0.0:
			_choose()
	else:
		_plan_logic(dt)
	if dc == 1:
		_dc_follow()
	_place()

# ---- the swing (a pure function of the room clock and the fields) ----
func pend_angle(now: float) -> float:
	return PEND_AMP * sin(TAU * (now - sw_t0) / PEND_T)

func pend_pos(now: float) -> Vector2:
	var a := pend_angle(now)
	return PEND_A + Vector2(sin(a), cos(a)) * PEND_LEN

func dc_pos(now: float) -> Vector2:
	var k := clampf((now - sw_t0) / 1.0, 0.0, 1.0)
	return Vector2(sw_x0, sw_y0).lerp(pend_pos(now), k * k * (3.0 - 2.0 * k))

func _dc_follow() -> void:
	var p := dc_pos(room.time)
	core_px = p.x
	core_y = p.y

func _ease(dt: float) -> void:
	if dc == 1 and not dying:
		return
	if sk_state != 0 and not dying:
		return
	var want_y := float(Boss.FLOOR - 70.0) if (down or down_t > 0.0 or dying) else _rest_y()
	core_y = move_toward(core_y, want_y, 160.0 * dt)
	core_px = move_toward(core_px, float(NODES[node].x), 220.0 * dt)

# rule 8: the node above whoever stood under the core longest in the last second; nobody: the next one in order
func _pick_node() -> int:
	var best_key := ""
	var best_n := 0
	if read != null:
		for k in kit_keys():
			var n_u := 0
			for s in read.samples[k]:
				if s.u:
					n_u += 1
			if n_u > best_n:
				best_n = n_u
				best_key = k
	if best_key != "":
		var q = kit_body(best_key)
		var bi := 0
		var bd := 1e9
		for i in range(NODES.size()):
			var dd := absf(float(NODES[i].x) - (q.x + q.w / 2.0))
			if dd < bd:
				bd = dd
				bi = i
		if bi != node:
			return bi
	return (node + 1) % NODES.size()

func _choose() -> void:
	if kit_keys().is_empty():
		idle_t = 0.3
		return
	if dc == 1:
		_choose_dc()
		return
	var seq: Array = P2_SEQ if _phase_now() == 2 else P1_SEQ
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	_start(id)

# the deep crawl: fetch / back at a swing's end, a volley every 2.4 s, a spin every second swing
func _choose_dc() -> void:
	var s := absf(sin(TAU * (room.time - sw_t0) / PEND_T))
	var at_end := s > 0.95 and room.time - sw_t0 > 1.2
	if at_end and not dc_end:
		dc_swing += 1
	dc_end = at_end
	idle_t = 0.05
	if at_end and dc_fetch_cd <= 0.0:
		dc_fetch_cd = PEND_T
		dc_toggle = not dc_toggle
		_start("fetch" if dc_toggle else "back")
	elif dc_volley_cd <= 0.0:
		dc_volley_cd = 2.4
		_start("volley")
	elif dc_swing >= 2 and s < 0.5:
		dc_swing = 0
		_start("spin")

func _start(id: String) -> void:
	down = false
	var tgt := kit_pick_target()
	var ap := kit_aim(tgt)
	match id:
		"fetch":
			leg_n = clampi(_phase_now(), 1, 3)
			leg_i = 0
			_start_leg(tgt)
		"spin":
			var from := _hang_point()
			var knot := _spin_knot(ap, from)
			plan_start("spin", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.9, 0.55)
			_add_strand(knot, from, float(plan.t))
		"volley":
			volley_cnt = clampi(_phase_now() + 2, 3, 5)
			plan_start("volley", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, 0.6)
		"skitter":
			sk_x = clampf(ap.x, 40.0, 344.0)
			sk_dir = 1.0 if sk_x < 192.0 else -1.0
			var run_t := absf((352.0 if sk_dir > 0.0 else 32.0) - sk_x) / SK_SPEED
			plan_start("skitter", "slam", tgt, [sk_x - 16.0, Boss.FLOOR - 24.0, 32.0, 24.0], 0.3, 0.7, run_t + 1.4)
		"back":
			leg_x = clampf(ap.x, 64.0, 320.0) if dc == 1 else float(NODES[prev_node].x)
			plan_start("back", "dual", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.8, 0.8)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

# where a strand starts: the node the crawler hangs under, or the swing point in the deep crawl
func _hang_point() -> Vector2:
	if dc == 1:
		return Vector2(core_px, core_y)
	return Vector2(NODES[node])

func _start_leg(tgt: String) -> void:
	var ap := kit_aim(tgt)
	leg_x = clampf(ap.x, 16.0, Game.W - 16.0)
	leg_top = 16.0 if dc == 1 else maxf(16.0, core_y - 8.0)
	var last := leg_i >= leg_n - 1
	plan_start("fetch", "slam", tgt, [leg_x - 16.0, leg_top, 32.0, Boss.FLOOR - leg_top], 0.45, 0.75 if leg_i == 0 else 0.45, 0.8 if last else 0.1)

func _plan_logic(dt: float) -> void:
	var pid := String(plan.id)
	# the aim follows the target through the cue; the last `lock` seconds it is fixed
	if plan.ph == "cue" and plan.t > float(plan.lock):
		var ap := kit_aim(plan.tgt)
		if pid == "fetch":
			leg_x = clampf(ap.x, 16.0, Game.W - 16.0)
			plan.fp = [leg_x - 16.0, leg_top, 32.0, Boss.FLOOR - leg_top]
		elif pid == "skitter":
			sk_x = clampf(ap.x, 40.0, 344.0)
			sk_dir = 1.0 if sk_x < 192.0 else -1.0
			plan.fp = [sk_x - 16.0, Boss.FLOOR - 24.0, 32.0, 24.0]
			plan["rec"] = absf((352.0 if sk_dir > 0.0 else 32.0) - sk_x) / SK_SPEED + 1.4
		elif pid == "back" and dc == 1:
			leg_x = clampf(ap.x, 64.0, 320.0)
	if pid == "volley" and plan.ph == "active":
		volley_t -= dt
		if volley_t <= 0.0 and volley_n < 1:
			volley_n += 1
			_shoot_fan()
	if pid == "skitter":
		_skitter_step(dt)
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"fetch":
					leg_on = 1
					strike_sid = Game.next_strike_id()
					room.shake(0.4)
					Audio.sfx("thud")
				"volley":
					volley_n = 0
					volley_t = 0.0
				"spin":
					room.shake(0.2)
					Audio.sfx("laser", {"vol": 0.5})
				"skitter":
					sk_state = 1
					sk_t = 0.0
					core_px = sk_x
					core_y = Boss.FLOOR - 9.0
					room.shake(0.5)
					room.burst(sk_x, Boss.FLOOR - 4.0, 10, [BRASS, "#ffffff"], 120.0, 300.0)
					Audio.sfx("thud")
				"back":
					if dc == 0:
						prev_node = node
						core_px = float(NODES[prev_node].x)
					room.shake(0.5)
					Audio.sfx("thud")
		"recover":
			strike_sid = 0
			match pid:
				"fetch":
					if leg_i >= leg_n - 1:
						down = true                              # the last leg stays planted and the core comes down: pogo it
					else:
						leg_on = 0
				"back":
					down = true
				"skitter":
					sk_state = 2
					sk_t = 0.0
	if ev == "done":
		strike_sid = 0
		if pid == "fetch" and leg_i < leg_n - 1:
			leg_i += 1
			leg_on = 0
			_start_leg(String(plan.tgt) if not plan.is_empty() else kit_pick_target())
			return
		leg_on = 0
		if sk_state != 0:
			sk_state = 0
			var nn := _nearest_node(core_px)
			prev_node = node
			node = nn
		_end_attack()

func _nearest_node(px: float) -> int:
	var bi := 0
	var bd := 1e9
	for i in range(NODES.size()):
		var dd := absf(float(NODES[i].x) - px)
		if dd < bd:
			bd = dd
			bi = i
	return bi

# after an attack: it walks (<= 0.6 s, harmless) to the node above whoever stood under it, then the next attack
func _end_attack() -> void:
	down = false
	if dc == 1:
		idle_t = 0.2
		return
	var to := _pick_node()
	var dist := absf(float(NODES[to].x) - core_px)
	prev_node = node
	node = to
	idle_t = clampf(dist / 220.0, 0.15, 0.6)

func _skitter_step(dt: float) -> void:
	match sk_state:
		1:
			core_y = Boss.FLOOR - 9.0
		2:
			var wall_x := 352.0 if sk_dir > 0.0 else 32.0
			core_px = move_toward(core_px, wall_x, SK_SPEED * dt)
			if absf(core_px - wall_x) < 0.5:
				sk_state = 3
		3:
			core_y = move_toward(core_y, 64.0, 220.0 * dt)
			if absf(core_y - 64.0) < 0.5:
				sk_state = 4
				sk_t = 0.6
		4:
			sk_t -= dt
			if sk_t <= 0.0:
				sk_state = 5
		5:
			var nn := _nearest_node(core_px)
			core_px = move_toward(core_px, float(NODES[nn].x), 260.0 * dt)
			core_y = move_toward(core_y, float(NODES[nn].y) + THREAD, 260.0 * dt)
			if absf(core_px - float(NODES[nn].x)) < 0.5 and absf(core_y - (float(NODES[nn].y) + THREAD)) < 0.5:
				sk_state = 0
				prev_node = node
				node = nn
	if sk_state == 1 and plan.ph == "recover":
		sk_state = 2

# a fan of yellow packets at the target (P1 3, P2 4, P3 5): catch one back and it hits the core for 2
func _shoot_fan() -> void:
	var ap := kit_aim(plan.tgt)
	var ox := core_px
	var oy := core_y + 8.0
	var dist := Vector2(ap.x - ox, ap.y - oy).length()
	if dist < 60.0:
		dist = 60.0
	var a0 := atan2(ap.y - oy, ap.x - ox)
	var speed := clampf(dist / 0.7, 80.0, 190.0)
	for i in range(volley_cnt):
		var a := a0 + (float(i) - float(volley_cnt - 1) / 2.0) * 0.17
		room.shoot(ox, oy, cos(a) * speed, sin(a) * speed, {"kind": "diamond", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1, "by_boss": true})
	Audio.sfx("shoot")

# ---- drawing ----
func _hatch(ci: CanvasItem, r: Rect2) -> void:
	var hot := int(t * 12.0) % 2 == 0
	var c1 := Color(Game.COL.hazardHi) if hot else Color(Game.COL.hazard)
	var c2 := Color(Game.COL.hazard)
	ci.draw_rect(r, Color(c2.r, c2.g, c2.b, 0.18))
	var yy := 0.0
	while yy < r.size.y:
		ci.draw_rect(Rect2(r.position.x, r.position.y + yy, r.size.x, 1), Color(c1.r, c1.g, c1.b, 0.7))
		yy += 4.0
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), c1)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c1)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), c1)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c1)

func _draw_strand(ci: CanvasItem, h: Dictionary) -> void:
	var a := strand_a(h)
	var b := strand_b(h)
	var live := hz_live(h, room.time)
	if live:
		ci.draw_line(a, b, Color(Game.COL.ink), 3.0)
		ci.draw_line(a, b, Color("#d6f6ff"), 1.0)
		var n := maxi(1, ceili(a.distance_to(b) / 16.0))
		for i in range(n + 1):                                   # beads: the strand is a row of hurt
			var p := a.lerp(b, float(i) / float(n))
			ci.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Color(Game.COL.hazardHi) if int(t * 10.0) % 2 == 0 else Color("#ffffff"))
	else:
		var n2 := maxi(1, ceili(a.distance_to(b) / 6.0))      # the warning: a dotted line that fills in
		var left := clampf((float(h.t0) + float(h.warn) - room.time) / maxf(0.01, float(h.warn)), 0.0, 1.0)
		for i in range(n2 + 1):
			if i % 2 == 0 and float(i) / float(n2) <= 1.0 - left * 0.0:
				var p2 := a.lerp(b, float(i) / float(n2))
				ci.draw_rect(Rect2(p2.x, p2.y, 1, 1), Color(Game.COL.hazardHi) if int(t * 12.0) % 2 == 0 else Color(Game.COL.hazard))
	var kb := knot_box(int(h.v[0]))
	var kc := Color("#ffd23f") if live else Color(Game.COL.hazard)
	ci.draw_rect(Rect2(kb.x, kb.y, kb.w, 1), kc)
	ci.draw_rect(Rect2(kb.x, kb.y + kb.h - 1, kb.w, 1), kc)
	ci.draw_rect(Rect2(kb.x, kb.y, 1, kb.h), kc)
	ci.draw_rect(Rect2(kb.x + kb.w - 1, kb.y, 1, kb.h), kc)

func draw_boss_body(ci: CanvasItem) -> void:
	var ink := Color(INK)
	var br := Color(BRASS)
	# the knots (rings in the walls) and the nodes (rings joined by lines); dark in the deep crawl
	for i in range(KNOTS.size()):
		var kp: Vector2 = KNOTS[i]
		ci.draw_arc(kp, 3.0, 0.0, TAU, 8, Color(br.r, br.g, br.b, 0.35), 1.0)
	if dc == 0:
		for i in range(NODES.size() - 1):
			ci.draw_line(NODES[i], NODES[i + 1], Color(br.r, br.g, br.b, 0.5), 1.0)
		for i in range(NODES.size()):
			ci.draw_arc(NODES[i], 6.0, 0.0, TAU, 14, ink, 3.0)
			ci.draw_arc(NODES[i], 6.0, 0.0, TAU, 14, br if not dying else Color("#3a4a5a"), 1.0)
	else:
		for i in range(NODES.size()):
			ci.draw_arc(NODES[i], 6.0, 0.0, TAU, 14, Color("#2a3040"), 1.0)
	for h in hz:
		_draw_strand(ci, h)
	for g in ghosts:
		ci.draw_line(g.a, g.b, Color(0.84, 0.96, 1.0, clampf(g.t / 0.3, 0.0, 1.0) * 0.6), 1.0)
	if plan_phase() == "cue" and not plan.is_empty() and dc == 0:
		if plan.id == "back":
			var bp: Vector2 = NODES[prev_node]
			PixelText.draw_text(ci, "BACK", bp.x, bp.y - 16.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
			ci.draw_arc(bp, 9.0 + sin(t * 14.0) * 2.0, 0.0, TAU, 14, Color("#ffd23f"), 1.0)
	# the thread and the core
	var cxp := floorf(core_px)
	var cyp := floorf(core_y)
	if dc == 1:
		var pa := Vector2(PEND_A.x, 16.0)
		ci.draw_line(pa, Vector2(cxp, cyp - 8.0), Color("#c3bccd"), 1.0)
	elif sk_state == 0 or sk_state == 5:
		ci.draw_line(Vector2(core_px, float(NODES[node].y)), Vector2(core_px, core_y - 8.0), Color("#c3bccd"), 1.0)
	# eight legs: two segments each, up to the ceiling; a planted leg is a column to the floor
	var low := sk_state >= 1 and sk_state <= 4
	for i in range(8):
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := float(i / 2)
		var knee := Vector2(cxp + side * (14.0 + k * 9.0), cyp - 10.0 - k * 3.0 + sin(t * 3.0 + float(i)) * 1.5)
		var foot := Vector2(cxp + side * (24.0 + k * 16.0), maxf(6.0, cyp - 34.0 - k * 6.0) if not low else cyp + 6.0)
		if sk_state == 2:
			knee.y = cyp - 4.0 - k * 2.0 + sin(t * 40.0 + float(i)) * 2.0
		ci.draw_line(Vector2(cxp + side * 6.0, cyp - 4.0), knee, ink, 3.0)
		ci.draw_line(knee, foot, ink, 3.0)
		ci.draw_line(Vector2(cxp + side * 6.0, cyp - 4.0), knee, Color("#2a6fa8"), 1.0)
		ci.draw_line(knee, foot, Color("#2a6fa8"), 1.0)
	if leg_on == 1:
		var top := leg_top if plan.get("id", "") == "fetch" else cyp
		ci.draw_rect(Rect2(leg_x - LEG_W / 2.0 - 1.0, top, LEG_W + 2.0, Boss.FLOOR - top), ink)
		ci.draw_rect(Rect2(leg_x - LEG_W / 2.0 + 1.0, top, LEG_W - 2.0, Boss.FLOOR - top), Color("#2a6fa8"))
		ci.draw_rect(Rect2(leg_x - 3.0, top, 2, Boss.FLOOR - top), Color("#5ad1ff"))
	ci.draw_rect(Rect2(cxp - 13.0, cyp - 9.0, 26, 18), ink)
	ci.draw_rect(Rect2(cxp - 12.0, cyp - 8.0, 24, 16), Color("#24306a"))
	ci.draw_rect(Rect2(cxp - 12.0, cyp - 8.0, 24, 3), Color("#3a4a9a"))
	ci.draw_rect(Rect2(cxp - 7.0, cyp - 3.0, 4, 3), Color(Game.COL.hazard))
	ci.draw_rect(Rect2(cxp + 3.0, cyp - 3.0, 4, 3), Color(Game.COL.hazard))
	ci.draw_rect(Rect2(cxp - 5.0, cyp + 3.0, 10, 2), ink)
	if plan_active() and plan.id == "back":
		for hb in harmboxes():
			if hb.h > 100.0:
				ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(0.45, 0.8, 1.0, 0.7))
	if sk_state == 1 or sk_state == 2:
		for hb in harmboxes():
			if hb.y > Boss.FLOOR - 30.0:
				ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.35))

func draw_boss_overlay(ci: CanvasItem) -> void:
	draw_plan(ci)
	if plan.is_empty() or plan.ph != "cue":
		return
	if plan.id == "skitter":
		ci.draw_rect(Rect2(sk_x - 18.0, Boss.FLOOR - 3.0, 36.0, 3.0), Color(0.0, 0.0, 0.0, 0.5))       # its shadow
		PixelText.draw_text(ci, "!", sk_x, Boss.FLOOR - 40.0, "#ffd23f", {"align": "c", "outline": INK})
		var wx := 352.0 if sk_dir > 0.0 else 32.0
		ci.draw_line(Vector2(sk_x, Boss.FLOOR - 9.0), Vector2(wx, Boss.FLOOR - 9.0), Color(1.0, 0.5, 0.3, 0.35), 1.0)
	elif plan.id == "back":
		_hatch(ci, Rect2(leg_x - 52.0, 0.0, 24.0, Boss.FLOOR))
		_hatch(ci, Rect2(leg_x + 28.0, 0.0, 24.0, Boss.FLOOR))
		PixelText.draw_text(ci, "1", leg_x - 40.0, 90.0, "#ffffff", {"align": "c", "outline": INK})
		PixelText.draw_text(ci, "2", leg_x + 40.0, 90.0, "#ffffff", {"align": "c", "outline": INK})
		PixelText.draw_text(ci, "SAFE", leg_x, Boss.FLOOR - 30.0, "#7fd08a", {"align": "c", "tiny": true, "outline": INK})
	elif plan.id == "fetch" and leg_n > 1:
		PixelText.draw_text(ci, "%d/%d" % [leg_i + 1, leg_n], leg_x, leg_top + 6.0, "#ffffff", {"align": "c", "tiny": true, "outline": INK})

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, node, prev_node, roundi(core_y), roundi(leg_x), leg_on, roundi(leg_top),
		roundi(core_px), 1 if (down or down_t > 0.0) else 0, sk_state, roundi(sk_x), roundi(sk_dir), dc, roundi(sw_t0 * 100.0), roundi(sw_x0), roundi(sw_y0), leg_i, leg_n]
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 21

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	strike_sid = int(f[3])
	node = clampi(int(f[4]), 0, 3)
	prev_node = clampi(int(f[5]), 0, 3)
	core_y = float(f[6])
	leg_x = float(f[7])
	leg_on = int(f[8])
	leg_top = float(f[9])
	core_px = float(f[10])
	down = int(f[11]) == 1
	sk_state = int(f[12])
	sk_x = float(f[13])
	sk_dir = float(f[14])
	dc = int(f[15])
	sw_t0 = f[16] / 100.0
	sw_x0 = float(f[17])
	sw_y0 = float(f[18])
	leg_i = int(f[19])
	leg_n = int(f[20])
	phase = _phase_now()
	plan_apply(f.slice(NF, NF + 11))
	var old: Array = hz.duplicate()
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])
	for h in old:                                        # a strand that is gone snapped: show it fading
		var gone := true
		for h2 in hz:
			if hz_key(h2) == hz_key(h):
				gone = false
		if gone and not dying:
			ghosts.append({"a": strand_a(h), "b": strand_b(h), "t": 0.3})
	if dc == 1:
		_dc_follow()
	_place()

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	for g in ghosts:
		g.t -= dt
	ghosts = ghosts.filter(func(g): return g.t > 0.0)
	if dc == 1 and active and not dying:
		_dc_follow()
		_place()
