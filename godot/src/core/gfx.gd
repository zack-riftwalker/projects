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
