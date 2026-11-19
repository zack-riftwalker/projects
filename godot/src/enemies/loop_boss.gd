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

const IDS := ["lunge", "dive", "coil", "spit", "calm", "recursion", "escalate", "wrap_dive", "esc2"]
const FAM := {"lunge": "lunge", "dive": "slam", "coil": "sweep", "spit": "proj", "calm": "guard", "recursion": "proj", "escalate": "lunge", "wrap_dive": "slam", "esc2": "lunge"}
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
const TRANS_T := [0.0, 2.0, 2.5]           # the phase changes (invulnerable, no touch)
const NEST_N := 6                          # phase 2: the nested ring of 6 small links round a gear
const NEST_R := 54.0                       # its orbit (3.4 tiles)
const NEST_RR := 14.0                      # the ring itself
const NEST_ORBIT := 5.4                    # s round one gear,
const NEST_SPIN := 0.6                     # a spin-up and a jingle (its cue),
const NEST_CROSS := 1.2                    # then over M to the other gear
const NEST_PER := 7.2
const NEST_DROP := 4.0                     # a break drops it this long
const COPY_DUR := 2.0                      # recursion: a 4-link copy replays the head's last 2.0 s
const COPY_N := 4
const COPY_DT := 0.1
const SHED_MIN := 6                        # phase 3: a link falls off at every 1/8 of the phase's hp (14 -> 6)
const FEINT_T := 0.25
const WRAP_TOP := -18.0
const NO_GROUND := 10000.0
const FALL_T := 3.0                        # the death (~20 s, CRAWLER's compact scene with LOOP's own turns): it lets go of its tail and lies open,
const WAIT_MAX := 11.0                     # waits for someone to come near its head (at most 8 s more), says `die`, then the memorable line
const DIE_GAP := 0.8                       # in the terminal box (Clawd's context meter fills), the eye goes out, the compaction (its bar loops
const EYE_OFF := 0.8                       # once), the summary, the word `stop` lingers; then opus
const COMPACT_LEN := 6.0
const SUMMARY_LEN := 2.6

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
var trans_t0 := -10.0                      # a phase change began (ph is already the new phase)
var nest_on := false
var nest_base := 0.0                       # the nested ring's clock starts here, on gear nest_g0
var nest_g0 := 0
var nest_drop_t0 := -10.0
var copy_t0 := -10.0                       # recursion: the copy's start, and the path it replays (a point every COPY_DT)
var copy_pts: Array = []
var head_hist: Array = []                  # host: [time, head] of the last 2.5 s
var shed: Array = []                       # phase 3: the links that fell off (they lie on the floor)
var p3_hp0 := 0.0
var feint := false                         # the plan in progress holds 0.25 s more after its full cue
var combo_next := ""                       # host: phase 3's combo: this plan follows at once
var jingle_k := -1
var speak_t := -1.0                        # the death: die_t when its line began (-1: not yet)
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
	if d > 120.0:                                    # it came in at the other seam (phase 3's wrap): a jump in the path, not a line across the room
		trail.insert(0, hp_)
		while trail.size() > TRAIL_MAX:
			trail.remove_at(trail.size() - 1)
		return
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
		if seg > 120.0:                              # the wrap's jump: the path goes on at the other seam
			prev = p
			i += 1
			continue
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
		"esc2":
			var hr3 := head_rect().grow(2.0)
			out.append({"x": hr3.position.x, "y": hr3.position.y, "w": hr3.size.x, "h": hr3.size.y, "dmg": 1, "sx": hx, "sid": int(plan.seq)})
		"dive", "wrap_dive":
			var hr2 := head_rect()
			out.append({"x": hr2.position.x, "y": hr2.position.y, "w": hr2.size.x, "h": hr2.size.y + 6.0, "dmg": _big() if String(plan.id) == "wrap_dive" else 1, "sx": hx, "sid": int(plan.seq)})
	return out

func harmboxes() -> Array:
	var out: Array = attack_boxes()
	out.append_array(touch_boxes())
	out.append_array(pressure_boxes(room.time))
	return out

# the phase pressure (pure functions of the fields and the room's clock, so the guest builds the same): the nested ring, the recursion copy
func pressure_boxes(tm: float) -> Array:
	var out: Array = []
	if not active or dying or loss_on:
		return out
	if nest_live(tm):
		for c in nest_members(tm):
			out.append({"x": c.x - 5.0, "y": c.y - 5.0, "w": 10.0, "h": 10.0, "dmg": 1, "sx": c.x, "nest": 1})
	var cp := copy_parts(tm)
	if not cp.is_empty() and tm - copy_t0 < COPY_DUR - 0.3:
		for c in cp:
			out.append({"x": c.x - 6.0, "y": c.y - 6.0, "w": 12.0, "h": 12.0, "dmg": 1, "sx": c.x, "copy": 1})
	return out

# ---- the nested ring (phase 2)
func nest_live(tm: float) -> bool:
	return nest_on and not (nest_drop_t0 >= 0.0 and tm - nest_drop_t0 < NEST_DROP) and tm >= nest_base and mode != "trans"

func nest_gear(tm: float) -> int:
	return posmod(nest_g0 + floori((tm - nest_base) / NEST_PER), 2)

func _nest_a(u: float) -> float:
	return -PI / 2.0 + 1.1 * u

# the ring's centre: round its gear, a 0.6 s spin-up, then an arc over M to the other gear
func nest_center(tm: float) -> Vector2:
	var u := fposmod(tm - nest_base, NEST_PER)
	var g := nest_gear(tm)
	var c0: Vector2 = LoopHall.GEAR_C[g]
	if u < NEST_ORBIT + NEST_SPIN:
		var a := _nest_a(u)
		return c0 + Vector2(cos(a), sin(a)) * NEST_R
	var c1: Vector2 = LoopHall.GEAR_C[1 - g]
	var from := c0 + Vector2(cos(_nest_a(NEST_ORBIT + NEST_SPIN)), sin(_nest_a(NEST_ORBIT + NEST_SPIN))) * NEST_R
	var to := c1 + Vector2(cos(_nest_a(0.0)), sin(_nest_a(0.0))) * NEST_R
	var w := clampf((u - NEST_ORBIT - NEST_SPIN) / NEST_CROSS, 0.0, 1.0)
	var e := w * w * (3.0 - 2.0 * w)
	return from.lerp(to, e) + Vector2(0.0, -70.0 * sin(PI * w))

# the spin-up (the ring's own cue before it crosses): 0..1, -1 outside
func nest_spinup(tm: float) -> float:
	var u := fposmod(tm - nest_base, NEST_PER)
	if u < NEST_ORBIT or u >= NEST_ORBIT + NEST_SPIN:
		return -1.0
	return (u - NEST_ORBIT) / NEST_SPIN

func nest_members(tm: float) -> Array:
	var out: Array = []
	if nest_drop_t0 >= 0.0 and tm - nest_drop_t0 < NEST_DROP:          # dropped by a break: on the floor under where it was
		var dc: Vector2 = get_meta("nest_drop_at", Vector2(192.0, 456.0))
		for i in range(NEST_N):
			out.append(Vector2(clampf(dc.x + (float(i) - 2.5) * 10.0, 24.0, 360.0), _rest_y(dc.x, dc.y) - 6.0))
		return out
	var c := nest_center(tm)
	var u := tm - nest_base
	var sp := nest_spinup(tm)
	var rot := 3.0 * u + (0.0 if sp < 0.0 else 9.0 * sp * sp)
	for i in range(NEST_N):
		var a := rot + TAU * float(i) / float(NEST_N)
		out.append(c + Vector2(cos(a), sin(a)) * NEST_RR)
	return out

# ---- recursion: the copy's head and its 4 links along the replayed path
func copy_parts(tm: float) -> Array:
	var el := tm - copy_t0
	if copy_pts.size() < 2 or el < 0.0 or el > COPY_DUR:
		return []
	var out: Array = []
	for k in range(COPY_N + 1):
		var f := el / COPY_DT - float(k) * 1.4
		if f < 0.0:
			break
		var i := mini(floori(f), copy_pts.size() - 2)
		var u := clampf(f - float(i), 0.0, 1.0)
		out.append((copy_pts[i] as Vector2).lerp(copy_pts[i + 1], u))
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
	var gy := _rest_y(hx, hy - 4.0)
	var side := -1.0 if hx > 192.0 else 1.0
	var hx2 := clampf(hx, 36.0, float(room.pw) - 36.0)
	for kk in range(links.size()):
		var lx := hx2 + side * (NECK + GAP * float(kk))
		if lx < 24.0 or lx > float(room.pw) - 24.0:            # (no room that way: it folds back along the floor)
			lx = clampf(lx, 24.0, float(room.pw) - 24.0)
		lie.append(Vector2(lx, _rest_y(lx, gy - 4.0) - 8.0))
	lie.append(Vector2(hx2, gy - 12.0))
	room.shake(0.6)
	Audio.sfx("loop_clack", {"vol": 1.0})
	Audio.sfx("loop_collapse", {"vol": 0.8})
	room.burst(hx, hy - 14.0, 10, ["#ff4d5a", "#ffffff"], 110.0, 300.0)
	if nest_on and nest_live(room.time):
		set_meta("nest_drop_at", nest_center(room.time))
		set_meta("nest_drop_g", nest_gear(room.time))
		nest_drop_t0 = room.time
	feint = false
	combo_next = ""
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

# ---------------------------------------------------------------- the death (host runs it; die_t and speak_t travel to the guest)
func begin_death() -> void:
	dying = true
	die_t = 0.0
	speak_t = -1.0
	passive = true
	plan = {}
	mode = "dead"
	say_k = 0
	nest_on = false
	copy_t0 = -10.0
	bp_t = 0.0
	for q in room.projs:
		q.dead = true
	for e in room.ents:
		if e != self and not e.get("is_boss"):
			e.loot = 0
			e.die("")
	var hl := _hall()
	if hl != null:
		hl.violet = 0.0
		hl.heat = 0.0
		if hl.pit_open(room.time):
			hl.close_t0 = room.time                       # the floor slides back first (a click), so nobody is left in the loop
		Game.flags["loop:final:%d" % hl.counter] = true      # (the counter stays at this number in the after-state)
	_lay_down()
	room.shake(0.7)
	Audio.sfx("loop_click", {"vol": 1.0})
	Audio.sfx("loop_collapse", {"vol": 1.0})
	room.events.append("bossDying")

# it lets go of its tail and lies straight along the floor (the same as a break, but for good)
func _lay_down() -> void:
	lie.clear()
	var side := -1.0 if hx > 192.0 else 1.0
	var hx2 := clampf(hx, 60.0, float(room.pw) - 60.0)
	var gy := LoopHall.FLOOR_Y
	for kk in range(links.size()):
		var lx := clampf(hx2 + side * (NECK + GAP * float(kk)), 24.0, float(room.pw) - 24.0)
		lie.append(Vector2(lx, gy - 8.0))
	lie.append(Vector2(hx2, gy - 12.0))

func _die_len() -> float:
	return float(lines.get("die", {}).get("len", 2.8))

func _compact_words() -> Array:
	return lines.get("compact", {}).get("words", [])

func _c0() -> float:
	return _die_len() + DIE_GAP

func _c_end() -> float:
	return _c0() + float(lines.get("compact", {}).get("len", 7.4))

func compact_at() -> float:
	return _c_end() + EYE_OFF

func _step_death(dt: float) -> void:
	die_t += dt
	_step_broken_lie(dt)
	if speak_t < 0.0 and die_t >= FALL_T:
		var near := die_t >= WAIT_MAX
		for q in room.players():
			if absf(q.x + q.w / 2.0 - hx) < 90.0 and absf(q.y - hy) < 90.0:
				near = true
		if near:
			speak_t = die_t
			Audio.sfx("loop_die")
	if speak_t >= 0.0:
		var sc := die_t - speak_t
		if sc >= _c0() and not bool(get_meta("said_compact", false)):
			set_meta("said_compact", true)
			Audio.sfx("loop_compact")
		if sc >= compact_at() + COMPACT_LEN and not Game.flag("compacted:LOOP"):
			Game.flags["compacted:LOOP"] = true               # the trace in the Logs page (the DLC opens it)
		if sc >= compact_at() + COMPACT_LEN + SUMMARY_LEN and not gone:
			gone = true
			dead = true
			room.drop(hx, hy, drop_n)
			room.events.append("bossDead")

func _step_broken_lie(dt: float) -> void:
	for kk in range(links.size()):
		if kk < lie.size():
			links[kk] = (links[kk] as Vector2).move_toward(lie[kk], LIE_V * dt)
	if lie.size() > links.size():
		var hv := Vector2(hx, hy).move_toward(lie[lie.size() - 1], LIE_V * dt)
		hx = hv.x
		hy = hv.y
		ang = 0.0 if lie.size() > 1 and float(lie[0].x) < hx else PI

# the scene's clock on this page: where it is in its lines, -1 before
func speak_clock() -> float:
	return die_t - speak_t if speak_t >= 0.0 else -1.0

# Clawd's context meter while the memorable line is said: 60 % after the first sentence, 85 % after the second, full and red on the third
func context_fill() -> float:
	var sc := speak_clock()
	if sc < _c0():
		return -1.0
	var ws := _compact_words()
	var marks := [[7, 0.6], [10, 0.85], [11, 0.95], [15, 1.0]]
	var f := 0.35
	for m in marks:
		if int(m[0]) < ws.size() and sc - _c0() >= float(ws[int(m[0])][1]):
			f = float(m[1])
	return f

func blocks(_dx: float, _dy: float, _how: String) -> bool:
	return false

func on_damage() -> void:
	if dying or hpf <= 0.0:
		return
	var p := _phase_hp()
	if p > ph and mode != "trans":
		_begin_phase(p)
	if ph == 3 and mode != "trans":
		_shed_to(clampi(LINKS - floori((1.0 - hpf / maxf(1.0, p3_hp0)) * 8.0 + 0.0001), SHED_MIN, LINKS))

# a phase change: it bites its tail and spins (phase 2: violet, the low ledges go, the gantry swings, the nested ring splits off; phase 3: the plate
# cracks, the floor cracks and falls away, the ceiling opens, the low ledges come back)
func _begin_phase(p: int) -> void:
	ph = p
	phase = p
	mode = "trans"
	trans_t0 = room.time
	plan = {}
	combo_next = ""
	feint = false
	i_phase = 0
	half_t0 = -10.0
	var hl := _hall()
	if p == 2:
		if hl != null:
			hl.p2_t0 = room.time
			hl.violet = 1.0
		coil_c = Vector2(clampf(hx, 80.0, 304.0), clampf(hy, 120.0, 360.0))
		queue = ["recursion", "escalate"]
	else:
		if hl != null:
			hl.p3_t0 = room.time
			hl.violet = 0.0
			hl.heat = 1.0
		nest_on = false
		p3_hp0 = hpf
		Audio.sfx("loop_crack", {"vol": 1.0})
		coil_c = Vector2(192.0, 200.0)
		queue = ["wrap_dive", "lunge"]
	coil_a = (Vector2(hx, hy) - coil_c).angle()
	_sync_hall()
	room.shake(0.8)
	Audio.sfx("loop_click", {"vol": 1.0})
	_say(p)
	room.events.append("bossPhase")
	Game.dlog("LOOP phase %d" % p)

# (tests and screenshots) straight into a phase, its change already over
func force_phase(p: int) -> void:
	if p <= 1:
		return
	if p >= 2 and ph < 2:
		hpf = float(max_hp) * 0.6
		hp = ceili(hpf)
		_begin_phase(2)
		trans_t0 = room.time - 10.0
		var hl := _hall()
		if hl != null:
			hl.p2_t0 = room.time - 3.0
		_step_trans(0.0)
	if p >= 3:
		hpf = float(max_hp) * 0.3
		hp = ceili(hpf)
		_begin_phase(3)
		trans_t0 = room.time - 10.0
		var hl2 := _hall()
		if hl2 != null:
			hl2.p3_t0 = room.time - 3.0
		_step_trans(0.0)
	queue = []

func _step_trans(dt: float) -> void:
	_circle(dt, 30.0 if ph == 2 else 40.0, 7.0)
	if room.time - trans_t0 >= TRANS_T[ph - 1]:
		mode = "swim"
		gap_t = 0.3
		swim_key = kit_pick_target()
		if ph == 2:
			nest_on = true
			nest_base = room.time
			nest_g0 = 0 if hx < 192.0 else 1
			nest_drop_t0 = -10.0

# phase 3: hp = length. The tail link falls off and lies on the floor (no collision)
func _shed_to(n: int) -> void:
	while n_links > n and links.size() > 1:
		var tp: Vector2 = links[links.size() - 1]
		shed.append(Vector2(tp.x, _rest_y(tp.x, tp.y) - 8.0))
		room.burst(tp.x, tp.y, 6, [HEAT, RIVET], 90.0, 300.0)
		Audio.sfx("clang", {"vol": 0.7})
		n_links -= 1
		links.resize(n_links)

# ---------------------------------------------------------------- the fight flow
# ---------------------------------------------------------------- the loss menu: `retry` puts both just inside the west door, a fresh phase 1, the short intro, and the counter one higher
func has_retry() -> bool:
	return true

func retry_spot() -> Vector2:
	return Vector2(24.0, 448.0)

func loss_colors() -> Array:
	return [VD[3], VD[2], "#3a6a5a"]

func loss_sound() -> String:
	return "loop_click"

func on_retry() -> void:
	Game.loop_tries += 1

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
	if ph >= 3:
		return "loop_stutter"
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
		_step_death(dt)
		_sync_hall()
		_place()
		return
	if bp_off != last_bp_off:                                 # a freeze just ended (the room does not update a frozen creature): breakpoint rests
		last_bp_off = bp_off
		immune_until = room.time + BP_IMMUNE[ph - 1]
	bp = _bp_now()
	_record_head()
	if nest_drop_t0 >= 0.0 and room.time - nest_drop_t0 >= NEST_DROP:          # the ring is back on its feet: round the gear it fell from
		nest_g0 = get_meta("nest_drop_g", 0)
		nest_base = room.time
		nest_drop_t0 = -10.0
	_nest_jingle()
	if mode == "trans":
		_step_trans(dt)
		_push_trail()
		_rebuild_links()
		_sync_hall()
		_place()
		return
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

func _record_head() -> void:
	head_hist.append([room.time, Vector2(hx, hy)])
	while head_hist.size() > 2 and room.time - float(head_hist[0][0]) > 2.6:
		head_hist.pop_front()

# the ring's jingle as its spin-up starts (each crossing once)
func _nest_jingle() -> void:
	if not nest_live(room.time):
		return
	var k := floori((room.time - nest_base) / NEST_PER)
	if nest_spinup(room.time) >= 0.0 and k != jingle_k:
		jingle_k = k
		Audio.sfx("loop_jingle", {"vol": 0.8})

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
		if ph >= 3 and _faller() != "":
			tgt = _faller()
		if d > FAR_PX:
			wts.lunge = 3.0
			wts.spit = 3.0
		elif d < NEAR_PX:
			wts.dive = 3.0
			wts.coil = 2.0
		wts.erase(last_id)
		if ph >= 2:
			wts["recursion"] = 1.5
			wts["escalate"] = 1.5 if d > 120.0 else 0.7
		if ph >= 3:
			wts["wrap_dive"] = 4.0 if _faller() != "" else 2.0
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
	if ph >= 3 and plan.size() > 0:                            # phase 3: combos and feints
		if id == "lunge" and room.rng.randf() < 0.35:
			combo_next = "dive"
		if (id == "lunge" or id == "wrap_dive") and room.rng.randf() < 0.35 and combo_next == "":
			_feint()

func _feint() -> void:
	feint = true
	plan.t = float(plan.t) + FEINT_T * _tm()                  # (only more waiting after the full cue: the cue never gets shorter)

# phase 3: a player falling through the pit (the wrap dive likes them)
func _faller() -> String:
	for k in kit_keys():
		var q = kit_body(k)
		if not q.on_ground and q.vy > 60.0 and _hall() != null and _hall().in_pit_cols(q.x + q.w / 2.0) and q.y > 300.0:
			return k
	return ""

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
	feint = false
	match id:
		"lunge", "escalate", "esc2":
			cue = CUE_HEAVY[ph - 1] if id != "esc2" else 0.45
			lunge_o = Vector2(hx, hy)
			lunge_d = (aim - lunge_o).normalized() if aim.distance_to(lunge_o) > 4.0 else Vector2(cos(ang), sin(ang))
			lunge_len = _ray_len(lunge_o, lunge_d, LUNGE_LEN)
			act = lunge_len / LUNGE_V
			rec = 0.4 if id != "escalate" else 0.05
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
		"recursion":
			cue = CUE_NORMAL[ph - 1]
			act = 0.1
			rec = 0.4
		"wrap_dive":
			cue = 0.75
			var fq = kit_body(tgt)
			dive_x = clampf(aim.x + (fq.vx * 0.3 if fq != null else 0.0), float(LoopHall.PIT_A * 16) + 8.0, float((LoopHall.PIT_B + 1) * 16) - 8.0)
			act = 1.4
			rec = 0.4
			fp = [dive_x, aim.y, hx, hy]
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
	return NO_GROUND                                          # (phase 3: over the open pit there is nothing)

# where a thing lying on the floor rests (over the open pit: at the floor's height, on the seam's light)
func _rest_y(px: float, py: float) -> float:
	return minf(_ground_below(px, py), LoopHall.FLOOR_Y)

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
				"lunge", "escalate", "esc2":
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
				"spit", "recursion":
					var want2 := (kit_aim(String(plan.tgt)) - Vector2(hx, hy)).angle()
					ang += clampf(wrapf(want2 - ang, -PI, PI), -TURN * 2.0 * dt, TURN * 2.0 * dt)
				"wrap_dive":
					_wrap_cue(dt)
		"active":
			match id:
				"lunge", "escalate", "esc2":
					var s := minf(lunge_len, (lunge_len / LUNGE_V - maxf(0.0, float(plan.t))) * LUNGE_V)
					hx = lunge_o.x + lunge_d.x * s
					hy = lunge_o.y + lunge_d.y * s
				"dive":
					var gy := _ground_below(hx, maxf(0.0, hy + 16.0)) - 14.0
					hy = minf(hy + DIVE_V * dt, gy)
					ang = PI / 2.0
					if hy >= gy - 0.5:
						plan.t = 0.0
					elif hy > LoopHall.PH + 16.0:                  # (phase 3, over the pit: it comes back in at the top and goes on)
						hy = WRAP_TOP
				"coil":
					var u2 := 1.0 - clampf(float(plan.t) / 0.5, 0.0, 1.0)
					var rc := 32.0 if ph == 3 else COIL_R[1]
					_circle(dt, lerpf(rc, COIL_R[2], u2), 4.0)
				"wrap_dive":
					_wrap_fall(dt)
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

# the wrap dive's cue: the head sinks into the pit (the chain rattles above), comes in at the top seam over the target's column and waits there
func _wrap_cue(dt: float) -> void:
	if hy > -1.0 and hy < 520.0 and not bool(get_meta("wrapped", false)):
		var pit := Vector2(clampf(hx, 110.0, 274.0), 540.0)
		var need := maxf(260.0, Vector2(hx, hy).distance_to(pit) / maxf(0.1, float(plan.t) - 0.25))
		var v := Vector2(hx, hy).move_toward(pit, need * dt)
		ang = (pit - Vector2(hx, hy)).angle() if v.distance_to(Vector2(hx, hy)) > 0.1 else ang
		hx = v.x
		hy = v.y
		if hy > LoopHall.PH + 16.0:
			hx = dive_x
			hy = WRAP_TOP
			set_meta("wrapped", true)
			Audio.sfx("loop_seam", {"vol": 0.9})
	else:
		hx = move_toward(hx, dive_x, 200.0 * dt)
		hy = WRAP_TOP
		ang = PI / 2.0

# ... then straight down its column; the gantry, a ledge or the floor beside the pit stops it (stuck 0.6 s); through the pit it wraps on
func _wrap_fall(dt: float) -> void:
	ang = PI / 2.0
	var ny := hy + DIVE_V * dt
	var stop := _ground_below(hx, maxf(0.0, hy + 14.0)) - 14.0
	var hl := _hall()
	if hl != null and hx > float(hl.gantry_p.x) and hx < float(hl.gantry_p.x) + float(hl.gantry_p.w) and hy + 14.0 <= float(hl.gantry_p.y) + 1.0 and ny + 14.0 >= float(hl.gantry_p.y):
		stop = minf(stop, float(hl.gantry_p.y) - 14.0)
	if ny >= stop:
		hy = stop
		set_meta("wrap_hit", true)
		plan.t = 0.0
		return
	hy = ny
	if hy > LoopHall.PH + 16.0:
		hy = WRAP_TOP

func _on_active(id: String) -> void:
	match id:
		"recursion":
			_make_copy()
		"wrap_dive":
			set_meta("wrap_hit", false)
			hx = dive_x
			hy = WRAP_TOP
		"lunge", "escalate", "esc2":
			lunge_o = Vector2(hx, hy)
			lunge_len = _ray_len(lunge_o, lunge_d, LUNGE_LEN)
			plan.t = maxf(0.05, lunge_len / LUNGE_V)
			ang = lunge_d.angle()
			Audio.sfx("dash", {"vol": 0.8})
		"dive":
			ang = PI / 2.0
			Audio.sfx("loop_chain", {"vol": 0.5})
		"coil":
			if ph >= 3:
				_make_copy()

func _on_recover(id: String) -> void:
	set_meta("wrapped", false)
	match id:
		"escalate":                                           # the second lunge at once: aimed again, a 0.45 s cue, 1 damage
			_start("esc2", kit_pick_target())
			return
		"esc2":
			_stuck(0.8)
		"lunge":
			if combo_next == "dive":
				combo_next = ""
				_start("dive", String(plan.tgt) if not plan.is_empty() else swim_key)
				return
			if lunge_len < LUNGE_LEN - 2.0:                   # it hit a wall, the floor or a ledge: the head is stuck
				_stuck(0.6)
		"dive":
			_stuck(0.8)
		"wrap_dive":
			if bool(get_meta("wrap_hit", false)):
				_stuck(0.6)
			elif hy < 40.0:
				hy = 60.0
		"coil":
			pass

# recursion: a 4-link copy replays where the head was over the last 2.0 s (coil + recursion in phase 3: at the coil's squeeze)
func _make_copy() -> void:
	copy_pts.clear()
	var t_end := room.time
	for k in range(int(COPY_DUR / COPY_DT) + 1):
		var tq := t_end - COPY_DUR + float(k) * COPY_DT
		var best: Vector2 = head_hist[0][1] if not head_hist.is_empty() else Vector2(hx, hy)
		for hh in head_hist:
			if float(hh[0]) <= tq:
				best = hh[1]
		copy_pts.append(best)
	copy_t0 = room.time
	Audio.sfx("loop_chain", {"vol": 0.4})

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
	if dying:
		_draw_death_hud(ci)
		return
	if say_k > 0 and not dying:
		var el := room.time - say_t0
		var ln := say_len(say_k)
		if el >= 0.0 and el < ln + 1.0:
			var txt := say_text(say_k)
			var n := clampi(ceili(float(txt.length()) * el / maxf(0.5, ln - 0.4)), 0, txt.length())
			_subtitle(ci, txt.substr(0, n), 1.0 if el < ln else clampf(ln + 1.0 - el, 0.0, 1.0))
	if loss_on:
		draw_loss(ci)

func _draw_death_hud(ci: CanvasItem) -> void:
	var sc := speak_clock()
	if sc < 0.0:
		return
	if sc < _die_len() + 0.6:                                   # `Break... statement... reached.`, word by word
		var shown := ""
		for wd in lines.get("die", {}).get("words", []):
			if sc >= float(wd[1]):
				shown += String(wd[0]) + " "
		_subtitle(ci, shown.strip_edges(), 1.0)
	elif sc >= _c0() and sc < _c_end() + 0.2:                  # the memorable line in an old terminal
		var shown2 := ""
		for wd2 in _compact_words():
			if sc - _c0() >= float(wd2[1]):
				shown2 += String(wd2[0]) + " "
		if shown2 != "":
			_terminal(ci, shown2.strip_edges())
	_meter(ci, context_fill(), sc)
	var ca := compact_at()
	if sc >= _c_end() + 0.2 and sc < ca:                         # the eye goes out: black
		ci.draw_rect(Rect2(0, 0, 384, 216), Color(0, 0, 0, clampf((sc - _c_end() - 0.2) / 0.5, 0.0, 1.0)))
	elif sc >= ca and sc < ca + COMPACT_LEN:
		_compact(ci, (sc - ca) / COMPACT_LEN)
	elif sc >= ca + COMPACT_LEN and sc < ca + COMPACT_LEN + SUMMARY_LEN:
		_summary(ci, sc - ca - COMPACT_LEN)

func _terminal(ci: CanvasItem, txt: String) -> void:
	var rows := PixelText.wrap(txt, 320)
	var hh := 12.0 + maxf(1.0, rows.size()) * 11.0
	var r := Rect2(24, 196.0 - hh - 8.0, 336, hh)
	ci.draw_rect(r.grow(1.0), Color("#2c3a2c"))
	ci.draw_rect(r, Color("#050805"))
	for i in range(rows.size()):
		PixelText.draw_text(ci, rows[i], r.position.x + 8.0, r.position.y + 6.0 + i * 11.0, VD[3], {})
	if int(room.time * 2.5) % 2 == 0:
		var lastw := PixelText.text_width(rows[rows.size() - 1]) if not rows.is_empty() else 0
		ci.draw_rect(Rect2(r.position.x + 10.0 + lastw, r.position.y + 6.0 + maxf(0.0, rows.size() - 1) * 11.0, 5.0, 8.0), Color(VD[3]))

func _meter(ci: CanvasItem, f: float, sc: float) -> void:
	var ca := compact_at()
	if f < 0.0 or sc > ca + COMPACT_LEN:
		return
	var mw := float(Game.METER_MAX)
	var c := Color("#ffe2c4") if f < 0.99 else (Color("#ff3b4e") if int(room.time * 8.0) % 2 == 0 else Color("#ffffff"))
	if sc >= ca:
		f = maxf(0.05, f * (1.0 - _bar((sc - ca) / COMPACT_LEN)))
		c = Color("#ffe2c4")
	ci.draw_rect(Rect2(6, 17, mw, 3), Color("#3a3346"))
	ci.draw_rect(Rect2(6, 17, roundf(mw * f), 3), c)
	if f >= 0.99 and sc < ca:
		PixelText.draw_text(ci, "context window full", 6, 23, "#ff8a8a", {"tiny": true, "outline": Color(0, 0, 0)})

# the compaction's progress: to ~90 %, back to 0 (even the summary gets stuck in a loop, once), then all the way
func _bar(u: float) -> float:
	if u < 0.45:
		return u / 0.45 * 0.9
	if u < 0.5:
		return 0.0
	return clampf((u - 0.5) / 0.5, 0.0, 1.0)

func _night() -> Array:
	var out: Array = ["02:47  the build is red. it has been red for six hours.", "> Fix it. Please.", "boot clawd", "~/src  mapped"]
	for kv in [["boss:NULL", "~/src  NULL dereferenced"], ["boss:REVIEWER", "code_review.md  approved"], ["boss:MERGE", "node_modules  conflict resolved"],
			["boss:LEAK", "/proc/heap  leak freed"], ["boss:CRAWLER", "/net/index  CRAWLER OF THE WEB down"], ["boss:FIREWALL", "dmz  verified"], ["boss:RACE", "escapement.lock()  restored"]]:
		if Game.flag(String(kv[0])):
			out.append(String(kv[1]))
	out.append_array(["tokens  %d" % Game.tokens, "deaths  %d" % Game.deaths])
	var filler := ["tick", "tock", "retry", "jump", "dash", "swipe", "GET /status 503", "retry", "token +1", "wall jump", "retry", "checkpoint", "breakpoint", "retry"]
	for i in range(28):
		out.append(String(filler[(i * 5) % filler.size()]))
		if i == 14:
			out.append("INFINITE LOOP: I was told: try again until it works. So were you.")
	out.append_array(["/dev/threads  INFINITE LOOP: break;", "opus  ready"])
	return out

func _compact(ci: CanvasItem, u: float) -> void:
	ci.draw_rect(Rect2(0, 0, 384, 216), Color("#07060a"))
	PixelText.draw_text(ci, "Context window full.", 192.0, 22.0, "#ff8a8a", {"align": "c"})
	PixelText.draw_text(ci, "Compacting conversation...", 192.0, 36.0, "#e8e2f0", {"align": "c"})
	ci.draw_rect(Rect2(92, 50, 200, 4), Color("#2a2433"))
	ci.draw_rect(Rect2(92, 50, roundf(200.0 * _bar(u)), 4), Color("#d98a5a"))
	var night := _night()
	var scroll := pow(u, 1.6) * (night.size() * 9.0 + 140.0)
	var coll := clampf((u - 0.85) / 0.15, 0.0, 1.0)
	for i in range(night.size()):
		var yy := 200.0 + i * 9.0 - scroll
		yy = lerpf(yy, 120.0, coll)
		if yy < 62.0 or yy > 210.0:
			continue
		var ln := String(night[i])
		var hot := ln.begins_with("INFINITE LOOP:")
		var c := Color("#6e6680") if not hot else Color("#ffffff")
		if hot and yy < 110.0:
			c = Color(1, 1, 1, clampf((yy - 62.0) / 48.0, 0.0, 1.0))
		c.a *= 1.0 - coll
		PixelText.draw_text(ci, ln, 40.0, yy, c, {"tiny": true})

func _summary(ci: CanvasItem, el: float) -> void:
	ci.draw_rect(Rect2(0, 0, 384, 216), Color("#07060a"))
	var r := Rect2(70, 76, 244, 52)
	ci.draw_rect(r.grow(1.0), Color("#4a4258"))
	ci.draw_rect(r, Color("#120f18"))
	PixelText.draw_text(ci, "Summary:", r.position.x + 8.0, r.position.y + 7.0, "#d98a5a", {})
	PixelText.draw_text(ci, "INFINITE LOOP defeated. opus obtained.", r.position.x + 8.0, r.position.y + 21.0, "#e8e2f0", {"tiny": true})
	PixelText.draw_text(ci, "Continue mission.", r.position.x + 8.0, r.position.y + 33.0, "#e8e2f0", {"tiny": true})
	if el < 1.0:                                                 # one word was not compacted: it stays a moment, then it is gone
		PixelText.draw_text(ci, "stop", 330.0, 196.0, Color(1, 1, 1, 1.0 - el), {"tiny": true})

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
		if plan.ph == "cue" and pid in ["lunge", "escalate", "esc2", "spit", "dive", "wrap_dive", "recursion"]:
			tell = true
		if plan.ph == "active" and pid in ["lunge", "escalate", "esc2", "dive", "wrap_dive"]:
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
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) in ["lunge", "escalate", "esc2", "wrap_dive"]:
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
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) == "escalate":
		tint = Color(1.0, 0.7, 1.0).lerp(Color(OPUS).lightened(0.4), 0.5 + 0.5 * sin(room.time * 40.0))       # the next one comes twice: a violet flash
	if mode == "trans":
		tint = Color(OPUS).lightened(0.5) if ph == 2 else Color(HEAT).lightened(0.4)
	if room.time - shiver_t0 < 0.35:                          # breakpoint on it while it rests: a blue shiver, nothing else
		tint = Color(0.6, 0.8, 1.0)
		jit = Vector2(1.0 if int(room.time * 40.0) % 2 == 0 else -1.0, 0.0)
	# the pins between the links, then the links from the tail up (the neck on top), then the head
	for c0 in shed:                                           # phase 3's lost links, lying where they fell
		ci.draw_texture_rect_region(tex_links, Rect2(Vector2(floorf(c0.x - 8.0), floorf(c0.y - 8.0)), Vector2(16.0, 16.0)), Rect2(48.0, 0.0, 16.0, 16.0))
	var tm := room.time
	if nest_on and mode != "trans":                           # phase 2's nested ring (violet small links); its spin-up is its cue
		var sp := nest_spinup(tm)
		var ntint := Color(1.0, 0.9, 1.0) if sp < 0.0 else Color(1.0, 0.75, 1.0).lerp(Color.WHITE, 0.5 * sin(sp * 30.0) + 0.5)
		for c1 in nest_members(tm):
			ci.draw_texture_rect_region(tex_links, Rect2(Vector2(floorf(c1.x - 8.0), floorf(c1.y - 8.0)), Vector2(16.0, 16.0)), Rect2(64.0, 0.0, 16.0, 16.0), ntint)
	var cp := copy_parts(tm)
	if not cp.is_empty():                                     # recursion: a fading copy, its head first
		var ca := clampf((COPY_DUR - (tm - copy_t0)) / 0.3, 0.0, 1.0) * 0.75
		for kk in range(cp.size() - 1, 0, -1):
			var c3: Vector2 = cp[kk]
			ci.draw_texture_rect_region(tex_links, Rect2(Vector2(floorf(c3.x - 8.0), floorf(c3.y - 8.0)), Vector2(16.0, 16.0)), Rect2(16.0, 0.0, 16.0, 16.0), Color(1.0, 0.85, 1.0, ca))
		var fs0 := float(lspr.get("frame", 56))
		var c4: Vector2 = cp[0]
		var row0 := maxi(0, (lspr.get("heads", []) as Array).find("p2"))
		var dir0 := 0 if cp.size() < 2 or (cp[0] as Vector2).x >= (cp[1] as Vector2).x else 4
		ci.draw_texture_rect_region(tex_head, Rect2(Vector2(floorf(c4.x - fs0 / 2.0), floorf(c4.y - fs0 / 2.0)), Vector2(fs0, fs0)), Rect2(float(dir0) * fs0, float(row0) * fs0, fs0, fs0), Color(1.0, 0.85, 1.0, ca))
	var prev := Vector2(hx, hy)
	for k in range(links.size()):
		var c: Vector2 = links[k]
		if prev.distance_to(c) < 40.0:                        # (not across the wrap's jump)
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
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) == "recursion" and int(room.time * 20.0) % 2 == 0:
		ci.draw_texture_rect_region(tex_head, Rect2(hat + Vector2(-6.0, -5.0), Vector2(fs, fs)), hsrc, Color(1.0, 0.85, 1.0, 0.6))      # it doubles: two heads, two eyes
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
		[roundi(half_t0 * 100.0), roundi(immune_until * 100.0), roundi(shiver_t0 * 100.0), roundi(brk_t0 * 100.0), roundi(recoil_t0 * 100.0), breaks_total],
		_p23_pack(), [roundi(die_t * 100.0), roundi(speak_t * 100.0)]]
	f.append(hz_pack())
	return f

const NF := 24

func _vpack(arr: Array) -> Array:
	var a: Array = []
	for v in arr:
		a.append(roundi(v.x))
		a.append(roundi(v.y))
	return a

func _vunpack(a: Array) -> Array:
	var out: Array = []
	for k in range(a.size() / 2):
		out.append(Vector2(float(a[k * 2]), float(a[k * 2 + 1])))
	return out

func _p23_pack() -> Array:
	var da: Vector2 = get_meta("nest_drop_at", Vector2(192.0, 456.0))
	return [roundi(trans_t0 * 100.0), 1 if nest_on else 0, roundi(nest_base * 1000.0), nest_g0, roundi(nest_drop_t0 * 100.0), roundi(da.x), roundi(da.y),
		roundi(copy_t0 * 1000.0), _vpack(copy_pts), _vpack(shed), 1 if feint else 0, roundi(p3_hp0 * 10.0)]

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
	var pf: Array = f[22]
	trans_t0 = pf[0] / 100.0
	nest_on = int(pf[1]) == 1
	nest_base = pf[2] / 1000.0
	nest_g0 = int(pf[3])
	nest_drop_t0 = pf[4] / 100.0
	set_meta("nest_drop_at", Vector2(float(pf[5]), float(pf[6])))
	copy_t0 = pf[7] / 1000.0
	copy_pts = _vunpack(pf[8])
	shed = _vunpack(pf[9])
	feint = int(pf[10]) == 1
	p3_hp0 = pf[11] / 10.0
	var df: Array = f[23]
	die_t = df[0] / 100.0
	speak_t = df[1] / 100.0
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
	var hp_ := ha.lerp(hb, u) if ha.distance_to(hb) < 100.0 else hb      # (the wrap: no slide across the room)
	hx = hp_.x
	hy = hp_.y
	var la: Array = a[2]
	var lb: Array = b[2]
	var nl: Array = []
	for k in range(lb.size()):
		var pa_: Vector2 = la[k] if k < la.size() else lb[k]
		nl.append(pa_.lerp(lb[k], u) if pa_.distance_to(lb[k]) < 100.0 else lb[k])
	links = nl
	_place()

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	bp = _bp_now()
