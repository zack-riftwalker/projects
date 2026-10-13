class_name DeadlockBoss
extends Boss
# DEADLOCK (T18, MV5A-08, optional): two halves, LOCK A and LOCK B, each holding the key of the other. A kit boss: every attack is announced, harm
# exists only in the active phase of a plan or in an arena hazard, and the guest builds the same boxes from the net fields.
# THE COMMIT RULE (the room's point): damage to one half is only pending for 2.0 s. It counts when the other half takes damage within that time
# (both are committed); else it rolls back (ROLLBACK). Alone: hit one, run, hit the other inside 2 s, or stop one half with breakpoint and alternate.
# Two players: one each. Each half has 48 hp at normal (96 together).
# The chain between the halves is the arena hazard: `chain` sweeps (they slide along opposite walls, the line crosses the whole arena); in phase 3 the
# chain is always live except while they recover. `grab`: one half lunges at its target (2). `swap` (phase 2+): they exchange keys: both are
# invulnerable for 1.5 s (a bright tell).

const IDS := ["chain", "grab", "swap"]
const SEQ1 := ["chain", "grab"]
const SEQ2 := ["chain", "grab", "swap", "grab"]
const SEQ3 := ["grab", "chain", "swap", "grab"]
const COL := ["#7cc4ff", "#ffd23f"]
const COL_HI := ["#d6f6ff", "#fff3b0"]
const COL_LO := ["#3a5a8a", "#8a6a1a"]
const PEND_T := 2.0
const SWEEP_T := 1.6
const LEFT_X := 30.0
const RIGHT_X := 354.0
const INK := "#1b1226"

var halves: Array = []
var cycle := 0
var idle_t := 0.0
var strike_sid := 0
var inv_t := 0.0                    # swap: both halves cannot be hurt
var recovering := false             # in a plan's recover: the chain of phase 3 is dark
var grab_i := 0
var grab_pt := Vector2.ZERO
var grab_from := Vector2.ZERO
var chain_n := 0
var phase_mem := 1
var chain_started := false

func _init(r: Room, bx: float, by: float, base_hp := 96) -> void:
	super(r, 192.0, Boss.FLOOR, 20, 26, base_hp)
	boss_name = "DEADLOCK"
	sub = "each waits for the other"
	col = COL[0]
	kit_init()
	var each := ceili(float(base_hp) / 2.0)
	var xs := [88.0, 280.0]
	if r.boss_cells.size() >= 2:
		xs = [float(r.boss_cells[0].x), float(r.boss_cells[1].x)]
	for i in range(2):
		halves.append({"i": i, "x": xs[i], "y": Boss.FLOOR, "hp": float(each), "max": each, "dead": false, "flash": 0.0, "pend": 0.0, "pend_t": 0.0, "bpt": 0.0, "face": 1.0 if i == 0 else -1.0, "home_x": xs[i]})
	_sums()

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["chain"]

func _big() -> int:
	return int(Game.dv("big_hit"))

func _sums() -> void:
	var tot := 0.0
	var mx := 0
	for q in halves:
		tot += maxf(0.0, q.hp)
		mx += int(q.max)
	hpf = tot
	hp = ceili(tot)
	max_hp = mx

func scale_hp(k: float) -> void:
	for q in halves:
		q.max = roundi(q.max * k)
		q.hp = float(q.max)
	_sums()

func alive() -> Array:
	return halves.filter(func(q): return not q.dead)

func _phase_now() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.25 else (2 if f <= 0.60 else 1)

func hpos(i: int) -> Vector2:
	return Vector2(halves[i].x, halves[i].y - 13.0)               # the centre of a half (20x26 standing on y)

# ---- breakpoint: each half on its own ----
func bp_halves() -> Array:
	var out: Array = []
	for q in halves:
		if not q.dead and q.bpt <= 0.0:
			var p := hpos(int(q.i))
			out.append({"i": q.i, "nx": p.x, "ny": p.y})
	return out

func bp_freeze(i: int) -> bool:
	if i < 0 or i > 1 or halves[i].dead or halves[i].bpt > 0.0:
		return false
	halves[i].bpt = Game.BP_TIME
	return true

func bp_half_pos(i: int) -> Vector2:
	return hpos(clampi(i, 0, 1))

# ---- boxes ----
func hurtboxes() -> Array:
	var b: Array = []
	for q in halves:
		if not q.dead:
			b.append({"x": q.x - 10.0, "y": q.y - 26.0, "w": 20.0, "h": 26.0, "head": q.i})
	return b

func _chain_boxes() -> Array:
	var b: Array = []
	if alive().size() < 2:
		return b
	var a := hpos(0)
	var c := hpos(1)
	var n := maxi(1, int(ceilf(a.distance_to(c) / 8.0)))
	for k in range(n + 1):
		var p := a.lerp(c, float(k) / float(n))
		b.append({"x": p.x - 4.0, "y": p.y - 4.0, "w": 8.0, "h": 8.0, "dmg": 1})
	return b

func _body_box(i: int, grow := 0.0) -> Dictionary:
	var q = halves[i]
	return {"x": q.x - 10.0 - grow, "y": q.y - 26.0 - grow, "w": 20.0 + grow * 2.0, "h": 26.0 + grow * 2.0, "dmg": _big()}

func harmboxes() -> Array:
	var b: Array = []
	if plan_active():
		match String(plan.id):
			"chain":
				b.append_array(_chain_boxes())
			"grab":
				b.append(_body_box(grab_i, 4.0))
	b.append_array(hz_harm())
	return b

# the phase-3 chain is a hazard: drawn from the start (warn 1.0 s), live whenever the halves are not recovering
func hz_boxes(h: Dictionary, _now: float) -> Array:
	if String(h.k) == "chain" and not recovering and inv_t <= 0.0:
		return _chain_boxes()
	return []

func _hz_expired(_h: Dictionary, _now: float) -> bool:
	return false

# ---- damage: the commit rule ----
func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	if d >= 9999:                                             # "skip boss"
		for c in halves:
			c.hp = 0.0
			c.dead = true
		_sums()
		hpf = 0.0
		hp = 0
		begin_death()
		return "kill"
	var q = null
	if box is Dictionary and box.has("head"):
		q = halves[int(box.head)]
	else:
		var more = null
		for c in halves:
			if not c.dead and (more == null or c.hp > more.hp):
				more = c
		q = more
	if q == null or q.dead:
		return ""
	if inv_t > 0.0:                                           # swap: the keys are in the air
		Audio.sfx("clang", {"vol": 0.6})
		room.spark(q.x, q.y - 13.0, "#ffffff", 6)
		return "block"
	var dm := float(d)
	if how == "agent" or how == "dash":
		dm *= 0.5
	q.flash = 0.1
	room.boss_damage(self, dm, how)
	var key := kit_key_of(room.attacker)
	if read != null and key != "":
		read.note_hit(key, how)
	var o = halves[1 - int(q.i)]
	if o.dead:
		q.hp -= dm                                            # the other half is gone: nothing to wait for
	elif float(o.pend_t) > 0.0:                               # the other half was hit a moment ago: both count
		q.hp -= dm + float(q.pend)
		o.hp -= float(o.pend)
		q.pend = 0.0
		q.pend_t = 0.0
		o.pend = 0.0
		o.pend_t = 0.0
		o.flash = 0.1
		room.pop((q.x + o.x) / 2.0, minf(q.y, o.y) - 40.0, "COMMIT", "#ffd23f", true)
		room.burst(o.x, o.y - 13.0, 6, [COL[o.i], "#ffffff"], 120.0, 200.0, {"glow": 1})
		Audio.sfx("bossHit")
	else:
		q.pend = float(q.pend) + dm
		if float(q.pend_t) <= 0.0:
			q.pend_t = PEND_T
		Audio.sfx("clang", {"vol": 0.5})
		room.spark(q.x, q.y - 13.0, COL[q.i], 5)
		return "hit"
	_sums()
	room.burst(q.x, q.y - 13.0, 6, [COL[q.i], "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	for c in [q, o]:
		if not c.dead and c.hp <= 0.0:
			c.hp = 0.0
			c.dead = true
			room.explode(c.x, c.y - 13.0, 22.0, ["#ffffff", COL_HI[c.i], COL[c.i]])
			room.shake(0.7)
			room.stop(0.2)
			Audio.sfx("explode")
	_sums()
	if alive().is_empty():
		hpf = 0.0
		hp = 0
		begin_death()
		return "kill"
	on_damage()
	if q.dead:
		room.pop(q.x, q.y - 40.0, "lock %s released" % ("A" if q.i == 0 else "B"), COL_HI[q.i], true)
		plan_cut()
		idle_t = 0.9
		return "kill"
	return "hit"

func on_damage() -> void:
	var p := _phase_now()
	if p != phase_mem:
		phase_mem = p
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

func begin_death() -> void:
	super.begin_death()
	hz.clear()

func start() -> void:
	super.start()
	idle_t = 1.0
	phase_mem = _phase_now()

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	for q in halves:
		if q.flash > 0.0:
			q.flash -= dt
	if dying:
		death_rattle(dt, 2.4, ["#ffffff", COL[0], COL[1]])
		return
	if not active:
		return
	phase = _phase_now()
	for q in halves:                                          # pending damage rolls back
		if float(q.pend_t) > 0.0:
			q.pend_t -= dt
			if q.pend_t <= 0.0 and float(q.pend) > 0.0:
				q.pend = 0.0
				room.pop(q.x, q.y - 36.0, "ROLLBACK", "#8d8798", true)
				room.ring(q.x, q.y - 13.0, 2, 14, "#8d8798", 0.3)
		if float(q.bpt) > 0.0:
			q.bpt -= dt
	if inv_t > 0.0:
		inv_t -= dt
	recovering = not plan.is_empty() and String(plan.ph) == "recover"
	if _phase_now() == 3 and not chain_started:
		chain_started = true
		hz_add("chain", 1.0, [])
		room.pop(192.0, 60.0, "deadlock", "#ff4f6d", true)
	if plan.is_empty():
		plan_clock += dt
		idle_t -= dt
		_idle(dt)
		if idle_t <= 0.0:
			_choose()
	else:
		_plan_logic(dt)
	var al := alive()
	if not al.is_empty():
		var mx := 0.0
		for q in al:
			mx += q.x
		x = mx / float(al.size()) - w / 2.0
		y = Boss.FLOOR - h

func _frozen(i: int) -> bool:
	return float(halves[i].bpt) > 0.0

func _idle(dt: float) -> void:
	for q in halves:
		if q.dead or float(q.bpt) > 0.0:
			continue
		var home: float = q.home_x
		if alive().size() == 1:
			home = 192.0 + (-70.0 if q.i == 0 else 70.0)
		q.x += clampf(home - q.x, -55.0 * dt, 55.0 * dt)
		q.y = Boss.FLOOR

func _choose() -> void:
	var ph := _phase_now()
	var seq: Array = SEQ3 if ph == 3 else (SEQ2 if ph == 2 else SEQ1)
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	if (id == "chain" or id == "swap") and alive().size() < 2:
		id = "grab"
	_start(id)

func _start(id: String) -> void:
	var tgt := kit_pick_target()
	match id:
		"chain":
			chain_n += 1
			plan_start("chain", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 1.0, 0.7, SWEEP_T)
		"grab":
			var gi := 0
			var best := 1e18
			for q in alive():
				var d := absf(float(q.x) - kit_aim(tgt).x)
				if d < best:
					best = d
					gi = int(q.i)
			grab_i = gi
			var ap := kit_aim(tgt)
			grab_from = hpos(gi)
			grab_pt = Vector2(clampf(ap.x, 30.0, 354.0), Boss.FLOOR - 13.0)
			var fp := [grab_pt.x - 14.0, grab_pt.y - 18.0, 28.0, 36.0]
			plan_start("grab", "lunge", tgt, fp, 0.2, 0.75, 0.9, 0.3)
		"swap":
			plan_start("swap", "guard", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, 0.6, 1.5)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])
	idle_t = 0.4

func _plan_logic(dt: float) -> void:
	var pid := String(plan.id)
	match pid:
		"chain":
			if plan.ph == "cue":                              # the halves walk to the walls; the sweep's path is drawn
				for q in halves:
					if not q.dead and not _frozen(int(q.i)):
						var wx: float = LEFT_X if q.i == 0 else RIGHT_X
						q.x += clampf(wx - q.x, -140.0 * dt, 140.0 * dt)
			elif plan.ph == "active":
				var f := clampf(1.0 - float(plan.t) / SWEEP_T, 0.0, 1.0)
				for q in halves:
					if q.dead or _frozen(int(q.i)):
						continue
					var y0: float = Boss.FLOOR if q.i == 0 else 56.0
					var y1: float = 56.0 if q.i == 0 else Boss.FLOOR
					q.y = lerpf(y0, y1, f)
		"grab":
			if plan.ph == "cue" and plan.t > float(plan.lock):
				var ap := kit_aim(String(plan.tgt))
				grab_pt = Vector2(clampf(ap.x, 30.0, 354.0), Boss.FLOOR - 13.0)
				grab_from = hpos(grab_i)
				plan.fp = [grab_pt.x - 14.0, grab_pt.y - 18.0, 28.0, 36.0]
			if plan.ph == "active" and not _frozen(grab_i):
				var f2 := clampf(1.0 - float(plan.t) / 0.3, 0.0, 1.0)
				var p := grab_from.lerp(grab_pt, sin(f2 * PI * 0.5))
				halves[grab_i].x = p.x
				halves[grab_i].y = p.y + 13.0
	var ev := plan_step(dt)
	match ev:
		"active":
			strike_sid = Game.next_strike_id()
			match pid:
				"swap":
					inv_t = 1.5
					for q in halves:
						q.pend = 0.0
						q.pend_t = 0.0
					room.ring(192.0, 100.0, 4, 60, "#ffffff", 0.5)
					Audio.sfx("charge", {"vol": 0.8})
				"chain":
					Audio.sfx("laser", {"vol": 0.6})
					room.shake(0.3)
				"grab":
					Audio.sfx("dash", {"vol": 0.7})
		"recover":
			strike_sid = 0
		"done":
			strike_sid = 0
			for q in halves:
				if not q.dead and not _frozen(int(q.i)):
					q.y = Boss.FLOOR
			idle_t = 0.3

# ---- drawing ----
func _draw_half(ci: CanvasItem, q: Dictionary) -> void:
	var ink := Color(INK)
	var bx := floorf(q.x - 10.0)
	var by := floorf(q.y - 26.0)
	var c := Color(COL[q.i])
	var hi := Color(COL_HI[q.i])
	var lo := Color(COL_LO[q.i])
	var wob := 0.0
	var bright: bool = inv_t > 0.0
	ci.draw_rect(Rect2(bx - 1.0, by - 1.0, 22.0, 28.0), ink)
	ci.draw_rect(Rect2(bx, by, 20.0, 26.0), Color.WHITE if (q.flash > 0.0 or (bright and int(t * 20.0) % 2 == 0)) else c)
	ci.draw_rect(Rect2(bx, by, 20.0, 3.0), hi)
	ci.draw_rect(Rect2(bx, by + 23.0, 20.0, 3.0), lo)
	# a big padlock for a body, with the key hole as a mouth
	ci.draw_rect(Rect2(bx + 4.0, by - 5.0, 12.0, 5.0), ink)
	ci.draw_rect(Rect2(bx + 6.0, by - 4.0, 8.0, 4.0), lo)
	var ex := bx + (12.0 if q.face > 0.0 else 4.0)
	ci.draw_rect(Rect2(ex, by + 8.0, 4.0, 4.0), Color.WHITE)
	ci.draw_rect(Rect2(ex + 1.0, by + 9.0, 2.0, 2.0), ink)
	ci.draw_rect(Rect2(bx + 8.0, by + 16.0, 4.0, 6.0), ink)
	PixelText.draw_text(ci, "A" if q.i == 0 else "B", bx + 10.0, by - 14.0, COL[q.i], {"align": "c", "tiny": true, "outline": INK})
	var frac := clampf(float(q.hp) / maxf(1.0, float(q.max)), 0.0, 1.0)
	ci.draw_rect(Rect2(bx - 2.0, by - 8.0 - 1.0, 24.0, 3.0), ink)
	ci.draw_rect(Rect2(bx - 1.0, by - 8.0, 22.0 * frac, 1.0), hi)
	if float(q.pend) > 0.0:                                   # pending: a red bar eating the health, shrinking with the window
		var pf := clampf(float(q.pend) / maxf(1.0, float(q.max)), 0.0, 1.0)
		ci.draw_rect(Rect2(bx - 1.0 + 22.0 * (frac - pf), by - 8.0, 22.0 * pf, 1.0), Color("#ff4f6d"))
		ci.draw_rect(Rect2(bx - 1.0, by - 11.0, 22.0 * clampf(float(q.pend_t) / PEND_T, 0.0, 1.0), 1.0), Color("#ffd23f"))
	if float(q.bpt) > 0.0:
		ci.draw_rect(Rect2(bx - 2.0, by - 2.0, 24.0, 30.0), Color("#7cc4ff"), false, 1.0)
		PixelText.draw_text(ci, "BREAK %.1f" % float(q.bpt), bx + 10.0, by - 20.0, "#7cc4ff", {"align": "c", "tiny": true, "outline": INK})

func _draw_chain(ci: CanvasItem, live: bool, dim: bool) -> void:
	if alive().size() < 2:
		return
	var a := hpos(0)
	var c := hpos(1)
	var col := Color("#ff6a8a") if live else Color(0.49, 0.77, 1.0, 0.7 if not dim else 0.25)
	ci.draw_line(a, c, col, 3.0 if live else 1.0)
	var n := int(a.distance_to(c) / 14.0)
	for k in range(n):
		var p := a.lerp(c, (float(k) + fposmod(t * 1.5, 1.0)) / float(maxi(n, 1)))
		ci.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 3, 3), Color("#ffd0d8") if live else Color("#d6f6ff"))

func draw_boss_body(ci: CanvasItem) -> void:
	var chain_live: bool = (plan_active() and String(plan.id) == "chain") or (chain_started and not recovering and inv_t <= 0.0 and hz.size() > 0 and hz_live(hz[0], room.time))
	_draw_chain(ci, chain_live, plan.is_empty())
	if dying and gone:
		return
	for q in halves:
		if not q.dead:
			_draw_half(ci, q)
	if plan_active() and String(plan.id) == "grab":
		var hb := _body_box(grab_i, 4.0)
		ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1, 1, 1, 0.5))

func _hatch(ci: CanvasItem, r: Rect2) -> void:
	var hot := int(t * 12.0) % 2 == 0
	var c1 := Color(Game.COL.hazardHi) if hot else Color(Game.COL.hazard)
	var c2 := Color(Game.COL.hazard)
	ci.draw_rect(r, Color(c2.r, c2.g, c2.b, 0.18))
	var yy := 0.0
	while yy < r.size.y:
		ci.draw_rect(Rect2(r.position.x, r.position.y + yy, r.size.x, 1), Color(c1.r, c1.g, c1.b, 0.7))
		yy += 4.0
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), c1)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c1)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), c1)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c1)

func draw_boss_overlay(ci: CanvasItem) -> void:
	if plan.is_empty() or plan.ph != "cue":
		return
	match String(plan.id):
		"chain":
			# the path of the sweep: the line at its start and at its end
			var a0 := Vector2(LEFT_X, Boss.FLOOR - 13.0)
			var b0 := Vector2(RIGHT_X, 56.0 - 13.0)
			var a1 := Vector2(LEFT_X, 56.0 - 13.0)
			var b1 := Vector2(RIGHT_X, Boss.FLOOR - 13.0)
			ci.draw_line(a0, b0, Color(1.0, 0.8, 0.3, 0.55), 1.0)
			ci.draw_line(a1, b1, Color(1.0, 0.8, 0.3, 0.55), 1.0)
			ci.draw_rect(Rect2(LEFT_X - 6.0, 56.0 - 13.0, 12.0, Boss.FLOOR - 56.0), Color(1.0, 0.31, 0.43, 0.2))
			ci.draw_rect(Rect2(RIGHT_X - 6.0, 56.0 - 13.0, 12.0, Boss.FLOOR - 56.0), Color(1.0, 0.31, 0.43, 0.2))
			PixelText.draw_text(ci, "sweep", 192.0, 40.0, "#ffd23f", {"align": "c", "tiny": true, "outline": INK})
		"grab":
			var fp: Array = plan.fp
			_hatch(ci, Rect2(fp[0], fp[1], fp[2], fp[3]))
			ci.draw_line(hpos(grab_i), grab_pt, Color(1.0, 0.31, 0.43, 0.4), 1.0)
			_target_marker(ci, String(plan.tgt))
		"swap":
			PixelText.draw_text(ci, "swap keys", 192.0, 60.0, "#ffffff", {"align": "c", "tiny": true, "outline": INK})
			ci.draw_line(hpos(0), hpos(1), Color(1, 1, 1, 0.6), 2.0)

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid,
		roundi(halves[0].x * 4.0), roundi(halves[0].y * 4.0), roundi(halves[1].x * 4.0), roundi(halves[1].y * 4.0),
		roundi(halves[0].hp * 10.0), roundi(halves[1].hp * 10.0), 1 if halves[0].dead else 0, 1 if halves[1].dead else 0,
		roundi(halves[0].pend * 10.0), roundi(halves[1].pend * 10.0), roundi(maxf(halves[0].pend_t, 0.0) * 100.0), roundi(maxf(halves[1].pend_t, 0.0) * 100.0),
		roundi(maxf(inv_t, 0.0) * 100.0), 1 if recovering else 0, roundi(maxf(halves[0].bpt, 0.0) * 100.0), roundi(maxf(halves[1].bpt, 0.0) * 100.0),
		int(round(halves[0].face)), int(round(halves[1].face)), roundi(grab_pt.x), roundi(grab_pt.y), roundi(grab_from.x), roundi(grab_from.y), grab_i, 1 if chain_started else 0]
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 28

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	strike_sid = int(f[3])
	halves[0].x = f[4] / 4.0
	halves[0].y = f[5] / 4.0
	halves[1].x = f[6] / 4.0
	halves[1].y = f[7] / 4.0
	halves[0].hp = f[8] / 10.0
	halves[1].hp = f[9] / 10.0
	halves[0].dead = int(f[10]) == 1
	halves[1].dead = int(f[11]) == 1
	halves[0].pend = f[12] / 10.0
	halves[1].pend = f[13] / 10.0
	halves[0].pend_t = f[14] / 100.0
	halves[1].pend_t = f[15] / 100.0
	inv_t = f[16] / 100.0
	recovering = int(f[17]) == 1
	halves[0].bpt = f[18] / 100.0
	halves[1].bpt = f[19] / 100.0
	halves[0].face = float(f[20])
	halves[1].face = float(f[21])
	grab_pt = Vector2(float(f[22]), float(f[23]))
	grab_from = Vector2(float(f[24]), float(f[25]))
	grab_i = int(f[26])
	chain_started = int(f[27]) == 1
	phase = _phase_now()
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])
	for q in halves:
		q.max = maxi(ceili(float(max_hp) / 2.0), 1)
	x = (halves[0].x + halves[1].x) / 2.0 - w / 2.0
	y = Boss.FLOOR - h

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	for q in halves:
		if q.flash > 0.0:
			q.flash -= dt
		if float(q.pend_t) > 0.0:
			q.pend_t -= dt
		if float(q.bpt) > 0.0:
			q.bpt -= dt
	if inv_t > 0.0:
		inv_t -= dt
