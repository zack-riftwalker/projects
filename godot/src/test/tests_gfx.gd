extends RefCounted
class_name TestsGfx
# GFX-N (the NETWORK's look, docs/PLAN-metroidvania-gfx-network.md). Tests marked (render) need a real renderer: tools/godot/gfx-tests.sh runs them
# under xvfb with --rendering-driver opengl3; the others run headless like the rest.

const NAMES := ["moods", "gfxtier", "netbackdrop2", "gfxcontrast", "lights", "normals", "luts", "post", "moodshift", "foreground", "ambient", "gloss", "livingbg", "arenas"]
const RENDER := ["gfxcontrast", "normals", "post", "gloss"]                                # the names that need a renderer (test-all runs them through gfx-tests.sh)
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
		"moodshift": return await t_moodshift()
		"foreground": return await t_foreground()
		"ambient": return await t_ambient()
		"gloss": return await t_gloss()
		"livingbg": return await t_livingbg()
		"arenas": return await t_arenas()
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

func run_follow(r: Room, secs: float) -> void:
	for i in range(int(secs * 60.0)):
		r.time += 1.0 / 60.0
		r.look.follow_room(1.0 / 60.0)
		r.look.step(1.0 / 60.0)

# MVGN-08: the N17 chase moves the look within 0.2 s and ends with it; the FIREWALL's phase 3 has its own look and skipping the boss restores it
func t_moodshift() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	var r := new_room("N17")
	await frames(2)
	run_follow(r, 0.5)
	var base: Color = r.look.out.ambient
	var base_b: Color = r.look.out.accent_b
	r.time = 20.0
	r.ch_t0 = 8.0
	run_follow(r, 0.2)
	var moved: Color = r.look.out.ambient
	if absf(moved.r - base.r) + absf(moved.g - base.g) + absf(moved.b - base.b) < 0.04 or absf((r.look.out.accent_b as Color).r - base_b.r) + absf((r.look.out.accent_b as Color).g - base_b.g) + absf((r.look.out.accent_b as Color).b - base_b.b) < 0.2:
		ok = false
		info += " chase did not move the look in 0.2 s;"
	run_follow(r, 1.2)
	var siren_a: Color = r.look.out.ambient
	r.look.follow_room(0.0)
	# the pulse: samples half a period apart differ, unless Reduce flashing is on
	var samples := []
	for calm in [false, true]:
		Game.reduce_flash = calm
		run_follow(r, 0.3)
		var s1: Color = r.look.out.ambient
		run_follow(r, 0.6)
		var s2: Color = r.look.out.ambient
		samples.append(absf(s1.r - s2.r) + absf(s1.g - s2.g) + absf(s1.b - s2.b))
	Game.reduce_flash = false
	if samples[0] < 0.01 or samples[1] > 0.02:
		ok = false
		info += " pulse %.3f / calm %.3f;" % [samples[0], samples[1]]
	r.ch_t0 = -1.0
	run_follow(r, 3.0)
	var back: Color = r.look.out.ambient
	if absf(back.r - base.r) + absf(back.g - base.g) + absf(back.b - base.b) > 0.02:
		ok = false
		info += " the chase look stayed;"
	r.queue_free()
	await frames(1)
	# N15
	var f := new_room("N15")
	f._start_intro()
	f.fight.t = 0.0
	f._begin_fight()
	await frames(2)
	run_follow(f, 0.5)
	var heat := Look.mixed("heat", 1.0)
	if not (f.look.out.sky_far as Color).is_equal_approx(heat.sky_far):
		ok = false
		info += " N15 does not start in heat;"
	f.boss.phase = 3
	run_follow(f, 2.3)
	if not (f.look.out.sky_far as Color).is_equal_approx(Look.mixed("heat_p3", 1.0).sky_far):
		ok = false
		info += " phase 3 look missing;"
	f.skip_boss()
	run_follow(f, 2.3)
	if not (f.look.out.sky_far as Color).is_equal_approx(heat.sky_far):
		ok = false
		info += " heat not restored after the boss;"
	f.queue_free()
	await frames(1)
	# N09 / N22: bloom up by 0.15 and the ambient 10 % darker in phase 3
	for id in ["N09", "N22"]:
		var a := new_room(id)
		a._start_intro()
		a.fight.t = 0.0
		a._begin_fight()
		await frames(2)
		run_follow(a, 0.6)
		var b0 := float(a.look.out.bloom)
		var amb0: Color = a.look.out.ambient
		a.boss.phase = 3
		run_follow(a, 1.5)
		if absf(float(a.look.out.bloom) - b0 - 0.15) > 0.02 or absf((a.look.out.ambient as Color).r / amb0.r - 0.9) > 0.03:
			ok = false
			info += " %s phase 3: bloom %.2f -> %.2f ambient x%.2f;" % [id, b0, a.look.out.bloom, (a.look.out.ambient as Color).r / amb0.r]
		a.queue_free()
		await frames(1)
	return report("moodshift", ok, info)

# every standable floor top (solid with air above, one-way) as world rects, brute force over the whole grid
func floor_rects(r: Room) -> Array:
	var out: Array = []
	var g := r.grid
	for ty in range(g.h):
		for tx in range(g.w):
			var t := g.tile(tx, ty)
			if t == TileGrid.ONEWAY or (t == TileGrid.SOLID and (ty == 0 or g.tile(tx, ty - 1) != TileGrid.SOLID)):
				out.append(Rect2(tx * 16, ty * 16, 16, 16))
	return out

# MVGN-09: 2-6 shapes per room; wherever one is drawn nothing that matters is within 64 px (objects) / 48 px (floors) of it; behind a player it is 0.3; Low has none
func t_foreground() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.gfx_url = 1
	var ok := true
	var info := ""
	var drawn := 0
	var faded := 0
	for i in range(1, 23):
		var id := "N%02d" % i
		var r := new_room(id)
		await frames(1)
		var fg: RoomForeground = r.foreground
		if fg == null or fg.shapes.size() < 2 or fg.shapes.size() > 6:
			ok = false
			info += " %s has %d shapes;" % [id, 0 if fg == null else fg.shapes.size()]
			r.queue_free()
			continue
		var floors := floor_rects(r)
		var wpx := float(r.pw)
		var hpx := float(r.ph)
		for cy in range(0, maxi(1, int(hpx - 216.0) + 1), 48):
			for cx in range(0, maxi(1, int(wpx - 384.0) + 1), 24):
				var cam := Vector2(cx, cy)
				for k in range(fg.shapes.size()):
					var a := fg.wanted_alpha(k, cam, [])
					var sr := fg.screen_rect(k, cam)
					if sr.end.x < 0.0 or sr.position.x > 384.0 or a <= 0.05:
						continue
					drawn += 1
					var wr := Rect2(sr.position + cam, sr.size)
					for o in fg.objects:
						if wr.grow(64.0).intersects(o):
							ok = false
							info += " %s shape %d near an object at cam %s;" % [id, k, str(cam)]
					for f in floors:
						if wr.grow_individual(0, 48, 0, 48).intersects(f):
							ok = false
							info += " %s shape %d within 48 px of a floor at cam %s;" % [id, k, str(cam)]
					# behind a player: 0.3
					var box := Rect2(wr.get_center() - Vector2(5, 5), Vector2(10, 10))
					if absf(fg.wanted_alpha(k, cam, [box]) - 0.3) > 0.001:
						ok = false
						info += " %s shape %d does not fade behind a player;" % [id, k]
					else:
						faded += 1
		r.queue_free()
		await frames(1)
	if drawn < 40 or faded < 40:
		ok = false
		info += " only %d drawn / %d faded states in 22 rooms;" % [drawn, faded]
	# the fade is smooth and per frame: a player stands behind a shape of N05 and its node dims
	Game.gfx_url = 2
	var r2 := new_room("N05")
	await frames(2)
	var fg2: RoomForeground = r2.foreground
	var found := -1
	var cam_f := Vector2.ZERO
	for cx in range(0, int(r2.pw - 384) + 1, 8):
		for k in range(fg2.shapes.size()):
			if found < 0 and fg2.wanted_alpha(k, Vector2(cx, 0), []) > 0.8 and fg2.screen_rect(k, Vector2(cx, 0)).position.x > 20.0 and fg2.screen_rect(k, Vector2(cx, 0)).end.x < 360.0:
				found = k
				cam_f = Vector2(cx, 0)
	if found >= 0:
		r2.camera.position = cam_f
		r2.cam.x = cam_f.x
		var wr2 := Rect2(fg2.screen_rect(found, cam_f).position + cam_f, fg2.screen_rect(found, cam_f).size)
		r2.player.x = wr2.get_center().x - r2.player.w * 0.5
		r2.player.y = wr2.get_center().y - r2.player.h * 0.5
		for i in range(40):
			fg2._process(1.0 / 60.0)
		if absf(float(fg2.shapes[found].a) - 0.3) > 0.05 or absf((fg2.shapes[found].node as DrawProxy).modulate.a - 0.3 / 0.9) > 0.06:
			ok = false
			info += " the node did not fade to 0.3 (a=%.2f);" % float(fg2.shapes[found].a)
	else:
		ok = false
		info += " no unsuppressed shape in N05;"
	r2.queue_free()
	await frames(1)
	# Low has none
	Game.gfx_url = 0
	var r3 := new_room("N05")
	await frames(2)
	if r3.foreground.visible:
		ok = false
		info += " low shows the foreground;"
	Game.gfx_url = 1
	Game.gfx_changed.emit()
	if not r3.foreground.visible:
		ok = false
		info += " high does not;"
	r3.queue_free()
	Game.gfx_url = -1
	return report("foreground", ok, info + (" (%d drawn states checked)" % drawn if ok else ""))

func play_frames(r: Room, n: int) -> void:
	for i in range(n):
		Controls.script_input = {"right": (i / 90) % 2 == 0, "left": (i / 90) % 2 == 1, "jump": i % 40 == 0, "attack": i % 25 == 0}
		Controls.poll()
		r.step(Game.STEP)
		await main.get_tree().process_frame

# MVGN-10: counts per tier, room.rng untouched (rule 0), the animated tiles obey their placement rules, at most two vents
func t_ambient() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	for tier in [0, 1, 2]:
		Game.gfx_url = tier
		var r := new_room("N05")
		await frames(3)
		var am: RoomAmbient = r.get_node("Ambient")
		if am.n != [40, 96, 160][tier] or am.kind != "motes":
			ok = false
			info += " tier %d: %d %s particles;" % [tier, am.n, am.kind]
		r.queue_free()
		await frames(1)
	Game.gfx_url = 2
	for pair in [["N12", "shards", 160], ["N09", "spores", 160], ["N15", "embers", 160], ["N22", "paper", 160]]:
		var r2 := new_room(pair[0])
		await frames(3)
		var am2: RoomAmbient = r2.get_node("Ambient")
		if am2.kind != pair[1] or am2.n != pair[2]:
			ok = false
			info += " %s has %d %s;" % [pair[0], am2.n, am2.kind]
		if pair[0] == "N15":
			r2.look.set_target("heat_p3", 1.0, true)
			await frames(3)
			if am2.n != 320:
				ok = false
				info += " embers x2 is %d;" % am2.n
		r2.queue_free()
		await frames(1)
	# rule 0: the room's rng is in the same state after 600 frames with and without the ambient particles
	var states := []
	for with_amb in [true, false]:
		Game.gfx_url = 2
		var r3 := new_room("N05")
		r3.rng.seed = 4242
		if not with_amb:
			r3.get_node("Ambient").free()
		await play_frames(r3, 600)
		states.append([r3.rng.state, r3.player.x, r3.player.y])
		r3.queue_free()
		await frames(1)
	if states[0][0] != states[1][0] or absf(states[0][1] - states[1][1]) > 0.01:
		ok = false
		info += " ambient particles changed the room's rng or the play: %s vs %s;" % [str(states[0]), str(states[1])]
	# animated tiles and vents
	for i in range(1, 23):
		var id := "N%02d" % i
		var r4 := new_room(id)
		await frames(1)
		var vw: RoomView = r4.view
		var cells := 0
		var air := 0
		var g := r4.grid
		for ty in range(g.h):
			for tx in range(g.w):
				if g.tile(tx, ty) == TileGrid.SOLID and (g.tile(tx - 1, ty) == TileGrid.E or g.tile(tx + 1, ty) == TileGrid.E or g.tile(tx, ty - 1) == TileGrid.E):
					air += 1
		for tl in [vw.led_layer, vw.fan_layer]:
			for c in tl.get_used_cells():
				cells += 1
				if r4.reserved(c.x, c.y) or g.tile(c.x, c.y) != TileGrid.SOLID:
					ok = false
					info += " %s: animated tile on a bad cell %s;" % [id, str(c)]
		if cells > air / 12 * 1.6 + 6:
			ok = false
			info += " %s: %d animated tiles for %d wall faces;" % [id, cells, air]
		if (r4.get_node("Ambient") as RoomAmbient).vents.size() > 2:
			ok = false
			info += " %s: too many vents;" % id
		r4.queue_free()
		await frames(1)
	Game.gfx_url = -1
	return report("ambient", ok, info)

# MVGN-11 (render): a bright shot above the floor brightens the strip under it; Low and High have no strip
func t_gloss() -> bool:
	if DisplayServer.get_name() == "headless":
		return report("gloss", true, "skipped: no renderer")
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	var lums := {}
	for tier in [2, 1, 0]:
		Game.gfx_url = tier
		var r := new_room("N05")
		await frames(2)
		var gl: RoomGloss = r.get_node("Gloss")
		if tier < 2:
			if gl.visible:
				ok = false
				info += " tier %d shows the gloss;" % tier
		var best: Dictionary = {}
		for s in gl.strips:
			if best.is_empty() or s.rect.size.x > best.rect.size.x:
				best = s
		var rc: Rect2 = best.rect
		var cx := clampf(rc.position.x + rc.size.x * 0.5 - 192.0, 0.0, maxf(0.0, float(r.pw) - 384.0))
		var cy := clampf(rc.position.y - 150.0, 0.0, maxf(0.0, float(r.ph) - 216.0))
		r.cam.x = cx
		r.cam.y = cy
		r.camera.position = Vector2(cx, cy)
		r.player.x = -500.0                                   # (out of the way)
		var vals := []
		for with_shot in [false, true]:
			var shot: ColorRect = null
			if with_shot:
				shot = ColorRect.new()
				shot.color = Color(1.0, 0.9, 0.5)
				shot.size = Vector2(8, 6)
				shot.position = Vector2(rc.position.x + rc.size.x * 0.5 - 4.0, rc.position.y - 10.0)
				shot.material = Look.unshaded()
				shot.z_index = 2
				r.add_child(shot)
			await frames(4)
			var lum := lum_array(await grab())
			var sx := int(rc.position.x + rc.size.x * 0.5 - cx)
			var sy := int(rc.position.y - cy) + 6
			vals.append(block_mean(lum, sx - 3, sy, 6, 3))
			if shot != null:
				shot.queue_free()
		lums[tier] = vals[1] - vals[0]
		r.queue_free()
		await frames(1)
	if lums[2] < 0.02 or lums[1] > 0.005 or lums[0] > 0.005:
		ok = false
		info += " strip brightening: ultra %.3f high %.3f low %.3f;" % [lums[2], lums[1], lums[0]]
	Game.gfx_url = -1
	return report("gloss", ok, info + (" ultra +%.3f" % lums[2] if ok else ""))

func live_frames(r: Room, n: int) -> void:
	for i in range(n):
		r.time += 1.0 / 60.0
		await main.get_tree().process_frame

# MVGN-12: the chase wave, a lost packet's tear, the crawler's strands, the clean palette after the firewall; all derived from flags and state
func t_livingbg() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.gfx_url = 1
	var ok := true
	var info := ""
	# N17: the RST wave goes red from the top down while the chase runs, fades back 2 s after it
	var r := new_room("N17")
	await frames(3)
	var nb: NetBackdrop = r.view.get_node("NetBackdrop")
	if nb.red_leds() != 0:
		ok = false
		info += " red LEDs before the chase;"
	r.time = 20.0
	r.ch_t0 = 20.0
	await live_frames(r, 30)
	var a := nb.red_leds()
	await live_frames(r, 120)
	var b := nb.red_leds()
	await live_frames(r, 600)
	var c := nb.red_leds()
	if not (a >= 0 and b > a and c >= b and c > 0):
		ok = false
		info += " wave %d -> %d -> %d;" % [a, b, c]
	r.ch_t0 = -1.0
	await live_frames(r, 60)
	if nb.chase_red <= 0.0 or nb.chase_red >= 1.0:
		ok = false
		info += " chase_red %.2f one second after the chase;" % nb.chase_red
	await live_frames(r, 130)
	if nb.red_leds() != 0:
		ok = false
		info += " still red 2 s after the chase;"
	r.queue_free()
	await frames(1)
	# N12: a packet turns lost -> a tear and a CA pulse (none with Reduce flashing); warn -> magenta either way
	for calm in [false, true]:
		Game.reduce_flash = calm
		var r2 := new_room("N12")
		await frames(3)
		var nb2: NetBackdrop = r2.view.get_node("NetBackdrop")
		var pk = null
		for m in r2.plats:
			if m.get("packet", false):
				pk = m
				break
		pk["lost"] = false
		await live_frames(r2, 2)
		pk["lost"] = true
		await live_frames(r2, 2)
		if not calm:
			if nb2.tears != 1 or nb2.bands.is_empty() or absf(r2.look.ca_pulse - 0.6 * 0.65) > 0.05:
				ok = false
				info += " tear %d bands %d ca %.2f;" % [nb2.tears, nb2.bands.size(), r2.look.ca_pulse]
			await live_frames(r2, 20)
			if not nb2.bands.is_empty() or nb2.tear_t > 0.0:
				ok = false
				info += " the tear did not end after 150 ms;"
		else:
			if nb2.tears != 0 or r2.look.ca_pulse > 0.001:
				ok = false
				info += " Reduce flashing still tears (%d, %.2f);" % [nb2.tears, r2.look.ca_pulse]
		pk["lost"] = false
		pk["warn"] = true
		await live_frames(r2, 2)
		if not nb2.warn_on:
			ok = false
			info += " warn did not turn the LEDs magenta (calm %s);" % str(calm)
		r2.queue_free()
		await frames(1)
	Game.reduce_flash = false
	# the crawler's strands: intact, falling for 1.5 s when the flag turns up, broken; a fresh load with the flag shows broken at once
	var r3 := new_room("N09")
	await frames(3)
	var nb3: NetBackdrop = r3.view.get_node("NetBackdrop")
	if nb3.strand_state() != "intact":
		ok = false
		info += " strands %s before the crawler;" % nb3.strand_state()
	Game.flags["boss:CRAWLER"] = true
	await live_frames(r3, 3)
	if nb3.strand_state() != "falling":
		ok = false
		info += " strands %s when the flag turned;" % nb3.strand_state()
	await live_frames(r3, 100)
	if nb3.strand_state() != "broken":
		ok = false
		info += " strands %s 1.6 s later;" % nb3.strand_state()
	r3.queue_free()
	await frames(1)
	var r4 := new_room("N08")
	await frames(2)
	if (r4.view.get_node("NetBackdrop") as NetBackdrop).strand_state() != "broken":
		ok = false
		info += " a fresh load with the flag is not broken;"
	r4.queue_free()
	await frames(1)
	# the clean palette after the firewall: stable rooms are stable_clean with the calmer LEDs and more green dots; the other moods do not change
	var r5 := new_room("N01")
	await frames(2)
	Game.flags["boss:FIREWALL"] = true
	var r6 := new_room("N05")
	await frames(3)
	var nb6: NetBackdrop = r6.view.get_node("NetBackdrop")
	if r6.look.mood != "stable_clean" or not nb6.clean:
		ok = false
		info += " N05 is %s after the firewall;" % r6.look.mood
	var r7 := new_room("N12")
	if r7.look.mood != "loss":
		ok = false
		info += " N12 changed;"
	Game.flags.erase("boss:FIREWALL")
	Game.flags.erase("boss:CRAWLER")
	for rr in [r5, r6, r7]:
		rr.queue_free()
	Game.gfx_url = -1
	return report("livingbg", ok, info)

func start_fight(id: String, phase := 1) -> Room:
	var r := new_room(id)
	r._start_intro()
	r.fight.t = 0.0
	r._begin_fight()
	if phase > 1:
		r.boss.phase = phase
	return r

# MVGN-13: each arena's own lights and effects; bosses and their telegraphs are never darkened (unshaded); the ambient floor of 35 %
func t_arenas() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	Game.gfx_url = 2
	var ok := true
	var info := ""
	for pair in [["N09", 0.45], ["N15", 1.0], ["N22", 1.0]]:
		for phase in [1, 3]:
			var r := start_fight(pair[0], phase)
			await frames(3)
			r.look.follow_room(1.0 / 60.0)
			for i in range(180):
				r.time += 1.0 / 60.0
				r.look.follow_room(1.0 / 60.0)
				r.look.step(1.0 / 60.0)
			await frames(2)
			var b = r.boss
			if b == null:
				ok = false
				info += " %s: no boss;" % pair[0]
				r.queue_free()
				continue
			if b.body.material == null or (b.overlay.material as CanvasItemMaterial).light_mode != CanvasItemMaterial.LIGHT_MODE_UNSHADED:
				ok = false
				info += " %s boss or telegraphs are lit;" % pair[0]
			var lit := lit_count(r)
			if lit < 2 or lit > 48:
				ok = false
				info += " %s phase %d: %d lights;" % [pair[0], phase, lit]
			# the ambient: N09 at 45 % of the lair during the fight (x0.9 in phase 3), never below 35 % anywhere
			var base := Look.mixed(r.look.mood, r.look.k).ambient as Color
			var ratio := (r.look.out.ambient as Color).r / base.r
			if pair[0] == "N09":
				var want: float = 0.45 * (0.9 if phase == 3 else 1.0)
				if absf(ratio - want) > 0.03:
					ok = false
					info += " N09 ambient x%.2f, wanted %.2f;" % [ratio, want]
			if ratio < 0.35 - 0.001:
				ok = false
				info += " %s ambient below 35 %% (%.2f);" % [pair[0], ratio]
			if pair[0] == "N15":
				var hz: RoomHaze = r.get_node_or_null("Haze")
				if hz == null or hz.rects.is_empty() or not hz.visible:
					ok = false
					info += " N15 haze missing;"
				Game.reduce_flash = true
				hz._apply()
				if hz.visible:
					ok = false
					info += " haze with Reduce flashing;"
				Game.reduce_flash = false
				hz._apply()
				if (r.get_node("Ambient") as RoomAmbient).fe.is_empty():
					ok = false
					info += " no embers off the bricks;"
			if pair[0] == "N09":
				var eyes := 0
				var rl: RoomLights = r.get_node("Lights")
				var c: Array = []
				rl._arena(c, b, Color.WHITE, Color.WHITE)
				for w in c:
					if w[7] == null:
						eyes += 1
				if eyes != 2:
					ok = false
					info += " N09 eyes %d;" % eyes
			if pair[0] == "N22":
				var c2: Array = []
				(r.get_node("Lights") as RoomLights)._arena(c2, b, Color.WHITE, Color.WHITE)
				var over := 0
				for w in c2:
					if w[8]:
						over += 1
				if over != 3:
					ok = false
					info += " N22 overheads %d;" % over
			r.queue_free()
			await frames(1)
	# the reviewer's verdict: bloom +0.3 for half a second
	var rv := start_fight("N22")
	await frames(2)
	rv.look.follow_room(0.0)
	for i in range(120):
		rv.time += 1.0 / 60.0
		rv.look.follow_room(1.0 / 60.0)
		rv.look.step(1.0 / 60.0)
	var b0 := float(rv.look.out.bloom)
	rv.boss.plan = {"id": "verdict", "ph": "active", "t": 0.3, "seq": 1, "fam": "", "tgt": "p1"}
	for i in range(20):
		rv.time += 1.0 / 60.0
		rv.look.follow_room(1.0 / 60.0)
		rv.look.step(1.0 / 60.0)
	var b1 := float(rv.look.out.bloom)
	rv.boss.plan = {}
	for i in range(90):
		rv.time += 1.0 / 60.0
		rv.look.follow_room(1.0 / 60.0)
		rv.look.step(1.0 / 60.0)
	var b2 := float(rv.look.out.bloom)
	if b1 - b0 < 0.2 or absf(b2 - b0) > 0.03:
		ok = false
		info += " verdict bloom %.2f -> %.2f -> %.2f;" % [b0, b1, b2]
	rv.queue_free()
	Game.gfx_url = -1
	return report("arenas", ok, info)
