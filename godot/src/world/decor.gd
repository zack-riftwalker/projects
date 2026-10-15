class_name Decor
extends RefCounted
# Decor: everything a room shows that is not a tile, a creature or an item: the cartographer `tree`, decoration (MVB1-13), lost-agent jars
# (MVB1-11), logbook pages (MVB1-12) and the far landmarks (MVB1-14). Purely a look (and local sounds): nothing here is simulated for
# the other player, so host and guest each run their own copy from the room's clock and the flags.

const T := 16

# ---------------------------------------------------------------- per step (both pages)
static func step(r: Room, dt: float) -> void:
	for n in r.npcs:
		_step_tree(r, n, dt)
	_step_jars(r, dt)

static func _near(r: Room, x: float, y: float, tiles: float) -> float:
	var best := 1e9
	for q in r.players():
		best = minf(best, Vector2(q.x + q.w / 2.0 - x, q.y + q.h / 2.0 - y).length())
	return best / (T * tiles)            # 0 = at it, 1 = exactly `tiles` away

# ---------------------------------------------------------------- the cartographer `tree`
# A hunched daemon at a desk with a printer. While somebody is within 10 tiles the printer prints one `├──` line every 2 s; a full strip tears off
# and falls. The typing tick is heard within 14 tiles, louder when closer; the paper scraps lying around (decor `scrap`) lead to it.
const STRIP_MAX := 3

static func _step_tree(r: Room, n: Dictionary, dt: float) -> void:
	var close := _near(r, n.x, n.y - 8.0, 10.0) < 1.0
	if close:
		n.acc += dt
		if n.acc >= 2.0:
			n.acc = 0.0
			if n.strip >= STRIP_MAX:
				n.strip = 0
				n.scraps.append({"x": n.x + 26.0, "y": n.y - 14.0, "vx": 14.0, "vy": -30.0, "rot": 0.0, "life": 3.0})
			else:
				n.strip += 1
	for sc in n.scraps:
		sc.life -= dt
		sc.vy += 220.0 * dt
		sc.x += sc.vx * dt
		sc.y = minf(sc.y + sc.vy * dt, n.y - 1.0)
		if sc.y >= n.y - 1.0:
			sc.vx = 0.0
			sc.vy = 0.0
		sc.rot += dt * 3.0
	n.scraps = n.scraps.filter(func(sc): return sc.life > 0.0)
	# the typing tick, heard on this page by this page's player only
	n.tick_t -= dt
	if n.tick_t <= 0.0:
		n.tick_t = r.rng.randf_range(0.08, 0.25)
		if r.player != null and not r.player.dead:
			var d := _near(r, n.x, n.y - 8.0, 14.0)
			if d < 1.0:
				Audio.local_sfx("tick", 0.07 + 0.22 * (1.0 - d))

static func draw_tree(ci: CanvasItem, r: Room, n: Dictionary) -> void:
	var x := floori(n.x)
	var y := floori(n.y)
	var zc := Color(String(Game.zone_def(String(n.zone)).get("col", "#8d8798")))
	var ink := Color(Game.COL.ink)
	var t: float = r.time
	# desk
	ci.draw_rect(Rect2(x + 6, y - 9, 26, 3), ink)
	ci.draw_rect(Rect2(x + 7, y - 9, 24, 2), Color("#6b5238"))
	ci.draw_rect(Rect2(x + 8, y - 7, 2, 7), Color("#4a3826"))
	ci.draw_rect(Rect2(x + 28, y - 7, 2, 7), Color("#4a3826"))
	# printer on the desk, with a blinking led
	ci.draw_rect(Rect2(x + 11, y - 17, 14, 9), ink)
	ci.draw_rect(Rect2(x + 12, y - 16, 12, 7), Color("#cfc8d8"))
	ci.draw_rect(Rect2(x + 12, y - 12, 12, 1), Color("#8d8798"))
	ci.draw_rect(Rect2(x + 20, y - 15, 2, 1), zc if int(t * 2.0) % 2 == 0 else Color("#3a3346"))
	# the paper strip hangs from the printer's right side, one `├──` line per print
	var lines: int = n.strip
	if lines > 0:
		var ph := lines * 6 + 2
		ci.draw_rect(Rect2(x + 24, y - 15, 12, ph), Color(Game.COL.paper))
		ci.draw_rect(Rect2(x + 24, y - 15 + ph, 12, 1), Color("#cfc8d8"))
		for i in range(lines):
			PixelText.draw_text(ci, "├──" if i < lines - 1 or lines == STRIP_MAX else "└──", x + 25, y - 13 + i * 6, "#3a3346", {"tiny": true})
	for sc in n.scraps:
		ci.draw_set_transform(Vector2(sc.x, sc.y), sc.rot if sc.vy != 0.0 else 0.3, Vector2.ONE)
		ci.draw_rect(Rect2(-3, -2, 6, 4), Color(Game.COL.paper))
		ci.draw_rect(Rect2(-2, -1, 3, 1), Color("#8d8798"))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the daemon: a hunched hooded shape facing the desk, two eyes in the zone's colour, an arm on the keys
	var bob := 1 if int(t * 5.0) % 2 == 0 else 0
	ci.draw_rect(Rect2(x - 7, y - 11 + bob, 14, 11 - bob), ink)
	ci.draw_rect(Rect2(x - 6, y - 10 + bob, 12, 10 - bob), Color("#2b3a33"))
	ci.draw_rect(Rect2(x - 5, y - 16 + bob, 10, 7), ink)
	ci.draw_rect(Rect2(x - 4, y - 15 + bob, 8, 6), Color("#33463c"))
	ci.draw_rect(Rect2(x - 1, y - 12 + bob, 2, 2) if int(t * 0.7) % 7 != 0 else Rect2(x - 1, y - 11 + bob, 2, 1), zc)
	ci.draw_rect(Rect2(x + 2, y - 12 + bob, 2, 2) if int(t * 0.7) % 7 != 0 else Rect2(x + 2, y - 11 + bob, 2, 1), zc)
	var kx := 5 + (int(t * 9.0) % 3)
	ci.draw_rect(Rect2(x + 4, y - 8, kx, 2), Color("#2b3a33"))
	# a hint above it when a player stands close: [up]
	if r.player != null and absf(r.player.x + r.player.w / 2.0 - n.x) < 36.0 and absf(r.player.y + r.player.h - n.y) < 20.0:
		PixelText.draw_text(ci, "[up]", n.x + 8, y - 28, Game.COL.paper, {"align": "c", "tiny": true, "outline": Game.COL.ink})

# ---------------------------------------------------------------- a logbook page (MVB1-12): a torn yellowed sheet that flutters in place
static func draw_page(ci: CanvasItem, it: Dictionary, t: float) -> void:
	var sway := sin(t * 2.6 + float(it.ph)) * 0.18
	var bob := sin(t * 1.9 + float(it.ph)) * 1.5
	ci.draw_set_transform(Vector2(floorf(it.x), floorf(it.y + bob)), sway, Vector2.ONE)
	ci.draw_rect(Rect2(-5, -6, 10, 12), Color(Game.COL.ink))
	ci.draw_rect(Rect2(-4, -5, 8, 10), Color("#e8d9a8"))
	ci.draw_rect(Rect2(-4, -5, 8, 1), Color("#cdb87a"))
	ci.draw_rect(Rect2(-3, -5, 2, 1), Color(Game.COL.ink))                  # the torn top edge
	ci.draw_rect(Rect2(1, -5, 1, 1), Color(Game.COL.ink))
	for ly in range(3):
		ci.draw_rect(Rect2(-3, -3 + ly * 3, 6 - (ly % 2) * 2, 1), Color("#8a7a52"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- lost agents (MVB1-11)
# A glass jar with a tiny agent in it, a `…` bubble above it and a soft beep every 2 s while somebody is within 10 tiles (never sound alone).
# Breaking it is state: the flag agent:<room> is set (by a swipe or dash on the host, asked by the guest) and every page plays the burst from the flag.
static func jar_rect(j: Dictionary) -> Dictionary:
	return {"x": j.x - 6.0, "y": j.y - 16.0, "w": 12.0, "h": 16.0}

static func _step_jars(r: Room, dt: float) -> void:
	var freed := Game.flag("agent:" + r.id)
	for j in r.jars:
		if freed and not j.broken:
			j.broken = true
			var cols := ["#bfe9ff", "#e8f7ff", "#ffffff"]
			r.fx.burst(j.x, j.y - 8.0, 18, cols, 110.0, 220.0, {"glow": 1})
			r.fx.ring(j.x, j.y - 8.0, 2, 22, "#bfe9ff", 0.3)
			r.fx.pop(j.x, j.y - 24.0, "agent freed  %d/8" % Game.agents_freed(), Game.COL.okHi, true)
			j.fly = {"x": j.x, "y": j.y - 8.0, "t": 0.0}
			Audio.local_sfx("brk", 0.8)
			Audio.local_sfx("agent", 0.8)
		if j.fly != null:
			j.fly.t += dt
			j.fly.y -= (50.0 + 90.0 * j.fly.t) * dt
			j.fly.x += sin(j.fly.t * 6.0) * 20.0 * dt
			if j.fly.t > 2.5:
				j.fly = null
		if not j.broken:
			j.t += dt
			if j.t >= 2.0:
				j.t = 0.0
				if r.player != null and not r.player.dead:
					var d := _near(r, j.x, j.y - 8.0, 10.0)
					if d < 1.0:
						Audio.local_sfx("tock", 0.12 + 0.2 * (1.0 - d))

static func draw_jar(ci: CanvasItem, r: Room, j: Dictionary) -> void:
	var x := floori(j.x)
	var y := floori(j.y)
	var t: float = r.time
	if j.fly != null:
		Agent._draw_at(ci, j.fly.x, j.fly.y, t * 2.0, 9.0, [])
	if j.broken:
		return
	var bob := 1 if int(t * 2.0 + x) % 2 == 0 else 0
	# the agent inside, smaller than the helper's own look
	var tex := Gfx.tex("agent_%d" % (int(t * 4.0) % 2))
	ci.draw_texture_rect(tex, Rect2(x - 4, y - 12 + bob, tex.get_width() * 0.8, tex.get_height() * 0.8), false)
	# the glass: a pale outline, a faint fill, a dark lid and a glint
	ci.draw_rect(Rect2(x - 6, y - 15, 12, 15), Color(0.75, 0.91, 1.0, 0.16))
	ci.draw_rect(Rect2(x - 6, y - 15, 12, 1), Color(0.75, 0.91, 1.0, 0.8))
	ci.draw_rect(Rect2(x - 6, y - 1, 12, 1), Color(0.75, 0.91, 1.0, 0.8))
	ci.draw_rect(Rect2(x - 6, y - 15, 1, 15), Color(0.75, 0.91, 1.0, 0.8))
	ci.draw_rect(Rect2(x + 5, y - 15, 1, 15), Color(0.75, 0.91, 1.0, 0.8))
	ci.draw_rect(Rect2(x - 5, y - 17, 10, 2), Color("#4c4658"))
	ci.draw_rect(Rect2(x - 4, y - 13, 1, 5), Color(1, 1, 1, 0.5))
	# the bubble with `…` (it shows even when the beep cannot be heard)
	var by := y - 30 - (1 if int(t * 3.0) % 2 == 0 else 0)
	ci.draw_rect(Rect2(x - 8, by, 16, 10), Color(Game.COL.ink))
	ci.draw_rect(Rect2(x - 7, by + 1, 14, 8), Color(Game.COL.paper))
	ci.draw_rect(Rect2(x - 1, by + 10, 3, 2), Color(Game.COL.ink))
	PixelText.draw_text(ci, "…", x - 2, by + 1, Game.COL.ink, {"tiny": true})

# ---------------------------------------------------------------- decoration (MVB1-13)
# rooms.json `decor`: {kind, x, y, if?, lit?} in cells; the thing stands on the bottom of its cell. `if` decides whether it is there at all.
static func draw_decor(ci: CanvasItem, r: Room, d: Dictionary) -> void:
	if d.has("if") and not Game.cond(String(d["if"])):
		return
	var x := floori(d.x)
	var y := floori(d.y)
	var t: float = r.time
	var ink := Color(Game.COL.ink)
	match String(d.kind):
		"threads":
			# RACE CONDITION in the background: an orange and a blue streak race along the row, now and then over the same cells (a red flash)
			var x0 := float(int(d.cx) * T)
			var span := float(int(d.get("w", 20)) * T)
			var yy := float(int(d.cy) * T) + 8.0
			var ua := fposmod(t * 0.23, 1.0)
			var ub := fposmod(t * 0.23 + 0.5 * sin(t * 0.4) + 0.5, 1.0)
			var ax := x0 + ua * span
			var bx := x0 + (1.0 - ub) * span
			ci.draw_rect(Rect2(ax - 30, yy - 1, 30, 2), Color(1.0, 0.48, 0.35, 0.55))
			ci.draw_rect(Rect2(ax - 4, yy - 2, 4, 4), Color(1.0, 0.62, 0.45, 0.9))
			ci.draw_rect(Rect2(bx, yy + 5, 30, 2), Color(0.49, 0.77, 1.0, 0.55))
			ci.draw_rect(Rect2(bx, yy + 4, 4, 4), Color(0.7, 0.88, 1.0, 0.9))
			if absf(ax - bx) < 24.0:
				ci.draw_rect(Rect2((ax + bx) / 2.0 - 8, yy - 3, 16, 12), Color(1.0, 0.2, 0.25, 0.5 + 0.3 * sin(t * 30.0)))
		"coffee2":
			for k in range(2):
				var cx2 := x - 6 + k * 12
				ci.draw_rect(Rect2(cx2 - 4, y - 8, 8, 8), ink)
				ci.draw_rect(Rect2(cx2 - 3, y - 7, 6, 7), Color("#e8e0d0"))
				ci.draw_rect(Rect2(cx2 + 3, y - 6, 3, 4), ink)
				ci.draw_rect(Rect2(cx2 - 2, y - 6, 4, 2), Color("#6b4520"))
				if k == 0:                                                   # one cup still steams
					for sp in range(2):
						var sy_ := fposmod(t * 14.0 + float(sp) * 6.0, 12.0)
						ci.draw_rect(Rect2(cx2 - 2 + sp * 3 + sin(t * 3.0 + float(sp)) * 1.5, y - 10 - sy_, 1, 2), Color(1, 1, 1, 0.5 - sy_ / 24.0))
		"scrap":
			ci.draw_rect(Rect2(x - 4, y - 5, 8, 5), ink)
			ci.draw_rect(Rect2(x - 3, y - 4, 6, 3), Color(Game.COL.paper))
			ci.draw_rect(Rect2(x + 1, y - 5, 3, 2), Color("#cfc8d8"))
			PixelText.draw_text(ci, "├", x - 3, y - 4, "#3a3346", {"tiny": true})
		"bucket":
			ci.draw_rect(Rect2(x - 5, y - 8, 10, 8), ink)
			ci.draw_rect(Rect2(x - 4, y - 7, 8, 7), Color("#8d8798"))
			ci.draw_rect(Rect2(x - 4, y - 7, 8, 1), Color("#c3bccd"))
			ci.draw_rect(Rect2(x - 3, y - 4, 6, 1), Color("#6b6478"))
			ci.draw_rect(Rect2(x - 4, y - 10, 1, 3), ink)
			ci.draw_rect(Rect2(x + 3, y - 10, 1, 3), ink)
		"chair":
			ci.draw_rect(Rect2(x - 5, y - 12, 2, 7), ink)
			ci.draw_rect(Rect2(x - 5, y - 6, 10, 3), ink)
			ci.draw_rect(Rect2(x - 4, y - 11, 1, 6), Color("#4a4458"))
			ci.draw_rect(Rect2(x - 4, y - 5, 8, 1), Color("#4a4458"))
			ci.draw_rect(Rect2(x - 1, y - 3, 2, 2), ink)
			ci.draw_rect(Rect2(x - 4, y - 1, 8, 1), ink)
			ci.draw_rect(Rect2(x - 4, y - 1, 1, 1), Color("#8d8798"))
			ci.draw_rect(Rect2(x + 3, y - 1, 1, 1), Color("#8d8798"))
		"package":
			ci.draw_rect(Rect2(x - 6, y - 10, 12, 10), ink)
			ci.draw_rect(Rect2(x - 5, y - 9, 10, 9), Color("#a8794a"))
			ci.draw_rect(Rect2(x - 5, y - 9, 10, 2), Color("#c4936a"))
			ci.draw_rect(Rect2(x - 1, y - 9, 3, 9), Color("#d8c9a0"))                    # a patch of tape
			ci.draw_rect(Rect2(x - 4, y - 5, 3, 3), Color("#85592f"))                    # a handprint: a palm and two fingers
			ci.draw_rect(Rect2(x - 4, y - 6, 1, 1), Color("#85592f"))
			ci.draw_rect(Rect2(x - 2, y - 6, 1, 1), Color("#85592f"))
		"lamp":
			var lit := d.has("lit") and Game.cond(String(d.lit))
			ci.draw_rect(Rect2(x - 3, y - 2, 6, 2), ink)
			ci.draw_rect(Rect2(x - 2, y - 2, 4, 1), Color("#6b6478"))
			ci.draw_rect(Rect2(x - 1, y - 8, 2, 6), ink)
			ci.draw_rect(Rect2(x - 4, y - 12, 8, 4), ink)
			ci.draw_rect(Rect2(x - 3, y - 11, 6, 2), Color("#ff9a3a") if lit else Color("#8a5a2a"))
			if lit:                                                                       # a warm cone of light
				var flick := 0.9 + 0.1 * sin(t * 5.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, y - 9), Vector2(x + 3, y - 9), Vector2(x + 22, y + 2), Vector2(x - 22, y + 2)]), Color(1.0, 0.78, 0.4, 0.2 * flick))
				ci.draw_circle(Vector2(x, y - 9), 3.0, Color(1.0, 0.9, 0.6, 0.5))
		"drip":
			# a harmless green drop from the cell to the first solid cell below, one every 0.6 s, with a small splash
			var fall_y: float = d.get("fall_y", y + 40.0)
			var ph := fposmod(t, 0.6) / 0.6
			var top := float(y) - 8.0
			if ph < 0.85:
				var k := ph / 0.85
				var dy := top + (fall_y - top) * k * k
				ci.draw_rect(Rect2(x - 1, dy - 2, 2, 3), Color("#7fe08a"))
				ci.draw_rect(Rect2(x - 1, dy - 3, 1, 1), Color("#d6ffd0"))
			else:
				var sp := (ph - 0.85) / 0.15
				ci.draw_rect(Rect2(x - 3 - sp * 2.0, fall_y - 2 - sp * 2.0, 1, 1), Color("#7fe08a"))
				ci.draw_rect(Rect2(x + 2 + sp * 2.0, fall_y - 2 - sp * 2.0, 1, 1), Color("#7fe08a"))
				ci.draw_rect(Rect2(x - 1, fall_y - 3 - sp * 3.0, 2, 1), Color("#d6ffd0"))
			ci.draw_rect(Rect2(x - 1, top - 2, 2, 2), Color("#3fa46a"))                  # the drop forming at the edge
		"fiber":
			# a fibre line along the floor's top edge with light dots running east
			var fx0: float = float(d.cx) * 16.0
			var fw: float = float(d.get("w", 1)) * 16.0
			var fy: float = float(d.cy) * 16.0
			ci.draw_rect(Rect2(fx0, fy, fw, 1), Color("#5ad1ff"))
			for k in range(int(fw / 48.0) + 1):
				var dx := fposmod(t * 80.0 + float(k) * 48.0, fw)
				ci.draw_rect(Rect2(fx0 + dx, fy - 1, 2, 2), Color("#d6f6ff"))
		"window":
			var wx: float = float(d.cx) * 16.0
			var wy: float = float(d.cy) * 16.0
			var ww: float = float(d.get("w", 1)) * 16.0
			var wh: float = float(d.get("h", 1)) * 16.0
			ci.draw_rect(Rect2(wx, wy, ww, wh), Color("#0b0f24"))
			if String(d.get("shadow", "")) == "firewall":
				if not Game.flag("boss:FIREWALL"):
					var sx: float = sin(t * 0.7) * 12.0
					ci.draw_rect(Rect2(wx + ww / 2.0 - 11.0 + sx, wy + 4, 22, wh - 8), Color(0.35, 0.08, 0.15, 0.55))
					ci.draw_rect(Rect2(wx + ww / 2.0 + 4.0 + sx, wy + 6, 4, wh - 12), Color(0.6, 0.15, 0.25, 0.6))
				else:
					PixelText.draw_text(ci, "200", wx + ww / 2.0, wy + wh / 2.0 - 4.0, "#2f6a3c", {"align": "c"})
			ci.draw_rect(Rect2(wx, wy, ww, 1), Color("#3a4a9a"))
			ci.draw_rect(Rect2(wx, wy + wh - 1, ww, 1), Color("#3a4a9a"))
			ci.draw_rect(Rect2(wx, wy, 1, wh), Color("#3a4a9a"))
			ci.draw_rect(Rect2(wx + ww - 1, wy, 1, wh), Color("#3a4a9a"))
		"contributors":
			var n := Game.agents_freed()
			if n >= 1:
				PixelText.draw_text(ci, "contributors: %d/8" % n, x, y - 4, Game.COL.paper, {"align": "c", "tiny": true, "outline": Game.COL.ink})
				# the freed agents wait around R08's bench, left and right of it
				var bx := float(r.cps[0].x) if not r.cps.is_empty() else float(x)
				var by := float(r.cps[0].y) if not r.cps.is_empty() else float(y + 40)
				for i in range(mini(n, 8)):
					var side := -1.0 if i % 2 == 0 else 1.0
					var step := float(i / 2)
					var ax := bx + side * (16.0 + step * 11.0)
					var ay := by - 10.0 - float(int(step) % 2) * 5.0 + sin(t * 2.0 + float(i)) * 1.5
					Agent._draw_at(ci, ax, ay, t * 2.0 + float(i), 9.0, [])

# ---------------------------------------------------------------- THE NETWORK (MVB2-05)
# a web strand: a 1-px line through the cell, joined to its neighbours, with a light dot running along it
static func draw_webs(r: Room, ci: CanvasItem) -> void:
	if r.webs.is_empty():
		return
	var cam_x: float = r.cam.x
	var cam_y: float = r.cam.y
	var lc := Color(0.49, 0.77, 1.0, 0.8)
	for wc in r.webs:
		var tx: int = wc[0]
		var ty: int = wc[1]
		if tx * 16 < cam_x - 16 or tx * 16 > cam_x + 400 or ty * 16 < cam_y - 16 or ty * 16 > cam_y + 232:
			continue
		if r.grid.tile(tx, ty) != TileGrid.WEB:
			continue                                              # (turned into air by boss:CRAWLER)
		var cxp := tx * 16 + 8
		var cyp := ty * 16 + 8
		var horiz: bool = r.grid.tile(tx - 1, ty) == TileGrid.WEB or r.grid.tile(tx + 1, ty) == TileGrid.WEB
		var vert: bool = r.grid.tile(tx, ty - 1) == TileGrid.WEB or r.grid.tile(tx, ty + 1) == TileGrid.WEB
		if horiz or not vert:
			ci.draw_rect(Rect2(tx * 16, cyp, 16, 1), lc)
		if vert or not horiz:
			ci.draw_rect(Rect2(cxp, ty * 16, 1, 16), lc)
		var u := fposmod(r.time * 1.3 + float(tx * 3 + ty), 1.0)
		ci.draw_rect(Rect2(tx * 16 + floorf(u * 15.0) if horiz or not vert else cxp - 1, cyp - 1 if horiz or not vert else ty * 16 + floorf(u * 15.0), 2, 2), Color("#d6f6ff"))

# a lever: a stick on a base, tilted left when off and right when on
static func draw_levers(r: Room, ci: CanvasItem) -> void:
	for lv in r.levers:
		var on := Game.flag(r.lever_flag(int(lv.i)))
		var bx: int = int(lv.x) + 8
		var by: int = int(lv.y) + 16
		ci.draw_rect(Rect2(bx - 6, by - 3, 12, 3), Color(Game.COL.ink))
		ci.draw_rect(Rect2(bx - 5, by - 3, 10, 2), Color("#6b6478"))
		var tip := Vector2(bx + (6 if on else -6), by - 12)
		ci.draw_line(Vector2(bx, by - 3), tip, Color(Game.COL.ink), 3.0)
		ci.draw_line(Vector2(bx, by - 3), tip, Color("#c3bccd"), 1.0)
		ci.draw_circle(tip, 2.5, Color(Game.COL.ink))
		ci.draw_circle(tip, 1.5, Color("#7fd08a") if on else Color("#ff4f6d"))

# a dark spider silhouette (the crawler passing in N08, 60 % alpha, no collision): an old monitor and eight red LEDs, as in its hall
static func draw_spider(ci: CanvasItem, x: float, y: float, a: float, t: float) -> void:
	var col := Color(0.04, 0.05, 0.12, a)
	ci.draw_rect(Rect2(x - 12, y - 8, 24, 16), col)
	for i in range(4):
		var ph := sin(t * 14.0 + float(i) * 1.6) * 3.0
		ci.draw_line(Vector2(x - 10 + i * 4, y + 4), Vector2(x - 18 + i * 8 - 4, y + 14 + ph), col, 2.0)
		ci.draw_line(Vector2(x + 10 - i * 4, y + 4), Vector2(x + 18 - i * 8 + 4, y + 14 - ph), col, 2.0)
	ci.draw_rect(Rect2(x - 7, y - 6, 14, 9), Color(0.55, 0.85, 0.65, a * 0.35))    # its old monitor, a faint green square in the dark
	for i in range(8):                                                     # eight red LEDs at its feet: what is seen again in the hall
		var side := -1.0 if i < 4 else 1.0
		var k := float(i % 4)
		var ph2 := sin(t * 14.0 + k * 1.6) * 3.0 * side
		ci.draw_rect(Rect2(x + side * (10.0 + k * 4.0) - 1.0, y + 13.0 + ph2, 2, 2), Color(1.0, 0.22, 0.28, minf(1.0, a * 1.6)))

# ---------------------------------------------------------------- the furniture layer
static func draw(r: Room, ci: CanvasItem) -> void:
	draw_webs(r, ci)
	draw_levers(r, ci)
	if r.sight_t >= 0.0:
		var u: float = r.sight_t / 3.0
		draw_spider(ci, -40.0 + (float(r.pw) + 80.0) * u, 24.0, 0.6, r.time)
	for d in r.decor_items:
		draw_decor(ci, r, d)
	for n in r.npcs:
		draw_tree(ci, r, n)
	for j in r.jars:
		draw_jar(ci, r, j)
