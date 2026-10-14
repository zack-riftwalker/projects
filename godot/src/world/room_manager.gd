class_name RoomManager
extends Node
# RoomManager: the rooms of the map, the player's current room, and the fade-through-a-door transition (MV2-01 rule 3).
# Everything that steps the simulation goes through tick(); tests call tick() by hand with Controls.script_input.

const FADE := 0.12

signal room_changed(room: Room)
signal restart_requested
signal bench_requested(room: Room, index: int)
signal shop_requested(room: Room)
signal index_requested(room: Room, npc_index: int)
signal end_requested
signal rested(room_id: String)          # the local player rested at a bench (a guest tells the host)

var host: Node2D                 # where rooms are added (Main.world)
var hud                          # Hud (fade overlay), may be null in tests
var rooms := {}                  # id -> Room (phase 2 solo: only the current one)
var room: Room
var player: Player
var trans := {"on": false, "t": 0.0, "door": null, "swapped": false}
var fade := 0.0
var door_blend := false          # the next swap_to is a door crossing: the new room's look starts from the old one and blends (MVGN-08)
var last_door_id := ""           # the door the local player last crossed (a guest tells the host, for `sets` doors)

func _init(h: Node2D, hd = null) -> void:
	host = h
	hud = hd

# ---------------------------------------------------------------- rooms
signal room_built(room: Room)
signal local_died(room: Room)

var mode := "solo"               # solo | host | guest (co-op)

# builds a room (fresh from its file and the flags). local = false: a room only the partner is in (hidden, no camera)
func make_room(room_id: String, spawn = null, local := true) -> Room:
	var r := Room.new()
	r.mode = mode
	host.add_child(r)
	r.load_room(room_id)
	r.build_nodes(player if local else null, spawn, local)
	if local and player == null:
		player = r.player
	r.door_crossed.connect(_on_door_crossed.bind(r))
	r.restart_requested.connect(func(_s): restart_requested.emit())
	r.bench_requested.connect(func(i): bench_requested.emit(r, i))
	r.shop_requested.connect(func(): shop_requested.emit(r))
	r.index_requested.connect(func(i): index_requested.emit(r, i))
	r.end_requested.connect(func(): end_requested.emit())
	r.bench_touched.connect(func(i): rest(r, i))
	r.local_died.connect(func(): local_died.emit(r))
	rooms[room_id] = r
	if local:
		Game.flags["room:%s:visited" % room_id] = true
	room_built.emit(r)
	return r

# a room for the partner (built if nobody is in it yet)
func ensure_room(room_id: String) -> Room:
	if rooms.has(room_id):
		return rooms[room_id]
	return make_room(room_id, null, false)

# a room nobody is in any more is dropped (it is rebuilt fresh on the next visit)
func release_if_empty(r: Room) -> void:
	if r == null or r == room:
		return
	if r.player == null and r.remote_players.is_empty():
		rooms.erase(r.id)
		r.queue_free()

# the local player goes to another room (the partner may already be there). rebuild: throw the old copy of the target away first
func swap_to(room_id: String, spawn = null, _snap = null, rebuild := false) -> void:
	var old := room
	Game.dlog("room %s -> %s%s" % [old.id if old != null else "-", room_id, " (rebuild)" if rebuild else ""])
	var keep: Array = []               # partners standing in a room that is rebuilt move into the new copy
	if rebuild and rooms.has(room_id):
		var dead_room: Room = rooms[room_id]
		for rp in dead_room.remote_players.duplicate():
			dead_room.remote_players.erase(rp)
			dead_room.remove_child(rp)
			if mode == "guest":           # the host's body is rebuilt from the next snapshot
				rp.queue_free()
			else:
				keep.append(rp)
		rooms.erase(room_id)
		if dead_room == old:
			old = null
			room = null
		dead_room.queue_free()
	var target: Room = rooms.get(room_id)
	if target == null:
		target = make_room(room_id, spawn, true)
	else:
		target.attach_local(player, spawn)
		Game.flags["room:%s:visited" % room_id] = true
	for rp in keep:
		rp.room = target
		target.remote_players.append(rp)
		target.add_child(rp)
	if old != null and old != target:
		old.detach_local()
		if old.remote_players.is_empty() or mode == "guest":     # the guest only shows the current room: the host's snapshots rebuild the rest
			rooms.erase(old.id)
			old.queue_free()
	if door_blend and old != null and old != target and old.look != null and target.look != null:
		var mm := Look.resolve(target.def)
		target.look.inherit(old.look)
		target.look.set_target(mm[0], mm[1], false)
	door_blend = false
	room = target
	room_changed.emit(room)
	if hud != null:
		hud.set_room(room)

# the loop room (T09) gets one pass worse and is rebuilt for whoever stands in it (the host decides; a guest's crossing comes as its `room` event)
func loop_advance(room_id: String) -> void:
	Game.loop_iter[room_id] = mini(3, int(Game.loop_iter.get(room_id, 0)) + 1)
	if room != null and room.id == room_id:
		swap_to(room_id, Vector2(player.x, player.y), null, true)
	elif rooms.has(room_id):
		var dead_room: Room = rooms[room_id]
		var keep: Array = dead_room.remote_players.duplicate()
		for rp in keep:
			dead_room.remote_players.erase(rp)
			dead_room.remove_child(rp)
		rooms.erase(room_id)
		dead_room.queue_free()
		var nr := ensure_room(room_id)
		for rp in keep:
			rp.room = nr
			nr.remote_players.append(rp)
			nr.add_child(rp)

func start_game() -> void:
	Game.load_meta()
	respawn(false)

# a fresh Clawd (full hp) on the respawn bench, or at the start of R01. The room is rebuilt: enemies are back, a fight resets.
func respawn(count_death := true) -> void:
	if count_death:
		Game.deaths += 1
	Game.load_meta()
	if room != null:
		room.record_loss()
	last_door_id = ""
	Game.loop_iter = {}                    # a new life: the loop room starts over
	if player != null:
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		player.queue_free()
	player = null
	if room != null:
		room.player = null
	var rid := String(Game.rooms_meta.start.room)
	if Game.lab and Game.rooms_meta.rooms.has("Z05"):
		rid = "Z05"
	var spawn = null
	if Game.bench != "" and Game.rooms_meta.rooms.has(Game.bench):
		rid = Game.bench
		spawn = Game.bench_spawn(rid)
	if room != null:
		room.player = null
	swap_to(rid, spawn, null, true)
	if Game.mod_restart_meter() and player != null:
		player.meter = float(Game.METER_MAX)               # restart: always
	Controls.locked = false
	trans.on = false
	fade = 0.0
	if hud != null:
		hud.fade = 0.0

# Rest at a bench: heal, make it the respawn point, save
var changelog_shown: Array = []          # the changelog lines the last rest at a terminal showed (the tests read them)
var commit_extra: Callable = Callable()   # co-op host: the rooms the guest walked (they are committed by the same rest)

func rest(r: Room, index: int) -> void:
	var c: Dictionary = r.cps[index]
	var first: bool = not Game.flag("bench:" + r.id)
	var committed := 0
	if mode != "guest":                         # (the guest's rooms are committed by the host, which tells it how many)
		var staged: Array = Game.staged_rooms()
		if commit_extra.is_valid():
			staged.append_array(commit_extra.call())
		committed = Game.commit_rooms(staged)
	Game.flags["bench:" + r.id] = true
	c.on = true
	Game.bench = r.id
	player.hp = player.max_hp
	player.meter = player.meter
	if first or committed > 0:
		r.pop(c.x, c.y - 36, "committed ✓" + (" +%d rooms" % committed if committed > 0 else ""), Game.COL.okHi, true)
		r.ring(c.x, c.y - 22, 3, 26, Game.COL.ok, 0.4)
		r.burst(c.x, c.y - 22, 14, [Game.COL.ok, Game.COL.okHi, "#ffffff"], 100.0, 100.0, {"glow": 1})
	Audio.sfx("checkpoint")
	if bool(Game.rooms_meta.rooms[r.id].get("terminal", false)):          # a terminal says what the new abilities now open (MVB1-07)
		changelog_shown = Game.changelog_commit()
		for line in changelog_shown:
			if hud != null:
				hud.toast(String(line), 6.0)
	Game.write_save()
	rested.emit(r.id)

# terminals only talk to terminals (D32): rested benches of rooms with "terminal": true, not the current room
func travel_targets() -> Array:
	var out: Array = []
	for id in rested_benches():
		if bool(Game.rooms_meta.rooms[id].get("terminal", false)) and not Game.is_lab(id) and (room == null or id != room.id):
			out.append(id)
	return out

# the terminal this player rested at that is nearest to the partner, when the partner is in another zone ("" = no such line); nobody is pulled, each moves only itself
func partner_travel_target() -> String:
	if room == null or Game.partner.is_empty():
		return ""
	var prid := String(Game.partner.room)
	if not Game.rooms_meta.rooms.has(prid) or Game.is_lab(prid):
		return ""
	var pz := Game.zone_of(prid)
	if pz == Game.zone_of(room.id):
		return ""
	var best := ""
	var bd := 1e18
	var po: Array = Game.rooms_meta.rooms[prid].origin
	for id in travel_targets():
		if Game.zone_of(id) != pz:
			continue
		var o: Array = Game.rooms_meta.rooms[id].origin
		var d := Vector2(float(o[0]) - float(po[0]), float(o[1]) - float(po[1])).length()
		if d < bd:
			bd = d
			best = id
	return best

func rested_benches() -> Array:
	var out: Array = []
	for id in Game.rooms_meta.rooms:
		if Game.flag("bench:" + id):
			out.append(id)
	out.sort()
	return out

# fade to another room's bench
func travel(room_id: String) -> void:
	if trans.on:
		return
	trans.on = true
	trans.t = 0.0
	trans.door = null
	trans.swapped = false
	last_door_id = ""
	trans.travel = room_id
	Game.loop_iter = {}
	Controls.locked = true


# Going up (D31): the push must carry the body onto the ledge above the door. A plain jump (~54 px, and halved when jump was let go)
# fell short of the tower's shafts (63..111 px to the one-way ledge over TA1/TB1/TC1 -> T04, TA2 -> T08, TC2 -> T09, H11 -> T02): the body
# dropped back through the floor into the room below at once, which looked like a crash. The push is the door's, so letting go of jump
# does not cut it. A ceiling (solid) over the door means side ledges: the plain push stays.
const PUSH_MAX_ROWS := 10
func _push_to_ledge(t_door: Dictionary) -> void:
	var g := room.grid
	var feet := player.y + player.h
	for ty in range(g.h - 2, maxi(-1, g.h - 2 - PUSH_MAX_ROWS), -1):
		var hit := -1
		for tx in range(int(t_door.a), int(t_door.b) + 1):
			var t := g.tile(tx, ty)
			if t != TileGrid.E:
				hit = t
				break
		if hit < 0:
			continue
		if hit == TileGrid.ONEWAY or hit == TileGrid.CRUMBLE or hit == TileGrid.BLINK_A or hit == TileGrid.BLINK_B:
			var rise := feet - ty * TileGrid.T + 6.0
			player.vy = minf(player.vy, -sqrt(2.0 * Player.G_UP * rise))
		break
	player.jumping = false

# ---------------------------------------------------------------- transitions
func _on_door_crossed(d: Dictionary, from_room: Room) -> void:
	if trans.on or from_room != room:
		return
	trans.on = true
	trans.t = 0.0
	trans.door = d
	trans.swapped = false
	trans.vx = player.vx
	trans.vy = player.vy
	trans.face = player.face
	trans.src_y = player.y
	trans.src_b = d.b
	trans.src_x = player.x
	trans.src_room = from_room.id
	trans.ssh = [player.ssh_t, player.ssh_dir, player.phase_fire]         # a tunnel through a firewall door goes on in the next room
	last_door_id = String(d.id)
	if String(d.get("sets", "")) != "":
		Game.flags[String(d.sets)] = true
		Game.write_save()
	Controls.locked = true

func tick(dt: float) -> void:
	if trans.on:
		_tick_transition(dt)
		return
	if room == null:
		return
	Controls.poll()
	Game.play_time += dt
	Audio.listen_room = room
	for r in rooms.values():
		Audio.room_ctx = r
		r.step(dt)
	Audio.room_ctx = null
	Audio.update_terminal(room, player, dt)

func _tick_transition(dt: float) -> void:
	trans.t += dt
	if trans.t < FADE:
		fade = trans.t / FADE
	elif not trans.swapped:
		trans.swapped = true
		_place_in_target()
		fade = 1.0
	elif trans.t < 2.0 * FADE:
		fade = 1.0 - (trans.t - FADE) / FADE
	else:
		fade = 0.0
		trans.on = false
		Controls.locked = false
	if hud != null:
		hud.fade = fade

func _place_in_target() -> void:
	if trans.door == null:
		var rid: String = trans.travel
		player.vx = 0.0
		player.vy = 0.0
		swap_to(rid, Game.bench_spawn(rid))
		return
	var d: Dictionary = trans.door
	var to_id := String(d.to)                       # "R02:W" = the target room and its door
	var wrap_rebuild := false
	if bool(d.get("wrap", false)):                  # the loop room's east door: back in the same room at its west door, one pass worse, until `break;` was touched
		var lp: Dictionary = Game.rooms_meta.rooms[String(trans.src_room)].loop
		if Game.flag(String(lp.flag)):
			to_id = String(lp.after)
		elif mode != "guest":
			Game.loop_iter[String(trans.src_room)] = mini(3, int(Game.loop_iter.get(String(trans.src_room), 0)) + 1)
			wrap_rebuild = true
	var target_room := to_id.get_slice(":", 0)
	var tmeta: Dictionary = Game.rooms_meta.rooms[target_room]
	var t_door: Dictionary = {}
	for td in tmeta.doors:
		if td.id == to_id:
			t_door = td
	var pw: int = int(tmeta.size[0]) * 16
	player.vx = trans.vx
	player.vy = trans.vy
	if t_door.side == "N" or t_door.side == "S":
		var src: Dictionary = Game.rooms_meta.rooms[trans.src_room]
		var nx: float = float(trans.src_x) + (float(src.origin[0]) - float(tmeta.origin[0])) * 16.0      # columns line up in the world
		nx = clampf(nx, int(t_door.a) * 16.0, (int(t_door.b) + 1) * 16.0 - player.w)
		var ny: float
		if d.side == "N":                      # going up: arrive at the bottom of the room above, pushed upward (D31)
			ny = float(tmeta.size[1]) * 16.0 - player.h - 1.0
			player.vy = minf(trans.vy, -Player.JUMP)
		else:                                  # falling through a floor
			ny = 1.0
			player.vy = maxf(trans.vy, 60.0)
		player.face = trans.face
		player.dash_t = 0.0
		player.atk_t = 0.0
		door_blend = true
		swap_to(target_room, Vector2(nx, ny))
		if d.side == "N":
			_push_to_ledge(t_door)
		return
	var new_y: float = (int(t_door.b) + 1) * 16 - ((int(trans.src_b) + 1) * 16 - float(trans.src_y))
	var new_x: float = 1.0 if t_door.side == "W" else pw - player.w - 1.0
	player.face = trans.face
	player.dash_t = 0.0
	player.atk_t = 0.0
	door_blend = true
	swap_to(target_room, Vector2(new_x, new_y), null, wrap_rebuild)
	if trans.has("ssh") and float(trans.ssh[0]) > 0.0:
		player.ssh_t = float(trans.ssh[0])
		player.ssh_dir = float(trans.ssh[1])
		player.phase_fire = bool(trans.ssh[2])
		player.vx = player.ssh_dir * Game.SSH_SPEED
