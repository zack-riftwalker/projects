class_name StackOverflow
extends EnemySM
# STACK OVERFLOW (q): a tower of three bugs. Wobbles when you come close, topples toward you (the slam hurts), and spills
# into three bugs. Three claws unwind it for nothing.

const STATES := ["stand", "wobble", "fall", "split"]
const FALL_T := 0.5               # the whole fall: it turns for the first 0.35 s, the slam is active in the last 0.15 s
const ROT_T := 0.35
const SLAM_T := 0.15

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 36)
	hp = 3
	loot = 0
	col = "#f2c14e"
	stompable = false
	kb = 0.3
	state = "stand"

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	match state:
		"stand":
			if on_ground and stun <= 0.0:
				vx = 0.0
				var tp := to_player()
				if tp.p != null and absf(tp.dx) <= 56.0 and absf(tp.dy) <= 48.0:
					face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else face
					set_state("wobble", 0.5 * float(Game.dv("telegraph_mult")))
					Audio.sfx("warn", {"vol": 0.6})
			elif on_ground:
				vx *= 0.85
		"wobble":
			vx = 0.0
			if state_t <= 0.0:
				set_state("fall", FALL_T)
				Audio.sfx("thud", {"vol": 0.5})
		"fall":
			vx = 0.0
			if state_t <= 0.0:
				_split()
				return
	physics(dt)

func _split() -> void:
	set_state("split")
	room.shake(0.3)
	room.dust(cx + face * 20.0, y + h, 6)
	for i in range(3):
		var b := Bug.new(room, 0, 0, false)
		b.x = cx + face * (12.0 + 12.0 * i) - 6.0
		b.y = y + h - 9.0
		room.add_entity(b)
	dead = true                  # (no loot, no kill count)

func die(how: String) -> void:
	super.die(how)
	room.pop(cx, y - 8.0, "stack unwound", "#f2c14e")

func _angle() -> float:
	if state != "fall":
		return 0.0
	var u := clampf((FALL_T - state_t) / ROT_T, 0.0, 1.0)
	return u * u * (PI / 2.0) * face

# the slam strip on the floor in front of the fallen tower, active in the last SLAM_T of the fall
func slam_box() -> Dictionary:
	return {"x": x + 6.0, "y": y + 24.0, "w": 36.0, "h": 12.0} if face > 0.0 else {"x": x - 30.0, "y": y + 24.0, "w": 36.0, "h": 12.0}

func harmboxes() -> Array:
	match state:
		"stand", "wobble":
			return [self]
		"fall":
			if state_t <= SLAM_T:
				return [slam_box()]
			var a := _angle()
			var base := Vector2(cx, y + h)
			var out: Array = []
			for d in [6.0, 18.0, 30.0]:
				var c: Vector2 = base + Vector2(sin(a), -cos(a)) * float(d)
				out.append({"x": c.x - 6.0, "y": c.y - 6.0, "w": 12.0, "h": 12.0})
			return out
	return []

func draw_body() -> void:
	var base := Vector2(floori(cx + 0.5), floori(y + h + 0.5) + 1)
	var frame := int(t * 6.0) % 2
	draw_set_transform(base, _angle(), Vector2.ONE)
	for i in range(3):
		var off := 0.0
		if state == "stand":
			off = sin(t * 3.0) * float(i + 1) * (1.0 if i > 0 else 0.5)
		elif state == "wobble":
			off = 2.0 if int(t * 40.0) % 2 == 0 else -2.0
		Gfx.spr(self, "bug_%d" % frame, off, -12.0 * i, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0), int(face)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 3)]
	state_t = f[1] / 100.0
	face = float(f[2])
