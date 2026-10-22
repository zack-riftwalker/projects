class_name BelfryHall
extends RefCounted
# BelfryHall: the arena of T06, RACE CONDITION v3 (docs/metroidvania/17-race-build.md, section 4). The room owns it, not the boss, so the belfry is
# still there before the fight and the frozen pair after it. It owns the five bells (moving platforms that are a pure function of the room's clock
# and the bell fields), the escapement, the buffer floor (cells that corrupt and open), the back wall and the tower's beat clock for this room.
# The fields are state: the host's boss writes them, the guest's boss copy writes them from its net fields; every drawing and every position is
# computed from them and `room.time` alone, so both pages show the same belfry.
# T06 is a world-4 room: it has no Look / room_lights (those are the network's), so its lamps and heat are drawn here.

const T := 16
const PW := 416.0
const PH := 480.0
const FLOOR_ROW := 27
const FLOOR_Y := 432.0
const BEAM_Y := 32.0                       # the beam's underside (the back wall image draws the beam itself)

# bells: [first column, width in tiles, top row, size 0 big / 1 middle / 2 small]
const BELLS := [[2, 5, 24, 0], [19, 5, 24, 0], [11, 4, 21, 1], [7, 3, 17, 2], [16, 3, 17, 2]]
const N_BELLS := 5
const BODY_H := 32.0                       # a hanging bell's body under its top surface; a lying bell is this high too (2 tiles)
const SWING_P := 1.2                       # s, period of a swing
const SWING_D := 0.8                       # s, decay of a swing
const AMP_BIG := 4.0                       # px of a strike on a big bell
const AMP_SMALL := 5.0
const AMP_KICK := 3.0                      # a landing's kick
const CRACK_T := 0.8                       # rattle before a cracked bell falls
const G := 900.0
const LIE_T := 8.0                         # phase 1: a fallen bell lies this long,
const FADE_T := 0.5                        # fades out,
const REHANG_T := 1.5                      # and a new one lowers from the beam
const MAX_FALLEN_P2 := 2
const MIN_HANGING := 3

# the buffer floor: 8 cells of 3 tiles from tile 1
const CELLS := 8
const CELL_W := 48.0
const CELL_X0 := 16.0
const PAINT_WINDOW := 4.0
const CORRUPT_WARN := 0.6
const CORRUPT_T := 6.0                     # phase 1: a hurt band this long
const HOLE_T := 4.0                        # phase 2: the cell is open this long
const MAX_CORRUPT := 4
const MAX_HOLES := 2
const NONE_T := -100.0

# the escapement
const PIVOT := Vector2(208.0, 40.0)
const ROD := 144.0
const BOB_R := 9.0
const LOCK_PIN := Vector2(208.0, 64.0)     # the bob pinned against the beam's bracket while the lock cools

# the clock face in the back wall image (the hands are drawn over it)
const CLOCK_C := Vector2(208.0, 231.0)
const CLOCK_R := 48.0

const TICK_P1 := 0.7
const TICK_P2 := 0.6
const TICK_AFTER := 0.8333

const INK := "#1b1226"
const BRASS := "#b58a34"
const BRASS_HI := "#f0cd72"
const BRASS_LO := "#6e4d1c"
const PATINA := "#4f7a6a"
const IRON := "#2d2a33"
const TICK_COL := "#ff4a3a"
const TOCK_COL := "#2ee6d6"

var room
var ph := 1                                # 1 / 2 (the boss writes it; phase 2 is hot and red)
var p2_t0 := NONE_T                        # room time the phase-2 look started (a 0.6 s cross-fade)
var after := false                         # boss:RACE: the pair frozen, the pin in
var pin_in := false
var pin_t0 := NONE_T
var serial_until := NONE_T                 # the escapement is caught until this room time
var lock_cd_until := NONE_T                # the bob stays pinned out of reach until this room time
var esc_spark_t0 := NONE_T
var creak_t0 := NONE_T                     # the anchor's one crooked swing in the intro (the boss derives it from its intro clock, both pages)
var cam_lock_v = null                      # the boss's camera script (the intro's pan); the room reads it every step

# per bell
var strike_t0: Array = []
var amp: Array = []
var crack_t0: Array = []                   # -1: none (a time can be 0, so NONE_T for unset)
var fall_t0: Array = []
var fallen: Array = []
var rehang_t0: Array = []
var hit_cd: Array = []                     # a player rang it: its cooldown (room time)
var last_who: Array = []                   # which automaton struck it last (a second one within 0.25 s cracks it)
var pool: Array = []                       # the platform dictionaries (also in room.plats)

# the buffer floor
var paint_t: Array = [[], []]              # [thread][cell] room time a write of that thread painted the cell
var corrupt_t0: Array = []
var hole_t0: Array = []

# the tower's beat clock in this room: segments [t0, i0, len]; the length changes mid-room (the boss starts a segment at a tick boundary)
var segs: Array = [[0.0, 0, TICK_P1]]

var static_rev := 0
var _sig: Array = []
var _tex1: Texture2D
var _tex2: Texture2D
var wall_nodes: Array = []
var _cracks := {}

func _init(r) -> void:
	room = r
	for i in range(N_BELLS):
		strike_t0.append(NONE_T)
		amp.append(0.0)
		crack_t0.append(NONE_T)
		fall_t0.append(NONE_T)
		fallen.append(false)
		rehang_t0.append(NONE_T)
		hit_cd.append(NONE_T)
		last_who.append(-1)
		var rc := rest_rect(i)
		var m := {"x": rc.position.x, "y": rc.position.y, "w": rc.size.x, "h": 6.0, "dx": 0.0, "dy": 0.0, "bell": i, "off": false, "lost": false}
		pool.append(m)
		room.plats.append(m)
	for c in range(CELLS):
		paint_t[0].append(NONE_T)
		paint_t[1].append(NONE_T)
		corrupt_t0.append(NONE_T)
		hole_t0.append(NONE_T)
	after = Game.flag("boss:RACE")
	if after:
		pin_in = true
		pin_t0 = -1000.0
		segs = [[0.0, 0, TICK_AFTER]]
	move_bells()

static func wanted(def: Dictionary) -> bool:
	return String(def.get("hall", "")) == "belfry"

func reset() -> void:
	for i in range(N_BELLS):
		strike_t0[i] = NONE_T
		amp[i] = 0.0
		crack_t0[i] = NONE_T
		fall_t0[i] = NONE_T
		fallen[i] = false
		rehang_t0[i] = NONE_T
		hit_cd[i] = NONE_T
		last_who[i] = -1
	for c in range(CELLS):
		paint_t[0][c] = NONE_T
		paint_t[1][c] = NONE_T
		corrupt_t0[c] = NONE_T
		hole_t0[c] = NONE_T
	ph = 1
	p2_t0 = NONE_T
	serial_until = NONE_T
	lock_cd_until = NONE_T
	segs = [[room.time, 0, TICK_P1]]
	move_bells()

# ---------------------------------------------------------------- geometry
static func new_rest(i: int) -> Rect2:
	var b: Array = BELLS[i]
	return Rect2(float(int(b[0]) * T), float(int(b[2]) * T), float(int(b[1]) * T), BODY_H)

func rest_rect(i: int) -> Rect2:
	return new_rest(i)

func rest_cx(i: int) -> float:
	var rc := rest_rect(i)
	return rc.position.x + rc.size.x * 0.5

# where a lying bell's top is: on the floor, 2 tiles high
func lie_y() -> float:
	return FLOOR_Y - BODY_H

func fall_dist(i: int) -> float:
	return maxf(0.0, lie_y() - rest_rect(i).position.y)

func fall_time(i: int) -> float:
	return sqrt(2.0 * fall_dist(i) / G)

func land_t(i: int) -> float:
	return float(fall_t0[i]) + fall_time(i)

# a bell's state at room time t: "hang" (swinging), "crack" (rattling), "fall", "lie", "fade" (phase 1), "rehang" (lowering)
func bell_mode(i: int, t: float) -> String:
	var f0: float = fall_t0[i]
	if f0 < 0.0:
		return "hang"
	if t < f0:
		var c0: float = crack_t0[i]
		return "crack" if c0 >= 0.0 and t >= c0 else "hang"
	var rh: float = rehang_t0[i]
	if rh >= 0.0 and t >= rh:
		return "hang" if t >= rh + REHANG_T else "rehang"
	if t < land_t(i):
		return "fall"
	if ph == 1 and rh < 0.0 and t >= land_t(i) + LIE_T:
		return "fade"
	return "lie"

func swing_dx(i: int, t: float) -> float:
	var s: float = float(strike_t0[i])
	if s < 0.0 or t < s:
		return 0.0
	var age := t - s
	return float(amp[i]) * sin(TAU * age / SWING_P) * exp(-age / SWING_D)

# the pose of a bell: {x, y (top surface), mode, a (alpha)}
func bell_pose(i: int, t: float) -> Dictionary:
	var rc := rest_rect(i)
	var mode := bell_mode(i, t)
	var x := rc.position.x
	var y := rc.position.y
	var a := 1.0
	match mode:
		"hang":
			x += swing_dx(i, t)
		"crack":
			x += swing_dx(i, t) + sin(t * 70.0)
		"fall":
			var age := t - float(fall_t0[i])
			y = minf(lie_y(), y + 0.5 * G * age * age)
			x += swing_dx(i, float(fall_t0[i]))
		"lie":
			y = lie_y()
		"fade":
			y = lie_y()
			a = 1.0 - clampf((t - (land_t(i) + LIE_T)) / FADE_T, 0.0, 1.0)
		"rehang":
			var u: float = clampf((t - float(rehang_t0[i])) / REHANG_T, 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)
			y = lerpf(BEAM_Y - BODY_H, rc.position.y, u)
	return {"x": x, "y": y, "mode": mode, "a": a}

# the standing surface of a bell right now (null: not standable: falling, rattling is still standable, fading, lowering until it has arrived)
func bell_standable(i: int, t: float) -> bool:
	var m := bell_mode(i, t)
	if m == "fall" or m == "fade":
		return false
	if m == "rehang":
		return false
	if m == "lie" and ph == 2:
		return false                       # phase 2: a lying bell is solid tiles (apply), not a platform
	return true

func hanging(i: int, t: float) -> bool:
	var m := bell_mode(i, t)
	return m == "hang" or m == "crack" or m == "rehang"

func hanging_count(t: float) -> int:
	var n := 0
	for i in range(N_BELLS):
		if hanging(i, t):
			n += 1
	return n

func fallen_count(t: float) -> int:
	return N_BELLS - hanging_count(t)

# may bell i crack / be dropped now? (at least 3 hang always; phase 2: at most 2 down)
func can_fall(i: int, t: float) -> bool:
	if not hanging(i, t) or bell_mode(i, t) == "rehang" or bell_mode(i, t) == "crack":
		return false
	var cracking := 0
	for k in range(N_BELLS):
		if bell_mode(k, t) == "crack":
			cracking += 1
	var down := fallen_count(t) + cracking
	if N_BELLS - down - 1 < MIN_HANGING:
		return false
	if ph == 2:
		if down + 1 > MAX_FALLEN_P2 or i == 2:
			return false                       # (the middle bell is the way up: it never falls for good)
		if (i == 3 and not hanging(4, t)) or (i == 4 and not hanging(3, t)):
			return false                       # (one of the two small bells always hangs: the ring and the lock stay in reach)
	return true

# ---------------------------------------------------------------- bell actions (host and tests)
func strike(i: int, big := true, who := -1) -> void:
	if not hanging(i, room.time):
		return
	if who >= 0 and int(last_who[i]) >= 0 and int(last_who[i]) != who and room.time - float(strike_t0[i]) < 0.25:
		crack(i)                                       # both automata struck this bell within 0.25 s
	last_who[i] = who
	strike_t0[i] = snappedf(room.time, 0.01)
	amp[i] = AMP_BIG if int(BELLS[i][3]) == 0 and big else AMP_SMALL
	if int(BELLS[i][3]) == 0 and not big:
		amp[i] = AMP_KICK

func kick(i: int) -> void:
	if not hanging(i, room.time):
		return
	strike_t0[i] = snappedf(room.time, 0.01)
	amp[i] = AMP_KICK

# both automata struck the same bell within 0.25 s: it rattles for CRACK_T, then falls
func crack(i: int) -> bool:
	if not can_fall(i, room.time):
		return false
	crack_t0[i] = snappedf(room.time, 0.01)
	fall_t0[i] = snappedf(room.time + CRACK_T, 0.01)
	return true

# TOCK rips a chain: no rattle here (its cue is the chain rattling), the bell falls at once
func drop(i: int) -> bool:
	if not can_fall(i, room.time):
		return false
	crack_t0[i] = NONE_T
	fall_t0[i] = snappedf(room.time, 0.01)
	return true

# is a bell between its crack and its landing over x? (the `bellfall` hazard's box)
func fall_box(i: int, t: float) -> Rect2:
	var p := bell_pose(i, t)
	return Rect2(float(p.x), float(p.y), rest_rect(i).size.x, BODY_H)

# ---------------------------------------------------------------- the beat clock
func tick_len() -> float:
	return float(segs[segs.size() - 1][2])

func _seg_at(tm: float) -> Array:
	for k in range(segs.size() - 1, -1, -1):
		if tm >= float(segs[k][0]):
			return segs[k]
	return segs[0]

func tick_i_at(tm: float) -> int:
	var s := _seg_at(tm)
	return int(s[1]) + floori((tm - float(s[0])) / float(s[2]))

func tick_f_at(tm: float) -> float:
	var s := _seg_at(tm)
	return fposmod(tm - float(s[0]), float(s[2])) / float(s[2])

# the next tick boundary at or after `tm` (a length change starts there)
func next_boundary(tm: float) -> float:
	var s := _seg_at(tm)
	var k := ceili((tm - float(s[0])) / float(s[2]) - 0.000001)
	return float(s[0]) + float(k) * float(s[2])

# a new length from the next tick boundary on; a no-op when it is the length already (or already pending)
func set_tick(len_: float, tm: float) -> void:
	var last: Array = segs[segs.size() - 1]
	if absf(float(last[2]) - len_) < 0.0001:
		return
	var tb := snappedf(next_boundary(maxf(tm, float(last[0]))), 0.01)
	var i0 := tick_i_at(tb)
	segs.append([tb, i0, len_])
	if segs.size() > 6:
		segs.pop_front()

# the guest: the host's newest segment arrived in a snapshot
func seg_apply(t0: float, i0: int, len_: float) -> void:
	var last: Array = segs[segs.size() - 1]
	if absf(float(last[0]) - t0) < 0.005 and int(last[1]) == i0:
		last[2] = len_
		return
	if t0 < float(last[0]) - 0.005:
		segs = [[t0, i0, len_]]
		return
	segs.append([t0, i0, len_])
	if segs.size() > 6:
		segs.pop_front()

# ---------------------------------------------------------------- the buffer floor
func cell_of(px: float) -> int:
	return clampi(floori((px - CELL_X0) / CELL_W), 0, CELLS - 1)

func paint(cell: int, thread: int, tm: float) -> void:
	paint_t[thread][cell] = snappedf(tm, 0.01)

# 0 none, 1 white-hot build-up, 2 active (a hurt band); the cell's `corrupt_t0` is when the build-up began
func corrupt_state(cell: int, tm: float) -> int:
	var t0: float = corrupt_t0[cell]
	if t0 < 0.0 or tm < t0 - 0.006:
		return 0
	if tm < t0 + CORRUPT_WARN:
		return 1
	return 2 if tm < t0 + CORRUPT_WARN + CORRUPT_T else 0

func hole_state(cell: int, tm: float) -> int:
	var t0: float = hole_t0[cell]
	if t0 < 0.0 or tm < t0 - 0.006:
		return 0
	if tm < t0 + CORRUPT_WARN:
		return 1
	return 2 if tm < t0 + CORRUPT_WARN + HOLE_T else 0

func corrupt_count(tm: float) -> int:
	var n := 0
	for c in range(CELLS):
		if corrupt_state(c, tm) > 0:
			n += 1
	return n

func hole_count(tm: float) -> int:
	var n := 0
	for c in range(CELLS):
		if hole_state(c, tm) > 0:
			n += 1
	return n

func clear_buffer() -> void:
	for c in range(CELLS):
		corrupt_t0[c] = NONE_T
		hole_t0[c] = NONE_T
		paint_t[0][c] = NONE_T
		paint_t[1][c] = NONE_T

# host and solo: a cell painted by both threads within PAINT_WINDOW turns corrupt (phase 1) or opens (phase 2), within the limits
func step_buffer(tm: float) -> void:
	for c in range(CELLS):
		var a: float = paint_t[0][c]
		var b: float = paint_t[1][c]
		if a < 0.0 or b < 0.0 or absf(a - b) > PAINT_WINDOW or tm - maxf(a, b) > PAINT_WINDOW:
			continue
		if ph == 1:
			if corrupt_state(c, tm) > 0 or corrupt_count(tm) >= MAX_CORRUPT:
				continue
			corrupt_t0[c] = snappedf(tm, 0.01)
		else:
			if hole_state(c, tm) > 0 or hole_count(tm) >= MAX_HOLES:
				continue
			if (c > 0 and hole_state(c - 1, tm) > 0) or (c < CELLS - 1 and hole_state(c + 1, tm) > 0):
				continue
			hole_t0[c] = snappedf(tm, 0.01)
		paint_t[0][c] = NONE_T
		paint_t[1][c] = NONE_T

func cell_rect(c: int) -> Rect2:
	return Rect2(CELL_X0 + float(c) * CELL_W, FLOOR_Y, CELL_W, 16.0)

# ---------------------------------------------------------------- the escapement
func serialized(tm: float) -> bool:
	return tm < serial_until

func lock_cooling(tm: float) -> bool:
	return tm < lock_cd_until

# the rod's angle (rad from the vertical): crooked and lazy in phase 1, wild in phase 2, even while caught and after the pin
func esc_angle(tm: float) -> float:
	if pin_in:
		var tl := tick_len()
		return 0.32 * sin(PI * tm / tl)
	if serialized(tm):
		var tl2 := tick_len()
		return 0.3 * sin(PI * tm / tl2)
	if creak_t0 >= 0.0 and tm >= creak_t0 and tm < creak_t0 + 1.6:
		var age := tm - creak_t0
		return 0.1 + 0.55 * sin(TAU * age / 1.6) * exp(-age / 1.0)           # one crooked swing, creaking
	if ph == 2:
		return 0.62 * sin(tm * 4.3) + 0.2 * sin(tm * 9.1 + 1.0)
	return 0.1 + 0.28 * sin(tm * 1.1) + 0.08 * sin(tm * 2.9 + 2.0)

func bob_pos(tm: float) -> Vector2:
	if lock_cooling(tm):
		var u := clampf((lock_cd_until - tm) / 0.5, 0.0, 1.0)         # it swings back down over the last half second
		var a := esc_angle(tm)
		var swing := PIVOT + Vector2(sin(a), cos(a)) * ROD
		return LOCK_PIN.lerp(swing, 1.0 - u) if u < 1.0 else LOCK_PIN
	var a2 := esc_angle(tm)
	return PIVOT + Vector2(sin(a2), cos(a2)) * ROD

func bob_rect(tm: float) -> Rect2:
	var p := bob_pos(tm)
	return Rect2(p.x - 9.0, p.y - 9.0, 18.0, 18.0)

# a player's attack box on the bob and off cooldown?
func bob_hittable(tm: float) -> bool:
	return not lock_cooling(tm) and not serialized(tm) and not pin_in

# ---------------------------------------------------------------- the clock hands
# [hour angle, minute angle] clockwise from 12, radians
func hands(tm: float) -> Array:
	if pin_in:
		var k := floori((tm - pin_t0) / TICK_AFTER) if pin_t0 > -500.0 else floori(tm / TICK_AFTER)
		var mins := 12.0 + float(maxi(k, 0))
		var hrs := 5.0 + mins / 60.0
		return [TAU * hrs / 12.0, TAU * fposmod(mins, 60.0) / 60.0]
	if ph == 2 and room != null and tm >= p2_t0 and p2_t0 >= 0.0:
		return [tm * 0.9, tm * 7.0]
	var ti := tick_i_at(tm)
	var steps := ti - (ti / 5) * 2                  # every fifth tick the hands jump back a step: two forward, one back, no progress overall
	var tremble := 0.025 * sin(tm * 37.0)
	var mins2 := float(steps % 60)
	return [TAU * (12.0 + mins2 / 60.0) / 12.0 + tremble, TAU * mins2 / 60.0 + tremble * 1.5]

# ---------------------------------------------------------------- the net: the hall's state as the boss's snapshot fields (times x100)
const NET_N := 9 + N_BELLS * 6
const NEVER := -10000                       # a time x100 that never happened

func _t100(v: float) -> int:
	return NEVER if v < 0.0 else roundi(v * 100.0)

func _from100(v) -> float:
	return NONE_T if int(v) <= NEVER else float(v) / 100.0

func net_pack() -> Array:
	var last: Array = segs[segs.size() - 1]
	var a: Array = [ph, _t100(p2_t0), 1 if pin_in else 0, _t100(pin_t0), _t100(serial_until), _t100(lock_cd_until), roundi(float(last[0]) * 100.0), int(last[1]), roundi(float(last[2]) * 1000.0)]
	for i in range(N_BELLS):
		a.append_array([_t100(strike_t0[i]), roundi(float(amp[i]) * 10.0), _t100(crack_t0[i]), _t100(fall_t0[i]), 1 if fallen[i] else 0, _t100(rehang_t0[i])])
	var cells: Array = []                                # only the cells with something going on (the paint of the last PAINT_WINDOW, a corrupt cell, a hole)
	for c in range(CELLS):
		var pa: float = paint_t[0][c] if room.time - float(paint_t[0][c]) <= PAINT_WINDOW + 1.0 else NONE_T
		var pb: float = paint_t[1][c] if room.time - float(paint_t[1][c]) <= PAINT_WINDOW + 1.0 else NONE_T
		var co: float = corrupt_t0[c] if room.time - float(corrupt_t0[c]) <= CORRUPT_WARN + CORRUPT_T + 1.0 else NONE_T
		var ho: float = hole_t0[c] if room.time - float(hole_t0[c]) <= CORRUPT_WARN + HOLE_T + 1.0 else NONE_T
		if pa >= 0.0 or pb >= 0.0 or co >= 0.0 or ho >= 0.0:
			cells.append([c, _t100(pa), _t100(pb), _t100(co), _t100(ho)])
	a.append(cells)
	return a

func net_unpack(a: Array) -> void:
	ph = int(a[0])
	p2_t0 = _from100(a[1])
	pin_in = int(a[2]) == 1
	pin_t0 = _from100(a[3]) if int(a[3]) > NEVER else NONE_T
	if pin_in and int(a[3]) <= NEVER:
		pin_t0 = -1000.0
	serial_until = _from100(a[4])
	lock_cd_until = _from100(a[5])
	seg_apply(float(a[6]) / 100.0, int(a[7]), float(a[8]) / 1000.0)
	for i in range(N_BELLS):
		var o := 9 + i * 6
		strike_t0[i] = _from100(a[o])
		amp[i] = float(a[o + 1]) / 10.0
		crack_t0[i] = _from100(a[o + 2])
		fall_t0[i] = _from100(a[o + 3])
		fallen[i] = int(a[o + 4]) == 1
		rehang_t0[i] = _from100(a[o + 5])
	for c in range(CELLS):
		paint_t[0][c] = NONE_T
		paint_t[1][c] = NONE_T
		corrupt_t0[c] = NONE_T
		hole_t0[c] = NONE_T
	for rec in a[NET_N]:
		var c2 := int(rec[0])
		paint_t[0][c2] = _from100(rec[1])
		paint_t[1][c2] = _from100(rec[2])
		corrupt_t0[c2] = _from100(rec[3])
		hole_t0[c2] = _from100(rec[4])

# ---------------------------------------------------------------- per step (host, solo and guest)
func move_bells() -> void:
	var tm: float = room.time
	for i in range(N_BELLS):
		var m: Dictionary = pool[i]
		var p := bell_pose(i, tm)
		var mode := String(p.mode)
		var solid_top := bell_standable(i, tm)
		var ny: float = float(p.y)
		var nx: float = float(p.x)
		var was_off: bool = m.off
		m["off"] = not solid_top
		m["dx"] = 0.0 if (was_off or m.off) else nx - float(m.x)
		m["dy"] = 0.0 if (was_off or m.off) else ny - float(m.y)
		m["x"] = nx
		m["y"] = ny
		m["mode"] = mode
		if mode == "lie" and ph == 1:
			m["w"] = rest_rect(i).size.x

# host and solo: bells land, lie, rehang; the buffer ages
func step_host(tm: float) -> void:
	for i in range(N_BELLS):
		var m := bell_mode(i, tm)
		if m == "lie" or m == "fade":
			fallen[i] = true
			if ph == 1 and float(rehang_t0[i]) < 0.0 and tm >= land_t(i) + LIE_T + FADE_T:
				rehang_t0[i] = snappedf(tm, 0.01)
		elif m == "hang" and float(fall_t0[i]) >= 0.0 and float(rehang_t0[i]) >= 0.0 and tm >= float(rehang_t0[i]) + REHANG_T:
			fall_t0[i] = NONE_T                           # the new bell has arrived: a plain hanging bell again
			crack_t0[i] = NONE_T
			rehang_t0[i] = NONE_T
			fallen[i] = false
			strike_t0[i] = snappedf(tm, 0.01)
			amp[i] = AMP_KICK
		elif m == "fall":
			fallen[i] = false
	step_buffer(tm)

func step(_dt: float) -> void:
	if room.mode != "guest":
		step_host(room.time)
	apply()
	if wall_nodes.size() == 2 and is_instance_valid(wall_nodes[1]):
		var wa := wall2_alpha(room.time)
		wall_nodes[1].visible = wa > 0.0
		wall_nodes[1].modulate.a = wa

# the masks as tiles: the open floor cells (phase 2) and the lying bells (phase 2: solid blocks, cover)
func apply() -> void:
	var tm: float = room.time
	var holes := 0
	var blocks := 0
	for c in range(CELLS):
		if hole_state(c, tm) == 2:
			holes |= 1 << c
	for i in range(N_BELLS):
		var m := bell_mode(i, tm)
		if ph == 2 and (m == "lie"):
			blocks |= 1 << i
	var s: Array = [holes, blocks, ph]
	if s == _sig:
		return
	_sig = s
	var g = room.grid
	for c in range(CELLS):
		var open: bool = (holes >> c) & 1 == 1
		for k in range(3):
			var tx: int = 1 + c * 3 + k
			for ty in [FLOOR_ROW, FLOOR_ROW + 1]:
				_set_tile(g, tx, ty, TileGrid.E if open else TileGrid.SOLID)
	for i in range(N_BELLS):
		var b: Array = BELLS[i]
		var on: bool = (blocks >> i) & 1 == 1
		for k in range(int(b[1])):
			for ty in [FLOOR_ROW - 2, FLOOR_ROW - 1]:
				_set_tile(g, int(b[0]) + k, ty, TileGrid.SOLID if on else TileGrid.E)

func _set_tile(g, tx: int, ty: int, t: int) -> void:
	var idx: int = ty * g.w + tx
	if g.tiles[idx] == t:
		return
	g.tiles[idx] = t
	if room.view != null:
		room.view.refresh_tile(tx, ty)

# does a solid fallen bell (phase 2) stand between (x, y) and a ring's centre? A ring wave does not pass through it
func cover_between(a: Vector2, b: Vector2, tm: float) -> bool:
	for i in range(N_BELLS):
		if ph == 2 and bell_mode(i, tm) == "lie":
			var rc := rest_rect(i)
			var box := Rect2(rc.position.x, lie_y(), rc.size.x, BODY_H)
			if _seg_hits_rect(a, b, box):
				return true
	return false

func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for k in range(0, 17):
		var p := a.lerp(b, float(k) / 16.0)
		if r.grow(-0.5).has_point(p):
			return true
	return false

func cam_lock():
	return cam_lock_v

# ---------------------------------------------------------------- drawing: the back wall (drawn once; phase 2's picture fades in over it)
func _textures() -> void:
	if _tex1 == null:
		_tex1 = load("res://assets/bg/race_p1.png")
		_tex2 = load("res://assets/bg/race_p2.png")

func draw_wall(ci: CanvasItem) -> void:
	_textures()
	ci.draw_rect(Rect2(0.0, 0.0, PW, PH), Color("#0b0a12"))
	ci.draw_texture(_tex1, Vector2.ZERO)

func draw_wall2(ci: CanvasItem) -> void:
	_textures()
	ci.draw_texture(_tex2, Vector2.ZERO)

# the phase-2 picture's alpha: 0 before phase 2, 0.6 s fade, 1
func wall2_alpha(tm: float) -> float:
	if ph < 2 or p2_t0 < 0.0:
		return 0.0
	return clampf((tm - p2_t0) / 0.6, 0.0, 1.0)

# ---------------------------------------------------------------- drawing: every frame
func _ink() -> Color:
	return Color(INK)

func draw_shaded(ci: CanvasItem) -> void:
	var tm: float = room.time
	_draw_buffer(ci, tm)
	for i in range(N_BELLS):
		_draw_bell(ci, i, tm)
	_draw_escapement(ci, tm)
	_draw_hands(ci, tm)
	if after:
		_draw_after(ci, tm)

func _draw_chain(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float) -> void:
	var iron := Color(IRON)
	var hi := Color("#5d596a")
	var n := maxi(2, int(absf(y1 - y0) / 5.0))
	for k in range(n + 1):
		var u := float(k) / float(n)
		var px := lerpf(x0, x1, u)
		var py := lerpf(y0, y1, u)
		if k % 2 == 0:
			ci.draw_rect(Rect2(floorf(px) - 1.0, floorf(py), 3.0, 4.0), iron)
			ci.draw_rect(Rect2(floorf(px), floorf(py) + 1.0, 1.0, 2.0), hi)
		else:
			ci.draw_rect(Rect2(floorf(px), floorf(py), 1.0, 4.0), iron)

func _glow_of(i: int) -> float:
	var b = room.boss
	if b is RaceBoss:
		return b.glow_of_bell(i)
	return 0.0

func _draw_bell(ci: CanvasItem, i: int, tm: float) -> void:
	var p := bell_pose(i, tm)
	var mode := String(p.mode)
	var rc := rest_rect(i)
	var x: float = floorf(float(p.x) + 0.5)
	var y: float = floorf(float(p.y) + 0.5)
	var a: float = float(p.a)
	var w := rc.size.x
	if mode == "hang" or mode == "crack" or mode == "fall" or mode == "rehang":
		var cx0 := rest_cx(i)
		_draw_chain(ci, cx0, BEAM_Y, x + w * 0.5, y)
		_draw_bell_body(ci, x, y, w, int(BELLS[i][3]), tm, a, float(crack_t0[i]) >= 0.0 and tm >= float(crack_t0[i]), i)
		var gl := _glow_of(i)
		if gl > 0.0:                                              # an automaton is about to ring it: the bell warms up and shakes
			ci.draw_rect(Rect2(x - 1.0, y + 4.0, w + 2.0, 26.0), Color(1.0, 0.85, 0.45, 0.35 * gl))
			ci.draw_rect(Rect2(x - 2.0, y + 28.0, w + 4.0, 3.0), Color(1.0, 0.95, 0.7, 0.8 * gl))
		var sa := tm - float(strike_t0[i])
		if mode == "hang" and sa >= 0.0 and sa < 0.5 and float(amp[i]) > 0.0:                    # a struck bell's harmless ring
			var rr := 8.0 + 50.0 * sa / 0.5
			ci.draw_arc(Vector2(x + w * 0.5, y + 14.0), rr, 0.0, TAU, 24, Color(1.0, 0.95, 0.75, 0.35 * (1.0 - sa / 0.5) * (float(amp[i]) / AMP_BIG)), 1.0)
	elif mode == "lie" or mode == "fade":
		_draw_chain(ci, rest_cx(i), BEAM_Y, rest_cx(i), BEAM_Y + 22.0)       # a broken chain end dangles from the beam
		_draw_lying(ci, x, y, w, i, a)

func _draw_bell_body(ci: CanvasItem, x: float, y: float, w: float, _kind: int, tm: float, a: float, cracked: bool, i: int) -> void:
	var ink := _ink()
	ink.a = a
	var base := Color(BRASS)
	var hi := Color(BRASS_HI)
	var lo := Color(BRASS_LO)
	var pat := Color(PATINA)
	base.a = a
	hi.a = a
	lo.a = a
	pat.a = a
	# the body: a flared trapezoid under the crown plate
	var top_in := w * 0.14
	var pts := PackedVector2Array([Vector2(x + top_in, y + 4.0), Vector2(x + w - top_in, y + 4.0), Vector2(x + w, y + 28.0), Vector2(x, y + 28.0)])
	var out := PackedVector2Array([Vector2(x + top_in - 1.0, y + 3.0), Vector2(x + w - top_in + 1.0, y + 3.0), Vector2(x + w + 1.0, y + 29.0), Vector2(x - 1.0, y + 29.0)])
	ci.draw_colored_polygon(out, ink)
	ci.draw_colored_polygon(pts, base)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + top_in, y + 4.0), Vector2(x + top_in + w * 0.22, y + 4.0), Vector2(x + w * 0.3, y + 28.0), Vector2(x, y + 28.0)]), hi)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + w - top_in - w * 0.2, y + 4.0), Vector2(x + w - top_in, y + 4.0), Vector2(x + w, y + 28.0), Vector2(x + w - w * 0.26, y + 28.0)]), lo)
	ci.draw_rect(Rect2(x + w * 0.3, y + 11.0, w * 0.4, 2.0), pat)                    # a patina band
	# the crown plate: the standing surface
	ci.draw_rect(Rect2(x - 1.0, y - 1.0, w + 2.0, 6.0), ink)
	ci.draw_rect(Rect2(x, y, w, 4.0), base)
	ci.draw_rect(Rect2(x, y, w, 1.0), hi)
	ci.draw_rect(Rect2(x, y + 3.0, w, 1.0), lo)
	# the lip and the clapper
	ci.draw_rect(Rect2(x - 2.0, y + 28.0, w + 4.0, 5.0), ink)
	ci.draw_rect(Rect2(x - 1.0, y + 28.0, w + 2.0, 3.0), hi)
	ci.draw_rect(Rect2(x - 1.0, y + 31.0, w + 2.0, 1.0), lo)
	ci.draw_circle(Vector2(x + w * 0.5, y + 34.0), 2.5, ink)
	ci.draw_circle(Vector2(x + w * 0.5, y + 34.0), 1.5, base)
	# a swung or struck bell shows its note: a faint bright rim for a moment
	var s: float = float(strike_t0[i])
	if s >= 0.0 and tm - s < 0.25:
		var k := 1.0 - (tm - s) / 0.25
		ci.draw_rect(Rect2(x - 2.0, y + 28.0, w + 4.0, 1.0), Color(1.0, 0.95, 0.7, 0.8 * k * a))
	if cracked:
		var cx := x + w * 0.5
		for seg in [[0.0, 6.0, 2.0, 12.0], [2.0, 12.0, -1.0, 20.0], [-1.0, 20.0, 3.0, 28.0]]:
			ci.draw_line(Vector2(cx + seg[0], y + seg[1]), Vector2(cx + seg[2], y + seg[3]), Color(0.05, 0.03, 0.05, a), 1.0)

func _draw_lying(ci: CanvasItem, x: float, y: float, w: float, i: int, a: float) -> void:
	var ink := _ink()
	ink.a = a
	var base := Color(BRASS)
	var hi := Color(BRASS_HI)
	var lo := Color(BRASS_LO)
	base.a = a
	hi.a = a
	lo.a = a
	var east := i % 2 == 0                       # which way the mouth faces: the big and the first small bell to the east, the rest west
	var mx := x + w - 4.0 if east else x + 4.0
	ci.draw_rect(Rect2(x - 1.0, y + 1.0, w + 2.0, BODY_H), ink)
	var pts := PackedVector2Array()
	if east:
		pts = PackedVector2Array([Vector2(x + 2.0, y + 12.0), Vector2(x + w * 0.35, y + 5.0), Vector2(x + w, y + 1.0), Vector2(x + w, y + BODY_H), Vector2(x + w * 0.35, y + BODY_H - 4.0), Vector2(x + 2.0, y + BODY_H - 10.0)])
	else:
		pts = PackedVector2Array([Vector2(x + w - 2.0, y + 12.0), Vector2(x + w * 0.65, y + 5.0), Vector2(x, y + 1.0), Vector2(x, y + BODY_H), Vector2(x + w * 0.65, y + BODY_H - 4.0), Vector2(x + w - 2.0, y + BODY_H - 10.0)])
	ci.draw_colored_polygon(pts, base)
	ci.draw_rect(Rect2(x + 3.0, y + 4.0, w - 6.0, 3.0), hi)
	ci.draw_rect(Rect2(x + 3.0, y + BODY_H - 6.0, w - 6.0, 3.0), lo)
	ci.draw_rect(Rect2(mx - 3.0, y + 4.0, 6.0, BODY_H - 8.0), Color(0.06, 0.04, 0.05, a))          # the open mouth
	var ccx := mx - 8.0 if east else mx + 8.0
	ci.draw_circle(Vector2(ccx, y + BODY_H * 0.5), 3.0, ink)
	ci.draw_circle(Vector2(ccx, y + BODY_H * 0.5), 2.0, base)

# ---------------------------------------------------------------- the buffer floor
func _draw_buffer(ci: CanvasItem, tm: float) -> void:
	for c in range(CELLS):
		var r := cell_rect(c)
		for th in range(2):
			var pt: float = paint_t[th][c]
			if pt < 0.0 or tm < pt:
				continue
			var k := 1.0 - (tm - pt) / PAINT_WINDOW
			if k <= 0.0:
				continue
			var col := Color(TICK_COL if th == 0 else TOCK_COL)
			ci.draw_rect(Rect2(r.position.x + 2.0, r.position.y - 1.0 + float(th) * 3.0, r.size.x - 4.0, 3.0), Color(col.r, col.g, col.b, 0.8 * k))
		var cs := corrupt_state(c, tm)
		if cs == 1:
			var u := (tm - float(corrupt_t0[c])) / CORRUPT_WARN
			ci.draw_rect(Rect2(r.position.x, r.position.y - 2.0, r.size.x, 4.0), Color(1.0, 1.0, 0.9, 0.2 + 0.7 * u))
		elif cs == 2:
			var blink := int(tm * 14.0) % 2 == 0
			ci.draw_rect(Rect2(r.position.x, r.position.y - 6.0, r.size.x, 6.0), Color("#ff4a3a") if blink else Color("#ffd0c0"))
			var gx := 0
			while gx < int(r.size.x):
				ci.draw_rect(Rect2(r.position.x + float(gx), r.position.y - 6.0 - float((gx / 4 + int(tm * 20.0)) % 3), 2.0, 2.0), Color("#ffffff"))
				gx += 6
		var hs := hole_state(c, tm)
		if hs == 1:
			var u2 := (tm - float(hole_t0[c])) / CORRUPT_WARN
			ci.draw_rect(Rect2(r.position.x, r.position.y - 1.0, r.size.x, 3.0), Color(1.0, 1.0, 0.9, 0.2 + 0.7 * u2))
			ci.draw_rect(Rect2(r.position.x, r.position.y + 3.0, r.size.x, 2.0), Color(1.0, 0.3, 0.2, 0.25 + 0.5 * u2))
		elif hs == 2:
			ci.draw_rect(Rect2(r.position.x, FLOOR_Y, r.size.x, 32.0), Color("#0a0306"))             # the pit
			ci.draw_rect(Rect2(r.position.x, FLOOR_Y + 30.0, r.size.x, 2.0), Color("#ff4a3a"))      # its bottom hurts
			ci.draw_rect(Rect2(r.position.x, FLOOR_Y, 2.0, 32.0), Color(0.45, 0.3, 0.1))
			ci.draw_rect(Rect2(r.position.x + r.size.x - 2.0, FLOOR_Y, 2.0, 32.0), Color(0.45, 0.3, 0.1))

# ---------------------------------------------------------------- the escapement
func _draw_escapement(ci: CanvasItem, tm: float) -> void:
	var a := esc_angle(tm)
	var ink := _ink()
	var br := Color(BRASS)
	var hi := Color(BRASS_HI)
	var lo := Color(BRASS_LO)
	var rot := Transform2D(a, PIVOT)
	# the anchor: an arc of 5 tiles with a pallet at each end
	var prev := Vector2.ZERO
	var first := true
	for k in range(0, 17):
		var ang := lerpf(deg_to_rad(205.0), deg_to_rad(335.0), float(k) / 16.0)
		var pt := rot * (Vector2(cos(ang), sin(ang)) * 44.0 + Vector2(0.0, 40.0))
		if not first:
			ci.draw_line(prev, pt, ink, 5.0)
		prev = pt
		first = false
	prev = Vector2.ZERO
	first = true
	for k in range(0, 17):
		var ang2 := lerpf(deg_to_rad(205.0), deg_to_rad(335.0), float(k) / 16.0)
		var pt2 := rot * (Vector2(cos(ang2), sin(ang2)) * 44.0 + Vector2(0.0, 40.0))
		if not first:
			ci.draw_line(prev, pt2, br, 3.0)
			ci.draw_line(prev + Vector2(0, -1), pt2 + Vector2(0, -1), hi, 1.0)
		prev = pt2
		first = false
	for sgn in [-1.0, 1.0]:
		var p0: Vector2 = rot * Vector2(sgn * 40.0, -2.0 + 40.0 - 40.0 + 14.0)
		var p1: Vector2 = rot * Vector2(sgn * 47.0, 14.0 + 16.0)
		ci.draw_line(p0, p1, ink, 5.0)
		ci.draw_line(p0, p1, Color("#8a8d96"), 3.0)                  # grey pallets
	# the rod and the bob
	var bob := bob_pos(tm)
	var rod_end := bob
	if lock_cooling(tm) and bob.distance_to(LOCK_PIN) < 1.0:
		rod_end = LOCK_PIN
	ci.draw_line(PIVOT, rod_end, ink, 4.0)
	ci.draw_line(PIVOT, rod_end, lo, 2.0)
	ci.draw_line(PIVOT + Vector2(-1, 0), rod_end + Vector2(-1, 0), br, 1.0)
	ci.draw_circle(bob, BOB_R + 1.0, ink)
	ci.draw_circle(bob, BOB_R, br)
	ci.draw_circle(bob + Vector2(-2, -2), 5.0, hi)
	ci.draw_circle(bob + Vector2(2, 3), 3.0, lo)
	# the pivot: a red cross where the pin should be, a red dot once it is in
	if pin_in:
		var steady := 0.65 + 0.35 * sin(tm * 6.0)
		ci.draw_circle(PIVOT, 4.0, ink)
		ci.draw_circle(PIVOT, 3.0, Color(1.0, 0.2 + 0.1 * steady, 0.15))
	else:
		var red := Color("#ff3b2f")
		ci.draw_line(PIVOT + Vector2(-4, -4), PIVOT + Vector2(4, 4), ink, 4.0)
		ci.draw_line(PIVOT + Vector2(-4, 4), PIVOT + Vector2(4, -4), ink, 4.0)
		ci.draw_line(PIVOT + Vector2(-4, -4), PIVOT + Vector2(4, 4), red, 2.0)
		ci.draw_line(PIVOT + Vector2(-4, 4), PIVOT + Vector2(4, -4), red, 2.0)
	if ph == 2 and not pin_in and not serialized(tm):                 # sparks fly off the wild anchor
		for k in range(5):
			var h := Game.hash3(k, floori(tm * 12.0), 5)
			var h2 := Game.hash3(k, floori(tm * 12.0), 9)
			var sp := bob + Vector2((h - 0.5) * 40.0, -(h2) * 26.0)
			ci.draw_rect(Rect2(floorf(sp.x), floorf(sp.y), 2.0, 2.0), Color("#ffd27a") if k % 2 == 0 else Color("#ff7a3a"))

# ---------------------------------------------------------------- the clock hands over the face in the back wall
func _draw_hands(ci: CanvasItem, tm: float) -> void:
	var h := hands(tm)
	var ink := _ink()
	var gold := Color("#e8b84a")
	var ctr := CLOCK_C
	var ha: float = float(h[0])
	var ma: float = float(h[1])
	var hv := Vector2(sin(ha), -cos(ha))
	var mv := Vector2(sin(ma), -cos(ma))
	ci.draw_line(ctr, ctr + hv * (CLOCK_R * 0.5), ink, 5.0)
	ci.draw_line(ctr, ctr + hv * (CLOCK_R * 0.5), gold, 3.0)
	ci.draw_circle(ctr + hv * (CLOCK_R * 0.5), 3.0, gold)               # the sun-shaped tip of the hour hand
	ci.draw_line(ctr, ctr + mv * (CLOCK_R * 0.78), ink, 4.0)
	ci.draw_line(ctr, ctr + mv * (CLOCK_R * 0.78), Color("#f6d77a"), 2.0)
	ci.draw_circle(ctr, 5.0, ink)
	ci.draw_circle(ctr, 4.0, Color("#c9962f"))

# ---------------------------------------------------------------- after the fight: the pair, bowing for ever (the bodies are the boss's drawing helper)
func _draw_after(_ci: CanvasItem, _tm: float) -> void:
	pass

# ---------------------------------------------------------------- the glow layer: the lamps, the phase-2 heat
func draw_glow(ci: CanvasItem) -> void:
	var tm: float = room.time
	var hot := wall2_alpha(tm)
	var warm := Color(1.0, 0.72, 0.3)
	var red := Color(1.0, 0.35, 0.2)
	var lc := warm.lerp(red, hot)
	var flick := 0.9 + 0.1 * sin(tm * 9.0) * sin(tm * 3.7)
	for lp in [Vector2(24.0, 192.0), Vector2(392.0, 192.0)]:
		for k in range(5):
			var r := 70.0 - float(k) * 12.0
			ci.draw_circle(lp, r, Color(lc.r, lc.g, lc.b, 0.035 * flick))
	if hot > 0.0:
		ci.draw_rect(Rect2(0.0, 0.0, PW, PH), Color(1.0, 0.25, 0.1, 0.07 * hot))
