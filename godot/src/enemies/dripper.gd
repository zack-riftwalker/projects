class_name Dripper
extends Enemy
# DRIPPER (i): a leaking pipe in the ceiling. Grows a drop for 0.55 s, lets it fall, waits 1.7 s. Not alive, cannot be hit.
# Exact port of `class Dripper` (index.html). Its drops are memory leaks: they always use world 3's liquid colours.

var cd := 0.0
var grow := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 4, 4)
	x = px + 6.0
	y = py
	no_hit = true
	passive = true
	cd = Game.hash3(px, py, 8) * 2.0

func update(dt: float) -> void:
	cd -= dt
	if grow > 0.0:
		grow -= dt
		if grow <= 0.0:
			room.shoot(x + 2.0, y + 5.0, 0.0, 20.0, {"kind": "drip", "col": Game.theme(3).liq, "g": 520.0, "r": 2.0, "cut": false})
			cd = 1.7
	elif cd <= 0.0:
		grow = 0.55

func draw_body() -> void:
	var th: Dictionary = Game.theme(room.world)
	draw_rect(Rect2(x - 1.0, y, 6, 2), Color(th.liqLo))
	if grow > 0.0:
		var s := ceili((1.0 - grow / 0.55) * 4.0)
		draw_rect(Rect2(x + 1.0, y + 2.0, 2, s), Color(th.liq))
		draw_rect(Rect2(x, y + 1.0 + s, 4, 2), Color(th.liq))

func net_fields() -> Array:
	return [roundi(grow * 100.0)]

func net_apply(f: Array) -> void:
	grow = f[0] / 100.0
