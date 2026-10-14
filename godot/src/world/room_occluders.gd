class_name RoomOccluders
extends Node2D
# RoomOccluders (MVGN-16, Ultra): light occluders from the tile grid, built once per room. Solid cells are merged into horizontal runs, then runs with the
# same x range on consecutive rows into rectangles; at most 120 polygons per room (above that only the ones nearest the arena's centre). Only lights
# flagged shadow (RoomLights: the crawler's beam, N22's overheads) cast shadows, in the sky_far colour at alpha 0.6 with PCF5.

const MAX_POLYS := 120

var room: Room
var rects: Array = []                      # merged Rect2 in world px
var polys := 0

func _ready() -> void:
	var g := room.grid
	var runs: Array = []                   # [y, x0, x1) per row run
	for ty in range(g.h):
		var tx := 0
		while tx < g.w:
			if g.tile(tx, ty) == TileGrid.SOLID:
				var x0 := tx
				while tx < g.w and g.tile(tx, ty) == TileGrid.SOLID:
					tx += 1
				runs.append([ty, x0, tx])
			else:
				tx += 1
	# merge vertically: a run extends the rect above it with the same x range
	var by_key := {}
	for r in runs:
		var key := "%d:%d:%d" % [r[1], r[2], r[0] - 1]
		if by_key.has(key):
			var idx: int = by_key[key]
			rects[idx] = Rect2(rects[idx].position, rects[idx].size + Vector2(0, 16))
			by_key.erase(key)
			by_key["%d:%d:%d" % [r[1], r[2], r[0]]] = idx
		else:
			rects.append(Rect2(r[1] * 16, r[0] * 16, (r[2] - r[1]) * 16, 16))
			by_key["%d:%d:%d" % [r[1], r[2], r[0]]] = rects.size() - 1
	if rects.size() > MAX_POLYS:
		var c := Vector2(float(room.pw) * 0.5, float(room.ph) * 0.5)
		rects.sort_custom(func(a, b): return a.get_center().distance_to(c) < b.get_center().distance_to(c))
		rects = rects.slice(0, MAX_POLYS)
	for rc in rects:
		var occ := LightOccluder2D.new()
		var op := OccluderPolygon2D.new()
		op.polygon = PackedVector2Array([rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)])
		occ.occluder = op
		add_child(occ)
		polys += 1
	Game.gfx_changed.connect(_apply)
	_apply()

func _exit_tree() -> void:
	if Game.gfx_changed.is_connected(_apply):
		Game.gfx_changed.disconnect(_apply)

func _apply() -> void:
	visible = Game.gfx_tier >= 2
