class_name Slime
extends Enemy
# SLIME (s): a blob of memory nobody freed. Hops at you from 130 px, splits into two small ones when it dies.
# Exact port of `class Slime` (index.html).

var small := false
var wait := 0.5
var land := 0.0

func _init(r: Room, px: float, py: float, is_small := false) -> void:
	super(r, px, py, 8 if is_small else 14, 6 if is_small else 10)
	small = is_small
	hp = 1 if small else 2
	wait = 0.5 + Game.hash3(px, py, 2) * 0.6
	col = "#58f0c8"
	loot = 1 if small else 0

func update(dt: float) -> void:
	tick(dt)
	if on_ground:
		vx *= 0.6
		wait -= dt
		if wait <= 0.0 and stun <= 0.0:
			var tp := to_player()
			if tp.d < 130.0:
				face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else 1.0
			else:
				face = -1.0 if room.rng.randf() < 0.5 else 1.0
			if edge_ahead(face) and tp.d > 50.0:
				face = -face
			vx = face * (62.0 if small else 44.0)
			vy = -175.0 if small else -150.0
			on_ground = false
			wait = 0.5 if small else 0.9
	if physics(dt):
		land = 0.14
	if land > 0.0:
		land -= dt
	if hit_wall != 0:
		vx = -vx * 0.5

func die(how: String) -> void:
	super.die(how)
	if not small:
		for d in [-1, 1]:
			var s := Slime.new(room, x, y, true)
			s.x = cx - 4.0 + d * 4.0
			s.y = y
			s.vx = d * 80.0
			s.vy = -170.0
			s.wait = 0.5
			room.add_entity(s)

func draw_body() -> void:
	var sq := 1.2 if land > 0.0 else (1.12 if on_ground and wait < 0.15 else (0.88 if not on_ground else 1.0))
	spr(("slimeS_%d" if small else "slime_%d") % (int(t * 3.0) % 2), false, sq, 2.0 - sq)

func net_fields() -> Array:
	return [roundi(wait * 100.0), roundi(land * 100.0)]

func net_apply(f: Array) -> void:
	wait = f[0] / 100.0
	land = f[1] / 100.0
