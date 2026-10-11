class_name Drone
extends Enemy
# DRONE (d): a hotfix drone. Hovers 66 px to the side and 46 px above the nearest player, shoots after a 0.5 s warning.
# Exact port of `class Drone` (index.html).

var cd := 1.5
var aim := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py - 6.0, 14, 10)
	hp = 2
	col = "#8a92a8"
	loot = 3

func update(dt: float) -> void:
	tick(dt)
	var tp := to_player()
	var p = tp.p
	if tp.d < 210.0:
		cd -= dt
		var side := -1.0 if cx < p.x else 1.0
		var tx: float = p.x + 5.0 + side * 66.0 - w / 2.0
		var ty: float = p.y - 46.0
		if aim <= 0.0 and stun <= 0.0:
			var nx := Game.damp(x, tx, 1.3, dt)
			var ny := Game.damp(y, ty, 1.3, dt)
			if not room.grid.box_hits_solid(nx, y, w, h):
				x = nx
			if not room.grid.box_hits_solid(x, ny, w, h):
				y = ny
		if aim > 0.0:
			aim -= dt
			if aim <= 0.0:
				var n: float = tp.d if tp.d != 0.0 else 1.0
				room.shoot(cx, cy + 4.0, (tp.dx / n) * 125.0, (tp.dy / n) * 125.0, {"kind": "orb", "col": "#ff5d5d", "r": 3.0})
				Audio.sfx("shoot")
				cd = 2.5
		elif cd <= 0.0:
			aim = 0.5
			Audio.sfx("warn", {"vol": 0.5})
	y += sin(t * 4.0) * 0.15
	x += vx * dt
	vx *= 0.88

func draw_body() -> void:
	spr("drone_%d" % ((2 if aim > 0.0 else 0) + (int(t * 20.0) % 2)), false, 1.0, 1.0, 3.0)

func net_fields() -> Array:
	return [roundi(aim * 100.0)]

func net_apply(f: Array) -> void:
	aim = f[0] / 100.0
