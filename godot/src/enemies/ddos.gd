class_name DdosBit
extends Enemy
# DDOS (`z` makes five of these): one packet of a swarm. 6x6, hp 1, flies. Idle until a player is within 140 px with a clear line, then the swarm
# orbits that player at radius 30. MVB3-04: they no longer all fly at once. Every 0.6 s one bit of the swarm (round robin) flashes white (0.35 s) and darts
# straight at the player's centre at 220 px/s, then rejoins the ring. A touch hurts (1) and the bit is gone ("packet dropped"). Three or more bits within
# 28 px of a body "jam" it (Room.jam_for).

const STATES := ["orbit", "tell", "dart"]
const RADIUS := 30.0
const DART_EVERY := 0.6
const DART_SPEED := 220.0
const DART_T := 0.3
const TELL_T := 0.35

var idx := 0
var tvx := 0.0
var awake := false
var owner_ref = null              # a BOTNET's bits: the rack that raised them (it knows when the swarm is gone)
var speed_k := 1.0                # a BOTNET's bits move 20 % faster (MVB3-03)
var swarm := 0                    # the swarm it belongs to (Room.spawn_ddos numbers them): the round robin runs inside it
var state := "orbit"
var state_t := 0.0
var dart_dir := Vector2.ZERO
var last_slot := -1               # host: the dart slot (0.6 s of this swarm's clock) already handled

func _init(r: Room, px: float, py: float, i := 0) -> void:
	super(r, px, py, 6, 6)
	x = px
	y = py
	idx = i
	hp = 1
	loot = 0
	col = "#ff6ad5"
	stompable = false
	no_agent = false

# the bits of this swarm that are alive, in index order
func _mates() -> Array:
	var out: Array = []
	for e in room.ents:
		if e is DdosBit and not e.dead and e.swarm == swarm and e.owner_ref == owner_ref:
			out.append(e)
	out.sort_custom(func(a, b): return a.idx < b.idx)
	return out

func update(dt: float) -> void:
	tick(dt)
	var tp := to_player()
	var p = tp.p
	if p != null and not awake and tp.d <= 140.0:
		var clear := true
		var n := maxi(1, int(ceilf(tp.d / 8.0)))
		for i in range(1, n):
			var k := float(i) / n
			if room.grid.solid_at(lerpf(cx, p.x + 5.0, k), lerpf(cy, p.y + 5.0, k)):
				clear = false
				break
		awake = clear
	if awake and p != null and stun <= 0.0:
		state_t -= dt
		# the round robin: this swarm's clock is the room's, shifted by the swarm; the bit whose turn it is flashes
		var slot := floori((room.time + float(swarm % 7) * 0.083) / DART_EVERY)
		if state == "orbit" and slot != last_slot:
			last_slot = slot
			var mates := _mates()
			if not mates.is_empty() and mates[slot % mates.size()] == self:
				state = "tell"
				state_t = TELL_T * float(Game.dv("telegraph_mult"))
				Audio.sfx("tick", {"vol": 0.4})
		elif state == "tell" and state_t <= 0.0:
			var want := Vector2(p.x + 5.0, p.y + 5.0) - Vector2(cx, cy)
			dart_dir = want.normalized() if want.length() > 1.0 else Vector2(1, 0)
			state = "dart"
			state_t = DART_T
			vx = dart_dir.x * DART_SPEED
			vy = dart_dir.y * DART_SPEED
		elif state == "dart" and state_t <= 0.0:
			state = "orbit"
		if state == "dart":
			vx = dart_dir.x * DART_SPEED
			vy = dart_dir.y * DART_SPEED
		else:
			var ang := float(idx) * TAU / 5.0 + t * 1.5
			var target := Vector2(p.x + 5.0 + cos(ang) * RADIUS, p.y + 5.0 + sin(ang) * RADIUS)
			var want2 := target - Vector2(cx, cy)
			if state == "tell":
				vx *= 0.8
				vy *= 0.8
			elif want2.length() > 1.0:
				var a := want2.normalized() * 300.0 * dt
				vx += a.x
				vy += a.y
			var sp := Vector2(vx, vy)
			if sp.length() > 90.0 * speed_k:
				sp = sp.normalized() * 90.0 * speed_k
				vx = sp.x
				vy = sp.y
		for e in room.ents:                       # the bits push each other apart
			if e != self and e is DdosBit and not e.dead and Vector2(e.cx - cx, e.cy - cy).length() < 6.0:
				var away := Vector2(cx - e.cx, cy - e.cy)
				away = away.normalized() if away.length() > 0.01 else Vector2(1, 0)
				x += away.x
				y += away.y
		# touching the partner (a body the host only simulates): the bit is spent; the guest's own body is hurt by the guest (it sees this bit as a puppet)
		for q in room.remote_players:
			if not q.dead and Game.overlap(q.hurtbox(), self):
				die("packet")
	else:
		vx *= 0.9
		vy *= 0.9
	x += vx * dt
	y += vy * dt
	if room.grid.box_hits_solid(x, y, w, h):
		x -= vx * dt
		y -= vy * dt
		vx *= -0.5
		vy *= -0.5
		if state == "dart":                       # a dart that meets a wall is over
			state = "orbit"

# the player was hurt by it: it is spent
func on_contact() -> void:
	if not puppet:
		die("packet")

func die(how: String) -> void:
	super.die(how)
	room.pop(cx, y - 4.0, "packet dropped", "#ffe0f6")

func draw_body() -> void:
	var px := floori(x + 0.5)
	var py := floori(y + 0.5)
	var flash: bool = state == "tell" and int(t * 24.0) % 2 == 0
	draw_rect(Rect2(px - floori(vx * 0.03), py - floori(vy * 0.03), 6, 6), Color(1.0, 0.42, 0.84, 0.25))     # a short trail
	draw_rect(Rect2(px, py, 6, 6), Color(Game.COL.ink))
	draw_rect(Rect2(px + 1, py + 1, 4, 4), Color.WHITE if (flash or state == "dart") else Color("#ff6ad5"))
	draw_rect(Rect2(px + 1, py + 1, 1, 1), Color("#ffe0f6"))

func net_fields() -> Array:
	return [1 if awake else 0, idx, STATES.find(state), roundi(state_t * 100.0)]

func net_apply(f: Array) -> void:
	awake = int(f[0]) == 1
	idx = int(f[1])
	if f.size() > 3:
		state = STATES[clampi(int(f[2]), 0, 2)]
		state_t = f[3] / 100.0
