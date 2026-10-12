class_name NetBackdrop
extends Node2D
# NetBackdrop: the sky of THE NETWORK (world 6), drawn with shapes: the JS game has no such backdrop and its builders are private.
# A dithered night gradient, a far layer of router towers with blinking LEDs (parallax 0.12 / 0.05) and a mid layer of fibre cables sagging
# between them with light dots running along (0.3 / 0.12). Deterministic: only hashes and the room's clock, so both pages draw the same.

const W := 384
const H := 216
const SKY := ["#0b0f24", "#0d1230", "#10143a", "#13164a", "#16184f", "#191a58", "#1a1050", "#1c1458"]

var room: Room
var draws := 0

func _process(_dt: float) -> void:
	if room == null or room.camera == null:
		return
	position = Vector2(room.cam.x, room.cam.y)          # the sky is fixed on screen; the layers below move by hand
	queue_redraw()

func _draw() -> void:
	draws += 1
	var cx: float = room.cam.x if room != null else 0.0
	var cy: float = room.cam.y if room != null else 0.0
	var t: float = room.time if room != null else 0.0
	for i in range(SKY.size()):
		draw_rect(Rect2(0, i * H / SKY.size(), W, H / SKY.size() + 1), Color(SKY[i]))
		if i > 0:                                         # a dithered seam between two bands (a 1-px checker)
			var y0 := i * H / SKY.size()
			for x in range(0, W, 2):
				draw_rect(Rect2(x + (y0 & 1), y0 - 1, 1, 1), Color(SKY[i]))
	# far layer: router towers
	var tower_edge := Color("#24306a")
	var tower_fill := Color("#141a3a")
	var base := 214.0 - cy * 0.05
	for i in range(9):
		var tw := 18.0 + Game.hash3(i, 1, 6) * 16.0
		var th := 60.0 + Game.hash3(i, 2, 6) * 90.0
		var tx := fposmod(float(i) * 47.0 + 10.0 - cx * 0.12, 460.0) - 40.0
		var ty := base - th
		draw_rect(Rect2(tx, ty, tw, th), tower_fill)
		draw_rect(Rect2(tx, ty, tw, 1), tower_edge)
		draw_rect(Rect2(tx, ty, 1, th), tower_edge)
		draw_rect(Rect2(tx + tw - 1, ty, 1, th), tower_edge)
		var rows := int(th / 7.0)
		var cols := int((tw - 4.0) / 5.0)
		var tick := floori(t * 2.0)
		for r in range(rows):
			for c in range(cols):
				var h := Game.hash3(i * 31 + c, r, 66)
				if h < 0.35:
					continue
				var on := Game.hash3(i * 131 + r * 17 + c, tick, 67) < 0.55 or h > 0.8
				var col := Color("#5ad1ff") if Game.hash3(i, r * 7 + c, 68) < 0.6 else Color("#ff6ad5")
				if not on:
					col.a = 0.18
				draw_rect(Rect2(tx + 3.0 + c * 5.0, ty + 4.0 + r * 7.0, 1, 1), col)
	# mid layer: three fibre cables with light dots
	for k in range(3):
		var y0 := 60.0 + k * 34.0 - cy * 0.12
		var shift := cx * 0.3
		var pts := PackedVector2Array()
		for s in range(0, 25):
			var u := float(s) / 24.0
			pts.append(Vector2(u * (W + 40.0) - 20.0, y0 + sin(u * PI) * (14.0 + k * 4.0)))
		draw_polyline(pts, Color("#24306a"), 2.0)
		var plen := float(W + 40)
		for d in range(4):
			var u2 := fposmod((t * 60.0 + float(d) * plen / 4.0 + k * 37.0) / plen - shift / plen * 0.0, 1.0)
			var px := u2 * (W + 40.0) - 20.0
			var py := y0 + sin(u2 * PI) * (14.0 + k * 4.0)
			draw_rect(Rect2(px, py - 1, 2, 2), Color("#9ae8ff"))
