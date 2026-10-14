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
const SKY_DIM := 0.66                  # the sky gradient is a little darker than the palette's colours (tuned with the contrast test, MVGN-17)
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
var tear_t := 0.0                      # a packet-loss tear is running (seconds left): rows of the backdrop are shifted sideways (MVGN-12)
var bands: Array = []                  # [[screen y0, y1, shift px]] of the running tear
var tears := 0                         # how many tears happened (the tests read it)
var packet_lost := {}                  # packet j -> was it lost last frame
var warn_on := false                   # a packet is about to be lost: the towers' LEDs blink magenta
var chase_red := 0.0                   # how red the LEDs are now (0 normal .. 1 red); fades back over 2 s when the chase ends
var chase_front := -1e9                # the RST line's y on screen while the chase runs (LEDs above it are red)
var crawler_done := false              # boss:CRAWLER was beaten: the web strands are broken
var strand_t0 := -1.0                  # room time the strands fell (-1: not falling)
var clean := false                     # the FIREWALL is down: fewer flickering LEDs, more green dots on the cables
var strands: Node2D
var dirty_strands := true
var wave_last := -1.0
var chase_end_t := -1.0
var chase_step := -99                  # the chase wave redraws the towers whenever its front passed another LED row
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
	shafts.material = Look.unshaded(true)
	haze_a = _haze(0.5)
	towers = _layer(_draw_towers)
	strands = _layer(_draw_strands)
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
	crawler_done = Game.flag("boss:CRAWLER")                  # a fresh load shows the end state (flags, not events)
	clean = look != null and look.mood == "stable_clean"
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
	n.material = Look.unshaded()                 # the backdrop is graded by its own colours, not by the ambient
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
		s.material = Look.unshaded()
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

# the living backdrop (MVGN-12): everything is derived from the room's clock, flags and packet state, which both pages have
func _live(dt: float, cy: float) -> void:
	var calm := Game.reduce_flash
	var t: float = room.time
	# N17: the RST line turns the LEDs red from the top down, they fade back over 2 s after the chase
	if room.def.has("chase"):
		if room.ch_t0 >= 0.0:
			chase_front = (-32.0 + float(room.def.chase.speed) * (t - room.ch_t0)) - cy
			chase_red = 1.0
			chase_end_t = -1.0
		else:
			if chase_red >= 1.0 and chase_end_t < 0.0:
				chase_end_t = t                                           # (the fade is the room's clock, so both pages fade together)
			chase_front = 1e9
			chase_red = clampf(1.0 - (t - chase_end_t) / 2.0, 0.0, 1.0) if chase_end_t >= 0.0 else chase_red
		var st := floori(chase_front / 7.0) if chase_front < 1e8 else 9999
		if (st != chase_step or (room.ch_t0 < 0.0 and chase_red > 0.0)) and t - wave_last >= 0.1:      # (a tower redraw is ~600 rects: 10 a second at most)
			chase_step = st
			wave_last = t
			towers.queue_redraw()
	# N12: a packet that was just lost tears the backdrop for 150 ms; one about to be lost makes the LEDs blink magenta
	var any_warn := false
	for m in room.plats:
		if not m.get("packet", false):
			continue
		var j := int(m.j)
		var lost: bool = m.get("lost", false)
		if lost and not bool(packet_lost.get(j, false)) and not calm:
			tears += 1
			tear_t = t + 0.15                                             # (the room's clock again)
			bands.clear()
			var nb := 2 + int(Game.hash3(tears, j, 71) * 3.0)
			for b in range(nb):
				var y0 := 12.0 + Game.hash3(tears * 7 + b, j, 72) * 160.0
				bands.append([y0, y0 + 10.0 + Game.hash3(tears, b, 73) * 18.0, (Game.hash3(tears, b + 5, 74) * 2.0 - 1.0) * 6.0])
			if look != null:
				look.pulse_ca(0.6 * float(look.out.glitch))
		packet_lost[j] = lost
		if m.get("warn", false):
			any_warn = true
	if tear_t > 0.0:
		if t >= tear_t:
			tear_t = 0.0
			bands.clear()
			towers.queue_redraw()
			skyline.queue_redraw()
			racks.queue_redraw()
	if any_warn != warn_on:
		warn_on = any_warn
		towers.queue_redraw()
	# N08 / N09: the web strands hang until the crawler is beaten; the frame it dies they fall for 1.5 s, then they hang broken
	var done := Game.flag("boss:CRAWLER")
	if done and not crawler_done:
		crawler_done = true
		strand_t0 = t
	if strand_t0 >= 0.0 and t - strand_t0 > 1.5:
		strand_t0 = -1.0
		dirty_strands = true
	var c := look != null and look.mood == "stable_clean"
	if c != clean:
		clean = c
		dirty = true

# a rect of a backdrop layer, clipped into the rows of a running tear and shifted per band (no tear: a plain rect)
func _r(ci: CanvasItem, r: Rect2, c: Color) -> void:
	if bands.is_empty():
		ci.draw_rect(r, c)
		return
	var oy: float = (ci as Node2D).position.y
	var y := r.position.y
	var y1 := r.end.y
	for b in bands:
		var b0: float = float(b[0]) - oy
		var b1: float = float(b[1]) - oy
		if b1 <= y or b0 >= y1:
			continue
		if b0 > y:
			ci.draw_rect(Rect2(r.position.x, y, r.size.x, b0 - y), c)
			y = b0
		var ye := minf(b1, y1)
		ci.draw_rect(Rect2(r.position.x + float(b[2]), y, r.size.x, ye - y), c)
		y = ye
	if y < y1:
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, y1 - y), c)

# ---- look ----
func _out() -> Dictionary:
	return look.base if look != null and not look.base.is_empty() else Look.mixed("stable", 1.0)

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
	if look != null and look.base_rev != last_rev:
		last_rev = look.base_rev
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
		strands.queue_redraw()
		var fog: Color = _out().fog
		for s in haze_a + haze_b:
			s.modulate = Color(fog.r, fog.g, fog.b, fog.a)
	var cx: float = room.cam.x
	var cy: float = room.cam.y
	_live(dt, cy)
	position = Vector2(cx, cy)                                   # the sky is fixed on screen; the layers below move by hand
	skyline.position = Vector2(-fposmod(cx * 0.04, P_FAR), -cy * 0.02)
	towers.position = Vector2(-fposmod(cx * 0.12, PERIOD), -cy * 0.05)
	strands.position = towers.position
	racks.position = Vector2(-fposmod(cx * 0.55, P_RACK), -cy * 0.25)
	shafts.position = Vector2(-fposmod(cx * 0.2, P_SHAFT), 0.0)
	if tier >= 2:
		shafts.modulate.a = 0.65 + 0.35 * sin(room.time * 0.5)
	if tier >= 1:
		var t: float = room.time
		for k in range(3):
			haze_a[k].position = Vector2(-fposmod(t * 2.0 + cx * 0.08, float(HAZE_W)) + k * HAZE_W, 96.0 - cy * 0.03)
			haze_b[k].position = Vector2(-fposmod(t * 4.0 + cx * 0.4, float(HAZE_W)) + k * HAZE_W, 138.0 - cy * 0.1)
	var tk := floori(room.time * (10.0 if warn_on else 2.0))
	if tk != tick:
		tick = tk
		towers.queue_redraw()
	if tear_t > 0.0 or strand_t0 >= 0.0:
		towers.queue_redraw()
		skyline.queue_redraw()
		racks.queue_redraw()
	cables.queue_redraw()
	if strands.visible and (strand_t0 >= 0.0 or dirty_strands):
		strands.queue_redraw()
		dirty_strands = false

# ---- layer 0 ----
func _draw_sky(ci: CanvasItem) -> void:
	var o := _out()
	var far: Color = o.sky_far
	var mid: Color = o.sky_mid
	var prev := Color()
	for i in range(SKY_BANDS):
		var col := far.lerp(mid, pow(float(i) / (SKY_BANDS - 1), 1.3)) * SKY_DIM
		col.a = 1.0
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
			_r(ci, Rect2(bx, by, bw, bh + 40.0), body)
			if Game.hash3(i, 10, 6 + sd) < 0.4:                              # an antenna
				_r(ci, Rect2(bx + bw * 0.5, by - 8.0, 1, 8), body)
			for w in range(int(bw / 8.0)):
				if Game.hash3(i * 13 + w, 11, 6 + sd) < 0.22:
					var c := win_a if Game.hash3(i, w, 12 + sd) < 0.6 else win_b
					c.a = 0.55
					_r(ci, Rect2(bx + 3.0 + w * 8.0, by + 4.0 + floorf(Game.hash3(i, w, 13 + sd) * 3.0) * 6.0, 2, 1), c)

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
			_r(ci, Rect2(tx, ty, tw, th + 120.0), fill)               # (+120: the layer rises with the camera, no gap under the towers)
			_r(ci, Rect2(tx, ty, tw, 1), edge)
			_r(ci, Rect2(tx, ty, 1, th + 120.0), edge)
			_r(ci, Rect2(tx + tw - 1, ty, 1, th + 120.0), edge)
		for ld in leds:
			var i: int = ld[0]
			var r: int = ld[1]
			var c: int = ld[2]
			var col: Color = lb if ld[4] else la
			var lit := Game.hash3(i * 131 + r * 17 + c, tk, 67 + sd) < (0.3 if clean else 0.55) or float(ld[3]) > (0.92 if clean else 0.8)
			if not lit:
				col.a = 0.18
			elif calm and float(ld[3]) > 0.5:
				col.a = 0.55
			var ly := 214.0 - _th(i) + 4.0 + r * 7.0
			if warn_on and float(ld[3]) < 0.5:                                    # about to lose a packet: magenta, blinking (steady with Reduce flashing)
				col = Color("#FF2BD6")
				col.a = 1.0 if (Game.reduce_flash or (tk & 1) == 0) else 0.3
			if chase_red > 0.0 and ly + tower_dy() <= chase_front or (chase_red > 0.0 and chase_front > 1e8):
				col = col.lerp(Color("#FF2A2A"), chase_red)
				col.a = maxf(col.a, 0.8 * chase_red)
			_r(ci, Rect2(float(i) * 47.0 - 30.0 + copy * PERIOD + 3.0 + c * 5.0, ly, 1, 1), col)

# the towers layer's screen y offset (-cam.y * 0.05): the LEDs' own y plus this is where they are on screen
func tower_dy() -> float:
	return towers.position.y

# how many LEDs are red now (tests): the same predicate as the drawing
func red_leds() -> int:
	var n := 0
	if chase_red <= 0.0:
		return 0
	for ld in leds:
		var ly := 214.0 - _th(int(ld[0])) + 4.0 + float(ld[1]) * 7.0
		if ly + tower_dy() <= chase_front or chase_front > 1e8:
			n += 1
	return n * 2

# ---- layer 3: cables, every frame ----
func _draw_cables(ci: CanvasItem) -> void:
	draws += 1
	var o := _out()
	var cable := _g((o.sky_mid as Color).lerp(o.accent_a, 0.4))
	var dot: Color = (o.accent_a as Color).lerp(Color.WHITE, 0.4)
	var ndots := 4
	if clean:
		dot = (o.accent_b as Color).lerp(Color.WHITE, 0.3)                          # the calm network: more, green dots
		ndots = 7
	var cy: float = room.cam.y if room != null else 0.0
	var t: float = room.time if room != null else 0.0
	var span := 150.0 / float(ncables)
	for k in range(ncables):
		var y0 := 50.0 + k * span * 0.8 - cy * 0.12
		var sag := 14.0 + (k % 3) * 4.0
		var pts := PackedVector2Array()
		for s in range(0, 13):
			var u := float(s) / 12.0
			pts.append(Vector2(u * (W + 40.0) - 20.0, y0 + sin(u * PI) * sag))
		ci.draw_polyline(pts, cable, 2.0)
		var plen := float(W + 40)
		for d in range(ndots):
			var u2 := fposmod((t * 60.0 + float(d) * plen / float(ndots) + k * 37.0) / plen, 1.0)
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
			_r(ci, Rect2(rx, ry, rw, rh + 300.0), body)
			for s in range(int(rh / 6.0)):
				_r(ci, Rect2(rx + 3.0, ry + 3.0 + s * 6.0, rw - 6.0, 1), slot)
				if Game.hash3(i * 17 + s, 23, 6 + sd) < 0.12:
					var c := lamp
					c.a = 0.75
					_r(ci, Rect2(rx + rw - 6.0, ry + 3.0 + s * 6.0 - 1.0, 2, 2), c)

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

# ---- N08 / N09: web strands between the tower roofs (the towers' parallax), intact until boss:CRAWLER, hanging broken after it ----
func strand_state() -> String:
	if not (room.id == "N08" or room.id == "N09"):
		return "none"
	if strand_t0 >= 0.0:
		return "falling"
	return "broken" if crawler_done else "intact"

func _draw_strands(ci: CanvasItem) -> void:
	var state := strand_state()
	if state == "none":
		return
	var o := _out()
	var col: Color = (o.accent_a as Color).lerp(Color.WHITE, 0.55)
	col.a = 0.5
	var u := 1.0 if state == "broken" else (0.0 if state == "intact" else clampf((room.time - strand_t0) / 1.5, 0.0, 1.0))
	u = u * u * (3.0 - 2.0 * u)
	for copy in range(2):
		for i in range(NT - 1):
			var ax := float(i) * 47.0 + 10.0 - 40.0 + copy * PERIOD + _tw(i) * 0.5
			var ay := 214.0 - _th(i)
			var bx := float(i + 1) * 47.0 + 10.0 - 40.0 + copy * PERIOD + _tw(i + 1) * 0.5
			var by := 214.0 - _th(i + 1)
			if Game.hash3(i, 40, 6 + sd) < 0.35:
				continue
			var sag := 10.0 + Game.hash3(i, 41, 6 + sd) * 12.0
			var drop := 14.0 + Game.hash3(i, 42, 6 + sd) * 22.0
			var pts := PackedVector2Array()
			for k in range(0, 13):
				var f := float(k) / 12.0
				var ix := lerpf(ax, bx, f)
				var iy := lerpf(ay, by, f) + sin(f * PI) * sag                     # intact: a sagging strand
				# broken: each half hangs from its own roof (the middle is gone); falling: it drops from the intact curve to the hanging one
				var fx := ax + (bx - ax) * minf(f, 0.5) * 0.12 if f < 0.5 else bx + (ax - bx) * (1.0 - f) * 0.12
				var fy := (ay if f < 0.5 else by) + drop * (2.0 * f if f < 0.5 else 2.0 * (1.0 - f)) + sin(room.time * 1.3 + float(i)) * 1.0 * u
				pts.append(Vector2(lerpf(ix, fx, u), lerpf(iy, fy, u)))
			if u > 0.98:                                                              # broken: two loose halves with a gap in the middle
				ci.draw_polyline(pts.slice(0, 6), col, 1.0)
				ci.draw_polyline(pts.slice(7, 13), col, 1.0)
			else:
				ci.draw_polyline(pts, col, 1.0)
			if u < 0.5:
				ci.draw_rect(Rect2(pts[6].x - 1.0, pts[6].y - 1.0, 3, 3), Color(col.r, col.g, col.b, 0.9))       # the knot
