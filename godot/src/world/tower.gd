class_name Tower
extends RefCounted
# Tower: the machines of THREAD TOWER (world 4): gears, pistons, mutex gates, spaghetti cables and the blink blocks that follow the tick.
# Everything that moves is a pure function of the room clock minus a per-object offset (breakpoint freezes an object by letting its
# offset grow), so a host and a guest with the same clock and the same offsets show the same machine. The guest never simulates
# these: it runs the same functions on the clock it got from the host (`rt`) and the offsets/keys from the snapshot (`tw`).

const T := 16
const TICK := 0.8333                 # s: two beats of the w4 song at 144 bpm
const MUTEX_T := 3.5                 # s a key keeps its gates open

var room                              # Room
var gears: Array = []                 # {x, y, r, n, decor, px, py (centre, px), plats: [platform dicts], key}
var pistons: Array = []               # {x, y, len, w, ticks, busy, key, phase, rows (solid rows now), cells: [[tx, ty, j]]}
var mutex: Array = []                 # {i, rect, rows, cells: [idx], t (s left), pred, last_atk, last_ev}
var cables: Array = []                # {cells: [[tx, ty]], cut}
var bgroups: Array = []               # blink groups: {key, cells: [[tx, ty]], ph}
var offs := {}                        # object key -> seconds its clock is behind the room's (breakpoint)
var fz := {}                          # object key -> seconds it stays frozen
var fz_mt := {}                       # guest: object key -> the clock the host froze it at (kept exactly: the guest's own clock may be a little off)
var has_blink := false
var flag_t := 0.0

func _init(r) -> void:
	room = r

static func tick_i_of(tm: float) -> int:
	return floori(tm / TICK)

static func tick_f_of(tm: float) -> float:
	return fposmod(tm, TICK) / TICK

static func ease_tick(f: float) -> float:
	return smoothstep(0.0, 0.3, f)

func mt(key: String) -> float:
	return maxf(0.0, room.time - float(offs.get(key, 0.0)))

# ---------------------------------------------------------------- loading
func load_all() -> void:
	var def: Dictionary = room.def
	var rows: PackedStringArray = room.rows
	for gi in range(def.get("gears", []).size()):
		var gd: Dictionary = def.gears[gi]
		var g := {"x": int(gd.x), "y": int(gd.y), "r": float(gd.r), "n": int(gd.n), "decor": bool(gd.get("decor", false)),
			"px": float(int(gd.x) * T + 8), "py": float(int(gd.y) * T + 8), "plats": [], "key": "g%d" % gi}
		for j in range(g.n):
			var pos := gear_pos(g, j, 0.0)
			var pl := {"x": pos.x - 24.0, "y": pos.y - 3.0, "w": 48.0, "h": 6.0, "ax": false, "a": 0, "b": 0, "ph": 0.0, "dx": 0.0, "dy": 0.0, "speed": 0.0, "gear": gi, "j": j}
			room.plats.append(pl)
			g.plats.append(pl)
		gears.append(g)
	for pi in range(def.get("pistons", []).size()):
		var pd: Dictionary = def.pistons[pi]
		var px := int(pd.x)
		var py := int(pd.y)
		var pw := int(pd.get("w", 1))
		var pz := {"x": px, "y": py, "len": int(pd.len), "w": pw, "ticks": pd.ticks, "busy": bool(pd.get("busy", false)), "key": "p%d" % pi,
			"phase": fposmod(float(px) * 0.37 + float(py) * 0.61, 1.0), "rows": 0, "cells": []}
		for i in range(pw):                                # (the `A` casing itself is not solid: the checker's routes pass through the shaft under it)
			if py >= rows.size() or px + i >= rows[py].length() or rows[py][px + i] != "A":
				push_error("room %s: piston %d has no `A` housing at %d,%d" % [room.id, pi, px + i, py])
			for j in range(pz.len):
				var ty := py + 1 + j
				if ty < room.h:
					room.grid.tiles[ty * room.w + px + i] = TileGrid.PHEAD
					pz.cells.append([px + i, ty, j])
		pistons.append(pz)
	for mi in range(def.get("mutex", []).size()):
		var md: Dictionary = def.mutex[mi]
		var m := {"i": mi, "rect": {"x": float(int(md.key[0]) * T), "y": float(int(md.key[1]) * T), "w": 16.0, "h": 16.0}, "rows": md.rows,
			"cells": [], "t": 0.0, "pred": -1.0, "last_atk": -1, "was": false}
		for ty in md.rows:
			for tx in range(room.w):
				if room.grid.tile(tx, int(ty)) == TileGrid.MGATE:
					m.cells.append(int(ty) * room.w + tx)
		mutex.append(m)
	_find_cables()
	if room.world == 4:
		_find_blinks()                               # (other worlds keep the old 1.5 s blink)
	for fk in Game.flags:                              # cables cut earlier stay cut
		var fks := String(fk)
		if fks.begins_with("cable:%s:" % room.id) and Game.flag(fks):
			var parts := fks.split(":")
			cut_at(int(parts[2]), int(parts[3]), true)

func _find_cables() -> void:
	var seen := {}
	for ty in range(room.h):
		for tx in range(room.w):
			if room.grid.tile(tx, ty) != TileGrid.CABLE or seen.has(ty * room.w + tx):
				continue
			var grp := {"cells": [], "cut": false}
			var q: Array = [[tx, ty]]
			seen[ty * room.w + tx] = true
			while not q.is_empty():
				var c: Array = q.pop_back()
				grp.cells.append(c)
				for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = c[0] + o[0]
					var ny: int = c[1] + o[1]
					if nx < 0 or ny < 0 or nx >= room.w or ny >= room.h or seen.has(ny * room.w + nx):
						continue
					if room.grid.tile(nx, ny) == TileGrid.CABLE:
						seen[ny * room.w + nx] = true
						q.append([nx, ny])
			cables.append(grp)

func _find_blinks() -> void:
	var seen := {}
	for ty in range(room.h):
		for tx in range(room.w):
			var t: int = room.grid.tile(tx, ty)
			if (t != TileGrid.BLINK_A and t != TileGrid.BLINK_B) or seen.has(ty * room.w + tx):
				continue
			var grp := {"key": "b%d" % bgroups.size(), "cells": [], "ph": -1}
			var q: Array = [[tx, ty]]
			seen[ty * room.w + tx] = true
			while not q.is_empty():
				var c: Array = q.pop_back()
				grp.cells.append(c)
				for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = c[0] + o[0]
					var ny: int = c[1] + o[1]
					if nx < 0 or ny < 0 or nx >= room.w or ny >= room.h or seen.has(ny * room.w + nx):
						continue
					var nt: int = room.grid.tile(nx, ny)
					if nt == TileGrid.BLINK_A or nt == TileGrid.BLINK_B:
						seen[ny * room.w + nx] = true
						q.append([nx, ny])
			bgroups.append(grp)
	has_blink = not bgroups.is_empty()

# ---------------------------------------------------------------- pure functions of the clock
# platform j of a gear at room time tm: 45 degrees per tick, moving in the first 0.3 of the tick and holding after
func gear_pos(g: Dictionary, j: int, tm: float) -> Vector2:
	var ang := deg_to_rad((float(tick_i_of(tm)) + ease_tick(tick_f_of(tm))) * 45.0 + float(j) * 360.0 / float(g.n))
	return Vector2(g.px + cos(ang) * g.r * float(T), g.py + sin(ang) * g.r * float(T))

# how many cells under the housing the piston covers at time tm (tile-quantised: a cell is covered the moment the head enters it,
# so the way is clear only while the piston waits)
func piston_rows_at(pz: Dictionary, tm: float) -> int:
	var tk: Array = pz.ticks
	var d0: float = float(tk[0]) * TICK
	var d1: float = float(tk[1]) * TICK
	var d2: float = float(tk[2]) * TICK
	var d3: float = float(tk[3]) * TICK
	var total := d0 + d1 + d2 + d3
	if total <= 0.0:
		return 0
	var u := fposmod(tm + float(pz.phase) * total, total)
	var ext := 0.0
	if u < d0:
		ext = u / d0
	elif u < d0 + d1:
		ext = 1.0
	elif u < d0 + d1 + d2:
		ext = 1.0 - (u - d0 - d1) / d2
	return clampi(ceili(ext * float(pz.len) - 0.0001), 0, int(pz.len))

func blink_phase_of(key: String) -> int:
	return floori(mt(key) / TICK) % 2

# ---------------------------------------------------------------- per step (host, solo and guest)
func step(dt: float, live: Array) -> void:
	for k in fz.keys():
		if fz_mt.has(k) and room.mode == "guest":
			offs[k] = room.time - float(fz_mt[k])          # frozen: its clock is the host's, whatever this page's clock says
		else:
			offs[k] = float(offs.get(k, 0.0)) + dt
		fz[k] = float(fz[k]) - dt
		if float(fz[k]) <= 0.0:
			fz.erase(k)
			fz_mt.erase(k)
	for g in gears:
		var tm := mt(g.key)
		for j in range(g.n):
			var pl: Dictionary = g.plats[j]
			var pos := gear_pos(g, j, tm)
			var nx := pos.x - 24.0
			var ny := pos.y - 3.0
			pl.dx = nx - float(pl.x)
			pl.dy = ny - float(pl.y)
			pl.x = nx
			pl.y = ny
	if not cables.is_empty():
		flag_t -= dt
		if flag_t <= 0.0:
			flag_t = 0.5
			_sync_cable_flags()
	_step_pistons()
	if has_blink:
		_step_blinks(live)
	_step_mutex(dt, live)

# a cable cut by the other player (or on the host) reaches this page as a world flag
var cable_fh := 0                       # the flags' hash at the last sync (nothing changed: no walk over every flag)
func _sync_cable_flags() -> void:
	var fh := Game.flags.hash()
	if fh == cable_fh:
		return
	cable_fh = fh
	var pre := "cable:%s:" % room.id
	for fk in Game.flags:
		var fks := String(fk)
		if fks.begins_with(pre) and Game.flag(fks):
			var parts := fks.split(":")
			cut_at(int(parts[2]), int(parts[3]), true)

func _step_pistons() -> void:
	var me = room.player
	for pz in pistons:
		var rows_now := piston_rows_at(pz, mt(pz.key))
		if rows_now == pz.rows:
			continue
		var old_rows: int = pz.rows
		pz.rows = rows_now
		var crushed := false
		for c in pz.cells:
			var idx: int = int(c[1]) * room.w + int(c[0])
			if int(c[2]) < rows_now:
				if not room.grid.phead_on.has(idx):
					room.grid.phead_on[idx] = true
					if me != null and not me.dead and not me.gone and Game.overlap(me.hurtbox(), {"x": float(c[0] * T), "y": float(c[1] * T), "w": 16.0, "h": 16.0}):
						crushed = true
			else:
				room.grid.phead_on.erase(idx)
		if rows_now > old_rows and old_rows == 0 and room.is_local:
			Audio.local_sfx("thud", 0.18)
		if crushed:
			me.hazard()                       # caught between the head and something solid: a pip and back to the last safe spot

func _step_blinks(live: Array) -> void:
	var grid: TileGrid = room.grid
	for g in bgroups:
		var ph := blink_phase_of(g.key)
		if ph != g.ph:
			if g.ph >= 0:
				for c in g.cells:
					var t: int = grid.tile(c[0], c[1])
					var becomes := (t == TileGrid.BLINK_A and ph == 0) or (t == TileGrid.BLINK_B and ph == 1)
					if becomes and grid.any_on(live, c[0], c[1]):
						grid.blink_hold[c[1] * room.w + c[0]] = true
			g.ph = ph
		for c in g.cells:
			grid.blink_ph[c[1] * room.w + c[0]] = ph
	if not grid.blink_hold.is_empty():
		for i in grid.blink_hold.keys():
			if not grid.any_on(live, i % room.w, i / room.w):
				grid.blink_hold.erase(i)

func _step_mutex(dt: float, live: Array) -> void:
	var p = room.player
	var grid: TileGrid = room.grid
	for m in mutex:
		var trig := false
		var hit := false
		var rect: Dictionary = m.rect
		for q in live:
			if Game.overlap({"x": q.x, "y": q.y, "w": q.w, "h": q.h + 2.0}, rect):
				trig = true
		if p != null and not p.dead and not p.gone:
			if p.atk_t > 0.0 and p.atk_live and int(p.atk_id) != int(m.last_atk) and Game.overlap(p.atk_box(), rect):
				m.last_atk = int(p.atk_id)
				trig = true
				hit = true
			if p.dash_t > 0.0 and Game.overlap(p.hurtbox(), rect):
				trig = true
				hit = true
		if trig:
			m.t = MUTEX_T
			if room.mode == "guest":
				m.pred = room.time + 1.0
				if hit:
					room.net_mutex.emit(int(m.i))
		elif float(m.t) > 0.0:
			m.t = float(m.t) - dt
		var active: bool = float(m.t) > 0.0
		if active and not m.was and room.is_local:
			Audio.local_sfx("gate", 0.3)
		m.was = active
		for idx in m.cells:
			if active:
				grid.mgate_open[idx] = true
			elif grid.mgate_open.has(idx) and not grid.any_on(live, idx % room.w, idx / room.w):
				grid.mgate_open.erase(idx)         # (a gate never closes on a body: it waits until the cell is free)

# host: a guest's claw or dash on key i
func mutex_hit(i: int) -> void:
	if i >= 0 and i < mutex.size():
		mutex[i].t = MUTEX_T

# ---------------------------------------------------------------- cables
# the local player's claw swing: 2 damage cuts the cable, 1 clangs
func claw(p, box: Dictionary) -> void:
	for gi in range(cables.size()):
		var g: Dictionary = cables[gi]
		if g.cut:
			continue
		for c in g.cells:
			if not Game.overlap(box, {"x": float(c[0] * T), "y": float(c[1] * T), "w": 16.0, "h": 16.0}):
				continue
			if p.tools.get("opus", false) and int(p.atk_dmg) >= 2:
				if room.mode == "guest":
					cut_at(c[0], c[1], false)
					room.net_cable.emit(c[0], c[1])
				else:
					cut_at(c[0], c[1], false)
			elif int(g.get("clang_id", -1)) != int(p.atk_id):
				g["clang_id"] = int(p.atk_id)
				room.spark(float(c[0] * T + 8), float(c[1] * T + 8), "#ffd23f", 5)
				Audio.sfx("clang")
			return

# cuts the whole cable that has the cell; the hit cell names the flag
func cut_at(tx: int, ty: int, silent: bool) -> bool:
	for g in cables:
		if g.cut:
			continue
		var has := false
		for c in g.cells:
			if c[0] == tx and c[1] == ty:
				has = true
		if not has:
			continue
		g.cut = true
		for c in g.cells:
			room.grid.tiles[c[1] * room.w + c[0]] = TileGrid.E
			if not silent:
				room.burst(float(c[0] * T + 8), float(c[1] * T + 8), 3, ["#ff7a59", "#7cc4ff", "#ffd23f"], 70.0, 200.0)
		if not silent:
			room.shake(0.3)
			Audio.sfx("brk")
			Game.set_world_flag("cable:%s:%d:%d" % [room.id, tx, ty])
		return true
	return false

# ---------------------------------------------------------------- breakpoint (MV5A-04)
# rewind: the guest pressed when ITS clock said `rewind` seconds before the host's, so the object stops in the state the guest saw
func freeze(key: String, rewind := 0.0) -> void:
	if not fz.has(key):
		fz[key] = Game.BP_TIME
		offs[key] = float(offs.get(key, 0.0)) + clampf(rewind, 0.0, 1.5)

func is_frozen(key: String) -> bool:
	return fz.has(key)

# every machine a breakpoint could stop, as {kind, id (key), x, y, w, h, d (distance from the body centre to its nearest point), nx, ny (that point)}
func bp_targets(cx: float, cy: float) -> Array:
	var out: Array = []
	var rects: Array = []
	for pz in pistons:
		rects.append(["p", pz.key, Rect2(float(pz.x * T), float(pz.y * T), float(pz.w * T), float((pz.len + 1) * T))])
	for g in gears:
		var gr := Rect2(g.px - g.r * T - 24.0, g.py - g.r * T - 24.0, g.r * T * 2.0 + 48.0, g.r * T * 2.0 + 48.0)
		rects.append(["g", g.key, gr])
	for i in range(room.plats.size()):
		var pl: Dictionary = room.plats[i]
		if pl.has("bpk"):
			rects.append(["m", pl.bpk, Rect2(float(pl.x), float(pl.y) - 4.0, float(pl.w), 14.0)])
	for g in bgroups:
		for c in g.cells:
			if room.grid.tile(c[0], c[1]) == TileGrid.BLINK_A or room.grid.tile(c[0], c[1]) == TileGrid.BLINK_B:
				rects.append(["b", g.key, Rect2(float(c[0] * T), float(c[1] * T), 16.0, 16.0)])
	for r in rects:
		var rc: Rect2 = r[2]
		var nx: float = clampf(cx, rc.position.x, rc.position.x + rc.size.x)
		var ny: float = clampf(cy, rc.position.y, rc.position.y + rc.size.y)
		if r[0] == "g":                                  # a gear is hit at its centre or at one of its platforms
			var g2: Dictionary = gears[int(String(r[1]).substr(1))]
			var best := Vector2(g2.px, g2.py)
			for j in range(g2.n):
				var pp: Vector2 = gear_pos(g2, j, mt(g2.key))
				if Vector2(cx, cy).distance_to(pp) < Vector2(cx, cy).distance_to(best):
					best = pp
			nx = best.x
			ny = best.y
		out.append({"kind": r[0], "id": r[1], "rect": rc, "nx": nx, "ny": ny, "d": Vector2(nx - cx, ny - cy).length()})
	return out

# ---------------------------------------------------------------- the watchdog rule tick-desync (guest)
# what the host's clock implies for the machines, with the line's lag allowed for: a state this page shows is fine when the pure function gave it at
# any time in [host_t - 0.3, host_t + 0.05]; "" = all agree, else the first object that does not
func mismatch(host_t: float) -> String:
	var times: Array = []
	for k in range(8):
		times.append(host_t - 0.3 + float(k) * 0.05)
	for g in bgroups:
		var ok := false
		for tc in times:
			if floori(maxf(0.0, float(tc) - float(offs.get(g.key, 0.0))) / TICK) % 2 == int(g.ph) or int(g.ph) < 0:
				ok = true
		if not ok:
			return "blink group %s shows phase %d" % [g.key, g.ph]
	for g in gears:
		var ok2 := false
		for tc in times:
			var pos := gear_pos(g, 0, maxf(0.0, float(tc) - float(offs.get(g.key, 0.0))))
			if Vector2(pos.x - 24.0, pos.y - 3.0).distance_to(Vector2(g.plats[0].x, g.plats[0].y)) < 6.0:
				ok2 = true
		if not ok2:
			return "gear %s is off its angle" % g.key
	for pz in pistons:
		var ok3 := false
		for tc in times:
			if piston_rows_at(pz, maxf(0.0, float(tc) - float(offs.get(pz.key, 0.0)))) == int(pz.rows):
				ok3 = true
		if not ok3:
			return "piston %s covers %d rows" % [pz.key, pz.rows]
	return ""

# ---------------------------------------------------------------- the snapshot (host writes, guest applies)
func net_pack() -> Dictionary:
	var mx: Array = []
	for m in mutex:
		if float(m.t) > 0.0:
			mx.append([int(m.i), roundi(float(m.t) * 100.0)])
	var fl: Array = []
	for k in offs:
		if float(offs[k]) > 0.0 or fz.has(k):
			fl.append([String(k), roundi(float(fz.get(k, 0.0)) * 100.0), roundi(float(offs[k]) * 100.0), roundi(mt(String(k)) * 100.0)])
	return {"mx": mx, "fz": fl, "it": room.iter}

func net_apply(d: Dictionary) -> void:
	var listed := {}
	for e in d.get("mx", []):
		listed[int(e[0])] = float(e[1]) / 100.0
	for m in mutex:
		var i: int = int(m.i)
		if listed.has(i):
			m.t = maxf(float(listed[i]), float(m.t) if float(m.pred) > room.time else 0.0)
		elif float(m.pred) <= room.time:
			m.t = 0.0
	var fresh_offs := {}
	var fresh_fz := {}
	var fresh_mt := {}
	for e in d.get("fz", []):
		fresh_offs[String(e[0])] = float(e[2]) / 100.0
		if int(e[1]) > 0:
			fresh_fz[String(e[0])] = float(e[1]) / 100.0
			if e.size() > 3:
				fresh_mt[String(e[0])] = float(e[3]) / 100.0
				fresh_offs[String(e[0])] = room.time - float(e[3]) / 100.0
	offs = fresh_offs
	fz = fresh_fz
	fz_mt = fresh_mt
	if d.has("it"):
		room.set_iter(int(d.it))

# ---------------------------------------------------------------- drawing
func _col(k: String) -> Color:
	return Color(String(Game.theme(4).get(k, "#a8793a")))

func draw(ci: CanvasItem) -> void:
	var ink := Color(Game.COL.ink)
	var base := _col("base")
	var lite := _col("lite")
	var dark := _col("dark")
	var cap := _col("cap")
	var accent := _col("accent")
	# blink blocks: solid = bright brass, off = a faint outline; the ones that turn off flicker in the last 0.2 of the tick
	for g in bgroups:
		var tm := mt(g.key)
		var f := tick_f_of(tm)
		for c in g.cells:
			var t: int = room.grid.tile(c[0], c[1])
			if t != TileGrid.BLINK_A and t != TileGrid.BLINK_B:
				continue
			var rx: float = c[0] * T
			var ry: float = c[1] * T
			var on: bool = room.grid.solid(c[0], c[1])
			if on:
				var warn: bool = f > 0.8 and not room.grid.blink_hold.has(c[1] * room.w + c[0])
				if warn and int(room.time * 24.0) % 2 == 0:
					ci.draw_rect(Rect2(rx + 1, ry + 1, 14, 14), Color(lite, 0.35))
				else:
					ci.draw_rect(Rect2(rx, ry, 16, 16), ink)
					ci.draw_rect(Rect2(rx + 1, ry + 1, 14, 14), base)
					ci.draw_rect(Rect2(rx + 1, ry + 1, 14, 2), cap)
					ci.draw_rect(Rect2(rx + 2, ry + 12, 12, 2), dark)
					ci.draw_rect(Rect2(rx + 6, ry + 6, 4, 4), lite)
			else:
				var soon: bool = f > 0.8
				ci.draw_rect(Rect2(rx + 1, ry + 1, 14, 14), Color(lite, 0.28 if soon else 0.10), false, 1.0)
				if soon:
					ci.draw_rect(Rect2(rx + 5, ry + 5, 6, 6), Color(lite, 0.18))
	# gears
	for g in gears:
		var tm2 := mt(g.key)
		var spin := (float(tick_i_of(tm2)) + ease_tick(tick_f_of(tm2))) * 45.0
		var ctr := Vector2(g.px, g.py)
		for j in range(g.n):
			var pos := gear_pos(g, j, tm2)
			ci.draw_line(ctr, pos, dark, 2.0)
			ci.draw_line(ctr, pos, base, 1.0)
		ci.draw_circle(ctr, 9.0, ink)
		ci.draw_circle(ctr, 8.0, base)
		for tI in range(8):
			var a := deg_to_rad(spin + float(tI) * 45.0)
			var dv := Vector2(cos(a), sin(a))
			ci.draw_rect(Rect2(ctr.x + dv.x * 9.0 - 1.5, ctr.y + dv.y * 9.0 - 1.5, 3, 3), lite)
		ci.draw_circle(ctr, 3.0, dark)
		ci.draw_circle(ctr, 1.5, cap)
		if fz.has(g.key):
			_frozen_frame(ci, ctr.x - 12.0, ctr.y - 12.0, 24.0, 24.0, float(fz[g.key]))
	# pistons: the casing (drawn here, not solid) and the shaft and head, which step down cell by cell
	for pz in pistons:
		var hx: float = pz.x * T
		var hy: float = (pz.y + 1) * T
		var wpx: float = pz.w * T
		var n: int = pz.rows
		var busy: bool = pz.busy
		ci.draw_rect(Rect2(hx, float(pz.y * T), wpx, 16.0), ink)
		ci.draw_rect(Rect2(hx + 1, float(pz.y * T) + 1, wpx - 2, 14.0), accent if busy else base)
		ci.draw_rect(Rect2(hx + 1, float(pz.y * T) + 1, wpx - 2, 2), cap)
		for i in range(int(pz.w)):
			ci.draw_rect(Rect2(hx + i * 16.0 + 6, float(pz.y * T) + 5, 4, 6), ink)
		# the rail the head runs in (faint)
		ci.draw_rect(Rect2(hx + 2, hy, wpx - 4, float(pz.len * T)), Color(dark, 0.18))
		if n > 0:
			var hh: float = n * 16.0
			ci.draw_rect(Rect2(hx + wpx / 2.0 - 2, hy, 4, hh - 8), dark)
			ci.draw_rect(Rect2(hx, hy + hh - 10, wpx, 10), ink)
			ci.draw_rect(Rect2(hx + 1, hy + hh - 9, wpx - 2, 8), accent if busy else lite)
			ci.draw_rect(Rect2(hx + 1, hy + hh - 9, wpx - 2, 2), cap)
			for i in range(int(wpx / 8.0)):
				ci.draw_rect(Rect2(hx + 2 + i * 8, hy + hh - 3, 4, 2), ink)
		if fz.has(pz.key):
			_frozen_frame(ci, hx - 2, hy - 18.0, wpx + 4, float(pz.len * T) + 18.0, float(fz[pz.key]))
	for k in fz:                                          # a frozen platform or blink group
		if String(k).begins_with("m"):
			for pl in room.plats:
				if pl.get("bpk", "") == k:
					_frozen_frame(ci, float(pl.x) - 2.0, float(pl.y) - 6.0, float(pl.w) + 4.0, 16.0, float(fz[k]))
		elif String(k).begins_with("b"):
			for g in bgroups:
				if g.key == k:
					var rx0 := 1e9
					var ry0 := 1e9
					var rx1 := -1e9
					var ry1 := -1e9
					for c in g.cells:
						rx0 = minf(rx0, float(c[0] * T))
						ry0 = minf(ry0, float(c[1] * T))
						rx1 = maxf(rx1, float(c[0] * T + T))
						ry1 = maxf(ry1, float(c[1] * T + T))
					_frozen_frame(ci, rx0 - 1.0, ry0 - 1.0, rx1 - rx0 + 2.0, ry1 - ry0 + 2.0, float(fz[k]))
	# mutex keys and gates
	for m in mutex:
		var r: Dictionary = m.rect
		var act: bool = float(m.t) > 0.0
		ci.draw_rect(Rect2(r.x, r.y + 12, 16, 4), ink)
		ci.draw_rect(Rect2(r.x + 1, r.y + 13, 14, 2), accent if act else lite)
		ci.draw_rect(Rect2(r.x + 5, r.y + 7, 6, 5), ink)                              # a padlock on the plate
		ci.draw_rect(Rect2(r.x + 6, r.y + 8, 4, 3), cap if act else base)
		ci.draw_rect(Rect2(r.x + 6, r.y + 5, 4, 3), ink)
		ci.draw_rect(Rect2(r.x + 7, r.y + 6, 2, 2), Color(0, 0, 0, 0) if act else lite)
		for idx in m.cells:
			var gx: float = (idx % room.w) * T
			var gy: float = (idx / room.w) * T
			if room.grid.mgate_open.has(idx):
				ci.draw_rect(Rect2(gx + 1, gy + 1, 14, 14), Color(lite, 0.22), false, 1.0)
				var frac := clampf(float(m.t) / MUTEX_T, 0.0, 1.0)
				ci.draw_rect(Rect2(gx + 2, gy + 14, 12.0 * frac, 1), accent)
			else:
				ci.draw_rect(Rect2(gx, gy, 16, 16), ink)
				ci.draw_rect(Rect2(gx + 1, gy + 1, 14, 14), dark)
				for s in range(4):                                                     # a striped lock bar
					ci.draw_rect(Rect2(gx + 1 + s * 4, gy + 1, 2, 14), accent if (s % 2 == 0) else ink)
	# cables
	for g in cables:
		if g.cut:
			continue
		for c in g.cells:
			var cx: float = c[0] * T
			var cy: float = c[1] * T
			ci.draw_rect(Rect2(cx, cy, 16, 16), ink)
			var cols := [Color("#ff7a59"), Color("#7cc4ff"), Color("#ffd23f"), Color("#7fd08a")]
			for s in range(4):
				var wob := sin(room.time * 2.0 + float(c[0] + c[1]) * 0.7 + float(s)) * 1.0
				ci.draw_rect(Rect2(cx + 1 + s * 4 + wob, cy, 3, 16), cols[s])

func _frozen_frame(ci: CanvasItem, x: float, y: float, w: float, h: float, left: float) -> void:
	var blue := Color("#7cc4ff")
	ci.draw_rect(Rect2(x, y, w, h), blue, false, 1.0)
	PixelText.draw_text(ci, "BREAK %.1f" % left, x + w / 2.0, y - 8.0, "#7cc4ff", {"align": "c", "tiny": true, "outline": Game.COL.ink})
