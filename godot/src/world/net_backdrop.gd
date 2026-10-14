class_name NetBackdrop
extends Node2D
# NetBackdrop v2 (MVGN-04): the sky of THE NETWORK (world 6), drawn with shapes, in five depth layers plus haze, coloured by the room's Look (mood).
#   0 sky (fixed)            gradient sky_far -> sky_mid, dithered seams
#   1 far skyline (0.04)     low server halls, a few accent windows
#   2 towers (0.12)          router towers, blinking LEDs (accent_a / accent_b)
#   3 cable bundles (0.30)   sagging fibre cables with running packet dots
#   4 near racks (0.55)      big dark rack silhouettes, rare status lights
# + haze bands between 1-2 and 3-4 (a generated texture scrolled by position) and, on Ultra, light shafts (additive, breathing via modulate).
# Deterministic: only hashes (seeded by the room number, so rooms differ), the room's clock and the Look, so both pages draw the same.
# Speed (CLAUDE.md rule): static layers are their own nodes, drawn once and moved by position; they are redrawn only when the Look changes (a door
# blend: at most 12 times a second), the towers also twice a second (blink), the cables every frame (a few polylines). Tiers (Game.gfx_tier):
# Low has sky + towers + cables, High adds skyline, racks, haze, Ultra adds the shafts.
# Grading: structure colours (skyline, towers, cables, racks) are multiplied by Look bg_brightness / bg_saturation; the sky gradient and the LEDs are not
# (the sky is the designed colour, LEDs are emissive). The structure is darker than the terrain (the contrast rule, §3.7 of the plan).

const W := 384
const H := 216
const PERIOD := 460.0                  # the towers' wrap (tower x = fposmod(base - cx * 0.12, PERIOD) - 40)
const P_FAR := 600.0                   # the far skyline's wrap
const P_RACK := 520.0                  # the racks' wrap
const P_SHAFT := 520.0
const HAZE_W := 256
const SKY_BANDS := 8
const NT := 9                          # towers per period

var room: Room
var draws := 0                         # cable redraws (the tests read it: it must keep counting)
var static_draws := 0                  # redraws of the static layers (the tests read it: it must stay flat while the look does)
var look: Look
var sky: Node2D
var skyline: Node2D
var towers: Node2D
var cables: Node2D
var racks: Node2D
var shafts: Node2D
var haze_a: Array = []
var haze_b: Array = []
var leds: Array = []                   # per LED: [tower, row, col, hash, use accent b] (the parts that never change)
var tick := -1
var sd := 0                          # from the room number: every room has its own skyline
var ncables := 3
var tier := -1
var dirty := true
var last_rev := -1
var last_redraw := -1.0
var clock := 0.0
static var haze_tex: ImageTexture

func _init() -> void:
	sky = _layer(_draw_sky)
	skyline = _layer(_draw_skyline)
	shafts = _layer(_draw_shafts)
	var ma := CanvasItemMaterial.new()
	ma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	shafts.material = ma
	haze_a = _haze(0.5)
	towers = _layer(_draw_towers)
	cables = _layer(_draw_cables)
	haze_b = _haze(0.7)
	racks = _layer(_draw_racks)

func _ready() -> void:
	if room != null:
		var digits := String(room.id).substr(1)
		sd = int(digits) * 7 if digits.is_valid_int() else 0
		look = room.look
	ncables = 3 + int(Game.hash3(sd, 3, 6) * 3.0)          # three to five
	for i in range(NT):
		var tw := _tw(i)
		var th := _th(i)
		for r in range(int(th / 7.0)):
			for c in range(int((tw - 4.0) / 5.0)):
				var h := Game.hash3(i * 31 + c, r, 66 + sd)
				if h >= 0.35:
					leds.append([i, r, c, h, Game.hash3(i, r * 7 + c, 68 + sd) >= 0.6])
	Game.gfx_changed.connect(_apply_tier)
	_apply_tier()

func _exit_tree() -> void:
	if Game.gfx_changed.is_connected(_apply_tier):
		Game.gfx_changed.disconnect(_apply_tier)

func _tw(i: int) -> float:
	return 18.0 + Game.hash3(i, 1, 6 + sd) * 16.0

func _th(i: int) -> float:
	return 60.0 + Game.hash3(i, 2, 6 + sd) * 90.0

func _layer(cb: Callable) -> Node2D:
	var n := DrawProxy.new()
	n.cb = cb
	add_child(n)
	return n

# a haze band: three sprites of one generated, horizontally seamless texture (soft in x and y), tinted with the fog colour
func _haze(_pf: float) -> Array:
	if haze_tex == null:
		var img := Image.create(HAZE_W, 64, false, Image.FORMAT_RGBA8)
		for x in range(HAZE_W):
			var u := float(x) / HAZE_W * TAU
			var n := 0.55 + 0.22 * sin(u * 2.0 + 1.3) + 0.15 * sin(u * 5.0 + 0.4) + 0.08 * sin(u * 9.0 + 2.1)
			for y in range(64):
				var b := sin(PI * float(y) / 63.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(b * b * n, 0.0, 1.0)))
		haze_tex = ImageTexture.create_from_image(img)
	var out: Array = []
	for i in range(3):
		var s := Sprite2D.new()
		s.texture = haze_tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.scale = Vector2(1.0, 1.6)
		add_child(s)
		out.append(s)
	return out

func _apply_tier() -> void:
	tier = Game.gfx_tier
	skyline.visible = tier >= 1
	racks.visible = tier >= 1
	for s in haze_a + haze_b:
		s.visible = tier >= 1
	shafts.visible = tier >= 2
	dirty = true

func layer_count() -> int:
	return 3 if tier == 0 else 5

# ---- look ----
func _out() -> Dictionary:
	return look.out if look != null and not look.out.is_empty() else Look.mixed("stable", 1.0)

# the structure colours' grade (brightness, saturation)
func _g(c: Color) -> Color:
	var o := _out()
	var l := c.get_luminance()
	var s := float(o.bg_saturation)
	var b := float(o.bg_brightness)
	return Color(lerpf(l, c.r, s) * b, lerpf(l, c.g, s) * b, lerpf(l, c.b, s) * b, c.a)

func _process(dt: float) -> void:
	if room == null or room.camera == null or not room.is_local:
		return
	clock += dt
	if look != null and look.rev != last_rev:
		last_rev = look.rev
		dirty = true
	if dirty and (clock - last_redraw >= 0.08 or look == null or look.reached()):
		dirty = false
		last_redraw = clock
		static_draws += 1
		sky.queue_redraw()
		if tier >= 1:
			skyline.queue_redraw()
			racks.queue_redraw()
			shafts.queue_redraw()
		towers.queue_redraw()
		var fog: Color = _out().fog
		for s in haze_a + haze_b:
			s.modulate = Color(fog.r, fog.g, fog.b, fog.a)
	var cx: float = room.cam.x
	var cy: float = room.cam.y
	position = Vector2(cx, cy)                                   # the sky is fixed on screen; the layers below move by hand
	skyline.position = Vector2(-fposmod(cx * 0.04, P_FAR), -cy * 0.02)
	towers.position = Vector2(-fposmod(cx * 0.12, PERIOD), -cy * 0.05)
	racks.position = Vector2(-fposmod(cx * 0.55, P_RACK), -cy * 0.25)
	shafts.position = Vector2(-fposmod(cx * 0.2, P_SHAFT), 0.0)
	if tier >= 2:
		shafts.modulate.a = 0.65 + 0.35 * sin(room.time * 0.5)
	if tier >= 1:
		var t: float = room.time
		for k in range(3):
			haze_a[k].position = Vector2(-fposmod(t * 2.0 + cx * 0.08, float(HAZE_W)) + k * HAZE_W, 96.0 - cy * 0.03)
			haze_b[k].position = Vector2(-fposmod(t * 4.0 + cx * 0.4, float(HAZE_W)) + k * HAZE_W, 138.0 - cy * 0.1)
	var tk := floori(room.time * 2.0)
	if tk != tick:
		tick = tk
		towers.queue_redraw()
	cables.queue_redraw()

# ---- layer 0 ----
func _draw_sky(ci: CanvasItem) -> void:
	var o := _out()
	var far: Color = o.sky_far
	var mid: Color = o.sky_mid
	var prev := Color()
	for i in range(SKY_BANDS):
		var col := far.lerp(mid, pow(float(i) / (SKY_BANDS - 1), 1.3))
		var y0 := i * H / SKY_BANDS
		ci.draw_rect(Rect2(0, y0, W, H / SKY_BANDS + 1), col)
		if i > 0:                                         # a dithered seam between two bands (a 1-px checker)
			for x in range(0, W, 2):
				ci.draw_rect(Rect2(x + (y0 & 1), y0 - 1, 1, 1), col)
		prev = col

# ---- layer 1: far skyline, drawn at its unshifted place, twice (one period apart) ----
func _draw_skyline(ci: CanvasItem) -> void:
	var o := _out()
	var body := _g((o.sky_mid as Color).lerp(o.accent_a, 0.10))
	var win_a: Color = o.accent_a
	var win_b: Color = o.accent_b
	for copy in range(2):
		for i in range(12):
			var bx := float(i) * 50.0 + Game.hash3(i, 7, 6 + sd) * 14.0 + copy * P_FAR
			var bw := 24.0 + Game.hash3(i, 8, 6 + sd) * 34.0
			var bh := 14.0 + Game.hash3(i, 9, 6 + sd) * 28.0
			var by := 206.0 - bh
			ci.draw_rect(Rect2(bx, by, bw, bh + 40.0), body)
			if Game.hash3(i, 10, 6 + sd) < 0.4:                              # an antenna
				ci.draw_rect(Rect2(bx + bw * 0.5, by - 8.0, 1, 8), body)
			for w in range(int(bw / 8.0)):
				if Game.hash3(i * 13 + w, 11, 6 + sd) < 0.22:
					var c := win_a if Game.hash3(i, w, 12 + sd) < 0.6 else win_b
					c.a = 0.55
					ci.draw_rect(Rect2(bx + 3.0 + w * 8.0, by + 4.0 + floorf(Game.hash3(i, w, 13 + sd) * 3.0) * 6.0, 2, 1), c)

# ---- layer 2: towers at the unshifted places, twice ----
func _draw_towers(ci: CanvasItem) -> void:
	var tk := maxi(tick, 0)
	var o := _out()
	var fill := _g((o.sky_mid as Color).lerp(o.sky_far, 0.15))
	var edge := _g((o.sky_mid as Color).lerp(o.accent_a, 0.35))
	var la: Color = o.accent_a
	var lb: Color = o.accent_b
	var calm := float(o.glitch) <= 0.0
	for copy in range(2):
		for i in range(NT):
			var tw := _tw(i)
			var th := _th(i)
			var tx := float(i) * 47.0 + 10.0 - 40.0 + copy * PERIOD
			var ty := 214.0 - th
			ci.draw_rect(Rect2(tx, ty, tw, th + 120.0), fill)               # (+120: the layer rises with the camera, no gap under the towers)
			ci.draw_rect(Rect2(tx, ty, tw, 1), edge)
			ci.draw_rect(Rect2(tx, ty, 1, th + 120.0), edge)
			ci.draw_rect(Rect2(tx + tw - 1, ty, 1, th + 120.0), edge)
		for ld in leds:
			var i: int = ld[0]
			var r: int = ld[1]
			var c: int = ld[2]
			var col: Color = lb if ld[4] else la
			if not (Game.hash3(i * 131 + r * 17 + c, tk, 67 + sd) < 0.55 or float(ld[3]) > 0.8):
				col.a = 0.18
			elif calm and float(ld[3]) > 0.5:
				col.a = 0.55
			ci.draw_rect(Rect2(float(i) * 47.0 - 30.0 + copy * PERIOD + 3.0 + c * 5.0, 214.0 - _th(i) + 4.0 + r * 7.0, 1, 1), col)

# ---- layer 3: cables, every frame ----
func _draw_cables(ci: CanvasItem) -> void:
	draws += 1
	var o := _out()
	var cable := _g((o.sky_mid as Color).lerp(o.accent_a, 0.4))
	var dot: Color = (o.accent_a as Color).lerp(Color.WHITE, 0.4)
	var cy: float = room.cam.y if room != null else 0.0
	var t: float = room.time if room != null else 0.0
	var span := 150.0 / float(ncables)
	for k in range(ncables):
		var y0 := 50.0 + k * span * 0.8 - cy * 0.12
		var sag := 14.0 + (k % 3) * 4.0
		var pts := PackedVector2Array()
		for s in range(0, 25):
			var u := float(s) / 24.0
			pts.append(Vector2(u * (W + 40.0) - 20.0, y0 + sin(u * PI) * sag))
		ci.draw_polyline(pts, cable, 2.0)
		var plen := float(W + 40)
		for d in range(4):
			var u2 := fposmod((t * 60.0 + float(d) * plen / 4.0 + k * 37.0) / plen, 1.0)
			var px := u2 * (W + 40.0) - 20.0
			var py := y0 + sin(u2 * PI) * sag
			ci.draw_rect(Rect2(px, py - 1, 2, 2), dot)

# ---- layer 4: near racks at the unshifted places, twice ----
func _draw_racks(ci: CanvasItem) -> void:
	var o := _out()
	var body := _g((o.sky_mid as Color).lerp(o.sky_far, 0.35)) * 0.8
	body.a = 1.0
	var slot := _g((o.sky_mid as Color).lerp(o.accent_a, 0.22))
	slot.a = 0.9
	var lamp: Color = o.accent_b
	for copy in range(2):
		for i in range(5):
			var rx := float(i) * 104.0 + Game.hash3(i, 20, 6 + sd) * 30.0 + copy * P_RACK
			var rw := 34.0 + Game.hash3(i, 21, 6 + sd) * 18.0
			var rh := 50.0 + Game.hash3(i, 22, 6 + sd) * 50.0
			var ry := 216.0 - rh
			ci.draw_rect(Rect2(rx, ry, rw, rh + 300.0), body)
			for s in range(int(rh / 6.0)):
				ci.draw_rect(Rect2(rx + 3.0, ry + 3.0 + s * 6.0, rw - 6.0, 1), slot)
				if Game.hash3(i * 17 + s, 23, 6 + sd) < 0.12:
					var c := lamp
					c.a = 0.75
					ci.draw_rect(Rect2(rx + rw - 6.0, ry + 3.0 + s * 6.0 - 1.0, 2, 2), c)

# ---- Ultra: light shafts (soft diagonal wedges from ceiling LEDs, additive) ----
func _draw_shafts(ci: CanvasItem) -> void:
	var o := _out()
	var col: Color = o.accent_a
	for copy in range(2):
		for i in range(3):
			var x0 := 40.0 + float(i) * 170.0 + Game.hash3(i, 30, 6 + sd) * 50.0 + copy * P_SHAFT
			var lean := 70.0 + Game.hash3(i, 31, 6 + sd) * 50.0
			var wd := 16.0 + Game.hash3(i, 32, 6 + sd) * 14.0
			for layer in range(3):                                      # three nested wedges: a soft core
				var a := 0.028 + layer * 0.014
				var k := 1.0 - layer * 0.28
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + wd * k, 0), Vector2(x0 + lean + wd * 1.8 * k, H), Vector2(x0 + lean - wd * 0.2, H)]), Color(col.r, col.g, col.b, a))
