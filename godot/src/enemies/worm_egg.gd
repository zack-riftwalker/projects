class_name WormEgg
extends Enemy
# WORM EGG (MVB3-04): what a worm leaves in a free brick of its group when its bite ended without a hit: a pulsing brick. Five seconds later it is a
# worm. It cannot be hit and does not hurt; it only counts towards the group's three.

var cell := Vector2i.ZERO
var group := Vector2i.ZERO
var left := Worm.EGG_T

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 16, 16)
	x = px
	y = py
	hp = 1
	loot = 0
	col = "#ff4f6d"
	stompable = false
	no_hit = true
	no_agent = true
	dashable = false
	passive = true

func hurtboxes() -> Array:
	return []

func harmboxes() -> Array:
	return []

func update(dt: float) -> void:
	tick(dt)
	left -= dt
	if left <= 0.0 and not puppet:
		var nw := Worm.new(room, cell.x * 16, cell.y * 16)
		room.add_entity(nw)
		room.burst(x + 8.0, y + 8.0, 8, ["#ff4f6d", "#ffffff"], 90.0, 100.0)
		Audio.sfx("squish", {"vol": 0.6})
		loot = 0
		dead = true

func draw_body() -> void:
	var k := 0.5 + 0.5 * sin(t * (4.0 + (Worm.EGG_T - left) * 2.0))
	var px := floorf(x)
	var py := floorf(y)
	draw_rect(Rect2(px, py, 16, 16), Color(1.0, 0.3, 0.45, 0.18 + 0.35 * k))
	draw_rect(Rect2(px + 4, py + 3, 8, 10), Color(Game.COL.ink))
	draw_rect(Rect2(px + 5, py + 4, 6, 8), Color(1.0, 0.7, 0.78, 0.6 + 0.4 * k))
	draw_rect(Rect2(px + 6, py + 5, 2, 2), Color(1.0, 1.0, 1.0, 0.8))

func net_fields() -> Array:
	return [roundi(left * 100.0), cell.x, cell.y, group.x, group.y]

func net_apply(f: Array) -> void:
	left = f[0] / 100.0
	cell = Vector2i(int(f[1]), int(f[2]))
	group = Vector2i(int(f[3]), int(f[4]))
