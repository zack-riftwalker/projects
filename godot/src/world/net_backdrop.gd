class_name NetBackdrop
extends Node2D
# NetBackdrop: the sky of THE NETWORK (world 6), drawn with shapes: the JS game has no such backdrop and its builders are private.
# A dithered night gradient, a far layer of router towers with blinking LEDs (parallax 0.12 / 0.05) and a mid layer of fibre cables sagging
# between them with light dots running along (0.3 / 0.12). Deterministic: only hashes and the room's clock, so both pages draw the same.
# Cost: it used to draw ~2500 rects (and parse colours, hash every LED) every frame, the main lag of the network rooms on a phone.
# Now the sky is drawn once, the towers only when their LEDs blink (twice a second) and slide by moving their node; only the cables run per frame.

const W := 384
const H := 216
const SKY := ["#0b0f24", "#0d1230", "#10143a", "#13164a", "#16184f", "#191a58", "#1a1050", "#1c1458"]
const PERIOD := 460.0                  # the towers' wrap (tower x = fposmod(base - cx * 0.12, PERIOD) - 40)
const C_EDGE := Color("#24306a")
const C_FILL := Color("#141a3a")
const C_LED_A := Color("#5ad1ff")
const C_LED_B := Color("#ff6ad5")
const C_DOT := Color("#9ae8ff")

var room: Room
var draws := 0
var sky: Node2D
var towers: Node2D
var cables: Node2D
var leds: Array = []                   # per LED: [tower, x, y, h, colour] (the parts that never change)
var tick := -1

func _init() -> void:
	sky = _layer(_draw_sky)
	towers = _layer(_draw_towers)
	cables = _layer(_draw_cables)
	for i in range(9):
		var tw := 18.0 + Game.hash3(i, 1, 6) * 16.0
		var th := 60.0 + Game.hash3(i, 2, 6) * 90.0
		for r in range(int(th / 7.0)):
			for c in range(int((tw - 4.0) / 5.0)):
				var h := Game.hash3(i * 31 + c, r, 66)
				if h >= 0.35:
					leds.append([i, r, c, h, C_LED_A if Game.hash3(i, r * 7 + c, 68) < 0.6 else C_LED_B])

func _layer(cb: Callable) -> Node2D:
	var n := DrawProxy.new()
	n.cb = cb
	add_child(n)
	return n

func _process(_dt: float) -> void:
	if room == null or room.camera == null:
		return
	position = Vector2(room.cam.x, room.cam.y)          # the sky is fixed on screen; the layers below move by hand
	towers.position = Vector2(-fposmod(room.cam.x * 0.12, PERIOD), -room.cam.y * 0.05)
	var tk := floori(room.time * 2.0)
	if tk != tick:
		tick = tk
		towers.queue_redraw()
	cables.queue_redraw()

func _draw_sky(ci: CanvasItem) -> void:
	for i in range(SKY.size()):
		var col := Color(SKY[i])
		ci.draw_rect(Rect2(0, i * H / SKY.size(), W, H / SKY.size() + 1), col)
		if i > 0:                                         # a dithered seam between two bands (a 1-px checker)
			var y0 := i * H / SKY.size()
			for x in range(0, W, 2):
				ci.draw_rect(Rect2(x + (y0 & 1), y0 - 1, 1, 1), col)

# drawn at the towers' unshifted places, twice (one period apart): the node's offset slides and wraps them
func _draw_towers(ci: CanvasItem) -> void:
	var tk := maxi(tick, 0)
	for copy in range(2):
		for i in range(9):
			var tw := 18.0 + Game.hash3(i, 1, 6) * 16.0
			var th := 60.0 + Game.hash3(i, 2, 6) * 90.0
			var tx := float(i) * 47.0 + 10.0 - 40.0 + copy * PERIOD
			var ty := 214.0 - th
			ci.draw_rect(Rect2(tx, ty, tw, th), C_FILL)
			ci.draw_rect(Rect2(tx, ty, tw, 1), C_EDGE)
			ci.draw_rect(Rect2(tx, ty, 1, th), C_EDGE)
			ci.draw_rect(Rect2(tx + tw - 1, ty, 1, th), C_EDGE)
		for ld in leds:
			var i: int = ld[0]
			var r: int = ld[1]
			var c: int = ld[2]
			var th2 := 60.0 + Game.hash3(i, 2, 6) * 90.0
			var col: Color = ld[4]
			if not (Game.hash3(i * 131 + r * 17 + c, tk, 67) < 0.55 or float(ld[3]) > 0.8):
				col.a = 0.18
			ci.draw_rect(Rect2(float(i) * 47.0 - 30.0 + copy * PERIOD + 3.0 + c * 5.0, 214.0 - th2 + 4.0 + r * 7.0, 1, 1), col)

func _draw_cables(ci: CanvasItem) -> void:
	draws += 1
	var cy: float = room.cam.y if room != null else 0.0
	var t: float = room.time if room != null else 0.0
	for k in range(3):
		var y0 := 60.0 + k * 34.0 - cy * 0.12
		var pts := PackedVector2Array()
		for s in range(0, 25):
			var u := float(s) / 24.0
			pts.append(Vector2(u * (W + 40.0) - 20.0, y0 + sin(u * PI) * (14.0 + k * 4.0)))
		ci.draw_polyline(pts, C_EDGE, 2.0)
		var plen := float(W + 40)
		for d in range(4):
			var u2 := fposmod((t * 60.0 + float(d) * plen / 4.0 + k * 37.0) / plen, 1.0)
			var px := u2 * (W + 40.0) - 20.0
			var py := y0 + sin(u2 * PI) * (14.0 + k * 4.0)
			ci.draw_rect(Rect2(px, py - 1, 2, 2), C_DOT)
