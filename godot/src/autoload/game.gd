extends Node
# Game: constants shared by everything, flags read once from the URL, and the helpers every port of the JS code needs.

const W := 384
const H := 216
const T := 16
const STEP := 1.0 / 60.0

# G.COL from the current game (js/art.js)
const COL := {
	"ink": "#1b1226", "night": "#0d0a12", "paper": "#f4ede0", "dim": "#8d8798",
	"clawd": "#d77757", "clawdHi": "#f0a184", "clawdLo": "#a8512f", "eye": "#1a1213",
	"gold": "#f2c14e", "goldHi": "#fff1b8", "goldLo": "#b9792a",
	"hazard": "#ff4f6d", "hazardHi": "#ffd0d6", "hazardLo": "#a8183a",
	"ok": "#7fd08a", "okHi": "#d6ffd0", "bad": "#ff5d5d", "mint": "#58f0c8", "sky": "#7cc4ff",
}

# persistent world flags: room:<id>:visited, bench:<id>, item:<room>:<n>, crack:<room>:<tx>:<ty>, boss:NULL, ability:bash
var flags := {}
var rooms_meta := {}

func load_meta() -> void:
	if rooms_meta.is_empty():
		rooms_meta = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/rooms.json"))
		# bench positions (letter C) for the map and the travel list
		for id in rooms_meta.rooms:
			var m: Dictionary = rooms_meta.rooms[id]
			m["benches"] = []
			var rows := FileAccess.get_file_as_string("res://src/world/rooms/" + m.file).split("\n")
			for ty in range(rows.size()):
				var tx := rows[ty].find("C")
				if tx >= 0:
					m.benches.append([tx, ty])

func flag(key: String) -> bool:
	return bool(flags.get(key, false))

# ---- the save (user://save.json; on the web this is IndexedDB, it survives reloads) ----
var persist := true                 # false in tests, selftest and screenshot runs
var save_path := "user://save.json"
var bench := ""                     # the room whose bench is the respawn point ("" = the start)
var tokens := 0
var max_hp := 5
var fragments := 0
var diff := "normal"
var coop_hp_pct := 50
var play_time := 0.0
var deaths := 0
var fights: Array = []

func fresh() -> void:
	flags = {}
	tools = {"bash": false, "sudo": false, "agents": false, "opus": false}
	bench = ""
	tokens = 0
	max_hp = 5
	fragments = 0
	play_time = 0.0
	deaths = 0
	fights = []

func save_exists() -> bool:
	return FileAccess.file_exists(save_path)

func new_game() -> void:
	fresh()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func write_save() -> void:
	if not persist:
		return
	var d := {"version": 1, "flags": flags, "tools": tools, "bench": bench, "tokens": tokens, "max_hp": max_hp, "fragments": fragments,
		"diff": diff, "coop_hp_pct": coop_hp_pct, "time": play_time, "deaths": deaths, "fights": fights}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

func load_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	fresh()
	flags = d.get("flags", {})
	for k in d.get("tools", {}):
		tools[k] = d.tools[k]
	bench = String(d.get("bench", ""))
	tokens = int(d.get("tokens", 0))
	max_hp = int(d.get("max_hp", 5))
	fragments = int(d.get("fragments", 0))
	diff = String(d.get("diff", "normal"))
	coop_hp_pct = int(d.get("coop_hp_pct", 50))
	play_time = float(d.get("time", 0.0))
	deaths = int(d.get("deaths", 0))
	fights = d.get("fights", [])
	return true

# the player's top-left when standing on the bench of a room
func bench_spawn(room_id: String):
	load_meta()
	var b: Array = rooms_meta.rooms[room_id].benches
	if b.is_empty():
		return null
	return Vector2(b[0][0] * 16 + 3, b[0][1] * 16 + 6)

# the tools Clawd owns (phase 1 test build: bash only)
var tools := {"bash": false, "sudo": false, "agents": false, "opus": false}
var shake_opt := 1.0
var low_fx := false          # G.save.data.opt.min

# query options: ?debug ?fps30 ?mute ?selftest (web) or user args (native)
var debug := false
var fps30 := false
var mute := false
var selftest := false
var test_name := ""
var shot_path := ""
var demo := false
var scene := ""
var shot_wait := 30
var full_shot := false
var build_text := "dev"
var touch_seen := false

func _ready() -> void:
	var q := ""
	if OS.has_feature("web"):
		q = str(JavaScriptBridge.eval("location.search"))
	else:
		q = "?" + "&".join(OS.get_cmdline_user_args())
	for part in q.trim_prefix("?").split("&", false):
		var kv := part.split("=", false, 1)
		var k := kv[0].trim_prefix("--")
		var v := kv[1] if kv.size() > 1 else ""
		match k:
			"debug": debug = true
			"fps30": fps30 = true
			"mute": mute = true
			"selftest": selftest = true
			"test": test_name = v
			"shot": shot_path = v
			"demo": demo = true
			"scene": scene = v
			"wait": shot_wait = int(v)
			"full": full_shot = true
	if fps30:
		Engine.max_fps = 30
	if test_name != "" or selftest or shot_path != "" or demo:
		persist = false
	if FileAccess.file_exists("res://build.txt"):
		build_text = FileAccess.get_file_as_string("res://build.txt").strip_edges()

# ---- math helpers (exact ports of G.* in js/core.js) ----
static func approach(v: float, target: float, step: float) -> float:
	return minf(v + step, target) if v < target else maxf(v - step, target)

static func damp(a: float, b: float, rate: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * dt))

static func sign_of(v: float) -> float:
	return -1.0 if v < 0.0 else (1.0 if v > 0.0 else 0.0)

static func overlap(a, b) -> bool:
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y

# JS ToInt32 of a double
static func _i32(f: float) -> int:
	var i := int(fposmod(f, 4294967296.0))
	return i - 4294967296 if i >= 2147483648 else i

# G.hash: deterministic hash -> [0,1). Done in doubles on purpose: the JS products exceed 2^53 and round, and the results must match.
static func hash3(x, y = 0, s = 0) -> float:
	var h0 := _i32(float(int(x)) * 374761393.0 + float(int(y)) * 668265263.0 + float(int(s)) * 2147483647.0)
	var a := (h0 & 0xFFFFFFFF) >> 13
	var h2 := _i32(float(h0 ^ a) * 1274126177.0)
	var b := (h2 & 0xFFFFFFFF) >> 16
	var h3 := h2 ^ b
	return float(h3 & 0xFFFFFFFF) / 4294967296.0
