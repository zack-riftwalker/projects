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
	for cls in range(26, 38):                                          # the NETWORK's creatures (4B-2, 4B-3): default state and a busy one
		for busy in [false, true]:
			var en = NetClasses.make(cls, room)
			en.puppet = false
			if busy:
				_busy(en, cls)
			var g1: Array = en.net_fields()
			var gjson = JSON.parse_string(JSON.stringify(g1))
			var q2 = NetClasses.make(cls, room)
			q2.net_apply(gjson)
			var g2: Array = q2.net_fields()
			if not _same(g1, g2):
				bad.append("%s (busy %s): %s != %s" % [NetClasses.NAMES[cls], str(busy), str(g1), str(g2)])
			en.queue_free()
			q2.queue_free()
	return [bad.is_empty(), "18 classes, mismatches: %s" % str(bad)]

# a state with something in every field the class sends
func _busy(e, cls: int) -> void:
	match cls:
		30:
			e.hpf = 51.5
			e.max_hp = 82
			e.active = true
			e.node = 2
			e.core_y = 71.0
			e.leg_x = 140.0
			e.sk_state = 2
			e.sk_x = 100.0
			e.dc = 0                       # (the deep crawl derives the core's place from the clock, not from the fields)
			e.sw_t0 = 12.34
			e.leg_i = 1
			e.leg_n = 3
			e.hz = [{"k": "strand", "t0": 3.5, "warn": 0.9, "v": [8, 144, 32]}, {"k": "strand", "t0": 4.5, "warn": 0.9, "v": [1, 240, 32]}]
		31:
			e.hpf = 30.0
			e.max_hp = 82
			e.active = true
			e.shield_t = 1.2
			e.turn_t = 0.2
			e.scan_order = [2, 1, 0]
			e.scan_gap = 0.35
			e.drop_seed = 3
			e.dropall_n = 4
			e.walls_on = true
			e.mk_x = 22.0
			e.hz = [{"k": "deny", "t0": 3.5, "warn": 1.0, "v": [0]}, {"k": "block", "t0": 4.0, "warn": 0.7, "v": [-1, 392]}, {"k": "drop", "t0": 5.0, "warn": 0.9, "v": [2]}]
		32:
			e.hpf = 70.0
			e.max_hp = 96
			e.active = true
			e.thrusts = 3
			e.nit_gap = 130.0
			e.pen_xs = [30.0, 60.0, 200.0, 250.0, 300.0, 340.0]
			e.hz = [{"k": "mark", "t0": 3.5, "warn": 0.8, "v": [100]}, {"k": "mark", "t0": 4.5, "warn": 0.8, "v": [222]}]
		33:
			e.state = "probe"
			e.state_t = 0.2
			e.ring_i = 1
			e.from_i = 0
		34:
			e.state = "echo"
			e.state_t = 0.1
			e.kind = 2
			e.face = 1.0
			e.landed = 1
		35:
			e.countdown = 2.5
			e.shielded = true
		36:
			e.state = "tell"
			e.state_t = 0.3
			e.shots = 5
		37:
			e.left = 3.2
			e.cell = Vector2i(6, 9)
			e.group = Vector2i(5, 8)
		26:
			e.state = "drop"
			e.state_t = 1.2
			e.len = 80.0
		27:
			e.state = "out"
			e.state_t = 0.2
		28:
			e.awake = true
			e.idx = 3
			e.state = "dart"
			e.state_t = 0.1
		29:
			e.state = "track"
			e.state_t = 0.7
			e.angle = 1.25

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
	Controls.script_input = {"left": true, "jump": true}
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
		Controls.script_input = {"jump": f <= 12 or f >= 20}
		await get_tree().physics_frame
		if mgr().room.id == "H11" and not mgr().trans.on:
			break
	var up: bool = mgr().room.id == "H11"
	Controls.script_input = {"left": true, "jump": true}
	await wait_secs(1.5)
	Controls.script_input = {}
	mgr().player.x = 51.0 * 16.0 + 3.0
	mgr().player.y = 14.0 * 16.0
	mgr().player.vx = 0.0
	mgr().player.vy = 0.0
	var down := await wait_until(func(): return mgr().room.id == "H10", 6.0)
	await wait_secs(2.0)
	return [up and down, "guest up %s (min y %.0f, room %s), back down %s" % [up, miny, mgr().room.id, down]]

# MV4-02: the guest walks through H03's dead code into H13; the host learns it (`reveal`) and keeps it for good
func sc_co_deadcode() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		var seen := await wait_until(func(): return Game.flag("dead:H03"), 20.0)
		await wait_secs(1.0)
		return [seen, "host has dead:H03 = %s" % seen]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(2.0)
	mgr().swap_to("H03", Vector2(31.0 * 16.0 - 14.0, 8.0 * 16.0 - 10.0))
	await wait_secs(0.6)
	Controls.script_input = {"right": true}
	var moved := await wait_until(func(): return mgr().room.id == "H13", 8.0)
	Controls.script_input = {}
	await wait_secs(2.0)
	return [moved and Game.flag("dead:H03"), "guest reached H13 %s, flag %s" % [moved, Game.flag("dead:H03")]]

# MV4-03: the valve's flag lowers the guest's flood level and the water in H03 follows the host's; in H06 the rising flood reaches
# the guest, and a guest that touches the water pushes the host's tide back
func sc_co_flood() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var bench_pos := Vector2(3.0 * 16.0, 8.0 * 16.0 - 10.0)
	var h6_pos := Vector2(10.0 * 16.0 + 2.0, 41.0 * 16.0 - 10.0)
	var h6_low := Vector2(2.0 * 16.0, 49.0 * 16.0 - 10.0)          # (below the trigger row: arms the rising flood)
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("H03", bench_pos)
		await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "H03", 15.0)
		await wait_secs(2.0)
		Game.flags["gate:H07:catch"] = true
		await wait_secs(14.0 * slow)
		var l_after: float = mgr().room.liquid_y if mgr().room.liquid_y != null else -1.0
		mgr().swap_to("H06", h6_low)
		var r: Room = mgr().room
		for e in r.ents:
			e.queue_free()
		r.ents.clear()
		r.player.inv = 99.0
		var in6 := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "H06", 20.0)
		await wait_secs(1.0)
		r.player.x = h6_pos.x
		r.player.y = h6_pos.y
		var rose := await wait_until(func(): return r.rise_on, 5.0)
		# watch for a push back (+60 or more in one frame) while the guest touches the water
		var last: float = r.liquid_y
		var push := 0.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 25000.0 * slow and push < 60.0:
			await get_tree().physics_frame
			r.player.inv = 99.0
			r.player.y = h6_pos.y
			r.player.vy = 0.0
			if r.liquid_y != null:
				push = maxf(push, r.liquid_y - last)
				last = r.liquid_y
		return [l_after > 700.0 and in6 and rose and push >= 60.0, "host: H03 water %.0f (want ~726), guest in H06 %s, rising %s, tide pushed back by %.0f" % [l_after, in6, rose, push]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(2.0)
	mgr().swap_to("H03", bench_pos)
	mgr().player.inv = 99.0
	var lvl := await wait_until(func(): return Game.heap_flood() == 1, 30.0)
	var moved := await wait_until(func(): return mgr().room.liquid_y != null and mgr().room.liquid_y > 600.0, 20.0)
	await wait_secs(2.0)
	var err_h3: float = absf(mgr().room.liquid_y - coop().last_lq / 4.0) if mgr().room.liquid_y != null else 999.0
	await wait_secs(1.0)
	mgr().swap_to("H06", h6_low)
	mgr().player.inv = 99.0
	var rr: Room = mgr().room
	var rose2 := await wait_until(func(): return rr.rise_on, 25.0)
	var close := await wait_until(func(): return rr.liquid_y != null and coop().last_lq >= 0 and absf(rr.liquid_y - coop().last_lq / 4.0) < 20.0, 5.0)
	await wait_secs(1.0)
	# step into the water: the guest's own body gets the hazard and tells the host
	mgr().player.inv = 0.0
	mgr().player.x = 10.0 * 16.0
	mgr().player.y = rr.liquid_y + 8.0
	mgr().player.vy = 0.0
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 4000.0 * slow:           # (the water must not kill the bot: that would restart the level for both)
		await get_tree().physics_frame
		mgr().player.hp = mgr().player.max_hp
	return [lvl and moved and err_h3 < 8.0 and rose2 and close, "guest: flood level 1 %s, H03 water followed %s (off by %.1f), H06 rising %s, water close to the host's %s" % [lvl, moved, err_h3, rose2, close]]

# MV4-07: both stand at H05's bulkhead; the host's SEGFAULT runs into it. The wall breaks on both screens and the guest takes the blast
# through its own harm-zone check.
func sc_co_segfault() -> Array:
	Game.flags["gate:H07:catch"] = true
	if not await wait_joined():
		return [false, "nobody joined"]
	var host_pos := Vector2(43.0 * 16.0 - 26.0, 13.0 * 16.0 - 10.0)
	var guest_pos := Vector2(43.0 * 16.0 - 12.0, 13.0 * 16.0 - 10.0)
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("H05", host_pos)
		var r: Room = mgr().room
		clear_creatures(r)
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "H05", 15.0)
		await wait_secs(1.0)
		var sg := Segfault.new(r, 30 * 16, 12 * 16)
		sg.face = 1.0
		r.add_entity(sg)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 25000.0 * slow and not Game.flag("crack:H05:44:12"):
			mgr().player.inv = 99.0
			await get_tree().physics_frame
		await wait_secs(2.0)
		return [there and Game.flag("crack:H05:44:12") and not r.grid.solid(44, 12), "host: guest there %s, bulkhead broken %s" % [there, not r.grid.solid(44, 12)]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(2.0)
	mgr().swap_to("H05", guest_pos)
	var r2: Room = mgr().room
	var hp0: int = mgr().player.hp
	var open := await wait_until(func(): return not r2.grid.solid(44, 12), 25.0)
	await wait_secs(1.5)
	var hp1: int = mgr().player.hp
	return [open and hp1 < hp0, "guest: bulkhead open %s, hp %d -> %d" % [open, hp0, hp1]]

# MV4-08: both fight THE LEAK. At level 1 the guest's water follows the host's, the wet floor hurts the guest through its own hazard check,
# and a guest that pops a GC drone lets the host's boss raise its tide by 30.
func sc_co_leak() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var arrive := Vector2(373.0, 166.0)
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("H09", arrive)
		var r: Room = mgr().room
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "H09", 15.0)
		Controls.script_input = {"left": true}
		var started := await wait_until(func(): return r.fight.state == "active", 20.0)
		Controls.script_input = {}
		mgr().player.inv = 999.0
		r.attacker = mgr().player
		r.boss.hit(roundi(r.boss.max_hp * 0.4), 0.0, 0.0, "swipe", r.boss)
		var lvl: int = r.boss.level
		var last: float = r.boss.flood_y
		var jump := 0.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 50000.0 * slow and jump < 25.0:
			await get_tree().physics_frame
			mgr().player.inv = 999.0
			mgr().player.hp = mgr().player.max_hp
			jump = maxf(jump, r.boss.flood_y - last)
			last = r.boss.flood_y
		await wait_secs(1.0)
		return [there and started and lvl == 1 and jump >= 25.0, "host: guest there %s, fight %s, level %d, the guest's pop raised the tide by %.0f" % [there, started, lvl, jump]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(2.0)
	mgr().swap_to("H09", arrive)
	var r2: Room = mgr().room
	Controls.script_input = {"left": true}
	var fight := await wait_until(func(): return r2.fight.state == "active", 25.0)
	Controls.script_input = {}
	var lv := await wait_until(func(): return r2.boss != null and r2.boss.level >= 1, 15.0)
	await wait_secs(5.0)
	var diff: float = absf(r2.liquid_y - coop().last_lq / 4.0) if r2.liquid_y != null else 999.0
	# the wet floor
	var p = mgr().player
	p.x = 180.0
	p.y = 166.0
	p.vx = 0.0
	p.vy = 0.0
	var hp0: int = p.hp
	var hurt := await wait_until(func(): return p.hp < hp0 or p.dead, 4.0)
	p.hp = p.max_hp
	# a GC drone
	var gc = null
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 30000.0 * slow and gc == null:
		await get_tree().physics_frame
		p.hp = p.max_hp
		p.inv = 999.0
		for e in r2.ents:
			if e is GcDrone and not e.dead:
				gc = e
	var popped := false
	var seen_gc: bool = gc != null
	if gc != null:
		for f in range(40):
			if not is_instance_valid(gc):
				break
			p.x = gc.x
			p.y = gc.y + 3.0
			p.vx = 0.0
			p.vy = 0.0
			await get_tree().physics_frame
			if f == 25 and is_instance_valid(gc):
				r2._hit_entity(gc, 1, 1.0, 0.0, "swipe", gc)
				popped = true
	await wait_secs(2.0)
	return [fight and lv and diff < 10.0 and hurt and seen_gc and popped, "guest: fight %s, level 1 %s, water off by %.1f, wet floor hurt %s, drone seen %s, hit it %s" % [fight, lv, diff, hurt, seen_gc, popped]]

# MVB0-01: a world flag the host sets (a one-way hatch it fell through, a lab door) reaches the guest while it plays: it opens the
# guest's door, and a tile variant changes under the guest's feet-free cells. MVB0-06: the guest's crossing of a symlink door sets the host's flag
func sc_co_flags() -> Array:
	Game.tools.sudo = true
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(3.0)
		mgr().swap_to("H10", Vector2(41.0 * 16.0 + 4.0, 8.0 * 16.0))
		await wait_secs(1.0)                # (lands on the one-way hatch, then [down]+[jump] drops through it)
		Controls.script_input = {"down": true, "jump": true}
		var went := await wait_until(func(): return Game.flag("hatch:H10S"), 10.0)
		Controls.script_input = {}
		await wait_secs(2.0)
		# the lab door Z01:E sets lab:a
		mgr().swap_to("Z01", Vector2(29.0 * 16.0, 12.0 * 16.0 - 10.0))
		await wait_secs(0.6)
		Controls.script_input = {"right": true}
		var lab_a := await wait_until(func(): return Game.flag("lab:a"), 8.0)
		Controls.script_input = {}
		await wait_secs(4.0 * slow)
		Game.flags["lab:solid"] = true      # (set by the host's world: the guest must follow)
		var link := await wait_until(func(): return Game.flag("link:lab"), 40.0)
		await wait_secs(1.0)
		return [went and lab_a and link, "host: hatch %s, lab:a %s, link:lab (from the guest's crossing) %s" % [went, lab_a, link]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(1.0)
	mgr().swap_to("H04", Vector2(107.0 * 16.0, 18.0 * 16.0))
	var flag_ok := await wait_until(func(): return Game.flag("hatch:H10S"), 12.0)
	await wait_secs(0.3)
	var d = mgr().room.grid.door_at("N", 107)
	var open: bool = d != null and d.open
	mgr().swap_to("Z01", Vector2(3.0 * 16.0, 12.0 * 16.0 - 10.0))
	var lab_a := await wait_until(func(): return Game.flag("lab:a"), 20.0)
	var solid := await wait_until(func(): return mgr().room.id == "Z01" and mgr().room.grid.tile(17, 10) == TileGrid.SOLID and mgr().room.grid.tile(20, 10) == TileGrid.SOLID, 8.0)
	mgr().swap_to("Z04", Vector2(4.0 * 16.0, 9.0 * 16.0 - 10.0))
	await wait_secs(0.6)
	Controls.script_input = {"left": true}
	var crossed := await wait_until(func(): return mgr().room.id == "Z03", 6.0)
	Controls.script_input = {}
	await wait_secs(2.0)
	return [flag_ok and open and lab_a and solid and crossed, "guest: hatch %s, H04:N open %s, lab:a %s, variant solid %s, crossed the symlink %s" % [flag_ok, open, lab_a, solid, crossed]]

# MVB0-07: the guest rides a packet (a platform that is a pure function of the room clock) through the two ports; the host sees it get there
func sc_co_packet() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("Z05", Vector2(3.0 * 16.0 + 3.0, 12.0 * 16.0 - 10.0))
		var seen_x := 0.0
		var t0 := Time.get_ticks_msec()
		var past := false
		while Time.get_ticks_msec() - t0 < 40000.0 * slow:
			var rr = coop()._remote_room()
			if rr != null and rr.id == "Z05" and not rr.remote_players.is_empty():
				seen_x = maxf(seen_x, rr.remote_players[0].x)
			elif mgr().room.id == "Z05" and not mgr().room.remote_players.is_empty():
				seen_x = maxf(seen_x, mgr().room.remote_players[0].x)
			if seen_x >= 50.0 * 16.0:
				past = true
				break
			await get_tree().physics_frame
		await wait_secs(1.0)
		return [past, "host saw the guest as far as x=%.0f (want >= 800)" % seen_x]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(1.5)
	mgr().swap_to("Z05", Vector2(3.0 * 16.0 + 3.0, 12.0 * 16.0 - 10.0))
	var r: Room = mgr().room
	var boarded = null
	var t_wait := Time.get_ticks_msec()
	while boarded == null and Time.get_ticks_msec() - t_wait < 15000.0 * slow:
		for m in r.plats:
			if m.get("packet", false) and not m.off and m.x >= 100.0 and m.x <= 260.0:
				boarded = m
				break
		if boarded == null:
			await get_tree().physics_frame
	if boarded == null:
		return [false, "no packet came by"]
	var p = mgr().player
	p.x = boarded.x + 8.0
	p.y = boarded.y - p.h
	p.vx = 0.0
	p.vy = 0.0
	var t0 := Time.get_ticks_msec()
	var inside := false
	var on_packet := false
	while Time.get_ticks_msec() - t0 < 16000.0 * slow:
		if r.grid.box_hits_solid(p.x, p.y, p.w, p.h):
			inside = true
		if p.x >= 50.0 * 16.0:
			on_packet = p.ride != null
			break
		await get_tree().physics_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	await wait_secs(1.5)
	return [p.x >= 50.0 * 16.0 and not inside, "guest rode to x=%.0f in %.1f s, inside a solid cell %s, on a packet at column 50 %s" % [p.x, secs, inside, on_packet]]

# MVB0-10: the sparring dummy (the boss kit) with both players in Z06: every attack the guest is hurt by was shown to it first, and both players are targeted
func sc_co_bosskit() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var secs := 25.0 * slow
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("Z06", Vector2(5.0 * 16.0, 10.0 * 16.0 + 6.0))
		await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "Z06", 20.0)
		var d: KitDummy = null
		for e in mgr().room.ents:
			if e is KitDummy:
				d = e
		if d == null:
			return [false, "no dummy in Z06"]
		var tgt_of := {}
		var changed := false
		var counts := {"p1": 0, "p2": 0}
		var t0 := Time.get_ticks_msec()
		var f := 0
		while Time.get_ticks_msec() - t0 < secs * 1000.0:
			var p = mgr().player
			p.inv = 99.0
			p.hp = p.max_hp
			Controls.script_input = {"attack": f % 50 < 3}
			f += 1
			if not d.plan.is_empty():
				var sq: int = d.plan.seq
				if not tgt_of.has(sq):
					tgt_of[sq] = d.plan.tgt
					counts[d.plan.tgt] += 1
				elif tgt_of[sq] != d.plan.tgt:
					changed = true
			await get_tree().physics_frame
		Controls.script_input = {}
		await wait_secs(1.0)
		return [counts.p1 >= 1 and counts.p2 >= 1 and not changed and tgt_of.size() >= 6, "host: %d attacks (p1 %d, p2 %d), target changed inside an attack %s" % [tgt_of.size(), counts.p1, counts.p2, changed]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	await wait_secs(1.5)
	mgr().swap_to("Z06", Vector2(15.0 * 16.0, 10.0 * 16.0 + 6.0))
	var found := {"d": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is KitDummy:
				found.d = e
		return found.d != null, 15.0)
	var pup: KitDummy = found.d
	if pup == null:
		return [false, "no dummy puppet"]
	var seen := {}
	var mine := 0
	var t1 := Time.get_ticks_msec()
	var g := 0
	while Time.get_ticks_msec() - t1 < secs * 1000.0:
		var p = mgr().player
		p.inv = 99.0
		p.hp = p.max_hp
		Controls.script_input = {"attack": g % 70 < 3}
		g += 1
		if not pup.plan.is_empty() and not seen.has(pup.plan.seq):
			seen[pup.plan.seq] = pup.plan.tgt
			if pup.plan.tgt == "p2":
				mine += 1
		await get_tree().physics_frame
	Controls.script_input = {}
	var short := 0
	var turned := 0
	for sq in pup.kit_active_seen:
		turned += 1
		if float(pup.cue_shown.get(sq, 0.0)) < 0.30 and sq != pup.kit_ignore_seq:
			short += 1
	await wait_secs(1.0)
	return [seen.size() >= 6 and short == 0 and mine >= 2 and pup.kit_violation == "", "guest: saw %d plans, %d turned active (%d shown < 0.30 s), targeted %d times, violation '%s'" % [seen.size(), turned, short, mine, pup.kit_violation]]

# MVB1-01: the guest asks for the world flags by digest. 200 flags set in one step reach it within 3 s; afterwards the host sends no list at all.
func sc_co_worldsync() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(2.0)
		for i in range(200):
			Game.flags["log:Z01:%d" % i] = true
		var t0 := Time.get_ticks_msec()
		var synced := await wait_until(func(): return coop().guest_wh == Game.world_digest(), 4.0)
		var took := (Time.get_ticks_msec() - t0) / 1000.0
		await wait_secs(1.0)
		var n0: int = coop().wf_count
		var b0: int = coop().wf_bytes
		await wait_secs(10.0)
		var n1: int = coop().wf_count
		return [synced and n1 == n0, "host: guest in sync after %.1f s, wf lists sent while nothing changed: %d (total %d lists, %d bytes)" % [took, n1 - n0, n1, b0]]
	var all := await wait_until(func():
		for i in range(200):
			if not Game.flag("log:Z01:%d" % i):
				return false
		return true, 9.0)
	await wait_secs(12.0)
	return [all, "guest: has all 200 flags %s" % all]

# A world flag only the guest has (its `wflag` was lost or refused) kept the two digests apart for the rest of a real session ("world-digest"
# all through T10 and T11) and a full flag list went out every second. The guest drops a world flag the host's lists keep lacking.
func sc_co_wfextra() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		var t0 := Time.get_ticks_msec()
		var apart := await wait_until(func(): return coop().guest_wh >= 0 and coop().guest_wh != Game.world_digest(), 6.0)
		var back := await wait_until(func(): return coop().guest_wh == Game.world_digest(), 12.0)
		var took := (Time.get_ticks_msec() - t0) / 1000.0
		await wait_secs(2.0)
		var host_kept: bool = not Game.flag("lever:ZZ9:0")
		return [apart and back and host_kept and coop().watchdog.count == 0, "host: digests apart %s, equal again %s after %.1f s, host flag still unset %s, watchdog %d" % [apart, back, took, host_kept, coop().watchdog.count]]
	await wait_secs(2.0)
	Game.flags["lever:ZZ9:0"] = true            # set behind the host's back: no `wflag` goes out
	var gone := await wait_until(func(): return not Game.flag("lever:ZZ9:0"), 12.0)
	await wait_secs(4.0)
	return [gone and not Game.flag("lever:ZZ9:0"), "guest: the flag the host does not have was dropped %s" % gone]

# MVB1-03: the host keeps a staged list for the guest. The guest walks R08 -> R09 -> D01, the host rests at R08: both have the guest's rooms committed.
func sc_co_commit() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.flags["map:src"] = true
		Game.flags["map:dep"] = true
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "D01", 20.0)
		await wait_secs(0.5)
		var staged_ok: bool = coop().guest_staged.has("R09") and coop().guest_staged.has("D01") and not Game.is_mapped("D01")
		mgr().swap_to("R08", Game.bench_spawn("R08"))
		await wait_secs(0.5)
		mgr().rest(mgr().room, 0)
		var mine: bool = Game.is_mapped("R09") and Game.is_mapped("D01") and Game.is_mapped("R01")
		var cleared: bool = coop().guest_staged.is_empty()
		await wait_secs(3.0)
		return [there and staged_ok and mine and cleared, "host: guest reached D01 %s, staged before the rest %s, committed %s, list cleared %s" % [there, staged_ok, mine, cleared]]
	await wait_secs(1.0)
	mgr().player.inv = 999.0
	for rid in ["R08", "R09", "D01"]:
		mgr().swap_to(rid, Game.bench_spawn(rid) if rid == "R08" else Vector2(60.0, 100.0))
		mgr().player.inv = 999.0
		await wait_secs(1.0)
	var got := await wait_until(func(): return Game.is_mapped("R09") and Game.is_mapped("D01"), 20.0)
	await wait_secs(0.5)
	var src_v: Dictionary = Game.map_view("src")
	var dep_v: Dictionary = Game.map_view("dep")
	var listed: bool = src_v.filled.has("R09") and dep_v.filled.has("D01")
	return [got and listed, "guest: R09 and D01 committed %s, in the map view %s" % [got, listed]]

# MVB1-04: the guest buys the DEPTHS index from the cartographer: the host sets the flag and answers; only the buyer pays.
func sc_co_tree() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tokens = 40
		var got := await wait_until(func(): return Game.owns_map("dep"), 20.0)
		await wait_secs(3.0)
		return [got and Game.tokens == 40, "host: map:dep %s, my tokens %d (still 40)" % [got, Game.tokens]]
	await wait_secs(1.5)
	Game.tokens = 40
	mgr().swap_to("D01", Vector2(19.0 * 16.0, 3.0 * 16.0))
	await wait_secs(1.0)
	mgr().player.inv = 999.0
	var r: Room = mgr().room
	main.index_menu.open(r, r.npcs[0])
	var asked: bool = main.index_menu.buy()
	var pending: bool = main.index_menu.pending == "dep" and Game.tokens == 40       # nothing is paid before the answer
	var got2 := await wait_until(func(): return Game.owns_map("dep") and main.index_menu.pending == "", 8.0)
	await wait_secs(2.0)
	return [asked and pending and got2 and Game.tokens == 0, "guest: asked %s, nothing paid before the answer %s, map:dep %s, tokens %d (0)" % [asked, pending, got2, Game.tokens]]

# MVB1-06: the map overlay does not pause co-op. The guest opens it for 3 s: the host's room clock keeps running, the host is not paused, and
# the host sees the folded-map icon (`mn`) over the guest only while it is open; then the same the other way round.
func sc_co_map() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		var saw := await wait_until(func(): return coop().remote.mapping, 12.0)
		var t0: float = mgr().room.time
		await wait_secs(2.0)
		var ran: bool = mgr().room.time - t0 > 1.0 and not main.paused
		var off := await wait_until(func(): return not coop().remote.mapping, 10.0)
		await wait_secs(1.5)
		main.open_map()
		var mine: bool = main.map_overlay.active
		await wait_secs(3.0)
		main.map_overlay.close()
		await wait_secs(2.0)
		return [saw and ran and off and mine, "host: saw the guest's map %s, my clock ran %s, icon gone after %s, my overlay opened %s" % [saw, ran, off, mine]]
	await wait_secs(2.0)
	main.open_map()
	var opened: bool = main.map_overlay.active
	var t1: float = mgr().room.time
	await wait_secs(3.0)
	var unpaused: bool = not main.paused and mgr().room.time - t1 > 1.0
	main.map_overlay.close()
	var saw2 := await wait_until(func(): return coop().host_body != null and coop().host_body.mapping, 14.0)
	var off2 := await wait_until(func(): return coop().host_body != null and not coop().host_body.mapping, 10.0)
	await wait_secs(1.0)
	return [opened and unpaused and saw2 and off2, "guest: overlay opened %s, not paused and clock ran %s, saw the host's map %s then not %s" % [opened, unpaused, saw2, off2]]

# MVB1-08: pins are the host's list (a guest asks, snapshots carry it) and pings go both ways with a tick back.
func sc_co_pins() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var got := await wait_until(func(): return Game.pins.size() == 1 and Game.pins[0].by == "P2" and Game.pins[0].kind == "HELP", 12.0)
		await wait_secs(1.5)
		var pn: Dictionary = Game.pins[0] if Game.pins.size() > 0 else {}
		var removed: bool = not pn.is_empty() and Game.pin_del_near(String(pn.room), float(pn.x), float(pn.y), 1.0)
		await wait_secs(2.5)
		var pinged := Game.ping_add("look", "R01", 200.0, 120.0)
		var ticked := await wait_until(func(): return Game.pings.size() > 0 and Game.pings[0].ack, 8.0)
		await wait_secs(1.0)
		return [got and removed and pinged and ticked, "host: the guest's pin listed %s, removed %s, my ping sent %s and ticked %s" % [got, removed, pinged, ticked]]
	await wait_secs(2.0)
	var t0 := Time.get_ticks_msec()
	Game.pin_add("HELP", "R01", 120.0, 100.0)
	var listed := await wait_until(func(): return Game.pins.size() == 1 and Game.pins[0].kind == "HELP", 3.0)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var gone := await wait_until(func(): return Game.pins.is_empty(), 10.0)
	var arrow := await wait_until(func(): return main.hud.ping_arrows().size() > 0 and main.hud.ping_arrows()[0].by == "P1", 12.0)
	await wait_secs(0.5)
	if arrow:
		Game.ping_ack_one(String(main.hud.ping_arrows()[0].id))
	await wait_secs(2.5)
	return [listed and gone and arrow, "guest: my pin came back in the list after %.2f s %s, the host's removal reached me %s, the host's ping arrow %s" % [took, listed, gone, arrow]]

# MVB1-10: a sign the guest reads is a world flag the host learns (a guest-only flag would break the digest rule)
func sc_co_logs() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var got := await wait_until(func(): return Game.flag("log:R01:0") and Game.flag("changelog:opus"), 15.0)
		await wait_secs(8.0)           # (the watchdog gives a differing digest 5 s: no INVARIANT line may follow)
		return [got, "host: the guest's sign and changelog flags arrived %s" % got]
	await wait_secs(1.5)
	var r: Room = mgr().room
	var sg: Dictionary = r.signs[0]
	mgr().player.x = float(sg.x) - 5.0
	mgr().player.y = float(sg.y) - 10.0
	await wait_secs(1.0)
	Game.tools["opus"] = true
	Game.set_world_flag("changelog:opus")
	await wait_secs(9.0)
	return [Game.flag("log:R01:0"), "guest: read the first sign %s" % Game.flag("log:R01:0")]

# MVB1-11: the guest breaks the jar in H13 with a swipe: the host decides, both pages have agent:H13, R08's contributors count it
func sc_co_lostagent() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var got := await wait_until(func(): return Game.flag("agent:H13"), 25.0)
		await wait_secs(1.0)
		mgr().swap_to("R08", Game.bench_spawn("R08"))
		await wait_secs(1.0)
		var shown: bool = Game.agents_freed() == 1 and mgr().room.decor_items.size() > 0
		return [got and shown, "host: agent:H13 %s, contributors %d" % [got, Game.agents_freed()]]
	await wait_secs(1.5)
	mgr().swap_to("H13", Vector2(52.0 * 16.0 + 8.0 - 24.0, 13.0 * 16.0 - 10.0))
	await wait_secs(1.0)
	mgr().player.inv = 999.0
	var r: Room = mgr().room
	var jar_ok: bool = r.jars.size() == 1 and not r.jars[0].broken
	for k in range(6):
		Controls.script_input = {"attack": true}
		await wait_secs(0.15)
		Controls.script_input = {}
		await wait_secs(0.35)
		if Game.flag("agent:H13"):
			break
	var got2 := await wait_until(func(): return Game.flag("agent:H13") and mgr().room.jars.size() == 1 and mgr().room.jars[0].broken, 8.0)
	await wait_secs(2.0)
	return [jar_ok and got2, "guest: jar was there %s, freed and broken %s" % [jar_ok, got2]]

# ---------------------------------------------------------------- THE NETWORK (MVB2-13)
# the guest's bot for one trench of N10: walk left from the east edge, jump, tap [special] every 12 frames from frame `off`; hurt: back to the edge, next offset
func curl_trench(tr: Array) -> bool:
	for off in [6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32]:
		var p = mgr().player
		p.x = float(tr[0]) * 16.0 + 3.0
		p.y = 19.0 * 16.0 - 10.0
		p.vx = 0.0
		p.vy = 0.0
		p.hp = p.max_hp
		p.inv = 0.0
		for f in range(260):
			p = mgr().player
			var keys := {"left": true}
			if f < 14 or (f > 40 and p.on_ground):
				keys["jump"] = true
			if f >= off and (f - off) % 12 == 0:
				keys["special"] = true
			Controls.script_input = keys
			await get_tree().physics_frame
			if p.hp < p.max_hp:
				break
			if f > 20 and p.on_ground and p.x < float(tr[1]) * 16.0 - 14.0:
				Controls.script_input = {}
				return true
	Controls.script_input = {}
	return false

# both in N10 with curl: the guest crosses the three trenches by curl; the host sees its body get past column 12 and its cable at least once
func sc_co_curl() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.curl = true
		await wait_secs(1.0)
		mgr().swap_to("N10", Vector2(90.0 * 16.0, 19.0 * 16.0 - 10.0))
		for e in mgr().room.ents:
			if e is Sniffer:
				e.dead = true                                   # (4B-3: N10's sniffer taps a ring; co-sniffer is about that, this one is about the trenches)
		var seen_cable := false
		var past := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 60000.0 * slow and not (past and seen_cable):
			mgr().player.inv = 999.0
			var rem = coop().remote
			if rem != null and coop()._remote_room() != null and coop()._remote_room().id == "N10":
				if rem.cz >= 0:
					seen_cable = true
				if rem.x < 12.0 * 16.0:
					past = true
			await get_tree().physics_frame
		await wait_secs(1.0)
		return [past and seen_cable, "host: the guest got past column 12 %s, its cable seen %s" % [past, seen_cable]]
	var has := await wait_until(func(): return Game.tools.get("curl", false), 10.0)
	mgr().swap_to("N10", Vector2(81.0 * 16.0 + 3.0, 19.0 * 16.0 - 10.0))
	await wait_secs(1.0)
	var crossed := 0
	for tr in [[80, 70], [62, 46], [36, 14]]:
		if await curl_trench(tr):
			crossed += 1
	for k in range(60):                                  # on, to the west end
		Controls.script_input = {"left": true}
		await get_tree().physics_frame
	Controls.script_input = {}
	await wait_secs(2.0)
	return [has and crossed == 3, "guest: curl %s, trenches crossed %d of 3" % [has, crossed]]

# the guest's walk through N16 and N17 with ssh: right (jumping now and then) until `to`, `dir` keys
func walk_until(dir: String, to: String, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	var f := 0
	while Time.get_ticks_msec() - t0 < secs * 1000.0 * slow:
		var keys := {dir: true}
		if f % 40 < 14:
			keys["jump"] = true
		f += 1
		Controls.script_input = keys
		mgr().player.hp = mgr().player.max_hp
		await get_tree().physics_frame
		if mgr().room.id == to and not mgr().trans.on:
			Controls.script_input = {}
			return true
	Controls.script_input = {}
	return false

func sc_co_ssh() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.ssh = true
		await wait_secs(1.0)
		mgr().swap_to("N16", Vector2(24.0, 15.0 * 16.0 - 10.0))
		var order: Array = []
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 70000.0 * slow:
			mgr().player.inv = 999.0
			var rr = coop()._remote_room()
			if rr != null and (order.is_empty() or order[order.size() - 1] != rr.id):
				order.append(rr.id)
			if order.has("N17") and order.size() >= 3 and order[order.size() - 1] == "N16":
				break
			await get_tree().physics_frame
		await wait_secs(1.0)
		var ok: bool = order.has("N17") and order.find("N17") < order.rfind("N16")
		return [ok, "host saw the guest in rooms %s" % str(order)]
	var has := await wait_until(func(): return Game.tools.get("ssh", false), 10.0)
	mgr().swap_to("N16", Vector2(24.0, 15.0 * 16.0 - 10.0))
	await wait_secs(2.0)
	var there := await walk_until("right", "N17", 40.0)
	await wait_secs(1.5)
	if not there:
		mgr().swap_to("N17", Vector2(6.0 * 16.0, 11.0 * 16.0 - 10.0))
	var back := await walk_until("left", "N16", 40.0)
	await wait_secs(1.5)
	return [has and there and back, "guest: ssh %s, N16 -> N17 %s, back %s" % [has, there, back]]

# ---- the three bosses of the NETWORK as kit bosses on a shared scenario skeleton
# the guest's bot: stand where it is, swing at a catchable packet that comes close, otherwise at the boss when it is next to it
func boss_guest_keys(g, boss, melee: bool, st: Dictionary) -> Dictionary:
	var press := false
	var r2: Room = mgr().room
	for q in r2.projs:
		if q.get("catchable", false) and not q.get("friendly", false) and not q.dead:
			var d := Vector2(q.x - (g.x + 5.0), q.y - (g.y + 5.0))
			if d.length() < 30.0:
				g.face = 1.0 if d.x >= 0.0 else -1.0
				press = true
	var keys := {}
	if not press and melee and boss != null:
		var dx: float = boss.cx - (g.x + 5.0)
		if absf(dx) > 28.0:
			keys["right" if dx > 0.0 else "left"] = true
		else:
			g.face = 1.0 if dx > 0.0 else -1.0
			press = st.f % 12 < 2
	keys["attack"] = press and g.atk_cd <= 0.0
	if press and g.atk_cd <= 0.0:
		st.swings += 1
	return keys

func boss_arena(room_id: String, host_x: float, guest_x: float) -> Room:
	var x: float = host_x if role == "host" else guest_x
	mgr().swap_to(room_id, Vector2(x, 100.0))
	var p = mgr().player
	p.x = x
	p.y = floor_y(mgr().room, x, 8)
	return mgr().room

func plan_stats(b, seen: Dictionary) -> void:
	if b != null and not b.plan.is_empty() and not seen.has(b.plan.seq):
		seen[b.plan.seq] = b.plan.tgt

# the guest's probe of an arena hazard (MVB3-09): once a hazard that hurts has been on its screen long enough (Boss.hz_harm lists only those), the guest
# puts its body in it, un-immortal, and the hits it takes from the hazard alone are counted. Every other frame it stays immortal as before.
func hazard_probe(g, pup, st: Dictionary) -> void:
	var lost: bool = g.hp < int(st.get("last_hp", g.hp))
	if lost:
		var body: Dictionary = g.hurtbox()
		var haz: Array = pup.hz_harm()
		var on_haz := false
		for b in haz:
			if Game.overlap(body, b):
				on_haz = true
		var on_plan := false
		for b in pup.harmboxes():
			if not b.has("dmg") or true:
				var is_haz := false
				for hb in haz:
					if absf(hb.x - b.x) < 0.01 and absf(hb.y - b.y) < 0.01 and absf(hb.w - b.w) < 0.01:
						is_haz = true
				if not is_haz and Game.overlap(body, b):
					on_plan = true
		if on_haz and not on_plan:
			st.hz_hits = int(st.get("hz_hits", 0)) + 1
	g.hp = g.max_hp
	st.last_hp = g.hp
	var boxes: Array = pup.hz_harm() if pup != null else []
	if int(st.get("hz_hits", 0)) < 1 and not boxes.is_empty() and pup.active:
		var b0: Dictionary = boxes[boxes.size() / 2]
		g.inv = 0.0
		g.x = float(b0.x) + float(b0.w) / 2.0 - 5.0
		g.y = float(b0.y) + float(b0.h) / 2.0 - 5.0
		g.vx = 0.0
		g.vy = 0.0
		st.probing = true
	else:
		g.inv = 999.0
		st.probing = false

# the host's scripted fight: attacks forced at set times, the phase raised twice; returns the plans seen, per target
func boss_phase_script(b, el: float, st: Dictionary, forced: Array, hp_marks: Array) -> void:
	if b == null or not is_instance_valid(b) or not b.active or b.dying:
		return
	if b.hpf < float(b.max_hp) * 0.12:                         # (the bot's claws must not finish it: the fight is the test, 100 s long on a bad line)
		b.hpf = float(b.max_hp) * 0.2
		b.hp = ceili(b.hpf)
	for k in range(hp_marks.size()):
		var m: Array = hp_marks[k]
		if el > float(m[0]) and not st.get("hp%d" % k, false):
			st["hp%d" % k] = true
			b.hpf = float(b.max_hp) * float(m[1])
			b.hp = ceili(b.hpf)
			b.on_damage()
	for k in range(forced.size()):
		var fc: Array = forced[k]
		if el > float(fc[0]) and not st.get("f%d" % k, false) and b.plan.is_empty():
			st["f%d" % k] = true
			if fc.size() > 2:
				b._start(String(fc[1]), String(fc[2]))
			else:
				b._start(String(fc[1]))

func sc_co_crawler() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var secs := 40.0 * slow
	if role == "host":
		Game.tools.catch = true
		await wait_secs(1.0)
		var r := boss_arena("N09", 230.0, 270.0)
		var p = mgr().player
		var started := await wait_until(func(): return mgr().room.fight.state == "active", 25.0)
		var b: CrawlerBoss = r.boss
		var seen := {}
		var st := {}
		var forced := [[3.0, "spin"], [6.0, "volley"], [10.0, "spin"], [14.0, "skitter"], [20.0, "spin"], [25.0, "volley"], [28.0, "spin"], [33.0, "back"]]
		var marks := [[12.0, 0.5], [22.0, 0.2]]
		var caught_hits := 0
		var prev_caught := int(r.stats.get("caught", 0))
		var strands_max := 0
		var phases := {}
		var t0 := Time.get_ticks_msec()
		var f := 0
		while Time.get_ticks_msec() - t0 < secs * 1000.0:
			p.inv = 999.0
			p.hp = p.max_hp
			Controls.script_input = {"attack": f % 50 < 3}
			f += 1
			plan_stats(b, seen)
			var el := float(Time.get_ticks_msec() - t0) / 1000.0 / slow
			boss_phase_script(b, el, st, forced, marks)
			strands_max = maxi(strands_max, b.hz.size())
			phases[b.phase] = true
			var caught := int(r.stats.get("caught", 0))
			if caught > prev_caught:
				caught_hits += 1
			prev_caught = caught
			await get_tree().physics_frame
		Controls.script_input = {}
		var tg := {"p1": 0, "p2": 0}
		for sq in seen:
			tg[seen[sq]] += 1
		await wait_secs(1.0)
		return [started and seen.size() >= 6 and tg.p1 >= 1 and tg.p2 >= 1 and strands_max >= 1 and phases.size() >= 3, "host: started %s, %d plans (p1 %d, p2 %d), strands at most %d, phases %s, packets caught %d" % [started, seen.size(), tg.p1, tg.p2, strands_max, str(phases.keys()), caught_hits]]
	var has := await wait_until(func(): return Game.tools.get("catch", false), 10.0)
	var r2 := boss_arena("N09", 230.0, 270.0)
	var found := {"b": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is CrawlerBoss:
				found.b = e
		return found.b != null, 15.0)
	var pup: CrawlerBoss = found.b
	if pup == null:
		return [false, "no crawler puppet"]
	var st2 := {"f": 0, "swings": 0}
	var seen2 := {}
	var deep := false
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < secs * 1000.0:
		var g = mgr().player
		st2.f += 1
		if not is_instance_valid(pup):
			break
		plan_stats(pup, seen2)
		Controls.script_input = boss_guest_keys(g, pup, false, st2)
		hazard_probe(g, pup, st2)
		deep = deep or pup.dc == 1
		await get_tree().physics_frame
	Controls.script_input = {}
	var short := 0
	for sq in pup.kit_active_seen:
		if float(pup.cue_shown.get(sq, 0.0)) < 0.30 and sq != pup.kit_ignore_seq:
			short += 1
	var mine := 0
	for sq in seen2:
		if seen2[sq] == "p2":
			mine += 1
	await wait_secs(1.0)
	return [has and seen2.size() >= 6 and short == 0 and mine >= 1 and pup.kit_violation == "" and pup.arena_violation == "" and int(st2.get("hz_hits", 0)) >= 1 and deep, "guest: saw %d plans, %d active shown < 0.30 s, targeted %d times, web hits taken %d, deep crawl seen %s, violations '%s' '%s'" % [seen2.size(), short, mine, int(st2.get("hz_hits", 0)), deep, pup.kit_violation, pup.arena_violation]]

func sc_co_firewall() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var secs := 40.0 * slow
	if role == "host":
		await wait_secs(1.0)
		var r := boss_arena("N15", 150.0, 330.0)
		var p = mgr().player
		var started := await wait_until(func(): return mgr().room.fight.state == "active", 25.0)
		var fw: FirewallBoss = r.boss
		var seen := {}
		var st := {}
		var forced := [[3.0, "rule", "p2"], [8.0, "deny", "p2"], [14.0, "scan", "p2"], [20.0, "rule", "p1"], [26.0, "scan", "p2"], [32.0, "deny", "p2"]]
		var marks := [[10.0, 0.55], [24.0, 0.2]]
		var turned := 0
		var wrong := 0
		var was_plan := false
		var walls := false
		var drops := false
		var t0 := Time.get_ticks_msec()
		var f := 0
		while Time.get_ticks_msec() - t0 < secs * 1000.0:
			p.inv = 999.0
			p.hp = p.max_hp
			Controls.script_input = {"attack": f % 50 < 3}
			f += 1
			plan_stats(fw, seen)
			var el := float(Time.get_ticks_msec() - t0) / 1000.0 / slow
			boss_phase_script(fw, el, st, forced, marks)
			for h in fw.hz:
				walls = walls or h.k == "deny"
				drops = drops or h.k == "drop"
			var idle: bool = fw.plan.is_empty()
			if idle and was_plan and fw.read.last_key == "p2" and coop().remote != null and fw._phase_now() < 3:
				var hs: Array = fw.read.hits.get("p2", [])
				if not hs.is_empty() and fw.read.clock - float(hs[hs.size() - 1].t) <= 2.0:
					var want: float = Game.sign_of(fw.kit_aim("p2").x - fw.cx)
					if want == fw.face:
						turned += 1
					else:
						wrong += 1
			was_plan = not idle
			await get_tree().physics_frame
		Controls.script_input = {}
		var tg := {"p1": 0, "p2": 0}
		for sq in seen:
			tg[seen[sq]] += 1
		await wait_secs(1.0)
		return [started and seen.size() >= 6 and tg.p2 >= 1 and wrong == 0 and walls and drops, "host: started %s, %d plans (p1 %d, p2 %d), shield turned to the guest %d times, wrong %d, deny walls %s, DROP ALL %s" % [started, seen.size(), tg.p1, tg.p2, turned, wrong, walls, drops]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := boss_arena("N15", 150.0, 330.0)
	var found := {"b": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is FirewallBoss:
				found.b = e
		return found.b != null, 15.0)
	var pup: FirewallBoss = found.b
	if pup == null:
		return [false, "no firewall puppet"]
	var st2 := {"f": 0, "swings": 0}
	var seen2 := {}
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < secs * 1000.0:
		var g = mgr().player
		st2.f += 1
		if not is_instance_valid(pup):
			break
		plan_stats(pup, seen2)
		Controls.script_input = boss_guest_keys(g, pup, true, st2)
		hazard_probe(g, pup, st2)
		await get_tree().physics_frame
	Controls.script_input = {}
	var short := 0
	for sq in pup.kit_active_seen:
		if float(pup.cue_shown.get(sq, 0.0)) < 0.30 and sq != pup.kit_ignore_seq:
			short += 1
	var mine := 0
	for sq in seen2:
		if seen2[sq] == "p2":
			mine += 1
	await wait_secs(1.0)
	return [seen2.size() >= 6 and short == 0 and mine >= 1 and pup.kit_violation == "" and pup.arena_violation == "" and int(st2.get("hz_hits", 0)) >= 1, "guest: saw %d plans, %d active shown < 0.30 s, targeted %d times, arena hits taken %d, violations '%s' '%s'" % [seen2.size(), short, mine, int(st2.get("hz_hits", 0)), pup.kit_violation, pup.arena_violation]]

# the guest sits on N22's chair with ssh and presses [up]: the host's intro starts, 40 s of fight, nobody is lost
func sc_co_reviewer2() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.ssh = true
		Game.flags["ability:ssh"] = true
		await wait_secs(1.0)
		var r := boss_arena("N22", 60.0, 60.0)
		var p = mgr().player
		var started := await wait_until(func(): return mgr().room.fight.state == "intro" or mgr().room.fight.state == "active", 60.0)
		var active := await wait_until(func(): return mgr().room.fight.state == "active", 15.0)
		var seen := {}
		var st := {}
		var phases := {}
		var marks_seen := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 40000.0 * slow:
			p.inv = 999.0
			p.hp = p.max_hp
			var b = r.boss
			plan_stats(b, seen)
			var el := float(Time.get_ticks_msec() - t0) / 1000.0 / slow
			if b != null:
				boss_phase_script(b, el, st, [[4.0, "nitpick", "p2"], [14.0, "nitpick", "p2"], [24.0, "verdict", "p2"], [34.0, "nitpick", "p2"]], [[12.0, 0.5], [26.0, 0.2]])
				marks_seen = maxi(marks_seen, b.hz.size())
				phases[b.phase] = true
			await get_tree().physics_frame
		var shut: bool = r.fight_active
		return [started and active and seen.size() >= 5 and shut and marks_seen >= 1 and phases.size() >= 3, "host: intro %s, active %s, %d plans, doors shut %s, comments on the floor at most %d, phases %s" % [started, active, seen.size(), shut, marks_seen, str(phases.keys())]]
	var has := await wait_until(func(): return Game.flag("ability:ssh"), 10.0)
	mgr().swap_to("N22", Vector2(11.0 * 16.0 + 3.0, 100.0))
	var g = mgr().player
	g.x = 11.0 * 16.0 + 3.0
	g.y = 176.0 - g.h
	await wait_secs(2.0)
	for k in range(5):
		g = mgr().player
		g.x = 11.0 * 16.0 + 3.0
		g.y = 176.0 - g.h
		g.vx = 0.0
		for q in range(4):
			Controls.script_input = {"up": q < 2}
			await get_tree().physics_frame
		Controls.script_input = {}
		await wait_secs(0.4)
		if mgr().room.fight.state != "none":
			break
	var intro := await wait_until(func(): return mgr().room.fight.state == "intro" or mgr().room.fight.state == "active", 15.0)
	var found := {"b": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is Reviewer2:
				found.b = e
		return found.b != null, 10.0)
	var pup: Reviewer2 = found.b
	var seen2 := {}
	var st2 := {"f": 0}
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 42000.0 * slow:
		var g2 = mgr().player
		st2.f += 1
		plan_stats(pup, seen2)
		if pup != null:
			hazard_probe(g2, pup, st2)
		else:
			g2.inv = 999.0
		await get_tree().physics_frame
	var viol: String = pup.kit_violation if pup != null else "no puppet"
	var av: String = pup.arena_violation if pup != null else "no puppet"
	return [has and intro and pup != null and seen2.size() >= 5 and viol == "" and av == "" and int(st2.get("hz_hits", 0)) >= 1, "guest: ssh flag %s, intro %s, saw %d plans, comment hits taken %d, violations '%s' '%s'" % [has, intro, seen2.size(), int(st2.get("hz_hits", 0)), viol, av]]

# the honeypot bot: go to the nearest DDOS bit, jump when it is above, swing
func honey_keys(r: Room, p, f: int) -> Dictionary:
	var best = null
	for e in r.ents:
		if e is DdosBit and not e.dead and (best == null or absf(e.x - p.x) < absf(best.x - p.x)):
			best = e
	var keys := {"attack": f % 12 < 2}
	if best != null:
		var dx: float = best.x - p.x
		if absf(dx) > 14.0:
			keys["right" if dx > 0.0 else "left"] = true
		else:
			p.face = 1.0 if (f / 24) % 2 == 0 else -1.0
		if best.y < p.y - 20.0 and f % 40 < 12:
			keys["jump"] = true
	return keys

# the typed creatures of the honeypot's waves (a MITM, a BOTNET, a PINGER) are shot down by the host after a few seconds (the bot only fights swarms);
# `seen` collects the classes both pages see
func honey_typed(r: Room, first: Dictionary, seen: Dictionary, kill: bool) -> void:
	for e in r.ents:
		if e.dead:
			continue
		var k := ""
		if e is Mitm:
			k = "mitm"
		elif e is Botnet:
			k = "botnet"
		elif e is Pinger:
			k = "pinger"
		if k == "":
			continue
		seen[k] = true
		if kill:
			var iid: int = e.get_instance_id()
			if not first.has(iid):
				first[iid] = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - int(first[iid]) > 4000:
				e.hp = 0
				e.die("swipe")

# both drop into N21: the swarms are fought off, the typed creatures seen, wave:N21 reaches both, the guest takes rate_limit out of the glass case
func sc_co_honeypot() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var spawn := Vector2(21.0 * 16.0, 3.0 * 16.0)
	if role == "host":
		Game.tools.bash = true
		await wait_secs(1.0)
		mgr().swap_to("N21", spawn)
		var cleared := false
		var first := {}
		var seen_k := {}
		var t0 := Time.get_ticks_msec()
		var f := 0
		while Time.get_ticks_msec() - t0 < 140000.0 * slow:
			var p = mgr().player
			p.inv = 999.0
			p.hp = p.max_hp
			f += 1
			Controls.script_input = honey_keys(mgr().room, p, f)
			honey_typed(mgr().room, first, seen_k, true)
			if Game.flag("wave:N21"):
				cleared = true
				break
			await get_tree().physics_frame
		Controls.script_input = {}
		var owned := await wait_until(func(): return Game.flag("plugin:rate_limit"), 40.0)
		await wait_secs(1.0)
		return [cleared and owned and seen_k.size() == 3, "host: waves cleared %s, rate_limit owned %s, typed creatures seen %s" % [cleared, owned, str(seen_k.keys())]]
	await wait_secs(1.0)
	mgr().swap_to("N21", spawn + Vector2(60.0, 0.0))
	var flag := false
	var seen_g := {}
	var t1 := Time.get_ticks_msec()
	var g := 0
	while Time.get_ticks_msec() - t1 < 140000.0 * slow:
		var p2 = mgr().player
		p2.inv = 999.0
		p2.hp = p2.max_hp
		g += 1
		Controls.script_input = honey_keys(mgr().room, p2, g)
		honey_typed(mgr().room, {}, seen_g, false)
		if Game.flag("wave:N21"):
			flag = true
			break
		await get_tree().physics_frame
	Controls.script_input = {}
	await wait_secs(1.5)
	var r: Room = mgr().room
	var dn = r.grid.door_at("N", 21)
	var door_open: bool = dn != null and dn.open
	var chip: Dictionary = {}
	for it in r.items:
		if it.kind == "plugin":
			chip = it
	var took := false
	if not chip.is_empty():
		for k in range(20):
			var p3 = mgr().player
			p3.x = float(chip.x) - 5.0
			p3.y = float(chip.y) - 6.0
			p3.vx = 0.0
			p3.vy = 0.0
			await wait_secs(0.3)
			if Game.owns_plugin("rate_limit"):
				took = true
				break
	if not took:                                          # (the host's bot may have taken the chip first: the ownership is shared either way)
		took = await wait_until(func(): return Game.owns_plugin("rate_limit"), 10.0)
	return [flag and door_open and took and seen_g.size() == 3, "guest: wave flag %s, N door open %s, chip %s taken %s, typed creatures seen %s" % [flag, door_open, str(not chip.is_empty()), took, str(seen_g.keys())]]

# the guest pulls N02's lever: the host has lever:D06 and D06's slot gate is open
func sc_co_lever() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		var got := await wait_until(func(): return Game.flag("lever:D06"), 30.0)
		var t_flag := Time.get_ticks_msec()
		mgr().swap_to("D06", Vector2(60.0, 100.0))
		await wait_secs(1.0)
		var open: bool = mgr().room.grid.gates_open.agents
		return [got and open, "host: lever:D06 %s, D06's slot gate open %s" % [got, open]]
	await wait_secs(1.5)
	mgr().swap_to("N02", Vector2(4.0 * 16.0 - 14.0, 12.0 * 16.0 + 6.0))
	var r: Room = mgr().room
	var lv: Dictionary = r.levers[0] if not r.levers.is_empty() else {}
	if lv.is_empty():
		return [false, "no lever in N02"]
	for k in range(12):
		var p = mgr().player
		p.x = float(lv.x) - 14.0
		p.y = float(lv.y) + 16.0 - p.h
		p.vx = 0.0
		p.face = 1.0
		p.inv = 999.0
		for q in range(4):
			Controls.script_input = {"attack": q < 2}
			await get_tree().physics_frame
		Controls.script_input = {}
		await wait_secs(0.4)
		if Game.flag("lever:D06"):
			break
	var mine := await wait_until(func(): return Game.flag("lever:D06"), 10.0)
	await wait_secs(2.5)
	return [mine, "guest: lever:D06 %s" % mine]

# ---------------------------------------------------------------- MVB3-09: the NETWORK made hard
# a spot to stand on: the first column from `x0` on with a floor under two free cells (px, top-left of the body)
func stand_spot(r: Room, x0: int, row0: int, dir := 1, row1 := -1) -> Vector2:
	var tx := x0
	while tx > 0 and tx < r.w - 1:
		for ty in range(row0, (r.h if row1 < 0 else mini(row1, r.h))):
			if (r.grid.solid(tx, ty) or r.grid.tile(tx, ty) == TileGrid.ONEWAY) and not r.grid.solid(tx, ty - 1) and not r.grid.solid(tx, ty - 2):
				return Vector2(float(tx * 16 + 3), float(ty * 16 - 10))
		tx += dir
	return Vector2(float(x0 * 16), 100.0)

func all_of(r: Room, cls) -> Array:
	var out: Array = []
	for e in r.ents:
		if is_instance_of(e, cls) and not e.dead:
			out.append(e)
	return out

# N11: a SNIFFER taps a GET ring. The guest's zip to it is cut on its own page, a zip to a clean ring arrives, and the host's sniffer hops
func sc_co_sniffer() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		Game.tools.curl = true
		await wait_secs(1.0)
		mgr().swap_to("N11", Vector2(14.0 * 16.0, 40.0 * 16.0 - 10.0))
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "N11", 20.0)
		var r: Room = mgr().room
		var sn: Array = all_of(r, Sniffer)
		if sn.is_empty():
			return [false, "host: no sniffer in N11"]
		var start_rings: Array = []
		for s2 in sn:
			start_rings.append(s2.ring_i)
		var hopped := false
		var left_clean := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 80000.0 * slow and not hopped:
			mgr().player.inv = 999.0
			for k in range(sn.size()):
				if is_instance_valid(sn[k]) and sn[k].ring_i != start_rings[k]:
					hopped = true
					left_clean = not r.ring_tapped(start_rings[k]) or start_rings.count(start_rings[k]) > 1
			await get_tree().physics_frame
		await wait_secs(4.0)
		return [there and hopped and left_clean, "host: guest in N11 %s, %d sniffers, a sniffer hopped %s, the ring it left was clean %s" % [there, sn.size(), hopped, left_clean]]
	var has := await wait_until(func(): return Game.tools.get("curl", false), 10.0)
	mgr().swap_to("N11", Vector2(56.0 * 16.0, 17.0 * 16.0))
	var r2: Room = mgr().room
	var got := await wait_until(func(): return not all_of(r2, Sniffer).is_empty() and coop().snaps_applied > 3, 15.0)
	if not got:
		return [false, "guest: no sniffer puppet"]
	var sp: Sniffer = all_of(r2, Sniffer)[0]
	# the tapped ring: stand 50 px above it and press [special]
	var cut := false
	var arrived_tapped := false
	for attempt in range(3):
		var rp: Vector2 = Vector2(float(r2.rings[sp.ring_i].x), float(r2.rings[sp.ring_i].y))
		var g = mgr().player
		g.curl_last = -1
		g.inv = 999.0
		g.hp = g.max_hp
		g.x = rp.x - 5.0
		g.y = rp.y - 55.0
		g.vx = 0.0
		g.vy = 0.0
		var tapped_idx: int = sp.ring_i
		await get_tree().physics_frame
		g.x = rp.x - 5.0
		g.y = rp.y - 55.0
		g.vy = 0.0
		Controls.script_input = {"special": true}
		await get_tree().physics_frame
		Controls.script_input = {}
		var started := false
		for k in range(40):
			await get_tree().physics_frame
			if g.zip >= 0:
				started = true
			elif started:
				break
		var d := Vector2(g.x + 5.0 - rp.x, g.y + 5.0 - rp.y).length()
		if started and d > 12.0 and r2.ring_tapped(tapped_idx):
			cut = true
			break
		if started and d <= 12.0:
			arrived_tapped = true
		await wait_secs(0.5)
	# a clean ring: the first ring nobody taps with a spot 50 px above it that picks it
	var arrived := false
	var tries := 0
	for i in range(r2.rings.size()):
		if r2.ring_tapped(i) or arrived:
			continue
		var rq: Vector2 = Vector2(float(r2.rings[i].x), float(r2.rings[i].y))
		var g2 = mgr().player
		g2.curl_last = -1
		g2.x = rq.x - 5.0
		g2.y = rq.y - 55.0
		g2.vx = 0.0
		g2.vy = 0.0
		if r2.grid.box_hits_solid(g2.x, g2.y, 10.0, 10.0) or r2.pick_anchor(g2, 0.0) != i:
			continue
		tries += 1
		await get_tree().physics_frame
		g2.x = rq.x - 5.0
		g2.y = rq.y - 55.0
		g2.vy = 0.0
		Controls.script_input = {"special": true}
		await get_tree().physics_frame
		Controls.script_input = {}
		var st2 := false
		for k in range(40):
			await get_tree().physics_frame
			if g2.zip >= 0:
				st2 = true
			elif st2:
				break
		if st2 and Vector2(g2.x + 5.0 - rq.x, g2.y + 5.0 - rq.y).length() <= 14.0:
			arrived = true
		if tries >= 4:
			break
	# then wait, 85+ px from any tapped ring, and watch the puppet hop
	var ring0: int = sp.ring_i
	var far := Vector2(float(r2.rings[0].x), float(r2.rings[0].y))
	var best_d := 0.0
	for i in range(r2.rings.size()):
		var rr2: Vector2 = Vector2(float(r2.rings[i].x), float(r2.rings[i].y))
		var dd := rr2.distance_to(Vector2(float(r2.rings[sp.ring_i].x), float(r2.rings[sp.ring_i].y)))
		if dd > 85.0 and dd < 150.0 and (best_d == 0.0 or dd < best_d):
			best_d = dd
			far = rr2
	var hop_seen := false
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 60000.0 * slow and not hop_seen:
		var g3 = mgr().player
		g3.inv = 999.0
		g3.hp = g3.max_hp
		g3.x = far.x - 5.0
		g3.y = far.y - 5.0
		g3.vx = 0.0
		g3.vy = 0.0
		if sp.ring_i != ring0:
			hop_seen = true
		await get_tree().physics_frame
	await wait_secs(1.0)
	return [has and cut and arrived and hop_seen, "guest: curl %s, zip to the tapped ring cut %s (arrived anyway %s), zip to a clean ring arrived %s, the puppet hopped %s" % [has, cut, arrived_tapped, arrived, hop_seen]]

# N01: the MITM records the guest's swing and echoes it toward the guest (a side swipe, then an up swipe)
func sc_co_mitm() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("N01", Vector2(3.0 * 16.0, 14.0 * 16.0 - 10.0))
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "N01", 20.0)
		var r: Room = mgr().room
		var ms: Array = all_of(r, Mitm)
		if ms.is_empty():
			return [false, "host: no MITM in N01"]
		var m: Mitm = ms[0]
		var kinds: Array = []
		var toward := 0
		var wrong := 0
		var last_state := ""
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 45000.0 * slow and kinds.size() < 2:
			mgr().player.inv = 999.0
			mgr().player.x = 3.0 * 16.0
			if m.state != last_state:
				if m.state == "echo" and coop().remote != null:
					kinds.append(m.kind)
					var want: float = Game.sign_of(coop().remote.x + 5.0 - m.cx)
					if want == m.face:
						toward += 1
					else:
						wrong += 1
				last_state = m.state
			await get_tree().physics_frame
		await wait_secs(2.0)
		return [there and kinds.size() >= 2 and kinds[0] == 0 and kinds[1] == 1 and wrong == 0, "host: echo kinds %s (side 0, up 1), faced the guest %d times, wrong %d" % [str(kinds), toward, wrong]]
	await wait_secs(1.5)
	mgr().swap_to("N01", Vector2(26.0 * 16.0, 14.0 * 16.0 - 10.0))
	var r2: Room = mgr().room
	var got := await wait_until(func(): return not all_of(r2, Mitm).is_empty() and coop().snaps_applied > 3, 15.0)
	if not got:
		return [false, "guest: no MITM puppet"]
	var pm: Mitm = all_of(r2, Mitm)[0]
	var saw_record := [false, false]
	var echo_toward := [false, false]
	var kind_seen := [-1, -1]
	for round in range(2):
		# wait until it stands near, in `listen`
		await wait_until(func(): return pm.state == "listen" and absf(pm.cx - (mgr().player.x + 5.0)) < 70.0, 25.0)
		await wait_secs(0.7)                                    # (it listens again 0.3 s after `open`)
		var g = mgr().player
		g.inv = 999.0
		g.hp = g.max_hp
		g.face = 1.0 if pm.cx > g.x else -1.0
		for q in range(4):
			Controls.script_input = {"attack": q < 2, "up": round == 1}
			await get_tree().physics_frame
		Controls.script_input = {}
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 6000.0 * slow:
			g.inv = 999.0
			g.hp = g.max_hp
			if pm.state == "record":
				saw_record[round] = true
				kind_seen[round] = pm.kind
			if pm.state == "echo":
				for hb in pm.harmboxes():
					if hb is Dictionary and hb.w == (28.0 if round == 0 else 26.0):
						var mid: float = hb.x + hb.w / 2.0
						if round == 0 and (mid - pm.cx) * (g.x + 5.0 - pm.cx) > 0.0:
							echo_toward[round] = true
						if round == 1 and absf(mid - pm.cx) < 2.0 and hb.y < pm.y:
							echo_toward[round] = true
			if pm.state == "open" and saw_record[round]:
				break
			await get_tree().physics_frame
		await wait_secs(0.5)
	return [saw_record[0] and saw_record[1] and echo_toward[0] and echo_toward[1] and kind_seen[0] == 0 and kind_seen[1] == 1, "guest: recorded %s (kinds %s), echo toward me %s" % [str(saw_record), str(kind_seen), str(echo_toward)]]

# N17: the guest passes row 16 and starts the RST chase; both pages draw the line within 8 px (plus the line's own delay); the line hurts the guest once;
# when both stand below row 77 rst:N17 is set on both and the line is gone
func sc_co_rst() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("N17", Vector2(3.0 * 16.0, 4.0 * 16.0))
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "N17", 20.0)
		var r: Room = mgr().room
		clear_creatures(r)                                           # (the line is the test, not the room's creatures)
		var top: Vector2 = stand_spot(r, 2, 3, 1, 15)
		var host_above := true
		var started := false
		var samples: Array = []
		var t0 := Time.get_ticks_msec()
		var next_s := 0.0
		while Time.get_ticks_msec() - t0 < 90000.0 * slow:
			var p = mgr().player
			p.inv = 999.0
			p.hp = p.max_hp
			for e in r.ents:
				if not e.dead:
					e.dead = true
			if not started:
				p.x = top.x
				p.y = top.y
				p.vx = 0.0
				p.vy = 0.0
				if r.ch_t0 >= 0.0:
					started = true
					host_above = p.y < 16.0 * 16.0
			else:
				if float(Time.get_ticks_msec()) / 1000.0 > next_s:
					next_s = float(Time.get_ticks_msec()) / 1000.0 + 0.25
					samples.append([Time.get_unix_time_from_system(), r.chase_line_y(), r.time])
				if r.time - r.ch_t0 > 12.0 and not Game.flag("rst:N17"):
					var bot: Vector2 = stand_spot(r, 2, 78)
					p.x = bot.x
					p.y = bot.y
					p.vx = 0.0
					p.vy = 0.0
				if Game.flag("rst:N17"):
					break
			await get_tree().physics_frame
		await wait_secs(2.0)
		var gone: bool = r.ch_t0 < 0.0
		# the guest's samples (its log lines reach this log) against ours at the same wall time
		var gs: Array = []
		for ln in Game.log_buf:
			var txt: String = ln[1]
			if txt.begins_with("P2> SCN chase "):
				var parts := txt.substr(14).split(" ")
				gs.append([float(parts[0]), float(parts[1]), float(parts[2])])
		var cmp := 0
		var worst := 0.0
		var tdiff: Array = []
		for gsm in gs.slice(6):                                      # (the first seconds after the guest came in: its clock is still catching up with ours)
			var best = null
			for hs in samples:
				if absf(hs[0] - gsm[0]) < 0.13 and (best == null or absf(hs[0] - gsm[0]) < absf(best[0] - gsm[0])):
					best = hs
			if best != null:
				cmp += 1
				worst = maxf(worst, absf(best[1] - gsm[1]))
				tdiff.append(snappedf(gsm[2] - best[2], 0.01))
		var tol := 8.0 + 46.0 * (Net.rtt / 2.0 + 0.2 if slow > 1.0 else 0.0)
		return [there and started and host_above and Game.flag("rst:N17") and gone and cmp >= 4 and worst <= tol, "host: guest in N17 %s, chase started by the guest %s (host above row 16: %s), rst:N17 %s, line gone %s, %d samples compared, worst difference %.1f px (limit %.1f), clock differences guest-host %s" % [there, started, host_above, Game.flag("rst:N17"), gone, cmp, worst, tol, str(tdiff.slice(0, 12))]]
	await wait_secs(1.5)
	mgr().swap_to("N17", Vector2(3.0 * 16.0, 18.0 * 16.0))
	var r2: Room = mgr().room
	var g = mgr().player
	var spot: Vector2 = stand_spot(r2, 2, 17, 1, 30)
	g.x = spot.x
	g.y = spot.y
	g.vx = 0.0
	g.vy = 0.0
	var saw := await wait_until(func(): return r2.ch_t0 >= 0.0, 15.0)
	var hp0: int = g.hp
	var hurt_once := false
	var moved_below := false
	var t1 := Time.get_ticks_msec()
	var next_log := 0.0
	var line_ok := true
	while Time.get_ticks_msec() - t1 < 30000.0 * slow and not hurt_once:
		g.inv = 0.0 if g.hp >= hp0 else 999.0
		if r2.ch_t0 >= 0.0 and float(Time.get_ticks_msec()) / 1000.0 > next_log:
			next_log = float(Time.get_ticks_msec()) / 1000.0 + 0.25
			Game.dlog("SCN chase %.3f %.1f %.3f" % [Time.get_unix_time_from_system(), r2.chase_line_y(), r2.time])
		if g.hp < hp0:
			hurt_once = true
			moved_below = g.y > r2.chase_line_y() - 2.0
			g.inv = 999.0
		await get_tree().physics_frame
	# then on down, to row 77 and below, logging the line on the way
	var t2 := Time.get_ticks_msec()
	var bot2: Vector2 = stand_spot(r2, 2, 78)
	while Time.get_ticks_msec() - t2 < 60000.0 * slow and not Game.flag("rst:N17"):
		g.inv = 999.0
		g.hp = g.max_hp
		if r2.ch_t0 >= 0.0 and float(Time.get_ticks_msec()) / 1000.0 > next_log:
			next_log = float(Time.get_ticks_msec()) / 1000.0 + 0.25
			Game.dlog("SCN chase %.3f %.1f %.3f" % [Time.get_unix_time_from_system(), r2.chase_line_y(), r2.time])
		if r2.time - maxf(r2.ch_t0, 0.0) > 10.0:
			g.x = bot2.x
			g.y = bot2.y
			g.vx = 0.0
			g.vy = 0.0
		await get_tree().physics_frame
	await wait_secs(3.0)
	var flag := Game.flag("rst:N17")
	return [saw and hurt_once and moved_below and flag and r2.ch_t0 < 0.0, "guest: line seen %s, hurt once by it %s and put below it %s, rst:N17 %s, line gone %s" % [saw, hurt_once, moved_below, flag, r2.ch_t0 < 0.0]]

# N12: packet loss. Both pages lose the same packets (the guest's list of lost packets is a run of the host's), and the guest, riding a lossy packet, falls with it
func loss_watch(r: Room, st: Dictionary) -> void:
	for m in r.plats:
		if m.get("packet", false) and m.get("lossy", false):
			var j: int = m.j
			var was: bool = st.was.get(j, false)
			var now: bool = bool(m.lost)
			if now and not was:
				st.events.append(j)
				if role == "guest":
					Game.dlog("SCN loss %d" % j)
			st.was[j] = now

func sc_co_loss() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var st := {"was": {}, "events": []}
	if role == "host":
		await wait_secs(1.0)
		mgr().swap_to("N12", Vector2(2.0 * 16.0, 10.0 * 16.0 - 10.0))
		var there := await wait_until(func(): return coop()._remote_room() != null and coop()._remote_room().id == "N12", 20.0)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 50000.0 * slow:
			mgr().player.inv = 999.0
			mgr().player.hp = mgr().player.max_hp
			mgr().player.x = 2.0 * 16.0
			mgr().player.y = 10.0 * 16.0 - 10.0
			loss_watch(mgr().room, st)
			await get_tree().physics_frame
		await wait_secs(2.0)
		var gl: Array = []
		for ln in Game.log_buf:
			var txt: String = ln[1]
			if txt.begins_with("P2> SCN loss "):
				gl.append(int(txt.substr(13)))
		# the guest's events are a run of ours (it came in later)
		var ok := gl.size() >= 3
		var hl: Array = st.events
		var start := -1
		for i in range(hl.size()):
			if hl.slice(i, i + gl.size()) == gl:
				start = i
		var all_third := true
		for j in hl:
			if int(j) % 3 != 2:
				all_third = false
		return [there and ok and start >= 0 and all_third and hl.size() >= 3, "host: %d losses %s, the guest saw %s (a run of ours at %d), only every third packet %s" % [hl.size(), str(hl), str(gl), start, all_third]]
	await wait_secs(1.5)
	mgr().swap_to("N12", Vector2(2.0 * 16.0, 10.0 * 16.0 - 10.0))
	var r2: Room = mgr().room
	await wait_until(func(): return coop().snaps_applied > 3, 10.0)
	var rode := 0
	var fell := false
	var riding_j := -1
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 52000.0 * slow:
		var g = mgr().player
		g.inv = 999.0
		g.hp = g.max_hp
		loss_watch(r2, st)
		# ride a lossy packet that is still before the first loss column
		if riding_j < 0 or g.y > 15.0 * 16.0:
			for m in r2.plats:
				if m.get("packet", false) and m.get("lossy", false) and not m.off and m.x + m.w / 2.0 > 22.0 * 16.0 and m.x + m.w / 2.0 < 25.0 * 16.0:
					riding_j = m.j
					g.x = m.x + m.w / 2.0 - 5.0
					g.y = m.y - 10.0
					g.vx = 0.0
					g.vy = 0.0
					break
		if g.ride != null and g.ride.get("lossy", false):
			rode += 1
		for m in r2.plats:
			if m.get("packet", false) and m.j == riding_j and m.lost and g.y > m.y + 14.0:
				fell = true
		await get_tree().physics_frame
	await wait_secs(1.0)
	return [rode >= 10 and fell and st.events.size() >= 3, "guest: rode a lossy packet for %d frames, fell with it when it was lost %s, saw %d losses %s" % [rode, fell, st.events.size(), str(st.events)]]

# ================================================================ phase 5A: THREAD TOWER
# both pages go to the same tower room and stand on a spot of their own (a pinned, immortal body)
func tower_room(room_id: String, hx: float, hy: float, gx: float, gy: float) -> Room:
	var x: float = hx if role == "host" else gx
	var y: float = hy if role == "host" else gy
	mgr().swap_to(room_id, Vector2(x, y))
	var p = mgr().player
	p.x = x
	p.y = y
	p.vx = 0.0
	p.vy = 0.0
	return mgr().room

func pin(p, x: float, y: float) -> void:
	p.inv = 999.0
	p.hp = p.max_hp
	p.x = x
	p.y = y
	p.vx = 0.0
	p.vy = 0.0

# the clock, the blink blocks, the gears and the pistons agree on both pages (T02, TC1, TC2): the guest compares its machines with what the host's clock implies
func sc_co_tick() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var worst := 0.0
	var bad := 0
	var checked := 0
	var seen_groups := 0
	var seen_gears := 0
	var seen_pistons := 0
	for rid in ["T02", "TC1", "TC2"]:
		await wait_secs(1.0)
		var r := tower_room(rid, 5.0 * 16.0 + 3.0, 5.0 * 16.0, 5.0 * 16.0 + 3.0, 5.0 * 16.0)
		clear_creatures(r)
		var t0 := Time.get_ticks_msec()
		var f := 0
		while Time.get_ticks_msec() - t0 < 7000.0 * slow:
			var p = mgr().player
			pin(p, 5.0 * 16.0 + 3.0 + (0.0 if role == "host" else 2.0), 5.0 * 16.0)
			f += 1
			if role == "guest" and coop().last_rt_at > 0.0 and f > 90:
				var rr: Room = mgr().room
				if rr.id == rid and rr.tower != null:
					var host_t: float = coop().last_rt + (coop().hms() - coop().last_rt_at)
					worst = maxf(worst, absf(rr.time - host_t))
					seen_groups = maxi(seen_groups, rr.tower.bgroups.size())
					seen_gears = maxi(seen_gears, rr.tower.gears.size())
					seen_pistons = maxi(seen_pistons, rr.tower.pistons.size())
					checked += 1
					if rr.tower.mismatch(host_t) != "":
						bad += 1
			await get_tree().physics_frame
	await wait_secs(1.0)
	if role == "host":
		return [true, "host: walked T02, TC1, TC2"]
	return [checked > 300 and bad <= 5 and worst < 0.6 and seen_groups > 0 and seen_gears > 0 and seen_pistons > 0, "guest: %d checks, %d mismatches, clock off by at most %.2f s, %d blink groups, %d gears, %d pistons" % [checked, bad, worst, seen_groups, seen_gears, seen_pistons]]

# the guest freezes a busy piston of TC2; the host sees it frozen, and the guest stands in the shaft for 2.5 s without a scratch
func sc_co_breakpoint() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var px := 11.0 * 16.0 + 19.0
	var py := 37.0 * 16.0 - 10.0
	if role == "host":
		Game.tools.breakpoint = true
		await wait_secs(1.0)
		var r := tower_room("TC2", 3.0 * 16.0, 58.0 * 16.0 - 10.0, px, py)
		clear_creatures(r)
		var pz: Dictionary = r.tower.pistons[0]
		var t0 := Time.get_ticks_msec()
		var seen_frozen := -1.0
		var open_after := 0
		var still := 0
		while Time.get_ticks_msec() - t0 < 16000.0 * slow:
			pin(mgr().player, 3.0 * 16.0, 58.0 * 16.0 - 10.0)
			if r.tower.is_frozen("p0"):
				if seen_frozen < 0.0:
					seen_frozen = float(Time.get_ticks_msec() - t0) / 1000.0
				else:
					still += 1
					if pz.rows == 0:
						open_after += 1
			await get_tree().physics_frame
		await wait_secs(1.0)
		return [seen_frozen >= 0.0 and still > 60 and open_after >= still - 2, "host: frozen after %.1f s, %d frames after it, the shaft open in %d of them" % [seen_frozen, still, open_after]]
	Game.tools.breakpoint = true
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := tower_room("TC2", 3.0 * 16.0, 58.0 * 16.0 - 10.0, px, py)
	await wait_secs(1.5)
	var g = mgr().player
	var press_at := 0.0
	var frozen_at := -1.0
	var hp0: int = g.hp
	var t1 := Time.get_ticks_msec()
	var f := 0
	var inside_f := 0
	var hurt := 0
	while Time.get_ticks_msec() - t1 < 14000.0 * slow:
		f += 1
		if frozen_at < 0.0:
			g.x = px
			g.y = py
			g.vx = 0.0
			g.vy = 0.0
			g.face = 1.0
			g.inv = 999.0
			var rows_now: int = r2.tower.pistons[0].rows
			var press: bool = f > 30 and rows_now == 0 and f % 2 == 0 and g.bp_cd <= 0.0     # (the guest presses when ITS page shows the shaft clear)
			Controls.script_input = {"special": press}
			if press and press_at == 0.0:
				press_at = float(Time.get_ticks_msec()) / 1000.0
			if r2.tower != null and r2.tower.is_frozen("p0"):
				frozen_at = float(Time.get_ticks_msec()) / 1000.0
				Controls.script_input = {}
		else:
			Controls.script_input = {}
			g.inv = 0.0
			g.x = 11.0 * 16.0 + 19.0
			g.y = 42.0 * 16.0 - 10.0
			g.vx = 0.0
			g.vy = 0.0
			if float(Time.get_ticks_msec()) / 1000.0 - frozen_at < 2.5:
				inside_f += 1
				if g.hp < hp0:
					hurt += 1
		await get_tree().physics_frame
	Controls.script_input = {}
	return [frozen_at > 0.0 and frozen_at - press_at < 3.0 * slow and inside_f > 60 and hurt == 0, "guest: pressed at %.1f, saw the freeze after %.2f s, %d frames in the shaft, hurt %d" % [press_at, frozen_at - press_at, inside_f, hurt]]

# the guest stands on TB2's first key; the host sees the gate open and a body can pass; when the guest steps off, it closes again
func sc_co_mutex() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var kx := 3.0 * 16.0 + 3.0
	var ky := 58.0 * 16.0 + 4.0
	if role == "host":
		await wait_secs(1.0)
		var r := tower_room("TB2", 12.0 * 16.0, 40.0 * 16.0, kx, ky)
		clear_creatures(r)
		var gate_idx: int = r.tower.mutex[0].cells[0]
		var gtx: int = gate_idx % r.w
		var gty: int = gate_idx / r.w
		var closed_first: bool = r.grid.solid(gtx, gty) or r.tower.mutex[0].t > 0.0       # (the guest may already stand on the key)
		var opened := false
		var open_held := 0
		var closed_again := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 16000.0 * slow:
			pin(mgr().player, 12.0 * 16.0, 40.0 * 16.0)
			var guest_on: bool = r.tower.mutex[0].t > 0.0
			if guest_on and not r.grid.solid(gtx, gty):
				opened = true
				open_held += 1
			if opened and r.tower.mutex[0].t <= 0.0 and r.grid.solid(gtx, gty):
				closed_again = true
				break
			await get_tree().physics_frame
		return [closed_first and opened and open_held > 60 and closed_again, "host: closed at first %s, opened %s (%d frames), closed again %s" % [closed_first, opened, open_held, closed_again]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := tower_room("TB2", 12.0 * 16.0, 40.0 * 16.0, kx, ky)
	var gate2: int = r2.tower.mutex[0].cells[0]
	var open_seen := false
	var closed_seen := false
	var t1 := Time.get_ticks_msec()
	var f := 0
	while Time.get_ticks_msec() - t1 < 16000.0 * slow:
		f += 1
		var on_key: bool = float(Time.get_ticks_msec() - t1) < 5000.0 * slow
		if on_key:
			pin(mgr().player, kx, ky)
		else:
			pin(mgr().player, 12.0 * 16.0, 40.0 * 16.0)
		if on_key and not r2.grid.solid(gate2 % r2.w, gate2 / r2.w):
			open_seen = true
		if open_seen and not on_key and r2.grid.solid(gate2 % r2.w, gate2 / r2.w):
			closed_seen = true
		await get_tree().physics_frame
	return [open_seen and closed_seen, "guest: gate open on its page %s, closed again %s" % [open_seen, closed_seen]]

# the guest wraps T09 three times: both pages show i = 3 and the `break;` key
func sc_co_loop() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var hx := 14.0 * 16.0
	var fy := 15.0 * 16.0 - 10.0
	if role == "host":
		await wait_secs(1.0)
		var r := tower_room("T09", hx, fy, 60.0 * 16.0, fy)
		var ok := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 40000.0 * slow:
			if mgr().room.id == "T09":
				clear_creatures(mgr().room)
				pin(mgr().player, hx, fy)
				if mgr().room.iter >= 3 and mgr().room.loop_key_on():
					ok = true
					break
			await get_tree().physics_frame
		await wait_secs(2.0)
		return [ok, "host: i = %d, key shown %s" % [mgr().room.iter, str(mgr().room.loop_key_on())]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := tower_room("T09", hx, fy, 60.0 * 16.0, fy)
	var t1 := Time.get_ticks_msec()
	var ok2 := false
	while Time.get_ticks_msec() - t1 < 40000.0 * slow:
		var g = mgr().player
		if mgr().room.id == "T09" and not mgr().trans.on:
			var rm: Room = mgr().room
			if rm.iter >= 3 and rm.loop_key_on():
				ok2 = true
				break
			g.inv = 999.0
			g.hp = g.max_hp
			if g.x < 900.0 or g.y > 236.0:                        # just arrived at the west door: back onto the ledge at the east door, and push through it again
				g.x = 1006.0
				g.y = fy
				g.vx = 0.0
				g.vy = 0.0
			Controls.script_input = {"right": true}
		else:
			Controls.script_input = {}
		await get_tree().physics_frame
	Controls.script_input = {}
	await wait_secs(1.0)
	return [ok2, "guest: i = %d, key shown %s" % [mgr().room.iter, str(mgr().room.loop_key_on())]]

# the shared fight: 30 s, the host forces attacks at set times; the guest swings at a thread, the kit's rules must hold (no boss-cue, no arena-tell)
func tower_fight_host(room_id: String, host_x: float, guest_x: float, forced: Array, marks: Array, extra: Callable) -> Array:
	await wait_secs(1.0)
	var secs := (34.0 if room_id == "T10" else 32.0) * slow
	var r := boss_arena(room_id, host_x, guest_x)
	var p = mgr().player
	var started := await wait_until(func(): return mgr().room.fight.state == "active", 25.0)
	var b = r.boss
	var seen := {}
	var st := {}
	var t0 := Time.get_ticks_msec()
	var f := 0
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		p.inv = 999.0
		p.hp = p.max_hp
		Controls.script_input = {"attack": f % 50 < 3}
		f += 1
		plan_stats(b, seen)
		var el := float(Time.get_ticks_msec() - t0) / 1000.0 / slow
		boss_phase_script(b, el, st, forced, marks)
		extra.call(b, st, el)
		await get_tree().physics_frame
	Controls.script_input = {}
	var tg := {"p1": 0, "p2": 0}
	for sq in seen:
		tg[seen[sq]] += 1
	await wait_secs(1.0)
	return [started, seen.size(), tg, st]

func sc_co_race() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var forced := [[3.0, "rw", "p2"], [8.0, "rw", "p1"], [13.0, "switch", "p2"], [18.0, "rw", "p2"], [23.0, "contend", "p2"], [28.0, "rw", "p2"]]
		var marks := [[9.0, 0.55], [20.0, 0.2]]
		var res: Array = await tower_fight_host("T06", 150.0, 270.0, forced, marks, func(b, st, el):
			st["corrupt"] = maxi(int(st.get("corrupt", 0)), b.hz.size())
			for q in b.th:                                        # (the guest's swings must not finish the fight: the rules are the test)
				if not q.dead and q.hp < 8.0:
					q.hp = 8.0
			b._sums())
		return [res[0] and res[1] >= 5 and res[2].p2 >= 1, "host: started %s, %d plans (p1 %d, p2 %d), corrupt segments at most %d" % [res[0], res[1], res[2].p1, res[2].p2, int(res[3].get("corrupt", 0))]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := boss_arena("T06", 150.0, 270.0)
	var found := {"b": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is RaceBoss:
				found.b = e
		return found.b != null, 15.0)
	var pup: RaceBoss = found.b
	if pup == null:
		return [false, "no RaceBoss puppet"]
	var st2 := {"f": 0, "swings": 0}
	var seen2 := {}
	var stale := 0
	var writes := 0
	var secs := 32.0 * slow
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < secs * 1000.0:
		var g = mgr().player
		st2.f += 1
		if not is_instance_valid(pup):
			break
		plan_stats(pup, seen2)
		# a thread is something to hit: walk up to the nearer living one and swing
		var near = null
		for q in pup.th:
			if not q.dead and (near == null or absf(q.x - (g.x + 5.0)) < absf(near.x - (g.x + 5.0))):
				near = q
		var keys := {}
		if near != null:
			var dx: float = near.x - (g.x + 5.0)
			if absf(dx) > 26.0:
				keys["right" if dx > 0.0 else "left"] = true
			else:
				g.face = 1.0 if dx > 0.0 else -1.0
				keys["attack"] = st2.f % 14 < 2 and g.atk_cd <= 0.0
		Controls.script_input = keys
		hazard_probe(g, pup, st2)
		# the write lands where the guest was when the thread read it: while a write box is live on this page, the guest has usually walked on
		if pup.plan_active() and String(pup.plan.id) == "rw":
			for hb in pup.harmboxes():
				if hb.get("dmg", 0) >= 1 and hb.h >= 39.0:
					writes += 1
					if absf((float(hb.x) + 16.0) - (g.x + 5.0)) > 20.0:
						stale += 1
		await get_tree().physics_frame
	Controls.script_input = {}
	var short := 0
	for sq in pup.kit_active_seen:
		if float(pup.cue_shown.get(sq, 0.0)) < 0.30 and sq != pup.kit_ignore_seq:
			short += 1
	var mine := 0
	for sq in seen2:
		if seen2[sq] == "p2":
			mine += 1
	await wait_secs(1.0)
	return [seen2.size() >= 5 and short == 0 and mine >= 1 and pup.kit_violation == "" and pup.arena_violation == "" and writes > 0, "guest: saw %d plans, %d active shown < 0.30 s, targeted %d times, %d write frames (%d off the guest), violations '%s' '%s'" % [seen2.size(), short, mine, writes, stale, pup.kit_violation, pup.arena_violation]]

func sc_co_loopboss() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	if role == "host":
		var forced := [[2.0, "lap", "p2"], [15.0, "nested", "p2"], [23.0, "recursion", "p2"], [31.0, "rest", "p2"]]
		var marks := [[16.0, 0.5], [24.0, 0.2]]
		var res: Array = await tower_fight_host("T10", 120.0, 280.0, forced, marks, func(b, st, el): st["strips"] = bool(st.get("strips", false)) or b.strips_on)
		return [res[0] and res[1] >= 4 and res[2].p2 >= 1, "host: started %s, %d plans (p1 %d, p2 %d), strips %s" % [res[0], res[1], res[2].p1, res[2].p2, str(res[3].get("strips", false))]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := boss_arena("T10", 120.0, 280.0)
	var found := {"b": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is LoopBoss:
				found.b = e
		return found.b != null, 15.0)
	var pup: LoopBoss = found.b
	if pup == null:
		return [false, "no LoopBoss puppet"]
	var st2 := {"f": 0, "swings": 0}
	var seen2 := {}
	var wraps := 0
	var last_x := 0.0
	var modes := {}
	var secs := 34.0 * slow
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < secs * 1000.0:
		var g = mgr().player
		st2.f += 1
		if not is_instance_valid(pup):
			break
		plan_stats(pup, seen2)
		modes[pup.mode] = true
		# walk left through the portal again and again, hitting the tail whenever it is close
		var keys := {"left": true}
		var tp: Vector2 = pup.tail_point()
		if pup.mode != "idle" and tp.x > 0.0 and absf(tp.x - (g.x + 5.0)) < 26.0 and absf(tp.y - (g.y + 5.0)) < 20.0:
			keys["attack"] = st2.f % 10 < 2
		Controls.script_input = keys
		hazard_probe(g, pup, st2)
		if st2.f > 1 and absf(g.x - last_x) > 250.0:
			wraps += 1
		last_x = g.x
		await get_tree().physics_frame
	Controls.script_input = {}
	var short := 0
	for sq in pup.kit_active_seen:
		if float(pup.cue_shown.get(sq, 0.0)) < 0.30 and sq != pup.kit_ignore_seq:
			short += 1
	var mine := 0
	for sq in seen2:
		if seen2[sq] == "p2":
			mine += 1
	await wait_secs(1.0)
	return [seen2.size() >= 4 and short == 0 and mine >= 1 and pup.kit_violation == "" and pup.arena_violation == "" and wraps >= 1 and modes.has("recursion"), "guest: saw %d plans, %d shown < 0.30 s, targeted %d times, wrapped through the portal %d times, modes %s, violations '%s' '%s'" % [seen2.size(), short, mine, wraps, str(modes.keys()), pup.kit_violation, pup.arena_violation]]

func sc_co_deadlock() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var secs := 30.0 * slow
	if role == "host":
		await wait_secs(1.0)
		var r := boss_arena("T18", 90.0, 300.0)
		var p = mgr().player
		var started := await wait_until(func(): return mgr().room.fight.state == "active", 25.0)
		var b: DeadlockBoss = r.boss
		var seen := {}
		var st := {}
		var committed := false
		var rolled := false
		var forced := [[4.0, "chain", "p2"], [10.0, "grab", "p2"], [20.0, "swap", "p2"]]
		var t0 := Time.get_ticks_msec()
		var f := 0
		var hit_a_at := -1.0
		while Time.get_ticks_msec() - t0 < secs * 1000.0:
			p.inv = 999.0
			p.hp = p.max_hp
			Controls.script_input = {}
			f += 1
			plan_stats(b, seen)
			var el := float(Time.get_ticks_msec() - t0) / 1000.0 / slow
			boss_phase_script(b, el, st, forced, [])
			if b != null and b.active and not b.dying:
				# the guest's swings land on half B; when B has a pending hit, the host hits A inside the window: both must commit
				if b.halves[1].pend > 0.0 and hit_a_at < 0.0 and el > 12.0:
					r.attacker = p
					var a_hp: float = b.halves[0].hp
					var b_hp: float = b.halves[1].hp
					b.hit(1, 1.0, 0.0, "swipe", b.hurtboxes()[0])
					hit_a_at = el
					st["a_before"] = a_hp
					st["b_before"] = b_hp
				if hit_a_at > 0.0 and el > hit_a_at + 0.3 and not committed:
					committed = b.halves[0].hp < float(st.get("a_before", 99.0)) and b.halves[1].hp < float(st.get("b_before", 99.0))
				if b.hpf < float(b.max_hp) * 0.12:
					b.halves[0].hp = maxf(b.halves[0].hp, 6.0)
					b.halves[1].hp = maxf(b.halves[1].hp, 6.0)
					b._sums()
				# park half B next to the guest so its swings reach it (outside the scripted attacks)
				if b.plan.is_empty() and not b.halves[1].dead:
					b.halves[1].home_x = 270.0
					b.halves[0].home_x = 90.0
			await get_tree().physics_frame
		Controls.script_input = {}
		var tg := {"p1": 0, "p2": 0}
		for sq in seen:
			tg[seen[sq]] += 1
		await wait_secs(1.0)
		return [started and seen.size() >= 3 and committed, "host: started %s, %d plans (p1 %d, p2 %d), the host hit and the guest's pending hit committed: %s" % [started, seen.size(), tg.p1, tg.p2, committed]]
	await wait_until(func(): return mgr().room != null and mgr().player != null, 10.0)
	var r2 := boss_arena("T18", 90.0, 300.0)
	var found := {"b": null}
	await wait_until(func():
		for e in mgr().room.ents:
			if e is DeadlockBoss:
				found.b = e
		return found.b != null, 15.0)
	var pup: DeadlockBoss = found.b
	if pup == null:
		return [false, "no DeadlockBoss puppet"]
	var st2 := {"f": 0, "swings": 0}
	var seen2 := {}
	var pend_seen := false
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < secs * 1000.0:
		var g = mgr().player
		st2.f += 1
		if not is_instance_valid(pup):
			break
		plan_stats(pup, seen2)
		var hb = pup.halves[1]
		var keys := {}
		var dx: float = hb.x - (g.x + 5.0)
		if not hb.dead:
			if absf(dx) > 24.0:
				keys["right" if dx > 0.0 else "left"] = true
			else:
				g.face = 1.0 if dx > 0.0 else -1.0
				keys["attack"] = st2.f % 14 < 2 and g.atk_cd <= 0.0
		Controls.script_input = keys
		hazard_probe(g, pup, st2)
		pend_seen = pend_seen or float(hb.pend) > 0.0
		await get_tree().physics_frame
	Controls.script_input = {}
	var short := 0
	for sq in pup.kit_active_seen:
		if float(pup.cue_shown.get(sq, 0.0)) < 0.30 and sq != pup.kit_ignore_seq:
			short += 1
	await wait_secs(1.0)
	return [seen2.size() >= 3 and short == 0 and pup.kit_violation == "" and pup.arena_violation == "" and pend_seen, "guest: saw %d plans, %d shown < 0.30 s, a pending hit shown %s, violations '%s' '%s'" % [seen2.size(), short, pend_seen, pup.kit_violation, pup.arena_violation]]

# A measuring run, not in `all`: both bots play in one room (PERF_ROOM, N02) for SOAK_S seconds and every 15 s each page prints its CPU per frame
# and what it holds, with every list over 40 entries (a cost or a count that keeps growing is the "the game gets slower the longer we play" bug).
# SOAK_S over ~90 needs a longer timeout than coop-test.sh gives.
func sc_co_perf() -> Array:
	if not await wait_joined():
		return [false, "nobody joined"]
	var secs := float(OS.get_environment("SOAK_S")) if OS.get_environment("SOAK_S") != "" else 120.0
	var rid := OS.get_environment("PERF_ROOM") if OS.get_environment("PERF_ROOM") != "" else "N02"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if role == "host" else 11
	var st := {"t": 0.0, "dir": "right"}
	await wait_secs(1.0)
	mgr().swap_to(rid, null, null, false)
	var t0 := Time.get_ticks_msec()
	var c0 := _cpu_ms()
	var f0 := Engine.get_physics_frames()
	var next := 15.0
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		var p = mgr().player
		Controls.script_input = _bot(rng, st)
		if p != null and p.dead:
			p.dead = false
			p.hp = p.max_hp
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t >= next:
			next += 15.0
			var c := _cpu_ms()
			var f := Engine.get_physics_frames()
			print("PERF %s t=%d cpu/frame %.2f ms objects %d nodes %d orphans %d log %d rel_out %d room %s ents %d" % [role, int(t), (c - c0) / maxf(1.0, float(f - f0)),
				Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Game.log_buf.size(), Net.rel_out.size(), mgr().room.id, mgr().room.ents.size()])
			print("PERFSIZES %s %s" % [role, " ".join(_big_lists({"coop": coop(), "net": Net, "game": Game, "room": mgr().room, "remote": coop().remote, "player": mgr().player}))])
			c0 = c
			f0 = f
		await get_tree().physics_frame
	Controls.script_input = {}
	return [true, "measured"]

func _big_lists(objs: Dictionary) -> Array:
	var out: Array = []
	for name in objs:
		var o = objs[name]
		if o == null or not is_instance_valid(o):
			continue
		for prop in o.get_property_list():
			var v = o.get(prop.name)
			if (v is Array or v is Dictionary) and v.size() > 40:
				out.append("%s.%s=%d" % [name, prop.name, v.size()])
	return out

func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	var parts := f.get_line().get_slice(")", 1).split(" ", false)
	return (float(parts[11]) + float(parts[12])) * 10.0
