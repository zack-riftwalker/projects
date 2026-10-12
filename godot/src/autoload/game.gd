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

var _themes := {}

# G.THEME[w] captured as JSON (tools/godot/capture: theme): liquid, platform and accent colours of a world
func theme(w: int) -> Dictionary:
	if not _themes.has(w):
		_themes[w] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/theme/w%d.json" % w))
	return _themes[w]

# a lab room is a test room: never on the map, never in Travel, never counted
func is_lab(room_id: String) -> bool:
	return bool(rooms_meta.rooms.get(room_id, {}).get("lab", false))

# the zones in map legend order (MVB1-02). `path` is what a player sees as the place's address.
const ZONES := [
	{"id": "src", "name": "THE SOURCE TREE", "path": "~/src", "col": "#3fa46a"},
	{"id": "dep", "name": "DEPENDENCY DEPTHS", "path": "~/node_modules", "col": "#c9792a"},
	{"id": "heap", "name": "THE HEAP", "path": "/proc/heap", "col": "#3cbfaa"},
	{"id": "net", "name": "THE NETWORK", "path": "/net", "col": "#5078e6"},
	{"id": "tower", "name": "THREAD TOWER", "path": "/dev/threads", "col": "#c8a05a"},
	{"id": "git", "name": "GIT HISTORY", "path": ".git", "col": "#e6783c"},
	{"id": "hell", "name": "DEPENDENCY HELL", "path": "~/node_modules/**", "col": "#9a5ac8"},
	{"id": "prod", "name": "PRODUCTION", "path": "/var/prod", "col": "#dc3c3c"},
	{"id": "lab", "name": "LAB", "path": "/tmp/lab", "col": "#8a8f99"},
]

func zone_def(zone_id: String) -> Dictionary:
	for z in ZONES:
		if z.id == zone_id:
			return z
	return {}

func zone_of(room_id: String) -> String:
	return String(rooms_meta.rooms.get(room_id, {}).get("zone", ""))

# a secret room is on the map only once it has been found (committed); an `offmap` room never is
func is_secret(room_id: String) -> bool:
	return bool(rooms_meta.rooms.get(room_id, {}).get("secret", false))

func is_offmap(room_id: String) -> bool:
	return bool(rooms_meta.rooms.get(room_id, {}).get("offmap", false))

# One parser for every `if` in the room data (decor, sign alts, variants): "<flag>", "!<flag>", "flood>0", "flood==0"
func cond(s: String) -> bool:
	if s.begins_with("!"):
		return not cond(s.substr(1))
	if s == "flood>0":
		return heap_flood() > 0
	if s == "flood==0":
		return heap_flood() == 0
	return flag(s)

# the rooms the pause map draws: visited, and not a lab room
func map_rooms() -> Array:
	var out: Array = []
	for id in rooms_meta.rooms:
		if flag("room:%s:visited" % id) and not is_lab(id):
			out.append(id)
	return out

# ---- the map (MVB1-03). Staged = walked by this player (room:<id>:visited); committed = a world flag mapped:<id>, set when somebody rests
# at a bench; owned = map:<zone>, bought from the cartographer `tree`. What may be drawn is one function, map_view().
func is_mapped(room_id: String) -> bool:
	return flag("mapped:" + room_id)

func _mappable(room_id: String) -> bool:
	return rooms_meta.rooms.has(room_id) and not is_lab(room_id) and not is_offmap(room_id)

func staged_rooms() -> Array:
	var out: Array = []
	for id in rooms_meta.rooms:
		if flag("room:%s:visited" % id) and _mappable(id) and not is_mapped(id):
			out.append(id)
	return out

# commits the listed rooms (and returns how many were new)
func commit_rooms(ids: Array) -> int:
	var n := 0
	for id in ids:
		if _mappable(String(id)) and not is_mapped(String(id)):
			flags["mapped:" + String(id)] = true
			n += 1
	return n

func owns_map(zone_id: String) -> bool:
	return flag("map:" + zone_id)

# {outline: every room the index lists, filled: the committed rooms}; nothing at all for a zone whose index is not owned
func map_view(zone_id: String) -> Dictionary:
	var out := {"outline": [], "filled": []}
	if not owns_map(zone_id):
		return out
	for id in rooms_meta.rooms:
		var m: Dictionary = rooms_meta.rooms[id]
		if String(m.get("zone", "")) != zone_id or not _mappable(id):
			continue
		if not bool(m.get("secret", false)):
			out.outline.append(id)
		if is_mapped(id):
			out.filled.append(id)
	return out

# "rooms n/N" of a zone: committed rooms that count (a secret never does) over the rooms its index lists
func zone_counts(zone_id: String) -> Array:
	var v := map_view(zone_id)
	var n := 0
	for id in v.filled:
		if not is_secret(id):
			n += 1
	return [n, v.outline.size()]

# an old save (before the map had to be bought): what it had walked is committed and its zones are indexed, once
func migrate_map() -> void:
	if flag("map:migrated"):
		return
	for id in rooms_meta.rooms:
		if flag("room:%s:visited" % id) and _mappable(id):
			flags["mapped:" + id] = true
			flags["map:" + zone_of(id)] = true
	flags["map:migrated"] = true

func flag(key: String) -> bool:
	return bool(flags.get(key, false))

# world state: flags that every player's world needs (a hatch the host opened must open for the guest too); they travel in snapshots
const WORLD_PREFIXES := ["boss:", "hatch:", "link:", "thread:", "lever:", "lab:", "map:", "mapped:", "changelog:", "log:", "agent:", "page:"]
const _WORLD_HEADS := ["boss", "hatch", "link", "thread", "lever", "lab", "map", "mapped", "changelog", "log", "agent", "page"]

func is_world_flag(ks: String) -> bool:
	var c := ks.find(":")
	return c > 0 and _WORLD_HEADS.has(ks.substr(0, c))

func world_flags() -> Array:
	var out: Array = []
	for k in flags:
		if flags[k] and is_world_flag(String(k)):
			out.append(String(k))
	out.sort()
	return out

# A short number for "which world flags are set" (MVB1-01): the sum of one hash per flag, so it does not depend on the order flags were set in.
# The host sends the full list only to a guest whose number differs. `extra` is state that travels beside the flags (the pins, MVB1-08).
func world_digest() -> int:
	var acc := 0
	for k in flags:
		if flags[k]:
			var ks := String(k)
			if is_world_flag(ks):
				acc = (acc + (ks.hash() * 2654435761 & 0xFFFFFFFF)) & 0xFFFFFFFF
	return (acc + pins_digest()) & 0xFFFFFFFF

# where the other player is ({room, x, y} while a partner is connected, else {}); Coop keeps it, the map and travel read it
var partner := {}

func pins_digest() -> int:
	return 0

# THE HEAP's water level: 2 = flooded, 1 = after the valve (free.c), 0 = after THE LEAK. The guest reads the host's (snapshot `fl`).
var flood_net := -1          # guest: the host's flood level from the last snapshot (-1 = none yet)
func heap_flood() -> int:
	if net_role == "guest" and flood_net >= 0:
		return flood_net
	if flag("boss:LEAK"):
		return 0
	if flag("gate:H07:catch"):
		return 1
	return 2

# ---- difficulty (docs/metroidvania/05-difficulty-model.md, changes from 00-decisions.md §11) ----
const DIFF := {
	"easy":      {"catch_window": 0.14, "start_hp": 7, "big_hit": 1, "boss_hp_mult": 0.7, "enemy_hp_mult": 1.0, "enemy_hp_extra": 0, "meter_per_hit": 16, "telegraph_mult": 1.3, "punish_mult": 1.3, "inv_after_hit": 1.6, "dash_iframes": true},
	"normal":    {"catch_window": 0.1, "start_hp": 5, "big_hit": 2, "boss_hp_mult": 1.0, "enemy_hp_mult": 1.0, "enemy_hp_extra": 0, "meter_per_hit": 11, "telegraph_mult": 1.0, "punish_mult": 1.0, "inv_after_hit": 1.3, "dash_iframes": false},
	"hard":      {"catch_window": 0.1, "start_hp": 5, "big_hit": 2, "boss_hp_mult": 1.3, "enemy_hp_mult": 1.0, "enemy_hp_extra": 1, "meter_per_hit": 11, "telegraph_mult": 1.0, "punish_mult": 1.0, "inv_after_hit": 1.3, "dash_iframes": false},
	"nightmare": {"catch_window": 0.08, "start_hp": 3, "big_hit": 2, "boss_hp_mult": 1.6, "enemy_hp_mult": 1.5, "enemy_hp_extra": 2, "meter_per_hit": 8, "telegraph_mult": 1.0, "punish_mult": 0.9, "inv_after_hit": 1.0, "dash_iframes": false},
}
# Boss hp (decision D9): T seconds of fight x R_PLAYER claw hits per player per second x u (how hard the boss is to hit).
# PROVISIONAL: replaced by the value measured from the fight list (pause > Fights). Never inline boss hp numbers.
const R_PLAYER := 1.0
const FOCUS_COST := 33
const FOCUS_HOLD := 0.25       # hold [special] this long before focus starts
const FOCUS_TIME := 0.9
const METER_MAX := 99

var strike_seq := 0                   # strike ids (catchable boss strikes): unique for the session, so a new boss never reuses a parried one
func next_strike_id() -> int:
	strike_seq += 1
	return strike_seq

func boss_hp(b: Dictionary) -> int:
	return maxi(1, roundi(float(b.T) * R_PLAYER * float(b.u) * float(dv("boss_hp_mult"))))

# ---- plugins (MV3-06): like the charms of Hollow Knight. Owned = flag plugin:<id> (shared by both players); equipped = this player's own list ----
const NOTCHES := 3                    # the "context window"
const PLUGINS := [
	{"id": "async_await", "name": "async/await", "cost": 2, "price": 0, "desc": "dash recharges twice as fast"},
	{"id": "cache", "name": "cache", "cost": 1, "price": 0, "desc": "tokens fly to you from farther away"},
	{"id": "hot_reload", "name": "hot-reload", "cost": 2, "price": 90, "desc": "healing (hold special) is much faster"},
	{"id": "eslint_fix", "name": "eslint --fix", "cost": 1, "price": 60, "desc": "every hit fills the meter a bit more"},
	{"id": "try_finally", "name": "try/finally", "cost": 1, "price": 80, "desc": "longer safe time after you get hurt"},
	{"id": "rubber_duck", "name": "rubber duck", "cost": 2, "price": 140, "desc": "at 1 hp your claw hits twice as hard"},
	{"id": "verbose", "name": "--verbose", "cost": 1, "price": 0, "desc": "dead code near you blinks green"},
	{"id": "restart_always", "name": "restart: always", "cost": 1, "price": 0, "desc": "come back from a bench with a full meter"},
]
var equipped: Array = []              # plugin ids (saved; the guest keeps its own in user://profile.json)
signal loadout_changed

func plugin_def(id: String) -> Dictionary:
	for d in PLUGINS:
		if d.id == id:
			return d
	return {}

func owns_plugin(id: String) -> bool:
	return flag("plugin:" + id)

func notches_used(list = null) -> int:
	var n := 0
	for id in (equipped if list == null else list):
		n += int(plugin_def(String(id)).get("cost", 0))
	return n

# the loadout that may really be on: known, owned (flag plugin:<id>, shared by both players) and within the context window, in order
func filter_loadout(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var d := plugin_def(String(id))
		if d.size() > 0 and owns_plugin(String(id)) and not out.has(String(id)) and notches_used(out) + int(d.cost) <= NOTCHES:
			out.append(String(id))
	return out

# at a bench: put a plugin on or take it off; false when it is not owned or the context window is full
func toggle_plugin(id: String) -> bool:
	if equipped.has(id):
		equipped.erase(id)
	else:
		var d := plugin_def(id)
		if d.is_empty() or not owns_plugin(id) or notches_used() + int(d.cost) > NOTCHES:
			return false
		equipped.append(id)
	loadout_changed.emit()
	if net_role == "guest":
		save_profile()
	else:
		write_save()
	return true

# the numbers a plugin changes; nothing else in the game checks plugin ids. `list` = another player's loadout (the host judging the guest)
func mod_dash_cd(list = null) -> float:
	return 0.1 if (equipped if list == null else list).has("async_await") else 0.2

func mod_focus_time(list = null) -> float:
	return 0.6 if (equipped if list == null else list).has("hot_reload") else FOCUS_TIME

func mod_meter_bonus(list = null) -> int:
	return 5 if (equipped if list == null else list).has("eslint_fix") else 0

func mod_inv_bonus(list = null) -> float:
	return 0.4 if (equipped if list == null else list).has("try_finally") else 0.0

func mod_claw_mult(hp: int, list = null) -> int:
	return 2 if hp == 1 and (equipped if list == null else list).has("rubber_duck") else 1

# --verbose: dead code near you blinks (MV4-04)
func mod_dead_sight(list = null) -> bool:
	return (equipped if list == null else list).has("verbose")

# restart: always: you come back from a bench with a full meter
func mod_restart_meter(list = null) -> bool:
	return (equipped if list == null else list).has("restart_always")

func mod_pickup_radius(list = null) -> float:
	return 2.5 if (equipped if list == null else list).has("cache") else 1.0

# the guest has no save: its loadout lives in its own small file
var profile_path := "user://profile.json"

func save_profile() -> void:
	if not persist_profile():
		return
	var f := FileAccess.open(profile_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"equipped": equipped, "tokens": tokens}))

func load_profile() -> void:
	if not persist_profile() or not FileAccess.file_exists(profile_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if typeof(d) == TYPE_DICTIONARY:
		tokens = int(d.get("tokens", 0))                  # the guest's wallet is its own
	if typeof(d) == TYPE_DICTIONARY and typeof(d.get("equipped")) == TYPE_ARRAY:
		equipped = filter_loadout(d.equipped)

func persist_profile() -> bool:
	return test_name == "" and not selftest and shot_path == "" and not demo and scenario == ""

func dv(key: String):
	return DIFF.get(diff, DIFF.normal)[key]

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
	flood_net = -1
	tools = {"bash": false, "catch": false, "sudo": false, "agents": false, "opus": false}
	equipped = []
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

func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

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
	flags["map:migrated"] = true                # (a save written by this build never needs migrating)
	var d := {"version": 1, "flags": flags, "tools": tools, "bench": bench, "tokens": tokens, "max_hp": max_hp, "fragments": fragments,
		"diff": diff, "coop_hp_pct": coop_hp_pct, "time": play_time, "deaths": deaths, "fights": fights, "equipped": equipped}
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
	load_meta()
	migrate_map()
	for k in d.get("tools", {}):
		tools[k] = d.tools[k]
	bench = String(d.get("bench", ""))
	tokens = int(d.get("tokens", 0))
	fragments = int(d.get("fragments", 0))
	var sd := String(d.get("diff", "normal"))
	if not diff_from_url:                 # ?diff= wins over the save (and a damaged value falls back to normal)
		diff = sd if DIFF.has(sd) else "normal"
	coop_hp_pct = int(d.get("coop_hp_pct", 50))
	play_time = float(d.get("time", 0.0))
	deaths = int(d.get("deaths", 0))
	fights = d.get("fights", [])
	equipped = filter_loadout(d.get("equipped", []))
	return true

# the player's top-left when standing on the bench of a room
func bench_spawn(room_id: String):
	load_meta()
	var b: Array = rooms_meta.rooms[room_id].benches
	if b.is_empty():
		return null
	return Vector2(b[0][0] * 16 + 3, b[0][1] * 16 + 6)

# the tools Clawd owns (phase 1 test build: bash only)
var tools := {"bash": false, "catch": false, "sudo": false, "agents": false, "opus": false}
var shake_opt := 1.0
var low_fx := false          # G.save.data.opt.min

# query options: ?debug ?fps30 ?mute ?selftest (web) or user args (native)
var debug := false
var lab := false                    # ?debug&lab: a new game starts in the lab rooms (Z05), nothing is saved
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

# the debug log: the last 5 minutes of game and co-op events, so a session can be sent after it happened (?debug: pause > Copy log)
var log_buf: Array = []
var log_out: Array = []              # guest: its lines still to go to the host, whose log then has both sides (as the JS game)

func dlog(s: String) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	log_buf.append([t, s])
	while log_buf.size() > 4000 or (not log_buf.is_empty() and t - log_buf[0][0] > 300.0):
		log_buf.pop_front()
	if net_role == "guest":
		log_out.append(s)
		if log_out.size() > 200:
			log_out.pop_front()

# Script errors go into the debug log too (and from the phone to the PC's log): an error on the guest used to be invisible.
# Godot calls a logger from any thread, so it only queues; _process moves the lines into the log.
class ErrLog extends Logger:
	var mutex := Mutex.new()
	var q: Array = []
	var seen := {}
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var msg := "ERROR %s:%d %s" % [file.get_file(), line, rationale if rationale != "" else code]
		mutex.lock()
		var n: int = int(seen.get(msg, 0)) + 1
		seen[msg] = n
		if (n <= 3 or n % 100 == 0) and q.size() < 50:       # the same error every frame must not flood the log
			q.append(msg if n <= 3 else "%s (x%d)" % [msg, n])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass

var err_log := ErrLog.new()
var errors := 0                      # how many script errors this page had (the debug overlay shows it)

func _process(_dt: float) -> void:
	if err_log.q.is_empty():
		return
	err_log.mutex.lock()
	var lines: Array = err_log.q.duplicate()
	err_log.q.clear()
	err_log.mutex.unlock()
	for l in lines:
		errors += 1
		dlog(l)

func log_text() -> String:
	var out := "CLAWD %s | %s | diff %s | role %s\n" % [build_text, Time.get_datetime_string_from_system(), diff, net_role if net_role != "" else "solo"]
	for e in log_buf:
		var s := int(e[0])
		out += "%d:%02d.%d %s\n" % [s / 60, s % 60, int(fmod(e[0], 1.0) * 10.0), e[1]]
	return out

# clipboard, and on the web also a .txt download (a phone's clipboard may refuse)
func export_log() -> int:
	var text := log_text()
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(t){var a=document.createElement('a');a.href=URL.createObjectURL(new Blob([t],{type:'text/plain'}));a.download='clawd-log.txt';document.body.appendChild(a);a.click();a.remove();})(%s)" % JSON.stringify(text))
	return log_buf.size()

func _ready() -> void:
	OS.add_logger(err_log)
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
			"lab": lab = true
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
			"diff":
				if DIFF.has(v):
					diff = v
					diff_from_url = true
			"scene": scene = v
			"wait": shot_wait = int(v)
			"full": full_shot = true
	if fps30:
		Engine.max_fps = 30
	lab = lab and debug                 # (only together with ?debug)
	if test_name != "" or selftest or shot_path != "" or demo or net_role == "guest" or scenario != "" or lab:
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
