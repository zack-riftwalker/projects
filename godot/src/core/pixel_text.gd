class_name PixelText
extends RefCounted
# PixelText: draws the bitmap fonts captured from the current game (assets/fonts/big|tiny.png + .json). Port of G.text / G.textW.

static var _fonts := {}

static func _font(tiny: bool) -> Dictionary:
	var key := "tiny" if tiny else "big"
	if not _fonts.has(key):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fonts/%s.json" % key))
		_fonts[key] = {"key": key, "tex": load("res://assets/fonts/%s.png" % key), "h": int(meta.h), "sp": int(meta.sp), "glyphs": meta.glyphs}
	return _fonts[key]

# A few signs the captured fonts do not have (tree lines, arrows, a tick, an ellipsis), drawn from small bitmaps: rows of equal length.
const CUSTOM := {
	"big": {
		"├": ["..#..", "..#..", "..#..", "..###", "..#..", "..#..", "..#.."],
		"└": ["..#..", "..#..", "..#..", "..###", ".....", ".....", "....."],
		"─": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
		"→": [".....", "...#.", "....#", "#####", "....#", "...#.", "....."],
		"←": [".....", ".#...", "#....", "#####", "#....", ".#...", "....."],
		"…": [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],
		"✓": [".....", "....#", "...#.", "#.#..", ".#...", ".....", "....."],
		"—": ["......", "......", "......", "######", "......", "......", "......"],
		"·": [".", ".", ".", "#", ".", ".", "."],
		"∞": [".......", ".......", ".##.##.", "#..#..#", ".##.##.", ".......", "......."],
	},
	"tiny": {
		"├": [".#.", ".#.", ".##", ".#.", ".#."],
		"└": [".#.", ".#.", ".##", "...", "..."],
		"─": ["...", "...", "###", "...", "..."],
		"→": ["..#.", "...#", "####", "...#", "..#."],
		"←": [".#..", "#...", "####", "#...", ".#.."],
		"…": [".....", ".....", ".....", ".....", "#.#.#"],
		"✓": [".....", "....#", "#..#.", ".##..", "....."],
		"—": ["....", "....", "####", "....", "...."],
		"·": [".", ".", "#", ".", "."],
		"∞": [".....", ".#.#.", "#.#.#", ".#.#.", "....."],
	},
}

static func _glyph(f: Dictionary, ch: String) -> Array:
	var g: Dictionary = f.glyphs
	if g.has(ch):
		return g[ch]
	var c: Dictionary = CUSTOM[f.key]
	if c.has(ch):
		return [-1, String(c[ch][0]).length(), ch]
	return g["?"]

# opts: align ("c" | "r"), scale, tiny, shadow (color), outline (color), sp
static func text_width(text: String, opts := {}) -> int:
	var f := _font(opts.get("tiny", false))
	var sc: int = opts.get("scale", 1)
	var sp: int = opts.get("sp", f.sp)
	var w := 0
	for ch in text:
		w += (int(_glyph(f, ch)[1]) + sp) * sc
	return maxi(0, w - sp * sc)

static func _run(ci: CanvasItem, f: Dictionary, text: String, x: int, y: int, col: Color, sc: int, sp: int) -> void:
	for ch in text:
		var gl := _glyph(f, ch)
		if int(gl[0]) < 0:
			var rows: Array = CUSTOM[f.key][ch]
			for ry in range(rows.size()):
				for rx in range(String(rows[ry]).length()):
					if String(rows[ry])[rx] == "#":
						ci.draw_rect(Rect2(x + rx * sc, y + ry * sc, sc, sc), col)
		elif ch != " ":
			ci.draw_texture_rect_region(f.tex, Rect2(x, y, gl[1] * sc, f.h * sc), Rect2(gl[0], 0, gl[1], f.h), col)
		x += (int(gl[1]) + sp) * sc

static func draw_text(ci: CanvasItem, text: String, x: float, y: float, color, opts := {}) -> int:
	var f := _font(opts.get("tiny", false))
	var sc: int = opts.get("scale", 1)
	var sp: int = opts.get("sp", f.sp)
	var w := text_width(text, opts)
	var al: String = opts.get("align", "")
	if al == "c":
		x -= w / 2.0
	elif al == "r":
		x -= w
	var xi := floori(x + 0.5)
	var yi := floori(y + 0.5)
	if opts.has("outline"):
		var oc := Color(opts.outline)
		if oc.a >= 1.0 and Color(color).a >= 1.0 and _plain(f, text):
			_run_outline(ci, f, text, xi, yi, oc, sc, sp)       # (the same pixels as the 8 copies below, in one draw per letter)
		else:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx != 0 or dy != 0:
						_run(ci, f, text, xi + dx * sc, yi + dy * sc, oc, sc, sp)
		if opts.has("shadow"):
			var shc := Color(opts.shadow)
			for dx in range(-1, 2):
				_run(ci, f, text, xi + dx * sc, yi + 2 * sc, shc, sc, sp)
	elif opts.has("shadow"):
		_run(ci, f, text, xi + sc, yi + sc, Color(opts.shadow), sc, sp)
	_run(ci, f, text, xi, yi, Color(color), sc, sp)
	return w

# The outline (brief 05: outlined text was most of the HUD's cost in a boss fight, 9 draws per letter). The 8 copies one pixel away
# cover exactly the font's mask grown by one pixel in every direction (8-neighbour dilation); the fonts are pure white with alpha 0
# or 1, so drawing that grown mask once in the outline colour gives the same pixels. Only for opaque colours (8 translucent copies
# add up where they overlap, and a translucent letter shows what is under it) and the captured glyphs (not the CUSTOM bitmaps).
static func _outlined(f: Dictionary) -> Dictionary:
	if f.has("otex"):
		return f
	var src: Image = f.tex.get_image()
	if src.is_compressed():
		src.decompress()
	var h: int = f.h
	var ox := {}
	var cur := 0
	for ch in f.glyphs:
		ox[ch] = cur
		cur += int(f.glyphs[ch][1]) + 3
	var img := Image.create(maxi(1, cur), h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ch in f.glyphs:
		var gx0 := int(f.glyphs[ch][0])
		var gw := int(f.glyphs[ch][1])
		for gy in range(h):
			for gx in range(gw):
				if src.get_pixel(gx0 + gx, gy).a > 0.5:
					for dy in range(3):
						for dx in range(3):
							img.set_pixel(int(ox[ch]) + gx + dx, gy + dy, Color(1, 1, 1, 1))
	f["otex"] = ImageTexture.create_from_image(img)
	f["ox"] = ox
	return f

static func _plain(f: Dictionary, text: String) -> bool:
	var c: Dictionary = CUSTOM[f.key]
	for ch in text:
		if c.has(ch) and not f.glyphs.has(ch):
			return false
	return true

static func _run_outline(ci: CanvasItem, f: Dictionary, text: String, x: int, y: int, col: Color, sc: int, sp: int) -> void:
	var o := _outlined(f)
	var ox: Dictionary = o.ox
	var tex: Texture2D = o.otex
	var g: Dictionary = f.glyphs
	for ch in text:
		var key: String = ch if g.has(ch) else "?"
		var gw := int(g[key][1])
		if ch != " ":
			ci.draw_texture_rect_region(tex, Rect2(x - sc, y - sc, (gw + 2) * sc, (f.h + 2) * sc), Rect2(int(ox[key]), 0, gw + 2, f.h + 2), col)
		x += (gw + sp) * sc

# G.wrap: word wrap to maxw pixels
static func wrap(text: String, maxw: int, opts := {}) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var t := (line + " " + word) if line != "" else word
			if line != "" and text_width(t, opts) > maxw:
				out.append(line)
				line = word
			else:
				line = t
		out.append(line)
	return out
