class_name Room
extends Node2D
# Room: one level room. Owns the tile grid, entities and effects and steps the whole simulation (port of `class Level`, js/level.js).
# Coordinates are the current game's: pixels, origin top-left of the room, entity x/y = top-left of the hitbox.

const T := 16
const W := 384
const H := 216

var id := ""
var def := {}
var grid := TileGrid.new()
var w := 0                 # width in tiles
var h := 0
var pw := 0                # width in pixels
var ph := 0
var ents: Array = []
var stomp_n := 0                 # guest: every stomp is its own attack (a stomp has no attack id of its own)
var lenient := false             # guest on a bad line: no damage from creatures whose place is only guessed (set by Coop)
var items: Array = []
var plats: Array = []
var projs: Array = []
var springs: Array = []
var cps: Array = []
var signs: Array = []
var break_q: Array = []
var events: Array = []
var player = null
var start := {"x": 32.0, "y": 32.0}
var time := 0.0
var clock := 0.0
var hitstop := 0.0
var tokens: int:
	get: return Game.tokens
	set(v): Game.tokens = v
var kills := 0
var hits := 0
var cp_index := -1
var sign_now = null
var auto_step := false
var rng := RandomNumberGenerator.new()
var cam := {"x": 0.0, "y": 0.0, "ty": 0.0, "look": 0.0, "lock": null}
var fx: Fx
var view: RoomView
var camera: Camera2D
var layers := {}
var liquid_y = null
var blink_period := 1.5
var entity_root: Node2D
var fight_active := false
var crossing := false
var mode := "solo"                         # solo | host | guest (co-op: the guest's room only shows what the host sends)
var is_local := true                       # false: a room only the partner is in (no local Clawd, no camera, hidden)
var next_nid := 1                          # network ids of creatures (host)
var hist := {}                             # entity nid -> [[time, [hurtboxes]]]: one second, for the guest's hit check
var zones: Array = []                      # short-lived damage areas the guest checks itself {id,kind,x,y,a,b,dmg,until}
var next_zone := 1
var next_pid := 1
var next_lid := 1
var summon_ok := true
var pending_cracks := {}                   # guest: tiles hidden before the host confirmed them
var zones_hit := {}
var summon_t := 0.0
signal net_hit(nid: int, how: String, dmg: int, dx: float, dy: float, atk: int)
signal net_hurt(d: int)
signal net_projhit(pid: int)
signal net_pickup(item_id: String)
signal local_died
signal fight_intro
signal item_collected(item_id: String, kind: String)
signal tile_broken(tx: int, ty: int)
signal net_crack(tx: int, ty: int)
var boss_spawn = null
var boss = null                            # the boss of this room (R05: NULL) while it is not beaten
var fight := {"state": "none", "t": 0.0}   # none | intro | active | reward | done
var stats := {}                            # the running fight statistics
var attacker = null                        # who is swinging right now (for the boss damage log)
var dmg_log: Array = []                    # {t, who, d}
var remote_players: Array = []
var banner := {"text": "", "sub": "", "t": 0.0}
var stats_line := ""
var stats_t := 0.0
var end_door = null
signal door_crossed(door: Dictionary)
signal bench_requested(index: int)
signal end_requested
signal bench_touched(index: int)
var got := {}                  # item ids already collected (kept across a death)
var sparks := [false, false, false]
var death_t := -1.0
var snapshot_in = null
signal restart_requested(snap: Dictionary)
var rows: PackedStringArray = PackedStringArray()

func _ready() -> void:
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if not auto_step:
		return
	Controls.poll()
	step(Game.STEP)

# ---------------------------------------------------------------- loading
# spawn: "" (the room's P letter, or the start bench), or a Vector2 top-left position for the player
func load_room(room_id: String, snap = null) -> void:
	Game.load_meta()
	id = room_id
	def = Game.rooms_meta.rooms[room_id]
	var raw: PackedStringArray = FileAccess.get_file_as_string("res://src/world/rooms/" + def.file).split("\n")
	w = int(def.size[0])
	h = int(def.size[1])
	if raw.size() != h:
		push_error("room %s: %d rows, rooms.json says %d" % [id, raw.size(), h])
	rows = PackedStringArray()
	for r in raw:
		if r.length() > w:
			push_error("room %s: a row is longer (%d) than the room width %d" % [id, r.length(), w])
		rows.append(r.rpad(w, " "))
	pw = w * T
	ph = h * T
	grid.w = w
	grid.h = h
	grid.tiles = PackedByteArray()
	grid.tiles.resize(w * h)
	grid.doors = []
	for d in def.get("doors", []):
		grid.doors.append({"id": d.id, "side": d.side, "a": int(d.a), "b": int(d.b), "to": d.to, "lock": d.get("lock", ""), "open": true})
	update_doors()
	var sign_n := 0
	var item_id := 0
	var spark_spots: Array = []
	for ty in range(h):
		var row := rows[ty]
		for tx in range(row.length()):
			var ch := row[tx]
			var x := tx * T
			var y := ty * T
			if TileGrid.CHARS.has(ch):
				var t: int = TileGrid.CHARS[ch]
				if t == TileGrid.CRACK and Game.flag("crack:%s:%d:%d" % [id, tx, ty]):
					t = TileGrid.E
				grid.tiles[ty * w + tx] = t
				continue
			match ch:
				" ", ".", "|":
					pass
				"P":
					start = {"x": float(x + 3), "y": float(y + 6)}
				"C":
					cps.append({"x": x + 8, "y": y + T, "on": Game.flag("bench:" + id), "tx": tx})
				"S":
					springs.append({"x": x + 2, "y": y + 9, "w": 12, "h": 7, "t": 0.0})
				"o":
					var tid := "item:%s:%d" % [id, item_id]
					if not Game.flag(tid) and mode != "guest":
						items.append({"kind": "token", "x": float(x + 8), "y": float(y + 8), "id": tid, "ph": tx * 0.7})
					item_id += 1
				"*":
					spark_spots.append({"x": x + 8, "y": y + 8})
				"H":
					var cid := "item:%s:%d" % [id, item_id]
					if not Game.flag(cid) and mode != "guest":
						items.append({"kind": "coffee", "x": float(x + 8), "y": float(y + 9), "id": cid, "ph": 0.0})
					item_id += 1
				"T":
					var texts: Array = def.get("signs", [])
					signs.append({"x": x + 8, "y": y + T, "text": texts[sign_n] if sign_n < texts.size() else "..."})
					sign_n += 1
				"M", "V":
					_add_platform(ch, tx, ty, rows)
				"E", "B", "D":
					if ch == "D":
						end_door = {"x": x + 8, "y": y + T}
					elif ch == "B":
						boss_spawn = {"x": x + 8, "y": y + T}
				_:
					var e = spawn_enemy(ch, x, y)
					if e != null:
						Game.scale_enemy(e)
						e.nid = next_nid
						next_nid += 1
						ents.append(e)
	if def.has("boss") and not Game.flag("boss:" + def.boss.id) and mode != "guest":
		var bs: Dictionary = boss_spawn if boss_spawn != null else {"x": pw - 80.0, "y": ph - 48.0}
		boss = NullBoss.new(self, bs.x, bs.y, roundi(60.0 * float(Game.dv("boss_hp_mult"))))
		boss.nid = next_nid
		next_nid += 1
		ents.append(boss)
	spark_spots.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in range(mini(3, spark_spots.size())):
		var fid := "item:%s:f%d" % [id, i]
		if not Game.flag(fid) and mode != "guest":
			items.append({"kind": "spark", "x": float(spark_spots[i].x), "y": float(spark_spots[i].y), "idx": i, "id": fid, "ph": i, "ghost": false})
	rng.seed = 1

# closed doors are solid; recomputed every step (a fight, a boss flag)
func update_doors() -> void:
	for d in grid.doors:
		var lock: String = d.lock
		var open := true
		if lock == "fight":
			open = not fight_active
		elif lock.begins_with("until:"):
			open = Game.flag(lock.substr(6))
		if d.has("was") and d.was != open and time > 0.5:
			Audio.sfx("gate" if open else "thud")
		d.was = open
		d.open = open

func _add_platform(ch: String, tx: int, ty: int, rows: PackedStringArray) -> void:
	var x := tx * T
	var y := ty * T
	var a := x if ch == "M" else y
	var b := a
	if ch == "M":
		var row := rows[ty]
		for i in range(tx + 1, row.length()):
			if row[i] == "|":
				b = (i + 1) * T - 48
				break
		if b == a:
			for i in range(tx - 1, -1, -1):
				if row[i] == "|":
					b = i * T
					break
	else:
		for j in range(ty + 1, h):
			if tx < rows[j].length() and rows[j][tx] == "|":
				b = j * T
				break
		if b == a:
			for j in range(ty - 1, -1, -1):
				if tx < rows[j].length() and rows[j][tx] == "|":
					b = j * T
					break
	plats.append({"x": float(x), "y": float(y + 2), "w": 48.0, "h": 6.0, "ax": ch == "M", "a": a, "b": b, "ph": fposmod(tx * 0.37 + ty * 0.61, 1.0), "dx": 0.0, "dy": 0.0, "speed": def.get("platSpeed", 44.0)})

func spawn_enemy(ch: String, x: int, y: int):
	if mode == "guest":
		return null
	match ch:
		"b": return Bug.new(self, x, y, false)
		"a": return Bug.new(self, x, y, true)
		"t": return Typo.new(self, x, y)
		"G": return Guard.new(self, x, y)
		"Z": return Zombie.new(self, x, y)
	push_warning("room %s: enemy letter '%s' is not ported yet (ignored)" % [id, ch])
	return null

# the nodes that draw the room; called once after load_room. local = false: a room only the partner is in
func build_nodes(p = null, spawn = null, local := true) -> void:
	view = RoomView.new()
	view.name = "View"
	add_child(view)
	view.build(self)
	fx = Fx.new(self)
	for spec in [["furniture", 1], ["top", 4]]:
		var layer := RoomLayer.new()
		layer.room = self
		layer.kind = spec[0]
		layer.z_index = spec[1]
		add_child(layer)
		layers[spec[0]] = layer
	var ent_root := Node2D.new()
	ent_root.name = "Entities"
	ent_root.z_index = 2
	add_child(ent_root)
	entity_root = ent_root
	for e in ents:
		entity_root.add_child(e)
	if local:
		attach_local(p, spawn)
	else:
		is_local = false
		visible = false
		snap_cam()

# Clawd (the local player) enters this room: camera, placement
func attach_local(p = null, spawn = null) -> void:
	is_local = true
	visible = true
	if camera == null:
		camera = Camera2D.new()
		camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		camera.position_smoothing_enabled = false
		add_child(camera)
	camera.make_current()
	if p == null:
		p = Player.new(self, start.x, start.y)
		p.name = "Player"
	else:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		p.room = self
	if spawn != null:
		p.x = spawn.x
		p.y = spawn.y
	add_child(p)
	player = p
	crossing = false
	snap_cam()

# Clawd leaves (the partner stays): the room goes on running, hidden
func detach_local():
	var p = player
	if p != null and p.get_parent() == self:
		remove_child(p)
	player = null
	is_local = false
	visible = false
	if camera != null:
		camera.queue_free()
		camera = null
	return p

# whose position the camera / the "near the camera" rule follows
func cam_player():
	if player != null and not (player.dead and not players().is_empty()):
		return player
	if not remote_players.is_empty():
		return remote_players[0]
	return null

func reserved(tx: int, ty: int) -> bool:
	if ty < 0 or ty >= rows.size() or tx >= rows[ty].length():
		return false
	var ch := rows[ty][tx]
	return ch != " " and ch != "."

# ---------------------------------------------------------------- effects (the JS Level helpers; the work is in Fx)
func shake(a: float) -> void: fx.shake(a)
func stop(t: float) -> void: hitstop = maxf(hitstop, t)
func flash_screen(a: float, col = null) -> void: fx.flash_screen(a, col)
func part(px: float, py: float, pvx: float, pvy: float, life: float, size: float, col, grav := 0.0, o = null): return fx.part(px, py, pvx, pvy, life, size, col, grav, o)
func burst(px: float, py: float, n: int, cols, spd: float, grav := 300.0, o = null) -> void: fx.burst(px, py, n, cols, spd, grav, o)
func dust(px: float, py: float, n: int, dir := 0.0) -> void: fx.dust(px, py, n, dir)
func ring(px: float, py: float, r0: float, r1: float, col, life: float) -> void: fx.ring(px, py, r0, r1, col, life)
func pop(px: float, py: float, text: String, col = "#ffffff", big := false) -> void: fx.pop(px, py, text, col, big)
func spark(px: float, py: float, col = "#ffffff", n := 5) -> void: fx.spark(px, py, col, n)
func explode(px: float, py: float, size: float, cols = null) -> void: fx.explode(px, py, size, cols)

func drop(px: float, py: float, n: int, kind := "token") -> void:
	for i in range(n):
		items.append({"kind": kind, "id": "L%d" % next_lid, "x": px, "y": py, "vx": rng.randf_range(-70, 70), "vy": rng.randf_range(-190, -90), "loose": true, "t": 0.0, "ph": i})
		next_lid += 1

func break_tile(tx: int, ty: int) -> bool:
	if mode == "guest":
		# hidden at once, the host decides (no chain here: its `tile` events break the neighbours)
		if grid.tile(tx, ty) != TileGrid.CRACK:
			return false
		grid.tiles[ty * w + tx] = TileGrid.E
		view.erase_tile(tx, ty)
		pending_cracks["%d:%d" % [tx, ty]] = time + 1.0
		burst(tx * T + 8, ty * T + 8, 12, ["#8d8798", "#c3bccd", "#4c4658"], 90.0, 300.0)
		shake(0.3)
		Audio.sfx("brk")
		net_crack.emit(tx, ty)
		return true
	if not grid.break_tile(tx, ty):
		return false
	tile_broken.emit(tx, ty)
	view.erase_tile(tx, ty)
	Game.flags["crack:%s:%d:%d" % [id, tx, ty]] = true
	burst(tx * T + 8, ty * T + 8, 12, ["#8d8798", "#c3bccd", "#4c4658"], 90.0, 300.0)
	shake(0.3)
	Audio.sfx("brk")
	# the rest of the wall follows a moment later
	for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		if grid.tile(tx + o[0], ty + o[1]) == TileGrid.CRACK:
			break_q.append({"tx": tx + o[0], "ty": ty + o[1], "t": 0.06})
	return true

func snapshot() -> Dictionary:
	return {"cp": cp_index, "tokens": tokens, "got": got.duplicate(), "sparks": sparks.duplicate(), "clock": clock, "kills": kills, "hits": hits}

# everyone who counts for the room's mechanics: the living players
func players() -> Array:
	var out: Array = []
	if player != null and not player.dead:
		out.append(player)
	for r in remote_players:
		if not r.dead and not r.lagging:
			out.append(r)
	return out

func recent_damage(q, secs: float) -> float:
	var sum := 0.0
	for e in dmg_log:
		if e.who == q and time - e.t <= secs:
			sum += e.d
	return sum

func boss_damage(_boss, d: float) -> void:
	if attacker == null:
		return
	dmg_log.append({"t": time, "who": attacker, "d": d})
	if fight.state == "active":
		var i: int = 1 if (attacker in remote_players) else 0
		stats.hits[i] += 1

func heal(q, n: int) -> void:
	q.hp = mini(q.max_hp, q.hp + n)

# ---------------------------------------------------------------- camera
func snap_cam() -> void:
	player_cam_snap()
	var t := cam_target()
	cam.x = t[0]
	cam.y = t[1]
	if camera != null:
		camera.position = Vector2(floori(cam.x + 0.5), floori(cam.y + 0.5))

func player_cam_snap() -> void:
	var p = cam_player()
	if p == null:
		cam.ty = start.y + 10 - H * 0.64
	else:
		cam.ty = p.y + p.h - H * 0.64

func cam_target() -> Array:
	var tx: float
	var ty: float = cam.ty
	var cp = cam_player()
	if cp != null:
		tx = cp.x + cp.w / 2.0 - W / 2.0 + cam.look
	else:
		tx = start.x + 5 - W / 2.0
	if cam.lock != null:
		tx = cam.lock.x
		ty = cam.lock.y
	if pw <= W:
		tx = (pw - W) / 2.0
	else:
		tx = clampf(tx, 0.0, pw - W)
	if ph <= H:
		ty = ph - H
	else:
		ty = clampf(ty, 0.0, ph - H)
	return [tx, ty]

func update_cam(dt: float) -> void:
	var p = cam_player()
	if p == null:
		return
	cam.look = Game.damp(cam.look, p.face * 22.0 + clampf(p.vx * 0.12, -16.0, 16.0), 2.2, dt)
	var feet: float = p.y + p.h
	if p.on_ground or p.wall_dir != 0:
		cam.ty = Game.damp(cam.ty, feet - H * 0.64, 5.0, dt)
	var sy: float = feet - cam.ty               # feet in screen space if the camera were at the target
	if sy < 56.0:
		cam.ty = feet - 56.0
	elif sy > H - 44.0:
		cam.ty = feet - (H - 44.0)
	var t := cam_target()
	cam.x = Game.damp(cam.x, t[0], 8.0, dt)
	cam.y = Game.damp(cam.y, t[1], 9.0 if absf(t[1] - cam.y) > 60.0 else 5.0, dt)

# the camera node follows cam plus the trauma shake; runs every rendered frame
func _process(_dt: float) -> void:
	if camera == null or fx == null:
		return
	var amp := fx.trauma * fx.trauma * 7.0 * Game.shake_opt
	camera.position = Vector2(floori(cam.x + (randf() * 2.0 - 1.0) * amp + 0.5), floori(cam.y + (randf() * 2.0 - 1.0) * amp + 0.5))
	for k in layers:
		layers[k].queue_redraw()

# ---------------------------------------------------------------- the guest's room: only its own body is simulated
func step_guest(dt: float) -> void:
	update_doors()
	fx.decay(dt)
	if hitstop > 0.0:
		hitstop -= dt
		return
	time += dt
	_move_platforms()
	var p = player
	if p != null:
		p.update(dt)
		_check_door()
		if not p.dead and not p.gone:
			interact_combat(p)
			interact_goals(p)
			# damage areas the host announced (blasts, the slam): checked on this body, once each
			var hb: Dictionary = p.hurtbox()
			for z in zones:
				if zones_hit.has(z.id):
					continue
				var hit_z := false
				if z.kind == "c":
					var cxp: float = clampf(z.x, hb.x, hb.x + hb.w)
					var cyp: float = clampf(z.y, hb.y, hb.y + hb.h)
					hit_z = Vector2(cxp - z.x, cyp - z.y).length() < z.a
				else:
					hit_z = Game.overlap(hb, {"x": z.x, "y": z.y, "w": z.a, "h": z.b})
				if hit_z:
					zones_hit[z.id] = true
					p.hurt(z.dmg, z.x)
			# pick things up: ask the host once per item
			var pcx: float = p.x + p.w / 2.0
			var pcy: float = p.y + p.h / 2.0
			for it in items:                # (asked again after 0.6 s: a refused request must not lose the item for good)
				if time - float(it.get("asked", -10.0)) < 0.6 or it.get("dead", false):
					continue
				var rr := 11.0 if it.kind == "spark" else 9.0
				if absf(pcx - it.x) < rr + 3 and absf(pcy - it.y) < rr and (not it.get("loose", false) or it.get("t", 1.0) > 0.2):
					it.asked = time
					net_pickup.emit(it.id)
	update_projs(dt)
	for s2 in springs:
		if s2.t > 0.0:
			s2.t -= dt
	fx.step(dt)
	# a crack the host never confirmed comes back
	for k in pending_cracks.keys():
		if time > pending_cracks[k]:
			var parts: PackedStringArray = String(k).split(":")
			var tx := int(parts[0])
			var ty := int(parts[1])
			pending_cracks.erase(k)
			if not Game.flag("crack:%s:%d:%d" % [id, tx, ty]):
				grid.tiles[ty * w + tx] = TileGrid.CRACK
				view.dynamic.set_cell(Vector2i(tx, ty), 0, Vector2i(2, 5))
	if cam.lock == null:
		update_cam(dt)
	else:
		cam.x = Game.damp(cam.x, cam.lock.x, 8.0, dt)
		cam.y = Game.damp(cam.y, cam.lock.y, 8.0, dt)
	for ev in events:
		if ev == "death":
			local_died.emit()
	events.clear()

# the host confirmed a broken tile (or the guest's own request came through)
func apply_tile(tx: int, ty: int) -> void:
	pending_cracks.erase("%d:%d" % [tx, ty])
	Game.flags["crack:%s:%d:%d" % [id, tx, ty]] = true
	if grid.tile(tx, ty) == TileGrid.CRACK:
		grid.tiles[ty * w + tx] = TileGrid.E
		view.erase_tile(tx, ty)
		burst(tx * T + 8, ty * T + 8, 12, ["#8d8798", "#c3bccd", "#4c4658"], 90.0, 300.0)
		shake(0.3)
		Audio.sfx("brk")
	elif grid.tile(tx, ty) == TileGrid.E:
		view.erase_tile(tx, ty)

# ---------------------------------------------------------------- simulation (js: Level.update, same order)
func _move_platforms() -> void:
	for m in plats:
		var span := absf(m.b - m.a)
		if span < 1.0:
			m.dx = 0.0
			m.dy = 0.0
			continue
		var period: float = (span / m.speed) * 2.0
		var u := 0.5 - 0.5 * cos(fposmod(time / period + m.ph, 1.0) * PI * 2.0)
		var v := lerpf(m.a, m.b, u)
		if m.ax:
			m.dx = v - m.x
			m.dy = 0.0
			m.x = v
		else:
			m.dy = v + 2.0 - m.y
			m.dx = 0.0
			m.y = v + 2.0

func _check_door() -> void:
	var p = player
	if p == null or p.dead or crossing:
		return
	var mid_x: float = p.x + p.w / 2.0
	var row := floori((p.y + p.h / 2.0) / T)
	var side := ""
	if mid_x < 0.0:
		side = "W"
	elif mid_x > pw:
		side = "E"
	if side != "":
		var d = grid.door_at(side, row)
		if d != null and d.open:
			crossing = true
			door_crossed.emit(d)

func step(dt: float) -> void:
	if mode == "guest":
		step_guest(dt)
		return
	update_doors()
	fx.decay(dt)
	if hitstop > 0.0:
		hitstop -= dt
		return
	time += dt
	var p = player                       # null in a room only the partner is in
	var live := players()
	if p != null and not p.dead:
		clock += dt

	# blinking blocks
	var ph_ := floori(time / blink_period) % 2
	if ph_ != grid.blink_phase:
		grid.blink_phase = ph_
		var want := TileGrid.BLINK_A if ph_ == 0 else TileGrid.BLINK_B
		for q in live:
			for ty in range(floori(q.y / T), floori((q.y + q.h) / T) + 1):
				for tx in range(floori(q.x / T), floori((q.x + q.w) / T) + 1):
					if grid.tile(tx, ty) == want:
						grid.blink_hold[ty * w + tx] = true
	if not grid.blink_hold.is_empty():
		for i in grid.blink_hold.keys():
			if not grid.any_on(live, i % w, i / w):
				grid.blink_hold.erase(i)
	# crumbling blocks
	for i in grid.crumble.keys():
		var c: Dictionary = grid.crumble[i]
		c.t -= dt
		if c.t > 0.0:
			continue
		var tx2: int = i % w
		var ty2: int = i / w
		if c.s == 1:
			c.s = 2
			c.t = 2.6
			burst(tx2 * T + 8, ty2 * T + 4, 7, ["#cbb894", "#8a7a5c"], 50.0, 260.0)
			Audio.sfx("crumble")
		elif c.s == 2:
			if grid.any_on(live, tx2, ty2):
				c.t = 0.2
			else:
				grid.crumble.erase(i)
				dust(tx2 * T + 8, ty2 * T + 8, 4)
	if not break_q.is_empty():
		for q in break_q:
			q.t -= dt
			if q.t <= 0.0:
				q.done = true
				break_tile(q.tx, q.ty)
		break_q = break_q.filter(func(q): return not q.get("done", false))
	_move_platforms()

	if p != null:
		p.update(dt)
	_check_door()

	# creatures (only the ones near a player think)
	var cx: float = cam.x
	var cy: float = cam.y
	for e in ents:
		if e.dead:
			continue
		if e.always or _near_a_player(e, cx, cy):
			e.update(dt)
	if remote_players.size() > 0:
		record_hist()
	interact()
	update_items(dt)
	update_projs(dt)
	for s in springs:
		if s.t > 0.0:
			s.t -= dt
	fx.step(dt)
	# tidy
	var any_dead := false
	for e in ents:
		if e.dead:
			any_dead = true
			break
	if any_dead:
		var keep: Array = []
		for e in ents:
			if e.dead:
				e.queue_free()
			else:
				keep.append(e)
		ents = keep
	_step_fight(dt)
	if cam.lock == null:
		update_cam(dt)
	else:
		cam.x = Game.damp(cam.x, cam.lock.x, 8.0, dt)
		cam.y = Game.damp(cam.y, cam.lock.y, 8.0, dt)
	for z in zones:
		z.until -= dt
	zones = zones.filter(func(z): return z.until > 0.0)
	for ev in events:
		if ev == "death" and mode == "solo" and death_t < 0.0:
			death_t = 1.2
		elif ev == "death":
			local_died.emit()
		elif ev == "bossDying":
			for q in players():
				q.inv = 99.0
		elif ev == "bossDead":
			_start_reward()
	events.clear()
	if stats_t > 0.0:
		stats_t -= dt
	if death_t >= 0.0:
		death_t -= dt
		if death_t < 0.0:
			death_t = -1.0
			restart_requested.emit(snapshot())

# ---------------------------------------------------------------- boss fight flow (MV2-06)
func _step_fight(dt: float) -> void:
	if boss == null:
		return
	var trigger: float = float(def.boss.trigger_x)
	match String(fight.state):
		"none":
			for q in players():
				if q.x + q.w / 2.0 > trigger:
					_start_intro()
					break
		"intro":
			fight.t -= dt
			summon_t += dt
			if fight.t <= 0.0 and summon_ready():
				_begin_fight()
		"active":
			if stats.has("secs"):
				stats.secs += dt
		"reward":
			fight.t -= dt
			banner.t = fight.t
			if fight.t <= 0.0:
				_finish_reward()

# co-op overrides this: the partner has to be in the arena (or 5 s have passed)
func summon_ready() -> bool:
	return summon_ok or summon_t >= 5.0

func _start_intro() -> void:
	fight.state = "intro"
	fight.t = 1.5
	summon_t = 0.0
	summon_ok = true
	fight_active = true
	cam.lock = {"x": (pw - W) / 2.0, "y": float(ph - H)}
	for q in players():
		q.frozen = true
	Audio.sfx("roar")                      # (the music follows fight.state: Main.song_for)
	events.append("bossIntro")
	fight_intro.emit()

func _begin_fight() -> void:
	fight.state = "active"
	var ps := players()
	for q in ps:
		q.frozen = false
	if ps.size() >= 2:                                   # both are in the arena: the co-op factor applies
		var k := 1.0 + float(Game.coop_hp_pct) / 100.0
		boss.max_hp = roundi(boss.max_hp * k)
		boss.hpf = float(boss.max_hp)
		boss.hp = boss.max_hp
	stats = {"secs": 0.0, "hits": [0, 0], "dmg": [0, 0], "coop": ps.size() >= 2}
	boss.start()
	events.append("bossStart")

func on_player_hurt(q, d: int) -> void:
	Game.dlog("%s hurt %d (hp %d) in %s%s" % ["P2" if q.get("is_remote") or mode == "guest" else "P1", d, q.hp, id, " fight" if fight.state == "active" else ""])
	if mode == "guest":
		net_hurt.emit(d)
		return
	if fight.state == "active":
		var i: int = 1 if (q in remote_players) else 0
		stats.dmg[i] += d

func _start_reward() -> void:
	fight.state = "reward"
	fight.t = 3.0
	Audio.sfx("kill")
	for q in players():
		q.frozen = true
	banner = {"text": "bash", "sub": "dash in any direction - breaks cracked % walls", "t": 3.0}
	# the fight statistics (to tune boss HP with real numbers)
	var np: int = 2 if stats.coop else 1
	var secs: float = maxf(stats.secs, 0.001)
	var r: float = float(stats.hits[0] + stats.hits[1]) / np / secs
	stats_line = "NULL %ds - P1 %d hits" % [roundi(secs), stats.hits[0]]
	if stats.coop:
		stats_line += " - P2 %d hits" % stats.hits[1]
	stats_line += " - r %.2f/s - won" % r
	stats_t = 15.0                                   # long enough to read (and screenshot); it is also in the debug log
	Game.dlog(stats_line + " | damage taken P1 %d P2 %d" % [stats.dmg[0], stats.dmg[1]])
	Game.fights.append({"boss": "NULL", "secs": snappedf(secs, 0.1), "hits": stats.hits.duplicate(), "dmg_taken": stats.dmg.duplicate(), "won": true, "diff": Game.diff, "coop": stats.coop})

func record_loss() -> void:
	if fight.state == "active":
		Game.fights.append({"boss": "NULL", "secs": snappedf(stats.secs, 0.1), "hits": stats.hits.duplicate(), "dmg_taken": stats.dmg.duplicate(), "won": false, "diff": Game.diff, "coop": stats.coop})
		Game.write_save()

func _finish_reward() -> void:
	Game.tools.bash = true
	Game.flags["ability:bash"] = true
	Game.flags["boss:NULL"] = true
	fight.state = "done"
	fight_active = false
	cam.lock = null
	for q in players():
		q.frozen = false
	boss = null
	banner.text = ""
	Game.write_save()
	update_doors()

func _near_a_player(e, cx: float, cy: float) -> bool:
	if player != null and e.x + e.w > cx - 90 and e.x < cx + W + 90 and e.y + e.h > cy - 110 and e.y < cy + H + 110:
		return true
	for r in remote_players:
		if e.x + e.w > r.x - W / 2.0 - 90 and e.x < r.x + W / 2.0 + 90 and e.y + e.h > r.y - H / 2.0 - 110 and e.y < r.y + H / 2.0 + 110:
			return true
	return false

# one second of every creature's hurtboxes (the guest's hit check looks back in time)
func record_hist() -> void:
	for e in ents:
		if e.dead or e.nid == 0:
			continue
		var h_: Array = hist.get(e.nid, [])
		var boxes: Array = []
		for b in e.hurtboxes():
			boxes.append({"x": b.x, "y": b.y, "w": b.w, "h": b.h})
		h_.append([time, boxes])
		while h_.size() > 0 and time - h_[0][0] > 1.0:
			h_.pop_front()
		hist[e.nid] = h_

# a short-lived damage area the guest checks against its own body: kind "c" circle (x, y, r), "r" rectangle (x, y, w, h)
func harm_zone(kind: String, zx: float, zy: float, za: float, zb: float, dmg: int) -> void:
	zones.append({"id": next_zone, "kind": kind, "x": zx, "y": zy, "a": za, "b": zb, "dmg": dmg, "until": 0.25})
	next_zone += 1

func interact() -> void:
	var p = player
	if p == null or p.dead or p.gone:
		return
	interact_combat(p)
	interact_goals(p)

# what is under a player's feet that hurts: "" , "spike" , "liq" or "pit"
func hazard_at(p) -> String:
	var x0 := floori((p.x + 1) / T)
	var x1 := floori((p.x + p.w - 1) / T)
	var y0 := floori((p.y + 1) / T)
	var y1 := floori((p.y + p.h - 1) / T)
	var hz := ""
	for ty in range(y0, y1 + 1):
		if hz != "":
			break
		for tx in range(x0, x1 + 1):
			var t := grid.tile(tx, ty)
			if t == TileGrid.SPIKE_U:
				if p.y + p.h > ty * T + 9 and p.x + p.w > tx * T + 2 and p.x < tx * T + 14:
					hz = "spike"
			elif t == TileGrid.SPIKE_D:
				if p.y < ty * T + 7 and p.x + p.w > tx * T + 2 and p.x < tx * T + 14:
					hz = "spike"
			elif t == TileGrid.LIQ:
				if p.y + p.h > ty * T + 6:
					hz = "liq"
	if p.y > ph + 24:
		hz = "pit"
	return hz

# solo / host: the creature takes the hit. Guest: only sparks and sound here, the host decides (announced with net_hit)
func _hit_entity(e, d: int, dx: float, dy: float, how: String, b) -> String:
	if mode != "guest":
		return e.hit(d, dx, dy, how, b)
	var res := "hit"
	if e.has_method("blocks") and e.blocks(dx, dy, how):
		res = "block"
	var p = player
	if how == "stomp":
		stomp_n += 1
	var atk_val: int = p.dash_id if how == "dash" else (stomp_n if how == "stomp" else p.atk_id)
	net_hit.emit(e.nid, how, d, dx, dy, atk_val)
	# predict the outcome, as the JS game does: a creature this hit kills can no longer hurt me or be hit again, although the
	# host's word of its death is a round trip away (the guess expires after 1 s if the host disagrees)
	var base: int = int(e.get_meta("ph", e.hp)) if float(e.get_meta("ph_t", -1.0)) > time else e.hp
	if not e.get("is_boss"):
		e.set_meta("ph", base - d)
		e.set_meta("ph_t", time + 1.0)
		if base - d <= 0:
			e.set_meta("pdead", time + 1.0)
	if res == "hit" and base - d <= 0:        # the host will kill it: the dash must not cost the guest hp (as solo)
		res = "kill"
	if res == "hit":
		Audio.sfx("hit")
	return res

func pred_dead(e) -> bool:
	return mode == "guest" and float(e.get_meta("pdead", -1.0)) > time

func interact_combat(p) -> void:
	# claw
	if p.atk_t > 0.0 and p.atk_live:
		var box: Dictionary = p.atk_box()
		for e in ents:
			if e.dead or e.marks.get(p.hit_key, 0) == p.atk_id or e.no_hit or pred_dead(e):
				continue
			for b in e.hurtboxes():
				if not Game.overlap(box, b):
					continue
				e.marks[p.hit_key] = p.atk_id
				attacker = p
				var res: String = _hit_entity(e, p.atk_dmg, p.atk_face if p.atk_dir == "f" else 0.0, -1.0 if p.atk_dir == "u" else (1.0 if p.atk_dir == "d" else 0.0), "swipe", b)
				if res != "":
					p.on_hit(e, res, b)
				break
		for q in projs:
			if q.dead or not q.cut or q.get("friendly", false):
				continue
			if q.x + q.r > box.x and q.x - q.r < box.x + box.w and q.y + q.r > box.y and q.y - q.r < box.y + box.h:
				q.dead = true
				if mode == "guest":
					net_projhit.emit(q.id)
				spark(q.x, q.y, q.col, 6)
				Audio.sfx("clang")
				stop(0.03)
				if p.atk_dir == "d":
					p.bounce(0.85)
		for s in springs:
			if p.atk_dir == "d" and Game.overlap(box, s):
				p.spring(s)
	# touching
	var hb: Dictionary = p.hurtbox()
	for e in ents:
		if e.dead or pred_dead(e):
			continue
		for b in e.harmboxes():
			if not Game.overlap(hb, b):
				continue
			if e.passive:                       # a corpse hurts nobody, but a stomp still finishes it
				if e.stompable and p.vy > 30.0 and p.prev_bottom <= b.y + minf(8.0, b.h * 0.6):
					var res4: String = _hit_entity(e, maxi(1, e.hp), 0.0, 1.0, "stomp", b)
					p.y = b.y - p.h
					p.bounce(1.0)
					p.gain_meter()
					if res4 != "":
						stop(0.05)
				break
			if p.dash_t > 0.0 and e.dashable:
				if e.marks.get(p.dash_key, 0) != p.dash_id:
					e.marks[p.dash_key] = p.dash_id
					attacker = p
					var res2: String = _hit_entity(e, 1, p.dash_dx if p.dash_dx != 0.0 else p.face, 0.0, "dash", b)
					if res2 != "":
						stop(0.05)
						shake(0.2)
					if res2 != "kill":                 # a dash is no shield: unless it has i-frames (easy), the contact hurts
						p.hurt(e.dmg, b.x + b.w / 2.0)

			elif e.stompable and p.vy > 30.0 and p.prev_bottom <= b.y + minf(8.0, b.h * 0.6):
				var res3: String = _hit_entity(e, maxi(1, e.hp), 0.0, 1.0, "stomp", b)       # a stomp always kills in one hit
				p.y = b.y - p.h
				p.bounce(1.0)
				p.gain_meter()
				if res3 != "":
					stop(0.05)
			elif p.grace <= 0.0 and not (lenient and e.get_meta("ex", false)):
				p.hurt(e.dmg, b.x + b.w / 2.0)
			break
	# spikes, liquid, pits
	var hz := hazard_at(p)
	if hz != "":
		p.hazard()
	# springs
	for s in springs:
		if p.vy >= 0.0 and Game.overlap(hb, s) and p.dash_t <= 0.0:
			p.spring(s)

func interact_goals(p) -> void:
	if p.on_ground and not crossing and Game.bench != id and p.hp > 0:     # the guest too: its own respawn point (the host is told)
		for i in range(cps.size()):         # walking up to a bench is enough to make it the respawn point
			var c0: Dictionary = cps[i]
			if absf(p.x + p.w / 2.0 - c0.x) < 12 and p.y + p.h > c0.y - 34 and p.y < c0.y:
				bench_touched.emit(i)
				break
	if Controls.pressed.get("up", false) and p.on_ground and not crossing:
		for i in range(cps.size()):
			var c: Dictionary = cps[i]
			if absf(p.x + p.w / 2.0 - c.x) < 12 and p.y + p.h > c.y - 34 and p.y < c.y:
				bench_requested.emit(i)
				break
	if end_door != null and Controls.pressed.get("up", false) and p.on_ground:
		if absf(p.x + p.w / 2.0 - end_door.x) < 14 and absf(p.y + p.h - end_door.y) < 20:
			end_requested.emit()
	sign_now = null
	for s in signs:
		if absf(p.x + p.w / 2.0 - s.x) < 26 and absf(p.y + p.h - s.y) < 30:
			sign_now = s

func update_items(dt: float) -> void:
	var p = player                      # may be null: then the partner picks things up (through the network)
	var live := players()
	for it in items:
		if it.get("dead", false):
			continue
		if it.get("loose", false):
			it.t += dt
			if it.t > 0.35 and not live.is_empty():       # drawn to the nearest living Clawd
				var tg = live[0]
				for q in live:
					if Vector2(q.x - it.x, q.y - it.y).length() < Vector2(tg.x - it.x, tg.y - it.y).length():
						tg = q
				var dx: float = tg.x + tg.w / 2.0 - it.x
				var dy: float = tg.y + tg.h / 2.0 - it.y
				var dd := sqrt(dx * dx + dy * dy)
				var d := dd if dd != 0.0 else 1.0
				var pull := minf(700.0, 160.0 + it.t * 500.0)
				it.vx = Game.damp(it.vx, (dx / d) * pull, 8.0, dt)
				it.vy = Game.damp(it.vy, (dy / d) * pull, 8.0, dt)
			else:
				it.vy += 520.0 * dt
				if it.vy > 0.0 and grid.solid_at(it.x, it.y + 4):
					it.vy *= -0.5
					it.vx *= 0.7
			it.x += it.vx * dt
			it.y += it.vy * dt
			if it.t > 8.0:
				it.dead = true
		var r := 11.0 if it.kind == "spark" else 9.0
		if p != null and not p.dead and not p.gone:
			var pcx: float = p.x + p.w / 2.0
			var pcy: float = p.y + p.h / 2.0
			if absf(pcx - it.x) < r + 3 and absf(pcy - it.y) < r and (not it.get("loose", false) or it.t > 0.2):
				collect(it)
	if items.size() > 40:
		var any := false
		for it in items:
			if it.get("dead", false):
				any = true
				break
		if any:
			items = items.filter(func(i): return not i.get("dead", false))

func collect(it: Dictionary) -> void:
	var p = player
	it.dead = true
	item_collected.emit(String(it.get("id", "")), String(it.kind))
	if it.has("id") and not String(it.id).begins_with("L"):
		got[it.id] = true
		Game.flags[it.id] = true
	match it.kind:
		"token":
			tokens += 1
			spark(it.x, it.y, Game.COL.goldHi, 4)
			Audio.sfx("token")
		"spark":                            # a memory fragment: 4 of them give +1 max hp
			Game.fragments += 1
			ring(it.x, it.y, 2, 30, Game.COL.clawdHi, 0.5)
			burst(it.x, it.y, 18, [Game.COL.clawd, Game.COL.clawdHi, "#fff3e4"], 130.0, 60.0, {"glow": 1})
			pop(it.x, it.y - 12, "memory chip ✳ %d/4" % ((Game.fragments - 1) % 4 + 1), "#fff3e4", true)
			stop(0.07)
			Audio.sfx("spark")
			if Game.fragments % 4 == 0:
				p.max_hp = Game.max_hp
				p.hp = p.max_hp
				pop(it.x, it.y - 26, "+1 max hp", Game.COL.okHi, true)
			Game.write_save()
			events.append("spark")
		"coffee":
			if Game.diff == "easy" and p.hp < p.max_hp:
				heal(p, 1)
			pop(it.x, it.y - 10, "+1 coffee", Game.COL.paper)
			burst(it.x, it.y, 8, [Game.COL.paper, Game.COL.clawd], 70.0, 100.0)
			Audio.sfx("heal")

# hostile projectile. kinds: orb, shard
func shoot(px: float, py: float, pvx: float, pvy: float, o = null) -> Dictionary:
	var q := {"id": next_pid, "x": px, "y": py, "vx": pvx, "vy": pvy, "r": 3.0, "kind": "orb", "col": Game.COL.hazard, "life": 4.0, "g": 0.0, "dmg": 1, "tile": true, "cut": true, "t": 0.0, "dead": false}
	if o != null:
		for k in o:
			q[k] = o[k]
	next_pid += 1
	projs.append(q)
	return q

func update_projs(dt: float) -> void:
	var p = player
	for q in projs:
		if q.dead:
			continue
		q.t += dt
		q.life -= dt
		q.vy += q.g * dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		if q.life <= 0.0 or q.y > ph + 60 or q.x < -60 or q.x > pw + 60:
			q.dead = true
			continue
		if q.tile and mode != "guest" and grid.solid_at(q.x, q.y):
			q.dead = true
			spark(q.x, q.y, q.col, 4)
			continue
		for pl in players():
			if pl.get("is_remote"):
				continue                         # the partner checks its own body
			var hb: Dictionary = pl.hurtbox()
			if not q.get("friendly", false) and not pl.gone and q.x + q.r > hb.x and q.x - q.r < hb.x + hb.w and q.y + q.r > hb.y and q.y - q.r < hb.y + hb.h:
				if pl.dash_t > 0.0 and Game.dv("dash_iframes"):
					continue
				if pl.hurt(q.dmg, q.x) and not q.get("pierce", false):
					q.dead = true
					if mode == "guest":
						net_projhit.emit(q.id)
					spark(q.x, q.y, q.col, 5)
					break
	if projs.size() > 30:
		projs = projs.filter(func(q): return not q.dead)

func _draw_proj(ci: CanvasItem, q: Dictionary) -> void:
	var px := floori(q.x + 0.5)
	var py := floori(q.y + 0.5)
	var ink := Color(Game.COL.ink)
	var col := Color(q.col)
	match q.kind:
		"shard", "plus", "minus":
			var minus: bool = q.kind == "minus"
			ci.draw_rect(Rect2(px - 3, py - 1 - (0 if minus else 2), 7, 3 if minus else 7), ink)
			if not minus:
				ci.draw_rect(Rect2(px - 3, py - 1, 7, 3), ink)
			ci.draw_rect(Rect2(px - 2, py, 5, 1), col)
			if not minus:
				ci.draw_rect(Rect2(px, py - 2, 1, 5), col)
		_:
			Fx._disc(ci, px, py, q.r + 1, ink)
			Fx._disc(ci, px, py, q.r, col)
			Fx._disc(ci, px - 1, py - 1, maxf(0.5, q.r - 2), Color.WHITE)

# ---------------------------------------------------------------- drawing of what is not an entity
func draw_layer(kind: String, ci: CanvasItem) -> void:
	if kind == "furniture":
		# closed doors: a gate column just inside the edge so the player sees why it is closed
		var gate := Gfx.tex("gate")
		for d in grid.doors:
			if d.open:
				continue
			var gx := 0 if d.side == "W" else pw - T
			for ty in range(d.a, d.b + 1):
				ci.draw_texture_rect_region(gate, Rect2(gx, ty * T, T, T), Rect2(7, 12, 16, 16))
		for m in plats:
			ci.draw_texture(Gfx.tex("platform_48"), Vector2(floori(m.x + 0.5), floori(m.y + 0.5) - 1))
		for c in cps:
			ci.draw_texture(Gfx.tex("checkpoint_%d" % (1 if c.on else 0)), Vector2(c.x - 8, c.y - 28))
		for s in signs:
			ci.draw_texture(Gfx.tex("sign"), Vector2(s.x - 8, s.y - 18))
		for s in springs:
			ci.draw_texture(Gfx.tex("spring_%d" % (0 if s.t > 0.0 else 1)), Vector2(s.x - 2, s.y - 7))
		for it in items:
			if it.get("dead", false):
				continue
			var bob := 0 if it.get("loose", false) else floori(sin(time * 3.0 + it.ph) * 1.5 + 0.5)
			var ix := floori(it.x + 0.5)
			var iy := floori(it.y + 0.5) + bob
			match it.kind:
				"token":
					ci.draw_texture(Gfx.tex("token_%d" % (int(time * 7.0 + it.ph * 2.0) % 4)), Vector2(ix - 4, iy - 4))
				"spark":
					var f := int(time * 3.0) % 2
					ci.draw_texture(Gfx.tex(("sparkGhost_%d" if it.ghost else "spark_%d") % f), Vector2(ix - 7, iy - 7))
				"coffee":
					ci.draw_texture(Gfx.tex("coffee"), Vector2(ix - 6, iy - 7))
	elif kind == "top":
		for q in projs:
			if not q.dead:
				_draw_proj(ci, q)
		fx.draw(ci)
		if fx.flash > 0.0:
			var c := fx.flash_col
			c.a = minf(1.0, fx.flash)
			ci.draw_rect(Rect2(camera.position, Vector2(W, H)), c)
