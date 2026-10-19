class_name FirewallBoss
extends Boss
# THE FIREWALL (docs/metroidvania/16-firewall.md, 16-firewall-build.md): a honeypot.
# Phase 1 is the friendly shell (GUEST SERVICES): the door never moves and has no contact damage; the lobby's things attack (cookies from the reception
# tray, hold-music notes, a carpet wave, a flame from the door's crack) and anything Clawd rests on for 2 s bites. When bar 1 empties the fake-victory
# cutscene runs (the door opens with 200 OK, the banner turns into ACCESS DENIED, the carpet burns, the floor goes, the door slides down the wall of a huge
# brick body) and phase 2 starts in the furnace: a face on the east wall with arms, packets that are inspected and dropped, a hot floor and, for every
# player, a rate limit (two hits in 2 s are free, the third is 429).
# Every tell is drawn on the body or the room, no markers. The arena (HoneypotHall) is owned by the room; the net fields carry its masks, the packets'
# clock and everything the face is doing, so the guest builds the same arena and is hurt by the same things as the host.

const IDS := ["cookies", "hold", "mat", "crack", "slam", "sweep", "banlist", "punch", "flame", "split"]
const P1_IDS := ["cookies", "hold", "mat", "crack"]
const FIRST := ["cookies", "mat", "hold", "crack"]       # the first cycle is a fixed teaching order
const FIRST2 := ["banlist", "slam", "sweep"]             # ... and so is the first cycle of phase 2
const FIRST3 := ["punch", "split"]                       # ... and of phase 3
const GREEN := "#57ff8a"                                 # the honeypot's warm voice
const COLD := "#ff9a8a"
const RED := "#ff5a3a"                                   # the real face
const INK := "#1b1226"
const DOOR := Rect2(304.0, 80.0, 64.0, 96.0)             # the door on the east wall, cols 19-22, rows 5-10
const SCREEN := Rect2(326.0, 93.0, 20.0, 14.0)           # its small smiling screen (a caught cookie that hits it dazes the shell)
const SPEAKER := Vector2(336.0, 72.0)                    # the hold music
const TRAY := Vector2(177.0, 122.0)                      # the reception tray (the hall draws it on the desk)
const SHELL_END := 0.70                                  # bar 1 ends at 70 % of the hp
const P3_AT := 0.35                                      # phase 3 begins here
const INTRO_LONG := 6.0
const INTRO_SHORT := 2.5
const SAY_LINES := {1: "intro", 2: "reveal", 3: "p3", 4: "plead"}
const LINE_TEXT := {"intro": "Welcome! You're safe here. The exit is just this way.", "reveal": "Request denied. ...You walked in on your own. They always do.", "p3": "I said \"welcome\" and you believed me. Why? Because I was polite?", "plead": "Please... you're safe here."}
const LINE_LEN := {"intro": 4.6, "reveal": 6.5, "p3": 6.0, "plead": 3.0}          # (stand-ins until the voice files exist: their real lengths come with M5)
const LINE_TINT := {"intro": GREEN, "reveal": COLD, "p3": COLD, "plead": GREEN}
const CRACK_CUE := 0.8
const MAT_ACT := 1.7
const MAT_X0 := 280.0                                    # the wave's box (24 wide) starts at the door and runs west
const NOTE_SPEED := 40.0
const NOTE_LIFE := 6.0
const NOTE_N := 4
const BITE_AFTER := 2.0
const BITE_REST := 3.0

# the fake victory: the marks (seconds from its start) of the first time (12 s) and of every time after (3 s)
const CUT_LONG := {"open": 0.0, "tape": 1.2, "deny": 2.0, "burn": 2.6, "fall": 4.0, "s0": 4.0, "s1": 5.0, "reveal": 5.0, "f0": 6.0, "f1": 7.0, "end": 12.0, "freeze": 4.0}
const CUT_SHORT := {"open": -1.0, "tape": 0.0, "deny": 0.0, "burn": 0.0, "fall": 0.5, "s0": 1.0, "s1": 2.0, "reveal": 1.0, "f0": 1.0, "f1": 2.0, "end": 3.0, "freeze": 0.0}

# the face (phase 2-3): 48 x 48 on the active wall's surface, half of it out of the bricks
const FACE := 48.0
const FACE_START := 300.0
const FACE_Y0 := 232.0
const FACE_Y1 := 368.0
const FACE_LOW := 368.0
const FACE_SPEED := 40.0
const SLAM_TOP := 232.0                                  # where the arm comes out (the top of the picture when Clawd stands on the floor: the tell must be on screen)
const SLAM_CUE := 0.75
const SLAM_ACT := 0.25
const SLAM_REC := 1.5
const SWEEP_CUE := 0.5
const SWEEP_ACT := 0.6
const BAN_CUE := 0.5
const ARM_BREAK := 2
const DAZE_T := 1.5

# phase 3: two walls (the scene, the hops, the punch, the flame, the split, DROP ALL, the plea)
const S3 := {"crack": 0.0, "grow": 1.5, "double0": 2.0, "double1": 2.5, "end": 3.0}
const HOP_T := 0.4
const PUNCH_CUE := 0.75
const PUNCH_ACT := 0.2
const PUNCH_REC := 1.0
const PUNCH_LEN := 96.0
const FLAME_CUE := 0.5
const FLAME_ACT := 0.4
const FLAME_LEN := 80.0
const SPLIT_CUE := 0.7
const DROP_EVERY := 6.0
const DROP_WARN := 0.9
const DROP_BURN := 1.6
const PLEAD_AT := 0.105
const MIN_FURNACE := 10                                  # tiles: the walls never step in closer than this

# the rate limit (per player): two hits in RL_WIN s are free, the third is 429
const RL_WIN := 2.0
const RL_CD := 3.0
const RL_CD2 := 5.0
const WAVE_WARN := 0.7
const WAVE_BOX := 96.0

var ph := 1
var idle_t := 0.8
var last_id := ""
var cyc := 0                       # attacks started in this phase (the first ones are the fixed order)
var daze_t := 0.0                  # a caught cookie / brick hit the screen / face: no attacks
var low_t := 0.0                   # a broken arm: the face slides down to the floor
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
var shift_k := 0                   # 0 none, 2 the fake-victory cutscene (3 is the phase-3 scene, M4)
var shift_t0 := 0.0                # room time the scene began (both pages derive the scene from it)
var shift_long := true
var cut_prev := -1.0               # host: the scene's clock at the last step
var face_wall := 0                 # 0 the east wall, 1 the west one (phase 3)
var face_y := FACE_START           # the centre height of the face
var arm_hits := 0                  # hits on the planted fist of this slam (the second breaks the arm)
var face2_y := -1.0                # a split: the second face, on the other wall (-1: none)
var hop_t0 := -10.0                # the room time the face last hopped to another wall (it cannot be hit or hurt for HOP_T)
var hop_fw := 0                    # ... and where it came from
var hop_fy := FACE_START
var hop_cd := 3.0                  # host: seconds to the next hop
var drop_t := 5.0                  # host: seconds to the next DROP ALL
var split_left := 0                # host: strikes still to come in this split
var rl := {"p1": [-9.0, -9.0, -1.0, 0], "p2": [-9.0, -9.0, -1.0, 0]}    # per player: the room times of its last two hits, the end of its cooldown, blinking (1) or not
var frozen_self := false           # this page froze its own player for the scene

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

func _line_hp() -> float:
	return float(max_hp) * P3_AT

# ---------------------------------------------------------------- the scene's clock and marks
func _marks() -> Dictionary:
	if shift_k == 3:
		return S3
	return CUT_LONG if shift_long else CUT_SHORT

func _el() -> float:
	return room.time - shift_t0 if shift_k != 0 else 0.0

func _mark(k: String) -> float:
	return float(_marks()[k])

# the height of the door / face while it slides down the east wall (4.0-5.0 s, or 1.0-2.0 s in the short scene)
func _slide_y(el: float) -> float:
	var u := clampf((el - _mark("s0")) / maxf(_mark("s1") - _mark("s0"), 0.1), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	return lerpf(DOOR.get_center().y, FACE_START, u)

# has the real name been revealed (the name, the bar, the colours follow from the state, never from an event)
func _revealed() -> bool:
	return ph >= 2 or (shift_k == 2 and _el() >= _mark("reveal"))

func _derive_names() -> void:
	var rv := _revealed()
	boss_name = "THE FIREWALL" if rv else "GUEST SERVICES"
	sub = "deny by default" if rv else "welcome, guest"
	col = RED if rv else GREEN
	phase = ph

# ---------------------------------------------------------------- the bar (the HUD asks every boss that has one)
# bar 1: the shell, green, from 100 % to 70 % of the hp (empty during the fake victory); bar 2: the real one, red, 70 % to 0 (it fills at the reveal)
func hud_bar() -> Array:
	if shift_k == 2:
		if _el() < _mark("f0"):
			return [0.0, RED if _el() >= _mark("reveal") else GREEN, boss_name]
		return [clampf((_el() - _mark("f0")) / maxf(_mark("f1") - _mark("f0"), 0.1), 0.0, 1.0), RED, boss_name]
	if ph >= 2:
		return [clampf(hpf / _floor_hp(), 0.0, 1.0), RED, "THE FIREWALL"]
	var f := clampf((hpf - _floor_hp()) / (float(max_hp) - _floor_hp()), 0.0, 1.0)
	return [f, GREEN, "GUEST SERVICES"]

# ---------------------------------------------------------------- the face
func _wall_x(wall: int) -> float:
	var hl := _hall()
	if hl == null:
		return 288.0 if wall == 0 else 16.0
	return hl.east_surface() if wall == 0 else hl.west_surface()

func face_cy() -> float:
	return _slide_y(_el()) if shift_k == 2 else face_y

func face_center() -> Vector2:
	return Vector2(_wall_x(face_wall), face_cy())

func face_rect() -> Rect2:
	var c := face_center()
	return Rect2(c.x - FACE / 2.0, c.y - FACE / 2.0, FACE, FACE)

func _face_rect_at(wall: int, cy: float) -> Rect2:
	return Rect2(_wall_x(wall) - FACE / 2.0, cy - FACE / 2.0, FACE, FACE)

func _hopping() -> bool:
	return shift_k == 0 and room.time - hop_t0 < HOP_T

# the faces that are out on a wall right now, [wall, centre y] each (none while the face hops between the walls; two in a split)
func faces() -> Array:
	if shift_k == 2 or _hopping():
		return []
	var out: Array = [[face_wall, face_cy()]]
	if face2_y >= 0.0:
		out.append([1 - face_wall, face2_y])
	return out

# the fist of a punch: 96 x 24 out of the wall at the target's height (plan fields: wall, row-aligned top)
func fist_rect() -> Rect2:
	var wl := int(plan.fp[0])
	var fy := float(plan.fp[1])
	var wx := _wall_x(wl)
	return Rect2(wx - PUNCH_LEN if wl == 0 else wx, fy, PUNCH_LEN, 24.0)

func _plan_is(id: String, phs: String = "") -> bool:
	return not plan.is_empty() and String(plan.id) == id and (phs == "" or String(plan.ph) == phs)
func _face_low() -> bool:
	return daze_t > 0.0 or low_t > 0.0

# ---------------------------------------------------------------- boxes
func hurtboxes() -> Array:
	var b: Array = []
	if not active or dying:
		if ph >= 2:
			return []
		return [{"x": DOOR.position.x, "y": DOOR.position.y, "w": DOOR.size.x, "h": DOOR.size.y}]
	if shift_k != 0:
		return []
	if ph >= 2:
		var fl := faces()
		for i in range(fl.size()):
			var fr := _face_rect_at(int(fl[i][0]), float(fl[i][1]))
			b.append({"x": fr.position.x, "y": fr.position.y, "w": fr.size.x, "h": fr.size.y, "face": 1 + i, "wall": int(fl[i][0]), "fy": float(fl[i][1])})
		if _plan_is("slam", "recover") and arm_hits < ARM_BREAK:
			var ax := float(plan.fp[0])
			b.append({"x": ax - 16.0, "y": HoneypotHall.FURN_Y - 24.0, "w": 32.0, "h": 24.0, "arm": 1})
		if _plan_is("punch", "recover"):                        # the fist that stays out: hit it, or stand on it
			var pf := fist_rect()
			b.append({"x": pf.position.x, "y": pf.position.y, "w": pf.size.x, "h": pf.size.y, "fist": 1})
		return b
	b.append({"x": SCREEN.position.x, "y": SCREEN.position.y, "w": SCREEN.size.x, "h": SCREEN.size.y, "screen": 1})      # (first: a caught cookie finds the screen before the door)
	b.append({"x": DOOR.position.x, "y": DOOR.position.y, "w": DOOR.size.x, "h": DOOR.size.y})
	for h in hz:
		if h.k == "note" and hz_live(h, room.time):
			var p := note_pos(h, room.time)
			b.append({"x": p.x - 5.0, "y": p.y - 5.0, "w": 10.0, "h": 10.0, "note": hz_key(h)})
	return b

# no contact damage from the door (it is a door); the face and the things the lobby throws do hurt
func harmboxes() -> Array:
	var b: Array = []
	if active and not dying and shift_k == 0:
		if ph == 1:
			if plan_active() and String(plan.id) == "mat":
				var u := float(plan.get("act", MAT_ACT)) - float(plan.t)
				b.append({"x": MAT_X0 - u * 160.0, "y": HoneypotHall.FLOOR_Y - 12.0, "w": 24.0, "h": 12.0, "dmg": 1})
			if plan_active() and String(plan.id) == "crack":
				b.append({"x": 208.0, "y": 144.0, "w": 96.0, "h": 32.0, "dmg": _big()})
		else:
			for fc in faces():
				var fr := _face_rect_at(int(fc[0]), float(fc[1]))
				b.append({"x": fr.position.x, "y": fr.position.y, "w": fr.size.x, "h": fr.size.y, "dmg": 1})
			if plan_active():
				match String(plan.id):
					"slam":
						var ax := float(plan.fp[0])
						b.append({"x": ax - 16.0, "y": SLAM_TOP, "w": 32.0, "h": HoneypotHall.FURN_Y - SLAM_TOP, "dmg": _big()})
					"sweep":
						b.append(_sweep_box())
					"punch":
						var pf := fist_rect()
						b.append({"x": pf.position.x, "y": pf.position.y, "w": pf.size.x, "h": pf.size.y, "dmg": _big()})
					"flame":
						b.append(_flame_box())
	b.append_array(hz_harm())
	return b

# the flame: 80 x 20 from the face's edge, straight out over the furnace (plan fields: wall, centre height)
func _flame_box() -> Dictionary:
	var wl := int(plan.fp[0])
	var wx := _wall_x(wl)
	return {"x": wx - FACE / 2.0 - FLAME_LEN if wl == 0 else wx + FACE / 2.0, "y": float(plan.fp[1]) - 10.0, "w": FLAME_LEN, "h": 20.0, "dmg": 1}

# the scraping arm: 24 px wide, 20 tall above the floor, from the face's wall to the other wall in the active time
func _sweep_box() -> Dictionary:
	var act := float(plan.get("act", SWEEP_ACT))
	var u := clampf((act - float(plan.t)) / maxf(act, 0.1), 0.0, 1.0)
	var x0 := _wall_x(face_wall) + (0.0 if face_wall == 1 else -24.0)
	var x1 := _wall_x(1 - face_wall) + (0.0 if face_wall == 0 else -24.0)
	return {"x": lerpf(x0, x1, u), "y": HoneypotHall.FURN_Y - 20.0, "w": 24.0, "h": 20.0, "dmg": 1}

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

func _heat_burn() -> float:
	return 1.6 if ph == 3 else 1.2

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
		"heat":                                                         # a stepped-on floor cell burns after its build-up
			if since >= 0.0 and since < _heat_burn():
				return [{"x": float(int(h.v[0]) * 16), "y": HoneypotHall.FURN_Y - 10.0, "w": 16.0, "h": 10.0, "dmg": 1}]
		"dropall":                                                      # DROP ALL: the whole furnace floor burns
			if since >= 0.0 and since < DROP_BURN:
				return [{"x": float(h.v[0]), "y": HoneypotHall.FURN_Y - 12.0, "w": float(h.v[1]) - float(h.v[0]), "h": 12.0, "dmg": 1}]
		"wave":                                                         # the counter blast of a 429: 96 x 96 around the face for 0.3 s
			if since >= 0.0 and since < 0.3:
				return [{"x": float(h.v[0]) - WAVE_BOX / 2.0, "y": float(h.v[1]) - WAVE_BOX / 2.0, "w": WAVE_BOX, "h": WAVE_BOX, "dmg": _big()}]
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
			"heat":
				if since > _heat_burn() + HoneypotHall.HEAT_COOL:
					hz.erase(h)
			"wave":
				if since > 0.4:
					hz.erase(h)
			"dropall":
				if since > DROP_BURN + 0.4:
					hz.erase(h)
			"pdrop":
				if since > 2.0:
					hz.erase(h)

# the hall draws the hot floor from the hazards (both pages, every frame: state, not events)
func _sync_heat() -> void:
	var hl := _hall()
	if hl == null:
		return
	hl.heat_burn = _heat_burn()
	var m := {}
	for h in hz:
		if h.k == "heat":
			m[int(h.v[0])] = float(h.t0)
	if m != hl.heat:
		hl.heat = m
	var pd := {}
	for h in hz:
		if h.k == "pdrop":
			pd[int(h.v[0]) * 1000000 + int(h.v[1])] = float(h.t0) + float(h.warn)       # (the moment the punch turns active)
	if pd != hl.pdrops:
		hl.pdrops = pd

# ---------------------------------------------------------------- hits
func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if not active or dying:
		return ""
	if d >= 9999:
		skipping = true                                           # (the pause menu's skip button: it ends the fight at once, in a scene too)
	elif shift_k != 0:
		return ""                                                 # (it cannot be hurt during the fake victory)
	if b is Dictionary and b.has("note"):
		for h in hz.duplicate():
			if hz_key(h) == String(b.note):
				var p := note_pos(h, room.time)
				room.burst(p.x, p.y, 5, ["#fff3b0", GREEN], 80.0, 160.0)
				hz.erase(h)
		Audio.sfx("squish", {"vol": 0.6})
		return "kill"
	if ph >= 2 and not skipping and how != "catch":                   # the rate limit: each player has two free hits in 2 s
		var at := face_center()
		if b is Dictionary and b.has("face"):
			at = Vector2(_wall_x(int(b.wall)), float(b.fy))
		if not _rate_ok(kit_key_of(room.attacker), at):
			room.burst(at.x, at.y, 4, ["#ffffff", "#ffb08a"], 60.0, 120.0)
			return "hit"
	if how == "catch":                                               # something thrown back at it (steered at the screen / the face): dazed
		daze_t = DAZE_T
		plan_cut()
		var fc := SCREEN.get_center() if ph == 1 else face_center()
		room.burst(fc.x, fc.y, 8, ["#ffd23f", "#ffffff"], 90.0, 100.0)
	if b is Dictionary and b.has("arm") and not skipping:
		arm_hits += 1
		var ap := Vector2(float(plan.fp[0]), HoneypotHall.FURN_Y - 12.0) if not plan.is_empty() else face_center()
		room.burst(ap.x, ap.y, 5, ["#ffffff", "#ffb08a"], 80.0, 160.0)
		Audio.sfx("clang", {"vol": 0.6})
		if arm_hits >= ARM_BREAK:                                    # the arm breaks and the face slides down
			low_t = DAZE_T
			room.shake(0.4)
			Audio.sfx("brk")
	return super.hit(d, dx, dy, how, b)

# per-player rate limit. true: the hit counts; false: it is wasted (a `tock`, the cooldown restarts at 5 s, or the 429 itself)
func _rate_ok(key: String, at: Vector2) -> bool:
	if key == "":
		key = "p1"
	var s: Array = rl[key]
	var now := room.time
	if now < float(s[2]):                                            # still in the cooldown: it restarts, longer
		s[2] = now + RL_CD2
		s[3] = 1
		Audio.sfx("tock", {"vol": 0.7})
		return false
	if now - float(s[0]) <= RL_WIN:                                   # the third hit in 2 s: 429 Too Many Requests
		s[0] = -9.0
		s[1] = -9.0
		s[2] = now + RL_CD
		s[3] = 0
		hz_add("wave", WAVE_WARN, [roundi(at.x), roundi(at.y)])       # the counter blast (it also pushes the walls in during phase 3)
		Audio.sfx("warn", {"vol": 0.7})
		_on_429()
		return false
	s[0] = s[1]
	s[1] = now
	return true

func _on_429() -> void:
	var hl := _hall()
	if ph != 3 or hl == null:
		return
	if hl.body_c0 - (hl.west_c1 + 1) > MIN_FURNACE:                  # both walls step one tile in, down to a furnace of 10 tiles
		hl.body_c0 -= 1
		hl.west_c1 += 1
		room.shake(0.5)
		Audio.sfx("thud", {"vol": 0.8})

# a player's LEDs: how many of its two hits are still lit (a hit stays lit 1 s)
func rl_lit(key: String, now: float) -> int:
	var s: Array = rl[key]
	var n := 0
	for i in range(2):
		if now - float(s[i]) < 1.0 and now >= float(s[i]):
			n += 1
	return n

func rl_cooling(key: String, now: float) -> bool:
	return now < float(rl[key][2])

# the shell holds at 70 % and starts the fake victory; phase 2 holds at 35 % and starts the phase-3 scene; a skip goes through
func on_damage() -> void:
	if skipping or dying:
		return
	if ph == 1 and shift_k == 0:
		if hpf <= _floor_hp():
			hpf = _floor_hp()
			hp = ceili(hpf)
			_begin_cut()
	elif ph == 2 and shift_k == 0:
		if hpf <= _line_hp():
			hpf = _line_hp()
			hp = ceili(hpf)
			_begin_scene3()

func start() -> void:
	super.start()
	idle_t = 0.8
	cyc = 0
	last_id = ""
	ph = 1
	shift_k = 0
	arm_hits = 0
	face2_y = -1.0
	split_left = 0
	hop_t0 = -10.0
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

# placeholders until the firewall has its own music: the friendly first-world theme (the honeypot plays what feels safe), silence while the tape stops
func music_now(_want: String) -> String:
	if dying:
		return ""
	if shift_k == 2:
		return "w1" if _el() < _mark("tape") else ""
	if shift_k == 3:
		return "boss"
	if ph >= 3:
		return "boss_hi"
	if ph == 2:
		return "boss"
	return "w1"

# ---------------------------------------------------------------- the fake victory (host runs it; the guest derives everything from shift_t0)
func _begin_cut() -> void:
	shift_k = 2
	shift_t0 = room.time
	shift_long = not Game.flag("reveal:FIREWALL")
	cut_prev = -1.0
	plan = {}
	hz.clear()
	notes_left = 0
	daze_t = 0.0
	for q in room.projs:
		q.dead = true
	var hl := _hall()
	if hl != null:
		hl.burn_t0 = shift_t0 + _mark("burn")                    # the carpet burns from this room time (a pure function of it on both pages)
	room.events.append("bossPhase")
	Game.dlog("%s fake victory (%s)" % [boss_name, "long" if shift_long else "short"])

# phase 2 -> 3 (3 s, invulnerable): the west wall cracks and grows out its bricks, the face shows a doubled image, the cold line plays; the packets stop and start again from both walls
func _begin_scene3() -> void:
	shift_k = 3
	shift_t0 = room.time
	cut_prev = -1.0
	plan = {}
	hz.clear()
	daze_t = 0.0
	low_t = 0.0
	split_left = 0
	face2_y = -1.0
	for q in room.projs:
		q.dead = true
	var hl := _hall()
	if hl != null:
		hl.fist = Rect2()
		hl.pk_t0 = HoneypotHall.NO_PK
	_say(3)
	room.shake(0.8)
	Audio.sfx("degauss", {"vol": 0.8})
	room.events.append("bossPhase")
	Game.dlog("%s phase 3 scene" % boss_name)

func _step_scene3(_dt: float) -> void:
	var el := _el()
	var prev := cut_prev
	cut_prev = el
	var hl := _hall()
	if _crossed(prev, el, float(S3.grow)) and hl != null:
		hl.set_stage(2)                                          # the west wall's bricks are there
		room.shake(0.8)
		Audio.sfx("crumble")
		Audio.sfx("bigExplode", {"vol": 0.4})
	if el >= float(S3.end):
		_end_scene3()

func _end_scene3() -> void:
	shift_k = 0
	ph = 3
	phase = 3
	cyc = 0
	last_id = ""
	idle_t = 0.8
	hop_cd = 3.0
	drop_t = 5.0
	arm_hits = 0
	var hl := _hall()
	if hl != null:
		hl.pk_t0 = room.time                                     # the packets start again, from both walls
		hl.pk_dir = 1
	Game.dlog("%s phase 3" % boss_name)

func _crossed(prev: float, el: float, mark: float) -> bool:
	return mark >= 0.0 and prev < mark and el >= mark

func _step_cut(_dt: float) -> void:
	var el := _el()
	var prev := cut_prev
	cut_prev = el
	var hl := _hall()
	if _crossed(prev, el, _mark("open")):
		Audio.sfx("uiOk", {"vol": 0.8})                          # 200 OK (a stand-in chime until the sounds exist)
	if _crossed(prev, el, _mark("tape")):
		Audio.sfx("degauss", {"vol": 0.7})                       # the tape stops
	if _crossed(prev, el, _mark("burn")) and shift_long:
		Audio.sfx("explode", {"vol": 0.4})
	if _crossed(prev, el, _mark("fall")) and hl != null:
		hl.set_stage(1)                                          # the carpet and the furniture go, the body's bricks come up, everyone falls
		room.shake(0.8)
		Audio.sfx("crumble")
		Audio.sfx("bigExplode", {"vol": 0.4})
	if _crossed(prev, el, _mark("reveal")):
		_say(2)
		room.shake(0.6)
		Audio.sfx("roar", {"vol": 0.7})
	if el >= _mark("end"):
		_end_cut()

func _end_cut() -> void:
	shift_k = 0
	ph = 2
	phase = 2
	face_wall = 0
	face_y = FACE_START
	cyc = 0
	last_id = ""
	idle_t = 0.8
	arm_hits = 0
	rl = {"p1": [-9.0, -9.0, -1.0, 0], "p2": [-9.0, -9.0, -1.0, 0]}
	Game.flags["reveal:FIREWALL"] = true
	var hl := _hall()
	if hl != null:
		hl.pk_t0 = room.time                                     # the packets begin
		hl.pk_dir = 0
		hl.green_t0 = -1.0
	Game.dlog("%s phase 2" % boss_name)

# each page freezes its own player while the scene lets them watch (the first time only: 0 to the fall)
func _freeze_own() -> void:
	var p = room.player
	if p == null:
		return
	var want: bool = shift_k == 2 and shift_long and _el() < _mark("freeze") and active and not dying
	if want and not frozen_self:
		p.frozen = true
		frozen_self = true
	elif not want and frozen_self:
		p.frozen = false
		frozen_self = false

# ---------------------------------------------------------------- the fight
func update(dt: float) -> void:
	tick(dt)
	if read != null:
		read.update(dt)
	_derive_names()
	_freeze_own()
	if dying:
		hz.clear()
		death_rattle(dt, 1.0, ["#ffffff", GREEN, "#2e9a52"])
		_sync_heat()
		return
	if not active:
		if room.fight.state == "intro":
			_step_intro(dt)
		return
	_hz_expire()
	_sync_heat()
	if shift_k == 2:
		_step_cut(dt)
		_place()
		return
	if shift_k == 3:
		_step_scene3(dt)
		_place()
		return
	daze_t = maxf(0.0, daze_t - dt)
	low_t = maxf(0.0, low_t - dt)
	_steer_caught()
	if ph == 1:
		_pressure(dt)
		if plan.is_empty():
			plan_clock += dt
			idle_t -= dt
			if idle_t <= 0.0 and daze_t <= 0.0:
				_choose()
		else:
			_plan_logic(dt)
	else:
		_heat_watch()
		if ph == 3:
			_phase3_tick(dt)
		_drift(dt)
		if plan.is_empty():
			plan_clock += dt
			idle_t -= dt
			if idle_t <= 0.0 and daze_t <= 0.0 and low_t <= 0.0 and not _hopping():
				if split_left > 0:
					_split_strike()
				elif face2_y >= 0.0:
					_end_split()
				else:
					_choose2()
		else:
			_plan_logic2(dt)
	_place()

# the boss's box follows its face once the shell is gone (the kit measures distances from it)
func _place() -> void:
	if ph >= 2:
		var fr := face_rect()
		x = fr.position.x
		y = fr.position.y
		w = fr.size.x
		h = fr.size.y

# a caught cookie / brick flies back at the screen / the face (the lob or the shot it was thrown with would not find it)
func _steer_caught() -> void:
	for q in room.projs:
		if q.dead or not q.get("friendly", false) or not (q.get("cookie", false) or q.get("fwb", false)) or q.get("steered", false):
			continue
		var sp := maxf(Vector2(float(q.vx), float(q.vy)).length(), 260.0)          # (a cookie at the top of its lob is slow: it still has to arrive)
		var tgt := SCREEN.get_center() if ph == 1 else face_center()
		var dir := (tgt - Vector2(float(q.x), float(q.y))).normalized()
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
		pick = _weighted(opts)
	cyc += 1
	last_id = pick
	_start(pick, tgt)

# a weighted pick that never repeats the last attack
func _weighted(opts: Array) -> String:
	var tot := 0.0
	for o in opts:
		if String(o[0]) != last_id:
			tot += float(o[1])
	var r := room.rng.randf() * tot
	var pick := String(opts[0][0])
	for o in opts:
		if String(o[0]) == last_id or float(o[1]) <= 0.0:
			continue
		r -= float(o[1])
		if r <= 0.0:
			pick = String(o[0])
			break
	return pick

func _notes_alive() -> int:
	var n := 0
	for h in hz:
		if h.k == "note":
			n += 1
	return n

func _start(id: String, tgt: String) -> void:
	if not P1_IDS.has(id):
		_start_phase2(id, tgt)
		return
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

# ---------------------------------------------------------------- phase 2: the furnace
# the hot floor: a floor cell somebody stands on starts to burn 2 s later (host: it adds the hazard, both pages draw it from the hazard list)
func _heat_watch() -> void:
	var hl := _hall()
	if hl == null or hl.stage < 1 or hl.stage > 2:
		return
	for h in hz:
		if h.k == "dropall":
			return                                                   # (the floor is already burning)
	var have := {}
	for h in hz:
		if h.k == "heat":
			have[int(h.v[0])] = true
	var ix := hl.inner_x()
	for key in kit_keys():
		var q = kit_body(key)
		if q == null or q.dead:
			continue
		if absf(q.y + q.h - HoneypotHall.FURN_Y) > 1.5:
			continue
		var c := floori((q.x + q.w / 2.0) / 16.0)
		if float(c * 16) < ix.x - 1.0 or float(c * 16 + 16) > ix.y + 1.0 or have.has(c):
			continue
		have[c] = true
		hz_add("heat", 2.0, [c])

# the face drifts towards the nearest player's height (or down to the floor when it is hurt)
func _drift(dt: float) -> void:
	if face2_y >= 0.0 or _hopping():
		return
	if not plan.is_empty() and String(plan.ph) != "recover":
		return
	if _face_low():
		face_y = move_toward(face_y, FACE_LOW, 300.0 * dt)
		return
	if not plan.is_empty():
		return
	var tgt_y := face_y
	var best := 1e9
	for key in kit_keys():
		var dd := kit_dist(key)
		if dd < best:
			best = dd
			tgt_y = kit_aim(key).y
	face_y = move_toward(face_y, clampf(tgt_y, FACE_Y0, FACE_Y1), FACE_SPEED * dt)

func _choose2() -> void:
	if kit_keys().is_empty():
		idle_t = 0.3
		return
	var tgt := kit_pick_target()
	var pick := ""
	var first: Array = FIRST3 if ph == 3 else FIRST2
	if cyc < first.size():
		pick = first[cyc]
	else:
		var q = kit_body(tgt)
		var on_floor: bool = q != null and q.y + q.h >= HoneypotHall.FURN_Y - 2.0
		var far: bool = q != null and absf(q.x + q.w / 2.0 - _wall_x(face_wall)) > 96.0
		var high: bool = q != null and q.y + q.h < 20.0 * 16.0
		var opts: Array = [["slam", 3.0 + (2.0 if on_floor else 0.0)], ["sweep", 2.0 + (2.0 if on_floor and far else 0.0)], ["banlist", 2.0 + (2.0 if high else 0.0)]]
		if ph == 3:
			opts = [["split", 3.0], ["punch", 2.0], ["flame", 2.0], ["slam", 1.0], ["sweep", 1.0], ["banlist", 1.0]]
		pick = _weighted(opts)
	cyc += 1
	last_id = pick
	_start(pick, tgt)

func _start_phase2(id: String, tgt: String) -> void:
	match id:
		"slam":
			var ix: Vector2 = _hall().inner_x() if _hall() != null else Vector2(16.0, 288.0)
			var ax := clampf(kit_aim(tgt).x, ix.x + 16.0, ix.y - 16.0)
			arm_hits = 0
			var feint: bool = ph == 3 and room.rng.randi() % 4 == 0               # 1 in 4 slams in phase 3 holds its cue 0.25 s longer
			plan_start("slam", "slam", tgt, [roundf(ax), float(face_wall), 0.0, 0.0], 0.0, SLAM_CUE + (0.25 if feint else 0.0), 1.0 if ph == 3 else SLAM_REC, SLAM_ACT)
			Audio.sfx("charge", {"vol": 0.5})                        # the hiss (a stand-in until the sounds exist)
		"sweep":
			plan_start("sweep", "sweep", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, SWEEP_CUE, 0.6, SWEEP_ACT)
			Audio.sfx("tick", {"vol": 0.6})
		"banlist":
			plan_start("banlist", "proj", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, BAN_CUE, 0.5, 0.2)
			Audio.sfx("charge", {"vol": 0.5})
		"punch":
			_start_punch(tgt, -1, PUNCH_REC)
		"flame":
			_start_flame(tgt, face_wall, face_y)
		"split":
			plan_start("split", "guard", tgt, [0.0, 0.0, 0.0, 0.0], 0.0, SPLIT_CUE, 0.35, 0.3)
			Audio.sfx("warn", {"vol": 0.7})                          # two deep beeps (a stand-in until the sounds exist)
			Audio.sfx("warn", {"vol": 0.7})
	if not plan.is_empty():
		Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _plan_logic2(dt: float) -> void:
	var pid := String(plan.id)
	var ev := plan_step(dt)
	match ev:
		"active":
			match pid:
				"slam":
					room.shake(0.5)
					Audio.sfx("thud", {"vol": 0.8})
				"sweep":
					Audio.sfx("dash", {"vol": 0.5})
				"banlist":
					_shoot_bricks()
				"punch":
					_punch_out()
				"flame":
					room.shake(0.2)
					Audio.sfx("roar", {"vol": 0.5})
				"split":
					_begin_split()
	if ev == "done":
		idle_t = 0.35 + room.rng.randf() * 0.15
		if split_left > 0:
			idle_t = 0.1                                             # (a split's strikes follow each other)
		if pid == "punch":
			var hl := _hall()
			if hl != null:
				hl.fist = Rect2()                                    # the fist goes back into the wall

# ---------------------------------------------------------------- phase 3
func _phase3_tick(dt: float) -> void:
	var hl := _hall()
	if hl == null:
		return
	if hl.green_t0 < 0.0 and hpf <= PLEAD_AT * float(max_hp):          # the last 15 %: it pleads, and the packets that look safe begin (they always drop)
		_say(4)
		hl.green_t0 = room.time
	drop_t -= dt                                                     # DROP ALL: the whole floor burns every 6 s (never during a split)
	if drop_t <= 0.0 and face2_y < 0.0:
		var ix := hl.inner_x()
		hz_add("dropall", DROP_WARN, [roundi(ix.x), roundi(ix.y)])
		drop_t = DROP_EVERY
		Audio.sfx("charge", {"vol": 0.7})
	if plan.is_empty() and face2_y < 0.0 and daze_t <= 0.0 and low_t <= 0.0 and not _hopping():
		hop_cd -= dt                                                 # the face hops to the other wall (or another height) every 2-4 s between attacks
		if hop_cd <= 0.0:
			_hop()

func _hop() -> void:
	var tgt := kit_pick_target()
	var ap := kit_aim(tgt)
	var hl := _hall()
	var ix := hl.inner_x() if hl != null else Vector2(16.0, 288.0)
	var to_wall := 0 if absf(ap.x - ix.y) < absf(ap.x - ix.x) else 1
	if room.rng.randf() < 0.25:
		to_wall = 1 - to_wall
	var to_y := clampf(ap.y, FACE_Y0, FACE_Y1)
	hop_cd = 2.0 + room.rng.randf() * 2.0
	if to_wall == face_wall and absf(to_y - face_y) < 24.0:
		return
	hop_t0 = room.time
	hop_fw = face_wall
	hop_fy = face_y
	face_wall = to_wall
	face_y = to_y
	idle_t = maxf(idle_t, 0.45)
	Audio.sfx("whoosh" if Audio.SFX.has("whoosh") else "dash", {"vol": 0.5})

# the wall facing the target throws a fist at its height; if it stands on a packet, that packet drops with the punch (its tell is the punch's)
func _start_punch(tgt: String, wall: int, rec: float) -> void:
	var q = kit_body(tgt)
	var feet: float = q.y + q.h if q != null else HoneypotHall.FURN_Y
	var ix: Vector2 = _hall().inner_x() if _hall() != null else Vector2(16.0, 288.0)
	var wl := wall
	if wl < 0:
		var ax: float = q.x + q.w / 2.0 if q != null else 150.0
		wl = 0 if absf(ax - ix.y) < absf(ax - ix.x) else 1
	var fy := clampf(floorf((feet - 6.0) / 16.0) * 16.0, 208.0, 376.0)
	plan_start("punch", "lunge", tgt, [float(wl), fy, 0.0, 0.0], 0.0, PUNCH_CUE, rec, PUNCH_ACT)
	Audio.sfx("charge", {"vol": 0.6})                                # the hiss
	if q != null:
		for m in room.plats:
			if m.has("fw") and not m.off and not m.lost and int(m.k) >= 0 and absf(feet - float(m.y)) <= 2.5 and q.x + q.w > float(m.x) and q.x < float(m.x) + 64.0:
				hz_add("pdrop", PUNCH_CUE * _tm(), [int(m.lane), int(m.k)])
				break

func _punch_out() -> void:
	var hl := _hall()
	if hl != null:
		hl.fist = fist_rect()
	room.shake(0.5)
	Audio.sfx("thud", {"vol": 0.8})

func _start_flame(tgt: String, wall: int, fy: float) -> void:
	plan_start("flame", "proj", tgt, [float(wall), roundf(fy), 0.0, 0.0], 0.0, FLAME_CUE, 0.5, FLAME_ACT)
	Audio.sfx("charge", {"vol": 0.5})

# SPLIT: two faces for a chain of 3-4 strikes (a punch or a flame each, from a random wall, at a player's spot at its cue), then they merge, dazed
func _begin_split() -> void:
	split_left = 3 + room.rng.randi() % 2
	var other := kit_pick_target()
	face2_y = clampf(kit_aim(other).y, FACE_Y0, FACE_Y1)
	room.shake(0.4)
	Audio.sfx("roar", {"vol": 0.6})

func _split_strike() -> void:
	if kit_keys().is_empty():
		idle_t = 0.3
		return
	var tgt := kit_pick_target()
	var ap := kit_aim(tgt)
	var wl := room.rng.randi() % 2
	var gy := clampf(ap.y, FACE_Y0, FACE_Y1)
	split_left -= 1
	if wl == face_wall:
		face_y = gy
	else:
		face2_y = gy
	if room.rng.randf() < 0.6:
		_start_punch(tgt, wl, 0.6)
	else:
		_start_flame(tgt, wl, gy)
	Game.dlog("%s split strike %s on %s (%d left)" % [boss_name, String(plan.id), tgt, split_left])

func _end_split() -> void:
	face2_y = -1.0
	face_wall = 0
	face_y = FACE_LOW
	daze_t = 1.0
	idle_t = 1.0
	cyc += 1                                                         # (the split counts as the attack it was)

# three burning bricks in a fan around the aim; one is yellow (catch it and send it back at the face)
func _shoot_bricks() -> void:
	var fc := face_center()
	var dir := -1.0 if face_wall == 0 else 1.0
	var o0 := Vector2(fc.x + dir * 26.0, fc.y)
	var ap := kit_aim(plan.tgt)
	var base := (ap - o0).angle()
	var gold := room.rng.randi() % 3
	for i in range(3):
		var a := base + deg_to_rad(15.0 * float(i - 1))
		var o := {"g": 0.0, "r": 4.0, "life": 3.0, "dmg": 1, "by_boss": true, "fwb": true, "tile": true}
		if i == gold:
			o.merge({"kind": "diamond", "col": "#ffd23f", "catchable": true, "cut": true})
		else:
			o.merge({"kind": "orb", "col": "#ff7a2a", "cut": true})
		room.shoot(o0.x, o0.y, cos(a) * 170.0, sin(a) * 170.0, o)
	Audio.sfx("shoot", {"vol": 0.7})

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
	if ph >= 2 or shift_k == 2:
		_draw_body2(ci)
		return
	_draw_door(ci, 0.0, 12.0 * crack_open(), clampf(crack_open() * 1.4 - 0.2, 0.0, 1.0), true)

# the exit door with its screen and speaker, `dy` lower than its place; `gap` px open (the lit strip behind it goes from white to red with `red`)
func _draw_door(ci: CanvasItem, dy: float, gap: float, red: float, lobby: bool) -> void:
	var now := room.time
	var d := Rect2(DOOR.position.x, DOOR.position.y + dy, DOOR.size.x, DOOR.size.y)
	ci.draw_rect(Rect2(d.position.x - 3.0, d.position.y - 3.0, d.size.x + 6.0, d.size.y + 3.0), Color("#0f2e1c"))      # the frame
	ci.draw_rect(Rect2(d.position.x - 2.0, d.position.y - 2.0, d.size.x + 4.0, d.size.y + 2.0), Color("#1d5a38"))
	if gap > 0.5:                                                    # the crack: white at first, then red; a lit strip of the room behind the door
		var lit := Color("#ffffff").lerp(Color("#ff3b2a"), red)
		ci.draw_rect(Rect2(d.position.x, d.position.y, gap, d.size.y), lit)
		ci.draw_rect(Rect2(d.position.x, d.position.y, gap, 2.0), Color("#ffe8e0"))
	var lx := d.position.x + gap                                    # the leaf swings away from the left edge
	var lw := d.size.x - gap
	ci.draw_rect(Rect2(lx, d.position.y, lw, d.size.y), Color("#2e9a52"))
	ci.draw_rect(Rect2(lx + 5.0, d.position.y + 8.0, lw - 10.0, d.size.y - 8.0), Color("#3fbf68"))
	ci.draw_rect(Rect2(lx + 5.0, d.position.y + 8.0, lw - 10.0, 2.0), Color("#7affa0"))
	ci.draw_rect(Rect2(lx, d.position.y, lw, 1.0), Color("#7affa0"))
	var ex := lx + lw / 2.0                                         # the EXIT lamp
	if lw > 22.0:
		ci.draw_rect(Rect2(ex - 13.0, d.position.y + 1.0, 26.0, 7.0), Color("#103a22"))
		PixelText.draw_text(ci, "EXIT", ex, d.position.y + 2.0, "#e8ffee", {"align": "c", "tiny": true})
		ci.draw_rect(Rect2(lx + 6.0, d.position.y + 56.0, 2.0, 8.0), Color("#c8f0d4"))      # the bar handle
		# the fake LED row: requests remaining: unlimited (there is no rate limit in the shell)
		PixelText.draw_text(ci, "requests", ex, d.position.y + 66.0, "#7affa0", {"align": "c", "tiny": true})
		PixelText.draw_text(ci, "remaining: ∞", ex, d.position.y + 73.0, "#7affa0", {"align": "c", "tiny": true})
	# the screen on the frame: a smiling face, a wide grin before the cookies, a spinning loading icon when dazed
	var sr := Rect2(SCREEN.position.x, SCREEN.position.y + dy, SCREEN.size.x, SCREEN.size.y)
	ci.draw_rect(Rect2(sr.position.x - 1.0, sr.position.y - 1.0, sr.size.x + 2.0, sr.size.y + 2.0), Color("#0f2e1c"))
	ci.draw_rect(sr, Color("#0a1a10"))
	var cutscene := shift_k == 2
	if daze_t > 0.0 or cutscene:
		var c := sr.get_center()
		var denied: bool = cutscene and _el() >= _mark("deny")
		if denied:                                                   # the screen turns into a red x: ACCESS DENIED
			for k in range(-4, 5):
				ci.draw_rect(Rect2(c.x + float(k) - 0.5, c.y + float(k) * 0.8 - 0.5, 1.5, 1.5), Color(1.0, 0.35, 0.3))
				ci.draw_rect(Rect2(c.x + float(k) - 0.5, c.y - float(k) * 0.8 - 0.5, 1.5, 1.5), Color(1.0, 0.35, 0.3))
		else:
			for i in range(8):
				var ang := TAU * float(i) / 8.0 - now * 6.0
				var al := 0.25 + 0.75 * float(i) / 8.0
				ci.draw_rect(Rect2(c.x + cos(ang) * 4.5 - 0.5, c.y + sin(ang) * 4.5 - 0.5, 1.5, 1.5), Color(0.5, 1.0, 0.6, al))
	else:
		var wide: bool = plan_phase() == "cue" and String(plan.get("id", "")) == "cookies"
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
	var sp := SPEAKER + Vector2(0.0, dy)
	ci.draw_rect(Rect2(sp.x - 8.0, sp.y - 5.0, 16.0, 10.0), Color("#1a1a22"))
	ci.draw_rect(Rect2(sp.x - 7.0, sp.y - 4.0, 14.0, 8.0), Color("#3a3a46"))
	ci.draw_circle(sp, 3.0, Color("#15151b"))
	if lobby and plan_phase() == "cue" and String(plan.get("id", "")) == "hold":
		ci.draw_circle(sp, 3.0, Color("#ffe27a"))                    # it lights up
		ci.draw_arc(sp, 6.0 + fposmod(now * 14.0, 6.0), -1.2, 1.2, 8, Color(1.0, 0.9, 0.5, 0.8), 1.0)

# phase 2 and the scene's second half: the door that slides down, the face, the arms, the LED row
func _draw_body2(ci: CanvasItem) -> void:
	var now := room.time
	if shift_k == 2:
		var el := _el()
		if el < _mark("reveal"):
			var opened := 0.0
			if _mark("open") >= 0.0:
				opened = clampf((el - _mark("open")) / 0.4, 0.0, 1.0)
			var gap := lerpf(12.0, 44.0, opened) if shift_long else 12.0
			var red := 0.0 if el < _mark("deny") else 1.0
			var dy := _slide_y(el) - DOOR.get_center().y
			_draw_door(ci, dy, gap, red, false)
			return
	var open_eyes: bool = ph >= 2 or (_el() - _mark("reveal")) > 0.4
	var fl := flash > 0.0
	if shift_k == 0 and not plan.is_empty():
		match String(plan.id):
			"slam":
				_draw_slam_arm(ci, _wall_x(int(plan.fp[1])), int(plan.fp[1]) == 0, now)
			"sweep":
				_draw_sweep_arm(ci, _wall_x(face_wall), face_wall == 0, now)
	for fc in faces():
		var wl := int(fc[0])
		var wx := _wall_x(wl)
		var ghost := 0.0
		if shift_k == 3 and _el() >= float(S3.double0) and _el() < float(S3.double1):          # the doubled image of the scene
			ghost = 7.0 * sin((_el() - float(S3.double0)) / (float(S3.double1) - float(S3.double0)) * PI)
		if ghost > 0.5:
			_draw_ghost(ci, wx + ghost * (-1.0 if wl == 0 else 1.0), float(fc[1]), wl == 0)
		_draw_face(ci, wx, float(fc[1]), wl == 0, open_eyes, fl, now)
		_draw_leds(ci, wx, float(fc[1]), wl == 0, now)

# the doubled image: a translucent copy of the face a few pixels off
func _draw_ghost(ci: CanvasItem, wx: float, cy: float, east: bool) -> void:
	ci.draw_set_transform(Vector2(wx, 0.0), 0.0, Vector2(1.0 if east else -1.0, 1.0))
	ci.draw_rect(Rect2(-24.0, cy - 24.0, 48.0, 48.0), Color(1.0, 0.35, 0.25, 0.30))
	ci.draw_rect(Rect2(-16.0, cy - 10.0, 12.0, 5.0), Color(1.0, 0.8, 0.6, 0.5))
	ci.draw_rect(Rect2(2.0, cy - 10.0, 12.0, 5.0), Color(1.0, 0.8, 0.6, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _brick_col(ci: CanvasItem, r: Rect2, glow := 0.0) -> void:
	ci.draw_rect(r, Color("#2a1512"))
	ci.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, r.size.x - 2.0, r.size.y - 2.0), Color("#5e3428").lerp(Color("#ff7a2a"), glow))
	ci.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, r.size.x - 2.0, 1.0), Color("#92563c").lerp(Color("#ffd890"), glow))
	var y := r.position.y + 6.0
	while y < r.end.y - 2.0:
		ci.draw_rect(Rect2(r.position.x + 1.0, y, r.size.x - 2.0, 1.0), Color("#2a1512"))
		y += 7.0

# the face in the wall's frame: lx grows into the room from the wall (east: world x = wx + lx with lx < 0; the transform mirrors it for the west wall)
func _draw_face(ci: CanvasItem, wx: float, cy: float, east: bool, open_eyes: bool, fl: bool, now: float) -> void:
	ci.draw_set_transform(Vector2(wx, 0.0), 0.0, Vector2(1.0 if east else -1.0, 1.0))
	var low := _face_low()
	var cuem := plan_phase() == "cue"
	var pid := String(plan.get("id", ""))
	var mouth_hot: bool = (cuem or plan_active()) and (pid == "banlist" or pid == "flame")
	var x0 := -24.0
	var y0 := cy - 24.0
	var plate := Color("#ffffff") if fl else Color("#4a2018")
	ci.draw_rect(Rect2(x0 - 2.0, y0 - 2.0, 52.0, 52.0), Color("#1b0c0a"))
	ci.draw_rect(Rect2(x0, y0, 48.0, 48.0), plate)
	ci.draw_rect(Rect2(x0 + 2.0, y0 + 2.0, 44.0, 44.0), Color("#6a2e22"))
	ci.draw_rect(Rect2(x0 + 2.0, y0 + 2.0, 44.0, 2.0), Color("#a2503a"))
	for bx in [x0 + 4.0, x0 + 40.0]:
		for by in [y0 + 4.0, y0 + 40.0]:
			ci.draw_rect(Rect2(bx, by, 3.0, 3.0), Color("#c4601e"))
	# the brow, the eyes (closed slits until the reveal's first moments; sagging when the face is hurt)
	var ey := y0 + 14.0 + (4.0 if low else 0.0)
	ci.draw_rect(Rect2(x0 + 6.0, ey - 4.0, 36.0, 3.0), Color("#2a1512"))
	for ex2 in [x0 + 8.0, x0 + 26.0]:
		if open_eyes and not low:
			ci.draw_rect(Rect2(ex2, ey, 12.0, 5.0), Color("#1b0c0a"))
			ci.draw_rect(Rect2(ex2 + 1.0, ey + 1.0, 10.0, 3.0), Color(RED))
			ci.draw_rect(Rect2(ex2 + 4.0, ey + 1.0, 4.0, 3.0), Color("#ffe0b0"))
		elif open_eyes:
			ci.draw_rect(Rect2(ex2, ey + 2.0, 12.0, 2.0), Color("#7a2a22"))
		else:
			ci.draw_rect(Rect2(ex2, ey + 2.0, 12.0, 1.0), Color("#1b0c0a"))
	# the mouth: a grille that glows when it is about to spit
	var my := y0 + 30.0
	ci.draw_rect(Rect2(x0 + 8.0, my, 32.0, 12.0), Color("#1b0c0a"))
	var gcol := Color("#ffb040") if mouth_hot else Color("#3a1812")
	if mouth_hot:
		gcol = gcol.lerp(Color("#ffffff"), 0.4 + 0.4 * sin(now * 30.0))
	if low:
		gcol = Color("#2a1512")
	for k in range(5):
		ci.draw_rect(Rect2(x0 + 10.0 + float(k) * 6.0, my + 2.0, 3.0, 8.0), gcol)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# the fist of a slam: out of the wall's top, across to the target's column, down onto the floor; its root glows orange in the cue
func _draw_slam_arm(ci: CanvasItem, wx: float, east: bool, now: float) -> void:
	var ax := float(plan.fp[0])
	var ph_ := String(plan.ph)
	var top := SLAM_TOP
	var tot: float = SLAM_CUE * _tm()
	if ph_ == "cue":
		var k := clampf(1.0 - float(plan.t) / maxf(tot, 0.01), 0.0, 1.0)         # the bricks around the arm's root glow (the arm is pulled back into the wall)
		var sgn := -1.0 if east else 1.0
		ci.draw_rect(Rect2(minf(wx, wx + sgn * 22.0), top - 4.0, 22.0, 24.0), Color(1.0, 0.4, 0.1, 0.25 + 0.5 * k))
		for s in range(3):
			var sy := top - 6.0 - fposmod(now * 40.0 + float(s) * 9.0, 18.0)
			ci.draw_circle(Vector2(wx + sgn * (8.0 + float(s) * 5.0), sy), 1.5 + k, Color(0.9, 0.9, 0.95, 0.5))      # steam
		return
	var u := 1.0
	if ph_ == "active":
		u = clampf((SLAM_ACT - float(plan.t)) / SLAM_ACT, 0.0, 1.0)
	var reach := clampf(u * 2.5, 0.0, 1.0)
	var bx: float = lerpf(wx, ax, reach)
	_brick_col(ci, Rect2(minf(wx, bx), top, absf(bx - wx) + 8.0, 14.0))
	var fy := lerpf(top + 14.0, HoneypotHall.FURN_Y - 32.0, clampf(u * 1.4 - 0.2, 0.0, 1.0))
	_brick_col(ci, Rect2(ax - 8.0, top, 16.0, fy - top + 4.0))
	var broken: bool = ph_ == "recover" and arm_hits >= ARM_BREAK
	if broken:
		ci.draw_rect(Rect2(ax - 10.0, fy + 6.0, 20.0, 26.0), Color("#1b0c0a"))
	else:
		_brick_col(ci, Rect2(ax - 16.0, fy, 32.0, 32.0), 0.35 if ph_ == "active" else 0.0)

# the arm that scrapes along the floor: lowered at the wall's foot with sparks, then drawn across to the other wall
func _draw_sweep_arm(ci: CanvasItem, wx: float, east: bool, now: float) -> void:
	var ph_ := String(plan.ph)
	var sgn := -1.0 if east else 1.0
	if ph_ == "cue":
		var tot: float = SWEEP_CUE * _tm()
		var k := clampf(1.0 - float(plan.t) / maxf(tot, 0.01), 0.0, 1.0)
		var w2 := 8.0 + 16.0 * k
		var rx := wx - (w2 if east else 0.0)
		_brick_col(ci, Rect2(rx, HoneypotHall.FURN_Y - 20.0 * k - 4.0, w2, 20.0 * k + 4.0), 0.2 * k)
		for s in range(4):
			var spx := wx + sgn * (w2 + float(s) * 3.0)
			ci.draw_rect(Rect2(spx, HoneypotHall.FURN_Y - 2.0 - fposmod(now * 50.0 + float(s) * 7.0, 10.0), 2.0, 2.0), Color(1.0, 0.8, 0.3))
		return
	if ph_ == "active":
		var sb := _sweep_box()
		var bx := float(sb.x)
		var edge := wx - (24.0 if east else 0.0)
		_brick_col(ci, Rect2(minf(edge, bx), HoneypotHall.FURN_Y - 12.0, absf(bx - edge) + 24.0, 12.0))
		_brick_col(ci, Rect2(bx, HoneypotHall.FURN_Y - 20.0, 24.0, 20.0), 0.4)
		for s in range(5):
			var spx := bx + (0.0 if east else 24.0) + sgn * float(s) * 3.0
			ci.draw_rect(Rect2(spx, HoneypotHall.FURN_Y - 2.0 - fposmod(now * 70.0 + float(s) * 5.0, 12.0), 2.0, 2.0), Color(1.0, 0.85, 0.35))

# the LED row on the body above the face: one row per player, two LEDs each (a hit stays lit 1 s; in the cooldown they are solid red, blinking when it restarted)
func _draw_leds(ci: CanvasItem, wx: float, cy: float, east: bool, now: float) -> void:
	var px := wx + (3.0 if east else -29.0)
	var py := cy - 44.0
	ci.draw_rect(Rect2(px - 1.0, py - 1.0, 28.0, 17.0), Color("#0d0606"))
	ci.draw_rect(Rect2(px, py, 26.0, 15.0), Color("#1d0c0a"))
	var rows := [["p1", Game.COL.clawdHi], ["p2", "#9cc4ff"]]
	for ri in range(2):
		var key: String = rows[ri][0]
		var cc := Color(String(rows[ri][1]))
		var lit := rl_lit(key, now)
		var cool := rl_cooling(key, now)
		var blink: bool = int(rl[key][3]) == 1
		for li in range(2):
			var lx := px + 5.0 + float(li) * 9.0
			var ly := py + 3.0 + float(ri) * 7.0
			var col2 := Color("#3a2220")
			if cool:
				col2 = Color("#ff2a1a") if (not blink or int(now * 8.0) % 2 == 0) else Color("#4a1410")
			elif li < lit:
				col2 = cc
			ci.draw_rect(Rect2(lx, ly, 6.0, 4.0), col2)
	PixelText.draw_text(ci, "requests", px + 13.0, py + 17.0, "#a87050", {"align": "c", "tiny": true})

func draw_boss_overlay(ci: CanvasItem) -> void:
	if gone:
		return
	var now := room.time
	var hl := _hall()
	var lobby: bool = hl == null or hl.stage == 0
	if ph >= 2 or shift_k == 2:
		_draw_overlay2(ci, now)
		if shift_k == 2 and lobby:
			_draw_lobby_things(ci, now, lobby)
		return
	_draw_lobby_things(ci, now, lobby)

# the lobby's things: the tray, the mat, the carpet wave, the flame, the notes, the bites
func _draw_lobby_things(ci: CanvasItem, now: float, lobby: bool) -> void:
	# the cookies on the tray glow before they are thrown
	if lobby and plan_phase() == "cue" and String(plan.get("id", "")) == "cookies":
		var pulse := 0.6 + 0.4 * sin(now * 24.0)
		for i in range(3):
			ci.draw_circle(Vector2(TRAY.x - 6.0 + float(i) * 6.0, TRAY.y), 2.5, Color(1.0, 0.85, 0.4, pulse))
	# the welcome mat: its corners lift before the wave
	var mat := Rect2(264.0, 173.0, 36.0, 3.0)
	if lobby:
		ci.draw_rect(mat, Color("#7a4a2a"))
		ci.draw_rect(Rect2(mat.position.x + 1.0, mat.position.y, mat.size.x - 2.0, 1.0), Color("#c89a5a"))
	if lobby and plan_phase() == "cue" and String(plan.get("id", "")) == "mat":
		var lift := 3.0 + 2.0 * sin(now * 30.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(mat.position.x, mat.end.y), Vector2(mat.position.x + 6.0, mat.end.y - lift), Vector2(mat.position.x + 7.0, mat.end.y)]), Color("#c89a5a"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(mat.end.x, mat.end.y), Vector2(mat.end.x - 6.0, mat.end.y - lift), Vector2(mat.end.x - 7.0, mat.end.y)]), Color("#c89a5a"))
	# the carpet wave: a hump of floor running west
	if lobby and active and not dying and plan_active() and String(plan.get("id", "")) == "mat":
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

# the furnace's things: the 429 blast, the hop's trail, the punch's bulge, the flame, the split's heat, DROP ALL, the west wall cracking
func _draw_overlay2(ci: CanvasItem, now: float) -> void:
	for h in hz:
		var kind := String(h.k)
		var since := now - float(h.t0)
		var warn := float(h.warn)
		if kind == "wave":
			var c := Vector2(float(h.v[0]), float(h.v[1]))
			if since < warn:                                         # the build-up: the face brightens, a heat shimmer grows around it
				var k := clampf(since / warn, 0.0, 1.0)
				ci.draw_circle(c, 18.0 + 30.0 * k, Color(1.0, 0.45, 0.15, 0.08 + 0.2 * k))
				ci.draw_circle(c, 10.0 + 14.0 * k, Color(1.0, 0.8, 0.5, 0.10 + 0.22 * k))
				PixelText.draw_text(ci, "429", c.x, c.y - 4.0, "#ffe8d0", {"align": "c", "outline": INK})
			elif since < warn + 0.3:                                 # the blast
				ci.draw_rect(Rect2(c.x - WAVE_BOX / 2.0, c.y - WAVE_BOX / 2.0, WAVE_BOX, WAVE_BOX), Color(1.0, 0.55, 0.2, 0.55))
				ci.draw_circle(c, WAVE_BOX / 2.0 * 0.9, Color(1.0, 0.95, 0.7, 0.6))
		elif kind == "dropall":                                      # DROP ALL: the floor glows red, then burns end to end
			var x0 := float(h.v[0])
			var x1 := float(h.v[1])
			if since < warn:
				var k2 := clampf(since / warn, 0.0, 1.0)
				ci.draw_rect(Rect2(x0, HoneypotHall.FURN_Y - 3.0 - 4.0 * k2, x1 - x0, 3.0 + 4.0 * k2), Color(1.0, 0.2 + 0.3 * k2, 0.1, 0.35 + 0.5 * k2))
			elif since < warn + DROP_BURN:
				var xx := x0
				while xx < x1:
					var fh := 10.0 + 8.0 * (0.5 + 0.5 * sin(now * 20.0 + xx * 0.4))
					ci.draw_rect(Rect2(xx, HoneypotHall.FURN_Y - fh, 8.0, fh), Color(1.0, 0.45, 0.1, 0.8))
					ci.draw_rect(Rect2(xx + 2.0, HoneypotHall.FURN_Y - fh * 0.6, 4.0, fh * 0.6), Color(1.0, 0.85, 0.35, 0.9))
					xx += 8.0
	# the hop: an orange trail under the bricks from where it was to where it is, and the old spot goes dark
	var ht := now - hop_t0
	if ph == 3 and shift_k == 0 and ht >= 0.0 and ht < HOP_T + 0.6:
		var a := Vector2(_wall_x(hop_fw), hop_fy)
		var b := Vector2(_wall_x(face_wall), face_y)
		var k3 := clampf(ht / HOP_T, 0.0, 1.0)
		var fade := 1.0 if ht < HOP_T else clampf(1.0 - (ht - HOP_T) / 0.6, 0.0, 1.0)
		var tip := a.lerp(b, k3)
		ci.draw_line(a, tip, Color(1.0, 0.5, 0.15, 0.8 * fade), 4.0)
		ci.draw_line(a, tip, Color(1.0, 0.85, 0.5, 0.9 * fade), 1.5)
		var east_a := hop_fw == 0
		ci.draw_rect(Rect2(a.x - 24.0 if east_a else a.x - 0.0, a.y - 24.0, 24.0, 48.0), Color(0.0, 0.0, 0.0, 0.5 * fade))
	if shift_k == 0 and not plan.is_empty():
		match String(plan.id):
			"punch":                                                 # the wall bulges at the target's height and its bricks glow
				var wl := int(plan.fp[0])
				var fy := float(plan.fp[1])
				if String(plan.ph) == "cue":
					var k4 := clampf(1.0 - float(plan.t) / maxf(PUNCH_CUE * _tm(), 0.01), 0.0, 1.0)
					var wx := _wall_x(wl)
					var dir := -1.0 if wl == 0 else 1.0
					ci.draw_rect(Rect2(minf(wx, wx + dir * 8.0 * k4), fy - 2.0, 8.0 * k4, 28.0), Color("#7a4a38"))
					ci.draw_rect(Rect2(minf(wx, wx + dir * 24.0), fy - 6.0, 24.0, 36.0), Color(1.0, 0.4, 0.1, 0.12 + 0.35 * k4))
					for s2 in range(3):
						ci.draw_circle(Vector2(wx + dir * (6.0 + float(s2) * 6.0), fy - 4.0 - fposmod(now * 40.0 + float(s2) * 8.0, 14.0)), 1.5, Color(0.9, 0.9, 0.95, 0.5))
			"flame":
				if String(plan.ph) == "active":
					var fb := _flame_box()
					var wl2 := int(plan.fp[0])
					for k5 in range(10):
						var fx := float(fb.x) + (float(k5) * 8.0 if wl2 == 1 else float(fb.w) - 8.0 - float(k5) * 8.0)
						var fh2 := 10.0 + 9.0 * (0.5 + 0.5 * sin(now * 30.0 + float(k5) * 1.7)) - float(k5) * 0.5
						ci.draw_rect(Rect2(fx, float(fb.y) + 10.0 - fh2 / 2.0, 8.0, fh2), Color("#ff6a1a"))
						ci.draw_rect(Rect2(fx + 1.0, float(fb.y) + 10.0 - fh2 * 0.3, 6.0, fh2 * 0.6), Color("#ffd84a"))
			"split":                                                 # both walls heat at once; a second face shows
				if String(plan.ph) == "cue":
					var k6 := clampf(1.0 - float(plan.t) / maxf(SPLIT_CUE * _tm(), 0.01), 0.0, 1.0)
					for wl3 in range(2):
						var wx3 := _wall_x(wl3)
						var dir3 := -1.0 if wl3 == 0 else 1.0
						ci.draw_rect(Rect2(minf(wx3, wx3 + dir3 * 20.0), 208.0, 20.0, 192.0), Color(1.0, 0.35, 0.1, 0.10 + 0.30 * k6 * (0.6 + 0.4 * sin(now * 20.0))))
	if shift_k == 3:                                                 # the west wall cracks (its bricks come at the scene's 1.5 s)
		var el := _el()
		var k7 := clampf(el / float(S3.grow), 0.0, 1.0)
		if el < float(S3.grow):
			var wx7 := 16.0
			ci.draw_rect(Rect2(wx7, 208.0, 4.0 + 44.0 * k7, 192.0), Color(1.0, 0.35, 0.1, 0.10 + 0.25 * k7))
			for i in range(6):
				var cy7 := 220.0 + float(i) * 30.0
				var l7 := 10.0 + 34.0 * k7 * (0.5 + Game.hash3(i, 3, 79))
				ci.draw_line(Vector2(wx7, cy7), Vector2(wx7 + l7, cy7 + 6.0), Color(1.0, 0.7, 0.3, 0.8), 1.0)
				ci.draw_line(Vector2(wx7 + l7, cy7 + 6.0), Vector2(wx7 + l7 * 0.7, cy7 + 14.0), Color(1.0, 0.7, 0.3, 0.8), 1.0)

# ---------------------------------------------------------------- the HUD: subtitles (warm lines are green, cold ones pale red) and the fake victory's banners
func draw_hud(ci: CanvasItem) -> void:
	if shift_k == 2 and active and not dying:
		_draw_cut_hud(ci)
	if say_k <= 0 or dying:
		return
	var key := String(SAY_LINES.get(say_k, "intro"))
	var el := room.time - say_t0
	var len_ := say_len(say_k)
	if el < 0.0 or el > len_ + 1.0:
		return
	var txt := String(LINE_TEXT.get(key, ""))
	var n := clampi(ceili(float(txt.length()) * el / maxf(0.5, len_ - 1.1)), 0, txt.length())
	_subtitle(ci, txt.substr(0, n), 1.0 if el < len_ else clampf(len_ + 1.0 - el, 0.0, 1.0), String(LINE_TINT.get(key, GREEN)))

func _subtitle(ci: CanvasItem, txt: String, a: float, tint: String) -> void:
	var rows := PixelText.wrap(txt, 330)
	var h := 6.0 + rows.size() * 11.0
	var y0 := 168.0 - h
	ci.draw_rect(Rect2(20, y0, 344, h), Color(0.03, 0.03, 0.05, 0.7 * a))
	for i in range(rows.size()):
		var c := Color(tint)
		c.a = a
		PixelText.draw_text(ci, rows[i], 192.0, y0 + 4.0 + i * 11.0, c, {"align": "c", "outline": Color(0.05, 0.05, 0.08, a)})

# the banner: `THE FIREWALL defeated` in the honeypot's green (its letters shift as the tape stops), then `ACCESS DENIED` in red; later the name card
func _draw_cut_hud(ci: CanvasItem) -> void:
	var el := _el()
	var W2 := float(Game.W)
	var ink := Color(Game.COL.ink)
	var deny_at := _mark("deny")
	var banner_end := _mark("reveal") if shift_long else 1.4
	if el < banner_end + 0.5:
		var fade := 1.0 if el < banner_end else clampf(1.0 - (el - banner_end) / 0.5, 0.0, 1.0)
		if el < deny_at:
			var txt := "THE FIREWALL defeated"
			if el < _mark("tape"):
				PixelText.draw_text(ci, txt, W2 / 2.0, 56.0, GREEN, {"align": "c", "scale": 2, "outline": ink})
			else:                                                # the tape has stopped: the letters shift one by one
				var cx := W2 / 2.0 - float(PixelText.text_width(txt, {"scale": 2})) / 2.0
				for i in range(txt.length()):
					var ch := txt.substr(i, 1)
					var dyy := (Game.hash3(i, int(room.time * 20.0), 71) - 0.5) * 10.0 * minf((el - _mark("tape")) / 0.4, 1.0)
					var dxx := (Game.hash3(i, int(room.time * 20.0), 72) - 0.5) * 6.0
					PixelText.draw_text(ci, ch, cx + dxx, 56.0 + dyy, GREEN, {"scale": 2, "outline": ink})
					cx += float(PixelText.text_width(txt.substr(0, i + 1), {"scale": 2})) - float(PixelText.text_width(txt.substr(0, i), {"scale": 2}))
		else:
			var c := Color(RED)
			c.a = fade
			PixelText.draw_text(ci, "ACCESS DENIED", W2 / 2.0 + (Game.hash3(int(room.time * 30.0), 1, 73) - 0.5) * 2.0, 56.0, c, {"align": "c", "scale": 2, "outline": Color(0.1, 0.02, 0.02, fade)})
	# the name card, as at an intro
	var r0 := _mark("reveal")
	if el >= r0 and el < r0 + 2.4:
		var k := clampf((el - r0) / 0.5, 0.0, 1.0)
		var fo := 1.0 if el < r0 + 1.9 else clampf(1.0 - (el - r0 - 1.9) / 0.5, 0.0, 1.0)
		var tc := Color(Game.COL.paper)
		tc.a = fo
		PixelText.draw_text(ci, "THE FIREWALL", W2 / 2.0, 40.0 - (1.0 - k) * 12.0, tc, {"align": "c", "scale": 2, "outline": Game.COL.ink, "shadow": Game.COL.ink})
		ci.draw_rect(Rect2(floori(W2 / 2.0 - 70.0 * k + 0.5), 60, floori(140.0 * k + 0.5), 1), Color(Game.COL.hazard))
		var sc2 := Color(Game.COL.hazardHi)
		sc2.a = fo
		PixelText.draw_text(ci, "deny by default", W2 / 2.0, 65.0, sc2, {"align": "c", "outline": Game.COL.ink})

# ---------------------------------------------------------------- the net (the guest sees the same arena)
func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, roundi(intro_t0 * 100.0), say_k, roundi(say_t0 * 100.0), roundi(die_t * 100.0), roundi(daze_t * 100.0)]
	f.append_array([ph, shift_k, roundi(shift_t0 * 100.0), 1 if shift_long else 0, face_wall, roundi(face_y), roundi(low_t * 100.0), arm_hits,
		roundi(face2_y), roundi(hop_t0 * 100.0), hop_fw, roundi(hop_fy)])
	for key in ["p1", "p2"]:
		var s: Array = rl[key]
		f.append_array([roundi(float(s[0]) * 100.0), roundi(float(s[1]) * 100.0), roundi(float(s[2]) * 100.0), int(s[3])])
	if hl != null:
		f.append_array([hl.stage, 1 if hl.floor_on else 0, hl.furniture, hl.body_c0, hl.west_c1, hl.stairs, roundi(hl.burn_t0 * 100.0),
			roundi(hl.fist.position.x), roundi(hl.fist.position.y), roundi(hl.fist.size.x), roundi(hl.fist.size.y),
			roundi(hl.pk_t0 * 100.0), hl.seed, roundi(hl.green_t0 * 100.0), hl.pk_dir])
	else:
		f.append_array([0, 1, 7, 0, 0, 0, -100, 0, 0, 0, 0, roundi(HoneypotHall.NO_PK * 100.0), 0, -100, 0])
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 44

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
	ph = int(f[9])
	shift_k = int(f[10])
	shift_t0 = f[11] / 100.0
	shift_long = int(f[12]) == 1
	face_wall = int(f[13])
	face_y = float(f[14])
	low_t = f[15] / 100.0
	arm_hits = int(f[16])
	face2_y = float(f[17])
	hop_t0 = f[18] / 100.0
	hop_fw = int(f[19])
	hop_fy = float(f[20])
	var i := 21
	for key in ["p1", "p2"]:
		rl[key] = [f[i] / 100.0, f[i + 1] / 100.0, f[i + 2] / 100.0, int(f[i + 3])]
		i += 4
	var hl := _hall()
	if hl != null:
		hl.stage = int(f[i])
		hl.floor_on = int(f[i + 1]) == 1
		hl.furniture = int(f[i + 2])
		hl.body_c0 = int(f[i + 3])
		hl.west_c1 = int(f[i + 4])
		hl.stairs = int(f[i + 5])
		hl.burn_t0 = f[i + 6] / 100.0
		hl.fist = Rect2(float(f[i + 7]), float(f[i + 8]), float(f[i + 9]), float(f[i + 10])) if int(f[i + 9]) > 0 else Rect2()
		hl.pk_t0 = f[i + 11] / 100.0
		hl.seed = int(f[i + 12])
		hl.green_t0 = f[i + 13] / 100.0
		hl.pk_dir = int(f[i + 14])
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])
	_derive_names()
	_place()

func puppet_tick(dt: float) -> void:
	if dying:
		die_t += dt
	if daze_t > 0.0:
		daze_t -= dt
	if low_t > 0.0:
		low_t -= dt
	_derive_names()
	_freeze_own()
	_sync_heat()
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
