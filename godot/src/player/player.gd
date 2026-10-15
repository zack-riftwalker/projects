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
var cache_bonus := false           # review cache: set by a catch, spent by the next claw hit (+1)
var rate_cd := 0.0                  # rate_limit: seconds until the next hit may hurt
var parried := {}                # strike ids this player parried (catch): that strike can no longer hurt it
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
var agents_t := 0.0             # seconds the two agents still fly (the room simulates them)
var special_t := 0.0            # how long [special] has been held (a tap casts agents, a hold focuses)
var cache_cool := 0.0           # seconds until the cache station fills the meter again
var grace := 0.0
var frozen := false
var in_menu := false            # a bench menu or the shop is open on this page while the co-op world goes on: no input, the body stands
var look_t := 0.0
var focus_hold := 0.0
var focus_t := -1.0              # < 0: not focusing
var focus_ring := 0.0
var downed := false              # co-op: lying there, the partner can bring Clawd back
var down_t := -1.0
var slow_t := 0.0                # SCRAPER's thread (MVB3-02): RUN and air acceleration halved while > 0
var jam := false                 # DDOS bits round the body (set by the room each frame): RUN x 0.6, no dash start
var zip_t := 0.0                 # how long the current zip has run
var zip_cut := 0.25              # a tapped ring cuts the zip at this age: 0.25 s, or 60 % of the way when the zip is shorter than that (CURL_RANGE 104 px at 400 px/s never lasts 0.25 s)
var zip := -1                    # curl (MVB2-03): the anchor Clawd is zipping to (-1: not zipping)
var zip_dx := 0.0                # the horizontal direction of the zip (for the exit speed)
var zip_blocked := 0
var bp_cd := 0.0                 # breakpoint: seconds until the next press (Game.BP_COOLDOWN)
var curl_last := -1              # the anchor used last: not again before landing
var push_warned := false
var ssh_x0 := 0.0
var ssh_t := 0.0                 # ssh (MVB2-04): seconds of tunnelling left
var ssh_dir := 0.0
var push_t := 0.0
var phase_fire := false
var spec_used := false           # this [special] press was spent on curl: no agents on release, no focus

func _init(r: Room, px: float, py: float) -> void:
	room = r
	x = px
	y = py
	tools = Game.tools
	max_hp = Game.max_hp
	hp = max_hp
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

# catch: a swipe that has just started (the first catch_window seconds of the 0.17 s swing) catches a yellow attack
func catch_window_open() -> bool:
	return bool(tools.get("catch", false)) and atk_t > 0.17 - float(Game.dv("catch_window"))

func set_safe(sx_: float, sy_: float) -> void:
	safe.x = sx_
	safe.y = sy_

# the context meter (0-99): every landed claw hit and stomp fills it, focus spends it
func gain_meter() -> void:
	var was := meter
	meter = minf(float(Game.METER_MAX), meter + float(Game.dv("meter_per_hit")) + float(Game.mod_meter_bonus()))
	if was < Game.METER_MAX and meter >= Game.METER_MAX and tools.get("agents", false) and agents_t <= 0.0:
		room.pop(x + 5, y - 14, "subagents ready", "#ffe2c4", true)
		Audio.sfx("agent")

func update(dt: float) -> void:
	var grid := room.grid
	var down: Dictionary = {} if frozen or in_menu else Controls.down
	var pressed: Dictionary = {} if frozen or in_menu else Controls.pressed
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
	if slow_t > 0.0: slow_t -= dt
	if rate_cd > 0.0: rate_cd -= dt
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

	# --- focus: hold [special] on the ground to turn context into hit points (rooted while it runs) ---
	var can_focus: bool = down.get("special", false) and not spec_used and on_ground and atk_t <= 0.0 and dash_t <= 0.0 and hurt_t <= 0.0 and hp < max_hp and meter >= Game.FOCUS_COST and not frozen
	if can_focus:
		focus_hold += dt
		if focus_hold >= Game.FOCUS_HOLD:
			if focus_t < 0.0:
				focus_t = 0.0
				focus_ring = 0.0
				Audio.sfx("charge")
			focus_t += dt
			focus_ring += dt
			if focus_ring >= 0.3:
				focus_ring = 0.0
				room.ring(x + 5, y + 5, 14, 3, Game.COL.okHi, 0.3)
			if focus_t >= Game.mod_focus_time():
				hp = mini(max_hp, hp + 1)
				meter -= Game.FOCUS_COST
				Audio.sfx("heal")
				room.burst(x + 5, y + 5, 8, [Game.COL.ok, Game.COL.okHi, "#ffffff"], 70.0, 100.0)
				room.pop(x + 5, y - 12, "+1", Game.COL.okHi)
				focus_t = -1.0
				focus_hold = Game.FOCUS_HOLD          # the next focus starts at once if it is still possible
	else:
		focus_hold = 0.0
		focus_t = -1.0
	if focus_t >= 0.0:
		down = {}
		pressed = {}
		vx = 0.0

	# --- agents: a TAP of [special] (released before the focus hold) with a full meter sends two helpers ---
	if agents_t > 0.0:
		agents_t -= dt
	if cache_cool > 0.0:
		cache_cool -= dt
	if bp_cd > 0.0:
		bp_cd -= dt
	if not frozen and not in_menu and Controls.down.get("special", false):          # (Controls, not `down`: a running focus empties `down`)
		special_t += dt
	elif not frozen and not in_menu and Controls.released.get("special", false):
		if special_t < Game.FOCUS_HOLD and tools.get("agents", false) and not spec_used:
			if meter >= Game.METER_MAX and agents_t <= 0.0:
				meter = 0.0
				agents_t = 11.0
				Audio.sfx("agent")
				room.pop(x + 5, y - 14, "Task(subagent) x2", "#ffe2c4", true)
				room.cast_agents(self)
			else:
				Audio.sfx("uiBack")
		special_t = 0.0
	else:
		special_t = 0.0

	if not Controls.down.get("special", false) or frozen or in_menu:
		spec_used = false
	# --- curl: [special] near a GET ring zips to it (MVB2-03) ---
	if zip < 0 and tools.get("curl", false) and not frozen and not in_menu and hurt_t <= 0.0 and focus_t < 0.0 and Controls.pressed.get("special", false):
		var cmx := (1.0 if down.get("right", false) else 0.0) - (1.0 if down.get("left", false) else 0.0)
		var ai := room.pick_anchor(self, cmx)
		if ai >= 0:
			var anc: Dictionary = room.anchors()[ai]
			zip = ai
			zip_t = 0.0
			zip_cut = clampf(0.6 * Vector2(float(anc.x) - (x + w / 2.0), float(anc.y) - (y + h / 2.0)).length() / Game.CURL_SPEED, 0.04, 0.25)
			zip_dx = float(anc.x) - (x + w / 2.0)
			zip_blocked = 0
			dash_t = 0.0
			spec_used = true
			special_t = 0.0
			Audio.sfx("dash")
			room.ring(float(anc.x), float(anc.y), 2, 12, "#7cc4ff", 0.2)
	# --- breakpoint: [special] facing a machine or a creature stops it for 3.5 s (a curl anchor in reach comes first) ---
	if zip < 0 and not spec_used and tools.get("breakpoint", false) and bp_cd <= 0.0 and not frozen and not in_menu and hurt_t <= 0.0 and focus_t < 0.0 and Controls.pressed.get("special", false):
		if room.bp_press(self):
			bp_cd = Game.BP_COOLDOWN
			spec_used = true
			special_t = 0.0
	if zip >= 0:
		if _zip_step(dt, pressed):
			return
	var mx := (1.0 if down.get("right", false) else 0.0) - (1.0 if down.get("left", false) else 0.0)
	var my := (1.0 if down.get("down", false) else 0.0) - (1.0 if down.get("up", false) else 0.0)
	if hurt_t > 0.0:
		mx = 0.0
	# --- ssh: push into a thin red firewall for 0.3 s and tunnel through (MVB2-04) ---
	if ssh_t > 0.0:
		if _ssh_step(dt):
			return
	elif tools.get("ssh", false) and mx != 0.0 and dash_t <= 0.0 and zip < 0 and hurt_t <= 0.0 and not frozen and not in_menu:
		var open_n := ssh_probe(mx)
		if open_n == 0:
			push_t = 0.0
			push_warned = false
		elif open_n < 0:
			push_t += dt
			if push_t >= Game.SSH_HOLD and not push_warned:
				push_warned = true
				room.pop(x + 5.0, y - 12.0, "too thick for ssh", "#ff9ad8", true)
				Audio.sfx("thud")
		else:
			push_t += dt
			if push_t >= Game.SSH_HOLD:
				ssh_start(mx)
	else:
		push_t = 0.0
		push_warned = false
	if mx != 0.0 and dash_t <= 0.0:
		face = mx
	look_t = look_t + dt if (my != 0.0 and on_ground and mx == 0.0) else 0.0

	# --- bash (dash) ---
	if pressed.get("dash", false):
		dash_buf = 0.1
	elif dash_buf > 0.0:
		dash_buf -= dt
	if dash_buf > 0.0 and tools.bash and can_dash and dash_cd <= 0.0 and hurt_t <= 0.0 and not jam:
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
		dash_cd = DASH_T + Game.mod_dash_cd()
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
		atk_dmg = (2 if tools.opus else 1) * Game.mod_claw_mult(hp) + (1 if cache_bonus and Game.mod_review_cache() else 0)
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
		var run_k := (0.5 if slow_t > 0.0 else 1.0) * (0.6 if jam else 1.0)
		var target := mx * RUN * run_k
		var acc := (ACC if mx != 0.0 else DEC) if on_ground else (AIR_ACC * (0.5 if slow_t > 0.0 else 1.0) if mx != 0.0 else AIR_DEC)
		if lock > 0.0 and not on_ground:
			acc *= 0.2
		if absf(vx) > RUN * run_k and Game.sign_of(vx) == mx:
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
		var pl = grid.plat_under(self, prev_bottom, room.ride_list())
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
		curl_last = -1
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

# the firewall bricks right ahead in direction dir: 0 = none; n >= 1 = n bricks in a row and a free spot beyond them (ssh can open it);
# -1 = a wall that does not open (too thick, another kind of solid, or no free spot past it)
func ssh_probe(dir: float) -> int:
	var grid := room.grid
	var y0 := floori((y + 1.0) / T)
	var y1 := floori((y + h - 1.0) / T)
	var col := floori((x + w + 0.5) / T) if dir > 0.0 else floori((x - 0.5) / T)
	var n := 0
	var any_fire := false
	for ty in range(y0, y1 + 1):
		if grid.tile(col, ty) == TileGrid.FIRE:
			any_fire = true
	if not any_fire:
		return 0
	while n <= Game.SSH_BRICKS:
		var fire := false
		var other := false
		for ty in range(y0, y1 + 1):
			var t := grid.tile(col, ty)
			if t == TileGrid.FIRE:
				fire = true
			elif grid.solid(col, ty):
				other = true
		if other:
			return -1
		if not fire:
			break
		n += 1
		col += int(dir)
	if n > Game.SSH_BRICKS:
		return -1
	# the first spot past the bricks must be free for the body (or be a W/E edge whose door is open)
	var nx := float(col) * T + (1.0 if dir > 0.0 else T - w - 1.0)
	if nx < 0.0 or nx + w > float(room.pw):
		return n if grid.tile(col, y0) == TileGrid.E else -1
	if grid.box_hits_solid(nx, y + 1.0, w, h - 2.0):
		return -1
	return n

func ssh_start(dir: float) -> void:
	ssh_t = 0.4
	ssh_dir = dir
	ssh_x0 = x
	phase_fire = true
	vx = dir * Game.SSH_SPEED
	vy = 0.0
	inv = maxf(inv, 0.45)
	push_t = 0.0
	Audio.sfx("dash")
	room.ring(x + 5.0, y + 5.0, 3, 14, "#ff9ad8", 0.25)

# the tunnel: no gravity, no input; it ends when the body overlaps no firewall brick any more. true = this step is the tunnel's
func _ssh_step(dt: float) -> bool:
	ssh_t -= dt
	vx = ssh_dir * Game.SSH_SPEED
	vy = 0.0
	prev_bottom = y + h
	ghost_t -= dt
	if ghost_t <= 0.0:
		ghost_t = 0.03
		ghosts.append({"x": x, "y": y, "life": 0.18, "face": face, "sx": 1.0, "sy": 1.0})
	room.grid.move_x(self, vx * dt)
	if ssh_dir > 0.0 and x + w > float(room.pw) + 2.0 or ssh_dir < 0.0 and x < -2.0:
		return true                                          # (past the edge: the room's door check carries the tunnel into the next room)
	var in_fire := false
	for ty in range(floori((y + 1.0) / T), floori((y + h - 1.0) / T) + 1):
		for tx in range(floori(x / T), floori((x + w - 0.001) / T) + 1):
			if room.grid.tile(tx, ty) == TileGrid.FIRE:
				in_fire = true
	if not in_fire:
		ssh_t = 0.0
		phase_fire = false
		vx = ssh_dir * RUN
		return true
	if ssh_t <= 0.0:                                           # it must never happen with the room data: put the body back
		Game.dlog("ssh: the tunnel did not end in %s, body put back" % room.id)
		x = ssh_x0
		phase_fire = false
		vx = 0.0
	return true

# the zip to a GET ring (curl): CURL_SPEED toward its centre, collisions apply; true when this step is the zip's (the normal physics is skipped)
func _zip_step(dt: float, pressed: Dictionary) -> bool:
	var list := room.anchors()
	if zip >= list.size() or hurt_t > 0.0:
		zip = -1
		return false
	if pressed.get("dash", false) and tools.bash:        # [dash] ends the zip and starts the dash
		zip = -1
		return false
	zip_t += dt
	if zip_t >= zip_cut and room.ring_tapped(zip):          # a SNIFFER taps this ring: the zip is cut on the way and Clawd falls (MVB3-03)
		zip = -1
		vx = 0.0
		vy = 0.0
		room.pop(x + 5.0, y - 12.0, "RST", "#ff5a5a", true)
		room.ring(x + 5.0, y + 5.0, 2, 14, "#ff5a5a", 0.25)
		Audio.sfx("thud")
		return false
	var a: Dictionary = list[zip]
	var d := Vector2(float(a.x) - (x + w / 2.0), float(a.y) - (y + h / 2.0))
	var dist := d.length()
	on_ground = false
	wall_dir = 0
	prev_bottom = y + h
	ghost_t -= dt
	if ghost_t <= 0.0:
		ghost_t = 0.03
		ghosts.append({"x": x, "y": y, "life": 0.16, "face": face, "sx": 1.0, "sy": 1.0})
	if dist <= Game.CURL_SPEED * dt + 0.5:
		var nx := float(a.x) - w / 2.0
		var ny := float(a.y) - h / 2.0
		if not room.grid.box_hits_solid(nx, ny, w, h):
			x = nx
			y = ny
		vy = -Game.CURL_POP
		vx = Game.sign_of(zip_dx) * Game.CURL_EXIT_VX if absf(zip_dx) > 4.0 else 0.0
		can_double = true
		can_dash = true
		jumping = false
		curl_last = zip
		zip = -1
		room.ring(float(a.x), float(a.y), 2, 14, "#d6f6ff", 0.25)
		Audio.sfx("spring")
		return true
	vx = d.x / dist * Game.CURL_SPEED
	vy = d.y / dist * Game.CURL_SPEED
	var hx := room.grid.move_x(self, vx * dt)
	var hy := room.grid.move_y(self, vy * dt, false)
	if hx != 0 or hy != 0:
		zip_blocked += 1
		if zip_blocked >= 2:
			vx = 0.0
			vy = 0.0
			zip = -1
	else:
		zip_blocked = 0
	if vx != 0.0:
		face = Game.sign_of(vx)
	return true

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
		if cache_bonus:
			cache_bonus = false                              # (the +1 is spent on this hit: the rest of the swing hits for the plain claw)
			atk_dmg = maxi(1, atk_dmg - 1)
		room.stop(0.075 if res == "kill" else 0.05)
		room.shake(0.3 if res == "kill" else 0.16)
		room.spark(hx, hy, "#fff3e4", 6)
		if atk_dir == "f" and not on_ground:
			vx -= atk_face * 50.0
		gain_meter()
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
	if inv > 0.0 or (dash_t > 0.0 and Game.dv("dash_iframes")) or dead or gone:
		return false
	if rate_cd > 0.0 and Game.mod_rate_limit():
		room.pop(x + 5, y - 12, "429", Game.COL.dim, true)
		return false                                         # rate_limit: at most one hit every 3 s (no damage, no knockback)
	if Game.mod_rate_limit():
		rate_cd = 3.0
	hp -= d
	room.hits += 1
	room.on_player_hurt(self, d)
	inv = float(Game.dv("inv_after_hit")) + Game.mod_inv_bonus()
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
	if room.liquid_y != null and safe.y + h > room.liquid_y - 8:       # the last safe spot is under water now
		var f = room.grid.find_safe(x, y, room.liquid_y)
		if f != null:
			set_safe(f.x, f.y)
	var under := room.grid.tile(floori((safe.x + w / 2.0) / T), floori((safe.y + h + 1.0) / T))
	if under != TileGrid.SOLID and under != TileGrid.ONEWAY:            # the ground it stood on is gone (a torn web, a fallen drawer)
		var f2 = room.grid.find_safe(safe.x, safe.y, room.liquid_y)
		if f2 != null:
			set_safe(f2.x, f2.y)
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
		if downed:                        # the downed body: flat, with the revive countdown
			ClawdDraw.draw_clawd(self, px, py, {"alpha": 0.75, "sy": 0.45, "legs": [0, 0, 0, 0], "eyes": "shut", "face": face})
			if down_t >= 0.0:
				PixelText.draw_text(self, str(ceili(down_t)), px, py - 16, "#ffffff", {"align": "c", "outline": Game.COL.ink})
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
	if ssh_t > 0.0:                                       # tunnelling: a short streak with tiny `ssh` text
		o.col = "#58f0c8"
		o.alpha = 0.75
		o.eyes = "shut"
		PixelText.draw_text(self, "ssh", px, py - 17, "#ff9ad8", {"align": "c", "tiny": true, "outline": Game.COL.ink})
	ClawdDraw.draw_clawd(self, px, py, o)
	if cache_bonus:
		PixelText.draw_text(self, "+1", px, py - 22, "#ffd23f", {"align": "c", "tiny": true, "outline": Game.COL.ink})
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
