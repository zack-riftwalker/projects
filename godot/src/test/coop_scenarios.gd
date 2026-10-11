class_name CoopScenarios
extends Node
# The co-op scenarios (tools/godot/coop-test.sh). Each process (host and guest) runs the same scenario and prints
# `COOP <scenario> <role> PASS|FAIL <info>`. Small scripted bots; nothing here is used by the game itself.

var main
var role := ""
var slow := 1.0
var done := false

func _init(m) -> void:
	main = m
	role = Game.net_role if Game.net_role != "" else "solo"
	slow = 2.5 if OS.get_environment("SCN_SLOW") == "1" else 1.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().physics_frame
	var name := Game.scenario
	var r := false
	var info := ""
	var res: Array = await call("sc_" + name.replace("-", "_"))
	r = res[0]
	info = res[1]
	print("COOP %s %s %s %s" % [name, role, "PASS" if r else "FAIL", info])
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if r else 1)

func wait_until(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0 * slow:
		if cond.call():
			return true
		await get_tree().physics_frame
	return false

func wait_secs(secs: float) -> void:
	await get_tree().create_timer(secs).timeout

func mgr() -> RoomManager:
	return main.manager

func coop() -> Coop:
	return main.coop

# the host puts a creature in the guest's room so both can see it
func spawn_bug(r: Room, x: float, y: float) -> Bug:
	var b := Bug.new(r, 0, 0, false)
	b.x = x
	b.y = y
	b.speed = 0.0
	b.nid = r.next_nid
	r.next_nid += 1
	r.ents.append(b)
	r.entity_root.add_child(b)
	return b

func clear_creatures(r: Room) -> void:
	for e in r.ents:
		e.queue_free()
	r.ents.clear()

func floor_y(r: Room, x: float, from_row: int) -> float:
	for ty in range(from_row, r.h):
		if r.grid.solid(floori((x + 5.0) / 16.0), ty):
			return ty * 16.0 - 10.0
	return r.ph - 26.0

func wait_joined() -> bool:
	if role == "host":
		return await wait_until(func(): return coop().guest_here and coop().guest_ready and coop().remote != null, 10.0)
	return await wait_until(func(): return coop().started and mgr().room != null and mgr().player != null, 10.0)

# ---------------------------------------------------------------- scenarios
func sc_co_connect() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var ok := await wait_until(func(): return coop().remote != null and coop().remote.samples.size() > 2, 3.0)
		var same: bool = coop()._remote_room() == mgr().room
		return [ok and same, "remote body seen (samples %d), same room %s" % [coop().remote.samples.size(), same]]
	# the guest: a snapshot with every creature of R01
	var rows := FileAccess.get_file_as_string("res://src/world/rooms/R01.txt")
	var want := 0
	for ch in rows:
		if ch in "batGZ":
			want += 1
	var ok2 := await wait_until(func(): return mgr().room.ents.size() >= want and coop().snaps_applied > 0, 3.0)
	return [ok2, "creatures %d of %d, snapshots %d" % [mgr().room.ents.size(), want, coop().snaps_applied]]

# the host's effects and sounds reach the guest in that room (the JS game relayed them; the Godot guest saw none of them), and
# the host no longer hears the sounds of the guest's room
func sc_co_fx() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "R02", 10.0)
		await wait_secs(1.0)
		var r: Room = coop()._remote_room()
		var s0: int = Audio.other_room_skipped
		var b := spawn_bug(r, coop().remote.x + 40.0, floor_y(r, coop().remote.x + 40.0, 9) + 1.0)
		await wait_secs(0.5)
		Audio.room_ctx = r                  # (a world event in that room, as RoomManager.tick would run it)
		b.hit(9, 1.0, 0.0, "swipe", b)
		Audio.room_ctx = null
		var killed: bool = b.dead            # (a dead creature is freed soon after)
		await wait_secs(2.0)
		var skipped: int = Audio.other_room_skipped - s0
		return [there and killed and skipped > 0, "guest in R02 %s, bug killed %s, sounds of that room not played here %d" % [there, killed, skipped]]
	await wait_secs(1.0)
	mgr().swap_to("R02", Vector2(60.0, 100.0))
	var f0: int = coop().fx_played
	var got := await wait_until(func(): return coop().fx_played > f0 + 2, 8.0)
	return [got, "host effects played here: %d" % (coop().fx_played - f0)]

# Soak (the JS game had one): two bots play for SOAK_S seconds (90 by default) on a bad line (coop-test.sh runs this one with
# lag, jitter and stalls): they run, jump, claw and dash, die, change rooms, pause, rest, and the guest's line drops once.
# Nothing is checked step by step: the watchdog's rules (any INVARIANT line fails the run) and script errors are the test.
func _bot(rng: RandomNumberGenerator, st: Dictionary) -> Dictionary:
	st.t -= get_physics_process_delta_time()
	if st.t <= 0.0:
		st.t = rng.randf_range(0.6, 2.0)
		st.dir = "right" if rng.randf() < 0.6 else "left"
	var inp := {st.dir: true}
	if rng.randf() < 0.04:
		inp["jump"] = true
	if rng.randf() < 0.08:
		inp["attack"] = true
	if rng.randf() < 0.01:
		inp["dash"] = true
	return inp

func sc_co_soak() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var secs := float(OS.get_environment("SOAK_S")) if OS.get_environment("SOAK_S") != "" else 90.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if role == "host" else 11
	var st := {"t": 0.0, "dir": "right"}
	var t0 := Time.get_ticks_msec()
	var done := {}
	var rooms := ["R01", "R02", "R03", "R04"]
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var p = mgr().player
		Controls.script_input = _bot(rng, st)
		if role == "host":
			if t > 15.0 and not done.has("pause"):
				done["pause"] = true
				main.set_paused(true)
				await wait_secs(2.0)
				main.set_paused(false)
			if t > 30.0 and not done.has("die") and p != null and not p.dead:
				done["die"] = true
				p.hp = 0
				p.die()
			if t > 45.0 and not done.has("room"):
				done["room"] = true
				mgr().swap_to(rooms[rng.randi() % rooms.size()], Vector2(60.0, 100.0))
			if t > 62.0 and not done.has("restart"):
				done["restart"] = true
				main.pause_menu.restart_requested.emit()
		else:
			if t > 20.0 and not done.has("die") and p != null and not p.dead:
				done["die"] = true
				p.hp = 0
				p.die()
			if t > 35.0 and not done.has("room"):
				done["room"] = true
				mgr().swap_to("R02", Vector2(60.0, 100.0))
			if t > 50.0 and not done.has("drop"):
				done["drop"] = true
				Net._force_close()           # the line drops: the relay keeps the seat, the guest comes back with its token
			if t > 70.0 and not done.has("rest") and mgr().room.id == "R02" and not mgr().room.cps.is_empty() and p != null:
				done["rest"] = true
				mgr().rest(mgr().room, 0)
		await get_tree().physics_frame
	Controls.script_input = {}
	await wait_secs(4.0)                 # let it settle: the line comes back, deaths resolve
	var ok: bool = Game.errors == 0 and coop().watchdog.count == 0 and Net.is_open
	var info := "errors %d, watchdog reports %d, line open %s, events done %s" % [Game.errors, coop().watchdog.count, Net.is_open, str(done.keys())]
	if role == "host":
		ok = ok and coop().remote != null and coop().guest_ready
	else:
		var s0: int = coop().snaps_applied
		var flowing := await wait_until(func(): return coop().snaps_applied > s0 + 5, 5.0)
		ok = ok and flowing
		info += ", snapshots flowing %s" % flowing
	return [ok, info]

# the watchdog itself: a stray partner body (a ghost, as G5 made) must be reported within a few seconds
func sc_co_watchdog() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		var ghost := RemotePlayer.new(mgr().room)
		mgr().room.add_child(ghost)
		var seen := await wait_until(func(): return coop().watchdog.count > 0, 6.0)
		ghost.queue_free()
		return [seen, "ghost body reported: %s" % seen]
	await wait_secs(8.0)
	return [true, "guest idle"]

# the pause is state: a guest that missed the host's pause event (here: never sent) still pauses and resumes with the host
func sc_co_pausestate() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(2.0)
		main.paused = true                  # paused without the event, as if it had been lost
		main.pause_menu.open()
		await wait_secs(4.0)
		main.paused = false
		main.pause_menu.close()
		await wait_secs(4.0)
		return [true, "paused 4 s without telling"]
	var paused := await wait_until(func(): return main.paused, 6.0)
	var resumed := await wait_until(func(): return not main.paused, 7.0)
	return [paused and resumed, "followed the host's pause %s and resume %s" % [paused, resumed]]

# the guest's log lines and its script errors reach the host's log (one copy from the PC has both sides)
func _boom():
	var d := {}
	return d["boom"]

func sc_co_log() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var has := func(sub: String) -> bool:
		for e in Game.log_buf:
			if String(e[1]).contains(sub):
				return true
		return false
	if role == "host":
		var line := await wait_until(func(): return has.call("P2> hello from P2"), 8.0)
		var err := await wait_until(func(): return has.call("P2> ERROR") and has.call("boom"), 8.0)
		return [line and err, "guest line in the host log %s, guest error in the host log %s" % [line, err]]
	await wait_secs(1.0)
	Game.dlog("hello from P2")
	_boom()
	await wait_secs(4.0)
	return [Game.errors >= 1, "errors counted here %d" % Game.errors]

func sc_co_hit() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var r: Room = mgr().room
		clear_creatures(r)
		await wait_secs(0.5)
		var gx: float = coop().remote.x
		var b := spawn_bug(r, gx + 22.0, floor_y(r, gx, 9) + 1.0)
		var dead := await wait_until(func(): return b.dead, 8.0)
		var ok_count: int = int(coop().verdicts.get("OK", 0))
		await wait_secs(0.5)
		return [dead and ok_count == 1, "bug dead=%s, verdicts %s" % [dead, str(coop().verdicts)]]
	# the guest: wait for the creature, swing once
	var r2: Room = mgr().room
	var seen := await wait_until(func(): return r2.ents.size() > 0, 6.0)
	if not seen:
		return [false, "never saw the creature"]
	await wait_secs(0.8)
	var p = mgr().player
	var bug = r2.ents[0]
	p.x = bug.x - 18.0
	p.y = bug.y - 1.0
	p.face = 1.0
	await wait_secs(0.3)
	Controls.script_input = {"attack": true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	Controls.script_input = {}
	var gone := await wait_until(func(): return r2.ents.size() == 0, 3.0)
	return [gone, "creature gone on the guest: %s" % gone]

# the guest jumps on a creature: the stomp must kill it on the host (it bounced but did no damage: the host compared the
# guest's late, higher position with the creature and said TOO FAR)
func sc_co_stomp() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var r: Room = mgr().room
		clear_creatures(r)
		await wait_secs(0.5)
		var gx: float = coop().remote.x
		var b := spawn_bug(r, gx + 30.0, floor_y(r, gx + 30.0, 9) + 1.0)
		var dead := await wait_until(func(): return b.dead, 8.0)
		await wait_secs(0.5)
		return [dead, "bug dead=%s, verdicts %s" % [dead, str(coop().verdicts)]]
	var r2: Room = mgr().room
	var seen := await wait_until(func(): return r2.ents.size() > 0, 6.0)
	if not seen:
		return [false, "never saw the creature"]
	await wait_secs(0.8)
	var p = mgr().player
	var bug = r2.ents[0]
	p.x = bug.x
	p.y = bug.y - 48.0
	p.vy = 0.0
	var bounced := await wait_until(func(): return p.vy < -100.0, 2.0)
	var gone := await wait_until(func(): return r2.ents.size() == 0, 3.0)
	return [gone, "bounced %s, creature gone on the guest: %s" % [bounced, gone]]

func sc_co_rooms() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var r1: Room = mgr().room
		var t0: float = r1.time
		var ok := await wait_until(func(): return mgr().rooms.has("R02") and coop()._remote_room() != null and coop()._remote_room().id == "R02", 12.0)
		await wait_secs(1.0)
		var running: bool = r1.time > t0 + 0.5
		return [ok and running and mgr().rooms.size() == 2, "rooms %s, R01 kept running %s" % [str(mgr().rooms.keys()), running]]
	var p = mgr().player
	var r: Room = mgr().room
	await wait_secs(1.0)
	p.x = r.pw - 40.0
	p.y = floor_y(r, p.x, 9)
	Controls.script_input = {"right": true}
	var moved := await wait_until(func(): return mgr().room.id == "R02", 6.0)
	Controls.script_input = {}
	var snaps0: int = coop().snaps_applied
	var got := await wait_until(func(): return coop().snaps_applied > snaps0 + 3 and mgr().room.ents.size() > 0, 5.0)
	return [moved and got, "in %s, creatures %d, snapshots +%d" % [mgr().room.id, mgr().room.ents.size(), coop().snaps_applied - snaps0]]

func sc_co_summon() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		# the guest goes to R03; the host walks into R05 and crosses the trigger
		await wait_secs(1.0)
		mgr().swap_to("R05", Vector2(40.0, 100.0))
		var p = mgr().player
		p.y = floor_y(mgr().room, 40.0, 7)
		await wait_secs(1.5)
		var ok_g := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "R03", 8.0)
		p.x = 100.0
		var t0 := Time.get_ticks_msec()
		var arrived := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "R05", 8.0)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		var active := await wait_until(func(): return mgr().room.fight.state == "active", 6.0)
		var hp: int = mgr().room.boss.max_hp if mgr().room.boss != null else -1
		return [ok_g and arrived and active and hp == 90, "guest in R03 first %s, arrived in R05 after %.1f s, fight active %s, boss hp %d" % [ok_g, secs, active, hp]]
	await wait_secs(1.0)
	var r: Room = mgr().room
	mgr().swap_to("R03", Vector2(60.0, 100.0), null, true)
	mgr().player.y = floor_y(mgr().room, 60.0, 9)
	var banner := await wait_until(func(): return not coop().guest_summon.is_empty(), 15.0)
	var t1 := Time.get_ticks_msec()
	var there := await wait_until(func(): return mgr().room.id == "R05", 8.0)
	var s2 := (Time.get_ticks_msec() - t1) / 1000.0
	return [banner and there and s2 < 4.5, "banner %s, arrived after %.1f s" % [banner, s2]]

func sc_co_revive() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	mgr().room.fight_active = true             # the revive countdown is a boss-fight rule
	if role == "host":
		await wait_secs(2.0)
		var down := await wait_until(func(): return coop().remote.dead, 10.0)
		await wait_secs(0.5)
		var hud_ok: bool = String(main.hud.partner_text).begins_with("back in")       # the partner's line says when it gets up
		var t0 := Time.get_ticks_msec()
		var up := await wait_until(func(): return not coop().remote.dead, 12.0)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		await wait_secs(2.0)
		var p = mgr().player
		p.hp = 0
		p.die()
		var both := await wait_until(func(): return coop().remote.dead and p.dead, 5.0)
		var back := await wait_until(func(): return mgr().player != null and not mgr().player.dead and not coop().remote.dead and mgr().room.id == "R01", 10.0)
		return [down and hud_ok and up and secs > 5.0 and secs < 8.5 and both and back, "guest down %s (hud %s), back after %.1f s, both down %s, both back on their benches %s" % [down, hud_ok, secs, both, back]]
	await wait_secs(3.0)
	var p2 = mgr().player
	p2.x += 90.0                        # fall away from the host: the revive puts P2 next to it (as the JS game)
	await wait_secs(0.5)
	p2.hp = 0
	p2.die()
	await wait_secs(0.5)
	var hud2: String = String(main.hud.me_text)                                      # "DOWN - BACK IN 6"
	var t1 := Time.get_ticks_msec()
	var up2 := await wait_until(func(): return not p2.dead, 12.0)
	var secs2 := (Time.get_ticks_msec() - t1) / 1000.0
	var hp_back: int = p2.hp
	var hb = coop().host_body
	var beside: bool = hb != null and absf(p2.x - hb.x) < 30.0
	# then both go down
	await wait_secs(2.0)
	p2.hp = 0
	p2.die()
	var back2 := await wait_until(func(): return mgr().player != null and not mgr().player.dead and mgr().room.id == "R01" and mgr().player.hp == mgr().player.max_hp, 10.0)
	return [up2 and hud2.begins_with("DOWN - BACK IN") and secs2 > 4.5 and secs2 < 9.0 and hp_back == 3 and beside and back2, "hud '%s', back after %.1f s with %d hp, beside the host %s, after both down: alive in %s hp %d" % [hud2, secs2, hp_back, beside, mgr().room.id, mgr().player.hp]]

func sc_co_crack() -> Array:
	Game.tools.bash = true
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("R07", Vector2(33.0 * 16.0 + 40.0, 100.0))
		var r: Room = mgr().room
		var left := func():
			var n := 0
			for ty in range(2, 13):
				for tx in range(37, 40):
					if r.grid.tile(tx, ty) == TileGrid.CRACK:
						n += 1
			return n
		var ok := await wait_until(func(): return left.call() == 0, 15.0)
		var flags := 0
		for ty in range(2, 13):
			for tx in range(37, 40):
				if Game.flag("crack:R07:%d:%d" % [tx, ty]):
					flags += 1
		return [ok and flags == 33, "host: cracked tiles left %d, flags %d" % [left.call(), flags]]
	await wait_secs(2.0)
	mgr().swap_to("R07", Vector2(34.0 * 16.0, 100.0), null, true)
	var r2: Room = mgr().room
	var p = mgr().player
	p.y = floor_y(r2, p.x, 9)
	p.vx = 0.0
	await wait_secs(1.5)
	Controls.script_input = {"right": true, "dash": true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	Controls.script_input = {"right": true}
	var left2 := func():
		var n := 0
		if not is_instance_valid(r2):           # the guest already walked on through the wall and the room was dropped (it only shows the current room)
			return 0
		for ty in range(2, 13):
			for tx in range(37, 40):
				if r2.grid.tile(tx, ty) == TileGrid.CRACK:
					n += 1
		return n
	var ok2 := await wait_until(func(): return left2.call() == 0, 8.0)
	await wait_secs(1.5)
	Controls.script_input = {}
	var flags2 := 0
	for ty in range(2, 13):
		for tx in range(37, 40):
			if Game.flag("crack:R07:%d:%d" % [tx, ty]):
				flags2 += 1
	return [ok2 and left2.call() == 0 and flags2 == 33, "guest: cracked tiles left %d, confirmed flags %d (x %.0f y %.0f bash %s dash_id %d)" % [left2.call(), flags2, p.x, p.y, str(p.tools.get("bash")), p.dash_id]]

func sc_co_resume() -> Array:
	var seen: Array = []
	if role == "host":
		Net.reliable.connect(func(k, d): if k == "testseq": seen.append(int(d.n)))      # before anyone joins: event 0 must not be missed
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var rp = coop().remote
		var id0 := rp.get_instance_id()
		await wait_until(func(): return seen.size() >= 20, 25.0)
		var same: bool = coop().remote != null and coop().remote.get_instance_id() == id0 and coop().guest_here
		var in_order := true
		for i in range(seen.size()):
			if seen[i] != i:
				in_order = false
		return [seen.size() == 20 and in_order and same, "events %d in order=%s, same body %s" % [seen.size(), in_order, same]]
	var p = mgr().player
	var pid := p.get_instance_id()
	var room_id: String = mgr().room.id
	var tok_before: String = Net.token
	for i in range(20):
		Net.rel("testseq", {"n": i})
		if i == 6:
			Net.ws.close(4000, "test")             # the line dies without a clean leave
		await wait_secs(0.25)
	var back := await wait_until(func(): return Net.is_open and not coop().line_down, 15.0)
	await wait_until(func(): return Net.rel_out.is_empty(), 8.0)       # the host must have every event before this process leaves
	await wait_secs(0.5)
	var same: bool = mgr().player != null and mgr().player.get_instance_id() == pid and mgr().room.id == room_id
	return [back and same, "back on the line %s, same body and room %s" % [back, same]]

func sc_co_netfields() -> Array:
	# every class: net_fields() -> JSON -> a fresh puppet's net_apply() -> net_fields() again must give the same numbers
	Game.load_meta()
	var room := Room.new()
	main.world.add_child(room)
	room.load_room("R05")
	room.build_nodes(null, null, false)
	var bad: Array = []
	for cls in range(6):
		var e = NetClasses.make(cls, room)
		e.puppet = false
		match cls:
			2:
				e.wait = 0.37
				e.on_ground = true
			3:
				e.state = "telegraph"
				e.state_t = 0.31
				e.face = 1.0
				e.turn_t = 0.4
			4:
				e.state = "down"
				e.state_t = 1.23
			5:
				e.hpf = 41.5
				e.max_hp = 60
				e.phase = 2
				e.st = "poke"
				e.fade = 0.55
				e.cur.x = 120.25
				e.cur.y = 90.5
				e.cur.a = 1.23
				e.cur.mode = "aim"
				e.active = true
				e.rain_marks = [{"x": 64.0, "t": 0.5, "done": false}]
				e.dmarks = [Vector2(100.5, 120.25)]
				e.land = Vector2(200.0, 176.0)
		var f1: Array = e.net_fields()
		var json = JSON.parse_string(JSON.stringify(f1))
		var p2 = NetClasses.make(cls, room)
		p2.net_apply(json)
		var f2: Array = p2.net_fields()
		if not _same(f1, f2):
			bad.append("%s: %s != %s" % [NetClasses.NAMES[cls], str(f1), str(f2)])
		e.queue_free()
		p2.queue_free()
	return [bad.is_empty(), "6 classes, mismatches: %s" % str(bad)]

func _same(a, b) -> bool:
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _same(a[i], b[i]):
				return false
		return true
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) < 0.011
	return a == b

func sc_co_badline() -> Array:
	var a: Array = await sc_co_hit()
	if not a[0]:
		return [false, "hit: " + str(a[1])]
	return [true, "hit ok on a bad line"]

# a fresh page joins with the code while the host keeps its state: the reliable channel must start over (G1, G5)
func sc_co_rejoin() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(3.0)
		var back := await wait_until(func(): return coop().guest_here and coop().guest_ready and coop().remote != null, 12.0)
		await wait_secs(1.0)
		var bodies: int = main.find_children("*", "RemotePlayer", true, false).size()
		return [back and bodies == 1, "guest ready again %s, RemotePlayer nodes %d (want 1)" % [back, bodies]]
	await wait_secs(2.0)
	main.shop_menu.pending = "hot_reload"                 # a purchase asked on the old link
	Net.ws.close(4000, "test")
	Net.connect_as("guest", Game.net_code)          # what a reloaded page does: fresh reliable channel, no token
	coop().started = false
	var again := await wait_until(func(): return coop().started, 8.0)
	var unstuck: bool = main.shop_menu.pending == ""
	var snaps0: int = coop().snaps_applied
	var flow := await wait_until(func(): return coop().snaps_applied > snaps0 + 5, 6.0)
	return [again and flow and unstuck, "restarted %s, snapshots flowing %s (+%d), stale purchase cleared %s" % [again, flow, coop().snaps_applied - snaps0, unstuck]]

# both down in the same room: both respawn there and the link keeps working (G2)
func sc_co_wipe() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(2.0)
		var p = mgr().player
		p.hp = 0
		p.die()
		var both := await wait_until(func(): return coop().remote.dead and p.dead, 8.0)
		var back := await wait_until(func(): return mgr().player != null and not mgr().player.dead and not coop().remote.dead, 12.0)
		await wait_secs(1.5)
		var rr = coop()._remote_room()
		return [both and back and rr == mgr().room, "both down %s, back %s, _remote_room %s" % [both, back, str(rr)]]
	await wait_secs(2.0)
	var p2 = mgr().player
	p2.hp = 0
	p2.die()
	await wait_until(func(): return not p2.dead, 14.0)
	await wait_secs(1.0)
	var snaps0: int = coop().snaps_applied
	var flow := await wait_until(func(): return coop().snaps_applied > snaps0 + 5, 5.0)
	var bodies: int = mgr().room.find_children("*", "RemotePlayer", true, false).size()
	return [flow and bodies <= 1, "snapshots flow after the wipe: %s (+%d), host bodies %d" % [flow, coop().snaps_applied - snaps0, bodies]]

# the host is seen as gone (before the game starts, or it reloads) and comes back: the guest must not stay locked (G3)
func sc_co_hostgone() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(6.0)
		return [true, "host waited"]
	coop()._on_host(false, false, false)          # what the relay says to a guest whose host is not there
	await wait_secs(0.3)
	var locked: bool = Controls.locked
	coop()._on_host(true, false, false)
	Net.message.emit("start", {"e": Net.epoch, "save": {"tools": Game.tools, "flags": Game.flags, "diff": Game.diff, "coop_hp_pct": Game.coop_hp_pct, "fragments": Game.fragments}, "you": {"room": "R01", "x4": 400, "y4": 400, "hp": 5, "max_hp": 5}, "tm": 0.0})
	await wait_secs(0.5)
	return [not Controls.locked, "locked after host left %s, still locked after host back + start: %s" % [locked, Controls.locked]]

# the guest leaves a room the host is in and comes back: no stale room, no doubled creatures or host bodies (G6)
func sc_co_return() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(14.0)
		return [true, "host stayed in %s" % mgr().room.id]
	await wait_until(func(): return coop().snaps_applied > 5 and coop().host_body != null, 8.0)
	mgr().swap_to("R02", Vector2(60.0, 100.0))
	await wait_secs(2.0)
	var rooms_away: Array = mgr().rooms.keys()
	mgr().swap_to("R01", Vector2(60.0, 100.0))
	await wait_secs(3.0)
	var r: Room = mgr().room
	var bodies := 0
	for c in r.get_children():
		if c is RemotePlayer:
			bodies += 1
	return [bodies == 1 and r.ents.size() == coop().puppets.size() and rooms_away == ["R02"], "ents %d, puppets %d, host bodies %d (want 1), rooms while away %s" % [r.ents.size(), coop().puppets.size(), bodies, str(rooms_away)]]

# the host is down and the guest leaves: the host must not lie there for good (G4)
func sc_co_hostdown() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	mgr().room.fight_active = true             # the revive countdown is a boss-fight rule
	if role == "host":
		await wait_secs(2.0)
		var p = mgr().player
		p.hp = 0
		p.die()
		await wait_until(func(): return p.dead and p.downed, 3.0)
		var up := await wait_until(func(): return mgr().player != null and not mgr().player.dead, 5.0)
		return [up and not coop().guest_here, "host up again: %s, guest_here %s" % [up, coop().guest_here]]
	await wait_secs(3.0)
	Net.closing = true                       # like the web build: the close frame goes out at once (role stays, so poll() keeps flushing)
	Net.ws.close(4010, "leave")
	await wait_secs(8.0)
	return [true, "guest left"]

# a friend joins during a boss fight (the arena's previous room has no start_pos) (G32)
func sc_co_joinfight() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("R05", Vector2(60.0, 100.0))
		mgr().player.y = floor_y(mgr().room, 60.0, 7)
		await wait_secs(0.5)
		mgr().room.fight_active = true                 # as if the arena doors were shut
		coop()._guest_left()
		coop()._guest_joined()
		await wait_secs(2.0)
		return [coop().remote != null and coop().remote.get_parent() != null, "remote parent %s" % str(coop().remote.get_parent() if coop().remote != null else null)]
	var starts := [0]
	Net.message.connect(func(t, _m): if t == "start": starts[0] += 1)
	var again := await wait_until(func(): return starts[0] >= 1, 8.0)
	return [again, "start received again: %s" % again]

# the guest rests at a bench in R02, then both go down: the guest comes back at that bench (G9)
func sc_co_bench() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var known := await wait_until(func(): return coop().guest_bench == "R02", 10.0)
		await wait_secs(1.0)
		var p = mgr().player
		p.hp = 0
		p.die()
		await wait_until(func(): return coop().remote.dead and p.dead, 5.0)
		var back := await wait_until(func(): return mgr().player != null and not mgr().player.dead and not coop().remote.dead and coop()._remote_room() != null and coop()._remote_room().id == "R02", 12.0)
		return [known and back, "bench known %s, guest respawned in R02 %s" % [known, back]]
	await wait_secs(1.0)
	mgr().swap_to("R02", Vector2(60.0, 100.0))
	await wait_secs(1.0)
	mgr().rest(mgr().room, 0)
	await wait_secs(2.0)
	var p2 = mgr().player
	p2.hp = 0
	p2.die()
	var ok := await wait_until(func(): return not p2.dead and mgr().room.id == "R02", 14.0)
	return [ok, "guest back in %s" % mgr().room.id]

# outside a boss fight: the guest makes a bench its own by walking up to it, a death sends each player straight back to
# its bench with full hp (no revive countdown)
func sc_co_home() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var known := await wait_until(func(): return coop().guest_bench == "R02", 10.0)
		var g_home := await wait_until(func(): return coop().remote.dead, 8.0)
		var g_back := await wait_until(func(): return not coop().remote.dead, 5.0)
		await wait_secs(1.0)
		var p = mgr().player
		p.hp = 0
		p.die()
		await wait_secs(0.3)
		var downed: bool = p.downed
		var back := await wait_until(func(): return mgr().player != null and not mgr().player.dead and mgr().player.hp == mgr().player.max_hp, 4.0)
		return [known and g_home and g_back and back and not downed, "guest bench known %s, guest died %s and came back %s, host downed %s, host back on its bench %s" % [known, g_home, g_back, downed, back]]
	await wait_secs(1.0)
	mgr().swap_to("R02", Vector2(60.0, 100.0))
	await wait_secs(0.5)
	var r: Room = mgr().room
	var c: Dictionary = r.cps[0]
	var g = mgr().player
	g.x = c.x - g.w / 2.0
	g.y = c.y - g.h - 1.0
	var rested := await wait_until(func(): return Game.bench == "R02", 4.0)
	await wait_secs(0.5)
	g.x = c.x + 60.0
	g.y = floor_y(r, c.x + 60.0, 2)
	await wait_secs(1.5)
	g.hp = 0
	g.die()
	var downed: bool = g.downed
	var t0 := Time.get_ticks_msec()
	var back := await wait_until(func(): return not mgr().player.dead and mgr().room.id == "R02" and mgr().player.hp == mgr().player.max_hp, 5.0)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	await wait_secs(4.0)
	return [rested and back and not downed and secs < 4.0, "bench touched %s, downed %s, back in R02 with full hp %s after %.1f s" % [rested, downed, back, secs]]

# a death the host sees only in the body report still gets the full revive countdown (G28)
func sc_co_lostdie() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	mgr().room.fight_active = true             # the revive countdown is a boss-fight rule
	if role == "host":
		await wait_secs(2.0)
		var rp = coop().remote
		var m := {"t": "st", "e": Net.epoch, "room": mgr().room.id, "x4": int(rp.x * 4.0), "y4": int(rp.y * 4.0), "vx": 0, "vy": 0, "face": 1, "hp": 0, "maxhp": 5, "dead": 1, "dn": rp.dn + 1, "atk": [0, "f", false], "dash": [0, 0, 0, 0], "gt": 0.0, "sa": 0, "inv": 0.0}
		coop()._host_msg("st", m)
		var t0: float = rp.down_t
		coop()._host_down_logic(0.016)
		return [rp.dead and t0 > 5.0, "after the report: down_t=%.1f (want about 6), still down one tick later: %s" % [t0, rp.dead]]
	await wait_secs(5.0)
	return [true, "guest idle"]

# the guest drinks a coffee on easy and is healed (G19)
func sc_co_coffee() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.diff = "easy"
		await wait_secs(1.5)
		mgr().player.x += 160.0                     # out of the way: the guest must be the one who picks it up
		var r: Room = mgr().room
		var rp = coop().remote
		r.items.append({"kind": "coffee", "id": "cT1", "x": rp.x + 5.0, "y": rp.y + 5.0, "ph": 0.0})
		await wait_secs(4.0)
		var gone := true
		for it in r.items:
			if it.id == "cT1" and not it.get("dead", false):
				gone = false
		return [gone, "coffee taken by the guest: %s" % gone]
	await wait_secs(1.0)
	var p = mgr().player
	p.hp = 2
	var healed := await wait_until(func(): return p.hp == 3, 6.0)
	return [healed, "guest hp 2 -> %d" % p.hp]

# a second start that puts the guest in another room leaves no orphan body behind (G18)
func sc_co_restart() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(3.5)
		coop()._guest_left()
		coop()._guest_joined()
		await wait_secs(3.0)
		return [true, "host re-sent start"]
	await wait_secs(1.0)
	mgr().swap_to("R02", Vector2(60.0, 100.0))
	var orphans0: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	await wait_until(func(): return mgr().room.id == "R01", 6.0)
	await wait_secs(2.5)
	var orphans1: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	return [orphans1 <= orphans0, "orphan nodes %d -> %d" % [orphans0, orphans1]]

# NULL must hurt the guest: the guest stands in the arena for 25 s without i-frames and counts its hurts
func sc_co_bossdmg() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("R05", Vector2(40.0, 100.0))
		var p = mgr().player
		p.y = floor_y(mgr().room, 40.0, 7)
		p.x = 100.0
		var active := await wait_until(func(): return mgr().room.fight.state == "active", 12.0)
		var picks := {}
		var touch := {}
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 28000:
			p.inv = 999.0
			p.hp = p.max_hp
			var b = mgr().room.boss
			if b != null and b.target != null:
				picks["P2" if b.target.get("is_remote") else "P1"] = true
				if b.cur.mode == "fly" and b.target.get("is_remote"):
					var rb = b.target.hurtbox()
					if Game.overlap(rb, {"x": b.cur.x - 5, "y": b.cur.y - 5, "w": 10, "h": 10}):
						touch[b.cycle] = true
			await get_tree().physics_frame
		var song_h := Audio.music_name
		return [active and picks.has("P2") and song_h == "boss", "fight active %s, NULL targeted %s, poke rounds that touched P2 here %d, music %s" % [active, str(picks.keys()), touch.size(), song_h]]
	var there := await wait_until(func(): return mgr().room.id == "R05", 15.0)
	var hurts := 0
	var t1 := Time.get_ticks_msec()
	var pup_passive := true
	var by := {}
	while Time.get_ticks_msec() - t1 < 25000:
		var g = mgr().player
		if g != null:
			if g.hp < g.max_hp:
				hurts += g.max_hp - g.hp
				g.hp = g.max_hp
				var b1 = mgr().room.boss
				if b1 != null:
					by[b1.st] = by.get(b1.st, 0) + 1
			g.dead = false
		var b2 = mgr().room.boss
		if b2 != null and b2.active:
			pup_passive = b2.passive
		await get_tree().physics_frame
	var song_g := Audio.music_name
	return [there and by.has("poke") and song_g == "boss", "in R05 %s, guest hurt %d times %s, puppet passive %s, music %s" % [there, hurts, str(by), pup_passive, song_g]]

# the host's pause menu "Restart room" brings the guest back too (it used to stay where it was)
func sc_co_pauserestart() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(3.0)
		main.pause_menu.restart_requested.emit()
		await wait_secs(3.0)
		return [mgr().player != null and coop()._remote_room() != null, "restarted, guest room %s" % str(coop()._remote_room())]
	await wait_secs(1.0)
	mgr().swap_to("R02", Vector2(60.0, 100.0))
	var back := await wait_until(func(): return mgr().room.id == String(Game.rooms_meta.start.room), 8.0)
	return [back, "guest back in %s: %s" % [mgr().room.id, back]]

# solo: two music changes inside a crossfade keep the last song (G15); a pause while the line is down is queued (G17)
func sc_co_solo() -> Array:
	main.music_auto = false
	Audio.music("title")
	await wait_secs(1.0)
	Audio.music("w1")
	await wait_secs(0.2)
	Audio.music("boss")
	await wait_secs(1.5)
	var music_ok: bool = Audio.music_a.playing
	# a fade-out still running must not silence the next song (entering the arena, which has no song, then the fight starts)
	Audio.music("w1")
	await wait_secs(0.7)
	Audio.stop_music(1.0)
	await wait_secs(0.2)
	Audio.music("boss")
	await wait_secs(1.5)
	var fade_ok: bool = Audio.music_a.playing and Audio.music_a.volume_db > -20.0 and Audio.music_name == "boss"
	main.music_auto = true
	Net.role = "host"
	Net.is_open = false
	Net.rel_out.clear()
	main.set_paused(true)
	var queued: int = Net.rel_out.size()
	main.set_paused(false)
	Net.role = "none"
	return [music_ok and fade_ok and queued == 1, "boss music still playing: %s; after a fade-out: %s (%.0f dB); pause queued offline: %d (want 1)" % [music_ok, fade_ok, Audio.music_a.volume_db, queued]]

# MV3-03: the guest swipes a catchable projectile the host threw. The host's real projectile turns around, presses the switch of R11 and
# the gate opens on both pages (the gate and switch flags are state in the snapshots).
func sc_co_catch() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.catch = true
		await wait_secs(1.0)
		mgr().swap_to("R11", Vector2(40.0, 100.0))
		mgr().player.x = 40.0
		mgr().player.y = floor_y(mgr().room, 40.0, 8)
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "R11" and absf(coop().remote.x - 230.0) < 12.0, 15.0)
		if not there:
			return [false, "the guest never stood at x=230 in R11"]
		var r: Room = mgr().room
		clear_creatures(r)
		await wait_secs(1.0)
		var q: Dictionary = r.shoot(305.0, 200.0, -60.0, 0.0, {"kind": "err", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 6.0, "dmg": 1})
		var caught := await wait_until(func(): return q.get("friendly", false), 8.0)
		var gate := await wait_until(func(): return Game.flag("gate:R11:catch") and r.grid.gates_open.catch, 6.0)
		await wait_secs(1.0)
		return [caught and gate, "projectile caught on the host=%s (vx %.0f), gate open=%s, switch=%s" % [caught, q.get("vx", 0.0), gate, Game.flag("switch:R11:0")]]
	var has_catch := await wait_until(func(): return Game.tools.get("catch", false), 10.0)      # (the host's ability event)
	mgr().swap_to("R11", Vector2(230.0, 100.0))
	var in_room: bool = has_catch and mgr().room.id == "R11"
	if not in_room:
		return [false, "never in R11 with catch (room %s, catch %s)" % [mgr().room.id, str(Game.tools.get("catch"))]]
	var r2: Room = mgr().room
	var p = mgr().player
	p.x = 230.0
	p.y = floor_y(r2, 230.0, 8)
	p.vx = 0.0
	p.vy = 0.0
	p.inv = 999.0
	var swung := false
	var mine := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000 * slow and not r2.grid.gates_open.catch:
		p.inv = 999.0
		p.face = 1.0
		var press := false
		for q in r2.projs:
			if q.kind == "err" and not q.get("friendly", false) and q.get("catchable", false) and not q.dead:
				if q.x - q.r - (p.x + p.w - 4.0 + 24.0) < 2.0:
					press = true
			elif q.kind == "err" and q.get("friendly", false):
				mine = true
		Controls.script_input = {"attack": press and not swung}
		if press:
			swung = true
		await get_tree().physics_frame
	Controls.script_input = {}
	await wait_secs(1.0)
	return [mine and r2.grid.gates_open.catch, "swung=%s saw it friendly=%s, gate open on the guest=%s" % [swung, mine, r2.grid.gates_open.catch]]

# MV3-05: both fight THE REVIEWER. The host sees its attacks alternate between the two bodies, the guest is hurt by strikes through its
# own contact check, and the guest's parry (catch) staggers the host's boss.
func sc_co_reviewer() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.catch = true
		await wait_secs(1.0)
		mgr().swap_to("R10", Vector2(100.0, 100.0))
		var p = mgr().player
		p.x = 100.0
		p.y = floor_y(mgr().room, 100.0, 8)
		var active := await wait_until(func(): return mgr().room.fight.state == "active", 20.0)
		var picks := {}
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 40000 * slow:
			p.inv = 999.0
			p.hp = p.max_hp
			var b = mgr().room.boss
			if b != null and b.target != null:
				picks["P2" if b.target.get("is_remote") else "P1"] = true
			await get_tree().physics_frame
		var b2 = mgr().room.boss
		var par: Array = b2.parries if b2 != null else [0, 0]
		var song := Audio.music_name
		return [active and picks.has("P1") and picks.has("P2") and par[1] >= 1 and song == "tension", "fight active %s, targets %s, parries (P1/P2) %s, music %s" % [active, str(picks.keys()), str(par), song]]
	var has_catch := await wait_until(func(): return Game.tools.get("catch", false), 10.0)
	mgr().swap_to("R10", Vector2(260.0, 100.0))
	var r2: Room = mgr().room
	var g = mgr().player
	g.x = 260.0
	g.y = floor_y(r2, 260.0, 8)
	var hurts := 0
	var swings := 0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 42000 * slow:
		g = mgr().player
		if g == null:
			await get_tree().physics_frame
			continue
		if g.hp < g.max_hp:
			hurts += g.max_hp - g.hp
			g.hp = g.max_hp
		g.dead = false
		var press := false
		var boss = r2.boss
		if boss != null and boss.active and not g.parried.has(boss.strike_sid):
			var face_to: float = 1.0 if boss.cx > g.x + 5.0 else -1.0
			for hb in boss.harmboxes():
				if hb is Dictionary and hb.has("sid") and hb.get("catchable", false) and hb.sid > 0 and not g.parried.has(hb.sid):
					var front: float = g.x + g.w - 4.0 + 24.0 if face_to > 0.0 else g.x + 4.0 - 24.0
					var gap: float = (hb.x - front) if face_to > 0.0 else (front - (hb.x + hb.w))
					if gap < 16.0 and gap > -20.0 and absf(hb.y - g.y) < 30.0:
						g.face = face_to
						press = true
		Controls.script_input = {"attack": press and g.atk_cd <= 0.0}
		if press and g.atk_cd <= 0.0:
			swings += 1
		await get_tree().physics_frame
	Controls.script_input = {}
	return [has_catch and g.parried.size() >= 1, "catch %s, swings %d, parried %d, hurt %d times" % [has_catch, swings, g.parried.size(), hurts]]

# MV3-06: the guest's own loadout counts on the host: with cache a token 40 px away flies to it and the host accepts the pickup; with a
# rubber duck at 1 hp a claw hit of 2 is accepted and a hit of 3 is cut down to 2.
func sc_co_plugins() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.flags["plugin:cache"] = true
		Game.flags["plugin:rubber_duck"] = true
		var ok_load := await wait_until(func(): return coop().remote != null and coop().remote.loadout.has("cache") and coop().remote.loadout.has("rubber_duck"), 15.0)
		if not ok_load:
			return [false, "the guest's loadout never arrived"]
		var r: Room = coop()._remote_room()
		clear_creatures(r)
		await wait_secs(1.0)
		var gx: float = coop().remote.x
		var gy: float = coop().remote.y
		mgr().player.x = gx + 260.0 if gx < 200.0 else gx - 260.0          # (the host body stands far away: it must not collect the token itself)
		mgr().player.vx = 0.0
		await wait_secs(0.5)
		var tok := {"kind": "token", "x": gx + 5.0 + 40.0, "y": gy + 5.0, "id": "item:test:cache", "ph": 0.0}
		r.items.append(tok)
		var got_tok := await wait_until(func(): return tok.get("dead", false), 6.0)
		var b := spawn_bug(r, gx + 22.0, floor_y(r, gx, 9) + 1.0)
		b.hp = 9
		b.speed = 0.0
		b.stun = 999.0
		# (the guest swings once with 1 hp, then sends a hit of 3)
		var first := await wait_until(func(): return b.hp <= 7, 8.0)
		var hp_after_first: int = b.hp
		var second := await wait_until(func(): return b.hp < hp_after_first, 8.0)
		await wait_secs(0.5)
		return [got_tok and first and hp_after_first == 7 and second and b.hp == 5, "token picked (accepted) %s, bug hp 9 -> %d after the swing of 2 -> %d after the hit of 3 (want 5)" % [got_tok, hp_after_first, b.hp]]
	Game.flags["plugin:cache"] = true
	var owned := await wait_until(func(): return Game.owns_plugin("cache") and Game.owns_plugin("rubber_duck"), 10.0)
	var e1 := Game.toggle_plugin("cache")
	var e2 := Game.toggle_plugin("rubber_duck")
	var r2: Room = mgr().room
	var tok_seen := await wait_until(func(): return Game.tokens >= 1, 25.0)
	var seen := await wait_until(func(): return r2.ents.size() > 0, 10.0)
	if not seen:
		return [false, "never saw the creature (owned %s, equipped %s %s)" % [owned, e1, e2]]
	await wait_secs(0.8)
	var g = mgr().player
	var bug = r2.ents[0]
	g.x = bug.x - 18.0
	g.y = bug.y - 1.0
	g.face = 1.0
	g.hp = 1
	g.inv = 999.0
	await wait_secs(0.5)
	for attempt in range(8):                      # (on a bad line the puppet is seen late: swing until the host's bug has lost hp)
		if bug.hp < 9:
			break
		g.x = bug.x - 18.0
		g.hp = 1
		Controls.script_input = {"attack": true}
		await get_tree().physics_frame
		await get_tree().physics_frame
		Controls.script_input = {}
		await wait_secs(0.8)
	await wait_secs(1.0)
	Net.rel("hit", {"eid": bug.nid, "how": "swipe", "dmg": 3, "dx": 1.0, "dy": 0.0, "atk": 9999, "px": roundi(g.x), "py": roundi(g.y)})
	await wait_secs(2.0)
	return [owned and e1 and e2 and tok_seen, "owned %s, equipped %s %s, token counted on the guest %s" % [owned, e1, e2, tok_seen]]

# MV3-08: the guest steps on a crumbling block (put in R01 on both pages): it shakes and falls on the host too, and the guest's grid follows
# the host's list (no INVARIANT crumble_state).
func sc_co_crumble() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var r: Room = mgr().room
	var tx := 6
	var ty := floori((floor_y(r, tx * 16.0 + 3.0, 9) + 10.0) / 16.0)
	var i: int = ty * r.w + tx
	if role == "host":
		r.grid.tiles[i] = TileGrid.CRUMBLE
		r.view.dynamic.set_cell(Vector2i(tx, ty), 0, Vector2i(3, 5))
		var seen := await wait_until(func(): return r.grid.crumble.has(i), 12.0)
		var fell := await wait_until(func(): return r.grid.crumble.has(i) and r.grid.crumble[i].s == 2, 4.0 * slow)
		var back := await wait_until(func(): return not r.grid.crumble.has(i), 8.0 * slow)
		await wait_secs(0.5)
		return [seen and fell and back, "crumble started by the guest on the host=%s, fell=%s, came back=%s" % [seen, fell, back]]
	await wait_secs(2.0)
	r.grid.tiles[i] = TileGrid.CRUMBLE
	r.view.dynamic.set_cell(Vector2i(tx, ty), 0, Vector2i(3, 5))
	var p = mgr().player
	p.x = tx * 16.0 + 3.0
	p.y = ty * 16.0 - 10.0
	p.vx = 0.0
	p.vy = 0.0
	var predicted := await wait_until(func(): return r.grid.crumble.has(i), 3.0)
	var confirmed := await wait_until(func(): return r.grid.crumble.has(i) and r.grid.crumble[i].has("host"), 4.0 * slow)
	var fell2 := await wait_until(func(): return r.grid.crumble.has(i) and r.grid.crumble[i].s == 2, 4.0 * slow)
	p.x = 60.0                                          # (this floor has more floor below it: step out of the gap so the block may come back)
	p.y = floor_y(r, 60.0, 9)
	var gone := await wait_until(func(): return not r.grid.crumble.has(i), 8.0 * slow)
	return [predicted and confirmed and fell2 and gone, "predicted %s, confirmed by the host %s, fell %s, back %s" % [predicted, confirmed, fell2, gone]]

# MV3-11: both fight MERGE CONFLICT. Head 0 aims at the host, head 1 at the guest; a band that fires hurts the guest through its own contact
# check; the guest sees the `git revert in N` countdown over the dead head and the head coming back.
func sc_co_merge() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("D05", Vector2(100.0, 100.0))
		var p = mgr().player
		p.x = 100.0
		p.y = floor_y(mgr().room, 100.0, 8)
		var active := await wait_until(func(): return mgr().room.fight.state == "active", 20.0)
		var boss: MergeBoss = mgr().room.boss
		var ok_targets := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000:
			p.inv = 999.0
			p.hp = p.max_hp
			var t_a = boss.target_of(boss.heads[0])
			var t_b = boss.target_of(boss.heads[1])
			if t_a != null and t_b != null and not t_a.get("is_remote") and t_b.get("is_remote"):
				ok_targets = true
			await get_tree().physics_frame
		# three conflict markers with the floor band unsafe-for-sure (M is the resolved one)
		for trial in range(3):
			for h in boss.heads:
				h.st = "rest"
			boss.band_state = 0
			boss.busy = 99.0
			boss._start_markers()
			boss.safe_band = 1
			await wait_until(func(): return boss.band_state == 0, 6.0 * slow)
			await wait_secs(0.5)
		# kill head 0: the guest sees the countdown; after 8 s it is back
		for h in boss.heads:
			h.st = "rest"
		boss.band_state = 0
		boss.busy = 99.0
		merge_head_kill(boss, 0)
		var came_back := await wait_until(func(): return not boss.heads[0].dead, 12.0 * slow)
		await wait_secs(1.5)
		return [active and ok_targets and came_back, "fight active %s, heads aim at different players %s, head 0 came back %s (hp %.0f)" % [active, ok_targets, came_back, boss.heads[0].hp]]
	var has := await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	mgr().swap_to("D05", Vector2(260.0, 100.0))
	var r2: Room = mgr().room
	var g = mgr().player
	g.x = 260.0
	g.y = floor_y(r2, 260.0, 8)
	var hurt_by_band := false
	var seen_rv := false
	var seen_back := false
	var was_dead := false
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 60000 * slow and not seen_back:
		g = mgr().player
		if g != null:
			g.dead = false
			if g.hp < g.max_hp:
				if r2.boss != null and r2.boss.band_state == 3:
					hurt_by_band = true
				g.hp = g.max_hp
			g.vx = 0.0
		var b = r2.boss
		if b != null and b is MergeBoss:
			var h0: Dictionary = b.heads[0]
			if h0.dead and h0.rv > 0.0 and h0.rv <= 8.0:
				seen_rv = true
			if h0.dead:
				was_dead = true
			elif was_dead and seen_rv:
				seen_back = true
		await get_tree().physics_frame
	return [hurt_by_band and seen_rv and seen_back, "band hurt the guest %s, countdown seen %s, head came back %s" % [hurt_by_band, seen_rv, seen_back]]

func merge_head_kill(boss: MergeBoss, i: int) -> void:
	for b in boss.hurtboxes():
		if b.head == i:
			boss.hit(999, 0.0, 0.0, "swipe", b)
			return

# MV3-12: the guest taps [special] with a full meter in D06: the host gives its body two agents, both pages see them, they press the slot key,
# the agents gate opens on both pages.
func sc_co_agents() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.agents = true
		await wait_secs(1.0)
		mgr().swap_to("D06", Vector2(60.0, 100.0))
		var p = mgr().player
		p.x = 60.0
		p.y = floor_y(mgr().room, 60.0, 8)
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "D06" and absf(coop().remote.x - 320.0) < 12.0, 15.0)
		var r: Room = mgr().room
		clear_creatures(r)
		var agents_seen := await wait_until(func(): return r.agents.size() == 2 and r.agents[0].owner_p.get("is_remote") == true, 10.0 * slow)
		var key := await wait_until(func(): return Game.flag("key:D06:0") and Game.flag("gate:D06:agents") and r.grid.gates_open.agents, 12.0 * slow)
		var gone := await wait_until(func(): return r.agents.is_empty(), 15.0 * slow)          # the first two expire (11 s)
		var again := await wait_until(func(): return r.agents.size() == 2 and r.agents[0].owner_p.get("is_remote") == true, 12.0 * slow)
		await wait_secs(1.0)
		return [there and agents_seen and key and gone and again, "guest at the key room %s, the guest's two agents on the host %s, key pressed + gate open %s, first cast gone %s, second cast on the host %s" % [there, agents_seen, key, gone, again]]
	var has := await wait_until(func(): return Game.tools.get("agents", false), 10.0)
	mgr().swap_to("D06", Vector2(320.0, 100.0))
	var r2: Room = mgr().room
	var g = mgr().player
	g.x = 320.0
	g.y = floor_y(r2, 320.0, 8)
	g.vx = 0.0
	g.inv = 999.0
	await wait_secs(2.5)
	g.meter = float(Game.METER_MAX)
	Controls.script_input = {"special": true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	Controls.script_input = {}
	var emptied := await wait_until(func(): return g.meter == 0.0, 2.0)
	var view := await wait_until(func(): return r2.agent_view.size() == 2, 6.0 * slow)
	var gate := await wait_until(func(): return r2.grid.gates_open.agents and Game.flag("key:D06:0"), 14.0 * slow)
	var view_gone := await wait_until(func(): return r2.agent_view.is_empty() and g.agents_t <= 0.0, 15.0 * slow)
	g.meter = float(Game.METER_MAX)
	Controls.script_input = {"special": true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	Controls.script_input = {}
	var view2 := await wait_until(func(): return r2.agent_view.size() == 2, 6.0 * slow)
	return [has and emptied and view and gate and view_gone and view2, "has agents %s, meter emptied %s, the two agents drawn on the guest %s, gate open on the guest %s, first cast gone %s, second cast drawn %s" % [has, emptied, view, gate, view_gone, view2]]

# MV3-13: the guest buys from the npm stall with its own tokens (the host sets the flag, the guest pays when the host answers); when both buy the
# same item the second buyer is told so and pays nothing.
func sc_co_shop() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tokens = 200
		await wait_secs(1.0)
		mgr().swap_to("D04", Vector2(60.0, 100.0))
		var p = mgr().player
		p.x = 60.0
		p.y = floor_y(mgr().room, 60.0, 8)
		var r: Room = mgr().room
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "D04", 15.0)
		var flag1 := await wait_until(func(): return Game.owns_plugin("hot_reload"), 10.0 * slow)
		# the double buy: the host buys try_finally now (80); the guest's request comes a moment later
		await wait_secs(3.0)
		main.shop_menu.open(r)
		var host_bought: bool = main.shop_menu.buy("try_finally")
		main.shop_menu.close()
		await wait_secs(4.0)
		return [there and flag1 and host_bought and Game.tokens == 120 and Game.owns_plugin("try_finally"), "guest reached the stall %s, guest's purchase set the host's flag %s, host bought try_finally %s, host tokens %d (want 120: only the host paid)" % [there, flag1, host_bought, Game.tokens]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	Game.tokens = 200
	mgr().swap_to("D04", Vector2(200.0, 100.0))
	var r2: Room = mgr().room
	var g = mgr().player
	g.x = 200.0
	g.y = floor_y(r2, 200.0, 8)
	await wait_secs(3.0)
	main.shop_menu.open(r2)
	var asked: bool = main.shop_menu.buy("hot_reload")
	var paid := await wait_until(func(): return Game.tokens == 110 and main.shop_menu.pending == "", 10.0 * slow)
	var owned: bool = Game.owns_plugin("hot_reload")
	# the second buyer: the host bought try_finally first; a late `buy` gets by "" and costs nothing
	await wait_secs(3.0)
	main.shop_menu.pending = "try_finally"
	Net.rel("buy", {"id": "try_finally"})
	var answered := await wait_until(func(): return main.shop_menu.pending == "", 8.0 * slow)
	await wait_secs(0.5)
	main.shop_menu.close()
	return [asked and paid and owned and answered and Game.tokens == 110 and Game.owns_plugin("try_finally"), "asked %s, paid %s (tokens %d, want 110), owns it %s, late buyer answered %s and still has %d tokens, owns try_finally %s" % [asked, paid, Game.tokens, owned, answered, Game.tokens, Game.owns_plugin("try_finally")]]

# MV3-FIX-3: an open bench menu / shop does not stop the co-op world (host: its rooms; guest: its own body), and the body takes no input
func sc_co_menutick() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("D04", Vector2(60.0, 100.0))
		var p = mgr().player
		p.x = 60.0
		p.y = floor_y(mgr().room, 60.0, 8)
		await wait_secs(1.0)
		var r: Room = mgr().room
		main.shop_menu.open(r)
		var t0: float = r.time
		var x0: float = p.x
		Controls.script_input = {"right": true}
		await wait_secs(1.5)
		Controls.script_input = {}
		var ran: float = r.time - t0
		var moved: float = absf(mgr().player.x - x0)
		main.shop_menu.close()
		await wait_secs(2.0)
		return [ran > 1.0 and moved < 1.0, "host room ran %.2f s with the shop open (want > 1), body moved %.1f px (want 0)" % [ran, moved]]
	await wait_secs(1.0)
	mgr().swap_to("D04", Vector2(120.0, 100.0))
	var g = mgr().player
	g.x = 120.0
	g.y = floor_y(mgr().room, 120.0, 8)
	await wait_secs(3.0)
	var r2: Room = mgr().room
	main.shop_menu.open(r2)
	var t1: float = r2.time
	var gx: float = g.x
	Controls.script_input = {"right": true}
	await wait_secs(1.5)
	Controls.script_input = {}
	var ran2: float = r2.time - t1
	var moved2: float = absf(mgr().player.x - gx)
	main.shop_menu.close()
	return [ran2 > 1.0 and moved2 < 1.0, "guest room ran %.2f s with the shop open (want > 1), body moved %.1f px (want 0)" % [ran2, moved2]]

# MV4-01: the guest goes up a one-way hatch and back down the hole; the host follows through the guest's `room` events and takes the hatch flag
func sc_co_nsdoor() -> Array:
	Game.tools.sudo = true
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("H10", Vector2(10.0 * 16.0, 100.0))
		var seen := {}
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 25000.0 * slow:
			var rr = coop()._remote_room()
			if rr != null:
				seen[rr.id] = true
			if seen.has("H11") and rr != null and rr.id == "H10" and seen.has("H10"):
				break
			await get_tree().physics_frame
		var flag_ok: bool = Game.flag("hatch:H10N")
		await wait_secs(1.0)
		return [seen.has("H11") and seen.has("H10") and flag_ok, "host saw the guest in %s, hatch flag %s" % [str(seen.keys()), flag_ok]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(2.5)
	mgr().swap_to("H10", Vector2(51.0 * 16.0 + 3.0, 6.0 * 16.0 - 10.0))
	var p = mgr().player
	p.tools.sudo = true
	p.vx = 0.0
	p.vy = 0.0
	var miny := 9999.0
	await wait_secs(0.6)                    # (let the body land on the ledge first)
	for f in range(160):
		miny = minf(miny, mgr().player.y)
		Controls.script_input = {"jump": f <= 12 or (f >= 20 and f <= 40)}
		await get_tree().physics_frame
		if mgr().room.id == "H11" and not mgr().trans.on:
			break
	Controls.script_input = {}
	var up: bool = mgr().room.id == "H11"
	await wait_secs(1.5)
	mgr().player.x = 51.0 * 16.0 + 3.0
	mgr().player.y = 14.0 * 16.0
	mgr().player.vx = 0.0
	mgr().player.vy = 0.0
	var down := await wait_until(func(): return mgr().room.id == "H10", 6.0)
	await wait_secs(2.0)
	return [up and down, "guest up %s (min y %.0f, room %s), back down %s" % [up, miny, mgr().room.id, down]]
