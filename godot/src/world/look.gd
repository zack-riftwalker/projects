class_name Look
extends Node
# Look (MVGN-02): the one owner of every look parameter of a NETWORK room (world 6): the mood's palette mixed over `stable`, blended toward a target
# with an eased 1.2 s fade, plus the small adjustments the rooms make while something happens (a boss phase, the chase, a verdict).
# Systems read `out` (never store look state of their own) and redraw when `rev` changes. Worlds 1-5 have no Look.
# Cosmetic only: it is fed from state both pages already have, never from room.rng, never synced.
# Palettes: assets/theme/moods.json (copied from docs/metroidvania/gfx-network-data/palettes.json by apply.py).

const DUR := 1.2
const TERRAIN_GAIN := Color(1.65, 1.65, 1.7)   # tiles' modulate (above 1 brightens in the shader): the ambient darkens the lit world, the terrain must still be lighter than the backdrop
const NUM := ["bg_brightness", "bg_saturation", "glitch", "bloom", "gloss"]
const COL := ["sky_far", "sky_mid", "fog", "ambient", "accent_a", "accent_b"]

static var _pal := {}                    # palette name -> {key: Color / float / String}
static var lit_frame := -100               # the last frame a local NETWORK room ran (Gfx.tex uses the lit sprites only then)
static var _outline_mat: ShaderMaterial
static var _unshaded: CanvasItemMaterial
static var _unshaded_add: CanvasItemMaterial

# the creatures' outline (MVGN-14): the Entities node of a NETWORK room is a CanvasGroup; this shader reads the group's own picture (alpha) and draws a 1-px
# dark ring around what is drawn, and on High and Ultra brightens the edge pixels a little (a rim in the creature's own highlight colour)
const OUTLINE_SHADER := "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform vec4 dark : source_color = vec4(0.03, 0.04, 0.08, 1.0);
uniform float rim = 0.0;
void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE;
	vec4 c = texture(scr, SCREEN_UV);
	float n = max(max(texture(scr, SCREEN_UV + vec2(p.x, 0.0)).a, texture(scr, SCREEN_UV - vec2(p.x, 0.0)).a), max(texture(scr, SCREEN_UV + vec2(0.0, p.y)).a, texture(scr, SCREEN_UV - vec2(0.0, p.y)).a));
	if (c.a > 0.5) {
		float edge = 1.0 - min(min(texture(scr, SCREEN_UV + vec2(p.x, 0.0)).a, texture(scr, SCREEN_UV - vec2(p.x, 0.0)).a), min(texture(scr, SCREEN_UV + vec2(0.0, p.y)).a, texture(scr, SCREEN_UV - vec2(0.0, p.y)).a));
		COLOR = vec4(min(c.rgb * (1.0 + 0.55 * rim * edge) + 0.12 * rim * edge, vec3(1.0)), c.a);
	} else if (n > 0.5) {
		COLOR = vec4(dark.rgb, 1.0);
	} else {
		COLOR = vec4(0.0);
	}
}"

static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		var sh := Shader.new()
		sh.code = OUTLINE_SHADER
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = sh
	return _outline_mat

# the one way to keep an item out of the ambient and the lights (plan 3.4): a material with LIGHT_MODE_UNSHADED
static func unshaded(additive := false) -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_unshaded_add = CanvasItemMaterial.new()
		_unshaded_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_unshaded_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _unshaded_add if additive else _unshaded

var room: Room
var mood := "stable"                     # the target's palette name (or "stable_clean" ...)
var k := 1.0                             # how strongly it is mixed over `stable`
var post: PostChain
var stage: LookStage                     # the canvas's one CanvasModulate: this room claims it with its ambient while it is the local room
var out := {}                            # the values now, after the blend and the adjustments
var rev := 0                             # +1 for every step in which `out` changed
var ca_pulse := 0.0                      # chromatic aberration strength now (0 at rest; pulse_ca sets it, it fades out over its length)
var _ca_peak := 0.0
var _ca_t := 0.0
var _ca_len := 0.12
var adj := {"ambient_mul": 1.0, "bloom_add": 0.0, "accent_b": Color(0, 0, 0, 0), "accent_b_k": 0.0, "ambient": Color(0, 0, 0, 0), "ambient_k": 0.0}
var _from := {}
var _tgt := {}
var _u := 1.0
var _dur := DUR

static func palettes() -> Dictionary:
	if not _pal.is_empty():
		return _pal
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://assets/theme/moods.json"))
	for name in raw:
		var p := {}
		for key in raw[name]:
			var v = raw[name][key]
			if key == "fog":
				var c := Color(String(v[0]))
				c.a = float(v[1])
				p[key] = c
			elif typeof(v) == TYPE_STRING and String(v).begins_with("#"):
				p[key] = Color(String(v))
			else:
				p[key] = v
		_pal[name] = p
	return _pal

# the mood a room shows: its rooms.json `mood` (stable 1 when it has none); `stable` becomes `stable_clean` once the FIREWALL is down (MVGN-12)
static func resolve(def: Dictionary) -> Array:
	var m = def.get("mood", ["stable", 1])
	var name := String(m[0])
	if name == "stable" and Game.flag("boss:FIREWALL"):
		name = "stable_clean"
	return [name, float(m[1])]

# the palette `name` mixed over `stable` by kk
static func mixed(name: String, kk: float) -> Dictionary:
	var pal := palettes()
	var a: Dictionary = pal["stable"] if name != "stable_clean" else pal["stable_clean"]
	var b: Dictionary = pal.get(name, pal["stable"])
	var d := {}
	for key in COL:
		d[key] = (a[key] as Color).lerp(b[key] as Color, kk)
	for key in NUM:
		d[key] = lerpf(float(a[key]), float(b[key]), kk)
	d["particles"] = b.particles if kk >= 0.5 else a.particles
	return d

func _enter_tree() -> void:
	if stage == null and room != null:
		stage = LookStage.of(room)
		post = PostChain.of(room)

func set_target(mood_name: String, kk: float, immediate := false, dur := DUR) -> void:
	mood = mood_name
	k = kk
	_tgt = mixed(mood_name, kk)
	var old_lut := lut_to if _u >= 1.0 or lut_from == null else (lut_to if _u > 0.5 else lut_from)
	lut_to = lut_for(mood_name, kk)
	lut_from = lut_to if immediate or _from.is_empty() or old_lut == null else old_lut
	if immediate or _from.is_empty():
		_from = _tgt.duplicate()
		_u = 1.0
	else:
		_from = _cur()
		_u = 0.0
		_dur = maxf(dur, 0.01)
	_apply()

# a door transition: start from where the room we came from is now, then blend to this room's own mood
func inherit(other: Look) -> void:
	_from = other._cur()
	_u = 1.0
	_tgt = _from.duplicate()
	lut_to = other.lut_to if other._u >= 1.0 or other._u > 0.5 else other.lut_from
	lut_from = lut_to
	_apply()

func reached() -> bool:
	return _u >= 1.0

# the blend alone (without the adjustments)
func _cur() -> Dictionary:
	if _u >= 1.0:
		return _tgt.duplicate()
	var e := _u * _u * (3.0 - 2.0 * _u)
	var d := {}
	for key in COL:
		d[key] = (_from[key] as Color).lerp(_tgt[key] as Color, e)
	for key in NUM:
		d[key] = lerpf(float(_from[key]), float(_tgt[key]), e)
	d["particles"] = _tgt.particles
	return d

# adjustments the rooms ask for (all of them blended by the room itself with Game.damp, so Look only applies them)
func _apply() -> void:
	var d := _cur()
	var amb: Color = d.ambient
	amb = amb.lerp(adj.ambient, float(adj.ambient_k))
	var m := float(adj.ambient_mul)
	d.ambient = Color(amb.r * m, amb.g * m, amb.b * m, 1.0)
	d.accent_b = (d.accent_b as Color).lerp(adj.accent_b, float(adj.accent_b_k))
	d.bloom = float(d.bloom) + float(adj.bloom_add)
	d.glitch = float(d.glitch)
	if out.is_empty() or d != out:
		out = d
		rev += 1

func step(dt: float) -> void:
	if _u < 1.0:
		_u = minf(1.0, _u + dt / _dur)
	if _ca_t > 0.0:
		_ca_t = maxf(0.0, _ca_t - dt)
		ca_pulse = _ca_peak * _ca_t / _ca_len
	_apply()

func _process(dt: float) -> void:
	if room == null or not room.is_local:
		return
	follow_room(dt)
	step(dt)
	lit_frame = Engine.get_process_frames()
	outline_material().set_shader_parameter("dark", out.sky_far)
	outline_material().set_shader_parameter("rim", 1.0 if Game.gfx_tier >= 1 else 0.0)
	if stage != null:
		stage.claim(out.ambient)
	if post != null:
		post.claim(self, room.time)

# a new adjustment value; Look is the only place that keeps them (so a room never stores look state)
func set_adj(key: String, v) -> void:
	adj[key] = v
	_apply()

# a short chromatic-aberration pulse (a lost packet, a hit, a phase change); the post chain reads ca_pulse; Reduce flashing swallows it there
func pulse_ca(v: float, length := 0.12) -> void:
	if v >= ca_pulse:
		_ca_peak = v
		_ca_len = length
		_ca_t = length
		ca_pulse = v

# ---------------------------------------------------------------- the colour grade (LUT) of the post chain
# One 16x16x16 LUT as a 256x16 strip (x = blue * 16 + red, y = green) per palette state, built from the palette with `grade` and cached; Look cross-fades
# the LUT of the state it came from with the LUT of the state it goes to. tools/godot/make-luts.gd writes the same LUTs of the pure palettes as PNGs.
static var _luts := {}                   # "mood:k" -> ImageTexture
var lut_to: Texture2D
var lut_from: Texture2D

# lift the shadows toward sky_far, tint the mid tones toward the ambient, leave the highlights alone (the catchable yellow stays yellow)
static func grade(c: Color, sky_far: Color, ambient: Color) -> Color:
	var l := c.get_luminance()
	var sh := 1.0 - smoothstep(0.0, 0.35, l)
	var mid := smoothstep(0.08, 0.3, l) * (1.0 - smoothstep(0.42, 0.65, l))
	var r := c.lerp(Color(sky_far.r * 2.0 + c.r * 0.5, sky_far.g * 2.0 + c.g * 0.5, sky_far.b * 2.0 + c.b * 0.5), 0.22 * sh)
	var tint := Color(lerpf(1.0, ambient.r * 1.3, 0.4 * mid), lerpf(1.0, ambient.g * 1.3, 0.4 * mid), lerpf(1.0, ambient.b * 1.3, 0.4 * mid))
	return Color(clampf(r.r * tint.r, 0.0, 1.0), clampf(r.g * tint.g, 0.0, 1.0), clampf(r.b * tint.b, 0.0, 1.0), 1.0)

static func lut_image(sky_far: Color, ambient: Color) -> Image:
	var img := Image.create(256, 16, false, Image.FORMAT_RGB8)
	for bi in range(16):
		for gi in range(16):
			for ri in range(16):
				img.set_pixel(bi * 16 + ri, gi, grade(Color(float(ri) / 15.0, float(gi) / 15.0, float(bi) / 15.0), sky_far, ambient))
	return img

static func lut_for(mood_name: String, kk: float) -> Texture2D:
	var key := "%s:%.2f" % [mood_name, kk]
	if not _luts.has(key):
		var m := mixed(mood_name, kk)
		_luts[key] = ImageTexture.create_from_image(lut_image(m.sky_far, m.ambient))
	return _luts[key]

# [from, to, mix]: set_target / inherit keep the two ends, the eased blend progress is the mix
func lut_pair() -> Array:
	if lut_to == null:
		lut_to = lut_for(mood, k)
		lut_from = lut_to
	var e := _u * _u * (3.0 - 2.0 * _u) if _u < 1.0 else 1.0
	return [lut_from, lut_to, e]

# ---------------------------------------------------------------- in-room shifts (MVGN-08): read from the state both pages already have
const SIREN := Color("#FF6B00")
var verdict_until := -1.0
var shift := ""                          # the palette the room's own state asks for now ("" = the room's mood from rooms.json)

func follow_room(dt: float) -> void:
	if room == null:
		return
	var id: String = room.id
	var want := ""
	var ambient_mul := 1.0
	var bloom_add := 0.0
	# the fight rooms: the boss's phase 3
	var b = room.boss
	var p3: bool = b != null and is_instance_valid(b) and not b.get("gone") and int(b.get("phase")) == 3 and not b.get("dying")
	var fighting: bool = room.fight.state in ["intro", "active"] and b != null and is_instance_valid(b)
	if id == "N09" and fighting:
		ambient_mul = 0.45                                          # the crawler's lair goes dark for the fight (the lights carry it: eyes, beams)
	if p3:
		if id == "N15":
			want = "heat_p3"
		elif id == "N09" or id == "N22":
			bloom_add = 0.15
			ambient_mul *= 0.9
	if id == "N22" and b != null and is_instance_valid(b) and b.get("plan") is Dictionary and not b.plan.is_empty() and String(b.plan.id) == "verdict" and String(b.plan.ph) == "active":
		verdict_until = room.time + 0.5
	if room.time < verdict_until:
		bloom_add += 0.3                                            # the verdict moment: a flash of bloom
	ambient_mul = maxf(ambient_mul, 0.35)                           # the arenas never go darker than 35 %
	if want != shift:
		shift = want
		var mm := Look.resolve(room.def)
		if want == "":
			set_target(mm[0], mm[1], false, 2.0)
		else:
			set_target(want, 1.0, false, 2.0)
		Game.dlog("look %s" % (want if want != "" else mm[0]))
	# N17: the RST line is running: the sky and the lights go siren orange, pulsing (no pulse with Reduce flashing)
	var chase_on: bool = id == "N17" and room.ch_t0 >= 0.0
	var pulse := 1.0 if Game.reduce_flash else 1.0 + 0.15 * sin(TAU * room.time / 1.2)
	adj.accent_b_k = Game.damp(float(adj.accent_b_k), 1.0 if chase_on else 0.0, 10.0 if chase_on else 2.5, dt)
	adj.accent_b = SIREN
	adj.ambient = SIREN
	adj.ambient_k = Game.damp(float(adj.ambient_k), 0.35 * pulse if chase_on else 0.0, 10.0 if chase_on else 2.5, dt)
	adj.ambient_mul = Game.damp(float(adj.ambient_mul), ambient_mul, 5.0, dt)
	adj.bloom_add = Game.damp(float(adj.bloom_add), bloom_add, 5.0, dt)
