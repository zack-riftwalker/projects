class_name CrawlerBoss
extends Boss
# WEB CRAWLER (MVB2-07): a spider on a ceiling graph of four nodes. Its core hangs on a thread under a node, out of reach, and only comes down
# in the recovery of a drop, a sweep or a backtrack, or when a yellow packet is caught back into it. A kit boss: every attack is announced
# (cue), harm exists only in its active phase and comes from the plan and the net fields; the guest builds the same boxes.
# Rule 8: `move` goes to the node above whoever stood under the core longest in the last second.

const IDS := ["move", "drop", "volley", "sweep", "back"]
const NODES := [Vector2(56, 40), Vector2(144, 32), Vector2(240, 32), Vector2(328, 40)]
const THREAD := 18.0
const LEG_W := 12.0
const SEQ := {1: ["move", "drop", "volley", "drop"], 2: ["move", "drop", "sweep", "volley"], 3: ["back", "drop", "sweep", "volley"]}
const BRASS := "#5ad1ff"
const INK := "#1b1226"

var node := 1
var prev_node := 0
var core_px := 144.0              # the core's x (it follows its node)
var core_y := 50.0                # the core's centre y
var down := false                 # the core is coming down (or is down) because of a recovery
var down_t := 0.0                 # caught packet: down for this long
var leg_x := 0.0
var leg_on := 0
var gap_x := 192.0                # sweep: the middle of the safe lane
var move_to := 1
var cycle := 0
var idle_t := 0.0
var volley_n := 0
var volley_t := 0.0
var strike_sid := 0

func _init(r: Room, bx: float, by: float, base_hp := 56) -> void:
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

func _place() -> void:
	x = core_px - w / 2.0
	y = core_y - h / 2.0

func _rest_y() -> float:
	return float(NODES[node].y) + THREAD

func hurtboxes() -> Array:
	var b: Array = [{"x": core_px - 12.0, "y": core_y - 8.0, "w": 24.0, "h": 16.0}]
	if leg_on == 1 and plan_phase() == "recover":                   # the planted leg's lower 48 px hurt it too (a pogo on the leg works)
		b.append({"x": leg_x - LEG_W / 2.0, "y": Boss.FLOOR - 48.0, "w": LEG_W, "h": 48.0})
	return b

# only the plan hurts, and only while it is active
func harmboxes() -> Array:
	var b: Array = []
	if not plan_active():
		return b
	match String(plan.id):
		"drop":
			b.append({"x": leg_x - LEG_W / 2.0, "y": core_y, "w": LEG_W, "h": Boss.FLOOR - core_y, "sid": strike_sid, "catchable": false})
		"sweep":
			b.append({"x": 0.0, "y": Boss.FLOOR - 40.0, "w": maxf(0.0, gap_x - 32.0), "h": 40.0})
			b.append({"x": gap_x + 32.0, "y": Boss.FLOOR - 40.0, "w": maxf(0.0, Game.W - gap_x - 32.0), "h": 40.0})
		"back":
			b.append({"x": leg_x - 52.0, "y": 0.0, "w": 24.0, "h": Boss.FLOOR})
			b.append({"x": leg_x + 28.0, "y": 0.0, "w": 24.0, "h": Boss.FLOOR})
	return b

func _phase_now() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.25 else (2 if f <= 0.60 else 1)

func on_damage() -> void:
	var p := _phase_now()
	if p != phase:
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if active and not dying and how == "catch":
		down_t = 1.6                                      # a packet caught back into the core: the core comes down, a cable snaps
		room.burst(core_px, core_y - 10.0, 8, [BRASS, "#d6f6ff"], 90.0, 100.0)
		Audio.sfx("clang")
	return super.hit(d, dx, dy, how, b)

func start() -> void:
	super.start()
	idle_t = 1.0

func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	_ease(dt)
	if dying:
		down = true
		death_rattle(dt, 2.4, ["#ffffff", "#d6f6ff", BRASS, "#2a6fa8"])
		_place()
		return
	if not active:
		_place()
		return
	if down_t > 0.0:
		down_t -= dt
	if plan.is_empty():
		idle_t -= dt
		plan_clock += dt
		if idle_t <= 0.0:
			_choose()
	else:
		_plan_logic(dt)
	_place()

func _ease(dt: float) -> void:
	var want_y := float(Boss.FLOOR - 70.0) if (down or down_t > 0.0 or dying) else _rest_y()
	core_y = move_toward(core_y, want_y, 160.0 * dt)
	if plan.is_empty() or String(plan.id) != "move" or plan.ph != "active":
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
	var seq: Array = SEQ[_phase_now()]
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	_start(id)

func _start(id: String) -> void:
	down = false
	var tgt := kit_pick_target()
	var ap := kit_aim(tgt)
	match id:
		"move":
			move_to = _pick_node()
			plan_start("move", "sweep", tgt, [0.0, 0.0, 0.0, 0.0])
		"drop":
			leg_x = clampf(ap.x, 16.0, Game.W - 16.0)
			plan_start("drop", "slam", tgt, [leg_x - 16.0, Boss.FLOOR - 112.0, 32.0, 112.0], 0.5)
		"volley":
			plan_start("volley", "proj", tgt, [0.0, 0.0, 0.0, 0.0])
		"sweep":
			gap_x = clampf(ap.x, 64.0, 320.0)
			plan_start("sweep", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.5)
		"back":
			leg_x = float(NODES[prev_node].x)
			plan_start("back", "dual", tgt, [0.0, 0.0, 0.0, 0.0])
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _plan_logic(dt: float) -> void:
	# the aim follows the target through the cue; the last `lock` seconds it is fixed
	if plan.ph == "cue" and plan.t > float(plan.lock):
		var ap := kit_aim(plan.tgt)
		if plan.id == "drop":
			leg_x = clampf(ap.x, 16.0, Game.W - 16.0)
			plan.fp = [leg_x - 16.0, Boss.FLOOR - 112.0, 32.0, 112.0]
		elif plan.id == "sweep":
			gap_x = clampf(ap.x, 64.0, 320.0)
	if plan.ph == "active" and plan.id == "move":
		var nxp := float(NODES[move_to].x)
		core_px = move_toward(core_px, nxp, absf(nxp - core_px) / maxf(0.05, plan.t + 0.02) * dt)
	if plan.ph == "active" and plan.id == "volley":
		volley_t -= dt
		if volley_t <= 0.0 and volley_n < 3:
			volley_n += 1
			volley_t = 0.25
			_shoot_packet()
	var ev := plan_step(dt)
	match ev:
		"active":
			match String(plan.id):
				"drop":
					leg_on = 1
					strike_sid = Game.next_strike_id()
					room.shake(0.4)
					Audio.sfx("thud")
				"volley":
					volley_n = 0
					volley_t = 0.0
				"sweep":
					room.shake(0.3)
					Audio.sfx("laser", {"vol": 0.6})
				"back":
					prev_node = node
					core_px = float(NODES[prev_node].x)
					room.shake(0.5)
					Audio.sfx("thud")
		"recover":
			strike_sid = 0
			match String(plan.id):
				"drop", "sweep", "back":
					down = true
				"move":
					prev_node = node
					node = move_to
	if ev == "done":
		leg_on = 0
		idle_t = 0.8

func _shoot_packet() -> void:
	var ap := kit_aim(plan.tgt)
	var ox := core_px
	var oy := core_y + 8.0
	var dist := Vector2(ap.x - ox, ap.y - oy).length()
	if dist < 60.0:
		dist = 60.0
	var a := atan2(ap.y - oy, ap.x - ox)
	var speed := clampf(dist / 0.7, 80.0, 190.0)
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

func draw_boss_body(ci: CanvasItem) -> void:
	var ink := Color(INK)
	var br := Color(BRASS)
	# the node graph: rings joined by lines; a pulse on the next node during a move cue
	for i in range(NODES.size() - 1):
		ci.draw_line(NODES[i], NODES[i + 1], Color(br.r, br.g, br.b, 0.5), 1.0)
	for i in range(NODES.size()):
		ci.draw_arc(NODES[i], 6.0, 0.0, TAU, 14, ink, 3.0)
		ci.draw_arc(NODES[i], 6.0, 0.0, TAU, 14, br if not dying else Color("#3a4a5a"), 1.0)
	if plan_phase() == "cue" and not plan.is_empty():
		if plan.id == "move":
			var pn: Vector2 = NODES[move_to]
			ci.draw_arc(pn, 8.0 + sin(t * 14.0) * 2.0, 0.0, TAU, 14, Color("#d6f6ff"), 1.0)
		elif plan.id == "back":
			var bp: Vector2 = NODES[prev_node]
			PixelText.draw_text(ci, "BACK", bp.x, bp.y - 16.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
			ci.draw_arc(bp, 9.0 + sin(t * 14.0) * 2.0, 0.0, TAU, 14, Color("#ffd23f"), 1.0)
	# the thread and the core
	ci.draw_line(Vector2(core_px, float(NODES[node].y)), Vector2(core_px, core_y - 8.0), Color("#c3bccd"), 1.0)
	var cxp := floorf(core_px)
	var cyp := floorf(core_y)
	# eight legs: two segments each, up to the ceiling; a planted leg is a column to the floor
	for i in range(8):
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := float(i / 2)
		var knee := Vector2(cxp + side * (14.0 + k * 9.0), cyp - 10.0 - k * 3.0 + sin(t * 3.0 + float(i)) * 1.5)
		var foot := Vector2(cxp + side * (24.0 + k * 16.0), maxf(6.0, cyp - 34.0 - k * 6.0))
		ci.draw_line(Vector2(cxp + side * 6.0, cyp - 4.0), knee, ink, 3.0)
		ci.draw_line(knee, foot, ink, 3.0)
		ci.draw_line(Vector2(cxp + side * 6.0, cyp - 4.0), knee, Color("#2a6fa8"), 1.0)
		ci.draw_line(knee, foot, Color("#2a6fa8"), 1.0)
	if leg_on == 1:
		ci.draw_rect(Rect2(leg_x - LEG_W / 2.0 - 1.0, cyp, LEG_W + 2.0, Boss.FLOOR - cyp), ink)
		ci.draw_rect(Rect2(leg_x - LEG_W / 2.0 + 1.0, cyp, LEG_W - 2.0, Boss.FLOOR - cyp), Color("#2a6fa8"))
		ci.draw_rect(Rect2(leg_x - 3.0, cyp, 2, Boss.FLOOR - cyp), Color("#5ad1ff"))
	ci.draw_rect(Rect2(cxp - 13.0, cyp - 9.0, 26, 18), ink)
	ci.draw_rect(Rect2(cxp - 12.0, cyp - 8.0, 24, 16), Color("#24306a"))
	ci.draw_rect(Rect2(cxp - 12.0, cyp - 8.0, 24, 3), Color("#3a4a9a"))
	ci.draw_rect(Rect2(cxp - 7.0, cyp - 3.0, 4, 3), Color(Game.COL.hazard))
	ci.draw_rect(Rect2(cxp + 3.0, cyp - 3.0, 4, 3), Color(Game.COL.hazard))
	ci.draw_rect(Rect2(cxp - 5.0, cyp + 3.0, 10, 2), ink)
	# the sweep strands: during the active phase two bands lie on the floor
	if plan_active() and plan.id == "sweep":
		for hb in harmboxes():
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(0.45, 0.8, 1.0, 0.75))
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, 2), Color("#d6f6ff"))
	if plan_active() and plan.id == "back":
		for hb in harmboxes():
			ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(0.45, 0.8, 1.0, 0.7))

func draw_boss_overlay(ci: CanvasItem) -> void:
	draw_plan(ci)
	if plan.is_empty() or plan.ph != "cue":
		return
	if plan.id == "sweep":
		_hatch(ci, Rect2(0.0, Boss.FLOOR - 40.0, maxf(0.0, gap_x - 32.0), 40.0))
		_hatch(ci, Rect2(gap_x + 32.0, Boss.FLOOR - 40.0, maxf(0.0, Game.W - gap_x - 32.0), 40.0))
		PixelText.draw_text(ci, "SAFE", gap_x, Boss.FLOOR - 30.0, "#7fd08a", {"align": "c", "tiny": true, "outline": INK})
	elif plan.id == "back":
		_hatch(ci, Rect2(leg_x - 52.0, 0.0, 24.0, Boss.FLOOR))
		_hatch(ci, Rect2(leg_x + 28.0, 0.0, 24.0, Boss.FLOOR))
		PixelText.draw_text(ci, "1", leg_x - 40.0, 90.0, "#ffffff", {"align": "c", "outline": INK})
		PixelText.draw_text(ci, "2", leg_x + 40.0, 90.0, "#ffffff", {"align": "c", "outline": INK})
		PixelText.draw_text(ci, "SAFE", leg_x, Boss.FLOOR - 30.0, "#7fd08a", {"align": "c", "tiny": true, "outline": INK})

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid, node, prev_node, roundi(core_y), roundi(leg_x), leg_on, roundi(gap_x), roundi(core_px), 1 if (down or down_t > 0.0) else 0]
	f.append_array(plan_fields())
	return f

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
	gap_x = float(f[9])
	core_px = float(f[10])
	down = int(f[11]) == 1
	phase = _phase_now()
	plan_apply(f.slice(12))
	_place()

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
