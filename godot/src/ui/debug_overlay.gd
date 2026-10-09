class_name DebugOverlay
extends Control
# DebugOverlay: the numbers of the phone test (?debug). Frame rate (average, slow 1 %, minute 1 vs now), input delay, audio delay, memory.

const RING := 36000
var frames := PackedFloat32Array()      # frame times (s), ring buffer
var head := 0
var count := 0
var total_t := 0.0
var total_frames := 0
var minute := {}                         # minute index -> [frames, seconds]
var input_us := -1
var input_ms := 0.0
var input_max := 0.0
var low1 := 0.0
var low_timer := 0.0
var mem2 := -1.0
var mem10 := -1.0
var last_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frames.resize(RING)
	visible = Game.debug

func _input(event: InputEvent) -> void:
	if not Game.debug:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		input_us = Time.get_ticks_usec()
		if Audio.first_touch_msec < 0:
			Audio.first_touch_msec = Time.get_ticks_msec()
			Audio.sfx("uiOk")

func _process(dt: float) -> void:
	if not Game.debug:
		return
	frames[head] = dt
	head = (head + 1) % RING
	count = mini(count + 1, RING)
	total_t += dt
	total_frames += 1
	var m := int(total_t / 60.0)
	var e: Array = minute.get(m, [0, 0.0])
	e[0] += 1
	e[1] += dt
	minute[m] = e
	if input_us >= 0:
		input_ms = (Time.get_ticks_usec() - input_us) / 1000.0
		input_max = maxf(input_max, input_ms)
		input_us = -1
	if mem2 < 0.0 and total_t >= 120.0:
		mem2 = _mem_mb()
	if mem10 < 0.0 and total_t >= 600.0:
		mem10 = _mem_mb()
	low_timer += dt
	if low_timer >= 1.0:
		low_timer = 0.0
		var fps := PackedFloat32Array()
		fps.resize(count)
		for i in range(count):
			fps[i] = 1.0 / maxf(frames[i], 0.0001)
		fps.sort()
		low1 = fps[int(count * 0.01)] if count > 0 else 0.0
	last_text = _text()
	queue_redraw()

# memory in MB: Godot's own counter (debug builds / native), else the size of the wasm heap (web release builds report 0)
func _mem_mb() -> float:
	var m := OS.get_static_memory_usage() / 1048576.0
	if m > 0.0 or not OS.has_feature("web"):
		return m
	var v = JavaScriptBridge.eval("(typeof wasmMemory!=='undefined')?wasmMemory.buffer.byteLength:((typeof HEAPU8!=='undefined')?HEAPU8.length:0)")
	if v != null and float(v) > 0.0:
		return float(v) / 1048576.0
	var js = JavaScriptBridge.eval("(window.performance&&performance.memory)?performance.memory.usedJSHeapSize:0", true)
	return float(js) / 1048576.0 if js != null else 0.0

func _avg(m: int) -> float:
	var e = minute.get(m)
	return 0.0 if e == null or e[1] <= 0.0 else e[0] / e[1]

func _text() -> String:
	var avg := total_frames / total_t if total_t > 0.0 else 0.0
	var m := int(total_t / 60.0)
	var audio_ms := "-" if Audio.first_sfx_msec < 0 or Audio.first_touch_msec < 0 else "%d" % maxi(0, Audio.first_sfx_msec - Audio.first_touch_msec)
	var mem_now := _mem_mb()
	var mem_txt := "%.1f MB" % mem_now
	if mem2 >= 0.0:
		mem_txt += " (2m %.1f" % mem2 + (" 10m %.1f" % mem10 if mem10 >= 0.0 else "") + ")"
	var l1 := "FPS %d | avg %.1f | low1%% %.1f | min1 %.1f | now-min %.1f" % [Engine.get_frames_per_second(), avg, low1, _avg(0), _avg(m)]
	var l2 := "input %d ms (max %d) | audio %s ms | mem %s" % [roundi(input_ms), roundi(input_max), audio_ms, mem_txt]
	var ws := DisplayServer.window_get_size()
	var l3 := "%s | %s | %dx%d @%.2f | %s" % [Game.build_text, AudioServer.get_driver_name(), ws.x, ws.y, DisplayServer.screen_get_scale(), Time.get_time_string_from_system().substr(0, 5)]
	return l1 + "\n" + l2 + "\n" + l3

func _draw() -> void:
	if not Game.debug:
		return
	# 2 x the device scale, but never wider than the window
	var lines := last_text.to_upper().split("\n")
	var wmax := 1
	for line in lines:
		wmax = maxi(wmax, PixelText.text_width(line))
	var sc := clampi(floori((size.x - 12.0) / wmax), 1, maxi(1, roundi(2.0 * DisplayServer.screen_get_scale())))
	var y := 6
	for line in lines:
		PixelText.draw_text(self, line, 6, y, "#ffffff", {"scale": sc, "outline": "#000000"})
		y += 10 * sc
