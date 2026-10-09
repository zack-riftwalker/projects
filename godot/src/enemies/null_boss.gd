class_name NullBoss
extends Boss
# NULL, the null pointer. Port of `class Null` (js/bosses.js) plus the v2 attacks of docs/PLAN-metroidvania-phase2.md MV2-06:
# dangling pointer, dereference and the feint poke in phase 2. Telegraphs times telegraph_mult, punish windows times punish_mult.

const W := 384.0
const PHASE1 := ["poke", "rain", "sweep"]
const PHASE2 := ["poke", "dangling", "sweep", "rain", "deref", "pokefeint"]

var cur := {"x": 0.0, "y": 0.0, "a": 0.0, "mode": "orbit", "vx": 0.0, "vy": 0.0, "t": 0.0}
var cycle := 0
var tx := 0.0
var ty := 0.0
var rain_marks: Array = []            # rain columns {x, t}
var dmarks: Array = []           # dangling pointers {x, y}
var aim := Vector2.ZERO
var aim_from := Vector2.ZERO
var trail: Array = []
var dir := 1
var poke_i := 0
var feint_at := -1
var feint_done := false
var jerk_t := 0.0
var land := Vector2.ZERO         # dereference landing point
var deref_from := Vector2.ZERO
var deref_dur := 0.7
var fade := 1.0
var target = null
var trail_node: DrawProxy

func _init(r: Room, bx: float, by: float, base_hp := 60) -> void:
	super(r, bx, by - 30.0, 26, 36, base_hp)
	boss_name = "NULL"
	sub = "the null pointer"
	col = "#bfe9ff"
	cur.x = cx - 30.0
	cur.y = cy
	tx = x
	ty = y

func _ready() -> void:
	trail_node = DrawProxy.new()
	trail_node.cb = draw_trails
	trail_node.material = Boss.tint_material()
	trail_node.z_index = -1
	add_child(trail_node)
	super._ready()

func _process(dt: float) -> void:
	super._process(dt)
	trail_node.queue_redraw()

func _tm() -> float:
	return float(Game.dv("telegraph_mult"))

func _pm(base: float) -> float:
	return maxf(0.4, base * float(Game.dv("punish_mult")))

func _idle_time(base: float) -> float:
	return base * (0.8 if phase == 2 else 1.0)

func on_damage() -> void:
	if phase == 1 and hpf <= max_hp / 2.0:
		phase = 2
		cycle = 0
		room.events.append("bossPhase")
		room.shake(0.6)
		room.flash_screen(0.5, "#bfe9ff")
		Audio.sfx("glitch")
		set_state("idle", 1.4)
		cur.mode = "orbit"
		rain_marks.clear()
		dmarks.clear()
		fade = 1.0

# who NULL aims at: the player who dealt the most damage in the last 5 s, unless it is far away or down (co-op); alone: the player
func pick_target():
	var ps: Array = room.players()
	if ps.is_empty():
		return room.player
	var best = ps[0]
	var bd := -1.0
	for q in ps:
		var d: float = room.recent_damage(q, 5.0)
		if d > bd:
			bd = d
			best = q
	if target != null and target in ps:
		var near: bool = absf(target.x - cx) < 200.0
		if near and bd <= room.recent_damage(target, 5.0) + 0.001:
			best = target
	target = best
	return best

func update(dt: float) -> void:
	tick(dt)
	var c := cur
	var fast := phase == 2
	if dying:
		y += sin(t * 40.0) * 0.6
		if room.rng.randf() < 0.3:
			Audio.sfx("glitch", {"vol": 0.3})
		death_rattle(dt, 2.2, ["#ffffff", "#bfe9ff", "#3d5a80"])
		return
	if not active:
		y += sin(t * 2.0) * 0.2
		orbit(dt)
		return
	st_t -= dt
	var p = pick_target()
	var pcx: float = p.x + 5
	var pcy: float = p.y + 5
	dmg = 1
	match st:
		"idle":
			var side := 1.0 if pcx < W / 2.0 else -1.0
			tx = W / 2.0 + side * 96.0 - w / 2.0
			ty = 96.0 + sin(t * 2.0) * 8.0
			fade = move_toward(fade, 1.0, dt * 4.0)
			if st_t <= 0.0:
				var seq: Array = PHASE2 if fast else PHASE1
				var pick: String = seq[cycle % seq.size()]
				cycle += 1
				match pick:
					"poke", "pokefeint":
						set_state("poke", 0.0)
						n = 5 if fast else 3
						poke_i = 0
						feint_done = false
						feint_at = room.rng.randi_range(1, n - 1) if pick == "pokefeint" else -1
						c.mode = "aim"
						c.t = (0.5 if fast else 0.7) * _tm()
						pick_aim()
					"rain":
						set_state("rain", 0.6)
						n = 4 if fast else 3
					"sweep":
						set_state("sweepPrep", 0.9 * _tm())
						dir = -1 if pcx < W / 2.0 else 1
					"dangling":
						start_dangling(p)
					"deref":
						start_deref(p)
		"poke":
			ty = 70.0 + sin(t * 2.0) * 6.0
			if c.mode == "aim":
				c.t -= dt
				c.x = Game.damp(c.x, aim_from.x, 10.0, dt)
				c.y = Game.damp(c.y, aim_from.y, 10.0, dt)
				if c.t > 0.16:
					aim = Vector2(pcx, pcy)
				c.a = atan2(aim.y - c.y, aim.x - c.x)
				if poke_i == feint_at and not feint_done and c.t <= 0.5 * _tm() * 0.4:
					# the feint: it jerks and aims somewhere else; the real telegraph restarts (at least 0.5 s after the last visible change)
					feint_done = true
					c.t = 0.5 * _tm()
					jerk_t = 0.15
					pick_aim()
					aim = Vector2(pcx, pcy)
				if c.t <= 0.0:
					c.mode = "fly"
					c.vx = cos(c.a) * 560.0
					c.vy = sin(c.a) * 560.0
					c.t = 0.7
					Audio.sfx("dash")
			elif c.mode == "fly":
				c.t -= dt
				c.x += c.vx * dt
				c.y += c.vy * dt
				trail.append({"x": c.x, "y": c.y, "a": c.a, "life": 0.15})
				if room.grid.solid_at(c.x, c.y) or c.t <= 0.0:
					c.mode = "stuck"
					n -= 1
					c.t = (0.25 if fast else 0.4) if n > 0 else _pm(1.9)
					room.shake(0.3)
					room.spark(c.x, c.y, "#ffffff", 8)
					Audio.sfx("thud", {"vol": 0.7})
			elif c.mode == "stuck":
				c.t -= dt
				if n <= 0:
					ty = FLOOR - 62.0                  # slumps while disarmed
				if c.t <= 0.0:
					if n > 0:
						poke_i += 1
						c.mode = "aim"
						c.t = (0.5 if fast else 0.62) * _tm()
						pick_aim()
					else:
						c.mode = "orbit"
						set_state("idle", _idle_time(1.1))
		"rain":
			tx = W / 2.0 - w / 2.0
			ty = 34.0
			if st_t <= 0.0:
				if n > 0:
					n -= 1
					var slots: Array = range(11)
					slots.shuffle()
					for s in slots.slice(0, 7 if fast else 5):
						rain_marks.append({"x": 32.0 + s * 32.0, "t": 0.75 * _tm(), "done": false})
					st_t = 1.0 if fast else 1.25
					st_t = maxf(st_t, 0.75 * _tm() + 0.25)
					Audio.sfx("warn")
				else:
					set_state("idle", _idle_time(1.2))
		"sweepPrep":
			tx = W - 52.0 if dir < 0 else 24.0
			ty = FLOOR - h - 2.0
			if st_t <= 0.0:
				set_state("sweep", 0.0)
				Audio.sfx("dash")
				room.shake(0.2)
		"sweep":
			dmg = int(Game.dv("big_hit"))
			x += dir * (400.0 if fast else 330.0) * dt
			tx = x
			ty = FLOOR - h - 2.0
			trail.append({"x": x, "y": y, "body": true, "life": 0.2})
			if (dir < 0 and x < 22.0) or (dir > 0 and x > W - 22.0 - w):
				set_state("tired", _pm(1.0 if fast else 1.5))
				room.shake(0.4)
				Audio.sfx("thud")
				room.dust(cx, FLOOR, 8)
		"tired":
			ty = FLOOR - h - 6.0 + sin(t * 14.0) * 1.0
			if st_t <= 0.0:
				set_state("idle", _idle_time(0.8))
		"dangling":
			tx = W / 2.0 - w / 2.0
			ty = 60.0
			if st_t <= 0.0:
				blow_dangling()
		"deref":
			var u := clampf(1.0 - st_t / deref_dur, 0.0, 1.0)
			c.x = lerpf(deref_from.x, land.x, u)
			c.y = lerpf(deref_from.y, land.y, u) - sin(u * PI) * 56.0
			c.a = atan2(land.y - c.y, land.x - c.x)
			fade = 1.0 - 0.9 * u
			if st_t <= 0.0:
				land_deref()
		"derefStuck":
			if st_t <= 0.0:
				set_state("idle", _idle_time(0.5))
	if st != "sweep":
		x = Game.damp(x, tx, 5.0 if st == "sweepPrep" else 2.2, dt)
		y = Game.damp(y, ty, 3.0, dt)
	if st == "deref":                                     # it is "gone" while the cursor flies
		x = Game.damp(x, tx, 2.2, dt)
	if jerk_t > 0.0:
		jerk_t -= dt
	if c.mode == "orbit":
		orbit(dt)
	for m in rain_marks:
		m.t -= dt
		if m.t <= 0.0 and not m.done:
			m.done = true
			room.shoot(m.x, 14.0, 0.0, 250.0, {"kind": "shard", "col": "#bfe9ff", "r": 3})
	rain_marks = rain_marks.filter(func(m): return not m.done)
	for q in trail:
		q.life -= dt
	trail = trail.filter(func(q): return q.life > 0.0)

func pick_aim() -> void:
	var p = pick_target()
	var a := -PI / 2.0 + room.rng.randf_range(-1.1, 1.1)
	aim_from = Vector2(clampf(p.x + 5 + cos(a) * 84.0, 30.0, W - 30.0), clampf(p.y + sin(a) * 84.0, 24.0, 150.0))
	aim = Vector2(p.x + 5, p.y + 5)
	Audio.sfx("warn", {"vol": 0.6})

func orbit(dt: float) -> void:
	var c := cur
	c.x = Game.damp(c.x, cx + cos(t * 1.7) * 30.0, 6.0, dt)
	c.y = Game.damp(c.y, cy + sin(t * 2.3) * 14.0, 6.0, dt)
	c.a = Game.damp(c.a, -2.17 + sin(t * 2.0) * 0.2, 6.0, dt)

# ---- v2: dangling pointer ----
func start_dangling(p) -> void:
	set_state("dangling", 1.0 * _tm())
	dmarks.clear()
	var targets: Array = room.players() if room.players().size() > 1 else [p]
	for q in targets:
		var qx: float = q.x + 5
		var qy: float = q.y + 5
		dmarks.append(Vector2(qx, qy))
		var k := 0
		while k < 3:                                      # three more within 96 px, never inside a wall
			var a := room.rng.randf() * TAU
			var d := room.rng.randf_range(24.0, 96.0)
			var m := Vector2(clampf(qx + cos(a) * d, 12.0, W - 12.0), clampf(qy + sin(a) * d * 0.5, 20.0, FLOOR - 4.0))
			var tries := 0
			while room.grid.solid_at(m.x, m.y) and tries < 10:
				a = room.rng.randf() * TAU
				m = Vector2(clampf(qx + cos(a) * d, 12.0, W - 12.0), clampf(qy + sin(a) * d * 0.5, 20.0, FLOOR - 4.0))
				tries += 1
			if not room.grid.solid_at(m.x, m.y):
				dmarks.append(m)
				k += 1
			elif tries >= 10:
				k += 1
	Audio.sfx("warn")

func blow_dangling() -> void:
	for m in dmarks:
		room.explode(m.x, m.y, 14.0)
		Audio.sfx("explode", {"vol": 0.6})
		for q in room.players():
			var qc := Vector2(q.x + 5, q.y + 5)
			if qc.distance_to(m) < 20.0:
				q.hurt(1, m.x)
	room.shake(0.4)
	dmarks.clear()
	set_state("idle", maxf(0.4, _pm(0.4)))

# ---- v2: dereference ----
func start_deref(p) -> void:
	set_state("deref", 0.7 * _tm())
	deref_dur = st_t
	deref_from = Vector2(cur.x, cur.y)
	land = Vector2(clampf(p.x + 5, 24.0, W - 24.0), FLOOR)
	Audio.sfx("warn")

func land_deref() -> void:
	x = land.x - w / 2.0
	y = FLOOR - h - 2.0
	tx = x
	ty = y
	fade = 1.0
	cur.x = x + w / 2.0
	cur.y = y
	cur.mode = "orbit"
	room.shake(0.5)
	Audio.sfx("thud")
	room.dust(land.x, FLOOR, 8)
	var slam := {"x": land.x - 20.0, "y": FLOOR - 16.0, "w": 40.0, "h": 16.0}
	for q in room.players():
		if Game.overlap(q.hurtbox(), slam):
			q.hurt(int(Game.dv("big_hit")), land.x)
	set_state("derefStuck", _pm(0.8))

func harmboxes() -> Array:
	if st == "deref":
		return []
	var b: Array = [{"x": x + 3, "y": y + 3, "w": w - 6, "h": h - 6}]
	if cur.mode == "fly":
		b.append({"x": cur.x - 5, "y": cur.y - 5, "w": 10, "h": 10})
	return b

func hurtboxes() -> Array:
	if st == "deref":
		return []
	return [{"x": x - 2, "y": y - 4, "w": w + 4, "h": h + 8}]

# ---- drawing ----
func draw_cursor(ci: CanvasItem, px: float, py: float, a: float, alpha: float) -> void:
	ci.draw_set_transform(Vector2(floori(px + 0.5), floori(py + 0.5)), a + 2.17, Vector2.ONE)
	ci.draw_texture(Gfx.tex("cursor"), Vector2(-1, -1), Color(1, 1, 1, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_trails(ci: CanvasItem) -> void:
	for q in trail:
		if q.get("body", false):
			ci.draw_texture(Gfx.tex("null_0"), Vector2(floori(q.x + 0.5) - 9, floori(q.y + 0.5) - 8), Color(1, 1, 1, clampf(q.life * 2.5, 0.0, 1.0)))

func draw_boss_body(ci: CanvasItem) -> void:
	if dying and int(t * 30.0) % 3 == 0:
		return
	var jx := (int(t * 40.0) % 2) if st == "sweepPrep" else 0
	ci.draw_texture(Gfx.tex("null_%d" % (int(t * 5.0) % 2)), Vector2(floori(x + 0.5) - 9 + jx, floori(y + 0.5) - 8), Color(1, 1, 1, fade))
	if phase == 2:
		Fx._ring(ci, floori(x + 6 + jx + 0.5), floori(y + 9 + 0.5), 4.0, Color(Game.COL.hazard))
		Fx._ring(ci, floori(x + 19 + jx + 0.5), floori(y + 9 + 0.5), 4.0, Color(Game.COL.hazard))

func draw_trails_cursor(ci: CanvasItem) -> void:
	for q in trail:
		if not q.get("body", false):
			draw_cursor(ci, q.x, q.y, q.a, clampf(q.life * 3.0, 0.0, 1.0))

func draw_boss_overlay(ci: CanvasItem) -> void:
	var c := cur
	draw_trails_cursor(ci)
	if c.mode == "aim":                                    # dotted line: where it points is where it lands
		var dx := cos(c.a)
		var dy := sin(c.a)
		var i := 14
		while i < 420:
			var px: float = c.x + dx * i
			var py: float = c.y + dy * i
			if room.grid.solid_at(px, py):
				break
			ci.draw_rect(Rect2(floori(px + 0.5), floori(py + 0.5), 2, 2), Color(Game.COL.hazard) if ((i / 6) + int(t * 20.0)) % 2 == 1 else Color(Game.COL.hazardHi))
			i += 6
	var shake_a := sin(t * 70.0) * 0.06 if c.mode == "stuck" else 0.0
	var jerk := 0.5 if jerk_t > 0.0 else 0.0
	draw_cursor(ci, c.x, c.y, c.a + shake_a + jerk, 1.0)
	for m in rain_marks:
		warn_col(ci, m.x)
	for m in dmarks:
		draw_cursor(ci, m.x, m.y, -2.17, 1.0)
		var rr := 20.0 * (0.6 + 0.4 * (int(t * 8.0) % 2))
		Fx._ring(ci, floori(m.x + 0.5), floori(m.y + 0.5), rr, Color(Game.COL.hazard) if int(t * 12.0) % 2 == 1 else Color(Game.COL.hazardHi))
	if st == "sweepPrep":
		var col := Color(Game.COL.hazard) if int(t * 14.0) % 2 == 1 else Color(Game.COL.hazardHi)
		var xx := 20
		while xx < W - 20:
			ci.draw_rect(Rect2(xx, FLOOR - 14, 4, 1), col)
			xx += 8
	if st == "deref":                                      # the landing spot
		var col2 := Color(Game.COL.hazard) if int(t * 14.0) % 2 == 1 else Color(Game.COL.hazardHi)
		ci.draw_rect(Rect2(land.x - 20, FLOOR - 1, 40, 1), col2)

func net_fields() -> Array:
	return [roundi(hpf * 10.0), phase, ["wait", "idle", "poke", "rain", "sweepPrep", "sweep", "tired", "dangling", "deref", "derefStuck"].find(st), roundi(fade * 100.0)]

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	phase = int(f[1])
	st = ["wait", "idle", "poke", "rain", "sweepPrep", "sweep", "tired", "dangling", "deref", "derefStuck"][clampi(int(f[2]), 0, 9)]
	fade = f[3] / 100.0
