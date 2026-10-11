class_name LeakBoss
extends Boss
# THE LEAK: "malloc() without free()". Exact port of `class Leak` (index.html) on top of Boss, plus the v2 GC drone.
# A blob that floods its arena in three levels (hp 67% / 34%); afloat it lobs, spits geysers and rains; on the ground it hops and spawns.
# The tide is room.liquid_y: the guest takes it from the snapshot (`lq`), never from the puppet.

const ST := ["wait", "idle", "flood", "hop"]
const LEVEL_Y := [216.0, 162.0, 116.0]          # FLOOR+40, FLOOR-14, FLOOR-60
const GC_EVERY := 9.0

var cycle := 0
var sq := 1.0
var level := 0
var flood_y := 216.0
var drops: Array = []                           # drips about to fall {x, t, done}
var geyser = null                               # {x, t, on, top}
var gc_t := GC_EVERY

func _init(r: Room, bx: float, by: float, base_hp := 60) -> void:
	super(r, bx, by, 44, 32, base_hp)
	boss_name = "THE LEAK"
	sub = "malloc() without free()"
	col = "#58f0c8"
	flood_y = FLOOR + 40.0
	r.liquid_y = flood_y

func boss_scale() -> float:
	return 0.62 + 0.38 * (hpf / float(max_hp))

func hurtboxes() -> Array:
	var s := boss_scale()
	var bw := 46.0 * s
	var bh := 34.0 * s
	return [{"x": cx - bw / 2.0, "y": y + h - bh, "w": bw, "h": bh}]

func harmboxes() -> Array:
	var s := boss_scale()
	var bw := 38.0 * s
	var bh := 28.0 * s
	var b: Array = [{"x": cx - bw / 2.0, "y": y + h - bh, "w": bw, "h": bh}]
	if geyser != null and geyser.on:
		b.append({"x": geyser.x - 9.0, "y": geyser.top, "w": 18.0, "h": 300.0})
	return b

func on_damage() -> void:
	var f := hpf / float(max_hp)
	var want := 2 if f <= 0.34 else (1 if f <= 0.67 else 0)
	sq = 1.25
	if want > level:
		level = want
		phase = want + 1
		room.events.append("bossPhase" if want == 1 else "bossPhase3")
		room.shake(0.8)
		Audio.sfx("roar")
		set_state("flood", 1.6)
		vx = 0.0
		vy = -200.0

func update(dt: float) -> void:
	tick(dt)
	var pw := float(room.pw)
	var p = pick_target()
	var ap := aim_point(p)
	var pcx: float = ap.x
	sq = Game.damp(sq, 1.0, 8.0, dt)
	# the tide
	var target_y: float = LEVEL_Y[0] if level == 0 else (LEVEL_Y[1] if level == 1 else LEVEL_Y[2])
	flood_y = move_toward(flood_y, target_y, 26.0 * dt)
	room.liquid_y = flood_y
	if dying:
		level = -1
		flood_y = move_toward(flood_y, FLOOR + 60.0, 60.0 * dt)
		room.liquid_y = flood_y
		sq = 1.0 + sin(t * 30.0) * 0.1
		death_rattle(dt, 2.2, ["#ffffff", "#d2fff2", "#58f0c8", "#127a80"])
		return
	if not active:
		return
	st_t -= dt
	var afloat := level > 0 and flood_y < FLOOR - 4.0
	if level >= 1:
		gc_t -= dt
		if gc_t <= 0.0:
			gc_t = GC_EVERY
			_send_gc()
	for m in drops:
		m.t -= dt
		if m.t <= 0.0 and not m.done:
			m.done = true
			room.shoot(m.x, 18.0, 0.0, 60.0, {"kind": "drip", "col": "#58f0c8", "g": 480.0, "r": 3.0, "cut": false})
	drops = drops.filter(func(m): return not m.done)
	if geyser != null:
		var q = geyser
		q.t -= dt
		if not q.on and q.t <= 0.0:
			q.on = true
			q.t = 0.7
			q.top = flood_y - 120.0
			Audio.sfx("splash")
			room.shake(0.3)
		elif q.on and q.t <= 0.0:
			geyser = null
		elif q.on:
			for i in range(3):
				room.part(q.x + room.rng.randf_range(-7, 7), flood_y, room.rng.randf_range(-20, 20), room.rng.randf_range(-380, -220), 0.35, 2 + room.rng.randi() % 2, ["#58f0c8", "#d2fff2", "#3fd1b0"][room.rng.randi() % 3], 600.0)
		elif room.rng.randf() < 0.5:
			room.part(q.x + room.rng.randf_range(-8, 8), flood_y, 0.0, room.rng.randf_range(-50, -20), 0.3, 1, "#d2fff2", 0.0)
	if afloat:
		# wading in its own mess
		y = Game.damp(y, flood_y - h * 0.62 + sin(t * 2.2) * 2.0, 4.0, dt)
		if st != "flood":
			x = clampf(x + clampf(pcx - cx, -1.0, 1.0) * (34.0 if level == 2 else 24.0) * dt, 40.0, pw - 40.0 - w)
		if st_t <= 0.0:
			var k := cycle % 3
			cycle += 1
			if k == 0:
				lob(4 if level == 2 else 3)
				set_state("wait", 1.7)
			elif k == 1:
				geyser = {"x": clampf(pcx, 40.0, pw - 40.0), "t": 0.9, "on": false, "top": 0.0}
				Audio.sfx("warn")
				set_state("wait", 2.2)
			else:
				spawn(2)
				rain(5 if level == 2 else 3)
				set_state("wait", 2.2)
			next_target()
		return
	if st == "idle" or st == "wait" or st == "flood":
		vx *= 0.85
		if st_t <= 0.0 and on_ground:
			var k2 := cycle % 3
			cycle += 1
			if k2 == 0:
				set_state("hop", 0.2)
				n = 3
			elif k2 == 1:
				spawn(3)
				set_state("wait", 1.6)
			else:
				rain(4)
				set_state("wait", 1.5)
			next_target()
	elif st == "hop":
		if on_ground and st_t <= 0.0:
			var had := n > 0
			n -= 1
			if had:
				vy = -285.0
				vx = clampf((pcx - cx) * 1.4, -120.0, 120.0)
				on_ground = false
				sq = 0.8
				Audio.sfx("jump", {"vol": 0.6})
			else:
				set_state("wait", 1.3)
	var landed := physics(dt, 760.0)
	x = clampf(x, 18.0, pw - 18.0 - w)
	if landed:
		sq = 1.35
		vx = 0.0
		st_t = maxf(st_t, 0.45)
		room.shake(0.5)
		Audio.sfx("thud")
		room.dust(cx, FLOOR, 10)
		room.burst(cx, FLOOR - 4.0, 10, ["#58f0c8", "#d2fff2"], 110.0, 320.0)
		if st == "hop":
			for d in [-1, 1]:
				room.shoot(cx + d * 20.0, FLOOR - 1.0, d * 125.0, 0.0, {"kind": "wave", "col": "#58f0c8", "r": 4.0, "hgt": 9.0, "tile": false, "life": 1.1, "cut": false})

func lob(count: int) -> void:
	var ap := aim_point(pick_target())
	for i in range(count):
		var tx: float = ap.x + (i - (count - 1) / 2.0) * 34.0
		var tt := 0.95
		var g := 420.0
		room.shoot(cx, y, (tx - cx) / tt, ((ap.y - 5.0) - y) / tt - 0.5 * g * tt, {"kind": "orb", "col": "#58f0c8", "g": g, "r": 4.0, "tile": true, "life": 3.0})
	sq = 0.8
	Audio.sfx("shoot")

func spawn(count: int) -> void:
	var alive := 0
	for e in room.ents:
		if e is Slime and not e.dead:
			alive += 1
	for i in range(mini(count, 4 - alive)):
		var s := Slime.new(room, cx - 4.0, y - 8.0, true)
		s.x = cx - 4.0
		s.y = y - 6.0
		s.vx = room.rng.randf_range(-150, 150)
		s.vy = room.rng.randf_range(-300, -220)
		s.loot = 0
		s.wait = 0.8
		room.add_entity(s)
	sq = 0.75
	Audio.sfx("splash", {"vol": 0.7})

func rain(count: int) -> void:
	var ap := aim_point(pick_target())
	for i in range(count):
		drops.append({"x": clampf(ap.x + room.rng.randf_range(-90, 90), 26.0, room.pw - 26.0), "t": 0.7 + i * 0.22, "done": false})
	Audio.sfx("warn", {"vol": 0.6})

# v2: the GC drone flies across from the side farther from the boss; popping it lets some of the water out
func _send_gc() -> void:
	var from_right := cx < room.pw / 2.0
	var d := GcDrone.new(room, 0, 0, self)
	d.x = room.pw + 16.0 if from_right else -30.0
	d.y = 40.0
	d.vx = -70.0 if from_right else 70.0
	room.add_entity(d)

func gc_popped(at: Vector2) -> void:
	flood_y += 30.0
	room.pop(at.x, at.y - 8.0, "gc()", "#7fd08a", true)
	Audio.sfx("uiOk")

# ---- drawing ----
func draw_boss_body(ci: CanvasItem) -> void:
	if dying and int(t * 30.0) % 3 == 0:
		return
	var s := boss_scale()
	Gfx.spr(ci, "leak_%d" % (int(t * 3.0) % 2), roundi(cx), roundi(y + h) + 2, false, s * sq, s * (2.0 - sq))

func draw_boss_overlay(ci: CanvasItem) -> void:
	for m in drops:
		var mx := roundi(m.x)
		var sz := ceili((1.0 - minf(1.0, m.t / 0.7)) * 4.0)
		ci.draw_rect(Rect2(mx - 1, 10, 2, 2 + sz), Color("#58f0c8"))
		ci.draw_rect(Rect2(mx - 2, 10 + sz, 4, 2), Color("#58f0c8"))
	if geyser != null:
		var q = geyser
		var gx := roundi(q.x)
		if q.on:
			ci.draw_rect(Rect2(gx - 8, q.top, 16, flood_y - q.top), Color(0.345, 0.941, 0.784, 0.75))
			ci.draw_rect(Rect2(gx - 3, q.top + 3, 5, flood_y - q.top), Color("#d2fff2"))
		else:
			var dc := Color(Game.COL.hazardHi) if int(t * 14.0) % 2 == 1 else Color(Game.COL.hazard)
			var yy := flood_y - 120.0
			while yy < flood_y:
				ci.draw_rect(Rect2(gx, yy, 1, 4), dc)
				yy += 8.0

# ---- co-op ----
func net_fields() -> Array:
	var mk: Array = []
	for m in drops.slice(0, 6):
		mk.append([roundi(m.x), roundi(m.t * 100.0)])
	return [roundi(hpf * 10.0), max_hp, phase, 1 if active else 0, 1 if dying else 0, level, ST.find(st), roundi(st_t * 100.0), roundi(flood_y), roundi(sq * 100.0),
		roundi(geyser.x) if geyser != null else -1, 1 if (geyser != null and geyser.on) else 0, roundi(geyser.t * 100.0) if geyser != null else 0, roundi(geyser.top) if geyser != null else 0, mk]

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	phase = int(f[2])
	active = int(f[3]) == 1
	dying = int(f[4]) == 1
	level = int(f[5])
	st = ST[clampi(int(f[6]), 0, ST.size() - 1)]
	st_t = f[7] / 100.0
	flood_y = float(f[8])
	sq = f[9] / 100.0
	if int(f[10]) < 0:
		geyser = null
	else:
		geyser = {"x": float(f[10]), "on": int(f[11]) == 1, "t": f[12] / 100.0, "top": float(f[13])}
	drops.clear()
	for m in f[14]:
		drops.append({"x": float(m[0]), "t": m[1] / 100.0, "done": false})
	passive = not active or dying
