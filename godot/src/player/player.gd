class_name Player
extends Node2D
# Player: Clawd. An exact port of `class Player` (js/player.js), same order, same constants.
# Skipped in phase 1: sub-agents (Agent), celebrate, auto, frozen, co-op branches. Names: L -> room.

const T := 16
const RUN := 118.0
const ACC := 1150.0
const DEC := 1500.0
const AIR_ACC := 840.0
const AIR_DEC := 480.0
const JUMP := 300.0
const G_UP := 830.0
const G_DOWN := 1250.0
const MAXFALL := 310.0
const COYOTE := 0.1
const BUFFER := 0.12
const WALL_SLIDE := 52.0
const WJ_X := 165.0
const WJ_Y := 285.0
const WJ_LOCK := 0.15
const DASH_SPEED := 320.0
const DASH_T := 0.15
const DASH_CD := 0.2
const DJUMP := 272.0
const POGO := 262.0
const QUIPS := ["You're absolutely right!", "Good catch!", "Let me fix that.", "Ah, I see the issue."]

var room: Room
var x := 0.0
var y := 0.0
var w := 10.0
var h := 10.0
var vx := 0.0
var vy := 0.0
var face := 1.0
var hit_key := "hitId"          # per-player marks on enemies
var dash_key := "dashId"
var tools: Dictionary
var max_hp := 5
var hp := 5
var on_ground := false
var coyote := 0.0
var jump_buf := 0.0
var jumping := false
var wall_dir := 0
var wall_coy := 0.0
var last_wall := 0
var lock := 0.0
var drop_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_buf := 0.0
var can_dash := true
var dash_id := 0
var dash_dx := 1.0
var dash_dy := 0.0
var can_double := true
var atk_t := 0.0
var atk_cd := 0.0
var atk_buf := 0.0
var atk_id := 0
var atk_dir := "f"
var atk_face := 1.0
var atk_live := false
var atk_dmg := 1
var inv := 0.0
var hurt_t := 0.0
var dead := false
var gone := false
var gone_t := 0.0
var sx := 1.0
var sy := 1.0
var run_t := 0.0
var t := 0.0
var blink_t := 2.0
var ghosts: Array = []
var ghost_t := 0.0
var ride = null
var safe := {"x": 0.0, "y": 0.0}
var prev_bottom := 0.0
var meter := 0.0
var agents: Array = []
var grace := 0.0
var frozen := false
var look_t := 0.0

func _init(r: Room, px: float, py: float) -> void:
	room = r
	x = px
	y = py
	tools = Game.tools
	safe = {"x": px, "y": py}
	prev_bottom = py + h
	z_index = 3

func hurtbox() -> Dictionary:
	return {"x": x + 1, "y": y + 1, "w": w - 2, "h": h - 1}

func atk_box() -> Dictionary:
	var rr := 30.0 if tools.opus else 24.0
	if atk_dir == "u":
		return {"x": x - 8, "y": y - rr + 3, "w": w + 16, "h": rr}
	if atk_dir == "d":
		return {"x": x - 8, "y": y + h - 3, "w": w + 16, "h": rr}
	return {"x": x + w - 4 if atk_face > 0 else x + 4 - rr, "y": y - 7, "w": rr, "h": h + 12}

func set_safe(sx_: float, sy_: float) -> void:
	safe.x = sx_
	safe.y = sy_

func add_meter(n: float) -> void:
	if not tools.agents or agents.size() > 0:
		return
	meter = minf(100.0, meter + n)

func update(dt: float) -> void:
	var grid := room.grid
	var down: Dictionary = {} if frozen else Controls.down
	var pressed: Dictionary = {} if frozen else Controls.pressed
	t += dt
	var gi := ghosts.size() - 1
	while gi >= 0:
		ghosts[gi].life -= dt
		if ghosts[gi].life <= 0.0:
			ghosts.remove_at(gi)
		gi -= 1
	if dead:
		return
	if gone:
		gone_t -= dt
		if gone_t <= 0.0:
			gone = false
			inv = 1.4
			room.ring(x + 5, y + 5, 2, 18, Game.COL.clawdHi, 0.3)
		return
	if inv > 0.0: inv -= dt
	if hurt_t > 0.0: hurt_t -= dt
	if atk_cd > 0.0: atk_cd -= dt
	if dash_cd > 0.0: dash_cd -= dt
	if lock > 0.0: lock -= dt
	if drop_t > 0.0: drop_t -= dt
	if grace > 0.0: grace -= dt
	sx = Game.damp(sx, 1.0, 14.0, dt)
	sy = Game.damp(sy, 1.0, 14.0, dt)
	blink_t -= dt
	if blink_t < -0.12:
		blink_t = room.rng.randf_range(1.5, 4.5)

	# carried by a moving platform
	if ride != null:
		grid.move_x(self, ride.dx)
		y = ride.y - h

	var mx := (1.0 if down.get("right", false) else 0.0) - (1.0 if down.get("left", false) else 0.0)
	var my := (1.0 if down.get("down", false) else 0.0) - (1.0 if down.get("up", false) else 0.0)
	if hurt_t > 0.0:
		mx = 0.0
	if mx != 0.0 and dash_t <= 0.0:
		face = mx
	look_t = look_t + dt if (my != 0.0 and on_ground and mx == 0.0) else 0.0

	# --- bash (dash) ---
	if pressed.get("dash", false):
		dash_buf = 0.1
	elif dash_buf > 0.0:
		dash_buf -= dt
	if dash_buf > 0.0 and tools.bash and can_dash and dash_cd <= 0.0 and hurt_t <= 0.0:
		var ddx := mx
		var ddy := my
		if on_ground and ddy > 0.0:
			ddy = 0.0
		if ddx == 0.0 and ddy == 0.0:
			ddx = face
		var n := sqrt(ddx * ddx + ddy * ddy)
		dash_dx = ddx / n
		dash_dy = ddy / n
		dash_t = DASH_T
		dash_cd = DASH_T + DASH_CD
		can_dash = false
		dash_id += 1
		dash_buf = 0.0
		jumping = false
		if ddx != 0.0:
			face = Game.sign_of(ddx)
		sx = 0.7 if (ddy != 0.0 and ddx == 0.0) else 1.45
		sy = 1.4 if (ddy != 0.0 and ddx == 0.0) else 0.65
		room.stop(0.035)
		room.shake(0.14)
		Audio.sfx("dash")
		room.ring(x + 5, y + 5, 3, 16, "#ffffff", 0.2)
	# --- claw ---
	if pressed.get("attack", false):
		atk_buf = 0.12
	elif atk_buf > 0.0:
		atk_buf -= dt
	if atk_buf > 0.0 and atk_cd <= 0.0 and dash_t <= 0.0 and hurt_t <= 0.0:
		atk_buf = 0.0
		atk_t = 0.17
		atk_cd = 0.27
		atk_id += 1
		atk_live = true
		atk_dir = "u" if down.get("up", false) else ("d" if (down.get("down", false) and not on_ground) else "f")
		atk_face = face
		atk_dmg = 2 if tools.opus else 1
		Audio.sfx("swipeBig" if tools.opus else "swipe")
		if atk_dir == "f":
			sx = 1.15
			sy = 0.9
	if atk_t > 0.0:
		atk_t -= dt
		atk_live = atk_t > 0.05

	prev_bottom = y + h
	var was_ground := on_ground
	var fall_v := vy

	if dash_t > 0.0:
		dash_t -= dt
		vx = dash_dx * DASH_SPEED
		vy = dash_dy * DASH_SPEED
		ghost_t -= dt
		if ghost_t <= 0.0:
			ghost_t = 0.022
			ghosts.append({"x": x, "y": y, "life": 0.2, "face": face, "sx": sx, "sy": sy})
		# smash through cracked blocks
		var nx := x + vx * dt
		var ny := y + vy * dt
		for ty in range(floori((ny - 1) / T), floori((ny + h) / T) + 1):
			for tx in range(floori((nx - 1) / T), floori((nx + w) / T) + 1):
				room.break_tile(tx, ty)
		if dash_t <= 0.0:
			vx = dash_dx * RUN * 1.1
			vy = dash_dy * 130.0 if dash_dy < 0.0 else dash_dy * RUN
	else:
		var target := mx * RUN
		var acc := (ACC if mx != 0.0 else DEC) if on_ground else (AIR_ACC if mx != 0.0 else AIR_DEC)
		if lock > 0.0 and not on_ground:
			acc *= 0.2
		if absf(vx) > RUN and Game.sign_of(vx) == mx:
			acc = 260.0
		vx = Game.approach(vx, target, acc * dt)
		var gr := G_UP if vy < 0.0 else G_DOWN
		if absf(vy) < 38.0 and down.get("jump", false) and not on_ground:
			gr *= 0.55
		vy += gr * dt
		if not on_ground and wall_dir != 0 and mx == wall_dir and vy > 0.0:
			vy = minf(vy, WALL_SLIDE)
			if room.rng.randf() < 0.3:
				room.part(x + (w if wall_dir > 0 else 0.0), y + room.rng.randf_range(0, h), -wall_dir * room.rng.randf_range(5, 20), room.rng.randf_range(-10, 10), 0.25, 1, "#e8e0f0", 0.0)
		if vy > MAXFALL:
			vy = MAXFALL

	# --- jumping ---
	if on_ground:
		coyote = COYOTE
	else:
		coyote -= dt
	if pressed.get("jump", false):
		jump_buf = BUFFER
	elif jump_buf > 0.0:
		jump_buf -= dt
	if wall_dir != 0 and not on_ground:
		wall_coy = 0.09
		last_wall = wall_dir
	else:
		wall_coy -= dt
	if jump_buf > 0.0 and hurt_t <= 0.0:
		if down.get("down", false) and on_ground and on_oneway():
			drop_t = 0.2
			jump_buf = 0.0
			on_ground = false
			coyote = 0.0
			y += 1.0
		elif coyote > 0.0:
			vy = -JUMP
			coyote = 0.0
			jump_buf = 0.0
			jumping = true
			on_ground = false
			dash_t = 0.0
			sx = 0.72
			sy = 1.32
			room.dust(x + 5, y + h, 4)
			Audio.sfx("jump")
			if Game.debug or Game.selftest:
				print("CLAWD: jump")
			if ride != null:
				vx += ride.dx * 60.0 * 0.6
		elif wall_coy > 0.0 and dash_t <= 0.0:
			var d := last_wall
			vx = -d * WJ_X
			vy = -WJ_Y
			lock = WJ_LOCK
			face = -d
			jumping = true
			jump_buf = 0.0
			wall_coy = 0.0
			sx = 0.75
			sy = 1.28
			room.dust(x + (w if d > 0 else 0.0), y + 6, 4, -d)
			Audio.sfx("walljump")
		elif tools.sudo and can_double and dash_t <= 0.0:
			vy = -DJUMP
			can_double = false
			jumping = true
			jump_buf = 0.0
			sx = 0.75
			sy = 1.3
			room.ring(x + 5, y + h, 2, 13, "#ffffff", 0.22)
			room.dust(x + 5, y + h + 2, 5)
			Audio.sfx("djump")
	if jumping and vy < 0.0 and not down.get("jump", false):
		vy *= 0.45
		jumping = false
	if vy >= 0.0:
		jumping = false

	# --- move + collide ---
	var hx := grid.move_x(self, vx * dt)
	if hx != 0:
		if dash_t > 0.0 and dash_dy == 0.0:
			dash_t = minf(dash_t, 0.02)
		vx = 0.0
	var hy := grid.move_y(self, vy * dt, drop_t > 0.0)
	ride = null
	if hy == 0 and vy >= 0.0 and drop_t <= 0.0:
		var pl = grid.plat_under(self, prev_bottom, room.plats)
		if pl != null:
			y = pl.y - h
			hy = 1
			ride = pl
	if hy < 0:
		# corner correction: slip round a ledge instead of bonking on it
		var slipped := false
		var o := 1
		while o <= 4 and not slipped:
			for s in [1, -1]:
				if not grid.box_hits_solid(x + s * o, y - 2, w, h):
					x += s * o
					slipped = true
					break
			o += 1
		if not slipped:
			vy = 0.0
			jumping = false
	on_ground = hy > 0
	if on_ground:
		if not was_ground and fall_v > 110.0:
			sx = 1.3
			sy = 0.7
			room.dust(x + 5, y + h, 5)
			Audio.sfx("land", {"vol": minf(1.0, fall_v / 300.0)})
		vy = 0.0
		can_dash = true
		can_double = true
		# unstable ground
		var ty := floori((y + h + 1) / T)
		for tx in range(floori(x / T), floori((x + w - 0.01) / T) + 1):
			if grid.tile(tx, ty) == TileGrid.CRUMBLE:
				var i := ty * grid.w + tx
				if not grid.crumble.has(i):
					grid.crumble[i] = {"s": 1, "t": 0.42}
		# remember solid footing for hazards
		if ride == null and hurt_t <= 0.0:
			var a := grid.tile(floori((x + 1) / T), ty)
			var b := grid.tile(floori((x + w - 1) / T), ty)
			var ny2 := floori((y + 4) / T)
			var sp := TileGrid.SPIKE_U
			if (a == TileGrid.SOLID or a == TileGrid.ONEWAY) and (b == TileGrid.SOLID or b == TileGrid.ONEWAY) and grid.tile(floori((x - 6) / T), ny2) != sp and grid.tile(floori((x + w + 6) / T), ny2) != sp:
				set_safe(x, y)
		if absf(vx) > 30.0:
			run_t += dt * absf(vx) / RUN
			if int(run_t * 7) != int((run_t - dt) * 7) and room.rng.randf() < 0.5:
				room.dust(x + 5 - face * 4, y + h, 1, -face)
		else:
			run_t = 0.0
	# walls
	wall_dir = 0
	if not on_ground:
		if grid.box_hits_solid(x + w, y + 2, 2, h - 4):
			wall_dir = 1
		elif grid.box_hits_solid(x - 2, y + 2, 2, h - 4):
			wall_dir = -1

func on_oneway() -> bool:
	var grid := room.grid
	var ty := floori((y + h + 1) / T)
	var any := false
	for tx in range(floori(x / T), floori((x + w - 0.01) / T) + 1):
		if grid.solid(tx, ty):
			return false
		if grid.tile(tx, ty) == TileGrid.ONEWAY:
			any = true
	return any or ride != null

func on_hit(e, res: String, b) -> void:
	var hx := clampf(x + 5 + (atk_face * 14 if atk_dir == "f" else 0.0), b.x, b.x + b.w)
	var hy := clampf(y + 5 + (-14.0 if atk_dir == "u" else (14.0 if atk_dir == "d" else 0.0)), b.y, b.y + b.h)
	if res == "block":
		room.spark(hx, hy, "#ffffff", 7)
		Audio.sfx("clang")
		room.stop(0.04)
		if atk_dir == "f":
			vx = -atk_face * 90.0
	else:
		room.stop(0.075 if res == "kill" else 0.05)
		room.shake(0.3 if res == "kill" else 0.16)
		room.spark(hx, hy, "#fff3e4", 6)
		if atk_dir == "f" and not on_ground:
			vx -= atk_face * 50.0
		add_meter(4)
	if atk_dir == "d":
		bounce(1.0)

func bounce(k: float) -> void:
	vy = -(JUMP * 0.96 if (Controls.down.get("jump", false) and not frozen) else POGO) * k
	jumping = false
	can_dash = true
	can_double = true
	on_ground = false
	sx = 0.8
	sy = 1.25
	grace = 0.14                 # a clean bounce never costs a pip

func spring(s: Dictionary) -> void:
	if s.t > 0.12:
		return
	vy = -470.0
	jumping = false
	can_dash = true
	can_double = true
	on_ground = false
	dash_t = 0.0
	sx = 0.65
	sy = 1.45
	s.t = 0.25
	room.dust(s.x + 6, s.y, 6)
	Audio.sfx("spring")

func scatter(vx0: float, vy0: float) -> void:
	var bx := x + 5
	var by := y + h
	for q in ClawdDraw.clawd_pixels():
		if q.eye:
			continue
		room.part(bx + q.x, by + q.y, q.x * room.rng.randf_range(8, 22) + vx0, q.y * room.rng.randf_range(6, 16) - 60 + vy0, room.rng.randf_range(0.6, 1.1), 1, Game.COL.clawdHi if room.rng.randf() < 0.15 else Game.COL.clawd, 520.0, {"bounce": true, "keep": true})

func hurt(d: int, src_x: float) -> bool:
	if inv > 0.0 or dash_t > 0.0 or dead or gone:
		return false
	hp -= d
	room.hits += 1
	inv = 1.3
	hurt_t = 0.22
	jumping = false
	vx = (-1.0 if x + 5 < src_x else 1.0) * 150.0
	vy = -175.0
	on_ground = false
	room.stop(0.09)
	room.shake(0.5)
	room.flash_screen(0.22, Game.COL.hazard)
	room.burst(x + 5, y + 5, 8, [Game.COL.clawd, Game.COL.clawdHi, "#ffffff"], 120.0, 300.0)
	Audio.sfx("hurt")
	if hp <= 0:
		die()
	elif room.rng.randf() < 0.22:
		room.pop(x + 5, y - 12, QUIPS[room.rng.randi() % QUIPS.size()], Game.COL.paper, true)
	return true

# spikes, liquid and pits: lose a pip, come back on the last solid ground
func hazard() -> void:
	if dead or gone:
		return
	hp -= 1
	room.hits += 1
	scatter(vx * 0.3, 0.0)
	room.stop(0.08)
	room.shake(0.5)
	room.flash_screen(0.22, Game.COL.hazard)
	if hp <= 0:
		die(true)
		return
	Audio.sfx("hurt")
	gone = true
	gone_t = 0.8
	x = safe.x
	y = safe.y
	vx = 0.0
	vy = 0.0
	dash_t = 0.0
	atk_t = 0.0
	ride = null
	on_ground = true

func die(silent := false) -> void:
	if dead:
		return
	dead = true
	hp = 0
	if not silent:
		scatter(vx * 0.3, -40.0)
	room.ring(x + 5, y + 5, 3, 30, Game.COL.clawdHi, 0.4)
	room.stop(0.14)
	room.shake(0.8)
	Audio.sfx("die")
	room.events.append("death")

# ---------------------------------------------------------------- drawing (port of Player.draw, without lighting)
func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_body()

func draw_body() -> void:
	var px := floori(x + w / 2.0 + 0.5)
	var py := floori(y + h + 0.5)
	if dead:
		return
	if gone:
		if gone_t < 0.34:                  # pixels knit themselves back together
			var u := maxf(0.0, gone_t / 0.34)
			var k := u * u
			for q in ClawdDraw.clawd_pixels():
				var a := Game.hash3(q.x, q.y, 5) * 6.28
				var d := 30.0 + Game.hash3(q.y, q.x, 9) * 40.0
				var col := Color(Game.COL.eye if q.eye else Game.COL.clawd)
				draw_rect(Rect2(floori(px + q.x + cos(a) * d * k + 0.5), floori(py + q.y + sin(a) * d * k + 0.5), 1, 1), col)
		return
	for gh in ghosts:
		ClawdDraw.draw_clawd(self, floori(gh.x + 5 + 0.5), floori(gh.y + h + 0.5), {"face": gh.face, "col": "#ffd0b8", "alpha": gh.life * 3.0, "noEyes": true, "sx": gh.sx, "sy": gh.sy})
	if inv > 0.0 and hurt_t <= 0.0 and int(inv * 20) % 2 == 1:
		return
	var o := {"face": face, "sx": sx, "sy": sy}
	var air := not on_ground
	if hurt_t > 0.0:
		o.eyes = "hurt"
		o.col = "#ffffff"
		o.armL = -2
		o.armR = -2
		o.legs = [2, 1, 1, 2]
	elif dash_t > 0.0:
		o.eyes = "shut"
		o.legs = [1, 1, 1, 1]
		o.col = "#ffe2c4"
	elif air:
		if wall_dir != 0 and vy > 0.0:
			o.eyeY = 1
			if wall_dir > 0:
				o.armR = -2
			else:
				o.armL = -2
			o.legs = [2, 1, 2, 1]
		elif vy < -40.0:
			o.armL = -1
			o.armR = -1
			o.legs = [2, 2, 2, 2]
			o.eyeY = -1
		elif vy > 60.0:
			o.armL = -3
			o.armR = -3
			o.legs = [2, 1, 1, 2]
			o.eyeY = 1
		else:
			o.armL = -2
			o.armR = -2
			o.legs = [1, 2, 2, 1]
	elif absf(vx) > 24.0:
		var f := int(run_t * 13) % 4
		o.legs = [2, 1, 2, 1] if f == 0 else ([1, 2, 1, 2] if f == 2 else [2, 2, 2, 2])
		o.lift = 0 if f % 2 == 1 else -1
		o.armL = -1 if f == 0 else (1 if f == 2 else 0)
		o.armR = -o.armL
	else:
		var breathe := sin(t * 2.6) > 0.55
		if breathe:
			o.lift = 1
			o.legs = [1, 1, 1, 1]
		if blink_t < 0.0:
			o.blink = true
		if look_t > 0.25:
			o.eyeY = -1 if Controls.down.get("up", false) else 1
	if atk_t > 0.0 and atk_dir == "f":
		o.reach = 3
	if atk_t > 0.0 and atk_dir == "u":
		o.armL = -4
		o.armR = -4
		o.eyeY = -1
	ClawdDraw.draw_clawd(self, px, py, o)
	if atk_t > 0.0:
		var set_name := "slashBig" if tools.opus else "slash"
		var f2 := 0 if atk_t > 0.115 else (1 if atk_t > 0.05 else 2)
		var pcy := py - 5
		var key := "u" if atk_dir == "u" else ("d" if atk_dir == "d" else ("f" if atk_face > 0 else "b"))
		var tex := Gfx.tex("%s_%s_%d" % [set_name, key, f2])
		var n := tex.get_width()
		var pos := Vector2.ZERO
		if atk_dir == "u":
			pos = Vector2(px - n / 2.0, pcy - 1 - (n - 3))
		elif atk_dir == "d":
			pos = Vector2(px - n / 2.0, pcy + 1 - 3)
		elif atk_face > 0:
			pos = Vector2(px + 1 - 3, pcy - n / 2.0)
		else:
			pos = Vector2(px - 1 - (n - 3), pcy - n / 2.0)
		draw_texture(tex, Vector2(floori(pos.x), floori(pos.y)))
