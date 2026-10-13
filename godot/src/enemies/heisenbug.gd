class_name Heisenbug
extends EnemySM
# HEISENBUG (`(`, MV5A-05): it only moves when it is not looked at. A player within 200 px who faces it (or stands right over it) with a clear
# line "observes" it: it freezes (touching it still hurts). While nobody observes it, it flies at the nearest player that does not, at
# 90 px/s, after a 0.2 s shimmer. The guest's face comes from its reports (the partner's body knows which way it looks).

const RANGE := 200.0
const SPEED := 90.0

var observed := false
var shimmer := 0.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 12)
	hp = 3
	loot = 2
	col = "#b8a8d8"
	dashable = true

# does this body observe me? within RANGE, facing me (or right over me), and no wall between
func observed_by(q) -> bool:
	var dx: float = cx - (q.x + q.w / 2.0)
	var dy: float = cy - (q.y + q.h / 2.0)
	if Vector2(dx, dy).length() > RANGE:
		return false
	if not (Game.sign_of(dx) == q.face or absf(dx) < 8.0):
		return false
	var qx: float = q.x + q.w / 2.0
	var qy: float = q.y + q.h / 2.0
	var n := maxi(1, int(ceilf(maxf(absf(dx), absf(dy)) / 8.0)))
	for i in range(1, n):
		var k := float(i) / n
		if room.grid.solid_at(lerpf(qx, cx, k), lerpf(qy, cy, k)):
			return false
	return true

func update(dt: float) -> void:
	tick(dt)
	if shimmer > 0.0:
		shimmer -= dt
	var was := observed
	observed = false
	var free_targets: Array = []
	for q in room.players():
		if observed_by(q):
			observed = true
		else:
			free_targets.append(q)
	if observed:
		vx = 0.0
		vy = 0.0
		return
	if was:
		shimmer = 0.2                                   # it comes loose: a short shimmer before it moves
	if shimmer > 0.0 or free_targets.is_empty():
		vx = 0.0
		vy = 0.0
		return
	var best = free_targets[0]
	var bd := 1e18
	for q in free_targets:
		var d: float = Vector2(q.x + 5.0 - cx, q.y + 5.0 - cy).length_squared()
		if d < bd:
			bd = d
			best = q
	var dir := Vector2(best.x + 5.0 - cx, best.y + 5.0 - cy)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if stun > 0.0:
		dir *= 0.0
	vx = dir.x * SPEED
	vy = dir.y * SPEED
	if absf(vx) > 1.0:
		face = Game.sign_of(vx)
	hit_wall = room.grid.move_x(self, vx * dt)
	room.grid.move_y(self, vy * dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	var jig := 0.0 if observed else (1.0 if int(t * 30.0) % 2 == 0 else -1.0)
	if shimmer > 0.0:
		jig = (1.0 if int(t * 60.0) % 2 == 0 else -2.0)
	var body := Color("#b8a8d8") if not observed else Color("#8d8798")
	draw_rect(Rect2(px - 1 + jig, py - 1, 14, 14), ink)
	draw_rect(Rect2(px + jig, py, 12, 12), body)
	draw_rect(Rect2(px + jig, py, 12, 2), Color("#dcd0f0") if not observed else Color("#a8a2b4"))
	# six little legs
	for i in range(3):
		draw_rect(Rect2(px - 2 + jig, py + 3 + i * 3, 2, 1), ink)
		draw_rect(Rect2(px + 12 + jig, py + 3 + i * 3, 2, 1), ink)
	if observed:                                         # a grey eye: it knows it is looked at
		draw_rect(Rect2(px + 2, py + 4, 8, 4), Color.WHITE)
		draw_rect(Rect2(px + 5, py + 4, 2, 4), Color("#4c4658"))
		draw_rect(Rect2(px + 2, py + 3, 8, 1), ink)
	else:
		draw_rect(Rect2(px + 2 + jig, py + 4, 2, 2), Color("#ff4f6d"))
		draw_rect(Rect2(px + 8 + jig, py + 4, 2, 2), Color("#ff4f6d"))
		draw_rect(Rect2(px + 3 + jig, py + 8, 6, 1), ink)

func net_fields() -> Array:
	return [1 if observed else 0, roundi(maxf(shimmer, 0.0) * 100.0)]

func net_apply(f: Array) -> void:
	observed = int(f[0]) == 1
	shimmer = f[1] / 100.0
