class_name RaceBody
extends RefCounted
# RaceBody: the drawing of TICK and TOCK, RACE CONDITION's two bronze bell-strikers (docs/metroidvania/17-race-condition.md, 17-race-data/ref/tick_tock.webp,
# sheet_keys.webp). A 32 x 48 body drawn from primitives: dark bronze with gold rivets and edges, a thin red (TICK) / cyan (TOCK) trim, TOCK's cyan headband and
# curly bronze beard, a torn tan sheepskin skirt, a big wind-up key on the back, a small clock on the chest. Static, no state: the boss and the hall call
# `draw(ci, o)` with where it stands and what it does; the pair after the fight uses it too (BelfryHall).
# Poses: idle, crouch, hop, up (hammer raised), strike (bowing at the waist), stuck (the hammer in the floor), dazed, down (wound down, lying), kneel (winding its
# partner), swing (the rope), bow (the pair after the fight).

const INK := Color("#120c10")
const BRONZE := Color("#3b2a26")
const BRONZE_HI := Color("#5a4036")
const BRONZE_LO := Color("#26191a")
const GOLD := Color("#d6a43e")
const GOLD_HI := Color("#f6d878")
const GOLD_LO := Color("#8a6420")
const SKIRT := Color("#b99a6c")
const SKIRT_LO := Color("#8d7249")
const HAMMER := Color("#35323c")
const HAMMER_HI := Color("#5a566a")
const WOOD := Color("#6b4a32")
const TRIM := [Color("#ff4a3a"), Color("#2ee6d6")]
const HOT := Color("#e0472c")
const BEARD := Color("#a8782f")
const BEARD_HI := Color("#d6a44a")
const PAPER := Color("#e8dcc0")

# a pose's numbers: bow (rad: the upper body leans forward at the waist), crouch (px lower), hand (px from the shoulder), hang (rad: the hammer's direction
# from the hand; 0 right, -PI/2 up, PI/2 down), tuck (legs pulled up)
static func pose_of(name: String, t: float) -> Dictionary:
	match name:
		"crouch":
			return {"bow": 0.25, "crouch": 8.0, "hand": Vector2(6, -2), "hang": -2.0, "tuck": 0.0}
		"hop":
			return {"bow": 0.1, "crouch": 0.0, "hand": Vector2(6, -6), "hang": -1.9, "tuck": 7.0}
		"up":
			return {"bow": -0.08, "crouch": 0.0, "hand": Vector2(3, -14), "hang": -1.35 + 0.05 * sin(t * 18.0), "tuck": 0.0}
		"strike":
			return {"bow": 0.55, "crouch": 2.0, "hand": Vector2(12, 8), "hang": 1.05, "tuck": 0.0}
		"stuck":
			return {"bow": 0.38 + 0.02 * sin(t * 30.0), "crouch": 3.0, "hand": Vector2(11, 12), "hang": 1.3, "tuck": 0.0}
		"dazed":
			return {"bow": 0.18 + 0.1 * sin(t * 5.0), "crouch": 1.0, "hand": Vector2(5, 9), "hang": 0.9, "tuck": 0.0}
		"kneel":
			return {"bow": 0.45, "crouch": 12.0, "hand": Vector2(9, 9), "hang": 1.5, "tuck": 0.0}
		"swing":
			return {"bow": -0.2, "crouch": 0.0, "hand": Vector2(9, -6), "hang": -0.5, "tuck": 0.0}
		"bow":
			return {"bow": 0.85, "crouch": 3.0, "hand": Vector2(5, 9), "hang": 1.45, "tuck": 0.0}
	return {"bow": 0.012 * sin(t * 2.0), "crouch": 0.0, "hand": Vector2(6, -3), "hang": -2.2, "tuck": 0.0}

# o: {who 0 TICK / 1 TOCK, x, y (feet), face (+1 right), pose, t (animation seconds), hot 0..1, eye (bool), dial (0..11 chest clock), a (alpha)}
static func draw(ci: CanvasItem, o: Dictionary) -> void:
	var face: float = float(o.get("face", 1.0))
	var pose: String = String(o.get("pose", "idle"))
	var t: float = float(o.get("t", 0.0))
	var root := Transform2D(0.0, Vector2(floorf(float(o.x) + 0.5), floorf(float(o.y) + 0.5)))
	root = root.scaled_local(Vector2(face, 1.0))
	_flash = 1.0 if bool(o.get("flash", false)) else 0.0
	var p: Dictionary
	var asleep := false
	if pose == "down":
		root = root * Transform2D(-PI * 0.5, Vector2(0.0, -8.0))              # on its back, head to the back side
		p = pose_of("idle", t)
		p.hand = Vector2(2, 6)
		p.hang = 1.2
		asleep = true
	else:
		p = pose_of(pose, t)
	_figure(ci, root, int(o.get("who", 0)), p, t, float(o.get("hot", 0.0)), float(o.get("a", 1.0)), bool(o.get("eye", false)) and not asleep, int(o.get("dial", 0)), asleep or bool(o.get("still", false)), pose == "kneel", pose == "dazed")
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static var _flash := 0.0

static func _k(c: Color, hot: float, a: float) -> Color:
	var k := c.lerp(HOT, hot * 0.55)
	if _flash > 0.0:
		k = k.lerp(Color.WHITE, 0.75)
	k.a = a
	return k

static func _r(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), c)

static func _figure(ci: CanvasItem, root: Transform2D, who: int, p: Dictionary, t: float, hot: float, a: float, eye: bool, dial: int, asleep: bool, kneel: bool, dazed: bool) -> void:
	var crouch: float = float(p.crouch)
	var tuck: float = float(p.tuck)
	var bow: float = float(p.bow)
	var bz := _k(BRONZE, hot, a)
	var bz_hi := _k(BRONZE_HI, hot, a)
	var bz_lo := _k(BRONZE_LO, hot, a)
	var gold := _k(GOLD, 0.0, a)
	var gold_hi := _k(GOLD_HI, 0.0, a)
	var gold_lo := _k(GOLD_LO, 0.0, a)
	var ink := INK
	ink.a = a
	var trim: Color = TRIM[who]
	trim.a = a
	var wide := 1.0 if who == 1 else 0.0                                          # TOCK is the stockier one
	var hip_y := -18.0 + crouch * 0.5 + tuck * 0.5
	ci.draw_set_transform_matrix(root)
	# ---- legs: the lower body does not bow
	for li in range(2):
		var lx: float = -7.0 - wide if li == 0 else 2.0 + wide * 0.5
		var top := hip_y
		var bot := 0.0 - tuck * 0.9
		if kneel and li == 1:                                                    # the front leg is folded flat
			_r(ci, lx - 1.0, -7.0, 14.0, 8.0, ink)
			_r(ci, lx, -6.0, 12.0, 6.0, bz)
			_r(ci, lx, -6.0, 12.0, 1.0, gold_lo)
			_r(ci, lx + 9.0, -7.0, 3.0, 8.0, gold)
			continue
		var h := bot - top
		_r(ci, lx - 1.0, top, 7.0 + wide, h + 1.0, ink)
		_r(ci, lx, top, 5.0 + wide, h, bz)
		_r(ci, lx, top, 1.0, h, bz_hi)
		_r(ci, lx + 4.0 + wide, top, 1.0, h, bz_lo)
		_r(ci, lx, top + h * 0.5 - 1.0, 5.0 + wide, 3.0, gold)                 # the knee rivet
		_r(ci, lx + 1.0, top + h * 0.5 - 1.0, 2.0, 1.0, gold_hi)
		_r(ci, lx + 3.0, top + 2.0, 1.0, maxf(h * 0.4, 1.0), trim)
		_r(ci, lx - 1.0, bot - 3.0, 8.0 + wide, 4.0, ink)                       # the boot
		_r(ci, lx, bot - 2.0, 6.0 + wide, 2.0, bz_lo)
		_r(ci, lx - 1.0, bot - 1.0, 8.0 + wide, 1.0, gold)
	# ---- the skirt: torn sheepskin
	var skc := SKIRT
	skc.a = a
	var skl := SKIRT_LO
	skl.a = a
	var sk := PackedVector2Array([Vector2(-10.0 - wide, hip_y - 4.0), Vector2(10.0 + wide, hip_y - 4.0), Vector2(11.0 + wide, hip_y + 4.0), Vector2(8.0, hip_y + 7.0), Vector2(5.0, hip_y + 4.0), Vector2(2.0, hip_y + 8.0), Vector2(-2.0, hip_y + 4.0), Vector2(-5.0, hip_y + 7.0), Vector2(-9.0, hip_y + 4.0), Vector2(-11.0 - wide, hip_y + 6.0)])
	ci.draw_colored_polygon(sk, skc)
	_r(ci, -9.0, hip_y - 1.0, 18.0, 1.0, skl)
	_r(ci, -2.0, hip_y + 1.0, 1.0, 4.0, skl)
	_r(ci, 4.0, hip_y + 1.0, 1.0, 3.0, skl)
	# ---- the upper body: rotated at the waist, lowered by the crouch
	ci.draw_set_transform_matrix(root * Transform2D(bow, Vector2(0.0, hip_y - 2.0)))
	var tw := 9.0 + wide
	# the back arm, then the key behind the torso
	_r(ci, -tw - 2.0, -12.0, 4.0, 11.0, ink)
	_r(ci, -tw - 1.0, -11.0, 3.0, 9.0, bz)
	_r(ci, -tw - 1.0, -3.0, 3.0, 3.0, gold)
	var spin := 0.0 if (asleep or dazed) else (t * (9.0 if kneel else 2.2))
	var kc := cos(spin)
	for ky in [-3.5, 3.5]:
		var yy: float = -13.0 + float(ky) * kc
		ci.draw_circle(Vector2(-tw - 5.0, yy), 3.0, ink)
		ci.draw_circle(Vector2(-tw - 5.0, yy), 2.0, gold)
		ci.draw_circle(Vector2(-tw - 5.0, yy), 0.9, bz_lo)
	_r(ci, -tw - 3.0, -14.0, 3.0, 2.0, gold_lo)
	# the torso
	_r(ci, -tw - 1.0, -15.0, tw * 2.0 + 2.0, 17.0, ink)
	_r(ci, -tw, -14.0, tw * 2.0, 15.0, bz)
	_r(ci, -tw, -14.0, 2.0, 15.0, bz_hi)
	_r(ci, tw - 2.0, -14.0, 2.0, 15.0, bz_lo)
	_r(ci, -tw, -14.0, tw * 2.0, 2.0, gold)                                      # the gold shoulder line
	_r(ci, -tw + 2.0, -13.0, tw * 2.0 - 4.0, 1.0, gold_hi)
	_r(ci, -tw, 0.0, tw * 2.0, 2.0, gold)                                        # the belt
	_r(ci, -tw, -3.0, tw * 2.0, 1.0, trim)
	_r(ci, -tw + 2.0, -10.0, 1.0, 6.0, trim)
	_r(ci, tw - 3.0, -10.0, 1.0, 6.0, trim)
	if hot > 0.3:
		for sx in [-5.0, 3.0]:
			_r(ci, sx, -9.0, 1.0, 5.0, Color(1.0, 0.35, 0.2, a))
		for sy in [-12.0, -4.0]:                                                  # springs out of the seams
			ci.draw_polyline(PackedVector2Array([Vector2(-tw - 1.0, sy), Vector2(-tw - 3.0, sy - 1.0), Vector2(-tw - 1.0, sy - 2.0), Vector2(-tw - 3.0, sy - 3.0)]), gold_hi, 1.0)
	# the chest clock
	ci.draw_circle(Vector2(1.0, -8.0), 4.5, ink)
	ci.draw_circle(Vector2(1.0, -8.0), 3.6, Color(PAPER.r, PAPER.g, PAPER.b, a))
	var ang := TAU * float(dial) / 12.0
	ci.draw_line(Vector2(1.0, -8.0), Vector2(1.0 + sin(ang) * 2.8, -8.0 - cos(ang) * 2.8), ink, 1.0)
	ci.draw_line(Vector2(1.0, -8.0), Vector2(1.0, -10.4), ink, 1.0)
	# the head
	_r(ci, -5.0, -24.0, 11.0, 10.0, ink)
	_r(ci, -4.0, -22.0, 9.0, 8.0, bz)
	_r(ci, -4.0, -22.0, 1.0, 8.0, bz_hi)
	_r(ci, -5.0, -26.0, 11.0, 4.0, ink)                                          # the cap
	_r(ci, -4.0, -25.0, 9.0, 3.0, bz)
	_r(ci, -2.0, -28.0, 5.0, 3.0, ink)
	_r(ci, -1.0, -27.0, 3.0, 2.0, bz)
	_r(ci, 0.0, -29.0, 2.0, 2.0, gold)                                           # the knob on the cap
	_r(ci, -5.0, -23.0, 11.0, 1.0, trim if who == 0 else Color(TRIM[1].r, TRIM[1].g, TRIM[1].b, a))
	if who == 1:
		_r(ci, -5.0, -24.0, 11.0, 2.0, TRIM[1])                                  # TOCK's cyan headband
		_r(ci, -5.0, -23.0, 11.0, 1.0, Color(0.78, 1.0, 0.97, a))
		_r(ci, -3.0, -14.0, 8.0, 5.0, ink)                                       # the curly bronze beard
		_r(ci, -2.0, -14.0, 7.0, 4.0, Color(BEARD.r, BEARD.g, BEARD.b, a))
		for bx in [-1.0, 1.0, 3.0, 5.0]:
			_r(ci, bx, -12.0, 1.0, 1.0, Color(BEARD_HI.r, BEARD_HI.g, BEARD_HI.b, a))
		_r(ci, -1.0, -9.0, 5.0, 1.0, Color(BEARD.r, BEARD.g, BEARD.b, a))
	# the eye: a bright point and a glow while it is lit (the READ cue), a dead brown one otherwise
	var ec: Color = TRIM[who]
	if eye:
		ci.draw_circle(Vector2(3.0, -19.0), 4.5, Color(ec.r, ec.g, ec.b, 0.28 * a))
		_r(ci, 2.0, -20.0, 3.0, 2.0, Color(1.0, 1.0, 1.0, a))
		_r(ci, 2.0, -20.0, 2.0, 2.0, ec)
	elif asleep:
		_r(ci, 3.0, -19.0, 2.0, 1.0, Color(0.2, 0.12, 0.1, a))
	else:
		_r(ci, 3.0, -20.0, 2.0, 2.0, Color(ec.r * 0.55, ec.g * 0.55, ec.b * 0.55, a))
	# the front arm and the hammer
	var sh := Vector2(tw - 1.0, -12.0)
	var hand: Vector2 = sh + Vector2(p.hand)
	var elbow := sh.lerp(hand, 0.5) + Vector2(0.0, 3.0)
	ci.draw_line(sh, elbow, ink, 5.0)
	ci.draw_line(elbow, hand, ink, 5.0)
	ci.draw_line(sh, elbow, bz, 3.0)
	ci.draw_line(elbow, hand, bz, 3.0)
	ci.draw_circle(elbow, 2.0, gold)
	ci.draw_rect(Rect2(sh.x - 2.0, sh.y - 1.0, 5.0, 3.0), gold)                  # the pauldron
	var hang: float = float(p.hang)
	var dirv := Vector2(cos(hang), sin(hang))
	var perp := Vector2(-dirv.y, dirv.x)
	var tip := hand + dirv * 17.0
	ci.draw_line(hand - dirv * 3.0, tip, ink, 4.0)
	ci.draw_line(hand - dirv * 3.0, tip, Color(WOOD.r, WOOD.g, WOOD.b, a), 2.0)
	var hc := tip + dirv * 1.0
	var head := PackedVector2Array([hc - dirv * 4.0 + perp * 5.0, hc + dirv * 4.0 + perp * 5.0, hc + dirv * 4.0 - perp * 5.0, hc - dirv * 4.0 - perp * 5.0])
	var head_ink := PackedVector2Array([hc - dirv * 5.0 + perp * 6.0, hc + dirv * 5.0 + perp * 6.0, hc + dirv * 5.0 - perp * 6.0, hc - dirv * 5.0 - perp * 6.0])
	ci.draw_colored_polygon(head_ink, ink)
	ci.draw_colored_polygon(head, Color(HAMMER.r, HAMMER.g, HAMMER.b, a))
	ci.draw_colored_polygon(PackedVector2Array([hc - dirv * 4.0 + perp * 5.0, hc + dirv * 4.0 + perp * 5.0, hc + dirv * 4.0 + perp * 2.0, hc - dirv * 4.0 + perp * 2.0]), Color(HAMMER_HI.r, HAMMER_HI.g, HAMMER_HI.b, a))
	ci.draw_line(hc + dirv * 4.0 + perp * 5.0, hc + dirv * 4.0 - perp * 5.0, gold, 2.0)           # the gold bands of the head
	ci.draw_line(hc - dirv * 4.0 + perp * 5.0, hc - dirv * 4.0 - perp * 5.0, gold, 2.0)
	ci.draw_circle(hand, 2.5, ink)
	ci.draw_circle(hand, 1.7, gold)
