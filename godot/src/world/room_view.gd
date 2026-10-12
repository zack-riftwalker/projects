class_name RoomView
extends Node2D
# RoomView: the static look of a room (tiles, decor, background), built once per load.

const T := 16
var tiles: TileMapLayer
var dynamic: TileMapLayer
var decor: TileMapLayer
var room: Room

static func make_tileset(world := 1) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/w%d_tiles.png" % Game.vis_world(world))
	src.texture_region_size = Vector2i(T, T)
	for r in range(7):
		for c in range(16):
			src.create_tile(Vector2i(c, r))
	ts.add_source(src, 0)
	return ts

# what a wall tile joins up with
static func _wallish(t: int) -> bool:
	return t == TileGrid.SOLID or t == TileGrid.DEAD or t == TileGrid.FIRE or t == TileGrid.THICK

func build(rm: Room) -> void:
	room = rm
	for c in get_children():
		c.queue_free()
	var world := int(room.def.get("world", 1))
	var ts := make_tileset(world)
	# background, scrolls with the camera at a fraction (set by the room each frame)
	var bg := Parallax2D.new()
	bg.name = "Background"
	bg.scroll_scale = Vector2(0.25, 0.1)
	bg.repeat_size = Vector2(384, 0)
	if world == 6:                                      # THE NETWORK draws its own sky (no art file)
		var nb := NetBackdrop.new()
		nb.name = "NetBackdrop"
		nb.room = room
		add_child(nb)
	else:
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/bg/w%d.png" % Game.vis_world(world))
		spr.centered = false
		bg.add_child(spr)
		add_child(bg)
	if not room.def.get("landmarks", []).is_empty():           # far shapes between the sky and the tiles (MVB1-14)
		var lm := Landmarks.new()
		lm.name = "Landmarks"
		lm.room = room
		lm.kinds = room.def.landmarks
		add_child(lm)
	decor = TileMapLayer.new()
	decor.name = "Decor"
	decor.tile_set = ts
	add_child(decor)
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = ts
	add_child(tiles)
	dynamic = TileMapLayer.new()
	dynamic.name = "Dynamic"
	dynamic.tile_set = ts
	add_child(dynamic)
	var g := room.grid
	for ty in range(g.h):
		for tx in range(g.w):
			_put_cell(g, tx, ty)
	# decor sits in the empty cell above exposed ground (and not on a cell the map uses for something else)
	for ty in range(1, g.h):
		for tx in range(g.w):
			if g.tile(tx, ty) == TileGrid.SOLID and g.tiles[(ty - 1) * g.w + tx] == TileGrid.E and not room.reserved(tx, ty - 1):
				decor.set_cell(Vector2i(tx, ty - 1), 0, Vector2i(floori(Game.hash3(tx, ty, 77) * 16), 6))

func _put_cell(g: TileGrid, tx: int, ty: int) -> void:
	var t := g.tile(tx, ty)
	if t == TileGrid.DEAD:
		if Game.flag("dead:" + room.id):
			return
		t = TileGrid.SOLID                      # dead code looks like wall until it is found
	match t:
		TileGrid.SOLID:
			var u := _wallish(g.tile(tx, ty - 1)) or ty == 0
			var d := _wallish(g.tile(tx, ty + 1)) or ty == g.h - 1
			var l := _wallish(g.tile(tx - 1, ty))
			var r := _wallish(g.tile(tx + 1, ty))
			var mask := int(u) | (int(d) << 1) | (int(l) << 2) | (int(r) << 3)
			var variant := floori(Game.hash3(tx, ty, 1) * 4)
			tiles.set_cell(Vector2i(tx, ty), 0, Vector2i(mask, variant))
		TileGrid.ONEWAY:
			var lw := g.tile(tx - 1, ty) == TileGrid.ONEWAY or g.tile(tx - 1, ty) == TileGrid.SOLID
			var rw := g.tile(tx + 1, ty) == TileGrid.ONEWAY or g.tile(tx + 1, ty) == TileGrid.SOLID
			tiles.set_cell(Vector2i(tx, ty), 0, Vector2i((int(lw) | (int(rw) << 1)) + 4 * (tx & 1), 4))
		TileGrid.SPIKE_U:
			tiles.set_cell(Vector2i(tx, ty), 0, Vector2i(0, 5))
		TileGrid.SPIKE_D:
			tiles.set_cell(Vector2i(tx, ty), 0, Vector2i(1, 5))
		TileGrid.CRACK:
			dynamic.set_cell(Vector2i(tx, ty), 0, Vector2i(2, 5))
		TileGrid.CRUMBLE:
			dynamic.set_cell(Vector2i(tx, ty), 0, Vector2i(3, 5))

# a tile changed after the room was built (a variant): redraw it and the wall cells around it (their masks depend on it)
func refresh_tile(tx: int, ty: int) -> void:
	var g := room.grid
	for o in [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]:
		var x: int = tx + o[0]
		var y: int = ty + o[1]
		if x < 0 or y < 0 or x >= g.w or y >= g.h:
			continue
		var nt := g.tile(x, y)
		if o == [0, 0] or nt == TileGrid.SOLID or nt == TileGrid.ONEWAY:      # (neighbours only when their shape depends on this cell)
			erase_tile(x, y)
			_put_cell(g, x, y)

func erase_tile(tx: int, ty: int) -> void:
	dynamic.erase_cell(Vector2i(tx, ty))
	tiles.erase_cell(Vector2i(tx, ty))
