class_name Pendulum
extends Enemy
# PENDULUM (p): a weight on a 54 px chain, anchored in its cell. Swings on room time, hurts on contact, cannot be hit.
# Exact port of `class Pendulum` (index.html). The anchor travels in net_fields so the guest draws the chain from the right place.

var ax := 0.0
var ay := 0.0
var bx := 0.0
var by := 0.0
var length := 54.0
var ph := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 12)
	ax = px + 8.0
	ay = py
	no_hit = true
	stompable = false
	dashable = false
	ph = Game.hash3(px, py, 6) * 6.0
	always = false
	place()

func place() -> void:
	var a := sin(room.time * 1.8 + ph) * 1.15
	bx = ax + sin(a) * length
	by = ay + cos(a) * length
	x = bx - 6.0
	y = by - 6.0

func update(_dt: float) -> void:
	place()

func draw_body() -> void:
	if puppet:
		bx = x + 6.0
		by = y + 6.0
	var n := 9
	for i in range(n + 1):
		var u := float(i) / n
		var c := Color("#8b91a3") if i % 2 == 1 else Color("#5c6378")
		draw_rect(Rect2(roundi(lerpf(ax, bx, u)) - 1, roundi(lerpf(ay, by, u)) - 1, 2, 2), c)
	draw_rect(Rect2(ax - 3.0, ay, 6, 3), Color(Game.COL.ink))
	var tx := Gfx.tex("pendulum")
	if tx != null:
		draw_texture(tx, Vector2(roundi(bx) - 9, roundi(by) - 9))

func net_fields() -> Array:
	return [roundi(ax), roundi(ay)]

func net_apply(f: Array) -> void:
	ax = float(f[0])
	ay = float(f[1])
