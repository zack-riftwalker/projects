class_name Noodle
extends Enemy
# NOODLE (n): spaghetti code. Walks, revs for 0.5 s when you are close in line, charges for up to 0.95 s, then is tired for 1 s.
# Exact port of `class Noodle` (js/enemies.js).

const STATES := ["walk", "rev", "charge", "tired"]

var st := "walk"
var st_t := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 16, 9)
	hp = 2
	col = "#f6d76b"
	face = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0
	loot = 2

func update(dt: float) -> void:
	tick(dt)
	st_t -= dt
	var tp := to_player()
	if st == "walk":
		if on_ground:
			if hit_wall != 0 or edge_ahead(face):
				face = -face
			if stun <= 0.0:
				vx = face * 17.0
		if absf(tp.dy) < 22.0 and absf(tp.dx) < 115.0 and stun <= 0.0 and on_ground:
			face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else 1.0
			st = "rev"
			st_t = 0.5
			vx = 0.0
			Audio.sfx("charge", {"vol": 0.6})
	elif st == "rev":
		vx = 0.0
		if st_t <= 0.0:
			st = "charge"
			st_t = 0.95
	elif st == "charge":
		vx = face * 195.0
		if room.rng.randf() < 0.5:
			room.dust(cx - face * 8.0, y + h, 1, -face)
		if hit_wall != 0 or st_t <= 0.0 or (on_ground and edge_ahead(face)):
			if hit_wall != 0:
				room.shake(0.15)
				room.dust(cx + face * 8.0, cy, 4)
			st = "tired"
			st_t = 1.0
			vx = 0.0
	else:
		vx *= 0.8
		if st_t <= 0.0:
			st = "walk"
	physics(dt)

func draw_body() -> void:
	var mad := st == "rev" or st == "charge"
	var img := "noodle_%d" % ((2 if mad else 0) + (int(t * (16.0 if mad else 5.0)) % 2))
	var jit := (int(t * 40.0) % 2) if st == "rev" else 0
	var tired := st == "tired"
	Gfx.spr(self, img, floori(x + w / 2.0 + 0.5) + jit, floori(y + h + 0.5) + 1, face < 0.0, 1.1 if tired else 1.0, 0.85 if tired else 1.0)
	if tired and int(t * 4.0) % 2 == 1:
		PixelText.draw_text(self, "z", cx + 6.0, y - 8.0, "#f4ede0", {"tiny": true})

func net_fields() -> Array:
	return [STATES.find(st), roundi(st_t * 100.0)]

func net_apply(f: Array) -> void:
	st = STATES[clampi(int(f[0]), 0, 3)]
	st_t = f[1] / 100.0
