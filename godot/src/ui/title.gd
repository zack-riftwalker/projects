class_name TitleScreen
extends Node2D
# TitleScreen: Continue / New game / Host co-op / Join co-op / Settings, drawn in the game viewport (384 x 216).
# Pages: main, settings, join (6-digit code with a pad for touch), wait (connecting as a guest).

const W := 384
const H := 216
signal continue_game
signal new_game
signal host_game
signal join_game(code: String)
signal leave_wait
signal fullscreen_requested

const DIFFS := ["easy", "normal", "hard", "nightmare"]
const FS_ROW := 5                 # the Fullscreen row of the settings page (Back is the one after it)
const PAD := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "DEL", "0", "OK"]

var active := false
var page := "main"
var sel := 0
var code := ""
var message := ""
var status := ""
var blink_t := 0.0
var coop: Coop = null
var has_save := false

func _ready() -> void:
	visible = false

func open() -> void:
	has_save = Game.save_exists()          # (looked up once: items() runs every tick)
	active = true
	visible = true
	page = "main"
	sel = 0
	Audio.music("title")
	queue_redraw()

func close() -> void:
	active = false
	visible = false

func items() -> Array:
	var o: Array = []
	if has_save:
		o.append("Continue")
	o.append("New game")
	if Game.host_allowed():
		o.append("Host co-op")
	o.append("Join co-op")
	o.append("Settings")
	return o

func settings_rows() -> Array:
	return ["Difficulty: " + Game.diff, "Co-op boss HP: %d%%" % Game.coop_hp_pct, "Music: %d" % Game.vol_music, "Sound: %d" % Game.vol_sfx, "30 fps: " + ("on" if Game.fps30 else "off"), "Fullscreen: " + ("on" if Game.is_fullscreen() else "off"), "Back"]

# the settings rows are 20 px apart (seven of them plus the hint line fit the 216 px picture)
func settings_y(i: int) -> int:
	return 52 + i * 20

# a failed connection (wrong code, no host ...): back to the code pad with the reason
func fail(why: String) -> void:
	page = "join"
	message = why
	sel = 11
	Audio.sfx("uiBack")
	queue_redraw()

func update() -> void:
	if not active:
		return
	blink_t += Game.STEP
	var pr := Controls.pressed
	match page:
		"main":
			var n := items().size()
			if pr.get("up", false):
				sel = (sel + n - 1) % n
				Audio.sfx("uiMove")
			if pr.get("down", false):
				sel = (sel + 1) % n
				Audio.sfx("uiMove")
			if pr.get("start", false) or pr.get("jump", false) or pr.get("attack", false):
				choose_main(sel)
		"settings":
			var n2 := settings_rows().size()
			if pr.get("up", false):
				sel = (sel + n2 - 1) % n2
				Audio.sfx("uiMove")
			if pr.get("down", false):
				sel = (sel + 1) % n2
				Audio.sfx("uiMove")
			if pr.get("left", false) and sel != FS_ROW:          # (Fullscreen is chosen, not stepped)
				change(sel, -1)
			if pr.get("right", false) and sel != FS_ROW:
				change(sel, 1)
			if pr.get("start", false) or pr.get("jump", false) or pr.get("attack", false):
				change(sel, 1)
			if pr.get("dash", false) or pr.get("pause", false):
				back()
		"join":
			if pr.get("left", false):
				sel = (sel / 3) * 3 + (sel % 3 + 2) % 3
				Audio.sfx("uiMove")
			if pr.get("right", false):
				sel = (sel / 3) * 3 + (sel % 3 + 1) % 3
				Audio.sfx("uiMove")
			if pr.get("up", false):
				sel = (sel + 9) % 12
				Audio.sfx("uiMove")
			if pr.get("down", false):
				sel = (sel + 3) % 12
				Audio.sfx("uiMove")
			if pr.get("start", false) or pr.get("jump", false) or pr.get("attack", false):
				press_pad(sel)
			if pr.get("dash", false) or pr.get("pause", false):
				back()
		"wait":
			if pr.get("dash", false) or pr.get("pause", false):
				back()
			if coop != null and Net.is_open:
				status = "waiting for the host..."
			else:
				status = "connecting..."
	queue_redraw()

func back() -> void:
	Audio.sfx("uiBack")
	if page == "settings" or page == "join":
		if page == "settings":
			Game.save_settings()
		page = "main"
		sel = 0
		message = ""
	elif page == "wait":
		leave_wait.emit()
		page = "join"
		message = ""
		sel = 11
	queue_redraw()

func choose_main(i: int) -> void:
	var label: String = items()[i]
	Audio.sfx("uiOk")
	match label:
		"Continue": continue_game.emit()
		"New game": new_game.emit()
		"Host co-op": host_game.emit()
		"Join co-op":
			page = "join"
			code = ""
			message = ""
			sel = 0
		"Settings":
			page = "settings"
			sel = 0
	queue_redraw()

func change(i: int, d: int) -> void:
	Audio.sfx("uiMove")
	match i:
		0: Game.diff = DIFFS[(DIFFS.find(Game.diff) + d + 4) % 4]
		1: Game.coop_hp_pct = clampi(Game.coop_hp_pct + 25 * d, 25, 100)
		2:
			Game.vol_music = clampi(Game.vol_music + d, 0, 10)
			Audio.refresh_music_volume()
		3:
			Game.vol_sfx = clampi(Game.vol_sfx + d, 0, 10)
			Audio.sfx("token")
		4:
			Game.fps30 = not Game.fps30
			Engine.max_fps = 30 if Game.fps30 else 0
		FS_ROW: fullscreen_requested.emit()
		6: back()
	Game.save_settings()
	queue_redraw()

func press_pad(i: int) -> void:
	var k: String = PAD[i]
	if k == "DEL":
		code = code.substr(0, maxi(0, code.length() - 1))
		Audio.sfx("uiBack")
	elif k == "OK":
		if code.length() == 6:
			Audio.sfx("uiOk")
			page = "wait"
			status = "connecting..."
			message = ""
			join_game.emit(code)
		else:
			message = "6 digits"
			Audio.sfx("uiBack")
	elif code.length() < 6:
		code += k
		message = ""
		Audio.sfx("uiMove")
	queue_redraw()

# keys are forwarded by Main (nodes inside the game viewport get no window input)
func key_event(event: InputEvent) -> void:
	if not active or page != "join" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var kc: int = event.keycode
	if kc >= KEY_0 and kc <= KEY_9:
		press_pad(PAD.find(str(kc - KEY_0)))
	elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
		press_pad(PAD.find(str(kc - KEY_KP_0)))
	elif kc == KEY_BACKSPACE:
		press_pad(9)
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
		press_pad(11)

# the pad button rectangles (game coordinates)
func pad_rect(i: int) -> Rect2:
	return Rect2(W / 2.0 - 58 + (i % 3) * 40, 70 + (i / 3) * 28, 36, 24)

# a tap in game coordinates
func tap(p: Vector2) -> void:
	if not active:
		return
	match page:
		"main":
			for i in range(items().size()):
				if main_rect(i).has_point(p):
					sel = i
					choose_main(i)
		"settings":
			for i in range(settings_rows().size()):
				var r := Rect2(W / 2.0 - 90, settings_y(i), 180, 18)
				if r.has_point(p):
					sel = i
					change(i, -1 if p.x < W / 2.0 - 20 and i < 4 else 1)
		"join":
			for i in range(12):
				if pad_rect(i).has_point(p):
					sel = i
					press_pad(i)
			if Rect2(8, H - 24, 60, 16).has_point(p):
				back()
		"wait":
			if Rect2(W / 2.0 - 40, 140, 80, 18).has_point(p):
				back()

func main_rect(i: int) -> Rect2:
	return Rect2(W / 2.0 - 70, 92 + i * 20, 140, 16)

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(Game.COL.ink))
	# a faint floor of tiles and a scrolling prompt line
	for i in range(0, W, 16):
		draw_rect(Rect2(i, 196, 15, 20), Color("#17131f"))
		draw_rect(Rect2(i, 196, 15, 2), Color("#2a2236"))
	var bob := sin(blink_t * 2.0) * 2.0
	if page == "main" or page == "wait":
		PixelText.draw_text(self, "CLAWD", W / 2.0, 22 + bob, Game.COL.clawd, {"align": "c", "scale": 3, "outline": Game.COL.ink, "shadow": "#3a2630"})
		PixelText.draw_text(self, "metroidvania demo - ~/src", W / 2.0, 58, Game.COL.dim, {"align": "c"})
	match page:
		"main":
			var it := items()
			for i in range(it.size()):
				var r := main_rect(i)
				Gfx.panel(self, r.position.x, r.position.y, r.size.x, r.size.y, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
				PixelText.draw_text(self, it[i], W / 2.0, r.position.y + 4, Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})
		"settings":
			PixelText.draw_text(self, "SETTINGS", W / 2.0, 22, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
			var rows := settings_rows()
			for i in range(rows.size()):
				var y := settings_y(i)
				Gfx.panel(self, W / 2.0 - 90, y, 180, 18, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
				PixelText.draw_text(self, rows[i], W / 2.0, y + 5, Game.COL.paper if i == sel else Game.COL.dim, {"align": "c"})
			PixelText.draw_text(self, "left / right to change - applies from the next room", W / 2.0, 198, Game.COL.dim, {"align": "c", "tiny": true})
		"join":
			PixelText.draw_text(self, "JOIN CO-OP", W / 2.0, 12, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
			for i in range(6):
				var x := W / 2.0 - 77 + i * 26
				Gfx.panel(self, x, 36, 22, 26, "#17131f", Game.COL.clawd if i == code.length() and int(blink_t * 3.0) % 2 == 0 else "#3a3346")
				if i < code.length():
					PixelText.draw_text(self, code[i], x + 11, 43, Game.COL.paper, {"align": "c", "scale": 2})
			for i in range(12):
				var r := pad_rect(i)
				var lab: String = PAD[i]
				var dis: bool = lab == "OK" and code.length() < 6
				Gfx.panel(self, r.position.x, r.position.y, r.size.x, r.size.y, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
				PixelText.draw_text(self, lab, r.position.x + r.size.x / 2.0, r.position.y + 8, Game.COL.dim if dis else Game.COL.paper, {"align": "c"})
			if message != "":
				PixelText.draw_text(self, message, W / 2.0, 188, "#ff6b6b", {"align": "c"})
			Gfx.panel(self, 8, H - 24, 60, 16, "#17131f", "#3a3346")
			PixelText.draw_text(self, "BACK", 38, H - 20, Game.COL.dim, {"align": "c"})
		"wait":
			PixelText.draw_text(self, status, W / 2.0, 110, Game.COL.paper, {"align": "c"})
			PixelText.draw_text(self, "code " + code, W / 2.0, 126, Game.COL.dim, {"align": "c"})
			Gfx.panel(self, W / 2.0 - 40, 140, 80, 18, "#2a2236", Game.COL.clawd)
			PixelText.draw_text(self, "CANCEL", W / 2.0, 145, Game.COL.paper, {"align": "c"})
	if Game.build_text != "":
		PixelText.draw_text(self, Game.build_text, W - 4, H - 8, "#3a3346", {"align": "r", "tiny": true})
