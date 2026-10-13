class_name RaceBoss
extends Boss
# RACE CONDITION (T06, MV5A-06): two threads, A (orange) and B (blue), one shared variable. A kit boss: every attack is announced, harm exists
# only in the active phase of a plan or in an arena hazard, and the guest builds the same boxes from the net fields.
# Two bodies (16x24, hp 45 each at normal; both must die; the last one alive is enraged: cues x0.85, recovers -0.1). Hits go to the thread whose
# hurtbox was struck (the host picks the one nearest to a guest's swing, like MERGE CONFLICT's heads).
#
# read -> write: each thread drops a ghost of its target's place AT THE START OF ITS CUE (B reads 0.3 s after A) and the write strikes the ghost:
# a 32x40 column on the floor, 1 damage; two ghosts in one segment of the floor = a collision write, 2. The ghost goes to the player who has moved
# least in the last second (rule 8: it reads your habit), B's to the other player when there are two.
# The shared buffer: the floor is 8 segments of 48 px. A write paints its segment with its thread's colour; a segment painted by both within 4 s turns
# corrupt (a warning of 0.6 s, then the floor band hurts for 6 s, at most 4 at once).
# The mutex lock (12x14 at 208, 96): a hit serializes for 6 s (one thread writes per attack, half the rate, every corrupt segment clears), then a 10 s cooldown.
# switch (phase 2+): the threads swap places, the arrival spots shown 0.6 s before. contend (phase 3): both dash through the lock along shown lines;
# when they meet they stun each other for 2 s.

const IDS := ["rw", "switch", "contend"]
const SEG_N := 8
const SEG_W := 48.0
const SEG_X0 := 16.0
const LOCK := {"x": 202.0, "y": 89.0, "w": 12.0, "h": 14.0}
const LOCK_C := Vector2(208.0, 96.0)
const COL := ["#ff7a2f", "#4a90ff"]
const COL_HI := ["#ffc08a", "#a8d0ff"]
const COL_LO := ["#8a3a10", "#1f4a8a"]
const HOMES := [130.0, 286.0]
const SEQ1 := ["rw", "rw"]
const SEQ2 := ["rw", "switch", "rw"]
const SEQ3 := ["rw", "contend", "switch", "rw"]
const WRITE_T := 0.3
const PAINT_WINDOW := 4.0
const CORRUPT_T := 6.0
const CORRUPT_WARN := 0.6
const SERIAL_T := 6.0
const LOCK_CD := 10.0
const WALK := 50.0
const ARENA_L := 24.0
const ARENA_R := 392.0

var th: Array = []
var cycle := 0
var idle_t := 0.0
var strike_sid := 0
var gx := [-1.0, -1.0]             # the ghosts (x of the write column), -1 = none
var seg_t := [[-99.0, -99.0, -99.0, -99.0, -99.0, -99.0, -99.0, -99.0], [-99.0, -99.0, -99.0, -99.0, -99.0, -99.0, -99.0, -99.0]]   # when thread A / B last painted each segment
var lock_cd := 0.0
var serial_t := 0.0
var ser_turn := 0                  # serialized: which thread writes next
var sw: Array = [0.0, 0.0, 0.0, 0.0]        # switch: the arrival spots [Ax, Ay, Bx, By] (A arrives where B stood)
var dsh := [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
var moved_samples := {"p1": [], "p2": []}
var mv_acc := 0.0
var wrote := [false, false]
var part_ghost_b := false          # B's ghost was read in this plan
var phase_mem := 1

func _init(r: Room, bx: float, by: float, base_hp := 90) -> void:
	super(r, bx, by, 16, 24, base_hp)
	boss_name = "RACE CONDITION"
	sub = "two threads, one variable"
	col = COL[0]
	kit_init()
	var each := ceili(float(base_hp) / 2.0)
	var starts := [HOMES[0], HOMES[1]]
	if r.boss_cells.size() >= 2:
		starts = [float(r.boss_cells[0].x), float(r.boss_cells[1].x)]
	for i in range(2):
		th.append({"i": i, "x": starts[i], "y": Boss.FLOOR, "hp": float(each), "max": each, "dead": false, "flash": 0.0, "stun": 0.0, "face": 1.0 if i == 0 else -1.0})
	_sums()

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["corrupt"]

func _sums() -> void:
	var tot := 0.0
	var mx := 0
	for q in th:
		tot += maxf(0.0, q.hp)
		mx += int(q.max)
	hpf = tot
	hp = ceili(tot)
	max_hp = mx

func scale_hp(k: float) -> void:
	for q in th:
		q.max = roundi(q.max * k)
		q.hp = float(q.max)
	_sums()

func alive() -> Array:
	return th.filter(func(q): return not q.dead)

func _big() -> int:
	return int(Game.dv("big_hit"))

func _phase_now() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.25 else (2 if f <= 0.60 else 1)

func _enr() -> float:
	return 0.85 if alive().size() == 1 else 1.0

func _rec(base: float) -> float:
	return maxf(0.5, base - (0.1 if alive().size() == 1 else 0.0))

# ---- boxes ----
func hurtboxes() -> Array:
	var b: Array = []
	for q in th:
		if not q.dead:
			b.append({"x": q.x - 8.0, "y": q.y - 24.0, "w": 16.0, "h": 24.0, "head": q.i})
	b.append({"x": LOCK.x, "y": LOCK.y, "w": LOCK.w, "h": LOCK.h, "lock": true})
	return b

func _seg_of(px: float) -> int:
	return clampi(floori((px - SEG_X0) / SEG_W), 0, SEG_N - 1)

func _write_box(i: int) -> Dictionary:
	var dmg := 1
	if gx[0] >= 0.0 and gx[1] >= 0.0 and _seg_of(gx[0]) == _seg_of(gx[1]):
		dmg = _big()                                       # both ghosts in one segment: a collision write
	return {"x": gx[i] - 16.0, "y": Boss.FLOOR - 40.0, "w": 32.0, "h": 40.0, "dmg": dmg}

func _act_total() -> float:
	return 2.0 * WRITE_T

func _el() -> float:
	return _act_total() - float(plan.t)              # seconds into the active phase

func harmboxes() -> Array:
	var b: Array = []
	if plan_active():
		match String(plan.id):
			"rw":
				var el := _el()
				for i in range(2):
					if gx[i] >= 0.0 and el >= float(i) * WRITE_T and el < float(i) * WRITE_T + WRITE_T:
						b.append(_write_box(i))
			"switch":
				for i in range(2):
					b.append({"x": sw[i * 2] - 14.0, "y": sw[i * 2 + 1] - 30.0, "w": 28.0, "h": 34.0})
			"contend":
				for q in th:
					if not q.dead and q.stun <= 0.0:
						b.append({"x": q.x - 9.0, "y": q.y - 26.0, "w": 18.0, "h": 28.0})
	b.append_array(hz_harm())
	return b

# ---- the arena hazard: a corrupt segment ----
func hz_boxes(h: Dictionary, now: float) -> Array:
	var el := now - float(h.t0) - float(h.warn)
	if el > CORRUPT_T:
		return []
	var s := clampi(int(h.v[0]), 0, SEG_N - 1)
	return [{"x": SEG_X0 + float(s) * SEG_W, "y": Boss.FLOOR - 6.0, "w": SEG_W, "h": 6.0, "dmg": 1}]

func _hz_expired(h: Dictionary, now: float) -> bool:
	return now - float(h.t0) - float(h.warn) > CORRUPT_T + 0.3

func _corrupt_n() -> int:
	return hz.size()

# ---- damage ----
func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	if d >= 9999:                                             # "skip boss": both threads at once
		for c in th:
			c.hp = 0.0
			c.dead = true
		_sums()
		hpf = 0.0
		hp = 0
		begin_death()
		return "kill"
	if box is Dictionary and box.has("lock"):
		return _lock_hit()
	var q = null
	if box is Dictionary and box.has("head"):
		q = th[int(box.head)]
	else:
		var more = null
		for c in th:
			if not c.dead and (more == null or c.hp > more.hp):
				more = c
		q = more
	if q == null or q.dead:
		return ""
	var dm := float(d)
	if how == "agent" or how == "dash":
		dm *= 0.5
	q.hp -= dm
	q.flash = 0.1
	_sums()
	room.burst(q.x, q.y - 12.0, 6, [COL[q.i], "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	room.boss_damage(self, dm, how)
	var key := kit_key_of(room.attacker)
	if read != null and key != "":
		read.note_hit(key, how)
	if q.hp <= 0.0:
		q.hp = 0.0
		q.dead = true
		_sums()
		room.explode(q.x, q.y - 12.0, 22.0, ["#ffffff", COL_HI[q.i], COL[q.i]])
		room.shake(0.7)
		room.stop(0.2)
		Audio.sfx("explode")
		if alive().is_empty():
			hpf = 0.0
			hp = 0
			begin_death()
			return "kill"
		room.pop(q.x, q.y - 40.0, "thread %s joined" % ("A" if q.i == 0 else "B"), COL_HI[q.i], true)
		plan_cut()
		idle_t = 0.9
		return "kill"
	on_damage()
	return "hit"

func on_damage() -> void:
	var p := _phase_now()
	if p != phase_mem:
		phase_mem = p
		phase = p
		room.shake(0.5)
		Audio.sfx("roar", {"vol": 0.7})

func _lock_hit() -> String:
	if lock_cd > 0.0 or serial_t > 0.0:
		Audio.sfx("clang", {"vol": 0.5})
		return "block"
	serial_t = SERIAL_T
	hz.clear()                                                # every corrupt segment clears
	room.pop(LOCK_C.x, LOCK_C.y - 12.0, "mutex.lock()", "#ffd23f", true)
	room.ring(LOCK_C.x, LOCK_C.y, 3, 26, "#ffd23f", 0.4)
	Audio.sfx("gate")
	room.shake(0.3)
	return "hit"

func begin_death() -> void:
	super.begin_death()
	hz.clear()

func start() -> void:
	super.start()
	idle_t = 1.0
	phase_mem = _phase_now()

# ---- rule 8: who moved least in the last second (host) ----
func _track(dt: float) -> void:
	mv_acc += dt
	if mv_acc < 0.1:
		return
	mv_acc = 0.0
	for key in ["p1", "p2"]:
		var q = kit_body(key)
		var s: Array = moved_samples[key]
		if q == null or q.dead:
			s.clear()
			continue
		s.append(Vector2(q.x, q.y))
		while s.size() > 11:
			s.pop_front()

func _moved(key: String) -> float:
	var s: Array = moved_samples[key]
	var tot := 0.0
	for i in range(1, s.size()):
		tot += absf(s[i].x - s[i - 1].x) + absf(s[i].y - s[i - 1].y)
	return tot

func _least_moved() -> String:
	var keys := kit_keys()
	if keys.is_empty():
		return kit_pick_target()
	var best: String = keys[0]
	for k in keys:
		if _moved(k) < _moved(best) - 0.5:
			best = k
	return best

# ---- the brain ----
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	for q in th:
		if q.flash > 0.0:
			q.flash -= dt
	if dying:
		death_rattle(dt, 2.4, ["#ffffff", COL[0], COL[1]])
		return
	if not active:
		_idle_pose(dt, 0.0)
		return
	_track(dt)
	phase = _phase_now()
	hz = hz.filter(func(h): return not _hz_expired(h, room.time))
	if serial_t > 0.0:
		serial_t -= dt
		if serial_t <= 0.0:
			lock_cd = LOCK_CD
			hz.clear()
	elif lock_cd > 0.0:
		lock_cd -= dt
	var stunned := false
	for q in th:
		if q.stun > 0.0:
			q.stun -= dt
			stunned = true
	if plan.is_empty():
		plan_clock += dt
		idle_t -= dt
		_idle_pose(dt, WALK)
		if idle_t <= 0.0 and not stunned:
			_choose()
	else:
		_plan_logic(dt)
	var mx := 0.0
	var al := alive()
	for q in al:
		mx += q.x
	if not al.is_empty():
		x = mx / float(al.size()) - w / 2.0
		y = Boss.FLOOR - h

func _idle_pose(dt: float, spd: float) -> void:
	for q in th:
		if q.dead:
			continue
		var home: float = HOMES[q.i]
		if alive().size() == 1:
			home = 192.0 + (-60.0 if q.i == 0 else 60.0)
		var d: float = home - q.x
		if spd > 0.0 and absf(d) > 2.0 and q.stun <= 0.0:
			q.x += clampf(d, -spd * dt, spd * dt)
			q.face = Game.sign_of(d)
		q.y = Boss.FLOOR

func _choose() -> void:
	var ph := _phase_now()
	var seq: Array = SEQ3 if ph == 3 else (SEQ2 if ph == 2 else SEQ1)
	var id: String = seq[cycle % seq.size()]
	cycle += 1
	if (id == "switch" or id == "contend") and alive().size() < 2:
		id = "rw"                                              # a lone thread cannot swap with itself
	_start(id)
	if cycle % seq.size() == 0:
		idle_t = 1.2                                           # the short pause after each round
	else:
		idle_t = 0.3

func _start(id: String) -> void:
	var tgt := _least_moved()
	match id:
		"rw":
			gx = [-1.0, -1.0]
			wrote = [false, false]
			part_ghost_b = false
			var a_i := 0
			if serial_t > 0.0:
				a_i = ser_turn                              # one thread at a time
				ser_turn = 1 - ser_turn
			elif th[0].dead:
				a_i = 1
			if th[a_i].dead:
				a_i = 1 - a_i
			gx[a_i] = clampf(kit_aim(tgt).x, ARENA_L, ARENA_R)
			var single: bool = serial_t > 0.0 or alive().size() == 1
			if single:
				part_ghost_b = true                         # (no second ghost to read)
			var rec: float = _rec(0.7) + (0.7 if serial_t > 0.0 else 0.0)
			plan_start("rw", "slam", tgt, [gx[a_i] - 16.0, Boss.FLOOR - 40.0, 32.0, 40.0], 0.0, 0.9 * _enr(), rec, _act_total())
			plan["a_i"] = a_i
		"switch":
			sw = [th[1].x, th[1].y, th[0].x, th[0].y]
			plan_start("switch", "slam", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6 * _enr(), _rec(0.7), 0.3)
		"contend":
			for q in th:
				var ex: float = clampf(LOCK_C.x * 2.0 - q.x, ARENA_L, ARENA_R)
				dsh[q.i] = [q.x, q.y, ex, 0.0]
			plan_start("contend", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.7 * _enr(), _rec(0.8), 0.6)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _plan_logic(dt: float) -> void:
	var pid := String(plan.id)
	for q in th:
		if not q.dead:
			q.y = Boss.FLOOR if pid != "contend" else q.y
	# B reads 0.3 s after A: its ghost is where its target is at that moment
	if pid == "rw" and plan.ph == "cue" and not part_ghost_b:
		var ct: float = float(plan.t)
		var cue_total: float = 0.9 * _enr() * _tm()
		if cue_total - ct >= WRITE_T:
			part_ghost_b = true
			var a_i: int = int(plan.get("a_i", 0))
			var b_i := 1 - a_i
			if not th[b_i].dead:
				var keys := kit_keys()
				var key: String = String(plan.tgt)
				if keys.size() >= 2:
					key = "p2" if String(plan.tgt) == "p1" else "p1"
				gx[b_i] = clampf(kit_aim(key).x, ARENA_L, ARENA_R)
				plan.fp = [gx[a_i] - 16.0, Boss.FLOOR - 40.0, 32.0, 40.0]
	if pid == "contend" and plan.ph == "active":
		var f := clampf(_el_c(), 0.0, 1.0)
		for q in th:
			if q.dead or q.stun > 0.0:
				continue
			var d: Array = dsh[q.i]
			var mid := LOCK_C
			# start -> the lock -> the far side
			var p := Vector2.ZERO
			if f < 0.5:
				p = Vector2(d[0], d[1]).lerp(mid + Vector2(0.0, 24.0), f * 2.0)
			else:
				p = (mid + Vector2(0.0, 24.0)).lerp(Vector2(d[2], Boss.FLOOR), (f - 0.5) * 2.0)
			q.x = p.x
			q.y = p.y
		if not th[0].dead and not th[1].dead and Vector2(th[0].x - th[1].x, th[0].y - th[1].y).length() < 24.0 and f > 0.05:
			for q in th:
				q.stun = 2.0
			room.pop((th[0].x + th[1].x) / 2.0, th[0].y - 40.0, "deadlock", "#ffd23f", true)
			room.shake(0.5)
			Audio.sfx("thud")
			plan_cut()
			idle_t = 2.0
	var ev := plan_step(dt)
	match ev:
		"active":
			strike_sid = Game.next_strike_id()
			match pid:
				"rw":
					wrote = [false, false]
					Audio.sfx("thud", {"vol": 0.6})
				"switch":
					var oa: Array = [th[0].x, th[0].y, th[1].x, th[1].y]
					th[0].x = sw[0]
					th[0].y = sw[1]
					th[1].x = sw[2]
					th[1].y = sw[3]
					room.dust(oa[0], oa[1], 6)
					room.dust(oa[2], oa[3], 6)
					Audio.sfx("dash", {"vol": 0.7})
				"contend":
					Audio.sfx("dash", {"vol": 0.7})
		"recover":
			strike_sid = 0
			for q in th:
				q.y = Boss.FLOOR
		"done":
			strike_sid = 0
			for q in th:
				q.y = Boss.FLOOR
			gx = [-1.0, -1.0]
	if pid == "rw" and plan_active():
		var el := _el()
		for i in range(2):
			if gx[i] >= 0.0 and not wrote[i] and el >= float(i) * WRITE_T:
				wrote[i] = true
				_paint(i, gx[i])
				room.shake(0.2)
				room.dust(gx[i], Boss.FLOOR, 8)

func _el_c() -> float:
	return 1.0 - float(plan.t) / 0.6

# a write paints its segment with its thread's colour; both threads within 4 s = corrupt
func _paint(i: int, px: float) -> void:
	var s := _seg_of(px)
	seg_t[i][s] = room.time
	var o := 1 - i
	if serial_t > 0.0:
		return
	if room.time - float(seg_t[o][s]) <= PAINT_WINDOW and _corrupt_n() < 4:
		for h in hz:
			if int(h.v[0]) == s:
				return
		hz_add("corrupt", CORRUPT_WARN, [s])
		room.pop(SEG_X0 + (float(s) + 0.5) * SEG_W, Boss.FLOOR - 24.0, "corrupt", "#ff4f6d", true)

# ---- drawing ----
func _draw_thread(ci: CanvasItem, q: Dictionary) -> void:
	var ink := Color("#1b1226")
	var bx := floorf(q.x - 8.0)
	var by := floorf(q.y - 24.0)
	var c := Color(COL[q.i])
	var c_hi := Color(COL_HI[q.i])
	var c_lo := Color(COL_LO[q.i])
	var wob := 0.0
	if q.stun > 0.0:
		wob = sin(t * 30.0) * 1.0
	ci.draw_rect(Rect2(bx - 1.0 + wob, by - 1.0, 18.0, 26.0), ink)
	ci.draw_rect(Rect2(bx + wob, by, 16.0, 24.0), c if q.flash <= 0.0 else Color.WHITE)
	ci.draw_rect(Rect2(bx + wob, by, 16.0, 3.0), c_hi)
	ci.draw_rect(Rect2(bx + wob, by + 21.0, 16.0, 3.0), c_lo)
	# a spool of thread for a head and two eyes
	var ex: float = bx + (9.0 if q.face > 0.0 else 3.0)
	ci.draw_rect(Rect2(ex + wob, by + 6.0, 4.0, 4.0), Color.WHITE)
	ci.draw_rect(Rect2(ex + 1.0 + wob + (1.0 if q.face > 0.0 else 0.0), by + 7.0, 2.0, 2.0), ink)
	for k in range(3):
		ci.draw_rect(Rect2(bx + 2.0 + wob, by + 12.0 + float(k) * 3.0, 12.0, 1.0), c_lo)
	PixelText.draw_text(ci, "A" if q.i == 0 else "B", bx + 8.0, by - 10.0, COL[q.i], {"align": "c", "tiny": true, "outline": "#1b1226"})
	var frac := clampf(float(q.hp) / maxf(1.0, float(q.max)), 0.0, 1.0)
	ci.draw_rect(Rect2(bx - 2.0, by - 5.0, 20.0, 3.0), ink)
	ci.draw_rect(Rect2(bx - 1.0, by - 4.0, 18.0 * frac, 1.0), c_hi)
	if alive().size() == 1:
		ci.draw_rect(Rect2(bx - 2.0, by - 2.0, 20.0, 1.0), Color(1.0, 0.31, 0.43, 0.5 + 0.4 * sin(t * 12.0)))
	if q.stun > 0.0:
		for k in range(3):
			var a: float = t * 6.0 + float(k) * TAU / 3.0
			ci.draw_rect(Rect2(bx + 8.0 + cos(a) * 9.0, by - 14.0 + sin(a) * 3.0, 2.0, 2.0), Color("#ffd23f"))

func _draw_floor(ci: CanvasItem) -> void:
	var ink := Color("#1b1226")
	for s in range(SEG_N):
		var sx: float = SEG_X0 + float(s) * SEG_W
		var age_a: float = room.time - float(seg_t[0][s])
		var age_b: float = room.time - float(seg_t[1][s])
		var pa: bool = age_a <= PAINT_WINDOW
		var pb: bool = age_b <= PAINT_WINDOW
		var cc := Color(0, 0, 0, 0)
		if pa and pb:
			cc = Color(0.8, 0.4, 0.8, 0.55)
		elif pa:
			cc = Color(COL[0]).lerp(Color(0, 0, 0, 0), clampf(age_a / PAINT_WINDOW, 0.0, 1.0) * 0.6)
			cc.a = 0.55 * (1.0 - age_a / PAINT_WINDOW) + 0.1
		elif pb:
			cc = Color(COL[1])
			cc.a = 0.55 * (1.0 - age_b / PAINT_WINDOW) + 0.1
		if cc.a > 0.0:
			ci.draw_rect(Rect2(sx, Boss.FLOOR - 3.0, SEG_W, 3.0), cc)
		ci.draw_rect(Rect2(sx, Boss.FLOOR - 1.0, 1.0, 1.0), Color(1, 1, 1, 0.3))
	for h in hz:
		var s2 := clampi(int(h.v[0]), 0, SEG_N - 1)
		var sx2: float = SEG_X0 + float(s2) * SEG_W
		if not hz_live(h, room.time):                          # the warning: the segment glitches
			var glitch := int(t * 14.0) % 2 == 0
			ci.draw_rect(Rect2(sx2, Boss.FLOOR - 6.0, SEG_W, 6.0), Color(1.0, 0.31, 0.43, 0.25 if glitch else 0.45), false, 1.0)
			ci.draw_rect(Rect2(sx2 + 4.0, Boss.FLOOR - 4.0, SEG_W - 8.0, 2.0), Color(1.0, 0.31, 0.43, 0.35))
		else:
			ci.draw_rect(Rect2(sx2, Boss.FLOOR - 6.0, SEG_W, 6.0), Color(0.95, 0.2, 0.5, 0.85))
			for k in range(6):
				var gxp: float = sx2 + 2.0 + float(k) * 8.0 + sin(t * 20.0 + float(k)) * 2.0
				ci.draw_rect(Rect2(gxp, Boss.FLOOR - 6.0 + float((k * 5) % 3) * 2.0, 6.0, 2.0), Color("#ffd0e8"))

func _draw_lock(ci: CanvasItem) -> void:
	var ink := Color("#1b1226")
	var lx: float = LOCK.x
	var ly: float = LOCK.y
	var cd_frac := clampf(lock_cd / LOCK_CD, 0.0, 1.0)
	ci.draw_rect(Rect2(lx - 1.0, ly - 1.0, 14.0, 16.0), ink)
	var body_c := Color("#ffd23f") if (lock_cd <= 0.0 and serial_t <= 0.0) else (Color("#7fd08a") if serial_t > 0.0 else Color("#6b6478"))
	ci.draw_rect(Rect2(lx, ly, 12.0, 14.0), body_c)
	ci.draw_rect(Rect2(lx + 3.0, ly - 5.0, 6.0, 5.0), ink)
	ci.draw_rect(Rect2(lx + 4.0, ly - 4.0, 4.0, 4.0), Color(0, 0, 0, 0))
	ci.draw_rect(Rect2(lx + 5.0, ly + 5.0, 2.0, 4.0), ink)
	if lock_cd > 0.0:
		ci.draw_rect(Rect2(lx, ly + 15.0, 12.0 * cd_frac, 2.0), Color("#8d8798"))
	if serial_t > 0.0:
		ci.draw_rect(Rect2(lx, ly + 15.0, 12.0 * clampf(serial_t / SERIAL_T, 0.0, 1.0), 2.0), Color("#7fd08a"))
		PixelText.draw_text(ci, "serial", lx + 6.0, ly - 12.0, "#7fd08a", {"align": "c", "tiny": true, "outline": "#1b1226"})

func draw_boss_body(ci: CanvasItem) -> void:
	_draw_floor(ci)
	_draw_lock(ci)
	if dying and gone:
		return
	for q in th:
		if not q.dead:
			_draw_thread(ci, q)
	if plan_active():
		match String(plan.id):
			"rw", "switch", "contend":
				for hb in harmboxes():
					if hb.h > 20.0 and not hb.has("sid"):
						ci.draw_rect(Rect2(hb.x, hb.y, hb.w, hb.h), Color(1.0, 0.31, 0.43, 0.5))
						ci.draw_rect(Rect2(hb.x, hb.y, hb.w, 2.0), Color("#ffd0d8"))

func _hatch(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var hot := int(t * 12.0) % 2 == 0
	var c1 := Color(Game.COL.hazardHi) if hot else Color(Game.COL.hazard)
	ci.draw_rect(r, Color(c.r, c.g, c.b, 0.18))
	var yy := 0.0
	while yy < r.size.y:
		ci.draw_rect(Rect2(r.position.x, r.position.y + yy, r.size.x, 1), Color(c1.r, c1.g, c1.b, 0.7))
		yy += 4.0
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), c1)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c1)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), c1)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c1)

func draw_boss_overlay(ci: CanvasItem) -> void:
	if plan.is_empty():
		return
	if plan.ph == "cue":
		match String(plan.id):
			"rw":
				for i in range(2):
					if gx[i] >= 0.0:
						var gc := Color(COL[i])
						var r := Rect2(gx[i] - 16.0, Boss.FLOOR - 40.0, 32.0, 40.0)
						_hatch(ci, r, gc)
						ci.draw_rect(Rect2(gx[i] - 5.0, Boss.FLOOR - 30.0, 10.0, 22.0), Color(gc.r, gc.g, gc.b, 0.35))   # a ghost of the player
						PixelText.draw_text(ci, "read", gx[i], Boss.FLOOR - 52.0, COL[i], {"align": "c", "tiny": true, "outline": "#1b1226"})
				_target_marker(ci, String(plan.tgt))
			"switch":
				for i in range(2):
					var ax: float = sw[i * 2]
					var ay: float = sw[i * 2 + 1]
					_hatch(ci, Rect2(ax - 14.0, ay - 30.0, 28.0, 34.0), Color(COL[i]))
					PixelText.draw_text(ci, "ctx", ax, ay - 42.0, COL[i], {"align": "c", "tiny": true, "outline": "#1b1226"})
			"contend":
				for i in range(2):
					var d: Array = dsh[i]
					var mid := LOCK_C + Vector2(0.0, 24.0)
					var cc := Color(COL[i])
					ci.draw_line(Vector2(d[0], d[1] - 12.0), mid, Color(cc.r, cc.g, cc.b, 0.8), 2.0)
					ci.draw_line(mid, Vector2(d[2], Boss.FLOOR - 12.0), Color(cc.r, cc.g, cc.b, 0.8), 2.0)
				PixelText.draw_text(ci, "lock()", LOCK_C.x, LOCK_C.y - 22.0, "#ffd23f", {"align": "c", "tiny": true, "outline": "#1b1226"})
	elif plan.ph == "active" and String(plan.id) == "rw":
		pass

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid,
		roundi(th[0].x * 4.0), roundi(th[0].y * 4.0), roundi(th[1].x * 4.0), roundi(th[1].y * 4.0),
		roundi(th[0].hp * 10.0), roundi(th[1].hp * 10.0), 1 if th[0].dead else 0, 1 if th[1].dead else 0,
		roundi(gx[0]), roundi(gx[1]), roundi(maxf(th[0].stun, 0.0) * 100.0), roundi(maxf(th[1].stun, 0.0) * 100.0),
		roundi(maxf(lock_cd, 0.0) * 10.0), roundi(maxf(serial_t, 0.0) * 10.0), int(round(th[0].face)), int(round(th[1].face)),
		roundi(sw[0]), roundi(sw[1]), roundi(sw[2]), roundi(sw[3]),
		roundi(dsh[0][0]), roundi(dsh[0][1]), roundi(dsh[0][2]), roundi(dsh[1][0]), roundi(dsh[1][1]), roundi(dsh[1][2]), int(plan.get("a_i", 0))]
	var segs: Array = []
	for s in range(SEG_N):
		segs.append(roundi(float(seg_t[0][s]) * 10.0))
		segs.append(roundi(float(seg_t[1][s]) * 10.0))
	f.append(segs)
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 31

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	strike_sid = int(f[3])
	th[0].x = f[4] / 4.0
	th[0].y = f[5] / 4.0
	th[1].x = f[6] / 4.0
	th[1].y = f[7] / 4.0
	th[0].hp = f[8] / 10.0
	th[1].hp = f[9] / 10.0
	th[0].dead = int(f[10]) == 1
	th[1].dead = int(f[11]) == 1
	gx = [float(f[12]), float(f[13])]
	th[0].stun = f[14] / 100.0
	th[1].stun = f[15] / 100.0
	lock_cd = f[16] / 10.0
	serial_t = f[17] / 10.0
	th[0].face = float(f[18])
	th[1].face = float(f[19])
	sw = [float(f[20]), float(f[21]), float(f[22]), float(f[23])]
	dsh = [[float(f[24]), float(f[25]), float(f[26]), 0.0], [float(f[27]), float(f[28]), float(f[29]), 0.0]]
	var segs: Array = f[NF]
	for s in range(SEG_N):
		seg_t[0][s] = float(segs[s * 2]) / 10.0
		seg_t[1][s] = float(segs[s * 2 + 1]) / 10.0
	phase = _phase_now()
	plan_apply(f.slice(NF + 1, NF + 12))
	if not plan.is_empty():
		plan["a_i"] = int(f[30])
	hz_unpack(f[NF + 12] if f.size() > NF + 12 else [])
	for q in th:
		q.max = maxi(ceili(float(max_hp) / 2.0), 1)
	x = (th[0].x + th[1].x) / 2.0 - w / 2.0
	y = Boss.FLOOR - h

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	for q in th:
		if q.flash > 0.0:
			q.flash -= dt
		if q.stun > 0.0:
			q.stun -= dt
	if lock_cd > 0.0:
		lock_cd -= dt
	if serial_t > 0.0:
		serial_t -= dt
