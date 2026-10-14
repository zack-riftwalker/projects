class_name PostChain
extends Node
# PostChain (MVGN-07): the full-screen effects of THE NETWORK, one shader pass in a CanvasLayer of the game viewport (384 x 216, so it costs ~83k
# pixels even on a phone), above the world and below the HUD layer (the HUD is never touched). Owned by the viewport like LookStage: the local
# NETWORK room's Look claims it every frame; when nobody claimed it for a few frames (worlds 1-5, the title) the layer is hidden and costs nothing.
# In order: bloom (only what is brighter than 0.9: emissives, LEDs, shots, lights; the base picture is never blurred), LUT grade (two LUTs cross-faded),
# vignette, grain, scanlines, and a chromatic-aberration pulse (0 at rest). Cosmetic only: reads Look and the tier, writes nothing.

const SHADER := "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D lut_a : filter_linear, repeat_disable;
uniform sampler2D lut_b : filter_linear, repeat_disable;
uniform float lut_mix = 0.0;
uniform float bloom = 0.0;
uniform int bloom_taps = 8;
uniform float bloom_lod = 1.5;
uniform float vignette = 0.35;
uniform float grain = 0.0;
uniform float scan = 0.0;
uniform float ca = 0.0;
uniform float tq = 0.0;
vec3 lut_at(sampler2D t, vec3 c) {
	vec3 q = clamp(c, 0.0, 1.0) * 15.0;
	float b = floor(q.b);
	float bf = q.b - b;
	vec2 u0 = vec2((b * 16.0 + q.r + 0.5) / 256.0, (q.g + 0.5) / 16.0);
	vec2 u1 = vec2((min(b + 1.0, 15.0) * 16.0 + q.r + 0.5) / 256.0, (q.g + 0.5) / 16.0);
	return mix(texture(t, u0).rgb, texture(t, u1).rgb, bf);
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	if (ca > 0.0) {
		vec2 d = (uv - 0.5) * ca * 0.02;
		c = vec3(texture(scr, uv + d).r, texture(scr, uv).g, texture(scr, uv - d).b);
	} else {
		c = texture(scr, uv).rgb;
	}
	if (bloom > 0.0) {
		vec3 acc = vec3(0.0);
		for (int i = 0; i < bloom_taps; i++) {
			float a = float(i) * 6.2831853 / float(bloom_taps) + float(i % 2) * 0.4;
			float r = (i % 2 == 0) ? 5.0 : 10.0;
			vec2 o = vec2(cos(a), sin(a)) * r / vec2(384.0, 216.0);
			vec3 s = textureLod(scr, uv + o, bloom_lod).rgb;
			float l = dot(s, vec3(0.299, 0.587, 0.114));
			acc += s * smoothstep(0.85, 0.97, l);
		}
		c += acc / float(bloom_taps) * bloom * 2.0;
	}
	c = mix(lut_at(lut_a, c), lut_at(lut_b, c), lut_mix);
	vec2 v = uv - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, dot(v, v) * 2.0);
	if (grain > 0.0) {
		c += (hash(floor(uv * vec2(384.0, 216.0)) + tq) - 0.5) * grain;
	}
	if (scan > 0.0 && mod(floor(uv.y * 216.0), 2.0) < 1.0) {
		c *= 1.0 - scan;
	}
	COLOR = vec4(c, 1.0);
}"

static var _shader: Shader

var vp: Viewport
var layer: CanvasLayer
var rect: ColorRect
var mat: ShaderMaterial
var claimed := -100

static func of(room: Node) -> PostChain:
	var v := room.get_viewport()
	if v == null:
		return null
	var pc := v.get_node_or_null("PostChain") as PostChain
	if pc == null:
		pc = PostChain.new()
		pc.name = "PostChain"
		v.add_child(pc)
	return pc

func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	layer = CanvasLayer.new()
	layer.name = "PostLayer"
	layer.layer = 1                                  # the HUD layer is 2 (main.gd): the HUD is above, never graded
	layer.visible = false
	add_child(layer)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bb)
	rect = ColorRect.new()
	rect.size = Vector2(384, 216)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	layer.add_child(rect)

# the local room's Look says what to draw this frame
func claim(look: Look, time: float) -> void:
	claimed = Engine.get_process_frames()
	var tier := Game.gfx_tier
	var calm := Game.reduce_flash
	var la := look.lut_pair()
	mat.set_shader_parameter("lut_a", la[0])
	mat.set_shader_parameter("lut_b", la[1])
	mat.set_shader_parameter("lut_mix", la[2])
	mat.set_shader_parameter("bloom", float(look.out.bloom) if tier >= 1 else 0.0)
	mat.set_shader_parameter("bloom_taps", 12 if tier >= 2 else 6)            # (High: fewer, coarser taps = the plan's half resolution bloom)
	mat.set_shader_parameter("bloom_lod", 1.5 if tier >= 2 else 2.2)
	mat.set_shader_parameter("vignette", 0.35)
	mat.set_shader_parameter("grain", 0.025 if tier >= 1 and not calm else 0.0)
	mat.set_shader_parameter("scan", 0.04 if tier >= 1 and not calm else 0.0)
	mat.set_shader_parameter("ca", 0.0 if calm else look.ca_pulse)
	mat.set_shader_parameter("tq", floorf(time * 24.0))
	layer.visible = true

func _process(_dt: float) -> void:
	if layer != null and layer.visible and Engine.get_process_frames() - claimed > 3:
		layer.visible = false
