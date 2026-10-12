class_name Coop
extends Node
# Coop: the game side of the two-player mode (docs/PLAN-metroidvania-phase2.md MV2-07, docs/metroidvania/04-coop-design.md).
# Host: owns the world (every room with a player in it is simulated here), checks the guest's announced hits, sends snapshots.
# Guest: owns its body, shows what the host sends, announces what it hits. The transport and the reliable channel are in Net (net.gd).

const SNAP_HZ := 15.0
const ST_HZ := 30.0
const REVIVE_T := 6.0
const FIGHT_STATES := ["none", "intro", "active", "reward", "done"]
const ITEM_KINDS := ["token", "spark", "coffee", "plugin", "page"]

var main
var mgr: RoomManager
var role := ""
var notice := ""
var notice_t := 0.0
var snap_acc := 0.0
var st_acc := 0.0
var verdicts := {}               # debug counters: OK, TOO FAR, ...
var log_lines: Array = []

# ---- host
var remote: RemotePlayer = null
var guest_here := false
var guest_ready := false
var guest_bench := ""
var snap_n := 0
var plan_snaps: Array = []             # host: [nid, plan seq, snapshot number] of the first snapshot that carried each boss-kit plan
var guest_staged := {}                  # host: the rooms the guest walked and nobody has rested since (committed with the next rest, MVB1-03)
var pins_sent := -1                     # host: Game.pins_rev of the last list sent in a snapshot
var guest_wh := -1                      # host: the world digest the guest last reported (MVB1-01)
var wh_sent := -1                       # host: the digest the last snapshot carried
var st_wh_sent := -1                    # guest: the digest its last `st` carried
var st_n := 0
var wf_t := -10.0                       # host: when the last full `wf` went out (at most one per second)
var wf_count := 0                       # host: how many full `wf` lists were sent (the tests count them)
var wf_bytes := 0
var snap_sent := {}
var force_full := false
var both_t := -1.0
var last_snap_tx := 0.0          # host: when the last snapshot went out (the watchdog checks they flow)
var host_present := true         # guest: false between "host left" and the host's return
var watchdog: Watchdog
var dl_acc := 0.0
var host_home_t := -1.0          # host: dead outside a boss fight, back to its bench when this runs out
var guest_home_t := -1.0         # host: the same for the guest
var host_dn := 0
var host_summon := {}
var fight_seen := {}
var phase_seen := {}
var fight_active_seen := {}
var last_gf: Array = []                  # guest: the switch / key / gate flags of the room, as the last snapshot said
var last_gf_room := ""
var last_lq := -1                 # guest: the host's liquid_y x4 for the room of the last snapshot (-1 = dry)
var last_lq_room := ""
var last_cr := {}                       # guest: the crumbling blocks the host listed (tile index -> true)
var abilities_sent := {}                # tool name -> true once the guest was told (boss rewards: bash, catch, ...)

# ---- guest
var started := false
var host_off := 0.0
var puppets := {}
var host_body: RemotePlayer = null
var snap_interval := 0.066
var last_snap_rx := 0.0
var last_snap_n := 0
var guest_summon := {}
var guest_dn := 0
var guest_down_t := -1.0
var host_lagging := false
var line_down := false
var snaps_applied := 0
var zones_seen := {}
var fx_played := 0              # guest: how many of the host's effects and sounds were played (the tests read it)
var fx_q: Array = []             # guest: the host's effects and sounds, each played when the delayed view reaches it [at, entry]

func setup(m) -> void:
	main = m
	mgr = m.manager
	watchdog = Watchdog.new(self)
	role = Game.net_role
	mgr.mode = role
	Net.message.connect(_on_msg)
	Net.reliable.connect(_on_rel)
	Net.peer_changed.connect(_on_peer)
	Net.host_changed.connect(_on_host)
	Net.code_received.connect(func(c): notice_set("code %s" % c, 3.0))
	Net.line_lost.connect(_on_line_lost)
	Net.opened.connect(func(): line_down = false)
	Net.fatal.connect(func(why): notice_set("cannot join (%s)" % why, 6.0))
	mgr.local_died.connect(_on_local_died)
	mgr.room_built.connect(_on_room_built)
	mgr.room_changed.connect(_on_room_changed)
	Game.loadout_changed.connect(func(): if role == "guest" and started: Net.rel("loadout", {"ids": Game.equipped}))
	mgr.commit_extra = func(): return guest_staged.keys()
	Game.world_flag_set.connect(func(k): if role == "guest" and started: Net.rel("wflag", {"k": k}))
	Game.pin_requested.connect(func(op, pn): if role == "guest" and started: Net.rel("pin", {"op": op, "room": pn.room, "x": pn.x, "y": pn.y, "kind": pn.kind}))
	Game.ping_made.connect(func(q): if (role == "host" and guest_here) or (role == "guest" and started): Net.rel("ping", {"id": q.id, "room": q.room, "x": q.x, "y": q.y, "kind": q.kind, "by": q.by}))
	Game.ping_acked.connect(func(id): if (role == "host" and guest_here) or (role == "guest" and started): Net.rel("pingok", {"id": id}))
	mgr.rested.connect(func(id):
		if role == "host":
			guest_staged.clear()                # (the rest just committed them)
		if role == "guest":
			Net.rel("bench", {"room": id})
			Game.save_profile())               # (the guest's tokens and loadout live in its own file)      # the host respawns the guest there after a wipe
	Net.connect_as(role, Game.net_code)

# the two pages must run the same build (a phone can keep an old copy): say so loudly, on both
func _check_build(other: String) -> void:
	log_("builds: mine %s, partner %s" % [Game.build_text, other])
	if other != Game.build_text:
		notice_set("DIFFERENT BUILDS - partner %s - reload both pages" % other.get_slice(" ", 1), 30.0)

func notice_set(text: String, secs: float) -> void:
	notice = text
	notice_t = secs

func log_(s: String) -> void:
	log_lines.append(s)
	Game.dlog(s)
	if Game.debug or Game.scenario != "":
		print("COOP ", s)

func hms() -> float:
	return Net.now()

# ---------------------------------------------------------------- shared per-tick work
func _physics_process(dt: float) -> void:
	if notice_t > 0.0:
		notice_t -= dt
		if notice_t <= 0.0:
			notice = ""
	if role == "host" and not guest_here and Net.code != "" and notice_t <= 0.0:
		notice_set("code %s - waiting for P2" % Net.code, 0.5)
	if main.hud != null:
		main.hud.notice = notice
	if role == "host":
		_host_tick(dt)
	elif role == "guest":
		_guest_tick(dt)
	if watchdog != null:
		watchdog.tick(dt)
	if Game.autotest:
		_autotest(dt)

# ?autotest (web two-tab check, tools/scenarios-mv.js mv-coop): the guest walks right, both prove the link works and print one line
var at_t := 0.0
var at_x0 := -1.0
var at_done := false
func _autotest(dt: float) -> void:
	if at_done or mgr.player == null:
		return
	at_t += dt
	if role == "guest":
		Controls.script_input = {"right": true}
		if at_x0 < 0.0 and snaps_applied > 0:
			at_x0 = mgr.player.x
		if at_x0 >= 0.0 and snaps_applied >= 10 and mgr.player.x > at_x0 + 60.0 and Net.is_open:
			at_done = true
	elif remote != null and remote.get_parent() != null and not remote.samples.is_empty():
		if at_x0 < 0.0:
			at_x0 = remote.x
		elif absf(remote.x - at_x0) > 40.0:
			at_done = true
	if at_done:
		Controls.script_input = null
		print("CLAWD: coop PASS")
	elif at_t > 50.0:
		at_done = true
		print("CLAWD: coop FAIL (%s, x0 %.0f, snaps %d)" % [role, at_x0, snaps_applied])

# ---------------------------------------------------------------- rooms: signals of every room we build
func _on_room_built(r: Room) -> void:
	if role == "host":
		r.tile_broken.connect(func(tx, ty): _host_tile(r, tx, ty))
		r.item_collected.connect(func(id, kind): _host_item(r, id, kind))
		r.fight_intro.connect(func(): _host_fight_intro(r))
		r.plugin_got.connect(func(pid, by): if guest_here: Net.rel("plugin", {"id": pid, "by": by}))
	elif role == "guest":
		r.net_hit.connect(func(nid, how, dmg, dx, dy, atk): Net.rel("hit", {"eid": nid, "how": how, "dmg": dmg, "dx": dx, "dy": dy, "atk": atk,
			"px": roundi(mgr.player.x) if mgr.player != null else 0, "py": roundi(mgr.player.y) if mgr.player != null else 0}))
		r.net_hurt.connect(func(d):
			Net.rel("hurt", {"d": d})
			if _laggy() and mgr.player != null:
				mgr.player.inv += 0.4)          # a bad line: a little more mercy after each hit (as the JS game)
		r.net_projhit.connect(func(pid): Net.rel("projhit", {"pid": pid}))
		r.net_catch.connect(func(pid): Net.rel("catch", {"pid": pid}))
		r.net_agents.connect(func(): Net.rel("agents", {}))
		r.net_buy.connect(func(pid): Net.rel("buy", {"id": pid}))
		r.net_buymap.connect(func(zid): Net.rel("buymap", {"zone": zid}))
		r.net_freejar.connect(func(ji): Net.rel("freejar", {"room": r.id, "jar": ji, "px": roundi(mgr.player.x) if mgr.player != null else 0, "py": roundi(mgr.player.y) if mgr.player != null else 0}))
		r.net_crumble.connect(func(tx, ty): Net.rel("crumble", {"tx": tx, "ty": ty, "px": roundi(mgr.player.x) if mgr.player != null else 0, "py": roundi(mgr.player.y) if mgr.player != null else 0}))
		r.net_parry.connect(func(nid, sid): Net.rel("parry", {"nid": nid, "sid": sid}))
		r.net_pickup.connect(func(id): Net.rel("pickup", {"room": r.id, "id": id}))
		r.net_crack.connect(func(tx, ty): Net.rel("crack", {"room": r.id, "tx": tx, "ty": ty}))
		r.net_reveal.connect(func(): Net.rel("reveal", {"room": r.id}))
		r.net_lqhit.connect(func(): Net.rel("lqhit", {"room": r.id}))

func _on_room_changed(r: Room) -> void:
	if role == "guest":
		puppets.clear()
		fx_q.clear()                   # (effects of the room just left must not play in the new one)
		host_body = null
		zones_seen.clear()
		if started:
			Net.rel("room", {"to": r.id, "door": mgr.last_door_id})

const FX_NAMES := ["burst", "ring", "spark", "pop", "explode", "dust", "shake", "flash_screen"]
const ECHO := ["hit", "clang", "squish", "bossHit", "token"]     # this screen already played them for its own actions

# the host's effects and sounds (fx_out on the host), at the moment the delayed view shows what caused them. The host player's
# shakes and flashes stay on the host's screen; the sounds the host player makes are quieter the farther away it is.
func _play_fx(r: Room, p) -> void:
	var now := hms()
	while not fx_q.is_empty() and float(fx_q[0][0]) <= now:
		var e: Array = fx_q.pop_front()[1]
		if e.is_empty():
			continue
		var cause := String(e[e.size() - 1])
		var what := String(e[0])
		if what == "S":
			if cause == "p2" and String(e[1]) in ECHO:
				continue
			var vol: float = float(e[2])
			if cause == "p1" and host_body != null and p != null:
				vol *= clampf(1.0 - Vector2(p.x - host_body.x, p.y - host_body.y).length() / 320.0, 0.25, 1.0)
			Audio.sfx(String(e[1]), {"vol": vol})
			fx_played += 1
		elif what in FX_NAMES:
			if (what == "shake" or what == "flash_screen") and cause == "p1":
				continue
			r.callv(what, e.slice(1, e.size() - 1))
			fx_played += 1

# a bad line: a round trip over 250 ms, a jumpy line or a host that went quiet
func _laggy() -> bool:
	return Net.rtt > 0.25 or Net.jitter > 0.08 or host_lagging

# this player has the map overlay open (the partner sees an icon over its head)
func _map_open() -> bool:
	return main.map_overlay != null and main.map_overlay.active

func _on_local_died(r: Room) -> void:
	if role == "host":
		_host_died()
	elif role == "guest":
		_guest_died()

# ================================================================ HOST
func _host_tick(dt: float) -> void:
	for r in mgr.rooms.values():
		_host_watch_room(r)
	_hud(mgr.player)
	var prm := _remote_room()
	Game.partner = {"room": prm.id, "x": remote.x, "y": remote.y} if (guest_here and remote != null and prm != null) else {}
	if not guest_here or remote == null:
		_host_down_logic(dt)
		return
	remote.follow(hms())
	remote.dash_t = maxf(0.0, remote.dash_t - dt)
	remote.atk_t = maxf(0.0, remote.atk_t - dt)
	if remote.inv > 0.0:
		remote.inv -= dt
	_host_down_logic(dt)
	_host_summon_logic(dt)
	snap_acc += dt
	var hz := SNAP_HZ if (Net.rtt < 0.2 and Net.jitter < 0.04) else 10.0
	if guest_ready and (snap_acc >= 1.0 / hz or force_full):
		snap_acc = 0.0
		force_full = false
		_send_snapshot()

# state changes of a room we tell the guest about (fight state, phase, doors) and the world (abilities)
func _host_watch_room(r: Room) -> void:
	if not guest_here:
		return
	var st: String = r.fight.state
	if fight_seen.get(r.id, "none") != st:
		fight_seen[r.id] = st
		Net.rel("boss", {"room": r.id, "ev": st})
	if r.boss != null and r.boss.phase != phase_seen.get(r.id, 1):
		phase_seen[r.id] = r.boss.phase
		Net.rel("boss", {"room": r.id, "ev": "phase"})
	if r.fight_active != fight_active_seen.get(r.id, false):
		fight_active_seen[r.id] = r.fight_active
		Net.rel("door", {"room": r.id, "id": "fight", "closed": r.fight_active})
	for tname in Game.tools:
		if Game.tools[tname] and not abilities_sent.has(tname):
			abilities_sent[tname] = true
			Net.rel("ability", {"name": tname})
			for fk in Game.flags:                 # the boss flags that came with it (door locks read them)
				if String(fk).begins_with("boss:"):
					Net.rel("flag", {"k": fk, "v": true})

func _host_tile(r: Room, tx: int, ty: int) -> void:
	if guest_here:
		Net.rel("tile", {"room": r.id, "tx": tx, "ty": ty})

func _host_item(r: Room, id: String, kind: String) -> void:
	if guest_here and not id.begins_with("L"):
		Net.rel("pick", {"room": r.id, "id": id, "by": "p1", "kind": kind})

func _remote_room() -> Room:
	if remote == null:
		return null
	var p := remote.get_parent()
	return p if p is Room else null

func _on_peer(on: bool, lag: bool, resume: bool) -> void:
	if role != "host":
		return
	if on and resume:
		if remote != null:
			remote.lagging = false
		force_full = true
		notice_set("P2 is back", 2.0)
		log_("host: guest resumed")
		return
	if lag:
		if remote != null:
			remote.lagging = true
		notice_set("P2 lagging", 3.0)
		return
	if on:
		_guest_joined()
	else:
		_guest_left()

func _guest_joined() -> void:
	if remote != null:                   # a new join while the old partner is still here (reload within the grace time): no ghost
		_guest_left()
	log_("host: guest joined")
	Net.reset_reliable()
	guest_here = true
	guest_ready = false
	Net.epoch += 1
	snap_n = 0
	guest_wh = -1
	pins_sent = -1
	wf_t = -10.0
	plan_snaps.clear()
	snap_sent.clear()
	fight_seen.clear()
	phase_seen.clear()
	fight_active_seen.clear()
	abilities_sent = {}
	var hr: Room = mgr.room
	var arena_door = null
	var place_room: Room = hr
	if hr != null and hr.fight_active:
		# a friend who joins during a fight is summoned into the arena the same way (boss hp does not change)
		for d in hr.grid.doors:
			if d.lock == "fight":
				arena_door = d
		var prev_id := String(arena_door.to).get_slice(":", 0)
		place_room = mgr.ensure_room(prev_id)
	remote = RemotePlayer.new(place_room)
	remote.name = "Partner"
	var pp = mgr.player
	var sp0 = null if place_room == hr else Game.bench_spawn(place_room.id)       # (only R01 has a start_pos: other rooms use their bench or the floor)
	var px: float = pp.x + 14.0 if place_room == hr else (sp0.x if sp0 != null else 24.0)
	var py: float = pp.y if place_room == hr else (sp0.y if sp0 != null else _floor_y(place_room, 24.0, 5))
	remote.x = px
	remote.y = py
	remote.hp = Game.max_hp
	remote.max_hp = Game.max_hp
	place_room.remote_players.append(remote)
	place_room.add_child(remote)
	guest_staged[place_room.id] = true
	var you := {"room": place_room.id, "x4": NetClasses.x4(px), "y4": NetClasses.x4(py), "hp": Game.max_hp, "max_hp": Game.max_hp}
	Net.send_msg("start", {"save": {"tools": Game.tools, "flags": Game.flags, "diff": Game.diff, "coop_hp_pct": Game.coop_hp_pct, "fragments": Game.fragments}, "you": you, "tm": hms(), "build": Game.build_text})
	if arena_door != null:
		Net.rel("summon", {"room": hr.id, "warn": 3.0})
		notice_set("P2 is joining the fight", 3.0)

func _guest_left() -> void:
	log_("host: guest left")
	Game.partner = {}
	guest_here = false
	guest_ready = false
	if remote != null:
		var r := _remote_room()
		if r != null:
			r.remote_players.erase(remote)
		remote.queue_free()
		if r != null:
			mgr.release_if_empty(r)
	remote = null
	both_t = -1.0

# ---------------------------------------------------------------- host: messages
func _on_msg(t: String, m: Dictionary) -> void:
	if role == "host":
		_host_msg(t, m)
	elif role == "guest":
		_guest_msg(t, m)

func _host_msg(t: String, m: Dictionary) -> void:
	if t == "dl":                       # the guest's log lines (and its script errors) join this log
		for line in m.get("v", []):
			Game.dlog("P2> " + String(line).left(300))
			if String(line).begins_with("ERROR"):
				notice_set("P2 " + String(line).left(60), 6.0)
		return
	if t != "st" or remote == null or int(m.get("e", -1)) != Net.epoch:
		return
	if m.has("wh"):
		guest_wh = int(m.wh)
	var r := _remote_room()
	if r == null or String(m.get("room", "")) != r.id:
		return
	remote.report(m.x4 / 4.0, m.y4 / 4.0, float(m.vx), float(m.vy), float(m.face), hms())
	remote.hp = int(m.hp)
	if m.has("maxhp"):
		remote.max_hp = int(m.maxhp)
	var was_dead := remote.dead
	remote.dead = bool(m.dead) and remote.dead or (bool(m.dead) and remote.dn != int(m.dn))
	remote.dn = int(m.dn)
	var atk: Array = m.atk
	remote.atk_id = int(atk[0])
	remote.atk_dir = String(atk[1])
	remote.atk_face = float(m.face)
	remote.atk_t = 0.17 if bool(atk[2]) else 0.0
	var dash: Array = m.dash
	if int(dash[0]) != remote.dash_id:
		remote.dash_id = int(dash[0])
		remote.dash_seen = r.time
	remote.dash_dx = dash[1] / 100.0
	remote.dash_dy = dash[2] / 100.0
	remote.dash_t = dash[3] / 100.0
	remote.inv = float(m.get("inv", 0.0))
	remote.focusing = int(m.get("fo", 0)) == 1
	remote.mapping = int(m.get("mn", 0)) == 1
	remote.cz = int(m.get("cz", -1))
	remote.ss = int(m.get("ss", 0)) == 1
	var sa := int(m.get("sa", 0))
	if not plan_snaps.is_empty():                  # the guest applied snapshot `sa`: every boss-kit plan those snapshots carried has been seen
		var keep: Array = []
		for ps in plan_snaps:
			if int(ps[2]) <= sa:
				for e in r.ents:
					if e.nid == int(ps[0]) and e.get("plan") != null:
						e.plan_seen(int(ps[1]))
						break
			elif int(ps[2]) > sa - 300:
				keep.append(ps)
		plan_snaps = keep
	if snap_sent.has(sa):
		var rtt: float = hms() - float(snap_sent[sa])
		Net.jitter = lerpf(Net.jitter, absf(rtt - Net.rtt), 0.1)
		Net.rtt = lerpf(Net.rtt, rtt, 0.1)
		snap_sent.erase(sa)
	if remote.dead and not was_dead:      # seen only in the report (the `die` event is late or lost): the revive countdown starts now
		_guest_fell()
	if was_dead and not remote.dead:
		log_("host: guest got up")

func _on_rel(k: String, d: Dictionary) -> void:
	if role == "host":
		_host_rel(k, d)
	elif role == "guest":
		_guest_rel(k, d)

func _host_rel(k: String, d: Dictionary) -> void:
	if remote == null:
		return
	match k:
		"ready":
			guest_ready = true
			force_full = true
			_check_build(String(d.get("build", "?")))
		"hit": _host_hit(d)
		"projhit":
			var r := _remote_room()
			if r != null:
				for q in r.projs:
					if int(q.id) == int(d.pid):
						q.dead = true
		"loadout":
			var ids: Array = Game.filter_loadout(d.get("ids", []))
			remote.loadout = ids
			log_("host: guest loadout %s" % str(ids))
		"buy":                                   # the guest wants a plugin from the stall: the first buyer gets it, a second one pays nothing
			var pid := String(d.id)
			var br := _remote_room()
			var by := ""
			if Game.plugin_def(pid).size() > 0 and int(Game.plugin_def(pid).price) > 0 and not Game.owns_plugin(pid):
				Game.flags["plugin:" + pid] = true
				Game.write_save()
				by = "p2"
				if br != null:
					_as_p2(br, func(): br.show_plugin_banner(pid))
			Net.rel("plugin", {"id": pid, "by": by})
		"freejar": _host_freejar(d)
		"pin": Game.apply_pin_request(String(d.op), d)
		"ping": Game.ping_receive(d)
		"pingok": Game.ping_ack_received(String(d.id))
		"wflag":                                 # a world flag only the guest's page could set (a sign it read, a changelog line it was shown)
			var wk := String(d.k)
			if wk.begins_with("changelog:") or wk.begins_with("log:"):
				if not Game.flag(wk):
					Game.flags[wk] = true
					Game.write_save()
		"buymap":                                # the guest buys a zone's index: the first buyer pays, the answer says who it was
			var zid := String(d.zone)
			var by := ""
			if Game.zone_def(zid).size() > 0 and not Game.owns_map(zid):
				Game.flags["map:" + zid] = true
				Game.write_save()
				by = "p2"
			Net.rel("mapbought", {"zone": zid, "by": by})
		"agents":                                # the guest spent a full meter (its own check): its two agents, replacing any it still has here
			var ar := _remote_room()
			if ar != null:
				ar.agents = ar.agents.filter(func(a): return a.owner_p != remote)
				ar.cast_agents(remote)
				log_("host: guest agents cast in %s" % ar.id)
		"crumble": _host_crumble(d)
		"catch": _host_catch(d)
		"parry": _host_parry(d)
		"hurt":
			var r2 := _remote_room()
			if r2 != null:
				r2.on_player_hurt(remote, int(d.d))
		"die": _guest_down()
		"room":
			_host_door_sets(String(d.get("door", "")))
			_host_remote_to_room(String(d.to))
		"crack": _host_crack(d)
		"lqhit":
			var lr := _remote_room()
			if lr != null and lr.id == String(d.room) and lr.rise_on and lr.liquid_y != null and Net.now() - lr.lq_last > 0.5:
				lr.lq_last = Net.now()
				lr.liquid_y += 72.0
		"reveal":
			var rid2 := String(d.room)
			Game.flags["dead:" + rid2] = true
			Game.write_save()
			if mgr.rooms.has(rid2):
				mgr.rooms[rid2].reveal_dead(false)
		"pickup": _host_pickup(d)
		"bench":
			guest_bench = String(d.room)
			Game.flags["bench:" + guest_bench] = true
			var cn := Game.commit_rooms(Game.staged_rooms() + guest_staged.keys())      # either player's rest commits both lists
			guest_staged.clear()
			if cn > 0:
				Net.rel("committed", {"n": cn})
			var br := _remote_room()
			if br != null and br.id == guest_bench:
				for c in br.cps:
					c.on = true
			Game.write_save()
		"summon_ok": pass
		"pause": main.set_paused(bool(d.on), true)

# the partner's line on the HUD (as the JS game): its hit points, a line-quality dot, and the state of a downed body
func _hud(p) -> void:
	var h = main.hud
	if h == null:
		return
	var q = remote if role == "host" else host_body
	if q == null:
		h.partner_hp = -1
		h.me_text = ""
		return
	h.partner_hp = q.hp
	h.partner_max = q.max_hp
	var lag: bool = q.lagging if role == "host" else host_lagging
	h.partner_dot = "#8d8798" if (lag or not Net.is_open) else ("#7fe08a" if Net.rtt < 0.12 and Net.jitter < 0.04 else ("#ffd27a" if Net.rtt < 0.25 else "#ff6b6b"))
	h.partner_text = ""
	if q.dead:
		h.partner_text = ("back in %d" % ceili(q.down_t)) if role == "host" and q.down_t > 0.0 else "down"
	h.me_text = ""
	if p != null and p.dead:
		if q.dead:
			h.me_text = "BOTH DOWN"
		elif p.downed and p.down_t > 0.0:
			h.me_text = "DOWN - BACK IN %d" % ceili(p.down_t)
		elif p.downed:
			h.me_text = "DOWN - REVIVING..."

# a `sets` door the guest crossed sets its flag here too (state: the watchdog checks it is set 2 s later)
var sets_pending := {}                    # flag -> when the guest crossed
func _host_door_sets(door_id: String) -> void:
	if door_id == "":
		return
	var rid := door_id.get_slice(":", 0)
	if not Game.rooms_meta.rooms.has(rid):
		return
	for d in Game.rooms_meta.rooms[rid].doors:
		if d.id == door_id and String(d.get("sets", "")) != "":
			Game.flags[String(d.sets)] = true
			sets_pending[String(d.sets)] = Net.now()
			Game.write_save()

func _host_remote_to_room(to_id: String) -> void:
	var old := _remote_room()
	if old != null and old.id == to_id:
		return
	var target: Room = mgr.ensure_room(to_id)
	if old != null:
		old.remote_players.erase(remote)
		old.fx_out.clear()              # (effects nobody will see; they must not play if the guest comes back)
		remote.get_parent().remove_child(remote)
	target.remote_players.append(remote)
	remote.room = target
	target.add_child(remote)
	remote.samples.clear()
	guest_staged[to_id] = true
	log_("host: guest moved to %s" % to_id)
	if old != null:
		mgr.release_if_empty(old)

# ---- the hit check (port of hostHit + recordHist in the JS game)
func _host_hit(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null:
		return
	var nid := int(d.eid)
	var e = null
	for q in r.ents:
		if q.nid == nid:
			e = q
	var verdict := "OK"
	if e == null:
		verdict = "NO SUCH CREATURE"
	elif e.dead:
		verdict = "DEAD"
	else:
		var how := String(d.how)
		var key := "p2" + how
		if int(e.marks.get(key, -1)) == int(d.atk):
			verdict = "ALREADY"
		else:
			# Lag compensation, as in the JS game: P2 hit the creature where ITS screen showed it, a round trip and the smoothing delay
			# ago. So the distance is measured from where P2 says it stood, where this page sees it and where its recent reports put
			# it, to where the creature was at any moment of the last second; the limit grows with speed and ping.
			var pts: Array = [Vector2(remote.x + 5, remote.y + 5)]
			if d.has("px"):
				var gp := Vector2(float(d.px) + 5.0, float(d.py) + 5.0)
				if absf(gp.x - remote.x - 5.0) + absf(gp.y - remote.y - 5.0) < 240.0:
					pts.append(gp)
			for smp in remote.samples:
				if hms() - float(smp[0]) <= Net.rtt / 2.0 + 0.35:
					pts.append(Vector2(smp[1] + 5.0, smp[2] + 5.0))
			var bd := 1e9
			var boxes_all: Array = e.hurtboxes().duplicate()
			for rec in r.hist.get(nid, []):
				boxes_all.append_array(rec[1])
			for bx in boxes_all:
				for pt in pts:
					var ddx: float = maxf(maxf(bx.x - pt.x, 0.0), pt.x - (bx.x + bx.w))
					var ddy: float = maxf(maxf(bx.y - pt.y, 0.0), pt.y - (bx.y + bx.h))
					bd = minf(bd, sqrt(ddx * ddx + ddy * ddy))
			var lim: float = 64.0 + (absf(e.vx) + absf(e.vy) + absf(remote.vx)) * (0.3 + Net.rtt) + 120.0 * Net.rtt
			var near: bool = bd <= lim
			if how == "stomp" and not e.stompable:
				near = false
			if not near:
				verdict = "TOO FAR"
			else:
				e.marks[key] = int(d.atk)
				# the most a claw may do: opus doubles it, a rubber duck doubles it again at the guest's last hit point
				var allowed: int = (2 if Game.tools.get("opus", false) else 1) * Game.mod_claw_mult(remote.hp, remote.loadout)
				var dmg := clampi(int(d.dmg), 1, allowed) if how == "swipe" else (1 if how == "dash" else maxi(1, e.hp))
				r.attacker = remote
				var boxes: Array = e.hurtboxes()
				var pick = boxes[0] if boxes.size() > 0 else e
				var pd := 1e9
				for bx2 in boxes:                           # (a creature with several hurtboxes, like MERGE CONFLICT's heads: the one nearest to P2)
					var bdx: float = clampf(remote.x + 5.0, bx2.x, bx2.x + bx2.w) - remote.x - 5.0
					var bdy: float = clampf(remote.y + 5.0, bx2.y, bx2.y + bx2.h) - remote.y - 5.0
					if bdx * bdx + bdy * bdy < pd:
						pd = bdx * bdx + bdy * bdy
						pick = bx2
				_as_p2(r, func(): e.hit(dmg, float(d.dx), float(d.dy), how, pick))
	verdicts[verdict] = int(verdicts.get(verdict, 0)) + 1
	if verdict != "OK":
		log_("P2 %s eid %d: %s" % [String(d.how), nid, verdict])
	if Game.debug:
		print("P2 hit %s eid %d" % [verdict, nid])

# the guest swiped a catchable projectile it saw: reverse the real one if it still exists (the guest predicted the same)
func _host_catch(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null:
		return
	for q in r.projs:
		if int(q.id) == int(d.pid) and not q.dead and q.get("catchable", false) and not q.get("friendly", false):
			_as_p2(r, func(): r.catch_proj(q, remote))
			return
	log_("P2 catch pid %d: no such catchable projectile" % int(d.pid))

# the guest parried a strike of creature nid: accepted if that strike was active within the last rtt/2 + 0.35 s
func _host_parry(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null:
		return
	for e in r.ents:
		if e.nid == int(d.nid) and not e.dead:
			var sid := int(d.sid)
			if r.time - float(e.strike_seen.get(sid, -99.0)) <= Net.rtt / 2.0 + 0.35:
				r.attacker = remote
				_as_p2(r, func(): e.parried(remote, sid))
			else:
				log_("P2 parry nid %d sid %d: that strike was not active" % [int(d.nid), sid])
			return

# the guest's swipe or dash met a lost agent's jar: accepted when its recent reports put it next to the jar (the same lenient check as the other hits)
func _host_freejar(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null or r.id != String(d.room) or r.jars.is_empty() or Game.flag("agent:" + r.id):
		return
	var j: Dictionary = r.jars[clampi(int(d.jar), 0, r.jars.size() - 1)]
	var c := Vector2(float(j.x), float(j.y) - 8.0)
	var pts: Array = [Vector2(remote.x + 5.0, remote.y + 5.0)]
	if d.has("px") and absf(float(d.px) - remote.x) + absf(float(d.py) - remote.y) < 240.0:
		pts.append(Vector2(float(d.px) + 5.0, float(d.py) + 5.0))
	for smp in remote.samples:
		if hms() - float(smp[0]) <= Net.rtt / 2.0 + 0.35:
			pts.append(Vector2(smp[1] + 5.0, smp[2] + 5.0))
	for pt in pts:
		if pt.distance_to(c) <= 48.0 + 120.0 * Net.rtt:
			r.free_jar(int(d.jar))
			Net.rel("flag", {"k": "agent:" + r.id, "v": true})
			log_("host: guest freed the agent of %s" % r.id)
			return
	log_("P2 freejar in %s refused (too far)" % r.id)

# the guest's body stepped on a crumbling block: start it here if the guest's recent reports really put it on that block
func _host_crumble(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null:
		return
	var tx := int(d.tx)
	var ty := int(d.ty)
	var i := ty * r.w + tx
	if r.grid.tile(tx, ty) != TileGrid.CRUMBLE or r.grid.crumble.has(i):
		return
	var pts: Array = [[remote.x, remote.y]]
	if d.has("px") and absf(float(d.px) - remote.x) + absf(float(d.py) - remote.y) < 240.0:
		pts.append([float(d.px), float(d.py)])               # where the guest says it stood (its reports may be a moment behind)
	for smp in remote.samples:
		if hms() - float(smp[0]) <= Net.rtt / 2.0 + 0.35:
			pts.append([smp[1], smp[2]])
	for pt in pts:
		if pt[0] + 10.0 > tx * 16 and pt[0] < tx * 16 + 16 and absf(pt[1] + 10.0 - ty * 16) <= 8.0:
			r.grid.crumble[i] = {"s": 1, "t": 0.42}
			return
	log_("P2 crumble %d,%d refused (not standing on it)" % [tx, ty])

func _host_crack(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null or r.id != String(d.room):
		return
	var tx := int(d.tx)
	var ty := int(d.ty)
	if r.grid.tile(tx, ty) != TileGrid.CRACK:
		return
	if r.time - remote.dash_seen > 0.3:
		return
	if Vector2(tx * 16 + 8, ty * 16 + 8).distance_to(Vector2(remote.x + 5, remote.y + 5)) > 32.0 + 24.0:
		return
	_as_p2(r, func(): r.break_tile(tx, ty))

# what the guest did, applied on this PC: its effects carry p2 (the guest showed its own already) and its sounds belong to its room
func _as_p2(r: Room, f: Callable) -> void:
	var c0 := r.ctx
	var a0 = Audio.room_ctx
	r.ctx = "p2"
	Audio.room_ctx = r
	f.call()
	r.ctx = c0
	Audio.room_ctx = a0

func _host_pickup(d: Dictionary) -> void:
	var r := _remote_room()
	if r == null or r.id != String(d.room):
		return
	for it in r.items:
		if it.get("dead", false) or String(it.id) != String(d.id):
			continue
		# the body seen here is late (running or jumping it can be 30 px behind): its recent reports count too
		var reach: float = 28.0 * Game.mod_pickup_radius(remote.loadout)      # (cache: its pickup radius is 2.5 times larger)
		var near := absf(remote.x + 5 - it.x) <= reach and absf(remote.y + 5 - it.y) <= reach
		for smp in remote.samples:
			if hms() - float(smp[0]) <= Net.rtt / 2.0 + 0.35 and absf(smp[1] + 5 - it.x) <= reach and absf(smp[2] + 5 - it.y) <= reach:
				near = true
		if not near:
			log_("host: P2 pickup %s refused (too far)" % it.id)
			return
		it.dead = true
		if not String(it.id).begins_with("L"):
			r.got[it.id] = true
			Game.flags[it.id] = true
		_as_p2(r, func(): r.spark(it.x, it.y, Game.COL.goldHi, 4))
		if it.kind == "plugin":
			_as_p2(r, func(): r.plugin_collected(String(it.id).trim_prefix("plugin:"), "p2"))
		if it.kind == "spark":
			Game.fragments += 1
			if Game.fragments % 4 == 0 and mgr.player != null:
				mgr.player.max_hp = Game.max_hp
				mgr.player.hp = mgr.player.max_hp
			Game.write_save()
		if it.kind == "coffee" and Game.diff == "easy" and remote.hp < remote.max_hp:      # (coffee only heals on easy, as in Room.collect)
			Net.rel("heal", {"n": 1})
		Net.rel("pick", {"room": r.id, "id": it.id, "by": "p2", "kind": it.kind})
		return

# ---- down, revive, both down
func _host_died() -> void:
	var hp_ = mgr.player
	if not guest_here or remote == null:
		mgr.respawn(true)
		return
	if not mgr.room.fight_active:       # the revive is a boss-fight rule: elsewhere a death sends you back to your bench, as alone
		host_home_t = 1.2
		log_("host: down outside a fight, back to the bench")
		return
	hp_.downed = true
	hp_.down_t = REVIVE_T
	host_dn += 1
	log_("host: host is down")

func _guest_down() -> void:
	if remote == null:
		return
	remote.dead = true
	remote.dn += 1
	_guest_fell()

# a guest death (event or report): a boss fight starts the revive countdown, anywhere else the guest goes back to its bench
func _guest_fell() -> void:
	var gr := _remote_room()
	if gr != null and gr.fight_active:
		remote.down_t = REVIVE_T
		log_("host: guest is down")
	else:
		remote.down_t = -1.0
		if guest_home_t < 0.0:
			guest_home_t = 1.2
		log_("host: guest died outside a fight, back to its bench")

func _host_down_logic(dt: float) -> void:
	var hp_ = mgr.player
	if hp_ == null:
		return
	var guest_alive := guest_here and remote != null and not remote.dead and not remote.lagging
	if host_home_t >= 0.0:
		host_home_t -= dt
		if host_home_t < 0.0:
			hp_.downed = false
			mgr.respawn(true)
			return
	if guest_home_t >= 0.0:
		guest_home_t -= dt
		if guest_home_t < 0.0 and guest_here and remote != null and remote.dead:
			_send_guest_home()
	var host_down: bool = hp_.dead and hp_.downed
	var guest_down_: bool = guest_here and remote != null and remote.dead and guest_home_t < 0.0
	if host_down and not guest_here:     # nobody left to bring the host back: same as dying alone
		hp_.downed = false
		mgr.respawn(true)
		return
	if host_down and guest_down_:
		if both_t < 0.0:
			both_t = 1.2
		both_t -= dt
		if both_t <= 0.0:
			_respawn_both()
		return
	both_t = -1.0
	if host_down and guest_alive:
		hp_.down_t -= dt
		if hp_.down_t <= 0.0:
			_revive_host()
	if guest_down_ and not host_down and not hp_.dead:
		remote.down_t -= dt
		if remote.down_t <= 0.0:
			_revive_guest()

func _revive_host() -> void:
	var p = mgr.player
	p.dead = false
	p.downed = false
	p.down_t = -1.0
	p.hp = 3
	p.inv = 1.5
	p.vx = 0.0
	p.vy = 0.0
	if remote == null or _remote_room() != mgr.room or remote.dead:
		p.x = p.safe.x
		p.y = p.safe.y
	else:                               # next to the partner, as in the JS game (not under the boss where it fell)
		p.x = remote.x
		p.y = remote.y - 2.0
	mgr.room.ring(p.x + 5, p.y + 5, 2, 18, Game.COL.clawdHi, 0.3)
	log_("host: host got up")

func _revive_guest() -> void:
	var same := _remote_room() == mgr.room
	remote.dead = false
	remote.down_t = -1.0
	var hp_ = mgr.player                 # next to the host, as in the JS game
	var rx: float = hp_.x if same else remote.x
	var ry: float = hp_.y - 2.0 if same else remote.y
	remote.x = rx
	remote.y = ry
	remote.samples.clear()
	Net.rel("revive", {"x4": NetClasses.x4(rx), "y4": NetClasses.x4(ry), "hp": 3, "same": same})
	log_("host: guest revive sent")

# also the host's "Restart room" (count_death false): the guest owns its body, so it is moved by the same event, not left behind
func _respawn_both(count_death := true) -> void:
	both_t = -1.0
	log_("host: both down, respawning" if count_death else "host: restart, the guest comes too")
	_send_guest_home()
	mgr.player.downed = false
	mgr.respawn(count_death)

# the guest back to its own bench (or the start), full hp
func _send_guest_home() -> void:
	guest_home_t = -1.0
	var rid := guest_bench if guest_bench != "" else String(Game.rooms_meta.start.room)
	var pos: Array = Game.rooms_meta.rooms[rid].get("start_pos", [24, 100])
	var sp = Game.bench_spawn(rid) if guest_bench != "" else null
	var gx: float = sp.x if sp != null else float(pos[0])
	var gy: float = sp.y if sp != null else float(pos[1])
	_host_remote_to_room(rid)
	remote.dead = false
	remote.down_t = -1.0
	remote.x = gx
	remote.y = gy
	remote.samples.clear()
	Net.rel("respawn", {"room": rid, "x4": NetClasses.x4(gx), "y4": NetClasses.x4(gy)})
	log_("host: guest sent to %s" % rid)

func restart_both() -> bool:
	if role != "host" or not guest_here or remote == null or mgr.player == null:
		return false
	_respawn_both(false)
	return true

# ---- the boss summon: the one who is not in the arena is brought in after a 3 s warning
func _host_fight_intro(r: Room) -> void:
	_check_summon(r, true)

func _check_summon(r: Room, announce := false) -> void:
	if not guest_here or remote == null:
		r.summon_ok = true
		return
	var host_in: bool = r == mgr.room
	var guest_in: bool = _remote_room() == r
	if host_in and guest_in:
		r.summon_ok = true
		return
	r.summon_ok = false
	if announce:
		if not guest_in:
			Net.rel("summon", {"room": r.id, "warn": 3.0})
			log_("host: summon sent for %s" % r.id)
		if not host_in:
			host_summon = {"room": r.id, "t": 3.0}
			Audio.sfx("warn")
			mgr.player.frozen = true
			mgr.player.inv = maxf(mgr.player.inv, 5.0)

func _host_summon_logic(dt: float) -> void:
	for r in mgr.rooms.values():
		if r.fight.state == "intro":
			var host_in: bool = r == mgr.room
			var guest_in: bool = _remote_room() == r
			if host_in and guest_in:
				r.summon_ok = true
	if host_summon.is_empty():
		return
	var rid := _summon_step(host_summon, dt)
	if rid != "":
		host_summon = {}
		mgr.room.summon_ok = _remote_room() == mgr.room

# the boss summon, shared by both sides: count down, then the partner who was outside walks into the arena. Returns its room id once arrived.
func _summon_step(sm: Dictionary, dt: float) -> String:
	var p = mgr.player
	sm.t -= dt
	notice_set("Partner fights NULL — joining in %d..." % maxi(1, ceili(sm.t)), 1.0)
	if not (sm.t <= -1.0 or (sm.t <= 0.0 and p.on_ground)):
		return ""
	p.frozen = false
	p.inv = 1.5
	mgr.swap_to(sm.room, Vector2(24.0, 100.0))
	p.y = _floor_y(mgr.room, 24.0, 5)
	p.x = 24.0
	p.vx = 0.0
	p.vy = 0.0
	p.on_ground = true
	return sm.room

func _floor_y(r: Room, x: float, from_row: int) -> float:
	var tx := floori((x + 5.0) / 16.0)
	for ty in range(from_row, r.h):
		if r.grid.solid(tx, ty):
			return ty * 16.0 - 10.0
	return r.ph - 26.0

# ---------------------------------------------------------------- host: snapshots
func _send_snapshot() -> void:
	var r := _remote_room()
	if r == null:
		return
	snap_n += 1
	last_snap_tx = hms()
	var en: Array = []
	for e in r.ents:
		if e.dead and not (e.get("is_boss") and e.dying):
			continue
		en.append(NetClasses.record(e))
		if e.get("plan") != null and not e.plan.is_empty() and int(e.plan.seq) > e.plan_snap_seq:
			e.plan_snap_seq = int(e.plan.seq)
			plan_snaps.append([e.nid, int(e.plan.seq), snap_n])
	var it: Array = []
	for i in r.items:
		if i.get("dead", false):
			continue
		it.append([i.id, ITEM_KINDS.find(i.kind), NetClasses.x4(i.x), NetClasses.x4(i.y)])
	var pj: Array = []
	for q in r.projs:
		if not q.dead:
			pj.append([q.id, q.kind, NetClasses.x4(q.x), NetClasses.x4(q.y), roundi(q.vx), roundi(q.vy), roundi(q.r), String(q.col), q.dmg, 1 if q.get("friendly", false) else 0, 1 if q.get("catchable", false) else 0, roundi(float(q.get("hgt", 0.0))), roundi(float(q.g)), 1 if q.cut else 0])
	var gf: Array = []                  # the room's switch / key / gate flags: state, applied by the guest on every snapshot
	for fk in Game.flags:
		var fks := String(fk)
		if (fks.begins_with("switch:") or fks.begins_with("key:") or fks.begins_with("gate:") or fks.begins_with("dead:")) and fks.get_slice(":", 1) == r.id:
			gf.append(fks)
	var pl: Array = []                  # owned plugins: state (the guest's pickup request or the `plugin` event may be lost)
	for d in Game.PLUGINS:
		if Game.owns_plugin(d.id):
			pl.append(d.id)
	var cr: Array = []                  # the crumbling blocks of the guest's room (the guest's grid follows this list)
	for ci in r.grid.crumble:
		var cc: Dictionary = r.grid.crumble[ci]
		cr.append([ci % r.w, ci / r.w, cc.s, roundi(cc.t * 100.0)])
	var ag: Array = []                  # the helpers of the guest's room: [owner 1 (host) | 2 (guest), x4, y4]
	for a in r.agents:
		if not is_instance_valid(a.owner_p):
			continue                        # (its owner was just freed; the room drops the agent on its next step)
		ag.append([2 if a.owner_p.get("is_remote") == true else 1, NetClasses.x4(a.x), NetClasses.x4(a.y)])
	var hz: Array = []
	for z in r.zones:
		hz.append([z.id, z.kind, NetClasses.x4(z.x), NetClasses.x4(z.y), NetClasses.x4(z.a), NetClasses.x4(z.b), z.dmg])
	var hp_ = mgr.player
	var p1: Array = [mgr.room.id, NetClasses.x4(hp_.x), NetClasses.x4(hp_.y), roundi(hp_.vx), roundi(hp_.vy), int(hp_.face), 0, hp_.hp, 1 if hp_.dead else 0, host_dn, 1 if _map_open() else 0, hp_.zip, 1 if hp_.ssh_t > 0.0 else 0]
	var s := {"sn": snap_n, "tm": hms(), "room": r.id, "rt": r.time, "en": en, "it": it, "pj": pj, "hz": hz, "gf": gf, "pl": pl, "cr": cr, "ag": ag, "p1": p1,
		"fs": FIGHT_STATES.find(r.fight.state), "fa": 1 if r.fight_active else 0,
		"fl": Game.heap_flood(), "lq": NetClasses.x4(r.liquid_y) if r.liquid_y != null else -1, "rs": 1 if r.rise_on else 0}
	# world flags are state: every snapshot carries the digest, the full list goes out only while the guest's digest differs (a lost one corrects itself)
	var wh := Game.world_digest()
	if wh != wh_sent or snap_n % 5 == 0:         # (3 times a second is enough: the host acts on the guest's number, this one is only for the record)
		s["wh"] = wh
		wh_sent = wh
	if wh != guest_wh and hms() - wf_t >= 1.0:
		var wf: Array = Game.world_flags()
		s["wf"] = wf
		wf_t = hms()
		wf_count += 1
		wf_bytes += JSON.stringify(wf).length()
		pins_sent = -1                          # (the pins are part of the digest: a list that differs goes out with it)
	if pins_sent != Game.pins_rev:
		s["pn"] = Game.pins_wire()
		pins_sent = Game.pins_rev
	if r.banner.text != "":
		s["bn"] = [r.banner.text, r.banner.sub]
	if r.stats_line != "" and r.stats_t > 0.0:
		s["sl"] = r.stats_line
	if not r.fx_out.is_empty():
		s["fx"] = r.fx_out
		r.fx_out = []
	if main.paused:
		s["pz"] = 1                     # the pause is state too (as the JS game's hs): a guest that missed the event, or joined during it, follows
	snap_sent[snap_n] = hms()
	if snap_sent.size() > 120:
		snap_sent.erase(snap_sent.keys()[0])
	Net.send_msg("s", s, true)

# ================================================================ GUEST
func _on_host(on: bool, lag: bool, _resume: bool) -> void:
	if role != "guest":
		return
	if lag:
		host_lagging = true
		notice_set("host lagging", 3.0)
	elif on:
		host_lagging = false
		host_present = true
		Controls.locked = false         # a host that comes back (or a new one) releases the "host left" lock
	else:
		host_present = false
		Game.partner = {}
		notice_set("Host left", 9999.0)
		log_("guest: host left")
		main.on_host_left()

func _on_line_lost() -> void:
	line_down = true
	if role == "guest":
		notice_set("reconnecting...", 15.0)
	log_("%s: line lost" % role)

func _guest_msg(t: String, m: Dictionary) -> void:
	if t == "start":
		_guest_start(m)
	elif t == "s":
		_apply_snapshot(m)

func _guest_start(m: Dictionary) -> void:
	log_("guest: start received")
	Net.reset_reliable()
	host_present = true
	Controls.locked = false
	Net.epoch = int(m.e)
	var sv: Dictionary = m.save
	Game.flags = sv.flags
	for k in sv.tools:
		Game.tools[k] = sv.tools[k]
	Game.diff = String(sv.diff)
	Game.coop_hp_pct = int(sv.coop_hp_pct)
	Game.fragments = int(sv.fragments)
	Game.tokens = 0
	started = true
	var you: Dictionary = m.you
	if mgr.player != null:                # a second start (the host came back): the old body must not leak
		if mgr.player.get_parent() != null:
			mgr.player.get_parent().remove_child(mgr.player)
		mgr.player.queue_free()
	mgr.player = null
	mgr.mode = "guest"
	mgr.swap_to(String(you.room), Vector2(you.x4 / 4.0, you.y4 / 4.0), null, true)
	var p = mgr.player
	p.max_hp = int(you.max_hp)
	p.hp = int(you.hp)
	p.parried.clear()                    # (a new host session restarts its strike ids)
	notice_set("", 0.1)
	_check_build(String(m.get("build", "?")))
	Game.load_profile()                  # the guest's own loadout (user://profile.json); the host judges its pickups and hits with it
	Game.save_profile()                  # (a plugin it does not own here is gone from its file too)
	if main.shop_menu.pending != "":                 # a purchase asked on the old link gets no answer: ask again from scratch
		main.shop_menu.pending = ""
		main.shop_menu.msg = ""
	if main.index_menu.pending != "":
		main.index_menu.pending = ""
		main.index_menu.msg = ""
	Net.rel("ready", {"build": Game.build_text})
	Net.rel("loadout", {"ids": Game.equipped})

func _guest_tick(dt: float) -> void:
	if not started:
		return
	var r: Room = mgr.room
	var p = mgr.player
	if r == null or p == null:
		return
	# the partner (the host's body) and the creatures follow the snapshots 0.1 s late
	var rt := hms() + host_off - clampf(snap_interval + 2.0 * Net.jitter, 0.08, 0.3)
	if host_body != null:
		host_body.follow(rt + 0.08)
	for id in puppets:
		_puppet_follow(puppets[id], rt, dt)
	r.lenient = _laggy()
	_play_fx(r, p)
	dl_acc += dt
	if dl_acc >= 0.5 and not Game.log_out.is_empty() and Net.is_open:
		dl_acc = 0.0
		var lines: Array = Game.log_out.slice(0, 30)
		Game.log_out = Game.log_out.slice(30)
		Net.send_msg("dl", {"v": lines})
	if r.boss != null and (r.boss.dying or r.boss.dead):
		p.inv = maxf(p.inv, 0.5)            # the boss is going down: nothing hurts any more (as the JS game)
	# the guest's body goes out 30 times a second (20 on a bad line)
	st_acc += dt
	var hz := ST_HZ if Net.rtt < 0.2 else 20.0
	if st_acc >= 1.0 / hz:
		st_acc = 0.0
		var d := {"room": r.id, "x4": NetClasses.x4(p.x), "y4": NetClasses.x4(p.y), "vx": roundi(p.vx), "vy": roundi(p.vy), "face": int(p.face), "pose": 0, "hp": p.hp, "maxhp": p.max_hp,
			"dead": 1 if p.dead else 0, "dn": guest_dn, "atk": [p.atk_id, p.atk_dir, p.atk_t > 0.0 and p.atk_live], "dash": [p.dash_id, roundi(p.dash_dx * 100.0), roundi(p.dash_dy * 100.0), roundi(maxf(p.dash_t, 0.0) * 100.0)],
			"gt": hms(), "sa": last_snap_n, "inv": p.inv, "fo": 1 if p.focus_t >= 0.0 else 0, "mn": 1 if _map_open() else 0, "cz": p.zip, "ss": 1 if p.ssh_t > 0.0 else 0}
		st_n += 1
		var gwh := Game.world_digest()
		if gwh != st_wh_sent or st_n % 10 == 1:       # the digest rides on every 10th report, at once when it changes
			d["wh"] = gwh
			st_wh_sent = gwh
		Net.send_msg("st", d, true)
	# downed countdown (the host decides when to bring it back)
	if p.dead and p.downed and guest_down_t >= 0.0:
		guest_down_t -= dt
		p.down_t = guest_down_t
	_guest_summon_logic(dt)
	_hud(p)

func _puppet_follow(e, rt: float, dt: float) -> void:
	e.t += dt
	if e.has_method("puppet_tick"):
		e.puppet_tick(dt)
	if e.has_method("puppet_follow_parts"):
		e.puppet_follow_parts(rt)
	if e.flash > 0.0:
		e.flash -= dt
	var s: Array = e.get_meta("samples", [])
	if s.is_empty():
		return
	var last: Array = s[s.size() - 1]
	e.set_meta("ex", rt >= last[0] + 0.05)      # only guessed (no fresh snapshot): a bad line forgives its touch
	if rt >= last[0]:
		var ex := minf(rt - last[0], 0.25)
		e.x = last[1] + e.vx * ex
		e.y = last[2] + e.vy * ex
		return
	for i in range(s.size() - 1):
		if s[i][0] <= rt and rt <= s[i + 1][0]:
			var k: float = (rt - s[i][0]) / maxf(0.0001, s[i + 1][0] - s[i][0])
			e.x = lerpf(s[i][1], s[i + 1][1], k)
			e.y = lerpf(s[i][2], s[i + 1][2], k)
			return
	e.x = s[0][1]
	e.y = s[0][2]

func _apply_snapshot(m: Dictionary) -> void:
	if not started or int(m.get("e", -1)) != Net.epoch:
		return
	var r: Room = mgr.room
	if r == null or String(m.room) != r.id:
		return
	var n := int(m.sn)
	var hb: Array = m.p1
	Game.partner = {"room": String(hb[0]), "x": hb[1] / 4.0, "y": hb[2] / 4.0}
	var rx := hms()
	if last_snap_rx > 0.0:
		snap_interval = lerpf(snap_interval, clampf(rx - last_snap_rx, 0.02, 0.5), 0.2)
	last_snap_rx = rx
	last_snap_n = n
	snaps_applied += 1
	var off: float = float(m.tm) - rx
	host_off = off if snaps_applied == 1 else lerpf(host_off, off, 0.1)
	var tm: float = float(m.tm)
	if absf(r.time - float(m.rt)) > 0.5:
		r.time = float(m.rt)
	else:
		r.time = lerpf(r.time, float(m.rt), 0.15)
	# creatures
	var seen := {}
	for rec in m.en:
		var id := int(rec[0])
		seen[id] = true
		var e = puppets.get(id)
		if e == null:
			e = NetClasses.make(int(rec[1]), r)
			if e == null:
				continue
			e.nid = id
			e.x = rec[2] / 4.0
			e.y = rec[3] / 4.0
			puppets[id] = e
			r.ents.append(e)
			r.entity_root.add_child(e)
			if e is Boss and not e.get("lab_dummy"):
				r.boss = e
		NetClasses.apply(e, rec)
		if e.has_method("net_sample"):
			e.net_sample(tm)                  # (parts that move on their own: MERGE CONFLICT's heads)
		var samples: Array = e.get_meta("samples", [])
		samples.append([tm, rec[2] / 4.0, rec[3] / 4.0])
		while samples.size() > 8:
			samples.pop_front()
		e.set_meta("samples", samples)
	for id in puppets.keys():
		if not seen.has(id):
			var e2 = puppets[id]
			puppets.erase(id)
			r.ents.erase(e2)
			e2.queue_free()               # (its death burst and sound come from the host, in fx)
	# items (host truth; the pickup request flag survives)
	var old_items := {}
	for i in r.items:
		old_items[String(i.id)] = i
	var items: Array = []
	for rec in m.it:
		var iid := String(rec[0])
		var old = old_items.get(iid)
		var d := {"kind": ITEM_KINDS[clampi(int(rec[1]), 0, ITEM_KINDS.size() - 1)], "id": iid, "x": rec[2] / 4.0, "y": rec[3] / 4.0, "loose": iid.begins_with("L"), "t": 1.0, "ph": float(hash(iid) % 100) / 10.0, "ghost": false, "idx": 0, "vx": 0.0, "vy": 0.0}
		if old != null:
			d["asked"] = old.get("asked", -10.0)
		items.append(d)
	r.items = items
	# projectiles: flown locally between snapshots
	var old_pj := {}
	for q in r.projs:
		old_pj[int(q.id)] = q
	var projs: Array = []
	for rec in m.pj:
		var pid := int(rec[0])
		var q: Dictionary = old_pj.get(pid, {})
		if q.is_empty():
			q = {"id": pid, "kind": rec[1], "r": float(rec[6]), "col": rec[7], "life": 4.0, "dmg": int(rec[8]), "tile": false, "cut": int(rec[13]) == 1, "t": 0.0, "dead": false, "friendly": false, "catchable": false, "hgt": float(rec[11]), "g": float(rec[12])}
		var host_friendly: bool = int(rec[9]) == 1
		q.catchable = int(rec[10]) == 1
		if host_friendly:
			q.friendly = true
			q.erase("pred_until")
		if float(q.get("pred_until", -1.0)) > r.time:          # this player caught it a moment ago: keep the local copy until the host agrees
			projs.append(q)
			continue
		q.x = rec[2] / 4.0
		q.y = rec[3] / 4.0
		q.vx = float(rec[4])
		q.vy = float(rec[5])
		q.dmg = int(rec[8])
		projs.append(q)
	r.projs = projs
	for pid in m.get("pl", []):
		Game.flags["plugin:" + String(pid)] = true
	r.agent_view = []
	for rec in m.get("ag", []):
		r.agent_view.append({"owner": int(rec[0]), "x": rec[1] / 4.0, "y": rec[2] / 4.0})
	r.apply_crumbles(m.get("cr", []))
	last_cr = {}
	for rec in m.get("cr", []):
		last_cr[int(rec[1]) * r.w + int(rec[0])] = true
	last_gf = m.get("gf", [])
	last_gf_room = r.id
	for fk in last_gf:
		if String(fk) == "dead:" + r.id and not Game.flag(String(fk)):
			r.reveal_dead(false)
		Game.flags[String(fk)] = true
	for fk in m.get("wf", []):
		Game.flags[String(fk)] = true   # (never clears one)
	if m.has("pn"):
		Game.set_pins(m.pn)
	Game.flood_net = int(m.get("fl", Game.flood_net))
	last_lq =int(m.get("lq", -1))
	last_lq_room = r.id
	if last_lq < 0:
		r.liquid_y = null
	elif r.liquid_y == null or absf(r.liquid_y - last_lq / 4.0) > 60.0:
		r.liquid_y = last_lq / 4.0
	else:
		r.liquid_y += (last_lq / 4.0 - r.liquid_y) * 0.5
	r.rise_on = int(m.get("rs", 0)) == 1
	r.update_doors()
	# damage areas
	for z in m.hz:
		var zid := int(z[0])
		if zones_seen.has(zid):
			continue
		zones_seen[zid] = true
		r.zones.append({"id": zid, "kind": z[1], "x": z[2] / 4.0, "y": z[3] / 4.0, "a": z[4] / 4.0, "b": z[5] / 4.0, "dmg": int(z[6]), "until": 0.25})
	# the fight (state and the doors follow the snapshot; the events add the effects)
	var fs: String = FIGHT_STATES[clampi(int(m.fs), 0, 4)]
	r.fight.state = fs
	var fa := int(m.fa) == 1
	if fa != r.fight_active:
		r.fight_active = fa
	if fa and r.cam.lock == null:
		r.cam.lock = {"x": (r.pw - 384.0) / 2.0, "y": float(r.ph - 216)}
	elif not fa:
		r.cam.lock = null
	if m.has("bn"):
		r.banner = {"text": m.bn[0], "sub": m.bn[1], "t": 1.0}
	else:
		r.banner.text = ""
	var pz := int(m.get("pz", 0)) == 1
	if pz != main.paused and hms() - main.pause_changed_at > 1.5:      # (not right after this player pressed pause itself)
		log_("guest: pause from the host's state (%s)" % pz)
		main.set_paused(pz, true)
	var at := hms() + clampf(snap_interval + 2.0 * Net.jitter, 0.08, 0.3)
	for e in m.get("fx", []):
		if fx_q.size() < 200:
			fx_q.append([at, e])
	r.stats_line = String(m.get("sl", ""))
	r.stats_t = 1.0 if m.has("sl") else 0.0
	# the host's body
	var p1: Array = m.p1
	if String(p1[0]) == r.id:
		if host_body == null:
			host_body = RemotePlayer.new(r)
			host_body.name = "Host"
			host_body.x = p1[1] / 4.0
			host_body.y = p1[2] / 4.0
			r.remote_players.append(host_body)
			r.add_child(host_body)
			host_body.set_meta("born", tm)
		host_body.report(p1[1] / 4.0, p1[2] / 4.0, float(p1[3]), float(p1[4]), float(p1[5]), tm)
		host_body.hp = int(p1[7])
		host_body.dead = int(p1[8]) == 1
		host_body.dn = int(p1[9])
		host_body.mapping = p1.size() > 10 and int(p1[10]) == 1
		host_body.cz = int(p1[11]) if p1.size() > 11 else -1
		host_body.ss = p1.size() > 12 and int(p1[12]) == 1
	elif host_body != null:
		r.remote_players.erase(host_body)
		host_body.queue_free()
		host_body = null

func _guest_rel(k: String, d: Dictionary) -> void:
	var r: Room = mgr.room
	var p = mgr.player
	match k:
		"heal":
			if p != null:
				p.hp = mini(p.max_hp, p.hp + int(d.n))
		"revive":
			if p != null:
				p.dead = false
				p.downed = false
				p.hp = int(d.hp)
				p.inv = 1.5
				guest_down_t = -1.0
				p.down_t = -1.0
				if bool(d.get("same", true)):
					p.x = d.x4 / 4.0
					p.y = d.y4 / 4.0
				else:
					p.x = p.safe.x
					p.y = p.safe.y
				p.vx = 0.0
				p.vy = 0.0
				log_("guest: revived")
		"respawn":
			if p != null:
				p.dead = false
				p.downed = false
				p.hp = p.max_hp
				p.inv = 1.5
				guest_down_t = -1.0
				var rid := String(d.room)
				mgr.swap_to(rid, Vector2(d.x4 / 4.0, d.y4 / 4.0), null, true)
				if Game.mod_restart_meter() and mgr.player != null:
					mgr.player.meter = float(Game.METER_MAX)              # restart: always
				log_("guest: respawned in %s" % rid)
		"summon":
			guest_summon = {"room": String(d.room), "t": float(d.warn)}
			Audio.sfx("warn")
			if p != null:
				p.frozen = true
				p.inv = maxf(p.inv, 5.0)
			log_("guest: summon banner")
		"door":
			if r != null and r.id == String(d.room):
				r.fight_active = bool(d.closed)
				Audio.sfx("thud" if bool(d.closed) else "gate")
		"tile":
			if r != null and r.id == String(d.room):
				r.apply_tile(int(d.tx), int(d.ty))
			else:
				Game.flags["crack:%s:%d:%d" % [d.room, int(d.tx), int(d.ty)]] = true
		"ability":
			Game.tools[String(d.name)] = true
		"flag":
			Game.flags[String(d.k)] = bool(d.v)
		"boss":
			if r != null and r.id == String(d.room):
				match String(d.ev):
					"intro":
						Audio.sfx("roar")           # (the music follows the snapshot's fight state: Main.song_for)
					"phase":
						r.shake(0.6)
						r.flash_screen(0.5, "#bfe9ff")
						Audio.sfx("glitch")
					"reward", "done":
						pass
		"pick":
			var rid2 := String(d.room)
			Game.flags[String(d.id)] = true
			if r != null and r.id == rid2:
				for it in r.items:
					if String(it.id) == String(d.id):
						it.dead = true
			if String(d.kind) == "coffee":
				Audio.sfx("heal")
			if String(d.kind) == "token" and String(d.by) == "p2":
				Game.tokens += 1
				Audio.sfx("token")
			if String(d.kind) == "spark":
				Game.fragments += 1
				if r != null and r.id == rid2:
					r.show_memory(rid2)
				if Game.fragments % 4 == 0 and p != null:
					p.max_hp = Game.max_hp
					p.hp = p.max_hp
		"plugin":
			Game.flags["plugin:" + String(d.id)] = true
			if main.shop_menu.pending == String(d.id):             # the answer to this player's `buy`: pays now (by "p2") or not at all (by "")
				main.shop_menu.answered(String(d.id), String(d.by))
			elif r != null:
				r.show_plugin_banner(String(d.id))
		"pause":
			main.set_paused(bool(d.on), true)
		"ping": Game.ping_receive(d)
		"pingok": Game.ping_ack_received(String(d.id))
		"mapbought":
			main.index_menu.answered(String(d.zone), String(d.by))
		"committed":
			if r != null and p != null and int(d.n) > 0:
				r.pop(p.x + 5.0, p.y - 30.0, "+%d rooms" % int(d.n), Game.COL.okHi, true)

func _guest_died() -> void:
	var p = mgr.player
	var in_fight: bool = mgr.room != null and mgr.room.fight_active
	p.downed = in_fight                 # outside a boss fight there is no countdown: the host sends this body to its bench
	guest_down_t = REVIVE_T if in_fight else -1.0
	p.down_t = REVIVE_T if in_fight else -1.0
	guest_dn += 1
	Net.rel("die", {})
	log_("guest: down")

func _guest_summon_logic(dt: float) -> void:
	if guest_summon.is_empty():
		return
	var rid := _summon_step(guest_summon, dt)
	if rid != "":
		guest_summon = {}
		Net.rel("summon_ok", {})
		log_("guest: arrived in %s" % rid)
