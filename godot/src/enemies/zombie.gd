class_name Zombie
extends EnemySM
# ZOMBIE PROCESS: it does not die from a claw. It lies there for 3 s and gets up, unless finished with a down-swipe or a stomp (kill -9).

var full_hp := 2
var rise_t := 0.0
var corpse_t := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 12)
	hp = 2
	full_hp = 2
	loot = 2
	col = "#8fa37a"
	face = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0

func _is_kill9(how: String, dy: float) -> bool:
	return how == "stomp" or (how == "swipe" and dy == 1.0)

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if state == "down" or state == "rise":
		if _is_kill9(how, dy):
			room.pop(cx, y - 8, "kill -9", Game.COL.hazardHi, true)
			hp = 0
			flash = 0.13
			die(how)
			return "kill"
		flash = 0.13
		Audio.sfx("hit")
		return "hit"
	if hp - d <= 0 and not _is_kill9(how, dy):
		# not a real death: it goes down
		hp = 0
		flash = 0.13
		stun = 0.22
		room.burst(cx, cy, 4, [col, "#ffffff"], 90.0, 300.0)
		_go_down()
		Audio.sfx("hit")
		return "hit"
	var r: String = super.hit(d, dx, dy, how, b)
	if r == "kill":
		room.pop(cx, y - 8, "kill -9", Game.COL.hazardHi, true)
	return r

func _go_down() -> void:
	state = "down"
	state_t = 3.0
	passive = true
	vx = 0.0
	y += 7.0
	h = 5.0
	room.pop(cx, y - 10, "zzz", Game.COL.dim)

func _rise() -> void:
	state = "rise"
	state_t = 0.5 * float(Game.dv("telegraph_mult"))
	Audio.sfx("glitch", {"vol": 0.5})

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	if state == "down":
		vx = 0.0
		physics(dt)
		if state_t <= 0.0:
			_rise()
		return
	if state == "rise":
		vx = 0.0
		physics(dt)
		if state_t <= 0.0:
			y -= 7.0
			h = 12.0
			hp = full_hp
			passive = false
			state = "idle"
		return
	if stun <= 0.0 and on_ground:
		var tp := to_player()
		var speed := 22.0
		if absf(tp.dx) < 96.0 and absf(tp.dy) < 24.0:
			face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else face
			speed = 30.0
			if edge_ahead(face) or hit_wall != 0:
				vx = 0.0
				physics(dt)
				return
		elif hit_wall != 0 or edge_ahead(face):
			face = -face
		vx = face * speed
	elif on_ground:
		vx *= 0.85
	physics(dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var body := Color(col)
	var shadow := Color("#56664a")
	var jx := 0.0
	if state == "rise":
		jx = 1.0 if int(t * 30.0) % 2 == 0 else -1.0
	if state == "down" or state == "rise" and h < 12.0:
		draw_rect(Rect2(x - 1 + jx, y - 1, 14, 7), ink)
		draw_rect(Rect2(x + jx, y, 12, 5), body)
		draw_rect(Rect2(x + jx, y + 4, 12, 1), shadow)
		var eye := Color("#ff5d5d") if (state == "rise" and int(t * 10.0) % 2 == 0) else shadow
		draw_rect(Rect2(x + 3 + jx, y + 2, 2, 1), eye)
		draw_rect(Rect2(x + 7 + jx, y + 2, 2, 1), eye)
		return
	draw_rect(Rect2(x - 1, y - 1, 14, 14), ink)
	draw_rect(Rect2(x, y, 12, 12), body)
	draw_rect(Rect2(x, y + 9, 12, 3), shadow)
	var ex := 7.0 if face > 0 else 2.0
	draw_rect(Rect2(x + ex, y + 3, 2, 2), Color("#ff5d5d"))
	draw_rect(Rect2(x + ex - (3 if face > 0 else -3), y + 3, 2, 2), Color("#ff5d5d"))
	PixelText.draw_text(self, "Z", x + 5, y + 6, "#56664a", {"tiny": true})

func net_fields() -> Array:
	return [["idle", "down", "rise"].find(state), roundi(state_t * 100.0)]

func net_apply(f: Array) -> void:
	var s: String = ["idle", "down", "rise"][clampi(int(f[0]), 0, 2)]
	if s != state:
		if s == "down" and state == "idle":
			y += 7.0
			h = 5.0
			passive = true
		elif s == "idle" and state != "idle":
			y -= 7.0 if h < 12.0 else 0.0
			h = 12.0
			passive = false
	state = s
	state_t = f[1] / 100.0
