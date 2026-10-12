class_name DdosBit
extends Enemy
# DDOS (`z` makes five of these): one packet of a swarm. 6x6, hp 1, flies. Idle until a player is within 140 px with a clear line, then it homes in
# on a point 18 px round that player (each bit its own angle), so the swarm closes in as a ring. A touch hurts (1) and the bit is gone ("packet dropped").

var idx := 0
var tvx := 0.0
var awake := false
var owner_ref = null              # a BOTNET's bits: the rack that raised them (it knows when the swarm is gone)
var speed_k := 1.0                # a BOTNET's bits move 20 % faster (MVB3-03)

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
		var ang := float(idx) * TAU / 5.0 + t * 1.5
		var target := Vector2(p.x + 5.0 + cos(ang) * 18.0, p.y + 5.0 + sin(ang) * 18.0)
		var want := target - Vector2(cx, cy)
		if want.length() > 1.0:
			var a := want.normalized() * 300.0 * dt
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
	draw_rect(Rect2(px - floori(vx * 0.03), py - floori(vy * 0.03), 6, 6), Color(1.0, 0.42, 0.84, 0.25))     # a short trail
	draw_rect(Rect2(px, py, 6, 6), Color(Game.COL.ink))
	draw_rect(Rect2(px + 1, py + 1, 4, 4), Color("#ff6ad5"))
	draw_rect(Rect2(px + 1, py + 1, 1, 1), Color("#ffe0f6"))

func net_fields() -> Array:
	return [1 if awake else 0, idx]

func net_apply(f: Array) -> void:
	awake = int(f[0]) == 1
	idx = int(f[1])
