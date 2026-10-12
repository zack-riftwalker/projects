class_name FirewallBoss
extends Boss
# THE FIREWALL v2 (MVB3-07): deny by default. A body with a shield in front. The shield stops claws, dashes and agents from the front; the back, a pogo
# from above, a caught packet and every moment the shield is away (thrown, or knocked off) land. A kit boss: every attack is announced, harm exists only
# in the active phase or in an arena hazard, and the guest builds the same boxes from the net fields.
# The environment (arena hazards, Boss.hz_*): in phase 2 two deny walls close in from both sides until the arena is 12 tiles wide; in phase 3 DROP ALL burns
# the floor every 3 s except a port that is announced 0.9 s before; `rule` sends brick blocks sliding along the floor.
# Rule 8: after each attack the shield turns (0.4 s, drawn) to whoever hit it in the last 2 s; a player who keeps clawing the shield from close gets a bash.

const IDS := ["throw", "return", "rule", "scan", "deny", "phase", "bash"]
const LANES := [[16.0, 120.0], [120.0, 264.0], [264.0, 368.0]]     # the membranes' columns are split between their lanes: no safe perch on top of one
const MEMB := [112.0, 256.0]                          # the membranes' left edges (16 px wide)
const SEQ1 := ["throw", "rule", "scan", "deny"]
const SEQ2 := ["phase", "throw", "rule", "scan", "deny"]
const SEQ3 := ["throw", "deny", "phase"]
const WALK := 50.0
const INK := "#1b1226"
const RED := "#ff4f6d"
const SHIELD := "#7cc4ff"
const WALL_FINAL := 96.0                              # the deny walls stop at x 96 and 288
const WALL_TIME := 6.0
const WALL_WARN := 1.0
const DROP_EVERY := 3.0
const DROP_BURN := 0.4
const DROP_WARN := 0.9
const PORT_X := [128.0, 170.0, 214.0, 256.0]          # the port's centre (64 px wide): 22, 80, 443, 8080
const PORT_NUM := ["22", "80", "443", "8080"]
const THROW_ACT := 0.5
const BLOCK_SPEED := 200.0
const LOW_Y := Boss.FLOOR - 18.0                      # the shield's low pass (FLOOR-18 .. -4): jump it
const HIGH_Y := Boss.FLOOR - 40.0                     # and its high pass back (FLOOR-40 .. -26): stay low

var cycle := 0
var idle_t := 0.0
var strike_sid := 0
var shield_on := true
var shield_t := 0.0                # a caught packet knocked the shield away for this long
var turn_t := 0.0
var auto_t := 1.5                  # phase 3: the shield turns on its own every 1.5 s
var mk_x := 192.0                  # the throw's turnaround: the wall it bounces from
var dest_x := 192.0                # phase: where it comes out (centre)
var phase_x0 := 0.0
var next_tgt := ""
var bash_tgt := ""
var phase_dir := 1.0
var scan_order: Array = [0, 1, 2]  # the lanes in the order they burn
var scan_gap := 0.6
var drop_seed := 0                 # the sequence of ports (fixed per fight)
var dropall_n := 0                 # DROP ALLs so far
var drop_cd := 1.5
var walls_on := false
var rule_two := false

func _init(r: Room, bx: float, by: float, base_hp := 82) -> void:
	super(r, bx, by, 22, 30, base_hp)
	boss_name = "THE FIREWALL"
	sub = "deny by default"
	col = RED
	face = -1.0
	kit_init()
	drop_seed = int(Game.hash3(bx, by, 17) * 4.0) % 4

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["deny", "block", "drop"]

func _big() -> int:
	return int(Game.dv("big_hit"))

func _phys(dt: float) -> void:
	vy = minf(vy + 900.0 * dt, 320.0)
	hit_wall = room.grid.move_x(self, vx * dt)
	var hy := room.grid.move_y(self, vy * dt, true)
	on_ground = hy > 0
	if hy != 0:
		vy = 0.0

func _phase_now() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.25 else (2 if f <= 0.60 else 1)

func on_damage() -> void:
	var p := _phase_now()
	if p != phase:
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

func blocks(dx: float, _dy: float, how: String) -> bool:
	return shield_on and shield_t <= 0.0 and turn_t <= 0.0 and (how == "swipe" or how == "agent" or how == "dash") and Game.sign_of(dx) == -face

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if active and not dying:
		if how == "catch":
			shield_t = 2.0                                    # a packet caught back: the shield is knocked off for 2 s, and it takes 2
			room.burst(cx, y + 10.0, 8, [SHIELD, "#ffffff"], 90.0, 100.0)
			Audio.sfx("clang")
		elif blocks(dx, dy, how):
			var key := kit_key_of(room.attacker)
			if read != null and key != "":
				read.note_hit(key, how)                       # (rule 8 also reads the claws the shield stopped)
			Audio.sfx("clang")
			room.spark(cx + face * 11.0, y + 12.0, "#ffffff", 8)
			room.stop(0.04)
			return "block"
	return super.hit(d, dx, dy, how, b)

func start() -> void:
	super.start()
	idle_t = 1.0
	next_tgt = ""

# ---- the lanes and the shield ----
func lane_of(px: float) -> int:
	if px < 120.0:
		return 0
	return 1 if px < 264.0 else 2

func _body_front() -> float:
	return cx + face * (w / 2.0 + 3.0)

# the playable width now: the deny walls' front faces (a pure function of the hazards and the room time)
func bounds(now: float) -> Vector2:
	var l := 16.0
	var r := 368.0
	for h in hz:
		if h.k == "deny":
			var e := wall_edge(h, now)
			if int(h.v[0]) == 0:
				l = maxf(l, e)
			else:
				r = minf(r, Game.W - e)
	return Vector2(l, r)

# how far the wall has come in (0 .. 96), the front face of the left wall / the right wall measured from its own side
func wall_edge(h: Dictionary, now: float) -> float:
	var k := clampf((now - float(h.t0) - float(h.warn)) / WALL_TIME, 0.0, 1.0)
	return WALL_FINAL * k

# the throw: a short box on the low band flies out to the wall (mk_x), waits for the bounce, and comes back on the high band
func shield_pos() -> Vector2:
	var bx := _body_front()
	if plan.is_empty():
		return Vector2(bx, LOW_Y)
	match String(plan.id):
		"throw":
			match String(plan.ph):
				"active":
					return Vector2(lerpf(bx, mk_x, clampf(1.0 - float(plan.t) / THROW_ACT, 0.0, 1.0)), LOW_Y)
				"recover":
					return Vector2(mk_x, LOW_Y)
		"return":
			match String(plan.ph):
				"cue":
					return Vector2(mk_x, HIGH_Y)
				"active":
					return Vector2(lerpf(mk_x, bx, clampf(1.0 - float(plan.t) / THROW_ACT, 0.0, 1.0)), HIGH_Y)
	return Vector2(bx, LOW_Y)

func shield_x() -> float:
	return shield_pos().x

func _shield_box() -> Dictionary:
	var sp := shield_pos()
	return {"x": sp.x - 5.0, "y": sp.y, "w": 10.0, "h": 14.0}

func _path_fp(y0: float) -> Array:
	var bx := _body_front()
	return [minf(bx, mk_x), y0, absf(mk_x - bx), 14.0]

func hurtboxes() -> Array:
	return [{"x": x + 1.0, "y": y + 1.0, "w": w - 2.0, "h": h - 1.0}]

func harmboxes() -> Array:
	var b: Array = []
	if plan_active():
		match String(plan.id):
			"throw":
				var sb := _shield_box()
				sb["dmg"] = _big()
				b.append(sb)
			"return":
				b.append(_shield_box())
			"scan":
				var el := _scan_elapsed()
				for i in range(3):
					var s0 := float(i) * scan_gap
					if el >= s0 and el <= s0 + 0.4:
						var l: Array = LANES[int(scan_order[i])]
						b.append({"x": l[0], "y": 16.0, "w": l[1] - l[0], "h": Boss.FLOOR - 16.0})
			"phase":
				b.append({"x": dest_x - 24.0, "y": Boss.FLOOR - 30.0, "w": 48.0, "h": 30.0, "sid": strike_sid, "catchable": false, "dmg": _big()})
			"bash":
				b.append({"x": _bash_x(), "y": Boss.FLOOR - 30.0, "w": 48.0, "h": 30.0, "sid": strike_sid, "catchable": false})
	b.append_array(hz_harm())
	return b

func _scan_total() -> float:
	return 2.0 * scan_gap + 0.4

func _scan_elapsed() -> float:
	return _scan_total() - float(plan.t)

func _bash_x() -> float:
	return cx + w / 2.0 if face > 0.0 else cx - w / 2.0 - 48.0

# ---- the arena hazards ----
func hz_boxes(h: Dictionary, now: float) -> Array:
	var el := now - float(h.t0) - float(h.warn)
	match String(h.k):
		"deny":
			var e := wall_edge(h, now)
			if int(h.v[0]) == 0:
				return [{"x": e - 16.0, "y": 0.0, "w": 16.0, "h": Boss.FLOOR, "dmg": 1}]
			return [{"x": Game.W - e, "y": 0.0, "w": 16.0, "h": Boss.FLOOR, "dmg": 1}]
		"block":
			var bx := block_x(h, now)
			if bx < -16.0 or bx > Game.W + 16.0:
				return []
			return [{"x": bx - 8.0, "y": Boss.FLOOR - 32.0, "w": 16.0, "h": 32.0, "dmg": 1}]
		"drop":
			if el > DROP_BURN:
				return []
			var px: float = PORT_X[clampi(int(h.v[0]), 0, 3)]
			var bn := bounds(now)
			var out: Array = []
			if px - 32.0 > bn.x:
				out.append({"x": bn.x, "y": Boss.FLOOR - 6.0, "w": px - 32.0 - bn.x, "h": 6.0, "dmg": 1})
			if px + 32.0 < bn.y:
				out.append({"x": px + 32.0, "y": Boss.FLOOR - 6.0, "w": bn.y - px - 32.0, "h": 6.0, "dmg": 1})
			return out
	return []

func block_x(h: Dictionary, now: float) -> float:
	var el := maxf(0.0, now - float(h.t0) - float(h.warn))
	return float(h.v[1]) + float(h.v[0]) * BLOCK_SPEED * el

func _hz_expired(h: Dictionary, now: float) -> bool:
	var el := now - float(h.t0) - float(h.warn)
	match String(h.k):
		"drop":
			return el > DROP_BURN + 0.3
		"block":
			var bx := block_x(h, now)
			return el > 0.0 and (bx < -24.0 or bx > Game.W + 24.0)
	return false

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if dying:
		hz.clear()
		death_rattle(dt, 2.4, ["#ffffff", SHIELD, RED, "#7a1f33"])
		vx = 0.0
		_phys(dt)
		return
	if not active:
		_phys(dt)
		return
	hz = hz.filter(func(h): return not _hz_expired(h, room.time))
	if shield_t > 0.0:
		shield_t -= dt
	if turn_t > 0.0:
		turn_t -= dt
	var ph := _phase_now()
	if ph >= 2 and not walls_on:
		walls_on = true
		hz_add("deny", WALL_WARN, [0])
		hz_add("deny", WALL_WARN, [1])
		room.pop(192.0, 60.0, "deny all", "#ff4f6d", true)
	if ph == 3:
		drop_cd -= dt
		if drop_cd <= 0.0 and walls_on:
			drop_cd = DROP_EVERY
			hz_add("drop", DROP_WARN, [(drop_seed + 3 * dropall_n) % 4])
			dropall_n += 1
		auto_t -= dt
		if auto_t <= 0.0 and (plan.is_empty() or String(plan.ph) == "recover"):
			auto_t = 1.5
			face = -face                                      # the shield swings round on its own (0.3 s, drawn): the back is open at a rhythm
			turn_t = 0.3
	if plan.is_empty():
		plan_clock += dt
		idle_t -= dt
		_idle_walk()
		if idle_t <= 0.0:
			vx = 0.0
			_choose()
	else:
		_plan_logic(dt)
	_phys(dt)

func _idle_walk() -> void:
	vx = 0.0
	if next_tgt == "" or not kit_alive(next_tgt):
		return
	var ap := kit_aim(next_tgt)
	var dirx := Game.sign_of(ap.x - cx)
	if absf(ap.x - cx) > 50.0 and dirx == face and turn_t <= 0.0:
		vx = face * WALK

# rule 8: who hit it in the last 2 s (the claws the shield stopped count), else the next target
func _turn() -> void:
	var key := ""
	if read != null and read.last_key != "":
		var hs: Array = read.hits.get(read.last_key, [])
		if not hs.is_empty() and read.clock - float(hs[hs.size() - 1].t) <= 2.0 and kit_alive(read.last_key):
			key = read.last_key
	next_tgt = kit_pick_target()
	if key == "":
		key = next_tgt
	if key == "":
		return
	var nf := Game.sign_of(kit_aim(key).x - cx)
	if nf != 0.0 and nf != face:
		face = nf
		turn_t = 0.4

func _choose() -> void:
	var keys := kit_keys()
	if keys.is_empty():
		idle_t = 0.3
		return
	for k in keys:
		if read != null and read.greedy(k):
			read.hits[k].clear()
			_start("bash", k)
			return
	var ph := _phase_now()
	var seq: Array = SEQ3 if ph == 3 else (SEQ2 if ph == 2 else SEQ1)
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	var tgt := next_tgt if (next_tgt != "" and kit_alive(next_tgt)) else kit_pick_target()
	_start(id, tgt)

func _rec(base: float) -> float:
	return minf(base, 0.5) if _phase_now() == 3 else base

# the lane order of a scan: away from the boss (a boss in the middle starts on the target's side)
func _scan_plan(tgt: String) -> void:
	var bl := lane_of(cx)
	if bl == 0:
		scan_order = [0, 1, 2]
	elif bl == 2:
		scan_order = [2, 1, 0]
	else:
		scan_order = [0, 1, 2] if kit_aim(tgt).x < cx else [2, 1, 0]
	scan_gap = 0.35 if _phase_now() >= 2 else 0.6

func _start(id: String, tgt: String) -> void:
	var ap := kit_aim(tgt)
	next_tgt = ""
	match id:
		"throw":
			_face_to(ap.x)
			var bn := bounds(room.time)
			mk_x = bn.y - 6.0 if face > 0.0 else bn.x + 6.0       # the far wall (or the deny wall) in the way it faces
			shield_on = true
			plan_start("throw", "dual", tgt, _path_fp(LOW_Y), 0.0, 0.75, 0.1, THROW_ACT)
		"return":
			plan_start("return", "dual", tgt, _path_fp(HIGH_Y), 0.0, 0.25, _rec(0.7), THROW_ACT)
		"rule":
			_face_to(ap.x)
			var bn2 := bounds(room.time)
			var dirb := -1.0 if cx > 192.0 else 1.0                # from the boss's side to the far side
			var x0 := bn2.y + 8.0 if dirb < 0.0 else bn2.x - 8.0
			rule_two = _phase_now() >= 2
			plan_start("rule", "lunge", tgt, [x0 - 8.0, Boss.FLOOR - 32.0, 16.0, 32.0], 0.0, 0.7, _rec(0.6))
			var cue := float(plan.t)
			hz_add("block", cue, [int(dirb), roundi(x0)])
			if rule_two:
				hz_add("block", cue + 0.5, [int(dirb), roundi(x0)])
		"scan":
			_scan_plan(tgt)
			plan_start("scan", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, _rec(0.6), _scan_total())
		"deny":
			_face_to(ap.x)
			plan_start("deny", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, _rec(0.7))
		"phase":
			var m := 0
			if absf(cx - (MEMB[1] + 8.0)) < absf(cx - (MEMB[0] + 8.0)):
				m = 1
			var mx: float = float(MEMB[m]) + 8.0
			phase_dir = 1.0 if mx > cx else -1.0
			face = phase_dir
			dest_x = mx + phase_dir * (8.0 + 30.0)
			plan_start("phase", "slam", tgt, [dest_x - 24.0, Boss.FLOOR - 30.0, 48.0, 30.0], 0.0, 0.75, _rec(0.7))
		"bash":
			_face_to(ap.x)
			plan_start("bash", "lunge", tgt, [_bash_x(), Boss.FLOOR - 30.0, 48.0, 30.0], 0.3, 0.45, _rec(0.6))
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _face_to(px: float) -> void:
	var nf := Game.sign_of(px - cx)
	if nf != 0.0 and nf != face:
		face = nf
		turn_t = 0.4

func _plan_logic(dt: float) -> void:
	vx = 0.0
	var pid := String(plan.id)
	# the aim follows the target through the cue; the last `lock` seconds it is fixed
	if plan.ph == "cue" and plan.t > float(plan.lock):
		match pid:
			"bash":
				_face_to(kit_aim(plan.tgt).x)
				plan.fp = [_bash_x(), Boss.FLOOR - 30.0, 48.0, 30.0]
	if pid == "phase" and plan.ph == "cue":
		vx = phase_dir * WALK
		if hit_wall != 0:
			vx = 0.0
	if pid == "phase" and plan.ph == "active":
		var f := clampf(1.0 - float(plan.t) / float(FAMILY["slam"][1]), 0.0, 1.0)
		x = lerpf(phase_x0, dest_x - w / 2.0, f)             # through the brick (the tunnel it will teach)
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"throw":
					shield_on = false
					strike_sid = Game.next_strike_id()
					Audio.sfx("dash", {"vol": 0.7})
				"return":
					Audio.sfx("dash", {"vol": 0.7})
				"scan":
					room.shake(0.3)
					Audio.sfx("laser", {"vol": 0.6})
				"rule":
					Audio.sfx("thud", {"vol": 0.7})
				"deny":
					_shoot_orbs()
				"phase":
					phase_x0 = x
					strike_sid = Game.next_strike_id()
					room.shake(0.3)
					Audio.sfx("thud")
				"bash":
					strike_sid = Game.next_strike_id()
					Audio.sfx("dash", {"vol": 0.7})
		"recover":
			strike_sid = 0
			if pid == "phase":
				x = dest_x - w / 2.0
				shield_on = false                                  # its back is to the membrane: nothing stops a claw for the recovery
		"done":
			strike_sid = 0
			if pid == "throw":
				_start("return", String(plan.get("tgt", "p1")) if not plan.is_empty() else kit_pick_target())
				return
			shield_on = true
			idle_t = 0.35
			_turn()

# one orb in phase 1, two in the later phases (a small fan): yellow, catchable; a catch back drops the shield for 2 s
func _shoot_orbs() -> void:
	var ap := kit_aim(plan.tgt)
	var ox := cx + face * 12.0
	var oy := y + 12.0
	var a0 := atan2(ap.y - oy, ap.x - ox)
	var n := 1 if _phase_now() == 1 else 2
	for i in range(n):
		var a := a0 + (float(i) - float(n - 1) / 2.0) * 0.36
		room.shoot(ox, oy, cos(a) * 110.0, sin(a) * 110.0, {"kind": "diamond", "col": "#ffd23f", "r": 5.0, "catchable": true, "cut": true, "life": 5.0, "dmg": 1, "by_boss": true})
	Audio.sfx("shoot")

# ---- drawing ----
func _hatch(ci: CanvasItem, r: Rect2, label := "") -> void:
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
	if label != "":
		PixelText.draw_text(ci, label, r.position.x + r.size.x / 2.0, r.position.y + 6.0, "#ffffff", {"align": "c", "outline": INK})

func _draw_shield(ci: CanvasItem, sx: float, sy: float, f: float, swing: float) -> void:
	var ink := Color(INK)
	var sw := 6.0 * (1.0 - swing)
	var rx := sx - 1.0 if f > 0.0 else sx - sw + 1.0
	ci.draw_rect(Rect2(rx - 1.0, sy - 1.0, sw + 2.0, 30.0), ink)
	ci.draw_rect(Rect2(rx, sy, sw, 28.0), Color(SHIELD))
	ci.draw_rect(Rect2(rx, sy, sw, 3.0), Color("#d6f0ff"))

func _draw_bricks(ci: CanvasItem, r: Rect2, c1: Color, c2: Color) -> void:
	ci.draw_rect(Rect2(r.position.x - 1.0, r.position.y, r.size.x + 2.0, r.size.y), Color(INK))
	var row := 0
	var yy := 0.0
	while yy < r.size.y:
		var off := 0.0 if row % 2 == 0 else 5.0
		var xx := -off
		while xx < r.size.x:
			var x0 := maxf(0.0, xx)
			var x1 := minf(r.size.x, xx + 10.0)
			if x1 > x0:
				ci.draw_rect(Rect2(r.position.x + x0, r.position.y + yy, x1 - x0 - 1.0, 5.0), c1 if (row + int(xx)) % 3 != 0 else c2)
			xx += 10.0
		yy += 6.0
		row += 1

func _draw_hazards(ci: CanvasItem) -> void:
	for h in hz:
		var live := hz_live(h, room.time)
		match String(h.k):
			"deny":
				var e := wall_edge(h, room.time)
				var left: bool = int(h.v[0]) == 0
				var wx: float = e - 16.0 if left else Game.W - e
				if not live:
					var edge_x: float = 0.0 if left else Game.W - 6.0
					if int(t * 10.0) % 2 == 0:
						ci.draw_rect(Rect2(edge_x, 0.0, 6.0, Boss.FLOOR), Color(1.0, 0.2, 0.3, 0.6))
				_draw_bricks(ci, Rect2(wx, 0.0, 16.0, Boss.FLOOR), Color("#8a2438"), Color(RED))
				ci.draw_rect(Rect2(wx + (14.0 if left else 0.0), 0.0, 2.0, Boss.FLOOR), Color("#ff9aa8"))
			"block":
				var bx := block_x(h, room.time)
				if not live:
					ci.draw_rect(Rect2(float(h.v[1]) - 8.0, Boss.FLOOR - 32.0, 16.0, 32.0), Color(1.0, 0.31, 0.43, 0.25), false, 1.0)
					continue
				_draw_bricks(ci, Rect2(bx - 8.0, Boss.FLOOR - 32.0, 16.0, 32.0), Color("#8a2438"), Color(RED))
			"drop":
				var px: float = PORT_X[clampi(int(h.v[0]), 0, 3)]
				var bn := bounds(room.time)
				if not live:                                    # the port: a green frame with its number
					ci.draw_rect(Rect2(px - 32.0, Boss.FLOOR - 14.0, 64.0, 14.0), Color(0.5, 0.9, 0.55, 0.2))
					ci.draw_rect(Rect2(px - 32.0, Boss.FLOOR - 14.0, 64.0, 14.0), Color("#7fd08a"), false, 1.0)
					PixelText.draw_text(ci, PORT_NUM[clampi(int(h.v[0]), 0, 3)], px, Boss.FLOOR - 28.0, "#7fd08a", {"align": "c", "outline": INK})
					ci.draw_rect(Rect2(bn.x, Boss.FLOOR - 6.0, bn.y - bn.x, 1), Color(1.0, 0.3, 0.3, 0.5 + 0.4 * sin(t * 16.0)))
				else:
					for hb in hz_boxes(h, room.time):
						ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.85))
						ci.draw_rect(Rect2(hb.x, hb.y, hb.w, 1), Color("#ffd0d8"))

func draw_boss_body(ci: CanvasItem) -> void:
	_draw_hazards(ci)
	var ink := Color(INK)
	var bx := floorf(x)
	var by := floorf(y)
	var red := Color(RED)
	ci.draw_rect(Rect2(bx - 1.0, by - 1.0, w + 2.0, h + 2.0), ink)
	ci.draw_rect(Rect2(bx, by, w, h), Color("#5b1a2a"))
	# a brick wall for a body: courses of bricks
	var row := 0
	var yy := 0.0
	while yy < h:
		var off := 0.0 if row % 2 == 0 else 5.0
		var xx := -off
		while xx < w:
			var x0 := maxf(0.0, xx)
			var x1 := minf(w, xx + 10.0)
			if x1 > x0:
				ci.draw_rect(Rect2(bx + x0, by + yy, x1 - x0 - 1.0, 5.0), Color("#8a2438") if (row + int(xx)) % 3 != 0 else red)
			xx += 10.0
		yy += 6.0
		row += 1
	var ex := bx + (13.0 if face > 0.0 else 3.0)
	ci.draw_rect(Rect2(ex, by + 5.0, 6, 3), ink)
	ci.draw_rect(Rect2(ex + 1.0, by + 6.0, 4, 1), Color("#ffd23f"))
	if dying:
		return
	var thrown := not plan.is_empty() and ((String(plan.id) == "throw" and String(plan.ph) != "cue") or String(plan.id) == "return")
	if thrown:
		var sp := shield_pos()
		ci.draw_rect(Rect2(sp.x - 6.0, sp.y - 1.0, 12.0, 16.0), ink)
		ci.draw_rect(Rect2(sp.x - 5.0, sp.y, 10.0, 14.0), Color(SHIELD))
		ci.draw_rect(Rect2(sp.x - 5.0, sp.y, 10.0, 3.0), Color("#d6f0ff"))
	elif shield_on and shield_t <= 0.0:
		_draw_shield(ci, _body_front(), by + 1.0, face, clampf(turn_t / (0.3 if _phase_now() == 3 else 0.4), 0.0, 1.0))
	elif shield_t > 0.0:
		PixelText.draw_text(ci, "x", cx - 2.0, by - 10.0, "#ffd23f", {"outline": INK})
	if plan_active() and String(plan.id) == "scan":
		for hb in harmboxes():
			if hb.h > 100.0:
				ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.55))
				ci.draw_rect(Rect2(hb.x, hb.y, hb.w, 2), Color("#ffd0d8"))
	if plan_active() and (String(plan.id) == "phase" or String(plan.id) == "bash"):
		for hb in harmboxes():
			if hb.has("sid"):
				ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1, 1, 1, 0.5))

func draw_boss_overlay(ci: CanvasItem) -> void:
	draw_plan(ci)
	if plan.is_empty() or plan.ph != "cue":
		return
	if String(plan.id) == "scan":
		for i in range(3):
			var l: Array = LANES[int(scan_order[i])]
			_hatch(ci, Rect2(l[0], 16.0, l[1] - l[0], Boss.FLOOR - 16.0), "%d" % (i + 1))
	elif String(plan.id) == "throw":
		ci.draw_rect(Rect2(mk_x - 1.0, Boss.FLOOR - 40.0, 2, 38), Color("#ffd23f"))
		PixelText.draw_text(ci, "low", (_body_front() + mk_x) / 2.0, LOW_Y - 8.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
	elif String(plan.id) == "return":
		PixelText.draw_text(ci, "high", (_body_front() + mk_x) / 2.0, HIGH_Y - 8.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
		ci.draw_rect(Rect2(minf(_body_front(), mk_x), HIGH_Y, absf(mk_x - _body_front()), 14.0), Color(1.0, 0.8, 0.2, 0.18))

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, 1 if shield_on else 0, roundi(maxf(shield_t, 0.0) * 100.0), roundi(maxf(turn_t, 0.0) * 100.0),
		scan_order[0] * 9 + scan_order[1] * 3 + scan_order[2], roundi(dest_x), roundi(mk_x), roundi(scan_gap * 100.0), drop_seed, dropall_n, 1 if walls_on else 0, int(face)]
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 15

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	strike_sid = int(f[3])
	shield_on = int(f[4]) == 1
	shield_t = f[5] / 100.0
	turn_t = f[6] / 100.0
	var so := int(f[7])
	scan_order = [so / 9, (so / 3) % 3, so % 3]
	dest_x = float(f[8])
	mk_x = float(f[9])
	scan_gap = f[10] / 100.0
	drop_seed = int(f[11])
	dropall_n = int(f[12])
	walls_on = int(f[13]) == 1
	phase = _phase_now()
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	if shield_t > 0.0:
		shield_t -= dt
	if turn_t > 0.0:
		turn_t -= dt
