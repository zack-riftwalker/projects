class_name RoomHaze
extends Node2D
# RoomHaze (MVGN-13, THE FIREWALL's arena N15): heat haze above the deny walls and the red bricks: a distortion of the picture (+-1.5 px, 6 Hz) over a strip
# 56 px tall on top of each brick column, strongest at the bricks and gone at the top. High and Ultra; off with "Reduce flashing". One shared material,
# one BackBufferCopy in front of the strips (the screen is copied once, after the entities, before the `top` layer). Built once from the room's fire cells.

const SHADER := "shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float t = 0.0;
uniform float k = 1.0;
void fragment() {
	float w = (1.0 - UV.y) * k;
	float n = sin(t * 37.7 + FRAGCOORD.y * 0.45 + FRAGCOORD.x * 0.06) * 0.6 + sin(t * 23.0 + FRAGCOORD.y * 0.21 - FRAGCOORD.x * 0.13) * 0.4;
	vec2 uv = SCREEN_UV + vec2(n * 1.5 * w * SCREEN_PIXEL_SIZE.x, 0.0);
	COLOR = vec4(texture(scr, uv).rgb, 1.0);
}"

static var _shader: Shader

var room: Room
var mat: ShaderMaterial
var rects: Array = []                   # world Rect2 of each strip

func _ready() -> void:
	z_index = 3
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	var top := {}                       # column -> its topmost fire cell row
	for c in room.fire_cells:
		var tx: int = c[0]
		var ty: int = c[1]
		if not top.has(tx) or ty < int(top[tx]):
			top[tx] = ty
	var cols: Array = top.keys()
	cols.sort()
	var i := 0
	while i < cols.size():
		var j := i
		while j + 1 < cols.size() and int(cols[j + 1]) == int(cols[j]) + 1 and int(top[cols[j + 1]]) == int(top[cols[i]]):
			j += 1
		var r := Rect2(int(cols[i]) * 16, int(top[cols[i]]) * 16 - 56, (j - i + 1) * 16, 56)
		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.material = mat
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cr)
		rects.append(r)
		i = j + 1
	Game.gfx_changed.connect(_apply)
	_apply()

func _exit_tree() -> void:
	if Game.gfx_changed.is_connected(_apply):
		Game.gfx_changed.disconnect(_apply)

func _apply() -> void:
	visible = Game.gfx_tier >= 1 and not Game.reduce_flash

func _process(_dt: float) -> void:
	if room == null or not room.is_local:
		return
	if visible == (Game.reduce_flash or Game.gfx_tier < 1):
		_apply()
	mat.set_shader_parameter("t", room.time)
