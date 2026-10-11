class_name Lint
extends Enemy
# LINT (l horizontal, L vertical): a warning that floats back and forth on a sine and cannot be stomped.
# Exact port of `class Lint` (index.html).

var hx := 0.0
var hy := 0.0
var vertical := false
var range_px := 30.0

func _init(r: Room, px: float, py: float, is_vertical := false) -> void:
	super(r, px, py - 2.0, 11, 11)
	hx = x
	hy = y
	vertical = is_vertical
	hp = 2
	stompable = false
	col = "#b9b0d0"

func update(dt: float) -> void:
	tick(dt)
	var o := sin(t * 1.6) * range_px
	if vertical:
		y = hy + o
		x = hx
	else:
		x = hx + o
		y = hy + sin(t * 3.1) * 3.0

func draw_body() -> void:
	spr("lint_%d" % (int(t * 5.0) % 2), false, 1.0, 1.0, 2.0)

func net_fields() -> Array:
	return []

func net_apply(_f: Array) -> void:
	pass
