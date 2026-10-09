class_name Guard
extends EnemySM
# FIREWALL GUARD: a shield in front. Claws and dashes from the front bounce off; hit its back, or pogo on it from above.

const BASE_HP := 8
var patrol := 18.0
var turn_t := -1.0              # > 0: the player is behind it and it is turning (the shield still faces the old way)
var attack_dx := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 14, 16)
	hp = BASE_HP
	stompable = false
	loot = 3
	col = "#8d8798"
	face = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0

func blocks(dx: float, dy: float, how: String) -> bool:
	return (how == "swipe" or how == "agent" or how == "dash") and dy == 0.0 and dx == -face

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if blocks(dx, dy, how):
		return "block"
	return super.hit(d, dx, dy, how, b)

func _sees_player() -> bool:
	var tp := to_player()
	if absf(tp.dx) > 112.0 or absf(tp.dy) > 48.0:
		return false
	var p = room.player
	var x0 := cx
	var y0 := cy
	var x1: float = p.x + 5
	var y1: float = p.y + 5
	var n := maxi(1, int(ceilf(maxf(absf(x1 - x0), absf(y1 - y0)) / 8.0)))
	for i in range(1, n):
		var k := float(i) / n
		if room.grid.solid_at(lerpf(x0, x1, k), lerpf(y0, y1, k)):
			return false
	return true

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	var tp := to_player()
	if stun > 0.0:
		if on_ground:
			vx *= 0.85
		physics(dt)
		return
	match state:
		"idle", "chase":
			var sees := _sees_player()
			state = "chase" if sees else "idle"
			if on_ground:
				if state == "idle":
					if hit_wall != 0 or edge_ahead(face):
						face = -face
					vx = face * patrol
					turn_t = -1.0
				else:
					var want: float = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else face
					if want != face:                      # the player is behind: turn after 0.6 s
						if turn_t < 0.0:
							turn_t = 0.6
						turn_t -= dt
						vx = 0.0
						if turn_t <= 0.0:
							face = want
							turn_t = -1.0
					else:
						turn_t = -1.0
						var blocked := edge_ahead(face) or hit_wall != 0
						vx = 0.0 if blocked else face * 24.0
					if absf(tp.dx) < 28.0 and absf(tp.dy) < 20.0 and want == face and turn_t < 0.0:
						set_state("telegraph", 0.5 * float(Game.dv("telegraph_mult")))
						vx = 0.0
		"telegraph":
			vx = 0.0
			if state_t <= 0.0:
				set_state("attack", 0.15)
				Audio.sfx("dash", {"vol": 0.6})
		"attack":
			vx = face * (24.0 / 0.15)
			if state_t <= 0.0:
				set_state("recover", 0.6 * float(Game.dv("punish_mult")))
				vx = 0.0
		"recover":
			vx = 0.0
			if state_t <= 0.0:
				set_state("chase")
	physics(dt)

func harmboxes() -> Array:
	if state == "attack":
		return [{"x": x if face < 0 else x, "y": y, "w": w + 6.0, "h": h} if face > 0 else {"x": x - 6.0, "y": y, "w": w + 6.0, "h": h}]
	return [self]

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var sh_x := x if face < 0 else x + 10.0
	var body_x := x + 4.0 if face < 0 else x
	# outline
	draw_rect(Rect2(body_x - 1, y + 1, 12, 16), ink)
	draw_rect(Rect2(sh_x - 1, y - 1, 6, 18), ink)
	# body
	draw_rect(Rect2(body_x, y + 2, 10, 14), Color("#5c6378"))
	draw_rect(Rect2(body_x, y + 2, 10, 1), Color("#8d8798"))
	var ex := 5.0 if face < 0 else 2.0
	draw_rect(Rect2(body_x + ex, y + 5, 1, 2), Color.WHITE)
	draw_rect(Rect2(body_x + ex + 2, y + 5, 1, 2), Color.WHITE)
	# shield, flashing yellow while it winds up
	var lit: bool = state == "telegraph" and int(t * 20.0) % 2 == 0
	draw_rect(Rect2(sh_x, y, 4, 16), Color("#ffd23f") if lit else Color("#ff7a2f"))
	draw_rect(Rect2(sh_x + 1, y + 4, 1, 1), Color("#ffd23f"))
	draw_rect(Rect2(sh_x + 2, y + 9, 1, 1), Color("#ffd23f"))

func net_fields() -> Array:
	return [["idle", "chase", "telegraph", "attack", "recover"].find(state), roundi(state_t * 100.0), int(face), roundi(maxf(turn_t, 0.0) * 100.0)]

func net_apply(f: Array) -> void:
	state = ["idle", "chase", "telegraph", "attack", "recover"][clampi(int(f[0]), 0, 4)]
	state_t = f[1] / 100.0
	face = float(f[2])
	turn_t = f[3] / 100.0
