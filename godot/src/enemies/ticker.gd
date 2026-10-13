class_name Ticker
extends EnemySM
# TICKER (`{`, MV5A-05): a clockwork runner that lives on the tick. At the start of every tick it moves exactly one cell along the floor
# (a 0.15 s step), turns at walls and edges, and every 4th tick it hops one cell up and forward instead. Its place is a function of its
# cell, its direction and the tick, so both pages agree; breakpoint stops its clock (frozen, it is harmless and can be stood on).

const STEP_T := 0.15

var cell_x := 0
var cell_y := 0                    # the row of the cell it stands in
var dir := 1
var last_tick := -999
var p0 := Vector2.ZERO             # the step in progress: from p0 to p1 (top-left, px)
var p1 := Vector2.ZERO
var hopping := false

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 14, 12)
	hp = 2
	loot = 1
	col = "#dcae5e"
	cell_x = floori((px + 8.0) / T)
	cell_y = floori((py + 8.0) / T)
	dir = -1 if Game.hash3(px, py, 1) < 0.5 else 1
	p0 = _cell_pos(cell_x, cell_y)
	p1 = p0
	x = p0.x
	y = p0.y

func _cell_pos(cx_: int, cy_: int) -> Vector2:
	return Vector2(float(cx_ * T) + (T - w) / 2.0, float(cy_ * T + T) - h)

func _floor_under(tx: int, ty: int) -> bool:
	return room.grid.solid(tx, ty + 1) or room.grid.tile(tx, ty + 1) == TileGrid.ONEWAY

func _plan(ti: int) -> void:
	p0 = _cell_pos(cell_x, cell_y)
	hopping = ti % 4 == 3
	var nx := cell_x + dir
	if hopping:
		if room.grid.solid(nx, cell_y):
			if not room.grid.solid(nx, cell_y - 1) and not room.grid.solid(cell_x, cell_y - 1):
				cell_x = nx                                   # a step up: onto the ledge
				cell_y -= 1
			else:
				dir = -dir
		else:
			cell_x = nx
	else:
		if room.grid.solid(nx, cell_y) or not _floor_under(nx, cell_y):
			dir = -dir                                        # a wall or an edge: turn, no move this tick
		else:
			cell_x = nx
	var guard := 0
	while not _floor_under(cell_x, cell_y) and cell_y < room.h - 2 and guard < 8:
		cell_y += 1
		guard += 1
	p1 = _cell_pos(cell_x, cell_y)
	face = float(dir)

func update(dt: float) -> void:
	tick(dt)
	var m := mtime()
	var ti := floori(m / Tower.TICK)
	if ti != last_tick:
		last_tick = ti
		_plan(ti)
	var k := clampf(fposmod(m, Tower.TICK) / STEP_T, 0.0, 1.0)
	var pos := p0.lerp(p1, k)
	if hopping and p0 != p1:
		pos.y -= 10.0 * sin(PI * k)
	x = pos.x
	y = pos.y
	vx = 0.0
	vy = 0.0

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	var spin := mtime() * 6.0
	draw_rect(Rect2(px - 1, py - 1, 16, 14), ink)
	draw_rect(Rect2(px, py, 14, 12), Color("#a8793a"))
	draw_rect(Rect2(px, py, 14, 2), Color("#f3d58a"))
	# a little wheel on its back that ticks
	var c := Vector2(px + 7.0, py + 6.0)
	for i in range(4):
		var a := spin + float(i) * PI / 2.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * 4.0, ink, 1.0)
	draw_circle(c, 1.5, Color("#f3d58a"))
	var ex := 10.0 if dir > 0 else 2.0
	draw_rect(Rect2(px + ex, py + 3, 2, 2), Color.WHITE)
	draw_rect(Rect2(px + 1, py + 11, 3, 2), ink)
	draw_rect(Rect2(px + 10, py + 11, 3, 2), ink)

func net_fields() -> Array:
	return [cell_x, cell_y, dir, last_tick]

func net_apply(f: Array) -> void:
	cell_x = int(f[0])
	cell_y = int(f[1])
	dir = int(f[2])
	last_tick = int(f[3])
	hopping = last_tick % 4 == 3
	face = float(dir)
