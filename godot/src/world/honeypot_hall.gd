class_name HoneypotHall
extends RefCounted
# HoneypotHall: the arena of N15, THE FIREWALL (docs/metroidvania/16-firewall-build.md, section 4). The room owns it, not the boss, so the lobby is
# still there before the fight and its burned shell after it. It owns the lobby floor, the furniture, the furnace walls, the stairs and a fist's
# top: their tiles follow the masks below, it draws them itself (RoomView skips them). The masks are state: the host's boss writes them, the
# guest's boss copy writes them from its net fields, and apply() turns them into tiles on each page.
# It also owns the packets: moving platforms that are a pure function of the room's clock and the fight's seed, so both pages agree without a message.

const T := 16
const FLOOR_ROW := 11                    # the lobby floor (the false floor)
const FURN_ROW := 25                     # the furnace floor
const FLOOR_Y := 176.0
const FURN_Y := 400.0
const C_MAX := 22                        # the last inner column
const SURF_E := 288.0                    # the body's face at its widest furnace (BODY_C0 = 18)
const BODY_C0_START := 18
const WEST_C1_START := 3

# furniture bits and their cells [first column, row, length]
const SOFA := [3, 9, 4]
const DESK := [9, 8, 3]
const SHELF := [13, 5, 4]
const PIECES := [SOFA, DESK, SHELF]

# stairs after the fight: [first column, last column, row], from the furnace floor up to the stubs
const STAIRS_E := [[14, 16, 22], [17, 19, 19], [19, 21, 16], [20, 22, 13]]
const STAIRS_W := [[7, 9, 22], [4, 6, 19], [2, 4, 16], [1, 3, 13]]

# packets: four lanes (the port numbers), each its own rhythm
const LANES := 4
const SLOTS := 4
const PK_W := 64.0
const PK_H := 6.0
const EVERY := [2.0, 2.4, 1.8, 2.2]
const OFFSET := [0.0, 0.7, 1.3, 0.4]
const SPEED := [100.0, 60.0, 80.0, 60.0]
const LANE_ROW := [23, 20, 17, 14]
const PORTS := ["22", "80", "443", "8080"]
const WARN_T := 0.6                      # a packet that is about to be dropped turns red this long before
const GAP_T := 1.0                       # no two drops within this long of each other
const DROP_P := 0.25
const NO_PK := -1000.0                   # `pk_t0` when no packets run (a real room time can be 0 or small, so -1 would not do)
const BITS_T := 1.2                      # how long a dropped packet's bricks fall

# the hot floor (the boss's `heat` hazards are mirrored into `heat`, column -> room time it was stepped on)
const HEAT_DIM := 1.4
const HEAT_LIVE := 2.0
const HEAT_COOL := 1.0

const INK := "#1b1226"
const GREEN := "#57ff8a"

var room
var stage := 0                           # 0 lobby (phase 1), 1 furnace (phase 2), 2 two walls (phase 3), 3 after
var floor_on := true
var furniture := 7                       # bit 0 sofa, 1 desk, 2 shelf
var body_c0 := 0                         # first column of the east body (18, 17, 16); 0 = none
var west_c1 := 0                         # last column of the west wall (3, 4, 5); 0 = none
var stairs := 0
var fist := Rect2()                      # a punch fist that stays out: a temporary one-way top
var burn_t0 := -1.0                      # room time the carpet started burning (cosmetic)
var pk_t0 := NO_PK                       # room time the packets started; NO_PK = none
var seed := 0
var green_t0 := -1.0
var pk_dir := 0                          # 0 all lanes east to west, 1 lanes 1 and 3 west to east
var dim := 0.0                           # 0..1: the fires go out (the boss derives it from its death clock, both pages)
var heat := {}                           # column -> room time (the hot floor)
var heat_burn := 1.2                     # how long a heated cell burns (1.6 in phase 3)
var pdrops := {}                         # lane * 1000000 + k -> room time a punch dropped that packet
var static_nodes: Array = []             # the nodes that draw the slowly changing things (redrawn only when the masks change)
var pool: Array = []                     # the packet dictionaries (also in room.plats)

var static_rev := 0                      # how many times the static drawing was asked to redraw (a test: it must not run every frame)
var _sig: Array = []
var _memo := {}
var _next := [0, 0, 0, 0]
var _acc: Array = []
var _memo_sig: Array = []
var _beeped := {}

func _init(r) -> void:
	room = r
	if Game.flag("boss:FIREWALL"):
		set_stage(3)
	for L in range(LANES):
		for s in range(SLOTS):
			var m := {"x": 0.0, "y": float(LANE_ROW[L] * T + 2), "w": PK_W, "h": PK_H, "dx": 0.0, "dy": 0.0, "fw": true, "lane": L, "k": -1, "off": true, "lost": false, "warn": false, "green": false, "td": 0.0}
			pool.append(m)
			room.plats.append(m)

static func wanted(def: Dictionary) -> bool:
	return String(def.get("hall", "")) == "honeypot"

# ---------------------------------------------------------------- the masks
# the stages as masks (the boss sets them one by one in a real fight; a test and the screenshots set them at once)
func set_stage(s: int) -> void:
	stage = s
	match s:
		0:
			floor_on = true
			furniture = 7
			body_c0 = 0
			west_c1 = 0
			stairs = 0
		1:
			floor_on = false
			furniture = 0
			body_c0 = BODY_C0_START
			west_c1 = 0
			stairs = 0
		2:
			floor_on = false
			furniture = 0
			body_c0 = BODY_C0_START
			west_c1 = WEST_C1_START
			stairs = 0
		_:
			floor_on = false
			furniture = 0
			body_c0 = 0
			west_c1 = 0
			stairs = 1
	fist = Rect2()
	heat = {}

func reset() -> void:
	set_stage(0)
	burn_t0 = -1.0
	pk_t0 = NO_PK
	seed = 0
	green_t0 = -1.0
	pk_dir = 0
	pdrops = {}
	_beeped = {}

# the camera: in the lobby (phase 1, and before the fight) the player must not see the furnace
func cam_lock():
	if stage == 0:
		return {"x": 0.0, "y": 0.0}
	return null

func _idx(tx: int, ty: int) -> int:
	return ty * room.grid.w + tx

# the cells this hall decides: the lobby floor, the furniture, and the whole furnace inside (walls, stairs, a fist's top)
func owns(tx: int, ty: int) -> bool:
	if tx >= 1 and tx <= C_MAX and ty >= FLOOR_ROW and ty < FURN_ROW:
		return true
	for p in PIECES:
		if ty == int(p[1]) and tx >= int(p[0]) and tx < int(p[0]) + int(p[2]):
			return true
	return false

func east_surface() -> float:
	return float(body_c0 * T) if body_c0 > 0 else float(room.pw - T)

func west_surface() -> float:
	return float((west_c1 + 1) * T) if west_c1 > 0 else float(T)

# the furnace inside, in pixels (the walls' faces)
func inner_x() -> Vector2:
	return Vector2(west_surface(), east_surface())

# the masks as tiles (every frame, both pages; only changed cells are written)
func apply() -> void:
	var s: Array = [stage, floor_on, furniture, body_c0, west_c1, stairs, fist]
	if s == _sig:
		return
	var redraw := _sig.is_empty() or s.slice(0, 6) != _sig.slice(0, 6)
	_sig = s
	var g = room.grid
	var want := {}                           # cell index -> tile (everything else owned is air)
	for tx in range(1, C_MAX + 1):           # the lobby floor: the middle goes with floor_on; the stubs stay, solid in the lobby and one-way after
		var stub: bool = tx <= 3 or tx >= 20
		if stub and (stage == 0 or stairs == 1):          # (the stubs burn with the floor and come back with the stairs: no safe ledge in the fight)
			want[_idx(tx, FLOOR_ROW)] = TileGrid.SOLID if stage == 0 else TileGrid.ONEWAY
		elif floor_on:
			want[_idx(tx, FLOOR_ROW)] = TileGrid.SOLID
	for pi in range(PIECES.size()):
		if (furniture >> pi) & 1 == 1:
			var p: Array = PIECES[pi]
			for k in range(int(p[2])):
				want[_idx(int(p[0]) + k, int(p[1]))] = TileGrid.ONEWAY
	if stairs == 1:
		for st in [STAIRS_E, STAIRS_W]:
			for step in st:
				for tx in range(int(step[0]), int(step[1]) + 1):
					want[_idx(tx, int(step[2]))] = TileGrid.ONEWAY
	if fist.size.x > 0.0:
		var fy: int = floori(fist.position.y / T)
		for tx in range(floori(fist.position.x / T), floori((fist.end.x - 0.01) / T) + 1):
			if tx >= 1 and tx <= C_MAX and fy >= FLOOR_ROW + 1 and fy < FURN_ROW:
				want[_idx(tx, fy)] = TileGrid.ONEWAY
	if body_c0 > 0:                          # solid beats everything else
		for ty in range(FLOOR_ROW + 1, FURN_ROW):
			for tx in range(body_c0, C_MAX + 1):
				want[_idx(tx, ty)] = TileGrid.SOLID
	if west_c1 > 0:
		for ty in range(FLOOR_ROW + 1, FURN_ROW):
			for tx in range(1, west_c1 + 1):
				want[_idx(tx, ty)] = TileGrid.SOLID
	for ty in range(FLOOR_ROW, FURN_ROW):
		for tx in range(1, C_MAX + 1):
			var i: int = _idx(tx, ty)
			var t: int = int(want.get(i, TileGrid.E))
			if g.tiles[i] != t:
				g.tiles[i] = t
	for pi in range(PIECES.size()):          # (the furniture cells are above the loop's rows)
		var p2: Array = PIECES[pi]
		for k in range(int(p2[2])):
			var i2: int = _idx(int(p2[0]) + k, int(p2[1]))
			var t2: int = int(want.get(i2, TileGrid.E))
			if g.tiles[i2] != t2:
				g.tiles[i2] = t2
	if redraw:
		_redraw_static()

func _redraw_static() -> void:
	static_rev += 1
	for n in static_nodes:
		if is_instance_valid(n):
			n.queue_redraw()

# every frame, both pages (the room's step; the packets move earlier, with the other platforms)
func step(_dt: float) -> void:
	apply()
	_push_out()

# a wall that steps in must not trap this page's own body in its bricks: it is pushed out of the new column (each page moves only its own player)
func _push_out() -> void:
	var p = room.player
	if p == null or p.dead or p.y + p.h <= float((FLOOR_ROW + 1) * T):
		return
	if body_c0 > 0 and p.x + p.w > float(body_c0 * T):
		p.x = float(body_c0 * T) - p.w
	if west_c1 > 0 and p.x < float((west_c1 + 1) * T):
		p.x = float((west_c1 + 1) * T)

# ---------------------------------------------------------------- packets (a pure function of room.time, pk_t0 and seed)
func lane_dir(lane: int) -> int:
	return 1 if (pk_dir == 1 and lane % 2 == 1) else -1

func _w_base() -> float:
	return 64.0 if pk_dir == 1 else 16.0

func travel_t(lane: int) -> float:
	return (SURF_E - _w_base() + PK_W) / float(SPEED[lane])

func spawn_t(lane: int, k: int) -> float:
	return pk_t0 + float(OFFSET[lane]) + float(k) * float(EVERY[lane])

# the left edge of packet (lane, k) `age` seconds after it spawned
func pos_x(lane: int, age: float) -> float:
	if lane_dir(lane) < 0:
		return SURF_E - float(SPEED[lane]) * age
	return _w_base() - PK_W + float(SPEED[lane]) * age

func _key(lane: int, k: int) -> int:
	return lane * 1000000 + k

# decide every packet in spawn order up to (lane, k): the memo is the same on both pages (same seed, same clock)
func _ensure(lane: int, k: int) -> void:
	var sig: Array = [seed, pk_t0, pk_dir, green_t0]
	if sig != _memo_sig:
		_memo_sig = sig
		_memo = {}
		_next = [0, 0, 0, 0]
		_acc = []
	var key: int = _key(lane, k)
	while not _memo.has(key):
		var bl := 0
		var bt := INF
		for l in range(LANES):
			var t: float = spawn_t(l, int(_next[l]))
			if t < bt:
				bt = t
				bl = l
		_decide(bl, int(_next[bl]))
		_next[bl] = int(_next[bl]) + 1

func _decide(lane: int, k: int) -> void:
	var u := Game.hash3(seed * 7 + lane, k, 41)
	var u2 := Game.hash3(seed * 7 + lane, k, 42)
	var ts: float = spawn_t(lane, k)
	var tt: float = travel_t(lane)
	var green: bool = green_t0 >= 0.0 and ts >= green_t0 and (k + lane) % 3 == 0
	var drop := false
	var f := 0.0
	if green:                                # a lie: it looks safe and always drops (it ignores the gap rule, but it counts for the others)
		drop = true
		f = 0.5 + 0.3 * u2
	elif u < DROP_P and not _dropped(lane, k - 1):
		f = 0.3 + 0.4 * u2
		drop = true
		var td0: float = ts + f * tt
		for a in _acc:
			if absf(float(a) - td0) < GAP_T:
				drop = false
				break
	var td: float = ts + f * tt
	if drop:
		_acc.append(td)
	_memo[_key(lane, k)] = {"drop": drop, "td": td, "green": green}

func _dropped(lane: int, k: int) -> bool:
	if k < 0:
		return false
	return bool(_memo.get(_key(lane, k), {}).get("drop", false))

# what packet (lane, k) is doing at `now`: {"x", "age", "drop", "td", "green", "warn", "lost"} (age > travel: gone)
func packet_info(lane: int, k: int, now: float) -> Dictionary:
	_ensure(lane, k)
	var d: Dictionary = _memo[_key(lane, k)]
	var age: float = now - spawn_t(lane, k)
	var td: float = float(d.td)
	var drop: bool = bool(d.drop)
	var pk: int = _key(lane, k)
	if pdrops.has(pk) and (not drop or float(pdrops[pk]) < td):
		drop = true
		td = float(pdrops[pk])
	return {"x": pos_x(lane, age), "age": age, "drop": drop, "td": td, "green": bool(d.green),
		"warn": drop and now >= td - WARN_T and now < td, "lost": drop and now >= td}

# called by the room right where it moves the other platforms
func move_packets() -> void:
	var now: float = room.time
	var wx: float = west_surface()
	var ex: float = east_surface()
	for L in range(LANES):
		var slots_used := {}
		if pk_t0 > NO_PK * 0.5 and stage != 3:
			var k_hi: int = floori((now - pk_t0 - float(OFFSET[L])) / float(EVERY[L]))
			for k in range(maxi(0, k_hi - SLOTS + 1), k_hi + 1):
				var age: float = now - spawn_t(L, k)
				if age < 0.0 or age > travel_t(L):
					continue
				slots_used[k % SLOTS] = k
		for s in range(SLOTS):
			var m: Dictionary = pool[L * SLOTS + s]
			if not slots_used.has(s):
				m["off"] = true
				m["lost"] = false
				m["warn"] = false
				m["k"] = -1
				m["dx"] = 0.0
				continue
			var k2: int = int(slots_used[s])
			var info := packet_info(L, k2, now)
			var was_off: bool = m.off or int(m.k) != k2
			var nx: float = float(info.x)
			m["dx"] = 0.0 if was_off else nx - float(m.x)
			m["x"] = nx
			m["k"] = k2
			m["green"] = info.green
			m["td"] = info.td
			m["warn"] = info.warn
			m["lost"] = info.lost
			m["off"] = nx >= ex or nx + PK_W <= wx
			if info.warn and not _beeped.has(_key(L, k2)):
				_beeped[_key(L, k2)] = true
				if room.mode != "guest" and room.is_local:
					Audio.local_sfx("fw_deny", 0.25)

# ---------------------------------------------------------------- drawing: shared pieces
func _bricks(ci: CanvasItem, r: Rect2, base: Color, mortar: Color, hi: Color, sd: int) -> void:
	ci.draw_rect(r, base)
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var h := minf(8.0, r.end.y - y)
		ci.draw_rect(Rect2(r.position.x, y + h - 1.0, r.size.x, 1.0), mortar)
		var off := 0.0 if row % 2 == 0 else 8.0
		var x := r.position.x + off
		while x < r.end.x:
			if x > r.position.x:
				ci.draw_rect(Rect2(x, y, 1.0, h), mortar)
			if Game.hash3(int(x / 16.0), row + int(y / 8.0), sd) < 0.28:
				ci.draw_rect(Rect2(x + 2.0, y + 1.0, minf(10.0, r.end.x - x - 2.0), 1.0), hi)
			x += 16.0
		y += 8.0
		row += 1

# --- the lobby's back wall: warm and a bit too clean for the NETWORK (drawn once)
func _lobby_wall(ci: CanvasItem, burned: bool) -> void:
	var xx := 16.0
	if burned:                                                                  # the wallpaper hangs in ragged strips over the bricks
		while xx < 368.0:
			if Game.hash3(int(xx), 5, 78) >= 0.35:
				var h := 10.0 + Game.hash3(int(xx), 3, 77) * 60.0
				ci.draw_rect(Rect2(xx, 16.0, 16.0, h), Color("#d8c9a6"))
				ci.draw_rect(Rect2(xx, 16.0 + h, 16.0, 3.0), Color("#3a2a1c"))
				ci.draw_rect(Rect2(xx, 16.0, 1.0, h), Color("#c4b48e"))
			xx += 16.0
	else:
		ci.draw_rect(Rect2(16.0, 16.0, 352.0, 160.0), Color("#efe2c6"))
		while xx < 368.0:
			ci.draw_rect(Rect2(xx, 20.0, 1.0, 112.0), Color("#e6d6b4"))
			xx += 16.0
		ci.draw_rect(Rect2(16.0, 16.0, 352.0, 4.0), Color("#cdb68a"))              # cornice
		ci.draw_rect(Rect2(16.0, 20.0, 352.0, 1.0), Color("#b99d6e"))
		ci.draw_rect(Rect2(16.0, 138.0, 352.0, 38.0), Color("#8c6b49"))            # wainscot
		xx = 20.0
		while xx < 360.0:
			ci.draw_rect(Rect2(xx, 144.0, 20.0, 24.0), Color("#7a5b3c"))
			ci.draw_rect(Rect2(xx + 1.0, 145.0, 18.0, 1.0), Color("#a07d58"))
			xx += 26.0
		ci.draw_rect(Rect2(16.0, 134.0, 352.0, 4.0), Color("#c9a878"))             # the dado rail
		ci.draw_rect(Rect2(16.0, 172.0, 352.0, 4.0), Color("#5b4430"))             # skirting
	# the window: a sunny sky that is not there
	var wr := Rect2(88.0, 32.0, 84.0, 52.0)
	ci.draw_rect(Rect2(wr.position.x - 3.0, wr.position.y - 3.0, wr.size.x + 6.0, wr.size.y + 6.0), Color("#7a5a3a"))
	ci.draw_rect(wr, Color("#8fd0ff"))
	ci.draw_rect(Rect2(wr.position.x, wr.position.y + 26.0, wr.size.x, 26.0), Color("#bfe6ff"))
	ci.draw_circle(Vector2(wr.position.x + 62.0, wr.position.y + 15.0), 7.0, Color("#ffd84a"))
	ci.draw_rect(Rect2(wr.position.x + 10.0, wr.position.y + 22.0, 22.0, 6.0), Color("#ffffff"))
	ci.draw_rect(Rect2(wr.position.x + 16.0, wr.position.y + 18.0, 14.0, 6.0), Color("#ffffff"))
	ci.draw_rect(Rect2(wr.position.x + wr.size.x / 2.0 - 1.0, wr.position.y, 2.0, wr.size.y), Color("#7a5a3a"))
	ci.draw_rect(Rect2(wr.position.x, wr.position.y + 25.0, wr.size.x, 2.0), Color("#7a5a3a"))
	ci.draw_rect(Rect2(wr.position.x - 5.0, wr.position.y + wr.size.y + 3.0, wr.size.x + 10.0, 3.0), Color("#6a4c30"))     # the sill
	if burned:
		var cr := Color("#3a3028")
		ci.draw_line(Vector2(wr.position.x + 30.0, wr.position.y), Vector2(wr.position.x + 44.0, wr.position.y + 22.0), cr, 1.0)
		ci.draw_line(Vector2(wr.position.x + 44.0, wr.position.y + 22.0), Vector2(wr.position.x + 36.0, wr.position.y + 36.0), cr, 1.0)
		ci.draw_line(Vector2(wr.position.x + 44.0, wr.position.y + 22.0), Vector2(wr.position.x + 64.0, wr.position.y + 34.0), cr, 1.0)
		ci.draw_line(Vector2(wr.position.x + 36.0, wr.position.y + 36.0), Vector2(wr.position.x + 40.0, wr.position.y + 52.0), cr, 1.0)
		return
	# the sign
	var txt := "Welcome! Free Wi-Fi"
	var tw: int = PixelText.text_width(txt)
	var sx := 252.0 - float(tw) / 2.0 - 6.0
	ci.draw_rect(Rect2(sx - 1.0, 30.0, tw + 14.0, 18.0), Color("#0e2a1c"))
	ci.draw_rect(Rect2(sx, 31.0, tw + 12.0, 16.0), Color("#143a26"))
	PixelText.draw_text(ci, txt, 252.0, 35.0, GREEN, {"align": "c"})
	# lamps (their light is in the glow layer): one on the sofa's table, one on the reception desk
	for lx in [124.0, 152.0]:
		var ly := 156.0 if lx < 140.0 else 128.0
		ci.draw_rect(Rect2(lx - 1.0, ly - 12.0, 2.0, 12.0), Color("#6a4c30"))
		ci.draw_rect(Rect2(lx - 5.0, ly - 1.0, 10.0, 2.0), Color("#6a4c30"))
		ci.draw_rect(Rect2(lx - 5.0, ly - 19.0, 10.0, 8.0), Color("#f4d58a"))
		ci.draw_rect(Rect2(lx - 4.0, ly - 19.0, 8.0, 2.0), Color("#fff1c4"))
	ci.draw_rect(Rect2(116.0, 156.0, 16.0, 16.0), Color("#6a4c30"))             # the little table
	ci.draw_rect(Rect2(116.0, 156.0, 16.0, 2.0), Color("#8c6b49"))

# --- the furnace: dark brick with orange cracks (drawn once)
func _brick_room(ci: CanvasItem, y0: float, y1: float) -> void:
	_bricks(ci, Rect2(16.0, y0, 352.0, y1 - y0), Color("#241617"), Color("#150c0d"), Color("#33201f"), 11)
	var n := 0
	var y := y0 + 6.0
	while y < y1 - 6.0:
		var x := 16.0 + Game.hash3(n, 1, 21) * 40.0
		while x < 360.0:
			if Game.hash3(int(x), int(y), 22) < 0.12:
				var l := 6.0 + Game.hash3(int(x), int(y), 23) * 10.0
				ci.draw_line(Vector2(x, y), Vector2(x + l * 0.5, y + 3.0), Color("#7a3414"), 1.0)
				ci.draw_line(Vector2(x + l * 0.5, y + 3.0), Vector2(x + l, y + 1.0), Color("#7a3414"), 1.0)
			x += 22.0
		y += 22.0
		n += 1

# the back wall, drawn once per stage (RoomView adds it behind everything)
func draw_wall(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, float(room.pw), float(room.ph)), Color("#0b0809"))
	if stage == 0:
		_lobby_wall(ci, false)
		ci.draw_rect(Rect2(16.0, 176.0, 352.0, 224.0), Color("#120d0e"))        # the foundation under the lobby floor, so a free camera never shows an empty pit
		_bricks(ci, Rect2(16.0, 192.0, 352.0, 208.0), Color("#1a1213"), Color("#100a0b"), Color("#241819"), 5)
	elif stage == 3:
		_brick_room(ci, 16.0, 400.0)
		_lobby_wall(ci, true)
		_burned_floor_edges(ci)
	else:
		_brick_room(ci, 16.0, 400.0)

func _burned_floor_edges(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(16.0, 168.0, 352.0, 8.0), Color(0.05, 0.03, 0.03, 0.55))

# the solid things that change rarely: lobby floor and furniture, the bodies' bricks, the stairs (drawn when a mask changes)
func draw_static(ci: CanvasItem) -> void:
	var carpet := Color("#a33a3a")
	if floor_on:
		ci.draw_rect(Rect2(16.0, FLOOR_Y, 352.0, 16.0), Color("#2a1a14"))
		ci.draw_rect(Rect2(16.0, FLOOR_Y, 352.0, 8.0), carpet)
		ci.draw_rect(Rect2(16.0, FLOOR_Y, 352.0, 2.0), Color("#fff2b8"))              # the gold trim is the floor's bright cap
		ci.draw_rect(Rect2(16.0, FLOOR_Y + 6.0, 352.0, 1.0), Color("#d6a64a"))
		var xx := 20.0
		while xx < 366.0:
			ci.draw_rect(Rect2(xx, FLOOR_Y + 3.0, 6.0, 2.0), Color("#c24b4b"))
			xx += 22.0
	elif stairs == 1:
		for stub in [[16.0, 48.0], [320.0, 48.0]]:                          # the stubs keep their charred carpet
			var sx: float = stub[0]
			ci.draw_rect(Rect2(sx, FLOOR_Y, stub[1], 14.0), Color("#1d1210"))
			ci.draw_rect(Rect2(sx, FLOOR_Y, stub[1], 4.0), Color("#3a2a24"))
			ci.draw_rect(Rect2(sx, FLOOR_Y, stub[1], 1.0), Color("#6a4630"))
	for pi in range(PIECES.size()):
		if (furniture >> pi) & 1 == 1:
			_piece(ci, pi)
	if body_c0 > 0:
		_wall_body(ci, body_c0 * T, 368, true)
	if west_c1 > 0:
		_wall_body(ci, 16, (west_c1 + 1) * T, false)
	if stairs == 1:
		for st in [STAIRS_E, STAIRS_W]:
			for step in st:
				var r := Rect2(float(step[0]) * T, float(step[2]) * T, float(int(step[1]) - int(step[0]) + 1) * T, 9.0)
				_bricks(ci, r, Color("#4a3030"), Color("#1c1010"), Color("#6a4240"), 31 + int(step[2]))
				ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), Color("#8a5a48"))

func _piece(ci: CanvasItem, pi: int) -> void:
	var p: Array = PIECES[pi]
	var x := float(int(p[0]) * T)
	var y := float(int(p[1]) * T)
	var w := float(int(p[2]) * T)
	if pi == 0:                                    # the sofa: seat at the one-way top, a back above, two arms, a plinth to the floor
		ci.draw_rect(Rect2(x, y - 14.0, w, 16.0), Color("#7d3b4a"))
		ci.draw_rect(Rect2(x + 2.0, y - 12.0, w - 4.0, 4.0), Color("#9a4e5e"))
		ci.draw_rect(Rect2(x - 4.0, y - 8.0, 6.0, 26.0), Color("#6a2f3d"))
		ci.draw_rect(Rect2(x + w - 2.0, y - 8.0, 6.0, 26.0), Color("#6a2f3d"))
		ci.draw_rect(Rect2(x, y, w, 7.0), Color("#a85a6a"))
		ci.draw_rect(Rect2(x, y, w, 1.0), Color("#c8788a"))
		ci.draw_rect(Rect2(x + w / 2.0, y + 1.0, 1.0, 6.0), Color("#7d3b4a"))
		ci.draw_rect(Rect2(x, y + 7.0, w, 12.0), Color("#5a2431"))
		ci.draw_rect(Rect2(x + 3.0, y + 19.0, 4.0, 3.0), Color("#3a2a20"))
		ci.draw_rect(Rect2(x + w - 7.0, y + 19.0, 4.0, 3.0), Color("#3a2a20"))
	elif pi == 1:                                  # the reception desk: its top is the one-way, its front goes to the floor
		ci.draw_rect(Rect2(x - 2.0, y, w + 4.0, 4.0), Color("#c9a878"))
		ci.draw_rect(Rect2(x - 2.0, y, w + 4.0, 1.0), Color("#e2c898"))
		ci.draw_rect(Rect2(x, y + 4.0, w, 44.0), Color("#8c6b49"))
		ci.draw_rect(Rect2(x + 3.0, y + 8.0, w - 6.0, 36.0), Color("#7a5b3c"))
		ci.draw_rect(Rect2(x + 3.0, y + 8.0, w - 6.0, 1.0), Color("#a07d58"))
		PixelText.draw_text(ci, "INFO", x + w / 2.0, y + 22.0, "#e2c898", {"align": "c", "tiny": true})
		ci.draw_rect(Rect2(x + w - 22.0, y - 6.0, 14.0, 6.0), Color("#d9d2c0"))      # the tray the cookies come from
		ci.draw_rect(Rect2(x + w - 22.0, y - 6.0, 14.0, 1.0), Color("#f2ecd8"))
	else:                                          # the shelf: a plank on two brackets, with a router and two plants
		ci.draw_rect(Rect2(x, y, w, 4.0), Color("#8c6b49"))
		ci.draw_rect(Rect2(x, y, w, 1.0), Color("#c9a878"))
		ci.draw_rect(Rect2(x + 4.0, y + 4.0, 3.0, 8.0), Color("#6a4c30"))
		ci.draw_rect(Rect2(x + w - 7.0, y + 4.0, 3.0, 8.0), Color("#6a4c30"))
		ci.draw_rect(Rect2(x + 6.0, y - 7.0, 18.0, 7.0), Color("#e8e8e8"))          # the router
		ci.draw_rect(Rect2(x + 6.0, y - 7.0, 18.0, 1.0), Color("#ffffff"))
		ci.draw_rect(Rect2(x + 9.0, y - 11.0, 1.0, 4.0), Color("#e8e8e8"))
		ci.draw_rect(Rect2(x + 20.0, y - 11.0, 1.0, 4.0), Color("#e8e8e8"))
		ci.draw_rect(Rect2(x + 8.0, y - 5.0, 2.0, 2.0), Color(GREEN))
		ci.draw_rect(Rect2(x + 40.0, y - 6.0, 8.0, 6.0), Color("#a8643a"))           # a pot and its plant
		ci.draw_rect(Rect2(x + 42.0, y - 12.0, 4.0, 6.0), Color("#3f9a52"))
		ci.draw_rect(Rect2(x + 38.0, y - 10.0, 3.0, 4.0), Color("#3f9a52"))

# a furnace wall: bricks, a lighter face edge, and the port holes the packets come out of
func _wall_body(ci: CanvasItem, x0: int, x1: int, east: bool) -> void:
	var r := Rect2(float(x0), float((FLOOR_ROW + 1) * T), float(x1 - x0), float((FURN_ROW - FLOOR_ROW - 1) * T))
	_bricks(ci, r, Color("#5e3428"), Color("#2a1512"), Color("#92563c"), 51 if east else 52)
	var fx: float = r.position.x if east else r.end.x - 2.0
	ci.draw_rect(Rect2(fx, r.position.y, 2.0, r.size.y), Color("#c4601e"))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), Color("#ffc890"))         # a lit top edge (a cap, like every other floor)
	for L in range(LANES):
		var has_hole: bool = (east and (pk_dir == 0 or L % 2 == 0)) or (not east and pk_dir == 1 and L % 2 == 1)
		if not has_hole:
			continue
		var hy: float = float(LANE_ROW[L] * T) - 3.0
		var hx: float = r.position.x if east else r.end.x - 14.0
		ci.draw_rect(Rect2(hx, hy, 14.0, 14.0), Color("#0d0606"))
		ci.draw_rect(Rect2(hx, hy, 14.0, 1.0), Color("#c4601e"))
		ci.draw_rect(Rect2(hx, hy + 13.0, 14.0, 1.0), Color("#c4601e"))
		var lbl: String = PORTS[L]
		var lx: float = hx + 22.0 if east else hx - 8.0
		PixelText.draw_text(ci, lbl, lx + 4.0 if east else lx - float(PixelText.text_width(lbl, {"tiny": true})), hy + 4.0, "#e8a060", {"tiny": true})

# ---------------------------------------------------------------- drawing: every frame
# shaded: what the room's lights darken (packets, a fist, the carpet burning)
func draw_shaded(ci: CanvasItem) -> void:
	var now: float = room.time
	if stage == 0 and burn_t0 >= 0.0 and floor_on and now >= burn_t0:
		_draw_carpet_burn(ci, now)
	var wx: float = west_surface()
	var ex: float = east_surface()
	for m in pool:
		if m.off and not (m.lost and int(m.k) >= 0):
			continue
		_draw_packet(ci, m, now, wx, ex)
	if fist.size.x > 0.0:
		_bricks(ci, fist, Color("#5a3228"), Color("#241210"), Color("#8a4a32"), 61)
		ci.draw_rect(Rect2(fist.position.x, fist.position.y, fist.size.x, 1.0), Color("#c8703a"))

func _draw_packet(ci: CanvasItem, m: Dictionary, now: float, wx: float, ex: float) -> void:
	var L: int = int(m.lane)
	var x: float = float(m.x)
	var y: float = float(m.y) - 1.0
	if m.lost:                                         # dropped: no floor, a few bricks fall from where it let go
		var since: float = now - float(m.td)
		if since > BITS_T or since < 0.0:
			return
		var dir: int = lane_dir(L)
		var cx: float = pos_x(L, float(m.td) - spawn_t(L, int(m.k)))
		for b in range(6):
			var bx: float = cx + 6.0 + float(b) * 9.0 - 2.0 + (Game.hash3(int(m.k), b, 91) - 0.5) * 10.0 * since
			var by: float = y + 80.0 * since * since * (0.6 + Game.hash3(int(m.k), b, 92)) + since * 6.0
			ci.draw_rect(Rect2(bx, by, 5.0, 4.0), Color("#8a4a32"))
			ci.draw_rect(Rect2(bx, by, 5.0, 1.0), Color("#c8703a"))
		return
	var x0: float = maxf(x, wx)                        # clipped by the wall faces (the packet comes out of a port and goes into the bricks)
	var x1: float = minf(x + PK_W, ex)
	if x1 <= x0:
		return
	var body := Color("#2a8f86")
	var top := Color("#58f0c8")
	var front := Color("#e8fff9")
	if m.green:
		body = Color("#2e9a52")
		top = Color(GREEN)
		front = Color("#e8ffee")
	if m.warn:                                         # about to be dropped: red, blinking
		if int(now * 10.0) % 2 == 0:
			body = Color("#c0392b")
			top = Color("#ff7a6a")
			front = Color("#ffd0c8")
		else:
			body = Color("#7a2a22")
			top = Color("#c0392b")
			front = Color("#ff9a8a")
	ci.draw_rect(Rect2(x0 - 1.0, y - 1.0, x1 - x0 + 2.0, 8.0), Color(INK))
	ci.draw_rect(Rect2(x0, y, x1 - x0, 6.0), body)
	ci.draw_rect(Rect2(x0, y, x1 - x0, 2.0), top)
	var lead_x: float = x if lane_dir(L) < 0 else x + PK_W - 4.0     # the bright edge is the front
	var fx0: float = maxf(lead_x, x0)
	var fx1: float = minf(lead_x + 4.0, x1)
	if fx1 > fx0:
		ci.draw_rect(Rect2(fx0, y, fx1 - fx0, 6.0), front)
	var lbl: String = PORTS[L]
	var lw: int = PixelText.text_width(lbl, {"tiny": true})
	var tx: float = x + PK_W / 2.0 - float(lw) / 2.0
	if tx >= x0 and tx + float(lw) <= x1:
		PixelText.draw_text(ci, lbl, tx, y - 7.0, "#ffd0c8" if m.warn else "#9ff0dc", {"tiny": true})

func _draw_carpet_burn(ci: CanvasItem, now: float) -> void:
	var p: float = clampf((now - burn_t0) / 1.4, 0.0, 1.0)
	var half: float = p * 176.0
	var cx := 192.0
	ci.draw_rect(Rect2(cx - half, FLOOR_Y, half * 2.0, 6.0), Color("#1a0f0d"))
	for side in [-1.0, 1.0]:                           # flames on the burning edges
		var ex2: float = cx + side * half
		for k in range(5):
			var fh: float = 5.0 + 6.0 * (0.5 + 0.5 * sin(now * 18.0 + float(k) * 2.3 + side))
			var fxp: float = ex2 - side * float(k) * 3.0
			ci.draw_rect(Rect2(fxp - 1.0, FLOOR_Y - fh, 3.0, fh), Color("#ff8a2a"))
			ci.draw_rect(Rect2(fxp, FLOOR_Y - fh * 0.6, 1.0, fh * 0.6), Color("#ffd84a"))

# glow: what gives light (the hot floor, the grates, the lamps' pools)
func draw_glow(ci: CanvasItem) -> void:
	var now: float = room.time
	if stage == 0:
		ci.draw_rect(Rect2(112.0, 40.0, 64.0, 36.0), Color(1.0, 0.95, 0.7, 0.07))     # the window's light
		return
	var wx: float = west_surface()
	var ex: float = east_surface()
	var x := wx
	while x < ex - 2.0:                                # the furnace floor's grates
		var pulse: float = 0.5 + 0.5 * sin(now * 2.0 + x * 0.05)
		ci.draw_rect(Rect2(x + 3.0, FURN_Y + 3.0, 10.0, 2.0), Color(1.0, 0.45 + 0.2 * pulse, 0.1, (0.55 + 0.25 * pulse) * (1.0 - dim)))
		x += 16.0
	for c in heat.keys():
		var age: float = now - float(heat[c])
		var cx: float = float(int(c) * T)
		match heat_phase(age, heat_burn):
			"dim":                                    # the build-up: dim orange
				ci.draw_rect(Rect2(cx, FURN_Y - 2.0, 16.0, 2.0), Color(1.0, 0.45, 0.1, 0.25 + 0.3 * age / HEAT_DIM))
			"warn":                                   # the warning: bright orange-white
				var k: float = (age - HEAT_DIM) / (HEAT_LIVE - HEAT_DIM)
				ci.draw_rect(Rect2(cx, FURN_Y - 3.0, 16.0, 3.0), Color(1.0, 0.7 + 0.25 * k, 0.35 + 0.4 * k, 0.8))
			"live":                                   # burning: flames up to the harm box's top
				ci.draw_rect(Rect2(cx, FURN_Y - 10.0, 16.0, 10.0), Color(1.0, 0.45, 0.1, 0.55))
				for f in range(4):
					var fh: float = 6.0 + 6.0 * (0.5 + 0.5 * sin(now * 16.0 + float(f) * 1.7 + float(c)))
					ci.draw_rect(Rect2(cx + 1.0 + float(f) * 4.0, FURN_Y - 10.0 - fh * 0.5, 3.0, fh), Color(1.0, 0.8, 0.3, 0.9))
			"cool":                                   # cooling: dark red
				ci.draw_rect(Rect2(cx, FURN_Y - 2.0, 16.0, 2.0), Color(0.5, 0.1, 0.08, 0.7))

# what a stepped-on floor cell is doing `age` seconds after it was stepped on (the boss's `heat` hazard follows the same clock)
static func heat_phase(age: float, burn: float) -> String:
	if age < 0.0:
		return ""
	if age < HEAT_DIM:
		return "dim"
	if age < HEAT_LIVE:
		return "warn"
	if age < HEAT_LIVE + burn:
		return "live"
	if age < HEAT_LIVE + burn + HEAT_COOL:
		return "cool"
	return ""
