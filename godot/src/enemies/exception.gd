class_name ExceptionFoe
extends EnemySM
# EXCEPTION (letter X): a warning triangle that throws yellow errors. The error is catchable (Player.catch_window_open): swipe it just as
# it reaches you and it flies back. Melee players can also just cut it (it is a `cut` projectile) or stomp the thrower.

const RANGE_X := 180.0
const RANGE_Y := 40.0
const COOLDOWN := 2.2
const STATES := ["idle", "windup", "recover"]

var cool := COOLDOWN * 0.5

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 12, 14)
	hp = 3
	loot = 3
	col = "#ffd23f"
	face = -1.0 if Game.hash3(px, py, 1) < 0.5 else 1.0

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	if stun > 0.0:
		physics(dt)
		return
	var tp := to_player()
	if tp.p != null and state == "idle" and absf(tp.dx) > 1.0:
		face = Game.sign_of(tp.dx)
	match state:
		"idle":
			cool -= dt
			if cool <= 0.0 and tp.p != null and absf(tp.dx) <= RANGE_X and absf(tp.dy) <= RANGE_Y and sees_player(RANGE_X, RANGE_Y):
				set_state("windup", 0.5 * float(Game.dv("telegraph_mult")))
		"windup":
			if state_t <= 0.0:
				room.shoot(cx + face * 8.0, y + 5.0, face * 130.0, 0.0, {"kind": "err", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1})
				Audio.sfx("shoot")
				set_state("recover", 0.6 * float(Game.dv("punish_mult")))
		"recover":
			if state_t <= 0.0:
				set_state("idle")
				cool = COOLDOWN
	physics(dt)

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var yel := Color(col)
	var bx := floori(x)
	var by := floori(y)
	var flash_on: bool = state == "windup" and int(t * 20.0) % 2 == 0
	var body := Color.WHITE if flash_on else yel
	# the warning triangle: 12 wide, 12 tall, two 1 px legs under it
	for row in range(12):
		var half := 1 + int(row * 5.0 / 11.0)           # 1..6 pixels each side of the middle
		draw_rect(Rect2(bx + 6 - half - 1, by + row, half * 2 + 2, 1), ink)
	for row in range(1, 11):
		var half := 1 + int(row * 5.0 / 11.0) - 1
		if half > 0:
			draw_rect(Rect2(bx + 6 - half, by + row, half * 2, 1), body)
	draw_rect(Rect2(bx + 5, by + 5, 2, 4), ink)          # the black !
	draw_rect(Rect2(bx + 5, by + 10, 2, 1), ink)
	draw_rect(Rect2(bx + 3, by + 12, 1, 2), ink)
	draw_rect(Rect2(bx + 8, by + 12, 1, 2), ink)
	if state == "windup":                                # a yellow ! over its head
		PixelText.draw_text(self, "!", bx + 5, by - 10, Game.COL.gold, {"outline": Game.COL.ink})

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 2)]
	state_t = f[1] / 100.0
