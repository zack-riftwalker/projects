class_name LoopBoss
extends Boss
# INFINITE LOOP (T10, MV5A-07): a ring snake of 12 segments that only gets hurt at the TAIL. A kit boss: every attack is announced, harm exists only
# in the active phase of a plan or in an arena hazard, and every position is a pure function of (mode, path_t, speed, ring_cx) that the guest
# reads from the net fields.
# The arena loops while the fight runs: the door rows 7-10 of both walls are a wrap portal for the players (and the snake). A body whose centre
# crosses x < 0 comes out on the right (each page moves its own body); outside the fight they are the usual fight-locked doors.
# The attacks always come in the order lap, nested, recursion; then the snake drops to the floor and the BREAK panel lights for 1.5 s (a hit freezes
# it for 3 s with its tail on the floor: free hits) and the iteration counter `i` (drawn on the wall) goes up. Every iteration is 15 % faster and from
# i = 2 each attack has an extra: a head lunge in the lap, the inner ring turning the other way, a fourth copy.
# Phase 3 (<= 30 %): the floor is a conveyor towards the head (40 px/s) and both side strips (x < 32, x > 352) hurt.

const IDS := ["lap", "nested", "recursion", "rest"]
const SEQ := ["lap", "nested", "recursion", "rest"]
const SEG_N := 12
const SEG_GAP := 12.0
const X0 := 22.0
const X1 := 362.0
const Y_TOP := 22.0
const Y_BOT := 170.0
const PERIM := 976.0
const LAP_END := 1656.0
const BASE_SPEED := 150.0
const COPY_SPEED := 130.0
const COPY_Y := [170.0, 146.0, 110.0, 170.0]
const COPY_DIR := [-1.0, 1.0, -1.0, 1.0]
const COPY_AT := [0.0, 0.9, 1.8, 2.7]
const COPY_LEN := 4
const RING_Y := 96.0
const RING_R := 88.0
const RING_r := 44.0
const PANEL := {"x": 180.0, "y": 84.0, "w": 24.0, "h": 24.0}
const BITE_ACT := 0.25
const FREEZE_T := 3.0
const PANEL_T := 1.5
const CONVEYOR := 40.0
const INK := "#1b1226"
const GREEN := "#3fbf8a"
const GREEN_HI := "#a8f0d0"
const GREEN_LO := "#1f6a4a"

var iter := 0
var cycle := 0
var idle_t := 0.0
var strike_sid := 0
var mode := "idle"                 # what the snake is doing now: idle | lap | nested | recursion | rest
var path_t := 0.0
var spd := 1.0
var panel_t := 0.0
var freeze_t := 0.0
var ring_cx := 192.0
var ring_dir2 := 1.0               # the inner ring's direction (1 = with the outer ring, -1 = against, from i = 2)
var phase_mem := 1
var strips_on := false
var bite_done := false

func _init(r: Room, bx: float, by: float, base_hp := 66) -> void:
	super(r, 192.0, 100.0, 12, 12, base_hp)
	boss_name = "INFINITE LOOP"
	sub = "while (true)"
	col = GREEN
	kit_init()

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["bite", "strip"]

func _big() -> int:
	return int(Game.dv("big_hit"))

func _phase_now() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.30 else (2 if f <= 0.65 else 1)

func _speed_k() -> float:
	return pow(1.15, float(mini(iter, 6)))

# ---- the path: a pure function of the arc length ----
func perimeter(arc: float) -> Vector2:
	var a := fposmod(arc, PERIM)
	if a < 340.0:
		return Vector2(X1 - a, Y_BOT)
	if a < 488.0:
		return Vector2(X0, Y_BOT - (a - 340.0))
	if a < 828.0:
		return Vector2(X0 + (a - 488.0), Y_TOP)
	return Vector2(X1, Y_TOP + (a - 828.0))

# lap 1 round the walls, then two passes along the floor (the second one comes out of the right portal, from behind). x < 14 = gone through the portal
func lap_point(arc: float) -> Vector2:
	if arc < PERIM:
		return perimeter(arc)
	var f := arc - PERIM
	if f < 340.0:
		return Vector2(X1 - f, Y_BOT)
	f -= 340.0
	var x := X1 - f
	if x < 14.0:
		return Vector2(-100.0, -100.0)
	return Vector2(x, Y_BOT)

func lap_len() -> float:
	return LAP_END + float(SEG_N) * SEG_GAP

func nested_len() -> float:
	return 7.0

func rec_len() -> float:
	return float(COPY_AT[3] if iter >= 2 else COPY_AT[2]) + (X1 - X0 + 100.0) / (COPY_SPEED * spd) + 0.3

func act_len(id: String) -> float:
	match id:
		"lap":
			return lap_len() / (BASE_SPEED * spd)
		"nested":
			return nested_len()
		"recursion":
			return rec_len()
		"rest":
			return PANEL_T
	return 1.0

func ring_omega() -> float:
	return 1.1 * spd

# the 12 segment centres at path time `t_` (head first). Vector2(-100, -100) = not on the field
func seg_points() -> Array:
	var out: Array = []
	match mode:
		"lap":
			var head := BASE_SPEED * spd * path_t
			for i in range(SEG_N):
				out.append(lap_point(head - SEG_GAP * float(i)))
		"nested":
			var w1 := ring_omega() * path_t
			var w2 := -ring_omega() * 1.4 * path_t * ring_dir2 if iter >= 2 else ring_omega() * 1.4 * path_t
			# 8 on the outer ring (the tail is its last), 4 on the inner ring
			for i in range(4):
				var a := w2 + float(i) * TAU / 4.0
				out.append(Vector2(ring_cx + cos(a) * RING_r, RING_Y + sin(a) * RING_r))
			for j in range(8):
				var b := w1 + float(j) * TAU / 8.0
				out.append(Vector2(ring_cx + cos(b) * RING_R, RING_Y + sin(b) * RING_R))
		"rest":
			for i in range(SEG_N):
				out.append(Vector2(336.0 - SEG_GAP * float(i), Y_BOT))
		_:
			for i in range(SEG_N):                                     # parked along the ceiling (not harmful)
				out.append(Vector2(204.0 + SEG_GAP * float(SEG_N - 1 - i), Y_TOP))
	return out

func copies() -> Array:
	var out: Array = []
	if mode != "recursion":
		return out
	var n := 4 if iter >= 2 else 3
	for c in range(n):
		var tt := path_t - float(COPY_AT[c])
		if tt < 0.0:
			continue
		var dirx: float = COPY_DIR[c]
		var hx: float = (X1 + 30.0 if dirx < 0.0 else X0 - 30.0) + dirx * COPY_SPEED * spd * tt
		if (dirx < 0.0 and hx < -80.0) or (dirx > 0.0 and hx > 464.0):
			continue
		var segs: Array = []
		for k in range(COPY_LEN):
			segs.append(Vector2(hx - dirx * SEG_GAP * float(k), COPY_Y[c]))
		out.append(segs)
	return out

func tail_point() -> Vector2:
	var p := seg_points()
	return p[SEG_N - 1]

func _box(p: Vector2, d := 1) -> Dictionary:
	return {"x": p.x - 6.0, "y": p.y - 6.0, "w": 12.0, "h": 12.0, "dmg": d}

func _tail_visible() -> bool:
	if mode == "idle" or mode == "recursion":
		return false
	var p := tail_point()
	return p.x > 0.0

func hurtboxes() -> Array:
	var b: Array = []
	if (plan_active() or freeze_t > 0.0 or (mode == "rest")) and _tail_visible():
		var p := tail_point()
		b.append({"x": p.x - 8.0, "y": p.y - 8.0, "w": 16.0, "h": 16.0, "tail": true})
	if panel_t > 0.0:
		b.append({"x": PANEL.x, "y": PANEL.y, "w": PANEL.w, "h": PANEL.h, "panel": true})
	return b

func harmboxes() -> Array:
	var b: Array = []
	if plan_active() and freeze_t <= 0.0:
		match mode:
			"lap", "nested", "rest":
				for p in seg_points():
					if p.x > 0.0:
						b.append(_box(p))
			"recursion":
				for segs in copies():
					for p in segs:
						b.append(_box(p))
	b.append_array(hz_harm())
	return b

# ---- arena hazards: a head lunge (bite) and the side strips of phase 3 ----
func hz_boxes(h: Dictionary, now: float) -> Array:
	var el := now - float(h.t0) - float(h.warn)
	match String(h.k):
		"bite":
			if el > BITE_ACT:
				return []
			return [{"x": float(h.v[0]) - 14.0, "y": float(h.v[1]) - 14.0, "w": 28.0, "h": 28.0, "dmg": _big()}]
		"strip":
			if int(h.v[0]) == 0:
				return [{"x": 0.0, "y": 0.0, "w": 32.0, "h": Boss.FLOOR, "dmg": 1}]
			return [{"x": 352.0, "y": 0.0, "w": 32.0, "h": Boss.FLOOR, "dmg": 1}]
	return []

func _hz_expired(h: Dictionary, now: float) -> bool:
	return String(h.k) == "bite" and now - float(h.t0) - float(h.warn) > BITE_ACT + 0.3

# ---- damage ----
func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	if d >= 9999:                                             # "skip boss"
		hpf = 0.0
		hp = 0
		begin_death()
		return "kill"
	if box is Dictionary and box.has("panel"):
		if panel_t <= 0.0:
			return ""
		panel_t = 0.0
		freeze_t = FREEZE_T
		mode = "rest"
		plan_cut()
		idle_t = FREEZE_T + 0.5
		room.pop(PANEL.x + 12.0, PANEL.y - 8.0, "break;", "#ffd23f", true)
		room.shake(0.4)
		Audio.sfx("gate")
		return "hit"
	if not (box is Dictionary and box.has("tail")):
		return ""
	var dm := float(d)
	if how == "agent" or how == "dash":
		dm *= 0.5
	hpf -= dm
	hp = ceili(hpf)
	flash = 0.1
	var tp := tail_point()
	room.burst(tp.x, tp.y, 6, [GREEN, "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	room.boss_damage(self, dm, how)
	var key := kit_key_of(room.attacker)
	if read != null and key != "":
		read.note_hit(key, how)
	on_damage()
	if hpf <= 0.0 and not dying:
		hp = 0
		hpf = 0.0
		begin_death()
		return "kill"
	return "hit"

func on_damage() -> void:
	var p := _phase_now()
	if p != phase_mem:
		phase_mem = p
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

func begin_death() -> void:
	super.begin_death()
	hz.clear()
	panel_t = 0.0
	freeze_t = 0.0
	mode = "idle"

func start() -> void:
	super.start()
	idle_t = 1.2
	spd = 1.0
	phase_mem = _phase_now()

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if dying:
		death_rattle(dt, 2.4, ["#ffffff", GREEN, GREEN_HI])
		return
	if not active:
		return
	_wrap_player()
	phase = _phase_now()
	hz = hz.filter(func(h): return not _hz_expired(h, room.time))
	spd = _speed_k()
	if freeze_t > 0.0:
		freeze_t -= dt
		if freeze_t <= 0.0:
			mode = "idle"
	if panel_t > 0.0:
		panel_t -= dt
	if _phase_now() == 3 and not strips_on:
		strips_on = true
		hz_add("strip", 1.0, [0])
		hz_add("strip", 1.0, [1])
		room.pop(192.0, 60.0, "while (true)", "#ff4f6d", true)
	if strips_on:
		_conveyor(dt)
	# the rings hunt the target (slowly)
	var tgt: String = String(plan.tgt) if not plan.is_empty() else ""
	if tgt != "" and kit_alive(tgt) and (String(plan.get("id", "")) == "nested"):
		ring_cx = move_toward(ring_cx, clampf(kit_aim(tgt).x, 120.0, 264.0), 45.0 * dt)
	if plan.is_empty():
		plan_clock += dt
		if freeze_t <= 0.0:
			idle_t -= dt
			if idle_t <= 0.0:
				_choose()
	else:
		_plan_logic(dt)
	var hp_ := tail_point() if mode != "idle" else Vector2(192.0, 100.0)
	x = hp_.x - w / 2.0
	y = hp_.y - h / 2.0

# the arena loops: the local body that leaves through a portal comes out of the other one
func _wrap_player() -> void:
	var p = room.player
	if p == null or p.dead:
		return
	var mid: float = p.x + p.w / 2.0
	if mid < 0.0:
		p.x += float(room.pw)
	elif mid > float(room.pw):
		p.x -= float(room.pw)

# phase 3: the floor carries a body towards the head
func _conveyor(dt: float) -> void:
	var p = room.player
	if p == null or p.dead or not p.on_ground:
		return
	var hx: float = tail_point().x if mode == "idle" else seg_points()[0].x
	if hx <= 0.0:
		hx = 192.0
	var dirx := Game.sign_of(hx - (p.x + p.w / 2.0))
	if dirx != 0.0:
		room.grid.move_x(p, dirx * CONVEYOR * dt)

func _choose() -> void:
	var id: String = SEQ[cycle % SEQ.size()]
	cycle += 1
	_start(id)

func _start(id: String, force_tgt := "") -> void:
	var tgt := kit_pick_target() if force_tgt == "" else force_tgt
	var cue := 0.8
	var rec := 0.6
	var fam := "sweep"
	match id:
		"lap":
			cue = 0.75
			rec = 0.6
		"nested":
			cue = 0.8
			rec = 0.6
			ring_cx = clampf(kit_aim(tgt).x, 120.0, 264.0)
			ring_dir2 = -1.0 if iter >= 2 else 1.0
		"recursion":
			cue = 0.8
			rec = 0.7
		"rest":
			cue = 0.5
			rec = 0.5
			fam = "guard"
	spd = _speed_k()
	plan_start(id, fam, tgt, [0.0, 0.0, 0.0, 0.0], 0.0, cue, rec, act_len(id))
	bite_done = false
	mode_cue = id
	Game.dlog("%s attack %s on %s (iteration %d, plan %d)" % [boss_name, id, tgt, iter, plan.seq])

var mode_cue := "idle"             # what the cue in progress announces (drawn as an outline)

func _plan_logic(dt: float) -> void:
	var pid := String(plan.id)
	if plan.ph == "active":
		path_t += dt
		if pid == "lap" and iter >= 2 and not bite_done and path_t >= act_len("lap") * 0.45:
			bite_done = true                                      # the head lunges at the target mid-lap (2 damage, cue 0.75)
			var ap := kit_aim(String(plan.tgt))
			hz_add("bite", 0.75, [roundi(clampf(ap.x, 24.0, 360.0)), roundi(clampf(ap.y, 40.0, Boss.FLOOR - 8.0))])
	var ev := plan_step(dt)
	match ev:
		"active":
			strike_sid = Game.next_strike_id()
			mode = pid
			path_t = 0.0
			if pid == "rest":
				panel_t = PANEL_T
				Audio.sfx("thud", {"vol": 0.8})
				room.shake(0.4)
			else:
				Audio.sfx("dash", {"vol": 0.6})
		"recover":
			strike_sid = 0
			if freeze_t <= 0.0:
				mode = "idle"
			panel_t = 0.0
		"done":
			strike_sid = 0
			if pid == "rest":
				iter += 1
				room.pop(192.0, 40.0, "i++", "#ffd23f", true)
				Audio.sfx("tick")
			idle_t = 0.5

# ---- drawing ----
func _segment(ci: CanvasItem, p: Vector2, i: int, lit: bool) -> void:
	var ink := Color(INK)
	var c := Color(GREEN) if i % 2 == 0 else Color("#2fa070")
	if lit:
		c = Color.WHITE
	ci.draw_rect(Rect2(floorf(p.x) - 7.0, floorf(p.y) - 7.0, 14.0, 14.0), ink)
	ci.draw_rect(Rect2(floorf(p.x) - 6.0, floorf(p.y) - 6.0, 12.0, 12.0), c)
	ci.draw_rect(Rect2(floorf(p.x) - 6.0, floorf(p.y) - 6.0, 12.0, 2.0), Color(GREEN_HI))
	ci.draw_rect(Rect2(floorf(p.x) - 2.0, floorf(p.y) + 1.0, 4.0, 2.0), Color(GREEN_LO))

func _head(ci: CanvasItem, p: Vector2, facing: float) -> void:
	var ink := Color(INK)
	ci.draw_rect(Rect2(floorf(p.x) - 8.0, floorf(p.y) - 8.0, 16.0, 16.0), ink)
	ci.draw_rect(Rect2(floorf(p.x) - 7.0, floorf(p.y) - 7.0, 14.0, 14.0), Color(GREEN))
	ci.draw_rect(Rect2(floorf(p.x) - 7.0, floorf(p.y) - 7.0, 14.0, 3.0), Color(GREEN_HI))
	var ex := 1.0 if facing >= 0.0 else -5.0
	ci.draw_rect(Rect2(floorf(p.x) + ex, floorf(p.y) - 4.0, 4.0, 4.0), Color.WHITE)
	ci.draw_rect(Rect2(floorf(p.x) + ex + 1.0, floorf(p.y) - 3.0, 2.0, 2.0), Color("#ff4f6d"))

func _draw_snake(ci: CanvasItem, pts: Array, lit_tail: bool) -> void:
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		if p.x < 0.0:
			continue
		if i == 0:
			var nxt: Vector2 = pts[1] if pts.size() > 1 else p
			_head(ci, p, Game.sign_of(p.x - nxt.x))
		elif i == pts.size() - 1:
			_segment(ci, p, i, flash > 0.0)
			ci.draw_rect(Rect2(floorf(p.x) - 3.0, floorf(p.y) - 3.0, 6.0, 6.0), Color("#ffd23f") if lit_tail else Color("#c8a05a"))   # the tail tip: the only part that can be hurt
		else:
			_segment(ci, p, i, false)

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

func draw_boss_body(ci: CanvasItem) -> void:
	# the panel on the back wall
	var lit: bool = panel_t > 0.0
	ci.draw_rect(Rect2(PANEL.x - 2.0, PANEL.y - 2.0, PANEL.w + 4.0, PANEL.h + 4.0), Color(INK))
	ci.draw_rect(Rect2(PANEL.x, PANEL.y, PANEL.w, PANEL.h), Color("#ffd23f") if (lit and int(t * 10.0) % 2 == 0) else (Color("#fff3b0") if lit else Color("#3a3346")))
	PixelText.draw_text(ci, "break;", PANEL.x + PANEL.w / 2.0, PANEL.y + 9.0, INK if lit else "#6b6478", {"align": "c", "tiny": true})
	if lit:
		ci.draw_rect(Rect2(PANEL.x, PANEL.y + PANEL.h + 3.0, PANEL.w * clampf(panel_t / PANEL_T, 0.0, 1.0), 2.0), Color("#ffd23f"))
	# i = n is drawn by the room (the loop room's wall); the iteration is also on the snake's belly via the counter below the panel
	PixelText.draw_text(ci, "i = %d" % iter, 192.0, 48.0, "#3a4a5a", {"scale": 3, "align": "c"})
	if dying and gone:
		return
	var parked := mode == "idle" or mode == "recursion"
	if mode == "lap" or mode == "nested" or mode == "rest" or parked:
		var pts := seg_points()
		if parked:
			for i in range(pts.size()):
				pts[i] = Vector2(pts[i].x, Y_TOP)
			_draw_snake_dim(ci, pts)
		else:
			_draw_snake(ci, pts, plan_active() or freeze_t > 0.0)
	for segs in copies():
		_draw_snake(ci, segs, false)
	if freeze_t > 0.0:
		var tp := tail_point()
		PixelText.draw_text(ci, "BREAK %.1f" % freeze_t, tp.x, tp.y - 18.0, "#7cc4ff", {"align": "c", "tiny": true, "outline": INK})
		ci.draw_rect(Rect2(tp.x - 10.0, tp.y - 10.0, 20.0, 20.0), Color("#7cc4ff"), false, 1.0)
	_draw_hazards(ci)

func _draw_snake_dim(ci: CanvasItem, pts: Array) -> void:
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		ci.draw_rect(Rect2(floorf(p.x) - 6.0, floorf(p.y) - 6.0, 12.0, 12.0), Color(0.12, 0.35, 0.28, 0.5))

func _draw_hazards(ci: CanvasItem) -> void:
	for h in hz:
		var live := hz_live(h, room.time)
		match String(h.k):
			"strip":
				var left: bool = int(h.v[0]) == 0
				var sx: float = 0.0 if left else 352.0
				if live:
					ci.draw_rect(Rect2(sx, 0.0, 32.0, Boss.FLOOR), Color(0.25, 0.75, 0.55, 0.45))
					for k in range(0, int(Boss.FLOOR), 12):
						ci.draw_rect(Rect2(sx + (4.0 if left else 18.0), float(k) + fposmod(t * 40.0, 12.0), 10.0, 6.0), Color(GREEN_HI))
				elif int(t * 10.0) % 2 == 0:
					ci.draw_rect(Rect2(sx, 0.0, 32.0, Boss.FLOOR), Color(1.0, 0.3, 0.4, 0.3))
			"bite":
				var bx: float = float(h.v[0])
				var by: float = float(h.v[1])
				if not live:
					_hatch(ci, Rect2(bx - 14.0, by - 14.0, 28.0, 28.0))
					ci.draw_line(Vector2(x + w / 2.0, y + h / 2.0), Vector2(bx, by), Color(1.0, 0.31, 0.43, 0.5), 1.0)
					PixelText.draw_text(ci, "!", bx, by - 4.0, Game.COL.hazardHi, {"align": "c", "outline": INK})
				else:
					ci.draw_rect(Rect2(bx - 14.0, by - 14.0, 28.0, 28.0), Color(1.0, 0.31, 0.43, 0.7))
					ci.draw_rect(Rect2(bx - 12.0, by - 4.0, 24.0, 8.0), Color.WHITE)

func draw_boss_overlay(ci: CanvasItem) -> void:
	if plan.is_empty() or plan.ph != "cue":
		return
	match String(plan.id):
		"lap":
			_hatch(ci, Rect2(X0 - 8.0, Y_BOT - 8.0, X1 - X0 + 16.0, 16.0))
			PixelText.draw_text(ci, "lap", 192.0, Y_BOT - 22.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
			ci.draw_rect(Rect2(X1 - 6.0, Y_BOT - 22.0, 12.0, 2.0), Color("#ffd23f"))
		"nested":
			ci.draw_arc(Vector2(ring_cx, RING_Y), RING_R, 0.0, TAU, 40, Color(1.0, 0.8, 0.3, 0.6), 1.0)
			ci.draw_arc(Vector2(ring_cx, RING_Y), RING_r, 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.6), 1.0)
			ci.draw_arc(Vector2(ring_cx, RING_Y), (RING_R + RING_r) / 2.0, 0.0, TAU, 40, Color(0.5, 0.9, 0.55, 0.5), 1.0)   # the safe band between the rings
			PixelText.draw_text(ci, "nested", ring_cx, RING_Y - 6.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
		"recursion":
			var n := 4 if iter >= 2 else 3
			for c in range(n):
				_hatch(ci, Rect2(X0 - 4.0, float(COPY_Y[c]) - 7.0, X1 - X0 + 8.0, 14.0))
				var ax: float = X0 + 6.0 if COPY_DIR[c] > 0.0 else X1 - 6.0
				PixelText.draw_text(ci, ">" if COPY_DIR[c] > 0.0 else "<", ax, float(COPY_Y[c]) - 3.0, "#ffffff", {"align": "c", "outline": INK})
		"rest":
			ci.draw_rect(Rect2(PANEL.x - 4.0, PANEL.y - 4.0, PANEL.w + 8.0, PANEL.h + 8.0), Color("#ffd23f"), false, 1.0)
			PixelText.draw_text(ci, "hit it", PANEL.x + 12.0, PANEL.y - 12.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, iter, ["idle", "lap", "nested", "recursion", "rest"].find(mode), roundi(path_t * 100.0),
		roundi(spd * 100.0), roundi(maxf(panel_t, 0.0) * 100.0), roundi(maxf(freeze_t, 0.0) * 100.0), roundi(ring_cx), int(ring_dir2), 1 if strips_on else 0,
		["idle", "lap", "nested", "recursion", "rest"].find(mode_cue)]
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 14

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	strike_sid = int(f[3])
	iter = int(f[4])
	mode = ["idle", "lap", "nested", "recursion", "rest"][clampi(int(f[5]), 0, 4)]
	path_t = f[6] / 100.0
	spd = f[7] / 100.0
	panel_t = f[8] / 100.0
	freeze_t = f[9] / 100.0
	ring_cx = float(f[10])
	ring_dir2 = float(f[11])
	strips_on = int(f[12]) == 1
	mode_cue = ["idle", "lap", "nested", "recursion", "rest"][clampi(int(f[13]), 0, 4)]
	phase = _phase_now()
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])
	var hp_ := tail_point() if mode != "idle" else Vector2(192.0, 100.0)
	x = hp_.x - w / 2.0
	y = hp_.y - h / 2.0

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	if active and not plan.is_empty() and plan.ph == "active":
		path_t += dt                                            # (the snapshot corrects it: the path is a function of path_t)
	if panel_t > 0.0:
		panel_t -= dt
	if freeze_t > 0.0:
		freeze_t -= dt
	if active:
		_wrap_player()
		if strips_on:
			_conveyor(dt)
