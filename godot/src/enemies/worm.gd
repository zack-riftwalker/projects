class_name Worm
extends EnemySM
# WORM (`W`): lives inside a firewall brick (the cell is `FIRE`) and crawls along its group of bricks. It teaches that bricks can be passed:
# when somebody stands at the brick face it hisses, puts its head out for a bite, and goes back in. Inside the bricks nothing can touch it.

const STATES := ["crawl", "tell", "out", "back"]
const STEP_T := 0.4              # one cell per 0.4 s (MVB3-04), toward the closest player
const MAX_PER_GROUP := 3         # worms + eggs in one firewall group
const EGG_T := 5.0

var cells: Array = []             # the 4-connected firewall group (lazily found)
var ci := 0                       # which cell it is in
var dir := 1
var side := 1.0                   # the face the head sticks out of (-1 / 1)
var step_t := STEP_T
var hurt_out := false            # it was hit while its head was out (a bite that ends unhurt lays an egg)

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 16, 16)
	x = px
	y = py
	hp = 3
	loot = 2
	col = "#ff4f6d"
	stompable = false
	dashable = false
	no_agent = true
	state = "crawl"

func _find_group() -> void:
	var g := room.grid
	var start := Vector2i(floori((x + 8.0) / 16.0), floori((y + 8.0) / 16.0))
	var seen := {start: true}
	var stack := [start]
	cells = []
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		cells.append(c)
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if not seen.has(n) and g.tile(n.x, n.y) == TileGrid.FIRE:
				seen[n] = true
				stack.append(n)
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	ci = maxi(0, cells.find(start))

func _cell_px(i: int) -> Vector2:
	var c: Vector2i = cells[clampi(i, 0, cells.size() - 1)]
	return Vector2(c.x * 16.0, c.y * 16.0)

# x of the group's face on a side
func face_x(s: float) -> float:
	var best := -1e9 if s > 0.0 else 1e9
	for c in cells:
		best = maxf(best, c.x * 16.0 + 16.0) if s > 0.0 else minf(best, c.x * 16.0)
	return best

func update(dt: float) -> void:
	tick(dt)
	if cells.is_empty():
		_find_group()
	state_t -= dt
	match state:
		"crawl":
			step_t -= dt
			if step_t <= 0.0:
				step_t = STEP_T
				ci = _next_cell()
			var cp := _cell_px(ci)
			x = cp.x
			y = cp.y
			for q in room.players():
				var fx_l := face_x(-1.0)
				var fx_r := face_x(1.0)
				var qcx: float = q.x + 5.0
				var qcy: float = q.y + 5.0
				var near_l: bool = qcx < fx_l and fx_l - qcx <= 28.0
				var near_r: bool = qcx > fx_r and qcx - fx_r <= 28.0
				if (near_l or near_r) and absf(qcy - (y + 8.0)) <= 16.0:
					side = 1.0 if near_r else -1.0
					set_state("tell", 0.6 * float(Game.dv("telegraph_mult")))
					Audio.sfx("warn", {"vol": 0.4})
					break
		"tell":
			if state_t <= 0.0:
				hurt_out = false
				set_state("out", 0.35)
		"out":
			if state_t <= 0.0:
				if not hurt_out:
					_lay_egg()
				set_state("back", 0.4)
		"back":
			if state_t <= 0.0:
				set_state("crawl")

# one step toward the group's cell nearest to the closest player: a breadth-first path over the 4-connected cells (it stays put when it is there)
func _next_cell() -> int:
	var tp := to_player()
	if tp.p == null or cells.size() < 2:
		return ci
	var pc := Vector2(tp.p.x + 5.0, tp.p.y + 5.0)
	var goal := ci
	var bd := 1e18
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		var d := Vector2(c.x * 16.0 + 8.0, c.y * 16.0 + 8.0).distance_squared_to(pc)
		if d < bd - 0.01:
			bd = d
			goal = i
	if goal == ci:
		return ci
	var prev := {ci: -1}
	var queue := [ci]
	var found := false
	while not queue.is_empty() and not found:
		var cur: int = queue.pop_front()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni := cells.find((cells[cur] as Vector2i) + o)
			if ni >= 0 and not prev.has(ni):
				prev[ni] = cur
				if ni == goal:
					found = true
					break
				queue.append(ni)
	if not found:
		return ci
	var step := goal
	while int(prev[step]) != ci:
		step = int(prev[step])
	return step

func group_key() -> Vector2i:
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)

# the group's worms and eggs in this room
func _group_count() -> int:
	var n := 0
	for e in room.ents:
		if e.dead:
			continue
		if (e is Worm and e.group_key() == group_key()) or (e is WormEgg and e.group == group_key()):
			n += 1
	return n

# a bite that ends without the worm being hit: an egg in a free cell of its group (a pulsing brick); 5 s later it is a worm
func _lay_egg() -> void:
	if puppet or cells.is_empty() or _group_count() >= MAX_PER_GROUP:
		return
	var taken := {}
	for e in room.ents:
		if e.dead:
			continue
		if e is Worm and e.group_key() == group_key():
			taken[(cells[e.ci] as Vector2i)] = true
		elif e is WormEgg and e.group == group_key():
			taken[e.cell] = true
	var free: Array = cells.filter(func(c): return not taken.has(c))
	if free.is_empty():
		return
	var c: Vector2i = free[room.rng.randi() % free.size()]
	var egg := WormEgg.new(room, c.x * 16, c.y * 16)
	egg.cell = c
	egg.group = group_key()
	room.add_entity(egg)
	room.pop(c.x * 16 + 8.0, c.y * 16.0 - 2.0, "egg", "#ffb0c0")

func on_hurt(_how: String) -> void:
	if state == "out":
		hurt_out = true

func _head() -> Dictionary:
	var fx_ := face_x(side)
	return {"x": fx_ + 4.0 if side > 0.0 else fx_ - 14.0, "y": _cell_px(ci).y + 4.0, "w": 10.0, "h": 8.0}

func _head_out() -> bool:
	return state == "out" or (state == "back" and state_t > 0.25)

func hurtboxes() -> Array:
	return [_head()] if _head_out() and not cells.is_empty() else []

func harmboxes() -> Array:
	return hurtboxes()

func die(how: String) -> void:
	super.die(how)

func draw_body() -> void:
	if cells.is_empty():
		return
	var cp := Vector2(floori(x), floori(y))
	var glow := 0.5 + 0.5 * sin(t * 8.0)
	if state == "tell":
		draw_rect(Rect2(cp.x, cp.y, 16, 16), Color(1.0, 0.3, 0.45, 0.25 + 0.3 * glow))
	elif state == "crawl":
		draw_rect(Rect2(cp.x + 4, cp.y + 6, 8, 4), Color(1.0, 0.45, 0.6, 0.55))
		draw_rect(Rect2(cp.x + 5, cp.y + 7, 2, 2), Color(1.0, 0.9, 0.9, 0.8))
	if _head_out():
		var hd := _head()
		var base := face_x(side)
		draw_rect(Rect2(minf(base, hd.x) , hd.y + 2, absf(hd.x - base) + 4, 4), Color("#a8183a"))
		draw_rect(Rect2(hd.x, hd.y, hd.w, hd.h), Color(Game.COL.ink))
		draw_rect(Rect2(hd.x + 1, hd.y + 1, hd.w - 2, hd.h - 2), Color("#ff4f6d"))
		draw_rect(Rect2(hd.x + (6.0 if side > 0.0 else 2.0), hd.y + 2, 2, 2), Color.WHITE)

func net_fields() -> Array:
	var cp := _cell_px(ci) if not cells.is_empty() else Vector2(x, y)
	return [STATES.find(state), roundi(state_t * 100.0), roundi(cp.x / 16.0), roundi(cp.y / 16.0), int(side)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 3)]
	state_t = f[1] / 100.0
	side = float(f[4])
	var cell := Vector2i(int(f[2]), int(f[3]))
	if cells.is_empty():
		x = cell.x * 16.0
		y = cell.y * 16.0
		_find_group()
	ci = maxi(0, cells.find(cell))
