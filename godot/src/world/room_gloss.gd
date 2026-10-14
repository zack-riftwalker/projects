class_name RoomGloss
extends Node2D
# RoomGloss (MVGN-11, Ultra only): a glossy floor. Under every run of floor caps (solid tiles with air above; not one-way platforms, not liquids) a strip
# 12 px deep shows the picture just above the floor line mirrored around that line, faded with depth, blurred by 1 px, with a slow ripple (+-1 px), at
# alpha gloss x 0.5 (the mood's `gloss`). One shared material (the room's clock and gloss are set once a frame) and one BackBufferCopy in front of the
# strips, so the screen is copied once, after the entities (z 2) and before the `top` layer (z 4). Built once per room from the grid.

const SHADER := "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float gloss = 0.3;
uniform float t = 0.0;
void fragment() {
	float d = UV.y * 12.0;
	vec2 ps = SCREEN_PIXEL_SIZE;
	float rip = sin(t * 1.4 + d * 0.9 + FRAGCOORD.x * 0.11) * ps.x;
	vec2 uv = vec2(SCREEN_UV.x + rip, SCREEN_UV.y - 2.0 * d * ps.y);
	vec3 c = texture(scr, uv).rgb * 0.5 + texture(scr, uv + vec2(ps.x, 0.0)).rgb * 0.25 + texture(scr, uv - vec2(ps.x, 0.0)).rgb * 0.25;
	COLOR = vec4(c, gloss * 0.5 * (1.0 - d / 12.0));
}"

static var _shader: Shader

var room: Room
var strips: Array = []                 # {rect: Rect2 (world), node: ColorRect}
var mat: ShaderMaterial
var bb: BackBufferCopy

func _ready() -> void:
	z_index = 3
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	bb = BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	var g := room.grid
	for ty in range(1, g.h):
		var tx := 0
		while tx < g.w:
			if g.tile(tx, ty) == TileGrid.SOLID and g.tile(tx, ty - 1) == TileGrid.E:
				var x0 := tx
				while tx < g.w and g.tile(tx, ty) == TileGrid.SOLID and g.tile(tx, ty - 1) == TileGrid.E:
					tx += 1
				var cr := ColorRect.new()
				cr.color = Color.WHITE
				cr.position = Vector2(x0 * 16, ty * 16)
				cr.size = Vector2((tx - x0) * 16, 12)
				cr.material = mat
				cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(cr)
				strips.append({"rect": Rect2(cr.position, cr.size), "node": cr})
			else:
				tx += 1
	Game.gfx_changed.connect(_apply_tier)
	_apply_tier()

func _exit_tree() -> void:
	if Game.gfx_changed.is_connected(_apply_tier):
		Game.gfx_changed.disconnect(_apply_tier)

func _apply_tier() -> void:
	visible = Game.gfx_tier >= 2

func _process(_dt: float) -> void:
	if room == null or not room.is_local or room.camera == null or not visible or room.look == null:
		return
	mat.set_shader_parameter("gloss", float(room.look.out.gloss))
	mat.set_shader_parameter("t", room.time)
	var view := Rect2(room.camera.position - Vector2(16, 16), Vector2(384 + 32, 216 + 32))
	for s in strips:
		(s.node as ColorRect).visible = view.intersects(s.rect)
