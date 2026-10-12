class_name Mitm
extends EnemySM
# MITM (`u`, MVB3-03): man in the middle. It stands between you and the way on and copies your last attack, mirrored, half a second later.
# Its front blocks claws, dashes and agents; an attack started near it makes it record (an icon over its head and a filling bar), then it echoes
# that attack toward the player and is open for a moment. Hits from behind always land.

const STATES := ["listen", "record", "echo", "open"]
const KINDS := ["side", "up", "pogo", "dash"]
const WALK := 50.0
const SEE := 160.0
const STOP := 40.0
const NOTICE := 130.0            # a player this close, attacking, is recorded

var kind := 0                    # what it copies / echoes (index in KINDS)
var landed := 0                  # pogo echo: 0 rising, 1 falling, 2 landed (the stomp box stays 0.15 s)
var seen_atk := {}               # player key -> the last attack / dash id it has looked at
var listen_cd := 0.0
var dash_dir := 1.0
var dash_left := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 16)
	hp = 5
	loot = 3
	col = "#7a6aa8"
	stompable = false
	face = -1.0
	state = "listen"

func guard_up() -> bool:
	return state != "open"

# the front is the side it faces; a hit from behind or from above/below (dx == 0) lands
func blocks(dx: float, _dy: float, how: String) -> bool:
	return guard_up() and (how == "swipe" or how == "agent" or how == "dash") and Game.sign_of(dx) == -face

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if blocks(dx, dy, how):
		Audio.sfx("clang")
		room.spark(cx + face * 8.0, y + 8.0, "#ffffff", 6)
		return "block"
	return super.hit(d, dx, dy, how, b)

func _key(q) -> String:
	return "p2" if q.get("is_remote") == true else "p1"

# the attack a player has just started (a new claw swing or a new dash), or -1
func _new_attack(q) -> int:
	var k := _key(q)
	var a_id: int = q.atk_id
	var d_id: int = q.dash_id
	var prev: Array = seen_atk.get(k, [a_id, d_id])
	seen_atk[k] = [a_id, d_id]
	if d_id != prev[1]:
		return 3
	if a_id != prev[0]:
		return 1 if q.atk_dir == "u" else (2 if q.atk_dir == "d" else 0)
	return -1

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	listen_cd -= dt
	var tp := to_player()
	if stun > 0.0:
		vx *= 0.85
		physics(dt)
		return
	match state:
		"listen":
			vx = 0.0
			if tp.p != null and tp.d < SEE:
				var want: float = Game.sign_of(tp.dx)
				if want != 0.0:
					face = want
				if absf(tp.dx) > STOP and on_ground and not edge_ahead(face):
					vx = face * WALK
					if hit_wall != 0:
						vx = 0.0
			# an attack started near it by a player in view: record it
			for q in room.players():
				var a := _new_attack(q)
				if a >= 0 and listen_cd <= 0.0 and Vector2(q.x + 5.0 - cx, q.y + 5.0 - cy).length() < NOTICE:
					kind = a
					var dxq: float = q.x + 5.0 - cx
					if absf(dxq) > 1.0:
						face = Game.sign_of(dxq)
					set_state("record", 0.5 * float(Game.dv("telegraph_mult")))
					Audio.sfx("warn", {"vol": 0.5})
					break
		"record":
			vx = 0.0
			for q in room.players():
				_new_attack(q)                                     # (what it sees now is not recorded)
			if state_t <= 0.0:
				_start_echo(tp)
		"echo":
			_echo_step(dt)
		"open":
			vx = 0.0
			for q in room.players():
				_new_attack(q)
			if state_t <= 0.0:
				listen_cd = 0.3
				set_state("listen")
	physics(dt)

func _start_echo(tp: Dictionary) -> void:
	if tp.p != null and absf(tp.dx) > 1.0:
		face = Game.sign_of(tp.dx)                              # toward the player
	landed = 0
	match KINDS[kind]:
		"side":
			set_state("echo", 0.25)
			Audio.sfx("swipe", {"vol": 0.7})
		"up":
			set_state("echo", 0.25)
			Audio.sfx("swipe", {"vol": 0.7})
		"pogo":
			vy = -260.0
			on_ground = false
			set_state("echo", 1.5)
			Audio.sfx("jump", {"vol": 0.7})
		"dash":
			dash_dir = face
			dash_left = 64.0
			set_state("echo", 0.3)
			Audio.sfx("dash", {"vol": 0.7})

func _echo_step(dt: float) -> void:
	vx = 0.0
	match KINDS[kind]:
		"dash":
			var step := minf(dash_left, 320.0 * dt)
			vx = dash_dir * step / maxf(dt, 0.0001)
			dash_left -= step
			if dash_left <= 0.0 or hit_wall != 0:
				vx = 0.0
				_end_echo()
		"pogo":
			if landed == 0 and vy > 0.0:
				landed = 1
			if landed == 1 and on_ground:
				landed = 2
				state_t = 0.15
				room.shake(0.2)
				Audio.sfx("thud", {"vol": 0.6})
			elif landed == 2 and state_t <= 0.0:
				_end_echo()
			elif landed < 2 and state_t <= 0.0:
				_end_echo()
		_:
			if state_t <= 0.0:
				_end_echo()

func _end_echo() -> void:
	landed = 0
	set_state("open", 0.6 * float(Game.dv("punish_mult")))

func harmboxes() -> Array:
	var out: Array = [self]
	if state != "echo":
		return out
	match KINDS[kind]:
		"side":
			if state_t > 0.10:                                    # the slash is live for the first 0.15 s of the echo
				out.append({"x": x + w if face > 0.0 else x - 28.0, "y": cy - 11.0, "w": 28.0, "h": 22.0})
		"up":
			if state_t > 0.10:
				out.append({"x": cx - 13.0, "y": y - 24.0, "w": 26.0, "h": 24.0})
		"pogo":
			if landed >= 1:
				out.append({"x": cx - 12.0, "y": y + h - 2.0, "w": 24.0, "h": 8.0})
	return out

# ---- drawing ----
func _icon(kd: int, ix: float, iy: float) -> void:
	var ink := Color(Game.COL.ink)
	var c := Color("#ffd23f")
	match KINDS[kd]:
		"side":
			draw_line(Vector2(ix - 4 * face, iy - 3), Vector2(ix + 4 * face, iy + 3), c, 2.0)
			draw_line(Vector2(ix + 4 * face, iy + 3), Vector2(ix + 1 * face, iy + 3), c, 1.0)
		"up":
			draw_line(Vector2(ix, iy + 4), Vector2(ix, iy - 4), c, 2.0)
			draw_line(Vector2(ix - 3, iy - 1), Vector2(ix, iy - 4), c, 1.0)
			draw_line(Vector2(ix + 3, iy - 1), Vector2(ix, iy - 4), c, 1.0)
		"pogo":
			draw_line(Vector2(ix, iy - 4), Vector2(ix, iy + 4), c, 2.0)
			draw_line(Vector2(ix - 3, iy + 1), Vector2(ix, iy + 4), c, 1.0)
			draw_line(Vector2(ix + 3, iy + 1), Vector2(ix, iy + 4), c, 1.0)
		"dash":
			for k in range(2):
				draw_line(Vector2(ix - 4 + k * 4, iy - 3), Vector2(ix - 1 + k * 4, iy), c, 1.0)
				draw_line(Vector2(ix - 1 + k * 4, iy), Vector2(ix - 4 + k * 4, iy + 3), c, 1.0)
	draw_rect(Rect2(ix - 6, iy - 6, 12, 1), ink)

func draw_body() -> void:
	var px := floori(cx + 0.5)
	var by := floori(y + h + 0.5)
	var ink := Color(Game.COL.ink)
	var open: bool = state == "open"
	var shake := (1.0 if int(t * 30.0) % 2 == 0 else -1.0) if open else 0.0
	var bx := px + shake
	# body: a grey-violet suit, a mirrored face (two eyes with a reflection), the shield side lit
	draw_rect(Rect2(bx - 7, by - 17, 14, 17), ink)
	draw_rect(Rect2(bx - 6, by - 16, 12, 15), Color("#4a4268"))
	draw_rect(Rect2(bx - 6, by - 16, 12, 3), Color("#7a6aa8"))
	var ex := bx + (2.0 if face > 0.0 else -4.0)
	draw_rect(Rect2(ex, by - 12, 2, 3), Color.WHITE)
	draw_rect(Rect2(ex + 3, by - 12, 2, 3), Color.WHITE)
	# the mirror in front: a shield-sized pane, dim while open
	var sx := bx + (4.0 if face > 0.0 else -8.0)
	if guard_up():
		draw_rect(Rect2(sx - 1, by - 18, 6, 19), ink)
		draw_rect(Rect2(sx, by - 17, 4, 17), Color("#c3e8ff") if state != "record" or int(t * 16.0) % 2 == 0 else Color("#ffffff"))
		draw_rect(Rect2(sx + 1, by - 15, 1, 6), Color("#ffffff"))
	else:
		draw_rect(Rect2(sx, by - 17, 4, 17), Color("#5a6a7a"))
	var legs := int(t * 8.0) % 2 if vx != 0.0 else 0
	draw_rect(Rect2(bx - 5, by - 1, 3, 1 + legs), ink)
	draw_rect(Rect2(bx + 2, by - 1, 3, 2 - legs), ink)
	# the recording: the icon of what it copies and a filling bar
	if state == "record":
		var dur := 0.5 * float(Game.dv("telegraph_mult"))
		var f := clampf(1.0 - state_t / dur, 0.0, 1.0)
		_icon(kind, bx, by - 28.0)
		draw_rect(Rect2(bx - 8, by - 23, 16, 3), ink)
		draw_rect(Rect2(bx - 7, by - 22, 14.0 * f, 1), Color("#ffd23f"))
	if state == "echo":
		for hb in harmboxes():
			if hb is Dictionary:
				draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.3, 0.3, 0.55))
				draw_rect(Rect2(hb.x, hb.y, hb.w, 1), Color("#ffd0d0"))
	if open:
		PixelText.draw_text(self, "open", px, by - 24.0, "#7fd08a", {"align": "c", "tiny": true, "outline": Game.COL.ink})

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0), kind, int(face), landed]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 3)]
	state_t = f[1] / 100.0
	kind = clampi(int(f[2]), 0, 3)
	face = float(f[3])
	landed = int(f[4])
