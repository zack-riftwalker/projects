class_name Boss
extends Enemy
# Boss: base of the boss fights. Port of `class Boss` (js/bosses.js). The arena floor line FLOOR (176) is shared by every arena.

const FLOOR := 176.0

static var tint_mat: ShaderMaterial

var boss_name := ""
var sub := ""
var max_hp := 1
var hpf := 1.0
var active := false
var phase := 1
var st := "wait"
var st_t := 0.0
var n := 0
var dying := false
var die_t := 0.0
var drop_n := 24
var gone := false
var is_boss := true
var body: DrawProxy
var overlay: DrawProxy

func _init(r: Room, bx: float, by: float, bw: float, bh: float, boss_hp: int) -> void:
	super(r, 0, 0, bw, bh)
	x = bx - bw / 2.0
	y = by - bh
	hp = boss_hp
	hpf = float(boss_hp)
	max_hp = boss_hp
	passive = true
	always = true
	stompable = false
	kb = 0.0
	z_index = 2

func _ready() -> void:
	body = DrawProxy.new()
	body.cb = draw_boss_body
	add_child(body)
	overlay = DrawProxy.new()
	overlay.cb = draw_boss_overlay
	add_child(overlay)

func set_state(s: String, t_ := 0.0) -> void:
	st = s
	st_t = t_
	n = 0

func start() -> void:
	active = true
	passive = false
	set_state("idle", 1.0)

func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	var dmg := float(d)
	if how == "agent" or how == "dash":
		dmg *= 0.5
	hpf -= dmg
	hp = ceili(hpf)
	flash = 0.1
	var b = box if box != null else self
	room.burst(b.x + b.w / 2.0, b.y + b.h / 2.0, 6, [col, "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	room.boss_damage(self, dmg)
	on_damage()
	if hpf <= 0.0 and not dying:
		hp = 0
		hpf = 0.0
		begin_death()
		return "kill"
	return "hit"

func on_damage() -> void:
	pass

func begin_death() -> void:
	dying = true
	die_t = 0.0
	passive = true
	for q in room.projs:
		q.dead = true
	for e in room.ents:
		if e != self and not e.get("is_boss"):
			e.loot = 0
			e.die("")
	room.stop(0.35)
	room.shake(1.0)
	room.flash_screen(0.9)
	room.events.append("bossDying")

# generic "blow up for a while" ending; returns true when finished
func death_rattle(dt: float, dur: float, cols: Array) -> bool:
	die_t += dt
	if room.rng.randf() < 0.35:
		room.explode(x + room.rng.randf_range(0, w), y + room.rng.randf_range(0, h), room.rng.randf_range(8, 16), cols)
		Audio.sfx("explode", {"vol": 0.6})
		room.shake(0.25)
	if die_t >= dur and not gone:
		gone = true
		dead = true
		room.explode(cx, cy, 46, cols)
		room.flash_screen(1.0)
		room.shake(1.0)
		Audio.sfx("bigExplode")
		room.drop(cx, cy, drop_n)
		room.events.append("bossDead")
		return true
	return false

func _process(_dt: float) -> void:
	if flash_mat == null:
		super._process(_dt)
	body.material = flash_mat if flash > 0.0 else null
	body.queue_redraw()
	overlay.queue_redraw()

func draw_body() -> void:
	pass

func draw_boss_body(_ci: CanvasItem) -> void:
	pass

func draw_boss_overlay(_ci: CanvasItem) -> void:
	pass

# dashed danger column (js: warnCol)
func warn_col(ci: CanvasItem, wx: float) -> void:
	var sx := floori(wx + 0.5)
	var col := Color(Game.COL.hazard) if int(t * 12.0) % 2 == 1 else Color(Game.COL.hazardHi)
	var yy: float = room.cam.y + 20 + (int(t * 60.0) % 8)
	while yy < FLOOR:
		ci.draw_rect(Rect2(sx, yy, 1, 4), col)
		yy += 8
	PixelText.draw_text(ci, "!", sx - 1, room.cam.y + 20, Game.COL.hazardHi, {"outline": Game.COL.ink})

static func tint_material() -> ShaderMaterial:
	if tint_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.75, 0.91, 1.0, 1.0);\nvoid fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(tint.rgb, c.a * COLOR.a); }\n"
		tint_mat = ShaderMaterial.new()
		tint_mat.shader = sh
	return tint_mat
