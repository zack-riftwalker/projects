extends Node2D
# Probe, not a game: proves the state machine, headless run and screenshot work.

var state := "idle"
var ticks := 0
var shot_path := "user://smoke.png"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shot_path = args[0]
	print("smoke: start")

func go(s: String) -> void:
	print("smoke: %s -> %s" % [state, s])
	state = s
	ticks = 0

func _physics_process(_dt: float) -> void:
	ticks += 1
	match state:
		"idle":
			if ticks >= 5: go("attack")
		"attack":
			if ticks >= 5: go("recover")
		"recover":
			if ticks >= 5: _finish()

func _finish() -> void:
	set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png(shot_path)
		print("smoke: screenshot %s (err %d)" % [shot_path, err])
	print("smoke: done")
	get_tree().quit()
