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
	hud_layer.layer = 2                                 # above the NETWORK's post chain (layer 1): the HUD is never graded
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
	if Game.scene.begins_with("gfxbench:"):               # MVGN-17: average frame time of a room (gfxbench:<room>[:<frames>]); web: ?scene=gfxbench:N05
		_bench(Game.scene.substr(9).split(":"))
		return
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
		elif Game.scene == "race_intro" or Game.scene.begins_with("racetell:") or Game.scene.begins_with("racefight") or Game.scene.begins_with("racemoment:"):          # screenshot helpers: RACE CONDITION's intro from its first frame (race_intro), or the fight with a plan just begun (racetell:<id>[:<x>:<y>])
			var rt := Game.scene.split(":")
			var rx := float(rt[2]) if rt.size() > 2 else 120.0
			var ry := float(rt[3]) if rt.size() > 3 else 422.0
			manager.swap_to("T06", Vector2(rx, ry))
			var rtp = manager.player
			rtp.x = rx
			rtp.y = ry
			rtp.inv = 999.0
			var rtr: Room = manager.room
			if rt[0] == "race_intro":
				rtp.x = 120.0
				rtr._start_intro()
			else:
				Game.flags["intro:RACE"] = true
				rtr._start_intro()
				rtr.fight.t = 0.0
				rtr._begin_fight()
				var rtb = rtr.boss
				if rt[0] == "racetell":
					for rq in rtb.th:
						rq.gap = 999.0
					rtb._start(rt[1], "p1")
				if rt[0] == "racemoment":                                      # racemoment:<clash|lock|crack|split>: the moment itself, reached by stepping the room
					for rq in rtb.th:
						rq.gap = 999.0
					match rt[1]:
						"clash", "split":
							rtb._start("double", "p1")
							for f in range(200):
								rtp.inv = 999.0
								rtp.x = rx - 5.0 if f < (52 if rt[1] == "clash" else 12) else 330.0
								rtp.y = ry
								rtr.step(Game.STEP)
								if rt[1] == "clash" and rtb.clash_t0 > 0.0 and f > 60:
									for g in range(6):
										rtr.step(Game.STEP)
									break
								if rt[1] == "split" and rtb.th[0].plan.get("landed", false):
									break
						"lock":
							rtr.attacker = rtp
							for hb in rtb.hurtboxes():
								if hb.has("bob"):
									rtb.hit(1, 1.0, 0.0, "swipe", hb)
									break
							rtr.belfry.paint(3, 0, rtr.time)
							rtr.belfry.paint(3, 1, rtr.time)
							rtr.belfry.step_buffer(rtr.time)
							for f in range(30):
								rtr.step(Game.STEP)
						"crack":
							rtr.belfry.crack(2)
							for f in range(24):
								rtr.step(Game.STEP)
		elif Game.scene.begins_with("race:"):          # screenshot helper: RACE CONDITION's belfry (race:<hp>:<x>:<y>[:<demo>]); 1.0 phase 1, 0.4 phase 2, 0 the after-state (M1: the hall alone, the boss inert); demo: bells struck / fallen, cells corrupt / open
			var ra := Game.scene.substr(5).split(":")
			var rhp := float(ra[0])
			manager.swap_to("T06", Vector2(float(ra[1]) if ra.size() > 1 else 60.0, float(ra[2]) if ra.size() > 2 else 400.0))
			var rp = manager.player
			rp.x = float(ra[1]) if ra.size() > 1 else 60.0
			rp.y = float(ra[2]) if ra.size() > 2 else 400.0
			rp.inv = 999.0
			var rr2: Room = manager.room
			rr2.fight.state = "done"
			rr2.time = 20.0
			var rh: BelfryHall = rr2.belfry
			if rhp <= 0.0:
				rh.after = true
				rh.pin_in = true
				rh.pin_t0 = rr2.time - 3.0
				rh.segs = [[0.0, 0, BelfryHall.TICK_AFTER]]
			elif rhp < 0.7:
				rh.ph = 2
				rh.p2_t0 = rr2.time - 2.0
				rh.segs = [[0.0, 0, BelfryHall.TICK_P2]]
			if ra.size() > 3 and ra[3] == "demo":
				var tn: float = rr2.time
				rh.strike_t0[0] = tn - 0.2
				rh.amp[0] = 4.0
				rh.strike_t0[4] = tn - 0.45
				rh.amp[4] = 5.0
				if rh.ph == 1:
					rh.fall_t0[2] = tn - 3.0
					rh.fallen[2] = true
					rh.paint_t[0][2] = tn - 1.0
					rh.paint_t[1][5] = tn - 2.0
					rh.corrupt_t0[3] = tn - 1.5
					rh.corrupt_t0[6] = tn - 0.3
				else:
					rh.fall_t0[0] = tn - 3.0
					rh.fall_t0[3] = tn - 3.0
					rh.hole_t0[1] = tn - 1.0
					rh.hole_t0[5] = tn - 0.3
					rh.paint_t[0][3] = tn - 1.0
		elif Game.scene.begins_with("crawler:"):       # screenshot helper: CRAWLER OF THE WEB at an hp fraction, Clawd at a spot (crawler:<hp>:<x>:<y>)
			var ca := Game.scene.substr(8).split(":")
			manager.swap_to("N09")
			var cp = manager.player
			cp.x = float(ca[1]) if ca.size() > 1 else 250.0
			cp.y = float(ca[2]) if ca.size() > 2 else 300.0
			cp.inv = 999.0
			var cr: Room = manager.room
			if ca.size() > 4:                               # crawler:<hp>:<x>:<y>:<secs>:fw: THE FIREWALL is dead too (its story shows in the compaction)
				Game.flags["boss:FIREWALL"] = true
				Game.flags["boss:NULL"] = true
			cr._start_intro()
			cr.fight.t = 0.0
			cr._begin_fight()
			var cbb = cr.boss
			cbb.hpf = float(cbb.max_hp) * float(ca[0])
			cbb.hp = ceili(cbb.hpf)
			cbb.on_damage()
			if ca.size() > 3:                               # crawler:<hp>:<x>:<y>:<seconds into its last line> (the death scene)
				cbb.hpf = 0.0
				cbb.begin_death()
				cbb.die_t = 3.0 + float(ca[3])
				cbb.speak_t = 3.0
				cbb.core_y = 300.0
		elif Game.scene.begins_with("firewall:"):      # screenshot helper: THE FIREWALL's arena (firewall:<hp>:<x>:<y>[:<secs>]); 1.0 lobby, 0.6 furnace, 0.3 two walls, 0 the burned shell (M1: the hall alone, the boss inert)
			var fa := Game.scene.substr(9).split(":")
			var fhp := float(fa[0])
			manager.swap_to("N15", Vector2(float(fa[1]) if fa.size() > 1 else 60.0, float(fa[2]) if fa.size() > 2 else 150.0))
			var fp = manager.player
			fp.x = float(fa[1]) if fa.size() > 1 else 60.0
			fp.y = float(fa[2]) if fa.size() > 2 else 150.0
			fp.inv = 999.0
			var fr: Room = manager.room
			fr.fight.state = "done"
			var fh: HoneypotHall = fr.hpot
			fh.set_stage(0 if fhp >= 0.7 else (1 if fhp > 0.35 else (2 if fhp > 0.0 else 3)))
			if fh.stage == 1 or fh.stage == 2:
				var fsec := float(fa[3]) if fa.size() > 3 else 6.0
				fh.seed = 4242
				fh.pk_t0 = fr.time - fsec
				fh.pk_dir = 1 if fh.stage == 2 else 0
				for hc in [[6, 0.7], [8, 1.7], [10, 2.6], [12, 3.5]]:       # the hot floor at each of its moments
					fh.heat[hc[0]] = fr.time - float(hc[1])
		elif Game.scene == "fwintro" or Game.scene.begins_with("fwtell:"):      # screenshot helpers: THE FIREWALL's intro (the card shows in its last 1.2 s), or phase 1 with an attack just begun (fwtell:<cookies|hold|mat|crack>[:<x>])
			var ta := Game.scene.split(":")
			manager.swap_to("N15", Vector2(140.0, 150.0))
			var tp = manager.player
			tp.x = float(ta[2]) if ta.size() > 2 else 140.0
			tp.y = 176.0 - tp.h
			tp.inv = 999.0
			var tr: Room = manager.room
			tr._start_intro()
			if ta[0] == "fwtell":
				tr.fight.t = 0.0
				tr._begin_fight()
				var tb = tr.boss
				tb.idle_t = 999.0
				tb._start(ta[1], "p1")
		elif Game.scene.begins_with("fwcut:"):          # screenshot helper: THE FIREWALL's fake victory `secs` seconds in (fwcut:<secs>[:short])
			var ua := Game.scene.split(":")
			manager.swap_to("N15", Vector2(200.0, 150.0))
			var up = manager.player
			up.x = 200.0
			up.y = 176.0 - up.h
			up.inv = 999.0
			var ur: Room = manager.room
			if ua.size() > 2:
				Game.flags["reveal:FIREWALL"] = true
			else:
				Game.flags.erase("reveal:FIREWALL")
			ur._start_intro()
			ur.fight.t = 0.0
			ur._begin_fight()
			var ub = ur.boss
			ur.time = 20.0                                  # (a real fight is never at room time 0)
			ub.hpf = float(ub.max_hp) * 0.70
			ub._begin_cut()
			ub.shift_t0 = ur.time - float(ua[1])           # (its events up to that second run in the first frame)
			ur.hpot.burn_t0 = ub.shift_t0 + ub._mark("burn")
		elif Game.scene.begins_with("fwp2:"):           # screenshot helper: the furnace in phase 2, an attack just begun (fwp2:<x>:<y>[:<slam|sweep|banlist|429>[:<secs the packets have run>]])
			var pa2 := Game.scene.split(":")
			manager.swap_to("N15", Vector2(200.0, 150.0))
			var pp = manager.player
			pp.x = float(pa2[1]) if pa2.size() > 1 else 120.0
			pp.y = float(pa2[2]) if pa2.size() > 2 else 300.0
			pp.inv = 999.0
			var pr: Room = manager.room
			Game.flags["reveal:FIREWALL"] = true
			pr._start_intro()
			pr.fight.t = 0.0
			pr._begin_fight()
			var pb = pr.boss
			pr.hpot.set_stage(1)
			pb._end_cut()
			pr.hpot.seed = 4242
			pr.hpot.pk_t0 = pr.time - (float(pa2[4]) if pa2.size() > 4 else 6.0)
			pb.idle_t = 999.0
			if pa2.size() > 3:
				if pa2[3] == "429":
					pr.attacker = pp
					for k in range(3):
						pb._rate_ok("p1")
						pr.time += 0.1
				else:
					pb._start(pa2[3], "p1")
		elif Game.scene.begins_with("fwp3:"):           # screenshot helper: phase 3 (fwp3:<x>:<y>[:<punch|flame|split|dropall|green|slam>[:<secs the packets have run>]])
			var qa := Game.scene.split(":")
			manager.swap_to("N15", Vector2(200.0, 150.0))
			var qp = manager.player
			qp.x = float(qa[1]) if qa.size() > 1 else 120.0
			qp.y = float(qa[2]) if qa.size() > 2 else 300.0
			qp.inv = 999.0
			var qr: Room = manager.room
			Game.flags["reveal:FIREWALL"] = true
			qr._start_intro()
			qr.fight.t = 0.0
			qr._begin_fight()
			var qb = qr.boss
			qr.hpot.set_stage(1)
			qb._end_cut()
			qr.hpot.set_stage(2)
			qb.hpf = float(qb.max_hp) * 0.3
			qb._end_scene3()
			qr.hpot.seed = 4242
			qr.hpot.pk_t0 = qr.time - (float(qa[4]) if qa.size() > 4 else 6.0)
			qb.idle_t = 999.0
			qb.hop_cd = 999.0
			qb.drop_t = 999.0
			if qa.size() > 3:
				match qa[3]:
					"split":
						qb._begin_split()
						qb.face2_y = 330.0
						qb.face_y = 260.0
					"dropall":
						var ix: Vector2 = qr.hpot.inner_x()
						var dh: Dictionary = qb.hz_add("dropall", 0.9, [roundi(ix.x), roundi(ix.y)])
						dh.t0 = qr.time - 0.45
					"green":
						qr.hpot.green_t0 = qr.time - 30.0
						qb.hpf = float(qb.max_hp) * 0.09
					_:
						qb._start(qa[3], "p1")
		elif Game.scene.begins_with("fwdie:"):          # screenshot helper: THE FIREWALL's death scene `secs` seconds in (fwdie:<secs>[:<x>:<y>])
			var da := Game.scene.split(":")
			manager.swap_to("N15", Vector2(200.0, 150.0))
			var dp = manager.player
			dp.x = float(da[2]) if da.size() > 2 else 150.0
			dp.y = float(da[3]) if da.size() > 3 else 300.0
			dp.inv = 999.0
			var dr: Room = manager.room
			Game.flags["reveal:FIREWALL"] = true
			dr._start_intro()
			dr.fight.t = 0.0
			dr._begin_fight()
			var db = dr.boss
			dr.hpot.set_stage(1)
			db._end_cut()
			dr.hpot.set_stage(2)
			db._end_scene3()
			dr.hpot.seed = 4242
			dr.hpot.pk_t0 = dr.time - 6.0
			db.hpf = 0.0
			db.begin_death()
			db.die_t = float(da[1])
			db.spoke = true                                  # (no sounds on the way)
			db.fine_said = true
			db.collapsed = db.die_t >= db._collapse_t0()
			if db.collapsed:
				dr.hpot.set_stage(3)
		elif Game.scene == "fwloss":                    # screenshot helper: THE FIREWALL's loss menu (both down in its fight)
			manager.swap_to("N15", Vector2(200.0, 150.0))
			var xp = manager.player
			xp.inv = 999.0
			var xr: Room = manager.room
			Game.flags["reveal:FIREWALL"] = true
			xr._start_intro()
			xr.fight.t = 0.0
			xr._begin_fight()
			xr.boss.open_loss()
		elif Game.scene.begins_with("n01scene:"):       # screenshot helper: N01's first words, `secs` in (n01scene:<secs>)
			Game.flags["net:refused"] = true
			FirewallBoss.ensure_lines()
			manager.swap_to("N01")
			hud.refused_t = float(Game.scene.substr(9))
			hud.refused_say = [true, true]
		elif Game.scene.begins_with("fwicon:"):         # screenshot helper: the signal icon (fwicon:red | fwicon:green)
			Game.flags["net:refused"] = true
			manager.swap_to("N02")
			if Game.scene.ends_with("green"):
				Game.flags["boss:FIREWALL"] = true
				hud.fw_prev = true
				hud.fw_green_t = 2.0
		elif Game.scene.begins_with("sign:"):           # screenshot helper: a sign read (sign:<room>:<n>[:after] after = THE FIREWALL is dead)
			var ga := Game.scene.split(":")
			if ga.size() > 3:
				Game.flags["boss:FIREWALL"] = true
			manager.swap_to(ga[1])
			var gs: Dictionary = manager.room.signs[int(ga[2])]
			manager.player.x = float(gs.x) - 5.0
			manager.player.y = float(gs.y) - manager.player.h
			manager.player.inv = 999.0
		elif Game.scene.begins_with("fwafter"):         # screenshot helper: N15 once THE FIREWALL is dead (fwafter[:<x>:<y>])
			var aa := Game.scene.split(":")
			Game.flags["boss:FIREWALL"] = true
			manager.swap_to("N15", Vector2(float(aa[1]) if aa.size() > 1 else 40.0, float(aa[2]) if aa.size() > 2 else 150.0))
			manager.player.inv = 999.0
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


func _bench(a: PackedStringArray) -> void:
	manager.swap_to(a[0])
	var n := int(a[1]) if a.size() > 1 else 600
	for i in range(60):
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in range(n):
		await get_tree().process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	print("BENCH %s %s %.2f ms/frame %.1f fps" % [a[0], Game.GFX_NAMES[Game.gfx_tier], ms, 1000.0 / ms])
	if not OS.has_feature("web"):
		get_tree().quit()

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
	var lb = _loss_boss()
	if lb != null and manager.mode != "guest":           # a tap on a line of the loss menu
		var lp := Vector2.ZERO
		var lh := false
		if event is InputEventScreenTouch and event.pressed:
			lp = event.position
			lh = true
		elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			lp = event.position
			lh = true
		if lh and not (touch.visible and touch.claims(lp)):
			var row: int = lb.loss_row_at(to_game(lp))
			if row >= 0:
				lb.loss_sel = row
				_loss_choose(row)
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
	var lb = _loss_boss()
	if lb != null:                                       # THE FIREWALL asks: retry, or back to the last commit ([start] chooses here, it does not pause)
		_loss_step(lb)
		return
	_map_button()
	if Controls.pressed.get("pause", false) or Controls.pressed.get("start", false):
		set_paused(true)

# ---- THE FIREWALL's loss menu (everybody is down in its fight, 16-firewall-build.md 7.1): the host picks with keys or a tap, the guest only sees it
const FW_RETRY := Vector2(24.0, 144.0)                 # `retry`: both just inside the arena's west door

func _loss_boss():
	if manager == null or manager.room == null:
		return null
	var b = manager.room.boss
	if b != null and is_instance_valid(b) and b.get("loss_on") == true:
		return b
	return null

func _loss_step(b) -> void:
	if manager.mode == "guest":
		return
	if Controls.pressed.get("up", false) or Controls.pressed.get("down", false):
		b.loss_sel = 1 - int(b.loss_sel)
		Audio.sfx("uiMove")
	if Controls.pressed.get("jump", false) or Controls.pressed.get("start", false) or Controls.pressed.get("attack", false):
		_loss_choose(int(b.loss_sel))

func _loss_choose(i: int) -> void:
	Audio.sfx("uiOk")
	var rid: String = manager.room.id
	var host_coop: bool = coop != null and coop.role == "host" and coop.guest_here and coop.remote != null
	if i == 0:
		if host_coop:
			coop.retry_both(rid, FW_RETRY)
		else:
			manager.respawn(true, rid, FW_RETRY)
	elif host_coop:
		coop._respawn_both()
	else:
		manager.respawn(true)

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
			if r.boss != null and is_instance_valid(r.boss) and r.boss.has_method("music_now"):
				want = r.boss.music_now(want)               # a boss with its own score (CRAWLER OF THE WEB: per phase, silence when it falls)
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
