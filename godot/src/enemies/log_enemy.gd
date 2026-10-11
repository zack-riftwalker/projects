class_name LogEnemy
extends Enemy
# LOGGER (g): spams the room with output. Opens its mouth for 0.5 s and fires a `log` projectile at the end. Exact port of `class Logger`.
# (named LogEnemy: Godot has its own `Logger` class)

var cd := 1.0
var open := 0.0
var shot := false

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 14, 15)
	hp = 2
	cd = 1.0 + Game.hash3(px, py, 4)
	col = "#cfc6b4"
	loot = 2

func update(dt: float) -> void:
	tick(dt)
	cd -= dt
	var tp := to_player()
	face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else 1.0
	if open > 0.0:
		open -= dt
		if open <= 0.18 and not shot:
			shot = true
			room.shoot(cx + face * 8.0, y + 6.0, face * 135.0, 0.0, {"kind": "log", "col": "#7dff9a", "r": 3.0})
			Audio.sfx("shoot")
	elif cd <= 0.0 and absf(tp.dx) < 200.0 and absf(tp.dy) < 56.0 and stun <= 0.0:
		open = 0.5
		shot = false
		cd = 2.1
	vx *= 0.8
	physics(dt)

func draw_body() -> void:
	spr("logger_%d" % (1 if open > 0.0 else 0), false, 1.0, 0.92 if open > 0.3 else 1.0)

func net_fields() -> Array:
	return [roundi(maxf(open, 0.0) * 100.0)]

func net_apply(f: Array) -> void:
	open = f[0] / 100.0
