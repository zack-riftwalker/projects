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
	src.texture = load("res://assets/tiles/w%d_tiles.png" % world)
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
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/bg/w%d.png" % world)
	spr.centered = false
	bg.add_child(spr)
	add_child(bg)
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
			var t := g.tile(tx, ty)
			if t == TileGrid.DEAD:
				if Game.flag("dead:" + room.id):
					continue
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
	# decor sits in the empty cell above exposed ground (and not on a cell the map uses for something else)
	for ty in range(1, g.h):
		for tx in range(g.w):
			if g.tile(tx, ty) == TileGrid.SOLID and g.tiles[(ty - 1) * g.w + tx] == TileGrid.E and not room.reserved(tx, ty - 1):
				decor.set_cell(Vector2i(tx, ty - 1), 0, Vector2i(floori(Game.hash3(tx, ty, 77) * 16), 6))

func erase_tile(tx: int, ty: int) -> void:
	dynamic.erase_cell(Vector2i(tx, ty))
	tiles.erase_cell(Vector2i(tx, ty))
