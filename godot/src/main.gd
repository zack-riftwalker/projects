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
var shop_menu: ShopMenu
var index_menu: IndexMenu
var map_overlay: MapView                 # the map as a local overlay (MVB1-06): the world does not stop in co-op
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
	if Game.scene == "gfxprobe":                       # MVGN-01: which 2D features this renderer has (no game, no HUD)
		game_vp.add_child(GfxProbe.new())
		return
	if Game.test_name != "":
		var script = load("res://src/test/run_tests.gd")
		if script == null:
			print("TEST ", Game.test_name, " FAIL could not load run_tests.gd")
			get_tree().quit(1)
			return
		var ok: bool = await script.new(self).run(Game.test_name)
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
	shop_menu = ShopMenu.new()
	hud_layer.add_child(shop_menu)
	index_menu = IndexMenu.new()
	hud_layer.add_child(index_menu)
	map_overlay = MapView.new()
	map_overlay.back_requested.connect(func():
		map_overlay.close())
	hud_layer.add_child(map_overlay)
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
	manager.shop_requested.connect(func(r): if active_overlay() == null: shop_menu.open(r))
	manager.index_requested.connect(func(r, i): if active_overlay() == null: index_menu.open(r, r.npcs[i]))
	bench_menu.manager = manager
	bench_menu.rest_chosen.connect(func():
		manager.rest(bench_room, bench_idx))
	bench_menu.travel_chosen.connect(func(id): manager.travel(id))
	manager.room_changed.connect(func(r): hud.set_room(r))
	pause_menu.manager = manager
	map_overlay.manager = manager
	end_screen = EndScreen.new()
	end_screen.done.connect(_back_to_title)
	hud_layer.add_child(end_screen)
	manager.end_requested.connect(func():
		if not end_screen.active:
			end_screen.open(String(manager.room.def.get("end", "to be continued"))))
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
		elif Game.scene.begins_with("reviewer:"):       # screenshot helper: THE REVIEWER in the telegraph of an attack (reviewer:<lunge|comments|review|nitpick|shove|phase>)
			manager.swap_to("R10")
			var p2 = manager.player
			p2.x = 120.0
			p2.y = 166.0
			p2.inv = 999.0
			var r2: Room = manager.room
			r2._start_intro()
			r2.fight.t = 0.0
			r2._begin_fight()
			var rb = r2.boss
			rb.face = -1.0
			var kinds := {"lunge": "lunge_tel", "comments": "comments_tel", "review": "review", "nitpick": "nitpick_tel", "shove": "shove_tel", "phase": "phase"}
			rb.set_state(kinds.get(Game.scene.substr(9), "idle"), 5.0)
		elif Game.scene == "shop":                      # screenshot helper: the npm registry stall and its menu
			Game.tokens = 95
			manager.swap_to("D04")
			var p4 = manager.player
			p4.x = 26.0 * 16 - 5.0
			p4.y = 166.0
			shop_menu.open(manager.room)
		elif Game.scene.begins_with("merge:"):          # screenshot helper: MERGE CONFLICT in an attack (merge:<markers|lunge|revert>)
			manager.swap_to("D05")
			var p3 = manager.player
			p3.x = 150.0
			p3.y = 166.0
			p3.inv = 999.0
			var r3: Room = manager.room
			r3._start_intro()
			r3.fight.t = 0.0
			r3._begin_fight()
			var mb = r3.boss
			mb.busy = 99.0
			var mk := Game.scene.substr(6)
			if mk == "markers":
				mb._start_markers()
				mb.band_state = 2
				mb.band_t = 0.5
				mb.safe_band = 1
			elif mk == "lunge":
				mb.act(mb.heads[1], "lunge")
				mb.heads[1].t = 0.3
			elif mk == "revert":
				mb.hit(999, 0.0, 0.0, "swipe", mb.hurtboxes()[0])
				mb.heads[0].rv = 5.0
		elif Game.scene.begins_with("bossp3:"):         # screenshot helper: a 4B-3 boss in its last phase (bossp3:<N09|N15|N22>[:<hp fraction>])
			var bp := Game.scene.substr(7).split(":")
			Game.flags["ability:ssh"] = true
			manager.swap_to(bp[0])
			var pp = manager.player
			pp.x = 250.0
			pp.y = 166.0
			pp.inv = 999.0
			var rr: Room = manager.room
			rr._start_intro()
			rr.fight.t = 0.0
			rr._begin_fight()
			var bb = rr.boss
			bb.hpf = float(bb.max_hp) * (float(bp[1]) if bp.size() > 1 else 0.2)
			bb.hp = ceili(bb.hpf)
			bb.on_damage()
		elif Game.scene == "chase":                     # screenshot helper: N17 with the RST line running (MVB3-05)
			manager.swap_to("N17", Vector2(3.0 * 16.0, 36.0 * 16.0))
			var rc: Room = manager.room
			rc.time = 20.0
			rc.ch_t0 = 8.0
			var pc = manager.player
			pc.x = 3.0 * 16.0 + 3.0
			pc.y = 36.0 * 16.0
			pc.inv = 999.0
		elif Game.scene == "loss":                      # screenshot helper: N12 with a packet about to be lost / lost (MVB3-05)
			manager.swap_to("N12", Vector2(24.0 * 16.0, 7.0 * 16.0))
			manager.player.inv = 999.0
			var rl: Room = manager.room
			for m in rl.plats:
				if m.get("packet", false) and int(m.j) % 3 == 2:
					var pa: Dictionary = m.path
					var span: float = float(pa.n) * float(pa.every)
					var prev := -1e9
					for k in range(int(span * 100.0)):
						var tt := float(k) / 100.0
						var nx: float = float(pa.xa) + fposmod(tt + float(m.j) * float(pa.every), span) * float(pa.speed) + float(pa.w) / 2.0
						if k > 0 and prev < 440.0 and nx >= 440.0 and nx <= float(pa.xb) + float(pa.w):
							rl.time = tt - 0.3                       # about to be lost: it flickers
							break
						prev = nx
					break
		elif Game.scene == "loop3":                     # screenshot helper: T09 on its third pass, the `break;` key shown (MV5A-11)
			Game.loop_iter = {"T09": 3}
			manager.swap_to("T09", Vector2(30.0 * 16.0, 14.0 * 16.0), null, true)
			manager.player.inv = 999.0
		elif Game.scene.begins_with("roomat:"):       # screenshot helper: stand in a room at a place (roomat:<id>:<x>:<y>)
			var ra := Game.scene.substr(7).split(":")
			manager.swap_to(ra[0], Vector2(float(ra[1]), float(ra[2])))
		elif Game.scene.begins_with("look:"):         # screenshot helper: a NETWORK room in a chosen mood (look:<room>:<mood>[:<k>])
			var la := Game.scene.substr(5).split(":")
			manager.swap_to(la[0])
			manager.room.look.set_target(la[1], float(la[2]) if la.size() > 2 else 1.0, true)
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
		elif Game.scene == "logs":                     # screenshot helper: the Logs page with some signs read and memories found
			for id in ["R01", "R02", "R08", "D01", "D04", "H03"]:
				for n in range(Game.rooms_meta.rooms[id].get("signs", []).size()):
					Game.flags["log:%s:%d" % [id, n]] = true
			for id in ["R01", "R06", "D01", "H12"]:
				Game.flags["item:%s:f0" % id] = true
			Game.flags["page:1"] = true
			Game.changelog_lines = ["changelog: something in /proc/heap answers to curl"]
			set_paused(true)
			pause_menu.page = "logs"
			pause_menu.logs_view.open()
		elif Game.scene in ["map", "mapworld", "mapheap"]:     # screenshot helper: the map page with every room committed and every zone indexed (mapworld: the world view)
			for id in Game.rooms_meta.rooms:
				if not Game.is_lab(id):
					Game.flags["mapped:" + id] = true
					Game.flags["map:" + Game.zone_of(id)] = true
			manager.swap_to("H05" if Game.scene == "mapheap" else "R03")
			manager.player.x = 1200.0 if Game.scene != "mapheap" else 300.0
			Game.partner = {"room": "D04", "x": 200.0, "y": 100.0}
			set_paused(true)
			pause_menu.page = "map"
			pause_menu.map_view.open()
			if Game.scene == "mapworld":
				pause_menu.map_view.set_world(true)
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

# the menus that stand over the running game (the bench, the stall, the cartographer's index, ...): at most one is open
func overlays() -> Array:
	return [bench_menu, shop_menu, index_menu, map_overlay]

func active_overlay():
	for o in overlays():
		if o != null and o.active:
			return o
	return null

func open_bench(r: Room, i: int) -> void:
	bench_room = r
	bench_idx = i
	bench_menu.open()

var pause_changed_at := -10.0          # when this player last pressed pause (the host's snapshots wait a moment before correcting)

func set_paused(v: bool, remote := false) -> void:
	paused = v
	if not remote:
		pause_changed_at = Net.now()
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
	_map_drag(event)
	if not paused and active_overlay() == null and hud != null and manager != null:         # a tap on a ping arrow says "seen"
		var tp2 := Vector2.ZERO
		var th2 := false
		if event is InputEventScreenTouch and event.pressed:
			tp2 = event.position
			th2 = true
		elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			tp2 = event.position
			th2 = true
		if th2 and not (touch.visible and touch.claims(tp2)):
			hud.ping_tap(to_game(tp2))
	# a tap on a pause option
	if paused or active_overlay() != null:
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
			var mv0 = _map_in_use()
			if mv0 != null:
				mv0.press_at(gp)
			if paused:
				pause_menu.tap(gp)
			else:
				active_overlay().tap(gp)

# the map page that is on screen now (the overlay, or the pause menu's Map page), or null
func _map_in_use():
	if map_overlay != null and map_overlay.active:
		return map_overlay
	if paused and pause_menu.page == "map":
		return pause_menu.map_view
	if paused and pause_menu.page == "logs":
		return pause_menu.logs_view
	if bench_menu.active and bench_menu.page == "logs":
		return bench_menu.logs_view
	return null

# dragging the map with a finger or the mouse
func _map_drag(event: InputEvent) -> void:
	var mv = _map_in_use()
	if mv == null:
		return
	var k := float(W) / game_rect.size.x
	if event is InputEventScreenDrag:
		mv.drag(event.relative * k)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and event.device != InputEvent.DEVICE_ID_EMULATION:
		mv.drag(event.relative * k)
	elif (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed):
		mv.drag_end()

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
	if Game.test_name != "" or Game.scene == "gfxprobe":
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
	var ov = active_overlay()
	if ov != null:
		Controls.poll()
		ov.update()
		if not Net.is_active() or manager.player == null:
			return                              # alone the world waits while a menu is open
		# co-op: the partner's world goes on (the host simulates it); this body stands still and takes no input
		manager.player.in_menu = true
		manager.tick(Game.STEP)
		if manager.player != null:
			manager.player.in_menu = false
			if manager.player.dead:              # hurt to death while choosing: the menu goes away
				for o in overlays():
					if o.active:
						o.close()
		return
	manager.tick(Game.STEP)
	_map_button()
	if Controls.pressed.get("pause", false) or Controls.pressed.get("start", false):
		set_paused(true)

# The map button opens the overlay when it is let go; held for QUICK_PIN_T it drops a TODO pin at the player instead (and then opens nothing).
const QUICK_PIN_T := 0.6
var map_hold := -1.0
var map_quick := false

func _map_button() -> void:
	if manager.player == null or manager.player.dead:
		map_hold = -1.0
		return
	if Controls.pressed.get("map", false):
		map_hold = 0.0
		map_quick = false
	if map_hold < 0.0:
		return
	if Controls.down.get("map", false):
		map_hold += Game.STEP
		if map_hold >= QUICK_PIN_T and not map_quick:
			map_quick = true
			quick_pin()
	else:
		if not map_quick:
			open_map()
		map_hold = -1.0

func open_map() -> void:
	if active_overlay() != null or paused:
		return
	map_overlay.open()
	Audio.sfx("uiOk")

# a TODO pin at the player's feet (MVB1-08 puts it in the shared list)
func quick_pin() -> void:
	var r := manager.room
	var p := manager.player
	if r == null or p == null:
		return
	if Game.pin_add("TODO", r.id, p.x + p.w / 2.0, p.y + p.h / 2.0):
		r.pop(p.x + 5.0, p.y - 14.0, "pinned", Game.COL.gold, true)
		Audio.sfx("uiOk")

# The music follows the state (the room, its fight), it is not started by events: a missed or reordered event (P2 summoned
# into a running fight, a fade still running) can no longer leave the wrong song or silence.
static func song_for(r: Room) -> String:
	var want := String(r.def.get("music", ""))
	match String(r.fight.state):
		"intro", "active":
			want = String(r.def.boss.get("music", "boss")) if r.def.has("boss") else "boss"
		"reward":
			want = "toolget"
		"done":
			if want == "":
				want = "w%d" % int(r.def.get("world", 1))
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
