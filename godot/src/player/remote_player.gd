class_name RemotePlayer
extends Node2D
# RemotePlayer: the partner as the host sees it (and the host as the guest sees it). It is only a body that follows the reports of the
# other game: position buffer with 0.05-0.25 s interpolation, a hurtbox enemies can target, and the pose to draw. It never hurts itself:
# its owner decides about hp and damage (docs/metroidvania/04-coop-design.md).

const BLUE := "#6aa8ff"

var room: Room
var is_remote := true
var x := 0.0
var y := 0.0
var w := 10.0
var h := 10.0
var vx := 0.0
var vy := 0.0
var face := 1.0
var hp := 5
var max_hp := 5
var dead := false
var on_ground := true            # the camera reads these when it follows the partner
var wall_dir := 0
var frozen := false
var dn := 0                      # how many times it went down (a lost event corrects itself)
var pose := 0
var gone := false
var dash_t := 0.0
var atk_t := 0.0
var atk_dir := "f"
var atk_face := 1.0
var atk_id := 0
var dash_id := 0
var dash_dx := 0.0
var dash_dy := 0.0
var dash_seen := -10.0           # when the last dash was reported (room time), for the crack check
var away := false
var lagging := false
var t := 0.0
var inv := 0.0
var samples: Array = []          # [time, x, y] reported positions
var ghost_since := 0.0
var down_t := -1.0               # host: the revive countdown of the partner (-1: not down)
var safe := {"x": 0.0, "y": 0.0}
var tools := {}

func _init(r: Room) -> void:
	room = r
	z_index = 3

func hurtbox() -> Dictionary:
	return {"x": x + 1, "y": y + 1, "w": w - 2, "h": h - 1}

func hurt(_d: int, _src: float) -> bool:
	return false

func atk_box() -> Dictionary:
	var rr := 24.0
	if atk_dir == "u":
		return {"x": x - 8, "y": y - rr + 3, "w": w + 16, "h": rr}
	if atk_dir == "d":
		return {"x": x - 8, "y": y + h - 3, "w": w + 16, "h": rr}
	return {"x": x + w - 4 if atk_face > 0 else x + 4 - rr, "y": y - 7, "w": rr, "h": h + 12}

# a body report arrived (positions in pixels)
func report(px: float, py: float, pvx: float, pvy: float, pface: float, now_t: float) -> void:
	vx = pvx
	vy = pvy
	face = pface
	samples.append([now_t, px, py])
	while samples.size() > 12:
		samples.pop_front()
	if samples.size() == 1:
		x = px
		y = py

# follow the reports 0.08 s late (smooth, never jumps)
func follow(now_t: float) -> void:
	t += Game.STEP
	if samples.is_empty():
		return
	var rt := now_t - 0.08
	var a: Array = samples[0]
	var b: Array = samples[samples.size() - 1]
	if rt >= b[0]:
		var ex := minf(rt - b[0], 0.25)
		x = b[1] + vx * ex
		y = b[2] + vy * ex
		return
	for i in range(samples.size() - 1):
		if samples[i][0] <= rt and rt <= samples[i + 1][0]:
			var s0: Array = samples[i]
			var s1: Array = samples[i + 1]
			var k: float = (rt - s0[0]) / maxf(0.0001, s1[0] - s0[0])
			x = lerpf(s0[1], s1[1], k)
			y = lerpf(s0[2], s1[2], k)
			return
	x = a[1]
	y = a[2]

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var px := floori(x + w / 2.0 + 0.5)
	var py := floori(y + h + 0.5)
	var alpha := 0.55 if (away or lagging) else 1.0
	if dead:
		# the downed body: flat, with the revive countdown
		ClawdDraw.draw_clawd(self, px, py, {"col": BLUE, "alpha": 0.7, "sy": 0.45, "legs": [0, 0, 0, 0], "eyes": "shut", "face": face})
		if down_t >= 0.0:
			PixelText.draw_text(self, str(ceili(down_t)), px, py - 16, "#ffffff", {"align": "c", "outline": Game.COL.ink})
		return
	var o := {"face": face, "col": BLUE, "alpha": alpha}
	if absf(vy) > 40.0:
		o.armL = -2
		o.armR = -2
		o.legs = [1, 2, 2, 1]
	elif absf(vx) > 24.0:
		var f := int(t * 13.0) % 4
		o.legs = [2, 1, 2, 1] if f == 0 else ([1, 2, 1, 2] if f == 2 else [2, 2, 2, 2])
	if dash_t > 0.0:
		o.eyes = "shut"
		o.col = "#bfdcff"
	if inv > 0.0 and int(inv * 20.0) % 2 == 1:
		return
	ClawdDraw.draw_clawd(self, px, py, o)
	if atk_t > 0.0:
		var f2 := 0 if atk_t > 0.115 else (1 if atk_t > 0.05 else 2)
		var pcy := py - 5
		var key := "u" if atk_dir == "u" else ("d" if atk_dir == "d" else ("f" if atk_face > 0 else "b"))
		var tex := Gfx.tex("slash_%s_%d" % [key, f2])
		var n := tex.get_width()
		var pos := Vector2.ZERO
		if atk_dir == "u":
			pos = Vector2(px - n / 2.0, pcy - 1 - (n - 3))
		elif atk_dir == "d":
			pos = Vector2(px - n / 2.0, pcy + 1 - 3)
		elif atk_face > 0:
			pos = Vector2(px + 1 - 3, pcy - n / 2.0)
		else:
			pos = Vector2(px - 1 - (n - 3), pcy - n / 2.0)
		draw_texture(tex, Vector2(floori(pos.x), floori(pos.y)), Color(0.42, 0.66, 1.0, 0.9))

func hazard() -> void:
	pass
