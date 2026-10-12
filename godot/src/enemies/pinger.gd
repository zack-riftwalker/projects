class_name Pinger
extends EnemySM
# PINGER (`y`, MVB3-03): an ICMP turret on a wall or a ceiling. Every 3 s, when a player is within 200 px with a clear line, its dish glows (the tell),
# then it fires a ball that ricochets four times (TTL). Every third ball is yellow: catch it and it flies back; a caught ball kills the pinger.

const STATES := ["idle", "tell", "cool"]
const EVERY := 3.0
const RANGE := 200.0

var shots := 0                   # balls fired so far (every third is yellow)
var cd := 1.0
var cell := Vector2.ZERO
var side := ""                   # "l" / "r" / "u": the wall it hangs on (found from the room's tiles, the guest too)

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 12)
	hp = 3
	loot = 2
	col = "#7cc4ff"
	stompable = false
	kb = 0.0
	state = "idle"
	cell = Vector2(px, py)
	settle()

# the nearest solid side of its cell: left, right or up (then it sits flush to that side); the room calls this again when all its tiles are read
func settle() -> void:
	var px := cell.x
	var py := cell.y
	var tx := floori((px + 8.0) / T)
	var ty := floori((py + 8.0) / T)
	if room.grid.solid(tx - 1, ty):
		side = "l"
		x = px
		y = py + 2.0
	elif room.grid.solid(tx + 1, ty):
		side = "r"
		x = px + 4.0
		y = py + 2.0
	else:
		side = "u"
		x = px + 2.0
		y = py

func _side() -> String:
	if side != "":
		return side
	var tx := floori(cx / T)
	var ty := floori(cy / T)
	if room.grid.solid(tx - 1, ty):
		return "l"
	if room.grid.solid(tx + 1, ty):
		return "r"
	return "u"

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if how == "catch":
		d = maxi(d, 3)                                     # a ball caught back deals 3
	return super.hit(d, dx, dy, how, b)

func harmboxes() -> Array:
	return []

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	cd -= dt
	match state:
		"idle":
			var tp := to_player()
			if cd <= 0.0 and tp.p != null and tp.d <= RANGE and sees_player(RANGE, RANGE):
				set_state("tell", 0.6 * float(Game.dv("telegraph_mult")))
				Audio.sfx("tick", {"vol": 0.5})
		"tell":
			if state_t <= 0.0:
				_fire()
				cd = EVERY
				set_state("cool", 0.25)
		"cool":
			if state_t <= 0.0:
				set_state("idle")

func _fire() -> void:
	var tp := to_player()
	if tp.p == null:
		return
	var d := Vector2(tp.p.x + 5.0 - cx, tp.p.y + 5.0 - cy)
	if d.length() < 1.0:
		d = Vector2(1, 0)
	d = d.normalized() * 130.0
	var yellow := shots % 3 == 2
	shots += 1
	var o := {"r": 4.0, "bounce": 4, "life": 7.0, "dmg": 1, "by_boss": true, "cut": yellow, "catchable": yellow}
	if yellow:
		o["kind"] = "diamond"
		o["col"] = "#ffd23f"
	else:
		o["kind"] = "orb"
		o["col"] = "#7cc4ff"
	room.shoot(cx, cy, d.x, d.y, o)
	Audio.sfx("shoot", {"vol": 0.6})

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	var s := _side()
	var glow: bool = state == "tell"
	var hot := glow and int(t * 20.0) % 2 == 0
	# a bracket on the wall, a dish pointing away from it
	var dish := Color("#fff3b0") if hot else (Color("#ffd23f") if glow else Color("#9ec4e8"))
	if s == "l":
		draw_rect(Rect2(px - 1, py, 4, 12), ink)
		draw_rect(Rect2(px, py + 1, 2, 10), Color("#4a5a78"))
		draw_rect(Rect2(px + 3, py - 1, 9, 14), ink)
		draw_rect(Rect2(px + 4, py, 7, 12), Color("#5c7aa0"))
		draw_rect(Rect2(px + 8, py + 3, 3, 6), dish)
	elif s == "r":
		draw_rect(Rect2(px + 9, py, 4, 12), ink)
		draw_rect(Rect2(px + 10, py + 1, 2, 10), Color("#4a5a78"))
		draw_rect(Rect2(px, py - 1, 9, 14), ink)
		draw_rect(Rect2(px + 1, py, 7, 12), Color("#5c7aa0"))
		draw_rect(Rect2(px + 1, py + 3, 3, 6), dish)
	else:
		draw_rect(Rect2(px, py - 1, 12, 4), ink)
		draw_rect(Rect2(px + 1, py, 10, 2), Color("#4a5a78"))
		draw_rect(Rect2(px - 1, py + 3, 14, 9), ink)
		draw_rect(Rect2(px, py + 3, 12, 8), Color("#5c7aa0"))
		draw_rect(Rect2(px + 3, py + 7, 6, 3), dish)
	if glow:
		PixelText.draw_text(self, "ping", px + 6.0, py - 9.0, "#ffd23f", {"align": "c", "tiny": true, "outline": Game.COL.ink})
	if shots % 3 == 2 and not glow:                          # the next ball is the yellow one: a tiny yellow pip
		draw_rect(Rect2(px + 5, py + 5, 2, 2), Color("#ffd23f"))

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0), shots]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 2)]
	state_t = f[1] / 100.0
	shots = int(f[2])
