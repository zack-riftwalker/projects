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
var manager: RoomManager:
	set(v):
		manager = v
		if map_view != null:
			map_view.manager = v
var map_view: MapView
var logs_view: LogsView
var blink_t := 0.0
var log_msg := ""
var refight_msg := ""

func options() -> Array:
	var o := ["Resume", "Map", "Logs", "Fights", "Restart room", "30 fps: " + ("on" if Game.fps30 else "off"), "Fullscreen: " + ("on" if Game.is_fullscreen() else "off"), "Graphics: " + Game.GFX_NAMES[Game.gfx_tier], "Reduce flashing: " + ("on" if Game.reduce_flash else "off")]
	if Game.debug:
		o.append("Refight bosses" if refight_msg == "" else refight_msg)
		o.append(log_msg if log_msg != "" else "Copy log (5 min)")
	if can_skip_boss():
		o.append("Skip boss (temp)")
	return o

# TEMPORARY: only in a boss fight, alone or as the host
func can_skip_boss() -> bool:
	var r = manager.room if manager != null else null
	return r != null and r.boss != null and is_instance_valid(r.boss) and String(r.fight.state) in ["intro", "active"] and Game.net_role != "guest"

func open() -> void:
	active = true
	sel = 0
	log_msg = ""
	refight_msg = ""
	page = "menu"
	if map_view != null:
		map_view.close()
		logs_view.close()
	visible = true
	Audio.sfx("pause")
	Audio.duck(-10.0)
	queue_redraw()

func close() -> void:
	active = false
	visible = false
	if map_view != null:
		map_view.close()
		logs_view.close()
	Audio.duck(0.0)

func _ready() -> void:
	visible = false
	map_view = MapView.new()
	map_view.dim = false
	map_view.manager = manager
	map_view.back_requested.connect(func():
		page = "menu"
		map_view.close())
	add_child(map_view)
	logs_view = LogsView.new()
	logs_view.back_requested.connect(func():
		page = "menu"
		logs_view.close())
	add_child(logs_view)

# called every fixed step while paused (Main polls the controls itself then)
func update() -> void:
	if not active:
		return
	blink_t += Game.STEP
	if page == "map":
		map_view.update()
		queue_redraw()
		return
	if page == "logs":
		logs_view.update()
		queue_redraw()
		return
	if page == "fights":
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
	if options()[i] == "Skip boss (temp)":       # (its index moves with ?debug, so it is matched by its label)
		if manager.room.skip_boss():
			resume_requested.emit()
		return
	match i:
		0: resume_requested.emit()
		1:
			page = "map"
			map_view.open()
		2:
			page = "logs"
			logs_view.open()
		3: page = "fights"
		4: restart_requested.emit()
		5:
			Game.fps30 = not Game.fps30
			Engine.max_fps = 30 if Game.fps30 else 0
		6: fullscreen_requested.emit()
		7:                                       # Low -> High -> Ultra -> Low (kept: the settings file)
			Game.gfx_tier = (Game.gfx_tier + 1) % 3
			Game.save_settings()
		8:
			Game.reduce_flash = not Game.reduce_flash
			Game.save_settings()
		9: refight_bosses()
		10: log_msg = "Log copied: %d lines" % Game.export_log()
	queue_redraw()

# a tap in game coordinates (0..384, 0..216)
func tap(p: Vector2) -> void:
	if not active:
		return
	if page == "map":
		map_view.tap(p)
		return
	if page == "logs":
		logs_view.tap(p)
		return
	if page != "menu":
		page = "menu"
		return
	for i in range(options().size()):
		if Rect2(W / 2.0 - 70, 52 + i * row_step(), 140, row_h()).has_point(p):
			choose(i)

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.6))
	if page == "map" or page == "logs":
		return                                    # (the map and the logs are child nodes and draw themselves)
	if page == "fights":
		_draw_fights()
		return
	if not Game.equipped.is_empty():                       # the plugins on (read only; they change at a bench)
		var names: Array = []
		for id in Game.equipped:
			names.append(Game.plugin_def(String(id)).name)
		PixelText.draw_text(self, "plugins: " + ", ".join(names), 6, H - 9, "#58f0c8", {"tiny": true})
	PixelText.draw_text(self, "PAUSED", W / 2.0, 30, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
	var opts := options()
	for i in range(opts.size()):
		var y := 52 + i * row_step()
		Gfx.panel(self, W / 2.0 - 70, y, 140, row_h(), "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, opts[i], W / 2.0, y + (4 if row_h() == 17 else 2), Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})

# more options than fit: tighter rows (the debug menu, a boss fight with the skip entry)
func row_step() -> int:
	var n := options().size()
	return 19 if n <= 7 else (16 if n <= 10 else 14)

func row_h() -> int:
	return 17 if row_step() == 19 else (14 if row_step() == 16 else 12)

# ?debug: forget the beaten bosses so they can be fought again for more measurements (abilities and plugins stay)
func refight_bosses() -> void:
	if Game.net_role == "guest":
		refight_msg = "the host does this"
		return
	var n := 0
	for k in Game.flags.keys():
		if String(k).begins_with("boss:"):
			Game.flags.erase(k)
			n += 1
	Game.write_save()
	refight_msg = "%d bosses can be fought again (restart the room)" % n

# one line per fight: NULL 72s P1 41 P2 30 r 0.99 won normal
static func fight_line(f: Dictionary) -> String:
	var secs := maxf(float(f.secs), 0.001)
	var np: int = 2 if f.get("coop", false) else 1
	var r: float = (float(f.hits[0]) + float(f.hits[1])) / np / secs
	var s := "%s %ds P1 %d" % [f.boss, roundi(secs), f.hits[0]]
	if np == 2:
		s += " P2 %d" % f.hits[1]
	return s + " r %.2f %s %s" % [r, "won" if f.won else "lost", f.diff]

static func fight_average(fs: Array) -> String:
	var sum := 0.0
	var n := 0
	for f in fs:
		if f.won:
			var np: int = 2 if f.get("coop", false) else 1
			sum += (float(f.hits[0]) + float(f.hits[1])) / np / maxf(float(f.secs), 0.001)
			n += 1
	return "average r (won fights): %.2f over %d fights" % [sum / n if n > 0 else 0.0, n]

func _draw_fights() -> void:
	PixelText.draw_text(self, "FIGHTS", W / 2.0, 20, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
	if Game.net_role == "guest":
		PixelText.draw_text(self, "the host keeps the fight list", W / 2.0, 90, Game.COL.dim, {"align": "c"})
		return
	var fs: Array = Game.fights
	if fs.is_empty():
		PixelText.draw_text(self, "no fights yet", W / 2.0, 90, Game.COL.dim, {"align": "c"})
	for i in range(mini(10, fs.size())):
		PixelText.draw_text(self, fight_line(fs[fs.size() - 1 - i]), 24, 44 + i * 12, Game.COL.paper, {"tiny": true})
	PixelText.draw_text(self, fight_average(fs), 24, 44 + 10 * 12 + 6, Game.COL.gold, {"tiny": true})
	PixelText.draw_text(self, "press any button to go back", W / 2.0, H - 22, Game.COL.dim, {"align": "c", "tiny": true})
