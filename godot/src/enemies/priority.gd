class_name PriorityInversion
extends EnemySM
# PRIORITY INVERSION (`}`, MV5A-05): a slow 32x32 giant, asleep until it is hit. While it sleeps it does not hurt, and every creature within 160 px is frozen
# with it (a blue `blocked` tint; they are stopped but still sharp). A hit wakes it: it walks at 20 px/s towards the nearest player (contact 1,
# and it pushes a body back 1 px a frame, like a wall) and everything near wakes with it. 6 s without a hit and it falls asleep again.

const RANGE := 160.0
const AWAKE_T := 6.0

var awake := false
var awake_t := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 32, 32)
	hp = 10
	loot = 6
	col = "#7a4a5a"
	stompable = false
	kb = 0.0
	x = px + (T - w) / 2.0
	face = -1.0

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	var res := super.hit(d, dx, dy, how, b)
	if res == "hit":
		if not awake:
			room.pop(cx, y - 10.0, "wake", "#ff7a59", true)
			Audio.sfx("roar", {"vol": 0.4})
		awake = true
		awake_t = AWAKE_T
	return res

func pushes() -> bool:
	return awake

func harmboxes() -> Array:
	return [self] if awake else []

func update(dt: float) -> void:
	tick(dt)
	if awake:
		awake_t -= dt
		if awake_t <= 0.0:
			awake = false
		var tp := to_player()
		if tp.p != null and on_ground:
			face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else face
			vx = 0.0 if (hit_wall != 0 and Game.sign_of(vx) == face) else face * 20.0
		else:
			vx = 0.0
	else:
		vx = 0.0
		for e in room.ents:                               # the lower priority waits: everything near is frozen while it sleeps
			if e == self or e.dead or e.get("is_boss") == true:
				continue
			if Vector2(e.cx - cx, e.cy - cy).length() <= RANGE and (e.bp_t <= 0.0 or e.bp_k == 2):
				e.bp_t = 0.2
				e.bp_k = 2
	physics(dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	draw_rect(Rect2(px - 1, py - 1, 34, 34), ink)
	draw_rect(Rect2(px, py, 32, 32), Color("#7a4a5a") if awake else Color("#5a3a4a"))
	draw_rect(Rect2(px, py, 32, 3), Color("#d98a8a") if awake else Color("#8a6070"))
	draw_rect(Rect2(px + 4, py + 26, 24, 3), Color("#3c1f33"))
	if awake:
		draw_rect(Rect2(px + 7, py + 10, 5, 5), Color.WHITE)
		draw_rect(Rect2(px + 20, py + 10, 5, 5), Color.WHITE)
		draw_rect(Rect2(px + 9, py + 12, 2, 3), Color("#ff4f6d"))
		draw_rect(Rect2(px + 22, py + 12, 2, 3), Color("#ff4f6d"))
	else:
		draw_rect(Rect2(px + 7, py + 13, 6, 1), Color.WHITE)
		draw_rect(Rect2(px + 20, py + 13, 6, 1), Color.WHITE)
		PixelText.draw_text(self, "z", px + 30.0 + sin(t * 2.0) * 2.0, py - 6.0, "#7cc4ff", {"tiny": true, "outline": Game.COL.ink})
		PixelText.draw_text(self, "Z", px + 36.0, py - 14.0 - fposmod(t * 8.0, 6.0), "#7cc4ff", {"tiny": true, "outline": Game.COL.ink})
	# a frozen neighbour gets the `blocked` tint
	if not awake:
		for e in room.ents:
			if e != self and not e.dead and e.bp_t > 0.0 and e.bp_k == 2:
				draw_rect(Rect2(e.x - 1.0, e.y - 1.0, e.w + 2.0, e.h + 2.0), Color(0.3, 0.55, 1.0, 0.35))

func net_fields() -> Array:
	return [1 if awake else 0, roundi(maxf(awake_t, 0.0) * 100.0)]

func net_apply(f: Array) -> void:
	awake = int(f[0]) == 1
	awake_t = f[1] / 100.0
