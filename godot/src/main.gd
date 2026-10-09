extends Control
# Main: builds the viewport, fits it to the window, and (for tests) hands control to src/test/run_tests.gd.

const W := 384
const H := 216

var game_vp: SubViewport
var world: Node2D
var screen: TextureRect
var room: Room

func _ready() -> void:
	game_vp = SubViewport.new()
	game_vp.name = "GameViewport"
	game_vp.size = Vector2i(W, H)
	game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	game_vp.snap_2d_transforms_to_pixel = true
	game_vp.snap_2d_vertices_to_pixel = true
	game_vp.transparent_bg = false
	add_child(game_vp)
	world = Node2D.new()
	world.name = "World"
	game_vp.add_child(world)
	screen = TextureRect.new()
	screen.name = "Screen"
	screen.texture = game_vp.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(screen)
	resized.connect(_fit)
	_fit()
	print("CLAWD: ready")
	if Game.test_name != "":
		var t = load("res://src/test/run_tests.gd").new(self)
		var ok: bool = t.run(Game.test_name)
		get_tree().quit(0 if ok else 1)
		return
	room = Room.new()
	world.add_child(room)
	room.load_room("R01")
	room.build_nodes()
	if Game.shot_path != "":
		_shot_after(30)

func _shot_after(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := game_vp.get_texture().get_image()
	img.save_png(Game.shot_path)
	print("CLAWD: shot ", Game.shot_path)
	get_tree().quit()

# landscape: the game fills the window. portrait: full width at the top with a 10 css-px margin (as the current page)
func _fit() -> void:
	var sz := size
	if sz.x >= sz.y:
		screen.position = Vector2.ZERO
		screen.size = sz
	else:
		var k := DisplayServer.screen_get_scale()
		var hh := sz.x * float(H) / float(W)
		screen.position = Vector2(0, 10.0 * k)
		screen.size = Vector2(sz.x, hh)
