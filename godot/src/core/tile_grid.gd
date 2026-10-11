class_name TileGrid
extends RefCounted
# TileGrid: tiles and collision, a line-by-line port of the tile functions in `class Level` (js/level.js).
# Entities are any object with x, y, w, h (top-left of the hitbox); move_x / move_y change x / y exactly like the JS.

const E := 0
const SOLID := 1
const ONEWAY := 2
const SPIKE_U := 3
const SPIKE_D := 4
const CRACK := 5
const CRUMBLE := 6
const BLINK_A := 7
const BLINK_B := 8
const LIQ := 9
const GATE_C := 10         # `!`: solid until the room's catch switches are all pressed
const GATE_A := 11         # `&`: solid until the room's slot keys are all pressed (3B)
const DEAD := 12           # `;`: dead code: looks like wall, walked through; revealed for good once touched
const FIRE := 13           # `N`: firewall brick: solid (ssh passes it in 4B)
const THICK := 14          # `0`: bulkhead: solid; only Room.blast breaks it
const T := 16

const CHARS := {"#": SOLID, "=": ONEWAY, "^": SPIKE_U, "v": SPIKE_D, "%": CRACK, "~": CRUMBLE, "1": BLINK_A, "2": BLINK_B, "w": LIQ, "!": GATE_C, "&": GATE_A, ";": DEAD, "N": FIRE, "0": THICK}

var w := 0
var h := 0
var tiles := PackedByteArray()
var crumble := {}          # index -> {s, t}
var blink_hold := {}       # index -> true
var blink_phase := 0
var gates_open := {"catch": false, "agents": false}        # the room sets them from its flags every step
var doors: Array = []      # {side: "W"|"E"|"N"|"S", a, b, open}: rows (W/E) or columns (N/S) a..b of the edge are walkable while open

func tile(tx: int, ty: int) -> int:
	if ty < 0:
		for d in doors:
			if d.side == "N" and tx >= d.a and tx <= d.b:
				return E if d.open else SOLID
		return SOLID
	if tx < 0 or tx >= w:
		if ty < h:
			var want := "W" if tx < 0 else "E"
			for d in doors:
				if d.side == want and d.open and ty >= d.a and ty <= d.b:
					return E
		return SOLID
	if ty >= h:
		for d in doors:
			if d.side == "S" and tx >= d.a and tx <= d.b:
				return E if d.open else SOLID
		return E
	return tiles[ty * w + tx]

# the open door whose rows cover ty on the given side ("" = none)
func door_at(side: String, ty: int):
	for d in doors:
		if d.side == side and ty >= d.a and ty <= d.b:
			return d
	return null

func solid(tx: int, ty: int) -> bool:
	var t := tile(tx, ty)
	if t == SOLID or t == CRACK or t == FIRE or t == THICK:
		return true
	if t == DEAD:
		return false
	if t == GATE_C:
		return not gates_open.catch
	if t == GATE_A:
		return not gates_open.agents
	if t < CRUMBLE or t == LIQ:
		return false
	var i := ty * w + tx
	if t == CRUMBLE:
		var c = crumble.get(i)
		return c == null or c.s != 2
	if blink_hold.has(i):
		return false
	return blink_phase == 0 if t == BLINK_A else blink_phase == 1

func solid_at(px: float, py: float) -> bool:
	return solid(floori(px / T), floori(py / T))

func box_hits_solid(x: float, y: float, bw: float, bh: float) -> bool:
	var x0 := floori(x / T)
	var x1 := floori((x + bw - 0.001) / T)
	var y0 := floori(y / T)
	var y1 := floori((y + bh - 0.001) / T)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if solid(tx, ty):
				return true
	return false

# returns 0, 1 (blocked going right) or -1 (blocked going left)
func move_x(e, dx: float) -> int:
	e.x += dx
	if dx == 0.0:
		return 0
	var y0 := floori(e.y / T)
	var y1 := floori((e.y + e.h - 0.001) / T)
	if dx > 0.0:
		var tx := floori((e.x + e.w - 0.001) / T)
		for ty in range(y0, y1 + 1):
			if solid(tx, ty):
				e.x = tx * T - e.w
				return 1
	else:
		var tx2 := floori(e.x / T)
		for ty in range(y0, y1 + 1):
			if solid(tx2, ty):
				e.x = (tx2 + 1) * T
				return -1
	return 0

# returns 0, 1 (landed) or -1 (hit a ceiling)
func move_y(e, dy: float, no_oneway := false) -> int:
	var prev_bottom: float = e.y + e.h
	e.y += dy
	if dy == 0.0:
		return 0
	var x0 := floori(e.x / T)
	var x1 := floori((e.x + e.w - 0.001) / T)
	if dy > 0.0:
		var ty := floori((e.y + e.h - 0.001) / T)
		for tx in range(x0, x1 + 1):
			if solid(tx, ty) or ((not no_oneway) and tile(tx, ty) == ONEWAY and prev_bottom <= ty * T + 0.01):
				e.y = ty * T - e.h
				return 1
	else:
		var ty2 := floori(e.y / T)
		for tx in range(x0, x1 + 1):
			if solid(tx, ty2):
				e.y = (ty2 + 1) * T
				return -1
	return 0

# is there floor right under this box?
func grounded(e) -> bool:
	var ty := floori((e.y + e.h + 1) / T)
	var x0 := floori(e.x / T)
	var x1 := floori((e.x + e.w - 0.001) / T)
	for tx in range(x0, x1 + 1):
		var t := tile(tx, ty)
		if solid(tx, ty) or (t == ONEWAY and e.y + e.h <= ty * T + 0.5):
			return true
	return false

# plats: the room's moving platforms (dictionaries with x y w h dx dy)
func plat_under(e, prev_bottom: float, plats: Array):
	for p in plats:
		if e.x + e.w > p.x and e.x < p.x + p.w and prev_bottom <= p.y + 2 + absf(p.dy) and e.y + e.h >= p.y:
			return p
	return null

# turns a CRACK tile into air; the room does the effects and queues the neighbours
func break_tile(tx: int, ty: int) -> bool:
	if tile(tx, ty) != CRACK:
		return false
	tiles[ty * w + tx] = E
	return true

# nearest dry place to stand (used when the last safe spot is gone)
func find_safe(x: float, y: float, liquid_y = null):
	var best = null
	var bd := 1e9
	for ty in range(1, h):
		for tx in range(1, w - 1):
			var t := tiles[ty * w + tx]
			if (t != SOLID and t != ONEWAY) or tiles[(ty - 1) * w + tx] != E:
				continue
			if liquid_y != null and ty * T > liquid_y - 12:
				continue
			var d := absf(tx * T + 8 - x) + absf(ty * T - y) * 1.5
			if d < bd:
				bd = d
				best = {"x": tx * T + 3, "y": ty * T - 10}
	return best

func any_on(players: Array, tx: int, ty: int) -> bool:
	for q in players:
		if q.x < tx * T + T and q.x + q.w > tx * T and q.y < ty * T + T and q.y + q.h > ty * T:
			return true
	return false
