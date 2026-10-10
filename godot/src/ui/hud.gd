class_name Hud
extends Node2D
# Hud: hit points, tokens, sparks, the room title for a moment, and the sign bubble (port of the HUD in js/scenes.js, phase 1 subset).

const W := 384
const H := 216
var room: Room
var age := 0.0
var fade := 0.0
var notice := ""
var partner_hp := -1
var partner_max := 0
var partner_dot := ""            # line quality, as in the JS game: green good, yellow slow, red bad, grey the partner is not answering
var partner_text := ""           # "down", "back in 4"
var me_text := ""                # my own body is down: "DOWN - BACK IN 4", "BOTH DOWN"

func set_room(r: Room) -> void:
	room = r
	age = 0.0

func _process(dt: float) -> void:
	age += dt
	queue_redraw()

func _draw() -> void:
	if fade > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.051, 0.039, 0.071, fade))
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
	# the context meter under the pips: 99 wide, marks at 33 and 66
	var meter_y := hud_y + 11
	draw_rect(Rect2(6, meter_y, Game.METER_MAX, 3), Color("#3a3346"))
	draw_rect(Rect2(6, meter_y, int(p.meter), 3), Color("#ffe2c4"))
	draw_rect(Rect2(6 + 33, meter_y, 1, 3), Color(Game.COL.ink))
	draw_rect(Rect2(6 + 66, meter_y, 1, 3), Color(Game.COL.ink))
	var tk := str(room.tokens)
	var tw := PixelText.text_width(tk)
	Gfx.spr_at(self, "token_0", W - 20 - tw, hud_y - 1)
	PixelText.draw_text(self, tk, W - 8, hud_y, Game.COL.paper, {"align": "r", "outline": Game.COL.ink})
	# memory fragments: a small square of 4 segments next to the pips
	var fx_: int = 6 + p.max_hp * 9 + 2
	draw_rect(Rect2(fx_, hud_y, 8, 8), Color(Game.COL.ink))
	var filled := Game.fragments % 4
	for q in range(4):
		draw_rect(Rect2(fx_ + 1 + (q % 2) * 3, hud_y + 1 + (q / 2) * 3, 2, 2), Color(Game.COL.clawdHi) if q < filled else Color("#3a3346"))
	# boss: the name and the health bar at the bottom, the name card during the intro
	var b = room.boss
	if b != null and not b.dead and (room.fight.state == "active" or room.fight.state == "reward"):
		var bw := 190
		var bx := (W - bw) / 2
		var byy := H - 12
		PixelText.draw_text(self, b.boss_name, bx, byy - 9, Game.COL.paper, {"tiny": true, "outline": Game.COL.ink})
		Gfx.panel(self, bx - 2, byy - 2, bw + 4, 7, "#231d2e", Game.COL.ink)
		draw_rect(Rect2(bx, byy, bw, 3), Color("#5a1630"))
		var fw := roundi(bw * maxf(0.0, b.hpf) / maxf(1.0, float(b.max_hp)))
		draw_rect(Rect2(bx, byy, fw, 3), Color.WHITE if b.flash > 0.0 else Color(Game.COL.hazard))
		draw_rect(Rect2(bx, byy, fw, 1), Color("#ff9aab"))
	if b != null and room.fight.state == "intro":
		var k := _ease_out(clampf((1.5 - room.fight.t - 0.3) / 0.5, 0.0, 1.0))
		if k > 0.0:
			PixelText.draw_text(self, b.boss_name, W / 2.0, 40 - (1.0 - k) * 12.0, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
			draw_rect(Rect2(floori(W / 2.0 - 70.0 * k + 0.5), 60, floori(140.0 * k + 0.5), 1), Color(Game.COL.hazard))
			PixelText.draw_text(self, b.sub, W / 2.0, 65, Game.COL.hazardHi, {"align": "c", "outline": Game.COL.ink})
	if room.banner.text != "":
		PixelText.draw_text(self, room.banner.text, W / 2.0, 70, Game.COL.paper, {"align": "c", "scale": 3, "outline": Game.COL.ink, "shadow": Game.COL.ink})
		PixelText.draw_text(self, room.banner.sub, W / 2.0, 100, Game.COL.hazardHi, {"align": "c", "outline": Game.COL.ink})
	if room.stats_t > 0.0 and room.stats_line != "":
		PixelText.draw_text(self, room.stats_line, W / 2.0, H - 34, Game.COL.paper, {"align": "c", "outline": Game.COL.ink})
	if notice != "":
		PixelText.draw_text(self, notice, W / 2.0, 22, Game.COL.paper, {"align": "c", "outline": Game.COL.ink})
	if partner_hp >= 0:
		var n: int = maxi(partner_max, partner_hp)
		for i in range(n):
			draw_rect(Rect2(6 + i * 5, 22, 4, 4), Color("#6aa8ff") if i < partner_hp else Color("#2a3550"))
		var dx := 8 + n * 5
		if partner_dot != "":
			draw_rect(Rect2(dx - 1, 21, 6, 6), Color(Game.COL.ink))
			draw_rect(Rect2(dx, 22, 4, 4), Color(partner_dot))
			dx += 8
		if partner_text != "":
			PixelText.draw_text(self, partner_text, dx, 20, "#8d8798", {"tiny": true})
	if me_text != "":
		var mw := PixelText.text_width(me_text) + 16
		Gfx.panel(self, floori((W - mw) / 2.0), 40, mw, 15, "#17131f", "#ffb38a")
		PixelText.draw_text(self, me_text, W / 2.0, 44, "#ffd9c4", {"align": "c"})
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
