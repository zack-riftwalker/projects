class_name Flaky
extends Enemy
# FLAKY (f): a test that sometimes passes. Hovers around its home, gets mad at 118 px, swoops through walls, comes back.
# Exact port of `class Flaky` (js/enemies.js); it has no physics.

const STATES := ["idle", "mad", "swoop", "back"]

var hx := 0.0
var hy := 0.0
var st := "idle"
var st_t := 0.0
var cd := 1.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py - 4.0, 10, 9)
	hx = x
	hy = y
	col = "#8fe3a0"

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	var r: String = super.hit(d, dx, dy, how, b)
	if r == "hit":
		st = "back"
		cd = 1.0
	return r

func update(dt: float) -> void:
	tick(dt)
	cd -= dt
	var tp := to_player()
	if st == "idle":
		var tx := hx + sin(t * 1.3) * 18.0
		var ty := hy + sin(t * 2.6) * 7.0
		x = Game.damp(x, tx, 3.0, dt)
		y = Game.damp(y, ty, 3.0, dt)
		face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else 1.0
		if tp.d < 118.0 and cd <= 0.0 and stun <= 0.0:
			st = "mad"
			st_t = 0.5
			Audio.sfx("warn", {"vol": 0.5})
	elif st == "mad":
		st_t -= dt
		x += sin(t * 60.0) * 0.5
		if st_t <= 0.0:
			var n: float = tp.d if tp.d != 0.0 else 1.0
			vx = (tp.dx / n) * 185.0
			vy = (tp.dy / n) * 185.0
			st = "swoop"
			st_t = 0.62
	elif st == "swoop":
		st_t -= dt
		x += vx * dt
		y += vy * dt
		if st_t <= 0.0 or room.grid.solid_at(cx, cy):
			st = "back"
	else:
		var dx := hx - x
		var dy := hy - y
		var d := sqrt(dx * dx + dy * dy)
		if d < 4.0:
			st = "idle"
			cd = 1.4
		else:
			x += (dx / d) * 70.0 * dt
			y += (dy / d) * 70.0 * dt

func draw_body() -> void:
	var mad := st == "mad" or st == "swoop"
	spr("%s_%d" % ["flakyMad" if mad else "flaky", int(t * 14.0) % 2], false, 1.0, 1.0, 2.0)

func net_fields() -> Array:
	return [STATES.find(st), roundi(st_t * 100.0)]

func net_apply(f: Array) -> void:
	st = STATES[clampi(int(f[0]), 0, 3)]
	st_t = f[1] / 100.0
