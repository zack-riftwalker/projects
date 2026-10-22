class_name Spinlock
extends EnemySM
# SPINLOCK (`)`, MV5A-05): a 20x20 spinning blade on the nearest solid side of its cell, a pure function of the tick. Every 4th tick it
# stops for one tick (only then it can be hit; hp 6), the tick after that it dashes 48 px out along its axis and back, then it spins in
# place for two ticks. It always cuts. breakpoint stops its clock (harmless while frozen).

const OUT := 48.0

var cell := Vector2.ZERO
var axis := Vector2.RIGHT         # away from the wall it sits on
var base := Vector2.ZERO          # the blade's centre when parked

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 20, 20)
	hp = 6
	loot = 3
	col = "#e0a040"
	stompable = false
	kb = 0.0
	cell = Vector2(px, py)
	settle()

# the nearest solid side of its cell decides where it hangs (left, right, up, then down); the room calls this again once all tiles are read
func settle() -> void:
	var tx := floori((cell.x + 8.0) / T)
	var ty := floori((cell.y + 8.0) / T)
	var ctr := Vector2(cell.x + 8.0, cell.y + 8.0)
	if room.grid.solid(tx - 1, ty):
		axis = Vector2.RIGHT
	elif room.grid.solid(tx + 1, ty):
		axis = Vector2.LEFT
	elif room.grid.solid(tx, ty - 1):
		axis = Vector2.DOWN
	elif room.grid.solid(tx, ty + 1):
		axis = Vector2.UP
	else:
		axis = Vector2.RIGHT
	base = ctr - axis * 4.0
	x = base.x - w / 2.0
	y = base.y - h / 2.0

func tick_k() -> int:
	return floori(mtime() / room.tick_len()) % 4

func stopped_now() -> bool:
	return tick_k() == 3

func blocks(_dx: float, _dy: float, _how: String) -> bool:
	return not stopped_now()                              # a spinning blade shrugs claws off

func update(dt: float) -> void:
	tick(dt)
	var m := mtime()
	var f := fposmod(m, room.tick_len()) / room.tick_len()
	var off := 0.0
	if floori(m / room.tick_len()) % 4 == 0:
		off = OUT * sin(PI * f)
	var c := base + axis * off
	x = c.x - w / 2.0
	y = c.y - h / 2.0

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var c := Vector2(floorf(x + w / 2.0), floorf(y + h / 2.0))
	var m := mtime()
	var stopped := stopped_now()
	var ang := 0.0 if stopped else m * 14.0
	# the rail it runs on, from the wall to the end of its dash
	draw_line(base - axis * 4.0, base + axis * OUT, Color(ink, 0.35), 1.0)
	var teeth := 8
	var pts := PackedVector2Array()
	for i in range(teeth * 2):
		var a := ang + float(i) * PI / float(teeth)
		var r := 10.0 if i % 2 == 0 else 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, ink)
	var inner := PackedVector2Array()
	for i in range(teeth * 2):
		var a2 := ang + float(i) * PI / float(teeth)
		var r2 := 8.5 if i % 2 == 0 else 5.0
		inner.append(c + Vector2(cos(a2), sin(a2)) * r2)
	draw_colored_polygon(inner, Color("#d9d2c4") if not stopped else Color("#ffd23f"))
	draw_circle(c, 2.5, ink)
	if stopped:
		PixelText.draw_text(self, "lock", c.x, c.y - 17.0, "#ffd23f", {"align": "c", "tiny": true, "outline": Game.COL.ink})

func net_fields() -> Array:
	return []

func net_apply(_f: Array) -> void:
	pass
