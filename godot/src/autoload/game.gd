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
				var px := rows[ty].find("P")
				if px >= 0:
					m["start_pos"] = [px * 16 + 3, ty * 16 + 6]

func flag(key: String) -> bool:
	return bool(flags.get(key, false))

# ---- difficulty (docs/metroidvania/05-difficulty-model.md, changes from 00-decisions.md §11) ----
const DIFF := {
	"easy":      {"start_hp": 7, "big_hit": 1, "boss_hp_mult": 0.7, "enemy_hp_mult": 1.0, "enemy_hp_extra": 0, "meter_per_hit": 16, "telegraph_mult": 1.3, "punish_mult": 1.3, "inv_after_hit": 1.6, "dash_iframes": true},
	"normal":    {"start_hp": 5, "big_hit": 2, "boss_hp_mult": 1.0, "enemy_hp_mult": 1.0, "enemy_hp_extra": 0, "meter_per_hit": 11, "telegraph_mult": 1.0, "punish_mult": 1.0, "inv_after_hit": 1.3, "dash_iframes": false},
	"hard":      {"start_hp": 5, "big_hit": 2, "boss_hp_mult": 1.3, "enemy_hp_mult": 1.0, "enemy_hp_extra": 1, "meter_per_hit": 11, "telegraph_mult": 1.0, "punish_mult": 1.0, "inv_after_hit": 1.3, "dash_iframes": false},
	"nightmare": {"start_hp": 3, "big_hit": 2, "boss_hp_mult": 1.6, "enemy_hp_mult": 1.5, "enemy_hp_extra": 2, "meter_per_hit": 8, "telegraph_mult": 1.0, "punish_mult": 0.9, "inv_after_hit": 1.0, "dash_iframes": false},
}
const FOCUS_COST := 33
const FOCUS_HOLD := 0.25       # hold [special] this long before focus starts
const FOCUS_TIME := 0.9
const METER_MAX := 99

func dv(key: String):
	return DIFF[diff][key]

# max hp = the start value of the difficulty + one per 4 memory fragments
var max_hp: int:
	get: return int(DIFF[diff].start_hp) + fragments / 4

# js/diff.js scale() with the numbers of the table above: every creature once
func scale_enemy(e) -> void:
	var base: int = e.hp
	e.hp = ceili(base * float(dv("enemy_hp_mult")) - 1e-9) + int(dv("enemy_hp_extra"))
	if e.loot > 0 and base > 0:
		e.loot = roundi(e.loot * float(e.hp) / base)         # tougher creatures drop more tokens

# ---- the save (user://save.json; on the web this is IndexedDB, it survives reloads) ----
var persist := true                 # false in tests, selftest and screenshot runs
var save_path := "user://save.json"
var settings_path := "user://settings.json"
var vol_music := 10                 # 0..10 (settings)
var vol_sfx := 10
var diff_from_url := false
var bench := ""                     # the room whose bench is the respawn point ("" = the start)
var tokens := 0
var fragments := 0
var diff := "normal"               # easy | normal | hard | nightmare
var coop_hp_pct := 50
var play_time := 0.0
var deaths := 0
var fights: Array = []

func fresh() -> void:
	flags = {}
	tools = {"bash": false, "sudo": false, "agents": false, "opus": false}
	bench = ""
	tokens = 0
	fragments = 0
	play_time = 0.0
	deaths = 0
	fights = []

# settings live in their own file so the guest (who has no save) keeps them too
func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if typeof(d) != TYPE_DICTIONARY:
		return
	if not diff_from_url and DIFF.has(String(d.get("diff", ""))):
		diff = String(d.diff)
	coop_hp_pct = clampi(int(d.get("coop_hp_pct", coop_hp_pct)), 25, 100)
	vol_music = clampi(int(d.get("vol_music", vol_music)), 0, 10)
	vol_sfx = clampi(int(d.get("vol_sfx", vol_sfx)), 0, 10)
	if d.get("fps30", false):
		fps30 = true
		Engine.max_fps = 30

func save_settings() -> void:
	if not persist:
		return
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"diff": diff, "coop_hp_pct": coop_hp_pct, "vol_music": vol_music, "vol_sfx": vol_sfx, "fps30": fps30}))

# Host co-op needs the PC server: only on localhost (the relay refuses other hosts), or natively with --net=host
func host_allowed() -> bool:
	if OS.has_feature("web"):
		var h := str(JavaScriptBridge.eval("location.hostname"))
		return h == "localhost" or h == "127.0.0.1"
	return net_role == "host"

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
# co-op (MV2-07): ?host / ?join=<code> on the web, --net=host|guest --port=<p> --code=<c> --scenario=<s> natively
var net_role := ""
var net_port := 3000
var net_code := ""
var scenario := ""
var autotest := false
var play_now := false               # ?play: no title screen

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
			"host": net_role = "host"
			"join": net_role = "guest"; net_code = v
			"net": net_role = v
			"port": net_port = int(v)
			"code": net_code = v
			"scenario": scenario = v
			"autotest": autotest = true
			"play": play_now = true
			"diff": diff = v; diff_from_url = true
			"scene": scene = v
			"wait": shot_wait = int(v)
			"full": full_shot = true
	if fps30:
		Engine.max_fps = 30
	if test_name != "" or selftest or shot_path != "" or demo or net_role == "guest" or scenario != "":
		persist = false
	if persist:
		load_settings()
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
