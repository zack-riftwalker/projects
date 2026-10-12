class_name Reviewer2
extends Boss
# THE REVIEWER #2 (MVB2-09): the optional second review, in the arena under the hub, started only from the chair (see Room.pad_press).
# A kit boss. `cached` reads what the target did to it (the kind of its last hit: side claw, up claw, pogo, dash, agent, caught shot) and blocks
# exactly that kind, then answers a blocked hit with a riposte; hits of another kind land. Rule 8: three close claws from one player earn that
# player a `cached`. Harm exists only in the active phase; the guest builds the same boxes from the net fields.

const IDS := ["cached", "double", "verdict", "cross", "signoff", "riposte", "nitpick", "slash", "sdiamond"]
const KINDS := ["side", "up", "pogo", "dash", "agent", "catch"]
const MAX_MARKS := 8
const MARK_WARN := 0.8
const VERDICT_GAP := 0.5
const DOUBLE_GAP := 0.25
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
var pen_xs: Array = []             # nitpick: where the pens fall
var nit_gap := 192.0               # nitpick: the middle of the 64 px gap that stays free
var pair_next := ""                # the second attack of a pair
var pair_tgt := ""
var thrusts := 2

func _init(r: Room, bx: float, by: float, base_hp := 96) -> void:
	super(r, bx, by, 14, 24, base_hp)
	boss_name = "THE REVIEWER #2"
	sub = "second review"
	col = HOODIE
	face = -1.0
	kit_init()

func plan_ids() -> Array:
	return IDS

func _big() -> int:
	return int(Game.dv("big_hit"))

# ---- unresolved comments: the arena hazard (MVB3-08). A grey `reject` shot or a `nitpick` pen that lands leaves a `//` on the floor at its x; it hurts a body
# standing on it (the 6 px band) after 0.8 s. Eight at most. A caught diamond back into the boss resolves the two oldest; a phase change, all of them.
func hz_kinds() -> Array:
	return ["mark"]

func hz_boxes(h: Dictionary, _now: float) -> Array:
	return [{"x": float(h.v[0]) - 8.0, "y": Boss.FLOOR - 6.0, "w": 16.0, "h": 6.0, "dmg": 1}]

func leave_mark(px: float) -> void:
	if not active or dying:
		return
	if hz.size() >= MAX_MARKS:
		hz.pop_front()                                    # a ninth removes the oldest
	hz_add("mark", MARK_WARN, [roundi(clampf(px, 8.0, Game.W - 8.0))])

func resolve_marks(n: int) -> void:
	if hz.is_empty():
		return
	for i in range(mini(n, hz.size())):
		var h: Dictionary = hz.pop_front()
		room.burst(float(h.v[0]), Boss.FLOOR - 4.0, 4, ["#7fd08a", "#ffffff"], 60.0, 100.0)
	room.pop(cx, y - 18.0, "LGTM", "#7fd08a", true)
	Audio.sfx("uiOk")

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
		hz.clear()                                          # a new phase: every unresolved comment is wiped
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
		if how == "catch":
			resolve_marks(2)
	return super.hit(d, dx, dy, how, box)

func start() -> void:
	super.start()
	idle_t = 1.0

func hurtboxes() -> Array:
	return [{"x": x, "y": y, "w": w, "h": h}]

func _thrust_total() -> float:
	return DOUBLE_GAP * float(thrusts)

func _verdict_total() -> float:
	return VERDICT_GAP * 6.0

func harmboxes() -> Array:
	var b: Array = []
	if plan_active():
		match String(plan.id):
			"riposte":
				b.append({"x": x + 2, "y": y + 2, "w": w - 4, "h": h - 3})
				b.append({"x": x + w if face > 0.0 else x - 18.0, "y": y + 6, "w": 18.0, "h": 12.0, "sid": strike_sid, "catchable": true, "dmg": _big()})
			"double":
				var el := _thrust_total() - float(plan.t)
				var k := clampi(floori(el / DOUBLE_GAP), 0, thrusts - 1)
				var dirx := face if k % 2 == 0 else -face
				b.append({"x": cx if dirx > 0.0 else cx - BAND, "y": Boss.FLOOR - 24.0, "w": BAND, "h": 24.0, "dmg": _big()})
			"cross":
				b.append({"x": mark_x - 112.0, "y": Boss.FLOOR - 40.0, "w": 80.0, "h": 40.0})
				b.append({"x": mark_x + 32.0, "y": Boss.FLOOR - 40.0, "w": 80.0, "h": 40.0})
			"signoff":
				b.append({"x": minf(x0, mark_x - w / 2.0), "y": Boss.FLOOR - 30.0, "w": absf(mark_x - w / 2.0 - x0) + w, "h": 30.0, "sid": strike_sid, "catchable": false, "dmg": _big()})
			"slash":
				b.append({"x": x + w if face > 0.0 else x - 40.0, "y": Boss.FLOOR - 30.0, "w": 40.0, "h": 30.0, "sid": strike_sid, "catchable": false})
	b.append_array(hz_harm())
	return b

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if dying:
		hz.clear()
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
	pair_next = ""
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
	var ph := _phase_now()
	var tgt := kit_pick_target()
	if ph == 1:
		var seq1 := ["cached", "double", "verdict", "nitpick"]
		_start(seq1[cycle % seq1.size()], tgt)
	else:
		# phases 2 and 3: attacks come in pairs (0.4 s between them); phase 3 adds the chained sign-off
		var seq: Array = [["double", "verdict"], ["cross", "nitpick"], ["cached"]]
		if ph == 3:
			seq.append(["signoff"])
		var pr: Array = seq[cycle % seq.size()]
		pair_next = String(pr[1]) if pr.size() > 1 else ""
		pair_tgt = tgt
		_start(String(pr[0]), tgt)
	cycle += 1

func _face_to(px: float) -> void:
	var nf := Game.sign_of(px - cx)
	if nf != 0.0:
		face = nf

func _rec_first() -> float:
	return 0.4 if pair_next != "" else -1.0

func _start(id: String, tgt: String) -> void:
	var ap := kit_aim(tgt)
	_face_to(ap.x)
	match id:
		"cached":
			cached_kind = String(last_kind.get(tgt, "side"))
			plan_start("cached", "guard", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 1.0, _rec_first())
		"double":
			thrusts = 3 if _phase_now() == 3 else 2
			plan_start("double", "dual", tgt, [0.0, 0.0, 0.0, 0.0], 0.5, 0.75, _rec_first() if pair_next != "" else 0.6, _thrust_total())
		"verdict":
			shots = 0
			plan_start("verdict", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, _rec_first() if pair_next != "" else 0.6, _verdict_total())
		"nitpick":
			_nitpick_xs(ap.x)
			plan_start("nitpick", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.7, _rec_first() if pair_next != "" else 0.6)
		"cross":
			mark_x = clampf(ap.x, 64.0, Game.W - 64.0)
			plan_start("cross", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.5, 0.9, _rec_first() if pair_next != "" else 0.6)
		"signoff":
			mark_x = clampf(ap.x, 24.0, Game.W - 24.0)
			x0 = x
			plan_start("signoff", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.4, 0.75, 0.2)
		"slash":
			plan_start("slash", "slam", tgt, [x + w if face > 0.0 else x - 40.0, Boss.FLOOR - 30.0, 40.0, 30.0], 0.0, 0.45, 0.2)
		"sdiamond":
			plan_start("sdiamond", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.45, 0.7)
		"riposte":
			plan_start("riposte", "lunge", tgt, _riposte_fp(), 0.4, 0.75)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

# six pens at marked x's; a 64 px gap around the target's x stays free
func _nitpick_xs(tx: float) -> void:
	nit_gap = clampf(tx, 48.0, Game.W - 48.0)
	pen_xs = []
	var tries := 0
	while pen_xs.size() < 6 and tries < 200:
		tries += 1
		var px := room.rng.randf_range(24.0, Game.W - 24.0)
		if absf(px - nit_gap) < 40.0:
			continue
		var ok := true
		for q in pen_xs:
			if absf(float(q) - px) < 22.0:
				ok = false
		if ok:
			pen_xs.append(roundf(px))
	pen_xs.sort()

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
	if pid == "verdict" and plan.ph == "active":
		var el := _verdict_total() - float(plan.t)
		while shots < 6 and float(shots) * VERDICT_GAP <= el:
			_shoot_verdict(shots)
			shots += 1
	var tgt_now := String(plan.tgt)
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"riposte", "signoff", "slash":
					strike_sid = Game.next_strike_id()
					Audio.sfx("dash", {"vol": 0.7})
				"cross":
					room.shake(0.3)
					Audio.sfx("laser", {"vol": 0.6})
				"double":
					Audio.sfx("slash", {"vol": 0.7})
				"nitpick":
					_drop_pens()
				"sdiamond":
					_shoot_diamond(true)
		"recover":
			strike_sid = 0
			vx = 0.0
			if pid == "signoff":
				x = mark_x - w / 2.0
		"done":
			strike_sid = 0
			if pid == "signoff":
				_start("slash", tgt_now)
				return
			if pid == "slash":
				_start("sdiamond", tgt_now)
				return
			if pair_next != "":
				var nx := pair_next
				pair_next = ""
				_start(nx, pair_tgt if kit_alive(pair_tgt) else kit_pick_target())
				return
			idle_t = 0.5

func _shoot_diamond(yellow := true) -> void:
	var ap := kit_aim(plan.tgt)
	var ox := cx + face * 8.0
	var oy := y + 8.0
	var dist := maxf(60.0, Vector2(ap.x - ox, ap.y - oy).length())
	var a := atan2(ap.y - oy, ap.x - ox)
	var speed := clampf(dist / 0.7, 90.0, 190.0)
	room.shoot(ox, oy, cos(a) * speed, sin(a) * speed, {"kind": "diamond", "col": "#ffd23f", "r": 4.0, "catchable": yellow, "cut": true, "life": 3.0, "dmg": 1, "by_boss": true})
	Audio.sfx("shoot")

# a grey `reject`: lobbed to the target's x; where it lands it leaves a comment on the floor
func _shoot_grey() -> void:
	var ap := kit_aim(plan.tgt)
	var ox := cx + face * 8.0
	var oy := y + 6.0
	var tt := 0.8
	var g := 420.0
	var gx := clampf(ap.x, 16.0, Game.W - 16.0)
	var vyi := ((Boss.FLOOR - 3.0 - oy) - 0.5 * g * tt * tt) / tt
	room.shoot(ox, oy, (gx - ox) / tt, vyi, {"kind": "orb", "col": "#8d8798", "r": 4.0, "catchable": false, "cut": false, "life": 3.0, "dmg": 1, "by_boss": true, "g": g, "mark": true})
	Audio.sfx("shoot")

func _shoot_verdict(i: int) -> void:
	if _phase_now() >= 2:
		_shoot_diamond(true)
		_shoot_grey()
	elif i % 2 == 0:
		_shoot_diamond(true)
	else:
		_shoot_grey()

func _drop_pens() -> void:
	for px in pen_xs:
		room.shoot(float(px), 20.0, 0.0, 250.0, {"kind": "pen", "col": PEN, "r": 3.0, "catchable": false, "cut": false, "life": 3.0, "dmg": 1, "by_boss": true, "mark": true})
	Audio.sfx("laser", {"vol": 0.5})

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
	if plan_active() and (String(plan.id) == "double" or String(plan.id) == "cross" or String(plan.id) == "signoff" or String(plan.id) == "slash"):
		for hb in harmboxes():
			if hb.h > 7.0:
				ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.5))
	_draw_marks(ci)

# the unresolved comments: `//` on the floor, dim while they only warn, red and hatched when they hurt
func _draw_marks(ci: CanvasItem) -> void:
	for h in hz:
		var mx := float(h.v[0])
		var live := hz_live(h, room.time)
		var c := Color("#ff4f6d") if live else Color(0.85, 0.85, 0.9, 0.5)
		ci.draw_rect(Rect2(mx - 8.0, Boss.FLOOR - 6.0, 16.0, 6.0), Color(1.0, 0.31, 0.43, 0.55) if live else Color(0.55, 0.55, 0.6, 0.25))
		if live:
			ci.draw_rect(Rect2(mx - 8.0, Boss.FLOOR - 6.0, 16.0, 1), Color("#ffd0d8"))
		PixelText.draw_text(ci, "//", mx, Boss.FLOOR - 12.0, c, {"align": "c", "tiny": true, "outline": INK})

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
			for k in range(thrusts):
				var dirk := face if k % 2 == 0 else -face
				_hatch(ci, Rect2(cx if dirk > 0.0 else cx - BAND, Boss.FLOOR - 24.0 - float(k) * 2.0, BAND, 24.0), "%d" % (k + 1))
		"nitpick":
			for px in pen_xs:
				_hatch(ci, Rect2(float(px) - 6.0, 16.0, 12.0, Boss.FLOOR - 16.0))
			ci.draw_rect(Rect2(nit_gap - 32.0, Boss.FLOOR - 4.0, 64.0, 2), Color("#7fd08a"))
			PixelText.draw_text(ci, "SAFE", nit_gap, Boss.FLOOR - 20.0, "#7fd08a", {"align": "c", "tiny": true, "outline": INK})
		"slash":
			_hatch(ci, Rect2(x + w if face > 0.0 else x - 40.0, Boss.FLOOR - 30.0, 40.0, 30.0))
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
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, KINDS.find(cached_kind), roundi(mark_x), roundi(x0), 1 if dying else 0, thrusts, roundi(nit_gap)]
	f.append_array(plan_fields())
	f.append(pen_xs.duplicate())
	f.append(hz_pack())
	return f

const NF := 10

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
	thrusts = clampi(int(f[8]), 2, 3)
	nit_gap = float(f[9])
	passive = not active or dying
	phase = _phase_now()
	plan_apply(f.slice(NF, NF + 11))
	pen_xs = f[NF + 11] if f.size() > NF + 11 else []
	hz_unpack(f[NF + 12] if f.size() > NF + 12 else [])

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
