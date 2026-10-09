class_name Enemy
extends Node2D
# Enemy: base class of everything that lives in a room. Port of `class Enemy` (js/enemies.js). Names: L -> room.
# Drawn with its own _draw (same anchor as G.spr); the white hit flash is a shared shader material.

const T := 16
static var flash_mat: ShaderMaterial

var room: Room
var x := 0.0
var y := 0.0
var w := 10.0
var h := 10.0
var vx := 0.0
var vy := 0.0
var hp := 1
var flash := 0.0
var face := -1.0
var t := 0.0
var stompable := true
var dmg := 1
var kb := 1.0
var loot := 1
var col := "#ffffff"
var stun := 0.0
var on_ground := false
var dead := false
var hit_wall := 0
var marks := {}               # per-player marks: hit_p1 / dash_p1 -> attack id
var no_hit := false
var passive := false
var dashable := true
var always := false
var nid := 0                  # network id (co-op)
var puppet := false           # a guest's copy: it only shows what the host sends

func _init(r: Room, px: float, py: float, ew: float, eh: float) -> void:
	room = r
	w = ew
	h = eh
	x = px + (T - ew) / 2.0
	y = py + T - eh
	t = Game.hash3(px, py, 3) * 10.0
	z_index = 0

var cx: float:
	get: return x + w / 2.0
var cy: float:
	get: return y + h / 2.0

func hurtboxes() -> Array:
	return [self]

func harmboxes() -> Array:
	return [self]

# returns "block", "kill", "hit" or ""
func hit(d: int, dx: float, _dy: float, how: String, _b = null) -> String:
	if has_method("blocks") and call("blocks", dx, _dy, how):
		return "block"
	hp -= d
	flash = 0.13
	stun = 0.22
	if how != "stomp":
		vx = dx * 130.0 * kb
		vy = minf(vy, -80.0 * kb)
	room.burst(cx, cy, 4, [col, "#ffffff"], 90.0, 300.0)
	if hp <= 0:
		die(how)
		return "kill"
	Audio.sfx("squish" if how == "stomp" else "hit")
	return "hit"

func die(how: String) -> void:
	dead = true
	room.kills += 1
	room.ring(cx, cy, 2, 14, "#ffffff", 0.2)
	room.burst(cx, cy, 10, [col, "#ffffff", Game.COL.ink], 120.0, 320.0)
	if how == "stomp":
		for i in range(6):
			room.part(cx + room.rng.randf_range(-6, 6), y + h, room.rng.randf_range(-70, 70), room.rng.randf_range(-30, -5), 0.35, 2, col, 200.0)
	room.drop(cx, cy, loot)
	Audio.sfx("squish" if how == "stomp" else "kill")

func physics(dt: float, grav := 900.0) -> bool:
	vy = minf(vy + grav * dt, 320.0)
	hit_wall = room.grid.move_x(self, vx * dt)
	var hy := room.grid.move_y(self, vy * dt)
	var was := on_ground
	on_ground = hy > 0
	if hy != 0:
		vy = 0.0
	if y > room.ph + 40:
		dead = true           # fell out of the world, no reward
	return on_ground and not was

func edge_ahead(dir: float) -> bool:
	var fx_ := x + w + 1 if dir > 0 else x - 1
	var ty := floori((y + h + 2) / T)
	var tx := floori(fx_ / T)
	return not room.grid.solid(tx, ty) and room.grid.tile(tx, ty) != TileGrid.ONEWAY

func tick(dt: float) -> void:
	t += dt
	if flash > 0.0:
		flash -= dt
	if stun > 0.0:
		stun -= dt

# the nearest living player (co-op: the partner counts too)
func to_player() -> Dictionary:
	var p = room.player
	var best := 1e18
	for q in room.players():
		var qd: float = Vector2(q.x + 5 - cx, q.y + 5 - cy).length_squared()
		if qd < best:
			best = qd
			p = q
	if p == null:
		return {"dx": 0.0, "dy": 0.0, "d": 1e9, "p": null}
	var dx: float = p.x + 5 - cx
	var dy: float = p.y + 5 - cy
	return {"dx": dx, "dy": dy, "d": sqrt(dx * dx + dy * dy), "p": p}

func update(_dt: float) -> void:
	pass

# draw a sprite like Enemy.spr: bottom-centre anchor, one pixel below the hitbox
func spr(sprite: String, flip := false, sx := 1.0, sy := 1.0, oy := 0.0) -> void:
	Gfx.spr(self, sprite, floori(x + w / 2.0 + 0.5), floori(y + h + 0.5) + 1 + oy, flip, sx, sy)

func draw_body() -> void:
	pass

func _draw() -> void:
	draw_body()

func _process(_dt: float) -> void:
	if flash_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform float flash = 1.0;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a); }\n"
		flash_mat = ShaderMaterial.new()
		flash_mat.shader = sh
	material = flash_mat if flash > 0.0 else null
	queue_redraw()
