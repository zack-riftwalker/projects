class_name Watchdog
extends RefCounted
# Watchdog: things that must never stay true in co-op, checked twice a second on both pages. A rule that stays broken past its
# grace time goes to the debug log as "INVARIANT <rule>: ..." (and to stdout in the tests, where such a line fails the scenario).
# Every kind of bug the co-op had so far has a rule here, so the same kind is seen at once: in a test, or in a real game's log.

var coop
var since := {}                 # rule -> when it started being broken
var told := {}                  # rule -> when it was last reported (once a minute at most)
var acc := 0.0
var count := 0                  # how many reports so far (the tests and the debug overlay read it)

func _init(c) -> void:
	coop = c

func tick(dt: float) -> void:
	acc += dt
	if acc < 0.5:
		return
	acc = 0.0
	if coop.mgr == null or coop.mgr.room == null or coop.main.paused:
		since.clear()                 # (a paused game stands still: no clock runs out)
		return
	var broken := {}                  # rule -> [grace seconds, detail]
	if coop.role == "host":
		_host(broken)
	elif coop.role == "guest" and coop.started:
		_guest(broken)
	var now := Net.now()
	for rule in broken:
		if not since.has(rule):
			since[rule] = now
		elif now - float(since[rule]) >= float(broken[rule][0]) and now - float(told.get(rule, -999.0)) > 60.0:
			told[rule] = now
			count += 1
			var line := "INVARIANT %s: %s" % [rule, broken[rule][1]]
			Game.dlog(line)
			if Game.debug or Game.scenario != "":
				print(line)
			if Game.debug:
				coop.notice_set(line.left(64), 4.0)
	for rule in since.keys():
		if not broken.has(rule):
			since.erase(rule)

func _bodies() -> int:
	return coop.main.world.find_children("*", "RemotePlayer", true, false).size()

func _host(b: Dictionary) -> void:
	var mgr = coop.mgr
	var rem = coop.remote
	# the partner's body: exactly one, in exactly one room's list, and a child of that room (ghosts, lost snapshots: G2, G5)
	var want := 1 if rem != null else 0
	if _bodies() != want:
		b["one-partner-body"] = [1.0, "%d partner bodies, want %d" % [_bodies(), want]]
	if rem != null:
		var holders := 0
		for r in mgr.rooms.values():
			if rem in r.remote_players:
				holders += 1
		var par = rem.get_parent()
		if holders != 1 or not (par is Room) or not (rem in par.remote_players):
			b["partner-in-one-room"] = [1.0, "in %d room lists, parent %s" % [holders, str(par)]]
	# the reliable channel moves (a reset missing on a rejoin, a retransmit that never happens: G1, G14)
	if Net.is_open and not Net.rel_out.is_empty() and Net.now() - float(Net.rel_out[0].get("t0", Net.now())) > 8.0:
		b["reliable-moves"] = [0.0, "oldest unacked event %s is %.0f s old" % [Net.rel_out[0].k, Net.now() - float(Net.rel_out[0].t0)]]
	if coop.guest_here and Net.is_open and not coop.guest_ready:
		b["guest-ready"] = [10.0, "the guest joined but never said ready"]
	if coop.guest_ready and rem != null and coop._remote_room() != null and Net.is_open and Net.now() - coop.last_snap_tx > 2.0:
		b["snapshots-flow"] = [1.0, "no snapshot for %.1f s" % (Net.now() - coop.last_snap_tx)]
	# nobody stays dead (a revive or a respawn that never comes: G4)
	if mgr.player != null and mgr.player.dead:
		b["host-gets-up"] = [15.0, "host dead (downed %s)" % mgr.player.downed]
	if rem != null and rem.dead and not rem.lagging:
		b["guest-gets-up"] = [15.0, "guest dead (countdown %.1f)" % rem.down_t]
	# a room is kept only while somebody is in it (a stale room comes back later with frozen creatures: G6)
	for r in mgr.rooms.values():
		if r != mgr.room and r.remote_players.is_empty():
			b["room-kept:" + r.id] = [2.0, "room %s kept with nobody in it" % r.id]

func _guest(b: Dictionary) -> void:
	var mgr = coop.mgr
	if Net.is_open and not coop.host_lagging and coop.host_present and Net.now() - coop.last_snap_rx > 3.0:
		b["snapshots-arrive"] = [1.0, "no snapshot for %.1f s" % (Net.now() - coop.last_snap_rx)]
	if Controls.locked and coop.host_present and not mgr.trans.on:
		b["controls-free"] = [5.0, "controls locked while the host is here (G3)"]
	var n := 0
	for e in mgr.room.ents:
		if e.puppet:
			n += 1
	if n != coop.puppets.size():
		b["puppets-match"] = [1.0, "%d puppets in the room, %d known (G6)" % [n, coop.puppets.size()]]
	if _bodies() > 1:
		b["one-host-body"] = [1.0, "%d host bodies" % _bodies()]
	if mgr.rooms.size() > 1:
		b["guest-one-room"] = [2.0, "the guest keeps %d rooms" % mgr.rooms.size()]
	if mgr.player != null and mgr.player.dead:
		b["guest-gets-up"] = [15.0, "dead (downed %s)" % mgr.player.downed]
