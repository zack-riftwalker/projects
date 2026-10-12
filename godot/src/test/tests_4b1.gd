extends RefCounted
class_name Tests4b1
# Unit tests of phase 4B-1 (the map, the cartographer and the small systems). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["worlddigest", "mapdata", "tree", "mappage", "mapoverlay", "changelog", "travelp2", "logs", "lostagents", "decor", "terminals"]

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String) -> bool:
	match name:
		"worlddigest": return t_worlddigest()
		"mapdata": return t_mapdata()
		"tree": return t_tree()
		"mappage": return await t_mappage()
		"mapoverlay": return t_mapoverlay()
		"changelog": return t_changelog()
		"travelp2": return t_travelp2()
		"logs": return t_logs()
		"lostagents": return t_lostagents()
		"decor": return await t_decor()
		"terminals": return await t_terminals()
	return report(name, false, "unknown test")

# one small checker: chk.call(label, cond)
func checker() -> Dictionary:
	return {"ok": true, "info": ""}

func fail(res: Dictionary, label: String) -> void:
	res.ok = false
	res.info += " BAD:" + label

func t_worlddigest() -> bool:
	Game.persist = false
	Game.flags = {}
	var res := checker()
	var e0 := Game.world_digest()
	Game.flags["boss:NULL"] = true
	Game.flags["log:R08:0"] = true
	Game.flags["mapped:R01"] = true
	var a := Game.world_digest()
	if a == e0:
		fail(res, "adding changes")
	Game.flags = {}
	Game.flags["mapped:R01"] = true
	Game.flags["boss:NULL"] = true
	Game.flags["log:R08:0"] = true
	if Game.world_digest() != a:
		fail(res, "order")
	Game.flags["room:R01:visited"] = true
	Game.flags["item:R01:3"] = true
	Game.flags["bench:R01"] = true
	if Game.world_digest() != a:
		fail(res, "a non-world flag changed it")
	Game.flags["log:R08:1"] = true
	if Game.world_digest() == a:
		fail(res, "a world flag did not change it")
	Game.flags["log:R08:1"] = false
	if Game.world_digest() != a:
		fail(res, "a cleared flag counts")
	var wf := Game.world_flags()
	if wf != ["boss:NULL", "log:R08:0", "mapped:R01"]:
		fail(res, "list " + str(wf))
	Game.flags = {}
	return report("worlddigest", res.ok, res.info)

func new_manager() -> RoomManager:
	var m := RoomManager.new(main.world, null)
	main.add_child(m)
	m.start_game()
	return m

func t_mapdata() -> bool:
	Game.persist = false
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# zones and secrets (MVB1-02)
	var zones := {}
	for z in Game.ZONES:
		zones[z.id] = true
	var secrets: Array = []
	for id in Game.rooms_meta.rooms:
		var m: Dictionary = Game.rooms_meta.rooms[id]
		if not zones.has(Game.zone_of(id)):
			fail(res, "zone of " + id)
		if bool(m.get("secret", false)):
			secrets.append(id)
		if Game.is_lab(id) and Game.zone_of(id) == "src":
			fail(res, "lab room in src " + id)
	secrets.sort()
	if secrets != ["D07", "H12", "H13", "H14", "H15", "H16", "R06", "R12", "R13", "R15"]:
		fail(res, "secrets " + str(secrets))
	# staged vs committed
	var mgr := new_manager()
	mgr.swap_to("R02")
	if Game.is_mapped("R01") or Game.is_mapped("R02"):
		fail(res, "committed before a rest")
	if not (Game.staged_rooms().has("R01") and Game.staged_rooms().has("R02")):
		fail(res, "staged " + str(Game.staged_rooms()))
	mgr.swap_to("R08")
	mgr.rest(mgr.room, 0)
	if not (Game.is_mapped("R01") and Game.is_mapped("R02") and Game.is_mapped("R08")):
		fail(res, "rest commits the walked rooms")
	if not Game.staged_rooms().is_empty():
		fail(res, "nothing stays staged")
	# the view needs the index
	var v: Dictionary = Game.map_view("src")
	if not (v.outline.is_empty() and v.filled.is_empty()):
		fail(res, "no map without the index")
	Game.flags["map:src"] = true
	v = Game.map_view("src")
	var want_outline: Array = []
	for id in Game.rooms_meta.rooms:
		if Game.zone_of(id) == "src" and not Game.is_secret(id) and not Game.is_lab(id):
			want_outline.append(id)
	want_outline.sort()
	var got_outline: Array = v.outline.duplicate()
	got_outline.sort()
	if got_outline != want_outline:
		fail(res, "outline " + str(got_outline))
	var got_filled: Array = v.filled.duplicate()
	got_filled.sort()
	if got_filled != ["R01", "R02", "R08"]:
		fail(res, "filled " + str(got_filled))
	if Game.map_view("dep").outline.size() != 0:
		fail(res, "another zone stays empty")
	# secret rooms: only once found
	if v.outline.has("R06") or v.filled.has("R06"):
		fail(res, "uncommitted secret shown")
	Game.flags["mapped:R06"] = true
	v = Game.map_view("src")
	if not v.filled.has("R06") or v.outline.has("R06"):
		fail(res, "committed secret: in filled, not in outline")
	if Game.zone_counts("src")[0] != 3:
		fail(res, "a secret never counts: %s" % str(Game.zone_counts("src")))
	# a lab room is never staged or committed
	if Game.commit_rooms(["Z01"]) != 0:
		fail(res, "lab committed")
	mgr.queue_free()
	# migration of an old save
	Game.fresh()
	var path := "user://t_mapdata_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "flags": {"room:H01:visited": true, "room:H02:visited": true, "room:H04:visited": true, "room:H03:visited": true, "room:Z01:visited": true}}))
	f.close()
	var old_path := Game.save_path
	Game.save_path = path
	Game.load_save()
	Game.save_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for id in ["H01", "H02", "H03", "H04"]:
		if not Game.is_mapped(id):
			fail(res, "migrated " + id)
	if not Game.owns_map("heap") or Game.owns_map("lab") or Game.is_mapped("Z01") or not Game.flag("map:migrated"):
		fail(res, "migration flags")
	var heap: Dictionary = Game.map_view("heap")
	if heap.filled.size() != 4:
		fail(res, "migrated view " + str(heap.filled))
	Game.fresh()
	return report("mapdata", res.ok, res.info)

func new_room(room_id: String) -> Room:
	var room := Room.new()
	main.world.add_child(room)
	room.load_room(room_id)
	room.build_nodes()
	return room

# MVB1-04: the cartographer. R08's index is free, D01's costs 40 tokens; an owned index cannot be bought again; [up] next to it opens the menu.
func t_tree() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var menu := IndexMenu.new()
	main.add_child(menu)
	var r8 := new_room("R08")
	if r8.npcs.size() != 1 or r8.npcs[0].zone != "src" or r8.npcs[0].price != 0:
		fail(res, "R08 npc")
	else:
		menu.open(r8, r8.npcs[0])
		if menu.rows()[0] != "take the index of ~/src":
			fail(res, "free row: " + str(menu.rows()))
		Game.tokens = 0
		if not menu.buy() or not Game.owns_map("src") or Game.tokens != 0:
			fail(res, "free index")
		if menu.rows() != ["Back"]:
			fail(res, "owned rows " + str(menu.rows()))
		menu.close()
	var d01 := new_room("D01")
	menu.open(d01, d01.npcs[0])
	if d01.npcs[0].price != 40 or menu.rows()[0] != "index ~/node_modules — 40 tokens":
		fail(res, "D01 offer " + str(menu.rows()))
	Game.tokens = 39
	if menu.buy() or Game.owns_map("dep") or Game.tokens != 39 or menu.msg != "not enough tokens":
		fail(res, "39 tokens buy nothing")
	Game.tokens = 45
	if not menu.buy() or not Game.owns_map("dep") or Game.tokens != 5:
		fail(res, "buy with 45: tokens %d" % Game.tokens)
	if menu.buy() or Game.tokens != 5:
		fail(res, "an owned index costs nothing")
	menu.close()
	# [up] next to it opens the menu; far away it does not
	var opened := [0]
	d01.index_requested.connect(func(_i): opened[0] += 1)
	var p = d01.player
	var n: Dictionary = d01.npcs[0]
	p.x = n.x + 8.0 - p.w / 2.0
	p.y = n.y - p.h
	p.vx = 0.0
	p.vy = 0.0
	for f in range(8):
		Controls.script_input = {"up": f == 4}
		Controls.poll()
		d01.step(Game.STEP)
	Controls.script_input = null
	if opened[0] != 1:
		fail(res, "[up] next to it opened %d times" % opened[0])
	p.x += 200.0
	for f in range(4):
		Controls.script_input = {"up": f == 2}
		Controls.poll()
		d01.step(Game.STEP)
	Controls.script_input = null
	if opened[0] != 1:
		fail(res, "far away it opened too")
	# the paper strip grows by a line every 2 s while somebody is within 10 tiles
	p.x = n.x - 40.0
	p.y = n.y - p.h
	var s0: int = n.strip
	for f in range(130):
		p.x = n.x - 40.0
		p.y = n.y - p.h
		p.vx = 0.0
		p.vy = 0.0
		d01.step(Game.STEP)
	if n.strip <= s0:
		fail(res, "the strip did not grow (%d)" % n.strip)
	menu.queue_free()
	return report("tree", res.ok, res.info)

# the draw of a node happens when the frame ends: wait for it
func frames(n := 2) -> void:
	for i in range(n):
		await main.get_tree().process_frame

# MVB1-05: the map page. Every zone, zone and world view, with everything committed and indexed: it draws, every room is inside the map area,
# zoom and pan move the transform, a secret room appears only once committed, lab rooms never, no index means a line that says so.
func t_mappage() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.partner = {}
	var res := checker()
	var mv := MapView.new()
	main.add_child(mv)
	await frames(1)
	# nothing indexed: the line that says so
	mv.open("heap")
	if not mv.rooms_in_view().is_empty() or mv.empty_text() != "no index for /proc/heap":
		fail(res, "no index text: " + mv.empty_text())
	# a committed room of a zone without its index is not shown (the map has to be found)
	Game.flags["mapped:H01"] = true
	if not mv.rooms_in_view().is_empty():
		fail(res, "committed without the index")
	for id in Game.rooms_meta.rooms:
		if not Game.is_lab(id):
			Game.flags["map:" + Game.zone_of(id)] = true
	# a secret room: only after mapped:
	mv.open("src")
	if mv.rooms_in_view().has("R06"):
		fail(res, "uncommitted secret in view")
	Game.flags["mapped:R06"] = true
	if not mv.rooms_in_view().has("R06"):
		fail(res, "committed secret not in view")
	Game.flags.erase("mapped:R06")
	for id in Game.rooms_meta.rooms:
		if not Game.is_lab(id):
			Game.flags["mapped:" + id] = true
	var area := MapView.AREA.grow(1.0)
	for world in [false, true]:
		for z in Game.ZONES:
			if z.id == "lab":
				continue
			mv.open(z.id)
			mv.set_world(world)
			var ids: Array = mv.rooms_in_view()
			for id in ids:
				if Game.is_lab(id):
					fail(res, "lab room in view " + id)
				if Game.zone_of(id) != z.id and not world:
					fail(res, "foreign room in the zone view " + id)
				var rr := mv.rect_of(id)
				if not area.encloses(rr):
					fail(res, "%s/%s room %s outside: %s" % [z.id, "world" if world else "zone", id, str(rr)])
			var d0: int = mv.draws
			mv.queue_redraw()
			mv.canvas.queue_redraw()
			await frames(2)
			if ids.size() > 0 and mv.draws <= d0:
				fail(res, "did not draw " + z.id)
	# zoom and pan, by calls and by script input
	mv.open("heap")
	var s0: float = mv.scale_px
	mv.zoom(1.5)
	if absf(mv.scale_px - s0 * 1.5) > 0.001 and mv.scale_px < 4.0:
		fail(res, "zoom in")
	mv.zoom(1.0 / 1.5)
	var c0: Vector2 = mv.center
	mv.pan_px(Vector2(24, 0))
	if mv.center == c0:
		fail(res, "pan")
	mv.open("heap")
	c0 = mv.center
	Controls.script_input = {"right": true}
	Controls.poll()
	mv.update()
	Controls.script_input = null
	Controls.poll()
	if mv.center.x <= c0.x:
		fail(res, "pan by the arrow key")
	var wcount: int = mv.rooms_in_view().size()
	Controls.script_input = {"jump": true}
	Controls.poll()
	mv.update()
	Controls.script_input = null
	Controls.poll()
	if not mv.world or mv.rooms_in_view().size() <= wcount:
		fail(res, "[jump] switches to the world view")
	# the partner's line and doors that must not be drawn
	if MapView.door_visible("R01", {"id": "x", "side": "W", "a": 9, "b": 12, "to": "G16:E"}):
		fail(res, "a door to a room that does not exist")
	Game.flags.erase("mapped:R06")
	if MapView.door_visible("R01", Game.rooms_meta.rooms.R01.doors[0]):
		fail(res, "a door into an uncommitted secret room")
	Game.flags["mapped:R06"] = true
	if not MapView.door_visible("R01", Game.rooms_meta.rooms.R01.doors[0]):
		fail(res, "a door into a committed secret room")
	# pins and pings (MVB1-08): the crosshair is the middle of the map area
	mv.open("heap")
	var h1: Dictionary = Game.rooms_meta.rooms.H01
	mv.center = Vector2(float(h1.origin[0]) + 10.0, float(h1.origin[1]) + 8.0)
	if mv.crosshair_room().is_empty() or mv.crosshair_room().id != "H01":
		fail(res, "crosshair room " + str(mv.crosshair_room()))
	Game.pins = []
	mv.press_pin()
	if not mv.armed or Game.pins.size() != 0:
		fail(res, "the first press arms")
	mv.press_pin()
	if Game.pins.size() != 1 or Game.pins[0].kind != "TODO" or Game.pins[0].room != "H01" or Game.pins[0].by != "P1":
		fail(res, "the second press places: " + str(Game.pins))
	mv.press_pin()
	if Game.pins.size() != 0:
		fail(res, "a press on a pin takes it away")
	for i in range(30):
		Game.pin_add("?", "H01", 10.0 + i, 10.0)
	if Game.pins.size() != Game.PIN_MAX or int(Game.pins[0].x) != 16:
		fail(res, "the 25th removes the oldest: %d, first x %s" % [Game.pins.size(), str(Game.pins[0].x)])
	Game.pins = []
	if Game.pin_add("TODO", "Z01", 10.0, 10.0) and Game.pins.size() > 0 and Game.pins[0].room == "Z01":
		pass                                              # (a lab room is not offmap: allowed)
	Game.pins = []
	Game.rooms_meta.rooms.H01["offmap"] = true
	if Game.pin_add("TODO", "H01", 10.0, 10.0) or Game.ping_add("help", "H01", 10.0, 10.0):
		fail(res, "pin or ping in an offmap room")
	Game.rooms_meta.rooms.H01.erase("offmap")
	mv.press_ping()
	if not mv.ping_choosing:
		fail(res, "ping chooser")
	mv.send_ping(2)
	if Game.pings.size() != 1 or Game.pings[0].kind != "help" or mv.ping_choosing:
		fail(res, "the ping: " + str(Game.pings))
	Game.pings = []
	mv.queue_free()
	Game.fresh()
	return report("mappage", res.ok, res.info)

# a whole Main (menus, manager, first room) that this test steps by hand: Main skips its loop while a test name is set
func make_main() -> Control:
	Game.persist = false
	Game.net_role = ""
	Game.play_now = true
	Game.fresh()
	var saved := Game.test_name
	Game.test_name = ""
	var m: Control = load("res://src/main.gd").new()
	main.add_child(m)
	Game.test_name = saved
	return m

func step_main(m: Control, keys: Dictionary, n := 1) -> void:
	var saved := Game.test_name
	Game.test_name = ""
	for i in range(n):
		Controls.script_input = keys
		m._physics_process(Game.STEP)
	Controls.script_input = null
	Game.test_name = saved

# MVB1-06: alone, the world waits while the overlay is open; the map button opens it when let go, and held 0.6 s it pins instead
func t_mapoverlay() -> bool:
	var res := checker()
	var m := make_main()
	var room: Room = m.manager.room
	step_main(m, {}, 5)
	var t0: float = room.time
	step_main(m, {}, 10)
	if room.time <= t0:
		fail(res, "the world runs when nothing is open")
	# a short press and release opens the overlay
	step_main(m, {"map": true}, 4)
	if m.map_overlay.active:
		fail(res, "opened on the press, not the release")
	step_main(m, {}, 2)
	if not m.map_overlay.active:
		fail(res, "the map button did not open the overlay")
	t0 = room.time
	step_main(m, {}, 20)
	if room.time != t0:
		fail(res, "the world moved while the map is open (alone)")
	if m.manager.player.in_menu:
		pass
	# [dash] closes it and never pins
	var pins0: int = Game.pins.size()
	step_main(m, {"dash": true}, 2)
	step_main(m, {}, 2)
	if m.map_overlay.active:
		fail(res, "dash did not close it")
	if Game.pins.size() != pins0:
		fail(res, "dash pinned")
	# the map action again closes it
	step_main(m, {"map": true}, 3)
	step_main(m, {}, 2)
	if not m.map_overlay.active:
		fail(res, "reopen")
	step_main(m, {"map": true}, 3)
	step_main(m, {}, 2)
	if m.map_overlay.active:
		fail(res, "the map action closes it")
	# held for 0.6 s: a TODO pin, and no overlay
	step_main(m, {"map": true}, 40)
	step_main(m, {}, 3)
	if m.map_overlay.active:
		fail(res, "a held press opened the map")
	if Game.pins.size() != pins0 + 1 or String(Game.pins[Game.pins.size() - 1].kind) != "TODO":
		fail(res, "the held press did not drop a TODO pin")
	m.queue_free()
	Game.play_now = false
	Game.fresh()
	return report("mapoverlay", res.ok, res.info)

# MVB1-07: `?` marks on obstacles that are not passed, and the terminal's changelog line
func t_changelog() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	Game.flags["map:heap"] = true
	Game.flags["mapped:H02"] = true
	var marks: Array = Game.obstacle_marks("H02")
	if marks.size() != 1 or marks[0].ability != "bash" or marks[0].y != 0 or marks[0].x < 130 or marks[0].x > 133:
		fail(res, "H02 ceiling crack: " + str(marks))
	Game.flags["crack:H02:131:0"] = true
	if not Game.obstacle_marks("H02").is_empty():
		fail(res, "a broken crack stays marked")
	# H03: the firewall is marked, nothing next to the dead code (31, 4..7)
	var h3: Array = Game.obstacle_marks("H03")
	if h3.size() != 1 or h3[0].ability != "ssh":
		fail(res, "H03 marks " + str(h3))
	for mk in Game.obstacle_marks("H03"):
		if absi(int(mk.x) - 31) <= 2 and int(mk.y) >= 2 and int(mk.y) <= 9:
			fail(res, "a mark next to the dead code")
	# a lever of another kind: H01's ring (curl); the marks are not drawn for a room that is not committed (the map decides), but they exist
	var h1: Array = Game.obstacle_marks("H01")
	if h1.size() != 1 or h1[0].ability != "curl":
		fail(res, "H01 ring " + str(h1))
	# the line: curl is gained, H01 is committed, rest at H03 (a terminal)
	Game.flags["mapped:H01"] = true
	Game.tools["curl"] = true
	var mgr := new_manager()
	mgr.swap_to("H03")
	mgr.rest(mgr.room, 0)
	if mgr.changelog_shown != ["changelog: something in /proc/heap answers to curl"]:
		fail(res, "the line: " + str(mgr.changelog_shown))
	if not Game.flag("changelog:curl"):
		fail(res, "flag")
	mgr.rest(mgr.room, 0)
	if not mgr.changelog_shown.is_empty():
		fail(res, "told twice " + str(mgr.changelog_shown))
	# an ability that nothing waits for: no line, the flag is still set
	Game.tools["opus"] = true
	mgr.rest(mgr.room, 0)
	if not mgr.changelog_shown.is_empty() or not Game.flag("changelog:opus"):
		fail(res, "an ability with no obstacle")
	# a bench that is not a terminal says nothing
	Game.tools["bash"] = true
	mgr.swap_to("R03")
	mgr.rest(mgr.room, 0)
	if Game.flag("changelog:bash") or not mgr.changelog_shown.is_empty():
		fail(res, "only a terminal says it")
	mgr.queue_free()
	Game.fresh()
	return report("changelog", res.ok, res.info)

# MVB1-09: the Travel page's first line goes to the terminal in the partner's zone; the player moves, nobody is pulled
func t_travelp2() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	Game.flags["bench:H03"] = true
	Game.flags["bench:R08"] = true
	var mgr := new_manager()
	mgr.swap_to("R08")
	var menu := BenchMenu.new()
	main.add_child(menu)
	menu.manager = mgr
	var chosen := [""]
	menu.travel_chosen.connect(func(id): chosen[0] = id)
	Game.partner = {"room": "H05", "x": 100.0, "y": 100.0}
	menu.open()
	menu.choose(menu.options().find("Travel"))
	var o: Array = menu.options()
	if o.is_empty() or o[0] != "→ P2 (/proc/heap)":
		fail(res, "first line: " + str(o))
	menu.choose(0)
	if chosen[0] != "H03":
		fail(res, "chose " + chosen[0])
	# the partner in the same zone: no such line
	Game.partner = {"room": "R03", "x": 100.0, "y": 100.0}
	menu.open()
	menu.choose(menu.options().find("Travel"))
	o = menu.options()
	if o.is_empty() or String(o[0]).begins_with("→"):
		fail(res, "a line for a partner in the same zone: " + str(o))
	# a partner in a zone where this player never rested at a terminal: no line either
	Game.partner = {"room": "D03", "x": 100.0, "y": 100.0}
	menu.open()
	menu.choose(menu.options().find("Travel"))
	if String(menu.options()[0]).begins_with("→"):
		fail(res, "a line to a zone without a rested terminal")
	# alone: none
	Game.partner = {}
	menu.open()
	menu.choose(menu.options().find("Travel"))
	if String(menu.options()[0]).begins_with("→"):
		fail(res, "a line when alone")
	# on the guest's page the partner is P1
	Game.net_role = "guest"
	Game.partner = {"room": "H05", "x": 100.0, "y": 100.0}
	menu.open()
	menu.choose(menu.options().find("Travel"))
	if String(menu.options()[0]) != "→ P1 (/proc/heap)":
		fail(res, "guest line " + String(menu.options()[0]))
	Game.net_role = ""
	Game.partner = {}
	menu.queue_free()
	mgr.queue_free()
	Game.fresh()
	return report("travelp2", res.ok, res.info)

func logs_text(lv: LogsView) -> String:
	var out := ""
	for l in lv.lines:
		out += String(l.text) + "\n"
	return out

# stand next to sign n of a room for a step: reading it
func read_sign(room: Room, n: int) -> void:
	var p = room.player
	var sg: Dictionary = room.signs[n]
	p.x = float(sg.x) - p.w / 2.0
	p.y = float(sg.y) - p.h
	p.vx = 0.0
	p.vy = 0.0
	Controls.script_input = {}
	Controls.poll()
	room.step(Game.STEP)

# MVB1-10: reading a sign is remembered (a world flag) and listed by zone; a memory fragment shows its line and is listed too; the lab is skipped
func t_logs() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var lv := LogsView.new()
	main.add_child(lv)
	lv.open()
	if not logs_text(lv).contains("nothing logged yet"):
		fail(res, "empty page")
	var z := new_room("Z01")
	read_sign(z, 0)
	if not Game.flag("log:Z01:0"):
		fail(res, "Z01 sign flag")
	z.queue_free()
	var r8 := new_room("R08")
	read_sign(r8, 0)
	if not Game.flag("log:R08:0"):
		fail(res, "R08 sign flag")
	lv.open()
	var txt := logs_text(lv)
	if not txt.contains("THE SOURCE TREE") or not txt.contains("Next door: the ledges go up"):
		fail(res, "R08 sign not listed under THE SOURCE TREE: " + txt.left(200))
	if txt.contains("LAB") or txt.contains("lab:") or txt.contains("waiting for a"):
		fail(res, "a lab sign is listed")
	r8.queue_free()
	# a memory fragment: the line under its pop, and in the list
	var r6 := new_room("R06")
	var spark = null
	for it in r6.items:
		if it.kind == "spark":
			spark = it
	if spark == null:
		fail(res, "R06 has no fragment")
	else:
		r6.collect(spark)
		if r6.memory.text != "03:02 — an old room, left in on purpose. the lamp was still on.":
			fail(res, "memory line " + str(r6.memory.text))
		lv.open()
		var t2 := logs_text(lv)
		if not t2.contains("memories") or not t2.contains("the lamp was still on"):
			fail(res, "memory not listed: " + t2.left(300))
	r6.queue_free()
	# MVB1-12: a logbook page: picked up by touch (the item path), its flag is page:1, the text is listed under logbook
	Game.flags["boss:LEAK"] = true                          # (the heap is dry: no water over the page)
	var h15 := new_room("H15")
	var page_it = null
	for it in h15.items:
		if it.kind == "page":
			page_it = it
	if page_it == null:
		fail(res, "H15 has no page")
	else:
		var pp = h15.player
		pp.x = float(page_it.x) - 5.0
		pp.y = float(page_it.y) - 5.0
		pp.vx = 0.0
		pp.vy = 0.0
		Controls.script_input = {}
		Controls.poll()
		h15.step(Game.STEP)
		if not Game.flag("page:1"):
			fail(res, "touching the page did not collect it")
		lv.open()
		var t3 := logs_text(lv)
		if not t3.contains("logbook") or not t3.contains("15:25  relay #4 clicked twice. nothing found."):
			fail(res, "logbook not listed: " + t3.left(300))
	h15.queue_free()
	# the changelog lines are listed too
	Game.changelog_lines = ["changelog: something in /proc/heap answers to curl"]
	lv.open()
	if not logs_text(lv).contains("answers to curl"):
		fail(res, "changelog not listed")
	# scrolling stays inside the page
	lv.scroll_by(99999.0)
	if lv.scroll > lv.max_scroll() + 0.01:
		fail(res, "scroll past the end")
	lv.scroll_by(-99999.0)
	if lv.scroll != 0.0:
		fail(res, "scroll above the top")
	lv.queue_free()
	Game.fresh()
	return report("logs", res.ok, res.info)

# MVB1-11: a swipe or a dash frees the agent in a jar, walking into it does not; four freed agents widen the context window, eight widen it again
func t_lostagents() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var room := new_room("D07")
	if room.jars.size() != 1:
		fail(res, "D07 has no jar")
		return report("lostagents", false, res.info)
	var jar: Dictionary = room.jars[0]
	for e in room.ents:
		e.queue_free()
	room.ents.clear()
	var p = room.player
	# walking into it: nothing
	p.x = float(jar.x) - 60.0
	p.y = float(jar.y) - p.h
	p.vx = 0.0
	p.vy = 0.0
	for f in range(70):
		Controls.script_input = {"right": true}
		Controls.poll()
		room.step(Game.STEP)
	if Game.flag("agent:D07") or room.jars[0].broken:
		fail(res, "walking into the jar freed it")
	if p.x + p.w < float(jar.x) - 2.0:
		fail(res, "the player did not reach the jar (x %.0f)" % p.x)
	# a swipe next to it
	p.x = float(jar.x) - 22.0
	p.y = float(jar.y) - p.h
	p.vx = 0.0
	p.vy = 0.0
	p.face = 1.0
	for f in range(12):
		Controls.script_input = {"attack": f < 2}
		Controls.poll()
		room.step(Game.STEP)
	Controls.script_input = {}
	for f in range(4):
		Controls.poll()
		room.step(Game.STEP)
	if not Game.flag("agent:D07"):
		fail(res, "a swipe did not free the agent")
	if not room.jars[0].broken or room.jars[0].fly == null:
		fail(res, "no effect from the flag")
	if Game.agents_freed() != 1:
		fail(res, "count %d" % Game.agents_freed())
	# a dash through a fresh jar
	Game.flags.erase("agent:D07")
	Game.tools.bash = true
	var room2 := new_room("D07")
	room2.ents.clear()
	var p2 = room2.player
	p2.x = float(room2.jars[0].x) - 40.0
	p2.y = float(room2.jars[0].y) - p2.h
	p2.face = 1.0
	for f in range(25):
		Controls.script_input = {"dash": f == 1, "right": true}
		Controls.poll()
		room2.step(Game.STEP)
	Controls.script_input = null
	if not Game.flag("agent:D07"):
		fail(res, "a dash did not free the agent")
	# the context window
	Game.flags = {}
	for pid in ["async_await", "cache", "verbose", "restart_always"]:
		Game.flags["plugin:" + pid] = true
	for rid in ["D07", "H13", "R01"]:
		Game.flags["agent:" + rid] = true
	if Game.notches() != 3:
		fail(res, "3 agents: %d notches" % Game.notches())
	if Game.filter_loadout(["async_await", "cache", "verbose"]) != ["async_await", "cache"]:
		fail(res, "3 notches fit two plugins of cost 2 and 1 only")
	Game.flags["agent:R02"] = true
	if Game.notches() != 4 or Game.filter_loadout(["async_await", "cache", "verbose"]).size() != 3:
		fail(res, "4 agents: %d notches" % Game.notches())
	for rid in ["R03", "D01", "D02", "D03"]:
		Game.flags["agent:" + rid] = true
	if Game.notches() != 5 or Game.filter_loadout(["async_await", "cache", "verbose", "restart_always"]).size() != 4:
		fail(res, "8 agents: %d notches" % Game.notches())
	Game.equipped = ["async_await", "cache", "verbose", "restart_always"]
	if Game.notches_used() != 5:
		fail(res, "notches used")
	Game.fresh()
	room.queue_free()
	room2.queue_free()
	return report("lostagents", res.ok, res.info)

# MVB1-13: the decor and the changes to the built rooms
func t_decor() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# every room: its signs match its `T` letters, its decor kinds are known, its decor and agents cells are inside the room
	var kinds := ["scrap", "drip", "bucket", "lamp", "chair", "package", "contributors"]
	for id in Game.rooms_meta.rooms:
		var m: Dictionary = Game.rooms_meta.rooms[id]
		var rows := FileAccess.get_file_as_string("res://src/world/rooms/" + String(m.file)).split("\n")
		var ts := 0
		for ln in rows:
			ts += ln.count("T")
		if ts != m.get("signs", []).size():
			fail(res, "%s: %d T letters, %d signs" % [id, ts, m.get("signs", []).size()])
		for d in m.get("decor", []):
			if not kinds.has(String(d.kind)):
				fail(res, "%s: decor kind %s" % [id, d.kind])
			if int(d.x) < 0 or int(d.x) >= int(m.size[0]) or int(d.y) < 0 or int(d.y) >= int(m.size[1]):
				fail(res, "%s: decor outside" % id)
			elif String(rows[int(d.y)][int(d.x)]) in "#=":
				fail(res, "%s: decor %s inside a wall" % [id, d.kind])
	# D04: the drip exists only while the heap is flooded; the sign and the bucket
	var d04 := new_room("D04")
	var drip: Dictionary = {}
	var bucket: Dictionary = {}
	for d in d04.decor_items:
		if d.kind == "drip":
			drip = d
		elif d.kind == "bucket":
			bucket = d
	if drip.is_empty() or bucket.is_empty():
		fail(res, "D04 drip or bucket missing")
	else:
		if not Game.cond(String(drip["if"])) or Game.heap_flood() != 2:
			fail(res, "the drip is missing at flood 2")
		Game.flags["gate:H07:catch"] = true
		if not Game.cond(String(drip["if"])):
			fail(res, "the drip at flood 1")
		Game.flags["boss:LEAK"] = true
		if Game.cond(String(drip["if"])):
			fail(res, "the drip after THE LEAK")
		if float(drip.fall_y) > float(bucket.y) - 8.0:
			fail(res, "the drip does not end in the bucket")
	if d04.signs.size() != 2 or d04.sign_text(d04.signs[1]) != "leak fixed. keeping the bucket, just in case.":
		fail(res, "D04 sign 2 after the leak: " + d04.sign_text(d04.signs[1]))
	Game.flags.erase("boss:LEAK")
	Game.flags.erase("gate:H07:catch")
	if d04.sign_text(d04.signs[1]) != "leak detected: please bring a bucket":
		fail(res, "D04 sign 2 before the leak")
	await frames(2)                                        # (the furniture layer draws every kind without an error)
	d04.queue_free()
	# R06: the lamp, the third sign, the closed west door
	var r6 := new_room("R06")
	var lamp: Dictionary = {}
	for d in r6.decor_items:
		if d.kind == "lamp":
			lamp = d
	if lamp.is_empty() or Game.cond(String(lamp.lit)):
		fail(res, "the lamp is lit without THE MONOLITH")
	Game.flags["boss:MONOLITH"] = true
	if lamp.is_empty() or not Game.cond(String(lamp.lit)):
		fail(res, "the lamp is not lit after THE MONOLITH")
	if r6.signs.size() != 3 or r6.sign_text(r6.signs[2]) != "// TODO: remove this room. — Not tonight.":
		fail(res, "R06 sign 3 reads " + (r6.sign_text(r6.signs[2]) if r6.signs.size() > 2 else "nothing"))
	Game.flags.erase("boss:MONOLITH")
	if r6.sign_text(r6.signs[2]) != "// TODO: remove this room.":
		fail(res, "R06 sign 3 before")
	if r6.sign_text(r6.signs[0]) != "ln: ../.git/old: broken symlink":
		fail(res, "R06 sign 1")
	var wd = r6.grid.door_at("W", 10)
	if wd == null or wd.open:
		fail(res, "R06's west door is not closed")
	for ty in range(9, 13):
		if r6.grid.tiles[ty * r6.w + 0] != TileGrid.E:
			fail(res, "R06 (0,%d) is not open" % ty)
	var chairs := 0
	for d in r6.decor_items:
		if d.kind == "chair":
			chairs += 1
	if chairs != 2:
		fail(res, "chairs %d" % chairs)
	await frames(2)
	r6.queue_free()
	# the others: D07's package and sign, H03's third sign, R08's sign after the boss, the scraps near the cartographers
	var d07 := new_room("D07")
	if d07.signs.size() != 2 or d07.sign_text(d07.signs[1]) != "abandoned does not mean unloved":
		fail(res, "D07 signs")
	await frames(2)
	d07.queue_free()
	var h3 := new_room("H03")
	if h3.signs.size() != 3 or h3.sign_text(h3.signs[2]) != "free() is not the same as goodbye.":
		fail(res, "H03 signs")
	h3.queue_free()
	var r8 := new_room("R08")
	Game.flags["boss:MONOLITH"] = true
	if r8.sign_text(r8.signs[0]) != "README: shipped at 06:00. keep the little orange one.":
		fail(res, "R08 sign after the boss")
	Game.flags.erase("boss:MONOLITH")
	await frames(2)
	r8.queue_free()
	for rid in ["R08", "D01", "H04"]:
		var rm := new_room(rid)
		var scraps := 0
		for d in rm.decor_items:
			if d.kind == "scrap":
				scraps += 1
		if scraps < 2:
			fail(res, "%s has %d scraps" % [rid, scraps])
		rm.queue_free()
	Game.fresh()
	return report("decor", res.ok, res.info)

# MVB1-14: a terminal is a quiet place: no enemy within 10 tiles of its bench, a fan that fades in, calm music; the far landmarks draw
func t_terminals() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var n := 0
	for id in Game.rooms_meta.rooms:
		if not bool(Game.rooms_meta.rooms[id].get("terminal", false)):
			continue
		n += 1
		var r := new_room(id)
		if r.cps.is_empty():
			fail(res, "%s has no bench" % id)
		for c in r.cps:
			for e in r.ents:
				var d := Vector2(float(e.x) + float(e.w) / 2.0 - float(c.x), float(e.y) + float(e.h) / 2.0 - float(c.y)).length() / 16.0
				if d < 10.0:
					fail(res, "%s: a %s %.1f tiles from the bench" % [id, e.get_class(), d])
		r.queue_free()
	if n < 4:
		fail(res, "only %d terminals" % n)
	# the fan: 1 within 6 tiles of the bench, silent at 20, silent in a room that is no terminal
	if Audio.fan_volume(true, 0.0) != 1.0 or Audio.fan_volume(true, 6.0) != 1.0:
		fail(res, "fan at the bench")
	if Audio.fan_volume(true, 20.0) != 0.0 or Audio.fan_volume(true, 40.0) != 0.0:
		fail(res, "fan at 20 tiles")
	if absf(Audio.fan_volume(true, 13.0) - 0.5) > 0.001:
		fail(res, "fan halfway")
	if Audio.fan_volume(false, 0.0) != 0.0:
		fail(res, "fan outside a terminal room")
	if not ResourceLoader.exists("res://assets/audio/amb_fan.wav"):
		fail(res, "amb_fan.wav is missing")
	# the calm music: ducked 6 dB within 8 tiles of a bench
	if Audio.calm_target(true, 7.9) != -6.0 or Audio.calm_target(true, 8.5) != 0.0 or Audio.calm_target(false, 1.0) != 0.0:
		fail(res, "calm target")
	# the far landmarks: the six rooms load and draw
	var want := {"H01": "tower", "H11": "tower", "H02": "lantern", "H04": "lantern", "R09": "horizon", "R10": "horizon"}
	for id in want:
		if not Game.rooms_meta.rooms[id].get("landmarks", []).has(want[id]):
			fail(res, "%s lacks the %s landmark" % [id, want[id]])
		var r2 := new_room(id)
		await frames(2)
		var lm = r2.view.get_node_or_null("Landmarks")
		if lm == null or lm.draws < 1:
			fail(res, "%s: the landmarks did not draw" % id)
		r2.queue_free()
	Game.fresh()
	return report("terminals", res.ok, res.info)
