extends Control
# Main: builds the viewport, fits it to the window, and (for tests) hands control to src/test/run_tests.gd.

const W := 384
const H := 216

var game_vp: SubViewport
var world: Node2D
var screen: TextureRect
var room: Room
var hud: Hud
var hud_layer: CanvasLayer

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
		var script = load("res://src/test/run_tests.gd")
		if script == null:
			print("TEST ", Game.test_name, " FAIL could not load run_tests.gd")
			get_tree().quit(1)
			return
		var ok: bool = script.new(self).run(Game.test_name)
		get_tree().quit(0 if ok else 1)
		return
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	game_vp.add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	start_room(null)
	if Game.demo:
		demo_frame = 0
	elif Game.shot_path != "":
		if Game.scene == "hud":          # screenshot helper: Clawd next to the first sign, a Bug and a Typo close by
			room.player.x = 104.0
			var b := Bug.new(room, 140, 192, false)
			room.ents.append(b)
			room.entity_root.add_child(b)
			room.tokens = 7
		_shot_after(30)

func start_room(snap) -> void:
	if room != null:
		room.queue_free()
	room = Room.new()
	world.add_child(room)
	room.load_room("R01", snap)
	room.build_nodes()
	room.restart_requested.connect(func(sn): start_room(sn))
	hud.set_room(room)
	Audio.music(String(room.def.get("music", "")))

# scripted demo for screenshots: run, jump, dash, swipe (--demo --shot=<prefix>)
var demo_frame := -1

func _physics_process(_d: float) -> void:
	if demo_frame < 0:
		return
	var f := demo_frame
	var keys := {}
	if f < 120:
		keys["right"] = true
	if f >= 40 and f < 62:
		keys["jump"] = true
	if f == 72:
		keys["dash"] = true
	if f == 96 or f == 102:
		keys["attack"] = true
	Controls.script_input = keys
	demo_frame += 1
	if f in [30, 66, 78, 98, 116]:
		_snap.call_deferred("%s_%d.png" % [Game.shot_path, f])
	if f == 120:
		get_tree().quit()

func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	game_vp.get_texture().get_image().save_png(path)

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
