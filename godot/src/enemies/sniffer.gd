class_name Sniffer
extends EnemySM
# SNIFFER (`j`): a packet sniffer that taps a GET ring (MVB3-03). A player whose zip goes to a tapped ring has the zip cut 0.25 s after it
# started (the player does it: Room.ring_tapped, both pages read this creature). Every 2.5 s it probes a player within 120 px: a glow, then one slow
# yellow shot (catch it back: 2 damage). If nobody is near it hops (0.4 s) to the nearest free ring within 80 px. Dead: the ring is clean again.

const STATES := ["tap", "probe", "hop"]
const PROBE_EVERY := 2.5
const HOP_EVERY := 4.0
const HOP_T := 0.4

var ring_i := 0                  # index in room.rings (the same on both pages)
var from_i := 0                  # the ring it left (hop)
var probe_cd := 1.0
var hop_cd := HOP_EVERY
var bob := 0.0

func _init(r: Room, px: float, py: float, ring_idx := 0) -> void:
	super(r, px, py, 10, 10)
	hp = 2
	loot = 2
	col = "#ff5a5a"
	stompable = false
	ring_i = ring_idx
	from_i = ring_idx
	state = "tap"
	_place(0.0)

func _ring_pos(i: int) -> Vector2:
	if i >= 0 and i < room.rings.size():
		return Vector2(float(room.rings[i].x), float(room.rings[i].y))
	return Vector2(cx, cy)

func _place(bobv: float) -> void:
	var p := _ring_pos(ring_i)
	x = p.x - w / 2.0
	y = p.y - h / 2.0 + bobv

# the ring this sniffer listens on (-1 while it is flying between two)
func tapped_ring() -> int:
	return -1 if state == "hop" else ring_i

func _free_ring_near() -> int:
	var best := -1
	var bd := 80.0
	var here := _ring_pos(ring_i)
	for i in range(room.rings.size()):
		if i == ring_i or room.ring_tapped(i):
			continue
		var skip := false
		for q in room.players():                           # not the ring a player is zipping to
			var z = q.get("zip") if not q.get("is_remote") else q.get("cz")
			if z != null and int(z) == i:
				skip = true
		if skip:
			continue
		var d := _ring_pos(i).distance_to(here)
		if d < bd:
			bd = d
			best = i
	return best

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	probe_cd -= dt
	match state:
		"tap":
			bob = sin(t * 3.0) * 2.0
			_place(bob)
			var tp := to_player()
			var near: bool = tp.p != null and tp.d <= 120.0 and sees_player(120.0, 120.0)
			if near and probe_cd <= 0.0:
				set_state("probe", 0.4 * float(Game.dv("telegraph_mult")))
				Audio.sfx("warn", {"vol": 0.4})
			elif tp.d > 64.0:
				hop_cd -= dt
				if hop_cd <= 0.0:
					var nxt := _free_ring_near()
					hop_cd = HOP_EVERY
					if nxt >= 0:
						from_i = ring_i
						ring_i = nxt
						set_state("hop", HOP_T)
			else:
				hop_cd = HOP_EVERY
		"probe":
			_place(sin(t * 3.0) * 2.0)
			if state_t <= 0.0:
				_shoot()
				probe_cd = PROBE_EVERY
				set_state("tap")
		"hop":
			var k := clampf(1.0 - state_t / HOP_T, 0.0, 1.0)
			var a := _ring_pos(from_i)
			var b := _ring_pos(ring_i)
			var p := a.lerp(b, k)
			x = p.x - w / 2.0
			y = p.y - h / 2.0
			if state_t <= 0.0:
				set_state("tap")
				probe_cd = maxf(probe_cd, 0.8)
				hop_cd = HOP_EVERY

func _shoot() -> void:
	var tp := to_player()
	if tp.p == null:
		return
	var d := Vector2(tp.p.x + 5.0 - cx, tp.p.y + 5.0 - cy)
	if d.length() < 1.0:
		return
	d = d.normalized() * 90.0
	room.shoot(cx, cy, d.x, d.y, {"kind": "diamond", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1, "by_boss": true})
	Audio.sfx("shoot", {"vol": 0.6})

func die(how: String) -> void:
	super.die(how)
	room.pop(cx, y - 4.0, "untapped", "#d6f6ff")

func draw_body() -> void:
	var lx := float(floori(cx + 0.5))
	var ly := float(floori(cy + 0.5))
	var ink := Color(Game.COL.ink)
	var red := Color("#ff5a5a")
	if state != "hop":                                         # the tapped ring: a red ring round the GET ring and a tiny `tap`
		var rp := _ring_pos(ring_i)
		draw_arc(rp, 9.0 + sin(t * 6.0) * 0.8, 0.0, TAU, 20, red, 1.0)
		PixelText.draw_text(self, "tap", rp.x, rp.y - 17.0, "#ff5a5a", {"align": "c", "tiny": true, "outline": Game.COL.ink})
	var glow := state == "probe" and int(t * 20.0) % 2 == 0
	# a small body with an antenna and six legs: an eavesdropping crab
	draw_rect(Rect2(lx - 6, ly - 5, 12, 10), ink)
	draw_rect(Rect2(lx - 5, ly - 4, 10, 8), Color("#7a2a3a") if not glow else Color("#ffd23f"))
	draw_rect(Rect2(lx - 5, ly - 4, 10, 2), Color("#b04a5a") if not glow else Color("#fff3b0"))
	draw_rect(Rect2(lx - 3, ly - 1, 2, 2), Color.WHITE)
	draw_rect(Rect2(lx + 1, ly - 1, 2, 2), Color.WHITE)
	draw_rect(Rect2(lx - 2, ly, 1, 1), ink)
	draw_rect(Rect2(lx + 2, ly, 1, 1), ink)
	draw_rect(Rect2(lx, ly - 8, 1, 3), ink)
	draw_rect(Rect2(lx - 1, ly - 9, 3, 2), red)
	for k in range(3):
		var off: float = 1.0 if int(t * 8.0 + k) % 2 == 0 else 0.0
		draw_rect(Rect2(lx - 8, ly - 2 + k * 3 + off, 2, 1), ink)
		draw_rect(Rect2(lx + 6, ly - 2 + k * 3 + off, 2, 1), ink)

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0), ring_i, from_i]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 2)]
	state_t = f[1] / 100.0
	ring_i = int(f[2])
	from_i = int(f[3])
