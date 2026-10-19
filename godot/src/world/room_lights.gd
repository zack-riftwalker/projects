class_name RoomLights
extends Node2D
# RoomLights (MVGN-05): the 2D lights of a NETWORK room, under the room (so a hidden room lights nothing: fact 8 of the plan).
# One pooled PointLight2D per active light; every frame the wanted lights are listed by priority (players, bosses, projectiles nearest the camera,
# static LEDs / signs / benches / door frames in view, glowing particles on Ultra) and the first `budget` of them take a pool light. Budget per tier:
# Low 6 (players + bosses only), High 24, Ultra 48. Cosmetic: it only reads room state, it never writes any.

const BUDGET := [6, 24, 48]
const CULL := 110.0                       # statics further than this outside the view are not listed
const TEX := 128.0

static var tex_soft: Texture2D
static var tex_cone: Texture2D

var room: Room
var pool: Array = []
var statics: Array = []                    # {x, y, r, e, k}  k: 0 accent_a, 1 accent_b, 2 green terminal
var active := 0
var wanted := 0                            # how many lights were wanted last frame (before the budget cut)
var extra: Array = []                      # arena lights other code adds each frame: {x, y, r, e, col, prio, cone?}

static func textures() -> void:
	if tex_soft == null:
		tex_soft = load("res://assets/fx/light_soft.png")
		tex_cone = load("res://assets/fx/light_cone.png")

func _ready() -> void:
	textures()
	z_index = 0
	for c in room.cps:
		statics.append({"x": float(c.x), "y": float(c.y) - 8.0, "r": 44.0, "e": 0.75, "k": 1})
	for s in room.signs:
		statics.append({"x": float(s.x), "y": float(s.y) - 12.0, "r": 38.0, "e": 0.55, "k": 0})
	for st in room.stations:
		statics.append({"x": float(st.x) + 6.0, "y": float(st.y) + 8.0, "r": 34.0, "e": 0.6, "k": 2})
	for d in room.grid.doors:
		var a: int = d.a
		var b: int = d.b
		var mid := float(a + b + 1) * 8.0
		var p := Vector2.ZERO
		match String(d.side):
			"W": p = Vector2(10.0, mid)
			"E": p = Vector2(float(room.pw) - 10.0, mid)
			"N": p = Vector2(mid, 10.0)
			"S": p = Vector2(mid, float(room.ph) - 10.0)
		statics.append({"x": p.x, "y": p.y, "r": 40.0, "e": 0.5, "k": 0})
	# the LEDs of the towers are in the backdrop (far away): they are not lights; terminals come from the signs / stations above

func _light(i: int) -> PointLight2D:
	while pool.size() <= i:
		var l := PointLight2D.new()
		l.texture = tex_soft
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		l.height = 20.0
		l.visible = false
		add_child(l)
		pool.append(l)
	return pool[i]

func _process(_dt: float) -> void:
	if room == null or not room.is_local or room.look == null or room.camera == null:
		return
	var tier := Game.gfx_tier
	var budget: int = BUDGET[tier]
	var o: Dictionary = room.look.out
	var ca: Color = o.accent_a
	var cb: Color = o.accent_b
	var cam := Vector2(room.cam.x + 192.0, room.cam.y + 108.0)
	var c: Array = []                                   # [prio, dist, x, y, r, e, col, cone]
	var pc := Color(Game.COL.clawd).lerp(ca, 0.3)
	var mine = room.player
	if mine != null:
		_players(c, mine, pc, cam)
	for rp in room.remote_players:
		_players(c, rp, pc, cam)
	var bs = room.boss
	if bs != null and is_instance_valid(bs) and not bs.gone:
		if not (bs is CrawlerBoss):
			c.append([1, 0.0, bs.x + bs.w * 0.5, bs.y + bs.h * 0.5, 96.0, 0.9, cb.lerp(Color.WHITE, 0.2), null, false])
		_arena(c, bs, ca, cb)
	if room.hall != null:
		_hall_lights(c)
	if room.hpot != null:
		_hpot_lights(c)
	for e in extra:
		c.append([int(e.get("prio", 1)), 0.0, float(e.x), float(e.y), float(e.r), float(e.e), e.col, e.get("cone", null), false])
	if tier >= 1:
		var pr: Array = []
		for q in room.projs:
			if q.dead:
				continue
			var d := Vector2(q.x, q.y).distance_to(cam)
			if d < 260.0:
				pr.append([2, d, float(q.x), float(q.y), 28.0 + float(q.r) * 2.0, 0.8, Color(q.col).lerp(Color.WHITE, 0.25), null, false])
		pr.sort_custom(func(a, b): return a[1] < b[1])
		c.append_array(pr.slice(0, 30))
		var st: Array = []
		for s in statics:
			var d2 := Vector2(s.x, s.y).distance_to(cam)
			if absf(s.x - cam.x) < 192.0 + CULL and absf(s.y - cam.y) < 108.0 + CULL:
				st.append([3, d2, s.x, s.y, s.r, s.e, ca if s.k == 0 else (cb if s.k == 1 else Color("#58f0c8")), null, false])
		st.sort_custom(func(a, b): return a[1] < b[1])
		c.append_array(st)
		if tier >= 2:                                       # glowing particles: a short-lived light, at most 6 at once
			var n := 0
			for i in range(room.fx.list.size() - 1, -1, -1):
				var p = room.fx.list[i]
				if int(p.get("glow", 0)) == 1 and float(p.get("life", 0.0)) > 0.05:
					c.append([4, 0.0, float(p.x), float(p.y), 22.0, 0.5 * clampf(float(p.life) / maxf(float(p.get("max", 1.0)), 0.01), 0.0, 1.0), Color(p.col), null, false])
					n += 1
					if n >= 6:
						break
	wanted = c.size()
	c.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	active = mini(c.size(), budget)
	for i in range(active):
		var w: Array = c[i]
		var l := _light(i)
		l.visible = true
		l.position = Vector2(w[2], w[3])
		l.color = w[6]
		l.energy = w[5]
		l.shadow_enabled = bool(w[8]) and tier >= 2                 # shadows: Ultra only, and only the lights that ask (MVGN-16)
		if l.shadow_enabled:
			l.shadow_color = Color(o.sky_far.r, o.sky_far.g, o.sky_far.b, 0.6)
			l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		if w[7] == null:
			l.texture = tex_soft
			l.texture_scale = w[4] * 2.0 / TEX
			l.rotation = 0.0
		else:
			l.texture = tex_cone
			l.texture_scale = w[4] / TEX * 1.0
			l.rotation = float(w[7])
			l.offset = Vector2(TEX * 0.5, 0.0)
	for i in range(active, pool.size()):
		if not pool[i].visible:
			break
		pool[i].visible = false
	Game.gfx_stats.lights = active

func _players(c: Array, p, col: Color, cam: Vector2) -> void:
	if p.get("dead") == true:
		return
	if p.material == null:                                     # players are never darkened: unshaded, and they carry the light that lights the ground
		p.material = Look.unshaded()
	var dk: float = room.hall.dark if room.hall != null else 0.0        # the crawler's dark: Clawd's own light shrinks to just enough to see itself
	c.append([0, 0.0, p.x + p.w * 0.5, p.y + p.h * 0.5, lerpf(74.0, 22.0, dk), lerpf(0.9, 0.4, dk), col, null, false])

# the arenas' own lights (MVGN-13): the crawler's eyes and its strands' beams, the firewall's shield, the reviewer's overheads and unresolved comments
func _arena(c: Array, bs, ca: Color, cb: Color) -> void:
	match String(room.id):
		"N09":
			if bs is CrawlerBoss:
				var cb2: CrawlerBoss = bs
				var crt := Color("#c8ffd8") if cb2.ph < 2 else Color("#ffcf9a")
				c.append([1, 0.0, cb2.core_px, cb2.core_y - 8.0, 46.0 if not cb2.lights_out() else 30.0, 0.9, crt, null, false])   # the monitor lights its own face from below
				if not cb2.lights_out():
					for i in range(8):                            # the eight red LEDs
						if i == 6 and cb2.legs_ok < 8:
							continue
						var tip: Vector2 = cb2._leg_points(i)[3]
						c.append([2, 0.0, tip.x, tip.y, 16.0, 0.8, Color(1.0, 0.25, 0.3), null, false])
				if room.time - cb2.flash_t0 < 0.22:                 # the flash: the whole hall, for a moment
					c.append([0, 0.0, 192.0, 170.0, 420.0, 1.6 * (1.0 - (room.time - cb2.flash_t0) / 0.22), Color.WHITE, null, false])
		"N22":
			if bs is Reviewer2:
				for i in range(3):                                # three cold overheads (shadows on Ultra)
					c.append([1, 0.0, float(room.pw) * (0.2 + 0.3 * float(i)), 18.0, 120.0, 0.65, Color(0.82, 0.9, 1.0), null, true])
				for h in bs.hz:                                   # unresolved comments glow
					c.append([2, 0.0, float(h.v[0]), Boss.FLOOR - 6.0, 24.0, 0.8 if bs.hz_live(h, room.time) else 0.4, Color("#FF4B5C"), null, false])

# the crawler's hall (IndexHall): its tubes, its screen and its cocoons, lit or not from the hall's own state (also after the fight)
func _hall_lights(c: Array) -> void:
	var hl: IndexHall = room.hall
	for i in range(IndexHall.ZONES.size()):
		if (hl.zones >> i) & 1 == 1 and hl.dark < 0.95:
			c.append([2, 0.0, IndexHall.ZONES[i], 214.0, 110.0, 0.75 * (1.0 - hl.dark), Color("#ff4fd8") if i % 2 == 0 else Color("#4ff0ff"), null, false])
	if String(hl.screen.get("mode", "home")) != "off":
		c.append([2, 0.0, IndexHall.SCREEN.get_center().x, IndexHall.SCREEN.get_center().y, 90.0, 0.7 * (1.0 - hl.dark * 0.7), Color("#d6f6e0"), null, false])
	for co in IndexHall.COCOONS:
		c.append([3, 0.0, co[0], co[1], 18.0, 0.35, Color(0.8, 0.95, 0.75), null, false])

# the honeypot hall (HoneypotHall): two warm lamps and the sunny window in the lobby; the furnace's grates, a glow per packet and the hot floor after it.
# From the hall's own state, so the lobby is lit before the fight and the burned shell after it
func _face_light_x(fw: FirewallBoss, wall: int) -> float:
	return fw._wall_x(wall) + (-16.0 if wall == 0 else 16.0)

func _hpot_lights(c: Array) -> void:
	var hp: HoneypotHall = room.hpot
	if hp.stage == 0:
		c.append([2, 0.0, 124.0, 140.0, 44.0, 0.3, Color("#ffcf8a"), null, false])
		c.append([2, 0.0, 152.0, 112.0, 44.0, 0.3, Color("#ffcf8a"), null, false])
		c.append([2, 0.0, 130.0, 62.0, 70.0, 0.18, Color("#cfe8ff"), null, false])
		return
	if hp.stage == 3:
		c.append([2, 0.0, 130.0, 58.0, 90.0, 0.5, Color("#cfe8ff"), null, false])
		return
	var ix: Vector2 = hp.inner_x()
	var x: float = ix.x + 40.0
	while x < ix.y - 20.0:                                   # the grates in the furnace floor
		c.append([3, 0.0, x, HoneypotHall.FURN_Y - 6.0, 46.0, 0.5, Color("#ff7a2a"), null, false])
		x += 72.0
	var fb = room.boss
	if fb is FirewallBoss and not fb.gone and not fb.dying:
		var fw: FirewallBoss = fb
		for fc in fw.faces():                                 # the faces glow red on their walls
			c.append([1, 0.0, _face_light_x(fw, int(fc[0])), float(fc[1]), 80.0, 0.9, Color("#ff5a3a"), null, false])
		if fw.ph == 3 and fw.shift_k == 0:                    # phase 3: a red alarm strobe, 1 Hz
			var pulse := 0.5 + 0.5 * sin(room.time * TAU)
			c.append([0, 0.0, 192.0, 300.0, 400.0, 0.12 + 0.4 * pulse, Color("#ff3a2a"), null, false])
	for m in hp.pool:
		if not m.off and not m.lost:
			var col := Color("#58f0c8")
			if m.green:
				col = Color("#57ff8a")
			if m.warn:
				col = Color("#ff5a4a")
			c.append([2, 0.0, float(m.x) + 32.0, float(m.y), 28.0, 0.45, col, null, false])
