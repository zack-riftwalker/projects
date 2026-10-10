class_name PauseMenu
extends Node2D
# PauseMenu: Resume / Restart room / 30 fps. Drawn in the game viewport (384 x 216) above everything.

const W := 384
const H := 216
signal resume_requested
signal restart_requested
signal fullscreen_requested

var active := false
var sel := 0
var page := "menu"            # "menu" or "map"
var manager: RoomManager
var blink_t := 0.0
var log_msg := ""

func options() -> Array:
	var o := ["Resume", "Map", "Restart room", "30 fps: " + ("on" if Game.fps30 else "off"), "Fullscreen: " + ("on" if Game.is_fullscreen() else "off")]
	if Game.debug:
		o.append(log_msg if log_msg != "" else "Copy log (5 min)")
	return o

func open() -> void:
	active = true
	sel = 0
	log_msg = ""
	page = "menu"
	visible = true
	Audio.sfx("pause")
	Audio.duck(-10.0)
	queue_redraw()

func close() -> void:
	active = false
	visible = false
	Audio.duck(0.0)

func _ready() -> void:
	visible = false

# called every fixed step while paused (Main polls the controls itself then)
func update() -> void:
	if not active:
		return
	blink_t += Game.STEP
	if page == "map":
		if Controls.pressed.get("pause", false) or Controls.pressed.get("jump", false) or Controls.pressed.get("attack", false) or Controls.pressed.get("dash", false) or Controls.pressed.get("start", false):
			page = "menu"
			Audio.sfx("uiBack")
		queue_redraw()
		return
	if Controls.pressed.get("pause", false):
		resume_requested.emit()
		return
	var n := options().size()
	if Controls.pressed.get("up", false):
		sel = (sel + n - 1) % n
		Audio.sfx("uiMove")
	if Controls.pressed.get("down", false):
		sel = (sel + 1) % n
		Audio.sfx("uiMove")
	if Controls.pressed.get("start", false) or Controls.pressed.get("jump", false) or Controls.pressed.get("attack", false):
		choose(sel)
	queue_redraw()

func choose(i: int) -> void:
	sel = i
	Audio.sfx("uiOk")
	match i:
		0: resume_requested.emit()
		1: page = "map"
		2: restart_requested.emit()
		3:
			Game.fps30 = not Game.fps30
			Engine.max_fps = 30 if Game.fps30 else 0
		4: fullscreen_requested.emit()
		5: log_msg = "Log copied: %d lines" % Game.export_log()
	queue_redraw()

# a tap in game coordinates (0..384, 0..216)
func tap(p: Vector2) -> void:
	if not active:
		return
	if page == "map":
		page = "menu"
		return
	for i in range(options().size()):
		if Rect2(W / 2.0 - 70, 78 + i * 22, 140, 18).has_point(p):
			choose(i)

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.6))
	if page == "map":
		_draw_map()
		return
	PixelText.draw_text(self, "PAUSED", W / 2.0, 52, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
	var opts := options()
	for i in range(opts.size()):
		var y := 78 + i * 22
		Gfx.panel(self, W / 2.0 - 70, y, 140, 18, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, opts[i], W / 2.0, y + 5, Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})

# MAP page: every visited room as a rectangle (1 tile = 0.5 px), benches green, the player blinking
func _draw_map() -> void:
	PixelText.draw_text(self, "MAP", W / 2.0, 20, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
	var rooms: Dictionary = Game.rooms_meta.rooms
	var x0 := 1e9
	var x1 := -1e9
	for id in rooms:
		var m: Dictionary = rooms[id]
		x0 = minf(x0, m.origin[0])
		x1 = maxf(x1, m.origin[0] + m.size[0])
	var ox: float = floorf((W - (x1 - x0) * 0.5) / 2.0 - x0 * 0.5)
	var oy := 100.0
	for id in rooms:
		if not Game.flag("room:%s:visited" % id):
			continue
		var m: Dictionary = rooms[id]
		var r := Rect2(ox + m.origin[0] * 0.5, oy + m.origin[1] * 0.5, m.size[0] * 0.5, m.size[1] * 0.5)
		var here: bool = manager != null and manager.room != null and manager.room.id == id
		draw_rect(r, Color("#17131f"))
		draw_rect(r, Color("#f0a184") if here else Color("#8d8798"), false, 1.0)
		for b in m.benches:
			draw_rect(Rect2(r.position.x + b[0] * 0.5 - 1, r.position.y + b[1] * 0.5, 2, 2), Color("#7fd08a"))
	if manager != null and manager.player != null and manager.room != null and int(blink_t * 3.0) % 2 == 0:
		var m2: Dictionary = rooms[manager.room.id]
		var p = manager.player
		draw_rect(Rect2(floorf(ox + m2.origin[0] * 0.5 + p.x / 32.0), floorf(oy + m2.origin[1] * 0.5 + p.y / 32.0), 2, 2), Color.WHITE)
	PixelText.draw_text(self, "press any button to go back", W / 2.0, H - 22, Game.COL.dim, {"align": "c", "tiny": true})
