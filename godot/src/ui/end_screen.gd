class_name EndScreen
extends Node2D
# EndScreen: the `D` door at the end of the demo. Time, deaths, memory fragments, tokens and the NULL fight statistics.

const W := 384
const H := 216
signal done

var active := false
var t := 0.0

func _ready() -> void:
	visible = false

func open() -> void:
	active = true
	visible = true
	t = 0.0
	Audio.music("clear")
	queue_redraw()

func update() -> void:
	if not active:
		return
	t += Game.STEP
	if t > 1.0:
		for a in ["jump", "attack", "start", "dash", "pause"]:
			if Controls.pressed.get(a, false):
				done.emit()
	queue_redraw()

func tap(_p: Vector2) -> void:
	if active and t > 1.0:
		done.emit()

static func clock(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(Game.COL.ink))
	PixelText.draw_text(self, "DEMO COMPLETE", W / 2.0, 20, Game.COL.clawd, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": "#3a2630"})
	var rows := [
		["time", clock(Game.play_time)],
		["deaths", str(Game.deaths)],
		["memory fragments", "%d / 4" % Game.fragments],
		["tokens", str(Game.tokens)],
	]
	for i in range(rows.size()):
		var y := 56 + i * 16
		PixelText.draw_text(self, rows[i][0], W / 2.0 - 8, y, Game.COL.dim, {"align": "r"})
		PixelText.draw_text(self, rows[i][1], W / 2.0 + 8, y, Game.COL.paper)
	var last = null
	for f in Game.fights:
		if f.get("won", false):
			last = f
	if last != null:
		var line := "NULL  %.0fs - P1 %d hits - P2 %d hits" % [last.secs, last.hits[0], last.hits[1]]
		PixelText.draw_text(self, line, W / 2.0, 128, Game.COL.paper, {"align": "c"})
		PixelText.draw_text(self, "damage taken  P1 %d - P2 %d - %s" % [last.dmg_taken[0], last.dmg_taken[1], last.diff], W / 2.0, 142, Game.COL.dim, {"align": "c", "tiny": true})
	PixelText.draw_text(self, "to be continued in ~/node_modules", W / 2.0, 172, Game.COL.paper, {"align": "c"})
	if t > 1.0 and int(t * 2.0) % 2 == 0:
		PixelText.draw_text(self, "press any button", W / 2.0, 196, Game.COL.dim, {"align": "c", "tiny": true})
