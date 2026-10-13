class_name OrphanChild
extends EnemySM
# The children of an ORPHAN: they orbit the parent (radius 18, a pure function of the clock); when the parent is gone each one dashes at the
# nearest player every 1.0 s (tell 0.35 s, 200 px/s for 0.3 s), staggered so they never come all at once.

const STATES := ["orbit", "hover", "tell", "dash"]

var parent: Orphan = null
var idx := 0
var orphan := false
var cd := 0.0
var dash_dir := Vector2.ZERO

func _init(r: Room, px: float, py: float, i := 0) -> void:
	super(r, px, py, 6, 6)
	idx = i
	hp = 1
	loot = 0
	col = "#dcae5e"
	stompable = false
	state = "orbit"

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	if not orphan and (parent == null or parent.dead or not is_instance_valid(parent)):
		orphan = true
		cd = 0.4 + float(idx) * 0.3
		set_state("hover")
		room.pop(cx, y - 8.0, "orphan", "#ffd97a")
	if not orphan:
		var a := mtime() * 2.4 + float(idx) * TAU / 3.0
		x = parent.cx + cos(a) * 18.0 - w / 2.0
		y = parent.cy + sin(a) * 18.0 - h / 2.0
		return
	match state:
		"hover":
			cd -= dt
			var tp := to_player()
			if tp.p != null:
				var dv := Vector2(tp.dx, tp.dy)
				if dv.length() > 1.0:
					room.grid.move_x(self, dv.normalized().x * 24.0 * dt)
					room.grid.move_y(self, dv.normalized().y * 24.0 * dt)
			if cd <= 0.0 and tp.p != null:
				dash_dir = Vector2(tp.dx, tp.dy).normalized() if Vector2(tp.dx, tp.dy).length() > 1.0 else Vector2.RIGHT
				set_state("tell", 0.35 * float(Game.dv("telegraph_mult")))
				Audio.sfx("warn", {"vol": 0.3})
		"tell":
			var tp2 := to_player()
			if tp2.p != null and Vector2(tp2.dx, tp2.dy).length() > 1.0:
				dash_dir = Vector2(tp2.dx, tp2.dy).normalized()
			if state_t <= 0.0:
				set_state("dash", 0.3)
		"dash":
			var hx := room.grid.move_x(self, dash_dir.x * 200.0 * dt)
			var hy := room.grid.move_y(self, dash_dir.y * 200.0 * dt)
			if state_t <= 0.0 or hx != 0 or hy != 0:
				set_state("hover")
				cd = 1.0 - 0.35 - 0.3
	vx = 0.0
	vy = 0.0

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	var lit: bool = state == "tell" and int(t * 20.0) % 2 == 0
	draw_rect(Rect2(px - 1, py - 1, 8, 8), ink)
	draw_rect(Rect2(px, py, 6, 6), Color("#ff4f6d") if (orphan and not lit) else (Color("#ffd23f") if lit else Color("#dcae5e")))
	draw_rect(Rect2(px + 1, py + 2, 1, 1), Color.WHITE)
	draw_rect(Rect2(px + 4, py + 2, 1, 1), Color.WHITE)

func net_fields() -> Array:
	return [1 if orphan else 0, STATES.find(state), roundi(maxf(state_t, 0.0) * 100.0), idx]

func net_apply(f: Array) -> void:
	orphan = int(f[0]) == 1
	state = STATES[clampi(int(f[1]), 0, 3)]
	state_t = f[2] / 100.0
	idx = int(f[3])
