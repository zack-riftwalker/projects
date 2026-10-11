class_name Mimic
extends Enemy
# MIMIC (m): a deprecated package that was never really removed. Sleeps like a crate; wakes at 46 px (or when hit) and hops at you.
# Exact port of `class Mimic` (js/enemies.js).

var awake := false
var wait := 0.5

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 16, 14)
	hp = 3
	passive = true
	col = "#c08a4e"
	loot = 4
	kb = 0.4

func wake() -> void:
	if awake:
		return
	awake = true
	passive = false
	vy = -150.0
	on_ground = false
	room.pop(cx, y - 8, "DEPRECATED!", "#ffb3b3")
	Audio.sfx("warn")

func on_hurt(_how: String) -> void:
	wake()

func update(dt: float) -> void:
	tick(dt)
	var tp := to_player()
	if not awake:
		if tp.d < 46.0 and absf(tp.dy) < 26.0:
			wake()
		physics(dt)
		return
	if on_ground:
		vx *= 0.6
		wait -= dt
		if wait <= 0.0 and stun <= 0.0:
			face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else 1.0
			vx = face * 74.0
			vy = -255.0
			on_ground = false
			wait = 0.7
	if physics(dt):
		room.dust(cx, y + h, 5)
		room.shake(0.14)
		Audio.sfx("thud", {"vol": 0.5})

func draw_body() -> void:
	spr("mimic_%d" % (0 if not awake else (1 if on_ground else 2)), face > 0.0 and awake, 1.0, 1.0, 0.0 if awake else 3.0)

func net_fields() -> Array:
	return [1 if awake else 0, 1 if on_ground else 0]

func net_apply(f: Array) -> void:
	awake = int(f[0]) == 1
	passive = not awake
	on_ground = int(f[1]) == 1
