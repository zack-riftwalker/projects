class_name BenchMenu
extends Node2D
# BenchMenu: Rest / Travel / Leave, opened with [up] next to a bench. Drawn in the game viewport; Main polls the controls while it is open.

const W := 384
const H := 216
signal rest_chosen
signal travel_chosen(room_id: String)
signal closed

var active := false
var sel := 0
var page := "main"
var manager: RoomManager
var travel_list: Array = []

func _ready() -> void:
	visible = false

func open() -> void:
	active = true
	visible = true
	sel = 0
	page = "main"
	Audio.sfx("uiOk")
	queue_redraw()

func close() -> void:
	active = false
	visible = false
	closed.emit()

func main_options() -> Array:
	var o := ["Rest"]
	if manager.rested_benches().size() >= 2:
		o.append("Travel")
	o.append("Leave")
	return o

func options() -> Array:
	if page == "travel":
		var o: Array = []
		for id in travel_list:
			o.append(String(Game.rooms_meta.rooms[id].title))
		o.append("Back")
		return o
	return main_options()

func update() -> void:
	if not active:
		return
	var n := options().size()
	if Controls.pressed.get("up", false):
		sel = (sel + n - 1) % n
		Audio.sfx("uiMove")
	if Controls.pressed.get("down", false):
		sel = (sel + 1) % n
		Audio.sfx("uiMove")
	if Controls.pressed.get("pause", false) or Controls.pressed.get("dash", false):
		if page == "travel":
			page = "main"
			sel = 0
		else:
			close()
		Audio.sfx("uiBack")
	elif Controls.pressed.get("start", false) or Controls.pressed.get("jump", false) or Controls.pressed.get("attack", false):
		choose(sel)
	queue_redraw()

func choose(i: int) -> void:
	var o := options()
	var label: String = o[i]
	Audio.sfx("uiOk")
	if page == "travel":
		if label == "Back":
			page = "main"
			sel = 0
		else:
			var target: String = travel_list[i]
			close()
			travel_chosen.emit(target)
		return
	match label:
		"Rest":
			rest_chosen.emit()
			close()
		"Travel":
			travel_list = []
			for id in manager.rested_benches():
				if id != manager.room.id:
					travel_list.append(id)
			page = "travel"
			sel = 0
		"Leave":
			close()
	queue_redraw()

func tap(p: Vector2) -> void:
	if not active:
		return
	for i in range(options().size()):
		if Rect2(W / 2.0 - 70, 70 + i * 22, 140, 18).has_point(p):
			sel = i
			choose(i)
			return

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.55))
	PixelText.draw_text(self, "BENCH" if page == "main" else "TRAVEL", W / 2.0, 42, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
	var opts := options()
	for i in range(opts.size()):
		var y := 70 + i * 22
		Gfx.panel(self, W / 2.0 - 70, y, 140, 18, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, opts[i], W / 2.0, y + 5, Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})
