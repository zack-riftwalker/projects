extends Control

# Main: builds the viewport, fits it to the window, runs the pause menu, the touch layer and the debug overlay,
# and (for tests) hands control to src/test/run_tests.gd.

const W := 384
const H := 216

var game_vp: SubViewport
var world: Node2D
var screen: TextureRect
var manager: RoomManager
var room: Room:
	get: return manager.room if manager != null else null
var hud: Hud
var hud_layer: CanvasLayer
var pause_menu: PauseMenu
var bench_menu: BenchMenu
var touch: TouchControls
var debug_overlay: DebugOverlay
var coop: Coop
var title: TitleScreen
var end_screen: EndScreen
var game_rect := Rect2()                # window pixels of the displayed 384x216 picture (after aspect fitting)
var paused := false
var demo_frame := -1
var selftest_frame := -1
var selftest_x0 := 0.0
var last_logged_x := 0.0

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
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	pause_menu = PauseMenu.new()
	pause_menu.resume_requested.connect(set_paused.bind(false))
	pause_menu.fullscreen_requested.connect(request_fullscreen)
	pause_menu.restart_requested.connect(func():
		set_paused(false)
		if coop == null or not coop.restart_both():
			manager.respawn(false))
	hud_layer.add_child(pause_menu)
	bench_menu = BenchMenu.new()
	hud_layer.add_child(bench_menu)
	touch = TouchControls.new()
	touch.name = "Touch"
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(touch)
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "Debug"
	debug_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(debug_overlay)
	manager = RoomManager.new(world, hud)
	add_child(manager)
	manager.restart_requested.connect(func(): manager.respawn(true))
	manager.bench_requested.connect(func(r, i): open_bench(r, i))
	bench_menu.manager = manager
	bench_menu.rest_chosen.connect(func():
		manager.rest(bench_room, bench_idx))
	bench_menu.travel_chosen.connect(func(id): manager.travel(id))
	manager.room_changed.connect(func(r): hud.set_room(r))
	pause_menu.manager = manager
	end_screen = EndScreen.new()
	end_screen.done.connect(_back_to_title)
	hud_layer.add_child(end_screen)
	manager.end_requested.connect(func():
		if not end_screen.active:
			end_screen.open())
	if _wants_title():
		_open_title()
		return
	_begin_game("continue")
	if Game.demo:
		demo_frame = 0
	elif Game.selftest:
		selftest_frame = 0
		selftest_x0 = room.player.x
	elif Game.shot_path != "":
		if Game.scene == "hud":          # screenshot helper: Clawd next to the first sign, a Bug close by
			room.player.x = 104.0
			manager.set_process(false)
			var b := Bug.new(room, 140, 192, false)
			room.ents.append(b)
			room.entity_root.add_child(b)
			room.tokens = 7
			Game.fragments = 2
		elif Game.scene == "enemies":                   # screenshot helper: a Guard, a Zombie, a corpse
			manager.set_process(false)
			room.player.x = 100.0
			for e in room.ents:
				e.queue_free()
			room.ents.clear()
			var g := Guard.new(room, 0, 0)
			g.x = 140.0
			g.y = 192.0
			g.face = -1.0
			g.stun = 999.0
			var z := Zombie.new(room, 0, 0)
			z.x = 190.0
			z.y = 196.0
			z.stun = 999.0
			var z2 := Zombie.new(room, 0, 0)
			z2.x = 230.0
			z2.y = 196.0
			var g2 := Guard.new(room, 0, 0)
			g2.x = 270.0
			g2.y = 192.0
			g2.face = 1.0
			g2.stun = 999.0
			for e in [g, z, z2, g2]:
				room.ents.append(e)
				room.entity_root.add_child(e)
			z2.hit(1, 1.0, 0.0, "swipe")
			z2.hit(1, 1.0, 0.0, "swipe")
		elif Game.scene.begins_with("null:"):           # screenshot helper: NULL in the middle of an attack (null:<attack>)
			manager.swap_to("R05")
			var p = manager.player
			p.x = 150.0
			p.y = 166.0
			p.inv = 999.0
			var r: Room = manager.room
			r._start_intro()
			r.fight.t = 0.0
			r._begin_fight()
			var b = r.boss
			b.phase = 2
			b.tx = 250.0
			b.ty = 96.0
			var kind := Game.scene.substr(5)
			if kind == "dangling":
				b.start_dangling(p)
			elif kind == "deref":
				b.start_deref(p)
			elif kind == "rain":
				b.set_state("rain", 0.1)
				b.n = 4
			elif kind == "sweep":
				b.set_state("sweepPrep", 5.0)
				b.dir = 1
			elif kind == "poke":
				b.set_state("poke")
				b.n = 5
				b.cur.mode = "aim"
				b.cur.t = 5.0
				b.pick_aim()
		elif Game.scene.begins_with("room:"):         # screenshot helper: stand in a room
			manager.swap_to(Game.scene.substr(5))
		elif Game.scene in ["title", "settings", "join", "end"]:       # screenshot helpers: the menus
			_open_title()
			if Game.scene == "settings":
				title.page = "settings"
			elif Game.scene == "join":
				title.page = "join"
				title.code = "246"
				title.sel = 4
			elif Game.scene == "end":
				title.close()
				Game.play_time = 1234.0
				Game.deaths = 7
				Game.fragments = 3
				Game.tokens = 41
				Game.fights = [{"boss": "NULL", "secs": 72.4, "hits": [41, 22], "dmg_taken": [3, 2], "won": true, "diff": "normal", "coop": true}]
				end_screen.open()
		elif Game.scene == "map":                      # screenshot helper: the pause map with every room visited
			for id in Game.rooms_meta.rooms:
				Game.flags["room:%s:visited" % id] = true
			manager.swap_to("R03")
			manager.player.x = 1200.0
			set_paused(true)
			pause_menu.page = "map"
		_shot_after(Game.shot_wait)


# the title screen shows up for a plain page load; every URL / test option that names what to do skips it
func _wants_title() -> bool:
	return not (Game.play_now or Game.test_name != "" or Game.selftest or Game.shot_path != "" or Game.demo or Game.net_role != "" or Game.scenario != "" or Game.autotest or Game.scene != "")

func _open_title() -> void:
	title = TitleScreen.new()
	hud_layer.add_child(title)
	title.coop = null
	title.continue_game.connect(func(): _start_from_title("continue"))
	title.new_game.connect(func(): _start_from_title("new"))
	title.host_game.connect(func(): _start_from_title("host"))
	title.join_game.connect(_join_from_title)
	title.leave_wait.connect(_cancel_join)
	title.fullscreen_requested.connect(request_fullscreen)
	title.open()                  # the touch pad stays on the menus: stick moves, JUMP chooses, DASH goes back

func _start_from_title(kind: String) -> void:
	title.close()
	touch.suspend(false)
	Audio.stop_music()
	if kind == "host":
		Game.net_role = "host"
	_begin_game(kind)

func _join_from_title(code: String) -> void:
	Game.net_role = "guest"
	Game.net_code = code
	Game.persist = false
	if coop == null:
		_make_coop()
		if not Net.fatal.is_connected(_join_failed):
			Net.fatal.connect(_join_failed)
	else:
		coop.started = false
		Net.connect_as("guest", code)
	title.coop = coop

func _make_coop() -> void:
	coop = Coop.new()
	coop.name = "Coop"
	add_child(coop)
	coop.setup(self)

func _join_failed(why: String) -> void:
	if title == null or not title.active:
		return
	_drop_join()
	title.fail("cannot join: " + why)

func _cancel_join() -> void:
	_drop_join()

# a join that did not happen leaves no guest state behind: New game / Continue / Host co-op must start a normal game afterwards
func _drop_join() -> void:
	Net.leave()
	Game.net_role = ""
	Game.persist = true
	if coop != null:
		coop.queue_free()
		coop = null
	title.coop = null

# the world: a save (or a new game), the co-op link, the first room
func _begin_game(kind: String) -> void:
	if kind == "new":
		Game.new_game()
		Game.fresh()
	elif Game.persist and Game.net_role != "guest":
		Game.load_save()
		Game.load_settings()          # the settings file wins over the save's copy (and ?diff= over both)
	if Game.demo:
		Game.tools.bash = true
	if Game.net_role != "" and coop == null:
		_make_coop()
	if Game.net_role != "guest":
		manager.start_game()
	if Game.scenario != "":
		var sc = load("res://src/test/coop_scenarios.gd")
		if sc != null:
			add_child(sc.new(self))

# end screen -> the title again (a fresh page: simplest way to reset every object)
func _back_to_title() -> void:
	Net.leave()
	Game.net_role = ""
	Game.play_now = false
	get_tree().reload_current_scene()

var bench_room: Room
var bench_idx := 0

func open_bench(r: Room, i: int) -> void:
	bench_room = r
	bench_idx = i
	bench_menu.open()

func set_paused(v: bool, remote := false) -> void:
	paused = v
	if not remote and Net.is_active():          # (queued even while the line is down: it is sent when the line is back)
		Net.rel("pause", {"on": v})
	if v:
		pause_menu.open()
	else:
		pause_menu.close()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
		gesture_msec = Time.get_ticks_msec()
		toggle_fullscreen()            # F, as in the JS game (it is not a game action: Controls does not bind it)
		return
	_fullscreen_input(event)
	if title != null and title.active:
		title.key_event(event)
	if title != null and title.active or end_screen != null and end_screen.active:
		var tp := Vector2.ZERO
		var th := false
		if event is InputEventScreenTouch and event.pressed:
			tp = event.position
			th = true
		elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:      # (a touch also arrives as an emulated mouse click: once is enough)
			tp = event.position
			th = true
		if th:
			if event is InputEventScreenTouch:
				touch.enable()            # a phone: the stick and buttons show up as soon as the title is gone
			var tg := to_game(tp)
			if Game.debug:
				print("CLAWD: tap ", event.get_class(), " ", tp, " -> ", tg)
			if touch.visible and touch.claims(tp):
				return                # the finger is on a pad button: it presses that button, not the menu item behind it
			if end_screen.active:
				end_screen.tap(tg)
			else:
				title.tap(tg)
		return
	# a tap on a pause option
	if paused or bench_menu.active:
		var pos := Vector2.ZERO
		var hit := false
		if event is InputEventScreenTouch and event.pressed:
			pos = event.position
			hit = true
		elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:      # (a touch also arrives as an emulated mouse click: once is enough)
			pos = event.position
			hit = true
		if hit:
			var gp := to_game(pos)
			if paused:
				pause_menu.tap(gp)
			else:
				bench_menu.tap(gp)

# Fullscreen (F, and the menu entries). Browsers only allow it inside a user gesture, and a gesture keeps the permission for a few
# seconds: F runs straight from its key event; a menu entry (chosen on a press or in the next physics step) goes at once when a
# gesture just happened, else it waits for the next key press / lifted finger / click (and gives up after 2 s)
var gesture_msec := -100000
var fs_deadline := 0

func _fullscreen_input(event: InputEvent) -> void:
	var g: bool = event is InputEventKey and event.pressed and not event.echo
	if event is InputEventScreenTouch and not event.pressed:
		g = true
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		g = true
	if not g:
		return
	gesture_msec = Time.get_ticks_msec()
	if fs_deadline > gesture_msec:
		toggle_fullscreen()

func request_fullscreen() -> void:
	var now := Time.get_ticks_msec()
	if not OS.has_feature("web") or now - gesture_msec < 3000:
		toggle_fullscreen()
	else:
		fs_deadline = now + 2000

func toggle_fullscreen() -> void:
	fs_deadline = 0
	var on := Game.is_fullscreen()
	if Game.debug:
		print("CLAWD: fullscreen ", "off" if on else "on")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if on else DisplayServer.WINDOW_MODE_FULLSCREEN)

# ?debug: the menu state as CLAWD: lines (the phone tests read them)
var _dbg_page := ""
var _dbg_touch := -1
var _dbg_code := ""

func _dbg_menu_state() -> void:
	var pg := "game"
	if title != null and title.active:
		pg = title.page
	elif end_screen != null and end_screen.active:
		pg = "end"
	if pg != _dbg_page:
		_dbg_page = pg
		print("CLAWD: page ", pg)
	var tv := 1 if touch.visible else 0
	if tv != _dbg_touch:
		_dbg_touch = tv
		print("CLAWD: touch visible ", touch.visible)
	var cd: String = title.code if title != null else ""
	if cd != _dbg_code:
		_dbg_code = cd
		print("CLAWD: code ", cd)

# a window position -> game pixels of the displayed 384x216 picture (not of the whole TextureRect: a wide phone has bars)
func to_game(p: Vector2) -> Vector2:
	return (p - game_rect.position) * Vector2(W, H) / game_rect.size

# the guest was told the host is gone
func on_host_left() -> void:
	set_paused(false, true)
	if coop != null and coop.started:     # (on the wait page nothing is running yet: nothing to lock)
		Controls.locked = true
	print("CLAWD: host left")

func _physics_process(_d: float) -> void:
	if Game.test_name != "":
		return
	if Game.debug:
		_dbg_menu_state()
	if title != null and title.active:
		Controls.poll()
		title.update()
		if title.page == "wait" and coop != null and coop.started and manager.room != null:
			title.close()
			touch.suspend(false)
			Audio.stop_music()
		return
	if end_screen != null and end_screen.active:
		Controls.poll()
		end_screen.update()
		return
	if manager.room == null:
		return
	_sync_music()
	if demo_frame >= 0:
		_demo_step()
		return
	if selftest_frame >= 0:
		_selftest_step()
	if Game.debug and room != null and room.player != null and absf(room.player.x - last_logged_x) > 8.0:
		last_logged_x = room.player.x
		print("CLAWD: x=%d" % int(last_logged_x))          # lets the touch test see that the stick moved Clawd
	if paused:
		Controls.poll()
		pause_menu.update()
		return
	if bench_menu.active:
		Controls.poll()
		bench_menu.update()
		return
	manager.tick(Game.STEP)
	if Controls.pressed.get("pause", false) or Controls.pressed.get("start", false):
		set_paused(true)

# The music follows the state (the room, its fight), it is not started by events: a missed or reordered event (P2 summoned
# into a running fight, a fade still running) can no longer leave the wrong song or silence.
static func song_for(r: Room) -> String:
	var want := String(r.def.get("music", ""))
	match String(r.fight.state):
		"intro", "active":
			want = "boss"
		"reward":
			want = "toolget"
		"done":
			if want == "":
				want = "w1"
	return want

var music_auto := true                 # (a test of the audio module turns this off)

func _sync_music() -> void:
	if not music_auto:
		return
	var want := song_for(manager.room)
	if want == "":
		if Audio.music_name != "":
			Audio.stop_music(1.0)
	elif want != Audio.music_name:
		Audio.music(want)

# the fixed 180-frame script of ?selftest: run right, jump, dash, swipe
func _selftest_step() -> void:
	var f := selftest_frame
	if f >= 180:
		return
	var keys := {"right": true}
	if f >= 20 and f < 40:
		keys["jump"] = true
	if f == 60:
		keys["dash"] = true
	if f == 100 or f == 106:
		keys["attack"] = true
	Controls.script_input = keys
	selftest_frame += 1
	if selftest_frame == 180:
		Controls.script_input = null
		Audio.sfx("jump")
		var moved: float = room.player.x - selftest_x0
		if moved > 100.0:
			print("CLAWD: selftest PASS")
		else:
			print("CLAWD: selftest FAIL moved only %.1f px" % moved)
		selftest_frame = -1

# scripted demo for screenshots: run, jump, dash, swipe (--demo --shot=<prefix>)
func _demo_step() -> void:
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
	var img := get_viewport().get_texture().get_image() if Game.full_shot else game_vp.get_texture().get_image()
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
	# the picture itself (KEEP_ASPECT_CENTERED inside the TextureRect): the overlay and the pause button are placed from it
	var sc := minf(screen.size.x / W, screen.size.y / H)
	var gs := Vector2(W, H) * sc
	game_rect = Rect2(screen.position + (screen.size - gs) * 0.5, gs)
	if touch != null:
		touch.layout()
	if debug_overlay != null:
		debug_overlay.queue_redraw()
