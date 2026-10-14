extends RefCounted
class_name TestsGfx
# GFX-N (the NETWORK's look, docs/PLAN-metroidvania-gfx-network.md). Tests marked (render) need a real renderer: tools/godot/gfx-tests.sh runs them
# under xvfb with --rendering-driver opengl3; the others run headless like the rest.

const NAMES := ["moods", "gfxtier", "netbackdrop2", "gfxcontrast", "lights", "normals", "luts", "post"]
const RENDER := ["gfxcontrast", "normals", "post"]                                # the names that need a renderer (test-all runs them through gfx-tests.sh)
var main

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String):
	match name:
		"moods": return t_moods()
		"gfxtier": return t_gfxtier()
		"netbackdrop2": return await t_netbackdrop2()
		"gfxcontrast": return await t_gfxcontrast()
		"lights": return await t_lights()
		"normals": return await t_normals()
		"luts": return t_luts()
		"post": return await t_post()

func frames(n: int) -> void:
	for i in range(n):
		await main.get_tree().process_frame

func new_room(room_id: String) -> Room:
	var room := Room.new()
	main.world.add_child(room)
	room.load_room(room_id)
	room.build_nodes()
	return room

# MVGN-02: every N room resolves to a mood, the look reaches its target in 1.2 s, worlds 1-5 have no Look
func t_moods() -> bool:
	Game.persist = false
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	var pal := Look.palettes()
	for want in ["stable", "loss", "lair", "heat", "heat_p3", "review", "stable_clean"]:
		if not pal.has(want):
			ok = false
			info += " palette %s missing;" % want
	var n := 0
	for id in Game.rooms_meta.rooms:
		if not id.begins_with("N") or not id.substr(1).is_valid_int():
			continue
		n += 1
		var def: Dictionary = Game.rooms_meta.rooms[id]
		var mm := Look.resolve(def)
		if not pal.has(mm[0]) or float(mm[1]) <= 0.0 or float(mm[1]) > 1.0:
			ok = false
			info += " %s has no mood;" % id
		if not def.has("mood"):
			ok = false
			info += " %s: no mood in rooms.json;" % id
	if n != 22:
		ok = false
		info += " %d N rooms;" % n
	# the table of the plan
	for pair in [["N09", "lair", 1.0], ["N12", "loss", 1.0], ["N15", "heat", 1.0], ["N22", "review", 1.0], ["N08", "lair", 0.6], ["N20", "loss", 0.5], ["N01", "stable", 1.0]]:
		var mm := Look.resolve(Game.rooms_meta.rooms[pair[0]])
		if mm[0] != pair[1] or not is_equal_approx(float(mm[1]), float(pair[2])):
			ok = false
			info += " %s is %s;" % [pair[0], str(mm)]
	# after the FIREWALL the stable rooms are clean, the others unchanged
	Game.flags["boss:FIREWALL"] = true
	if Look.resolve(Game.rooms_meta.rooms["N01"])[0] != "stable_clean" or Look.resolve(Game.rooms_meta.rooms["N12"])[0] != "loss":
		ok = false
		info += " stable_clean;"
	Game.flags.erase("boss:FIREWALL")
	# a blend takes 1.2 s (+- 0.1) and ends exactly on the mixed palette
	var look := Look.new()
	look.set_target("stable", 1.0, true)
	look.set_target("heat", 1.0, false)
	var t := 0.0
	while not look.reached() and t < 3.0:
		look.step(1.0 / 60.0)
		t += 1.0 / 60.0
	if absf(t - 1.2) > 0.1:
		ok = false
		info += " blend took %.2f s;" % t
	if not (look.out.ambient as Color).is_equal_approx(Look.mixed("heat", 1.0).ambient):
		ok = false
		info += " blend does not end on the target;"
	# a half way mood is a mix (k 0.5: halfway between stable and heat)
	var half := Look.mixed("heat", 0.5)
	var mid: Color = (pal.stable.ambient as Color).lerp(pal.heat.ambient as Color, 0.5)
	if not (half.ambient as Color).is_equal_approx(mid):
		ok = false
		info += " k mix;"
	look.free()
	# rooms: a NETWORK room has a Look in its mood, a room of another world has none
	var r1 := new_room("N09")
	if r1.look == null or r1.look.mood != "lair":
		ok = false
		info += " N09 look;"
	r1.queue_free()
	for id in ["R01", "D05", "H05", "T04"]:
		var r2 := new_room(id)
		if r2.look != null:
			ok = false
			info += " %s has a Look;" % id
		r2.queue_free()
	return report("moods", ok, info if info != "" else "%d rooms" % n)

# MVGN-03: the tier round-trips through the settings file, ?gfx= wins, low_fx follows, the device default
func t_gfxtier() -> bool:
	var ok := true
	var info := ""
	var path := "user://gfxtier_test.json"
	var old_path: String = Game.settings_path
	var old_persist: bool = Game.persist
	Game.settings_path = path
	Game.persist = true
	Game.gfx_url = -1
	Game.gfx_saved = -1
	Game._gfx_default = -1
	Game.touch_seen = false
	if not OS.has_feature("web") and not DisplayServer.is_touchscreen_available():
		if Game.gfx_tier != 2:
			ok = false
			info += " pc default is %d;" % Game.gfx_tier
	Game.touch_seen = true
	if Game.gfx_tier != 1:
		ok = false
		info += " touch default is %d;" % Game.gfx_tier
	Game.touch_seen = false
	Game._gfx_default = -1
	Game.gfx_tier = 0
	Game.reduce_flash = true
	Game.save_settings()
	Game.gfx_saved = -1
	Game.reduce_flash = false
	Game.load_settings()
	if Game.gfx_tier != 0 or not Game.reduce_flash or not Game.low_fx:
		ok = false
		info += " round trip %d %s;" % [Game.gfx_tier, str(Game.reduce_flash)]
	Game.gfx_url = 2                                         # ?gfx=ultra wins over the saved low
	if Game.gfx_tier != 2 or Game.low_fx:
		ok = false
		info += " url;"
	Game.gfx_url = -1
	Game.gfx_tier = 1
	if Game.low_fx:
		ok = false
		info += " low_fx on high;"
	# the pause menu has the two rows and they change the values
	var pm := PauseMenu.new()
	var o: Array = pm.options()
	if not (o.has("Graphics: high") and o.has("Reduce flashing: on")):
		ok = false
		info += " pause rows %s;" % str(o)
	pm.choose(o.find("Graphics: high"))
	if Game.gfx_tier != 2:
		ok = false
		info += " pause choose;"
	pm.free()
	# Reduce flashing caps the screen flash
	var rm := new_room("N01")
	rm.flash_screen(0.9, "#ffffff")
	if absf(rm.fx.flash - 0.25) > 0.001:
		ok = false
		info += " flash %.2f;" % rm.fx.flash
	rm.queue_free()
	Game.reduce_flash = false
	Game.gfx_saved = -1
	Game.settings_path = old_path
	Game.persist = old_persist
	DirAccess.remove_absolute(path)
	return report("gfxtier", ok, info)

# MVGN-04: five layers, the static ones do not redraw while nothing changes, the mood colours apply, a blend costs at most 12 redraws a second
func t_netbackdrop2() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	Game.gfx_url = 1
	var r := new_room("N05")
	await frames(6)
	var nb: NetBackdrop = r.view.get_node_or_null("NetBackdrop")
	if nb == null:
		return report("netbackdrop2", false, "no backdrop")
	for n in ["sky", "skyline", "towers", "cables", "racks"]:
		if nb.get(n) == null or not nb.get(n).is_inside_tree():
			ok = false
			info += " layer %s missing;" % n
	if nb.layer_count() != 5 or not nb.skyline.visible or not nb.racks.visible:
		ok = false
		info += " high has %d layers;" % nb.layer_count()
	var s0 := nb.static_draws
	var c0 := nb.draws
	await frames(300)
	if nb.static_draws != s0:
		ok = false
		info += " static layers redrew %d times in 300 frames;" % (nb.static_draws - s0)
	if nb.draws - c0 < 200:
		ok = false
		info += " cables drew %d times;" % (nb.draws - c0)
	# the mood colours apply: a heat room is red at the top of the sky, a blend finishes on the target
	r.look.set_target("heat", 1.0, true)
	await frames(3)
	if not (nb._out().sky_far as Color).is_equal_approx(Look.mixed("heat", 1.0).sky_far) or nb.static_draws == s0:
		ok = false
		info += " heat not applied;"
	var s1 := nb.static_draws
	r.look.set_target("loss", 1.0, false)                # 1.2 s blend
	for i in range(80):
		r.look.step(1.0 / 60.0)                          # (the node's own _process steps it too; this makes sure 1.2 s passed)
		await frames(1)
	if not r.look.reached() or not (nb._out().sky_far as Color).is_equal_approx(Look.mixed("loss", 1.0).sky_far):
		ok = false
		info += " blend end;"
	if nb.static_draws - s1 > 24 or nb.static_draws - s1 < 1:
		ok = false
		info += " blend redraws %d;" % (nb.static_draws - s1)
	# the tiers: Low has three layers, Ultra shows the shafts
	Game.gfx_url = 0
	Game.gfx_changed.emit()
	if nb.layer_count() != 3 or nb.skyline.visible or nb.racks.visible or nb.shafts.visible:
		ok = false
		info += " low layers;"
	Game.gfx_url = 2
	Game.gfx_changed.emit()
	if not nb.shafts.visible or not nb.skyline.visible:
		ok = false
		info += " ultra shafts;"
	# two rooms do not share a skyline (the rooms' numbers seed it)
	var r2 := new_room("N06")
	await frames(2)
	var nb2: NetBackdrop = r2.view.get_node_or_null("NetBackdrop")
	if nb2 == null or is_equal_approx(nb._th(0), nb2._th(0)) and is_equal_approx(nb._th(1), nb2._th(1)):
		ok = false
		info += " same skyline;"
	Game.gfx_url = -1
	r.queue_free()
	r2.queue_free()
	return report("netbackdrop2", ok, info)

# ---------------------------------------------------------------- rendering helpers (a real renderer)
func grab() -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = main.game_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

# L = 0.299 R + 0.587 G + 0.114 B of every pixel (0..1), row by row
func lum_array(img: Image) -> PackedFloat32Array:
	var d := img.get_data()
	var out := PackedFloat32Array()
	out.resize(d.size() / 4)
	for i in range(out.size()):
		out[i] = (0.299 * d[i * 4] + 0.587 * d[i * 4 + 1] + 0.114 * d[i * 4 + 2]) / 255.0
	return out

func block_mean(lum: PackedFloat32Array, x0: int, y0: int, w: int, h: int) -> float:
	var s := 0.0
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			s += lum[y * 384 + x]
	return s / float(w * h)

# which parts of a room are drawn: the backdrop (sky + landmarks), the terrain tiles, everything else (decor, furniture, creatures, players, ...)
func show_parts(r: Room, bg: bool, terr: bool, rest: bool) -> void:
	for n in ["NetBackdrop", "Landmarks"]:
		var c = r.view.get_node_or_null(n)
		if c != null:
			c.visible = bg
	r.view.tiles.visible = terr
	r.view.decor.visible = rest
	r.view.dynamic.visible = rest
	for k in r.layers:
		r.layers[k].visible = rest
	r.entity_root.visible = rest
	if r.player != null:
		r.player.visible = rest
	for rp in r.remote_players:
		rp.visible = rest
	for n in ["Lights", "Post"]:
		var c2 = r.get_node_or_null(n)
		if c2 != null:
			c2.visible = rest

# the camera at x (clamped), the room's first y; `settle` frames so every node has moved with it
func look_at(r: Room, x: float, settle := 3) -> void:
	var wpx := float(r.def.size[0]) * 16.0
	r.cam.x = clampf(x, 0.0, maxf(0.0, wpx - 384.0))
	r.camera.position = Vector2(floor(r.cam.x + 0.5), floor(r.cam.y + 0.5))
	for i in range(settle):
		await main.get_tree().process_frame

func cam_positions(r: Room) -> Array:
	var wpx := float(r.def.size[0]) * 16.0
	if wpx <= 384.0 + 16.0:
		return [0.0]
	return [0.0, (wpx - 384.0) * 0.5, wpx - 384.0]

# ---------------------------------------------------------------- MVGN-04 / 05 / 14: the 3-tier contrast rule (plan 3.7), measured
# tier 1 background: mean L <= 0.16, at most 2 % of the pixels above 0.35 (LEDs and dots)
# tier 2 terrain: its tiles' mean L is at least 0.06 above the background behind them; floor cap rows (the top 2 pixel rows of a tile with air above) >= 0.40
func contrast_room(id: String, mood = null, label := "") -> Dictionary:
	var r := new_room(id)
	if mood != null and r.look != null:
		r.look.set_target(mood[0], mood[1], true)
	await frames(2)
	var res := {"ok": true, "info": "", "line": ""}
	var bg_means := []
	var bg_his := []
	var gains := []
	var caps := []
	for cx in cam_positions(r):
		await look_at(r, cx)
		show_parts(r, true, false, false)
		await frames(1)
		var bg := lum_array(await grab())
		show_parts(r, false, true, false)
		await frames(1)
		var tr := lum_array(await grab())
		show_parts(r, true, true, true)
		var m := 0.0
		var hi := 0
		for v in bg:
			m += v
			if v > 0.35:
				hi += 1
		bg_means.append(m / bg.size())
		bg_his.append(float(hi) / bg.size())
		var g := r.grid
		var tx0 := floori(r.camera.position.x / 16.0)
		var ty0 := floori(r.camera.position.y / 16.0)
		var gsum := 0.0
		var gn := 0
		for ty in range(ty0, ty0 + 14):
			for tx in range(tx0 + 1, tx0 + 24):
				if tx < 0 or ty < 0 or tx >= g.w or ty >= g.h or g.tile(tx, ty) != TileGrid.SOLID:
					continue
				var px := tx * 16 - int(r.camera.position.x)
				var py := ty * 16 - int(r.camera.position.y)
				if px < 0 or py < 0 or px > 368 or py > 200:
					continue
				gsum += block_mean(tr, px, py, 16, 16) - block_mean(bg, px, py, 16, 16)
				gn += 1
				if ty > 0 and g.tile(tx, ty - 1) == TileGrid.E:
					caps.append(block_mean(tr, px, py, 16, 2))
		if gn > 0:
			gains.append(gsum / gn)
	var bgm: float = bg_means.max() if not bg_means.is_empty() else 0.0
	var bgh: float = bg_his.max() if not bg_his.is_empty() else 0.0
	var gain: float = gains.min() if not gains.is_empty() else 1.0
	var cap: float = caps.min() if not caps.is_empty() else 1.0
	res.line = "GFX contrast %s%s bg_mean %.3f bg_bright %.3f terrain_gain %.3f cap %.2f" % [id, label, bgm, bgh, gain, cap]
	if bgm > 0.16 or bgh > 0.02:
		res.ok = false
		res.info += " %s%s background %.3f/%.3f;" % [id, label, bgm, bgh]
	if gain < 0.06:
		res.ok = false
		res.info += " %s%s terrain gain %.3f;" % [id, label, gain]
	if cap < 0.40:
		res.ok = false
		res.info += " %s%s cap rows %.2f;" % [id, label, cap]
	r.queue_free()
	await frames(1)
	return res

func t_gfxcontrast() -> bool:
	if DisplayServer.get_name() == "headless":
		return report("gfxcontrast", true, "skipped: no renderer (run it through tools/godot/gfx-tests.sh)")
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.gfx_url = 2
	var ok := true
	var info := ""
	var only: String = OS.get_environment("GFX_ROOMS")
	for i in range(1, 23):
		var id := "N%02d" % i
		if only != "" and not only.split(",").has(id):
			continue
		var res: Dictionary = await contrast_room(id)
		print(res.line)
		if not res.ok:
			ok = false
			info += res.info
	Game.gfx_url = -1
	return report("gfxcontrast", ok, info)

func lit_count(r: Room) -> int:
	var n := 0
	var rl: RoomLights = r.get_node_or_null("Lights")
	if rl == null:
		return -1
	for l in rl.pool:
		if l.visible and l.is_visible_in_tree():
			n += 1
	return n

# MVGN-05: the light budget holds (worst room with a swarm of shots, every arena, every tier), a hidden room lights nothing, the ambient is claimed
func t_lights() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	var budgets := [6, 24, 48]
	for tier in [0, 1, 2]:
		Game.gfx_url = tier
		var r := new_room("N05")
		for i in range(40):                                  # a swarm: 40 shots around the player
			r.shoot(r.player.x + float(i * 7 % 160) - 80.0, r.player.y - float(i * 11 % 90), 0.0, 0.0, {"life": 99.0})
		await frames(3)
		var n := lit_count(r)
		if n > budgets[tier] or n < 1:
			ok = false
			info += " N05 tier %d lights %d;" % [tier, n]
		if tier == 0 and (r.get_node("Lights").wanted > 3):
			ok = false
			info += " low lists %d;" % r.get_node("Lights").wanted
		if tier == 2 and n < 30:
			ok = false
			info += " ultra only %d lights in a busy room;" % n
		var st := LookStage.of(r)
		if st == null or st.color == Color.WHITE:
			ok = false
			info += " no ambient claimed;"
		r.queue_free()
		await frames(1)
	Game.gfx_url = 2
	for pair in [["N09", "CRAWLER"], ["N15", "FIREWALL"], ["N22", "REVIEWER2"]]:
		var r2 := new_room(pair[0])
		r2._start_intro()
		r2.fight.t = 0.0
		r2._begin_fight()
		await frames(3)
		var n2 := lit_count(r2)
		if n2 > 48 or n2 < 1:
			ok = false
			info += " %s lights %d;" % [pair[0], n2]
		r2.queue_free()
		await frames(1)
	# a hidden room (only the partner is in it) has no visible light and does not claim the ambient
	var hid := Room.new()
	main.world.add_child(hid)
	hid.load_room("N09")
	hid.build_nodes(null, null, false)
	await frames(3)
	if lit_count(hid) > 0:
		ok = false
		info += " hidden room lights %d;" % lit_count(hid)
	hid.queue_free()
	# worlds 1-5: no lights node, the stage (if any) is white again a few frames after the last NETWORK room
	var r3 := new_room("D05")
	await frames(6)
	if r3.get_node_or_null("Lights") != null:
		ok = false
		info += " D05 has lights;"
	var stg := main.world.get_node_or_null("LookStage") as LookStage
	if stg != null and stg.color != Color.WHITE:
		ok = false
		info += " the ambient stayed on in world 2;"
	r3.queue_free()
	Game.gfx_url = -1
	return report("lights", ok, info)

# MVGN-06: the normal maps exist and match their diffuse; lit from the left, a tile's left bevel is lighter than its right bevel (render)
func t_normals() -> bool:
	var ok := true
	var info := ""
	var pairs := [["res://assets/tiles/w6_tiles.png", "res://assets/tiles/w6_tiles_n.png"]]
	for s in ["drone_0", "bug_0", "platform_w6", "noodle_0"]:
		pairs.append(["res://assets/sprites/%s.png" % s, "res://assets/sprites/%s_n.png" % s])
	for p in pairs:
		if not ResourceLoader.exists(p[1]):
			ok = false
			info += " missing %s;" % p[1]
			continue
		var d: Texture2D = load(p[0])
		var n: Texture2D = load(p[1])
		if d.get_size() != n.get_size():
			ok = false
			info += " size %s;" % p[1]
	if DisplayServer.get_name() == "headless":
		return report("normals", ok, info + " (light test skipped: no renderer)")
	Game.gfx_url = 1
	var res := []
	for with_normal in [true, false]:
		var root := Node2D.new()
		main.world.add_child(root)
		var cm := CanvasModulate.new()
		cm.color = Color(0.15, 0.15, 0.2)
		root.add_child(cm)
		var tex: Texture2D = load("res://assets/tiles/w6_tiles.png")
		if with_normal:
			tex = RoomView.normal_tex(tex)
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.region_enabled = true
		sp.region_rect = Rect2(0, 0, 16, 16)                       # the tile with every edge exposed (mask 0, variant 0)
		sp.centered = false
		sp.position = Vector2(184, 100)
		sp.scale = Vector2(4, 4)
		root.add_child(sp)
		var l := PointLight2D.new()
		l.texture = load("res://assets/fx/light_soft.png")
		l.position = Vector2(150, 132)
		l.texture_scale = 2.0
		l.energy = 1.4
		l.height = 12.0
		root.add_child(l)
		await frames(4)
		var lum := lum_array(await grab())
		var left := block_mean(lum, 184, 110, 8, 40)             # the left 2 tile pixels (x4)
		var right := block_mean(lum, 240, 110, 8, 40)
		res.append(left - right)
		root.queue_free()
		await frames(1)
	if res[0] < 0.03 or res[0] < res[1] + 0.02:
		ok = false
		info += " lit edges: with normal %.3f without %.3f;" % [res[0], res[1]]
	Game.gfx_url = -1
	return report("normals", ok, info + " left-right %.3f (flat %.3f)" % [res[0], res[1]])

const MOODS := ["stable", "loss", "lair", "heat", "heat_p3", "review", "stable_clean"]

# CIE76 delta E between two sRGB colours
static func delta_e(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return la.distance_to(lb)

static func _lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))

# MVGN-07: the LUT of every palette keeps the catchable yellow within delta E 6 (computed), and writes the strips when LUT_OUT is set
func t_luts() -> bool:
	var ok := true
	var info := ""
	var yel := Color("#ffd23f")
	var out: String = OS.get_environment("LUT_OUT")
	for name in MOODS:
		var m := Look.mixed(name, 1.0)
		var img := Look.lut_image(m.sky_far, m.ambient)
		if out != "":
			img.save_png(out.path_join("%s.png" % name))
		# the grid cell nearest to the yellow, as the shader's trilinear fetch would give (corners mixed by the fractions)
		var q := Vector3(yel.r, yel.g, yel.b) * 15.0
		var acc := Color(0, 0, 0, 0)
		for dr in [0, 1]:
			for dg in [0, 1]:
				for db in [0, 1]:
					var ri := mini(int(q.x) + dr, 15)
					var gi := mini(int(q.y) + dg, 15)
					var bi := mini(int(q.z) + db, 15)
					var w := (q.x - int(q.x) if dr == 1 else 1.0 - (q.x - int(q.x))) * (q.y - int(q.y) if dg == 1 else 1.0 - (q.y - int(q.y))) * (q.z - int(q.z) if db == 1 else 1.0 - (q.z - int(q.z)))
					acc += img.get_pixel(bi * 16 + ri, gi) * w
		acc.a = 1.0
		var de := delta_e(yel, acc)
		if de > 6.0:
			ok = false
			info += " %s yellow dE %.1f;" % [name, de]
	return report("luts", ok, info)

# MVGN-07 (render): the HUD's pixels are the same with the post chain on and off; the catchable yellow is within dE 6 after the real shader, in every mood
func t_post() -> bool:
	if DisplayServer.get_name() == "headless":
		return report("post", true, "skipped: no renderer")
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.gfx_url = 2
	var ok := true
	var info := ""
	var r := new_room("N05")
	var hl := CanvasLayer.new()
	hl.layer = 2
	main.game_vp.add_child(hl)
	var hud := Hud.new()
	hl.add_child(hud)
	hud.set_room(r)
	r.visible = false                                          # nothing but the HUD and the (empty) post-graded screen
	await frames(4)
	var on := await grab()
	var pc: PostChain = main.game_vp.get_node("PostChain")
	pc.layer.visible = false
	r.look.post = null                                          # (Look no longer claims it: the layer stays hidden)
	await frames(2)
	var off := await grab()
	var diff := 0
	var hudpx := 0
	var bg := off.get_pixel(380, 210)
	for y in range(0, 216):
		for x in range(0, 384):
			var c1 := on.get_pixel(x, y)
			var c0 := off.get_pixel(x, y)
			if c0 != bg and c0.a > 0.0 and y >= 6 and y < 15 and x >= 6 and x < 60:        # the HUD's hit-point pips (opaque sprites; the panels are translucent over the graded world on purpose)
				hudpx += 1
				if c1 != c0:
					diff += 1
	if hudpx < 15 or diff > 0:
		ok = false
		info += " hud pixels %d differ %d;" % [hudpx, diff]
	hl.queue_free()
	r.queue_free()
	await frames(2)
	# the yellow in every mood
	Game.reduce_flash = true                                    # (no grain, no scanlines: only the grade is measured)
	for name in MOODS:
		var r2 := new_room("N05")
		r2.look.set_target(name, 1.0, true)
		var sq := ColorRect.new()
		sq.color = Color("#ffd23f")
		sq.size = Vector2(60, 40)
		sq.position = r2.camera.position + Vector2(162, 88)
		sq.material = Look.unshaded()
		sq.z_index = 100
		r2.add_child(sq)
		await frames(4)
		var img := await grab()
		var got := img.get_pixel(192, 109)
		var de := delta_e(Color("#ffd23f"), got)
		if de > 6.0:
			ok = false
			info += " %s yellow dE %.1f (%s);" % [name, de, got.to_html(false)]
		r2.queue_free()
		await frames(1)
	Game.reduce_flash = false
	Game.gfx_url = -1
	return report("post", ok, info)
