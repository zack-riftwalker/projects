class_name DataRace
extends EnemySM
# DATA RACE (`[`, MV5A-05): twins with one hp pool that move as each other's mirror. A hit on one twin is only pending for 0.5 s: it
# counts when the other twin is hit inside that window (both hits are added up and taken from the pool), else it rolls back (ROLLBACK).
# The letter makes twin A at the cell and twin B 64 px to the right; A drives the pair, B follows the mirror of A about their midpoint.

const SPEED := 60.0
const WINDOW := 0.5

var twin: DataRace = null
var is_b := false
var pend_d := 0
var pend_t := 0.0
var dir := 1.0
var mid_x := 0.0

func _init(r: Room, px: float, py: float, b := false) -> void:
	super(r, px, py, 12, 16)
	is_b = b
	hp = 4
	loot = 3
	col = "#ff9a59" if not b else "#59a8ff"
	stompable = false
	mid_x = x + w / 2.0

func pair_with(other: DataRace) -> void:
	twin = other
	other.twin = self
	mid_x = (cx + other.cx) / 2.0
	other.mid_x = mid_x

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if twin == null or twin.dead:
		return super.hit(d, dx, dy, how, b)
	flash = 0.13
	room.spark(cx, cy, col, 4)
	if twin.pend_t > 0.0:                                 # the other twin was hit a moment ago: both count
		var total: int = d + twin.pend_d
		twin.pend_d = 0
		twin.pend_t = 0.0
		pend_d = 0
		pend_t = 0.0
		var pool: int = hp - total
		hp = pool
		twin.hp = pool
		twin.flash = 0.13
		room.burst(twin.cx, twin.cy, 4, [twin.col, "#ffffff"], 90.0, 300.0)
		room.pop(mid_x, minf(y, twin.y) - 10.0, "COMMIT", "#ffd23f", true)
		if pool <= 0:
			var other := twin
			twin = null
			other.twin = null
			other.die(how)
			die(how)
			return "kill"
		Audio.sfx("hit")
		return "hit"
	pend_d += d
	pend_t = WINDOW
	Audio.sfx("clang", {"vol": 0.5})
	return "hit"

func _roll_back() -> void:
	pend_d = 0
	room.pop(cx, y - 10.0, "ROLLBACK", "#8d8798", true)
	room.ring(cx, cy, 2, 12, "#8d8798", 0.3)

func update(dt: float) -> void:
	tick(dt)
	if pend_t > 0.0:
		pend_t -= dt
		if pend_t <= 0.0 and pend_d > 0:
			_roll_back()
	if is_b and twin != null and not twin.dead:
		vx = 0.0
		physics(dt)
		return
	# A (or a twin whose partner is gone) walks; B is moved to A's mirror
	if twin == null or twin.dead:
		if on_ground and (hit_wall != 0 or edge_ahead(dir)):
			dir = -dir
		vx = dir * SPEED * 0.5
		face = dir
		physics(dt)
		return
	face = dir
	var hit_a := room.grid.move_x(self, dir * SPEED * dt)
	var want_bx: float = 2.0 * mid_x - cx - twin.w / 2.0
	var hit_b := room.grid.move_x(twin, want_bx - twin.x)
	twin.face = -dir
	if hit_a != 0 or hit_b != 0 or edge_ahead(dir) or twin.edge_ahead(-dir):
		dir = -dir
	vx = 0.0
	twin.vx = 0.0
	physics(dt)
	twin.physics(dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	var c := Color(col)
	draw_rect(Rect2(px - 1, py - 1, 14, 18), ink)
	draw_rect(Rect2(px, py, 12, 16), c)
	draw_rect(Rect2(px, py, 12, 2), c.lightened(0.35))
	var ex := 7.0 if face > 0.0 else 2.0
	draw_rect(Rect2(px + ex, py + 4, 2, 3), Color.WHITE)
	draw_rect(Rect2(px + ex + (1 if face > 0.0 else 0), py + 5, 1, 2), ink)
	draw_rect(Rect2(px + 2, py + 11, 8, 1), c.darkened(0.4))
	PixelText.draw_text(self, "B" if is_b else "A", px + 6.0, py - 8.0, col, {"align": "c", "tiny": true, "outline": Game.COL.ink})
	if pend_t > 0.0:                                      # a hit is pending: a shrinking bar over the twin
		draw_rect(Rect2(px, py - 3, 12.0 * clampf(pend_t / WINDOW, 0.0, 1.0), 2), Color("#ffd23f"))
	if twin != null and not twin.dead and not is_b:        # the link between the twins
		draw_line(Vector2(cx, cy), Vector2(twin.cx, twin.cy), Color(1, 1, 1, 0.25), 1.0)

func net_fields() -> Array:
	return [roundi(mid_x * 10.0), int(dir), pend_d, roundi(maxf(pend_t, 0.0) * 100.0), 1 if is_b else 0]

func net_apply(f: Array) -> void:
	mid_x = f[0] / 10.0
	dir = float(f[1])
	pend_d = int(f[2])
	pend_t = f[3] / 100.0
	is_b = int(f[4]) == 1
	col = "#ff9a59" if not is_b else "#59a8ff"
