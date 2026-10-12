class_name MapView
extends Node2D
# MapView: the map page (MVB1-05). One class for the pause menu's Map page and for the overlay that does not pause co-op (MVB1-06).
# Rooms come from Game.map_view(zone) (what the index lists, what is committed), so both pages draw the same thing from world flags.
# Layout 384 x 216: header y 4, partner line y 15, map area x 8-376 y 26-196, button bar y 200-214.

const W := 384
const H := 216
const AREA := Rect2(8, 26, 368, 170)
const PAN_STEP := 24.0
const SCALE_ZONE_MIN := 0.35
const SCALE_ZONE_MAX := 2.0
const SCALE_WORLD_MAX := 0.5
const COL_P1 := "#f0a184"
const COL_P2 := "#8fd0ff"

signal back_requested

var manager: RoomManager
var active := false
var dim := true                 # the overlay dims the game behind it; the pause page sits on the pause menu's own dim
var world := false              # false: the zone view, true: every indexed zone
var zone := ""                  # the zone of the zone view
var scale_px := 1.0             # px per tile
var center := Vector2.ZERO      # the tile at the middle of the map area
var canvas: Control             # the map area (clips what is drawn outside it)
var drag_active := false
var repeat_t := 0.0
var _keys_prev := {}
var buttons: Array = []         # [{id, rect, label}] (rebuilt by _layout_buttons)
var msg := ""
var msg_t := 0.0
var t := 0.0

static var _rows_cache := {}

func _ready() -> void:
	visible = false
	canvas = Control.new()
	canvas.position = AREA.position
	canvas.size = AREA.size
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_area)
	add_child(canvas)
	_layout_buttons()

# ---------------------------------------------------------------- opening and the view
func open(start_zone := "") -> void:
	active = true
	visible = true
	world = false
	t = 0.0
	zone = start_zone if start_zone != "" else current_zone()
	drag_active = false
	_keys_prev = {}
	msg = ""
	fit()
	queue_redraw()
	if canvas != null:
		canvas.queue_redraw()

func close() -> void:
	active = false
	visible = false

func current_zone() -> String:
	if manager != null and manager.room != null:
		return Game.zone_of(manager.room.id)
	return "src"

# the room ids drawn right now (an outline room that is also committed is drawn once, as filled)
func rooms_in_view() -> Array:
	var out: Array = []
	var zones: Array = []
	if world:
		for z in Game.ZONES:
			zones.append(z.id)
	else:
		zones.append(zone)
	for zid in zones:
		var v: Dictionary = Game.map_view(zid)
		for id in v.outline:
			if not out.has(id):
				out.append(id)
		for id in v.filled:
			if not out.has(id):
				out.append(id)
	return out

# what the map area says when there is nothing to draw (no index yet)
func empty_text() -> String:
	return "no index for %s" % (String(Game.zone_def(zone).get("path", zone)) if not world else "anything yet")

var draws := 0                  # how many times the map area was drawn (the tests read it)

func is_filled(id: String) -> bool:
	return Game.is_mapped(id) and Game.owns_map(Game.zone_of(id))

func tile_bounds(ids: Array) -> Rect2:
	var rects: Array = []
	for id in ids:
		var m: Dictionary = Game.rooms_meta.rooms[id]
		rects.append(Rect2(float(m.origin[0]), float(m.origin[1]), float(m.size[0]), float(m.size[1])))
	if rects.is_empty():
		return Rect2()
	var b: Rect2 = rects[0]
	for r in rects:
		b = b.merge(r)
	return b

# every room of the view fits the map area (at most 2 px per tile in a zone, 0.5 in the world, at least 0.35 in a zone)
func fit() -> void:
	var ids := rooms_in_view()
	if ids.is_empty():
		scale_px = 1.0 if not world else SCALE_WORLD_MAX
		center = Vector2.ZERO
		return
	var b := tile_bounds(ids)
	var s := minf(AREA.size.x / maxf(1.0, b.size.x), AREA.size.y / maxf(1.0, b.size.y))
	if world:
		scale_px = minf(s, SCALE_WORLD_MAX)
	else:
		scale_px = clampf(s, SCALE_ZONE_MIN, SCALE_ZONE_MAX)
	center = b.get_center()

func set_world(v: bool) -> void:
	world = v
	fit()

func zoom(mult: float) -> void:
	var lo := 0.1 if world else SCALE_ZONE_MIN
	scale_px = clampf(scale_px * mult, lo, 4.0)

func pan_px(d: Vector2) -> void:
	center += d / scale_px

# a tile position -> a point in the map area (canvas coordinates)
func to_canvas(tile: Vector2) -> Vector2:
	return AREA.size / 2.0 + (tile - center) * scale_px

# a room's rectangle in screen coordinates (the whole 384 x 216 picture), for the tests and the drawing
func rect_of(id: String) -> Rect2:
	var m: Dictionary = Game.rooms_meta.rooms[id]
	var p := to_canvas(Vector2(float(m.origin[0]), float(m.origin[1])))
	return Rect2(AREA.position + p, Vector2(float(m.size[0]), float(m.size[1])) * scale_px)

# ---------------------------------------------------------------- the partner
# {room, x, y, who} of the other player, kept by Coop in Game.partner ({} when alone)
func partner() -> Dictionary:
	return Game.partner

func local_label() -> String:
	return "P2" if Game.net_role == "guest" else "P1"

func partner_label() -> String:
	return "P1" if Game.net_role == "guest" else "P2"

# ---------------------------------------------------------------- input (called every fixed step by whoever shows the map)
func key_edge(k: Key) -> bool:
	var down := Input.is_physical_key_pressed(k)
	var edge: bool = down and not bool(_keys_prev.get(k, false))
	_keys_prev[k] = down
	return edge

func update() -> void:
	if not active:
		return
	t += Game.STEP
	if msg_t > 0.0:
		msg_t -= Game.STEP
		if msg_t <= 0.0:
			msg = ""
	var c := Controls.pressed
	if c.get("dash", false) or c.get("pause", false):
		Audio.sfx("uiBack")
		back_requested.emit()
		_redraw()
		return
	if c.get("jump", false):
		set_world(not world)
		Audio.sfx("uiMove")
	if c.get("attack", false):
		centre_on_partner()
	if key_edge(KEY_EQUAL) or key_edge(KEY_KP_ADD):
		zoom(1.5)
	if key_edge(KEY_MINUS) or key_edge(KEY_KP_SUBTRACT):
		zoom(1.0 / 1.5)
	# the arrows pan: once per press, then repeating while held
	var d := Vector2(float(Controls.down.get("right", false)) - float(Controls.down.get("left", false)), float(Controls.down.get("down", false)) - float(Controls.down.get("up", false)))
	if d != Vector2.ZERO and not drag_active:
		var fresh: bool = c.get("left", false) or c.get("right", false) or c.get("up", false) or c.get("down", false)
		repeat_t -= Game.STEP
		if fresh:
			repeat_t = 0.25
			pan_px(d * PAN_STEP)
		elif repeat_t <= 0.0:
			repeat_t = 0.07
			pan_px(d * PAN_STEP)
	else:
		repeat_t = 0.0
	_redraw()

func _redraw() -> void:
	queue_redraw()
	if canvas != null:
		canvas.queue_redraw()

func centre_on_partner() -> void:
	var pt := partner()
	if pt.is_empty():
		msg = "you are alone"
		msg_t = 1.5
		return
	var rid := String(pt.room)
	if not Game.rooms_meta.rooms.has(rid):
		return
	if not world:
		zone = Game.zone_of(rid)
		fit()
	var m: Dictionary = Game.rooms_meta.rooms[rid]
	center = Vector2(float(m.origin[0]) + float(pt.x) / 16.0, float(m.origin[1]) + float(pt.y) / 16.0)
	Audio.sfx("uiMove")

# ---------------------------------------------------------------- the button bar
func _layout_buttons() -> void:
	buttons = []
	var x := 8.0
	var defs := [["world", "zone", 52.0], ["minus", "-", 20.0], ["plus", "+", 20.0], ["partner", "P2", 28.0], ["pin", "pin", 32.0], ["ping", "ping", 36.0], ["back", "back", 40.0]]
	for d in defs:
		buttons.append({"id": d[0], "label": d[1], "rect": Rect2(x, 200, d[2], 14)})
		x += float(d[2]) + 5.0

func button_label(b: Dictionary) -> String:
	match String(b.id):
		"world": return "zone" if world else "world"
		"partner": return partner_label()
	return String(b.label)

func tap(p: Vector2) -> void:
	if not active:
		return
	for b in buttons:
		if b.rect.grow(2.0).has_point(p):
			press_button(String(b.id))
			return

func press_button(id: String) -> void:
	match id:
		"world":
			set_world(not world)
			Audio.sfx("uiMove")
		"minus": zoom(1.0 / 1.5)
		"plus": zoom(1.5)
		"partner": centre_on_partner()
		"back":
			Audio.sfx("uiBack")
			back_requested.emit()
	_redraw()

# a finger or the mouse dragging the map (screen px of the 384 x 216 picture)
func drag(rel: Vector2) -> void:
	if active:
		pan_px(-rel)
		drag_active = true
		_redraw()

func drag_end() -> void:
	drag_active = false

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.9 if dim else 0.75))     # (the hearts and the room title of the HUD must not show through the text)
	var zd: Dictionary = Game.zone_def(zone)
	var zc := Color(String(zd.get("col", "#8d8798")))
	if world:
		PixelText.draw_text(self, "WORLD", 8, 4, Game.COL.paper, {"outline": Game.COL.ink})
		PixelText.draw_text(self, "every index you own", 54, 4, Game.COL.dim)
	else:
		var nm := String(zd.get("name", ""))
		var wd := PixelText.draw_text(self, nm, 8, 4, zc, {"outline": Game.COL.ink})
		PixelText.draw_text(self, String(zd.get("path", "")), 8 + wd + 6, 4, Game.COL.dim)
		if Game.owns_map(zone):
			var cn: Array = Game.zone_counts(zone)
			PixelText.draw_text(self, "rooms %d/%d" % [cn[0], cn[1]], 376, 4, Game.COL.paper, {"align": "r"})
	# the partner line
	var pt := partner()
	if not pt.is_empty():
		var prid := String(pt.room)
		var ptxt := "%s · " % partner_label()
		if Game.is_offmap(prid) or not Game.rooms_meta.rooms.has(prid):
			ptxt += "unindexed"
		else:
			ptxt += "%s · %s" % [String(Game.zone_def(Game.zone_of(prid)).get("path", "")), prid]
		PixelText.draw_text(self, ptxt, 8, 15, COL_P1 if partner_label() == "P1" else COL_P2)
	if msg != "":
		PixelText.draw_text(self, msg, 376, 15, Game.COL.gold, {"align": "r"})
	# the bar
	for b in buttons:
		Gfx.panel(self, b.rect.position.x, b.rect.position.y, b.rect.size.x, b.rect.size.y, "#17131f", "#3a3346")
		PixelText.draw_text(self, button_label(b), b.rect.position.x + b.rect.size.x / 2.0, b.rect.position.y + 3, Game.COL.paper, {"align": "c", "tiny": true})
	_draw_extra_hud()

func _draw_extra_hud() -> void:
	pass

func _draw_area() -> void:
	if not active:
		return
	draws += 1
	var ids := rooms_in_view()
	if ids.is_empty():
		PixelText.draw_text(canvas, empty_text(), AREA.size.x / 2.0, AREA.size.y / 2.0 - 4, Game.COL.dim, {"align": "c"})
		_draw_players()
		return
	# outline rooms first, then the committed ones over them
	for id in ids:
		if not is_filled(id):
			_draw_outline_room(id)
	for id in ids:
		if is_filled(id):
			_draw_filled_room(id)
	if world:
		for z in Game.ZONES:
			var zr: Array = []
			for id in ids:
				if Game.zone_of(id) == z.id:
					zr.append(id)
			if not zr.is_empty():
				var b := tile_bounds(zr)
				var cp := to_canvas(b.get_center())
				PixelText.draw_text(canvas, String(z.path), cp.x, cp.y - 2, Color(z.col).lightened(0.3), {"align": "c", "tiny": true, "outline": Game.COL.ink})
	_draw_marks(ids)
	_draw_players()

func _canvas_rect(id: String) -> Rect2:
	return Rect2(rect_of(id).position - AREA.position, rect_of(id).size)

func _draw_outline_room(id: String) -> void:
	var r := _canvas_rect(id)
	var col := Color("#8d8798")
	col.a = 0.7
	# a dotted border: 2 px on, 2 px off
	var x0 := floorf(r.position.x)
	var y0 := floorf(r.position.y)
	var x1 := floorf(r.end.x)
	var y1 := floorf(r.end.y)
	var x := x0
	while x < x1:
		canvas.draw_rect(Rect2(x, y0, minf(2.0, x1 - x), 1), col)
		canvas.draw_rect(Rect2(x, y1, minf(2.0, x1 - x), 1), col)
		x += 4.0
	var y := y0
	while y < y1:
		canvas.draw_rect(Rect2(x0, y, 1, minf(2.0, y1 - y)), col)
		canvas.draw_rect(Rect2(x1, y, 1, minf(2.0, y1 - y)), col)
		y += 4.0

func _draw_filled_room(id: String) -> void:
	var m: Dictionary = Game.rooms_meta.rooms[id]
	var r := _canvas_rect(id)
	var zc := Color(String(Game.zone_def(Game.zone_of(id)).get("col", "#8d8798")))
	var fill := zc
	fill.a = 0.25
	canvas.draw_rect(r, fill)
	var here: bool = manager != null and manager.room != null and manager.room.id == id
	var border := Color(COL_P1) if here else zc
	var x0 := floorf(r.position.x)
	var y0 := floorf(r.position.y)
	var x1 := floorf(r.end.x)
	var y1 := floorf(r.end.y)
	# the border, broken along the doors that may be shown; the doors that lead to a room not on the map get a stub
	var gaps := {"N": [], "S": [], "W": [], "E": []}
	var stubs: Array = []
	for d in m.get("doors", []):
		if not door_visible(id, d):
			continue
		var side := String(d.side)
		var a: float
		var b: float
		if side == "W" or side == "E":
			a = floorf(r.position.y + float(d.a) * scale_px)
			b = floorf(r.position.y + float(int(d.b) + 1) * scale_px)
		else:
			a = floorf(r.position.x + float(d.a) * scale_px)
			b = floorf(r.position.x + float(int(d.b) + 1) * scale_px)
		if b - a < 1.0:
			b = a + 1.0
		gaps[side].append([a, b])
		var to_id := String(d.to).get_slice(":", 0)
		if not is_filled(to_id):
			stubs.append([side, a, b])
	_edge(border, x0, x1, y0, true, gaps.N)
	_edge(border, x0, x1, y1, true, gaps.S)
	_edge(border, y0, y1, x0, false, gaps.W)
	_edge(border, y0, y1, x1, false, gaps.E)
	for s in stubs:
		var mid: float = (s[1] + s[2]) / 2.0
		var sc2 := zc
		sc2.a = 0.9
		match String(s[0]):
			"W":
				canvas.draw_rect(Rect2(x0 - 3, mid, 3, 1), sc2)
				if scale_px >= 1.0:
					PixelText.draw_text(canvas, "…", x0 - 8, mid - 2, Game.COL.dim, {"align": "r", "tiny": true})
			"E":
				canvas.draw_rect(Rect2(x1 + 1, mid, 3, 1), sc2)
				if scale_px >= 1.0:
					PixelText.draw_text(canvas, "…", x1 + 6, mid - 2, Game.COL.dim, {"tiny": true})
			"N":
				canvas.draw_rect(Rect2(mid, y0 - 3, 1, 3), sc2)
				if scale_px >= 1.0:
					PixelText.draw_text(canvas, "…", mid, y0 - 9, Game.COL.dim, {"align": "c", "tiny": true})
			"S":
				canvas.draw_rect(Rect2(mid, y1 + 1, 1, 3), sc2)
				if scale_px >= 1.0:
					PixelText.draw_text(canvas, "…", mid, y1 + 4, Game.COL.dim, {"align": "c", "tiny": true})
	# benches and terminals
	var term: bool = bool(m.get("terminal", false))
	for bn in m.benches:
		var bp := r.position + Vector2(float(bn[0]), float(bn[1])) * scale_px
		bp = Vector2(floorf(bp.x), floorf(bp.y))
		if term:
			canvas.draw_rect(Rect2(bp.x - 2, bp.y - 3, 5, 4), Color(Game.COL.ink))
			canvas.draw_rect(Rect2(bp.x - 1, bp.y - 2, 3, 2), Color("#58f0c8"))
		else:
			canvas.draw_rect(Rect2(bp.x - 1, bp.y, 2, 2), Color("#7fd08a"))

# a straight edge from `from` to `to` along one axis (horizontal: x runs, y fixed), minus the door gaps
func _edge(col: Color, a0: float, a1: float, fixed: float, horizontal: bool, gaps: Array) -> void:
	var start := a0
	var stop := a1
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var cur := start
	for g in cuts:
		var g0: float = maxf(g[0], start)
		var g1: float = minf(g[1], stop)
		if g0 > cur:
			_seg(col, cur, g0, fixed, horizontal)
		cur = maxf(cur, g1)
	if cur < stop:
		_seg(col, cur, stop, fixed, horizontal)

func _seg(col: Color, a: float, b: float, fixed: float, horizontal: bool) -> void:
	if horizontal:
		canvas.draw_rect(Rect2(a, fixed, b - a + 1.0, 1), col)
	else:
		canvas.draw_rect(Rect2(fixed, a, 1, b - a + 1.0), col)

# the rows of a room file (the map looks at the cells of a door for dead code)
static func room_rows(id: String) -> PackedStringArray:
	if not _rows_cache.has(id):
		_rows_cache[id] = FileAccess.get_file_as_string("res://src/world/rooms/" + String(Game.rooms_meta.rooms[id].file)).split("\n")
	return _rows_cache[id]

# which doors the map may show: not into a room that does not exist (sealed), not into a secret room nobody has found, not one whose
# cells are dead code that has not been revealed, none at all of an offmap room
static func door_visible(id: String, d: Dictionary) -> bool:
	if Game.is_offmap(id):
		return false
	var to_id := String(d.to).get_slice(":", 0)
	if not Game.rooms_meta.rooms.has(to_id):
		return false
	if Game.is_secret(to_id) and not Game.is_mapped(to_id):
		return false
	if not Game.flag("dead:" + id):
		var rows := room_rows(id)
		var m: Dictionary = Game.rooms_meta.rooms[id]
		var w := int(m.size[0])
		var h := int(m.size[1])
		for i in range(int(d.a), int(d.b) + 1):
			var ch := ""
			match String(d.side):
				"W": ch = rows[i][0] if i < rows.size() and rows[i].length() > 0 else ""
				"E": ch = rows[i][w - 1] if i < rows.size() and rows[i].length() >= w else ""
				"N": ch = rows[0][i] if rows.size() > 0 and rows[0].length() > i else ""
				"S": ch = rows[h - 1][i] if rows.size() >= h and rows[h - 1].length() > i else ""
			if ch == ";":
				return false
	return true

func _draw_marks(_ids: Array) -> void:
	pass

# the players: P1 a circle with `1`, P2 a diamond with `2`, 7 px, steady. Only in a room that is on the map; otherwise the partner line says where it is.
func _draw_players() -> void:
	var drawn := rooms_in_view()
	if manager != null and manager.room != null and manager.player != null and drawn.has(manager.room.id):
		_player_mark(manager.room.id, manager.player.x + 5.0, manager.player.y + 5.0, local_label())
	var pt := partner()
	if not pt.is_empty() and drawn.has(String(pt.room)):
		_player_mark(String(pt.room), float(pt.x) + 5.0, float(pt.y) + 5.0, partner_label())

func _player_mark(room_id: String, px: float, py: float, who: String) -> void:
	var m: Dictionary = Game.rooms_meta.rooms[room_id]
	var p := to_canvas(Vector2(float(m.origin[0]) + px / 16.0, float(m.origin[1]) + py / 16.0))
	p = Vector2(floorf(p.x), floorf(p.y))
	var ink := Color(Game.COL.ink)
	if who == "P1":
		canvas.draw_circle(p, 4.0, ink)
		canvas.draw_circle(p, 3.0, Color(COL_P1))
		PixelText.draw_text(canvas, "1", p.x - 1, p.y - 2, Game.COL.ink, {"tiny": true})
	else:
		canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), ink)
		canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), Color(COL_P2))
		PixelText.draw_text(canvas, "2", p.x - 1, p.y - 2, Game.COL.ink, {"tiny": true})
