class_name FrameMeter
extends RefCounted
# FrameMeter (brief 05): where a frame's time goes, sampled once per frame. The benches (gfxbench, fightbench) and the pause menu's
# "Measure" page use it. An average hides the stutter Zakaria sees, so it keeps the spread: the median, the slowest 1 %, the
# worst, and how many frames missed a 60 Hz screen. The parts are the engine's own timers of the last frame: the game's logic
# (physics: the 60 steps a second), the _process calls, and the CPU side of drawing (filling the draw lists and sending them to GL).
# 1 ms buckets (0..250 ms): O(1) per frame, like the debug overlay's.

var hist := PackedInt32Array()
var n := 0
var total := 0.0
var worst := 0.0
var zero := 0                       # frames with no game step (the picture did not move: at 60 Hz a stutter)
var multi := 0                       # frames with 2+ steps (the game jumped ahead)
var missed := 0                      # frames longer than 17.5 ms (a 60 Hz screen showed the last picture twice)
var long := 0                        # frames longer than 50 ms (a visible hitch)
var phys := 0.0
var proc := 0.0
var draw := 0.0
var calls := 0.0                     # GL draw calls a frame (each one costs CPU in the driver; on the web every one is checked and sent to the GPU process)
var prims := 0.0
var steps0 := 0
var nsteps := 0
var last_us := 0
var lastms := 0.0
var vp: RID

# measure_draw: the engine also times the drawing (the benches); the game's own speed report leaves it off (it is not free on the web)
func _init(measure_draw := true) -> void:
	hist.resize(251)
	hist.fill(0)
	steps0 = Engine.get_physics_frames()
	last_us = Time.get_ticks_usec()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and measure_draw:
		vp = tree.root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)

# once per frame (after the frame: `await process_frame`, or from a _process)
func sample() -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - last_us) / 1000.0
	last_us = now
	lastms = ms
	var st := Engine.get_physics_frames()
	add(ms, st - steps0)
	steps0 = st

# one frame of `ms` that ran `steps` game steps; the engine's part timers are read here (they are the last frame's)
func add(ms: float, steps: int) -> void:
	n += 1
	nsteps += steps
	if steps == 0:
		zero += 1
	elif steps >= 2:
		multi += 1
	total += ms
	worst = maxf(worst, ms)
	hist[clampi(int(ms), 0, 250)] += 1
	if ms > 17.5:
		missed += 1
	if ms > 50.0:
		long += 1
	phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if vp.is_valid():
		draw += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()

# the frame time below which `frac` of the frames are (0.5: the median, 0.99: the slowest 1 % start here)
func pct(frac: float) -> float:
	var need := int(ceil(n * frac))
	var acc := 0
	for i in range(251):
		acc += hist[i]
		if acc >= need:
			return i + 0.5
	return 250.0

func summary() -> String:
	if n == 0:
		return "no frames"
	return "frames %d p50 %.1f p99 %.1f max %.1f ms, missed60 %.1f%% long %d | logic %.2f process %.2f draw-cpu %.2f ms, %d draw calls %d prims | steps %.2f/frame, 0 steps %.1f%% 2+ steps %.1f%%" % [n,
		pct(0.5), pct(0.99), worst, missed * 100.0 / n, long, phys / n, proc / n, draw / n, int(calls / n), int(prims / n), float(nsteps) / n, zero * 100.0 / n, multi * 100.0 / n]

# the short form of the speed report: one line per room
func short() -> String:
	if n == 0:
		return "-"
	return "%ds p50 %.1f p99 %.1f max %.0f ms missed60 %.0f%% long %d | logic %.1f calls %d | 0st %.0f%% 2st %.0f%%" % [int(total / 1000.0),
		pct(0.5), pct(0.99), worst, missed * 100.0 / n, long, phys / n, int(calls / n), zero * 100.0 / n, multi * 100.0 / n]
