class_name RaceBoss
extends Boss
# RACE CONDITION v3 (T06): TICK (red, slim, reads where you are GOING) and TOCK (cyan, bearded, reads where you WERE), two bronze bell-strikers that attack at the
# same time (docs/metroidvania/17-race-build.md, 17-race-condition.md). A kit boss with two concurrent plans: each automaton has its own plan (cue, active,
# recover), a plan is state (it travels in net_fields), the guest is hurt only by what it was shown, and the arena (BelfryHall) is the room's.
# Everything is read from the bodies and the bells, never from a marker: the eye light and its thin beam to the READ point, a faint afterimage of the target,
# the raised hammer, the glowing bell. Hits go to the automaton whose hurtbox was struck; the pair shares one fight with two HP bars.
# The signature is the double write: both read the same point, both raise hammers; stay and it is 2 damage, leave late and the hammers clash (both dazed 2 s).

const IDS := ["strike", "slam", "double", "clapper", "rope", "switch", "drop", "triple", "combo"]
const COL := ["#ff4a3a", "#2ee6d6"]
const COL_HI := ["#ffb4ac", "#b6fff7"]
const NAMES := ["TICK", "TOCK"]
const SPLIT := 0.4                                   # TICK's share of the total hp

const ARENA_L := 24.0
const ARENA_R := 392.0
const FLOOR_Y := 432.0
const BODY_W := 28.0
const BODY_H := 46.0
const NEAR_PX := 96.0                                # six tiles: nearer, the attacks are the close ones

# [cue in beats, active s, recover s] per plan; a beat is half a tick (0.35 s in phase 1)
const PLANS := {
	"strike": [2, 0.5, 0.3],
	"slam": [2, 0.45, 0.5],
	"clapper": [2, 0.15, 0.4],
	"rope": [2, 0.5, 0.3],
	"double": [3, 0.5, 0.5],
	"switch": [2, 0.8, 0.3],
	"drop": [3, 0.6, 0.8],
	"triple": [2, 1.4, 0.8],
	"combo": [2, 0.8, 0.0],
}
const DIVE_T := 0.25                                 # a slam's / the double write's dive, then its box on the landing
const RING_R := 80.0
const HOP_T := 0.45
const CROUCH_T := 0.25
const GAP_MIN := 0.3
const GAP_MAX := 0.4
const STAGGER := 0.15                                # two single strikes of different automata do not land within this
const DAZE_CAUGHT := 0.7                             # a caught clapper that comes back hurts TOCK and dazes it
const CLASH_DAZE := 2.0                              # the hammers clash: both dazed, the one big punish
const GUARD_K := 0.8                                 # the cue of a normal plan while the partner is vulnerable
const CHECK_T := 0.30                                # the double write checks its target this long before the strike
const SPLIT_PX := 32.0                               # the target is further than this from the read point at the check: the strikes land apart
const BOX_W := 40.0                                  # the double write's strike box
const LOCK_SERIAL := [3.0, 2.5]                      # the escapement lock: the two take turns for this long (phase 1, phase 2)
const LOCK_CD := 12.0
const RING_CD := 1.5                                 # a player rings a bell: per-bell cooldown
const TRANS_T := 2.0                                 # phase 2's transition: both invulnerable
const ALONE_K := 0.85                                # the survivor's cues (normal plans only)
const REWIND_AT := 15.0                              # the survivor tries to rewind its partner this long after it went down
const REWIND_T := 2.0
const REWIND_RETRY := 6.0                            # ... and again this long after it was hurt while winding
const REWIND_HP := 0.3
const SWITCH_RING := 48.0
const TRIPLE_RING_T := 0.5
const HOLE_BOTTOM_Y := 458.0
const DOUBLE_NEED := [3, 4]                          # plans each before the next double write (after the first: one each)

var th: Array = []
var ph := 1                                          # 1 / 2 (phase 2: M4)
var trans_t0 := -1.0
var intro_t0 := -1.0
var say_k := 0                                       # which line plays (0 none, 1 intro, 2 p2, 3 alone, 4 die)
var say_t0 := -1.0
var die_t0 := -1.0
var clash_t0 := -100.0                               # the last clash (sparks, both pages)
var clash_pt := Vector2.ZERO
var serial_turn := 0                                 # serialized by the lock: whose turn it is to start a plan
var say_who := 0                                     # whose line (the survivor's `alone`)
var rewind_t0 := -1.0                                # the survivor kneels from this room time (2.0 s of winding)
var rw_at := -1.0                                    # host: when the survivor tries to rewind its partner
var pending_alone := -1                              # the survivor whose line plays when the transition is over
var p2_flags := {"drop": false, "triple": false}     # phase 2's teaching order: switch, TOCK's drop, TICK's triple
var hist := {"p1": [], "p2": []}                     # host: the last second of each player's centre, for the prefetch and the least-moved read
var hsamp: Array = [[], []]                          # guest: snapshot samples of each body
var pseen := {}                                      # guest: plan seq -> the phase it was first seen in

func _init(r: Room, bx: float, by: float, base_hp := 90) -> void:
	super(r, bx, by, 32, 48, base_hp)
	boss_name = "RACE CONDITION"
	sub = "two threads, one variable"
	col = COL[0]
	for i in range(2):
		th.append(_mk(i))
	_split_hp(base_hp)
	_to_bells()

func _mk(i: int) -> Dictionary:
	return {"i": i, "x": 0.0, "y": FLOOR_Y, "face": 1.0 if i == 0 else -1.0, "hp": 1.0, "max": 1, "st": 0, "mode": "idle", "mt": 0.0, "gap": 1.0,
		"hop": {}, "plan": {}, "last": "", "tgt": "p1" if i == 0 else "p2", "hammer": 0, "daze_until": -1.0, "eye": false, "dial": i * 6, "bell": -1, "ox": 0.0,
		"dest": -1, "dbell": -1, "dx": 0.0, "dy": FLOOR_Y, "next": "", "flash": 0.0, "n": 0, "start_at": 0.0, "rx": 0.0, "ry": 0.0, "since": 0, "need": 1, "wait_t": 0.0, "swsince": 0, "swneed": 0, "air": false}

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["ring", "slambox", "clapper", "rope", "bellfall", "corrupt", "hole"]

func _hall() -> BelfryHall:
	return room.belfry

func _big() -> int:
	return int(Game.dv("big_hit"))

func _split_hp(total: int) -> void:
	max_hp = total
	var a := roundi(SPLIT * float(total))
	th[0].max = a
	th[1].max = maxi(total - a, 1)
	th[0].hp = float(th[0].max)
	th[1].hp = float(th[1].max)
	_sums()

func _sums() -> void:
	hpf = maxf(0.0, th[0].hp) + maxf(0.0, th[1].hp)
	hp = ceili(hpf)

func scale_hp(k: float) -> void:
	_split_hp(roundi(max_hp * k))

func alive_list() -> Array:
	return th.filter(func(q): return q.st != 1)

func alive_n() -> int:
	return alive_list().size()

# the two stand frozen on the big bells (the intro wakes them)
func _to_bells() -> void:
	for i in range(2):
		var q: Dictionary = th[i]
		var b := 0 if i == 0 else 1
		var rc := BelfryHall.new_rest(b)
		q.bell = b
		q.ox = 0.0
		q.x = rc.position.x + rc.size.x * 0.5
		q.y = rc.position.y
		q.face = 1.0 if i == 0 else -1.0
		q.mode = "idle"
		q.plan = {}
		q.hop = {}
		q.hammer = 0
		q.eye = false

# ---------------------------------------------------------------- the beat (a half tick) and the clock
func _beat() -> float:
	var hl := _hall()
	return (hl.tick_len() if hl != null else BelfryHall.TICK_P1) * 0.5

func _next_beat(tm: float) -> float:
	var hl := _hall()
	if hl == null:
		return tm
	var s: Array = hl._seg_at(tm)
	var b := float(s[2]) * 0.5
	var k := ceili((tm - float(s[0])) / b - 0.000001)
	return float(s[0]) + float(k) * b

# ---------------------------------------------------------------- the players
func _track(_dt: float) -> void:
	for key in ["p1", "p2"]:
		var q = kit_body(key)
		var a: Array = hist[key]
		if q == null or q.dead:
			a.clear()
			continue
		a.append([room.time, q.x + q.w * 0.5, q.y + q.h * 0.5])
		while a.size() > 2 and room.time - float(a[0][0]) > 1.05:
			a.pop_front()

# the velocity of a player over the last 0.25 s
func _vel(key: String) -> Vector2:
	var a: Array = hist[key]
	if a.size() < 2:
		return Vector2.ZERO
	var last: Array = a[a.size() - 1]
	var first: Array = a[0]
	for s in a:
		if room.time - float(s[0]) <= 0.25:
			first = s
			break
	var dt_ := maxf(0.05, float(last[0]) - float(first[0]))
	return Vector2(float(last[1]) - float(first[1]), float(last[2]) - float(first[2])) / dt_

# how far a player moved in the last second (the double write reads the one that moved least)
func _moved(key: String) -> float:
	var a: Array = hist[key]
	if a.size() < 2:
		return 0.0
	var mx := 0.0
	var last: Array = a[a.size() - 1]
	for s in a:
		mx = maxf(mx, Vector2(float(s[1]) - float(last[1]), float(s[2]) - float(last[2])).length())
	return mx

# the READ point of an automaton: TOCK reads where the target IS (stale), TICK where it will be 0.5 s from now (prefetch), inside the room
func read_point(i: int, key: String, prefetch := true) -> Vector2:
	var p := kit_aim(key)
	if i == 0 and prefetch:
		p += _vel(key) * 0.5
	return Vector2(clampf(p.x, ARENA_L, ARENA_R), clampf(p.y, 40.0, FLOOR_Y - 6.0))

func _key_for(i: int) -> String:
	var keys := kit_keys()
	if keys.is_empty():
		return "p1" if room.mode != "guest" else "p2"
	var want: String = String(th[i].tgt)
	if keys.has(want):
		return want
	return keys[0]

# solo: the player; co-op: the one that moved least in the last second
func _double_key() -> String:
	var keys := kit_keys()
	if keys.is_empty():
		return "p1"
	var best: String = keys[0]
	for k in keys:
		if _moved(k) < _moved(best):
			best = k
	return best

# guard: the player nearest to the vulnerable partner
func _guard_key(i: int) -> String:
	var o: Dictionary = th[1 - i]
	var keys := kit_keys()
	if keys.is_empty():
		return _key_for(i)
	var best: String = keys[0]
	var bd := 1e9
	for k in keys:
		var q = kit_body(k)
		var d := Vector2(q.x + q.w * 0.5 - float(o.x), q.y + q.h * 0.5 - float(o.y)).length()
		if d < bd:
			bd = d
			best = k
	return best

func _vulnerable(q: Dictionary) -> bool:
	return q.st != 1 and (int(q.hammer) == 2 or room.time < float(q.daze_until) or q.st == 2)

# ---------------------------------------------------------------- hurt and harm boxes
func hurtboxes() -> Array:
	var b: Array = []
	for q in th:
		if q.st != 1:
			b.append({"x": q.x - BODY_W * 0.5, "y": q.y - BODY_H, "w": BODY_W, "h": BODY_H, "th": q.i})
	var hl := _hall()
	if hl != null and active and not dying:
		if hl.bob_hittable(room.time):
			var br := hl.bob_rect(room.time)
			b.append({"x": br.position.x, "y": br.position.y, "w": br.size.x, "h": br.size.y, "bob": true})
		for k in range(BelfryHall.N_BELLS):                      # a bell is something to ring: the one interrupt
			if hl.hanging(k, room.time) and hl.bell_mode(k, room.time) != "rehang":
				var bp := hl.bell_pose(k, room.time)
				b.append({"x": float(bp.x), "y": float(bp.y), "w": BelfryHall.new_rest(k).size.x, "h": 36.0, "bell": k})
	return b

func body_rect(i: int) -> Rect2:
	var q: Dictionary = th[i]
	return Rect2(q.x - BODY_W * 0.5, q.y - BODY_H, BODY_W, BODY_H)

# time into a plan's active phase
func _el(p: Dictionary) -> float:
	return float(p.act_len) - float(p.t)

# a ring wave's boxes: the band of a growing circle, on the points of its circumference (10 x 10 each); a fallen bell blocks it in phase 2
func ring_boxes(c: Vector2, r: float) -> Array:
	var out: Array = []
	if r < 1.0:
		return out
	var n := clampi(ceili(TAU * r / 9.0), 6, 56)
	var hl := _hall()
	for k in range(n):
		var a := TAU * float(k) / float(n)
		var pt := c + Vector2(cos(a), sin(a)) * r
		if pt.x < 8.0 or pt.x > float(room.pw) - 8.0 or pt.y > FLOOR_Y - 2.0 or pt.y < 16.0:
			continue
		if hl != null and hl.cover_between(c, pt, room.time):
			continue
		out.append({"x": pt.x - 5.0, "y": pt.y - 5.0, "w": 10.0, "h": 10.0, "dmg": 1})
	return out

func ring_center(p: Dictionary) -> Vector2:
	var b := int(p.bell)
	var hl := _hall()
	if b >= 0 and hl != null:
		var rc := BelfryHall.new_rest(b)
		return Vector2(rc.position.x + rc.size.x * 0.5 + hl.swing_dx(b, room.time), rc.position.y + 14.0)
	return Vector2(float(p.sx), float(p.sy) - 8.0)

func harmboxes() -> Array:
	var out: Array = []
	for q in th:
		var p: Dictionary = q.plan
		if p.is_empty() or p.ph != "active":
			continue
		match String(p.id):
			"strike":
				out.append_array(ring_boxes(ring_center(p), RING_R * clampf(_el(p) / float(p.act_len), 0.0, 1.0)))
			"slam":
				if _el(p) >= DIVE_T:
					out.append({"x": float(p.lx) - 16.0, "y": float(p.ly) - 48.0, "w": 32.0, "h": 48.0, "dmg": 1})
			"rope":
				var u := _el(p) / float(p.act_len)
				if u >= 0.25 and u <= 0.75:
					out.append({"x": q.x - 14.0, "y": q.y - 12.0, "w": 28.0, "h": 12.0, "dmg": 1})
			"switch", "combo":
				var ue := (_el(p) - 0.5) / 0.3
				if ue > 0.0:
					out.append_array(ring_boxes(Vector2(float(p.lx), float(p.ly) - 8.0), SWITCH_RING * clampf(ue, 0.0, 1.0)))
			"drop":
				var hl2 := _hall()
				if hl2 != null and int(p.bell) >= 0 and hl2.bell_mode(int(p.bell), room.time) == "fall":
					var fb2 := hl2.fall_box(int(p.bell), room.time)
					out.append({"x": fb2.position.x, "y": fb2.position.y, "w": fb2.size.x, "h": fb2.size.y, "dmg": _big()})
			"triple":
				var tb2: Array = p.get("tb", [-1, -1, -1])
				var bt: float = float(p.get("tbeat", 0.3))
				for k in range(3):
					var el_k: float = bt * float(k + 1)
					var ek := _el(p) - el_k
					if int(tb2[k]) >= 0 and ek >= 0.0 and ek < TRIPLE_RING_T:
						var rck := BelfryHall.new_rest(int(tb2[k]))
						out.append_array(ring_boxes(Vector2(rck.position.x + rck.size.x * 0.5, rck.position.y + 14.0), RING_R * ek / TRIPLE_RING_T))
			"double":
				if p.get("alone", false):
					var ea := _el(p)
					if ea >= 0.2 and ea < 0.3:
						out.append({"x": float(p.lx) - 16.0, "y": float(p.ly) - 48.0, "w": 32.0, "h": 48.0, "dmg": 1})
					elif ea >= 0.4 and ea < 0.5:
						out.append({"x": float(p.l2x) - 16.0, "y": float(p.l2y) - 48.0, "w": 32.0, "h": 48.0, "dmg": 1})
				elif _el(p) >= DIVE_T:
					if p.get("split", false):
						out.append({"x": float(p.lx) - 16.0, "y": float(p.ly) - 48.0, "w": 32.0, "h": 48.0, "dmg": 1})
					elif p.get("hit", false) and int(q.i) == 1:
						out.append({"x": float(p.rx) - BOX_W * 0.5, "y": float(p.ly) - 48.0, "w": BOX_W, "h": 48.0, "dmg": _big()})
	out.append_array(hz_harm())
	return out

# ---------------------------------------------------------------- the arena hazards (the floor layer): corrupt cells and the falling bell
func hz_boxes(h: Dictionary, now: float) -> Array:
	var hl := _hall()
	match String(h.k):
		"corrupt":
			var el := now - float(h.t0) - float(h.warn)
			if el > BelfryHall.CORRUPT_T:
				return []
			var c := clampi(int(h.v[0]), 0, BelfryHall.CELLS - 1)
			return [{"x": BelfryHall.CELL_X0 + float(c) * BelfryHall.CELL_W, "y": FLOOR_Y - 6.0, "w": BelfryHall.CELL_W, "h": 6.0, "dmg": 1}]
		"bellfall":
			if hl == null:
				return []
			var bi := clampi(int(h.v[0]), 0, BelfryHall.N_BELLS - 1)
			var el2 := now - float(h.t0) - float(h.warn)
			if el2 > hl.fall_time(bi) + 0.05:
				return []
			if hl.bell_mode(bi, now) != "fall":
				return []
			var fb := hl.fall_box(bi, now)
			return [{"x": fb.position.x, "y": fb.position.y, "w": fb.size.x, "h": fb.size.y, "dmg": _big()}]
		"hole":
			var el3 := now - float(h.t0) - float(h.warn)
			if el3 > BelfryHall.HOLE_T:
				return []
			var c3 := clampi(int(h.v[0]), 0, BelfryHall.CELLS - 1)
			return [{"x": BelfryHall.CELL_X0 + float(c3) * BelfryHall.CELL_W + 2.0, "y": HOLE_BOTTOM_Y, "w": BelfryHall.CELL_W - 4.0, "h": 6.0, "dmg": 1}]
	return []

func _hz_expired(h: Dictionary, now: float) -> bool:
	match String(h.k):
		"corrupt":
			return now - float(h.t0) - float(h.warn) > BelfryHall.CORRUPT_T + 0.3
		"bellfall":
			var hl := _hall()
			if hl == null:
				return true
			var bj := clampi(int(h.v[0]), 0, BelfryHall.N_BELLS - 1)
			if float(hl.fall_t0[bj]) < 0.0:
				return now - float(h.t0) > 6.0                          # (a chain still being rattled)
			return now - float(hl.fall_t0[bj]) > hl.fall_time(bj) + 0.3
		"hole":
			return now - float(h.t0) - float(h.warn) > BelfryHall.HOLE_T + 0.3
	return now - float(h.t0) > 12.0

func _has_hz(kind: String, v0: int, t0: float) -> bool:
	for h in hz:
		if h.k == kind and int(h.v[0]) == v0 and absf(float(h.t0) - t0) < 0.06:
			return true
	return false

# the floor layer follows the hall: a corrupt cell is a hazard with a 0.6 s build-up, a bell that cracked falls on whatever is under it after its rattle
func _sync_hazards() -> void:
	var hl := _hall()
	if hl == null:
		return
	hz = hz.filter(func(h): return not _hz_expired(h, room.time))
	for c in range(BelfryHall.CELLS):
		var t0: float = hl.corrupt_t0[c]
		if t0 >= 0.0 and hl.corrupt_state(c, room.time) > 0 and not _has_hz("corrupt", c, t0):
			var h := hz_add("corrupt", BelfryHall.CORRUPT_WARN, [c])
			h.t0 = snappedf(t0, 0.01)
	for b in range(BelfryHall.N_BELLS):
		var c0: float = hl.crack_t0[b]
		var f0: float = hl.fall_t0[b]
		if c0 >= 0.0 and (f0 < 0.0 or room.time < f0 + hl.fall_time(b) + 0.3) and not _has_hz("bellfall", b, c0):
			var h2 := hz_add("bellfall", BelfryHall.CRACK_T, [b])
			h2.t0 = snappedf(c0, 0.01)
	for c in range(BelfryHall.CELLS):
		var ht: float = hl.hole_t0[c]
		if ht >= 0.0 and hl.hole_state(c, room.time) > 0 and not _has_hz("hole", c, ht):
			var h3 := hz_add("hole", BelfryHall.CORRUPT_WARN, [c])
			h3.t0 = snappedf(ht, 0.01)

# ---------------------------------------------------------------- damage
func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying or (trans_t0 >= 0.0 and room.time - trans_t0 < 2.0):
		return ""
	if d >= 9999:                                             # "skip boss": both at once
		for q in th:
			q.hp = 0.0
			q.st = 1
		_sums()
		hpf = 0.0
		hp = 0
		begin_death()
		return "kill"
	if box is Dictionary and box.has("bob"):
		return _lock_hit()
	if box is Dictionary and box.has("bell"):
		var near := _body_near_attacker()
		if near < 0:
			return _ring_bell(int(box.bell))
		box = {"th": near}                                    # (the swing also reached an automaton: that is the hit)
	var i := -1
	if box is Dictionary and box.has("th"):
		i = int(box.th)
	else:
		var best := -1.0
		for q in th:
			if q.st != 1 and float(q.hp) > best:
				best = float(q.hp)
				i = int(q.i)
	if i < 0 or th[i].st == 1:
		return ""
	var q: Dictionary = th[i]
	var dm := float(d)
	if how == "agent" or how == "dash":
		dm *= 0.5
	q.hp -= dm
	q.flash = 0.1
	_sums()
	if q.st == 2 and q.hp > 0.0:
		_rewind_cancel(i)
	room.burst(q.x, q.y - 24.0, 6, [COL[i], "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	room.boss_damage(self, dm, how)
	if how == "catch" and i == 1:                              # the clapper came back: TOCK is dazed
		_daze(1, DAZE_CAUGHT)
	if q.hp <= 0.0:
		q.hp = 0.0
		_sums()
		_fall(i)
		if alive_n() == 0:
			hpf = 0.0
			hp = 0
			begin_death()
			return "kill"
		return "hit"
	on_damage()
	return "hit"

func on_damage() -> void:
	pass

# a swing that reached a bell and an automaton: the one near the attacker takes it
func _body_near_attacker() -> int:
	var att = room.attacker
	if att == null or not is_instance_valid(att):
		return -1
	var c := Vector2(att.x + att.w * 0.5, att.y + att.h * 0.5)
	for q in th:
		if q.st != 1 and body_rect(q.i).grow(26.0).has_point(c):
			return int(q.i)
	return -1

# a player rings a bell: a small swing, and the cue of an automaton on it (or within 40 px) is over: its plan goes straight to a 0.3 s recovery, no daze
func _ring_bell(b: int) -> String:
	var hl := _hall()
	if hl == null or room.time < float(hl.hit_cd[b]):
		return ""
	hl.hit_cd[b] = snappedf(room.time + RING_CD, 0.01)
	hl.strike(b, false)
	Audio.sfx("clang", {"vol": 0.5})
	var rc := BelfryHall.new_rest(b)
	for q in th:
		var p: Dictionary = q.plan
		if q.st == 1 or p.is_empty() or p.ph != "cue":
			continue
		var gap := maxf(maxf(rc.position.x - float(q.x), float(q.x) - (rc.position.x + rc.size.x)), 0.0)
		if (int(q.bell) == b or gap <= 40.0) and absf(float(q.y) - rc.position.y) <= 52.0:
			var pid: String = String(p.id)
			_cancel(int(q.i))
			if pid == "double":
				_cancel(1 - int(q.i))
	_sync_mirror()
	return "block"

func _cancel(i: int) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	if p.is_empty() or p.ph == "recover":
		return
	_abort_plan(q)
	p.ph = "recover"
	p.t = 0.3
	p.rec_len = 0.3
	q.eye = false
	q.hammer = 0
	q.air = false

# the lock: a hit on the escapement's bob catches it: the two take turns for 3 s (2.5 s in phase 2), every corrupt cell clears, then 12 s before it can be hit again
func _lock_hit() -> String:
	var hl := _hall()
	if hl == null or not hl.bob_hittable(room.time):
		return ""
	var t: float = room.time
	hl.serial_until = snappedf(t + float(LOCK_SERIAL[0 if ph == 1 else 1]), 0.01)
	hl.lock_cd_until = snappedf(t + LOCK_CD, 0.01)
	hl.clear_buffer()
	hz = hz.filter(func(h): return h.k != "corrupt" and h.k != "hole")
	serial_turn = 0
	for q in th:
		if not q.plan.is_empty() and q.plan.id == "double":
			_cancel(int(q.i))
	room.pop(BelfryHall.PIVOT.x, 100.0, "escapement.lock()", "#ffd23f", true)
	Audio.sfx("clang", {"vol": 1.0})
	Audio.sfx("gate", {"vol": 0.6})
	room.shake(0.35)
	return "hit"

func _daze(i: int, secs: float) -> void:
	var q: Dictionary = th[i]
	q.daze_until = room.time + secs
	q.hammer = 0
	q.air = false
	if not q.plan.is_empty():
		_abort_plan(q)
		if q.plan.id == "double":
			_cancel(1 - i)
		q.plan = {}
		q.mode = "idle"
		q.gap = 0.0
		q.eye = false
	_sync_mirror()

# an automaton at 0 hp winds down where it stands (M4: the survivor's alone / rewind logic)
func _fall(i: int) -> void:
	var q: Dictionary = th[i]
	if not q.plan.is_empty() and q.plan.id == "double":
		_cancel(1 - i)
	_abort_plan(q)
	q.st = 1
	q.plan = {}
	q.mode = "idle"
	q.eye = false
	q.hammer = 0
	q.air = false
	q.hop = {}
	var gy := _ground_at(q.x, q.y)
	q.y = gy.y
	q.bell = int(gy.bell)
	var o: Dictionary = th[1 - i]
	if o.st == 2:                                              # the survivor was winding its partner: not any more
		o.st = 0
		o.gap = 0.5
		rewind_t0 = -1.0
	if o.st == 0:
		rw_at = room.time + REWIND_AT
		pending_alone = 1 - i
	_sync_mirror()

func start() -> void:
	super.start()
	for q in th:
		q.gap = 0.8 + 0.4 * float(q.i)
		q.mode = "idle"
		q.eye = false
		q.since = 0
		q.need = 1
	Game.flags["intro:RACE"] = true                            # the long intro only once
	var hl := _hall()
	if hl != null and room.mode != "guest":
		hl.reset()
		hl.set_tick(BelfryHall.TICK_P1, room.time)

func intro_len() -> float:
	return 2.0 if Game.flag("intro:RACE") else 6.0

# ---------------------------------------------------------------- the intro (6.0 s the first time): the pan up to the escapement, the eyes, the line, the name card
func _step_intro(_dt: float) -> void:
	if intro_t0 < 0.0:
		intro_t0 = room.time
		_to_bells()
	var el := room.time - intro_t0
	if el >= 3.0:
		for q in th:
			q.eye = true
	if el >= 3.4 and say_k == 0 and intro_len() > 3.0:
		say_k = 1
		say_t0 = room.time

func intro_el() -> float:
	return room.time - intro_t0 if intro_t0 >= 0.0 else -1.0

# the camera: the long intro pans from the floor up over the bells to the escapement (0 .. 2.5 s) and holds; nothing after 3.0 s
func cam_lock_now():
	var el := intro_el()
	if el < 0.0 or room.fight.state != "intro" or intro_len() < 3.0 or el >= 3.0:
		return null
	var k := clampf(el / 2.5, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return {"x": (float(room.pw) - 384.0) * 0.5, "y": lerpf(float(room.ph) - 216.0, 0.0, k)}

func music_now(_want: String) -> String:
	if dying or room.fight.state == "intro":
		return ""
	return "boss" if ph == 1 else "boss_hi"                    # stand-ins until the pair has its own music

# ---------------------------------------------------------------- the fight (host)
func update(dt: float) -> void:
	tick(dt)
	for q in th:
		if q.flash > 0.0:
			q.flash -= dt
	_sync_hall()
	if dying:
		death_rattle(dt, 2.4, ["#ffffff", COL[0], COL[1]])
		return
	if not active:
		if room.fight.state == "intro":
			_step_intro(dt)
		_focus()
		return
	plan_clock += dt
	_track(dt)
	_sync_hazards()
	if ph == 1 and (hpf <= 0.5 * float(max_hp) or th[0].st == 1 or th[1].st == 1):
		_begin_trans()
	if trans_t0 >= 0.0 and room.time - trans_t0 < TRANS_T:
		for i in range(2):                                    # (the transition: both stand and heat up, nothing hurts and nothing can be hurt)
			if th[i].st != 1 and int(th[i].bell) >= 0:
				var sp := _stand(i)
				th[i].x = sp.x
				th[i].y = sp.y
		_focus()
		return
	if pending_alone >= 0:
		say_k = 3
		say_who = pending_alone
		say_t0 = room.time
		pending_alone = -1
	_rewind_watch()
	for i in range(2):
		_step_th(i, dt)
	_sync_mirror()
	_focus()

# at half the hp or when one falls: 2.0 s of heat, then phase 2 (tick 0.6, the bells stay down, holes, switch, drop, triple, combo)
func _begin_trans() -> void:
	var hl := _hall()
	ph = 2
	phase = 2
	trans_t0 = snappedf(room.time, 0.01)
	for q in th:
		_abort_plan(q)
		q.plan = {}
		q.mode = "idle"
		q.gap = TRANS_T + 0.6
		q.eye = false
		q.hammer = 0
		q.hop = {}
		q.daze_until = -1.0
		q.since = 0
		q.need = 1
		q.swsince = 0
		q.swneed = 0
		q.next = ""
		q.air = false
	p2_flags = {"drop": false, "triple": false}
	hz.clear()
	if hl != null and room.mode != "guest":
		hl.clear_buffer()
		hl.ph = 2
		hl.p2_t0 = trans_t0
		hl.set_tick(BelfryHall.TICK_P2, trans_t0 + TRANS_T)
	say_k = 2
	say_t0 = room.time
	Audio.sfx("roar", {"vol": 0.8})
	room.shake(0.8)
	Game.dlog("RACE CONDITION phase 2 (hp %.0f / %d, down %d)" % [hpf, max_hp, int(th[0].st == 1) + int(th[1].st == 1)])
	_sync_mirror()

# a plan that holds something in the room (the chain of a bell being dropped) lets go of it
func _abort_plan(q: Dictionary) -> void:
	var p: Dictionary = q.plan
	var hl := _hall()
	if p.is_empty() or hl == null:
		return
	if String(p.id) == "drop" and int(p.bell) >= 0 and float(hl.fall_t0[int(p.bell)]) < 0.0:
		hl.crack_t0[int(p.bell)] = BelfryHall.NONE_T

func _hot() -> float:
	if ph == 1:
		return 0.0
	if trans_t0 < 0.0:
		return 1.0
	var k := clampf((room.time - trans_t0) / 1.0, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

# ---------------------------------------------------------------- alone and the rewind
func _rewind_watch() -> void:
	if alive_n() != 1 or rw_at < 0.0 or room.time < rw_at:
		return
	for i in range(2):
		var q: Dictionary = th[i]
		if q.st == 0 and q.plan.is_empty() and String(q.mode) in ["idle", "wait"] and room.time >= float(q.daze_until):
			var o: Dictionary = th[1 - i]
			var side := 1.0 if float(o.x) < 208.0 else -1.0
			q.next = "rewind"
			q.dest = -1
			q.dx = clampf(float(o.x) + side * 30.0, ARENA_L, ARENA_R)
			q.dy = float(o.y)
			if int(o.bell) >= 0:
				q.dy = FLOOR_Y
				q.dx = clampf(float(o.x) + side * 50.0, ARENA_L, ARENA_R)
			q.mode = "crouch"
			q.mt = CROUCH_T
			rw_at = -2.0                                      # (on its way: no second start)
			return

func _kneel(i: int) -> void:
	var q: Dictionary = th[i]
	q.st = 2
	q.mode = "idle"
	q.next = ""
	q.hammer = 0
	q.eye = false
	rewind_t0 = snappedf(room.time, 0.01)
	q.face = 1.0 if float(th[1 - i].x) >= float(q.x) else -1.0

func _rewind_step(i: int) -> void:
	if room.time - rewind_t0 < REWIND_T:
		return
	var q: Dictionary = th[i]
	var o: Dictionary = th[1 - i]
	q.st = 0
	q.gap = 0.8
	q.mode = "idle"
	o.st = 0
	o.hp = maxf(1.0, roundf(float(o.max) * REWIND_HP))
	o.mode = "idle"
	o.gap = 0.8
	o.plan = {}
	o.eye = false
	o.hammer = 0
	o.daze_until = -1.0
	rewind_t0 = -1.0
	rw_at = -1.0
	_sums()
	room.burst(float(o.x), float(o.y) - 24.0, 12, [COL[1 - i], "#ffffff"], 140.0, 220.0, {"glow": 1})
	Audio.sfx("gate", {"vol": 0.8})
	Game.dlog("%s rewound its partner to %.0f hp" % [NAMES[i], float(o.hp)])
	_sync_mirror()

# any damage to the kneeling survivor stops it; it tries again 6 s later
func _rewind_cancel(i: int) -> void:
	var q: Dictionary = th[i]
	q.st = 0
	q.mode = "idle"
	q.gap = 0.4
	rewind_t0 = -1.0
	rw_at = room.time + REWIND_RETRY

# ---------------------------------------------------------------- choosing: pairs (both free) and singles
# 0 none, else the pair attack to start: double / switch / combo (phase 2: switch first, then double or combo half and half)
func _pair_kind() -> String:
	var hl := _hall()
	if hl == null or hl.serialized(room.time) or alive_n() < 2:
		return ""
	for q in th:
		if q.st != 0 or not q.plan.is_empty() or room.time < float(q.daze_until) or not (String(q.mode) in ["idle", "wait"]):
			return ""
	var dready: bool = int(th[0].since) >= int(th[0].need) and int(th[1].since) >= int(th[1].need)
	if ph == 1:
		return "double" if dready else ""
	var sready: bool = int(th[0].swsince) >= int(th[0].swneed) and int(th[1].swsince) >= int(th[1].swneed)
	if sready and (not dready or room.rng.randf() < 0.5):
		return "switch"
	if dready:
		return "combo" if room.rng.randf() < 0.5 else "double"
	return ""

func _droppable_bell(pt: Vector2) -> int:
	var hl := _hall()
	if hl == null or ph != 2 or hl.fallen_count(room.time) >= 2:
		return -1
	var best := -1
	var bd := 1e9
	for b in range(BelfryHall.N_BELLS):
		if not hl.can_fall(b, room.time) or hl.hit_cd.size() == 0:
			continue
		var rc := BelfryHall.new_rest(b)
		var d := Vector2(rc.position.x + rc.size.x * 0.5, rc.position.y).distance_to(pt)
		if d < bd:
			bd = d
			best = b
	return best

# the hall follows the boss's phase and clock (host; the guest's copy gets them in the snapshot)
func _sync_hall() -> void:
	var hl := _hall()
	if hl == null:
		return
	hl.cam_lock_v = cam_lock_now()
	if room.mode != "guest":
		hl.ph = ph
		hl.creak_t0 = intro_t0 + 2.5 if intro_t0 >= 0.0 and intro_len() > 3.0 else BelfryHall.NONE_T

# the camera leans toward the automaton in its cue, else the middle of the pair (the free camera follows `cy`)
func _focus() -> void:
	var fx := 0.0
	var fy := 0.0
	var n := 0
	for q in th:
		if q.st != 1:
			var w := 3.0 if (not q.plan.is_empty() and q.plan.ph == "cue") else 1.0
			fx += q.x * w
			fy += (q.y - 24.0) * w
			n += int(w)
	if n > 0:
		x = fx / float(n) - w / 2.0
		y = fy / float(n) - h / 2.0

func _sync_mirror() -> void:
	var newest := {}
	for q in th:
		if not q.plan.is_empty() and (newest.is_empty() or int(q.plan.seq) > int(newest.seq)):
			newest = q.plan
	plan = newest

# the stand point of an automaton on its bell (it rides the swing)
func _stand(i: int) -> Vector2:
	var q: Dictionary = th[i]
	var b := int(q.bell)
	var hl := _hall()
	if b >= 0 and hl != null:
		var rc := BelfryHall.new_rest(b)
		return Vector2(rc.position.x + rc.size.x * 0.5 + float(q.ox) + hl.swing_dx(b, room.time), hl.bell_pose(b, room.time).y)
	return Vector2(q.x, q.y)

# the surface under (x, y): {y, bell}: the first standable bell top at or under the point, else the floor
func _ground_at(px: float, py: float) -> Dictionary:
	var hl := _hall()
	var best := {"y": FLOOR_Y, "bell": -1}
	if hl == null:
		return best
	for b in range(BelfryHall.N_BELLS):
		var rc := BelfryHall.new_rest(b)
		var top := float(hl.bell_pose(b, room.time).y)
		if px >= rc.position.x and px <= rc.position.x + rc.size.x and top >= py - 6.0 and top < float(best.y) and hl.bell_standable(b, room.time):
			best = {"y": top, "bell": b}
		elif ph == 2 and hl.bell_mode(b, room.time) == "lie" and px >= rc.position.x and px <= rc.position.x + rc.size.x and hl.lie_y() >= py - 6.0 and hl.lie_y() < float(best.y):
			best = {"y": hl.lie_y(), "bell": -1}                  # (a lying bell is solid in phase 2: a floor two tiles high)
	return best

func _partner_on(i: int, b: int) -> bool:
	var o: Dictionary = th[1 - i]
	return o.st != 1 and (int(o.bell) == b or int(o.dest) == b)

# a bell to strike from: the nearest to the read point among the free ones; TICK prefers the small high bells, TOCK the big low ones
func _pick_bell(i: int, pt: Vector2) -> int:
	var hl := _hall()
	var best := -1
	var bd := 1e9
	for b in range(BelfryHall.N_BELLS):
		if hl == null or not hl.bell_standable(b, room.time) or not hl.hanging(b, room.time) or _partner_on(i, b):
			continue
		var rc := BelfryHall.new_rest(b)
		var d := Vector2(rc.position.x + rc.size.x * 0.5, rc.position.y).distance_to(pt)
		var kind: int = int(BelfryHall.BELLS[b][3])
		if i == 0 and kind == 0:
			d += 60.0
		if i == 1 and kind == 2:
			d += 60.0
		if d < bd:
			bd = d
			best = b
	return best

# where to stand on bell b when the read point is pt (a big bell: leaning toward it)
func _bell_pt(b: int, pt: Vector2) -> Vector2:
	var rc := BelfryHall.new_rest(b)
	var cx := rc.position.x + rc.size.x * 0.5
	var lean := 0.0 if rc.size.x < 60.0 else clampf(pt.x - cx, -20.0, 20.0)
	return Vector2(clampf(cx + lean, ARENA_L, ARENA_R), rc.position.y)

func _bell_unsafe(b: int) -> bool:
	var hl := _hall()
	if hl == null or b < 0:
		return false
	return hl.bell_mode(b, room.time) != "hang" or not hl.bell_standable(b, room.time)

# ---------------------------------------------------------------- one automaton
func _step_th(i: int, dt: float) -> void:
	var q: Dictionary = th[i]
	if q.st == 1:
		return
	if q.st == 2:
		_rewind_step(i)
		return
	if room.time < float(q.daze_until):
		if int(q.bell) >= 0:
			var sd := _stand(i)
			q.x = sd.x
			q.y = sd.y
		return
	if int(q.bell) >= 0 and _bell_unsafe(int(q.bell)) and String(q.mode) in ["idle", "wait", "plan"]:
		_flee(i)                                               # its bell is cracking or falling: off it
	match String(q.mode):
		"idle":
			var sp := _stand(i)
			if int(q.bell) >= 0:
				q.x = sp.x
				q.y = sp.y
			q.gap -= dt
			if q.gap <= 0.0:
				_begin_next(i)
		"crouch":
			var sp2 := _stand(i)
			if int(q.bell) >= 0:
				q.x = sp2.x
				q.y = sp2.y
			q.mt -= dt
			if q.mt <= 0.0:
				_launch(i)
		"hop":
			_hop_step(i)
		"wait":
			var sp3 := _stand(i)
			if int(q.bell) >= 0:
				q.x = sp3.x
				q.y = sp3.y
			if String(q.next) in ["double", "switch", "combo"] and alive_n() == 2:
				_wait_double(i, dt)
			elif room.time >= float(q.start_at):
				_cue_start(i)
		"plan":
			_plan_logic(i, dt)

# its bell is going: cancel what it was doing and hop to a free bell (or the floor)
func _flee(i: int) -> void:
	var q: Dictionary = th[i]
	q.air = false
	if not q.plan.is_empty():
		_abort_plan(q)
		if q.plan.id == "double":
			_cancel(1 - i)
		q.plan = {}
		q.eye = false
		q.hammer = 0
	var pt := read_point(i, _key_for(i))
	var b := _pick_bell(i, pt)
	q.next = ""
	if b >= 0:
		var bp := _bell_pt(b, pt)
		q.dest = b
		q.dx = bp.x
		q.dy = bp.y
	else:
		q.dest = -1
		q.dx = clampf(float(q.x) + 60.0 * (1.0 if float(q.x) < 208.0 else -1.0), ARENA_L, ARENA_R)
		q.dy = FLOOR_Y
	q.mode = "crouch"
	q.mt = CROUCH_T * 0.5

# weighted choice by distance: far, bell strikes and the clapper; near, slams and the rope; never the same twice, a fixed order the first time
func _choose(i: int) -> String:
	var q: Dictionary = th[i]
	if int(q.n) == 0:
		return "strike" if i == 1 else "slam"                  # the teaching order of phase 1 (the double write follows)
	var key := _key_for(i)
	var d := absf(kit_aim(key).x - float(q.x))
	if ph == 2:
		var rpt := read_point(i, key)
		if i == 1 and not p2_flags.drop and _droppable_bell(rpt) >= 0:
			p2_flags.drop = true
			return "drop"                                      # the teaching order of phase 2: switch, TOCK's drop, TICK's triple
		if i == 0 and not p2_flags.triple and d > 64.0:
			p2_flags.triple = true
			return "triple"
	var opts: Array = []                                       # [id, weight]
	if d > NEAR_PX:
		opts = [["strike", 3.0], ["slam", 1.0]]
		if i == 1:
			opts.append(["clapper", 2.0])
	else:
		opts = [["slam", 3.0], ["strike", 1.0]]
		if i == 0:
			opts.append(["rope", 2.0])
	if ph == 2:
		if i == 1 and _droppable_bell(read_point(i, key)) >= 0:
			opts.append(["drop", 2.0])
		if i == 0 and d > 64.0:
			opts.append(["triple", 2.0])
	opts = opts.filter(func(o): return o[0] != q.last)
	var tot := 0.0
	for o in opts:
		tot += float(o[1])
	var roll := room.rng.randf() * tot
	for o in opts:
		roll -= float(o[1])
		if roll <= 0.0:
			return String(o[0])
	return String(opts[0][0])

# both free, neither used the double write in its last 3-4 plans (the first one comes after a plan each), never while the lock has them taking turns
func _double_ready() -> bool:
	var hl := _hall()
	if hl == null or hl.serialized(room.time) or alive_n() < 2:
		return false
	for q in th:
		if q.st != 0 or not q.plan.is_empty() or room.time < float(q.daze_until) or not (String(q.mode) in ["idle", "wait"]):
			return false
		if int(q.since) < int(q.need):
			return false
	return true

func _begin_next(i: int) -> void:
	var q: Dictionary = th[i]
	if alive_n() == 0:
		return
	var pair := _pair_kind()
	if pair == "double":
		_begin_double()
		return
	if pair != "":
		_begin_swap(pair)
		return
	var id := _choose(i)
	if alive_n() == 1 and int(q.since) >= int(q.need):
		id = "double"                                           # alone: the double write with two reads, 1 + 1
	q.next = id
	var key := _key_for(i)
	var pt := read_point(i, key)
	var b := _pick_bell(i, pt)
	if id == "rope" and int(q.bell) >= 0:
		b = int(q.bell)
	if id == "double":
		b = int(q.bell)
	if id == "drop":
		var db := _droppable_bell(pt)
		var rcd := BelfryHall.new_rest(db)
		q.rx = pt.x
		q.ry = pt.y
		q.dest = -3                                             # the chain above the bell: in the air
		q.dx = rcd.position.x + rcd.size.x * 0.5
		q.dy = rcd.position.y - 38.0
		q.dbell = db
		q.mode = "crouch"
		q.mt = CROUCH_T
		return
	if b >= 0 and (b != int(q.bell) or int(q.bell) < 0):
		var bp := _bell_pt(b, pt)
		q.dest = b
		q.dx = bp.x
		q.dy = bp.y
		q.rx = pt.x
		q.ry = pt.y
		q.mode = "crouch"
		q.mt = CROUCH_T
		return
	_to_wait(i)

func _to_wait(i: int) -> void:
	var q: Dictionary = th[i]
	q.mode = "wait"
	q.wait_t = 0.0
	q.start_at = _next_beat(room.time)
	var hl := _hall()
	if hl != null and hl.serialized(room.time):                  # the lock: a plan starts on a tick, one automaton per tick, in turns
		q.start_at = hl.next_boundary(room.time + 0.001)

func _launch(i: int) -> void:
	var q: Dictionary = th[i]
	var b: int = int(q.dest)
	var to := Vector2(float(q.dx), float(q.dy))
	if b >= 0:
		var rc := BelfryHall.new_rest(b)
		q.ox = to.x - (rc.position.x + rc.size.x * 0.5)
	q.hop = {"t0": snappedf(room.time, 0.01), "dur": HOP_T, "fx": q.x, "fy": q.y, "tx": to.x, "ty": to.y}
	q.face = 1.0 if to.x >= q.x else -1.0
	q.bell = -1
	q.air = false
	q.mode = "hop"

func _hop_pos(h: Dictionary, tm: float) -> Vector2:
	var u := clampf((tm - float(h.t0)) / float(h.dur), 0.0, 1.0)
	var dist := absf(float(h.tx) - float(h.fx))
	var arc := 26.0 + 0.14 * dist
	return Vector2(lerpf(float(h.fx), float(h.tx), u), lerpf(float(h.fy), float(h.ty), u) - arc * 4.0 * u * (1.0 - u))

func _hop_step(i: int) -> void:
	var q: Dictionary = th[i]
	var h: Dictionary = q.hop
	var p := _hop_pos(h, room.time)
	q.x = p.x
	q.y = p.y
	if room.time >= float(h.t0) + float(h.dur):
		var b: int = int(q.dest)
		var hl := _hall()
		if b == -3:                                           # up on the chain of a bell it is going to rip down
			q.bell = -1
			q.air = true
			q.x = float(q.dx)
			q.y = float(q.dy)
		elif b >= 0 and hl != null and hl.bell_standable(b, room.time):
			q.bell = b
			hl.kick(b)                                        # landing on a bell kicks it: a small harmless ring from its swing
			var sp := _stand(i)
			q.x = sp.x
			q.y = sp.y
		else:
			var g := _ground_at(q.x, q.y)
			q.bell = int(g.bell)
			q.y = float(g.y)
			q.ox = 0.0
		q.hop = {}
		_to_wait(i)
		if String(q.next) == "rewind" and q.st == 0:
			_kneel(i)

# ---------------------------------------------------------------- a plan
func _cue_len(id: String, guard: bool) -> float:
	var c := float(PLANS[id][0]) * _beat() * _tm()
	var two := id == "double" and alive_n() == 2                # (the pair's double write is the 2-damage one: no guard, no alone)
	if guard and not two:
		c = maxf(c * GUARD_K, 0.30)                             # (never on a 2-damage plan, never under 0.30 s)
	if alive_n() == 1 and not two:
		c = maxf(c * ALONE_K, 0.30)                             # the survivor is quicker
	return c

func _rec_len(id: String) -> float:
	return _pm_rec(float(PLANS[id][2]))

func _new_plan(i: int, id: String, key: String, rp: Vector2, cue: float) -> Dictionary:
	var q: Dictionary = th[i]
	plan_seq += 1
	var p := {"seq": plan_seq, "id": id, "fam": "slam", "tgt": key, "ph": "cue", "t": cue, "cue_len": cue, "act_len": float(PLANS[id][1]), "rec_len": _rec_len(id),
		"rx": rp.x, "ry": rp.y, "sx": q.x, "sy": q.y, "lx": q.x, "ly": q.y, "bell": int(q.bell), "land_at": room.time + cue, "hold": 0.0, "ack_at": -1.0, "dir": 1.0,
		"split": false, "hit": false, "r2x": rp.x, "r2y": rp.y, "checked": false, "l2x": q.x, "l2y": q.y, "alone": false, "tbeat": 0.3, "tb": [-1, -1, -1]}
	if not _guest_waits():
		p.ack_at = plan_clock
	if alive_n() == 1 and _hall() != null and _hall().serialized(room.time):
		p.rec_len = float(p.rec_len) + 1.5                       # alone and serialized: it cannot guard, so it stumbles after each plan
	return p

func _cue_start(i: int) -> void:
	var q: Dictionary = th[i]
	var id: String = String(q.next)
	var o: Dictionary = th[1 - i]
	var hl := _hall()
	var guard := _vulnerable(o)
	var key := _guard_key(i) if guard else _key_for(i)
	var cue := _cue_len(id, guard)
	if hl != null and hl.serialized(room.time):                  # the lock: this one only on a tick and only in its turn
		var turn_ok: bool = i == serial_turn or String(o.mode) != "wait"          # (its turn, or the other one is not ready this tick)
		if not turn_ok or hl.tick_f_at(room.time) > 0.06 or (not o.plan.is_empty() and o.plan.ph == "cue" and float(o.plan.cue_len) - float(o.plan.t) < 0.05):
			q.start_at = hl.next_boundary(room.time + 0.05)
			return
		serial_turn = 1 - i
	elif not o.plan.is_empty() and o.plan.ph != "recover" and absf(float(o.plan.land_at) - (room.time + cue)) < STAGGER:
		q.start_at = room.time + _beat()                      # two strikes do not land together: this one waits a beat
		return
	var rp := read_point(i, key)
	q.rx = rp.x
	q.ry = rp.y
	var sp := _stand(i)
	if int(q.bell) >= 0:
		q.x = sp.x
		q.y = sp.y
	var p := _new_plan(i, id, key, rp, cue)
	if id == "slam":
		var lx := clampf(rp.x, ARENA_L + 16.0, ARENA_R - 16.0)
		var g := _ground_at(lx, rp.y)
		p.lx = lx
		p.ly = float(g.y)
		p.lb = int(g.bell)
	if id == "rope":
		var v := _vel(key)
		var dir := signf(v.x) if absf(v.x) > 8.0 else signf(kit_aim(key).x - float(q.x))
		p.dir = dir if dir != 0.0 else float(q.face)
	if id == "double":                                         # alone: two reads (where it was, where it is going), two strikes 0.2 s apart, 1 + 1, no clash
		var ra := read_point(1, key, false)
		var rb := read_point(0, key, true)
		var ga := _ground_at(clampf(ra.x, ARENA_L + 16.0, ARENA_R - 16.0), ra.y)
		var gb := _ground_at(clampf(rb.x, ARENA_L + 16.0, ARENA_R - 16.0), rb.y)
		p.rx = ra.x
		p.ry = ra.y
		p.r2x = rb.x
		p.r2y = rb.y
		p.lx = clampf(ra.x, ARENA_L + 16.0, ARENA_R - 16.0)
		p.ly = float(ga.y)
		p.l2x = clampf(rb.x, ARENA_L + 16.0, ARENA_R - 16.0)
		p.l2y = float(gb.y)
		p.lb = int(gb.bell)
		p.alone = true
		p.act_len = 0.6
		q.rx = ra.x
		q.ry = ra.y
	if id == "triple":
		p.act_len = 3.0 * _beat() + TRIPLE_RING_T
		p.tbeat = _beat()
		p.tb = [-1, -1, -1]
	if id == "drop":
		var db := int(q.dbell)
		if db < 0 or hl == null or not hl.can_fall(db, room.time):
			q.plan = {}
			q.mode = "idle"
			q.air = false
			q.gap = 0.3
			return                                                # (the bell cannot fall any more: nothing happens)
		var rc := BelfryHall.new_rest(db)
		p.bell = db
		p.lx = rc.position.x + rc.size.x * 0.5
		p.ly = rc.position.y
		p.act_len = hl.fall_time(db) + 0.15
		hl.rattle(db)                                             # the chain rattles and the bell shakes: that is the cue
	q.face = float(p.dir) if id == "rope" else (1.0 if rp.x >= q.x else -1.0)
	q.plan = p
	q.mode = "plan"
	q.eye = true
	q.dial = (int(q.dial) + 1) % 12                           # the chest clock ticks once: the READ
	q.hammer = 1
	if hl != null and int(q.bell) >= 0 and (id == "strike" or id == "clapper"):
		hl.kick(int(q.bell))                                  # the bell it will ring starts to glow and sway
	Game.dlog("%s %s -> %s (read %d,%d)%s" % [NAMES[i], id, key, roundi(rp.x), roundi(rp.y), " guard" if guard else ""])
	_sync_mirror()

# ---- the double write: both read the same point (the target's position, no prefetch), both raise hammers, 3 beats
func _begin_double() -> void:
	var key := _double_key()
	var pt := read_point(1, key, false)
	var g := _ground_at(pt.x, pt.y)
	for i in range(2):
		var q: Dictionary = th[i]
		q.next = "double"
		q.rx = pt.x
		q.ry = pt.y
		var fx := clampf(pt.x + (-BOX_W * 0.5 if i == 0 else BOX_W * 0.5), ARENA_L + 8.0, ARENA_R - 8.0)
		var gb := int(g.bell)
		if gb >= 0:
			var rc := BelfryHall.new_rest(gb)
			fx = clampf(fx, rc.position.x + 10.0, rc.position.x + rc.size.x - 10.0)
		q.dest = gb
		q.dx = fx
		q.dy = float(g.y)
		q.wait_t = 0.0
		if absf(float(q.x) - fx) < 6.0 and absf(float(q.y) - float(g.y)) < 3.0:
			_to_wait(i)
			q.next = "double"
		else:
			q.mode = "crouch"
			q.mt = CROUCH_T

# both flank the point; the cue starts when both are there
func _wait_double(i: int, dt: float) -> void:
	var q: Dictionary = th[i]
	var o: Dictionary = th[1 - i]
	q.wait_t += dt
	if q.wait_t > 3.0:                                         # the partner never came (hit, dazed, fallen): a single plan instead
		q.next = _choose(i)
		q.mode = "wait"
		q.start_at = room.time
		return
	if i == 1:
		return                                                # (TICK starts the pair)
	if String(o.mode) == "wait" and String(o.next) == String(q.next) and room.time >= float(q.start_at) and room.time >= float(o.start_at):
		if String(q.next) == "double":
			_cue_double()
		else:
			_cue_swap(String(q.next))

func _cue_double(forced_key := "") -> void:
	var key := forced_key if forced_key != "" else _double_key()
	var rp := read_point(1, key, false)
	var g := _ground_at(rp.x, rp.y)
	var cue := _cue_len("double", false)
	var dial := (int(th[0].dial) + 1) % 12
	for i in range(2):
		var q: Dictionary = th[i]
		var sp := _stand(i)
		if int(q.bell) >= 0:
			q.x = sp.x
			q.y = sp.y
		var p := _new_plan(i, "double", key, rp, cue)
		p.ly = float(g.y)
		p.lb = int(g.bell)
		p.lx = clampf(rp.x + (-BOX_W * 0.5 if i == 0 else BOX_W * 0.5), ARENA_L + 8.0, ARENA_R - 8.0)
		q.rx = rp.x
		q.ry = rp.y
		q.plan = p
		q.mode = "plan"
		q.eye = true
		q.dial = dial                                         # both chest clocks show the same number
		q.hammer = 1
		q.face = 1.0 if rp.x >= q.x else -1.0
	Game.dlog("double write -> %s (read %d,%d)" % [key, roundi(rp.x), roundi(rp.y)])
	_sync_mirror()

# ---- switch: the two swap places (a crossing leap), each landing makes a small ring; combo: the same, then a double write that starts on the landing
func _begin_swap(kind: String) -> void:
	for i in range(2):
		var q: Dictionary = th[i]
		q.next = kind
		q.wait_t = 0.0
		_to_wait(i)
		q.next = kind

func _cue_swap(kind: String) -> void:
	var key := _double_key()
	var cue := _cue_len("switch", false)
	var hl := _hall()
	for i in range(2):
		var q: Dictionary = th[i]
		var o: Dictionary = th[1 - i]
		var sp := _stand(i)
		if int(q.bell) >= 0:
			q.x = sp.x
			q.y = sp.y
		var p := _new_plan(i, kind, key, Vector2(float(o.x), float(o.y)), cue)
		p.lx = float(o.x)
		p.ly = float(o.y)
		p.lb = int(o.bell)
		p.act_len = 0.8
		q.plan = p
		q.mode = "plan"
		q.eye = false
		q.hammer = 0
		q.face = 1.0 if float(o.x) >= float(q.x) else -1.0
		if hl != null and int(o.bell) >= 0:
			hl.strike(int(o.bell), false)                         # the destination bells start swinging and jingling: that is the tell
	Game.dlog("%s: the two swap places" % kind)
	_sync_mirror()

func _plan_logic(i: int, dt: float) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	if p.is_empty():
		q.mode = "idle"
		return
	p.t -= dt
	match String(p.ph):
		"cue":
			if String(p.id) == "double" and not p.checked and float(p.t) <= CHECK_T and i == 0:
				_double_check()
			if p.t > 0.0:
				return
			if _guest_waits() and not (float(p.ack_at) >= 0.0 and plan_clock - float(p.ack_at) >= SEEN_MIN):
				p.t = 0.0                                     # the guest has not been looking at this long enough
				p.hold += dt
				if p.hold > HOLD_MAX:
					Game.dlog("%s plan %d cancelled: the guest did not see it" % [NAMES[i], p.seq])
					p.ph = "recover"
					p.t = float(p.rec_len)
					q.eye = false
					if p.id == "double":
						_cancel(1 - i)
				return
			p.ph = "active"
			p.t = float(p.act_len)
			q.eye = false
			_on_active(i)
		"active":
			_active_step(i, dt)
			if q.plan.is_empty() or int(q.plan.seq) != int(p.seq):
				return                                        # (a combo's second part replaced it)
			if p.t <= 0.0:
				if String(p.id) == "combo":
					if i == 0:
						_cue_double()                         # the double write's 3-beat cue starts on the landing
					return
				p.ph = "recover"
				p.t = float(p.rec_len)
				_on_recover(i)
		"recover":
			if p.t <= 0.0:
				_plan_done(i)

# 0.30 s before the strike: the target left the read point (further than 32 px): TICK reads again, the strikes land apart (1 + 1, no clash)
func _double_check() -> void:
	var p0: Dictionary = th[0].plan
	var p1: Dictionary = th[1].plan
	if p0.is_empty() or p1.is_empty() or p1.id != "double":
		return
	p0.checked = true
	p1.checked = true
	var key: String = String(p0.tgt)
	var rp := Vector2(float(p0.rx), float(p0.ry))
	var now_pt := kit_aim(key)
	if now_pt.distance_to(rp) <= SPLIT_PX:
		return
	var r2 := read_point(0, key)
	p0.split = true
	p1.split = true
	p0.r2x = r2.x
	p0.r2y = r2.y
	var g2 := _ground_at(clampf(r2.x, ARENA_L + 16.0, ARENA_R - 16.0), r2.y)
	p0.lx = clampf(r2.x, ARENA_L + 16.0, ARENA_R - 16.0)
	p0.ly = float(g2.y)
	p0.lb = int(g2.bell)
	p0.rx = r2.x                                                # (TICK's beam and afterimage follow the new read)
	p0.ry = r2.y
	th[0].rx = r2.x
	th[0].ry = r2.y
	p0.t = float(p0.t) + 0.15                                   # TICK lands 0.15 s after TOCK
	p0.cue_len = float(p0.cue_len) + 0.15
	p1.lx = clampf(float(p1.rx), ARENA_L + 16.0, ARENA_R - 16.0)
	Game.dlog("double write: %s left (%.0f px): TICK reads again" % [key, now_pt.distance_to(rp)])

func _on_active(i: int) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	var hl := _hall()
	match String(p.id):
		"strike":
			if hl != null and int(p.bell) >= 0:
				hl.strike(int(p.bell), true, i)
			Audio.sfx("clang", {"vol": 0.8})
			room.shake(0.25)
		"slam":
			Audio.sfx("swipeBig", {"vol": 0.6})
		"clapper":
			_shoot_clapper(i)
		"rope":
			Audio.sfx("swipe", {"vol": 0.7})
		"double":
			Audio.sfx("swipeBig", {"vol": 0.7})
		"drop":
			if hl != null and int(p.bell) >= 0:
				hl.release(int(p.bell))                          # the chain is ripped: the bell falls with TOCK riding it
			Audio.sfx("brk", {"vol": 0.9})
		"switch", "combo":
			Audio.sfx("swipeBig", {"vol": 0.6})
		"triple":
			p.tb = [-1, -1, -1]

func _active_step(i: int, _dt: float) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	var el := _el(p)
	var hl := _hall()
	match String(p.id):
		"slam":
			_dive(q, p, el)
			if el >= DIVE_T and not p.get("landed", false):
				p["landed"] = true
				q.bell = int(p.get("lb", -1))
				q.ox = 0.0
				q.hammer = 2
				room.shake(0.45)
				Audio.sfx("thud", {"vol": 0.9})
				if hl != null:
					if int(q.bell) >= 0:
						hl.kick(int(q.bell))
					else:
						hl.paint(hl.cell_of(float(p.lx)), i, room.time)       # a write on the floor paints its cell
		"rope":
			var u2 := el / float(p.act_len)
			q.x = clampf(float(p.sx) + float(p.dir) * 50.0 * sin(PI * u2), ARENA_L, ARENA_R)
			q.y = float(p.sy) - 18.0 * sin(PI * u2)
		"switch", "combo":
			var u3 := clampf(el / 0.5, 0.0, 1.0)
			q.x = lerpf(float(p.sx), float(p.lx), u3)
			q.y = lerpf(float(p.sy), float(p.ly), u3) - 44.0 * 4.0 * u3 * (1.0 - u3)
			if el >= 0.5 and not p.get("landed", false):
				p["landed"] = true
				q.bell = int(p.get("lb", -1))
				q.ox = 0.0
				q.x = float(p.lx)
				q.y = float(p.ly)
				if hl != null and int(q.bell) >= 0:
					hl.kick(int(q.bell))
				Audio.sfx("thud", {"vol": 0.6})
		"drop":
			var ib := int(p.bell)
			if hl != null and ib >= 0:
				var bp := hl.bell_pose(ib, room.time)
				var u4 := clampf(el / 0.12, 0.0, 1.0)
				q.x = float(p.lx)
				q.y = float(bp.y) - 38.0 * (1.0 - u4)             # it drops onto the top of the bell and rides it down
				if String(hl.bell_mode(ib, room.time)) != "fall" and room.time >= float(hl.fall_t0[ib]) + hl.fall_time(ib):
					if not p.get("landed", false):
						p["landed"] = true
						room.shake(0.5)
						Audio.sfx("thud", {"vol": 1.0})
		"triple":
			_triple_step(i, q, p, el)
		"double":
			if p.get("alone", false):
				_alone_double_step(i, q, p, el)
				return
			_dive(q, p, el)
			if el >= DIVE_T and not p.get("landed", false):
				p["landed"] = true
				q.bell = int(p.get("lb", -1))
				q.ox = 0.0
				if p.get("split", false):
					q.hammer = 2
					room.shake(0.4)
					Audio.sfx("thud", {"vol": 0.9})
					if hl != null:
						if int(q.bell) >= 0:
							hl.crack(int(q.bell))
						else:
							hl.paint(hl.cell_of(float(p.lx)), i, room.time)
				elif i == 0:
					_double_impact()

# the survivor's double write: it dives onto where the target was, then 0.2 s later onto where it was going: 1 + 1
func _alone_double_step(i: int, q: Dictionary, p: Dictionary, el: float) -> void:
	var hl := _hall()
	if el < 0.2:
		var u := el / 0.2
		q.x = lerpf(float(p.sx), float(p.lx), u)
		q.y = lerpf(float(p.sy), float(p.ly), u * u) - 12.0 * 4.0 * u * (1.0 - u)
	elif el < 0.3:
		q.x = float(p.lx)
		q.y = float(p.ly)
		if not p.get("landed", false):
			p["landed"] = true
			room.shake(0.3)
			Audio.sfx("thud", {"vol": 0.8})
			if hl != null and _ground_at(float(p.lx), float(p.ly) - 4.0).bell < 0 and float(p.ly) >= FLOOR_Y - 1.0:
				hl.paint(hl.cell_of(float(p.lx)), i, room.time)
	elif el < 0.4:
		var u2 := (el - 0.3) / 0.1
		q.x = lerpf(float(p.lx), float(p.l2x), u2)
		q.y = lerpf(float(p.ly), float(p.l2y), u2) - 10.0 * 4.0 * u2 * (1.0 - u2)
	else:
		q.x = float(p.l2x)
		q.y = float(p.l2y)
		if not p.get("landed2", false):
			p["landed2"] = true
			q.bell = int(p.get("lb", -1))
			q.ox = 0.0
			room.shake(0.3)
			Audio.sfx("thud", {"vol": 0.8})
			if hl != null and float(p.l2y) >= FLOOR_Y - 1.0:
				hl.paint(hl.cell_of(float(p.l2x)), i, room.time)

# the triple strike: three leaps one beat apart, each onto the bell nearest a fresh prefetch read, each landing rings it
func _triple_step(i: int, q: Dictionary, p: Dictionary, el: float) -> void:
	var hl := _hall()
	var beat: float = float(p.tbeat)
	var k := clampi(floori(el / beat), 0, 2)
	var tb: Array = p.tb
	# at the start of leap k choose its bell from a fresh read
	if int(tb[k]) == -1 and el < beat * 3.0:
		var prev: int = int(tb[k - 1]) if k > 0 else int(q.bell)
		var pt := read_point(0, String(p.tgt))
		var best := -1
		var bd := 1e9
		for b in range(BelfryHall.N_BELLS):
			if hl == null or b == prev or (k > 0 and b == int(tb[0])) or not hl.bell_standable(b, room.time) or not hl.hanging(b, room.time) or _partner_on(i, b):
				continue
			var rc := BelfryHall.new_rest(b)
			var d := Vector2(rc.position.x + rc.size.x * 0.5, rc.position.y).distance_to(pt)
			if d < bd:
				bd = d
				best = b
		if best < 0:
			best = prev
		tb[k] = best
		p["leap_from_%d" % k] = Vector2(q.x, q.y)
	if el < beat * 3.0:
		var from: Vector2 = p.get("leap_from_%d" % k, Vector2(q.x, q.y))
		var to_b: int = int(tb[k])
		if to_b >= 0 and hl != null:
			var rc2 := BelfryHall.new_rest(to_b)
			var dst := Vector2(rc2.position.x + rc2.size.x * 0.5 + hl.swing_dx(to_b, room.time), hl.bell_pose(to_b, room.time).y)
			var u := clampf((el - beat * float(k)) / beat, 0.0, 1.0)
			q.x = lerpf(from.x, dst.x, u)
			q.y = lerpf(from.y, dst.y, u) - (20.0 + 0.1 * absf(dst.x - from.x)) * 4.0 * u * (1.0 - u)
			q.face = 1.0 if dst.x >= from.x else -1.0
	for kk in range(3):                                           # a leap lands on its beat: the bell rings
		if int(tb[kk]) >= 0 and hl != null and el >= beat * float(kk + 1) and not p.get("hit_%d" % kk, false):
			p["hit_%d" % kk] = true
			q.bell = int(tb[kk])
			q.ox = 0.0
			hl.strike(int(tb[kk]), true, i)
			Audio.sfx("clang", {"vol": 0.8})
			room.shake(0.2)
	p.tbeat = beat

# the dive of a slam / double write: up a little, then fast to the landing spot
func _dive(q: Dictionary, p: Dictionary, el: float) -> void:
	if el < DIVE_T:
		var u := el / DIVE_T
		q.x = lerpf(float(p.sx), float(p.lx), u)
		q.y = lerpf(float(p.sy), float(p.ly), u * u) - 14.0 * 4.0 * u * (1.0 - u)
	else:
		q.x = float(p.lx)
		q.y = float(p.ly)

# the two hammers arrive: the target inside the strike box takes 2 (one hit); gone (it left in the last 0.30 s) and they clash: both dazed 2 s
func _double_impact() -> void:
	var p0: Dictionary = th[0].plan
	var p1: Dictionary = th[1].plan
	if p0.is_empty() or p1.is_empty() or p0.get("split", false):
		return
	var key: String = String(p0.tgt)
	var box := Rect2(float(p1.rx) - BOX_W * 0.5, float(p1.ly) - 48.0, BOX_W, 48.0)
	var inside := box.grow(4.0).has_point(kit_aim(key))
	var hl := _hall()
	if inside:
		p0.hit = true
		p1.hit = true
		room.shake(0.6)
		Audio.sfx("thud", {"vol": 1.0})
		Audio.sfx("clang", {"vol": 0.8})
		if hl != null:
			if int(p1.get("lb", -1)) >= 0:
				hl.crack(int(p1.lb))                          # the target stood on a bell and the strike lands on it
			else:
				var c := hl.cell_of(float(p1.rx))
				hl.paint(c, 0, room.time)                     # both threads write the same cell: it corrupts
				hl.paint(c, 1, room.time)
		return
	clash_t0 = snappedf(room.time, 0.01)
	clash_pt = Vector2(float(p1.rx), float(p1.ly) - 24.0)
	Audio.sfx("clang", {"vol": 1.0})
	Audio.sfx("explode", {"vol": 0.5})
	room.shake(0.8)
	room.flash_screen(0.25, "#ffffff")
	room.burst(clash_pt.x, clash_pt.y, 14, ["#ffffff", COL[0], COL[1]], 160.0, 220.0, {"glow": 1})
	for k in range(2):
		var q: Dictionary = th[k]
		q.x = float(q.plan.lx)
		q.y = float(q.plan.ly)
		q.bell = int(q.plan.get("lb", -1))
		q.ox = 0.0
	th[0].plan = {}
	th[1].plan = {}
	for k in range(2):
		th[k].mode = "idle"
		th[k].gap = 0.0
		th[k].eye = false
		th[k].hammer = 0
		th[k].daze_until = room.time + CLASH_DAZE
		th[k].since = 0
		th[k].need = DOUBLE_NEED[room.rng.randi() % 2]
	_sync_mirror()

func _on_recover(i: int) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	match String(p.id):
		"slam":
			q.x = float(p.lx)
			q.y = float(p.ly)
			q.hammer = 2                                      # the hammer is stuck in the floor for the recovery
		"rope":
			q.x = float(p.sx)
			q.y = float(p.sy)
		"double":
			if p.get("alone", false):
				q.x = float(p.l2x)
				q.y = float(p.l2y)
				q.hammer = 2
			else:
				q.x = float(p.lx)
				q.y = float(p.ly)
				q.hammer = 2 if p.get("split", false) else 0
		"drop":
			var side := 1.0 if float(p.lx) < 208.0 else -1.0                # TOCK is stuck on the floor beside the bell it brought down
			q.x = clampf(float(p.lx) + side * (BelfryHall.new_rest(int(p.bell)).size.x * 0.5 + 14.0), ARENA_L, ARENA_R)
			q.y = FLOOR_Y
			q.bell = -1
			q.ox = 0.0
			q.hammer = 2
		"triple":
			var tb3: Array = p.get("tb", [-1, -1, -1])
			var lastb: int = int(tb3[2]) if int(tb3[2]) >= 0 else int(q.bell)
			q.bell = lastb
			q.ox = 0.0
			if lastb >= 0:
				var sp3 := _stand(int(q.i))
				q.x = sp3.x
				q.y = sp3.y
			q.hammer = 0
		"switch", "combo":
			q.x = float(p.lx)
			q.y = float(p.ly)
			q.bell = int(p.get("lb", -1))
			q.hammer = 0
		_:
			q.hammer = 0

func _plan_done(i: int) -> void:
	var q: Dictionary = th[i]
	q.last = String(q.plan.id)
	q.air = false
	if q.plan.id == "double":
		q.since = 0
		q.need = DOUBLE_NEED[room.rng.randi() % 2]
	else:
		q.since = int(q.since) + 1
	if q.plan.id == "switch":
		q.swsince = 0
		q.swneed = 2 + room.rng.randi() % 2
	else:
		q.swsince = int(q.swsince) + 1
	q.plan = {}
	q.mode = "idle"
	q.gap = room.rng.randf_range(GAP_MIN, GAP_MAX)
	q.n = int(q.n) + 1
	q.hammer = 0
	q.eye = false
	q.tgt = "p2" if q.tgt == "p1" else "p1"                   # the players swap
	_sync_mirror()

func _shoot_clapper(i: int) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	var b := int(p.bell)
	var from := Vector2(float(p.sx), float(p.sy) + 34.0)
	if b >= 0:
		var rc := BelfryHall.new_rest(b)
		from = Vector2(rc.position.x + rc.size.x * 0.5 + (_hall().swing_dx(b, room.time) if _hall() != null else 0.0), rc.position.y + 34.0)
	var dv := (Vector2(float(p.rx), float(p.ry)) - from)
	if dv.length() < 1.0:
		dv = Vector2(0.0, -1.0)
	dv = dv.normalized() * 150.0
	room.shoot(from.x, from.y, dv.x, dv.y, {"kind": "diamond", "col": "#ffd23f", "catchable": true, "cut": true, "r": 4.0, "life": 3.2, "dmg": 1, "by_boss": true, "clapper": true, "tile": true})
	Audio.sfx("shoot", {"vol": 0.7})

# ---------------------------------------------------------------- the guest's acknowledgement: per plan (two plans run at once)
func plan_seen(seq: int) -> void:
	super.plan_seen(seq)
	for q in th:
		var p: Dictionary = q.plan
		if not p.is_empty() and int(p.seq) <= seq and float(p.get("ack_at", -1.0)) < 0.0:
			p.ack_at = plan_clock

# the test harness and the kit's old one-plan calls: start `id` on the right automaton now (TOCK for the clapper, TICK for the rope; both for the double write)
func _start(id: String, tgt := "p1") -> void:
	for q in th:
		q.plan = {}
		q.mode = "idle"
		q.hop = {}
		q.daze_until = -1.0
		q.hammer = 0
	if id in ["switch", "combo", "drop", "triple"]:
		ph = 2                                                    # (phase 2's plans: the harness asks for them directly)
		phase = 2
		if _hall() != null:
			_hall().ph = 2
			_hall().segs = [[room.time, 0, BelfryHall.TICK_P2]]
	if id == "switch" or id == "combo":
		for k in range(2):
			th[k].next = id
			th[k].tgt = tgt
		_cue_swap(id)
		return
	if id == "drop":
		var pt0 := read_point(1, tgt)
		var db0 := _droppable_bell(pt0)
		var qd0: Dictionary = th[1]
		qd0.next = "drop"
		qd0.tgt = tgt
		qd0.dbell = db0
		if db0 >= 0:
			var rcd0 := BelfryHall.new_rest(db0)
			qd0.bell = -1
			qd0.air = true
			qd0.x = rcd0.position.x + rcd0.size.x * 0.5
			qd0.y = rcd0.position.y - 38.0
		qd0.start_at = room.time
		_cue_start(1)
		return
	if id == "double":
		var pt := read_point(1, tgt, false)
		var g := _ground_at(pt.x, pt.y)
		for k in range(2):
			var qd: Dictionary = th[k]
			qd.next = "double"
			qd.tgt = tgt
			qd.x = clampf(pt.x + (-BOX_W if k == 0 else BOX_W), ARENA_L + 8.0, ARENA_R - 8.0)
			qd.y = float(g.y)
			qd.bell = int(g.bell)
			qd.ox = 0.0
			qd.mode = "wait"
			qd.start_at = room.time
		_cue_double(tgt)
		return
	var i := 1 if id == "clapper" else 0
	var q2: Dictionary = th[i]
	q2.next = id
	q2.tgt = tgt
	if int(q2.bell) < 0:
		var b := _pick_bell(i, read_point(i, tgt))
		if b >= 0:
			var rc := BelfryHall.new_rest(b)
			q2.bell = b
			q2.x = rc.position.x + rc.size.x * 0.5
			q2.y = rc.position.y
	q2.start_at = room.time
	_cue_start(i)

# plan_step for the harness: counts every plan down by `dt` and returns the phase the first plan began ("active", "recover", "done")
func plan_step(dt: float) -> String:
	plan_clock += dt
	var ev := ""
	for i in range(2):
		var q: Dictionary = th[i]
		if q.plan.is_empty():
			continue
		var before := String(q.plan.ph)
		_plan_logic(i, dt)
		var after: String = String(q.plan.ph) if not q.plan.is_empty() else "done"
		if after != before and ev == "":
			ev = after
	_sync_mirror()
	return ev

func plan_active() -> bool:
	for q in th:
		if not q.plan.is_empty() and q.plan.ph == "active":
			return true
	return false

func plan_cut() -> void:
	for q in th:
		if not q.plan.is_empty() and q.plan.ph != "recover":
			q.plan.ph = "recover"
			q.plan.t = float(q.plan.rec_len)
	_sync_mirror()

# ---------------------------------------------------------------- the bars (the HUD asks for two)
func hud_bars() -> Array:
	var out: Array = []
	for q in th:
		var f := clampf(float(q.hp) / maxf(1.0, float(q.max)), 0.0, 1.0) if q.st != 1 else 0.0
		out.append([f, COL[q.i], NAMES[q.i], q.st == 1])
	return out

# how much bell i glows: an automaton on it is about to strike or shoot from it (a pure function of the plan state, both pages)
func glow_of_bell(b: int) -> float:
	for q in th:
		var p: Dictionary = q.plan
		if p.is_empty() or int(p.bell) != b:
			continue
		if (p.id == "strike" or p.id == "clapper") and p.ph == "cue":
			return clampf(1.0 - float(p.t) / maxf(float(p.cue_len), 0.01), 0.0, 1.0)
	return 0.0

# ---------------------------------------------------------------- drawing
func _pose_of(i: int) -> String:
	var q: Dictionary = th[i]
	if q.st == 1:
		return "down"
	if q.st == 2:
		return "kneel"
	if room.time < float(q.daze_until):
		return "dazed"
	if int(q.hammer) == 2:
		return "stuck"
	var p: Dictionary = q.plan
	if bool(q.air) or (not p.is_empty() and String(p.id) == "drop" and p.ph == "active" and _el(p) < float(p.act_len) - 0.1):
		return "hang"
	if p.is_empty():
		match String(q.mode):
			"crouch":
				return "crouch"
			"hop":
				return "hop"
		return "idle"
	match String(p.id):
		"strike":
			return "up" if p.ph == "cue" else "strike"
		"slam":
			if p.ph == "cue":
				return "up"
			return "hop" if p.ph == "active" and _el(p) < DIVE_T else "stuck"
		"clapper":
			return "swing" if p.ph == "cue" else ("strike" if p.ph == "active" else "idle")
		"rope":
			return "swing"
		"double":
			if p.ph == "cue":
				return "up"
			if p.get("alone", false):
				return "hop" if p.ph == "active" and (_el(p) < 0.2 or (_el(p) > 0.3 and _el(p) < 0.4)) else "strike"
			if p.ph == "active":
				return "hop" if _el(p) < DIVE_T * 0.5 else "strike"
			return "strike" if not p.get("split", false) else "stuck"
		"switch", "combo":
			if p.ph == "cue":
				return "crouch"
			return "hop" if p.ph == "active" and _el(p) < 0.5 else "strike"
		"triple":
			return "up" if p.ph == "cue" else ("hop" if p.ph == "active" else "idle")
		"drop":
			return "hang"
	return "idle"

func draw_boss_body(ci: CanvasItem) -> void:
	var intro_asleep: bool = (not active) and (intro_t0 < 0.0 or room.time - intro_t0 < 3.0 or dying)
	for q in th:
		var pose := _pose_of(q.i)
		var o := {"who": q.i, "x": q.x, "y": q.y, "face": q.face, "pose": pose, "t": room.time + float(q.i) * 0.37, "hot": _hot(), "eye": q.eye, "dial": q.dial, "a": 1.0}
		if intro_asleep:
			o["still"] = true
		if q.flash > 0.0:
			o["flash"] = true
		RaceBody.draw(ci, o)

func draw_boss_overlay(ci: CanvasItem) -> void:
	for q in th:
		var p: Dictionary = q.plan
		if p.is_empty() or (p.ph != "cue" and not (p.ph == "active" and _el(p) < 0.12)):
			continue
		var c := Color(COL[q.i])
		var eye := Vector2(float(q.x) + 3.0 * float(q.face), float(q.y) - 38.0 + (4.0 if p.id == "slam" and p.ph == "cue" else 0.0))
		var rp := Vector2(float(p.rx), float(p.ry))
		var k := 1.0 if p.ph == "cue" else 1.0 - _el(p) / 0.12
		ci.draw_line(eye, rp, Color(c.r, c.g, c.b, 0.5 * k), 2.0)                         # the thin beam from the eye to the READ point
		_afterimage(ci, rp, c, 0.4 * k)
	if room.time - clash_t0 < 0.5:                                                         # the hammers clashed: a star of sparks
		var u := (room.time - clash_t0) / 0.5
		for k in range(10):
			var a := TAU * float(k) / 10.0 + 0.3
			var r0 := 4.0 + 26.0 * u
			var r1 := r0 + 8.0 * (1.0 - u)
			ci.draw_line(clash_pt + Vector2(cos(a), sin(a)) * r0, clash_pt + Vector2(cos(a), sin(a)) * r1, Color(1.0, 1.0, 0.85, 1.0 - u), 2.0)

# the READ: a faint outline of the target where the automaton last saw it, in its colour (light from the eye, not a marker box)
func _afterimage(ci: CanvasItem, pt: Vector2, c: Color, a: float) -> void:
	var x0 := floorf(pt.x - 5.0)
	var y0 := floorf(pt.y - 5.0)
	var col := Color(c.r, c.g, c.b, a)
	ci.draw_rect(Rect2(x0, y0, 10.0, 10.0), col, false, 1.0)
	ci.draw_rect(Rect2(x0 + 1.0, y0 - 2.0, 2.0, 2.0), col)
	ci.draw_rect(Rect2(x0 + 7.0, y0 - 2.0, 2.0, 2.0), col)
	ci.draw_rect(Rect2(x0 + 2.0, y0 + 3.0, 1.0, 2.0), Color(c.r, c.g, c.b, a * 1.5))
	ci.draw_rect(Rect2(x0 + 7.0, y0 + 3.0, 1.0, 2.0), Color(c.r, c.g, c.b, a * 1.5))

func draw_hud(ci: CanvasItem) -> void:
	_draw_intro_line(ci)
	_draw_say(ci)

# ---- the other lines (estimated word times until M5 measures them): phase 2's two voices over each other, the survivor's
# [word, time, voice] voice 0 TICK red, 1 TOCK cyan
const P2_WORDS := [["We", 0.0, 0], ["both", 0.3, 0], ["read", 0.6, 0], ["zero.", 0.95, 0], ["We", 0.9, 1], ["both", 1.2, 1], ["wrote", 1.5, 1], ["one.", 1.9, 1]]
const ALONE_WORDS := [["Who", 0.0], ["wrote", 0.5], ["last?", 0.95], ["WHO", 2.4], ["WROTE", 2.8], ["LAST?", 3.25]]

func _draw_say(ci: CanvasItem) -> void:
	if say_t0 < 0.0 or (say_k != 2 and say_k != 3):
		return
	var el := room.time - say_t0
	var words: Array = []
	if say_k == 2:
		words = P2_WORDS.duplicate()
		words.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	else:
		for w in ALONE_WORDS:
			words.append([w[0], w[1], say_who])
	if el > float(words[words.size() - 1][1]) + 1.6:
		return
	var total := 0
	for w in words:
		total += PixelText.text_width(String(w[0]) + " ")
	var cx := 192.0 - float(total) * 0.5
	for w in words:
		var wt := String(w[0]) + " "
		if el >= float(w[1]):
			PixelText.draw_text(ci, wt, cx, 168.0, COL[int(w[2])], {"outline": Game.COL.ink})
		cx += float(PixelText.text_width(wt))

# ---- the intro line: "One at a time, little agent." said by both at once; the subtitle is the race itself (each word when its voice says it)
const INTRO_WORDS := [["One", 0.0], ["at", 0.38], ["a", 0.58], ["time,", 0.7], ["little", 1.12], ["agent.", 1.42]]
const INTRO_LEN := 1.9

func intro_words() -> Array:
	var out: Array = []
	for w in INTRO_WORDS:
		out.append([String(w[0]), float(w[1]) * 0.92, 0])                  # TICK: faster
		out.append([String(w[0]), 0.08 + float(w[1]) * 1.08, 1])           # TOCK: 0.08 s later and slower, so they drift apart
	out.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	return out

func _draw_intro_line(ci: CanvasItem) -> void:
	if say_k != 1 or say_t0 < 0.0:
		return
	var el := room.time - say_t0
	if el > INTRO_LEN + 1.2:
		return
	var words := intro_words()
	var total := 0
	for w in words:
		total += PixelText.text_width(String(w[0]) + " ")
	var x0 := 192.0 - float(total) * 0.5
	var y0 := 168.0
	var cx := x0
	for w in words:
		var wt := String(w[0]) + " "
		if el >= float(w[1]):
			PixelText.draw_text(ci, wt, cx, y0, COL[int(w[2])], {"outline": Game.COL.ink})
		cx += float(PixelText.text_width(wt))

# ---------------------------------------------------------------- net (the guest sees the same belfry and the same two bodies)
func _plan_pack(q: Dictionary) -> Array:
	var p: Dictionary = q.plan
	if p.is_empty():
		return [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, -1, -1, 30]
	return [int(p.seq), maxi(0, IDS.find(p.id)), PLAN_PH.find(p.ph), roundi(maxf(float(p.t), 0.0) * 100.0), 0 if p.tgt == "" else (1 if p.tgt == "p1" else 2),
		roundi(float(p.rx)), roundi(float(p.ry)), roundi(float(p.sx) * 4.0), roundi(float(p.sy) * 4.0), roundi(float(p.lx) * 4.0), roundi(float(p.ly) * 4.0), int(p.bell),
		roundi(float(p.cue_len) * 100.0), roundi(float(p.act_len) * 100.0), roundi(float(p.dir)), (2 if p.get("alone", false) else (1 if p.get("split", false) else 0)), 1 if p.get("hit", false) else 0,
		roundi(float(p.get("r2x", p.rx))), roundi(float(p.get("r2y", p.ry))), roundi(float(p.get("l2x", p.lx)) * 4.0), roundi(float(p.get("l2y", p.ly)) * 4.0),
		int(p.tb[0]), int(p.tb[1]), int(p.tb[2]), roundi(float(p.get("tbeat", 0.3)) * 100.0)]

func _th_pack(q: Dictionary) -> Array:
	var h: Dictionary = q.hop
	return [roundi(float(q.x) * 4.0), roundi(float(q.y) * 4.0), int(q.face), roundi(float(q.hp) * 10.0), int(q.max), int(q.st), ["idle", "crouch", "hop", "plan", "wait"].find(q.mode),
		roundi(float(h.get("t0", -1.0)) * 100.0), roundi(float(h.get("dur", 0.0)) * 100.0), int(q.hammer), roundi(float(q.daze_until) * 100.0), 1 if q.eye else 0, int(q.dial), int(q.bell),
		roundi(float(q.rx)), roundi(float(q.ry)), roundi(float(q.ox)), _plan_pack(q), 1 if q.air else 0]

func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, ph, roundi(trans_t0 * 100.0), roundi(intro_t0 * 100.0), say_k, roundi(say_t0 * 100.0),
		roundi(die_t0 * 100.0), roundi(clash_t0 * 100.0), roundi(clash_pt.x), roundi(clash_pt.y), say_who, roundi(rewind_t0 * 100.0), _th_pack(th[0]), _th_pack(th[1]), hl.net_pack() if hl != null else []]
	f.append(hz_pack())
	return f

const NF := 18

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	dying = int(f[3]) == 1
	ph = int(f[4])
	phase = ph
	trans_t0 = f[5] / 100.0
	intro_t0 = f[6] / 100.0
	say_k = int(f[7])
	say_t0 = f[8] / 100.0
	die_t0 = f[9] / 100.0
	clash_t0 = f[10] / 100.0
	clash_pt = Vector2(float(f[11]), float(f[12]))
	say_who = int(f[13])
	rewind_t0 = f[14] / 100.0
	for i in range(2):
		var a: Array = f[15 + i]
		var q: Dictionary = th[i]
		q.x = a[0] / 4.0
		q.y = a[1] / 4.0
		q.face = float(a[2])
		q.hp = a[3] / 10.0
		q.max = int(a[4])
		q.st = int(a[5])
		q.mode = ["idle", "crouch", "hop", "plan", "wait"][clampi(int(a[6]), 0, 4)]
		q.hop = {} if int(a[7]) < -50 else {"t0": a[7] / 100.0, "dur": a[8] / 100.0}
		q.hammer = int(a[9])
		q.daze_until = a[10] / 100.0
		q.eye = int(a[11]) == 1
		q.dial = int(a[12])
		q.bell = int(a[13])
		q.rx = float(a[14])
		q.ry = float(a[15])
		q.ox = float(a[16])
		_plan_unpack(q, a[17])
		q.air = int(a[18]) == 1
	_sums()
	var hl := _hall()
	if hl != null and not (f[17] as Array).is_empty():
		hl.net_unpack(f[17])
	hz_unpack(f[NF] if f.size() > NF else [])
	_sync_mirror()

func _plan_unpack(q: Dictionary, a: Array) -> void:
	if int(a[2]) < 0:
		q.plan = {}
		return
	var old: Dictionary = q.plan
	var keep_t: float = float(old.t) if (not old.is_empty() and int(old.seq) == int(a[0]) and old.ph == PLAN_PH[clampi(int(a[2]), 0, 2)]) else -1.0
	var p := {"seq": int(a[0]), "id": IDS[clampi(int(a[1]), 0, IDS.size() - 1)], "fam": "slam", "ph": PLAN_PH[clampi(int(a[2]), 0, 2)], "t": a[3] / 100.0,
		"tgt": ["", "p1", "p2"][clampi(int(a[4]), 0, 2)], "rx": float(a[5]), "ry": float(a[6]), "sx": a[7] / 4.0, "sy": a[8] / 4.0, "lx": a[9] / 4.0, "ly": a[10] / 4.0, "bell": int(a[11]),
		"cue_len": a[12] / 100.0, "act_len": a[13] / 100.0, "rec_len": 0.3, "dir": float(a[14]), "lock": 0.0, "split": int(a[15]) == 1, "alone": int(a[15]) == 2, "hit": int(a[16]) == 1,
		"r2x": float(a[17]), "r2y": float(a[18]), "l2x": a[19] / 4.0, "l2y": a[20] / 4.0, "tb": [int(a[21]), int(a[22]), int(a[23])], "tbeat": a[24] / 100.0}
	if keep_t >= 0.0 and absf(keep_t - float(p.t)) < 0.15:
		p.t = keep_t                                          # (counted down locally between snapshots: do not jump back)
	q.plan = p

# guest: the snapshot just applied, at host time tm (Coop._apply_snapshot)
func net_sample(tm: float) -> void:
	for i in range(2):
		var s: Array = hsamp[i]
		s.append([tm, th[i].x, th[i].y])
		while s.size() > 8:
			s.pop_front()

# guest: each body where it was at render time rt (as MERGE CONFLICT's heads)
func puppet_follow_parts(rt: float) -> void:
	for i in range(2):
		var s: Array = hsamp[i]
		if s.is_empty():
			continue
		var q: Dictionary = th[i]
		var last: Array = s[s.size() - 1]
		if rt >= last[0]:
			var vx := 0.0
			var vy := 0.0
			if s.size() >= 2 and q.st != 1:
				var prev: Array = s[s.size() - 2]
				var dt_: float = maxf(0.0001, last[0] - prev[0])
				vx = (last[1] - prev[1]) / dt_
				vy = (last[2] - prev[2]) / dt_
			var ex := minf(rt - last[0], 0.1)
			q.x = last[1] + vx * ex
			q.y = last[2] + vy * ex
			continue
		var done := false
		for k in range(s.size() - 1):
			if s[k][0] <= rt and rt <= s[k + 1][0]:
				var u: float = (rt - s[k][0]) / maxf(0.0001, s[k + 1][0] - s[k][0])
				q.x = lerpf(s[k][1], s[k + 1][1], u)
				q.y = lerpf(s[k][2], s[k + 1][2], u)
				done = true
				break
		if not done:
			q.x = s[0][1]
			q.y = s[0][2]
	_focus()

func puppet_tick(dt: float) -> void:
	hz_puppet_tick(dt)
	kit_age += dt
	for q in th:
		if q.flash > 0.0:
			q.flash -= dt
		var p: Dictionary = q.plan
		if p.is_empty():
			continue
		var s: int = int(p.seq)
		if not pseen.has(s):
			pseen[s] = String(p.ph)
		if float(p.t) > 0.0:
			p.t = maxf(0.0, float(p.t) - dt)
		if p.ph == "cue":
			cue_shown[s] = float(cue_shown.get(s, 0.0)) + dt
		elif p.ph == "active" and not kit_active_seen.has(s):
			kit_active_seen[s] = true
			var shown: float = float(cue_shown.get(s, 0.0))
			if shown < 0.30 and kit_violation == "" and pseen.get(s, "") == "cue":
				kit_violation = "%s plan %d active after %.2f s of cue" % [NAMES[q.i], s, shown]
	_sync_hall()
