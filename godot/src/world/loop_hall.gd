class_name LoopHall
extends RefCounted
# LoopHall: the iteration shaft of INFINITE LOOP v3 (T10, docs/metroidvania/18-loop-build.md §3-4). The room owns it, not the boss, so the shaft (and
# the open snake lying on its floor) is still there after the fight. Its state is written by the host and travels in the boss's net fields
# (net_pack / net_unpack); everything a page shows or stands on is a pure function of that state and the room's clock, so both pages build the same
# ledges, gears, gantry and pit.
#
# Pieces (tiles of 16 px): the low ledges L1 / R1 (row 25, one-way, they slide into the walls in phase 2 and come back in phase 3), two tick gears
# whose four teeth are platforms (their direction flips at every `i++` in phase 2), the gantry `while (true) {` (row 4; it swings on two chains from
# phase 2 on), the wall counter `i = <n>` and, in phase 3, the pit: floor and ceiling columns 6..17 open and a body that falls through comes back in
# at the top (the vertical wrap: each page moves its own body). M, L2, R2 and TOP are plain one-way tiles of the map file.
# Before the first fight the room plays the fake loop: the east door looks open, and whoever walks through it comes back in by the west door.

const T := 16
const PW := 384.0
const PH := 512.0
const FLOOR_ROW := 29
const FLOOR_Y := 464.0
const PIT_A := 6
const PIT_B := 17
const LOW := [[3, 5, 25, -1], [18, 20, 25, 1]]        # L1 / R1: first column, last column, row, the wall they slide into (-1 west, 1 east)
const GEAR_C := [Vector2(88.0, 296.0), Vector2(296.0, 296.0)]      # tiles (5, 18) / (18, 18), centres
const GEAR_R := 32.0                                   # 2 tiles
const GEAR_N := 4
const TOOTH_W := 32.0
const GANTRY_X := 128.0                                # cols 8..15, row 4
const GANTRY_W := 128.0
const GANTRY_Y := 64.0
const CHAIN_Y := 16.0                                  # the chains hang from row 1
const SWING_PX := 32.0
const SWING_TICKS := 4.0
const RETRACT_T := 0.6
const CRACK_T := 0.8                                   # phase 3: the floor's cracks glow this long, then it falls away
const CLOSE_T := 0.4                                   # death: the floor slides back
const FAKE_X := 368.0                                  # the fake loop: a body whose centre crosses this comes back in by the west door
const FAKE_SEEN_X := 352.0                             # (the host sees the partner late: a little earlier for it)
const FAKE_MAX := 8.0
const SPOT := Vector2(24.0, 448.0)                     # the west door's inside (x of a body's left side; its feet go on the floor)
const COUNTER0 := 4095
const NONE_T := -100.0
const NEVER := -10000

const INK := "#1b1226"
const BRASS := "#a8793a"
const BRASS_HI := "#dcae5e"
const BRASS_CAP := "#f3d58a"
const BRASS_LO := "#5f3d1e"
const WALL := "#24170d"
const WALL_HI := "#3a2614"
const WALL_LO := "#160d07"
const VD := ["#0f2a27", "#1d4a44", "#2f7f6a", "#5fc0a0", "#b8f0d8"]
const OPUS := "#9b6bff"
const HEAT := "#ff7a59"

var room
var ph := 1                       # 1..3 (the boss writes it)
var p2_t0 := NONE_T               # phase 2 began (the low ledges retract, the gantry starts to swing)
var p3_t0 := NONE_T               # phase 3 began (cracks 0.8 s, then the pit; the low ledges come back)
var close_t0 := NONE_T            # the death: the pit's floor slides back
var counter := COUNTER0           # the wall's `i = <n>`
var gear_dir := 1                 # 1 clockwise
var gear_s0 := 0.0                # gear steps (45 degrees each) at gear_k0
var gear_k0 := 0.0                # the tick clock (ticks, eased) when the direction last changed
var fake_on := false              # the fake loop is armed (host decides; the guest reads it)
var fake_t := 0.0                 # host: how long it has been armed
var wrap_n := 0                   # host: how many times the fake loop sent everybody back (the guest moves itself when it changes)
var wrap_t0 := NONE_T
var after := false                # boss:LOOP: the open snake on the floor, plate false, the counter frozen
var violet := 0.0                 # phase 2's violet wash from the snake (the boss writes 0..1; drawn by the hall)
var heat := 0.0                   # phase 3's red

var gears_p: Array = []           # [gear][tooth] platform dicts (also in room.plats)
var gantry_p: Dictionary = {}
var _sig: Array = []
var static_rev := 0
var _drawn_rev := -1
var wall_node: Node2D = null
var gantry_node: Node2D = null
var _seen_wrap := -1              # guest: the wrap_n it has acted on (-1: the first snapshot sets it)
var _local_wrapped := false       # this page already moved its own body for the fake loop

func _init(r) -> void:
	room = r
	after = Game.flag("boss:LOOP")
	counter = final_count() if after else COUNTER0
	for gi in range(2):
		var arr: Array = []
		for j in range(GEAR_N):
			var m := {"x": 0.0, "y": 0.0, "w": TOOTH_W, "h": 6.0, "dx": 0.0, "dy": 0.0, "lhall": true, "lgear": gi, "j": j}
			arr.append(m)
			room.plats.append(m)
		gears_p.append(arr)
	gantry_p = {"x": GANTRY_X, "y": GANTRY_Y, "w": GANTRY_W, "h": 6.0, "dx": 0.0, "dy": 0.0, "lhall": true, "gantry": true}
	room.plats.append(gantry_p)
	fake_on = not after and not Game.flag("intro:LOOP")
	move_parts()
	apply()

# the counter the snake stopped at (a flag `loop:final:<n>` set at the kill; read once when the room loads, never per frame)
static func final_count() -> int:
	for k in Game.flags:
		var ks := String(k)
		if ks.begins_with("loop:final:"):
			return int(ks.substr(11))
	return COUNTER0 + 1

static func wanted(def: Dictionary) -> bool:
	return String(def.get("hall", "")) == "loop"

# a fresh phase 1 (retry)
func reset() -> void:
	ph = 1
	p2_t0 = NONE_T
	p3_t0 = NONE_T
	close_t0 = NONE_T
	gear_dir = 1
	gear_s0 = gear_steps(room.time)
	gear_k0 = _tk(room.time)
	violet = 0.0
	heat = 0.0
	_sig = []
	apply()

# ---------------------------------------------------------------- the clock
func _tick_len() -> float:
	return room.tick_len()

func _tk(tm: float) -> float:                           # ticks, eased like the tower's gears (a step in the first 0.3 of each tick)
	var tl := _tick_len()
	return float(Tower.tick_i_of(tm, tl)) + Tower.ease_tick(Tower.tick_f_of(tm, tl))

func gear_steps(tm: float) -> float:
	return gear_s0 + float(gear_dir) * (_tk(tm) - gear_k0)

# the boss flips the gears at every `i++` of phase 2 (continuous: the teeth never jump)
func flip_gears(tm: float) -> void:
	gear_s0 = gear_steps(tm)
	gear_k0 = _tk(tm)
	gear_dir = -gear_dir

func tooth_pos(gi: int, j: int, tm: float) -> Vector2:
	var a := deg_to_rad(-90.0 + gear_steps(tm) * 45.0 + float(j) * 360.0 / float(GEAR_N))
	return GEAR_C[gi] + Vector2(cos(a), sin(a)) * GEAR_R

# the gantry: level, on two chains 48 px long; phase 2+ it swings 32 px each way, period 4 ticks, a pure function of the room's clock
func gantry_off(tm: float) -> Vector2:
	if after or ph < 2 or p2_t0 < 0.0:
		return Vector2.ZERO
	var per := SWING_TICKS * _tick_len()
	var ramp := clampf((tm - p2_t0) / 1.0, 0.0, 1.0)          # (the chains slacken over a second: it starts gently)
	var sx := SWING_PX * ramp * sin(TAU * (tm - p2_t0) / per)
	var ln := GANTRY_Y - CHAIN_Y
	var dy := ln - sqrt(maxf(0.0, ln * ln - sx * sx))
	return Vector2(sx, -dy)

# ---------------------------------------------------------------- the phases' room states
# how many columns of a low ledge stand now (3: all; they go from the room side into the wall, one column per 0.2 s)
func low_cols(tm: float) -> int:
	if after:
		return 3
	if ph == 2 and p2_t0 >= 0.0:
		return clampi(3 - floori((tm - p2_t0) / RETRACT_T * 3.0), 0, 3)
	if ph == 3 and p3_t0 >= 0.0:
		return clampi(floori((tm - p3_t0) / RETRACT_T * 3.0) + 1, 0, 3) if tm >= p3_t0 else 0
	return 3

# the floor cracks glow (phase 3's build-up: >= 0.6 s, no damage)
func cracking(tm: float) -> float:
	if ph != 3 or p3_t0 < 0.0 or tm < p3_t0 or tm >= p3_t0 + CRACK_T:
		return -1.0
	return (tm - p3_t0) / CRACK_T

func pit_open(tm: float) -> bool:
	if after or ph != 3 or p3_t0 < 0.0 or tm < p3_t0 + CRACK_T:
		return false
	return not (close_t0 >= 0.0 and tm >= close_t0 + CLOSE_T)

# the floor sliding back in the death scene (0..1), -1 when not
func closing(tm: float) -> float:
	if close_t0 < 0.0 or tm < close_t0 or tm >= close_t0 + CLOSE_T or ph != 3:
		return -1.0
	return (tm - close_t0) / CLOSE_T

func in_pit_cols(px: float) -> bool:
	return px >= float(PIT_A * T) and px < float((PIT_B + 1) * T)

# the fake loop: the east door is a portal (it looks open) while it is armed
func door_portal(d: Dictionary) -> bool:
	return fake_on and String(d.side) == "E"

# ---------------------------------------------------------------- per step (host, solo and guest)
func move_parts() -> void:
	var tm: float = room.time
	for gi in range(2):
		for j in range(GEAR_N):
			var m: Dictionary = gears_p[gi][j]
			var pos := tooth_pos(gi, j, tm)
			var nx := pos.x - TOOTH_W / 2.0
			var ny := pos.y - 3.0
			m["dx"] = nx - float(m.x)
			m["dy"] = ny - float(m.y)
			m["x"] = nx
			m["y"] = ny
	var go := gantry_off(tm)
	var gx := GANTRY_X + go.x
	var gy := GANTRY_Y + go.y
	gantry_p["dx"] = gx - float(gantry_p.x)
	gantry_p["dy"] = gy - float(gantry_p.y)
	gantry_p["x"] = gx
	gantry_p["y"] = gy
	if gantry_node != null and is_instance_valid(gantry_node):
		gantry_node.position = Vector2(roundf(go.x), roundf(go.y))

func step(dt: float) -> void:
	apply()
	if room.mode != "guest":
		_step_fake(dt)
	else:
		_guest_fake()
	_wrap_local()
	if wall_node != null and is_instance_valid(wall_node):
		if _drawn_rev != static_rev:
			_drawn_rev = static_rev
			wall_node.queue_redraw()
		# the washes tint the back wall only (a modulate: nothing is redrawn): violet from the snake in phase 2, a darker red in phase 3
		var wc := Color(1.0, 1.0, 1.0).lerp(Color(0.86, 0.74, 1.0), clampf(violet, 0.0, 1.0)).lerp(Color(0.78, 0.5, 0.48), clampf(heat, 0.0, 1.0))
		if wall_node.modulate != wc:
			wall_node.modulate = wc

# the masks as tiles: the low ledges and the pit (floor rows 29..31 and ceiling row 0, columns 6..17). Idempotent; only a change touches the grid
func apply() -> void:
	var tm: float = room.time
	var n := low_cols(tm)
	var pit := pit_open(tm)
	var s: Array = [n, pit]
	if s == _sig:
		return
	_sig = s
	var g = room.grid
	for lw in LOW:
		var a: int = lw[0]
		var b: int = lw[1]
		var wall: int = lw[3]
		for tx in range(a, b + 1):
			var k := (tx - a) if wall < 0 else (b - tx)        # 0 = the column next to the wall: the last to go
			_set_tile(g, tx, int(lw[2]), TileGrid.ONEWAY if k < n else TileGrid.E)
	for tx in range(PIT_A, PIT_B + 1):
		for ty in [0, FLOOR_ROW, FLOOR_ROW + 1, FLOOR_ROW + 2]:
			_set_tile(g, tx, ty, TileGrid.E if pit else TileGrid.SOLID)
	g.seam_a = PIT_A if pit else -1
	g.seam_b = PIT_B if pit else -2
	if not pit:                                       # the floor came back (the death, a retry): this page's own body is not left inside it
		var p = room.player
		if p != null and not p.dead and in_pit_cols(p.x + p.w / 2.0) and p.y + p.h > FLOOR_Y:
			p.y = FLOOR_Y - p.h
			p.vy = 0.0

func _set_tile(g, tx: int, ty: int, t: int) -> void:
	var idx: int = ty * g.w + tx
	if g.tiles[idx] == t:
		return
	g.tiles[idx] = t
	if room.view != null:
		room.view.refresh_tile(tx, ty)

# phase 3: this page's own body comes back in at the top (each page moves its own; the camera cuts, it does not pan across the room)
func _wrap_local() -> void:
	if not pit_open(room.time):
		return
	var p = room.player
	if p == null or p.dead:
		return
	var mid: float = p.x + p.w / 2.0
	if p.y + p.h / 2.0 > PH and in_pit_cols(mid):
		var dy: float = -float(p.h) - p.y
		p.y = -float(p.h)
		p.vy = minf(p.vy, 330.0)
		_cut_cam(dy)

func _cut_cam(dy: float) -> void:
	room.cam.y += dy
	room.cam.ty += dy

# host: the fake loop. Any body past the east door (or 8 s) sends everybody back to the west door, the counter goes to 4096, and the fight starts
func _step_fake(dt: float) -> void:
	if not fake_on:
		return
	if room.fight.state != "none" or after:
		fake_on = false
		return
	var ps: Array = room.players()
	if ps.is_empty():
		return
	fake_t += dt
	var go := fake_t >= FAKE_MAX
	for q in ps:
		var lim := FAKE_SEEN_X if q.get("is_remote") == true else FAKE_X
		if q.x + q.w / 2.0 > lim:
			go = true
	if not go:
		return
	fake_on = false
	wrap_n += 1
	wrap_t0 = room.time
	counter = COUNTER0 + 1
	static_rev += 1
	Game.flags["intro:LOOP"] = true
	_place_self()
	if room.boss != null and room.fight.state == "none":
		room._start_intro()

# guest: the host sent everybody back; this page moves its own body (once)
func _guest_fake() -> void:
	if _seen_wrap < 0:
		_seen_wrap = wrap_n
		return
	if wrap_n != _seen_wrap:
		_seen_wrap = wrap_n
		if room.time - wrap_t0 < 1.5:
			_place_self()
	var p = room.player
	if fake_on and p != null and not p.dead and p.x + p.w / 2.0 > FAKE_X:
		_place_self()                                   # (it got there first: back in by the west door now; the host follows when it sees it)

func _place_self() -> void:
	var p = room.player
	room.flash_screen(0.35)
	if p == null or p.dead:
		return
	if _local_wrapped and p.x < 64.0:
		return
	_local_wrapped = true
	var dy: float = (FLOOR_Y - p.h) - p.y
	p.x = SPOT.x
	p.y = FLOOR_Y - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.face = 1
	room.cam.x = 0.0
	_cut_cam(dy)
	Audio.local_sfx("tick", 0.5)

func set_counter(n: int) -> void:
	if n != counter:
		counter = n
		static_rev += 1

func cam_lock():
	var b = room.boss
	if b != null and is_instance_valid(b) and b.has_method("cam_lock_now"):
		return b.cam_lock_now()
	return null

# ---------------------------------------------------------------- the net (times x100)
func _t100(v: float) -> int:
	return NEVER if v < -50.0 else roundi(v * 100.0)

func _from100(v) -> float:
	return NONE_T if int(v) <= NEVER else float(v) / 100.0

func net_pack() -> Array:
	return [ph, _t100(p2_t0), _t100(p3_t0), _t100(close_t0), counter, gear_dir, roundi(gear_s0 * 1000.0), roundi(gear_k0 * 1000.0),
		1 if fake_on else 0, wrap_n, _t100(wrap_t0), 1 if after else 0, roundi(violet * 100.0), roundi(heat * 100.0)]

const NET_N := 14

func net_unpack(a: Array) -> void:
	if a.size() < NET_N:
		return
	ph = int(a[0])
	p2_t0 = _from100(a[1])
	p3_t0 = _from100(a[2])
	close_t0 = _from100(a[3])
	set_counter(int(a[4]))
	gear_dir = int(a[5])
	gear_s0 = float(a[6]) / 1000.0
	gear_k0 = float(a[7]) / 1000.0
	fake_on = int(a[8]) == 1
	wrap_n = int(a[9])
	wrap_t0 = _from100(a[10])
	after = int(a[11]) == 1
	violet = float(a[12]) / 100.0
	heat = float(a[13]) / 100.0

# ---------------------------------------------------------------- drawing: the back wall (drawn once; again only when the counter changes)
func make_nodes(parent: Node, z: int) -> Array:
	var dyn := DrawProxy.new()
	dyn.name = "LoopHall"
	dyn.cb = draw_dynamic
	dyn.z_index = z
	parent.add_child(dyn)
	gantry_node = DrawProxy.new()
	gantry_node.name = "LoopGantry"
	gantry_node.cb = draw_gantry
	gantry_node.z_index = z
	parent.add_child(gantry_node)
	move_parts()
	return [dyn]

func draw_wall(ci: CanvasItem) -> void:
	var wall := Color(WALL)
	ci.draw_rect(Rect2(0.0, 0.0, PW, PH), wall)
	# the shaft's riveted panels: tall plates in four columns, a seam between them
	for c in range(4):
		var x0 := 16.0 + float(c) * 88.0
		for r in range(5):
			var y0 := 16.0 + float(r) * 92.0
			var rc := Rect2(x0 + 2.0, y0 + 2.0, 84.0, 88.0)
			ci.draw_rect(rc, Color(WALL_HI))
			ci.draw_rect(rc.grow(-1.0), wall)
			ci.draw_rect(Rect2(rc.position.x + 1.0, rc.end.y - 3.0, rc.size.x - 2.0, 2.0), Color(WALL_LO))
			for p in [Vector2(4, 4), Vector2(rc.size.x - 5.0, 4), Vector2(4, rc.size.y - 5.0), Vector2(rc.size.x - 5.0, rc.size.y - 5.0)]:
				ci.draw_rect(Rect2(rc.position + p, Vector2(1, 1)), Color(BRASS_LO))
	# two pipes up the shaft (the old scheduler's), and the darkness above (the snake comes down out of it)
	for px in [52.0, 330.0]:
		ci.draw_rect(Rect2(px, 0.0, 6.0, PH), Color(WALL_LO))
		ci.draw_rect(Rect2(px + 1.0, 0.0, 1.0, PH), Color(BRASS_LO))
	for k in range(6):
		ci.draw_rect(Rect2(0.0, float(k) * 6.0, PW, 6.0), Color(0.0, 0.0, 0.0, 0.35 - float(k) * 0.05))
	# the counter: a brass frame round dark glass, `i = <n>` in mint
	var cr := Rect2(148.0, 222.0, 88.0, 26.0)
	ci.draw_rect(cr.grow(2.0), Color(INK))
	ci.draw_rect(cr.grow(1.0), Color(BRASS))
	ci.draw_rect(cr, Color("#08100e"))
	ci.draw_rect(Rect2(cr.position.x, cr.position.y, cr.size.x, 1.0), Color(BRASS_LO))
	PixelText.draw_text(ci, "i = %d" % counter, cr.get_center().x, cr.position.y + 10.0, VD[3] if not after else VD[2], {"align": "c"})
	# the diff sign by the west door (the user's refactor: the retry limit went)
	var sr := Rect2(18.0, 318.0, 136.0, 54.0)
	ci.draw_rect(sr.grow(1.0), Color(INK))
	ci.draw_rect(sr, Color("#d9cfae"))
	ci.draw_rect(Rect2(sr.position.x, sr.end.y - 2.0, sr.size.x, 2.0), Color("#a89c78"))
	var lines := [["- for (attempt = 0;", "#b0303c"], ["   attempt < 3; attempt++)", "#b0303c"], ["+ while (true)", "#2a7a40"], ["   // retries are cheap", "#6b6b6b"]]
	for k in range(lines.size()):
		PixelText.draw_text(ci, String(lines[k][0]), sr.position.x + 4.0, sr.position.y + 4.0 + float(k) * 12.0 + (3.0 if k >= 2 else 0.0), String(lines[k][1]), {})
	# the gear hubs' brackets (the hubs themselves turn, drawn every frame)
	for c in GEAR_C:
		ci.draw_rect(Rect2(c.x - 3.0, c.y, 6.0, 40.0), Color(WALL_LO))

# the gantry (its own node: drawn once, the swing only moves it)
func draw_gantry(ci: CanvasItem) -> void:
	var r := Rect2(GANTRY_X, GANTRY_Y, GANTRY_W, 10.0)
	ci.draw_rect(r.grow(1.0), Color(INK))
	ci.draw_rect(r, Color(BRASS))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), Color(BRASS_CAP))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), Color(BRASS_LO))
	ci.draw_rect(Rect2(r.position.x + 20.0, r.end.y + 1.0, r.size.x - 40.0, 11.0), Color(INK))
	PixelText.draw_text(ci, "while (true) {", r.get_center().x, r.end.y + 2.0, VD[3], {"align": "c"})
	for k in range(8):
		ci.draw_rect(Rect2(r.position.x + 6.0 + float(k) * 16.0, r.position.y + 4.0, 2.0, 2.0), Color(BRASS_LO))

# ---------------------------------------------------------------- drawing: every frame (the gears' teeth, the chains, the pit's seam and cracks, the washes)
func draw_dynamic(ci: CanvasItem) -> void:
	var tm: float = room.time
	var ink := Color(INK)
	# the gantry's chains (from row 1 to the beam's ends)
	var go := gantry_off(tm)
	for ex in [GANTRY_X + 8.0, GANTRY_X + GANTRY_W - 8.0]:
		var top := Vector2(ex, CHAIN_Y)
		var bot := Vector2(ex + go.x, GANTRY_Y + go.y)
		var n := 6
		for k in range(n):
			var pa := top.lerp(bot, float(k) / float(n))
			ci.draw_rect(Rect2(floorf(pa.x) - 1.0, floorf(pa.y), 3.0, 5.0), ink)
			ci.draw_rect(Rect2(floorf(pa.x), floorf(pa.y) + 1.0, 1.0, 3.0), Color(BRASS_HI))
	# the gears: spokes to the teeth, the teeth (platforms), the hub
	for gi in range(2):
		var c: Vector2 = GEAR_C[gi]
		ci.draw_circle(c, GEAR_R - 6.0, Color(BRASS_LO), false, 3.0)
		for j in range(GEAR_N):
			var pos := tooth_pos(gi, j, tm)
			ci.draw_line(c, pos, ink, 4.0)
			ci.draw_line(c, pos, Color(BRASS), 2.0)
			var tr := Rect2(floorf(pos.x - TOOTH_W / 2.0), floorf(pos.y - 3.0), TOOTH_W, 6.0)
			ci.draw_rect(tr.grow(1.0), ink)
			ci.draw_rect(tr, Color(BRASS))
			ci.draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, 1.0), Color(BRASS_CAP))
		ci.draw_circle(c, 9.0, ink)
		ci.draw_circle(c, 8.0, Color(BRASS))
		ci.draw_circle(c, 3.0, Color(BRASS_LO))
	# phase 3: the floor's cracks glow before it falls; the open seams are lit (a faint white band) so the pit always reads
	var ck := cracking(tm)
	if ck >= 0.0:
		var a := 0.35 + 0.65 * ck
		var hot := Color(HEAT, a) if int(tm * 16.0) % 2 == 0 else Color("#ffd0a0", a)
		for k in range(PIT_A, PIT_B + 1):
			var cx := float(k * T) + 4.0 + float((k * 7) % 9)
			ci.draw_line(Vector2(cx, FLOOR_Y), Vector2(cx + 3.0, FLOOR_Y + 9.0), hot, 1.0)
			ci.draw_line(Vector2(cx + 3.0, FLOOR_Y + 9.0), Vector2(cx - 2.0, FLOOR_Y + 16.0), hot, 1.0)
		ci.draw_rect(Rect2(float(PIT_A * T), FLOOR_Y - 1.0, float((PIT_B - PIT_A + 1) * T), 1.0), hot)
	if pit_open(tm):
		var x0 := float(PIT_A * T)
		var wd := float((PIT_B - PIT_A + 1) * T)
		for k in range(4):
			var al := 0.16 - float(k) * 0.04
			ci.draw_rect(Rect2(x0, float(k) * 2.0, wd, 2.0), Color(1.0, 1.0, 1.0, al))
			ci.draw_rect(Rect2(x0, PH - 2.0 - float(k) * 2.0, wd, 2.0), Color(1.0, 1.0, 1.0, al))
		ci.draw_rect(Rect2(x0 - 1.0, FLOOR_Y, 1.0, PH - FLOOR_Y), Color(BRASS_HI))
		ci.draw_rect(Rect2(x0 + wd, FLOOR_Y, 1.0, PH - FLOOR_Y), Color(BRASS_HI))
	var cl := closing(tm)
	if cl >= 0.0:                                        # the floor slides back from both sides
		var half := float((PIT_B - PIT_A + 1) * T) / 2.0 * cl
		ci.draw_rect(Rect2(float(PIT_A * T), FLOOR_Y, half, PH - FLOOR_Y), Color(BRASS))
		ci.draw_rect(Rect2(float((PIT_B + 1) * T) - half, FLOOR_Y, half, PH - FLOOR_Y), Color(BRASS))
