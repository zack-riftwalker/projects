class_name DeadlockGuard
extends EnemySM
# DEADLOCK pair (`]`, MV5A-05): two guards that each wait for the other. They hold still and lunge 32 px at a player within 40 px (tell 0.4 s).
# While each has a clear line to the other a blue chain is drawn between them and both block every hit (clang). A player's body on the line
# breaks it: the line test counts player boxes. Walk between them and they are plain 4 hp guards.

const STATES := ["idle", "tell", "lunge", "recover"]

var partner: DeadlockGuard = null
var is_b := false
var linked := false

func _init(r: Room, px: float, py: float, b := false) -> void:
	super(r, px, py, 14, 18)
	is_b = b
	hp = 4
	loot = 3
	col = "#7cc4ff"
	stompable = false
	face = 1.0 if not b else -1.0

func pair_with(other: DeadlockGuard) -> void:
	partner = other
	other.partner = self

# the chain is whole: both alive, nothing solid and no player body on the line between their centres
func chain_whole() -> bool:
	if partner == null or partner.dead or not is_instance_valid(partner):
		return false
	var a := Vector2(cx, cy)
	var b := Vector2(partner.cx, partner.cy)
	var n := maxi(1, int(ceilf(a.distance_to(b) / 4.0)))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / float(n))
		if room.grid.solid_at(p.x, p.y):
			return false
		for q in room.players():
			var hb: Dictionary = q.hurtbox()
			if p.x >= hb.x and p.x <= hb.x + hb.w and p.y >= hb.y and p.y <= hb.y + hb.h:
				return false
	return true

func blocks(_dx: float, _dy: float, how: String) -> bool:
	if how == "stomp":
		return false
	if (how == "swipe" or how == "dash") and room.lock_free_attacker():
		return false
	return linked

func hit(d: int, dx: float, dy: float, how: String, b = null) -> String:
	if blocks(dx, dy, how):
		Audio.sfx("clang", {"vol": 0.6})
		room.spark(cx, cy, "#7cc4ff", 4)
		return "block"
	return super.hit(d, dx, dy, how, b)

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	linked = chain_whole()
	if stun > 0.0:
		physics(dt)
		return
	var tp := to_player()
	match state:
		"idle":
			vx = 0.0
			if tp.p != null and absf(tp.dx) < 40.0 and absf(tp.dy) < 24.0:
				face = Game.sign_of(tp.dx) if Game.sign_of(tp.dx) != 0.0 else face
				set_state("tell", 0.4 * float(Game.dv("telegraph_mult")))
		"tell":
			vx = 0.0
			if state_t <= 0.0:
				set_state("lunge", 0.15)
				Audio.sfx("dash", {"vol": 0.6})
		"lunge":
			vx = face * (32.0 / 0.15)
			if state_t <= 0.0:
				vx = 0.0
				set_state("recover", 0.6 * float(Game.dv("punish_mult")))
		"recover":
			vx = 0.0
			if state_t <= 0.0:
				set_state("idle")
	physics(dt)

func harmboxes() -> Array:
	if state == "lunge":
		return [{"x": x if face < 0 else x, "y": y, "w": w + 6.0, "h": h} if face > 0 else {"x": x - 6.0, "y": y, "w": w + 6.0, "h": h}]
	return [self]

func _mate():
	if partner != null and is_instance_valid(partner) and not partner.dead:
		return partner
	var best = null
	var bd := 140.0
	for e in room.ents:
		if e != self and e is DeadlockGuard and not e.dead and absf(e.cx - cx) < bd and absf(e.cy - cy) < 40.0:
			best = e
			bd = absf(e.cx - cx)
	return best

func draw_body() -> void:
	var ink := Color(Game.COL.ink)
	var px := floorf(x)
	var py := floorf(y)
	var tell: bool = state == "tell" and int(t * 20.0) % 2 == 0
	draw_rect(Rect2(px - 1, py - 1, 16, 20), ink)
	draw_rect(Rect2(px, py, 14, 18), Color("#4c5a8a") if not tell else Color("#ffd23f"))
	draw_rect(Rect2(px, py, 14, 2), Color("#7a8ac0"))
	draw_rect(Rect2(px + 2, py + 7, 10, 2), ink)                       # a padlock-like visor
	draw_rect(Rect2(px + 3 if face < 0 else px + 8, py + 6, 3, 2), Color.WHITE)
	draw_rect(Rect2(px + 4, py + 12, 6, 4), Color("#ffd23f") if linked else Color("#8d8798"))   # the key it holds
	var m = _mate()
	if m != null and (not is_b or partner == null) and m.cx > cx:
		var a := Vector2(cx, cy)
		var b := Vector2(m.cx, m.cy)
		if linked:
			draw_line(a, b, Color("#7cc4ff"), 2.0)
			var k := fposmod(t * 1.5, 1.0)
			draw_rect(Rect2(a.lerp(b, k) - Vector2(1.5, 1.5), Vector2(3, 3)), Color("#d6f6ff"))
			PixelText.draw_text(self, "lock", (a.x + b.x) / 2.0, a.y - 14.0, "#7cc4ff", {"align": "c", "tiny": true, "outline": Game.COL.ink})
		else:
			draw_line(a, b, Color(0.49, 0.77, 1.0, 0.25), 1.0)

func net_fields() -> Array:
	return [1 if linked else 0, STATES.find(state), roundi(maxf(state_t, 0.0) * 100.0), 1 if is_b else 0]

func net_apply(f: Array) -> void:
	linked = int(f[0]) == 1
	state = STATES[clampi(int(f[1]), 0, 3)]
	state_t = f[2] / 100.0
	is_b = int(f[3]) == 1
