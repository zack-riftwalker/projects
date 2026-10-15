class_name CrawlerBoss
extends Boss
# CRAWLER OF THE WEB (docs/metroidvania/14-crawler.md): an old search engine nobody asks anything any more; with nothing left to answer it only
# crawls, and it has become its own spider. A big body (an old beige case under a CRT that shows its homepage, the text cursor for an eye) on
# eight long cable legs with a red LED at each tip, in its tall hall (IndexHall: drawers, a web net over a spike pit, two strands, a screen).
# No warning is drawn on the screen: every attack is read from the body (a leg's LED brightens and the leg draws back, the body crouches, the
# cursor widens, the search box types). The kit still runs each attack as an announced plan, so the guest sees the same wind-up.
# Two layers at once: the attack, and the hall (CAPTCHA squares, falling drawers, the dark). Choices are weighted by where the target is and
# never repeat. Phase 1 (lit, heavy): fetch, results, drop. Phase 2 (a leg breaks: it leaps; the net tears, the tubes break): leap, fetch,
# results, CAPTCHA. Phase 3 (blackout, it swings from the ceiling): flash + stabs at the remembered spots + a dive at where you are now,
# feints, results, small crawlers on the strands, drawers falling every 10 s; the last 15 % without its leg lights.

const IDS := ["fetch", "results", "drop", "leap", "flash", "dive", "feint"]
const KINDS := ["captcha", "drawer", "stab", "ling"]
const FLOOR_Y := 336.0
const CEIL_Y := 16.0
const HANG_Y := 62.0
const HOME := Vector2(192.0, 62.0)
const BW := 44.0
const BH := 30.0
const P2_AT := 0.65
const P3_AT := 0.30
const DARK_AT := 0.15
const PIVOT := Vector2(192.0, 16.0)
const SW_LEN := 150.0
const SW_AMP := 0.85
const SW_T := 3.4
const SHIFT2 := 2.0
const SHIFT3 := 3.0
const DIVE_CUE := 0.7               # a 2-damage hit is wound up at least 0.7 s (the kit's rule)
const QUERIES := ["where is it", "new agent", "who replaced me", "is it faster", "find the new one", "why"]
const SCREENS := ["home", "query", "results", "zero", "off"]
const INK := "#1b1226"
const BEIGE := "#c9b98f"
const RED := "#ff3b4e"
const CABLES := ["#8d93a0", "#c9b98f", "#3f6fd0", "#8d93a0", "#6a6f7a", "#c9b98f", "#3f6fd0", "#6a6f7a"]

var core_px := 192.0
var core_y := 62.0
var strike_sid := 0                 # the strike now (a parry is checked against it)
var ph := 1                         # the phase it is in (a phase change waits for its little scene)
var shift_k := 0                    # 2 or 3: the scene of the change to that phase is running
var shift_t := 0.0
var legs_ok := 8                    # 7 once a leg broke (phase 2)
var leg_x := 0.0                    # the stab: where the leg strikes / stays planted
var leg_y := 0.0
var leg_on := 0                     # 0 none, 1 striking, 2 planted in the web (claw it 3 times: the body sags)
var leg_k := 0                      # which leg
var leg_hits := 0
var leg_i := 0
var leg_n := 1
var down_t := 0.0                   # host: sagging low (a knocked leg, a caught link): the body is in reach
var low := false                    # the body is low now (down, stuck after a drop / leap / dive)
var pend := ""                      # host: an attack waiting for the body to get above the target first (drop)
var pend_x := 0.0
var pend_t := 0.0
var arc_a := Vector2.ZERO           # a leap or a dive: from, to
var arc_b := Vector2.ZERO
var dc := 0                         # phase 3: swinging from the middle of the ceiling
var sw_t0 := 0.0
var sw_x0 := 192.0
var sw_y0 := 62.0
var flash_t0 := -9.0                # the room time of the last flash (a light, and its stabs)
var dbl := false                    # host: the flash is the first of two
var combo := ""                     # host: the attack that must follow (a flash or a feint is followed by a dive)
var last_id := ""
var idle_t := 1.0
var vol_n := 0
var vol_t := 0.0
var captcha_cd := 4.0
var drawer_cd := 6.0
var ling_cd := 2.0
var scr := 0                        # the screen: SCREENS index
var scr_t0 := 0.0
var scr_q := 0
var feet: Array = []                # cosmetic, each page its own: [{p, from, to, t}] the planted feet of the eight legs
var dark_k := 0.0                   # cosmetic: smoothed darkness

func _init(r: Room, bx: float, by: float, base_hp := 82) -> void:
	super(r, bx, by, BW, BH, base_hp)
	boss_name = "CRAWLER OF THE WEB"
	sub = "search engine · 0 searches today"
	col = BEIGE
	kit_init()
	core_px = HOME.x
	core_y = HOME.y
	_place()
	for i in range(8):
		feet.append({"p": _ideal_foot(i), "from": Vector2.ZERO, "to": Vector2.ZERO, "t": 0.0})

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return KINDS

func _big() -> int:
	return int(Game.dv("big_hit"))

func _place() -> void:
	x = core_px - w / 2.0
	y = core_y - h / 2.0

func _hall():
	return room.hall

func _phase_hp() -> int:
	var f := hpf / float(max_hp)
	return 3 if f <= P3_AT else (2 if f <= P2_AT else 1)

func lights_out() -> bool:
	return ph == 3 and hpf / float(max_hp) <= DARK_AT

# ---------------------------------------------------------------- boxes
func _body_box() -> Dictionary:
	return {"x": core_px - BW / 2.0, "y": core_y - BH / 2.0, "w": BW, "h": BH}

func _cbox() -> Dictionary:                           # the "I'm not a robot" tick box, on the left drawer of row 12
	return {"x": 24.0, "y": 180.0, "w": 12.0, "h": 12.0, "cbox": 1}

func _captcha_on() -> bool:
	for h in hz:
		if h.k == "captcha":
			return true
	return false

func hurtboxes() -> Array:
	var b: Array = []
	if shift_k == 0:
		b.append(_body_box())
	if leg_on == 2:
		b.append({"x": leg_x - 6.0, "y": leg_y - 30.0, "w": 12.0, "h": 30.0, "leg": 1})
	if _captcha_on():
		b.append(_cbox())
	for h in hz:
		if h.k == "ling" and hz_live(h, room.time):
			var lp := ling_pos(h, room.time)
			b.append({"x": lp.x - 5.0, "y": lp.y - 4.0, "w": 10.0, "h": 8.0, "ling": hz_key(h)})
	return b

func harmboxes() -> Array:
	var b: Array = []
	if active and not dying and shift_k == 0:
		var bb := _body_box()
		bb["dmg"] = 1
		if plan_active() and String(plan.id) in ["drop", "dive"]:
			bb["dmg"] = _big()
		if plan_active() and String(plan.id) == "leap" and float(plan.t) < 0.15:
			bb = {"x": core_px - 28.0, "y": core_y - BH / 2.0, "w": 56.0, "h": BH + 4.0, "dmg": _big()}
		b.append(bb)
		if leg_on == 1 and plan_active() and String(plan.id) == "fetch":
			b.append({"x": leg_x - 7.0, "y": leg_y - 30.0, "w": 14.0, "h": 34.0, "dmg": 1, "sid": strike_sid, "catchable": false})
	b.append_array(hz_harm())
	return b

# ---------------------------------------------------------------- the hall's hazards: pure functions of their fields and the room time
func ling_pos(h: Dictionary, now: float) -> Vector2:
	var s: Array = IndexHall.STRANDS[clampi(int(h.v[0]), 0, 1)]
	var x0 := float(s[0]) * 16.0
	var x1 := float(int(s[0]) + int(s[2])) * 16.0
	var dir := float(h.v[1])
	var u := maxf(0.0, now - float(h.t0) - float(h.warn)) * 42.0
	var px := (x0 + u) if dir > 0.0 else (x1 - u)
	return Vector2(px, float(s[1]) * 16.0 - 4.0)

func hz_boxes(h: Dictionary, now: float) -> Array:
	var since := now - float(h.t0) - float(h.warn)
	match String(h.k):
		"stab":
			if since < 0.25:
				return [{"x": float(h.v[0]) - 7.0, "y": float(h.v[1]) - 28.0, "w": 14.0, "h": 34.0, "dmg": 1}]
		"drawer":
			var r: Rect2 = room.hall.drawer_rect(clampi(int(h.v[0]), 0, 9)) if room.hall != null else Rect2()
			if since < 0.8:
				return [{"x": r.position.x, "y": r.position.y + since * 320.0, "w": r.size.x, "h": 12.0, "dmg": 1}]
		"ling":
			var lp := ling_pos(h, now)
			return [{"x": lp.x - 4.0, "y": lp.y - 3.0, "w": 8.0, "h": 6.0, "dmg": 1}]
	return []

# ---------------------------------------------------------------- hits
func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if b is Dictionary and b.has("cbox"):
		if active and not dying:
			room.pop(30.0, 168.0, "Verification failed: you are a robot", "#ff8a8a", true)
			Audio.sfx("glitch", {"vol": 0.7})
		return "hit"
	if b is Dictionary and b.has("ling"):
		for h in hz.duplicate():
			if hz_key(h) == String(b.ling):
				var lp := ling_pos(h, room.time)
				room.burst(lp.x, lp.y, 6, ["#d6f6ff", RED], 90.0, 200.0)
				hz.erase(h)
		Audio.sfx("squish", {"vol": 0.7})
		return "kill"
	if b is Dictionary and b.has("leg"):
		if not active or dying:
			return ""
		leg_hits += 1
		room.burst(leg_x, leg_y - 12.0, 4, ["#ffffff", RED], 80.0, 200.0)
		Audio.sfx("clang", {"vol": 0.6})
		if leg_hits >= 3:                                  # the leg tears out of the web: the body sags into reach
			leg_on = 0
			leg_hits = 0
			down_t = 1.6
			room.shake(0.4)
			Audio.sfx("brk")
		return "hit"
	if not active or dying or shift_k != 0:
		return ""
	if how == "catch":
		down_t = maxf(down_t, 1.5)                         # a link caught back into its screen: dazed, it sags
		room.burst(core_px, core_y - 8.0, 8, ["#ffd23f", "#ffffff"], 90.0, 100.0)
	return super.hit(d, dx, dy, how, b)

func on_damage() -> void:
	var p := _phase_hp()
	if p > ph and shift_k == 0 and not dying and hpf > 0.0:
		_begin_shift(p)

func start() -> void:
	super.start()
	idle_t = 0.8
	scr = 0

# ---------------------------------------------------------------- the phase scenes (it cannot be hurt during them)
func _begin_shift(p: int) -> void:
	shift_k = p
	shift_t = SHIFT2 if p == 2 else SHIFT3
	plan = {}
	pend = ""
	combo = ""
	leg_on = 0
	down_t = 0.0
	room.shake(0.8)
	Audio.sfx("roar", {"vol": 0.8})
	room.events.append("bossPhase")
	Game.dlog("%s phase %d" % [boss_name, p])

func _step_shift(dt: float) -> void:
	var hl = _hall()
	var total := SHIFT2 if shift_k == 2 else SHIFT3
	var u := 1.0 - shift_t / total
	shift_t -= dt
	if shift_k == 2:
		core_y = move_toward(core_y, 250.0, 300.0 * dt)       # it slams itself down; a leg snaps
		if u > 0.35 and legs_ok == 8:
			legs_ok = 7
			room.shake(1.0)
			room.burst(core_px + 14.0, core_y, 12, ["#ffffff", "#ffd23f", RED], 160.0, 300.0)
			Audio.sfx("brk")
			if hl != null:
				hl.zones &= ~_zone_bit(core_px)
	else:
		if hl != null:                                        # the power dies: the tubes one by one, the screen shows 0, then nothing
			var n := clampi(floori(u * 5.0), 0, 4)
			for i in range(n):
				hl.zones &= ~(1 << i)
			if u > 0.55:
				scr = SCREENS.find("zero")
			if u > 0.85:
				scr = SCREENS.find("off")
			if u > 0.4:
				hl.net = 0
		core_px = move_toward(core_px, PIVOT.x, 160.0 * dt)
		core_y = move_toward(core_y, PIVOT.y + SW_LEN, 160.0 * dt)
	if shift_t <= 0.0:
		ph = shift_k
		phase = ph
		shift_k = 0
		if ph == 3:
			dc = 1
			_swing_from_here()
			ling_cd = 0.5
			drawer_cd = 6.0
		idle_t = 0.5
		last_id = ""

func _zone_bit(px: float) -> int:
	return 1 << clampi(floori(px / 96.0), 0, 3)

# ---------------------------------------------------------------- update (host)
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	_feet_step(dt)
	if dying:
		hz.clear()
		down_t = 0.0
		core_y = move_toward(core_y, FLOOR_Y - 40.0, 160.0 * dt)
		death_rattle(dt, 2.6, ["#ffffff", "#d6f6ff", BEIGE, "#57ff8a"])
		_sync_hall()
		_place()
		return
	if not active:
		_sync_hall()
		_place()
		return
	_hz_expire()
	if shift_k != 0:
		_step_shift(dt)
		_sync_hall()
		_place()
		return
	down_t = maxf(0.0, down_t - dt)
	_pressure(dt)
	if plan.is_empty():
		plan_clock += dt
		_idle_move(dt)
		idle_t -= dt
		if pend != "":
			pend_t -= dt
			if absf(core_px - pend_x) < 6.0 or pend_t <= 0.0:
				var id := pend
				pend = ""
				_start(id, kit_pick_target())
		elif idle_t <= 0.0:
			_choose()
	else:
		_plan_logic(dt)
	_sync_hall()
	_place()

# the hall follows the boss (host: from its state; guest: from the net fields, in net_apply)
func _sync_hall() -> void:
	var hl = _hall()
	if hl == null:
		return
	var hide := 0
	hl.rattle = {}
	for h in hz:
		match String(h.k):
			"captcha":
				if hz_live(h, room.time):
					var sel := int(h.v[0])
					for k in range(7):
						if (sel >> k) & 1 == 1:
							hide |= 3 << (k * 2)
			"drawer":
				if not hz_live(h, room.time):
					hl.rattle[int(h.v[0])] = float(h.t0)
	hl.hide = hide & IndexHall.ALL_NET
	var dk := 0.0
	if ph == 2 or shift_k == 2:
		var lit := 0
		for i in range(4):
			if (hl.zones >> i) & 1 == 1:
				lit += 1
		dk = 0.15 + 0.5 * float(4 - lit) / 4.0
	if ph == 3 or shift_k == 3:
		dk = 1.0 if ph == 3 else clampf(1.0 - shift_t / SHIFT3, 0.0, 1.0)
	hl.dark = dk
	var mode: String = SCREENS[clampi(scr, 0, SCREENS.size() - 1)]
	if _captcha_on() and mode != "zero" and mode != "off":
		var sel2 := 0
		for h in hz:
			if h.k == "captcha":
				sel2 = int(h.v[0])
		hl.screen = {"mode": "captcha", "text": "", "t0": 0.0, "sel": sel2}
	else:
		hl.screen = {"mode": mode, "text": QUERIES[clampi(scr_q, 0, QUERIES.size() - 1)], "t0": scr_t0, "sel": 0, "sub": "%d results" % (1 + scr_q * 7 % 9)}
	hl.apply()                                          # (the tiles follow at once: a torn cell is not a floor for another frame)

func _hz_expire() -> void:
	var now := room.time
	var hl = _hall()
	for h in hz.duplicate():
		var since := now - float(h.t0) - float(h.warn)
		match String(h.k):
			"captcha":
				if since > 2.5:
					hz.erase(h)
			"stab":
				if since > 0.3:
					hz.erase(h)
			"drawer":
				if since >= 0.0 and hl != null:
					hl.drawers &= ~(1 << int(h.v[0]))
				if since > 0.8:
					hz.erase(h)
			"ling":
				var lp := ling_pos(h, now)
				var s: Array = IndexHall.STRANDS[clampi(int(h.v[0]), 0, 1)]
				if lp.x < float(s[0]) * 16.0 - 2.0 or lp.x > float(int(s[0]) + int(s[2])) * 16.0 + 2.0 or (hl != null and (hl.strands >> int(h.v[0])) & 1 == 0):
					hz.erase(h)

# the hall's own pressure, beside the attack
func _pressure(dt: float) -> void:
	var hl = _hall()
	if hl == null:
		return
	if ph == 2:
		captcha_cd -= dt
		if captcha_cd <= 0.0 and not _captcha_on():
			captcha_cd = 11.0
			var sel := 0
			var picks := [0, 1, 2, 3, 4, 5, 6]
			picks.shuffle()
			for k in range(3 + room.rng.randi() % 2):
				sel |= 1 << int(picks[k])
			hz_add("captcha", 1.4, [sel])
			Audio.sfx("textSys", {"vol": 0.8})
	if ph == 3:
		drawer_cd -= dt
		if drawer_cd <= 0.0:
			drawer_cd = 10.0
			_drop_drawer(-1)
		ling_cd -= dt
		var n := 0
		for h in hz:
			if h.k == "ling":
				n += 1
		if ling_cd <= 0.0 and n < 2:
			ling_cd = 7.0
			var si := room.rng.randi() % 2
			if (hl.strands >> si) & 1 == 1:
				hz_add("ling", 0.7, [si, 1 if room.rng.randf() < 0.5 else -1])

# a drawer shakes, then falls (never fewer than four left: there is always a way to win). di < 0: one at random
func _drop_drawer(di: int) -> void:
	var hl = _hall()
	if hl == null or hl.drawers_left() <= 4:
		return
	var cand: Array = []
	for i in range(IndexHall.DRAWERS.size()):
		if (hl.drawers >> i) & 1 == 1:
			var busy := false
			for h in hz:
				if h.k == "drawer" and int(h.v[0]) == i:
					busy = true
			if not busy:
				cand.append(i)
	if cand.is_empty():
		return
	var pick: int = di if di in cand else int(cand[room.rng.randi() % cand.size()])
	hz_add("drawer", 0.8, [pick])

# ---------------------------------------------------------------- moving between attacks
func _idle_move(dt: float) -> void:
	if dc == 1:
		var p := dc_pos(room.time)
		core_px = p.x
		core_y = p.y
		low = false
		return
	if down_t > 0.0:
		core_y = move_toward(core_y, 232.0, 260.0 * dt)
		low = true
		return
	low = false
	var tx := core_px
	if pend != "":
		tx = pend_x
	elif ph == 1:
		var ap := kit_aim(kit_pick_target()) if not kit_keys().is_empty() else HOME
		tx = clampf(ap.x, 56.0, 328.0)
	# jerky: it scuttles in bursts, then stops dead (a pure function of the clock: no state)
	var go := 1.0 if fposmod(room.time, 0.5) < 0.28 else 0.0
	var spd := (300.0 if pend != "" else 170.0) * (go if pend == "" else 1.0)
	if ph == 2:
		spd *= 0.6                                      # a broken leg: it drags itself
	core_px = move_toward(core_px, tx, spd * dt)
	core_y = move_toward(core_y, HANG_Y, (140.0 if ph == 2 else 220.0) * dt)

# ---------------------------------------------------------------- choosing (weighted, never the same twice in a row)
func _choose() -> void:
	if kit_keys().is_empty():
		idle_t = 0.3
		return
	var tgt := kit_pick_target()
	if combo != "":
		var c := combo
		combo = ""
		_start(c, tgt)
		return
	var ap := kit_aim(tgt)
	var far := absf(ap.x - core_px) > 120.0
	var opts: Array = []
	match ph:
		1:
			opts = [["fetch", 3.0], ["results", 2.0 + (2.0 if far else 0.0)], ["drop", 2.0 + (2.0 if not far else 0.0)]]
		2:
			opts = [["leap", 3.0], ["fetch", 2.0], ["results", 2.0 + (1.0 if far else 0.0)]]
		_:
			opts = [["flash", 3.0], ["feint", 2.0], ["results", 1.0], ["dflash", 1.0]]
	var tot := 0.0
	for o in opts:
		if String(o[0]) != last_id:
			tot += float(o[1])
	var r := room.rng.randf() * tot
	var pick := String(opts[0][0])
	for o in opts:
		if String(o[0]) == last_id:
			continue
		r -= float(o[1])
		if r <= 0.0:
			pick = String(o[0])
			break
	last_id = pick
	if pick == "drop":
		pend = "drop"
		pend_x = clampf(ap.x, 40.0, 344.0)
		pend_t = 0.9
		return
	if pick == "dflash":
		dbl = true
		pick = "flash"
	_start(pick, tgt)

func _start(id: String, tgt: String) -> void:
	var ap := kit_aim(tgt)
	match id:
		"fetch":
			leg_n = (1 + room.rng.randi() % 2) if ph == 1 else (2 + room.rng.randi() % 2)
			leg_i = 0
			_start_leg(tgt)
		"results":
			vol_n = 0
			scr = SCREENS.find("query")
			scr_t0 = room.time
			scr_q = room.rng.randi() % QUERIES.size()
			plan_start("results", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.5 if ph == 3 else 0.6, 0.5, 0.2 if ph == 1 else 0.7)
		"drop":
			arc_a = Vector2(core_px, core_y)
			var land := _ground_below(ap.x, ap.y) - BH / 2.0 - 2.0
			arc_b = Vector2(core_px, maxf(core_y + 20.0, land))
			plan_start("drop", "slam", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.7, 1.5, (arc_b.y - arc_a.y) / 520.0 + 0.05)
		"leap":
			arc_a = Vector2(core_px, core_y)
			arc_b = Vector2(clampf(ap.x, 40.0, 344.0), _ground_below(ap.x, ap.y) - BH / 2.0)
			plan_start("leap", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.25, 0.7, 1.5, 0.6)
		"flash":
			plan_start("flash", "guard", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.5, 0.1, 0.05)
		"dive":
			arc_a = Vector2(core_px, core_y)
			arc_b = ap
			plan_start("dive", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.2, DIVE_CUE, 1.0, 0.35)
		"feint":
			arc_a = Vector2(core_px, core_y)
			arc_b = ap
			plan_start("feint", "lunge", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, DIVE_CUE, 0.35, 0.05)
	if not plan.is_empty():
		Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _start_leg(tgt: String) -> void:
	var ap := kit_aim(tgt)
	leg_x = clampf(ap.x, 20.0, 364.0)
	leg_y = ap.y + 6.0
	leg_k = [1, 2, 5, 6][(leg_i + leg_n) % 4]
	var last := leg_i >= leg_n - 1
	plan_start("fetch", "slam", tgt, [0.0, 0.0, 0.0, 0.0], 0.2, 0.5 if leg_i == 0 else 0.4, 1.2 if last else 0.05, 0.2)

# the first floor under a point (a one-way top or a solid cell); the floor line when there is none (the pit: its spikes)
func _ground_below(px: float, py: float) -> float:
	var g = room.grid
	var tx := clampi(floori(px / 16.0), 1, g.w - 2)
	for ty in range(clampi(floori(py / 16.0), 0, g.h - 1), g.h):
		var t: int = g.tile(tx, ty)
		if t == TileGrid.SOLID or t == TileGrid.ONEWAY or t == TileGrid.SPIKE_U:
			return float(ty) * 16.0
	return FLOOR_Y

func _plan_logic(dt: float) -> void:
	var pid := String(plan.id)
	if plan.ph == "cue" and plan.t > float(plan.lock):          # the aim follows the target through the wind-up; fixed for the last `lock`
		var ap := kit_aim(plan.tgt)
		match pid:
			"fetch":
				leg_x = clampf(ap.x, 20.0, 364.0)
				leg_y = ap.y + 6.0
			"leap":
				arc_b = Vector2(clampf(ap.x, 40.0, 344.0), _ground_below(ap.x, ap.y) - BH / 2.0)
			"dive":
				arc_b = ap
	match pid:
		"drop":
			if plan.ph == "active":
				core_y = move_toward(core_y, arc_b.y, 520.0 * dt)
				low = true
			elif plan.ph == "recover":
				low = true
		"leap":
			if plan.ph == "cue":
				pass
			elif plan.ph == "active":
				var u := clampf(1.0 - float(plan.t) / 0.6, 0.0, 1.0)
				var p := arc_a.lerp(arc_b, u)
				p.y -= sin(u * PI) * 90.0
				core_px = p.x
				core_y = p.y
			else:
				low = true
		"dive", "feint":
			if plan.ph == "cue":                               # it comes closer: the eight lights grow
				var c := arc_a.lerp(arc_b, 0.3 * (1.0 - float(plan.t) / DIVE_CUE))
				core_px = c.x
				core_y = c.y
			elif plan.ph == "active" and pid == "dive":
				var u2 := clampf(1.0 - float(plan.t) / 0.35, 0.0, 1.0)
				var p2 := arc_a.lerp(arc_b, 0.3 + 0.7 * u2)
				core_px = p2.x
				core_y = clampf(p2.y, CEIL_Y + 20.0, FLOOR_Y - 10.0)
			elif plan.ph == "recover" and pid == "dive":
				low = true
		"results":
			if plan.ph == "active":
				vol_t -= dt
				var want := 2 if ph >= 2 else 1
				if vol_n < want and vol_t <= 0.0:
					vol_n += 1
					vol_t = 0.45
					_shoot_results()
	if dc == 1 and pid in ["results", "flash"]:
		var sp := dc_pos(room.time)
		core_px = sp.x
		core_y = sp.y
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"fetch":
					leg_on = 1
					strike_sid = Game.next_strike_id()
					room.shake(0.35)
					Audio.sfx("thud", {"vol": 0.8})
				"results":
					scr = SCREENS.find("results")
					vol_t = 0.0
				"drop":
					Audio.sfx("dash")
				"leap":
					Audio.sfx("jump")
				"flash":
					flash_t0 = room.time
					Audio.sfx("spark")
					room.flash_screen(0.35, "#ffffff")
					for k in kit_keys():                           # it remembers where everyone was: legs will strike there
						var q = kit_body(k)
						var ap2 := kit_aim(k)
						hz_add("stab", 0.65, [roundi(ap2.x), roundi(q.y + q.h if q != null else ap2.y + 6.0)])
				"dive":
					Audio.sfx("dash")
		"recover":
			strike_sid = 0
			match pid:
				"fetch":
					if leg_i >= leg_n - 1:
						leg_on = 2                                 # the last leg stays in the web: claw it
						leg_hits = 0
					else:
						leg_on = 0
				"drop":
					core_y = arc_b.y
					room.shake(0.6)
					Audio.sfx("thud")
					room.dust(core_px, core_y + BH / 2.0, 8)
				"leap":
					_land()
				"dive":
					room.shake(0.4)
					Audio.sfx("thud", {"vol": 0.7})
				"feint":
					# it pulls back into the dark and comes again from the other side
					core_px = clampf(float(room.pw) - core_px, 40.0, 344.0)
					arc_a = Vector2(core_px, core_y)
					combo = "dive"
	if ev == "done":
		strike_sid = 0
		if pid == "fetch" and leg_i < leg_n - 1:
			leg_i += 1
			leg_on = 0
			_start_leg(String(plan.tgt) if not plan.is_empty() else kit_pick_target())
			return
		leg_on = 0
		if pid == "results":
			scr = SCREENS.find("home") if ph < 3 else scr
		if pid == "flash":
			if dbl:
				dbl = false
				combo = "flash"
			else:
				combo = "dive"
		if pid in ["dive"] and dc == 1:
			_swing_from_here()
		idle_t = 0.35 if ph == 3 else (0.45 if ph == 2 else 0.6)
		if combo != "":
			idle_t = 0.15

func _land() -> void:
	var hl = _hall()
	core_px = arc_b.x
	core_y = arc_b.y
	room.shake(1.0)
	Audio.sfx("thud")
	room.dust(core_px, core_y + BH / 2.0, 12)
	var gy := core_y + BH / 2.0
	for d in [-1.0, 1.0]:
		room.shoot(core_px + d * 20.0, gy - 1.0, d * 140.0, 0.0, {"kind": "wave", "col": "#d6f6ff", "r": 4.0, "hgt": 9.0, "tile": false, "life": 1.0, "cut": false, "by_boss": true})
	if hl != null:
		if absf(gy - float(IndexHall.NET_ROW) * 16.0) < 6.0:   # it landed on the net: it tears
			var ci := floori(core_px / 16.0) - IndexHall.NET_C0
			for k in [ci - 1, ci, ci + 1]:
				if k >= 0 and k < IndexHall.NET_N:
					hl.net &= ~(1 << k)
			Audio.sfx("crumble")
		var zb := _zone_bit(core_px)
		if hl.zones & zb != 0:
			hl.zones &= ~zb                                 # a neon tube breaks: that quarter of the hall goes dark
			Audio.sfx("glitch", {"vol": 0.8})
		var best := -1
		var bd := 70.0
		for i in range(IndexHall.DRAWERS.size()):
			var r: Rect2 = hl.drawer_rect(i)
			var dd := Vector2(r.get_center()).distance_to(Vector2(core_px, core_y))
			if (hl.drawers >> i) & 1 == 1 and dd < bd:
				bd = dd
				best = i
		if best >= 0:
			_drop_drawer(best)

# results: four blue links and one yellow (catch it back into its screen)
func _shoot_results() -> void:
	var ap := kit_aim(plan.tgt)
	var ox := core_px
	var oy := core_y - 6.0
	var a0 := atan2(ap.y - oy, ap.x - ox)
	var n := 5
	var gold := room.rng.randi() % n
	var speed := 150.0 if ph < 3 else 175.0
	for i in range(n):
		var a := a0 + (float(i) - 2.0) * 0.2
		if i == gold:
			room.shoot(ox, oy, cos(a) * speed, sin(a) * speed, {"kind": "diamond", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1, "by_boss": true})
		else:
			room.shoot(ox, oy, cos(a) * speed, sin(a) * speed, {"kind": "link", "col": "#3f6fd0", "r": 3.0, "cut": true, "life": 3.0, "dmg": 1, "by_boss": true})
	Audio.sfx("shoot")

# ---------------------------------------------------------------- the swing of phase 3 (a pure function of the clock and the fields)
func _swing_from_here() -> void:
	sw_t0 = snappedf(room.time, 0.01)
	sw_x0 = core_px
	sw_y0 = core_y

func pend_angle(now: float) -> float:
	return SW_AMP * sin(TAU * (now - sw_t0) / SW_T)

func pend_pos(now: float) -> Vector2:
	var a := pend_angle(now)
	return PIVOT + Vector2(sin(a), cos(a)) * SW_LEN

func dc_pos(now: float) -> Vector2:
	var k := clampf((now - sw_t0) / 1.0, 0.0, 1.0)
	return Vector2(sw_x0, sw_y0).lerp(pend_pos(now), k * k * (3.0 - 2.0 * k))

# ---------------------------------------------------------------- the legs (cosmetic: each page its own)
func _hip(i: int) -> Vector2:
	var s := -1.0 if i < 4 else 1.0
	var k := i % 4
	return Vector2(core_px + s * (8.0 + float(k) * 3.0), core_y - 2.0 + float(k) * 3.0)

func _ideal_foot(i: int) -> Vector2:
	var s := -1.0 if i < 4 else 1.0
	var k := i % 4
	var reach := 46.0 + float(k) * 20.0
	var up := core_y < 150.0 and not low
	var fx := core_px + s * reach
	var fy: float
	if up:
		fy = CEIL_Y if k < 3 else core_y + 30.0             # hanging: three pairs on the ceiling, the last pair hangs free
	else:
		fy = minf(_ground_below(fx, core_y) if room.grid != null else FLOOR_Y, FLOOR_Y)
		if k == 0:
			fy = core_y - 40.0
	return Vector2(clampf(fx, 16.0, float(room.pw) - 16.0), clampf(fy, CEIL_Y, FLOOR_Y))

func _feet_step(dt: float) -> void:
	for i in range(feet.size()):
		var f: Dictionary = feet[i]
		if float(f.t) > 0.0:
			f.t = maxf(0.0, float(f.t) - dt)
			var u := 1.0 - float(f.t) / 0.12
			f.p = Vector2(f.from).lerp(Vector2(f.to), u) + Vector2(0.0, -sin(u * PI) * 8.0)
			if float(f.t) <= 0.0 and room.is_local:
				Audio.local_sfx("tick", 0.25)                  # a key of an old keyboard
			continue
		var ideal := _ideal_foot(i)
		if Vector2(f.p).distance_to(ideal) > 28.0:
			f.from = f.p
			f.to = ideal
			f.t = 0.12

# ---------------------------------------------------------------- drawing
func _process(_dt: float) -> void:
	super._process(_dt)
	if flash <= 0.0:
		body.material = null                                   # the body is lit by the room's lights (it is dark in the dark); the overlay glows
	dark_k = Game.damp(dark_k, room.hall.dark if room.hall != null else 0.0, 3.0, _dt)

func _leg_points(i: int) -> Array:
	var hip := _hip(i)
	var foot: Vector2 = feet[i].p
	if i == 6 and legs_ok < 8:                                 # the broken one dangles
		foot = hip + Vector2(10.0 + sin(t * 3.0) * 3.0, 24.0)
	if i == leg_k and plan_phase() == "cue" and not plan.is_empty() and String(plan.id) == "fetch":
		foot = hip + Vector2((-1.0 if i < 4 else 1.0) * 14.0, -26.0)     # drawn back before the strike
	elif i == leg_k and leg_on > 0:
		foot = Vector2(leg_x, leg_y)
	var d := foot - hip
	var up := Vector2(0.0, -1.0)
	var k1 := hip + d * 0.33 + up * (16.0 + d.length() * 0.12)
	var k2 := hip + d * 0.7 + up * (6.0 + d.length() * 0.05)
	return [hip, k1, k2, foot]

func draw_boss_body(ci: CanvasItem) -> void:
	if gone:
		return
	var ink := Color(INK)
	# the legs: three segments of old cable
	for i in range(8):
		var pts: Array = _leg_points(i)
		for s in range(3):
			ci.draw_line(pts[s], pts[s + 1], ink, 4.0)
		var cc := Color(CABLES[i])
		for s in range(3):
			ci.draw_line(pts[s], pts[s + 1], cc, 2.0)
		ci.draw_rect(Rect2(Vector2(pts[3]) - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("#4a4f5a"))          # the plug at the tip
	var cx_ := floorf(core_px)
	var cy_ := floorf(core_y)
	var crouch := 0.0
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) in ["leap", "drop"]:
		crouch = 4.0
	# the case: yellowed beige, stickers, a dangling cable
	var case_r := Rect2(cx_ - 17.0, cy_ - 1.0 + crouch, 34.0, 15.0)
	ci.draw_rect(case_r.grow(1.0), ink)
	ci.draw_rect(case_r, Color(BEIGE))
	ci.draw_rect(Rect2(case_r.position.x, case_r.position.y + 12.0, case_r.size.x, 3.0), Color("#8f7f5a"))
	ci.draw_rect(Rect2(case_r.position.x + 3.0, case_r.position.y + 3.0, 9.0, 4.0), Color("#efe6c8"))        # "Under Construction"
	ci.draw_rect(Rect2(case_r.position.x + 4.0, case_r.position.y + 4.0, 7.0, 2.0), Color("#e0b23a"))
	ci.draw_rect(Rect2(case_r.position.x + 22.0, case_r.position.y + 4.0, 9.0, 2.0), Color("#5a5040"))       # the drive bay
	if legs_ok < 8:
		ci.draw_rect(Rect2(case_r.position.x + 28.0, case_r.position.y + 7.0, 4.0, 6.0), Color("#2a2420"))  # the crack
	ci.draw_line(Vector2(cx_ - 6.0, case_r.end.y), Vector2(cx_ - 4.0 + sin(t * 2.0) * 2.0, case_r.end.y + 9.0), Color("#6a6f7a"), 1.0)
	# the monitor (the picture itself is in the overlay: it glows)
	var mon := Rect2(cx_ - 14.0, cy_ - 17.0 + crouch, 28.0, 20.0)
	ci.draw_rect(mon.grow(1.0), ink)
	ci.draw_rect(mon, Color("#d8cba3"))
	ci.draw_rect(Rect2(mon.position.x, mon.end.y - 3.0, mon.size.x, 3.0), Color("#a89a74"))

func draw_boss_overlay(ci: CanvasItem) -> void:
	if gone:
		return
	var cx_ := floorf(core_px)
	var cy_ := floorf(core_y)
	var crouch := 0.0
	if not plan.is_empty() and plan.ph == "cue" and String(plan.id) in ["leap", "drop"]:
		crouch = 4.0
	# the LEDs at the leg tips: dim at rest, bright on the leg about to strike; off in the last 15 %; brighter as it comes at you in a dive
	var leds_off := lights_out() and not dying
	if not leds_off:
		for i in range(8):
			if i == 6 and legs_ok < 8:
				continue
			var pts: Array = _leg_points(i)
			var tip: Vector2 = pts[3]
			var hot := 0.45
			if i == leg_k and leg_on > 0:
				hot = 1.0
			if i == leg_k and not plan.is_empty() and String(plan.id) == "fetch" and plan.ph == "cue":
				hot = 1.0
			if not plan.is_empty() and String(plan.id) in ["dive", "feint"] and plan.ph == "cue":
				hot = 0.6 + 0.4 * (1.0 - float(plan.t) / DIVE_CUE)
			if not plan.is_empty() and String(plan.id) == "feint" and plan.ph == "recover":
				hot = 0.0
			var r := 1.0 + hot * 1.5
			ci.draw_rect(Rect2(tip.x - r, tip.y - r, r * 2.0, r * 2.0), Color(1.0, 0.23, 0.3, 0.35 + hot * 0.65))
	# the screen: its homepage, small; the text cursor is its eye
	var scr_r := Rect2(cx_ - 11.0, cy_ - 15.0 + crouch, 22.0, 14.0)
	var glow := 1.0 if not leds_off else 0.55
	var face := Color("#dfe6da") * Color(glow, glow, glow, 1.0)
	if ph >= 2 or shift_k == 2:
		face = Color("#ffcf9a") * Color(glow, glow, glow, 1.0)
	if ph == 3 and int(t * 25.0) % 7 == 0:
		face = Color("#9aa09a")                               # static
	ci.draw_rect(scr_r, face)
	for k in range(4):
		ci.draw_rect(Rect2(scr_r.position.x + 3.0 + k * 4.0, scr_r.position.y + 2.0, 3.0, 2.0), Color(["#3a6ff0", "#e8463a", "#f2c12e", "#2fa84f"][k]))
	ci.draw_rect(Rect2(scr_r.position.x + 2.0, scr_r.position.y + 6.0, 18.0, 5.0), Color("#ffffff"))
	ci.draw_rect(Rect2(scr_r.position.x + 2.0, scr_r.position.y + 6.0, 18.0, 1.0), Color("#7d8a96"))
	var dazed: bool = down_t > 0.0 or low and not plan.is_empty() and plan.ph == "recover"
	if dazed:                                                   # an hourglass instead of the cursor
		var hx := scr_r.position.x + 10.0
		var hy := scr_r.position.y + 6.0
		ci.draw_rect(Rect2(hx, hy, 3.0, 1.0), Color("#222222"))
		ci.draw_rect(Rect2(hx + 1.0, hy + 1.0, 1.0, 3.0), Color("#c08a2a"))
		ci.draw_rect(Rect2(hx, hy + 4.0, 3.0, 1.0), Color("#222222"))
	else:
		var winding: bool = not plan.is_empty() and plan.ph == "cue"
		var cw := 2.0 if winding else 1.0
		var cur_col := Color("#222222")
		if ph >= 2 or winding:
			cur_col = Color(RED)
		var blink := 2.5 if not winding else 9.0
		if int(t * blink) % 2 == 0 or winding:
			ci.draw_rect(Rect2(scr_r.position.x + 4.0, scr_r.position.y + 7.0, cw, 3.0), cur_col)
	# sparks from the broken joint
	if legs_ok < 8 and int(t * 6.0) % 3 == 0:
		var hp6 := _hip(6)
		ci.draw_rect(Rect2(hp6.x + sin(t * 40.0) * 3.0, hp6.y + 2.0, 1.0, 1.0), Color("#ffd23f"))
	# the small crawlers on the strands (hazards): a faint glow each
	for h in hz:
		if h.k == "ling":
			var lp := ling_pos(h, room.time)
			var a := 0.4 if not hz_live(h, room.time) else 1.0
			ci.draw_rect(Rect2(lp.x - 4.0, lp.y - 3.0, 8.0, 5.0), Color(0.1, 0.08, 0.14, a))
			ci.draw_rect(Rect2(lp.x - 2.0, lp.y - 2.0, 4.0, 2.0), Color(0.85, 0.8, 0.6, a))
			ci.draw_rect(Rect2(lp.x - 1.0, lp.y - 2.0, 1.0, 1.0), Color(1.0, 0.25, 0.3, a))
			for s in [-1.0, 1.0]:
				ci.draw_line(Vector2(lp.x + s * 3.0, lp.y), Vector2(lp.x + s * 6.0, lp.y + 3.0 + sin(t * 20.0 + s) * 1.0), Color(0.6, 0.6, 0.65, a), 1.0)
		elif h.k == "drawer" and hz_live(h, room.time) and room.hall != null:          # the drawer falling
			var since := room.time - float(h.t0) - float(h.warn)
			var r: Rect2 = room.hall.drawer_rect(int(h.v[0]))
			var yy := r.position.y + since * 320.0
			ci.draw_rect(Rect2(r.position.x, yy, r.size.x, 11.0), Color(BEIGE))
			ci.draw_rect(Rect2(r.position.x, yy + 9.0, r.size.x, 2.0), Color("#8f7f5a"))

# ---------------------------------------------------------------- net
func net_fields() -> Array:
	var hl = _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, strike_sid, roundi(core_px), roundi(core_y), ph, shift_k, roundi(shift_t * 100.0),
		legs_ok, roundi(leg_x), roundi(leg_y), leg_on, leg_k, 1 if (down_t > 0.0 or low) else 0, dc, roundi(sw_t0 * 100.0), roundi(sw_x0), roundi(sw_y0),
		roundi(flash_t0 * 100.0), hl.net if hl != null else 0, hl.drawers if hl != null else 0, hl.strands if hl != null else 0, hl.zones if hl != null else 0,
		scr, roundi(scr_t0 * 100.0), scr_q, roundi(arc_a.x), roundi(arc_a.y), roundi(arc_b.x), roundi(arc_b.y)]
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 32

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	dying = int(f[3]) == 1
	strike_sid = int(f[4])
	core_px = float(f[5])
	core_y = float(f[6])
	ph = int(f[7])
	phase = ph
	shift_k = int(f[8])
	shift_t = f[9] / 100.0
	legs_ok = int(f[10])
	leg_x = float(f[11])
	leg_y = float(f[12])
	leg_on = int(f[13])
	leg_k = int(f[14])
	low = int(f[15]) == 1
	down_t = 0.5 if low else 0.0
	dc = int(f[16])
	sw_t0 = f[17] / 100.0
	sw_x0 = float(f[18])
	sw_y0 = float(f[19])
	var was_flash := flash_t0
	flash_t0 = f[20] / 100.0
	if flash_t0 > was_flash + 0.05 and room.time - flash_t0 < 0.5:
		room.flash_screen(0.35, "#ffffff")                    # (the host's flash: this page shows it too)
	var hl = _hall()
	if hl != null:
		hl.net = int(f[21])
		hl.drawers = int(f[22])
		hl.strands = int(f[23])
		hl.zones = int(f[24])
	scr = int(f[25])
	scr_t0 = f[26] / 100.0
	scr_q = int(f[27])
	arc_a = Vector2(float(f[28]), float(f[29]))
	arc_b = Vector2(float(f[30]), float(f[31]))
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])
	if dc == 1 and active and not dying and plan.is_empty():
		var p := dc_pos(room.time)
		core_px = p.x
		core_y = p.y
	_sync_hall()
	_place()

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
	_feet_step(dt)
	if dc == 1 and active and not dying and plan.is_empty():
		var p := dc_pos(room.time)
		core_px = p.x
		core_y = p.y
		_place()
	_sync_hall()
