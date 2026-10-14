class_name GfxProbe
extends Node2D
# GfxProbe (MVGN-01): which of Godot's 2D rendering features work in this renderer (desktop opengl3 / the web build's WebGL 2), and what they cost.
# Seven steps, 2 s each, drawn into the game viewport. A step "works" when the picture changed the way the feature should change it (a measured pixel
# compared with a baseline), not when no error was printed. Results: stdout lines `PROBE ...`, the debug log, and a table in the report.
# Run: --scene=gfxprobe (native, prints and quits) or /mv/?gfxprobe&debug (web: the table stays on screen, send the log).

const W := 384
const H := 216
const FRAMES := 120
const NAMES := ["lights", "normal map", "shadows", "native glow", "custom bloom", "screen texture", "LUT grade"]

var vp: SubViewport
var results: Array = []                  # per step: [name, works, ms, note]
var label: Label
var done := false
var in_test := false                     # the gfxprobe test: finish without quitting the process

func _ready() -> void:
	vp = get_viewport() as SubViewport
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	label = Label.new()
	label.position = Vector2(4, 4)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	cl.add_child(label)
	_run()

# ---- helpers ----
static func glow_tex(sz := 64) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = sz
	t.height = sz
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

func _base(parent: Node) -> Node2D:
	var b := Node2D.new()
	parent.add_child(b)
	var bg := ColorRect.new()
	bg.color = Color(0.5, 0.5, 0.5)
	bg.size = Vector2(W, H)
	b.add_child(bg)
	return b

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

# frame ms over FRAMES frames
func _time() -> float:
	var t0 := Time.get_ticks_usec()
	await _frames(FRAMES)
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(FRAMES)

func _say(i: int, works: bool, ms: float, note: String) -> void:
	results.append([NAMES[i], works, ms, note])
	var line := "PROBE %d %s: %s, %.2f ms/frame %s" % [i + 1, NAMES[i], "YES" if works else "NO", ms, note]
	print(line)
	Game.dlog(line)

func _show(i: int) -> void:
	label.text = "GFX PROBE %d/7 %s\n%s" % [i + 1, NAMES[i], "\n".join(results.map(func(r): return "%s: %s %.1f ms" % [r[0], "yes" if r[1] else "NO", r[2]]))]

# ---- the run ----
func _run() -> void:
	await _frames(5)
	# the reference frame (no feature): the base only, its ms is the floor the others are compared with
	var b0 := _base(self)
	await _frames(10)
	var floor_ms := await _time()
	Game.dlog("PROBE base %.2f ms/frame" % floor_ms)
	print("PROBE base %.2f ms/frame" % floor_ms)
	b0.queue_free()
	for i in range(7):
		_show(i)
		await call("_step%d" % (i + 1), floor_ms)
		await _frames(30)
	_show(6)
	var md := "| step | works | ms/frame | note |\n|---|---|---|---|\n"
	for r in results:
		md += "| %s | %s | %.2f | %s |\n" % [r[0], "yes" if r[1] else "NO", r[2], r[3]]
	md += "\nbase (no feature): %.2f ms/frame, renderer `%s`, %s\n" % [floor_ms, RenderingServer.get_video_adapter_name(), "web" if OS.has_feature("web") else "native"]
	print("PROBE TABLE\n", md)
	Game.dlog("PROBE done")
	label.text += "\nDONE (send the log)"
	done = true
	if OS.has_feature("web") or in_test:
		return
	if Game.probe_out != "":
		var f := FileAccess.open(Game.probe_out, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
	get_tree().quit()

# a light lit-area test shared by steps 1-3: returns the picture with the lights on
func _lit_scene(extra := {}) -> Array:
	var root := Node2D.new()
	add_child(root)
	var cm := CanvasModulate.new()
	cm.color = Color(0.15, 0.15, 0.2)
	root.add_child(cm)
	var b := _base(root)
	var lt := glow_tex(128)
	for p in [Vector2(96, 54), Vector2(288, 54), Vector2(96, 162), Vector2(288, 162)]:
		var l := PointLight2D.new()
		l.texture = lt
		l.position = p
		l.texture_scale = 1.5
		l.energy = 1.2
		l.color = Color(1.0, 0.9, 0.7)
		if extra.get("shadow", false):
			l.shadow_enabled = true
			l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		root.add_child(l)
	return [root, b]

func _step1(floor_ms: float) -> void:
	var s := _lit_scene()
	await _frames(10)
	var img := await _grab()
	var lit := _lum(img.get_pixel(96, 54))
	var dark := _lum(img.get_pixel(192, 108))
	var ms := await _time()
	_say(0, lit > dark + 0.15, ms, "lit %.2f vs dark %.2f" % [lit, dark])
	s[0].queue_free()

func _step2(floor_ms: float) -> void:
	var root := Node2D.new()
	add_child(root)
	var cm := CanvasModulate.new()
	cm.color = Color(0.2, 0.2, 0.25)
	root.add_child(cm)
	# a flat grey tile with a normal map that tilts left on its left half and right on its right half
	var n := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var nx := -0.8 if x < 32 else 0.8
			var v := Vector3(nx, 0.0, 0.6).normalized()
			n.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5, 1.0))
	var d := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	d.fill(Color(0.6, 0.6, 0.6))
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(d)
	ct.normal_texture = ImageTexture.create_from_image(n)
	var sp := Sprite2D.new()
	sp.texture = ct
	sp.position = Vector2(192, 108)
	sp.scale = Vector2(2, 2)
	root.add_child(sp)
	var l := PointLight2D.new()
	l.texture = glow_tex(256)
	l.position = Vector2(60, 108)                    # to the left of the tile: its left-facing half is lit more than the right-facing one
	l.energy = 1.5
	l.height = 40.0
	root.add_child(l)
	await _frames(10)
	var img := await _grab()
	var a := _lum(img.get_pixel(160, 108))
	var c := _lum(img.get_pixel(224, 108))
	var ms := await _time()
	_say(1, absf(a - c) > 0.05, ms, "left half %.2f right half %.2f" % [a, c])
	root.queue_free()

func _step3(floor_ms: float) -> void:
	var s := _lit_scene({"shadow": true})
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(120, 40), Vector2(130, 40), Vector2(130, 70), Vector2(120, 70)])
	occ.occluder = poly
	s[0].add_child(occ)
	await _frames(10)
	var img := await _grab()
	var behind := _lum(img.get_pixel(150, 54))       # right of the occluder, the light at (96,54) is blocked there
	var side := _lum(img.get_pixel(150, 90))         # the same distance from the light, no occluder in between
	var ms := await _time()
	_say(2, behind < side - 0.05, ms, "behind %.2f beside %.2f" % [behind, side])
	s[0].queue_free()

func _step4(floor_ms: float) -> void:
	var root := Node2D.new()
	add_child(root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.5
	env.glow_bloom = 0.3
	env.glow_hdr_threshold = 0.7
	we.environment = env
	root.add_child(we)
	var dark := ColorRect.new()
	dark.color = Color(0.1, 0.1, 0.12)
	dark.size = Vector2(W, H)
	root.add_child(dark)
	var spot := ColorRect.new()
	spot.color = Color(1.4, 1.4, 1.4)
	spot.position = Vector2(180, 100)
	spot.size = Vector2(24, 16)
	root.add_child(spot)
	await _frames(10)
	var img := await _grab()
	var near := _lum(img.get_pixel(172, 108))
	var far := _lum(img.get_pixel(350, 190))
	var ms := await _time()
	_say(3, near > far + 0.04, ms, "near the spot %.2f far %.2f (hdr_2d %s)" % [near, far, str(vp.use_hdr_2d)])
	root.queue_free()

const BLOOM_SHADER := "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float thr = 0.4;
uniform float amount = 1.0;
void fragment() {
	vec3 base = texture(scr, SCREEN_UV).rgb;
	vec3 acc = vec3(0.0);
	float w = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		vec2 o = vec2(cos(a), sin(a)) * (i % 2 == 0 ? 6.0 : 11.0) / vec2(384.0, 216.0);
		vec3 s = textureLod(scr, SCREEN_UV + o, 1.5).rgb;
		float l = dot(s, vec3(0.299, 0.587, 0.114));
		acc += s * smoothstep(thr, thr + 0.1, l);
		w += 1.0;
	}
	COLOR = vec4(base + acc / w * amount * 2.0, 1.0);
}"

func _step5(floor_ms: float) -> void:
	var root := Node2D.new()
	add_child(root)
	var dark := ColorRect.new()
	dark.color = Color(0.1, 0.1, 0.12)
	dark.size = Vector2(W, H)
	root.add_child(dark)
	var spot := ColorRect.new()
	spot.color = Color(1, 1, 1)
	spot.position = Vector2(180, 100)
	spot.size = Vector2(24, 16)
	root.add_child(spot)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	root.add_child(bb)
	var pass1 := ColorRect.new()
	pass1.size = Vector2(W, H)
	var sh := Shader.new()
	sh.code = BLOOM_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	pass1.material = mat
	root.add_child(pass1)
	await _frames(10)
	var img := await _grab()
	var near := _lum(img.get_pixel(177, 108))
	var far := _lum(img.get_pixel(350, 190))
	var ms := await _time()
	_say(4, near > far + 0.04, ms, "near the spot %.2f far %.2f" % [near, far])
	root.queue_free()

func _step6(floor_ms: float) -> void:
	var root := Node2D.new()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.8, 0.3, 0.1)
	bg.size = Vector2(W, H)
	root.add_child(bg)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	root.add_child(bb)
	var r := ColorRect.new()
	r.size = Vector2(W, H)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;\nvoid fragment() { COLOR = vec4(1.0 - texture(scr, SCREEN_UV).rgb, 1.0); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	root.add_child(r)
	await _frames(10)
	var img := await _grab()
	var c := img.get_pixel(300, 150)
	var ms := await _time()
	_say(5, absf(c.r - 0.2) < 0.1 and absf(c.b - 0.9) < 0.1, ms, "pixel %s (expected 0.2 0.7 0.9)" % [c.to_html(false)])
	root.queue_free()

func _step7(floor_ms: float) -> void:
	var root := Node2D.new()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.8, 0.3, 0.1)
	bg.size = Vector2(W, H)
	root.add_child(bg)
	# a 16^3 LUT as a 256x16 strip: cell (r,g) tile index b; this one swaps red and blue
	var lut := Image.create(256, 16, false, Image.FORMAT_RGB8)
	for bi in range(16):
		for gi in range(16):
			for ri in range(16):
				lut.set_pixel(bi * 16 + ri, gi, Color(float(bi) / 15.0, float(gi) / 15.0, float(ri) / 15.0))
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	root.add_child(bb)
	var r := ColorRect.new()
	r.size = Vector2(W, H)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform sampler2D lut : filter_linear, repeat_disable;
void fragment() {
	vec3 c = clamp(texture(scr, SCREEN_UV).rgb, 0.0, 1.0) * 15.0;
	float b = floor(c.b);
	float bf = c.b - b;
	vec2 uv0 = vec2((b * 16.0 + c.r + 0.5) / 256.0, (c.g + 0.5) / 16.0);
	vec2 uv1 = vec2((min(b + 1.0, 15.0) * 16.0 + c.r + 0.5) / 256.0, (c.g + 0.5) / 16.0);
	COLOR = vec4(mix(texture(lut, uv0).rgb, texture(lut, uv1).rgb, bf), 1.0);
}"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("lut", ImageTexture.create_from_image(lut))
	r.material = m
	root.add_child(r)
	await _frames(10)
	var img := await _grab()
	var c := img.get_pixel(300, 150)
	var ms := await _time()
	_say(6, c.r < 0.3 and c.b > 0.65, ms, "pixel %s (red and blue swapped from 0.8 0.3 0.1)" % [c.to_html(false)])
	root.queue_free()
