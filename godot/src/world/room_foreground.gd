class_name RoomForeground
extends Node2D
# RoomForeground (MVGN-09): 2-6 dark shapes in front of the playfield (hanging cable loops, rack edges, pipe clusters) at parallax 1.3 horizontally.
# They hang from the top edge of the screen or rise from the bottom edge, dark (sky_far x 0.6, alpha 0.9) with a 1-px accent rim on one side, drawn once
# and moved by position. Layout is deterministic from the room id. Readability comes first:
#   - a shape is not drawn while anything that matters is near it on screen: a door, a bench, a terminal, a sign, the boss trigger within 64 px, or a floor
#     (solid top / one-way) within 48 px above or below it (they parallax, so this is decided every frame from the camera, not once at build time);
#   - it fades to alpha 0.3 while a player's box is behind it.
# Vertical: they stay on the screen edge (a parallax of 1.1 would carry them off it in a tall room); that is the one change from the plan's 1.3 / 1.1.

const PX := 1.3
const W := 384
const H := 216
const A_FULL := 0.9
const A_BEHIND := 0.3

var room: Room
var shapes: Array = []                 # {kind, x (layer x of the left edge), w, h, top, node, a (alpha now), t (alpha wanted)}
var objects: Array = []                # world rects that must stay clear (+ 64 px)
var rev := -1

func _ready() -> void:
	z_index = 6
	var rid := String(room.id)
	var sd := int(rid.substr(1)) * 11 if rid.substr(1).is_valid_int() else 3
	var n := 2 + int(Game.hash3(sd, 1, 90) * 5.0)                                 # 2..6
	var wpx := float(room.pw)
	var span := maxf(wpx - float(W), 0.0)
	for i in range(n):
		var kind: String = ["loop", "rack", "pipes"][int(Game.hash3(sd, i + 2, 91) * 3.0)]
		var top: bool = kind == "loop"
		var w: float = 52.0 + Game.hash3(sd, i + 20, 92) * 40.0 if kind == "loop" else (22.0 + Game.hash3(sd, i + 20, 92) * 10.0 if kind == "rack" else 24.0)
		var h := 22.0 + Game.hash3(sd, i + 30, 93) * 18.0
		var focus := 192.0 + (span * (float(i) + 0.15 + Game.hash3(sd, i + 40, 94) * 0.7) / float(n) if span > 0.0 else 0.0)      # the camera x + 192 at which the shape crosses the middle
		var lx := 192.0 + PX * (focus - 192.0) - w * 0.5                           # layer x of its left edge: screen x = lx - PX * cam.x
		var node := DrawProxy.new()
		node.material = Look.unshaded()
		node.cb = _draw_shape.bind(shapes.size())
		add_child(node)
		shapes.append({"kind": kind, "x": lx, "w": w, "h": h, "top": top, "node": node, "a": A_FULL, "t": A_FULL, "seed": sd + i})
	for d in room.grid.doors:
		var a: int = d.a
		var b: int = d.b
		match String(d.side):
			"W": objects.append(Rect2(0, a * 16, 16, (b - a + 1) * 16))
			"E": objects.append(Rect2(room.pw - 16, a * 16, 16, (b - a + 1) * 16))
			"N": objects.append(Rect2(a * 16, 0, (b - a + 1) * 16, 16))
			"S": objects.append(Rect2(a * 16, room.ph - 16, (b - a + 1) * 16, 16))
	for c in room.cps:
		objects.append(Rect2(float(c.x) - 8.0, float(c.y) - 16.0, 16, 16))
	for s in room.stations:
		objects.append(Rect2(float(s.x), float(s.y), float(s.w), float(s.h)))
	for s in room.signs:
		objects.append(Rect2(float(s.x) - 8.0, float(s.y) - 16.0, 16, 16))
	if room.def.has("boss") and room.def.boss.has("trigger_x"):
		objects.append(Rect2(float(room.def.boss.trigger_x) - 8.0, 0, 16, room.ph))
	Game.gfx_changed.connect(_apply_tier)
	_apply_tier()

func _exit_tree() -> void:
	if Game.gfx_changed.is_connected(_apply_tier):
		Game.gfx_changed.disconnect(_apply_tier)

func _apply_tier() -> void:
	visible = Game.gfx_tier >= 1                    # Low has none
	rev = -1

# ---- geometry ----
func screen_rect(i: int, cam: Vector2) -> Rect2:
	var s: Dictionary = shapes[i]
	return Rect2(float(s.x) - PX * cam.x, 0.0 if s.top else H - float(s.h), float(s.w), float(s.h))

# the alpha shape i should have with the camera at `cam`; `boxes`: the players' world rects. 0 = something that matters is near it
func wanted_alpha(i: int, cam: Vector2, boxes: Array) -> float:
	var sr := screen_rect(i, cam)
	if sr.end.x < 0.0 or sr.position.x > W:
		return A_FULL                                 # (not on screen: nothing to check, it is not drawn either)
	var wr := Rect2(sr.position + cam, sr.size)
	var near := wr.grow(64.0)
	for o in objects:
		if near.intersects(o):
			return 0.0
	var g := room.grid
	var tx0 := floori(wr.position.x / 16.0)
	var tx1 := floori(wr.end.x / 16.0)
	var ty0 := floori((wr.position.y - 48.0) / 16.0)
	var ty1 := floori((wr.end.y + 48.0) / 16.0)
	for ty in range(maxi(ty0, 0), mini(ty1, g.h - 1) + 1):
		for tx in range(maxi(tx0, 0), mini(tx1, g.w - 1) + 1):
			var t := g.tile(tx, ty)
			if t == TileGrid.ONEWAY or (t == TileGrid.SOLID and (ty == 0 or g.tile(tx, ty - 1) != TileGrid.SOLID)):
				return 0.0
	for b in boxes:
		if wr.grow(2.0).intersects(b):
			return A_BEHIND
	return A_FULL

func _boxes() -> Array:
	var out: Array = []
	var ps: Array = [room.player] + room.remote_players
	for p in ps:
		if p != null and p.get("dead") != true:
			out.append(Rect2(p.x, p.y, p.w, p.h))
	return out

func _process(dt: float) -> void:
	if room == null or not room.is_local or room.camera == null or not visible:
		return
	var cam: Vector2 = room.camera.position
	var boxes := _boxes()
	var redraw := room.look != null and room.look.rev != rev
	if redraw:
		rev = room.look.rev
	for i in range(shapes.size()):
		var s: Dictionary = shapes[i]
		var sr := screen_rect(i, cam)
		var node: DrawProxy = s.node
		var on := sr.end.x >= 0.0 and sr.position.x <= W
		node.visible = on
		if not on:
			continue
		s.t = wanted_alpha(i, cam, boxes)
		s.a = Game.damp(float(s.a), float(s.t), 14.0 if float(s.t) < float(s.a) else 6.0, dt)
		node.position = sr.position + cam
		node.modulate.a = float(s.a) / A_FULL
		if redraw:
			node.queue_redraw()

func _draw_shape(ci: CanvasItem, i: int) -> void:
	var s: Dictionary = shapes[i]
	var o: Dictionary = room.look.out if room != null and room.look != null and not room.look.out.is_empty() else Look.mixed("stable", 1.0)
	var body: Color = (o.sky_far as Color) * 0.6
	body.a = A_FULL
	var rim: Color = o.accent_a
	rim.a = 0.6
	var w: float = s.w
	var h: float = s.h
	match String(s.kind):
		"loop":                                       # a cable loop sagging from the top edge, two strands hanging off it
			var pts := PackedVector2Array()
			for k in range(0, 17):
				var u := float(k) / 16.0
				pts.append(Vector2(u * w, sin(u * PI) * h * 0.8))
			ci.draw_polyline(pts, body, 5.0)
			ci.draw_polyline(pts, rim, 1.0)
			ci.draw_rect(Rect2(0, 0, 6, 8), body)
			ci.draw_rect(Rect2(w - 6, 0, 6, 8), body)
			for e in range(2):
				var sx := w * (0.3 + 0.4 * float(e))
				var sy := sin((sx / w) * PI) * h * 0.8
				ci.draw_rect(Rect2(sx - 1, sy, 3, h * 0.3 + float((int(s.seed) + e) % 5)), body)
		"rack":                                       # a rack edge rising from the bottom edge
			ci.draw_rect(Rect2(0, 0, w, h), body)
			ci.draw_rect(Rect2(w - 1, 0, 1, h), rim)
			for r in range(int(h / 6.0)):
				ci.draw_rect(Rect2(3, 3 + r * 6, w - 8, 1), body * 1.6)
		_:                                            # a cluster of three pipes
			for k in range(3):
				var pw := 5.0 + float(k % 2) * 2.0
				var ph := h * (0.55 + 0.2 * float((int(s.seed) + k) % 3))
				var px := float(k) * 8.0
				ci.draw_rect(Rect2(px, h - ph, pw, ph), body)
				ci.draw_rect(Rect2(px + pw - 1, h - ph, 1, ph), rim)
				ci.draw_rect(Rect2(px - 1, h - ph, pw + 2, 2), body)
