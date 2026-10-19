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
var ping_hits: Array = []        # [{id, rect}] the ping arrows of the last draw (a tap on one acknowledges it)
var toasts: Array = []           # small panels at the bottom for a few seconds (the terminal's changelog line): [{text, t}]

func toast(text: String, secs: float) -> void:
	toasts.append({"text": text, "t": secs})
	if toasts.size() > 4:
		toasts.pop_front()

func set_room(r: Room) -> void:
	room = r
	age = 0.0

func _process(dt: float) -> void:
	age += dt
	for tq in toasts:
		tq.t -= dt
	toasts = toasts.filter(func(q): return q.t > 0.0)
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
	if p.agents_t > 0.0:                      # while the agents fly the bar shows how long they still have
		draw_rect(Rect2(6, meter_y, int(Game.METER_MAX * clampf(p.agents_t / 11.0, 0.0, 1.0)), 3), Color("#f0b79a"))
	else:
		draw_rect(Rect2(6, meter_y, int(p.meter), 3), Color("#ffe2c4"))
	draw_rect(Rect2(6 + 33, meter_y, 1, 3), Color(Game.COL.ink))
	draw_rect(Rect2(6 + 66, meter_y, 1, 3), Color(Game.COL.ink))
	if room.world == 4:                       # THREAD TOWER: a small pendulum at the top centre swings on the tick (the extremes are the ticks)
		var pa: float = 0.5 * cos(PI * room.time / Tower.TICK)
		var piv := Vector2(W / 2.0, 1.0)
		var bob := piv + Vector2(sin(pa), cos(pa)) * 10.0
		draw_line(piv, bob, Color(Game.COL.ink), 3.0)
		draw_line(piv, bob, Color("#dcae5e"), 1.0)
		draw_circle(bob, 2.5, Color(Game.COL.ink))
		draw_circle(bob, 1.5, Color("#f3d58a"))
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
		var bar_f: float = maxf(0.0, b.hpf) / maxf(1.0, float(b.max_hp))
		var bar_c := Color(Game.COL.hazard)
		var bar_bg := Color("#5a1630")
		var bar_hi := Color("#ff9aab")
		var bar_name: String = b.boss_name
		if b.has_method("hud_bar"):                      # a boss with bars of its own (THE FIREWALL: [fraction, colour, name])
			var hb: Array = b.hud_bar()
			bar_f = float(hb[0])
			bar_c = Color(hb[1])
			bar_bg = bar_c.darkened(0.75)
			bar_hi = bar_c.lightened(0.45)
			bar_name = String(hb[2])
		PixelText.draw_text(self, bar_name, bx, byy - 9, Game.COL.paper, {"tiny": true, "outline": Game.COL.ink})
		Gfx.panel(self, bx - 2, byy - 2, bw + 4, 7, "#231d2e", Game.COL.ink)
		draw_rect(Rect2(bx, byy, bw, 3), bar_bg)
		var fw := roundi(bw * bar_f)
		draw_rect(Rect2(bx, byy, fw, 3), Color.WHITE if b.flash > 0.0 else bar_c)
		draw_rect(Rect2(bx, byy, fw, 1), bar_hi)
	if b != null and room.fight.state == "intro":
		var k := _ease_out(clampf((1.5 - room.fight.t - 0.3) / 0.5, 0.0, 1.0))
		if k > 0.0:
			PixelText.draw_text(self, b.boss_name, W / 2.0, 40 - (1.0 - k) * 12.0, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
			draw_rect(Rect2(floori(W / 2.0 - 70.0 * k + 0.5), 60, floori(140.0 * k + 0.5), 1), Color(Game.COL.hazard))
			PixelText.draw_text(self, b.sub, W / 2.0, 65, Game.COL.hazardHi, {"align": "c", "outline": Game.COL.ink})
	if room.banner.text != "":
		PixelText.draw_text(self, room.banner.text, W / 2.0, 70, Game.COL.paper, {"align": "c", "scale": 3, "outline": Game.COL.ink, "shadow": Game.COL.ink})
		PixelText.draw_text(self, room.banner.sub, W / 2.0, 100, Game.COL.hazardHi, {"align": "c", "outline": Game.COL.ink})
	if room.pick_banner.t > 0.0:
		PixelText.draw_text(self, room.pick_banner.text, W / 2.0, 60, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
		PixelText.draw_text(self, room.pick_banner.sub, W / 2.0, 80, "#58f0c8", {"align": "c", "outline": Game.COL.ink})
	if room.memory.t > 0.0:                                 # the memory line under the fragment's pop
		var mlines := PixelText.wrap(String(room.memory.text), 300)
		var ma := clampf(room.memory.t, 0.0, 1.0)
		for mi in range(mlines.size()):
			var mc := Color("#fff3e4")
			mc.a = ma
			PixelText.draw_text(self, mlines[mi], W / 2.0, 100 + mi * 11, mc, {"align": "c", "outline": Color(0.106, 0.071, 0.149, ma)})
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
		var label: String = String(Game.theme(room.world).path) + "/" + str(room.def.get("title", room.id))
		var pw := PixelText.text_width(label) + 22
		var px := floori(-pw + (pw + 6) * k + 0.5)
		Gfx.panel(self, px, 30, pw, 15, "#17131f", "#3a3346")
		draw_rect(Rect2(px + 2, 31, 2, 13), Color("#5b9bd5") if false else Color(Game.COL.ok))
		PixelText.draw_text(self, label, px + 9, 34, Game.COL.paper)
	_draw_pings()
	# toasts: one small panel per line, under the middle of the screen
	var ty := H - 40 - toasts.size() * 16
	for tq in toasts:
		var tlines := PixelText.wrap(String(tq.text), 300)
		var tw2 := 0
		for l in tlines:
			tw2 = maxi(tw2, PixelText.text_width(l))
		Gfx.panel(self, floori((W - tw2 - 12) / 2.0), ty, tw2 + 12, tlines.size() * 11 + 5, "#17131f", "#58f0c8", "#0d0a12")
		for li in range(tlines.size()):
			PixelText.draw_text(self, tlines[li], W / 2.0, ty + 4 + li * 11, "#d6fff4", {"align": "c"})
		ty += 16 + (tlines.size() - 1) * 11
	# sign bubble
	if room.sign_now != null:
		var s: Dictionary = room.sign_now
		var lines := PixelText.wrap(_expand(room.sign_text(s)), 196)
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
	# last, over everything else (the room tab, toasts): CRAWLER OF THE WEB's lines, and the scene when it falls
	if b != null and is_instance_valid(b) and b.has_method("draw_hud"):
		b.draw_hud(self)

# the partner's (and our own) pings as arrows at the screen edge: [{id, pos, dir, word, secs, by, ack, on_screen}]
func ping_arrows() -> Array:
	var out: Array = []
	if room == null or room.player == null:
		return out
	Game.pings_purge()
	var p = room.player
	var rm: Dictionary = Game.rooms_meta.rooms[room.id]
	var origin := Vector2(float(rm.origin[0]), float(rm.origin[1])) * 16.0
	var tnow := Game._now_s()
	var c := Vector2(W / 2.0, H / 2.0)
	for q in Game.pings:
		if not Game.rooms_meta.rooms.has(String(q.room)):
			continue
		var qm: Dictionary = Game.rooms_meta.rooms[q.room]
		var target := Vector2(float(qm.origin[0]), float(qm.origin[1])) * 16.0 + Vector2(float(q.x), float(q.y))
		var from := origin + Vector2(p.x + 5.0, p.y + 5.0)
		if q.room != room.id:
			from = origin + Vector2(float(rm.size[0]), float(rm.size[1])) * 8.0        # another room: from the middle of this one
		var d := target - from
		var pos := Vector2.ZERO
		var on_screen := false
		if q.room == room.id:
			pos = Vector2(float(q.x) - room.cam.x, float(q.y) - room.cam.y)
			on_screen = pos.x > 10.0 and pos.x < W - 10.0 and pos.y > 28.0 and pos.y < H - 10.0
		if not on_screen:
			if d.length() < 1.0:
				d = Vector2(1, 0)
			var k := minf(absf((W / 2.0 - 16.0) / d.x) if d.x != 0.0 else 1e9, absf((H / 2.0 - 16.0) / d.y) if d.y != 0.0 else 1e9)
			pos = c + d * k
		out.append({"id": String(q.id), "pos": pos, "dir": d.normalized(), "word": String(q.kind), "secs": ceili(float(q.until) - tnow), "by": String(q.by), "ack": bool(q.ack), "on_screen": on_screen})
	return out

func _draw_pings() -> void:
	ping_hits = []
	for a in ping_arrows():
		var col := MapView.owner_color(String(a.by))
		var pos: Vector2 = a.pos
		var d: Vector2 = a.dir
		if a.on_screen:
			# the ping is in view: a ring on the spot, the word above it
			var pulse := 0.5 + 0.5 * sin(Game._now_s() * 7.0)
			draw_arc(pos, 6.0 + 3.0 * pulse, 0.0, TAU, 20, col, 1.0)
		else:
			var tip := pos + d * 7.0
			var side := Vector2(-d.y, d.x) * 4.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(1, 1), pos - d * 4.0 + side + Vector2(1, 1), pos - d * 4.0 - side + Vector2(1, 1)]), Color(Game.COL.ink))
			draw_colored_polygon(PackedVector2Array([tip, pos - d * 4.0 + side, pos - d * 4.0 - side]), col)
		var label := "%s %d%s" % [a.word, a.secs, " ✓" if a.ack else ""]
		var tw := PixelText.text_width(label, {"tiny": true})
		var lx := clampf(pos.x - tw / 2.0 - d.x * 12.0 * (0.0 if a.on_screen else 1.0), 2.0, W - tw - 2.0)
		var ly := clampf(pos.y - 14.0 * (1.0 if a.on_screen else 0.0) - d.y * 12.0 * (0.0 if a.on_screen else 1.0) - 2.0, 28.0, H - 10.0)
		PixelText.draw_text(self, label, lx, ly, col, {"tiny": true, "outline": Game.COL.ink})
		ping_hits.append({"id": a.id, "rect": Rect2(minf(pos.x, lx) - 6.0, minf(pos.y, ly) - 8.0, absf(pos.x - lx) + tw + 12.0, 22.0)})

# a tap on a ping arrow says "seen" (the sender gets a tick)
func ping_tap(p: Vector2) -> bool:
	for h in ping_hits:
		if h.rect.has_point(p):
			Game.ping_ack_one(String(h.id))
			return true
	return false

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
