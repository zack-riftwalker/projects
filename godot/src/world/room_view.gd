class_name RoomView
extends Node2D
# RoomView: the static look of a room (tiles, decor, background), built once per load.

const T := 16
var tiles: TileMapLayer
var dynamic: TileMapLayer
var decor: TileMapLayer
var room: Room
var led_layer: TileMapLayer              # world 6: animated LED strips and fan grilles over some wall faces (MVGN-10)
var fan_layer: TileMapLayer
var anim_rev := -1

static func make_tileset(world := 1) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/w%d_tiles.png" % Game.vis_world(world))
	if world == 6 and Game.gfx_tier >= 1:                  # lit tiles get relief from the normal map (High and Ultra, MVGN-06)
		src.texture = normal_tex(src.texture)
	src.texture_region_size = Vector2i(T, T)
	for r in range(7):
		for c in range(16):
			src.create_tile(Vector2i(c, r))
	ts.add_source(src, 0)
	return ts

static var _ntiles: CanvasTexture

static func normal_tex(diffuse: Texture2D) -> Texture2D:
	if _ntiles == null:
		_ntiles = CanvasTexture.new()
		_ntiles.diffuse_texture = diffuse
		_ntiles.normal_texture = load("res://assets/tiles/w6_tiles_n.png")
	return _ntiles

# the tier changed in the pause menu: the tiles of a NETWORK room swap their texture (the next room is built with the new tier anyway)
func _on_gfx_changed() -> void:
	if room == null or room.look == null:
		return
	_apply_anim()
	var d: Texture2D = load("res://assets/tiles/w6_tiles.png")
	var tx: Texture2D = normal_tex(d) if Game.gfx_tier >= 1 else d
	for tl in [decor, tiles, dynamic]:
		var s := tl.tile_set.get_source(0) as TileSetAtlasSource
		if s != null and s.texture != tx:
			s.texture = tx

# what a wall tile joins up with
static func _wallish(t: int) -> bool:
	return t == TileGrid.SOLID or t == TileGrid.DEAD or t == TileGrid.FIRE or t == TileGrid.THICK

func build(rm: Room) -> void:
	room = rm
	for c in get_children():
		c.queue_free()
	var world := int(room.def.get("world", 1))
	var ts := make_tileset(world)
	if world == 6 and not Game.gfx_changed.is_connected(_on_gfx_changed):
		Game.gfx_changed.connect(_on_gfx_changed)
	# background, scrolls with the camera at a fraction (set by the room each frame)
	if world == 6:                                      # THE NETWORK draws its own sky (no art file)
		var nb := NetBackdrop.new()
		nb.name = "NetBackdrop"
		nb.room = room
		add_child(nb)
	else:
		var bg := Parallax2D.new()                      # (made only here: one made for a network room was never freed, a leak per visit)
		bg.name = "Background"
		bg.scroll_scale = Vector2(0.25, 0.1)
		bg.repeat_size = Vector2(384, 0)
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
		if room.look != null:
			lm.material = Look.unshaded()
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
	if room.look != null:                                   # the terrain sits above the backdrop in the 3-tier contrast rule: the ambient darkens it, this lifts it back
		for tl in [decor, tiles, dynamic]:
			tl.modulate = Look.TERRAIN_GAIN
	var g := room.grid
	for ty in range(g.h):
		for tx in range(g.w):
			_put_cell(g, tx, ty)
	if room.look != null:
		_build_anim(g)
	# decor sits in the empty cell above exposed ground (and not on a cell the map uses for something else)
	for ty in range(1, g.h):
		for tx in range(g.w):
			if g.tile(tx, ty) == TileGrid.SOLID and g.tiles[(ty - 1) * g.w + tx] == TileGrid.E and not room.reserved(tx, ty - 1):
				decor.set_cell(Vector2i(tx, ty - 1), 0, Vector2i(floori(Game.hash3(tx, ty, 77) * 16), 6))

# an animated tile set from a 4-frame strip (64 x 16)
static func anim_set(path: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(T, T)
	src.create_tile(Vector2i(0, 0))
	src.set_tile_animation_columns(Vector2i(0, 0), 4)
	src.set_tile_animation_frames_count(Vector2i(0, 0), 4)
	for f in range(4):
		src.set_tile_animation_frame_duration(Vector2i(0, 0), f, 0.18)
	ts.add_source(src, 0)
	return ts

# LED strips and fan grilles on some wall faces (a solid cell with air beside or above it), by hash, at most 1 cell in 12, never on a cell the map uses
func _build_anim(g: TileGrid) -> void:
	led_layer = TileMapLayer.new()
	led_layer.name = "AnimLed"
	led_layer.tile_set = anim_set("res://assets/tiles/w6_led.png")
	led_layer.material = Look.unshaded()
	add_child(led_layer)
	fan_layer = TileMapLayer.new()
	fan_layer.name = "AnimFan"
	fan_layer.tile_set = anim_set("res://assets/tiles/w6_fan.png")
	fan_layer.modulate = Look.TERRAIN_GAIN
	add_child(fan_layer)
	var sd := int(String(room.id).substr(1)) * 13 if String(room.id).substr(1).is_valid_int() else 5
	for ty in range(g.h):
		for tx in range(g.w):
			if g.tile(tx, ty) != TileGrid.SOLID or room.reserved(tx, ty):
				continue
			var air := g.tile(tx - 1, ty) == TileGrid.E or g.tile(tx + 1, ty) == TileGrid.E or g.tile(tx, ty - 1) == TileGrid.E
			if not air or Game.hash3(tx, ty, 330 + sd) >= 1.0 / 12.0:
				continue
			(led_layer if Game.hash3(tx, ty, 331 + sd) < 0.6 else fan_layer).set_cell(Vector2i(tx, ty), 0, Vector2i(0, 0))
	_apply_anim()

# the layers follow the tier ("Reduce flashing" freezes the LED strips on one frame) and the mood's accent
func _apply_anim() -> void:
	if led_layer == null:
		return
	# the arenas dim the ambient (N09's fight): the terrain is lifted back toward readable (the contrast rule beats the mood)
	var am := float(room.look.adj.ambient_mul) if room.look != null else 1.0
	var tg := Look.TERRAIN_GAIN * clampf(pow(1.0 / maxf(am, 0.35), 0.9), 1.0, 2.4)
	tg.a = 1.0
	for tl in [decor, tiles, dynamic, fan_layer]:
		tl.modulate = tg
	var on := Game.gfx_tier >= 1
	led_layer.visible = on
	fan_layer.visible = on
	var dur := 1000.0 if Game.reduce_flash else 0.18
	for tl in [led_layer, fan_layer]:
		var src := tl.tile_set.get_source(0) as TileSetAtlasSource
		for f in range(4):
			src.set_tile_animation_frame_duration(Vector2i(0, 0), f, 1000.0 if (Game.reduce_flash and tl == led_layer) else 0.18)
	var o: Dictionary = room.look.out if room.look != null and not room.look.out.is_empty() else Look.mixed("stable", 1.0)
	var ca: Color = o.accent_a
	led_layer.modulate = Color(ca.r, ca.g, ca.b, 1.0)
	anim_rev = room.look.rev if room.look != null else 0

func _process(_dt: float) -> void:
	if led_layer != null and room.look != null and room.look.rev != anim_rev:
		_apply_anim()

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
