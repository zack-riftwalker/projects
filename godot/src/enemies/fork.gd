class_name Fork
extends EnemySM
# FORK (K): a nest that spawns bugs (`fork()`). It does not move and cannot be stomped. While a player is within 200 px and fewer than 4 of
# its children live, it shakes for 0.4 s every 3.0 s and a small Bug crawls out at its side.

const MAX_KIDS := 4
const EVERY := 3.0
const STATES := ["idle", "shake"]

var cool := 1.5
var kids: Array = []
var side := 1.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 14, 12)
	hp = 4
	loot = 2
	stompable = false
	col = "#3a3346"

func alive_kids() -> int:
	kids = kids.filter(func(k): return is_instance_valid(k) and not k.dead)
	return kids.size()

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	var tp := to_player()
	match state:
		"idle":
			cool -= dt
			if cool <= 0.0 and tp.p != null and tp.d < 200.0 and alive_kids() < MAX_KIDS:
				set_state("shake", 0.4)
				Audio.sfx("thud", {"vol": 0.5})
		"shake":
			if state_t <= 0.0:
				var b := Bug.new(room, cx + side * 11.0 - 8.0, y + h - 16.0, false)
				b.face = side
				room.add_entity(b)
				b.loot = 0
				kids.append(b)
				side = -side
				room.dust(cx + side * -11.0, y + h, 4)
				set_state("idle")
				cool = EVERY
	physics(dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var bx := floorf(x) + (1.0 if state == "shake" and int(t * 40.0) % 2 == 0 else 0.0)
	var by := floorf(y)
	# the mound, with a door-like hole, and the label
	draw_rect(Rect2(bx, by + 1, w, h - 1), ink)
	draw_rect(Rect2(bx + 1, by, w - 2, 1), ink)
	draw_rect(Rect2(bx + 1, by + 1, w - 2, h - 2), Color("#3a3346"))
	draw_rect(Rect2(bx + 2, by + 1, w - 4, 1), Color("#4c4658"))
	draw_rect(Rect2(bx + 5, by + 6, 4, 6), ink)
	draw_rect(Rect2(bx + 6, by + 7, 2, 5), Color("#0d0a12"))
	PixelText.draw_text(self, "fork()", bx - 3.0, by - 8.0, "#ffd97a", {"tiny": true, "outline": Game.COL.ink})

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 1)]
	state_t = f[1] / 100.0
