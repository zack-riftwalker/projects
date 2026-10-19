class_name FirewallBoss
extends Boss
# THE FIREWALL (docs/metroidvania/16-firewall.md, 16-firewall-build.md): a honeypot. M2 of the build: the exit door and phase 1, the friendly shell
# (GUEST SERVICES). The door never moves and has no contact damage; the lobby's things attack (cookies from the reception tray, hold-music notes, a carpet
# wave, a flame from the door's crack) and anything Clawd rests on for 2 s bites. Every tell is drawn on the body or the room, no markers.
# The arena (HoneypotHall) is owned by the room; the net fields carry its masks and the packets' clock, so the guest builds the same arena as the host.
# Bar 1 is the shell's: it shows hp from 100 % to 70 %. Phase 2 (the fake victory, the furnace) comes with M3: until then the shell holds at 70 %.

const IDS := ["cookies", "hold", "mat", "crack"]
const FIRST := ["cookies", "mat", "hold", "crack"]       # the first cycle is a fixed teaching order
const GREEN := "#57ff8a"                                 # the honeypot's warm voice
const COLD := "#ff9a8a"
const INK := "#1b1226"
const DOOR := Rect2(304.0, 80.0, 64.0, 96.0)             # the door on the east wall, cols 19-22, rows 5-10
const SCREEN := Rect2(326.0, 93.0, 20.0, 14.0)           # its small smiling screen (a caught cookie that hits it dazes the shell)
const SPEAKER := Vector2(336.0, 72.0)                    # the hold music
const TRAY := Vector2(177.0, 122.0)                      # the reception tray (the hall draws it on the desk)
const SHELL_END := 0.70                                  # bar 1 ends at 70 % of the hp
const INTRO_LONG := 6.0
const INTRO_SHORT := 2.5
const SAY_LINES := {1: "intro"}
const LINE_TEXT := {"intro": "Welcome! You're safe here. The exit is just this way."}
const LINE_LEN := {"intro": 4.6}                         # (a stand-in until the voice files exist: their real lengths come with M5)
const CRACK_CUE := 0.8
const MAT_ACT := 1.7
const MAT_X0 := 280.0                                    # the wave's box (24 wide) starts at the door and runs west
const NOTE_SPEED := 40.0
const NOTE_LIFE := 6.0
const NOTE_N := 4
const BITE_AFTER := 2.0
const BITE_REST := 3.0

var ph := 1
var idle_t := 0.8
var last_id := ""
var cyc := 0                       # attacks started in this phase (the first four are the fixed order)
var daze_t := 0.0                  # a caught cookie hit the screen: no attacks, a spinning loading icon
var intro_t0 := -1.0
var clicked := false
var say_k := 0
var say_t0 := 0.0
var notes_left := 0                # host: notes still to leave the speaker in this `hold`
var note_t := 0.0
var note_i := 0
var note_aim := Vector2.ZERO       # where the target was at the cue: the notes drift that way
var bite_t := {}                   # host: player key -> [piece, seconds on it]
var bite_rest := [0.0, 0.0, 0.0]   # host: room time each piece may bite again
var skipping := false

func _init(r: Room, bx: float, by: float, base_hp := 82) -> void:
	super(r, bx, by, 64, 96, base_hp)
	boss_name = "GUEST SERVICES"
	sub = "welcome, guest"
	col = GREEN
	face = -1.0
	x = DOOR.position.x
	y = DOOR.position.y
	kit_init()

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["note", "bite", "heat", "wave", "pdrop", "dropall"]

func _big() -> int:
	return int(Game.dv("big_hit"))

func _hall() -> HoneypotHall:
	return room.hpot

func _floor_hp() -> float:
	return float(max_hp) * SHELL_END

# ---------------------------------------------------------------- the bar (the HUD asks every boss that has one)
# bar 1: the shell, green, from 100 % to 70 % of the hp
func hud_bar() -> Array:
	var f := clampf((hpf - _floor_hp()) / (float(max_hp) - _floor_hp()), 0.0, 1.0)
	return [f, GREEN, "GUEST SERVICES"]

# ---------------------------------------------------------------- boxes
func hurtboxes() -> Array:
	var b: Array = []
	if not active or dying:
		return [{"x": DOOR.position.x, "y": DOOR.position.y, "w": DOOR.size.x, "h": DOOR.size.y}]
	b.append({"x": SCREEN.position.x, "y": SCREEN.position.y, "w": SCREEN.size.x, "h": SCREEN.size.y, "screen": 1})      # (first: a caught cookie finds the screen before the door)
	b.append({"x": DOOR.position.x, "y": DOOR.position.y, "w": DOOR.size.x, "h": DOOR.size.y})
	for h in hz:
		if h.k == "note" and hz_live(h, room.time):
			var p := note_pos(h, room.time)
			b.append({"x": p.x - 5.0, "y": p.y - 5.0, "w": 10.0, "h": 10.0, "note": hz_key(h)})
	return b

# no contact damage: it is a door
func harmboxes() -> Array:
	var b: Array = []
	if active and not dying:
		if plan_active() and String(plan.id) == "mat":
			var u := float(plan.get("act", MAT_ACT)) - float(plan.t)
			b.append({"x": MAT_X0 - u * 160.0, "y": HoneypotHall.FLOOR_Y - 12.0, "w": 24.0, "h": 12.0, "dmg": 1})
		if plan_active() and String(plan.id) == "crack":
			b.append({"x": 208.0, "y": 144.0, "w": 96.0, "h": 32.0, "dmg": _big()})
	b.append_array(hz_harm())
	return b

# ---------------------------------------------------------------- hazards: pure functions of their fields and the room time
# a note leaves the speaker towards where its target was, with a small wobble
func note_pos(h: Dictionary, now: float) -> Vector2:
	var since := maxf(0.0, now - float(h.t0) - float(h.warn))
	var aim := Vector2(float(h.v[0]), float(h.v[1]))
	var dir := (aim - SPEAKER).normalized()
	var perp := Vector2(-dir.y, dir.x)
	return SPEAKER + dir * NOTE_SPEED * since + perp * sin(TAU * 1.5 * since + float(h.v[2]) * 1.7) * 8.0

func piece_rect(pi: int) -> Rect2:
	var p: Array = HoneypotHall.PIECES[clampi(pi, 0, 2)]
	return Rect2(float(int(p[0]) * 16), float(int(p[1]) * 16), float(int(p[2]) * 16), 10.0)

func hz_boxes(h: Dictionary, now: float) -> Array:
	var since := now - float(h.t0) - float(h.warn)
	match String(h.k):
		"note":
			var p := note_pos(h, now)
			return [{"x": p.x - 4.0, "y": p.y - 3.0, "w": 8.0, "h": 6.0, "dmg": 1}]
		"bite":
			if since < 0.2:
				var r := piece_rect(int(h.v[0]))
				return [{"x": r.position.x, "y": r.position.y - 10.0, "w": r.size.x, "h": 10.0, "dmg": 1}]
	return []

func _hz_expire() -> void:
	var now := room.time
	for h in hz.duplicate():
		var since := now - float(h.t0) - float(h.warn)
		match String(h.k):
			"note":
				var p := note_pos(h, now)
				if since > NOTE_LIFE or p.x < 16.0 or p.x > 368.0 or p.y < 16.0 or p.y > 176.0:
					hz.erase(h)
			"bite":
				if since > 0.3:
					hz.erase(h)

# ---------------------------------------------------------------- hits
func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if not active or dying:
		return ""
	if b is Dictionary and b.has("note"):
		for h in hz.duplicate():
			if hz_key(h) == String(b.note):
				var p := note_pos(h, room.time)
				room.burst(p.x, p.y, 5, ["#fff3b0", GREEN], 80.0, 160.0)
				hz.erase(h)
		Audio.sfx("squish", {"vol": 0.6})
		return "kill"
	if how == "catch":                                               # a cookie thrown back at it (it was steered at the screen): the shell is dazed
		daze_t = 1.5
		plan_cut()
		room.burst(SCREEN.get_center().x, SCREEN.get_center().y, 8, ["#ffd23f", "#ffffff"], 90.0, 100.0)
	if d >= 9999:
		skipping = true                                           # (the pause menu's skip button: it ends the fight at once)
	return super.hit(d, dx, dy, how, b)

# the shell holds at 70 % until phase 2 exists (M3); a skip goes through
func on_damage() -> void:
	if skipping or ph != 1:
		return
	if hpf < _floor_hp():
		hpf = _floor_hp()
		hp = ceili(hpf)

func start() -> void:
	super.start()
	idle_t = 0.8
	cyc = 0
	last_id = ""
	Game.flags["intro:FIREWALL"] = true                          # the long intro only once
	var hl := _hall()
	if hl != null and room.mode != "guest":
		hl.seed = room.rng.randi() % 1000000                     # the fight's seed: which packets get inspected (phase 2)

func intro_len() -> float:
	return INTRO_SHORT if Game.flag("intro:FIREWALL") else INTRO_LONG

# ---------------------------------------------------------------- the intro: the door closes behind you, the screen smiles, the shell welcomes you
func _step_intro(_dt: float) -> void:
	if intro_t0 < 0.0:
		intro_t0 = room.time
		clicked = false
	var it := room.time - intro_t0
	if it >= 0.3 and not clicked:
		clicked = true
		Audio.sfx("gate", {"vol": 0.3})                          # the west door closes with a soft click
	if it >= 0.8 and say_k == 0:
		_say(1)

func _say(k: int) -> void:
	say_k = k
	say_t0 = room.time                                           # (the voice itself comes with M5; the subtitle runs on say_t0 on both pages)

func say_len(k: int) -> float:
	return float(LINE_LEN.get(String(SAY_LINES.get(k, "intro")), 4.0)) + 0.6

# placeholders until the firewall has its own music: the friendly first-world theme (the honeypot plays what feels safe)
func music_now(_want: String) -> String:
	if dying:
		return ""
	return "w1"

# ---------------------------------------------------------------- the fight
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	if dying:
		hz.clear()
		death_rattle(dt, 1.0, ["#ffffff", GREEN, "#2e9a52"])
		return
	if not active:
		if room.fight.state == "intro":
			_step_intro(dt)
		return
	_hz_expire()
	daze_t = maxf(0.0, daze_t - dt)
	_steer_cookies()
	_pressure(dt)
	if plan.is_empty():
		plan_clock += dt
		idle_t -= dt
		if idle_t <= 0.0 and daze_t <= 0.0:
			_choose()
	else:
		_plan_logic(dt)

# a caught cookie flies back at the screen (the lob it was thrown with would not find it)
func _steer_cookies() -> void:
	for q in room.projs:
		if q.dead or not q.get("friendly", false) or not q.get("cookie", false) or q.get("steered", false):
			continue
		var sp := maxf(Vector2(float(q.vx), float(q.vy)).length(), 260.0)          # (a cookie at the top of its lob is slow: it still has to arrive)
		var dir := (SCREEN.get_center() - Vector2(float(q.x), float(q.y))).normalized()
		q.vx = dir.x * sp
		q.vy = dir.y * sp
		q.g = 0.0
		q["steered"] = true

func _choose() -> void:
	if kit_keys().is_empty():
		idle_t = 0.3
		return
	var tgt := kit_pick_target()
	var pick := ""
	if cyc < FIRST.size():
		pick = FIRST[cyc]
	else:
		var q = kit_body(tgt)
		var on_floor: bool = q != null and q.y + q.h >= HoneypotHall.FLOOR_Y - 2.0
		var ap := kit_aim(tgt)
		var near_door: bool = ap.x > DOOR.position.x - 96.0
		var opts: Array = [["cookies", 3.0], ["hold", 2.0 if _notes_alive() < 2 else 0.0], ["mat", 2.0 + (2.0 if on_floor else 0.0)], ["crack", 2.0 + (2.0 if near_door else 0.0)]]
		var tot := 0.0
		for o in opts:
			if String(o[0]) != last_id:
				tot += float(o[1])
		var r := room.rng.randf() * tot
		pick = String(opts[0][0])
		for o in opts:
			if String(o[0]) == last_id or float(o[1]) <= 0.0:
				continue
			r -= float(o[1])
			if r <= 0.0:
				pick = String(o[0])
				break
	cyc += 1
	last_id = pick
	_start(pick, tgt)

func _notes_alive() -> int:
	var n := 0
	for h in hz:
		if h.k == "note":
			n += 1
	return n

func _start(id: String, tgt: String) -> void:
	match id:
		"cookies":
			plan_start("cookies", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, 0.5, 0.2)
			Audio.sfx("uiOk", {"vol": 0.6})                          # the ding (a stand-in until the sounds exist)
		"hold":
			note_aim = kit_aim(tgt)
			plan_start("hold", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.7, 0.6, 0.3 * float(NOTE_N - 1) + 0.1)
			Audio.sfx("chirp", {"vol": 0.6})
		"mat":
			plan_start("mat", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, 0.6, 0.5, MAT_ACT)
			Audio.sfx("tick", {"vol": 0.6})
		"crack":
			plan_start("crack", "slam", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, CRACK_CUE, 1.0, 0.35)
			Audio.sfx("gate", {"vol": 0.5})                          # the hinge creaks
	if not plan.is_empty():
		Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _plan_logic(dt: float) -> void:
	var pid := String(plan.id)
	if pid == "hold" and plan.ph == "active" and notes_left > 0:
		note_t -= dt
		if note_t <= 0.0:
			note_t = 0.3
			notes_left -= 1
			hz_add("note", 0.6, [roundi(note_aim.x), roundi(note_aim.y), note_i])
			note_i += 1
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"cookies":
					_throw_cookies()
				"hold":
					notes_left = NOTE_N
					note_i = 0
					note_t = 0.0
				"mat":
					Audio.sfx("dash", {"vol": 0.5})
				"crack":
					room.shake(0.3)
					Audio.sfx("roar", {"vol": 0.5})
	if ev == "done":
		idle_t = 0.35 + room.rng.randf() * 0.15
		notes_left = 0

# three cookies in arcs towards where the target stands; one of them is gold (catch it and throw it back at the screen)
func _throw_cookies() -> void:
	var ap := kit_aim(plan.tgt)
	var gold := room.rng.randi() % 3
	var g := 300.0
	for i in range(3):
		var tt := 0.8 + 0.1 * float(i)
		var tx := ap.x + (float(i) - 1.0) * 28.0
		var vx := (tx - TRAY.x) / tt
		var vy := (ap.y - TRAY.y - 0.5 * g * tt * tt) / tt
		var o := {"g": g, "r": 4.0, "life": 3.0, "dmg": 1, "by_boss": true, "cookie": true, "tile": true}
		if i == gold:
			o.merge({"kind": "diamond", "col": "#ffd23f", "catchable": true, "cut": true})
		else:
			o.merge({"kind": "orb", "col": "#c98a4a", "cut": true})
		room.shoot(TRAY.x, TRAY.y, vx, vy, o)
	Audio.sfx("shoot", {"vol": 0.7})

# "don't get comfortable": whatever Clawd rests on for 2 s bites (the sofa, the desk, the shelf)
func _pressure(dt: float) -> void:
	var hl := _hall()
	if hl == null or hl.stage != 0:
		return
	for key in kit_keys():
		var q = kit_body(key)
		if q == null or q.dead:
			bite_t.erase(key)
			continue
		var pi := _piece_under(q, hl)
		if pi < 0 or room.time < float(bite_rest[pi]):
			bite_t.erase(key)
			continue
		var cur: Array = bite_t.get(key, [pi, 0.0])
		if int(cur[0]) != pi:
			cur = [pi, 0.0]
		cur[1] = float(cur[1]) + dt
		bite_t[key] = cur
		if float(cur[1]) >= BITE_AFTER:
			hz_add("bite", 0.6, [pi])
			bite_rest[pi] = room.time + 0.6 + 0.2 + BITE_REST
			Audio.sfx("tick", {"vol": 0.5})
			for k2 in bite_t.keys():
				if int(bite_t[k2][0]) == pi:
					bite_t.erase(k2)

func _piece_under(q, hl: HoneypotHall) -> int:
	var feet: float = q.y + q.h
	for pi in range(3):
		if (hl.furniture >> pi) & 1 == 0:
			continue
		var r := piece_rect(pi)
		if q.x + q.w > r.position.x and q.x < r.end.x and absf(feet - r.position.y) <= 2.5:
			return pi
	return -1

# ---------------------------------------------------------------- drawing
# how far the door's crack is open (0..1), from the plan alone: it opens through the cue, stays open while the flame is out and while it recovers, then shuts
func crack_open() -> float:
	if plan.is_empty() or String(plan.id) != "crack":
		return 0.0
	match String(plan.ph):
		"cue":
			var tot: float = CRACK_CUE * _tm()
			return clampf(1.0 - float(plan.t) / maxf(tot, 0.01), 0.0, 1.0)
		"active":
			return 1.0
		_:
			return clampf(float(plan.t) / 0.25, 0.0, 1.0)

func draw_boss_body(ci: CanvasItem) -> void:
	if gone:
		return
	var now := room.time
	var d := DOOR
	var a := crack_open()
	var gap := 12.0 * a
	ci.draw_rect(Rect2(d.position.x - 3.0, d.position.y - 3.0, d.size.x + 6.0, d.size.y + 3.0), Color("#0f2e1c"))      # the frame
	ci.draw_rect(Rect2(d.position.x - 2.0, d.position.y - 2.0, d.size.x + 4.0, d.size.y + 2.0), Color("#1d5a38"))
	if gap > 0.5:                                                    # the crack: white at first, then red; a lit strip of the room behind the door
		var lit := Color("#ffffff").lerp(Color("#ff3b2a"), clampf(a * 1.4 - 0.2, 0.0, 1.0))
		ci.draw_rect(Rect2(d.position.x, d.position.y, gap, d.size.y), lit)
		ci.draw_rect(Rect2(d.position.x, d.position.y, gap, 2.0), Color("#ffe8e0"))
	var lx := d.position.x + gap                                    # the leaf swings away from the left edge
	var lw := d.size.x - gap
	ci.draw_rect(Rect2(lx, d.position.y, lw, d.size.y), Color("#2e9a52"))
	ci.draw_rect(Rect2(lx + 5.0, d.position.y + 8.0, lw - 10.0, d.size.y - 8.0), Color("#3fbf68"))
	ci.draw_rect(Rect2(lx + 5.0, d.position.y + 8.0, lw - 10.0, 2.0), Color("#7affa0"))
	ci.draw_rect(Rect2(lx, d.position.y, lw, 1.0), Color("#7affa0"))
	var ex := lx + lw / 2.0                                         # the EXIT lamp
	ci.draw_rect(Rect2(ex - 13.0, d.position.y + 1.0, 26.0, 7.0), Color("#103a22"))
	PixelText.draw_text(ci, "EXIT", ex, d.position.y + 2.0, "#e8ffee", {"align": "c", "tiny": true})
	ci.draw_rect(Rect2(lx + 6.0, d.position.y + 56.0, 2.0, 8.0), Color("#c8f0d4"))      # the bar handle
	# the fake LED row: requests remaining: unlimited (there is no rate limit in the shell)
	PixelText.draw_text(ci, "requests", ex, d.position.y + 66.0, "#7affa0", {"align": "c", "tiny": true})
	PixelText.draw_text(ci, "remaining: ∞", ex, d.position.y + 73.0, "#7affa0", {"align": "c", "tiny": true})
	# the screen on the frame: a smiling face, a wide grin before the cookies, a spinning loading icon when dazed
	var sr := Rect2(SCREEN.position.x + (gap * 0.0), SCREEN.position.y, SCREEN.size.x, SCREEN.size.y)
	ci.draw_rect(Rect2(sr.position.x - 1.0, sr.position.y - 1.0, sr.size.x + 2.0, sr.size.y + 2.0), Color("#0f2e1c"))
	ci.draw_rect(sr, Color("#0a1a10"))
	if daze_t > 0.0:
		var c := sr.get_center()
		for i in range(8):
			var ang := TAU * float(i) / 8.0 - now * 6.0
			var al := 0.25 + 0.75 * float(i) / 8.0
			ci.draw_rect(Rect2(c.x + cos(ang) * 4.5 - 0.5, c.y + sin(ang) * 4.5 - 0.5, 1.5, 1.5), Color(0.5, 1.0, 0.6, al))
	else:
		var wide: bool = plan_phase() == "cue" and String(plan.id) == "cookies"
		var g := Color(GREEN)
		ci.draw_rect(Rect2(sr.position.x + 5.0, sr.position.y + 3.0, 2.0, 2.0), g)
		ci.draw_rect(Rect2(sr.position.x + 13.0, sr.position.y + 3.0, 2.0, 2.0), g)
		if wide:                                                     # the smile widens
			ci.draw_rect(Rect2(sr.position.x + 4.0, sr.position.y + 7.0, 12.0, 1.0), g)
			ci.draw_rect(Rect2(sr.position.x + 5.0, sr.position.y + 8.0, 10.0, 3.0), Color("#e8ffee"))
			ci.draw_rect(Rect2(sr.position.x + 10.0, sr.position.y + 8.0, 1.0, 3.0), Color("#0a1a10"))
		else:
			ci.draw_rect(Rect2(sr.position.x + 6.0, sr.position.y + 9.0, 8.0, 1.0), g)
			ci.draw_rect(Rect2(sr.position.x + 5.0, sr.position.y + 8.0, 1.0, 1.0), g)
			ci.draw_rect(Rect2(sr.position.x + 14.0, sr.position.y + 8.0, 1.0, 1.0), g)
	# the speaker over the door
	var sp := SPEAKER
	ci.draw_rect(Rect2(sp.x - 8.0, sp.y - 5.0, 16.0, 10.0), Color("#1a1a22"))
	ci.draw_rect(Rect2(sp.x - 7.0, sp.y - 4.0, 14.0, 8.0), Color("#3a3a46"))
	ci.draw_circle(sp, 3.0, Color("#15151b"))
	if plan_phase() == "cue" and String(plan.id) == "hold":
		ci.draw_circle(sp, 3.0, Color("#ffe27a"))                    # it lights up
		ci.draw_arc(sp, 6.0 + fposmod(now * 14.0, 6.0), -1.2, 1.2, 8, Color(1.0, 0.9, 0.5, 0.8), 1.0)

func draw_boss_overlay(ci: CanvasItem) -> void:
	if gone:
		return
	var now := room.time
	var hl := _hall()
	var lobby: bool = hl == null or hl.stage == 0
	# the cookies on the tray glow before they are thrown
	if lobby and plan_phase() == "cue" and String(plan.id) == "cookies":
		var pulse := 0.6 + 0.4 * sin(now * 24.0)
		for i in range(3):
			ci.draw_circle(Vector2(TRAY.x - 6.0 + float(i) * 6.0, TRAY.y), 2.5, Color(1.0, 0.85, 0.4, pulse))
	# the welcome mat: its corners lift before the wave
	var mat := Rect2(264.0, 173.0, 36.0, 3.0)
	if lobby:
		ci.draw_rect(mat, Color("#7a4a2a"))
		ci.draw_rect(Rect2(mat.position.x + 1.0, mat.position.y, mat.size.x - 2.0, 1.0), Color("#c89a5a"))
	if lobby and plan_phase() == "cue" and String(plan.id) == "mat":
		var lift := 3.0 + 2.0 * sin(now * 30.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(mat.position.x, mat.end.y), Vector2(mat.position.x + 6.0, mat.end.y - lift), Vector2(mat.position.x + 7.0, mat.end.y)]), Color("#c89a5a"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(mat.end.x, mat.end.y), Vector2(mat.end.x - 6.0, mat.end.y - lift), Vector2(mat.end.x - 7.0, mat.end.y)]), Color("#c89a5a"))
	# the carpet wave: a hump of floor running west
	if lobby and active and not dying and plan_active() and String(plan.id) == "mat":
		var u := float(plan.get("act", MAT_ACT)) - float(plan.t)
		var wx := MAT_X0 - u * 160.0
		var pts := PackedVector2Array()
		for k in range(9):
			var f := float(k) / 8.0
			pts.append(Vector2(wx + f * 24.0, HoneypotHall.FLOOR_Y - sin(f * PI) * 12.0))
		pts.append(Vector2(wx + 24.0, HoneypotHall.FLOOR_Y))
		pts.append(Vector2(wx, HoneypotHall.FLOOR_Y))
		ci.draw_colored_polygon(pts, Color("#a33a3a"))
		ci.draw_polyline(pts.slice(0, 9), Color("#e8c46a"), 1.0)
	# the flame out of the door's crack (and its heat on the floor while the door is open)
	if lobby and active and not dying and String(plan.get("id", "")) == "crack":
		if plan_phase() == "cue":
			ci.draw_rect(Rect2(296.0, 150.0, 8.0, 26.0), Color(1.0, 0.3, 0.2, 0.15 + 0.2 * crack_open()))
		elif plan_active():
			for k in range(12):
				var fx := 304.0 - float(k) * 8.0
				var fh := 14.0 + 12.0 * (0.5 + 0.5 * sin(now * 30.0 + float(k) * 1.9)) - float(k) * 0.9
				ci.draw_rect(Rect2(fx - 8.0, 176.0 - fh, 8.0, fh), Color("#ff6a1a"))
				ci.draw_rect(Rect2(fx - 6.0, 176.0 - fh * 0.7, 4.0, fh * 0.7), Color("#ffd84a"))
	# the notes (small and dim while they are being born at the speaker, then drifting)
	for h in hz:
		match String(h.k):
			"note":
				var p := note_pos(h, now)
				var live := hz_live(h, now)
				var al := 1.0 if live else 0.4 + 0.4 * (now - float(h.t0)) / maxf(float(h.warn), 0.1)
				var c := Color(1.0, 0.95, 0.6, al)
				ci.draw_circle(Vector2(p.x, p.y + 2.0), 2.5 if live else 1.5, c)
				ci.draw_rect(Rect2(p.x + 1.0, p.y - 5.0, 1.0, 7.0), c)
				ci.draw_rect(Rect2(p.x + 1.0, p.y - 5.0, 3.0, 1.0), c)
			"bite":
				var r := piece_rect(int(h.v[0]))
				var since := now - float(h.t0)
				if since < float(h.warn):                            # the cushions twitch
					var tw := sin(now * 70.0) * 1.2
					ci.draw_rect(Rect2(r.position.x + tw, r.position.y - 2.0, r.size.x, 2.0), Color(1.0, 0.35, 0.25, 0.7))
					ci.draw_rect(Rect2(r.position.x - 1.0 - tw, r.position.y + 1.0, r.size.x + 2.0, 1.0), Color(1.0, 0.7, 0.5, 0.6))
				elif since < float(h.warn) + 0.25:                   # the bite: teeth along the top
					var x2 := r.position.x
					while x2 < r.end.x - 2.0:
						ci.draw_colored_polygon(PackedVector2Array([Vector2(x2, r.position.y), Vector2(x2 + 4.0, r.position.y), Vector2(x2 + 2.0, r.position.y - 8.0)]), Color("#f4f0e0"))
						x2 += 5.0

# ---------------------------------------------------------------- the HUD: the shell's subtitle (warm lines are green, cold ones pale red)
func draw_hud(ci: CanvasItem) -> void:
	if say_k <= 0 or dying:
		return
	var key := String(SAY_LINES.get(say_k, "intro"))
	var el := room.time - say_t0
	var len_ := say_len(say_k)
	if el < 0.0 or el > len_ + 1.0:
		return
	var txt := String(LINE_TEXT.get(key, ""))
	var n := clampi(ceili(float(txt.length()) * el / maxf(0.5, len_ - 1.1)), 0, txt.length())
	_subtitle(ci, txt.substr(0, n), 1.0 if el < len_ else clampf(len_ + 1.0 - el, 0.0, 1.0), GREEN)

func _subtitle(ci: CanvasItem, txt: String, a: float, tint: String) -> void:
	var rows := PixelText.wrap(txt, 330)
	var h := 6.0 + rows.size() * 11.0
	var y0 := 168.0 - h
	ci.draw_rect(Rect2(20, y0, 344, h), Color(0.03, 0.03, 0.05, 0.7 * a))
	for i in range(rows.size()):
		var c := Color(tint)
		c.a = a
		PixelText.draw_text(ci, rows[i], 192.0, y0 + 4.0 + i * 11.0, c, {"align": "c", "outline": Color(0.05, 0.05, 0.08, a)})

# ---------------------------------------------------------------- the net (the guest sees the same arena)
func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, roundi(intro_t0 * 100.0), say_k, roundi(say_t0 * 100.0), roundi(die_t * 100.0), roundi(daze_t * 100.0)]
	if hl != null:
		f.append_array([hl.stage, 1 if hl.floor_on else 0, hl.furniture, hl.body_c0, hl.west_c1, hl.stairs, roundi(hl.burn_t0 * 100.0),
			roundi(hl.fist.position.x), roundi(hl.fist.position.y), roundi(hl.fist.size.x), roundi(hl.fist.size.y),
			roundi(hl.pk_t0 * 100.0), hl.seed, roundi(hl.green_t0 * 100.0), hl.pk_dir])
	else:
		f.append_array([0, 1, 7, 0, 0, 0, -100, 0, 0, 0, 0, roundi(HoneypotHall.NO_PK * 100.0), 0, -100, 0])
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 24

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	dying = int(f[3]) == 1
	intro_t0 = f[4] / 100.0
	say_k = int(f[5])
	say_t0 = f[6] / 100.0
	die_t = f[7] / 100.0
	daze_t = f[8] / 100.0
	var hl := _hall()
	if hl != null:
		hl.stage = int(f[9])
		hl.floor_on = int(f[10]) == 1
		hl.furniture = int(f[11])
		hl.body_c0 = int(f[12])
		hl.west_c1 = int(f[13])
		hl.stairs = int(f[14])
		hl.burn_t0 = f[15] / 100.0
		hl.fist = Rect2(float(f[16]), float(f[17]), float(f[18]), float(f[19])) if int(f[18]) > 0 else Rect2()
		hl.pk_t0 = f[20] / 100.0
		hl.seed = int(f[21])
		hl.green_t0 = f[22] / 100.0
		hl.pk_dir = int(f[23])
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])

func puppet_tick(dt: float) -> void:
	if dying:
		die_t += dt
	if daze_t > 0.0:
		daze_t -= dt
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
