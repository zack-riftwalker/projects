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
var plugin_ids: Array = []        # the owned plugins listed on the Plugins page

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
	if not manager.travel_targets().is_empty() and bool(Game.rooms_meta.rooms[manager.room.id].get("terminal", false)):
		o.append("Travel")
	o.append("Plugins")
	o.append("Leave")
	return o

# one row per owned plugin: [x] async/await ●●  (the dots are its notches)
func plugin_rows() -> Array:
	plugin_ids = []
	var rows: Array = []
	for d in Game.PLUGINS:
		if Game.owns_plugin(d.id):
			plugin_ids.append(d.id)
			rows.append(("[x] " if Game.equipped.has(d.id) else "[ ] ") + d.name + " " + "o".repeat(int(d.cost)))
	rows.append("Back")
	return rows

func options() -> Array:
	if page == "plugins":
		return plugin_rows()
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
		if page != "main":
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
	if page == "plugins":
		if label == "Back":
			page = "main"
			sel = 0
		elif not Game.toggle_plugin(plugin_ids[i]):
			Audio.sfx("thud")                  # the context window is full
		queue_redraw()
		return
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
			travel_list = manager.travel_targets()
			page = "travel"
			sel = 0
		"Plugins":
			page = "plugins"
			sel = 0
		"Leave":
			close()
	queue_redraw()

func tap(p: Vector2) -> void:
	if not active:
		return
	for i in range(options().size()):
		if Rect2(W / 2.0 - 70, (70 if page != "plugins" else 62) + i * row_step(), 140, row_h()).has_point(p):
			sel = i
			choose(i)
			return

# many plugins: tighter rows so the list still fits the screen
func row_step() -> int:
	return 22 if page != "plugins" or options().size() <= 6 else 17

func row_h() -> int:
	return 18 if row_step() == 22 else 14

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.55))
	PixelText.draw_text(self, {"main": "BENCH", "travel": "TRAVEL", "plugins": "PLUGINS"}[page], W / 2.0, 30, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
	var opts := options()
	if page == "plugins":
		PixelText.draw_text(self, "context %d/%d" % [Game.notches_used(), Game.NOTCHES], W / 2.0, 50, Game.COL.gold, {"align": "c"})
	for i in range(opts.size()):
		var y := (70 if page != "plugins" else 62) + i * row_step()
		Gfx.panel(self, W / 2.0 - 70, y, 140, row_h(), "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, opts[i], W / 2.0, y + (5 if row_h() == 18 else 3), Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})
	if page == "plugins" and sel < plugin_ids.size():
		PixelText.draw_text(self, String(Game.plugin_def(String(plugin_ids[sel])).get("desc", "")), W / 2.0, H - 12, Game.COL.paper, {"align": "c", "tiny": true})
