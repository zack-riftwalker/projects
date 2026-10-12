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
	# no agent outlives its owner leaving the room (the host simulates every agent)
	for r in mgr.rooms.values():
		for a in r.agents:
			var o = a.owner_p
			if not is_instance_valid(o) or not (o == r.player or o in r.remote_players):
				b["agent_owner"] = [1.0, "an agent in %s whose owner is gone" % r.id]
				break
	# a one-way hatch the guest crossed is open for good: its flag must be set on the host (MV4-01)
	for f in coop.sets_pending:
		if not Game.flag(f) and Net.now() - float(coop.sets_pending[f]) > 2.0:
			b["door-sets"] = [0.0, "the guest crossed a door that sets %s, still not set" % f]
	# the guest's world flags equal the host's (MVB1-01): a guest-only world flag the host never learns, or a list that never arrives
	if rem != null and coop.guest_ready and coop.guest_wh >= 0 and not rem.lagging and Net.is_open and coop.guest_wh != Game.world_digest():
		b["world-digest"] = [5.0, "the guest's world digest %d differs from the host's %d" % [coop.guest_wh, Game.world_digest()]]
	# the honeypot's door: the host has wave:N21, the guest stands against that door and still does not have the flag (MVB2-13)
	if rem != null and Game.flag("wave:N21") and coop._remote_room() != null and coop._remote_room().id == "N21" and coop.guest_wh >= 0 and coop.guest_wh != Game.world_digest() \
			and rem.x > 20.0 * 16.0 - 24.0 and rem.x < 24.0 * 16.0 + 8.0 and rem.y < 5.0 * 16.0:
		b["wave-door"] = [3.0, "wave:N21 is set here, the guest stands at the shut door without it"]
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
	# the guest was never hurt by an attack it did not see: a boss-kit plan turns active only after it was shown in its cue
	for e in mgr.room.ents:
		var kv = e.get("kit_violation")
		if e.puppet and kv != null and kv != "":
			b["boss-cue"] = [0.0, kv]
			break
	# ... and by no arena hazard it had not been looking at for 0.5 s (MVB3-02)
	for e in mgr.room.ents:
		var av = e.get("arena_violation")
		if e.puppet and av != null and av != "":
			b["arena-tell"] = [0.0, av + " s"]
			break
	if _bodies() > 1:
		b["one-host-body"] = [1.0, "%d host bodies" % _bodies()]
	if mgr.rooms.size() > 1:
		b["guest-one-room"] = [2.0, "the guest keeps %d rooms" % mgr.rooms.size()]
	if mgr.player != null and mgr.player.dead:
		b["guest-gets-up"] = [15.0, "dead (downed %s)" % mgr.player.downed]
	# a crumble the host does not list is gone after a second (the guest's own guess expires then)
	if mgr.room.id == coop.last_gf_room:
		for ci in mgr.room.grid.crumble:
			var cc: Dictionary = mgr.room.grid.crumble[ci]
			if not coop.last_cr.has(ci) and not (cc.has("pred") and float(cc.pred) > mgr.room.time):
				b["crumble_state"] = [1.0, "block %d,%d crumbles here but the host does not list it" % [ci % mgr.room.w, ci / mgr.room.w]]
				break
	# the water is where the host says it is (the guest never simulates it)
	if mgr.room.id == coop.last_lq_room and mgr.room.liquid_y != null and coop.last_lq >= 0 and absf(mgr.room.liquid_y - coop.last_lq / 4.0) > 80.0:
		b["liquid-desync"] = [2.0, "water at %.0f, the host says %.0f" % [mgr.room.liquid_y, coop.last_lq / 4.0]]
	# a gate stands open exactly when the host's last snapshot listed its flag (switches and keys are state, not events)
	if mgr.room.id == coop.last_gf_room:
		var gid: String = mgr.room.id
		var want_c: bool = ("gate:%s:catch" % gid) in coop.last_gf
		var want_a: bool = ("gate:%s:agents" % gid) in coop.last_gf
		if mgr.room.grid.gates_open.catch != want_c or mgr.room.grid.gates_open.agents != want_a:
			b["gate_state"] = [1.0, "gates open catch=%s agents=%s, the host says %s/%s" % [mgr.room.grid.gates_open.catch, mgr.room.grid.gates_open.agents, want_c, want_a]]
