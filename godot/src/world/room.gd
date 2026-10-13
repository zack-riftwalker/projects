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
var packet_paths: Array = []        # per `J`: {xa, xb, y, n, every, speed, w} (packets are platforms in `plats`, flagged `packet`)
var port_cols: Array = []           # per port column: {tx, ty0, ty1, idx} (idx = its number in the column order)
var variants_on := {}               # variant index -> true once its flag was seen (its cells are queued)
var variant_q: Array = []           # cells still to change: {tx, ty, t} (a tile must never appear inside a body or vanish under one)
var auto_step := false
var rng := RandomNumberGenerator.new()
var cam := {"x": 0.0, "y": 0.0, "ty": 0.0, "look": 0.0, "lock": null}
var fx: Fx
var view: RoomView
var camera: Camera2D
var layers := {}
var liquid_y = null
var rise_armed := false         # a player has been below the trigger row: only then does climbing past it start the flood (coming in from the top door must not)
var rise_on := false            # H06: the flood is rising (it started when somebody climbed past the trigger row)
var lq_last := -9.0            # host: when a guest's `lqhit` last pushed the tide back (one push per 0.5 s)
var blink_period := 1.5
var tower: Tower = null                    # world 4: gears, pistons, mutex gates, cables and the tick's blink blocks (MV5A-03)
var iter := 0                              # T09's loop room: which pass this is (0..3)
var bp_plats: Array = []                    # frozen creatures as one-way platforms (rebuilt every step)
var loop_key = null                        # T09: the `break;` key cell {x, y, w, h} (null in other rooms)
var land_t := 0.0                          # boss trigger "land": how long somebody has stood on the arena floor
var last_tick := -1                        # world 4: the tick the last sound was made for
const TICK := Tower.TICK
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
var ch_t0 := -1.0                           # N17's RST chase (rooms.json `chase`): the room time it started (-1: not running). Host decides; the guest gets it in the snapshot (`ch`)
var ch_seen := -1.0
var ch_prev := -1.0
var ch_fade_y := 0.0
var ch_fade := 0.0                          # > 0: the line fades after the chase ended
var next_swarm := 0                        # DDOS swarms made in this room (host): their round robin runs inside each
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
signal net_reveal
signal net_lqhit
signal plugin_got(plugin_id: String, by: String)
signal net_agents
signal net_buy(plugin_id: String)
signal net_buymap(zone_id: String)
signal shop_requested
signal index_requested(npc_index: int)
signal net_lever(lever_index: int)
signal net_mutex(key_index: int)
signal net_bp(kind: String, id)
signal net_cable(tx: int, ty: int)
signal net_pad()
signal net_freejar(jar_index: int)
signal net_crumble(tx: int, ty: int)
signal net_catch(pid: int)
signal net_parry(nid: int, sid: int)
var tags := {"p1": 0.0, "p2": 0.0}         # SPYWARE's tag (MVB3-02): seconds left per player key (p1 = the host's player, p2 = the guest's), host; the guest follows the snapshot
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
var memory := {"text": "", "t": 0.0}                       # the line of the memory fragment just picked up (the HUD shows it for a few seconds)
var pick_banner := {"text": "", "sub": "", "t": 0.0}      # "<plugin>" / "plugin - equip it at a bench" for 2 s
var agents: Array = []         # the helpers of every player in this room (host / solo simulate them all)
var agent_view: Array = []     # guest: [{owner, x, y, t}] as the host's snapshot lists them
var keys: Array = []           # slot keys (letter k): {x, y, w, h, i}; only agents can press them
var shops: Array = []          # npm registry stalls (letter $): {x (centre), y (bottom)}
var jars: Array = []           # lost agents' jars (rooms.json `agents`): {x, y (bottom centre), broken, fly, asked, t}
var decor_items: Array = []    # rooms.json `decor`: {kind, x, y (px, bottom centre), if?, lit?, fall_y?}
var npcs: Array = []           # the cartographer `tree` (rooms.json `npc`): {kind, x (centre), y (feet), zone, price, ...look state}
var stations: Array = []       # cache stations (letter R): {x, y, w, h}
var switches: Array = []       # catch switches (letter Y): {x, y, w, h, i}; pressed = flag switch:<room>:<i>
var dead_cells: Array = []     # [tx, ty] of the dead code (`;`): wall to look at, air to walk through
var dead_groups: Array = []    # the pixel centres of its 4-connected groups (moths, the reveal burst)
var fire_cells: Array = []     # firewall bricks (`N`) and bulkheads (`0`), drawn by the furniture layer
var thick_cells: Array = []
var webs: Array = []           # [tx, ty] of every `h` (drawn while the tile is still a web)
var levers: Array = []         # `I`: {x, y, i}; lever i sets def.levers[i].flag (MVB2-05)
var wave_i := -1               # the honeypot (rooms.json `wave`): which wave is running (-1: none yet), host and solo only
var wave_t := 1.0
var wave_ents: Array = []
var sight_t := -1.0            # N08: the crawler's silhouette passes (seconds into its walk; -1 = not now)
var hooks: Array = []          # `c`: {x, y} centres; a SCRAPER hangs from each until boss:CRAWLER, then it is a GET ring (MVB2-05)
var rings: Array = []          # GET rings (`@`): decoration in 4A
var gate_cells: Array = []     # [tx, ty, "catch"|"agents"]: where a gate tile stands (drawn while it is closed)
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
var world := 1

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
	world = int(def.get("world", 1))
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
		grid.doors.append({"id": d.id, "side": d.side, "a": int(d.a), "b": int(d.b), "to": d.to, "lock": d.get("lock", ""), "sets": d.get("sets", ""), "wrap": bool(d.get("wrap", false)), "open": true})
	update_doors()
	var sign_n := 0
	var item_id := 0
	var switch_n := 0
	var plugin_n := 0
	var key_n := 0
	var spark_spots: Array = []
	for ty in range(h):
		var row := rows[ty]
		for tx in range(row.length()):
			var ch := row[tx]
			var x := tx * T
			var y := ty * T
			if TileGrid.CHARS.has(ch):
				var t: int = TileGrid.CHARS[ch]
				if (t == TileGrid.CRACK or t == TileGrid.THICK) and Game.flag("crack:%s:%d:%d" % [id, tx, ty]):
					t = TileGrid.E
				grid.tiles[ty * w + tx] = t
				if t == TileGrid.WEB:
					webs.append([tx, ty])
				if t == TileGrid.DEAD:
					dead_cells.append([tx, ty])
				elif t == TileGrid.FIRE:
					fire_cells.append([tx, ty])
				elif t == TileGrid.THICK:
					thick_cells.append([tx, ty])
				if t == TileGrid.GATE_C or t == TileGrid.GATE_A:
					gate_cells.append([tx, ty, "catch" if t == TileGrid.GATE_C else "agents"])
				continue
			match ch:
				" ", ".", "|", "O", "A", "Q":        # (the tower's machines are read by Tower from rooms.json; Q is only the key's look)
					pass
				"P":
					start = {"x": float(x + 3), "y": float(y + 6)}
				"C":
					cps.append({"x": x + 8, "y": y + T, "on": Game.flag("bench:" + id), "tx": tx})
				"U":
					var plist: Array = def.get("plugins", [])
					if plugin_n < plist.size():
						var pid := String(plist[plugin_n])
						if not Game.owns_plugin(pid) and mode != "guest":
							items.append({"kind": "plugin", "x": float(x + 8), "y": float(y + 8), "id": "plugin:" + pid, "ph": float(plugin_n)})
					plugin_n += 1
				"k":
					keys.append({"x": float(x + 3), "y": float(y + 3), "w": 10.0, "h": 10.0, "i": key_n})
					key_n += 1
				"$":
					shops.append({"x": float(x + 8), "y": float(y + T)})
				"R":
					stations.append({"x": float(x + 2), "y": float(y), "w": 12.0, "h": 16.0})
				"Y":
					switches.append({"x": float(x + 3), "y": float(y + 3), "w": 10.0, "h": 10.0, "i": switch_n})
					switch_n += 1
				"@", "j":
					rings.append({"x": x + 8, "y": y + 8})
					if ch == "j" and mode != "guest":                 # a SNIFFER taps this ring
						var sn := Sniffer.new(self, x, y, rings.size() - 1)
						Game.scale_enemy(sn)
						sn.nid = next_nid
						next_nid += 1
						ents.append(sn)
				"c":
					hooks.append({"x": x + 8, "y": y + 8})
					var sce = spawn_enemy("c", x, y)
					if sce != null and not Game.flag("boss:CRAWLER"):
						Game.scale_enemy(sce)
						sce.nid = next_nid
						next_nid += 1
						ents.append(sce)
				"F":
					loop_key = {"x": float(x), "y": float(y), "w": 16.0, "h": 16.0}
				"I":
					levers.append({"x": x, "y": y, "i": levers.size()})
				"z":
					spawn_ddos(float(x), float(y))
				"W":
					grid.tiles[ty * w + tx] = TileGrid.FIRE                # a worm lives in a brick
					fire_cells.append([tx, ty])
					var we = spawn_enemy("W", x, y)
					if we != null:
						Game.scale_enemy(we)
						we.nid = next_nid
						next_nid += 1
						ents.append(we)
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
					var se = texts[sign_n] if sign_n < texts.size() else "..."
					if se is Dictionary:        # {"text", "alt": [{"if": "<flag>" | "!<flag>", "text"}]}: the first alt that holds wins
						signs.append({"x": x + 8, "y": y + T, "text": String(se.text), "alt": se.get("alt", []), "i": sign_n})
					else:
						signs.append({"x": x + 8, "y": y + T, "text": String(se), "i": sign_n})
					sign_n += 1
				"M", "V":
					_add_platform(ch, tx, ty, rows)
				"J":
					_add_packets(tx, ty, rows)
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
	tower = Tower.new(self)                                  # (every room: a breakpoint can stop its platforms)
	tower.load_all()
	if def.has("loop"):
		iter = clampi(int(Game.loop_iter.get(id, 0)), 0, 3)
		if mode != "guest" and not Game.flag("boss:LOOP"):
			for spn in def.loop.iters[iter].get("spawn", []):
				var le = spawn_enemy(String(spn[0]), int(spn[1]) * T, int(spn[2]) * T)
				if le != null:
					Game.scale_enemy(le)
					le.nid = next_nid
					next_nid += 1
					ents.append(le)
	for se in ents:
		if se.has_method("settle"):
			se.settle()
	if def.has("lab_boss") and mode != "guest" and boss_spawn != null:     # the sparring dummy: an entity, not the room's boss fight
		var kd := KitDummy.new(self, boss_spawn.x, boss_spawn.y)
		kd.nid = next_nid
		next_nid += 1
		ents.append(kd)
	if def.has("boss") and not Game.flag("boss:" + def.boss.id) and mode != "guest":
		var bs: Dictionary = boss_spawn if boss_spawn != null else {"x": pw - 80.0, "y": ph - 48.0}
		boss = make_boss(def.boss, bs.x, bs.y)
		ents.append(boss)
	spark_spots.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in range(mini(3, spark_spots.size())):
		var fid := "item:%s:f%d" % [id, i]
		if not Game.flag(fid) and mode != "guest":
			items.append({"kind": "spark", "x": float(spark_spots[i].x), "y": float(spark_spots[i].y), "idx": i, "id": fid, "ph": i, "ghost": false})
	_group_dead()
	for nd in def.get("npc", []):
		npcs.append({"kind": String(nd.kind), "x": float(int(nd.x) * T + 8), "y": float(int(nd.y) * T + T), "zone": String(nd.zone), "price": int(nd.price),
			"strip": 0, "acc": 0.0, "scraps": [], "tick_t": 0.0})
	for pg in def.get("pages", []):                    # logbook pages (MVB1-12): an item whose id is the flag page:<n>
		var pgid := "page:%d" % int(pg[2])
		if not Game.flag(pgid) and mode != "guest":
			items.append({"kind": "page", "x": float(int(pg[0]) * T + 8), "y": float(int(pg[1]) * T + 8), "id": pgid, "ph": float(pg[2])})
	for jc in def.get("agents", []):
		jars.append({"x": float(int(jc[0]) * T + 8), "y": float(int(jc[1]) * T + T), "broken": Game.flag("agent:" + id), "fly": null, "asked": -10.0, "t": 0.0})
	for dd in def.get("decor", []):
		var di: Dictionary = dd.duplicate()
		var dtx := int(dd.x)
		var dty := int(dd.y)
		di["cx"] = dtx
		di["cy"] = dty
		di["x"] = float(dtx * T + 8)
		di["y"] = float(dty * T + T)
		var fy := dty + 1
		while fy < h - 1 and grid.tile(dtx, fy) != TileGrid.SOLID and grid.tile(dtx, fy) != TileGrid.ONEWAY:
			fy += 1
		di["fall_y"] = float(fy * T)
		decor_items.append(di)
	for di in decor_items:                             # a drip that has a bucket under it falls into the bucket
		if String(di.kind) == "drip":
			for bk in decor_items:
				if String(bk.kind) == "bucket" and absf(float(bk.x) - float(di.x)) < 1.0:
					di["fall_y"] = minf(float(di.fall_y), float(bk.y) - 9.0)
	if def.has("flood"):
		liquid_y = flood_target()
	_find_ports()
	_move_platforms()                   # (packets and ports at time 0)
	_step_variants(true)                # (variants whose flag is already set are part of the room from the start)
	rng.seed = 1

# `variants` (rooms.json): while a flag is set, the cells of a rect that the room file has as `from` are `to`.
# At load they apply at once; later each cell waits until it is safe (never a wall inside a body, never a floor vanishing under one).
# a room condition: `iter>=n` is the loop room's pass, anything else is the game's
func _cond(s: String) -> bool:
	if s.begins_with("iter>="):
		return iter >= int(s.substr(6))
	return Game.cond(s)

# guest: the host's pass number (the snapshot's `tw.it`)
func set_iter(n: int) -> void:
	if n != iter:
		iter = n
		_step_variants()

func loop_key_on() -> bool:
	return def.has("loop") and loop_key != null and bool(def.loop.iters[iter].get("key", false)) and not Game.flag(String(def.loop.flag))

func _step_loop_key(p) -> void:
	if p == null or p.dead or p.gone or not loop_key_on():
		return
	if Game.overlap(p.hurtbox(), loop_key):
		Game.set_world_flag(String(def.loop.flag))
		pop(float(loop_key.x) + 8.0, float(loop_key.y) - 6.0, "break;", "#f3d58a", true)
		burst(float(loop_key.x) + 8.0, float(loop_key.y) + 8.0, 10, ["#f3d58a", "#ffffff"], 80.0, 200.0)
		Audio.sfx("gate")

func _step_variants(at_load := false) -> void:
	var vs: Array = def.get("variants", [])
	if vs.is_empty():
		return
	for vi in range(vs.size()):
		if variants_on.has(vi) or not _cond(String(vs[vi]["if"])):
			continue
		variants_on[vi] = true
		var v: Dictionary = vs[vi]
		var to_t: int = TileGrid.CHARS.get(String(v.to), TileGrid.E)
		for ty in range(int(v.rect[1]), int(v.rect[1]) + int(v.rect[3])):
			for tx in range(int(v.rect[0]), int(v.rect[0]) + int(v.rect[2])):
				if ty < h and tx < rows[ty].length() and rows[ty][tx] == String(v.from):
					variant_q.append({"tx": tx, "ty": ty, "t": to_t})
	if variant_q.is_empty():
		return
	var bds: Array = bodies() if not at_load else []
	var left: Array = []
	for c in variant_q:
		if _variant_safe(c, bds):
			grid.tiles[c.ty * w + c.tx] = c.t
			grid.blink_hold.erase(c.ty * w + c.tx)
			if view != null:
				view.refresh_tile(c.tx, c.ty)
		else:
			left.append(c)
	variant_q = left

func _variant_safe(c: Dictionary, bodies: Array) -> bool:
	var old := grid.tiles[c.ty * w + c.tx]
	var top: float = c.ty * T
	var blocks: bool = c.t != TileGrid.E and c.t != TileGrid.ONEWAY and c.t != TileGrid.CRUMBLE
	for b in bodies:
		var over: bool = b.x < c.tx * T + T and b.x + b.w > c.tx * T
		if not over:
			continue
		if blocks and b.y < top + T and b.y + b.h > top:
			return false
		if not blocks and (old == TileGrid.SOLID or old == TileGrid.ONEWAY) and absf(b.y + b.h - top) <= 2.0:
			return false
	return true

# THE HEAP's water: the surface row of this room at the current flood level (null = dry). Pixel y = row * 16 + 6
func flood_target():
	if not def.has("flood"):
		return null
	var v = def.flood[2 - Game.heap_flood()]
	return null if v == null else float(v) * T + 6.0

# solo / host: the water follows the flood level (26 px/s) and, in a rising room, climbs after the players (MV4-03)
func _step_flood(dt: float) -> void:
	if not def.has("flood"):
		# THE LEAK's arena: once the fight is won the tide drains away (the boss writes liquid_y itself while it lives)
		if liquid_y != null and def.has("boss") and (fight.state == "done" or fight.state == "reward"):
			liquid_y += 60.0 * dt
			if liquid_y > ph + 60:
				liquid_y = null
		return
	if def.has("rise") and Game.heap_flood() > 0:
		var ps := players()
		if not rise_armed:
			for q in ps:
				if q.y >= float(def.rise.trigger) * T:
					rise_armed = true
		if not rise_on and rise_armed and not ps.is_empty():
			for q in ps:
				if q.y < float(def.rise.trigger) * T:
					rise_on = true
					Audio.sfx("roar")
					shake(0.5)
					break
		if rise_on and liquid_y != null and not ps.is_empty():
			var low := -1e9
			for q in ps:
				low = maxf(low, q.y + q.h)
			var gap: float = liquid_y - low                # from the lowest player: nobody is left behind
			liquid_y -= (float(def.rise.speed) + maxf(0.0, gap - 130.0) * 1.2) * dt
			liquid_y = maxf(liquid_y, float(def.rise.top) * T)
	if rise_on:
		return
	var tgt = flood_target()
	if tgt == null:
		if liquid_y != null:
			liquid_y += 26.0 * dt
			if liquid_y > ph + 30:
				liquid_y = null
	else:
		if liquid_y == null:
			liquid_y = float(ph + 40)
		liquid_y = move_toward(liquid_y, tgt, 26.0 * dt)

# the 4-connected groups of dead code: where its moths fly and its reveal bursts
func _group_dead() -> void:
	dead_groups = []
	var left := {}
	for c in dead_cells:
		left[c[1] * w + c[0]] = true
	for c in dead_cells:
		if not left.has(c[1] * w + c[0]):
			continue
		var stack := [c]
		left.erase(c[1] * w + c[0])
		var sx := 0.0
		var sy := 0.0
		var n := 0
		var quiet := false
		while not stack.is_empty():
			var q: Array = stack.pop_back()
			for qc in def.get("dead_quiet", []):
				if int(qc[0]) == q[0] and int(qc[1]) == q[1]:
					quiet = true
				sx += q[0] * T + 8.0
				sy += q[1] * T + 8.0
				n += 1
				for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var k: int = (q[1] + o[1]) * w + q[0] + o[0]
					if q[0] + o[0] >= 0 and q[0] + o[0] < w and left.has(k):
						left.erase(k)
						stack.append([q[0] + o[0], q[1] + o[1]])
		dead_groups.append({"x": sx / n, "y": sy / n, "quiet": quiet})

# the boss class named by rooms.json (a match, no reflection)
func make_boss(bd: Dictionary, bx: float, by: float):
	var hp_: int = Game.boss_hp(bd)
	var b
	match String(bd.get("class", "NullBoss")):
		"Reviewer": b = Reviewer.new(self, bx, by, hp_)
		"MergeBoss": b = MergeBoss.new(self, bx, by, hp_)
		"LeakBoss": b = LeakBoss.new(self, bx, by, hp_)
		"CrawlerBoss": b = CrawlerBoss.new(self, bx, by, hp_)
		"FirewallBoss": b = FirewallBoss.new(self, bx, by, hp_)
		"Reviewer2": b = Reviewer2.new(self, bx, by, hp_)
		_: b = NullBoss.new(self, bx, by, hp_)
	b.boss_name = String(bd.get("name", bd.id))
	b.drop_n = int(bd.get("drop", 24))
	b.nid = next_nid
	next_nid += 1
	return b

# closed doors are solid; recomputed every step (a fight, a boss flag)
# `until:<flag>` or `until:<k>of:<f1>,<f2>,...` (at least k of the flags are set)
var _until_cache := {}
func _until_open(spec: String) -> bool:
	var p = _until_cache.get(spec)
	if p == null:
		p = [1, [spec]]
		var of_at := spec.find("of:")
		if of_at > 0 and spec.substr(0, of_at).is_valid_int():
			p = [int(spec.substr(0, of_at)), Array(spec.substr(of_at + 3).split(",", false))]
		_until_cache[spec] = p
	var n := 0
	for f in p[1]:
		if Game.flag(String(f)):
			n += 1
	return n >= int(p[0])

# the text of a sign, chosen when it is read (so a flag set while the player stands there shows at once)
func sign_text(s: Dictionary) -> String:
	for a in s.get("alt", []):
		if Game.cond(String(a["if"])):
			return String(a.text)
	return String(s.text)

# curl (MVB2-03): what [special] can zip to. Rings, and the crawler's hooks once it is beaten. The same list on both pages.
func anchors() -> Array:
	var out: Array = rings.duplicate()
	if Game.flag("boss:CRAWLER"):
		out.append_array(hooks)
	return out

# the anchor a [special] press would take: within CURL_RANGE of the body centre, not the one just used, a clear line (sampled every 8 px);
# with a direction held only those on that side (when any exist); the nearest wins. -1 = none.
func pick_anchor(q, mx: float) -> int:
	var list := anchors()
	var cx: float = q.x + q.w / 2.0
	var cy: float = q.y + q.h / 2.0
	var cand: Array = []
	for i in range(list.size()):
		if i == int(q.get("curl_last")):
			continue
		var a: Dictionary = list[i]
		var d := Vector2(float(a.x) - cx, float(a.y) - cy)
		if d.length() > Game.CURL_RANGE:
			continue
		var clear := true
		var steps := maxi(1, ceili(d.length() / 8.0))
		for s in range(1, steps):
			var p := Vector2(cx, cy) + d * (float(s) / float(steps))
			if grid.solid_at(p.x, p.y):
				clear = false
				break
		if clear:
			cand.append([i, d])
	if cand.is_empty():
		return -1
	if mx != 0.0:
		var side: Array = cand.filter(func(c): return c[1].x * mx > 0.0 or absf(c[1].x) < 12.0)
		if not side.is_empty():
			cand = side
	var best: Array = cand[0]
	for c in cand:
		if c[1].length() < best[1].length():
			best = c
	return int(best[0])

# ---------------------------------------------------------------- breakpoint (MV5A-04)
# a frozen creature is a one-way platform for players: its box joins the platforms the player can ride
func ride_list() -> Array:
	if bp_plats.is_empty():
		return plats
	return plats + bp_plats

func _rebuild_bp_plats() -> void:
	bp_plats = []
	for e in ents:
		if not e.dead and e.bp_t > 0.0 and e.bp_k == 1:
			bp_plats.append({"x": e.x, "y": e.y, "w": e.w, "h": minf(e.h, 6.0), "dx": 0.0, "dy": 0.0})

# in range, in front (or within 8 px behind), a clear line (a piston's own cells do not block the line to it)
func _bp_ok(cx: float, cy: float, face: float, nx: float, ny: float) -> bool:
	var d := Vector2(nx - cx, ny - cy)
	var len_ := d.length()
	if len_ > Game.BP_RANGE or d.x * face < -8.0:
		return false
	var steps := maxi(1, ceili(len_ / 8.0))
	for s in range(1, steps):
		var k := float(s) / float(steps)
		if k * len_ > len_ - 10.0:
			break
		var px := cx + d.x * k
		var py := cy + d.y * k
		if grid.solid_at(px, py) and grid.tile(floori(px / T), floori(py / T)) != TileGrid.PHEAD:
			return false
	return true

# what a [special] press would stop: the nearest creature, piston, gear, platform or blink group in front of the body. {} = nothing
func bp_pick(q) -> Dictionary:
	if q == null or q.dead:
		return {}
	var cx: float = q.x + q.w / 2.0
	var cy: float = q.y + q.h / 2.0
	var face: float = q.face
	var best := {}
	var bd := 1e9
	for e in ents:
		if e.dead or e.bp_t > 0.0 or e.passive or (e.get("is_boss") == true and e.get("bp") != true):
			continue
		var d := Vector2(e.cx - cx, e.cy - cy).length()
		if d < bd and _bp_ok(cx, cy, face, e.cx, e.cy):
			bd = d
			best = {"kind": "c", "id": e.nid, "nx": e.cx, "ny": e.cy}
	if tower != null:
		for t in tower.bp_targets(cx, cy):
			if tower.is_frozen(String(t.id)):
				continue
			if float(t.d) < bd and _bp_ok(cx, cy, face, float(t.nx), float(t.ny)):
				bd = float(t.d)
				best = {"kind": String(t.kind), "id": t.id, "nx": t.nx, "ny": t.ny}
	return best

# [special] with breakpoint: freeze the target (a guest asks the host, which decides). true = the press was used
func bp_press(q) -> bool:
	var t := bp_pick(q)
	if t.is_empty():
		return false
	if mode == "guest":
		net_bp.emit(String(t.kind), t.id)
		Audio.sfx("pause")
	else:
		bp_apply(String(t.kind), t.id)
	return true

# host: does the guest's press name something that is really in its reach (a round trip of lag allowed for)?
func bp_valid(kind: String, id, q) -> bool:
	var cx: float = q.x + q.w / 2.0
	var cy: float = q.y + q.h / 2.0
	if kind == "c":
		for e in ents:
			if e.nid == int(id):
				return Vector2(e.cx - cx, e.cy - cy).length() <= Game.BP_RANGE + 64.0
		return false
	if tower != null:
		for t in tower.bp_targets(cx, cy):
			if t.id == String(id):
				return float(t.d) <= Game.BP_RANGE + 64.0
	return false

# host / solo: stop the target for BP_TIME
func bp_apply(kind: String, id) -> bool:
	var at := Vector2.ZERO
	if kind == "c":
		var hit_e = null
		for e in ents:
			if e.nid == int(id) and not e.dead and e.bp_t <= 0.0 and (e.get("is_boss") != true or e.get("bp") == true):
				hit_e = e
		if hit_e == null:
			return false
		hit_e.bp_t = Game.BP_TIME
		at = Vector2(hit_e.cx, hit_e.cy)
	else:
		if tower == null or tower.is_frozen(String(id)):
			return false
		tower.freeze(String(id))
		at = Vector2(player.x, player.y) if player != null else Vector2.ZERO
	Audio.sfx("pause")
	ring(at.x, at.y, 3, 18, "#7cc4ff", 0.35)
	pop(at.x, at.y - 14.0, "BREAK", "#7cc4ff", true)
	return true

func _draw_bp(ci: CanvasItem) -> void:
	var blue := Color("#7cc4ff")
	for e in ents:
		if e.dead or e.bp_t <= 0.0 or e.bp_k != 1:
			continue
		ci.draw_rect(Rect2(e.x - 2.0, e.y - 2.0, e.w + 4.0, e.h + 4.0), blue, false, 1.0)
		PixelText.draw_text(ci, "BREAK %.1f" % e.bp_t, e.x + e.w / 2.0, e.y - 12.0, "#7cc4ff", {"align": "c", "tiny": true, "outline": Game.COL.ink})
	var p = player
	Game.bp_hint = false
	if p == null or p.dead or not bool(p.tools.get("breakpoint", false)) or float(p.bp_cd) > 0.0 or Game.curl_hint:
		return
	var t := bp_pick(p)
	if t.is_empty():
		return
	Game.bp_hint = true
	var bx := floorf(float(t.nx)) - 8.0
	var by := floorf(float(t.ny)) - 8.0
	for c in [[0.0, 1.0], [16.0, -1.0]]:               # a pause bracket round the target
		ci.draw_rect(Rect2(bx + c[0], by, 1, 16), blue)
		ci.draw_rect(Rect2(bx + c[0] + 3.0 * c[1], by, 1, 16), blue)

func update_doors() -> void:
	grid.gates_open.catch = Game.flag("gate:%s:catch" % id)
	grid.gates_open.agents = Game.flag("gate:%s:agents" % id) or (def.has("gate_lever") and Game.flag(String(def.gate_lever)))
	for d in grid.doors:
		var lock: String = d.lock
		var open: bool = Game.rooms_meta.rooms.has(String(d.to).get_slice(":", 0))      # a door to a room that does not exist (yet) never opens
		if not open:
			pass
		elif lock == "oneway":
			open = false                           # never opens from this side: the other side is a drop into this room
		elif lock == "fight":
			open = not fight_active
		elif lock.begins_with("until:"):
			open = _until_open(lock.substr(6))
		elif lock.begins_with("flood:"):
			open = Game.heap_flood() <= int(lock.substr(6))
		if d.has("was") and d.was != open and time > 0.5:
			Audio.sfx("gate" if open else "thud")
		d.was = open
		d.open = open

# packets (letter `J`): looping platforms along the row to the next `|`, a pure function of the room's clock (the guest computes the same)
func _add_packets(tx: int, ty: int, prow: PackedStringArray) -> void:
	var pk: Dictionary = def.get("packets", {})
	var pw_t := int(pk.get("w", 4))
	var speed := float(pk.get("speed", 64.0))
	var every := float(pk.get("every", 4.0))
	var xa := float(tx * T)
	var xb := xa
	var row := prow[ty]
	for i in range(tx + 1, row.length()):
		if row[i] == "|":
			xb = float((i + 1) * T - pw_t * T)
			break
	if xb <= xa:
		return
	var n := ceili((xb - xa) / (speed * every)) + 1
	var path := {"xa": xa, "xb": xb, "n": n, "every": every, "speed": speed, "w": pw_t * T}
	packet_paths.append(path)
	for j in range(n):
		plats.append({"x": xa, "y": float(ty * T + 2), "w": float(pw_t * T), "h": 6.0, "dx": 0.0, "dy": 0.0, "packet": true, "j": j, "path": path, "off": true, "ax": true, "a": 0.0, "b": 0.0, "ph": 0.0, "speed": speed})

# ports (letter `3`): a column of port cells is one port; numbered in column order (22, 80, 443, 8080)
func _find_ports() -> void:
	var cols := {}
	for ty in range(h):
		for tx in range(w):
			if grid.tiles[ty * w + tx] == TileGrid.PORT:
				if not cols.has(tx):
					cols[tx] = [ty, ty]
				cols[tx][1] = ty
	var keys := cols.keys()
	keys.sort()
	for i in range(keys.size()):
		port_cols.append({"tx": keys[i], "ty0": cols[keys[i]][0], "ty1": cols[keys[i]][1], "idx": i})

func _move_packets() -> void:
	var lossy: Dictionary = def.get("packets", {}).get("lossy", {})
	for m in plats:
		if not m.get("packet", false):
			continue
		m["warn"] = false
		var pa: Dictionary = m.path
		var span: float = float(pa.n) * float(pa.every)
		var u := fposmod(time + float(m.j) * float(pa.every), span)
		var nx: float = float(pa.xa) + u * float(pa.speed)
		var was_off: bool = m.off
		m.off = nx > float(pa.xb)
		m.dx = 0.0 if (m.off or was_off) else nx - m.x
		m.x = nx if not m.off else float(pa.xa)
		m["lost"] = false
		m["lossy"] = false
		if not lossy.is_empty() and int(m.j) % int(lossy.every) == int(lossy.every) - 1:
			m["lossy"] = true
			if not m.off:                                         # packet loss: a pure function of the clock, so both pages lose the same packet
				var centre: float = m.x + float(m.w) / 2.0
				for lc in lossy.x:
					var reach: float = ((float(lc) * T + 8.0) - centre) / float(pa.speed)    # seconds until its centre is over the column
					if reach > 0.0 and reach <= float(lossy.warn):
						m["warn"] = true
					elif reach <= 0.0 and -reach < float(lossy.off):
						m["lost"] = true

# a port is open while a packet's front is close enough (the lead) and its back has not left yet (the lag); it never closes on a body
func _update_ports(bodies: Array) -> void:
	if port_cols.is_empty():
		return
	var pk: Dictionary = def.get("packets", {})
	var lead := float(pk.get("lead", 32.0))
	var lag := float(pk.get("lag", 16.0))
	for pc in port_cols:
		var px: float = pc.tx * T
		var want := false
		for m in plats:
			if m.get("packet", false) and not m.off and not m.get("lost", false) and m.x + m.w >= px - lead and m.x <= px + T + lag:
				want = true
				break
		for ty in range(pc.ty0, pc.ty1 + 1):
			var i: int = ty * w + pc.tx
			if want:
				grid.port_open[i] = true
			elif grid.port_open.has(i) and not _box_over_cell(bodies, pc.tx, ty):
				grid.port_open.erase(i)

func _box_over_cell(bodies: Array, tx: int, ty: int) -> bool:
	for b in bodies:
		if b.x < tx * T + T and b.x + b.w > tx * T and b.y < ty * T + T and b.y + b.h > ty * T:
			return true
	return false

# everything that has a body in this room: the local player, the partner's body, creatures (and a guest's puppets of them)
func bodies() -> Array:
	var out: Array = []
	if player != null:
		out.append(player)
	out.append_array(remote_players)
	for e in ents:
		if not e.dead:
			out.append(e)
	return out

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
	plats.append({"x": float(x), "y": float(y + 2), "w": 48.0, "h": 6.0, "ax": ch == "M", "a": a, "b": b, "ph": fposmod(tx * 0.37 + ty * 0.61, 1.0), "dx": 0.0, "dy": 0.0, "speed": def.get("platSpeed", 44.0), "bpk": "m%d" % plats.size()})

# a creature that comes into the room while it runs (FORK's children): numbered, scaled by the difficulty, drawn
func add_entity(e) -> Node:
	Game.scale_enemy(e)
	e.nid = next_nid
	next_nid += 1
	ents.append(e)
	if entity_root != null:
		entity_root.add_child(e)
	return e

func spawn_enemy(ch: String, x: int, y: int):
	if mode == "guest":
		return null
	match ch:
		"b": return Bug.new(self, x, y, false)
		"a": return Bug.new(self, x, y, true)
		"t": return Typo.new(self, x, y)
		"G": return Guard.new(self, x, y)
		"Z": return Zombie.new(self, x, y)
		"X": return ExceptionFoe.new(self, x, y)
		"m": return Mimic.new(self, x, y)
		"g": return LogEnemy.new(self, x, y)
		"n": return Noodle.new(self, x, y)
		"f": return Flaky.new(self, x, y)
		"K": return Fork.new(self, x, y)
		"s": return Slime.new(self, x, y, false)
		"l": return Lint.new(self, x, y, false)
		"L": return Lint.new(self, x, y, true)
		"i": return Dripper.new(self, x, y)
		"p": return Pendulum.new(self, x, y)
		"d": return Drone.new(self, x, y)
		"x": return Segfault.new(self, x, y)
		"q": return StackOverflow.new(self, x, y)
		"c": return Scraper.new(self, x, y)
		"W": return Worm.new(self, x, y)
		"e": return Spyware.new(self, x, y)
		"u": return Mitm.new(self, x, y)
		"r": return Botnet.new(self, x, y)
		"y": return Pinger.new(self, x, y)
	push_warning("room %s: enemy letter '%s' is not ported yet (ignored)" % [id, ch])
	return null

# the five bits of a DDOS swarm at a cell (px); returns them (MVB2-06 gives the class)
func spawn_ddos(px: float, py: float, owner_rack = null) -> Array:
	var out: Array = []
	if mode == "guest":
		return out
	next_swarm += 1
	for i in range(5):
		var b = DdosBit.new(self, px + 4.0 + float(i) * 5.0, py + 4.0 + float((i * 7) % 3) * 4.0, i)
		b.swarm = next_swarm
		if owner_rack != null:
			b.owner_ref = owner_rack
			b.speed_k = 1.2
			b.awake = true
		add_entity(b)
		out.append(b)
	return out

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
# Co-op, as in the JS game: on the host every effect and sound of a room the guest is in is also written down (fx_out) and goes
# out with the next snapshot, tagged with its cause: p1 the host player, p2 the guest (its hits applied here), all the world.
# The guest plays them at the moment its delayed view reaches them; the partner's shakes and flashes stay on the partner's screen.
var fx_out: Array = []
var ctx := "all"

static func _plain(v):
	if v is Color:
		return "#" + v.to_html(false)
	if v is float:
		return snappedf(v, 0.1)
	if v is Array:
		return v.map(func(x): return _plain(x))
	return v

func _rec(e: Array) -> void:
	if mode == "host" and not remote_players.is_empty() and fx_out.size() < 80:
		var out: Array = e.map(func(x): return _plain(x))
		out.append(ctx)
		fx_out.append(out)

func rec_sound(sfx_name: String, opts: Dictionary) -> void:
	_rec(["S", sfx_name, float(opts.get("vol", 1.0))])

func shake(a: float) -> void:
	_rec(["shake", a])
	if ctx != "p2":                     # the partner's hits shake the partner's screen only
		fx.shake(a)
func stop(t: float) -> void:
	if ctx != "p2":                     # (no hitstop here for the partner's hits either)
		hitstop = maxf(hitstop, t)
func flash_screen(a: float, col = null) -> void:
	_rec(["flash_screen", a, col])
	if ctx != "p2":
		fx.flash_screen(a, col)
func part(px: float, py: float, pvx: float, pvy: float, life: float, size: float, col, grav := 0.0, o = null): return fx.part(px, py, pvx, pvy, life, size, col, grav, o)
func burst(px: float, py: float, n: int, cols, spd: float, grav := 300.0, o = null) -> void:
	_rec(["burst", px, py, n, cols, spd, grav, o])
	fx.burst(px, py, n, cols, spd, grav, o)
func dust(px: float, py: float, n: int, dir := 0.0) -> void:
	_rec(["dust", px, py, n, dir])
	fx.dust(px, py, n, dir)
func ring(px: float, py: float, r0: float, r1: float, col, life: float) -> void:
	_rec(["ring", px, py, r0, r1, col, life])
	fx.ring(px, py, r0, r1, col, life)
func pop(px: float, py: float, text: String, col = "#ffffff", big := false) -> void:
	_rec(["pop", px, py, text, col, big])
	fx.pop(px, py, text, col, big)
func spark(px: float, py: float, col = "#ffffff", n := 5) -> void:
	_rec(["spark", px, py, col, n])
	fx.spark(px, py, col, n)
func explode(px: float, py: float, size: float, cols = null) -> void:
	_rec(["explode", px, py, size, cols])
	fx.explode(px, py, size, cols)

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

# an explosion (a SEGFAULT): every bulkhead and crack within r of the centre breaks at once (solo and host)
func blast(cx: float, cy: float, r: float) -> void:
	if mode == "guest":
		return
	var tx0 := floori((cx - r) / T)
	var tx1 := floori((cx + r) / T)
	var ty0 := floori((cy - r) / T)
	var ty1 := floori((cy + r) / T)
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if tx < 0 or ty < 0 or tx >= w or ty >= h:
				continue
			var t := grid.tile(tx, ty)
			if t != TileGrid.THICK and t != TileGrid.CRACK:
				continue
			if Vector2(tx * T + 8 - cx, ty * T + 8 - cy).length() > r:
				continue
			grid.tiles[ty * w + tx] = TileGrid.E
			Game.flags["crack:%s:%d:%d" % [id, tx, ty]] = true
			view.erase_tile(tx, ty)
			burst(tx * T + 8, ty * T + 8, 12, ["#8d8798", "#c3bccd", "#4c4658"], 90.0, 300.0)
			tile_broken.emit(tx, ty)
	shake(0.5)
	explode(cx, cy, 20)
	Audio.sfx("explode")

func dead_revealed() -> bool:
	return Game.flag("dead:" + id)

# the dead code of this room is shown for good (announce: the local player found it; false: a partner did, or a snapshot says so)
func reveal_dead(announce := true) -> void:
	Game.flags["dead:" + id] = true
	if view != null:
		for c in dead_cells:
			view.tiles.erase_cell(Vector2i(c[0], c[1]))
	if announce:
		Audio.sfx("glitch")
		for g in dead_groups:
			burst(g.x, g.y, 10, ["#8d8798", "#c3bccd", "#4c4658"], 80.0, 200.0)
		if not dead_groups.is_empty():
			pop(dead_groups[0].x, dead_groups[0].y - 12, "dead code", "#c3bccd")

# does a player's box touch unrevealed dead code?
func _touches_dead(p) -> bool:
	if dead_cells.is_empty() or dead_revealed():
		return false
	for ty in range(floori(p.y / T), floori((p.y + p.h - 0.001) / T) + 1):
		for tx in range(floori(p.x / T), floori((p.x + p.w - 0.001) / T) + 1):
			if grid.tile(tx, ty) == TileGrid.DEAD:
				return true
	return false

func snapshot() -> Dictionary:
	return {"cp": cp_index, "tokens": tokens, "got": got.duplicate(), "sparks": sparks.duplicate(), "clock": clock, "kills": kills, "hits": hits}

# the key ("p1" host's player, "p2" guest's) of a body on this page
func key_of(q) -> String:
	var remote: bool = q.get("is_remote") == true
	return ("p1" if remote else "p2") if mode == "guest" else ("p2" if remote else "p1")

func tag_player(q, secs: float) -> void:
	tags[key_of(q)] = maxf(float(tags[key_of(q)]), secs)

func is_tagged(q) -> bool:
	return float(tags.get(key_of(q), 0.0)) > 0.0

# the living tagged players (every creature of the room chases one of them while the tag lasts)
func tagged_players() -> Array:
	var out: Array = []
	for q in players():
		if is_tagged(q):
			out.append(q)
	return out

func _step_tags(dt: float) -> void:
	for k in tags:
		if tags[k] > 0.0:
			tags[k] = maxf(0.0, tags[k] - dt)

# is a GET ring tapped by a SNIFFER (MVB3-03)? Host and guest read it from the creature (the guest's is a puppet with the host's fields)
func ring_tapped(i: int) -> bool:
	for e in ents:
		if not e.dead and e.has_method("tapped_ring") and e.tapped_ring() == i:
			return true
	return false

# ---- the RST chase (N17, MVB3-05): a red line of `connection reset` falls from the top; a body above it is hurt and put below it
func chase_line_y() -> float:
	return -32.0 + float(def.chase.speed) * (time - ch_t0)

# host / solo: it starts when somebody passes the trigger row, it ends (for good: a world flag) when everybody is below the end row
func _chase_track(dt: float) -> void:
	if ch_fade > 0.0:
		ch_fade -= dt
	if ch_t0 >= 0.0:
		ch_seen = ch_t0
	elif ch_seen >= 0.0:                                                  # it just ended: the line fades where it stopped
		if def.has("chase") and Game.flag(String(def.chase.flag)):
			ch_fade = 1.0
			ch_prev = ch_seen
			ch_fade_y = -32.0 + float(def.chase.speed) * (time - ch_seen)
		ch_seen = -1.0

func _step_chase(dt: float) -> void:
	_chase_track(dt)
	if not def.has("chase") or mode == "guest":
		return
	var cd: Dictionary = def.chase
	if Game.flag(String(cd.flag)):
		ch_t0 = -1.0
		return
	var live := players()
	if ch_t0 < 0.0:
		for q in live:
			if q.y > float(cd.trigger_row) * T:
				ch_t0 = snappedf(time, 0.01)
				Audio.sfx("glitch")
				shake(0.4)
				break
	elif not live.is_empty() and live.all(func(q): return q.y > float(cd.end_row) * T):
		Game.flags[String(cd.flag)] = true
		Game.write_save()
		ch_t0 = -1.0
		Audio.sfx("gate")
		for q in live:
			pop(q.x + 5.0, q.y - 14.0, "connection restored", "#58f0c8", true)
			break

# each page, its own body: above the line costs 1 hp and a place on the nearest floor below the line
func _chase_hurt(p) -> void:
	if ch_t0 < 0.0 or not def.has("chase") or p.dead or p.gone:
		return
	var ly := chase_line_y()
	if p.y >= ly:
		return
	var spot = _chase_spot(p, ly)
	p.hurt(1, p.x + 5.0)
	if p.dead:
		return
	if spot != null:
		p.x = spot.x
		p.y = spot.y
	p.vx = 0.0
	p.vy = 0.0
	p.on_ground = true
	p.inv = maxf(p.inv, 1.0)

# searching down from the line, the same column first, then the neighbours: a floor with a free cell above it
func _chase_spot(p, ly: float):
	var tx0 := floori((p.x + 5.0) / T)
	for off in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6]:
		var tx: int = tx0 + off
		if tx < 1 or tx >= w - 1:
			continue
		var ty := maxi(1, ceili((ly + 12.0) / T))
		while ty < h - 1:
			if (grid.tile(tx, ty) == TileGrid.SOLID or grid.tile(tx, ty) == TileGrid.ONEWAY) and grid.tile(tx, ty - 1) == TileGrid.E and float(ty * T) - 10.0 > ly:
				return {"x": float(tx * T + 3), "y": float(ty * T - 10)}
			ty += 1
	return null

func _draw_chase(ci: CanvasItem) -> void:
	if not def.has("chase") or (ch_t0 < 0.0 and ch_fade <= 0.0):
		return
	var a := 1.0 if ch_t0 >= 0.0 else clampf(ch_fade, 0.0, 1.0)
	if ch_t0 < 0.0 and (ch_fade <= 0.0 or ch_prev < 0.0):
		return
	var ly: float = chase_line_y() if ch_t0 >= 0.0 else ch_fade_y
	var red := Color("#ff3b3b")
	red.a = a
	ci.draw_rect(Rect2(0, ly - 3.0, pw, 6), red)
	ci.draw_rect(Rect2(0, ly - 3.0, pw, 1), Color(1.0, 0.8, 0.8, a))
	for k in range(int(pw / 14)):                                         # static falling off the band
		var sx: float = float(k) * 14.0 + Game.hash3(float(k), floorf(time * 14.0), 5) * 10.0
		ci.draw_rect(Rect2(sx, ly + 3.0 + fposmod(time * 40.0 + float(k) * 7.0, 14.0), 1, 2), Color(1.0, 0.4, 0.4, a * 0.6))
	var cxm: float = cam.x + 192.0
	for k in range(-2, 3):
		PixelText.draw_text(ci, "RST", cxm + k * 90.0, ly - 9.0, "#ffd0d0", {"align": "c", "tiny": true, "outline": Game.COL.ink})
	if time - ch_t0 < 0.6:
		PixelText.draw_text(ci, "connection reset", cxm, cam.y + 70.0, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})

# DDOS bits close round a body make it "jam" (MVB3-02): slow and no dash. Computed on each page for its own body from the bits it sees.
func jam_for(q) -> bool:
	var n := 0
	var c := Vector2(q.x + q.w / 2.0, q.y + q.h / 2.0)
	for e in ents:
		if e is DdosBit and not e.dead and Vector2(e.cx, e.cy).distance_to(c) <= 28.0:
			n += 1
			if n >= 3:
				return true
	return false

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

func boss_damage(_boss, d: float, how := "swipe") -> void:
	if attacker == null:
		return
	if _boss != null and _boss.get("read") != null:       # a kit boss reads what the players do (rule 8)
		_boss.read.note_hit("p2" if attacker in remote_players else "p1", how)
	dmg_log.append({"t": time, "who": attacker, "d": d})
	if fight.state == "active":
		var i: int = 1 if (attacker in remote_players) else 0
		if how == "swipe":
			stats.hits[i] += 1                 # R_PLAYER counts claw hits only
		else:
			stats.other[i] += 1                # agents, caught projectiles, dashes: shown apart

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
	pick_banner.t -= dt
	memory.t -= dt
	if hitstop > 0.0:
		hitstop -= dt
		return
	time += dt
	Decor.step(self, dt)
	_step_sighting(dt)
	_step_variants()
	for pe in ents:
		if pe.bp_t > 0.0:
			pe.bp_t -= dt
			pe.bp_off += dt
	_rebuild_bp_plats()
	_move_platforms()
	if tower != null:
		tower.step(dt, players())
		_tick_sound()
	_step_loop_key(player)
	_step_tags(dt)
	_chase_track(dt)
	var p = player
	if p != null:
		p.jam = jam_for(p) if not p.dead else false
		p.update(dt)
		_chase_hurt(p)
		_check_door()
		if not p.dead and _touches_dead(p):
			reveal_dead()
			net_reveal.emit()
		if not p.dead and not p.gone:
			interact_combat(p)
			interact_goals(p)
			_check_jars(p)
			_check_levers(p)
			_step_pad()
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
				if time - float(it.get("asked", -10.0)) < 0.6 or it.get("dead", false) or item_locked(it):
					continue
				var rr := (11.0 if it.kind == "spark" else 9.0) * Game.mod_pickup_radius()
				if absf(pcx - it.x) < rr + 3 and absf(pcy - it.y) < rr and (not it.get("loose", false) or it.get("t", 1.0) > 0.2):
					it.asked = time
					net_pickup.emit(it.id)
	# a zone lives 0.25 s here too (it stayed forever: walking into an old blast spot later still hurt)
	for z in zones:
		z.until -= dt
	if not zones.is_empty():
		zones = zones.filter(func(z): return z.until > 0.0)
		if zones.is_empty():
			zones_hit.clear()
	_step_crumble(dt, players())
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

# crumbling blocks (js: Level.update): stand -> 0.42 s shaking -> gone for 2.6 s (waits while somebody stands there) -> back
func _step_crumble(dt: float, live: Array) -> void:
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
			view.dynamic.erase_cell(Vector2i(tx2, ty2))
		elif c.s == 2:
			if grid.any_on(live, tx2, ty2):
				c.t = 0.2
			else:
				grid.crumble.erase(i)
				dust(tx2 * T + 8, ty2 * T + 8, 4)
				view.dynamic.set_cell(Vector2i(tx2, ty2), 0, Vector2i(3, 5))
	if mode == "guest":
		# a crumble this body started is only a guess until the host lists it (its prediction expires after 1 s)
		for i in grid.crumble.keys():
			var c2: Dictionary = grid.crumble[i]
			if not c2.has("pred") and not c2.has("host"):
				c2["pred"] = time + 1.0
				net_crumble.emit(i % w, i / w)

# guest: the host's list [[tx, ty, s, t*100], ...] is the truth; a guess it does not list is dropped after its second
func apply_crumbles(list: Array) -> void:
	var listed := {}
	for rec in list:
		var i: int = int(rec[1]) * w + int(rec[0])
		listed[i] = true
		var c = grid.crumble.get(i)
		if c == null:
			c = {"s": int(rec[2]), "t": rec[3] / 100.0, "host": true}
			grid.crumble[i] = c
			if c.s == 2:
				view.dynamic.erase_cell(Vector2i(int(rec[0]), int(rec[1])))
		else:
			c.erase("pred")
			c["host"] = true
			if int(rec[2]) == 2 and c.s != 2:
				view.dynamic.erase_cell(Vector2i(int(rec[0]), int(rec[1])))
			c.s = int(rec[2])
			c.t = rec[3] / 100.0
	for i in grid.crumble.keys():
		if listed.has(i):
			continue
		var c3: Dictionary = grid.crumble[i]
		if c3.has("pred") and float(c3.pred) > time:
			continue
		grid.crumble.erase(i)
		view.dynamic.set_cell(Vector2i(i % w, i / w), 0, Vector2i(3, 5))

# the host confirmed a broken tile (or the guest's own request came through)
func apply_tile(tx: int, ty: int) -> void:
	pending_cracks.erase("%d:%d" % [tx, ty])
	Game.flags["crack:%s:%d:%d" % [id, tx, ty]] = true
	if grid.tile(tx, ty) == TileGrid.CRACK or grid.tile(tx, ty) == TileGrid.THICK:
		grid.tiles[ty * w + tx] = TileGrid.E
		view.erase_tile(tx, ty)
		burst(tx * T + 8, ty * T + 8, 12, ["#8d8798", "#c3bccd", "#4c4658"], 90.0, 300.0)
		shake(0.3)
		Audio.sfx("brk")
	elif grid.tile(tx, ty) == TileGrid.E:
		view.erase_tile(tx, ty)

# ---------------------------------------------------------------- simulation (js: Level.update, same order)
func _move_platforms() -> void:
	_move_packets()
	_update_ports(bodies())
	for m in plats:
		if m.get("packet", false) or m.has("gear"):
			continue
		var span := absf(m.b - m.a)
		if span < 1.0:
			m.dx = 0.0
			m.dy = 0.0
			continue
		var period: float = (span / m.speed) * 2.0
		var pt: float = tower.mt(String(m.bpk)) if tower != null and m.has("bpk") else time
		var u := 0.5 - 0.5 * cos(fposmod(pt / period + m.ph, 1.0) * PI * 2.0)
		var v := lerpf(m.a, m.b, u)
		if m.ax:
			m.dx = v - m.x
			m.dy = 0.0
			m.x = v
		else:
			m.dy = v + 2.0 - m.y
			m.dx = 0.0
			m.y = v + 2.0

# world 4 beats with the tick: the clock is the room's, so both pages tick together
func tick_i() -> int:
	return Tower.tick_i_of(time)

func tick_f() -> float:
	return Tower.tick_f_of(time)

func _tick_sound() -> void:
	if world != 4:
		return
	var ti := tick_i()
	if ti != last_tick:
		last_tick = ti
		if is_local and player != null and not player.dead:
			Audio.local_sfx("tick" if ti % 2 == 0 else "tock", 0.22)

func _check_door() -> void:
	var p = player
	if p == null or p.dead or crossing:
		return
	var mid_x: float = p.x + p.w / 2.0
	var side := ""
	var idx := 0
	if mid_x < 0.0:
		side = "W"
		idx = floori((p.y + p.h / 2.0) / T)
	elif mid_x > pw:
		side = "E"
		idx = floori((p.y + p.h / 2.0) / T)
	elif p.y < 0.0 and p.vy < 0.0:
		side = "N"
		idx = floori(mid_x / T)
	elif p.y + p.h > ph and p.vy >= 0.0:
		side = "S"
		idx = floori(mid_x / T)
	if side != "":
		var d = grid.door_at(side, idx)
		if d != null and d.open:
			crossing = true
			door_crossed.emit(d)

func step(dt: float) -> void:
	if mode == "guest":
		step_guest(dt)
		return
	update_doors()
	fx.decay(dt)
	pick_banner.t -= dt
	memory.t -= dt
	if hitstop > 0.0:
		hitstop -= dt
		return
	time += dt
	Decor.step(self, dt)
	var p = player                       # null in a room only the partner is in
	var live := players()
	_step_flood(dt)
	if p != null and not p.dead:
		clock += dt

	# blinking blocks
	var ph_ := floori(time / blink_period) % 2
	if (tower == null or not tower.has_blink) and ph_ != grid.blink_phase:
		grid.blink_phase = ph_
		var want := TileGrid.BLINK_A if ph_ == 0 else TileGrid.BLINK_B
		for q in live:
			for ty in range(floori(q.y / T), floori((q.y + q.h) / T) + 1):
				for tx in range(floori(q.x / T), floori((q.x + q.w) / T) + 1):
					if grid.tile(tx, ty) == want:
						grid.blink_hold[ty * w + tx] = true
	if (tower == null or not tower.has_blink) and not grid.blink_hold.is_empty():
		for i in grid.blink_hold.keys():
			if not grid.any_on(live, i % w, i / w):
				grid.blink_hold.erase(i)
	_step_variants()
	_step_crumble(dt, live)
	if not break_q.is_empty():
		for q in break_q:
			q.t -= dt
			if q.t <= 0.0:
				q.done = true
				break_tile(q.tx, q.ty)
		break_q = break_q.filter(func(q): return not q.get("done", false))
	_rebuild_bp_plats()
	_move_platforms()
	if tower != null:
		tower.step(dt, live)
		_tick_sound()
	_step_loop_key(player)

	_step_tags(dt)
	_step_chase(dt)
	if p != null:
		p.jam = jam_for(p) if not p.dead else false
		ctx = "p1"
		p.update(dt)
		ctx = "all"
		_chase_hurt(p)
		if not p.dead and _touches_dead(p):
			reveal_dead()
	_check_door()
	_step_agents(dt)

	# creatures (only the ones near a player think)
	var cx: float = cam.x
	var cy: float = cam.y
	for e in ents:
		if e.dead:
			continue
		if e.bp_t > 0.0:                          # breakpoint: stopped (its clock falls behind by the time it stood still)
			e.bp_t -= dt
			e.bp_off += dt
			if e.bp_t <= 0.0:
				e.bp_k = 1
			continue
		if e.always or _near_a_player(e, cx, cy):
			e.update(dt)
	if remote_players.size() > 0:
		record_hist()
	interact()
	if p != null and not p.dead:
		_check_jars(p)
		_check_levers(p)
	_step_wave(dt)
	_step_sighting(dt)
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
	_step_pad()
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
	if boss == null and fight.state != "reward":      # (the dead boss is freed by the room: the reward timer must not depend on it)
		return
	var trigger: float = float(def.boss.get("trigger_x", 1e9))          # (a pad boss has none: MVB2-09 starts it from its pad)
	match String(fight.state):
		"none":
			if String(def.boss.get("trigger", "")) == "land":
				_step_land(dt)
				return
			var from_east: bool = String(def.boss.get("trigger_side", "W")) == "E"        # an arena entered from the east starts below trigger_x
			for q in players():
				var qx: float = q.x + q.w / 2.0
				if (qx < trigger) if from_east else (qx > trigger):
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

# boss trigger "land" (T18): the fight starts when somebody has stood 0.5 s on the arena floor (not on the lid of the hole they came through)
func _step_land(dt: float) -> void:
	var fy: float = float(boss_spawn.y) if boss_spawn != null else float(ph - 48)
	var lid_a := 0.0
	var lid_b := 0.0
	for d in grid.doors:
		if d.side == "S":
			lid_a = float(d.a) * T
			lid_b = float(int(d.b) + 1) * T
	var stand := false
	for q in players():
		var cxp: float = q.x + q.w / 2.0
		if q.on_ground and absf(q.y + q.h - fy) <= 2.0 and (cxp < lid_a or cxp > lid_b):
			stand = true
	land_t = land_t + dt if stand else 0.0
	if land_t >= 0.5:
		_start_intro()

# ---- the pad boss (MVB2-09): started by [up] on a marked cell, not by walking in ----
func pad_on(q) -> bool:
	var pd: Array = def.boss.get("pad", []) if def.has("boss") else []
	if pd.size() < 2 or q == null:
		return false
	return floori((q.x + q.w / 2.0) / T) == int(pd[0]) and floori((q.y + q.h - 1.0) / T) == int(pd[1])

func pad_ready() -> bool:
	var need := String(def.boss.get("pad_needs", ""))
	return need == "" or Game.cond(need)

func _step_pad() -> void:
	if not def.has("boss") or String(def.boss.get("trigger", "")) != "pad" or fight.state != "none" or Game.flag("boss:" + String(def.boss.id)):
		return
	var p = player
	if p == null or p.dead or p.gone or not Controls.pressed.get("up", false) or not pad_on(p):
		return
	if not pad_ready():
		pop(p.x + p.w / 2.0, p.y - 14.0, "you have nothing new to show", Game.COL.dim)
	elif mode == "guest":
		net_pad.emit()
	elif boss != null:
		pad_start()

# host / solo: the intro of a pad fight (the guest's `pad` event comes here after the host checked where it stands)
func pad_start() -> void:
	if fight.state == "none" and boss != null:
		_start_intro()

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

# TEMPORARY (pause menu "Skip boss"): the boss dies at once and the normal reward follows (flag, ability, doors)
func skip_boss() -> bool:
	if mode == "guest" or boss == null or not is_instance_valid(boss) or player == null:
		return false
	if fight.state == "none" and String(def.boss.get("trigger", "")) == "pad":
		_start_intro()                                  # (a pad boss waits for the chair: the skip button starts it)
	if fight.state == "intro":
		_begin_fight()
	if fight.state != "active" or boss.dying:
		return false
	attacker = player
	boss.hit(99999, 0.0, 0.0, "swipe", boss)
	return true

func _begin_fight() -> void:
	fight.state = "active"
	var ps := players()
	for q in ps:
		q.frozen = false
		if q.get("parried") != null:
			q.parried.clear()
	if ps.size() >= 2:                                   # both are in the arena: the co-op factor applies
		boss.scale_hp(1.0 + float(Game.coop_hp_pct) / 100.0)
	stats = {"secs": 0.0, "hits": [0, 0], "dmg": [0, 0], "other": [0, 0], "coop": ps.size() >= 2, "caught": 0}
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
	var bd: Dictionary = def.boss
	banner = {"text": String(bd.banner), "sub": String(bd.banner_sub), "t": 3.0}
	# the fight statistics (to tune boss HP with real numbers)
	var np: int = 2 if stats.coop else 1
	var secs: float = maxf(stats.secs, 0.001)
	var r: float = float(stats.hits[0] + stats.hits[1]) / np / secs
	stats_line = "%s %ds - P1 %d hits" % [bd.name, roundi(secs), stats.hits[0]]
	if stats.coop:
		stats_line += " - P2 %d hits" % stats.hits[1]
	stats_line += " - r %.2f/s - won" % r
	stats_t = 15.0                                   # long enough to read (and screenshot); it is also in the debug log
	Game.dlog(stats_line + " | damage taken P1 %d P2 %d | other damage P1 %d P2 %d" % [stats.dmg[0], stats.dmg[1], stats.get("other", [0, 0])[0], stats.get("other", [0, 0])[1]])      # (.get: a test sets stats by hand, without it)
	Game.fights.append({"boss": bd.id, "secs": snappedf(secs, 0.1), "hits": stats.hits.duplicate(), "dmg_taken": stats.dmg.duplicate(), "other": stats.get("other", [0, 0]).duplicate(), "won": true, "diff": Game.diff, "coop": stats.coop, "caught": stats.get("caught", 0)})

func record_loss() -> void:
	if fight.state == "active":
		Game.fights.append({"boss": def.boss.id, "secs": snappedf(stats.secs, 0.1), "hits": stats.hits.duplicate(), "dmg_taken": stats.dmg.duplicate(), "other": stats.get("other", [0, 0]).duplicate(), "won": false, "diff": Game.diff, "coop": stats.coop})
		Game.write_save()

func _finish_reward() -> void:
	var bd: Dictionary = def.boss
	var rw := String(bd.reward)
	if rw.begins_with("plugin:"):
		Game.flags[rw] = true                              # (a plugin is a flag, shared by both players; no tool)
	else:
		Game.tools[rw] = true
		Game.flags["ability:" + rw] = true
	Game.flags["boss:" + String(bd.id)] = true
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
		for sb in e.harmboxes():
			if sb is Dictionary and sb.has("sid"):
				e.strike_seen[sb.sid] = time
		if e.strike_seen.size() > 8:                     # keep the last second: a late parry from the guest is judged against it
			for sk in e.strike_seen.keys():
				if time - float(e.strike_seen[sk]) > 1.0:
					e.strike_seen.erase(sk)

# a short-lived damage area the guest checks against its own body: kind "c" circle (x, y, r), "r" rectangle (x, y, w, h)
func harm_zone(kind: String, zx: float, zy: float, za: float, zb: float, dmg: int) -> void:
	zones.append({"id": next_zone, "kind": kind, "x": zx, "y": zy, "a": za, "b": zb, "dmg": dmg, "until": 0.25})
	next_zone += 1

func interact() -> void:
	var p = player
	if p == null or p.dead or p.gone:
		return
	ctx = "p1"
	interact_combat(p)
	interact_goals(p)
	ctx = "all"

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
	if hz == "":                                             # a web strand hurts like a spike (inset 3 px, MVB2-05)
		for ty in range(y0, y1 + 1):
			for tx in range(x0, x1 + 1):
				if grid.tile(tx, ty) == TileGrid.WEB and p.x + p.w > tx * T + 3 and p.x < tx * T + T - 3 and p.y + p.h > ty * T + 3 and p.y < ty * T + T - 3:
					hz = "web"
	if liquid_y != null and p.y + p.h > liquid_y + 5:
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
		if tower != null:
			tower.claw(p, box)
		var win: bool = p.catch_window_open()
		for q in projs:
			if q.dead or q.get("friendly", false):
				continue
			if not (q.x + q.r > box.x and q.x - q.r < box.x + box.w and q.y + q.r > box.y and q.y - q.r < box.y + box.h):
				continue
			if win and q.get("catchable", false):          # a yellow attack met a swipe that has just started: caught
				catch_proj(q, p)
				if mode == "guest":
					q["pred_until"] = time + 0.5          # (keep the local copy until a snapshot shows it friendly)
					net_catch.emit(q.id)
				continue
			if not q.cut:
				continue
			q.dead = true
			if mode == "guest":
				net_projhit.emit(q.id)
			spark(q.x, q.y, q.col, 6)
			Audio.sfx("clang")
			stop(0.03)
			if p.atk_dir == "d":
				p.bounce(0.85)
		if win:                                             # strikes a boss marks as catchable (harmboxes with a strike id)
			for e in ents:
				if e.dead:
					continue
				for sb in e.harmboxes():
					if sb is Dictionary and sb.has("sid") and sb.get("catchable", false) and not p.parried.has(sb.sid) and Game.overlap(box, sb):
						p.parried[sb.sid] = true
						if p.parried.size() > 64:
							p.parried.clear()
							p.parried[sb.sid] = true
						Audio.sfx("clang")
						spark((box.x + sb.x + sb.w / 2.0) / 2.0, sb.y + sb.h / 2.0, "#ffd23f", 8)
						stop(0.06)
						shake(0.3)
						p.gain_meter()
						if mode == "guest":
							net_parry.emit(e.nid, int(sb.sid))
						else:
							attacker = p
							e.parried(p, int(sb.sid))
		for s in springs:
			if p.atk_dir == "d" and Game.overlap(box, s):
				p.spring(s)
	# touching
	var hb: Dictionary = p.hurtbox()
	for e in ents:
		if e.dead or pred_dead(e) or (e.bp_t > 0.0 and e.bp_k == 1):
			continue
		for b in e.harmboxes():
			if b is Dictionary and b.has("sid") and p.parried.has(b.sid):
				continue
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
				if p.hurt(int(b.get("dmg", e.dmg)) if b is Dictionary else e.dmg, b.x + b.w / 2.0) and e.has_method("on_contact"):
					e.on_contact()
			break
	# spikes, liquid, pits
	var hz := hazard_at(p)
	if hz != "":
		if hz == "liq" and def.has("rise") and rise_on and not p.get("is_remote"):
			if mode == "guest":
				net_lqhit.emit()
			elif liquid_y != null:
				liquid_y += 72.0                       # the tide backs off a little so one slip is not the end
		p.hazard()
	# springs
	for s in springs:
		if p.vy >= 0.0 and Game.overlap(hb, s) and p.dash_t <= 0.0:
			p.spring(s)

func interact_goals(p) -> void:
	if p.get("in_menu") == true:
		return                                 # (a menu is open: its up/down presses must not open a bench, the shop or the end)
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
	if Controls.pressed.get("up", false) and p.on_ground and not crossing:
		for sh in shops:
			if absf(p.x + p.w / 2.0 - sh.x) < 20.0 and absf(p.y + p.h - sh.y) < 20.0:
				shop_requested.emit()
				break
		for ni in range(npcs.size()):
			if absf(p.x + p.w / 2.0 - (npcs[ni].x + 8.0)) < 32.0 and absf(p.y + p.h - npcs[ni].y) < 20.0:
				index_requested.emit(ni)
				break
	if p.cache_cool <= 0.0 and not stations.is_empty():
		var hb2: Dictionary = p.hurtbox()
		for st in stations:
			if Game.overlap(hb2, st):
				p.meter = float(Game.METER_MAX)
				p.cache_cool = 20.0
				pop(p.x + 5.0, p.y - 12.0, "cache hit", "#58f0c8", true)
				Audio.sfx("agent")
				break
	sign_now = null
	for s in signs:
		if absf(p.x + p.w / 2.0 - s.x) < 26 and absf(p.y + p.h - s.y) < 30:
			sign_now = s
	if sign_now != null:
		Game.set_world_flag("log:%s:%d" % [id, int(sign_now.i)])          # read: the Logs page lists it (a world flag: the partner's page knows too)

func update_items(dt: float) -> void:
	var p = player                      # may be null: then the partner picks things up (through the network)
	var live := players()
	for it in items:
		if it.get("dead", false):
			continue
		if item_locked(it):
			continue
		if it.kind == "token" and not it.get("loose", false):         # cache: a token within 64 px of a player who has it flies to that player
			for q in live:
				var ql: Array = Game.equipped if not q.get("is_remote") else q.loadout
				if ql.has("cache") and Vector2(q.x + 5.0 - it.x, q.y + 5.0 - it.y).length() < 64.0:
					it["loose"] = true
					it["t"] = 0.4
					it["vx"] = 0.0
					it["vy"] = 0.0
					break
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
		var r := (11.0 if it.kind == "spark" else 9.0) * Game.mod_pickup_radius()
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
			if Game.mod_gzip():
				if Game.gz_bonus(Game.gz_n):
					tokens += 1
					pop(it.x, it.y - 12, "+1 gzip", Game.COL.gold)
				Game.gz_n += 1
			spark(it.x, it.y, Game.COL.goldHi, 4)
			Audio.sfx("token")
		"spark":                            # a memory fragment: 4 of them give +1 max hp
			Game.fragments += 1
			ring(it.x, it.y, 2, 30, Game.COL.clawdHi, 0.5)
			burst(it.x, it.y, 18, [Game.COL.clawd, Game.COL.clawdHi, "#fff3e4"], 130.0, 60.0, {"glow": 1})
			pop(it.x, it.y - 12, "memory chip ✳ %d/4" % ((Game.fragments - 1) % 4 + 1), "#fff3e4", true)
			show_memory(id)
			stop(0.07)
			Audio.sfx("spark")
			if Game.fragments % 4 == 0:
				p.max_hp = Game.max_hp
				p.hp = p.max_hp
				pop(it.x, it.y - 26, "+1 max hp", Game.COL.okHi, true)
			Game.write_save()
			events.append("spark")
		"plugin":
			plugin_collected(String(it.id).trim_prefix("plugin:"))
		"page":
			var pn := int(String(it.id).get_slice(":", 1))
			pop(it.x, it.y - 12, "logbook page %d/6" % pn, Game.COL.gold, true)
			burst(it.x, it.y, 8, ["#e8d9a8", "#cdb87a", "#ffffff"], 70.0, 100.0)
			Audio.sfx("spark", {"vol": 0.7})
			Game.write_save()
		"coffee":
			if Game.diff == "easy" and p.hp < p.max_hp:
				heal(p, 1)
			pop(it.x, it.y - 10, "+1 coffee", Game.COL.paper)
			burst(it.x, it.y, 8, [Game.COL.paper, Game.COL.clawd], 70.0, 100.0)
			Audio.sfx("heal")

# ---- agents (MV3-12) ----
func cast_agents(p) -> void:
	if mode == "guest":
		net_agents.emit()                  # the host simulates them (the guest only draws what the snapshot lists)
		return
	agents.append(Agent.new(p, 0))
	agents.append(Agent.new(p, 1))

func _step_agents(dt: float) -> void:
	if agents.is_empty():
		return
	var keep: Array = []
	for a in agents:
		var o = a.owner_p
		var here: bool = is_instance_valid(o) and (o == player or o in remote_players) and not o.dead
		if not here:
			continue                                   # no agent outlives its owner leaving the room (or dying)
		a.update(dt, self)
		if a.life <= 0.0:
			ring(a.x, a.y, 1, 10, "#ffe2c4", 0.25)
			pop(a.x, a.y - 6, "done", Game.COL.okHi)
			continue
		keep.append(a)
	agents = keep

# an agent pressed slot key i; when every key of the room is pressed the agents gate opens for good
func press_key(i: int) -> void:
	var key := "key:%s:%d" % [id, i]
	if Game.flag(key):
		return
	Game.flags[key] = true
	Audio.sfx("uiOk")
	var all := true
	for k in keys:
		if not Game.flag("key:%s:%d" % [id, k.i]):
			all = false
	if all and not Game.flag("gate:%s:agents" % id):
		Game.flags["gate:%s:agents" % id] = true
		Audio.sfx("gate")
		shake(0.3)
		update_doors()
	Game.write_save()

# catch (MV3-03): a catchable projectile turns around, faster, and hurts creatures instead of players. The same function runs for the
# local player's swipe, and on the host for the guest's `catch` event.
func catch_proj(q: Dictionary, by) -> void:
	q.friendly = true
	q.vx *= -1.5
	q.vy *= -1.5
	q.life = 2.0
	q.dmg = 2
	q.pierce = true
	q.hit = {}
	q["by"] = by
	Audio.sfx("clang")
	Audio.sfx("uiOk")
	stop(0.06)
	ring(q.x, q.y, 2, 16, "#ffd23f", 0.25)
	if by.has_method("gain_meter"):
		by.gain_meter()
	if by == player and Game.mod_review_cache():
		by.cache_bonus = true                              # review cache: the next claw hit of this player deals +1
	if mode != "guest" and fight.state == "active" and stats.has("caught"):
		stats.caught += 1

func switch_on(i: int) -> bool:
	return Game.flag("switch:%s:%d" % [id, i])

# a caught projectile touched switch i (host / solo); when every switch of the room is pressed the gate opens for good
func press_switch(i: int) -> void:
	var key := "switch:%s:%d" % [id, i]
	if Game.flag(key):
		return
	Game.flags[key] = true
	Audio.sfx("uiOk")
	var all := true
	for s2 in switches:
		if not Game.flag("switch:%s:%d" % [id, s2.i]):
			all = false
	if all and not Game.flag("gate:%s:catch" % id):
		Game.flags["gate:%s:catch" % id] = true
		Audio.sfx("gate")
		shake(0.3)
		if def.get("valve", false):
			Audio.sfx("roar")
			shake(0.8)
			var vsw: Dictionary = switches[i]
			pop(vsw.x + 5.0, vsw.y - 10.0, "free()  heap level 1", "#58f0c8", true)
		update_doors()
	Game.write_save()

# a plugin chip was picked up by anybody (host / solo here; the guest gets the same through Coop's `plugin` event)
func plugin_collected(pid: String, by := "p1") -> void:
	Game.flags["plugin:" + pid] = true
	show_plugin_banner(pid)
	plugin_got.emit(pid, by)
	Game.write_save()

# a plugin bought at the stall (the money has been taken by the ShopMenu): the host tells the guest like any other plugin
func plugin_bought(pid: String, by: String) -> void:
	Game.flags["plugin:" + pid] = true
	pop(player.x + 5.0 if player != null else sx_default(), (player.y - 14.0) if player != null else 40.0, "npm install " + String(Game.plugin_def(pid).get("name", pid)), "#58f0c8", true)
	plugin_got.emit(pid, by)

# curl (MVB2-03): the cable while zipping (ours and the partner's), and a bracket round the ring a [special] press would take
func _draw_curl(ci: CanvasItem) -> void:
	var list := anchors()
	var cable := func(from: Vector2, a: Dictionary) -> void:
		var to := Vector2(float(a.x), float(a.y))
		ci.draw_line(from, to, Color("#7cc4ff"), 1.0)
		ci.draw_rect(Rect2(from.x - 1, from.y - 1, 3, 3), Color("#d6f6ff"))
	for rp in remote_players:
		var cz: int = int(rp.get("cz")) if rp.get("cz") != null else -1
		if cz >= 0 and cz < list.size():
			cable.call(Vector2(rp.x + 5.0, rp.y + 5.0), list[cz])
	var p = player
	if p == null or p.dead:
		return
	if p.push_t > 0.0 and p.ssh_t <= 0.0:                      # pushing into a firewall: the bricks ahead glow (ssh, MVB2-04)
		var gdir := 1.0 if p.face > 0.0 else -1.0
		var gcol := floori((p.x + p.w + 0.5) / T) if gdir > 0.0 else floori((p.x - 0.5) / T)
		var glow := Color("#ff9ad8")
		glow.a = 0.5 + 0.5 * sin(time * 20.0)
		for gty in range(floori((p.y + 1.0) / T), floori((p.y + p.h - 1.0) / T) + 1):
			for k in range(Game.SSH_BRICKS + 1):
				var gx := gcol + k * int(gdir)
				if grid.tile(gx, gty) == TileGrid.FIRE:
					ci.draw_rect(Rect2(gx * T, gty * T, T, T), glow, false, 1.0)
	if p.zip >= 0 and p.zip < list.size():
		cable.call(Vector2(p.x + 5.0, p.y + 5.0), list[p.zip])
		return
	if mode != "guest" or true:
		Game.curl_hint = false
	if bool(p.tools.get("curl", false)) and not list.is_empty():
		var mxh := (1.0 if Controls.down.get("right", false) else 0.0) - (1.0 if Controls.down.get("left", false) else 0.0)
		var ai := pick_anchor(p, mxh)
		if ai >= 0:
			Game.curl_hint = true
			var a: Dictionary = list[ai]
			var bc := Color("#d6f6ff")
			var bx := floorf(float(a.x)) - 9.0
			var by := floorf(float(a.y)) - 9.0
			for c in [[0, 0, 1, 1], [18, 0, -1, 1], [0, 18, 1, -1], [18, 18, -1, -1]]:
				ci.draw_rect(Rect2(bx + c[0], by + c[1], 1, 4) if c[2] > 0 else Rect2(bx + c[0], by + c[1], 1, 4), bc)
				ci.draw_rect(Rect2(bx + c[0] + (0 if c[2] > 0 else -3), by + c[1] + (0 if c[3] > 0 else 3), 4, 1), bc)

# body effects of the NETWORK enemies (MVB3-02): the tag's red crosshair on both pages, JAM and a slowed body on the local one
func _draw_status(ci: CanvasItem) -> void:
	var red := Color("#ff5a5a")
	for q in tagged_players():
		var tx: float = floorf(q.x + q.w / 2.0 + 0.5)
		var ty: float = floorf(q.y + q.h / 2.0 + 0.5)
		var rr: float = 11.0 + sin(time * 12.0) * 1.5
		ci.draw_arc(Vector2(tx, ty), rr, 0.0, TAU, 20, red, 1.0)
		ci.draw_line(Vector2(tx - rr - 3.0, ty), Vector2(tx - rr + 4.0, ty), red, 1.0)
		ci.draw_line(Vector2(tx + rr - 4.0, ty), Vector2(tx + rr + 3.0, ty), red, 1.0)
		ci.draw_line(Vector2(tx, ty - rr - 3.0), Vector2(tx, ty - rr + 4.0), red, 1.0)
		ci.draw_line(Vector2(tx, ty + rr - 4.0), Vector2(tx, ty + rr + 3.0), red, 1.0)
	var p = player
	if p == null or p.dead:
		return
	if p.jam:
		var jx: float = floorf(p.x + p.w / 2.0 + 0.5)
		var jy: float = floorf(p.y + p.h / 2.0 + 0.5)
		for k in range(14):                                       # static noise on a ring
			var a: float = Game.hash3(float(k), floorf(time * 24.0), 7) * TAU
			ci.draw_rect(Rect2(jx + cos(a) * 13.0, jy + sin(a) * 13.0, 2, 1), red if k % 2 == 0 else Color("#ffd0d0"))
		PixelText.draw_text(ci, "JAM", jx, p.y - 14.0, "#ff5a5a", {"align": "c", "tiny": true, "outline": Game.COL.ink})
	if p.slow_t > 0.0:
		var sx_: float = floorf(p.x + p.w / 2.0 + 0.5)
		for k in range(3):
			ci.draw_line(Vector2(sx_ - 6.0 + k * 6.0, p.y + p.h), Vector2(sx_ - 6.0 + k * 6.0, p.y + p.h + 3.0 + sin(time * 10.0 + k)), Color("#c3bccd"), 1.0)

# ---- levers (MVB2-05): a swipe or a dash on the box sets the lever's world flag; a guest asks the host
func lever_flag(i: int) -> String:
	var l: Array = def.get("levers", [])
	return String(l[i].flag) if i < l.size() else ""

func _check_levers(p) -> void:
	if levers.is_empty() or p.dead:
		return
	var swipe: bool = p.atk_t > 0.0 and p.atk_live
	var dash: bool = p.dash_t > 0.0
	if not swipe and not dash:
		return
	for lv in levers:
		var box := {"x": float(lv.x) + 2.0, "y": float(lv.y) + 2.0, "w": 12.0, "h": 14.0}
		if (swipe and Game.overlap(p.atk_box(), box)) or (dash and Game.overlap(p.hurtbox(), box)):
			if Game.flag(lever_flag(int(lv.i))):
				continue
			if mode == "guest":
				net_lever.emit(int(lv.i))
			else:
				pull_lever(int(lv.i))

func pull_lever(i: int) -> void:
	var f := lever_flag(i)
	if f == "" or Game.flag(f):
		return
	Game.flags[f] = true
	Game.write_save()
	Audio.sfx("uiOk")
	update_doors()
	if i < levers.size():
		pop(float(levers[i].x) + 8.0, float(levers[i].y) - 6.0, "lever", Game.COL.paper, true)

# ---- the honeypot (N21): waves of DDOS bits; the room is shut until the last is dead and wave:N21 is set (host and solo; the flag travels)
func _step_wave(dt: float) -> void:
	if not def.has("wave") or mode == "guest":
		return
	var wv: Dictionary = def.wave
	if Game.flag(String(wv.flag)) or players().is_empty():
		return
	wave_ents = wave_ents.filter(func(e): return is_instance_valid(e) and not e.dead)
	if wave_i >= 0 and not wave_ents.is_empty():
		wave_t = 1.0
		return
	wave_t -= dt
	if wave_t > 0.0:
		return
	wave_i += 1
	wave_t = 1.0
	if wave_i >= wv.waves.size():
		Game.flags[String(wv.flag)] = true
		Game.write_save()
		Audio.sfx("kill")
		update_doors()
		for q in players():
			pop(q.x + 5.0, q.y - 14.0, "honeypot drained", "#58f0c8", true)
			break
		return
	for cell in wv.waves[wave_i]:
		if cell[0] is String:                                   # ["u" | "r" | "y", x, y]: a MITM, a BOTNET or a PINGER at that cell (MVB3-05)
			var te = spawn_enemy(String(cell[0]), int(cell[1]) * T, int(cell[2]) * T)
			if te != null:
				add_entity(te)
				if te.has_method("settle"):
					te.settle()
				wave_ents.append(te)                          # (a botnet's bits die with it, so the rack is the wave's whole claim)
			continue
		for e in spawn_ddos(float(int(cell[0]) * T), float(int(cell[1]) * T)):
			wave_ents.append(e)

# ---- the crawler's silhouette (N08, once per player): local, cosmetic
func _step_sighting(dt: float) -> void:
	if not def.has("sighting") or player == null or Game.flag("boss:CRAWLER"):
		return
	if sight_t < 0.0:
		if not Game.flag("seen:crawler") and player.y < float(def.sighting.row) * T:
			Game.flags["seen:crawler"] = true
			sight_t = 0.0
		return
	sight_t += dt
	if int(sight_t * 9.0) != int((sight_t - dt) * 9.0):
		Audio.local_sfx("tick", 0.12)
	if sight_t > 3.0:
		sight_t = -1.0

# the honeypot's chip sits in a glass case until the waves are drained
func item_locked(it: Dictionary) -> bool:
	return String(it.kind) == "plugin" and def.has("wave") and not Game.flag(String(def.wave.flag))

func jar_rect(j: Dictionary) -> Dictionary:
	return Decor.jar_rect(j)

# a swipe or a dash of the local player that overlaps a jar breaks it (walking into it does not): host and solo set the flag, a guest asks the host
func _check_jars(p) -> void:
	if jars.is_empty() or p.dead:
		return
	var swipe: bool = p.atk_t > 0.0 and p.atk_live
	var dash: bool = p.dash_t > 0.0
	if not swipe and not dash:
		return
	for i in range(jars.size()):
		var j: Dictionary = jars[i]
		if j.broken:
			continue
		var jr := jar_rect(j)
		if (swipe and Game.overlap(p.atk_box(), jr)) or (dash and Game.overlap(p.hurtbox(), jr)):
			if mode == "guest":
				if time - float(j.asked) > 0.6:
					j.asked = time
					net_freejar.emit(i)
			else:
				free_jar(i)

# the jar's agent is free for good (flag agent:<room>, shared); the effect plays from the flag on every page
func free_jar(_i: int) -> void:
	if Game.flag("agent:" + id):
		return
	Game.flags["agent:" + id] = true
	Game.write_save()

# the line of a memory fragment, under its pop (the table lives in Game)
func show_memory(room_id: String) -> void:
	var line := String(Game.MEMORIES.get(room_id, ""))
	if line != "":
		memory = {"text": line, "t": 6.0}

func sx_default() -> float:
	return pw / 2.0

func show_plugin_banner(pid: String) -> void:
	Audio.sfx("gate")
	pick_banner = {"text": String(Game.plugin_def(pid).get("name", pid)), "sub": String(Game.plugin_def(pid).get("desc", "equip it at a bench")), "t": 3.0}

# hostile projectile. kinds: orb, shard
func shoot(px: float, py: float, pvx: float, pvy: float, o = null) -> Dictionary:
	var q := {"id": next_pid, "x": px, "y": py, "vx": pvx, "vy": pvy, "r": 3.0, "kind": "orb", "col": Game.COL.hazard, "life": 4.0, "g": 0.0, "dmg": 1, "tile": true, "cut": true, "t": 0.0, "dead": false, "friendly": false, "catchable": false}
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
		if q.kind == "drip" and mode != "guest" and liquid_y != null and q.y > liquid_y + 3:
			q.dead = true
			continue
		if q.tile and mode != "guest" and int(q.get("bounce", 0)) > 0 and grid.solid_at(q.x, q.y):
			_bounce_proj(q, dt)
			continue
		if q.tile and mode != "guest" and grid.solid_at(q.x, q.y):
			q.dead = true
			if q.get("mark", false) and boss != null and boss.has_method("leave_mark") and not q.get("friendly", false):
				boss.leave_mark(q.x)                  # REVIEWER #2's grey shots and pens leave a comment where they land (MVB3-08)
			if q.kind == "drip":                    # a drip splashes (js: onLand); a memory leak, so always in world 3's colours
				var th3: Dictionary = Game.theme(3)
				burst(q.x, q.y - 2.0, 4, [th3.liq, th3.liqHi], 50.0, 300.0)
				if player != null and absf(q.x - player.x) < 200.0:
					Audio.sfx("drip", {"vol": 0.6})
			else:
				spark(q.x, q.y, q.col, 4)
			continue
		if q.get("friendly", false):
			if mode != "guest":
				_friendly_proj_hits(q)
			continue
		for pl in players():
			if pl.get("is_remote"):
				continue                         # the partner checks its own body
			var hb: Dictionary = pl.hurtbox()
			if not q.get("friendly", false) and not pl.gone and q.x + q.r > hb.x and q.x - q.r < hb.x + hb.w and q.y + q.r > hb.y and q.y - q.r < hb.y + hb.h:
				if pl.dash_t > 0.0 and Game.dv("dash_iframes"):
					continue
				if pl.hurt(q.dmg, q.x) and not q.get("pierce", false):
					if float(q.get("slow", 0.0)) > 0.0:
						pl.slow_t = float(q.slow)
					q.dead = true
					if mode == "guest":
						net_projhit.emit(q.id)
					spark(q.x, q.y, q.col, 5)
					break
	if projs.size() > 30:
		projs = projs.filter(func(q): return not q.dead)

# a shot with `bounce` left reflects instead of dying (MVB3-02): vx when the cell it came from is open in y (it hit a wall), vy when open in x
# (a floor or a ceiling), both in a corner; it is put back where it was
func _bounce_proj(q: Dictionary, dt: float) -> void:
	var px: float = q.x - q.vx * dt
	var py: float = q.y - q.vy * dt
	var side_solid: bool = grid.solid_at(q.x, py)           # moving in x alone runs into a wall
	var vert_solid: bool = grid.solid_at(px, q.y)           # moving in y alone runs into a floor / ceiling
	if side_solid or not vert_solid:
		q.vx = -q.vx
	if vert_solid or not side_solid:
		q.vy = -q.vy
	q.x = px
	q.y = py
	q.bounce = int(q.bounce) - 1
	Audio.sfx("tick", {"vol": 0.5})
	spark(q.x, q.y, q.col, 2)

# a caught projectile: hurts every creature it touches once, presses switches
func _friendly_proj_hits(q: Dictionary) -> void:
	for e in ents:
		if e.dead or q.hit.has(e.nid):
			continue
		for b in e.hurtboxes():
			if q.x + q.r > b.x and q.x - q.r < b.x + b.w and q.y + q.r > b.y and q.y - q.r < b.y + b.h:
				q.hit[e.nid] = true
				var by = q.get("by")
				attacker = by if by != null and is_instance_valid(by) else null
				e.hit(int(q.dmg), signf(q.vx), 0.0, "catch", b)
				spark(q.x, q.y, "#ffffff", 5)
				break
	for sw in switches:
		if q.x + q.r > sw.x and q.x - q.r < sw.x + sw.w and q.y + q.r > sw.y and q.y - q.r < sw.y + sw.h:
			press_switch(int(sw.i))

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
		"pen":                                    # a red pen falling point first
			ci.draw_rect(Rect2(px - 2, py - 7, 5, 15), ink)
			ci.draw_rect(Rect2(px - 1, py - 6, 3, 10), col)
			ci.draw_rect(Rect2(px - 1, py + 4, 3, 3), Color("#ffd0d8"))
			ci.draw_rect(Rect2(px - 1, py - 6, 1, 8), Color("#ffffff"))
		"thread":                                 # a SCRAPER's sticky thread: a 1-px line from the scraper to the shot (hgt = its network id)
			var src = null
			for e in ents:
				if e.nid == int(q.get("hgt", -1)) and not e.dead:
					src = e
					break
			var from := Vector2(q.x - q.vx * 0.12, q.y - q.vy * 0.12) if src == null else Vector2(src.cx, src.cy)
			ci.draw_line(from, Vector2(q.x, q.y), Color("#c3bccd"), 1.0)
			ci.draw_rect(Rect2(px - 1, py - 1, 3, 3), ink)
			ci.draw_rect(Rect2(px, py, 1, 1), Color("#ffffff"))
		"wave":
			var hg := int(q.get("hgt", 10.0))
			ci.draw_rect(Rect2(px - 3, py - hg, 6, hg), col)
			ci.draw_rect(Rect2(px - 1, py - hg, 2, hg - 2), Color.WHITE)
			ci.draw_rect(Rect2(px - 4, py - hg + 2, 1, hg - 2), ink)
			ci.draw_rect(Rect2(px + 3, py - hg + 2, 1, hg - 2), ink)
		"log":
			ci.draw_rect(Rect2(px - 5, py - 2, 10, 4), ink)
			ci.draw_rect(Rect2(px - 4, py - 1, 5, 2), col)
			ci.draw_rect(Rect2(px + 2, py - 1, 2, 2), Color.WHITE)
		"comment":
			PixelText.draw_text(ci, "//", px - 3, py - 3, q.col, {"outline": Game.COL.ink})
		"diamond":                                       # a catchable orb of the boss kit: a yellow diamond
			var dr: float = q.r + 1.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(px, py - dr - 1), Vector2(px + dr + 1, py), Vector2(px, py + dr + 1), Vector2(px - dr - 1, py)]), ink)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(px, py - dr), Vector2(px + dr, py), Vector2(px, py + dr), Vector2(px - dr, py)]), col)
		"err":
			Fx._disc(ci, px, py, q.r + 1, ink)
			Fx._disc(ci, px, py, q.r, col)
			ci.draw_rect(Rect2(px, py - 2, 1, 3), ink)
			ci.draw_rect(Rect2(px, py + 2, 1, 1), ink)
		_:
			Fx._disc(ci, px, py, q.r + 1, ink)
			Fx._disc(ci, px, py, q.r, col)
			Fx._disc(ci, px - 1, py - 1, maxf(0.5, q.r - 2), Color.WHITE)
	if q.get("friendly", false):                          # a caught one has a white core
		Fx._disc(ci, px, py, maxf(1.0, q.r - 2), Color.WHITE)

# ---------------------------------------------------------------- drawing of what is not an entity
# the npm registry booth: 24 x 24, wood, a pale top, a red `npm` sign and a vendor
# a packet of light: a two-tone bar with a bright front edge (the front is the +x end)
func _draw_packet(ci: CanvasItem, m: Dictionary) -> void:
	if m.off:
		return
	var x := floori(m.x + 0.5)
	var y := floori(m.y + 0.5) - 1
	var wd := int(m.w)
	if m.get("lost", false):                                  # lost: an outline, no floor
		ci.draw_rect(Rect2(x, y, wd, 6), Color(1.0, 0.35, 0.35, 0.7), false, 1.0)
		PixelText.draw_text(ci, "LOSS", x + wd / 2.0, y - 8, "#ff5a5a", {"align": "c", "tiny": true, "outline": Game.COL.ink})
		return
	if m.get("warn", false):                                  # about to be lost: red / clear at 10 Hz
		PixelText.draw_text(ci, "LOSS", x + wd / 2.0, y - 8, "#ff5a5a", {"align": "c", "tiny": true, "outline": Game.COL.ink})
		if int(time * 10.0) % 2 == 0:
			ci.draw_rect(Rect2(x - 1, y - 1, wd + 2, 8), Color(Game.COL.ink))
			ci.draw_rect(Rect2(x, y, wd, 6), Color("#c0392b"))
			ci.draw_rect(Rect2(x, y, wd, 2), Color("#ff7a6a"))
			return
		ci.draw_rect(Rect2(x, y, wd, 6), Color(1.0, 0.35, 0.35, 0.5), false, 1.0)
		return
	ci.draw_rect(Rect2(x - 1, y - 1, wd + 2, 8), Color(Game.COL.ink))
	ci.draw_rect(Rect2(x, y, wd, 6), Color("#2a8f86"))
	ci.draw_rect(Rect2(x, y, wd, 2), Color("#58f0c8"))
	ci.draw_rect(Rect2(x + wd - 4, y, 4, 6), Color("#e8fff9"))

const PORT_NUMBERS := ["22", "80", "443", "8080"]

# a closed port is a red bar with its number on the middle cell; an open one is a faint outline
func _draw_port(ci: CanvasItem, pc: Dictionary) -> void:
	var x: int = pc.tx * T
	var mid: int = (pc.ty0 + pc.ty1) / 2
	for ty in range(pc.ty0, pc.ty1 + 1):
		var open: bool = grid.port_open.has(ty * w + pc.tx)
		if open:
			ci.draw_rect(Rect2(x, ty * T, T, T), Color(1, 1, 1, 0.12), false)
			continue
		ci.draw_rect(Rect2(x + 1, ty * T, T - 2, T), Color(Game.COL.ink))
		ci.draw_rect(Rect2(x + 3, ty * T, T - 6, T), Color("#ff4f6d"))
		ci.draw_rect(Rect2(x + 3, ty * T, 2, T), Color("#ff8fa3"))
		if ty == mid:
			var label: String = PORT_NUMBERS[mini(int(pc.idx), PORT_NUMBERS.size() - 1)]
			ci.draw_rect(Rect2(x - 8, ty * T + 3, T + 16, 10), Color(Game.COL.ink))
			PixelText.draw_text(ci, label, x + 8 - PixelText.text_width(label) / 2, ty * T + 5, "#ffffff", {"tiny": true})

func _draw_stall(ci: CanvasItem, sh: Dictionary) -> void:
	var bx: float = sh.x - 12.0
	var by: float = sh.y - 24.0
	var ink := Color(Game.COL.ink)
	ci.draw_rect(Rect2(bx - 1, by - 1, 26, 26), ink)
	ci.draw_rect(Rect2(bx, by + 8, 24, 16), Color("#8f6238"))
	ci.draw_rect(Rect2(bx, by + 8, 24, 2), Color("#e2b475"))
	ci.draw_rect(Rect2(bx, by + 22, 24, 2), Color("#4e3220"))
	ci.draw_rect(Rect2(bx, by + 4, 24, 4), Color("#e2b475"))                # the top
	for st_ in range(0, 24, 6):
		ci.draw_rect(Rect2(bx + st_, by + 4, 3, 4), Color("#ff4f6d"))
	ci.draw_rect(Rect2(bx + 2, by - 3, 20, 7), Color("#ff4f6d"))           # the sign
	ci.draw_rect(Rect2(bx + 2, by - 3, 20, 1), Color("#ff9aab"))
	PixelText.draw_text(ci, "npm", bx + 12.0, by - 1.0, "#ffffff", {"align": "c", "tiny": true})
	var vx := bx + 9.0                                                       # the vendor: a face behind the counter
	ci.draw_rect(Rect2(vx, by + 10, 7, 7), Color("#f4ede0"))
	ci.draw_rect(Rect2(vx + 1, by + 12, 2, 2), ink)
	ci.draw_rect(Rect2(vx + 4, by + 12, 2, 2), ink)
	ci.draw_rect(Rect2(vx + 2, by + 15, 3, 1), ink)

# liquid goes over everything (js: the "liquid goes over everything" loop of Level.draw + G.drawLiquid)
func _draw_liquid(ci: CanvasItem) -> void:
	var has_tiles: bool = grid.tiles.has(TileGrid.LIQ)
	if not has_tiles and liquid_y == null:
		return
	var th: Dictionary = Game.theme(world)
	var cols := {"liq": Color(th.liq), "hi": Color(th.liqHi), "lo": Color(th.liqLo)}
	var cx0: float = cam.x if camera == null else camera.position.x
	var tx0 := maxi(0, floori(cx0 / T))
	var tx1 := mini(w - 1, floori((cx0 + W) / T))
	if liquid_y != null:                       # a flood: a body from the surface down, the same look as a liquid tile's top
		var ytop := roundi(liquid_y)
		for tx in range(tx0, tx1 + 1):
			_liq_col(ci, tx * T, ytop, ph + 4, cols, true)
	if not has_tiles:
		return
	for tx in range(tx0, tx1 + 1):
		var top := -1
		for ty in range(0, h + 1):
			var is_l := ty < h and grid.tiles[ty * w + tx] == TileGrid.LIQ
			if is_l and top < 0:
				top = ty
			if not is_l and top >= 0:
				var surface: bool = top > 0 and grid.tiles[(top - 1) * w + tx] != TileGrid.LIQ
				_liq_col(ci, tx * T, top * T + (4 if surface else 0), ty * T, cols, surface)
				top = -1

# one 16-px column of liquid from y0 to y1 (js: G.drawLiquid); surface: the wobbling top line and the glints
func _liq_col(ci: CanvasItem, px: int, y0: int, y1: int, cols: Dictionary, surface: bool) -> void:
	var liq: Color = cols.liq
	var liq_hi: Color = cols.hi
	var liq_lo: Color = cols.lo
	var fill_a := Color(liq.r, liq.g, liq.b, 0.5)
	var fill_b := Color(liq_lo.r, liq_lo.g, liq_lo.b, 0.45)
	if surface:
		ci.draw_rect(Rect2(px, y0 + 2, T, y1 - y0), fill_a)
		ci.draw_rect(Rect2(px, y0 + 8, T, y1 - y0 - 6), fill_b)
		for xx in range(px, px + T):
			var o := roundi(sin(xx * 0.19 + time * 2.6) * 1.2 + sin(xx * 0.07 - time * 1.7) * 1.1)
			ci.draw_rect(Rect2(xx, y0 + o, 1, 1), liq_hi)
			ci.draw_rect(Rect2(xx, y0 + o + 1, 1, 2), liq)
			if Game.hash3(xx >> 2, floori(time * 3.0 + xx * 0.01), 3) < 0.012:
				ci.draw_rect(Rect2(xx, y0 + 5 + (xx * 7) % 23, 1, 1), liq_hi)
	else:
		ci.draw_rect(Rect2(px, y0, T, y1 - y0), fill_a)
		ci.draw_rect(Rect2(px, y0, T, y1 - y0), fill_b)

# firewall bricks, bulkheads, dead code (dotted once revealed, moths while hidden), GET rings
func _draw_bricks(ci: CanvasItem) -> void:
	for c in fire_cells:
		var bx: int = c[0] * T
		var by: int = c[1] * T
		ci.draw_rect(Rect2(bx, by, T, T), Color("#a8183a"))
		var mortar := Color("#1b1226")
		var hi := Color("#ff4f6d")
		ci.draw_rect(Rect2(bx, by + 7, T, 1), mortar)
		ci.draw_rect(Rect2(bx, by + 15, T, 1), mortar)
		ci.draw_rect(Rect2(bx + 7, by, 1, 7), mortar)
		ci.draw_rect(Rect2(bx + 15, by, 1, 7), mortar)
		ci.draw_rect(Rect2(bx + 3, by + 8, 1, 7), mortar)
		ci.draw_rect(Rect2(bx + 11, by + 8, 1, 7), mortar)
		ci.draw_rect(Rect2(bx, by, 7, 1), hi)
		ci.draw_rect(Rect2(bx + 8, by, 7, 1), hi)
		ci.draw_rect(Rect2(bx, by + 8, 3, 1), hi)
		ci.draw_rect(Rect2(bx + 4, by + 8, 7, 1), hi)
		ci.draw_rect(Rect2(bx + 12, by + 8, 4, 1), hi)
	for c in thick_cells:
		if grid.tile(c[0], c[1]) != TileGrid.THICK:
			continue
		var tx0: int = c[0] * T
		var ty0: int = c[1] * T
		ci.draw_rect(Rect2(tx0, ty0, T, T), Color("#3a3346"))
		var bd := Color("#8d8798")
		ci.draw_rect(Rect2(tx0, ty0, T, 1), bd)
		ci.draw_rect(Rect2(tx0, ty0 + 15, T, 1), bd)
		ci.draw_rect(Rect2(tx0, ty0, 1, T), bd)
		ci.draw_rect(Rect2(tx0 + 15, ty0, 1, T), bd)
		var rv := Color("#c3bccd")
		for o in [[2, 2], [12, 2], [2, 12], [12, 12]]:
			ci.draw_rect(Rect2(tx0 + o[0], ty0 + o[1], 2, 2), rv)
	if not dead_cells.is_empty():
		if dead_revealed():
			var dotted := Color(0.55, 0.53, 0.6, 0.35)
			for c in dead_cells:
				var dx: int = c[0] * T
				var dy: int = c[1] * T
				for i in range(0, T, 2):
					ci.draw_rect(Rect2(dx + i, dy, 1, 1), dotted)
					ci.draw_rect(Rect2(dx + i, dy + 15, 1, 1), dotted)
					ci.draw_rect(Rect2(dx, dy + i, 1, 1), dotted)
					ci.draw_rect(Rect2(dx + 15, dy + i, 1, 1), dotted)
		else:
			var vb := verbose_cells()
			for c in vb:
				if int(time * 4.0) % 2 == 0:
					var vx: int = c[0] * T
					var vy: int = c[1] * T
					var vc := Color("#58f0c8")
					ci.draw_rect(Rect2(vx, vy, T, 1), vc)
					ci.draw_rect(Rect2(vx, vy + 15, T, 1), vc)
					ci.draw_rect(Rect2(vx, vy, 1, T), vc)
					ci.draw_rect(Rect2(vx + 15, vy, 1, T), vc)
			for g in dead_groups:
				if g.get("quiet", false):
					continue                                     # (this group has no moths: its clue is a sign, MVB2-05)
				var near_verbose := false
				for c in vb:
					if absf(c[0] * T + 8.0 - g.x) < 48.0 and absf(c[1] * T + 8.0 - g.y) < 48.0:
						near_verbose = true
				for i in range(3):
					var mx: int = floori(g.x + sin(time * 1.7 + i * 2.1) * 14.0)
					var my: int = floori(g.y + cos(time * 2.3 + i * 1.3) * 10.0 - 4.0)
					var wy := -1 if int(time * 8.0) % 2 == 0 else 1
					ci.draw_rect(Rect2(mx, my, 1, 2), Color("#58f0c8") if near_verbose else Color("#e8e0f0"))
					ci.draw_rect(Rect2(mx - 1, my + wy, 1, 1), Color("#c3bccd"))
					ci.draw_rect(Rect2(mx + 1, my + wy, 1, 1), Color("#c3bccd"))
	for rg in rings:
		var ry: float = rg.y + floori(sin(time * 2.0) * 1.5)
		ci.draw_arc(Vector2(rg.x, ry), 6.0, 0.0, TAU, 24, Color(Game.COL.ink), 4.0)
		ci.draw_arc(Vector2(rg.x, ry), 6.0, 0.0, TAU, 24, Color("#7cc4ff"), 2.0)
		PixelText.draw_text(ci, "GET", int(rg.x) - 5, int(ry) + 9, "#7cc4ff", {"tiny": true})
	for hk in hooks:
		var hy: float = hk.y + floori(sin(time * 2.0) * 1.5)
		if Game.flag("boss:CRAWLER"):                            # the crawler is gone: its hooks are GET rings now
			ci.draw_arc(Vector2(hk.x, hy), 6.0, 0.0, TAU, 24, Color(Game.COL.ink), 4.0)
			ci.draw_arc(Vector2(hk.x, hy), 6.0, 0.0, TAU, 24, Color("#7cc4ff"), 2.0)
			PixelText.draw_text(ci, "GET", int(hk.x) - 5, int(hy) + 9, "#7cc4ff", {"tiny": true})
		else:                                                    # a hook: a ring with a gap at the bottom
			ci.draw_arc(Vector2(hk.x, hk.y), 4.0, PI * 0.65, PI * 2.35, 16, Color("#8d8798"), 2.0)

# the unrevealed dead code near the local player, shown by the --verbose plugin (MV4-04)
func verbose_cells() -> Array:
	var p = player
	if p == null or dead_revealed() or not Game.mod_dead_sight():
		return []
	var out: Array = []
	var cx: float = p.x + p.w / 2.0
	var cy: float = p.y + p.h / 2.0
	for c in dead_cells:
		if Vector2(c[0] * T + 8.0 - cx, c[1] * T + 8.0 - cy).length() <= 96.0:
			out.append(c)
	return out

func draw_layer(kind: String, ci: CanvasItem) -> void:
	if kind == "furniture":
		_draw_bricks(ci)
		# closed doors: a gate column just inside the edge so the player sees why it is closed
		var gate := Gfx.tex("gate")
		for d in grid.doors:
			if d.open:
				continue
			if d.side == "W" or d.side == "E":
				var gx := 0 if d.side == "W" else pw - T
				for ty in range(d.a, d.b + 1):
					ci.draw_texture_rect_region(gate, Rect2(gx, ty * T, T, T), Rect2(7, 12, 16, 16))
			else:
				var hy := 0 if d.side == "N" else ph - 4
				for tx in range(d.a, d.b + 1):
					ci.draw_rect(Rect2(tx * T, hy, T, 4), Color(Game.COL.ink))
					ci.draw_rect(Rect2(tx * T + 1, hy + 1, 14, 2), Color("#8d8798"))
					ci.draw_rect(Rect2(tx * T + 7, hy + 1, 1, 1), Color("#c3bccd"))
		for pc in port_cols:
			_draw_port(ci, pc)
		for gc in gate_cells:
			if not grid.gates_open[gc[2]]:
				ci.draw_texture_rect_region(gate, Rect2(gc[0] * T, gc[1] * T, T, T), Rect2(7, 12, 16, 16))
		for sh in shops:
			_draw_stall(ci, sh)
		Decor.draw(self, ci)
		if tower != null:
			tower.draw(ci)
		if def.has("loop"):
			PixelText.draw_text(ci, "i = %d" % iter, float(pw) / 2.0, 40.0, "#8f6430", {"scale": 4, "align": "c"})
			if loop_key_on():
				ci.draw_rect(Rect2(loop_key.x, loop_key.y + 12, 16, 4), Color(Game.COL.ink))
				ci.draw_rect(Rect2(loop_key.x + 1, loop_key.y + 13, 14, 2), Color("#f3d58a"))
				PixelText.draw_text(ci, "break;", loop_key.x + 8.0, loop_key.y + 2.0 + sin(time * 4.0) * 1.5, "#f3d58a", {"align": "c", "tiny": true, "outline": Game.COL.ink})
		for k in keys:
			var lit := Game.flag("key:%s:%d" % [id, k.i])
			ci.draw_rect(Rect2(k.x - 3, k.y - 3, 16, 16), Color("#17131f"))
			ci.draw_rect(Rect2(k.x, k.y, 10, 10), Color("#231d2e"))
			var kc := Color("#fff3b0") if lit else Color("#ffd97a")
			ci.draw_rect(Rect2(k.x + 2, k.y + 2, 3, 3), kc)                       # the key: a ring and a shaft with two teeth
			ci.draw_rect(Rect2(k.x + 5, k.y + 3, 4, 1), kc)
			ci.draw_rect(Rect2(k.x + 7, k.y + 4, 1, 2), kc)
			ci.draw_rect(Rect2(k.x + 5, k.y + 4, 1, 1), kc)
			if lit:
				ci.draw_rect(Rect2(k.x, k.y + 9, 10, 1), Color("#7fd08a"))
		var me = player
		for st in stations:
			var cool: bool = me != null and me.cache_cool > 0.0
			var rack := Color("#3a3346") if not cool else Color("#2a2433")
			ci.draw_rect(Rect2(st.x - 1, st.y - 1, 14, 17), Color(Game.COL.ink))
			ci.draw_rect(Rect2(st.x, st.y, 12, 16), rack)
			for ro in range(3):
				ci.draw_rect(Rect2(st.x + 1, st.y + 2 + ro * 5, 10, 3), Color("#231d2e"))
				var on_l: bool = (int(time * (3.0 + ro)) + ro) % 2 == 0 and not cool
				ci.draw_rect(Rect2(st.x + 2, st.y + 3 + ro * 5, 2, 1), Color("#58f0c8") if on_l else Color("#1f4a45"))
				ci.draw_rect(Rect2(st.x + 6, st.y + 3 + ro * 5, 4, 1), Color("#3a3346"))
		for sw in switches:
			var on := switch_on(int(sw.i))
			var swc := Color("#7fd08a") if on else Color("#ffd23f")
			var sxp: float = sw.x + 5.0
			var syp: float = sw.y + 5.0
			Fx._disc(ci, sxp, syp, 6, Color(Game.COL.ink))
			if def.get("valve", false):
				Fx._disc(ci, sxp, syp, 5, Color("#7fd08a") if on else Color("#3fbfae"))
				var ink_c := Color(Game.COL.ink)
				for ang in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
					var dv := Vector2(cos(ang), sin(ang)) * 4.0
					ci.draw_line(Vector2(sxp, syp) - dv, Vector2(sxp, syp) + dv, ink_c, 1.0)
				ci.draw_rect(Rect2(sxp - 1, syp - 1, 2, 2), ink_c)
			else:
				Fx._disc(ci, sxp, syp, 5, swc)
				PixelText.draw_text(ci, "{}", sxp - 3, syp - 2, Game.COL.ink, {"tiny": true})
		for m in plats:
			if m.get("packet", false):
				_draw_packet(ci, m)
				continue
			ci.draw_texture(Gfx.tex("platform_48" if world == 1 else "platform_w%d" % Game.vis_world(world)), Vector2(floori(m.x + 0.5), floori(m.y + 0.5) - 1))
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
				"page":
					Decor.draw_page(ci, it, time)
				"plugin":
					ci.draw_rect(Rect2(ix - 6, iy - 6, 12, 12), Color(Game.COL.ink))
					ci.draw_rect(Rect2(ix - 5, iy - 5, 10, 10), Color("#231d2e"))
					for pin in range(3):
						ci.draw_rect(Rect2(ix - 7, iy - 4 + pin * 3, 2, 1), Color("#58f0c8"))
						ci.draw_rect(Rect2(ix + 5, iy - 4 + pin * 3, 2, 1), Color("#58f0c8"))
					ci.draw_rect(Rect2(ix - 3, iy - 3, 6, 6), Color("#3a3346"))
					if int(time * 3.0) % 2 == 0:
						ci.draw_rect(Rect2(ix - 1, iy - 1, 2, 2), Color("#58f0c8"))
					if item_locked(it):                                                       # (the honeypot's glass case)
						ci.draw_rect(Rect2(ix - 9, iy - 9, 18, 18), Color(0.75, 0.91, 1.0, 0.22))
						ci.draw_rect(Rect2(ix - 9, iy - 9, 18, 1), Color(0.75, 0.91, 1.0, 0.8))
						ci.draw_rect(Rect2(ix - 9, iy + 8, 18, 1), Color(0.75, 0.91, 1.0, 0.8))
						ci.draw_rect(Rect2(ix - 9, iy - 9, 1, 18), Color(0.75, 0.91, 1.0, 0.8))
						ci.draw_rect(Rect2(ix + 8, iy - 9, 1, 18), Color(0.75, 0.91, 1.0, 0.8))
	elif kind == "top":
		_draw_curl(ci)
		_draw_bp(ci)
		_draw_status(ci)
		_draw_chase(ci)
		for a in agents:
			a.draw(ci)
		for av in agent_view:
			Agent._draw_at(ci, av.x, av.y, time + av.owner * 0.7, 9.0, [])
		_draw_liquid(ci)
		for q in projs:
			if not q.dead:
				_draw_proj(ci, q)
		fx.draw(ci)
		if fx.flash > 0.0:
			var c := fx.flash_col
			c.a = minf(1.0, fx.flash)
			ci.draw_rect(Rect2(camera.position, Vector2(W, H)), c)
