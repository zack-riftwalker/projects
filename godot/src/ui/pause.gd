class_name PauseMenu
extends Node2D
# PauseMenu: Resume / Restart room / 30 fps. Drawn in the game viewport (384 x 216) above everything.

const W := 384
const H := 216
signal resume_requested
signal restart_requested

var active := false
var sel := 0

func options() -> Array:
	return ["Resume", "Restart room", "30 fps: " + ("on" if Game.fps30 else "off")]

func open() -> void:
	active = true
	sel = 0
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
		1: restart_requested.emit()
		2:
			Game.fps30 = not Game.fps30
			Engine.max_fps = 30 if Game.fps30 else 0
	queue_redraw()

# a tap in game coordinates (0..384, 0..216)
func tap(p: Vector2) -> void:
	if not active:
		return
	for i in range(options().size()):
		if Rect2(W / 2.0 - 70, 78 + i * 22, 140, 18).has_point(p):
			choose(i)

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.6))
	PixelText.draw_text(self, "PAUSED", W / 2.0, 52, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
	var opts := options()
	for i in range(opts.size()):
		var y := 78 + i * 22
		Gfx.panel(self, W / 2.0 - 70, y, 140, 18, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, opts[i], W / 2.0, y + 5, Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})
