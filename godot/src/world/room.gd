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
var tokens := 0
var kills := 0
var hits := 0
var cp_index := -1
var sign_now = null
var auto_step := true
var rng := RandomNumberGenerator.new()
var cam := {"x": 0.0, "y": 0.0, "ty": 0.0, "look": 0.0, "lock": null}
var fx: Fx
var view: RoomView
var camera: Camera2D
var layers := {}
var liquid_y = null
var blink_period := 1.5
var rows: PackedStringArray = PackedStringArray()

func _ready() -> void:
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if not auto_step:
		return
	Controls.poll()
	step(Game.STEP)

# ---------------------------------------------------------------- loading
func load_room(room_id: String) -> void:
	id = room_id
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/rooms.json"))
	def = meta[room_id]
	rows = FileAccess.get_file_as_string("res://src/world/rooms/" + def.file).split("\n")
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, r.length())
	pw = w * T
	ph = h * T
	grid.w = w
	grid.h = h
	grid.tiles = PackedByteArray()
	grid.tiles.resize(w * h)
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
				grid.tiles[ty * w + tx] = TileGrid.CHARS[ch]
				continue
			match ch:
				" ", ".", "|":
					pass
				"P":
					start = {"x": float(x + 3), "y": float(y + 6)}
				"C":
					cps.append({"x": x + 8, "y": y + T, "on": false})
				"S":
					springs.append({"x": x + 2, "y": y + 9, "w": 12, "h": 7, "t": 0.0})
				"o":
					items.append({"kind": "token", "x": float(x + 8), "y": float(y + 8), "id": item_id, "ph": tx * 0.7})
					item_id += 1
				"*":
					spark_spots.append({"x": x + 8, "y": y + 8})
				"H":
					items.append({"kind": "coffee", "x": float(x + 8), "y": float(y + 9), "id": item_id, "ph": 0.0})
					item_id += 1
				"T":
					var texts: Array = def.get("signs", [])
					signs.append({"x": x + 8, "y": y + T, "text": texts[sign_n] if sign_n < texts.size() else "..."})
					sign_n += 1
				"M", "V":
					_add_platform(ch, tx, ty, rows)
				"E", "B", "E ":
					pass
				_:
					var e = spawn_enemy(ch, x, y)
					if e != null:
						ents.append(e)
	spark_spots.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in range(mini(3, spark_spots.size())):
		items.append({"kind": "spark", "x": float(spark_spots[i].x), "y": float(spark_spots[i].y), "idx": i, "ph": i, "ghost": false})
	rng.seed = 1
	if cp_index >= 0 and cp_index < cps.size():
		cps[cp_index].on = true
		start = {"x": cps[cp_index].x - 5.0, "y": cps[cp_index].y - 10.0}

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
	return null          # MV1-06

# the nodes that draw the room; called once after load_room
func build_nodes() -> void:
	view = RoomView.new()
	view.name = "View"
	add_child(view)
	view.build(self)
	fx = Fx.new(self)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	snap_cam()

func reserved(tx: int, ty: int) -> bool:
	if ty < 0 or ty >= rows.size() or tx >= rows[ty].length():
		return false
	var ch := rows[ty][tx]
	return ch != " " and ch != "."

# ---------------------------------------------------------------- camera
func snap_cam() -> void:
	var t := cam_target()
	cam.x = t[0]
	cam.y = t[1]
	camera.position = Vector2(floori(cam.x + 0.5), floori(cam.y + 0.5))

func cam_target() -> Array:
	var tx: float = start.x + 5 - W / 2.0
	var ty: float = start.y + 10 - H * 0.64
	if pw <= W:
		tx = (pw - W) / 2.0
	else:
		tx = clampf(tx, 0.0, pw - W)
	if ph <= H:
		ty = ph - H
	else:
		ty = clampf(ty, 0.0, ph - H)
	return [tx, ty]

# ---------------------------------------------------------------- simulation
func step(_dt: float) -> void:
	pass          # MV1-05
