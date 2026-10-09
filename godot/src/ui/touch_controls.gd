class_name TouchControls
extends Control
# TouchControls: the on-screen pad, a port of the touch script in public/index.html.
# Left half = floating stick (its base is wherever the thumb lands); right side = round buttons; a finger belongs to the button
# under it and moves to another one when it slides onto it. Every press is latched until the game has seen it (Controls.tq) and
# lasts at least MIN_HOLD ms. Sizes are CSS px x the device scale.

const MIN_HOLD := 90
const SPOTS := {"jump": [22.0, 26.0, 82.0, "JUMP"], "attack": [116.0, 30.0, 62.0, "CLAW"], "dash": [34.0, 120.0, 62.0, "DASH"], "special": [118.0, 112.0, 54.0, "SPEC"]}
const BTN_ORDER := ["jump", "attack", "dash", "special"]

var enabled := false
var kc := 1.0                 # device scale (css px -> screen px)
var k := 1.0                  # layout scale from the window size
var stick_r := 50.0
var btn := {}                 # action -> {x, y, r, label}
var pause_rect := Rect2()
var held := {}
var down_at := {}
var pending := {}             # action -> msec when the press may end
var ptr := {}                 # finger index -> action
var stick_id := -1
var ox := 0.0
var oy := 0.0
var kx := 0.0                 # knob offset
var ky := 0.0
var stick_on := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	resized.connect(layout)
	if DisplayServer.is_touchscreen_available():
		enable()

func enable() -> void:
	if enabled:
		return
	enabled = true
	Game.touch_seen = true
	visible = true
	layout()

func layout() -> void:
	kc = DisplayServer.screen_get_scale()
	var w := size.x
	var h := size.y
	k = clampf(minf(w, h) / kc / 380.0, 0.8, 1.25)
	btn.clear()
	for a in BTN_ORDER:
		var sp: Array = SPOTS[a]
		var d: float = sp[2] * k * kc
		btn[a] = {"x": w - (sp[0] * k * kc) - d / 2.0, "y": h - (sp[1] * k * kc) - d / 2.0, "r": d / 2.0, "label": sp[3]}
	var pw := 46.0 * kc
	var ph := 38.0 * kc
	var top := 10.0 * kc
	if h > w:
		top = get_parent().game_rect.end.y + 8.0 * kc    # just below the picture
	pause_rect = Rect2(w - 16.0 * kc - pw, top, pw, ph)
	stick_r = 50.0 * k * kc
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		enable()
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_move(event.index, event.position)

func _hit(p: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for a in btn:
		var b: Dictionary = btn[a]
		var d := p.distance_to(Vector2(b.x, b.y))
		var lim: float = b.r * 1.18 + 8.0 * kc
		if d < lim and d < bd:
			bd = d
			best = a
	if best == "" and pause_rect.grow(8.0 * kc).has_point(p):
		best = "pause"
	return best

func _press(a: String) -> void:
	pending.erase(a)
	held[a] = int(held.get(a, 0)) + 1
	down_at[a] = Time.get_ticks_msec()
	Controls.touch[a] = true
	Controls.tq[a] = true
	queue_redraw()

func _release(a: String) -> void:
	if not held.get(a, 0):
		return
	held[a] -= 1
	if held[a] > 0:
		return
	var left: int = MIN_HOLD - (Time.get_ticks_msec() - int(down_at[a]))
	if left > 0:
		pending[a] = Time.get_ticks_msec() + left
	else:
		Controls.touch[a] = false
	queue_redraw()

func _process(_dt: float) -> void:
	if pending.is_empty():
		return
	var now := Time.get_ticks_msec()
	for a in pending.keys():
		if now >= pending[a]:
			pending.erase(a)
			if not held.get(a, 0):
				Controls.touch[a] = false
				queue_redraw()

func _down(index: int, pos: Vector2) -> void:
	var a := _hit(pos)
	if a != "":
		ptr[index] = a
		_press(a)
		return
	if pos.x < size.x * 0.5 and stick_id < 0:
		stick_id = index
		stick_on = true
		ox = clampf(pos.x, stick_r + 6.0 * kc, size.x * 0.5 - stick_r)
		oy = clampf(pos.y, stick_r + 6.0 * kc, size.y - stick_r - 6.0 * kc)
		_move_stick(pos)

func _move(index: int, pos: Vector2) -> void:
	if index == stick_id:
		_move_stick(pos)
		return
	if not ptr.has(index):
		return
	var cur: String = ptr[index]
	var a := _hit(pos)
	if a != "" and a != cur:
		ptr[index] = a
		_release(cur)
		_press(a)

func _up(index: int) -> void:
	if index == stick_id:
		stick_id = -1
		stick_on = false
		kx = 0.0
		ky = 0.0
		_dirs(false, false, false, false)
		queue_redraw()
		return
	if not ptr.has(index):
		return
	var cur: String = ptr[index]
	ptr.erase(index)
	_release(cur)

func _dirs(l: bool, r: bool, u: bool, d: bool) -> void:
	Controls.touch["left"] = l
	Controls.touch["right"] = r
	Controls.touch["up"] = u
	Controls.touch["down"] = d

func _move_stick(pos: Vector2) -> void:
	var dx := pos.x - ox
	var dy := pos.y - oy
	var d := sqrt(dx * dx + dy * dy)
	if d > stick_r:                # the base follows a thumb that goes too far
		ox = pos.x - dx / d * stick_r
		oy = pos.y - dy / d * stick_r
		dx = pos.x - ox
		dy = pos.y - oy
		d = stick_r
	kx = dx
	ky = dy
	# walking reacts early; up/down only for a firm, nearly vertical push (an upward swipe on a thumb pushed diagonally would miss)
	var m := d / stick_r
	var ux := dx / d if d > 0.0 else 0.0
	var uy := dy / d if d > 0.0 else 0.0
	_dirs(m > 0.28 and ux < -0.38, m > 0.28 and ux > 0.38, m > 0.55 and uy < -0.82, m > 0.55 and uy > 0.82)
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var border := Color(0.957, 0.929, 0.878, 0.42)
	var fill := Color(35 / 255.0, 29 / 255.0, 46 / 255.0, 0.55)
	var clawd := Color(Game.COL.clawd)
	# stick
	var sc := Vector2(ox, oy) if stick_on else Vector2(90.0 * kc, size.y - 96.0 * kc)
	var sr := 62.0 * kc
	var op := 1.0 if stick_on else 0.45
	draw_circle(sc, sr, Color(0.957, 0.929, 0.878, 0.1 * op))
	draw_arc(sc, sr - kc, 0.0, TAU, 48, Color(0.957, 0.929, 0.878, 0.28 * op), 2.0 * kc, true)
	var kn := sc + Vector2(kx, ky)
	draw_circle(kn, 27.0 * kc, clawd if stick_on else Color(0.957, 0.929, 0.878, 0.3))
	draw_arc(kn, 26.0 * kc, 0.0, TAU, 32, Color("#ffe3d6") if stick_on else Color(0.957, 0.929, 0.878, 0.6), 2.0 * kc, true)
	# buttons
	var lbl := maxi(1, roundi(2.0 * kc))
	for a in btn:
		var b: Dictionary = btn[a]
		var on: bool = held.get(a, 0) > 0 or pending.has(a)
		var c := Vector2(b.x, b.y)
		var r: float = b.r * (0.9 if on else 1.0)
		draw_circle(c, r, clawd if on else fill)
		draw_arc(c, r - kc, 0.0, TAU, 48, Color("#ffe3d6") if on else border, 2.0 * kc, true)
		var tw := PixelText.text_width(b.label, {"tiny": true, "scale": lbl})
		PixelText.draw_text(self, b.label, c.x - tw / 2.0, c.y - 2.5 * lbl, Game.COL.ink if on else Color(1, 0.97, 0.93, 0.92), {"tiny": true, "scale": lbl})
	# pause
	var pon: bool = held.get("pause", 0) > 0 or pending.has("pause")
	draw_rect(pause_rect, clawd if pon else fill)
	draw_rect(pause_rect, Color("#ffe3d6") if pon else border, false, 2.0 * kc)
	var pc := pause_rect.get_center()
	PixelText.draw_text(self, "II", pc.x - PixelText.text_width("II", {"scale": lbl}) / 2.0, pc.y - 3.5 * lbl, Game.COL.ink if pon else Color(1, 0.97, 0.93, 0.92), {"scale": lbl})
