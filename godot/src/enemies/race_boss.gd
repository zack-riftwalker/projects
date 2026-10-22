class_name RaceBoss
extends Boss
# RACE CONDITION v3 (T06): TICK (red, slim, reads where you are GOING) and TOCK (cyan, bearded, reads where you WERE), two bronze bell-strikers that attack at the
# same time (docs/metroidvania/17-race-build.md, 17-race-condition.md). A kit boss with two concurrent plans: each automaton has its own plan (cue, active,
# recover), a plan is state (it travels in net_fields), the guest is hurt only by what it was shown, and the arena (BelfryHall) is the room's.
# Everything is read from the bodies and the bells, never from a marker: the eye light and its thin beam to the READ point, a faint afterimage of the target,
# the raised hammer, the glowing bell. Hits go to the automaton whose hurtbox was struck; the pair shares one fight with two HP bars.

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
}
const DIVE_T := 0.25                                 # a slam's dive, then its box on the landing
const RING_R := 80.0
const RING_THICK := 6.0
const HOP_T := 0.45
const CROUCH_T := 0.25
const GAP_MIN := 0.3
const GAP_MAX := 0.4
const STAGGER := 0.15                                # two single strikes of different automata do not land within this
const DAZE_CAUGHT := 0.7                             # a caught clapper that comes back hurts TOCK and dazes it

var th: Array = []
var ph := 1                                          # 1 / 2 (phase 2: M4)
var trans_t0 := -1.0
var intro_t0 := -1.0
var say_k := 0                                       # which line plays (0 none, 1 intro, 2 p2, 3 alone, 4 die)
var say_t0 := -1.0
var die_t0 := -1.0
var ass: Array = ["p1", "p2"]                        # which player each automaton reads next (they swap after every plan)
var hist := {"p1": [], "p2": []}                     # host: the last 0.3 s of each player's centre, for the prefetch
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
		"dest": -1, "next": "", "flash": 0.0, "n": 0, "start_at": 0.0, "rx": 0.0, "ry": 0.0, "r2x": 0.0, "r2y": 0.0, "t0": 0.0}

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
	return th.filter(func(q): return q.st == 0)

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
func _track(dt: float) -> void:
	for key in ["p1", "p2"]:
		var q = kit_body(key)
		var a: Array = hist[key]
		if q == null or q.dead:
			a.clear()
			continue
		a.append([room.time, q.x + q.w * 0.5, q.y + q.h * 0.5])
		while a.size() > 2 and room.time - float(a[0][0]) > 0.3:
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

# ---------------------------------------------------------------- hurt and harm boxes
func hurtboxes() -> Array:
	var b: Array = []
	for q in th:
		if q.st == 0:
			b.append({"x": q.x - BODY_W * 0.5, "y": q.y - BODY_H, "w": BODY_W, "h": BODY_H, "th": q.i})
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
	out.append_array(hz_harm())
	return out

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
	var i := -1
	if box is Dictionary and box.has("th"):
		i = int(box.th)
	else:
		var best := -1.0
		for q in th:
			if q.st == 0 and float(q.hp) > best:
				best = float(q.hp)
				i = int(q.i)
	if i < 0 or th[i].st != 0:
		return ""
	var q: Dictionary = th[i]
	var dm := float(d)
	if how == "agent" or how == "dash":
		dm *= 0.5
	q.hp -= dm
	q.flash = 0.1
	_sums()
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

func _daze(i: int, secs: float) -> void:
	var q: Dictionary = th[i]
	q.daze_until = room.time + secs
	q.hammer = 0
	if not q.plan.is_empty():
		q.plan = {}
		q.mode = "idle"
		q.gap = 0.0
		q.eye = false
	_sync_mirror()

# an automaton at 0 hp winds down where it stands (M4: the survivor's alone / rewind logic)
func _fall(i: int) -> void:
	var q: Dictionary = th[i]
	q.st = 1
	q.plan = {}
	q.mode = "idle"
	q.eye = false
	q.hammer = 0
	q.hop = {}
	var gy := _ground_at(q.x, q.y)
	q.y = gy.y
	q.bell = int(gy.bell)
	_sync_mirror()

func start() -> void:
	super.start()
	for q in th:
		q.gap = 0.8 + 0.4 * float(q.i)
		q.mode = "idle"
		q.eye = false
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
		_audio_edges()
		return
	plan_clock += dt
	_track(dt)
	for i in range(2):
		_step_th(i, dt)
	_sync_mirror()
	_focus()
	_audio_edges()

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
		if q.st == 0:
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
	return best

func _partner_on(i: int, b: int) -> bool:
	var o: Dictionary = th[1 - i]
	return o.st == 0 and (int(o.bell) == b or int(o.dest) == b)

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

# ---------------------------------------------------------------- one automaton
func _step_th(i: int, dt: float) -> void:
	var q: Dictionary = th[i]
	if q.st != 0:
		return
	if room.time < float(q.daze_until):
		return
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
			if room.time >= float(q.start_at):
				_cue_start(i)
		"plan":
			_plan_logic(i, dt)

# weighted choice by distance: far, bell strikes and the clapper; near, slams and the rope; never the same twice, a fixed order the first time
func _choose(i: int) -> String:
	var q: Dictionary = th[i]
	if int(q.n) == 0:
		return "strike" if i == 1 else "slam"                  # the teaching order of phase 1 (the double write follows in M3)
	var key := _key_for(i)
	var d := absf(kit_aim(key).x - float(q.x))
	var opts: Array = []                                       # [id, weight]
	if d > NEAR_PX:
		opts = [["strike", 3.0], ["slam", 1.0]]
		if i == 1:
			opts.append(["clapper", 2.0])
	else:
		opts = [["slam", 3.0], ["strike", 1.0]]
		if i == 0:
			opts.append(["rope", 2.0])
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

func _begin_next(i: int) -> void:
	var q: Dictionary = th[i]
	if alive_n() == 0:
		return
	var id := _choose(i)
	q.next = id
	var key := _key_for(i)
	var pt := read_point(i, key)
	var b := _pick_bell(i, pt)
	if id == "rope" and int(q.bell) >= 0:
		b = int(q.bell)
	if id == "clapper" or id == "strike" or id == "slam" or id == "rope":
		if b >= 0 and b != int(q.bell):
			q.dest = b
			q.mode = "crouch"
			q.mt = CROUCH_T
			return
	if int(q.bell) < 0 and b >= 0:
		q.dest = b
		q.mode = "crouch"
		q.mt = CROUCH_T
		return
	_to_wait(i)

func _to_wait(i: int) -> void:
	var q: Dictionary = th[i]
	q.mode = "wait"
	q.start_at = _next_beat(room.time)

func _launch(i: int) -> void:
	var q: Dictionary = th[i]
	var b: int = int(q.dest)
	var rc := BelfryHall.new_rest(b)
	var to := Vector2(clampf(rc.position.x + rc.size.x * 0.5 + (0.0 if rc.size.x < 60.0 else clampf(float(q.rx) - (rc.position.x + rc.size.x * 0.5), -20.0, 20.0)), ARENA_L, ARENA_R), rc.position.y)
	q.ox = to.x - (rc.position.x + rc.size.x * 0.5)
	q.hop = {"t0": snappedf(room.time, 0.01), "dur": HOP_T, "fx": q.x, "fy": q.y, "tx": to.x, "ty": to.y}
	q.face = 1.0 if to.x >= q.x else -1.0
	q.bell = -1
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
		if hl != null and hl.bell_standable(b, room.time):
			q.bell = b
			hl.kick(b)                                        # landing on a bell kicks it: a small harmless ring from its swing
			var sp := _stand(i)
			q.x = sp.x
			q.y = sp.y
		else:
			var g := _ground_at(q.x, q.y)
			q.bell = int(g.bell)
			q.y = float(g.y)
		q.hop = {}
		_to_wait(i)

# ---------------------------------------------------------------- a plan
func _cue_len(id: String) -> float:
	return float(PLANS[id][0]) * _beat() * _tm()

func _rec_len(id: String) -> float:
	return _pm_rec(float(PLANS[id][2]))

func _cue_start(i: int) -> void:
	var q: Dictionary = th[i]
	var id: String = String(q.next)
	var key := _key_for(i)
	var cue := _cue_len(id)
	var o: Dictionary = th[1 - i]
	if not o.plan.is_empty() and o.plan.ph != "recover" and absf(float(o.plan.land_at) - (room.time + cue)) < STAGGER:
		q.start_at = room.time + _beat()                      # two strikes do not land together: this one waits a beat
		return
	var rp := read_point(i, key)
	q.rx = rp.x
	q.ry = rp.y
	plan_seq += 1
	var sp := _stand(i)
	q.x = sp.x if int(q.bell) >= 0 else q.x
	q.y = sp.y if int(q.bell) >= 0 else q.y
	var p := {"seq": plan_seq, "id": id, "fam": "slam", "tgt": key, "ph": "cue", "t": cue, "cue_len": cue, "act_len": float(PLANS[id][1]), "rec_len": _rec_len(id),
		"rx": rp.x, "ry": rp.y, "sx": q.x, "sy": q.y, "lx": q.x, "ly": q.y, "bell": int(q.bell), "land_at": room.time + cue, "hold": 0.0, "ack_at": -1.0, "dir": 1.0}
	if not _guest_waits():
		p.ack_at = plan_clock
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
	q.face = float(p.dir) if id == "rope" else (1.0 if rp.x >= q.x else -1.0)
	q.plan = p
	q.mode = "plan"
	q.eye = true
	q.dial = (int(q.dial) + 1) % 12                           # the chest clock ticks once: the READ
	q.hammer = 1
	var hl := _hall()
	if hl != null and int(q.bell) >= 0 and (id == "strike" or id == "clapper"):
		hl.kick(int(q.bell))                                  # the bell it will ring starts to glow and sway
	Game.dlog("%s %s -> %s (read %d,%d)" % [NAMES[i], id, key, roundi(rp.x), roundi(rp.y)])
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
				return
			p.ph = "active"
			p.t = float(p.act_len)
			q.eye = false
			_on_active(i)
		"active":
			_active_step(i, dt)
			if p.t <= 0.0:
				p.ph = "recover"
				p.t = float(p.rec_len)
				_on_recover(i)
		"recover":
			if p.t <= 0.0:
				_plan_done(i)

func _on_active(i: int) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	var hl := _hall()
	match String(p.id):
		"strike":
			if hl != null and int(p.bell) >= 0:
				hl.strike(int(p.bell))
			Audio.sfx("clang", {"vol": 0.8})
			room.shake(0.25)
		"slam":
			Audio.sfx("swipeBig", {"vol": 0.6})
		"clapper":
			_shoot_clapper(i)
		"rope":
			Audio.sfx("swipe", {"vol": 0.7})

func _active_step(i: int, _dt: float) -> void:
	var q: Dictionary = th[i]
	var p: Dictionary = q.plan
	var el := _el(p)
	var hl := _hall()
	match String(p.id):
		"slam":
			if el < DIVE_T:                                   # the dive: up a little, then fast to the read point
				var u := el / DIVE_T
				q.x = lerpf(float(p.sx), float(p.lx), u)
				q.y = lerpf(float(p.sy), float(p.ly), u * u) - 14.0 * 4.0 * u * (1.0 - u)
			else:
				q.x = float(p.lx)
				q.y = float(p.ly)
				if not p.get("landed", false):
					p["landed"] = true
					q.bell = int(p.get("lb", -1))
					q.ox = 0.0
					q.hammer = 2
					room.shake(0.45)
					Audio.sfx("thud", {"vol": 0.9})
					if hl != null and int(q.bell) >= 0:
						hl.kick(int(q.bell))
		"rope":
			var u2 := el / float(p.act_len)
			q.x = clampf(float(p.sx) + float(p.dir) * 50.0 * sin(PI * u2), ARENA_L, ARENA_R)
			q.y = float(p.sy) - 18.0 * sin(PI * u2)

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
		_:
			q.hammer = 0

func _plan_done(i: int) -> void:
	var q: Dictionary = th[i]
	q.last = String(q.plan.id)
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

# the test harness and the kit's old one-plan calls: start `id` on the right automaton now (TOCK for the clapper, TICK for the rope), the cue as for a real one
func _start(id: String, tgt := "p1") -> void:
	var i := 1 if id == "clapper" else 0
	for q in th:
		q.plan = {}
		q.mode = "idle"
		q.hop = {}
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
		var f := clampf(float(q.hp) / maxf(1.0, float(q.max)), 0.0, 1.0) if q.st == 0 else 0.0
		out.append([f, COL[q.i], NAMES[q.i], q.st != 0])
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

# ---------------------------------------------------------------- sounds from state edges (both pages: the plan phases are in the snapshot); M5 fills it
func _audio_edges() -> void:
	pass

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
	return "idle"

func draw_boss_body(ci: CanvasItem) -> void:
	var intro_asleep: bool = (not active) and (intro_t0 < 0.0 or room.time - intro_t0 < 3.0 or dying)
	for q in th:
		var pose := _pose_of(q.i)
		var o := {"who": q.i, "x": q.x, "y": q.y, "face": q.face, "pose": pose, "t": room.time + float(q.i) * 0.37, "hot": 0.0 if ph == 1 else 1.0, "eye": q.eye, "dial": q.dial, "a": 1.0}
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
		ci.draw_line(eye, rp, Color(c.r, c.g, c.b, 0.5 * k), 2.0)                       # the thin beam from the eye to the READ point
		_afterimage(ci, rp, c, 0.4 * k)
		if p.id == "slam" and p.ph == "cue":                                              # (the landing is the read point's ground)
			pass

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

# the ring waves and the kick are drawn here: light, not markers
func draw_hud(ci: CanvasItem) -> void:
	_draw_intro_line(ci)

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
		return [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0]
	return [int(p.seq), maxi(0, IDS.find(p.id)), PLAN_PH.find(p.ph), roundi(maxf(float(p.t), 0.0) * 100.0), 0 if p.tgt == "" else (1 if p.tgt == "p1" else 2),
		roundi(float(p.rx)), roundi(float(p.ry)), roundi(float(p.sx) * 4.0), roundi(float(p.sy) * 4.0), roundi(float(p.lx) * 4.0), roundi(float(p.ly) * 4.0), int(p.bell),
		roundi(float(p.cue_len) * 100.0), roundi(float(p.act_len) * 100.0), roundi(float(p.dir))]

func _th_pack(q: Dictionary) -> Array:
	var h: Dictionary = q.hop
	return [roundi(float(q.x) * 4.0), roundi(float(q.y) * 4.0), int(q.face), roundi(float(q.hp) * 10.0), int(q.max), int(q.st), ["idle", "crouch", "hop", "plan", "wait"].find(q.mode),
		roundi(float(h.get("t0", -1.0)) * 100.0), roundi(float(h.get("dur", 0.0)) * 100.0), int(q.hammer), roundi(float(q.daze_until) * 100.0), 1 if q.eye else 0, int(q.dial), int(q.bell),
		roundi(float(q.rx)), roundi(float(q.ry)), roundi(float(q.ox)), _plan_pack(q)]

func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, ph, roundi(trans_t0 * 100.0), roundi(intro_t0 * 100.0), say_k, roundi(say_t0 * 100.0),
		roundi(die_t0 * 100.0), _th_pack(th[0]), _th_pack(th[1]), hl.net_pack() if hl != null else []]
	f.append(hz_pack())
	return f

const NF := 13

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
	for i in range(2):
		var a: Array = f[10 + i]
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
	_sums()
	var hl := _hall()
	if hl != null and not (f[12] as Array).is_empty():
		hl.net_unpack(f[12])
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
		"cue_len": a[12] / 100.0, "act_len": a[13] / 100.0, "rec_len": 0.3, "dir": float(a[14]), "lock": 0.0}
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
			if s.size() >= 2 and q.st == 0:
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
	_audio_edges()
