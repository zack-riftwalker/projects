class_name Fx
extends RefCounted
# Fx: particles, rings, floating text, discs, screen shake and flash (ports of part/burst/spark/dust/ring/pop/explode in js/level.js).
# One flat array; kinds: 0 particle, 1 ring, 2 pop (text), 3 disc.

var room: Room
var list: Array = []
var trauma := 0.0
var flash := 0.0
var flash_col := Color.WHITE

func _init(r: Room) -> void:
	room = r

func _rand(a: float, b: float) -> float:
	return room.rng.randf_range(a, b)

func shake(a: float) -> void:
	trauma = minf(1.0, trauma + a)

func flash_screen(a: float, col) -> void:
	flash = a
	flash_col = Color(col if col != null else "#ffffff")

func part(x: float, y: float, vx: float, vy: float, life: float, size: float, col, grav := 0.0, o = null):
	var cap := 90 if Game.low_fx else (280 if Game.touch_seen else 700)
	if list.size() > cap:
		return null
	var p := {"k": 0, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "size": size, "col": Color(col), "g": grav, "drag": 0.0, "glow": 0, "bounce": false, "keep": false}
	if o != null:
		for k in o:
			p[k] = o[k]
	list.append(p)
	return p

func burst(x: float, y: float, n: int, cols, spd: float, grav := 300.0, o = null) -> void:
	for i in range(n):
		var a := room.rng.randf() * TAU
		var s := spd * (0.3 + room.rng.randf() * 0.8)
		var c = cols[room.rng.randi() % cols.size()] if cols is Array else cols
		part(x, y, cos(a) * s, sin(a) * s - spd * 0.3, 0.3 + room.rng.randf() * 0.45, 1 + int(room.rng.randf() * 2.2), c, grav, o)

func dust(x: float, y: float, n: int, dir := 0.0) -> void:
	for i in range(n):
		part(x + _rand(-3, 3), y - 1, (dir if dir != 0.0 else _rand(-1, 1)) * _rand(10, 40) + _rand(-12, 12), _rand(-28, -6), _rand(0.2, 0.42), 1 + int(room.rng.randf() * 2), "#e8e0f0" if i % 2 == 1 else "#a9dd52", -40.0, {"drag": 3.0})

func ring(x: float, y: float, r0: float, r1: float, col, life: float) -> void:
	list.append({"k": 1, "x": x, "y": y, "r0": r0, "r1": r1, "col": Color(col), "life": life, "max": life, "vx": 0.0, "vy": 0.0, "g": 0.0})

func pop(x: float, y: float, text: String, col = "#ffffff", big := false) -> void:
	var life := 1.3 if big else 0.8
	list.append({"k": 2, "x": x, "y": y, "text": text, "col": Color(col), "life": life, "max": life, "vx": 0.0, "vy": -26.0, "g": 0.0, "big": big, "drag": 0.0, "bounce": false})

func spark(x: float, y: float, col = "#ffffff", n := 5) -> void:
	for i in range(n):
		var a := room.rng.randf() * 6.28
		var s := _rand(60, 160)
		part(x, y, cos(a) * s, sin(a) * s, _rand(0.12, 0.25), 1, col, 0.0, {"drag": 5.0, "glow": 1})

func explode(x: float, y: float, size: float, cols = null) -> void:
	if cols == null:
		cols = ["#ffffff", "#ffe27a", "#ff9a3a", "#ff5d5d"]
	ring(x, y, 2, size, "#ffffff", 0.25)
	burst(x, y, roundi(size * 0.8), cols, size * 5, 120.0, {"glow": 1})
	for i in range(int(size / 4)):
		part(x + _rand(-size, size) * 0.4, y + _rand(-size, size) * 0.4, _rand(-20, 20), _rand(-50, -10), _rand(0.4, 0.8), 3, "#6b6478", -30.0, {"drag": 2.0})
	list.append({"k": 3, "x": x, "y": y, "r": size * 0.6, "life": 0.14, "max": 0.14, "col": Color("#ffffff"), "vx": 0.0, "vy": 0.0, "g": 0.0})

# js: the particle loop at the end of Level.update (swap-remove, same order)
func decay(dt: float) -> void:
	trauma = maxf(0.0, trauma - dt * 2.2)
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 3.0)

func step(dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var q: Dictionary = list[i]
		q.life -= dt
		if q.life <= 0.0:
			list[i] = list[list.size() - 1]
			list.pop_back()
			i -= 1
			continue
		if q.k == 0 or q.k == 2:
			q.vy += q.g * dt
			if q.drag != 0.0:
				var d := exp(-q.drag * dt)
				q.vx *= d
				q.vy *= d
			q.x += q.vx * dt
			q.y += q.vy * dt
			if q.bounce and q.vy > 0.0 and room.grid.solid_at(q.x, q.y + 1):
				q.vy *= -0.45
				q.vx *= 0.7
				q.y -= 1
		i -= 1

func draw(ci: CanvasItem) -> void:
	for q in list:
		var x := floori(q.x + 0.5)
		var y := floori(q.y + 0.5)
		var u: float = q.life / q.max
		match q.k:
			0:
				var s := maxi(1, ceili(q.size * (1.0 if q.keep else minf(1.0, u * 1.6))))
				ci.draw_rect(Rect2(x - (s >> 1), y - (s >> 1), s, s), q.col)
			1:
				_ring(ci, x, y, lerpf(q.r0, q.r1, _ease_out(1.0 - u)), q.col)
			2:
				PixelText.draw_text(ci, q.text, x, y, q.col, {"align": "c", "outline": "#1b1226", "tiny": not q.big})
			3:
				_disc(ci, x, y, q.r * (0.6 + 0.4 * u), q.col)

static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)

# G.ring: pixel-perfect circle outline
static func _ring(ci: CanvasItem, cx: int, cy: int, r_f: float, col: Color) -> void:
	var r := floori(r_f + 0.5)
	if r <= 0:
		return
	var x := r
	var y := 0
	var err := 1 - r
	while x >= y:
		for p in [[x, y], [-x, y], [x, -y], [-x, -y], [y, x], [-y, x], [y, -x], [-y, -x]]:
			ci.draw_rect(Rect2(cx + p[0], cy + p[1], 1, 1), col)
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1

# G.disc: filled circle, one row at a time
static func _disc(ci: CanvasItem, cx: int, cy: int, r: float, col: Color) -> void:
	for y in range(-ceili(r), ceili(r) + 1):
		var hw := floori(sqrt(maxf(0.0, r * r - y * y)))
		ci.draw_rect(Rect2(cx - hw, cy + y, hw * 2 + 1, 1), col)
