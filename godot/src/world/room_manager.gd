class_name RoomManager
extends Node
# RoomManager: the rooms of the map, the player's current room, and the fade-through-a-door transition (MV2-01 rule 3).
# Everything that steps the simulation goes through tick(); tests call tick() by hand with Controls.script_input.

const FADE := 0.12

signal room_changed(room: Room)
signal restart_requested
signal bench_requested(room: Room, index: int)

var host: Node2D                 # where rooms are added (Main.world)
var hud                          # Hud (fade overlay), may be null in tests
var rooms := {}                  # id -> Room (phase 2 solo: only the current one)
var room: Room
var player: Player
var trans := {"on": false, "t": 0.0, "door": null, "swapped": false}
var fade := 0.0

func _init(h: Node2D, hd = null) -> void:
	host = h
	hud = hd

# ---------------------------------------------------------------- rooms
func make_room(room_id: String, snap = null, spawn = null) -> Room:
	var r := Room.new()
	host.add_child(r)
	r.load_room(room_id, snap)
	r.build_nodes(player, spawn)
	if player == null:
		player = r.player
	r.door_crossed.connect(_on_door_crossed.bind(r))
	r.restart_requested.connect(func(_s): restart_requested.emit())
	r.bench_requested.connect(func(i): bench_requested.emit(r, i))
	Game.flags["room:%s:visited" % room_id] = true
	return r

func swap_to(room_id: String, spawn = null, snap = null) -> void:
	var old := room
	room = make_room(room_id, snap, spawn)
	rooms.clear()
	rooms[room_id] = room
	if old != null:
		old.queue_free()
	room_changed.emit(room)
	if hud != null:
		hud.set_room(room)
	var song := String(room.def.get("music", ""))
	if song != "":
		Audio.music(song)
	else:
		Audio.stop_music(1.0)

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
	if player != null:
		player.queue_free()
	player = null
	var rid := String(Game.rooms_meta.start.room)
	var spawn = null
	if Game.bench != "" and Game.rooms_meta.rooms.has(Game.bench):
		rid = Game.bench
		spawn = Game.bench_spawn(rid)
	swap_to(rid, spawn)
	Controls.locked = false
	trans.on = false
	fade = 0.0
	if hud != null:
		hud.fade = 0.0

# Rest at a bench: heal, make it the respawn point, save
func rest(r: Room, index: int) -> void:
	var c: Dictionary = r.cps[index]
	var first: bool = not Game.flag("bench:" + r.id)
	Game.flags["bench:" + r.id] = true
	c.on = true
	Game.bench = r.id
	player.hp = player.max_hp
	player.meter = player.meter
	if first:
		r.pop(c.x, c.y - 36, "committed ✓", Game.COL.okHi, true)
		r.ring(c.x, c.y - 22, 3, 26, Game.COL.ok, 0.4)
		r.burst(c.x, c.y - 22, 14, [Game.COL.ok, Game.COL.okHi, "#ffffff"], 100.0, 100.0, {"glow": 1})
	Audio.sfx("checkpoint")
	Game.write_save()

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
	trans.travel = room_id
	Controls.locked = true


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
	Controls.locked = true

func tick(dt: float) -> void:
	if trans.on:
		_tick_transition(dt)
		return
	Controls.poll()
	Game.play_time += dt
	room.step(dt)

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
	var target_room := to_id.get_slice(":", 0)
	var tmeta: Dictionary = Game.rooms_meta.rooms[target_room]
	var t_door: Dictionary = {}
	for td in tmeta.doors:
		if td.id == to_id:
			t_door = td
	var pw: int = int(tmeta.size[0]) * 16
	var new_y: float = (int(t_door.b) + 1) * 16 - ((int(trans.src_b) + 1) * 16 - float(trans.src_y))
	var new_x: float = 1.0 if t_door.side == "W" else pw - player.w - 1.0
	player.vx = trans.vx
	player.vy = trans.vy
	player.face = trans.face
	player.dash_t = 0.0
	player.atk_t = 0.0
	swap_to(target_room, Vector2(new_x, new_y))
