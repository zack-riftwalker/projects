class_name ClawdDraw
extends RefCounted
# ClawdDraw: Clawd is drawn live from rectangles so it can squash, stretch, blink and look around.
# Port of G.drawClawd / G.clawdPixels (js/art.js). (x, y) is the point between the feet; one unit = one pixel of the mascot.

const LEGX := [-6, -4, 3, 5]

static func _r(v: float) -> int:
	return floori(v + 0.5)

static func draw_clawd(ci: CanvasItem, x: float, y: float, o: Dictionary) -> void:
	var u: float = o.get("u", 1.0)
	var sx: float = o.get("sx", 1.0) * u
	var sy: float = o.get("sy", 1.0) * u
	var legs: Array = o.get("legs", [2, 2, 2, 2])
	var lift: float = o.get("lift", 0)
	var a_l: float = o.get("armL", 0)
	var a_r: float = o.get("armR", 0)
	var reach: float = o.get("reach", 0)
	var f: float = o.get("face", 1)
	var alpha: float = o.get("alpha", 1.0)
	var body := Color(o.get("col", Game.COL.clawd))
	body.a = alpha
	var rect := func(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
		var a := _r(x + x0 * sx)
		var b := _r(y + y0 * sy)
		ci.draw_rect(Rect2(a, b, maxi(1, _r(x + x1 * sx) - a), maxi(1, _r(y + y1 * sy) - b)), col)
	rect.call(-6, -10 + lift, 6, -2 + lift, body)
	rect.call(-8 - (reach if f < 0 else 0), -6 + a_l + lift, -6, -4 + a_l + lift, body)
	rect.call(6, -6 + a_r + lift, 8 + (reach if f > 0 else 0), -4 + a_r + lift, body)
	for i in range(4):
		if legs[i] > 0:
			rect.call(LEGX[i], -2 + lift, LEGX[i] + 1, -2 + lift + legs[i], body)
	if not o.get("noEyes", false):
		var ex: float = o.get("eyeX", f)
		var ey: float = o.get("eyeY", 0) + lift
		var ec := Color(o.get("eyeCol", Game.COL.eye))
		ec.a = alpha
		var eyes: String = o.get("eyes", "")
		if eyes == "hurt":
			rect.call(-5 + ex, -7 + ey, -3 + ex, -6 + ey, ec)
			rect.call(3 + ex, -7 + ey, 5 + ex, -6 + ey, ec)
		elif eyes == "shut" or o.get("blink", false):
			rect.call(-4 + ex, -7 + ey, -3 + ex, -6 + ey, ec)
			rect.call(3 + ex, -7 + ey, 4 + ex, -6 + ey, ec)
		elif eyes == "wide":
			rect.call(-4 + ex, -9 + ey, -3 + ex, -6 + ey, ec)
			rect.call(3 + ex, -9 + ey, 4 + ex, -6 + ey, ec)
		else:
			rect.call(-4 + ex, -8 + ey, -3 + ex, -6 + ey, ec)
			rect.call(3 + ex, -8 + ey, 4 + ex, -6 + ey, ec)

# the exact pixel layout, for effects that take Clawd apart
static func clawd_pixels() -> Array:
	var out: Array = []
	for y in range(-10, 0):
		for x in range(-8, 8):
			var body: bool = x >= -6 and x < 6 and y < -2
			var arm: bool = (x < -6 or x >= 6) and y >= -6 and y < -4
			var leg: bool = y >= -2 and (x == -6 or x == -4 or x == 3 or x == 5)
			var eye: bool = (x == -3 or x == 4) and y >= -8 and y < -6
			if body or arm or leg:
				out.append({"x": x, "y": y, "eye": eye})
	return out
