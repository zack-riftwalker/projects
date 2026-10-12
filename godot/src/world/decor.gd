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

# ---------------------------------------------------------------- the furniture layer
static func draw(r: Room, ci: CanvasItem) -> void:
	for n in r.npcs:
		draw_tree(ci, r, n)
