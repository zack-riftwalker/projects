class_name Bug
extends Enemy
# Bug: walks. That's the whole bug. Port of `class Bug` (letters b normal, a spiky).

var spiky := false
var speed := 27.0

func _init(r: Room, px: float, py: float, is_spiky: bool) -> void:
	super(r, px, py, 12, 9)
	spiky = is_spiky
	hp = 2 if spiky else 1
	stompable = not spiky
	speed = 20.0 if spiky else 27.0
	col = "#e0568a" if spiky else "#a9dd52"
	face = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0
	loot = 2 if spiky else 1

func update(dt: float) -> void:
	tick(dt)
	if stun <= 0.0:
		if on_ground:
			if hit_wall != 0 or edge_ahead(face):
				face = -face
			vx = face * speed
	elif on_ground:
		vx *= 0.85
	physics(dt)

func draw_body() -> void:
	spr("%s_%d" % ["spiky" if spiky else "bug", int(t * 6.0) % 2], face < 0.0)

func net_fields() -> Array:
	return []

func net_apply(_f: Array) -> void:
	pass
