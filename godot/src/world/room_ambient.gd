class_name RoomAmbient
extends Node2D
# RoomAmbient (MVGN-10): the ambient particles of a NETWORK room (data motes, glitch shards, spores, embers, paper bits: the Look's `particles`) and the
# steam of up to two floor vents. Their own system, not Fx: its own RandomNumberGenerator seeded from the room id (never room.rng: that drives the
# gameplay bursts and the parity tapes), drawn behind the entities. Counts 40 / 100 / 160 for Low / High / Ultra (25 / 60 / 100 %), embers x2 in a
# boss's last phase. Motes drift with the parallax of the cable layer (0.3) and are pushed away from a player within 20 px; embers rise, spores sink;
# glitch shards only blink when "Reduce flashing" is off. Vent puffs are a pure function of the room clock and a hash.

const COUNTS := [40, 96, 160]
const W := 384.0
const H := 216.0

var room: Room
var rng := RandomNumberGenerator.new()
var kind := ""
var n := 0
var px := PackedFloat32Array()          # layer-space x, y, speed x, speed y, phase, size (per particle, 6 floats)
var count_now := 0
var vents: Array = []                   # {x, y (world px: the top of the floor tile), period, off}
var proxy: DrawProxy
var t := 0.0
var fade := 1.0
var fe: Array = []                      # N15: embers off the bricks {x, y (world), vx, vy, life, max}

func _ready() -> void:
	z_index = 1
	rng.seed = hash("ambient:" + String(room.id))
	proxy = DrawProxy.new()
	proxy.material = Look.unshaded()
	proxy.cb = _draw_all
	add_child(proxy)
	# vents: the two floor caps with the smallest hash (the cell above them is empty and not used by the map)
	var cand: Array = []
	var g := room.grid
	for ty in range(1, g.h):
		for tx in range(g.w):
			if g.tile(tx, ty) == TileGrid.SOLID and g.tiles[(ty - 1) * g.w + tx] == TileGrid.E and not room.reserved(tx, ty - 1):
				cand.append([Game.hash3(tx, ty, 311), tx, ty])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(mini(2, cand.size())):
		vents.append({"x": float(cand[i][1]) * 16.0 + 8.0, "y": float(cand[i][2]) * 16.0, "period": 3.0 + Game.hash3(cand[i][1], cand[i][2], 312) * 2.0, "off": Game.hash3(cand[i][1], cand[i][2], 313) * 5.0})
	_rebuild(Look.mixed("stable", 1.0).particles)

func wanted_count(k: String) -> int:
	var c: int = COUNTS[Game.gfx_tier]
	return c * 2 if k == "embers2" else c

func _rebuild(k: String) -> void:
	kind = k
	n = wanted_count(k)
	px.resize(n * 6)
	for i in range(n):
		var b := i * 6
		px[b] = rng.randf() * W * 3.0                     # layer space is 3 screens wide so that parallax scrolling never shows a seam
		px[b + 1] = rng.randf() * H
		px[b + 4] = rng.randf() * TAU
		px[b + 5] = 1.0 if rng.randf() < 0.75 else 2.0
		match k:
			"embers", "embers2": px[b + 2] = rng.randf_range(-6.0, 6.0); px[b + 3] = rng.randf_range(-26.0, -10.0)
			"spores": px[b + 2] = rng.randf_range(-3.0, 3.0); px[b + 3] = rng.randf_range(2.0, 8.0)
			"paper": px[b + 2] = rng.randf_range(-8.0, 8.0); px[b + 3] = rng.randf_range(6.0, 16.0)
			"shards": px[b + 2] = rng.randf_range(-4.0, 4.0); px[b + 3] = rng.randf_range(-4.0, 4.0)
			_: px[b + 2] = rng.randf_range(-5.0, 5.0); px[b + 3] = rng.randf_range(-3.0, 3.0)
	count_now = n
	fade = 0.0

func _process(dt: float) -> void:
	if room == null or not room.is_local or room.camera == null or room.look == null:
		return
	var want: String = room.look.out.particles
	if want != kind or wanted_count(want) != n:
		_rebuild(want)
	t += dt
	fade = minf(1.0, fade + dt / 0.8)
	var cam: Vector2 = room.camera.position
	var pushers: Array = []
	for p in [room.player] + room.remote_players:
		if p != null and p.get("dead") != true:
			pushers.append(Vector2(p.x + p.w * 0.5 - cam.x, p.y + p.h * 0.5 - cam.y))
	for i in range(n):
		var b := i * 6
		px[b] += px[b + 2] * dt
		px[b + 1] += px[b + 3] * dt
		if kind == "spores" or kind == "paper":
			px[b] += sin(t * 1.3 + px[b + 4]) * 6.0 * dt
		if px[b + 1] < -4.0:
			px[b + 1] += H + 8.0
		elif px[b + 1] > H + 4.0:
			px[b + 1] -= H + 8.0
		px[b] = fposmod(px[b], W * 3.0)
		if kind == "motes" and not pushers.is_empty():       # pushed away from a player (within 20 px of its centre)
			var sp := _screen(i, cam)
			for pp in pushers:
				var d: Vector2 = sp - pp
				var dl := d.length()
				if dl < 20.0 and dl > 0.01:
					var push := d / dl * (20.0 - dl) * 6.0 * dt * 4.0
					px[b] += push.x
					px[b + 1] += push.y
	if room.id == "N15" and not room.fire_cells.is_empty():            # THE FIREWALL: embers lift off the brick tops
		var want_fe: int = [8, 18, 30][Game.gfx_tier]
		while fe.size() < want_fe:
			var c: Array = room.fire_cells[rng.randi() % room.fire_cells.size()]
			fe.append({"x": float(c[0]) * 16.0 + rng.randf() * 16.0, "y": float(c[1]) * 16.0, "vx": rng.randf_range(-8.0, 8.0), "vy": rng.randf_range(-42.0, -20.0), "life": rng.randf_range(0.8, 2.2), "max": 2.2})
		for e in fe:
			e.x += float(e.vx) * dt
			e.y += float(e.vy) * dt
			e.life -= dt
			if e.life <= 0.0:
				var c2: Array = room.fire_cells[rng.randi() % room.fire_cells.size()]
				e.x = float(c2[0]) * 16.0 + rng.randf() * 16.0
				e.y = float(c2[1]) * 16.0
				e.vx = rng.randf_range(-8.0, 8.0)
				e.vy = rng.randf_range(-42.0, -20.0)
				e.life = rng.randf_range(0.8, 2.2)
		while fe.size() > want_fe:
			fe.pop_back()
	Game.gfx_stats.parts = n + fe.size()
	proxy.position = cam
	proxy.queue_redraw()

func _screen(i: int, cam: Vector2) -> Vector2:
	var b := i * 6
	return Vector2(fposmod(px[b] - cam.x * 0.3, W * 3.0) - W, px[b + 1] - cam.y * 0.12)       # (a screen is 384 wide of the 1152-wide layer)

func _draw_all(ci: CanvasItem) -> void:
	if room == null or room.look == null or room.camera == null:
		return
	var o: Dictionary = room.look.out
	var ca: Color = o.accent_a
	var cb: Color = o.accent_b
	var cam: Vector2 = room.camera.position
	var calm := Game.reduce_flash
	for i in range(n):
		var sp := _screen(i, cam)
		if sp.x < -2.0 or sp.x > W + 2.0:
			continue
		var b := i * 6
		var ph := px[b + 4]
		var sz := px[b + 5]
		var col: Color
		var a := 0.55 * fade
		match kind:
			"shards":
				col = ca if (i & 1) == 0 else cb
				if not calm and sin(t * 9.0 + ph * 3.0) < -0.3:
					a = 0.0
				a *= 0.9
				ci.draw_rect(Rect2(floorf(sp.x), floorf(sp.y), sz + 1.0, 1.0 if (i % 3) != 0 else 2.0), Color(col.r, col.g, col.b, a))
				continue
			"embers", "embers2":
				col = ca.lerp(cb, 0.5 + 0.5 * sin(ph))
				a = 0.8 * fade * (0.6 + 0.4 * sin(t * 3.0 + ph))
			"spores":
				col = ca.lerp(Color.WHITE, 0.25)
				a = 0.45 * fade * (0.5 + 0.5 * sin(t * 1.1 + ph))
			"paper":
				col = Color(0.85, 0.87, 0.92)
				a = 0.4 * fade
				ci.draw_rect(Rect2(floorf(sp.x), floorf(sp.y), 2.0 if sin(t * 4.0 + ph) > 0.0 else 1.0, 1.0), Color(col.r, col.g, col.b, a))
				continue
			_:
				col = ca if (i & 1) == 0 else cb
				a = 0.5 * fade * (0.6 + 0.4 * sin(t * 1.7 + ph))
		ci.draw_rect(Rect2(floorf(sp.x), floorf(sp.y), sz, sz), Color(col.r, col.g, col.b, a))
	for e in fe:
		var ex := float(e.x) - cam.x
		var ey := float(e.y) - cam.y
		if ex > -2.0 and ex < W + 2.0 and ey > -2.0 and ey < H + 2.0:
			var ec := ca.lerp(cb, 0.4)
			ci.draw_rect(Rect2(floorf(ex), floorf(ey), 1.0, 1.0 if float(e.life) < 0.8 else 2.0), Color(ec.r, ec.g, ec.b, clampf(float(e.life) / 0.8, 0.0, 1.0) * 0.9))
	# vent steam: puffs rise and spread for 1.4 s every 3-5 s (a pure function of the room clock)
	var rt: float = room.time
	for v in vents:
		var vx: float = v.x - cam.x
		var vy: float = v.y - cam.y
		if vx < -20.0 or vx > W + 20.0 or vy < -40.0 or vy > H + 20.0:
			continue
		ci.draw_rect(Rect2(vx - 5.0, vy - 1.0, 10.0, 1.0), Color(0.12, 0.14, 0.2, 1.0))
		var age := fposmod(rt + float(v.off), float(v.period))
		if age < 1.4:
			for k in range(5):
				var u := clampf((age - float(k) * 0.12) / 1.2, 0.0, 1.0)
				if u <= 0.0 or u >= 1.0:
					continue
				var rr := 1.0 + u * 3.0
				ci.draw_rect(Rect2(floorf(vx - rr + sin(u * 5.0 + float(k)) * 2.0), floorf(vy - 4.0 - u * 20.0), rr * 2.0, rr * 1.6), Color(0.8, 0.88, 1.0, 0.22 * (1.0 - u)))
