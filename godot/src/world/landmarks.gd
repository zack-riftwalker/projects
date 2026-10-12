class_name Landmarks
extends Node2D
# Landmarks: far shapes in the backdrop behind the tiles (MVB1-14), seen from several rooms of a zone: THREAD TOWER's brass columns and clock face,
# the pale lantern of the garbage collector whose light sweeps, PRODUCTION's low red glow with rising specks. Drawn with shapes, dark and low in
# contrast so they never hide the playfield. They drift at 0.15 of the camera, so they stay far away, and wrap so they come back on a long room.

const W := 384
const H := 216
const PARALLAX := 0.15
const PERIOD := 640.0

var room: Room
var kinds: Array = []
var t := 0.0
var draws := 0                          # how many times it was drawn (the tests read it)

func _process(dt: float) -> void:
	t += dt
	if room == null or room.camera == null:
		return
	# the node follows the camera, minus the part of its movement the landmark does not share: it appears to move at PARALLAX of it
	var cx: float = room.cam.x
	var cy: float = room.cam.y
	position = Vector2(cx - fposmod(cx * PARALLAX, PERIOD), cy * 0.9)
	queue_redraw()

func _draw() -> void:
	draws += 1
	for k in kinds:
		match String(k):
			"tower": _tower()
			"lantern": _lantern()
			"horizon": _horizon()
			"ci": _ci()

# three thin brass columns and a clock face, far top right
func _tower() -> void:
	var brass := Color(0.55, 0.42, 0.22, 0.34)
	var dark := Color(0.2, 0.15, 0.1, 0.4)
	for i in range(3):
		var x := 292.0 + i * 20.0
		draw_rect(Rect2(x, 40.0 + (1 - i % 2) * 8.0, 4, 190), brass)
		draw_rect(Rect2(x + 3, 40.0 + (1 - i % 2) * 8.0, 1, 190), dark)
	draw_rect(Rect2(286, 36, 56, 5), brass)
	var c := Vector2(322, 30)
	draw_circle(c, 17.0, dark)
	draw_circle(c, 15.0, Color(0.62, 0.5, 0.3, 0.3))
	draw_circle(c, 12.0, Color(0.12, 0.1, 0.14, 0.55))
	for h in range(12):
		var a := h * TAU / 12.0
		draw_line(c + Vector2(cos(a), sin(a)) * 9.5, c + Vector2(cos(a), sin(a)) * 11.0, Color(0.7, 0.58, 0.34, 0.4), 1.0)
	var ha := t * 0.05
	draw_line(c, c + Vector2(cos(ha), sin(ha)) * 7.0, Color(0.7, 0.58, 0.34, 0.5), 1.0)
	draw_line(c, c + Vector2(cos(ha * 12.0), sin(ha * 12.0)) * 10.0, Color(0.7, 0.58, 0.34, 0.4), 1.0)

# a pale lantern, far away; its light sweeps slowly
func _lantern() -> void:
	var p := Vector2(86, 70)
	var ang := sin(t * 0.35) * 0.9
	var dir := Vector2(cos(ang + 1.2), sin(ang + 1.2))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([p, p + dir * 170.0 + side * 34.0, p + dir * 170.0 - side * 34.0]), Color(0.75, 0.95, 0.9, 0.06))
	draw_colored_polygon(PackedVector2Array([p, p + dir * 120.0 + side * 16.0, p + dir * 120.0 - side * 16.0]), Color(0.75, 0.95, 0.9, 0.06))
	draw_rect(Rect2(p.x - 4, p.y - 12, 8, 3), Color(0.3, 0.34, 0.36, 0.5))
	draw_rect(Rect2(p.x - 3, p.y - 9, 6, 9), Color(0.7, 0.9, 0.85, 0.28))
	draw_rect(Rect2(p.x - 1, p.y - 7, 2, 5), Color(0.9, 1.0, 0.95, 0.4))
	draw_rect(Rect2(p.x - 1, p.y, 2, 40), Color(0.3, 0.34, 0.36, 0.35))

# a thin diagonal line of light across the upper sky with three brighter dots running along it (the network seen from far away), parallax 0.05
func _ci() -> void:
	var cx: float = room.cam.x if room != null else 0.0
	var off := fposmod(cx * PARALLAX, PERIOD) - fposmod(cx * 0.05, PERIOD)       # (this node moves at 0.15: undo the difference)
	var a := Vector2(W * 0.2 + off, 30.0)
	var b := Vector2(W * 0.8 + off, 12.0)
	draw_line(a, b, Color(0.6, 0.91, 1.0, 0.5), 1.0)
	for i in range(3):
		var u := fposmod(t / 2.5 + float(i) / 3.0, 1.0)
		var p := a.lerp(b, u)
		draw_rect(Rect2(p.x - 1, p.y - 1, 2, 2), Color(0.85, 0.97, 1.0, 0.75))

# PRODUCTION on fire at the horizon: a low red glow with specks that rise
func _horizon() -> void:
	for i in range(11):
		draw_rect(Rect2(0, 76 + i * 11, W, 12), Color(0.95, 0.22, 0.12, 0.03 + 0.026 * i))
	for i in range(18):
		var ph := fposmod(t * (0.12 + 0.05 * float(i % 3)) + float(i) * 0.37, 1.0)
		var sx := fposmod(float(i) * 61.0 + sin(t * 0.7 + float(i)) * 6.0, W)
		var sy := 190.0 - ph * 100.0
		draw_rect(Rect2(sx, sy, 1, 1), Color(1.0, 0.6, 0.3, 0.6 * (1.0 - ph)))
