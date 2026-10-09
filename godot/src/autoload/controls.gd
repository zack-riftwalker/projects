extends Node
# Controls: input actions and the per-step poll(), a port of js/core.js `input`.

const ACTIONS := ["left", "right", "up", "down", "jump", "attack", "dash", "special", "pause", "start"]

var down := {}
var pressed := {}
var released := {}
var touch := {}               # held by the on-screen buttons
var tq := {}                  # touch presses the game has not seen yet
var script_input = null       # Dictionary: tests and tapes drive the game with it
var locked := false
var _prev := {}

func _ready() -> void:
	_add("left", [KEY_LEFT, KEY_A], [], [[JOY_AXIS_LEFT_X, -1.0]], [JOY_BUTTON_DPAD_LEFT])
	_add("right", [KEY_RIGHT, KEY_D], [], [[JOY_AXIS_LEFT_X, 1.0]], [JOY_BUTTON_DPAD_RIGHT])
	_add("up", [KEY_UP, KEY_W], [], [[JOY_AXIS_LEFT_Y, -1.0]], [JOY_BUTTON_DPAD_UP])
	_add("down", [KEY_DOWN, KEY_S], [], [[JOY_AXIS_LEFT_Y, 1.0]], [JOY_BUTTON_DPAD_DOWN])
	_add("jump", [KEY_Z, KEY_SPACE], [], [], [JOY_BUTTON_A])
	_add("attack", [KEY_X, KEY_J], [], [], [JOY_BUTTON_X])
	_add("dash", [KEY_C, KEY_SHIFT], [], [], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER])
	_add("special", [KEY_V, KEY_E], [], [], [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER])
	_add("pause", [KEY_ESCAPE, KEY_P], [], [], [JOY_BUTTON_BACK])
	_add("start", [KEY_ENTER], [], [], [JOY_BUTTON_START])
	for a in ACTIONS:
		down[a] = false
		pressed[a] = false
		released[a] = false
		_prev[a] = false

func _add(action: String, keys: Array, _unused: Array, axes: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for ax in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[0]
		m.axis_value = ax[1]
		InputMap.action_add_event(action, m)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)

# called once per fixed step (js `input.poll`)
func poll() -> void:
	for a in ACTIONS:
		var state := false
		if script_input != null:
			state = bool(script_input.get(a, false))
		else:
			state = Input.is_action_pressed(a) or bool(touch.get(a, false)) or bool(tq.get(a, false))
		var d: bool = state and not locked
		pressed[a] = d and not _prev[a]
		released[a] = (not d) and _prev[a]
		down[a] = d
		_prev[a] = d
	tq.clear()

func clear_edges() -> void:
	for a in ACTIONS:
		pressed[a] = false
		released[a] = false
