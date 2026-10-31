class_name RaceBody
extends RefCounted
# RaceBody: the drawing of TICK and TOCK, RACE CONDITION's two bronze bell-strikers. Since Zakaria's play-test (2026-10-31: "I drew the boss in
# pixels and it looks nothing like it") the bodies are his own pixel art: the frames are cut from 17-race-data/ref/tick_tock.webp and
# sheet_keys.webp by tools/godot/race_sprites.py (godot/assets/sprites/race_tick*.png, race_tock*.png, race_sprites.json). Before, they were
# ~20 rectangles drawn every frame.
# Static, no state: the boss and the hall call `draw(ci, o)` with where it stands and what it does; the pair after the fight uses it too
# (BelfryHall). One textured rect per body per frame (two while phase 2's heat fades in), plus the lit eye and the chest clock's hand.
# Poses (one frame each, POSES in the json): idle, crouch, hop, up (hammer raised), strike (bowing at the waist), stuck (the hammer in the floor),
# dazed, down (wound down, lying), kneel (winding its partner), swing (the rope), hang, bow (the pair after the fight).

const TRIM := [Color("#ff4a3a"), Color("#2ee6d6")]
const INK := Color("#120c10")

static var _tex: Array = []          # [who][0 plain, 1 hot, 2 flash]
static var _meta: Dictionary = {}
static var _pose_i: Dictionary = {}

static func _load() -> void:
	if not _tex.is_empty():
		return
	for n in ["race_tick", "race_tock"]:
		_tex.append([load("res://assets/sprites/%s.png" % n), load("res://assets/sprites/%s_hot.png" % n), load("res://assets/sprites/%s_flash.png" % n)])
	_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/race_sprites.json"))
	var poses: Array = _meta.poses
	for i in range(poses.size()):
		_pose_i[String(poses[i])] = i

static func frame_size() -> Vector2:
	_load()
	return Vector2(float(_meta.frame[0]), float(_meta.frame[1]))

static func has_pose(name: String) -> bool:
	_load()
	return _pose_i.has(name)

# where the eye is (room pixels) for a body standing at (x, y): the READ's beam starts there
static func eye_at(who: int, pose: String, x: float, y: float, face: float) -> Vector2:
	_load()
	var fr: Dictionary = _meta.who[str(who)].frames[int(_pose_i.get(pose, 0))]
	var eye: Array = fr.eye if not (fr.eye as Array).is_empty() else _meta.who[str(who)].frames[0].eye
	if eye.is_empty():
		return Vector2(x, y - 46.0)
	var f := 1.0 if face >= 0.0 else -1.0
	return Vector2(floorf(x + 0.5) + (float(eye[0][0]) + 0.5 - float(_meta.frame[0]) * 0.5) * f, floorf(y + 0.5) + float(eye[0][1]) + 0.5 - float(_meta.foot_y))

# o: {who 0 TICK / 1 TOCK, x, y (feet), face (+1 right), pose, t (animation seconds), hot 0..1, eye (bool), dial (0..11 chest clock), a (alpha),
#     flash (bool), still (bool: no breathing)}
static func draw(ci: CanvasItem, o: Dictionary) -> void:
	_load()
	var who: int = clampi(int(o.get("who", 0)), 0, 1)
	var pose: String = String(o.get("pose", "idle"))
	var fi: int = int(_pose_i.get(pose, 0))
	var face: float = 1.0 if float(o.get("face", 1.0)) >= 0.0 else -1.0
	var t: float = float(o.get("t", 0.0))
	var a: float = float(o.get("a", 1.0))
	var fw: float = float(_meta.frame[0])
	var fh: float = float(_meta.frame[1])
	var foot: float = float(_meta.foot_y)
	var bob := 0.0
	if pose == "idle" and not bool(o.get("still", false)):
		bob = 1.0 if sin(t * 2.0) > 0.6 else 0.0                       # (breathing: a pixel down now and then)
	elif pose == "dazed":
		bob = 1.0 if sin(t * 5.0) > 0.0 else 0.0
	var root := Transform2D(0.0, Vector2(floorf(float(o.x) + 0.5), floorf(float(o.y) + 0.5) + bob)).scaled_local(Vector2(face, 1.0))
	ci.draw_set_transform_matrix(root)
	var dst := Rect2(-fw * 0.5, -foot, fw, fh)
	var src := Rect2(float(fi) * fw, 0.0, fw, fh)
	var hot: float = clampf(float(o.get("hot", 0.0)), 0.0, 1.0)
	var set: Array = _tex[who]
	if bool(o.get("flash", false)):
		ci.draw_texture_rect_region(set[2], dst, src, Color(1, 1, 1, a))
	else:
		if hot < 1.0:
			ci.draw_texture_rect_region(set[0], dst, src, Color(1, 1, 1, a))
		if hot > 0.0:
			ci.draw_texture_rect_region(set[1], dst, src, Color(1, 1, 1, a * hot))
	var fr: Dictionary = _meta.who[str(who)].frames[fi]
	# the chest clock's hand: the READ ticks it (both clocks show the same number for the double write)
	if fr.clock != null and pose != "down":
		var c := Vector2(float(fr.clock[0]) - fw * 0.5, float(fr.clock[1]) - foot)
		var ang := TAU * float(int(o.get("dial", 0)) % 12) / 12.0
		var tip := c + Vector2(roundf(sin(ang) * 1.4), roundf(-cos(ang) * 1.4))
		ci.draw_rect(Rect2(c, Vector2.ONE), Color(INK, a))
		ci.draw_rect(Rect2(tip, Vector2.ONE), Color(INK, a))
	# the eye: dead in the frames; lit for the READ (a bright point and a glow in its colour)
	if bool(o.get("eye", false)) and pose != "down":
		var eye: Array = fr.eye
		if eye.is_empty():
			eye = _meta.who[str(who)].frames[0].eye
		var ec: Color = TRIM[who]
		if not eye.is_empty():
			var e0 := Vector2(float(eye[0][0]) - fw * 0.5, float(eye[0][1]) - foot)
			ci.draw_circle(e0 + Vector2(0.5, 0.5), 4.5, Color(ec.r, ec.g, ec.b, 0.28 * a))
			for p in eye:
				ci.draw_rect(Rect2(float(p[0]) - fw * 0.5, float(p[1]) - foot, 1.0, 1.0), Color(ec.lerp(Color.WHITE, 0.25), a))
			ci.draw_rect(Rect2(e0, Vector2.ONE), Color(1, 1, 1, a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
