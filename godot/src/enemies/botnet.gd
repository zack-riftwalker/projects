class_name Botnet
extends Enemy
# BOTNET (`r`, MVB3-03): a server rack that raises DDOS swarms. While any bit of its swarm lives, the rack is shielded (hits clang off a blue shimmer).
# When the swarm is gone four LEDs go out one by one (4 s) and a new swarm of five rises from its top; in that countdown the rack takes hits.
# It never moves and does not hurt by touch. Its bits fly 20 % faster. Its death kills its bits.

const COUNT := 4.0

var bits: Array = []
var countdown := COUNT
var shielded := false
var shield_flash := 0.0
var cell := Vector2.ZERO

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 24, 32)
	hp = 10
	loot = 6
	col = "#3a6fb0"
	stompable = false
	dashable = true
	cell = Vector2(px, py)
	settle()

# its bottom stands on the floor under the cell (the room calls this again when all its tiles are read)
func settle() -> void:
	var tx := floori((cell.x + 8.0) / T)
	var ty := floori(cell.y / T)
	while ty < room.h - 1 and not room.grid.solid(tx, ty):
		ty += 1
	y = float(ty * T) - h
	x = cell.x + 8.0 - w / 2.0

func bits_alive() -> int:
	var n := 0
	for b in bits:
		if is_instance_valid(b) and not b.dead:
			n += 1
	return n

func harmboxes() -> Array:
	return []

func blocks(_dx: float, _dy: float, how: String) -> bool:
	return shielded and (how == "swipe" or how == "agent" or how == "dash" or how == "stomp" or how == "catch")

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if blocks(dx, dy, how):
		shield_flash = 0.2
		Audio.sfx("clang")
		room.spark(cx + (dx * -8.0 if dx != 0.0 else 0.0), cy - 6.0, "#7cc4ff", 6)
		return "block"
	return super.hit(d, dx, dy, how, b)

func die(how: String) -> void:
	for b in bits:
		if is_instance_valid(b) and not b.dead:
			b.loot = 0
			b.die("packet")
	bits = []
	super.die(how)

func update(dt: float) -> void:
	tick(dt)
	shield_flash = maxf(0.0, shield_flash - dt)
	var alive := bits_alive()
	shielded = alive > 0
	if alive == 0:
		bits = []
		countdown -= dt
		if countdown <= 0.0:
			bits = room.spawn_ddos(cx - 12.0, y - 6.0, self)
			countdown = COUNT
			shielded = true
			Audio.sfx("glitch", {"vol": 0.6})
			room.pop(cx, y - 10.0, "swarm up", "#ff9ad8")
	else:
		countdown = COUNT

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var bx := floorf(x)
	var by := floorf(y)
	draw_rect(Rect2(bx - 1, by - 1, 26, 34), ink)
	draw_rect(Rect2(bx, by, 24, 32), Color("#2a3858"))
	draw_rect(Rect2(bx, by, 24, 2), Color("#4a6aa0"))
	for u in range(4):                                          # four server units, each with a LED that goes out during the countdown
		var uy := by + 3.0 + u * 7.0
		draw_rect(Rect2(bx + 2, uy, 20, 5), Color("#18203a"))
		draw_rect(Rect2(bx + 4, uy + 2, 10, 1), Color("#3a4a70"))
		var lit: bool = shielded or (countdown > COUNT * (float(u) / 4.0))
		var led := Color("#58f0c8") if lit and int(t * (3.0 + u)) % 2 == 0 else (Color("#2a8a78") if lit else Color("#1a2238"))
		if not shielded and lit:
			led = Color("#ff5a5a") if int(t * 6.0) % 2 == 0 else Color("#7a2a2a")
		draw_rect(Rect2(bx + 17, uy + 1, 3, 3), led)
	draw_rect(Rect2(bx + 2, by + 30, 20, 1), ink)
	if shielded:
		var a := 0.30 + 0.25 * sin(t * 8.0) + (0.4 if shield_flash > 0.0 else 0.0)
		draw_rect(Rect2(bx - 3, by - 3, 30, 38), Color(0.45, 0.75, 1.0, clampf(a, 0.0, 0.8)), false, 1.0)
		draw_rect(Rect2(bx - 2, by - 2, 28, 36), Color(0.45, 0.75, 1.0, clampf(a * 0.35, 0.0, 0.5)))
	else:
		PixelText.draw_text(self, "%.1f" % maxf(countdown, 0.0), bx + 12, by - 8.0, "#ffd23f", {"align": "c", "tiny": true, "outline": Game.COL.ink})

func net_fields() -> Array:
	return [roundi(countdown * 100.0), 1 if shielded else 0]

func net_apply(f: Array) -> void:
	countdown = f[0] / 100.0
	shielded = int(f[1]) == 1
