class_name Typo
extends Enemy
# Typo: hops at you. Port of `class Typo`.

var wait := 0.5

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 10, 10)
	wait = 0.4 + Game.hash3(px, py, 2)
	col = "#b79cff"

func update(dt: float) -> void:
	tick(dt)
	if on_ground:
		vx *= 0.7
		wait -= dt
		if wait <= 0.0 and stun <= 0.0:
			var tp := to_player()
			face = (Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else 1.0) if tp.d < 150.0 else (-1.0 if room.rng.randf() < 0.5 else 1.0)
			if edge_ahead(face) and tp.d > 60.0:
				face = -face
			vx = face * 62.0
			vy = -235.0
			on_ground = false
			wait = room.rng.randf_range(0.55, 1.0)
	if physics(dt):
		room.dust(cx, y + h, 2)
	if hit_wall != 0:
		vx = -vx * 0.5

func draw_body() -> void:
	var air := not on_ground
	var squat := on_ground and wait < 0.18
	spr("typo_%d" % (1 if air else 0), face < 0.0, 1.15 if squat else 1.0, 0.8 if squat else 1.0)
