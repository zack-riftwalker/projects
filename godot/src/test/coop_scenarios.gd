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
	if role == "host":
		await wait_secs(2.0)
		var down := await wait_until(func(): return coop().remote.dead, 10.0)
		var t0 := Time.get_ticks_msec()
		var up := await wait_until(func(): return not coop().remote.dead, 12.0)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		await wait_secs(2.0)
		var p = mgr().player
		p.hp = 0
		p.die()
		var both := await wait_until(func(): return coop().remote.dead and p.dead, 5.0)
		var back := await wait_until(func(): return mgr().player != null and not mgr().player.dead and not coop().remote.dead and mgr().room.id == "R01", 10.0)
		return [down and up and secs > 5.0 and secs < 8.5 and both and back, "guest down %s, back after %.1f s, both down %s, both back on their benches %s" % [down, secs, both, back]]
	await wait_secs(3.0)
	var p2 = mgr().player
	p2.hp = 0
	p2.die()
	var t1 := Time.get_ticks_msec()
	var up2 := await wait_until(func(): return not p2.dead, 12.0)
	var secs2 := (Time.get_ticks_msec() - t1) / 1000.0
	var hp_back: int = p2.hp
	# then both go down
	await wait_secs(2.0)
	p2.hp = 0
	p2.die()
	var back2 := await wait_until(func(): return mgr().player != null and not mgr().player.dead and mgr().room.id == "R01" and mgr().player.hp == mgr().player.max_hp, 10.0)
	return [up2 and secs2 > 5.0 and secs2 < 9.0 and hp_back == 3 and back2, "back after %.1f s with %d hp, after both down: alive in %s hp %d" % [secs2, hp_back, mgr().room.id, mgr().player.hp]]

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
	Net.ws.close(4000, "test")
	Net.connect_as("guest", Game.net_code)          # what a reloaded page does: fresh reliable channel, no token
	coop().started = false
	var again := await wait_until(func(): return coop().started, 8.0)
	var snaps0: int = coop().snaps_applied
	var flow := await wait_until(func(): return coop().snaps_applied > snaps0 + 5, 6.0)
	return [again and flow, "restarted %s, snapshots flowing %s (+%d)" % [again, flow, coop().snaps_applied - snaps0]]

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
