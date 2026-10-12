class_name Reviewer2
extends Boss
# THE REVIEWER #2 (MVB2-09): the optional second review, in the arena under the hub, started only from the chair (see Room.pad_press).
# A kit boss. `cached` reads what the target did to it (the kind of its last hit: side claw, up claw, pogo, dash, agent, caught shot) and blocks
# exactly that kind, then answers a blocked hit with a riposte; hits of another kind land. Rule 8: three close claws from one player earn that
# player a `cached`. Harm exists only in the active phase; the guest builds the same boxes from the net fields.

const IDS := ["cached", "double", "verdict", "cross", "signoff", "riposte"]
const KINDS := ["side", "up", "pogo", "dash", "agent", "catch"]
const SEQ1 := ["cached", "double", "verdict"]
const SEQ2 := ["cached", "double", "cross", "verdict"]
const SEQ3 := ["cached", "double", "signoff", "cross", "verdict"]
const WALK := 60.0
const LUNGE_DIST := 130.0
const BAND := 150.0
const INK := "#1b1226"
const HOODIE := "#5a6b8c"
const PEN := "#ff4f6d"

var cycle := 0
var idle_t := 0.0
var strike_sid := 0
var cached_kind := "side"
var riposte_to := ""
var last_kind := {"p1": "side", "p2": "side"}
var mark_x := 192.0                # cross: the mark; signoff: the spot it lunges to
var x0 := 0.0                      # signoff: where the lunge started
var shots := 0
var shot_t := 0.0
var signoff_shot := false

func _init(r: Room, bx: float, by: float, base_hp := 59) -> void:
	super(r, bx, by, 14, 24, base_hp)
	boss_name = "THE REVIEWER #2"
	sub = "second review"
	col = HOODIE
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
	var f := hpf / float(max_hp)
	return 3 if f <= 0.25 else (2 if f <= 0.60 else 1)

func on_damage() -> void:
	var p := _phase_now()
	if p != phase:
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

# what a hit is, as far as `cached` is concerned
static func kind_of(dy: float, how: String) -> String:
	match how:
		"swipe":
			return "up" if dy < 0.0 else ("pogo" if dy > 0.0 else "side")
		"stomp":
			return "pogo"
		"dash", "agent", "catch":
			return how
	return "side"

func blocks(_dx: float, dy: float, how: String) -> bool:
	if not plan_active() and not (plan_phase() == "cue" and String(plan.id) == "signoff"):
		return false
	match String(plan.id):
		"cached":
			return plan_active() and kind_of(dy, how) == cached_kind
		"signoff":
			return plan_phase() == "cue" and how != "catch"                    # a closed guard
	return false

func hit(d: int, dx: float, dy: float, how: String, box = null) -> String:
	if active and not dying:
		var key := kit_key_of(room.attacker)
		if key != "":
			last_kind[key] = kind_of(dy, how)
		if blocks(dx, dy, how):
			if String(plan.id) == "cached" and key != "":
				riposte_to = key
			Audio.sfx("clang")
			room.spark(cx + face * 8.0, y + 8.0, "#ffffff", 8)
			room.stop(0.04)
			if String(plan.id) == "cached":
				plan_cut()
			return "block"
	return super.hit(d, dx, dy, how, box)

func start() -> void:
	super.start()
	idle_t = 1.0

func hurtboxes() -> Array:
	return [{"x": x, "y": y, "w": w, "h": h}]

func harmboxes() -> Array:
	var b: Array = []
	if not plan_active():
		return b
	match String(plan.id):
		"riposte":
			b.append({"x": x + 2, "y": y + 2, "w": w - 4, "h": h - 3})
			b.append({"x": x + w if face > 0.0 else x - 18.0, "y": y + 6, "w": 18.0, "h": 12.0, "sid": strike_sid, "catchable": true})
		"double":
			var first: bool = float(plan.t) > float(FAMILY["dual"][1]) / 2.0
			var dirx := face if first else -face
			b.append({"x": cx if dirx > 0.0 else cx - BAND, "y": Boss.FLOOR - 24.0, "w": BAND, "h": 24.0})
		"cross":
			b.append({"x": mark_x - 112.0, "y": Boss.FLOOR - 40.0, "w": 80.0, "h": 40.0})
			b.append({"x": mark_x + 32.0, "y": Boss.FLOOR - 40.0, "w": 80.0, "h": 40.0})
		"signoff":
			b.append({"x": minf(x0, mark_x - w / 2.0), "y": Boss.FLOOR - 30.0, "w": absf(mark_x - w / 2.0 - x0) + w, "h": 30.0, "sid": strike_sid, "catchable": false})
	return b

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if dying:
		death_rattle(dt, 2.4, ["#ffffff", HOODIE, PEN, "#f4ede0"])
		vx = 0.0
		_phys(dt)
		return
	if not active:
		_phys(dt)
		return
	if plan.is_empty():
		plan_clock += dt
		idle_t -= dt
		vx = 0.0
		var keys := kit_keys()
		if not keys.is_empty() and idle_t > 0.2:
			var ap := kit_aim(kit_pick_target() if keys.size() == 1 else keys[0])
			if absf(ap.x - cx) > 64.0:
				face = Game.sign_of(ap.x - cx)
				vx = face * WALK
		if idle_t <= 0.0:
			vx = 0.0
			_choose()
	else:
		_plan_logic(dt)
	_phys(dt)

func _choose() -> void:
	var keys := kit_keys()
	if keys.is_empty():
		idle_t = 0.3
		return
	if riposte_to != "":
		var k := riposte_to
		riposte_to = ""
		if kit_alive(k):
			_start("riposte", k)
			return
	for k in keys:
		if read != null and read.greedy(k):
			read.hits[k].clear()
			_start("cached", k)
			return
	var seq: Array = SEQ3 if _phase_now() == 3 else (SEQ2 if _phase_now() == 2 else SEQ1)
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	_start(id, kit_pick_target())

func _face_to(px: float) -> void:
	var nf := Game.sign_of(px - cx)
	if nf != 0.0:
		face = nf

func _start(id: String, tgt: String) -> void:
	var ap := kit_aim(tgt)
	_face_to(ap.x)
	match id:
		"cached":
			cached_kind = String(last_kind.get(tgt, "side"))
			plan_start("cached", "guard", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 1.3)
		"double":
			plan_start("double", "dual", tgt, [0.0, 0.0, 0.0, 0.0], 0.5)
		"verdict":
			shots = 0
			shot_t = 0.0
			plan_start("verdict", "proj", tgt, [0.0, 0.0, 0.0, 0.0])
		"cross":
			mark_x = clampf(ap.x, 64.0, Game.W - 64.0)
			plan_start("cross", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.5)
		"signoff":
			mark_x = clampf(ap.x, 24.0, Game.W - 24.0)
			x0 = x
			signoff_shot = false
			plan_start("signoff", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.4, 1.5)
		"riposte":
			plan_start("riposte", "lunge", tgt, _riposte_fp(), 0.4, 0.8)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _riposte_fp() -> Array:
	return [cx + 8.0 if face > 0.0 else cx - 8.0 - LUNGE_DIST, y + 4.0, LUNGE_DIST, h - 4.0]

func _plan_logic(dt: float) -> void:
	vx = 0.0
	var pid := String(plan.id)
	if plan.ph == "cue" and plan.t > float(plan.lock):
		var ap := kit_aim(plan.tgt)
		match pid:
			"double", "riposte":
				_face_to(ap.x)
				if pid == "riposte":
					plan.fp = _riposte_fp()
			"cross":
				mark_x = clampf(ap.x, 64.0, Game.W - 64.0)
			"signoff":
				mark_x = clampf(ap.x, 24.0, Game.W - 24.0)
	if pid == "signoff" and plan.ph == "active":
		var f := clampf(1.0 - float(plan.t) / float(FAMILY["lunge"][1]), 0.0, 1.0)
		x = lerpf(x0, mark_x - w / 2.0, f)
	if pid == "riposte" and plan.ph == "active":
		vx = face * 420.0
		if hit_wall != 0:
			vx = 0.0
	if pid == "verdict" and (plan.ph == "active" or plan.ph == "recover") and shots < 4:
		shot_t -= dt
		if shot_t <= 0.0:
			_shoot_verdict()
			shots += 1
			shot_t = 0.7
		if plan.ph == "recover" and plan.t < 0.3:
			plan.t = 0.3                                            # (the recovery waits for the last shot)
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"riposte", "signoff":
					strike_sid = Game.next_strike_id()
					Audio.sfx("dash", {"vol": 0.7})
				"cross":
					room.shake(0.3)
					Audio.sfx("laser", {"vol": 0.6})
				"double":
					Audio.sfx("slash", {"vol": 0.7})
		"recover":
			strike_sid = 0
			vx = 0.0
			if pid == "signoff" and not signoff_shot:
				signoff_shot = true
				x = mark_x - w / 2.0
				_shoot_diamond(true)
			elif pid == "verdict":
				plan.t = maxf(plan.t, 0.3)
		"done":
			strike_sid = 0
			idle_t = 0.9

func _shoot_diamond(yellow := true) -> void:
	var ap := kit_aim(plan.tgt)
	var ox := cx + face * 8.0
	var oy := y + 8.0
	var dist := maxf(60.0, Vector2(ap.x - ox, ap.y - oy).length())
	var a := atan2(ap.y - oy, ap.x - ox)
	var speed := clampf(dist / 0.7, 90.0, 190.0)
	room.shoot(ox, oy, cos(a) * speed, sin(a) * speed, {"kind": "diamond", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1, "by_boss": true})
	Audio.sfx("shoot")

func _shoot_verdict() -> void:
	if shots % 2 == 0:
		_shoot_diamond(true)
	else:
		var ap := kit_aim(plan.tgt)
		var dirx := Game.sign_of(ap.x - cx)
		if dirx == 0.0:
			dirx = face
		room.shoot(cx + dirx * 8.0, Boss.FLOOR - 7.0, dirx * 130.0, 0.0, {"kind": "orb", "col": "#8d8798", "r": 4.0, "catchable": false, "cut": false, "life": 3.0, "dmg": 1, "by_boss": true, "tile": false})
		Audio.sfx("shoot")

# ---- drawing ----
func _pen(ci: CanvasItem, x0_: float, y0_: float, len_: float, vertical: bool) -> void:
	var ink := Color(INK)
	var pen := Color(PEN)
	if vertical:
		ci.draw_rect(Rect2(x0_ - 1, y0_ - 1, 4, len_ + 2), ink)
		ci.draw_rect(Rect2(x0_, y0_, 2, len_), pen)
	else:
		var px := x0_ if face > 0.0 else x0_ - len_
		ci.draw_rect(Rect2(px - 1, y0_ - 1, len_ + 2, 4), ink)
		ci.draw_rect(Rect2(px, y0_, len_, 2), pen)

func draw_boss_body(ci: CanvasItem) -> void:
	var ink := Color(INK)
	var hood := Color(HOODIE)
	var bx := floorf(x)
	var by := floorf(y)
	var f := face
	var crouch := 5.0 if (plan_phase() == "cue" and (String(plan.id) == "signoff" or String(plan.id) == "riposte")) else 0.0
	by += crouch
	var hh := h - crouch
	ci.draw_rect(Rect2(bx, by, w, hh), ink)
	ci.draw_rect(Rect2(bx + 1, by + 9, w - 2, hh - 9), hood)
	ci.draw_rect(Rect2(bx + 1, by + 1, w - 2, 9), hood)
	var fxp := bx + (6.0 if f > 0.0 else 2.0)
	ci.draw_rect(Rect2(fxp, by + 3, 6, 6), Color("#f4ede0"))
	ci.draw_rect(Rect2(fxp, by + 4, 6, 3), ink)
	ci.draw_rect(Rect2(fxp + (3.0 if f > 0.0 else 2.0), by + 5, 1, 1), Color("#f4ede0"))
	PixelText.draw_text(ci, "#2", bx + 3.0, by + 13.0, "#f4ede0", {"tiny": true})           # the badge
	var hand_y := by + 13.0
	var hand_x := bx + w - 2.0 if f > 0.0 else bx + 2.0
	if plan_phase() == "cue" or plan_active():
		match String(plan.id):
			"cached":
				_pen(ci, hand_x + f * 2.0, by - 11.0, 16.0, true)
			"signoff":
				_pen(ci, hand_x, hand_y - 1.0, 18.0, false)
			_:
				_pen(ci, hand_x, hand_y, 16.0, false)
	else:
		_pen(ci, hand_x, hand_y, 16.0, false)
	if plan_active() and String(plan.id) == "cached":                 # the closed guard: a page held up
		var gx := bx + w if f > 0.0 else bx - 6.0
		ci.draw_rect(Rect2(gx - 1, by + 1, 8, hh - 2), ink)
		ci.draw_rect(Rect2(gx, by + 2, 6, hh - 4), Color("#f4ede0"))
		ci.draw_rect(Rect2(gx + 1, by + 5, 4, 1), ink)
		ci.draw_rect(Rect2(gx + 1, by + 8, 4, 1), ink)
	if plan_active() and (String(plan.id) == "double" or String(plan.id) == "cross" or String(plan.id) == "signoff"):
		for hb in harmboxes():
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.5))

func _bubble(ci: CanvasItem, text: String) -> void:
	var tw := PixelText.text_width(text, {"tiny": true})
	var bx := clampf(floorf(cx - tw / 2.0 - 3.0), 2.0, Game.W - tw - 8.0)
	var by := y - 22.0
	Gfx.panel(ci, bx, by, tw + 6.0, 12.0, "#f4ede0", INK)
	PixelText.draw_text(ci, text, bx + 3.0, by + 3.0, INK, {"tiny": true})

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
		PixelText.draw_text(ci, label, r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0 - 3.0, "#ffffff", {"align": "c", "outline": INK})

func draw_boss_overlay(ci: CanvasItem) -> void:
	if not active and not dying:
		PixelText.draw_text(ci, "sit, when you have something new to show", cx, y - 14.0, Game.COL.dim, {"align": "c", "tiny": true})
	draw_plan(ci)
	if dying:
		_bubble(ci, "LGTM! Approved.")
		return
	if plan.is_empty():
		return
	var pid := String(plan.id)
	if pid == "cached" and plan.ph != "recover":
		_bubble(ci, "cached: %s" % cached_kind.to_upper())
	if plan.ph != "cue":
		return
	match pid:
		"double":
			_hatch(ci, Rect2(cx if face > 0.0 else cx - BAND, Boss.FLOOR - 24.0, BAND, 24.0), "1")
			_hatch(ci, Rect2(cx if face < 0.0 else cx - BAND, Boss.FLOOR - 24.0, BAND, 24.0), "2")
		"cross":
			_hatch(ci, Rect2(mark_x - 112.0, Boss.FLOOR - 40.0, 80.0, 40.0))
			_hatch(ci, Rect2(mark_x + 32.0, Boss.FLOOR - 40.0, 80.0, 40.0))
			PixelText.draw_text(ci, "SAFE", mark_x, Boss.FLOOR - 30.0, "#7fd08a", {"align": "c", "tiny": true, "outline": INK})
		"signoff":
			_hatch(ci, Rect2(minf(x, mark_x - w / 2.0), Boss.FLOOR - 30.0, absf(mark_x - w / 2.0 - x) + w, 30.0))
			PixelText.draw_text(ci, "x", mark_x, Boss.FLOOR - 14.0, "#ffffff", {"align": "c", "outline": INK})
		"riposte":
			PixelText.draw_text(ci, "!", cx - 1.0, y - 10.0, Game.COL.hazardHi, {"outline": INK})

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, KINDS.find(cached_kind), roundi(mark_x), roundi(x0), 1 if dying else 0]
	f.append_array(plan_fields())
	return f

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	strike_sid = int(f[3])
	cached_kind = KINDS[clampi(int(f[4]), 0, KINDS.size() - 1)]
	mark_x = float(f[5])
	x0 = float(f[6])
	dying = int(f[7]) == 1
	passive = not active or dying
	phase = _phase_now()
	plan_apply(f.slice(8))

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
