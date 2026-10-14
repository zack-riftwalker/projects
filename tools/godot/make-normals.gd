extends SceneTree
# Makes the normal maps of GFX-N (MVGN-06) with Godot's own Image (no dependencies).
#   w6_tiles_n.png  from w6_tiles.png (16 columns x 7 rows of 16-px tiles, the layout of RoomView.make_tileset):
#     height = 0.35 * luminance + 0.65 * a 2-px bevel along every exposed edge (row = variant; the column is the join mask: bit 0 up, 1 down, 2 left,
#     3 right = "joins a wall"; a clear bit is an exposed edge. Row 4 (one-way platforms) is exposed on top and where it does not join.)
#     Sobel (3x3, inside the tile only) -> normal, strength 1.5. Transparent pixels get the flat normal.
#   <sprite>_n.png  for the creature sprites of the NETWORK (SPRITES below): the same without the bevel, with the sprite's own silhouette
#     as the edge (height falls off over 2 px next to a transparent pixel).
# Run: godot --headless --path godot -s ../tools/godot/make-normals.gd
const STRENGTH := 1.5
const SPRITES := ["drone_0", "drone_1", "drone_2", "drone_3", "bug_0", "bug_1", "noodle_0", "noodle_1", "noodle_2", "noodle_3", "flaky_0", "flaky_1", "flakyMad_0", "flakyMad_1",
	"lint_0", "lint_1", "logger_0", "logger_1", "typo_0", "typo_1", "ghost_0", "ghost_1", "ghost_2", "mimic_0", "mimic_1", "mimic_2", "racer_0", "racer_1",
	"spiky_0", "spiky_1", "slime_0", "slime_1", "slimeS_0", "slimeS_1", "platform_w6", "gate", "checkpoint_0", "checkpoint_1", "spring_0", "spring_1", "crumble", "cracked"]

func _init() -> void:
	var img := Image.load_from_file("res://assets/tiles/w6_tiles.png")
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.5, 0.5, 1.0, 1.0))
	for r in range(7):
		for c in range(16):
			_tile(img, out, c, r)
	out.save_png("res://assets/tiles/w6_tiles_n.png")
	var n := 0
	for s in SPRITES:
		var p := "res://assets/sprites/%s.png" % s
		if not FileAccess.file_exists(p):
			continue
		var si := Image.load_from_file(p)
		si.convert(Image.FORMAT_RGBA8)
		var so := Image.create(si.get_width(), si.get_height(), false, Image.FORMAT_RGBA8)
		so.fill(Color(0.5, 0.5, 1.0, 1.0))
		_normal(si, so, 0, 0, si.get_width(), si.get_height(), [false, false, false, false], true)
		so.save_png("res://assets/sprites/%s_n.png" % s)
		n += 1
	print("normal maps written: tiles + %d sprites" % n)
	quit()

func _tile(src: Image, dst: Image, c: int, r: int) -> void:
	var up := false
	var dn := false
	var lf := false
	var rt := false
	if r <= 3:
		up = (c & 1) == 0
		dn = (c & 2) == 0
		lf = (c & 4) == 0
		rt = (c & 8) == 0
	elif r == 4:
		var m := c % 4
		up = true
		lf = (m & 1) == 0
		rt = (m & 2) == 0
	_normal(src, dst, c * 16, r * 16, 16, 16, [up, dn, lf, rt], false)

# height of the pixel (x, y) inside the rect: luminance + bevel
func _h(src: Image, x0: int, y0: int, w: int, h: int, ex: Array, silhouette: bool, x: int, y: int) -> float:
	x = clampi(x, 0, w - 1)
	y = clampi(y, 0, h - 1)
	var col := src.get_pixel(x0 + x, y0 + y)
	if col.a < 0.1:
		return 0.0
	var lum := 0.299 * col.r + 0.587 * col.g + 0.114 * col.b
	var bev := 1.0
	if silhouette:                                     # the distance to the nearest transparent pixel (within 2 px)
		for d in range(1, 3):
			for o in [Vector2i(d, 0), Vector2i(-d, 0), Vector2i(0, d), Vector2i(0, -d)]:
				var qx: int = x + o.x
				var qy: int = y + o.y
				if qx < 0 or qy < 0 or qx >= w or qy >= h or src.get_pixel(x0 + qx, y0 + qy).a < 0.1:
					bev = minf(bev, float(d - 1) / 2.0 + 0.25)
	else:
		if ex[0]: bev = minf(bev, clampf(float(y) / 2.0, 0.0, 1.0))
		if ex[1]: bev = minf(bev, clampf(float(h - 1 - y) / 2.0, 0.0, 1.0))
		if ex[2]: bev = minf(bev, clampf(float(x) / 2.0, 0.0, 1.0))
		if ex[3]: bev = minf(bev, clampf(float(w - 1 - x) / 2.0, 0.0, 1.0))
	return 0.35 * lum + 0.65 * bev

func _normal(src: Image, dst: Image, x0: int, y0: int, w: int, h: int, ex: Array, silhouette: bool) -> void:
	var hm := []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(_h(src, x0, y0, w, h, ex, silhouette, x, y))
		hm.append(row)
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x0 + x, y0 + y).a < 0.1:
				continue
			var xl := maxi(x - 1, 0)
			var xr := mini(x + 1, w - 1)
			var yu := maxi(y - 1, 0)
			var yd := mini(y + 1, h - 1)
			var dx: float = (hm[yu][xr] + 2.0 * hm[y][xr] + hm[yd][xr]) - (hm[yu][xl] + 2.0 * hm[y][xl] + hm[yd][xl])
			var dy: float = (hm[yd][xl] + 2.0 * hm[yd][x] + hm[yd][xr]) - (hm[yu][xl] + 2.0 * hm[yu][x] + hm[yu][xr])
			var n := Vector3(-dx / 8.0 * STRENGTH * 3.0, -dy / 8.0 * STRENGTH * 3.0, 1.0).normalized()
			dst.set_pixel(x0 + x, y0 + y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
