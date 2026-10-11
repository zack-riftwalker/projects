class_name Reviewer
extends Boss
# THE REVIEWER #1 (docs/PLAN-metroidvania-phase3.md MV3-05): a rival duelist in the arena R10. Attacks are marked: a `lunge` and the first
# two `nitpick` slashes are catchable strikes (harmboxes with `sid` + `catchable`; a parry staggers him), the `comments` are catchable
# projectiles, the counter stance `review` blocks claws and dashes and answers with a riposte. Telegraphs times telegraph_mult, punish
# windows times punish_mult (never below 0.4 s). Everything a guest's combat reads is in net_fields().

const STATES := ["wait", "idle", "lunge_tel", "lunge", "lunge_rec", "stagger", "comments_tel", "comments_air", "comments_rec", "review", "review_open",
	"riposte", "nitpick_tel", "slash", "nitpick_gap", "nitpick_rec", "shove_tel", "shove", "phase", "kneel"]
const PHASE1 := ["lunge", "comments", "review"]
const PHASE2 := ["lunge", "nitpick", "review", "comments"]
const WALK := 60.0
const LUNGE_DIST := 150.0
const LUNGE_SPEED := 420.0
const COMMENT_SPEED := 150.0
const STRIKE_ST := ["lunge", "slash", "riposte"]
const INK := "#1b1226"
const HOODIE := "#5a6b8c"
const PEN := "#ff4f6d"

var cycle := 0
var strike_sid := 0           # the id of the strike in progress (0: none); the guest's parry names it
var slash := 0                # nitpick: which slash (1..3)
var riposted := false
var camp_t := 0.0             # how long a player has been standing at his side
var parries := [0, 0]         # host: how many strikes P1 / P2 parried (the co-op test reads it)

func _init(r: Room, bx: float, by: float, base_hp := 49) -> void:
	super(r, bx, by, 14, 24, base_hp)
	boss_name = "THE REVIEWER"
	sub = "changes requested"
	col = HOODIE
	face = -1.0

func _tm() -> float:
	return float(Game.dv("telegraph_mult"))

func _pm(base: float) -> float:
	return maxf(0.4, base * float(Game.dv("punish_mult")))

func _sp() -> float:
	return 1.15 if phase == 2 else 1.0

func _new_strike() -> void:
	strike_sid = Game.next_strike_id()

func _phys(dt: float, grav := 900.0) -> void:
	vy = minf(vy + grav * dt, 320.0)
	hit_wall = room.grid.move_x(self, vx * dt)
	var hy := room.grid.move_y(self, vy * dt, true)       # (he never stands on the one-way ledges: the arena floor is his)
	on_ground = hy > 0
	if hy != 0:
		vy = 0.0

func on_damage() -> void:
	if phase == 1 and hpf <= max_hp / 2.0 and not dying:
		phase = 2
		cycle = 0
		room.events.append("bossPhase")
		room.shake(0.6)
		for q in room.projs:
			if not q.get("friendly", false):
				q.dead = true
		vx = 0.0
		strike_sid = 0
		set_state("phase", 1.0)

# a swipe or dash on the raised pen is blocked and answered; everything else lands
func blocks(_dx: float, _dy: float, how: String) -> bool:
	return st == "review" and (how == "swipe" or how == "dash" or how == "agent")

func hit(d: int, dx: float, dy: float, how: String, box = null) -> String:
	if active and not dying and blocks(dx, dy, how):
		var att = room.attacker
		Audio.sfx("clang")
		room.spark(cx + face * 8.0, y + 8.0, "#ffffff", 8)
		room.stop(0.04)
		if att != null and is_instance_valid(att):
			face = 1.0 if att.x + 5.0 >= cx else -1.0
		riposted = true
		_new_strike()
		set_state("riposte", 0.4)
		vx = 0.0
		return "block"
	return super.hit(d, dx, dy, how, box)

# a player caught his strike (Room.interact_combat / Coop._host_parry)
func parried(_by, sid: int) -> void:
	if dying or not active or sid <= 0 or st in ["stagger", "phase", "wait", "review", "riposte"]:
		return
	vx = 0.0
	strike_sid = 0
	flash = 0.15
	parries[1 if (_by != null and _by.get("is_remote")) else 0] += 1
	set_state("stagger", _pm(0.9))
	Audio.sfx("clang")
	Audio.sfx("hit", {"vol": 0.7})
	room.spark(cx, y + 6.0, "#ffd23f", 10)
	room.stop(0.06)

func _idle_time() -> float:
	return 0.7 if phase == 2 else 0.9

func _camping() -> bool:
	for q in room.players():
		if absf(q.x + 5.0 - cx) < 26.0 and absf(q.y + 5.0 - cy) < 24.0:
			return true
	return false

func update(dt: float) -> void:
	tick(dt)
	if dying:
		die_t += dt
		vx = 0.0
		_phys(dt)
		if die_t >= 1.5 and not gone:
			gone = true
			dead = true
			room.ring(cx, cy, 4, 44, "#ffffff", 0.5)
			Audio.sfx("kill")
			room.drop(cx, cy, drop_n)
			room.events.append("bossDead")
		return
	if not active:
		_phys(dt)
		return
	st_t -= dt
	var p = pick_target()
	var ap := aim_point(p)
	var sp := _sp()
	dmg = int(Game.dv("big_hit")) if (st == "slash" and slash == 3) else 1
	match st:
		"idle":
			var dxp: float = ap.x - cx
			face = 1.0 if dxp >= 0.0 else -1.0
			var dist := absf(dxp)
			if dist < 70.0:
				vx = -face * WALK * sp
			elif dist > 110.0:
				vx = face * WALK * sp
			else:
				vx = 0.0
			if _camping():
				camp_t += dt
			else:
				camp_t = maxf(0.0, camp_t - dt)
			if camp_t >= 1.2:
				camp_t = 0.0
				vx = 0.0
				set_state("shove_tel", 0.5 * _tm())
			elif st_t <= 0.0:
				next_target()
				p = pick_target()
				ap = aim_point(p)
				face = 1.0 if ap.x >= cx else -1.0
				vx = 0.0
				var seq: Array = PHASE2 if phase == 2 else PHASE1
				var pick: String = seq[cycle % seq.size()]
				cycle += 1
				match pick:
					"lunge":
						set_state("lunge_tel", 0.55 * _tm())
					"comments":
						set_state("comments_tel", 0.6 * _tm())
					"review":
						riposted = false
						set_state("review", 1.2)
					"nitpick":
						slash = 0
						set_state("nitpick_tel", 0.6 * _tm())
		"lunge_tel":
			vx = 0.0
			if st_t <= 0.0:
				_new_strike()
				set_state("lunge", LUNGE_DIST / (LUNGE_SPEED * sp))
				vx = face * LUNGE_SPEED * sp
				Audio.sfx("dash", {"vol": 0.7})
		"lunge":
			vx = face * LUNGE_SPEED * sp
			if st_t <= 0.0 or hit_wall != 0:
				vx = 0.0
				strike_sid = 0
				set_state("lunge_rec", _pm(0.6))
		"lunge_rec", "stagger", "review_open", "nitpick_rec":
			vx = 0.0
			if st_t <= 0.0:
				set_state("idle", _idle_time())
		"comments_tel":
			vx = 0.0
			vy = 0.0
			y = Game.damp(y, Boss.FLOOR - 60.0 - h, 12.0, dt)
			if st_t <= 0.0:
				_throw_comments(ap)
				set_state("comments_air", 3.0)
		"comments_air":
			vx = 0.0
			if on_ground:
				set_state("comments_rec", _pm(0.5))
		"comments_rec":
			vx = 0.0
			if st_t <= 0.0:
				set_state("idle", _idle_time())
		"review":
			vx = 0.0
			if _camping():
				camp_t += dt
			else:
				camp_t = maxf(0.0, camp_t - dt)
			if camp_t >= 1.2:
				camp_t = 0.0
				set_state("shove_tel", 0.5 * _tm())
			elif st_t <= 0.0:
				if riposted:
					set_state("idle", _idle_time())
				else:
					set_state("review_open", _pm(0.5))
		"riposte":
			vx = 0.0
			if st_t <= 0.0:
				strike_sid = 0
				set_state("idle", _idle_time())
		"nitpick_tel":
			vx = 0.0
			if st_t <= 0.0:
				_start_slash(1)
		"slash":
			if st_t <= 0.0:
				vx = 0.0
				strike_sid = 0
				if slash < 3:
					set_state("nitpick_gap", 0.2 if slash == 1 else 0.7)
				else:
					set_state("nitpick_rec", _pm(0.9))
		"nitpick_gap":
			vx = 0.0
			if st_t <= 0.0:
				_start_slash(slash + 1)
		"shove_tel":
			vx = 0.0
			if st_t <= 0.0:
				set_state("shove", 0.15)
				Audio.sfx("thud")
				room.shake(0.3)
				room.ring(cx, cy, 4, 26, "#ffffff", 0.2)
		"shove":
			vx = 0.0
			if st_t <= 0.0:
				set_state("idle", _idle_time())
		"phase":
			vx = 0.0
			if st_t <= 0.0:
				set_state("idle", 0.7)
	_phys(dt)

func begin_death() -> void:
	super.begin_death()
	vx = 0.0
	strike_sid = 0
	set_state("kneel", 1.5)

func _start_slash(i: int) -> void:
	slash = i
	_new_strike()
	set_state("slash", 0.15)
	n = i
	vx = face * 20.0 / 0.1                          # steps 20 px forward
	if i == 3:
		dmg = int(Game.dv("big_hit"))
	Audio.sfx("swipe", {"vol": 0.8})

func _throw_comments(ap: Vector2) -> void:
	var ox: float = cx + face * 6.0
	var oy: float = y + 8.0
	var base := atan2(ap.y - oy, ap.x - ox)
	for da in [-0.2618, 0.0, 0.2618]:
		var a: float = base + da
		room.shoot(ox, oy, cos(a) * COMMENT_SPEED * _sp(), sin(a) * COMMENT_SPEED * _sp(), {"kind": "comment", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 2.5, "dmg": 1})
	Audio.sfx("shoot")

# ---- hitboxes (the guest's body check reads these from the net fields) ----
func harmboxes() -> Array:
	var b: Array = [{"x": x + 2, "y": y + 2, "w": w - 4, "h": h - 3}]
	match st:
		"lunge":
			b.append({"x": x + w if face > 0.0 else x - 18.0, "y": y + 8, "w": 18.0, "h": 10.0, "sid": strike_sid, "catchable": true})
		"slash":
			b.append({"x": x + w if face > 0.0 else x - 20.0, "y": y + 6, "w": 20.0, "h": 14.0, "sid": strike_sid, "catchable": slash < 3})
		"riposte":
			if st_t > 0.4 - 0.12:
				b.append({"x": x + w - 2.0 if face > 0.0 else x - 20.0, "y": y + 4, "w": 22.0, "h": 16.0, "sid": strike_sid, "catchable": false})
		"shove":
			b.append({"x": cx - 22.0, "y": cy - 22.0, "w": 44.0, "h": 44.0})
	return b

# ---- drawing ----
func _pen(ci: CanvasItem, x0: float, y0: float, len_: float, vertical: bool) -> void:
	var ink := Color(INK)
	var pen := Color(PEN)
	if vertical:
		ci.draw_rect(Rect2(x0 - 1, y0 - 1, 4, len_ + 2), ink)
		ci.draw_rect(Rect2(x0, y0, 2, len_), pen)
	else:
		var px := x0 if face > 0.0 else x0 - len_
		ci.draw_rect(Rect2(px - 1, y0 - 1, len_ + 2, 4), ink)
		ci.draw_rect(Rect2(px, y0, len_, 2), pen)

func draw_boss_body(ci: CanvasItem) -> void:
	var ink := Color(INK)
	var hood := Color(HOODIE)
	var bx := floorf(x)
	var by := floorf(y)
	var crouch := 5.0 if st == "lunge_tel" else 0.0
	by += crouch
	var hh := h - crouch
	var f := face
	if st == "kneel":
		by += 8.0
		hh = h - 8.0
	if st == "stagger" and int(t * 20.0) % 2 == 0:
		bx += 1.0
	# outline, body, hood
	ci.draw_rect(Rect2(bx, by, w, hh), ink)
	ci.draw_rect(Rect2(bx + 1, by + 9, w - 2, hh - 9), hood)
	ci.draw_rect(Rect2(bx + 1, by + 1, w - 2, 9), hood)
	# pale face with dark square glasses (they look the way he looks)
	var fxp := bx + (6.0 if f > 0.0 else 2.0)
	ci.draw_rect(Rect2(fxp, by + 3, 6, 6), Color("#f4ede0"))
	ci.draw_rect(Rect2(fxp - (0.0 if f > 0.0 else 0.0), by + 4, 6, 3), ink)
	ci.draw_rect(Rect2(fxp + (3.0 if f > 0.0 else 2.0), by + 5, 1, 1), Color("#f4ede0"))
	# the pen: forward; raised in the stance and while tapping; swung in a slash
	var hand_y := by + 13.0
	var hand_x := bx + w - 2.0 if f > 0.0 else bx + 2.0
	match st:
		"review", "nitpick_gap", "phase":
			_pen(ci, hand_x + f * 2.0, by - 11.0, 16.0, true)
		"review_open":
			_pen(ci, hand_x, hand_y + 2.0, 12.0, false)
		"nitpick_tel":
			var up: bool = int(st_t * 10.0) % 2 == 0
			_pen(ci, hand_x + f * 2.0, by - (8.0 if up else 2.0), 14.0, true)
		"comments_tel":
			ci.draw_rect(Rect2(hand_x + f * 1.0, by - 3, 3, 5), Color("#f4ede0"))
			ci.draw_rect(Rect2(bx + 3, by + 14, 8, 2), Color("#3d4a66"))
		"shove_tel", "shove":
			ci.draw_rect(Rect2(bx - 6, by + 12, w + 12, 3), ink)
			ci.draw_rect(Rect2(bx - 5, by + 13, w + 10, 1), hood)
		"slash":
			var k := slash
			_pen(ci, hand_x, hand_y - 4.0 + float(k % 2) * 6.0, 18.0, false)
		"lunge", "riposte":
			_pen(ci, hand_x, hand_y - 1.0, 18.0, false)
		_:
			_pen(ci, hand_x, hand_y, 16.0, false)
	if st == "lunge_tel" and int(t * 24.0) % 2 == 0:            # the pen glints
		ci.draw_rect(Rect2(hand_x + f * 14.0 - 1, hand_y - 1, 3, 3), Color.WHITE)

func _bubble(ci: CanvasItem, text: String) -> void:
	var tw := PixelText.text_width(text, {"tiny": true})
	var bx := clampf(floorf(cx - tw / 2.0 - 3.0), 2.0, Game.W - tw - 8.0)
	var by := y - 22.0
	Gfx.panel(ci, bx, by, tw + 6.0, 12.0, "#f4ede0", INK)
	PixelText.draw_text(ci, text, bx + 3.0, by + 3.0, INK, {"tiny": true})

func draw_boss_overlay(ci: CanvasItem) -> void:
	if st == "lunge_tel" or st == "lunge":                   # the path of the lunge, dotted on the floor
		var x0 := cx + face * 10.0
		var i := 0
		while i < int(LUNGE_DIST):
			var col := Color(Game.COL.hazardHi) if (i / 8) % 2 == 0 else Color(Game.COL.hazard)
			ci.draw_rect(Rect2(floorf(x0 + face * i), Boss.FLOOR - 2.0, 2, 2), col)
			i += 8
	if st == "review":
		_bubble(ci, "CHANGES REQUESTED?")
	elif st == "phase":
		_bubble(ci, "Hmm. Let me take another look.")
	elif st == "kneel":
		_bubble(ci, "LGTM! Approved.")
	elif st == "riposte" and st_t > 0.28:
		PixelText.draw_text(ci, "!", cx - 1.0, y - 10.0, Game.COL.hazardHi, {"outline": INK})
	if st == "shove_tel":
		PixelText.draw_text(ci, "!", cx - 1.0, y - 10.0, Game.COL.hazardHi, {"outline": INK})

# ---- net ----
func net_fields() -> Array:
	return [STATES.find(st), roundi(st_t * 100.0), phase, strike_sid, roundi(hpf * 10.0), max_hp, 1 if (target != null and target.get("is_remote")) else 0, 1 if active else 0, 1 if dying else 0, slash]

func net_apply(f: Array) -> void:
	st = STATES[clampi(int(f[0]), 0, STATES.size() - 1)]
	st_t = f[1] / 100.0
	phase = int(f[2])
	strike_sid = int(f[3])
	hpf = f[4] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[5])
	active = int(f[7]) == 1
	dying = int(f[8]) == 1
	slash = int(f[9])
	passive = not active or dying
	dmg = int(Game.dv("big_hit")) if (st == "slash" and slash == 3) else 1
