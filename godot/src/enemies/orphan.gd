class_name Orphan
extends EnemySM
# ORPHAN (`+`, MV5A-05): a fork() with three children. The parent (12x16, hp 4) walks at 40 px/s with three 6x6 children (hp 1, contact 1)
# orbiting it at radius 18. Kill the parent first and the children become orphans: each dashes at the nearest player every second
# (tell 0.35 s, 200 px/s). The children are creatures of their own.

var kids: Array = []
var dir := 1.0

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 16)
	hp = 4
	loot = 2
	col = "#a8793a"
	dir = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0
	face = dir

func update(dt: float) -> void:
	tick(dt)
	if stun <= 0.0 and on_ground:
		if hit_wall != 0 or edge_ahead(dir):
			dir = -dir
		vx = dir * 40.0
		face = dir
	elif on_ground:
		vx *= 0.85
	physics(dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	draw_rect(Rect2(px - 1, py - 1, 14, 18), ink)
	draw_rect(Rect2(px, py, 12, 16), Color("#a8793a"))
	draw_rect(Rect2(px, py, 12, 2), Color("#dcae5e"))
	draw_rect(Rect2(px + (7 if face > 0 else 2), py + 4, 2, 3), Color.WHITE)
	draw_rect(Rect2(px + 2, py + 12, 8, 1), ink)
	PixelText.draw_text(self, "fork()", px + 6.0, py - 9.0, "#ffd97a", {"align": "c", "tiny": true, "outline": Game.COL.ink})

func net_fields() -> Array:
	return []

func net_apply(_f: Array) -> void:
	pass
