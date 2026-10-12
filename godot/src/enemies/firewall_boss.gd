class_name FirewallBoss
extends Boss
# THE FIREWALL (MVB2-08): deny by default. A body with a shield in front. The shield stops claws, dashes and agents from the front; the back, a pogo
# from above, a caught packet and every moment the shield is away (thrown, or knocked off) land. A kit boss: every attack is announced, harm exists
# only in the active phase, and the guest builds the same boxes from the net fields (the shield is a pure function of the plan).
# Rule 8: after each attack the shield turns (0.4 s, drawn) to whoever hit it in the last 2 s; a player who keeps clawing the shield from close gets a bash.

const IDS := ["throw", "return", "scan", "deny", "phase", "bash"]
const LANES := [[16.0, 112.0], [128.0, 256.0], [272.0, 368.0]]
const MEMB := [112.0, 256.0]                          # the membranes' left edges (16 px wide)
const SEQ1 := ["throw", "scan", "deny"]
const SEQ2 := ["phase", "throw", "scan", "deny"]
const WALK := 50.0
const INK := "#1b1226"
const RED := "#ff4f6d"
const SHIELD := "#7cc4ff"

var cycle := 0
var idle_t := 0.0
var strike_sid := 0
var shield_on := true
var shield_t := 0.0                # a caught packet knocked the shield away for this long
var turn_t := 0.0
var open_lane := 1
var mk_x := 192.0                  # the throw's turnaround marker
var dest_x := 192.0                # phase: where it comes out (centre)
var phase_x0 := 0.0
var next_tgt := ""
var bash_tgt := ""
var phase_dir := 1.0

func _init(r: Room, bx: float, by: float, base_hp := 60) -> void:
	super(r, bx, by, 22, 30, base_hp)
	boss_name = "THE FIREWALL"
	sub = "deny by default"
	col = RED
	face = -1.0
	kit_init()

func plan_ids() -> Array:
	return IDS

func _phys(dt: float) -> void:
	vy = minf(vy + 900.0 * dt, 320.0)
	hit_wall = room.grid.move_x(self, vx * dt)
	var hy := room.grid.move_y(self, vy * dt, true)
	on_ground = hy > 0
	if hy != 0:
		vy = 0.0

func _phase_now() -> int:
	return 2 if hpf / float(max_hp) <= 0.55 else 1

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
			shield_t = 1.6                                    # a packet caught back: the shield is knocked off for a while, and it takes 2
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

# where the shield is drawn and where its band lies: a pure function of the plan, the same on both pages
func shield_x() -> float:
	var bx := _body_front()
	if plan.is_empty():
		return bx
	var dur: float = float(FAMILY["sweep"][1])
	match String(plan.id):
		"throw":
			match String(plan.ph):
				"active":
					return lerpf(bx, mk_x, clampf(1.0 - float(plan.t) / dur, 0.0, 1.0))
				"recover":
					return mk_x
		"return":
			match String(plan.ph):
				"cue":
					return mk_x
				"active":
					return lerpf(mk_x, bx, clampf(1.0 - float(plan.t) / dur, 0.0, 1.0))
	return bx

func _band() -> Dictionary:
	var bx := _body_front()
	return {"x": minf(bx, mk_x), "y": Boss.FLOOR - 18.0, "w": absf(mk_x - bx), "h": 14.0}

func hurtboxes() -> Array:
	return [{"x": x + 1.0, "y": y + 1.0, "w": w - 2.0, "h": h - 1.0}]

func harmboxes() -> Array:
	var b: Array = []
	if not plan_active():
		return b
	match String(plan.id):
		"throw", "return":
			b.append(_band())
		"scan":
			for i in range(3):
				if i != open_lane:
					var l: Array = LANES[i]
					b.append({"x": l[0], "y": 16.0, "w": l[1] - l[0], "h": Boss.FLOOR - 16.0})
		"phase":
			b.append({"x": dest_x - 24.0, "y": Boss.FLOOR - 30.0, "w": 48.0, "h": 30.0, "sid": strike_sid, "catchable": false})
		"bash":
			b.append({"x": _bash_x(), "y": Boss.FLOOR - 30.0, "w": 48.0, "h": 30.0, "sid": strike_sid, "catchable": false})
	return b

func _bash_x() -> float:
	return cx + w / 2.0 if face > 0.0 else cx - w / 2.0 - 48.0

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if dying:
		death_rattle(dt, 2.4, ["#ffffff", SHIELD, RED, "#7a1f33"])
		vx = 0.0
		_phys(dt)
		return
	if not active:
		_phys(dt)
		return
	if shield_t > 0.0:
		shield_t -= dt
	if turn_t > 0.0:
		turn_t -= dt
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
	var seq: Array = SEQ2 if _phase_now() == 2 else SEQ1
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	var tgt := next_tgt if (next_tgt != "" and kit_alive(next_tgt)) else kit_pick_target()
	_start(id, tgt)

func _open_lane_for(tgt: String) -> int:
	var tl := lane_of(kit_aim(tgt).x)
	if tl == 1:
		return 2 if cx < 192.0 else 0              # the side away from the boss
	return 1

func _start(id: String, tgt: String) -> void:
	var ap := kit_aim(tgt)
	next_tgt = ""
	match id:
		"throw":
			_face_to(ap.x)
			mk_x = clampf(ap.x, 8.0, Game.W - 8.0)
			shield_on = true
			plan_start("throw", "sweep", tgt, _band_fp())
		"return":
			plan_start("return", "sweep", tgt, _band_fp(), 0.0, 0.5)
		"scan":
			open_lane = _open_lane_for(tgt)
			plan_start("scan", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.5)
		"deny":
			_face_to(ap.x)
			plan_start("deny", "proj", tgt, [0.0, 0.0, 0.0, 0.0])
		"phase":
			var m := 0
			if absf(cx - (MEMB[1] + 8.0)) < absf(cx - (MEMB[0] + 8.0)):
				m = 1
			var mx: float = float(MEMB[m]) + 8.0
			phase_dir = 1.0 if mx > cx else -1.0
			face = phase_dir
			dest_x = mx + phase_dir * (8.0 + 30.0)
			plan_start("phase", "slam", tgt, [dest_x - 24.0, Boss.FLOOR - 30.0, 48.0, 30.0], 0.0, 1.6)
		"bash":
			_face_to(ap.x)
			plan_start("bash", "lunge", tgt, [_bash_x(), Boss.FLOOR - 30.0, 48.0, 30.0], 0.4)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _face_to(px: float) -> void:
	var nf := Game.sign_of(px - cx)
	if nf != 0.0 and nf != face:
		face = nf
		turn_t = 0.4

func _band_fp() -> Array:
	var bd := _band()
	return [bd.x, bd.y, bd.w, bd.h]

func _plan_logic(dt: float) -> void:
	vx = 0.0
	var pid := String(plan.id)
	# the aim follows the target through the cue; the last `lock` seconds it is fixed
	if plan.ph == "cue" and plan.t > float(plan.lock):
		match pid:
			"throw":
				mk_x = clampf(kit_aim(plan.tgt).x, 8.0, Game.W - 8.0)
				plan.fp = _band_fp()
			"scan":
				open_lane = _open_lane_for(plan.tgt)
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
					Audio.sfx("dash", {"vol": 0.7})
				"return":
					Audio.sfx("dash", {"vol": 0.7})
				"scan":
					room.shake(0.3)
					Audio.sfx("laser", {"vol": 0.6})
				"deny":
					_shoot_orb()
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
			idle_t = 0.9
			_turn()

func _shoot_orb() -> void:
	var ap := kit_aim(plan.tgt)
	var ox := cx + face * 12.0
	var oy := y + 12.0
	var a := atan2(ap.y - oy, ap.x - ox)
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

func draw_boss_body(ci: CanvasItem) -> void:
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
		_draw_shield(ci, shield_x(), by + 1.0, face, 0.0)
	elif shield_on and shield_t <= 0.0:
		_draw_shield(ci, _body_front(), by + 1.0, face, clampf(turn_t / 0.4, 0.0, 1.0))
	elif shield_t > 0.0:
		PixelText.draw_text(ci, "x", cx - 2.0, by - 10.0, "#ffd23f", {"outline": INK})
	if plan_active() and (String(plan.id) == "scan"):
		for hb in harmboxes():
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.55))
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, 2), Color("#ffd0d8"))
	if plan_active() and (String(plan.id) == "phase" or String(plan.id) == "bash"):
		for hb in harmboxes():
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1, 1, 1, 0.5))

func draw_boss_overlay(ci: CanvasItem) -> void:
	draw_plan(ci)
	if plan.is_empty() or plan.ph != "cue":
		return
	if String(plan.id) == "scan":
		for i in range(3):
			var l: Array = LANES[i]
			if i == open_lane:
				ci.draw_rect(Rect2(l[0], 16.0, l[1] - l[0], Boss.FLOOR - 16.0), Color(0.5, 0.85, 0.55, 0.12))
				PixelText.draw_text(ci, "OPEN", (l[0] + l[1]) / 2.0, 60.0, "#7fd08a", {"align": "c", "outline": INK})
			else:
				_hatch(ci, Rect2(l[0], 16.0, l[1] - l[0], Boss.FLOOR - 16.0), ["22", "80", "443"][i])
	elif String(plan.id) == "throw":
		var mxp := mk_x
		ci.draw_rect(Rect2(mxp - 1.0, Boss.FLOOR - 26.0, 2, 24), Color("#ffd23f"))

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, 1 if shield_on else 0, roundi(maxf(shield_t, 0.0) * 100.0), roundi(maxf(turn_t, 0.0) * 100.0), open_lane, roundi(dest_x), roundi(mk_x)]
	f.append_array(plan_fields())
	return f

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
	open_lane = clampi(int(f[7]), 0, 2)
	dest_x = float(f[8])
	mk_x = float(f[9])
	phase = _phase_now()
	plan_apply(f.slice(10))

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	if shield_t > 0.0:
		shield_t -= dt
	if turn_t > 0.0:
		turn_t -= dt
