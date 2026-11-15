class_name LoopBoss
extends Boss
# INFINITE LOOP v3 (T10, docs/metroidvania/18-loop-build.md): an old retry worker of the tower's scheduler that the user's refactor turned into
# `while (true)`. A long verdigris chain snake that bites its own tail, a condition plate `true` on its brow.
#
# The body: a head (40 x 32) and LINKS chain links (16 x 16) that follow the head's own path (a trail of the head's positions; link k sits
# NECK + GAP k behind the head along it), so the body moves like a train. The host moves the head; the snapshot carries the head and the links
# (the guest draws and checks exactly them, interpolated between snapshots), the plan, the plate and the hall's state.
# Attacks are kit plans (one at a time): a cue shown by the body only (jaw, eye, plate, head pose), then the active part, then a recovery.
# Every page checks its own body against harmboxes(): the head and every link hurt by touch (1 and a knock-back) outside the scenes, a lunge's
# head 2, the spat rings are projectiles.

const IDS := ["lunge", "dive", "coil", "spit", "calm", "recursion", "escalate", "wrap_dive"]
const FAM := {"lunge": "lunge", "dive": "slam", "coil": "sweep", "spit": "proj", "calm": "guard", "recursion": "proj", "escalate": "lunge", "wrap_dive": "slam"}
const MODES := ["hidden", "descend", "swim", "plan", "stuck", "broken", "recoil", "trans", "dead"]
const LINKS := 14
const GAP := 14.0
const NECK := 24.0
const HEAD_W := 40.0
const HEAD_H := 32.0
const LINK_S := 16.0
const TRAIL_STEP := 2.0
const TRAIL_MAX := 150                     # points kept (300 px of path)
const SPEED := [90.0, 105.0, 120.0]        # swim speed per phase (px/s)
const TURN := deg_to_rad(140.0)            # turn rate (rad/s)
const ITER_K := 0.06
const ITER_MAX := 1.18
const MARGIN := 40.0                       # it keeps this far from the walls (not in a dive)
const ARENA := Rect2(40.0, 48.0, 304.0, 384.0)
const CUE_NORMAL := [0.5, 0.45, 0.4]
const CUE_HEAVY := [0.75, 0.7, 0.7]
const LUNGE_LEN := 160.0
const LUNGE_V := 420.0
const DIVE_V := 480.0
const COIL_R := [64.0, 40.0, 26.0]         # the ring: from, closed (end of the cue), squeezed (end of the active part)
const RING_V := 110.0
const NEAR_PX := 96.0
const FAR_PX := 160.0
const CAMP_BOX := 48.0
const CAMP_T := 2.5
const CAMP_CD := 6.0
const INTRO_LONG := 7.6                    # the first time: the chain comes down (3.0 s), bites its tail, the plate lights, the line
const INTRO_SHORT := 2.0
const DESCEND_LONG := 3.0
const DESCEND_SHORT := 1.6
const COIL_C := Vector2(192.0, 64.0)       # the intro's coil round the gantry
const COIL_RR := 36.0
const DROP_X := 228.0
const DROP_Y0 := -60.0
const INK := "#1b1226"
const VD := ["#0f2a27", "#1d4a44", "#2f7f6a", "#5fc0a0", "#b8f0d8"]
const RIVET := "#dcae5e"
const OPUS := "#9b6bff"
const HEAT := "#ff7a59"
const YELLOW := "#ffd23f"
const SAY := {1: "intro", 2: "p2", 3: "p3", 4: "again"}
const BREAK_T := [2.0, 1.8, 1.6]           # the break window (it lies on the floor, every link takes full damage)
const RECOIL_T := 0.5                      # then it bites its tail again (invulnerable), i++
const HALF_WINDOW := 3.0                   # a second half hit on the plate within this breaks it
const BP_IMMUNE := [4.0, 4.0, 6.0]         # after a freeze, breakpoint does not take this long
const LIE_V := 520.0

static var tex_head: Texture2D
static var tex_links: Texture2D
static var tex_plate: Texture2D
static var lspr := {}
static var lines := {}

var hx := DROP_X
var hy := DROP_Y0
var ang := PI / 2.0
var trail := PackedVector2Array()          # host: the head's path, newest first, a point every TRAIL_STEP px
var links: Array = []                      # link centres, the neck first (the tail last)
var n_links := LINKS
var mode := "hidden"
var ph := 1
var iter := 0                              # breaks so far (the counter on the wall is the hall's)
var i_phase := 0                           # breaks in this phase (the speed-up)
var stuck_t := 0.0
var gap_t := 0.8                           # host: time to the next plan
var last_id := ""
var queue: Array = []                      # host: the phase's fixed first cycle
var intro_t0 := -1.0
var say_k := 0
var say_t0 := -10.0
var swim_key := "p1"
var orbit_a := 0.0                         # host: where on its circle round the target it swims
var lunge_d := Vector2.RIGHT               # the active lunge's direction and length
var lunge_len := 0.0
var lunge_o := Vector2.ZERO
var coil_c := Vector2.ZERO
var coil_a := 0.0
var dive_x := 0.0
var spat := false
var camp := {}                             # host: key -> [x, y, since]
var camp_cd := 0.0
var flick_t := -10.0                       # the tail's flick (a hit on it)
var hsamp: Array = []                      # guest: [tm, hx, hy, ang, links]
var bp := false                            # the room's breakpoint may stop it now (derived every frame, both pages)
var half_t0 := -10.0                       # the first half hit on the plate (a stuck head, a caught yellow ring)
var immune_until := -10.0                  # breakpoint does not take until then (it shivers blue)
var shiver_t0 := -10.0
var brk_t0 := -10.0                        # the condition broke: it lies on the floor
var recoil_t0 := -10.0
var breaks_total := 0                      # (the first break says `...again.`)
var lie: Array = []                        # host: where each link (and the head, last) comes to lie
var last_bp_off := 0.0
var _flag_hash := 0

func _init(r: Room, bx: float, by: float, base_hp := 126) -> void:
	super(r, 192.0, 100.0, HEAD_W, HEAD_H, base_hp)
	boss_name = "INFINITE LOOP"
	sub = "while (true)"
	col = VD[2]
	kit_init()
	_load_art()
	_seed_trail(Vector2(DROP_X, DROP_Y0), Vector2(0.0, -1.0))
	_rebuild_links()
	_place()

static func _load_art() -> void:
	if tex_head != null:
		return
	tex_head = load("res://assets/sprites/loop_head.png")
	tex_links = load("res://assets/sprites/loop_links.png")
	tex_plate = load("res://assets/sprites/loop_plate.png")
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/loop_sprites.json"))
	lspr = j if j is Dictionary else {}
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voice/loop.json")) if FileAccess.file_exists("res://assets/voice/loop.json") else null
	lines = v if v is Dictionary else {}

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return []

func _hall() -> LoopHall:
	return room.shaft

func _big() -> int:
	return int(Game.dv("big_hit"))

func _phase_hp() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= 0.33 else (2 if f <= 0.66 else 1)

func _place() -> void:
	x = hx - w / 2.0
	y = hy - h / 2.0

# ---------------------------------------------------------------- the body: the trail and the links
func _seed_trail(at: Vector2, back: Vector2) -> void:
	trail = PackedVector2Array()
	for k in range(TRAIL_MAX):
		trail.append(at + back * TRAIL_STEP * float(k))

func _push_trail() -> void:
	var hp_ := Vector2(hx, hy)
	if trail.is_empty():
		trail.append(hp_)
		return
	var d := hp_.distance_to(trail[0])
	if d < TRAIL_STEP:
		return                                      # (not far enough yet: the links read the head itself first)
	var n := mini(int(d / TRAIL_STEP), 40)
	var from := trail[0]
	for k in range(1, n + 1):
		trail.insert(0, from.lerp(hp_, float(k) / float(n)))
	while trail.size() > TRAIL_MAX:
		trail.remove_at(trail.size() - 1)

# link k at arc length NECK + GAP k behind the head, along (head, trail...)
func _rebuild_links() -> void:
	links.clear()
	var want := NECK
	var acc := 0.0
	var prev := Vector2(hx, hy)
	var i := 0
	var k := 0
	while k < n_links:
		if i >= trail.size():
			links.append(prev)
			k += 1
			want += GAP
			continue
		var p := trail[i]
		var seg := prev.distance_to(p)
		if acc + seg >= want and seg > 0.0001:
			var u := (want - acc) / seg
			var q := prev.lerp(p, u)
			links.append(q)
			k += 1
			want += GAP
			continue
		acc += seg
		prev = p
		i += 1

func tail_point() -> Vector2:
	return links[links.size() - 1] if not links.is_empty() else Vector2(hx, hy)

func dir8() -> int:
	return posmod(roundi(ang / (PI / 4.0)), 8)

func head_rect() -> Rect2:
	return Rect2(hx - 14.0, hy - 12.0, 28.0, 24.0)

func plate_rect() -> Rect2:
	var pa: Array = lspr.get("plate_at", [-6.0, -12.0])
	var o := Vector2(float(pa[0]), float(pa[1])).rotated(snappedf(ang, PI / 4.0))
	if cos(snappedf(ang, PI / 4.0)) < -0.01:
		o = Vector2(-float(pa[0]), float(pa[1])).rotated(snappedf(ang, PI / 4.0) - PI)
	return Rect2(hx + o.x - 9.0, hy + o.y - 4.0, 18.0, 8.0)

# ---------------------------------------------------------------- what can be touched, what hurts
func _touch_on() -> bool:
	if not active or dying or loss_on or bp_t > 0.0:
		return false
	return mode == "swim" or mode == "plan" or mode == "stuck"

# breakpoint takes when it is not in an active part, not lying, not in a scene; while immune it is still a target (and shivers)
func _bp_now() -> bool:
	if not active or dying or loss_on or bp_t > 0.0:
		return false
	if not (mode == "swim" or mode == "plan" or mode == "stuck"):
		return false
	return plan.is_empty() or plan.ph != "active"

# host: room.bp_apply asks before it freezes; true = refused (immune): the clang and a blue shiver, nothing else
func bp_refused() -> bool:
	if room.time < immune_until:
		shiver_t0 = room.time
		Audio.sfx("loop_bpclang", {"vol": 0.8})
		return true
	return false

# frozen: the top of every link (and the head) is a one-way platform, on both pages
func bp_plats() -> Array:
	var out: Array = []
	for c in links:
		out.append({"x": c.x - 8.0, "y": c.y - 7.0, "w": 16.0, "h": 4.0, "dx": 0.0, "dy": 0.0})
	out.append({"x": hx - 14.0, "y": hy - 10.0, "w": 28.0, "h": 4.0, "dx": 0.0, "dy": 0.0})
	return out

func touch_boxes() -> Array:
	var out: Array = []
	if not _touch_on():
		return out
	var hr := head_rect()
	out.append({"x": hr.position.x, "y": hr.position.y, "w": hr.size.x, "h": hr.size.y, "dmg": 1, "sx": hx, "touch": 0})
	for k in range(links.size()):
		var c: Vector2 = links[k]
		out.append({"x": c.x - 6.0, "y": c.y - 6.0, "w": 12.0, "h": 12.0, "dmg": 1, "sx": c.x, "touch": k + 1})
	return out

func attack_boxes() -> Array:
	var out: Array = []
	if plan.is_empty() or plan.ph != "active" or not _touch_on():
		return out
	match String(plan.id):
		"lunge", "escalate":
			var hr := head_rect().grow(2.0)
			out.append({"x": hr.position.x, "y": hr.position.y, "w": hr.size.x, "h": hr.size.y, "dmg": _big(), "sx": hx, "sid": int(plan.seq)})
		"dive", "wrap_dive":
			var hr2 := head_rect()
			out.append({"x": hr2.position.x, "y": hr2.position.y, "w": hr2.size.x, "h": hr2.size.y + 6.0, "dmg": 1, "sx": hx, "sid": int(plan.seq)})
	return out

func harmboxes() -> Array:
	var out: Array = attack_boxes()
	out.append_array(touch_boxes())
	return out

func hurtboxes() -> Array:
	var b: Array = []
	if not active or dying or mode == "hidden" or mode == "descend":
		return b
	var hr := head_rect()
	b.append({"x": hr.position.x, "y": hr.position.y - 8.0, "w": hr.size.x, "h": hr.size.y + 8.0, "head": 1})       # (with the plate on the brow)
	for k in range(links.size()):
		var c: Vector2 = links[k]
		b.append({"x": c.x - 7.0, "y": c.y - 7.0, "w": 14.0, "h": 14.0, "link": k})
	return b

# ---------------------------------------------------------------- damage
func hit(d: int, dx: float, dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	if mode == "trans" or mode == "recoil" or mode == "descend" or mode == "hidden":
		return "block"
	var k := -1
	if box is Dictionary and box.has("link"):
		k = int(box.link)
	if mode == "broken":                                      # the break window: every link and the head take full damage
		var at0: Vector2 = links[k] if k >= 0 and k < links.size() else Vector2(hx, hy)
		return super.hit(d, dx, dy, how, {"x": at0.x - 7.0, "y": at0.y - 7.0, "w": 14.0, "h": 14.0})
	if box is Dictionary and box.has("head"):                 # the condition plate (on the head)
		if bp_t > 0.0:
			_break()                                          # frozen: one hit and `true` becomes `false`
			return "hit"
		if mode == "stuck" or how == "catch":
			return _half()
	if k == links.size() - 1:                                 # the tail tip: full damage, it flicks
		flick_t = room.time
		var tp := tail_point()
		var res := super.hit(d, dx, dy, how, {"x": tp.x - 7.0, "y": tp.y - 7.0, "w": 14.0, "h": 14.0})
		for q in room.players():
			if absf(q.x + q.w / 2.0 - tp.x) < 28.0 and absf(q.y + q.h / 2.0 - tp.y) < 28.0:
				q.vx = signf(q.x + q.w / 2.0 - tp.x + 0.01) * 80.0
		return res
	Audio.sfx("clang", {"vol": 0.6})                          # the head (outside its chances, M3) and the middle links ring
	var at: Vector2 = links[k] if k >= 0 and k < links.size() else Vector2(hx, hy)
	room.burst(at.x, at.y, 3, [VD[4], "#ffffff"], 70.0, 200.0)
	return "block"

# a half hit: `tru_` flickers; a second within 3 s breaks the condition
func _half() -> String:
	if room.time - half_t0 <= HALF_WINDOW:
		_break()
		return "hit"
	half_t0 = room.time
	Audio.sfx("loop_clack", {"vol": 0.5})
	room.burst(hx, hy - 14.0, 4, [VD[4], "#ffffff"], 70.0, 200.0)
	return "hit"

# the loop breaks: `false`, it lets go and lies along the floor (or the ledge under it) for the window
func _break() -> void:
	bp_t = 0.0
	plan = {}
	mode = "broken"
	brk_t0 = room.time
	half_t0 = -10.0
	lie.clear()
	# it lies straight along the surface under its head, the body toward the middle of the room (a link past a ledge's end drops to the floor)
	var gy := _ground_below(hx, hy - 4.0)
	var side := -1.0 if hx > 192.0 else 1.0
	var hx2 := clampf(hx, 36.0, float(room.pw) - 36.0)
	for kk in range(links.size()):
		var lx := hx2 + side * (NECK + GAP * float(kk))
		if lx < 24.0 or lx > float(room.pw) - 24.0:            # (no room that way: it folds back along the floor)
			lx = clampf(lx, 24.0, float(room.pw) - 24.0)
		lie.append(Vector2(lx, _ground_below(lx, gy - 4.0) - 8.0))
	lie.append(Vector2(hx2, gy - 12.0))
	room.shake(0.6)
	Audio.sfx("loop_clack", {"vol": 1.0})
	Audio.sfx("loop_collapse", {"vol": 0.8})
	room.burst(hx, hy - 14.0, 10, ["#ff4d5a", "#ffffff"], 110.0, 300.0)
	breaks_total += 1
	if breaks_total == 1:
		_say(4)
	Game.dlog("LOOP break %d (phase %d)" % [breaks_total, ph])

func _step_broken(dt: float) -> void:
	for kk in range(links.size()):
		if kk < lie.size():
			var c: Vector2 = links[kk]
			links[kk] = c.move_toward(lie[kk], LIE_V * dt)
	if lie.size() > links.size():
		var hv := Vector2(hx, hy).move_toward(lie[lie.size() - 1], LIE_V * dt)
		hx = hv.x
		hy = hv.y
		ang = 0.0 if float(lie[0].x) < hx else PI
	if room.time - brk_t0 >= BREAK_T[ph - 1]:
		mode = "recoil"
		recoil_t0 = room.time
		Audio.sfx("loop_click", {"vol": 0.9})

# it gathers itself up and bites its tail again: i++ (the counter, a little faster)
func _step_recoil(dt: float) -> void:
	hy = move_toward(hy, maxf(60.0, hy - 40.0), 80.0 * dt)
	if room.time - recoil_t0 >= RECOIL_T:
		iter += 1
		i_phase += 1
		var hl := _hall()
		if hl != null:
			hl.set_counter(hl.counter + 1)
			if ph == 2:
				hl.flip_gears(room.time)
		_trail_from_body()
		mode = "swim"
		gap_t = 0.4
		swim_key = kit_pick_target()

# the trail again from the body as it lies (so the chain swims on from where it is)
func _trail_from_body() -> void:
	var pts: Array = [Vector2(hx, hy)]
	pts.append_array(links)
	trail = PackedVector2Array()
	for kk in range(pts.size() - 1):
		var a: Vector2 = pts[kk]
		var bb: Vector2 = pts[kk + 1]
		var n := maxi(1, int(a.distance_to(bb) / TRAIL_STEP))
		for j in range(n):
			trail.append(a.lerp(bb, float(j) / float(n)))
	var last: Vector2 = pts[pts.size() - 1]
	while trail.size() < TRAIL_MAX:
		trail.append(last)
	_rebuild_links()

func blocks(_dx: float, _dy: float, _how: String) -> bool:
	return false

func on_damage() -> void:
	pass

# ---------------------------------------------------------------- the fight flow
func intro_long() -> bool:
	return not Game.flag("intro:LOOP_SEEN")

func intro_len() -> float:
	return (DESCEND_LONG + 0.2 + say_len(1) + 0.4) if intro_long() else INTRO_SHORT

# the intro's camera (both pages, from intro_t0): up to the gantry while the chain comes down and speaks, back to the floor for the fight
func cam_lock_now():
	if active or dying or intro_t0 < 0.0 or room.fight.state != "intro":
		return null
	var el := room.time - intro_t0
	if el > intro_len() - 0.7:
		return null
	return {"x": 0.0, "y": 0.0}

func start() -> void:
	super.start()
	Game.flags["intro:LOOP_SEEN"] = true
	if mode == "hidden" or mode == "descend":                 # (a fight started without its intro: a test, the skip button)
		_finish_descent()
	mode = "swim"
	ang = 0.0
	gap_t = 0.6
	queue = ["spit", "lunge", "calm"]
	swim_key = kit_pick_target()
	_sync_hall()

func _finish_descent() -> void:
	var path_len := _descent_len()
	var hp_ := _descent_point(path_len)
	hx = hp_.x
	hy = hp_.y
	_seed_descent(path_len)
	ang = _descent_ang(path_len)

# the intro: the head comes straight down at x 228 from above the shaft, then once round the gantry (clockwise) until it meets its tail
func _descent_len() -> float:
	return (COIL_C.y - DROP_Y0) + TAU * COIL_RR

func _descent_point(s: float) -> Vector2:
	var drop := COIL_C.y - DROP_Y0
	if s <= drop:
		return Vector2(DROP_X, DROP_Y0 + s)
	var a := (s - drop) / COIL_RR
	return COIL_C + Vector2(cos(a), sin(a)) * COIL_RR

func _descent_ang(s: float) -> float:
	var drop := COIL_C.y - DROP_Y0
	if s <= drop:
		return PI / 2.0
	return (s - drop) / COIL_RR + PI / 2.0

func _seed_descent(s: float) -> void:
	trail = PackedVector2Array()
	var k := 0
	while k < TRAIL_MAX:
		var sv := s - float(k) * TRAIL_STEP
		trail.append(_descent_point(sv) if sv >= 0.0 else Vector2(DROP_X, DROP_Y0 + sv))
		k += 1
	_rebuild_links()

func _step_intro() -> void:
	if intro_t0 < 0.0:
		intro_t0 = room.time
		mode = "descend"
		Audio.sfx("loop_chain", {"vol": 0.7})
	var el := room.time - intro_t0
	var dl := DESCEND_LONG if intro_long() else DESCEND_SHORT
	var s := clampf(el / dl, 0.0, 1.0) * _descent_len()
	var hp_ := _descent_point(s)
	hx = hp_.x
	hy = hp_.y
	ang = _descent_ang(s)
	_seed_descent(s)
	if el >= dl and say_k == 0 and intro_long() and el >= dl + 0.2:
		_say(1)
	if el >= dl and not bool(get_meta("bit", false)):
		set_meta("bit", true)
		Audio.sfx("loop_click", {"vol": 0.9})

func _say(k: int) -> void:
	say_k = k
	say_t0 = room.time
	if k != 4:
		Audio.sfx("loop_" + String(SAY.get(k, "intro")))

func music_now(want: String) -> String:
	if dying:
		return ""
	if room.fight.state == "intro":
		var el := room.time - intro_t0 if intro_t0 >= 0.0 else 0.0
		if intro_long() and el < intro_len() - 0.3:
			return ""
	if ph >= 2:
		return "boss_hi"
	return want

# ---------------------------------------------------------------- update (host)
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if not active:
		if room.fight.state == "intro":
			_step_intro()
		_sync_hall()
		_place()
		return
	if dying:
		_place()
		return
	if bp_off != last_bp_off:                                 # a freeze just ended (the room does not update a frozen creature): breakpoint rests
		last_bp_off = bp_off
		immune_until = room.time + BP_IMMUNE[ph - 1]
	bp = _bp_now()
	if mode == "broken" or mode == "recoil":
		if mode == "broken":
			_step_broken(dt)
		else:
			_step_recoil(dt)
		_sync_hall()
		_place()
		return
	_track_camp(dt)
	camp_cd = maxf(0.0, camp_cd - dt)
	match mode:
		"swim":
			plan_clock += dt
			_swim(dt, _speed())
			gap_t -= dt
			if gap_t <= 0.0:
				_choose()
		"plan":
			_plan_logic(dt)
		"stuck":
			plan_clock += dt
			stuck_t -= dt
			if stuck_t <= 0.0:
				mode = "swim"
				gap_t = room.rng.randf_range(0.35, 0.5)
				swim_key = kit_pick_target()
	_push_trail()
	_rebuild_links()
	_steer_rings(dt)
	bp = _bp_now()
	_sync_hall()
	_place()

func _speed() -> float:
	return SPEED[ph - 1] * minf(ITER_MAX, 1.0 + ITER_K * float(i_phase))

func _sync_hall() -> void:
	var hl := _hall()
	if hl == null or not active:
		return                                      # (the hall's phase is the fight's: before it, the room's own state stands)
	hl.ph = ph

# ---------------------------------------------------------------- swimming: round its target at ~110 px, turning at most TURN per second
func _swim(dt: float, v: float) -> void:
	var tp := kit_aim(swim_key)
	orbit_a += dt * 0.7
	var want := tp + Vector2(cos(orbit_a), sin(orbit_a) * 0.6 - 0.5) * 110.0
	want.x = clampf(want.x, ARENA.position.x, ARENA.end.x)
	want.y = clampf(want.y, ARENA.position.y, ARENA.end.y)
	_steer_to(want, dt, v)

func _steer_to(want: Vector2, dt: float, v: float) -> void:
	var d := want - Vector2(hx, hy)
	if d.length() > 2.0:
		var a := d.angle()
		var diff := wrapf(a - ang, -PI, PI)
		ang += clampf(diff, -TURN * dt, TURN * dt)
	var nv := Vector2(cos(ang), sin(ang)) * v * dt
	hx = clampf(hx + nv.x, MARGIN - 16.0, float(room.pw) - MARGIN + 16.0)
	hy = clampf(hy + nv.y, MARGIN - 16.0, LoopHall.FLOOR_Y - 20.0)

# ---------------------------------------------------------------- choosing (weighted, never the same twice in a row; the first cycle of a phase is fixed)
func _choose() -> void:
	var tgt := kit_pick_target()
	var id := ""
	var camper := _camper()
	if not queue.is_empty():
		id = String(queue.pop_front())
	elif camper != "" and camp_cd <= 0.0 and last_id != "coil":
		id = "coil"
		tgt = camper
		camp_cd = CAMP_CD
	else:
		var d := Vector2(hx, hy).distance_to(kit_aim(tgt))
		var wts := {"lunge": 1.0, "dive": 1.0, "coil": 1.0, "spit": 1.0}
		if d > FAR_PX:
			wts.lunge = 3.0
			wts.spit = 3.0
		elif d < NEAR_PX:
			wts.dive = 3.0
			wts.coil = 2.0
		wts.erase(last_id)
		var tot := 0.0
		for k in wts:
			tot += float(wts[k])
		var r := room.rng.randf() * tot
		for k in wts:
			r -= float(wts[k])
			if r <= 0.0:
				id = String(k)
				break
		if id == "":
			id = String(wts.keys()[0])
	_start(id, tgt)

# the plan begins (the harness calls this too)
func _start(id: String, tgt := "p1") -> void:
	last_id = id
	swim_key = tgt
	mode = "plan"
	spat = false
	var aim := kit_aim(tgt)
	var cue := 0.0
	var act := 0.3
	var rec := 0.4
	var fp: Array = [aim.x, aim.y, hx, hy]
	match id:
		"lunge":
			cue = CUE_HEAVY[ph - 1]
			lunge_o = Vector2(hx, hy)
			lunge_d = (aim - lunge_o).normalized() if aim.distance_to(lunge_o) > 4.0 else Vector2(cos(ang), sin(ang))
			lunge_len = _ray_len(lunge_o, lunge_d, LUNGE_LEN)
			act = lunge_len / LUNGE_V
			rec = 0.4
			fp = [lunge_o.x + lunge_d.x * 100.0, lunge_o.y + lunge_d.y * 100.0, lunge_o.x, lunge_o.y]
		"dive":
			cue = CUE_NORMAL[ph - 1]
			dive_x = clampf(aim.x, 32.0, float(room.pw) - 32.0)
			act = 0.6
			rec = 0.3
			fp = [dive_x, aim.y, hx, hy]
		"coil":
			cue = 1.0
			coil_c = aim
			coil_a = (Vector2(hx, hy) - aim).angle()
			act = 0.5
			rec = 0.4
			fp = [aim.x, aim.y, hx, hy]
		"spit":
			cue = CUE_NORMAL[ph - 1]
			act = 0.12
			rec = 0.5
		"calm":
			cue = 1.5
			act = 0.05
			rec = 0.2
			var side := -1.0 if aim.x > 192.0 else 1.0                   # near the low ledge away from the target (the safe place to learn breakpoint)
			coil_c = Vector2(192.0 + side * 112.0, 360.0)
			coil_a = (Vector2(hx, hy) - coil_c).angle()
			fp = [coil_c.x, coil_c.y, hx, hy]
	plan_start(id, String(FAM.get(id, "lunge")), tgt, fp, 0.0, cue, rec, act)
	if id == "dive":                                          # (the head goes up over the target's column during the cue)
		plan.fp[2] = dive_x
	Game.dlog("LOOP %s -> %s (cue %.2f)" % [id, tgt, float(plan.t)])

# how far a straight lunge goes before a wall, the floor or a one-way ledge stops it
func _ray_len(o: Vector2, d: Vector2, mx: float) -> float:
	var s := 0.0
	while s < mx:
		s += 4.0
		var p := o + d * s
		var tx := floori(p.x / 16.0)
		var ty := floori((p.y + 8.0) / 16.0)
		if p.x < 20.0 or p.x > float(room.pw) - 20.0 or p.y < 16.0 or p.y > LoopHall.FLOOR_Y - 12.0:
			return maxf(0.0, s - 4.0)
		if room.grid.solid(tx, ty) or (d.y > 0.3 and room.grid.tile(tx, ty) == TileGrid.ONEWAY):
			return maxf(0.0, s - 4.0)
	return mx

func _ground_below(px: float, py: float) -> float:
	var ty := maxi(0, floori(py / 16.0))
	while ty < room.h:
		var t := room.grid.tile(floori(px / 16.0), ty)
		if room.grid.solid(floori(px / 16.0), ty) or t == TileGrid.ONEWAY:
			return float(ty * 16)
		ty += 1
	return LoopHall.FLOOR_Y

func _plan_logic(dt: float) -> void:
	var nxt := plan_step(dt)
	var id := String(plan.id) if not plan.is_empty() else last_id
	if nxt == "active":
		_on_active(id)
	elif nxt == "recover":
		_on_recover(id)
	elif nxt == "done":
		_on_done(id)
		return
	if plan.is_empty():
		return
	match String(plan.ph):
		"cue":
			match id:
				"lunge", "escalate":
					var want := lunge_d.angle()
					ang += clampf(wrapf(want - ang, -PI, PI), -TURN * 3.0 * dt, TURN * 3.0 * dt)
					hx -= cos(want) * 14.0 * dt                    # it draws back a little (the S-coil)
					hy -= sin(want) * 14.0 * dt
				"dive":
					var top := Vector2(dive_x, clampf(float(plan.fp[1]) - 110.0, 40.0, 300.0))
					var tv := Vector2(hx, hy).move_toward(top, 420.0 * dt)
					hx = tv.x
					hy = tv.y
					ang += clampf(wrapf(PI / 2.0 - ang, -PI, PI), -TURN * 4.0 * dt, TURN * 4.0 * dt)
				"coil", "calm":
					var tot: float = 1.0 if id == "coil" else 1.5
					var u := 1.0 - clampf(float(plan.t) / maxf(0.01, tot * _tm()), 0.0, 1.0)
					var rr: float = lerpf(COIL_R[0], COIL_R[1], u) if id == "coil" else 44.0
					_circle(dt, rr, 4.0 if id == "coil" else 2.4)
				"spit":
					var want2 := (kit_aim(String(plan.tgt)) - Vector2(hx, hy)).angle()
					ang += clampf(wrapf(want2 - ang, -PI, PI), -TURN * 2.0 * dt, TURN * 2.0 * dt)
		"active":
			match id:
				"lunge", "escalate":
					var s := minf(lunge_len, (lunge_len / LUNGE_V - maxf(0.0, float(plan.t))) * LUNGE_V)
					hx = lunge_o.x + lunge_d.x * s
					hy = lunge_o.y + lunge_d.y * s
				"dive":
					var gy := _ground_below(hx, hy + 16.0) - 14.0
					hy = minf(hy + DIVE_V * dt, gy)
					ang = PI / 2.0
					if hy >= gy - 0.5:
						plan.t = 0.0
				"coil":
					var u2 := 1.0 - clampf(float(plan.t) / 0.5, 0.0, 1.0)
					_circle(dt, lerpf(COIL_R[1], COIL_R[2], u2), 4.0)
				"spit":
					if not spat:
						spat = true
						_spit()
		"recover":
			if id == "coil" or id == "calm":
				_swim(dt, _speed() * 0.6)

func _circle(dt: float, rr: float, w: float) -> void:
	coil_a += w * dt
	var want := coil_c + Vector2(cos(coil_a), sin(coil_a)) * rr
	var d := want - Vector2(hx, hy)
	var stepv := d.limit_length(maxf(240.0, d.length() * 6.0) * dt)
	hx += stepv.x
	hy += stepv.y
	if stepv.length() > 0.01:
		ang = stepv.angle()

func _on_active(id: String) -> void:
	match id:
		"lunge", "escalate":
			lunge_o = Vector2(hx, hy)
			lunge_len = _ray_len(lunge_o, lunge_d, LUNGE_LEN)
			plan.t = maxf(0.05, lunge_len / LUNGE_V)
			ang = lunge_d.angle()
			Audio.sfx("dash", {"vol": 0.8})
		"dive":
			ang = PI / 2.0
			Audio.sfx("loop_chain", {"vol": 0.5})

func _on_recover(id: String) -> void:
	match id:
		"lunge", "escalate":
			if lunge_len < LUNGE_LEN - 2.0:                   # it hit a wall, the floor or a ledge: the head is stuck
				_stuck(0.6)
		"dive":
			_stuck(0.8)

func _stuck(secs: float) -> void:
	stuck_t = _pm_rec(secs)
	plan = {}
	mode = "stuck"
	room.shake(0.3)
	Audio.sfx("thud", {"vol": 0.8})
	room.burst(hx, hy + 8.0, 6, [RIVET, "#ffffff"], 90.0, 300.0)

func _on_done(_id: String) -> void:
	mode = "swim"
	gap_t = room.rng.randf_range(0.35, 0.5)
	swim_key = kit_pick_target()

# three brass rings at the target, a little apart; the middle one is yellow (catch it)
func _spit() -> void:
	var tgt := String(plan.tgt)
	var aim := kit_aim(tgt)
	var mouth := Vector2(hx, hy) + Vector2(cos(ang), sin(ang)) * 16.0
	var a0 := (aim - mouth).angle()
	for i in range(3):
		var a := a0 + (float(i) - 1.0) * 0.28
		var yel := i == 1
		room.shoot(mouth.x, mouth.y, cos(a) * RING_V, sin(a) * RING_V, {"kind": "ring", "col": YELLOW if yel else RIVET, "r": 5.0, "catchable": yel, "cut": true, "life": 4.0, "dmg": 1, "by_boss": true, "loop_ring": a, "tile": true})
	Audio.sfx("shoot", {"vol": 0.8})

# the rings swing round small circles as they go (host: their velocity turns; the guest flies the snapshot's velocity)
func _steer_rings(_dt: float) -> void:
	for q in room.projs:
		if q.dead or not q.has("loop_ring") or q.get("friendly", false):
			continue
		var a: float = float(q.loop_ring)
		var w := 9.0
		var base := Vector2(cos(a), sin(a)) * RING_V
		var side := Vector2(-sin(a), cos(a)) * (12.0 * w) * cos(w * float(q.t))
		q.vx = base.x + side.x
		q.vy = base.y + side.y

# ---------------------------------------------------------------- camping: a player who stays in a 48 px box for 2.5 s gets the coil
func _track_camp(_dt: float) -> void:
	for k in kit_keys():
		var q = kit_body(k)
		var c := Vector2(q.x + q.w / 2.0, q.y + q.h / 2.0)
		var rec: Array = camp.get(k, [c.x, c.y, room.time])
		if absf(c.x - float(rec[0])) > CAMP_BOX / 2.0 or absf(c.y - float(rec[1])) > CAMP_BOX / 2.0:
			rec = [c.x, c.y, room.time]
		camp[k] = rec

func _camper() -> String:
	for k in camp:
		if kit_alive(String(k)) and room.time - float(camp[k][2]) >= CAMP_T:
			return String(k)
	return ""

# ---------------------------------------------------------------- the HUD: one bar (verdigris; violet edge in phase 2, orange in phase 3), the lines
func hud_bar() -> Array:
	var c := "#3fa58a" if ph == 1 else ("#9b6bff" if ph == 2 else "#ff7a59")
	return [maxf(0.0, hpf) / maxf(1.0, float(max_hp)), c, boss_name]

func say_text(k: int) -> String:
	var ln: Dictionary = lines.get(String(SAY.get(k, "intro")), {})
	if ln.has("text"):
		return String(ln.text)
	match k:
		1: return "Attempt four thousand and ninety-six. ... You are new. Every attempt is new."
		2: return "Retrying. Escalating. Retrying. Escalating."
		3: return "I was allowed three tries. Then someone said... retries are cheap."
		4: return "...again."
	return ""

func say_len(k: int) -> float:
	var ln: Dictionary = lines.get(String(SAY.get(k, "intro")), {})
	if ln.has("len"):
		return float(ln.len)
	return 1.4 if k == 4 else 5.0

func draw_hud(ci: CanvasItem) -> void:
	if say_k > 0 and not dying:
		var el := room.time - say_t0
		var ln := say_len(say_k)
		if el >= 0.0 and el < ln + 1.0:
			var txt := say_text(say_k)
			var n := clampi(ceili(float(txt.length()) * el / maxf(0.5, ln - 0.4)), 0, txt.length())
			_subtitle(ci, txt.substr(0, n), 1.0 if el < ln else clampf(ln + 1.0 - el, 0.0, 1.0))
	if loss_on:
		draw_loss(ci)

func _subtitle(ci: CanvasItem, txt: String, a: float) -> void:
	var rows := PixelText.wrap(txt, 330)
	var hh := 6.0 + rows.size() * 11.0
	var y0 := 168.0 - hh
	ci.draw_rect(Rect2(20, y0, 344, hh), Color(0.03, 0.03, 0.05, 0.7 * a))
	for i in range(rows.size()):
		var c := Color(VD[4])
		c.a = a
		PixelText.draw_text(ci, rows[i], 192.0, y0 + 4.0 + i * 11.0, c, {"align": "c", "outline": Color(0.05, 0.05, 0.08, a)})

# ---------------------------------------------------------------- drawing (the body is the sketch's pixel art: tools/godot/loop_sprites.py)
func _head_row() -> int:
	var heads: Array = lspr.get("heads", [])
	var open := false
	var tell := false
	if not plan.is_empty():
		var pid := String(plan.id)
		if plan.ph == "cue" and pid in ["lunge", "escalate", "spit", "dive", "wrap_dive"]:
			tell = true
		if plan.ph == "active" and pid in ["lunge", "escalate", "dive", "wrap_dive"]:
			open = true
	var k := "idle"
	if mode == "broken" or mode == "dead":
		k = "down"
	elif ph == 1:
		k = "tell" if tell else ("open" if open else "idle")
	elif ph == 2:
		k = "p2open" if (tell or open) else "p2"
	else:
		k = "p3open" if (tell or open) else "p3"
	return maxi(0, heads.find(k))

func _plate_i() -> int:
	if mode == "broken" or mode == "dead":
		return 3
	if room.time - half_t0 <= HALF_WINDOW and int(room.time * 8.0) % 2 == 0:
		return 2
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) in ["lunge", "escalate"]:
		return 1
	if ph == 3:
		return 4
	return 0

func _link_i() -> int:
	if mode == "broken" or mode == "dead":
		return 3
	return ph - 1

func draw_boss_body(ci: CanvasItem) -> void:
	if mode == "hidden" or tex_head == null:
		return
	var ink := Color(INK)
	var li := _link_i()
	var flick := room.time - flick_t < 0.25
	var tint := Color.WHITE
	var jit := Vector2.ZERO
	if bp_t > 0.0:
		tint = Color(0.72, 0.88, 1.0)                         # frozen: the game's blue for a stopped thing
	if room.time - shiver_t0 < 0.35:                          # breakpoint on it while it rests: a blue shiver, nothing else
		tint = Color(0.6, 0.8, 1.0)
		jit = Vector2(1.0 if int(room.time * 40.0) % 2 == 0 else -1.0, 0.0)
	# the pins between the links, then the links from the tail up (the neck on top), then the head
	var prev := Vector2(hx, hy)
	for k in range(links.size()):
		var c: Vector2 = links[k]
		ci.draw_line(prev, c, ink, 4.0)
		ci.draw_line(prev, c, Color(RIVET), 1.0)
		prev = c
	for k in range(links.size() - 1, -1, -1):
		var c2: Vector2 = links[k]
		var src := Rect2(float(li) * 16.0, 0.0, 16.0, 16.0)
		var at := Vector2(floorf(c2.x - 8.0 + 0.5), floorf(c2.y - 8.0 + 0.5)) + jit
		if k == links.size() - 1 and flick:
			at += Vector2(0.0, -2.0)
		ci.draw_texture_rect_region(tex_links, Rect2(at, Vector2(16.0, 16.0)), src, tint)
	var fs := float(lspr.get("frame", 56))
	var row := _head_row()
	var d := dir8()
	var hsrc := Rect2(float(d) * fs, float(row) * fs, fs, fs)
	var hat := Vector2(floorf(hx - fs / 2.0 + 0.5), floorf(hy - fs / 2.0 + 0.5)) + jit
	ci.draw_texture_rect_region(tex_head, Rect2(hat, Vector2(fs, fs)), hsrc, tint)
	# the plate, upright on the brow (readable whichever way the head points)
	var pr := plate_rect()
	var pi_ := _plate_i()
	var psz: Array = lspr.get("plate", [20, 10])
	ci.draw_texture_rect_region(tex_plate, Rect2(Vector2(floorf(pr.position.x - 1.0), floorf(pr.position.y - 1.0)), Vector2(float(psz[0]), float(psz[1]))), Rect2(float(pi_) * float(psz[0]), 0.0, float(psz[0]), float(psz[1])))
	# a spit's cue: brass rings in its mouth
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) == "spit":
		var m := Vector2(hx, hy) + Vector2(cos(ang), sin(ang)) * 14.0
		for i in range(3):
			var rc := m + Vector2(float(i - 1) * 4.0, 2.0)
			ci.draw_arc(rc, 3.0, 0.0, TAU, 8, ink, 2.0)
			ci.draw_arc(rc, 3.0, 0.0, TAU, 8, Color(YELLOW if i == 1 else RIVET), 1.0)

# ---------------------------------------------------------------- net
func _links_pack() -> Array:
	var a: Array = []
	for c in links:
		a.append(roundi(c.x * 2.0))
		a.append(roundi(c.y * 2.0))
	return a

func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, ph, MODES.find(mode), roundi(hx * 4.0), roundi(hy * 4.0), roundi(ang * 1000.0),
		_links_pack(), plan_fields(), [roundi(lunge_d.x * 1000.0), roundi(lunge_d.y * 1000.0), roundi(lunge_len * 10.0), roundi(dive_x * 4.0), roundi(coil_c.x), roundi(coil_c.y)],
		iter, i_phase, roundi(stuck_t * 100.0), roundi(intro_t0 * 100.0), say_k, roundi(say_t0 * 100.0), roundi(flick_t * 100.0),
		hl.net_pack() if hl != null else [], [1 if loss_on else 0, loss_sel],
		[roundi(half_t0 * 100.0), roundi(immune_until * 100.0), roundi(shiver_t0 * 100.0), roundi(brk_t0 * 100.0), roundi(recoil_t0 * 100.0), breaks_total]]
	f.append(hz_pack())
	return f

const NF := 22

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	dying = int(f[3]) == 1
	ph = int(f[4])
	phase = ph
	mode = MODES[clampi(int(f[5]), 0, MODES.size() - 1)]
	var nhx: float = f[6] / 4.0
	var nhy: float = f[7] / 4.0
	ang = f[8] / 1000.0
	var la: Array = f[9]
	var nl: Array = []
	for k in range(la.size() / 2):
		nl.append(Vector2(la[k * 2] / 2.0, la[k * 2 + 1] / 2.0))
	n_links = nl.size()
	if hsamp.is_empty():
		hx = nhx
		hy = nhy
		links = nl
	set_meta("net_head", Vector2(nhx, nhy))
	set_meta("net_links", nl)
	plan_apply(f[10])
	var pa: Array = f[11]
	lunge_d = Vector2(pa[0] / 1000.0, pa[1] / 1000.0)
	lunge_len = pa[2] / 10.0
	dive_x = pa[3] / 4.0
	coil_c = Vector2(float(pa[4]), float(pa[5]))
	iter = int(f[12])
	i_phase = int(f[13])
	stuck_t = f[14] / 100.0
	intro_t0 = f[15] / 100.0
	say_k = int(f[16])
	say_t0 = f[17] / 100.0
	flick_t = f[18] / 100.0
	var hl := _hall()
	if hl != null and not (f[19] as Array).is_empty():
		hl.net_unpack(f[19])
	var lf: Array = f[20]
	loss_on = int(lf[0]) == 1
	loss_sel = int(lf[1])
	var cf: Array = f[21]
	half_t0 = cf[0] / 100.0
	immune_until = cf[1] / 100.0
	shiver_t0 = cf[2] / 100.0
	brk_t0 = cf[3] / 100.0
	recoil_t0 = cf[4] / 100.0
	breaks_total = int(cf[5])
	hz_unpack(f[NF] if f.size() > NF else [])

# guest: the snapshot just applied, at host time tm
func net_sample(tm: float) -> void:
	hsamp.append([tm, get_meta("net_head", Vector2(hx, hy)), get_meta("net_links", links), ang])
	while hsamp.size() > 8:
		hsamp.pop_front()

# guest: the head and every link where they were at render time rt
func puppet_follow_parts(rt: float) -> void:
	if hsamp.is_empty():
		return
	var a: Array = hsamp[0]
	var b: Array = hsamp[0]
	var u := 0.0
	var last: Array = hsamp[hsamp.size() - 1]
	if rt >= float(last[0]):
		a = last
		b = last
	elif rt <= float(hsamp[0][0]):
		pass
	else:
		for k in range(hsamp.size() - 1):
			if float(hsamp[k][0]) <= rt and rt <= float(hsamp[k + 1][0]):
				a = hsamp[k]
				b = hsamp[k + 1]
				u = (rt - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
				break
	var ha: Vector2 = a[1]
	var hb: Vector2 = b[1]
	var hp_ := ha.lerp(hb, u)
	hx = hp_.x
	hy = hp_.y
	var la: Array = a[2]
	var lb: Array = b[2]
	var nl: Array = []
	for k in range(lb.size()):
		var pa_: Vector2 = la[k] if k < la.size() else lb[k]
		nl.append(pa_.lerp(lb[k], u))
	links = nl
	_place()

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	bp = _bp_now()
