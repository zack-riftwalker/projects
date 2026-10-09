class_name Hud
extends Node2D
# Hud: hit points, tokens, sparks, the room title for a moment, and the sign bubble (port of the HUD in js/scenes.js, phase 1 subset).

const W := 384
const H := 216
var room: Room
var age := 0.0

func set_room(r: Room) -> void:
	room = r
	age = 0.0

func _process(dt: float) -> void:
	age += dt
	queue_redraw()

func _draw() -> void:
	if room == null or room.player == null:
		return
	var p = room.player
	var hud_y := 6
	var t := room.time
	for i in range(p.max_hp):
		var low: bool = p.hp == 1 and i == 0 and int(t * 4.0) % 2 == 1
		if i < p.hp:
			Gfx.spr_at(self, "pip", 6 + i * 9, hud_y)
		else:
			Gfx.spr_at(self, "pipOff", 6 + i * 9, hud_y)
		if low:
			draw_rect(Rect2(6 + i * 9, hud_y, 8, 8), Color(1, 1, 1, 0.55))
	var tk := str(room.tokens)
	var tw := PixelText.text_width(tk)
	Gfx.spr_at(self, "token_0", W - 20 - tw, hud_y - 1)
	PixelText.draw_text(self, tk, W - 8, hud_y, Game.COL.paper, {"align": "r", "outline": Game.COL.ink})
	for i in range(3):
		Gfx.spr_at(self, "sparkSm_%d" % (0 if room.sparks[i] else 2), W - 37 + i * 10, hud_y + 10)
	# room title tab
	if age < 3.2:
		var k := _ease_out(clampf(age / 0.4, 0.0, 1.0)) * (1.0 - _ease_in(clampf((age - 2.7) / 0.5, 0.0, 1.0)))
		var label: String = "~/src/" + str(room.def.get("title", room.id))
		var pw := PixelText.text_width(label) + 22
		var px := floori(-pw + (pw + 6) * k + 0.5)
		Gfx.panel(self, px, 30, pw, 15, "#17131f", "#3a3346")
		draw_rect(Rect2(px + 2, 31, 2, 13), Color("#5b9bd5") if false else Color(Game.COL.ok))
		PixelText.draw_text(self, label, px + 9, 34, Game.COL.paper)
	# sign bubble
	if room.sign_now != null:
		var s: Dictionary = room.sign_now
		var lines := PixelText.wrap(_expand(s.text), 196)
		var bw := 0
		for l in lines:
			bw = maxi(bw, PixelText.text_width(l))
		bw += 12
		var bh: int = lines.size() * 13 + 7
		var bx := floori(clampf(s.x - room.cam.x - bw / 2.0, 4, W - bw - 4) + 0.5)
		var by := maxi(22, floori(s.y - room.cam.y - 24 - bh + 0.5))
		Gfx.panel(self, bx, by, bw, bh, "#17131f", Game.COL.paper, "#0d0a12")
		draw_rect(Rect2(floori(clampf(s.x - room.cam.x, bx + 4, bx + bw - 6)), by + bh, 3, 2), Color(Game.COL.paper))
		for i in range(lines.size()):
			PixelText.draw_text(self, lines[i], bx + 6, by + 6 + i * 13, Game.COL.paper)

static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)

static func _ease_in(u: float) -> float:
	return u * u * u

# [move] [jump] ... become key names (keyboard) or button names (touch)
static func _expand(text: String) -> String:
	var names := {"move": "ARROWS", "jump": "Z", "attack": "X", "dash": "C", "special": "V", "down": "DOWN"}
	if Game.touch_seen:
		names = {"move": "STICK", "jump": "JUMP", "attack": "CLAW", "dash": "DASH", "special": "SPECIAL", "down": "DOWN"}
	for k in names:
		text = text.replace("[" + k + "]", names[k])
	return text
