extends Node
# Game: constants shared by everything, flags read once from the URL, and the helpers every port of the JS code needs.

const W := 384
const H := 216
const T := 16
const STEP := 1.0 / 60.0

# G.COL from the current game (js/art.js)
const COL := {
	"ink": "#1b1226", "night": "#0d0a12", "paper": "#f4ede0", "dim": "#8d8798",
	"clawd": "#d77757", "clawdHi": "#f0a184", "clawdLo": "#a8512f", "eye": "#1a1213",
	"gold": "#f2c14e", "goldHi": "#fff1b8", "goldLo": "#b9792a",
	"hazard": "#ff4f6d", "hazardHi": "#ffd0d6", "hazardLo": "#a8183a",
	"ok": "#7fd08a", "okHi": "#d6ffd0", "bad": "#ff5d5d", "mint": "#58f0c8", "sky": "#7cc4ff",
}

# the tools Clawd owns (phase 1 test build: bash only)
var tools := {"bash": true, "sudo": false, "agents": false, "opus": false}
var shake_opt := 1.0
var low_fx := false          # G.save.data.opt.min

# query options: ?debug ?fps30 ?mute ?selftest (web) or user args (native)
var debug := false
var fps30 := false
var mute := false
var selftest := false
var test_name := ""
var shot_path := ""
var demo := false
var build_text := "dev"
var touch_seen := false

func _ready() -> void:
	var q := ""
	if OS.has_feature("web"):
		q = str(JavaScriptBridge.eval("location.search"))
	else:
		q = "?" + "&".join(OS.get_cmdline_user_args())
	for part in q.trim_prefix("?").split("&", false):
		var kv := part.split("=", false, 1)
		var k := kv[0].trim_prefix("--")
		var v := kv[1] if kv.size() > 1 else ""
		match k:
			"debug": debug = true
			"fps30": fps30 = true
			"mute": mute = true
			"selftest": selftest = true
			"test": test_name = v
			"shot": shot_path = v
			"demo": demo = true
	if fps30:
		Engine.max_fps = 30
	if FileAccess.file_exists("res://build.txt"):
		build_text = FileAccess.get_file_as_string("res://build.txt").strip_edges()

# ---- math helpers (exact ports of G.* in js/core.js) ----
static func approach(v: float, target: float, step: float) -> float:
	return minf(v + step, target) if v < target else maxf(v - step, target)

static func damp(a: float, b: float, rate: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * dt))

static func sign_of(v: float) -> float:
	return -1.0 if v < 0.0 else (1.0 if v > 0.0 else 0.0)

static func overlap(a, b) -> bool:
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y

# JS ToInt32 of a double
static func _i32(f: float) -> int:
	var i := int(fposmod(f, 4294967296.0))
	return i - 4294967296 if i >= 2147483648 else i

# G.hash: deterministic hash -> [0,1). Done in doubles on purpose: the JS products exceed 2^53 and round, and the results must match.
static func hash3(x, y = 0, s = 0) -> float:
	var h0 := _i32(float(int(x)) * 374761393.0 + float(int(y)) * 668265263.0 + float(int(s)) * 2147483647.0)
	var a := (h0 & 0xFFFFFFFF) >> 13
	var h2 := _i32(float(h0 ^ a) * 1274126177.0)
	var b := (h2 & 0xFFFFFFFF) >> 16
	var h3 := h2 ^ b
	return float(h3 & 0xFFFFFFFF) / 4294967296.0
