extends SceneTree
# Makes the animated wall details of GFX-N (MVGN-10) with Godot's own Image (no dependencies): 4 frames of 16x16 side by side, transparent around them.
#   w6_led.png  a dark pill with four LEDs, one lit per frame (white: the game tints the layer with the mood's accent colour)
#   w6_fan.png  a fan grille, a pair of blades turning a quarter of a turn over the 4 frames
# Run: godot --headless --path godot -s ../tools/godot/make-anim-tiles.gd
func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			img.set_pixel(x, y, c)

func _init() -> void:
	var led := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	var fan := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	for f in range(4):
		var ox := f * 16
		_rect(led, ox + 1, 5, 14, 6, Color("#05070f"))
		_rect(led, ox + 2, 6, 12, 4, Color("#0d1222"))
		for i in range(4):
			var c := Color(1, 1, 1, 1) if i == f else Color(0.22, 0.22, 0.22, 1)
			_rect(led, ox + 3 + i * 3, 7, 2, 2, c)
		for y in range(16):
			for x in range(16):
				var dx := float(x) - 7.5
				var dy := float(y) - 7.5
				var r := sqrt(dx * dx + dy * dy)
				if r <= 6.2:
					fan.set_pixel(ox + x, y, Color("#0b0f1a") if r < 5.4 else Color("#232a40"))
		var a := float(f) * PI / 8.0
		for s in range(-8, 9):
			var t := float(s) / 2.0
			for b in range(2):
				var ang := a + float(b) * PI / 2.0
				var px := int(round(7.5 + cos(ang) * t * 1.15))
				var py := int(round(7.5 + sin(ang) * t * 1.15))
				if px >= 0 and px < 16 and py >= 0 and py < 16 and absf(t) < 4.6:
					fan.set_pixel(ox + px, py, Color("#6a7599"))
		fan.set_pixel(ox + 7, 7, Color("#9aa6c8"))
		fan.set_pixel(ox + 8, 8, Color("#9aa6c8"))
	led.save_png("res://assets/tiles/w6_led.png")
	fan.save_png("res://assets/tiles/w6_fan.png")
	print("animated tiles written")
	quit()
