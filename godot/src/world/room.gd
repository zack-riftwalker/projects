class_name Room
extends Node2D
# Room: one level room. Owns the tile grid, entities and effects and steps the whole simulation (port of `class Level`, js/level.js).
# Coordinates are the current game's: pixels, origin top-left of the room, entity x/y = top-left of the hitbox.

const T := 16
const W := 384
const H := 216

var id := ""
var def := {}
var grid := TileGrid.new()
var w := 0                 # width in tiles
var h := 0
var pw := 0                # width in pixels
var ph := 0
var ents: Array = []
var items: Array = []
var plats: Array = []
var projs: Array = []
var springs: Array = []
var cps: Array = []
var signs: Array = []
var break_q: Array = []
var events: Array = []
var player = null
var start := {"x": 32.0, "y": 32.0}
var time := 0.0
var clock := 0.0
var hitstop := 0.0
var tokens := 0
var kills := 0
var hits := 0
var cp_index := -1
var sign_now = null
var auto_step := true
var rng := RandomNumberGenerator.new()
var cam := {"x": 0.0, "y": 0.0, "ty": 0.0, "look": 0.0, "lock": null}
var fx: Fx
var view: RoomView
var camera: Camera2D
var layers := {}
var liquid_y = null
var blink_period := 1.5
var entity_root: Node2D
var rows: PackedStringArray = PackedStringArray()

func _ready() -> void:
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if not auto_step:
		return
	Controls.poll()
	step(Game.STEP)

# ---------------------------------------------------------------- loading
func load_room(room_id: String) -> void:
	id = room_id
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/rooms.json"))
	def = meta[room_id]
	rows = FileAccess.get_file_as_string("res://src/world/rooms/" + def.file).split("\n")
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, r.length())
	pw = w * T
	ph = h * T
	grid.w = w
	grid.h = h
	grid.tiles = PackedByteArray()
	grid.tiles.resize(w * h)
	var sign_n := 0
	var item_id := 0
	var spark_spots: Array = []
	for ty in range(h):
		var row := rows[ty]
		for tx in range(row.length()):
			var ch := row[tx]
			var x := tx * T
			var y := ty * T
			if TileGrid.CHARS.has(ch):
				grid.tiles[ty * w + tx] = TileGrid.CHARS[ch]
				continue
			match ch:
				" ", ".", "|":
					pass
				"P":
					start = {"x": float(x + 3), "y": float(y + 6)}
				"C":
					cps.append({"x": x + 8, "y": y + T, "on": false})
				"S":
					springs.append({"x": x + 2, "y": y + 9, "w": 12, "h": 7, "t": 0.0})
				"o":
					items.append({"kind": "token", "x": float(x + 8), "y": float(y + 8), "id": item_id, "ph": tx * 0.7})
					item_id += 1
				"*":
					spark_spots.append({"x": x + 8, "y": y + 8})
				"H":
					items.append({"kind": "coffee", "x": float(x + 8), "y": float(y + 9), "id": item_id, "ph": 0.0})
					item_id += 1
				"T":
					var texts: Array = def.get("signs", [])
					signs.append({"x": x + 8, "y": y + T, "text": texts[sign_n] if sign_n < texts.size() else "..."})
					sign_n += 1
				"M", "V":
					_add_platform(ch, tx, ty, rows)
				"E", "B", "E ":
					pass
				_:
					var e = spawn_enemy(ch, x, y)
					if e != null:
						ents.append(e)
	spark_spots.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in range(mini(3, spark_spots.size())):
		items.append({"kind": "spark", "x": float(spark_spots[i].x), "y": float(spark_spots[i].y), "idx": i, "ph": i, "ghost": false})
	rng.seed = 1
	if cp_index >= 0 and cp_index < cps.size():
		cps[cp_index].on = true
		start = {"x": cps[cp_index].x - 5.0, "y": cps[cp_index].y - 10.0}

func _add_platform(ch: String, tx: int, ty: int, rows: PackedStringArray) -> void:
	var x := tx * T
	var y := ty * T
	var a := x if ch == "M" else y
	var b := a
	if ch == "M":
		var row := rows[ty]
		for i in range(tx + 1, row.length()):
			if row[i] == "|":
				b = (i + 1) * T - 48
				break
		if b == a:
			for i in range(tx - 1, -1, -1):
				if row[i] == "|":
					b = i * T
					break
	else:
		for j in range(ty + 1, h):
			if tx < rows[j].length() and rows[j][tx] == "|":
				b = j * T
				break
		if b == a:
			for j in range(ty - 1, -1, -1):
				if tx < rows[j].length() and rows[j][tx] == "|":
					b = j * T
					break
	plats.append({"x": float(x), "y": float(y + 2), "w": 48.0, "h": 6.0, "ax": ch == "M", "a": a, "b": b, "ph": fposmod(tx * 0.37 + ty * 0.61, 1.0), "dx": 0.0, "dy": 0.0, "speed": def.get("platSpeed", 44.0)})

func spawn_enemy(ch: String, x: int, y: int):
	return null          # MV1-06

# the nodes that draw the room; called once after load_room
func build_nodes() -> void:
	view = RoomView.new()
	view.name = "View"
	add_child(view)
	view.build(self)
	fx = Fx.new(self)
	for spec in [["furniture", 1], ["top", 4]]:
		var layer := RoomLayer.new()
		layer.room = self
		layer.kind = spec[0]
		layer.z_index = spec[1]
		add_child(layer)
		layers[spec[0]] = layer
	var ent_root := Node2D.new()
	ent_root.name = "Entities"
	ent_root.z_index = 2
	add_child(ent_root)
	entity_root = ent_root
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	player = Player.new(self, start.x, start.y)
	player.name = "Player"
	add_child(player)
	snap_cam()

func reserved(tx: int, ty: int) -> bool:
	if ty < 0 or ty >= rows.size() or tx >= rows[ty].length():
		return false
	var ch := rows[ty][tx]
	return ch != " " and ch != "."

# ---------------------------------------------------------------- effects (the JS Level helpers; the work is in Fx)
func shake(a: float) -> void: fx.shake(a)
func stop(t: float) -> void: hitstop = maxf(hitstop, t)
func flash_screen(a: float, col = null) -> void: fx.flash_screen(a, col)
func part(px: float, py: float, pvx: float, pvy: float, life: float, size: float, col, grav := 0.0, o = null): return fx.part(px, py, pvx, pvy, life, size, col, grav, o)
func burst(px: float, py: float, n: int, cols, spd: float, grav := 300.0, o = null) -> void: fx.burst(px, py, n, cols, spd, grav, o)
func dust(px: float, py: float, n: int, dir := 0.0) -> void: fx.dust(px, py, n, dir)
func ring(px: float, py: float, r0: float, r1: float, col, life: float) -> void: fx.ring(px, py, r0, r1, col, life)
func pop(px: float, py: float, text: String, col = "#ffffff", big := false) -> void: fx.pop(px, py, text, col, big)
func spark(px: float, py: float, col = "#ffffff", n := 5) -> void: fx.spark(px, py, col, n)
func explode(px: float, py: float, size: float, cols = null) -> void: fx.explode(px, py, size, cols)

func drop(px: float, py: float, n: int, kind := "token") -> void:
	for i in range(n):
		items.append({"kind": kind, "x": px, "y": py, "vx": rng.randf_range(-70, 70), "vy": rng.randf_range(-190, -90), "loose": true, "t": 0.0, "ph": i})

func break_tile(tx: int, ty: int) -> bool:
	if not grid.break_tile(tx, ty):
		return false
	view.erase_tile(tx, ty)
	burst(tx * T + 8, ty * T + 8, 12, ["#8d8798", "#c3bccd", "#4c4658"], 90.0, 300.0)
	shake(0.3)
	Audio.sfx("brk")
	# the rest of the wall follows a moment later
	for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		if grid.tile(tx + o[0], ty + o[1]) == TileGrid.CRACK:
			break_q.append({"tx": tx + o[0], "ty": ty + o[1], "t": 0.06})
	return true

func heal(q, n: int) -> void:
	q.hp = mini(q.max_hp, q.hp + n)

# ---------------------------------------------------------------- camera
func snap_cam() -> void:
	player_cam_snap()
	var t := cam_target()
	cam.x = t[0]
	cam.y = t[1]
	camera.position = Vector2(floori(cam.x + 0.5), floori(cam.y + 0.5))

func player_cam_snap() -> void:
	var p = player
	if p == null:
		cam.ty = start.y + 10 - H * 0.64
	else:
		cam.ty = p.y + p.h - H * 0.64

func cam_target() -> Array:
	var tx: float
	var ty: float = cam.ty
	if player != null:
		tx = player.x + player.w / 2.0 - W / 2.0 + cam.look
	else:
		tx = start.x + 5 - W / 2.0
	if cam.lock != null:
		tx = cam.lock.x
		ty = cam.lock.y
	if pw <= W:
		tx = (pw - W) / 2.0
	else:
		tx = clampf(tx, 0.0, pw - W)
	if ph <= H:
		ty = ph - H
	else:
		ty = clampf(ty, 0.0, ph - H)
	return [tx, ty]

func update_cam(dt: float) -> void:
	var p = player
	cam.look = Game.damp(cam.look, p.face * 22.0 + clampf(p.vx * 0.12, -16.0, 16.0), 2.2, dt)
	var feet: float = p.y + p.h
	if p.on_ground or p.wall_dir != 0:
		cam.ty = Game.damp(cam.ty, feet - H * 0.64, 5.0, dt)
	var sy: float = feet - cam.ty               # feet in screen space if the camera were at the target
	if sy < 56.0:
		cam.ty = feet - 56.0
	elif sy > H - 44.0:
		cam.ty = feet - (H - 44.0)
	var t := cam_target()
	cam.x = Game.damp(cam.x, t[0], 8.0, dt)
	cam.y = Game.damp(cam.y, t[1], 9.0 if absf(t[1] - cam.y) > 60.0 else 5.0, dt)

# the camera node follows cam plus the trauma shake; runs every rendered frame
func _process(_dt: float) -> void:
	if camera == null or fx == null:
		return
	var amp := fx.trauma * fx.trauma * 7.0 * Game.shake_opt
	camera.position = Vector2(floori(cam.x + (randf() * 2.0 - 1.0) * amp + 0.5), floori(cam.y + (randf() * 2.0 - 1.0) * amp + 0.5))
	for k in layers:
		layers[k].queue_redraw()

# ---------------------------------------------------------------- simulation (js: Level.update, same order)
func step(dt: float) -> void:
	fx.decay(dt)
	if hitstop > 0.0:
		hitstop -= dt
		return
	time += dt
	var p = player
	if not p.dead:
		clock += dt

	# blinking blocks
	var ph_ := floori(time / blink_period) % 2
	if ph_ != grid.blink_phase:
		grid.blink_phase = ph_
		var want := TileGrid.BLINK_A if ph_ == 0 else TileGrid.BLINK_B
		var q = p
		if not q.dead:
			for ty in range(floori(q.y / T), floori((q.y + q.h) / T) + 1):
				for tx in range(floori(q.x / T), floori((q.x + q.w) / T) + 1):
					if grid.tile(tx, ty) == want:
						grid.blink_hold[ty * w + tx] = true
	if not grid.blink_hold.is_empty():
		for i in grid.blink_hold.keys():
			if not grid.any_on([p] if not p.dead else [], i % w, i / w):
				grid.blink_hold.erase(i)
	# crumbling blocks
	for i in grid.crumble.keys():
		var c: Dictionary = grid.crumble[i]
		c.t -= dt
		if c.t > 0.0:
			continue
		var tx2: int = i % w
		var ty2: int = i / w
		if c.s == 1:
			c.s = 2
			c.t = 2.6
			burst(tx2 * T + 8, ty2 * T + 4, 7, ["#cbb894", "#8a7a5c"], 50.0, 260.0)
			Audio.sfx("crumble")
		elif c.s == 2:
			if grid.any_on([p] if not p.dead else [], tx2, ty2):
				c.t = 0.2
			else:
				grid.crumble.erase(i)
				dust(tx2 * T + 8, ty2 * T + 8, 4)
	if not break_q.is_empty():
		for q in break_q:
			q.t -= dt
			if q.t <= 0.0:
				q.done = true
				break_tile(q.tx, q.ty)
		break_q = break_q.filter(func(q): return not q.get("done", false))
	# moving platforms
	for m in plats:
		var span := absf(m.b - m.a)
		if span < 1.0:
			m.dx = 0.0
			m.dy = 0.0
			continue
		var period: float = (span / m.speed) * 2.0
		var u := 0.5 - 0.5 * cos(fposmod(time / period + m.ph, 1.0) * PI * 2.0)
		var v := lerpf(m.a, m.b, u)
		if m.ax:
			m.dx = v - m.x
			m.dy = 0.0
			m.x = v
		else:
			m.dy = v + 2.0 - m.y
			m.dx = 0.0
			m.y = v + 2.0

	p.update(dt)

	# creatures (only the ones near the camera think)
	var cx: float = cam.x
	var cy: float = cam.y
	for e in ents:
		if e.dead:
			continue
		if e.always or (e.x + e.w > cx - 90 and e.x < cx + W + 90 and e.y + e.h > cy - 110 and e.y < cy + H + 110):
			e.update(dt)
	interact()
	update_items(dt)
	update_projs(dt)
	for s in springs:
		if s.t > 0.0:
			s.t -= dt
	fx.step(dt)
	# tidy
	var any_dead := false
	for e in ents:
		if e.dead:
			any_dead = true
			break
	if any_dead:
		var keep: Array = []
		for e in ents:
			if e.dead:
				e.queue_free()
			else:
				keep.append(e)
		ents = keep
	update_cam(dt)

func interact() -> void:
	var p = player
	if p.dead or p.gone:
		return
	interact_combat(p)
	interact_goals(p)

# what is under a player's feet that hurts: "" , "spike" , "liq" or "pit"
func hazard_at(p) -> String:
	var x0 := floori((p.x + 1) / T)
	var x1 := floori((p.x + p.w - 1) / T)
	var y0 := floori((p.y + 1) / T)
	var y1 := floori((p.y + p.h - 1) / T)
	var hz := ""
	for ty in range(y0, y1 + 1):
		if hz != "":
			break
		for tx in range(x0, x1 + 1):
			var t := grid.tile(tx, ty)
			if t == TileGrid.SPIKE_U:
				if p.y + p.h > ty * T + 9 and p.x + p.w > tx * T + 2 and p.x < tx * T + 14:
					hz = "spike"
			elif t == TileGrid.SPIKE_D:
				if p.y < ty * T + 7 and p.x + p.w > tx * T + 2 and p.x < tx * T + 14:
					hz = "spike"
			elif t == TileGrid.LIQ:
				if p.y + p.h > ty * T + 6:
					hz = "liq"
	if p.y > ph + 24:
		hz = "pit"
	return hz

func interact_combat(p) -> void:
	# claw
	if p.atk_t > 0.0 and p.atk_live:
		var box: Dictionary = p.atk_box()
		for e in ents:
			if e.dead or e.marks.get(p.hit_key, 0) == p.atk_id or e.no_hit:
				continue
			for b in e.hurtboxes():
				if not Game.overlap(box, b):
					continue
				e.marks[p.hit_key] = p.atk_id
				var res: String = e.hit(p.atk_dmg, p.atk_face if p.atk_dir == "f" else 0.0, -1.0 if p.atk_dir == "u" else (1.0 if p.atk_dir == "d" else 0.0), "swipe", b)
				if res != "":
					p.on_hit(e, res, b)
				break
		for s in springs:
			if p.atk_dir == "d" and Game.overlap(box, s):
				p.spring(s)
	# touching
	var hb: Dictionary = p.hurtbox()
	for e in ents:
		if e.dead or e.passive:
			continue
		for b in e.harmboxes():
			if not Game.overlap(hb, b):
				continue
			if p.dash_t > 0.0 and e.dashable:
				if e.marks.get(p.dash_key, 0) != p.dash_id:
					e.marks[p.dash_key] = p.dash_id
					var res2: String = e.hit(1, p.dash_dx if p.dash_dx != 0.0 else p.face, 0.0, "dash", b)
					if res2 != "":
						stop(0.05)
						shake(0.2)
			elif e.stompable and p.vy > 30.0 and p.prev_bottom <= b.y + minf(8.0, b.h * 0.6):
				var res3: String = e.hit(maxi(1, e.hp), 0.0, 1.0, "stomp", b)       # a stomp always kills in one hit
				p.y = b.y - p.h
				p.bounce(1.0)
				if res3 != "":
					stop(0.05)
			elif p.grace <= 0.0:
				p.hurt(e.dmg, b.x + b.w / 2.0)
			break
	# spikes, liquid, pits
	var hz := hazard_at(p)
	if hz != "":
		p.hazard()
	# springs
	for s in springs:
		if p.vy >= 0.0 and Game.overlap(hb, s) and p.dash_t <= 0.0:
			p.spring(s)

func interact_goals(p) -> void:
	for i in range(cps.size()):
		var c: Dictionary = cps[i]
		var in_r: bool = absf(p.x + p.w / 2.0 - c.x) < 12 and p.y + p.h > c.y - 34 and p.y < c.y
		if not c.on and in_r:
			for o in cps:
				o.on = false
			c.on = true
			cp_index = i
			heal(p, 99)
			p.set_safe(c.x - 5, c.y - p.h)
			ring(c.x, c.y - 22, 3, 26, Game.COL.ok, 0.4)
			burst(c.x, c.y - 22, 14, [Game.COL.ok, Game.COL.okHi, "#ffffff"], 100.0, 100.0, {"glow": 1})
			pop(c.x, c.y - 36, "committed ✓", Game.COL.okHi, true)
			Audio.sfx("checkpoint")
			events.append("checkpoint")
	sign_now = null
	for s in signs:
		if absf(p.x + p.w / 2.0 - s.x) < 26 and absf(p.y + p.h - s.y) < 30:
			sign_now = s

func update_items(dt: float) -> void:
	var p = player
	var pcx: float = p.x + p.w / 2.0
	var pcy: float = p.y + p.h / 2.0
	for it in items:
		if it.get("dead", false):
			continue
		if it.get("loose", false):
			it.t += dt
			if it.t > 0.35 and not p.dead:       # drawn to the nearest living Clawd
				var dx: float = pcx - it.x
				var dy: float = pcy - it.y
				var d := maxf(sqrt(dx * dx + dy * dy), 1e-9)
				if sqrt(dx * dx + dy * dy) == 0.0:
					d = 1.0
				var pull := minf(700.0, 160.0 + it.t * 500.0)
				it.vx = Game.damp(it.vx, (dx / d) * pull, 8.0, dt)
				it.vy = Game.damp(it.vy, (dy / d) * pull, 8.0, dt)
			else:
				it.vy += 520.0 * dt
				if it.vy > 0.0 and grid.solid_at(it.x, it.y + 4):
					it.vy *= -0.5
					it.vx *= 0.7
			it.x += it.vx * dt
			it.y += it.vy * dt
			if it.t > 8.0:
				it.dead = true
		var r := 11.0 if it.kind == "spark" else 9.0
		if not p.dead and not p.gone and absf(pcx - it.x) < r + 3 and absf(pcy - it.y) < r and (not it.get("loose", false) or it.t > 0.2):
			collect(it)
	if items.size() > 40:
		var any := false
		for it in items:
			if it.get("dead", false):
				any = true
				break
		if any:
			items = items.filter(func(i): return not i.get("dead", false))

func collect(it: Dictionary) -> void:
	var p = player
	it.dead = true
	match it.kind:
		"token":
			tokens += 1
			p.add_meter(2 if it.get("loose", false) else 3)
			spark(it.x, it.y, Game.COL.goldHi, 4)
			Audio.sfx("token")
			# every 25 tokens buys back a pip
			if tokens % 25 == 0 and p.hp < p.max_hp:
				heal(p, 1)
				pop(p.x + 5, p.y - 12, "25 tokens: +1", Game.COL.goldHi, true)
				Audio.sfx("heal")
		"spark":
			ring(it.x, it.y, 2, 30, Game.COL.clawdHi, 0.5)
			burst(it.x, it.y, 18, [Game.COL.clawd, Game.COL.clawdHi, "#fff3e4"], 130.0, 60.0, {"glow": 1})
			pop(it.x, it.y - 12, "spark" if it.ghost else "✳ spark found!", "#fff3e4", true)
			stop(0.07)
			Audio.sfx("spark")
			p.add_meter(25)
			events.append("spark")
		"coffee":
			if p.hp < p.max_hp:
				heal(p, 1)
			pop(it.x, it.y - 10, "+1 coffee", Game.COL.paper)
			burst(it.x, it.y, 8, [Game.COL.paper, Game.COL.clawd], 70.0, 100.0)
			Audio.sfx("heal")

func update_projs(_dt: float) -> void:
	pass          # no hostile projectiles in phase 1 (Bug and Typo do not shoot)

# ---------------------------------------------------------------- drawing of what is not an entity
func draw_layer(kind: String, ci: CanvasItem) -> void:
	if kind == "furniture":
		for c in cps:
			ci.draw_texture(Gfx.tex("checkpoint_%d" % (1 if c.on else 0)), Vector2(c.x - 8, c.y - 28))
		for s in signs:
			ci.draw_texture(Gfx.tex("sign"), Vector2(s.x - 8, s.y - 18))
		for s in springs:
			ci.draw_texture(Gfx.tex("spring_%d" % (0 if s.t > 0.0 else 1)), Vector2(s.x - 2, s.y - 7))
		for it in items:
			if it.get("dead", false):
				continue
			var bob := 0 if it.get("loose", false) else floori(sin(time * 3.0 + it.ph) * 1.5 + 0.5)
			var ix := floori(it.x + 0.5)
			var iy := floori(it.y + 0.5) + bob
			match it.kind:
				"token":
					ci.draw_texture(Gfx.tex("token_%d" % (int(time * 7.0 + it.ph * 2.0) % 4)), Vector2(ix - 4, iy - 4))
				"spark":
					var f := int(time * 3.0) % 2
					ci.draw_texture(Gfx.tex(("sparkGhost_%d" if it.ghost else "spark_%d") % f), Vector2(ix - 7, iy - 7))
				"coffee":
					ci.draw_texture(Gfx.tex("coffee"), Vector2(ix - 6, iy - 7))
	elif kind == "top":
		fx.draw(ci)
		if fx.flash > 0.0:
			var c := fx.flash_col
			c.a = minf(1.0, fx.flash)
			ci.draw_rect(Rect2(camera.position, Vector2(W, H)), c)
