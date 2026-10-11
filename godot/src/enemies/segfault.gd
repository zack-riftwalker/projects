class_name Segfault
extends EnemySM
# SEGFAULT (x): runs at you, blinks red for 0.6 s and dumps core. The blast hurts everybody near it, hurts creatures and breaks
# bulkheads (Room.blast). A hit while it is arming makes it blow up at once; killed while it idles or chases it just dies.

const STATES := ["idle", "chase", "arm", "boom"]
const BLAST_R := 34.0
const HURT_R := 30.0

var run_wall := false          # committed to running into the bulkhead ahead

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 12)
	hp = 2
	loot = 2
	col = "#ff5d5d"
	face = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0

# a bulkhead within `dist` px straight ahead of the body (at its middle height)
func _thick_ahead(dist: float) -> bool:
	var k := 2.0
	while k <= dist:
		var fx := cx + face * (w / 2.0 + k)
		if room.grid.tile(floori(fx / T), floori(cy / T)) == TileGrid.THICK:
			return true
		k += 4.0
	return false

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if state == "arm" and not dead:
		flash = 0.13
		_boom()
		return "kill"
	return super.hit(d, dx, dy, how, b)

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	var tp := to_player()
	match state:
		"idle":
			if on_ground and stun <= 0.0:
				if hit_wall != 0 or edge_ahead(face):
					face = -face
				vx = face * 20.0
			elif on_ground:
				vx *= 0.85
			if tp.p != null and absf(tp.dx) <= 140.0 and absf(tp.dy) <= 40.0 and sees_player(140.0, 40.0):
				set_state("chase")
		"chase":
			if on_ground and stun <= 0.0:
				if not run_wall and tp.p != null and absf(tp.dx) > 1.0:
					face = Game.sign_of(tp.dx)
				var blocked := edge_ahead(face)
				vx = 0.0 if blocked else face * 95.0
				var bumped: bool = hit_wall != 0 and room.grid.tile(floori((cx + face * (w / 2.0 + 2.0)) / T), floori(cy / T)) == TileGrid.THICK
				if not run_wall and absf(tp.dx) <= 26.0 and _thick_ahead(64.0):
					run_wall = true             # a bulkhead right ahead (the player stands at it): run on into it, so the blast is centred on the wall
				if bumped or (run_wall and blocked) or (not run_wall and absf(tp.dx) <= 26.0):
					set_state("arm", 0.6 * float(Game.dv("telegraph_mult")))
					vx = 0.0
					run_wall = false
					Audio.sfx("warn", {"vol": 0.6})
				elif tp.d > 240.0:
					set_state("idle")
					run_wall = false
			elif on_ground:
				vx *= 0.85
		"arm":
			vx = 0.0
			if state_t <= 0.0:
				_boom()
				return
	physics(dt)

func _boom() -> void:
	set_state("boom")
	var bx := cx
	var by := cy
	room.blast(bx, by, BLAST_R)
	room.harm_zone("c", bx, by, HURT_R, 0.0, 1)             # the guest checks its own body against the blast
	for q in room.players():
		if q.get("is_remote"):
			continue
		if Vector2(q.x + 5.0 - bx, q.y + 5.0 - by).length() < HURT_R:
			q.hurt(1, bx)
	for e in room.ents:
		if e == self or e.dead or e.no_hit:
			continue
		if Vector2(e.cx - bx, e.cy - by).length() < HURT_R:
			e.hit(2, Game.sign_of(e.cx - bx), 0.0, "blast")
	room.pop(bx, y - 10.0, "core dumped", "#ff5d5d", true)
	die("blast")

func harmboxes() -> Array:
	if state == "chase" or state == "arm":
		return [self]
	return []

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var body := Color("#a8183a")
	if state == "arm" and int(t * 12.0) % 2 == 0:
		body = Color.WHITE
	draw_rect(Rect2(x - 1.0, y, 14, 12), ink)
	draw_rect(Rect2(x, y - 1.0, 12, 14), ink)
	draw_rect(Rect2(x, y, 12, 12), body)
	var ex := 7.0 if face > 0.0 else 3.0
	draw_rect(Rect2(x + ex - 2.0, y + 2.0, 2, 2), Color.WHITE)
	draw_rect(Rect2(x + ex + 1.0, y + 2.0, 2, 2), Color.WHITE)
	PixelText.draw_text(self, "0x0", x + 6.0, y + 6.0, "#ffd0d6", {"align": "c", "tiny": true})

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 3)]
	state_t = f[1] / 100.0
