class_name GcDrone
extends Enemy
# GC DRONE (THE LEAK v2): a harmless collector that flies across the arena. Popping it with anything lets some of the flood out.

var boss

func _init(r: Room, px: float, py: float, owner_boss = null) -> void:
	super(r, px, py, 14, 10)
	boss = owner_boss
	hp = 1
	loot = 0
	col = "#7fd08a"
	always = true
	stompable = true

func update(dt: float) -> void:
	tick(dt)
	x += vx * dt
	y = 40.0 + sin(t * 3.0) * 3.0
	if x < -40.0 or x > room.pw + 40.0:
		dead = true                     # off the arena: freed, nobody popped it

func harmboxes() -> Array:
	return []

func die(how: String) -> void:
	super.die(how)
	if how != "" and boss != null and is_instance_valid(boss) and not boss.dead and not boss.dying:
		boss.gc_popped(Vector2(cx, cy))

func draw_body() -> void:
	var tx := Gfx.tex("drone_%d" % (int(t * 20.0) % 2))
	if tx != null:
		draw_texture(tx, Vector2(floori(x + w / 2.0 + 0.5) - tx.get_width() / 2.0, floori(y + h + 0.5) + 1 - tx.get_height()), Color("#9be8a5"))

func net_fields() -> Array:
	return []

func net_apply(_f: Array) -> void:
	pass
