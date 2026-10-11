class_name MergeBoss
extends Boss
# MERGE CONFLICT v2 (D05). Two heads (`<<<<<<< HEAD` and `>>>>>>> theirs`) fight over one file. Port of `class Merge` (js/bosses.js) with the
# phase 3 changes: conflict markers (three bands across the arena, one of the two lower ones is "resolved" = safe) replace the double slam,
# `git revert in 8` brings a dead head back with half its hp unless the other falls in time, slam contact is big, and with two players
# head 0 aims at P1, head 1 at P2. Telegraphs times telegraph_mult. Everything a guest's combat reads is in net_fields().

const W := 384.0
const HEAD_NAMES := ["<<<<<<< HEAD", ">>>>>>> theirs"]
const MAIN := ["#4ec9b0", "#e05a8a"]
const LO := ["#23806e", "#8c2356"]
const HI := ["#b5f5e6", "#ffc2d8"]
const GLYPH := ["<", ">"]
const ST := ["rest", "lunge", "spit", "slam", "dead", "markers"]
const BANDS := [[48.0, 48.0], [96.0, 48.0], [144.0, 32.0]]       # H, M, L: top and height
const BAND_TEXT := ["<<<<<<<", "=======", ">>>>>>>"]
const REVERT := 8.0

var heads: Array = []
var cycle := 0
var busy := 0.0
var alone = null                  # the head left when the other died
var band_state := 0               # 0 none, 1 rise, 2 telegraph, 3 fire
var band_t := 0.0
var safe_band := 2                # 1 = M, 2 = L (H, 0, is never safe)
var last = null
var hsamp := [[], []]              # guest: per head [[tm, x, y], ...] from the snapshots, followed like any creature's position

func _init(r: Room, bx: float, by: float, base_hp := 90) -> void:
	super(r, W / 2.0, 120.0, 20, 20, base_hp)
	boss_name = "MERGE CONFLICT"
	sub = "both modified: everything"
	col = "#f4ede0"
	var each := ceili(float(base_hp) / 2.0)
	for i in range(2):
		heads.append({"i": i, "side": 1.0 if i == 1 else -1.0, "ax": W - 16.0 if i == 1 else 16.0, "ay": 76.0, "x": W - 70.0 if i == 1 else 70.0, "y": 92.0,
			"rx": W - 78.0 if i == 1 else 78.0, "ry": 96.0, "hp": float(each), "max": each, "st": "rest", "t": 0.0, "open": 0, "flash": 0.0, "dead": false,
			"vy": 0.0, "aim": Vector2.ZERO, "n": 0, "t2": 0.0, "launched": false, "rv": -1.0})
	_sums()

func _tm() -> float:
	return float(Game.dv("telegraph_mult"))

func _sums() -> void:
	var tot := 0.0
	var mx := 0
	for h in heads:
		tot += maxf(0.0, h.hp)
		mx += int(h.max)
	hpf = tot
	hp = ceili(tot)
	max_hp = mx

func scale_hp(k: float) -> void:
	for h in heads:
		h.max = roundi(h.max * k)
		h.hp = float(h.max)
	_sums()

func alive() -> Array:
	return heads.filter(func(h): return not h.dead)

# ---- boxes: a head is hit where its sprite is; bodies, lunges and slams hurt on contact; so do the active bands ----
func hurtboxes() -> Array:
	var b: Array = []
	for h in heads:
		if not h.dead:
			b.append({"x": h.x - 14.0, "y": h.y - 12.0, "w": 28.0, "h": 24.0, "head": h.i})
	return b

func harmboxes() -> Array:
	var b: Array = []
	for h in heads:
		if not h.dead:
			b.append({"x": h.x - 11.0, "y": h.y - 9.0, "w": 22.0, "h": 18.0})
	if band_state == 3:
		var al := alive().size()
		for i in range(3):
			if i == safe_band:
				continue
			var off := 0.0
			if al < 2:
				off = [0.5, 0.25, 0.0][i]                 # one head left: L, M, H one after another
			if band_t >= off and band_t < off + 0.35:
				b.append({"x": 0.0, "y": BANDS[i][0], "w": W, "h": BANDS[i][1]})
	return b

func _head_for(box):
	if box is Dictionary and box.has("head"):
		return heads[int(box.head)]
	var best = null
	var bd := 1e9
	if box != null and box is Dictionary:
		var bcx: float = box.x + box.w / 2.0
		var bcy: float = box.y + box.h / 2.0
		for h in heads:
			if h.dead:
				continue
			var d := Vector2(h.x - bcx, h.y - bcy).length()
			if d < bd:
				bd = d
				best = h
	if best != null and bd < 30.0:
		return best
	var more = null
	for h in heads:                                    # a box that is no head: the head with more hp takes it
		if not h.dead and (more == null or h.hp > more.hp):
			more = h
	return more

func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	var h = _head_for(box)
	if h == null:
		return ""
	var dm := float(d)
	if how == "agent" or how == "dash":
		dm *= 0.5
	h.hp -= dm
	h.flash = 0.1
	_sums()
	room.burst(h.x, h.y, 6, [MAIN[h.i], "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	room.boss_damage(self, dm, how)
	if h.hp <= 0.0:
		h.hp = 0.0
		h.dead = true
		h.st = "dead"
		h.vy = -120.0
		h.rv = REVERT
		_sums()
		room.explode(h.x, h.y, 22.0, ["#ffffff", HI[h.i], MAIN[h.i]])
		room.shake(0.7)
		room.stop(0.2)
		Audio.sfx("explode")
		var other: Dictionary = heads[1 - h.i]
		if other.dead:
			last = h
			band_state = 0
			begin_death()
			return "kill"
		phase = 2
		alone = other
		room.events.append("bossPhase")
		busy = 1.6
		if band_state != 0:
			band_state = 0
			other.st = "rest"
		return "kill"
	return "hit"

func begin_death() -> void:
	super.begin_death()
	for h in heads:
		h.rv = -1.0
		h.st = "dead"

func act(h: Dictionary, kind: String) -> void:
	h.st = kind
	h.t = 0.0
	h.n = 0
	if kind == "lunge":
		Audio.sfx("warn")
	elif kind == "spit":
		Audio.sfx("charge", {"vol": 0.5})

# who a head aims at: head 0 at P1, head 1 at P2 when both are here; a lone head takes turns (as NULL)
func target_of(h: Dictionary):
	var ps: Array = room.players()
	if ps.is_empty():
		return room.player
	if ps.size() >= 2 and alive().size() == 2:
		return ps[mini(int(h.i), ps.size() - 1)]
	return pick_target()

func update(dt: float) -> void:
	tick(dt)
	var rage := phase == 2
	if dying:
		die_t += dt
		if room.rng.randf() < 0.3:
			var h0: Dictionary = heads[room.rng.randi() % 2]
			room.explode(h0.x + room.rng.randf_range(-14, 14), h0.y + room.rng.randf_range(-10, 10), room.rng.randf_range(8, 14), ["#ffffff", MAIN[0], MAIN[1]])
			Audio.sfx("explode", {"vol": 0.5})
		if die_t > 2.2 and not gone:
			gone = true
			dead = true
			room.flash_screen(1.0)
			room.shake(1.0)
			Audio.sfx("bigExplode")
			for h in heads:
				room.explode(h.x, h.y, 34.0, ["#ffffff", HI[h.i], MAIN[h.i]])
			room.drop(W / 2.0, 100.0, drop_n)
			room.events.append("bossDead")
		for h in heads:
			h.vy += 500.0 * dt
			h.y = minf(FLOOR - 10.0, h.y + h.vy * dt)
		return
	dmg = 1
	for h in heads:
		if h.flash > 0.0:
			h.flash -= dt
		h.t += dt
		var bob := sin(t * 2.0 + h.i * 2.0) * 7.0
		if h.dead:
			h.vy += 500.0 * dt
			h.y = minf(FLOOR - 10.0, h.y + h.vy * dt)
			if h.rv >= 0.0 and active:
				h.rv -= dt
				if h.rv <= 0.0:
					_revert(h)
			continue
		if not active or h.st == "rest":
			h.x = Game.damp(h.x, h.rx, 3.0, dt)
			h.y = Game.damp(h.y, h.ry + bob, 3.0, dt)
			h.open = 0
			continue
		var tg = target_of(h)
		var ap := aim_point(tg) if tg != null else Vector2(W / 2.0, 150.0)
		match h.st:
			"lunge":
				var tele := (0.5 if rage else 0.75) * _tm()
				if h.t < tele:                                   # pull back, open wide, lock on
					h.x = Game.damp(h.x, h.ax - h.side * 34.0, 6.0, dt)
					h.y = Game.damp(h.y, 70.0, 6.0, dt)
					h.open = 1
					if h.t < tele - 0.18:
						h.aim = Vector2(clampf(ap.x, 30.0, W - 30.0), clampf(ap.y, 40.0, FLOOR - 10.0))
				elif h.n == 0:
					var dx: float = h.aim.x - h.x
					var dy: float = h.aim.y - h.y
					var d := sqrt(dx * dx + dy * dy)
					if d == 0.0:
						d = 1.0
					if not h.launched:
						h.launched = true
						Audio.sfx("dash")
					var sp := 460.0 * dt
					if d <= sp:
						h.x = h.aim.x
						h.y = h.aim.y
						h.n = 1
						h.t2 = 1.0 if rage else 1.4
						h.launched = false
						room.shake(0.35)
						Audio.sfx("thud")
						if h.y > FLOOR - 24.0:
							room.dust(h.x, FLOOR, 8)
					else:
						h.x += dx / d * sp
						h.y += dy / d * sp
				else:
					h.open = 0
					h.t2 -= dt
					if h.t2 <= 0.0:
						h.st = "rest"
			"spit":
				h.x = Game.damp(h.x, h.rx, 4.0, dt)
				h.y = Game.damp(h.y, 58.0, 4.0, dt)
				h.open = 1 if h.t > 0.35 else 0
				if h.t > 0.6 and h.n == 0:
					h.n = 1
					var count := 7 if rage else 5
					for i in range(count):
						var u := float(i) / float(count - 1)
						var plus := i % 2 == 0
						room.shoot(h.x - h.side * 12.0, h.y + 4.0, -h.side * lerpf(40.0, 250.0, u) + room.rng.randf_range(-10, 10), lerpf(-210.0, -90.0, u),
							{"kind": "plus" if plus else "minus", "col": "#7fd08a" if plus else "#ff5d5d", "g": 330.0, "r": 3.0})
					Audio.sfx("shoot")
				if h.t > 1.2:
					h.st = "rest"
			"slam":
				var tx: float = h.rx - h.side * 8.0
				if h.t < 0.7:
					h.x = Game.damp(h.x, tx, 5.0, dt)
					h.y = Game.damp(h.y, 44.0, 5.0, dt)
					h.open = 1
				elif h.n == 0:
					h.y += 520.0 * dt
					if h.y >= FLOOR - 11.0:
						h.y = FLOOR - 11.0
						h.n = 1
						h.t2 = 1.0 if rage else 1.5
						room.shake(0.6)
						Audio.sfx("thud")
						room.dust(h.x, FLOOR, 10)
						for dd in [-1.0, 1.0]:
							room.shoot(h.x + dd * 12.0, FLOOR - 1.0, dd * 150.0, 0.0, {"kind": "wave", "col": MAIN[h.i], "r": 4.0, "hgt": 11.0, "tile": false, "life": 2.2, "cut": false})
				else:
					h.open = 0
					h.t2 -= dt
					if h.t2 <= 0.0:
						h.st = "rest"
			"markers":
				h.x = Game.damp(h.x, 30.0 if h.i == 0 else W - 30.0, 8.0, dt)
				h.y = Game.damp(h.y, 44.0, 8.0, dt)
				h.open = 1 if band_state >= 2 else 0
		if h.st == "slam" and h.t >= 0.7:
			dmg = int(Game.dv("big_hit"))
	if not active:
		return
	if band_state > 0:
		_step_bands(dt)
	# conductor
	busy -= dt
	var al := alive()
	var all_rest := true
	for h in al:
		if h.st != "rest":
			all_rest = false
	if busy <= 0.0 and all_rest and band_state == 0 and not al.is_empty():
		var step := cycle
		cycle += 1
		if al.size() == 2:
			var a: Dictionary = heads[0 if step % 2 == 0 else 1]
			var k := step % 5
			if k == 0 or k == 2:
				act(a, "lunge")
				busy = 0.9
			elif k == 1 or k == 3:
				act(a, "spit")
				busy = 0.6
			else:
				_start_markers()
		else:
			var h1: Dictionary = al[0]
			var k2 := step % 5
			if k2 == 4:
				_start_markers()
			else:
				act(h1, ["lunge", "spit", "lunge", "slam"][k2])
				busy = 0.5

func _start_markers() -> void:
	for h in alive():
		act(h, "markers")
	band_state = 1
	band_t = 0.0
	safe_band = 1 + room.rng.randi() % 2
	Audio.sfx("warn")

func _step_bands(dt: float) -> void:
	band_t += dt
	match band_state:
		1:
			if band_t >= 0.6:
				band_state = 2
				band_t = 0.0
				Audio.sfx("charge", {"vol": 0.6})
		2:
			if band_t >= 1.0 * _tm():
				band_state = 3
				band_t = 0.0
				room.shake(0.4)
				Audio.sfx("laser")
		3:
			var dur := 0.35 if alive().size() == 2 else 0.85
			if band_t >= dur:
				band_state = 0
				band_t = 0.0
				for h in alive():
					h.st = "rest"
				busy = 0.8

func _revert(h: Dictionary) -> void:
	h.dead = false
	h.hp = ceilf(float(h.max) / 2.0)
	h.st = "rest"
	h.rv = -1.0
	h.vy = 0.0
	h.y = h.ry
	h.x = h.rx
	phase = 1
	alone = null
	_sums()
	room.pop(h.x, h.y - 20.0, "git revert", "#ffd97a", true)
	room.burst(h.x, h.y, 14, [MAIN[h.i], "#ffffff"], 130.0, 100.0, {"glow": 1})
	Audio.sfx("glitch")
	room.shake(0.4)
	busy = 1.0

# ---- drawing ----
func _tex(h: Dictionary) -> Texture2D:
	if h.dead:
		return Gfx.tex("merge_dead_%d" % h.i)
	return Gfx.tex("merge_head_%d_%d" % [h.i, h.open])

func draw_boss_body(ci: CanvasItem) -> void:
	for h in heads:
		# the file they are fighting over: a curve of glyphs from the corner to the head
		var n := 11
		var mx: float = (h.ax + h.x) / 2.0
		var my: float = maxf(h.ay, h.y) + (6.0 if h.dead else 16.0)
		for i in range(n + 1):
			var u := float(i) / n
			var gx: float = (1 - u) * (1 - u) * h.ax + 2 * u * (1 - u) * mx + u * u * h.x
			var gy: float = (1 - u) * (1 - u) * h.ay + 2 * u * (1 - u) * my + u * u * h.y
			var gc: String = "#4a4458" if h.dead else (MAIN[h.i] if i % 2 == 1 else LO[h.i])
			PixelText.draw_text(ci, GLYPH[h.i], floori(gx + 0.5) - 3, floori(gy + 0.5) - 9, gc, {"outline": Game.COL.ink, "scale": 2})
		if dying and int(t * 30.0) % 3 == 0:
			continue
		var jit := roundi(sin(t * 50.0)) if phase == 2 and not h.dead else 0
		ci.draw_set_transform(Vector2(floori(h.x + 0.5) + jit, floori(h.y + 0.5)), 0.0, Vector2(-1.0 if h.side > 0 else 1.0, 1.0))
		ci.draw_texture(_tex(h), Vector2(-16, -15), Color(2, 2, 2, 1) if h.flash > 0.0 else Color.WHITE)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_boss_overlay(ci: CanvasItem) -> void:
	for h in heads:
		if h.st == "lunge" and h.n == 0 and h.t < 0.8 and not h.dead:        # where it will land
			var i := 0.0
			while i < 1.0:
				var px := lerpf(h.x, h.aim.x, i)
				var py := lerpf(h.y, h.aim.y, i)
				ci.draw_rect(Rect2(floori(px + 0.5), floori(py + 0.5), 2, 2), Color(Game.COL.hazard) if int(i * 16.0 + t * 20.0) % 2 == 1 else Color(Game.COL.hazardHi))
				i += 0.06
			Fx._disc(ci, h.aim.x, h.aim.y, 3.0 + sin(t * 20.0), Color(Game.COL.hazard))
		if h.dead and h.rv > 0.0 and not dying:                               # the countdown over the dead head
			PixelText.draw_text(ci, "git revert in %d" % ceili(h.rv), floori(h.x) - 30, floori(h.y) - 24, "#ffd97a", {"tiny": true, "outline": Game.COL.ink})
	if band_state >= 2:
		for i in range(3):
			var top: float = BANDS[i][0]
			var hgt: float = BANDS[i][1]
			var safe: bool = i == safe_band
			var firing := band_state == 3
			var col := Color("#7fd08a") if safe else (Color(Game.COL.hazard) if int(t * 14.0) % 2 == 1 else Color(Game.COL.hazardHi))
			if firing and not safe:
				var fire: bool = false
				for b in harmboxes():
					if b.w == W and b.y == top:
						fire = true
				if fire:
					ci.draw_rect(Rect2(0, top, W, hgt), Color(col.r, col.g, col.b, 0.55))
			var xx := 0
			while xx < int(W):
				ci.draw_rect(Rect2(xx, top, 6, 1), col)
				ci.draw_rect(Rect2(xx, top + hgt - 1, 6, 1), col)
				xx += 10
			var text: String = BAND_TEXT[i] if not safe else "resolved"
			PixelText.draw_text(ci, text, 8, top + hgt / 2.0 - 3.0, "#d6ffd0" if safe else Game.COL.hazardHi, {"outline": Game.COL.ink})
			PixelText.draw_text(ci, text, W - 8, top + hgt / 2.0 - 3.0, "#d6ffd0" if safe else Game.COL.hazardHi, {"outline": Game.COL.ink, "align": "r"})
			if safe:
				ci.draw_rect(Rect2(W / 2.0 - 6, top + hgt / 2.0 - 1, 3, 2), Color("#7fd08a"))      # a check mark
				ci.draw_rect(Rect2(W / 2.0 - 3, top + hgt / 2.0 + 1, 3, 2), Color("#7fd08a"))
				ci.draw_rect(Rect2(W / 2.0, top + hgt / 2.0 - 3, 3, 4), Color("#7fd08a"))

# ---- net ----
func net_fields() -> Array:
	var hs: Array = []
	for h in heads:
		hs.append([roundi(h.x * 4.0), roundi(h.y * 4.0), roundi(h.hp * 10.0), ST.find(h.st), roundi(h.t * 100.0), h.open, 1 if h.dead else 0, roundi(h.rv * 10.0), roundi(h.aim.x * 4.0), roundi(h.aim.y * 4.0), h.n, h.max])
	return [hs, [band_state, safe_band, roundi(band_t * 100.0)], phase, 1 if active else 0, 1 if dying else 0]

func net_apply(f: Array) -> void:
	for i in range(2):
		var r: Array = f[0][i]
		var h: Dictionary = heads[i]
		var was_dead: bool = h.dead
		h.x = r[0] / 4.0
		h.y = r[1] / 4.0
		h.hp = r[2] / 10.0
		h.st = ST[clampi(int(r[3]), 0, ST.size() - 1)]
		h.t = r[4] / 100.0
		h.open = int(r[5])
		h.dead = int(r[6]) == 1
		h.rv = r[7] / 10.0
		h.aim = Vector2(r[8] / 4.0, r[9] / 4.0)
		h.n = int(r[10])
		h.max = int(r[11])
		if was_dead and not h.dead:
			hsamp[i].clear()
			room.pop(h.x, h.y - 20.0, "git revert", "#ffd97a", true)
			Audio.sfx("glitch")
	band_state = int(f[1][0])
	safe_band = int(f[1][1])
	band_t = f[1][2] / 100.0
	phase = int(f[2])
	active = int(f[3]) == 1
	dying = int(f[4]) == 1
	passive = not active or dying
	_sums()
	dmg = 1
	for h in heads:
		if h.st == "slam" and h.t >= 0.7 and not h.dead:
			dmg = int(Game.dv("big_hit"))

# guest: the snapshot that was just applied, at host time tm (Coop._apply_snapshot)
func net_sample(tm: float) -> void:
	for i in range(2):
		var s: Array = hsamp[i]
		s.append([tm, heads[i].x, heads[i].y])
		while s.size() > 8:
			s.pop_front()

# guest: put each head where it was at render time rt, as Coop._puppet_follow does for whole creatures (a dead head falls: no guessing ahead)
func puppet_follow_parts(rt: float) -> void:
	for i in range(2):
		var s: Array = hsamp[i]
		if s.is_empty():
			continue
		var h: Dictionary = heads[i]
		var last: Array = s[s.size() - 1]
		if rt >= last[0]:
			var vx := 0.0
			var vy := 0.0
			if s.size() >= 2 and not h.dead:
				var prev: Array = s[s.size() - 2]
				var dt_: float = maxf(0.0001, last[0] - prev[0])
				vx = (last[1] - prev[1]) / dt_
				vy = (last[2] - prev[2]) / dt_
			var ex := minf(rt - last[0], 0.1)
			h.x = last[1] + vx * ex
			h.y = last[2] + vy * ex
			continue
		var done := false
		for k in range(s.size() - 1):
			if s[k][0] <= rt and rt <= s[k + 1][0]:
				var u: float = (rt - s[k][0]) / maxf(0.0001, s[k + 1][0] - s[k][0])
				h.x = lerpf(s[k][1], s[k + 1][1], u)
				h.y = lerpf(s[k][2], s[k + 1][2], u)
				done = true
				break
		if not done:
			h.x = s[0][1]
			h.y = s[0][2]
