class_name Look
extends Node
# Look (MVGN-02): the one owner of every look parameter of a NETWORK room (world 6): the mood's palette mixed over `stable`, blended toward a target
# with an eased 1.2 s fade, plus the small adjustments the rooms make while something happens (a boss phase, the chase, a verdict).
# Systems read `out` (never store look state of their own) and redraw when `rev` changes. Worlds 1-5 have no Look.
# Cosmetic only: it is fed from state both pages already have, never from room.rng, never synced.
# Palettes: assets/theme/moods.json (copied from docs/metroidvania/gfx-network-data/palettes.json by apply.py).

const DUR := 1.2
const NUM := ["bg_brightness", "bg_saturation", "glitch", "bloom", "gloss"]
const COL := ["sky_far", "sky_mid", "fog", "ambient", "accent_a", "accent_b"]

static var _pal := {}                    # palette name -> {key: Color / float / String}

var room: Room
var mood := "stable"                     # the target's palette name (or "stable_clean" ...)
var k := 1.0                             # how strongly it is mixed over `stable`
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

func set_target(mood_name: String, kk: float, immediate := false, dur := DUR) -> void:
	mood = mood_name
	k = kk
	_tgt = mixed(mood_name, kk)
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
	step(dt)

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
