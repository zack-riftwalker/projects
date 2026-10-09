class_name Gfx
extends RefCounted
# Gfx: sprite loading and the bottom-centre sprite anchor of G.spr (js/gfx.js).

static var _tex := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/sprites/%s.png" % name)
	return _tex[name]

static func rnd(v: float) -> int:
	return floori(v + 0.5)

# draw `name` centred on x with its bottom on y; optional flip and squash (G.spr)
static func spr(ci: CanvasItem, name: String, x: float, y: float, flip := false, sx := 1.0, sy := 1.0) -> void:
	var t := tex(name)
	if t == null:
		return
	var w := t.get_width()
	var h := t.get_height()
	if not flip and sx == 1.0 and sy == 1.0:
		ci.draw_texture(t, Vector2(rnd(x - w / 2.0), rnd(y - h)))
		return
	ci.draw_set_transform(Vector2(rnd(x), rnd(y)), 0.0, Vector2(-sx if flip else sx, sy))
	ci.draw_texture(t, Vector2(-w / 2.0, -h))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# G.panel: the notched panel the UI uses
static func panel(ci: CanvasItem, x: float, y: float, pw: float, ph: float, fill, edge, shade = null) -> void:
	var xi := rnd(x)
	var yi := rnd(y)
	var wi := rnd(pw)
	var hi := rnd(ph)
	var e := Color(edge)
	ci.draw_rect(Rect2(xi + 1, yi, wi - 2, hi), e)
	ci.draw_rect(Rect2(xi, yi + 1, wi, hi - 2), e)
	var f := Color(fill)
	ci.draw_rect(Rect2(xi + 2, yi + 1, wi - 4, hi - 2), f)
	ci.draw_rect(Rect2(xi + 1, yi + 2, wi - 2, hi - 4), f)
	if shade != null:
		ci.draw_rect(Rect2(xi + 2, yi + hi - 2, wi - 4, 1), Color(shade))

# a sprite with its top-left at (x, y), like ctx.drawImage
static func spr_at(ci: CanvasItem, name: String, x: float, y: float) -> void:
	var t := tex(name)
	if t != null:
		ci.draw_texture(t, Vector2(x, y))
