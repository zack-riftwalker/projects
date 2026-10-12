class_name Scraper
extends EnemySM
# SCRAPER (`c`): hangs from a hook in the ceiling on a thread. When somebody stands under it, it shivers, drops on its thread until it is level with
# them (or hits something), waits, and climbs back. It teaches what a GET anchor looks like: after THE WEB CRAWLER the hook is a ring.

const STATES := ["hang", "tell", "drop", "wait", "climb"]
const MIN_LEN := 8.0
const MAX_LEN := 160.0

var hx := 0.0                     # the hook (px)
var hy := 0.0
var len := MIN_LEN
var tgt_y := 0.0                  # the height it drops to (locked when the drop starts)

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 10)
	hp = 2
	loot = 2
	col = "#8d8798"
	hx = px + 8.0
	hy = py + 8.0
	state = "hang"
	_place()

func _place() -> void:
	x = hx - w / 2.0
	y = hy + len

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	match state:
		"hang":
			len = MIN_LEN
			var tp := to_player()
			if tp.p != null and absf(tp.dx) <= 24.0 and tp.dy > 0.0 and tp.dy <= MAX_LEN and sees_player(24.0, MAX_LEN):
				set_state("tell", 0.4 * float(Game.dv("telegraph_mult")))
				Audio.sfx("warn", {"vol": 0.4})
		"tell":
			if state_t <= 0.0:
				var tp2 := to_player()
				tgt_y = tp2.p.y + 5.0 if tp2.p != null else cy + 40.0
				set_state("drop", 3.0)
		"drop":
			len = minf(len + 260.0 * dt, MAX_LEN)
			_place()
			if cy >= tgt_y or room.grid.solid_at(cx, y + h + 2.0) or len >= MAX_LEN:
				set_state("wait", 0.8)
		"wait":
			if state_t <= 0.0:
				set_state("climb")
		"climb":
			len = maxf(len - 70.0 * dt, MIN_LEN)
			if len <= MIN_LEN:
				set_state("hang")
	_place()

func harmboxes() -> Array:
	return [] if state == "hang" else [self]

func draw_body() -> void:
	var sway := sin(t * 2.0) * (1.5 if state == "hang" else 0.0)
	var shake := (1.0 if int(t * 40.0) % 2 == 0 else -1.0) if state == "tell" else 0.0
	var bx := floori(cx + sway + shake + 0.5)
	var top := floori(y - len + 0.5)
	draw_line(Vector2(bx, top), Vector2(bx, floori(y + 1.0)), Color("#c3bccd"), 1.0)
	var by := floori(y + 0.5)
	draw_rect(Rect2(bx - 6, by, 12, 10), Color(Game.COL.ink))
	draw_rect(Rect2(bx - 5, by + 1, 10, 8), Color(col))
	draw_rect(Rect2(bx - 5, by + 1, 10, 2), Color("#c3bccd"))
	var legs := 1 if int(t * 6.0) % 2 == 0 else 0
	for i in range(4):
		draw_rect(Rect2(bx - 7 + (i % 2) * 13, by + 3 + (i / 2) * 4 + legs, 2, 1), Color(Game.COL.ink))
	draw_rect(Rect2(bx - 1, by + 4, 3, 3), Color(Game.COL.hazard))

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0), roundi(len)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 4)]
	state_t = f[1] / 100.0
	len = float(f[2])
