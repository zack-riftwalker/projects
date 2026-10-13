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
var loop_iter := {}               # loop rooms (T09): room id -> the pass this life is on (0..3); a respawn or a travel starts over

# the world whose art a room uses: world 6 (THE NETWORK) falls back to world 3's until its own tiles and theme exist
func vis_world(w: int) -> int:
	if w == 6 and not FileAccess.file_exists("res://assets/theme/w6.json"):
		return 3
	return w

# G.THEME[w] captured as JSON (tools/godot/capture: theme): liquid, platform and accent colours of a world
func theme(w: int) -> Dictionary:
	if not _themes.has(w):
		_themes[w] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/theme/w%d.json" % vis_world(w)))
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
	var of_at := s.find("of:")                 # "<k>of:<f1>,<f2>,...": at least k of the flags are set (the same form the `until:` lock parses)
	if of_at > 0 and s.substr(0, of_at).is_valid_int():
		var n := 0
		for f in s.substr(of_at + 3).split(",", false):
			if flag(String(f)):
				n += 1
		return n >= int(s.substr(0, of_at))
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

# ---- the Logs page (MVB1-10, MVB1-12) ----
# one line per memory fragment, keyed by the room that holds it (the rooms of later zones come with their zones)
const MEMORIES := {
	"R01": "02:47 — the build went red. nobody else was awake.",
	"R02": "02:51 — the first test failed: null, where something used to be.",
	"R03": "02:58 — the linter screamed about code nobody had read in years.",
	"R06": "03:02 — an old room, left in on purpose. the lamp was still on.",
	"R11": "03:20 — try/catch around everything, and then sleep.",
	"R13": "03:05 — the tests folder still had a test for two players.",
	"D01": "03:34 — npm install. one thousand and forty-two packages.",
	"D02": "03:41 — a package was unpublished. everything above it fell.",
	"D03": "03:50 — the lockfile and the code disagreed about what was true.",
	"H12": "04:20 — memory was taken and never given back.",
	"H15": "04:31 — the crash dump kept a process mid-sentence.",
	"N19": "04:47 — the backup still had last week's working build.",
	"T14": "05:12 — two threads wrote the same line at once.",
	"X13": "03:59 — the cache remembered a version that worked.",
	"G15": "05:33 — the first commit: \"hello world. for two.\"",
	"P16": "05:51 — nine minutes to deploy. the old core still holding the roof up.",
}
# the logbook pages (n -> text); the order of Panel F's switches in G15 is the relays sorted by time: 3, 1, 4, 2
const LOGBOOK := {
	1: "15:25  relay #4 clicked twice. nothing found.",
	2: "14:10  relay #1 stuck open. tapped it shut.",
	3: "15:45  relay #2: moth in relay. first actual case of bug being found.",
	4: "13:05  relay #3 warm. ran the test again.",
	5: "16:00  taped into this book. we checked the relays in the order of these times.",
	6: "15:50  panel F closed up. it ran.",
}

# the text of sign n of a room as it reads now (alts decided by the flags), with the key names of this device
func sign_text_of(room_id: String, n: int) -> String:
	var list: Array = rooms_meta.rooms.get(room_id, {}).get("signs", [])
	if n < 0 or n >= list.size():
		return ""
	var se = list[n]
	if se is Dictionary:
		for a in se.get("alt", []):
			if cond(String(a["if"])):
				return Hud._expand(String(a.text))
		return Hud._expand(String(se.text))
	return Hud._expand(String(se))

# the memory fragments picked up: [room id] in the table's order (lab rooms have none)
func memories_found() -> Array:
	var out: Array = []
	for id in MEMORIES:
		for i in range(3):
			if flag("item:%s:f%d" % [id, i]):
				out.append(id)
				break
	return out

# ---- obstacles (MVB1-07): what the map marks with an unnamed `?` until the player has passed it ----
const OBSTACLES := {"%": "bash", "!": "catch", "&": "agents", "k": "agents", "@": "curl", "c": "curl", "N": "ssh", "A": "breakpoint", "5": "opus"}
const CHANGELOG_WORDS := {"bash": "gives way to bash", "catch": "answers to catch", "agents": "waits for agents", "curl": "answers to curl", "ssh": "lets ssh through", "breakpoint": "stops under breakpoint", "opus": "gives way to opus"}
var _obst_cache := {}

# the groups of obstacle cells of a room, from its file (one group = 4-connected cells of one letter): {letter, ability, cells, mid, keys}
func obstacle_groups(room_id: String) -> Array:
	if _obst_cache.has(room_id):
		return _obst_cache[room_id]
	var out: Array = []
	var rows := FileAccess.get_file_as_string("res://src/world/rooms/" + String(rooms_meta.rooms[room_id].file)).split("\n")
	var seen := {}
	var key_n := 0
	var key_index := {}
	for ty in range(rows.size()):
		for tx in range(rows[ty].length()):
			if rows[ty][tx] == "k":
				key_index[Vector2i(tx, ty)] = key_n
				key_n += 1
	for ty in range(rows.size()):
		for tx in range(rows[ty].length()):
			var ch: String = rows[ty][tx]
			if not OBSTACLES.has(ch) or seen.has(Vector2i(tx, ty)):
				continue
			if ch == "A" and not _busy_piston_at(room_id, tx, ty):
				continue                                         # (only the busy pistons are an obstacle: breakpoint gets past them)
			var cells: Array = []
			var stack := [Vector2i(tx, ty)]
			seen[Vector2i(tx, ty)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				cells.append([c.x, c.y])
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + o
					if n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < rows[n.y].length() and rows[n.y][n.x] == ch and not seen.has(n):
						seen[n] = true
						stack.append(n)
			var mean := Vector2.ZERO
			for c in cells:
				mean += Vector2(c[0], c[1])
			mean /= float(cells.size())
			var mid: Array = cells[0]
			for c in cells:
				if Vector2(c[0], c[1]).distance_to(mean) < Vector2(mid[0], mid[1]).distance_to(mean):
					mid = c
			var keys: Array = []
			if ch == "k":
				for c in cells:
					keys.append(key_index[Vector2i(c[0], c[1])])
			out.append({"letter": ch, "ability": OBSTACLES[ch], "cells": cells, "mid": mid, "keys": keys})
	_obst_cache[room_id] = out
	return out

# is the `A` cell the casing of a piston that never rests (rooms.json `pistons`, busy: true)?
func _busy_piston_at(room_id: String, tx: int, ty: int) -> bool:
	for pz in rooms_meta.rooms[room_id].get("pistons", []):
		if bool(pz.get("busy", false)) and ty == int(pz.y) and tx >= int(pz.x) and tx < int(pz.x) + int(pz.get("w", 1)):
			return true
	return false

# a crack broken, a gate opened, a slot key pressed
func obstacle_passed(room_id: String, g: Dictionary) -> bool:
	match String(g.letter):
		"%":
			for c in g.cells:
				if flag("crack:%s:%d:%d" % [room_id, c[0], c[1]]):
					return true
			return false
		"!": return flag("gate:%s:catch" % room_id)
		"&": return flag("gate:%s:agents" % room_id)
		"5":
			for c in g.cells:
				if flag("cable:%s:%d:%d" % [room_id, c[0], c[1]]):
					return true
			return false
		"k":
			for i in g.keys:
				if not flag("key:%s:%d" % [room_id, i]):
					return false
			return true
	return false

# the dead code of a room that nobody has found: the map never points at it
func _near_hidden_dead(room_id: String, g: Dictionary) -> bool:
	if flag("dead:" + room_id):
		return false
	var rows := FileAccess.get_file_as_string("res://src/world/rooms/" + String(rooms_meta.rooms[room_id].file)).split("\n")
	for c in g.cells:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var y: int = c[1] + dy
				var x: int = c[0] + dx
				if y >= 0 and y < rows.size() and x >= 0 and x < rows[y].length() and rows[y][x] == ";":
					return true
	return false

# the `?` marks of a room (tile cells): one per unpassed group, none next to dead code that has not been revealed
func obstacle_marks(room_id: String) -> Array:
	var out: Array = []
	for g in obstacle_groups(room_id):
		if obstacle_passed(room_id, g) or _near_hidden_dead(room_id, g):
			continue
		out.append({"x": g.mid[0], "y": g.mid[1], "ability": g.ability})
	return out

# the changelog (option A): an ability gained since the last time a terminal said so. Returns the lines to show and sets `changelog:<ability>`.
var changelog_lines: Array = []         # everything that was said (the Logs page lists it)
func changelog_pending() -> Array:
	var out: Array = []
	for a in tools:
		if tools[a] and not flag("changelog:" + String(a)):
			out.append(String(a))
	return out

func changelog_commit() -> Array:
	var lines: Array = []
	for a in changelog_pending():
		if CHANGELOG_WORDS.has(a):
			for z in ZONES:
				var hit := false
				for id in map_view(z.id).filled:
					for g in obstacle_groups(id):
						if g.ability == a and not obstacle_passed(id, g) and not _near_hidden_dead(id, g):
							hit = true
				if hit:
					lines.append("changelog: something in %s %s" % [z.path, CHANGELOG_WORDS[a]])
		set_world_flag("changelog:" + a)
	changelog_lines.append_array(lines)
	return lines

signal world_flag_set(key: String)      # a guest's own world flag: Coop tells the host (the host's digest must have it too)

func set_world_flag(key: String) -> void:
	if flag(key):
		return
	flags[key] = true
	if net_role == "guest":
		world_flag_set.emit(key)

# an old save (before the map had to be bought): what it had walked is committed and its zones are indexed, once
func migrate_map() -> void:
	if flag("map:migrated"):
		return
	for id in rooms_meta.rooms:
		if flag("room:%s:visited" % id) and _mappable(id):
			flags["mapped:" + id] = true
			flags["map:" + zone_of(id)] = true
	for a in tools:
		if tools[a]:
			flags["changelog:" + String(a)] = true       # (a save that already owns abilities is not told about them now)
	flags["map:migrated"] = true

func flag(key: String) -> bool:
	return bool(flags.get(key, false))

# world state: flags that every player's world needs (a hatch the host opened must open for the guest too); they travel in snapshots
const WORLD_PREFIXES := ["boss:", "hatch:", "link:", "thread:", "lever:", "lab:", "map:", "mapped:", "changelog:", "log:", "agent:", "page:", "wave:", "rst:", "break:", "cable:"]
const _WORLD_HEADS := ["boss", "hatch", "link", "thread", "lever", "lab", "map", "mapped", "changelog", "log", "agent", "page", "wave", "rst", "break", "cable"]

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
# Co-op asks for it ~30 times a second on each page. Walking every flag each time cost ~1.2 ms on a PC with a late-game save (~1000 flags),
# ten times that on a phone, and it grew the further the players got ("the longer we play, the slower it gets"). The flags are set directly
# all over the code, so the walk is redone only when the dictionary's native hash (keys and values) changes.
var _wd_hash := 0
var _wd_val := -1

func world_digest() -> int:
	var fh := flags.hash()
	if fh != _wd_hash or _wd_val < 0:
		_wd_hash = fh
		var acc := 0
		for k in flags:
			if flags[k]:
				var ks := String(k)
				if is_world_flag(ks):
					acc = (acc + (ks.hash() * 2654435761 & 0xFFFFFFFF)) & 0xFFFFFFFF
		_wd_val = acc
	return (_wd_val + pins_digest()) & 0xFFFFFFFF

# a room's switch / key / gate / dead-code flags (the host's snapshot carries them), cached like the digest
var _rf_hash := 0
var _rf := {}                           # room id -> its flags, for the flags whose hash is _rf_hash

func room_flags(room_id: String) -> Array:
	var fh := flags.hash()
	if fh != _rf_hash:
		_rf_hash = fh
		_rf = {}
	if not _rf.has(room_id):
		var gf: Array = []
		for fk in flags:
			var fks := String(fk)
			if (fks.begins_with("switch:") or fks.begins_with("key:") or fks.begins_with("gate:") or fks.begins_with("dead:")) and fks.get_slice(":", 1) == room_id:
				gf.append(fks)
		_rf[room_id] = gf
	return _rf[room_id]

# where the other player is ({room, x, y} while a partner is connected, else {}); Coop keeps it, the map and travel read it
var partner := {}
const BP_RANGE := 112.0          # breakpoint (MV5A-04): px from the body centre to the target
const BP_TIME := 3.5            # s a target stays frozen
const BP_COOLDOWN := 6.0        # s before the same player can freeze again
var bp_hint := false             # the local player has a breakpoint target in reach (the touch SPEC button reads BRK)
var curl_hint := false            # the local player has a GET ring in reach (the touch SPEC button reads GET)

# ---- pins on the map (MVB1-08): shared, at most PIN_MAX; the host owns the list (a guest asks, snapshots carry it) ----
const PIN_KINDS := ["TODO", "?", "HELP", "ability"]
const PIN_MAX := 24
var pins: Array = []                    # [{id, room, x, y, kind, by}] (x, y in pixels of the room)
var pin_seq := 0
var pins_rev := 0                       # bumps on every change (Coop sends the list when it moved)
signal pin_requested(op: String, pin: Dictionary)      # a guest's wish; Coop sends it to the host

func pins_digest() -> int:
	var acc := 0
	for pn in pins:
		acc = (acc + ("%s:%d:%d:%s:%s" % [pn.room, int(pn.x), int(pn.y), pn.kind, pn.by]).hash()) & 0xFFFFFFFF
	return acc

func pin_label_by() -> String:
	return "P2" if net_role == "guest" else "P1"

# the same call on every page: the host (or solo) changes the list, a guest asks the host
func pin_add(kind: String, room_id: String, x: float, y: float) -> bool:
	if not rooms_meta.rooms.has(room_id) or is_offmap(room_id) or not PIN_KINDS.has(kind):
		return false
	var pn := {"room": room_id, "x": int(roundf(x)), "y": int(roundf(y)), "kind": kind, "by": pin_label_by()}
	if net_role == "guest":
		pin_requested.emit("add", pn)
		return true
	apply_pin_add(pn)
	return true

# removes the pin nearest to a point of the room (within `reach` px); the owner of any pin may remove it
func pin_del_near(room_id: String, x: float, y: float, reach: float) -> bool:
	var best := -1
	var bd := reach
	for i in range(pins.size()):
		var pn: Dictionary = pins[i]
		if pn.room == room_id:
			var d := Vector2(float(pn.x) - x, float(pn.y) - y).length()
			if d <= bd:
				bd = d
				best = i
	if best < 0:
		return false
	if net_role == "guest":
		pin_requested.emit("del", pins[best].duplicate())
		return true
	pins.remove_at(best)
	pins_rev += 1
	write_save()
	return true

func apply_pin_add(pn: Dictionary) -> void:
	pin_seq += 1
	var q := pn.duplicate()
	q["id"] = pin_seq
	pins.append(q)
	while pins.size() > PIN_MAX:
		pins.pop_front()
	pins_rev += 1
	write_save()

# the host applies a guest's request (the same checks as for its own)
func apply_pin_request(op: String, pn: Dictionary) -> void:
	if op == "add":
		if rooms_meta.rooms.has(String(pn.room)) and not is_offmap(String(pn.room)) and PIN_KINDS.has(String(pn.kind)):
			apply_pin_add({"room": String(pn.room), "x": int(pn.x), "y": int(pn.y), "kind": String(pn.kind), "by": "P2"})
	elif op == "del":
		for i in range(pins.size()):
			var q: Dictionary = pins[i]
			if q.room == pn.room and int(q.x) == int(pn.x) and int(q.y) == int(pn.y) and q.kind == pn.kind:
				pins.remove_at(i)
				pins_rev += 1
				write_save()
				break

# the guest takes the host's list as it is
func set_pins(list: Array) -> void:
	pins = []
	for q in list:
		pins.append({"id": int(q[0]), "room": String(q[1]), "x": int(q[2]), "y": int(q[3]), "kind": String(q[4]), "by": String(q[5])})
	pins_rev += 1

# ---- pings (MVB1-08): short-lived, shown to both players, never saved, never pause anything ----
const PING_KINDS := ["go here", "wait", "help", "look"]
const PING_LIFE := 6.0
var pings: Array = []                   # [{id, room, x, y, kind, by, until, ack}]
var ping_seq := 0
signal ping_made(p: Dictionary)         # Coop sends it to the partner
signal ping_acked(id: String)           # Coop tells the sender

func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

func pings_purge() -> void:
	var t := _now_s()
	pings = pings.filter(func(q): return q.until > t)

# a ping from this page: a room, a point in it (pixels) and one of the four words
func ping_add(kind: String, room_id: String, x: float, y: float) -> bool:
	if not rooms_meta.rooms.has(room_id) or is_offmap(room_id) or not PING_KINDS.has(kind):
		return false
	ping_seq += 1
	var q := {"id": "%s-%d" % [pin_label_by(), ping_seq], "room": room_id, "x": int(roundf(x)), "y": int(roundf(y)), "kind": kind, "by": pin_label_by(), "until": _now_s() + PING_LIFE, "ack": false}
	pings = pings.filter(func(o): return o.by != q.by)          # one active ping per player
	pings.append(q)
	ping_made.emit(q)
	return true

# the partner's ping arrived
func ping_receive(d: Dictionary) -> void:
	if not rooms_meta.rooms.has(String(d.room)) or is_offmap(String(d.room)) or not PING_KINDS.has(String(d.kind)):
		return
	var by := String(d.get("by", "P1" if net_role == "guest" else "P2"))
	pings = pings.filter(func(o): return o.by != by)
	pings.append({"id": String(d.id), "room": String(d.room), "x": int(d.x), "y": int(d.y), "kind": String(d.kind), "by": by, "until": _now_s() + PING_LIFE, "ack": false})

# this player saw the partner's ping (tapped its arrow, or opened the map): the sender gets a tick
func ping_ack_all_incoming() -> void:
	for q in pings:
		if q.by != pin_label_by() and not q.ack:
			q.ack = true
			ping_acked.emit(String(q.id))

func ping_ack_one(id: String) -> void:
	for q in pings:
		if q.id == id and q.by != pin_label_by() and not q.ack:
			q.ack = true
			ping_acked.emit(id)

# the partner acknowledged a ping of ours
func ping_ack_received(id: String) -> void:
	for q in pings:
		if q.id == id:
			q.ack = true

func pins_wire() -> Array:
	var out: Array = []
	for pn in pins:
		out.append([int(pn.id), pn.room, int(pn.x), int(pn.y), pn.kind, pn.by])
	return out

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
# curl and ssh (MVB2-03, MVB2-04)
const CURL_RANGE := 104.0         # px, player centre to ring centre
const CURL_SPEED := 400.0         # px/s, the zip
const CURL_POP := 300.0           # px/s up on arrival (= JUMP)
const CURL_EXIT_VX := 210.0       # px/s along the zip's horizontal direction on arrival (0 if the zip was within 4 px of vertical)
const SSH_HOLD := 0.30            # s of pushing into a firewall brick
const SSH_SPEED := 280.0          # px/s through the bricks
const SSH_BRICKS := 2             # at most this many bricks in a row (a thicker wall does not open)

const NOTCHES := 3                    # the "context window" at the start; Game.notches() adds one at 4 freed lost agents and one more at 8 (D47)
const PLUGINS := [
	{"id": "async_await", "name": "async/await", "cost": 2, "price": 0, "desc": "dash recharges twice as fast"},
	{"id": "cache", "name": "cache", "cost": 1, "price": 0, "desc": "tokens fly to you from farther away"},
	{"id": "hot_reload", "name": "hot-reload", "cost": 2, "price": 90, "desc": "healing (hold special) is much faster"},
	{"id": "eslint_fix", "name": "eslint --fix", "cost": 1, "price": 60, "desc": "every hit fills the meter a bit more"},
	{"id": "try_finally", "name": "try/finally", "cost": 1, "price": 80, "desc": "longer safe time after you get hurt"},
	{"id": "rubber_duck", "name": "rubber duck", "cost": 2, "price": 140, "desc": "at 1 hp your claw hits twice as hard"},
	{"id": "verbose", "name": "--verbose", "cost": 1, "price": 0, "desc": "dead code near you blinks green"},
	{"id": "restart_always", "name": "restart: always", "cost": 1, "price": 0, "desc": "come back from a bench with a full meter"},
	{"id": "gzip", "name": "gzip", "cost": 1, "price": 0, "desc": "every second token you pick up counts twice"},
	{"id": "sourcemap", "name": "sourcemap", "cost": 1, "price": 0, "desc": "the map marks what you left behind in rooms you have mapped"},
	{"id": "rate_limit", "name": "rate_limit", "cost": 2, "price": 0, "desc": "429: you take at most one hit every 3 s"},
	{"id": "review_cache", "name": "review cache", "cost": 1, "price": 0, "desc": "after a catch, your next claw hit deals +1"},
	{"id": "hot_path", "name": "hot path", "cost": 1, "price": 0, "desc": "a dash that hits a creature recharges the dash"},
	{"id": "lock_free", "name": "lock_free", "cost": 2, "price": 0, "desc": "your claw and dash go through the front guard of ordinary creatures"},
]
var equipped: Array = []              # plugin ids (saved; the guest keeps its own in user://profile.json)
signal loadout_changed

# how many lost agents were freed (flags agent:<room>, shared) and the context window they widen
var _af_hash := 0
var _af := -1
func agents_freed() -> int:
	var fh := flags.hash()                # (R08's decor asks every frame: walk the flags only after a change)
	if fh != _af_hash or _af < 0:
		_af_hash = fh
		_af = 0
		for k in flags:
			if flags[k] and String(k).begins_with("agent:"):
				_af += 1
	return _af

func notches() -> int:
	var n := agents_freed()
	return NOTCHES + (1 if n >= 4 else 0) + (1 if n >= 8 else 0)

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
		if d.size() > 0 and owns_plugin(String(id)) and not out.has(String(id)) and notches_used(out) + int(d.cost) <= notches():
			out.append(String(id))
	return out

# at a bench: put a plugin on or take it off; false when it is not owned or the context window is full
func toggle_plugin(id: String) -> bool:
	if equipped.has(id):
		equipped.erase(id)
	else:
		var d := plugin_def(id)
		if d.is_empty() or not owns_plugin(id) or notches_used() + int(d.cost) > notches():
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

# MVB2-10
func mod_gzip(list = null) -> bool:
	return (equipped if list == null else list).has("gzip")

func mod_sourcemap(list = null) -> bool:
	return (equipped if list == null else list).has("sourcemap")

func mod_rate_limit(list = null) -> bool:
	return (equipped if list == null else list).has("rate_limit")

func mod_hot_path(list = null) -> bool:
	return (equipped if list == null else list).has("hot_path")

func mod_lock_free(list = null) -> bool:
	return (equipped if list == null else list).has("lock_free")

func mod_review_cache(list = null) -> bool:
	return (equipped if list == null else list).has("review_cache")

var gz_n := 0                                 # tokens this player picked up since gzip (every second one counts twice)

# gzip: one more token for every second pickup (the counter is this player's own; the host counts a guest's)
func gz_bonus(n_before: int) -> bool:
	return (n_before + 1) % 2 == 0

# sourcemap: what is still lying in a room, from its file and the world flags: [{kind, x, y}] in tiles (a token cluster is one mark)
func item_marks(room_id: String) -> Array:
	var out: Array = []
	if not rooms_meta.rooms.has(room_id):
		return out
	var m: Dictionary = rooms_meta.rooms[room_id]
	var rows := FileAccess.get_file_as_string("res://src/world/rooms/" + String(m.file)).split("\n")
	var item_id := 0
	var plugin_n := 0
	var tok: Array = []
	var sparks: Array = []
	for ty in range(rows.size()):
		for tx in range(rows[ty].length()):
			match rows[ty][tx]:
				"o":
					if not flag("item:%s:%d" % [room_id, item_id]):
						tok.append(Vector2i(tx, ty))
					item_id += 1
				"H":
					item_id += 1
				"*":
					sparks.append(Vector2i(tx, ty))
				"U":
					var plist: Array = m.get("plugins", [])
					if plugin_n < plist.size() and not owns_plugin(String(plist[plugin_n])):
						out.append({"kind": "plugin", "x": tx, "y": ty})
					plugin_n += 1
	var seen := {}
	for c in tok:
		if seen.has(c):
			continue
		var stack := [c]
		seen[c] = true
		var sum := Vector2.ZERO
		var cnt := 0
		while not stack.is_empty():
			var q: Vector2i = stack.pop_back()
			sum += Vector2(q.x, q.y)
			cnt += 1
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nq: Vector2i = q + o
				if tok.has(nq) and not seen.has(nq):
					seen[nq] = true
					stack.append(nq)
		out.append({"kind": "token", "x": roundi(sum.x / cnt), "y": roundi(sum.y / cnt)})
	sparks.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in range(mini(3, sparks.size())):
		if not flag("item:%s:f%d" % [room_id, i]):
			out.append({"kind": "spark", "x": sparks[i].x, "y": sparks[i].y})
	for pg in m.get("pages", []):
		if not flag("page:%d" % int(pg[2])):
			out.append({"kind": "page", "x": int(pg[0]), "y": int(pg[1])})
	for jc in m.get("agents", []):
		if not flag("agent:" + room_id):
			out.append({"kind": "agent", "x": int(jc[0]), "y": int(jc[1])})
	return out

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
	loop_iter = {}
	flood_net = -1
	tools = {"bash": false, "catch": false, "sudo": false, "agents": false, "opus": false, "curl": false, "ssh": false, "breakpoint": false}
	equipped = []
	bench = ""
	tokens = 0
	gz_n = 0
	fragments = 0
	play_time = 0.0
	deaths = 0
	fights = []
	pins = []
	pin_seq = 0
	pins_rev += 1
	partner = {}
	pings = []
	changelog_lines = []

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
		"diff": diff, "coop_hp_pct": coop_hp_pct, "time": play_time, "deaths": deaths, "fights": fights, "equipped": equipped, "pins": pins_wire(), "changelog_lines": changelog_lines}
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
	load_meta()
	migrate_map()
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
	changelog_lines = d.get("changelog_lines", [])
	set_pins(d.get("pins", []))
	pin_seq = 0
	for pn in pins:
		pin_seq = maxi(pin_seq, int(pn.id))
	return true

# the player's top-left when standing on the bench of a room
func bench_spawn(room_id: String):
	load_meta()
	var b: Array = rooms_meta.rooms[room_id].benches
	if b.is_empty():
		return null
	return Vector2(b[0][0] * 16 + 3, b[0][1] * 16 + 6)

# the tools Clawd owns (phase 1 test build: bash only)
var tools := {"bash": false, "catch": false, "sudo": false, "agents": false, "opus": false, "curl": false, "ssh": false, "breakpoint": false}
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
	# (a page on plain http, as the phone opens the PC's address, has no clipboard: the call only logged "Clipboard API is not supported")
	if not OS.has_feature("web") or bool(JavaScriptBridge.eval("window.isSecureContext === true")):
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
