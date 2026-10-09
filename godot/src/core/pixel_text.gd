class_name PixelText
extends RefCounted
# PixelText: draws the bitmap fonts captured from the current game (assets/fonts/big|tiny.png + .json). Port of G.text / G.textW.

static var _fonts := {}

static func _font(tiny: bool) -> Dictionary:
	var key := "tiny" if tiny else "big"
	if not _fonts.has(key):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fonts/%s.json" % key))
		_fonts[key] = {"tex": load("res://assets/fonts/%s.png" % key), "h": int(meta.h), "sp": int(meta.sp), "glyphs": meta.glyphs}
	return _fonts[key]

static func _glyph(f: Dictionary, ch: String) -> Array:
	var g: Dictionary = f.glyphs
	return g[ch] if g.has(ch) else g["?"]

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
		if ch != " ":
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
