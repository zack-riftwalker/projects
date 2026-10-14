extends SceneTree
# Makes the light textures of GFX-N (MVGN-05) with Godot's own Image (no dependencies): a soft round light and a cone (a beam pointing right).
# Run: godot --headless --path godot -s ../tools/godot/make-light-textures.gd   (writes godot/assets/fx/light_soft.png and light_cone.png, 128x128)

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/fx")
	var n := 128
	var soft := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var cone := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var dx := (float(x) + 0.5 - n / 2.0) / (n / 2.0)
			var dy := (float(y) + 0.5 - n / 2.0) / (n / 2.0)
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)                                # smoothstep falloff, zero at the rim
			soft.set_pixel(x, y, Color(1, 1, 1, a))
			# the cone: the apex at the left middle, opening to the right (the node is rotated to the beam), soft at the sides and at the far end
			var u := float(x) / (n - 1.0)                              # 0 at the apex .. 1 at the far end
			var half := 0.08 + 0.42 * u                                # half width (fraction of the height) grows along the beam
			var side := clampf(1.0 - absf(dy * 0.5) / maxf(half, 0.001), 0.0, 1.0)
			var along := clampf(1.0 - u, 0.0, 1.0)
			var c := side * side * (3.0 - 2.0 * side) * (0.35 + 0.65 * along)
			cone.set_pixel(x, y, Color(1, 1, 1, clampf(c, 0.0, 1.0)))
	soft.save_png("res://assets/fx/light_soft.png")
	cone.save_png("res://assets/fx/light_cone.png")
	print("light textures written")
	quit()
