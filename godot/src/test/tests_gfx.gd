extends RefCounted
class_name TestsGfx
# GFX-N (the NETWORK's look, docs/PLAN-metroidvania-gfx-network.md). Tests marked (render) need a real renderer: tools/godot/gfx-tests.sh runs them
# under xvfb with --rendering-driver opengl3; the others run headless like the rest.

const NAMES := ["moods", "gfxtier", "netbackdrop2", "gfxcontrast", "lights"]
const RENDER := ["gfxcontrast"]                                # the names that need a renderer (test-all runs them through gfx-tests.sh)
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
