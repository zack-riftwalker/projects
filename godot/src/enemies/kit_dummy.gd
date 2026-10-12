class_name KitDummy
extends Boss
# KitDummy: the sparring dummy that proves the boss kit (lab room Z06, never in the main game). It uses only the kit: lunge -> orbs
# -> drop, announced with a cue each; if a player keeps swiping it from close by (rule 8: BossRead.greedy) it guards that player, and
# a swipe into the guard is answered by a riposte. It never dies and gives nothing.

const IDS := ["lunge", "orbs", "drop", "guard", "riposte"]
const CYCLE := ["lunge", "orbs", "drop"]
const LUNGE_DIST := 150.0
const LUNGE_SPEED := 420.0
const WAKE := 160.0
const INK := "#1b1226"
const GREY := "#8d8798"
const LIGHT := "#c3bccd"

var lab_dummy := true            # (not a room boss: the guest does not make it `room.boss`)
var cycle := 0
var strike_sid := 0
var idle_t := 0.0
var riposte_to := ""             # the player whose swipe the guard blocked: the next attack is a riposte on it

func _init(r: Room, bx: float, by: float, _hp := 999) -> void:
	super(r, bx, by, 18, 26, 999)
	boss_name = "SPARRING DUMMY"
	sub = "boss kit"
	col = GREY
	face = -1.0
	drop_n = 0
	loot = 0
	kit_init()

func plan_ids() -> Array:
	return IDS

func _phys(dt: float, grav := 900.0) -> void:
	vy = minf(vy + grav * dt, 320.0)
	hit_wall = room.grid.move_x(self, vx * dt)
	var hy := room.grid.move_y(self, vy * dt, true)
	on_ground = hy > 0
	if hy != 0:
		vy = 0.0

func on_damage() -> void:
	if hpf < max_hp / 2.0:
		hpf = float(max_hp)             # a sparring partner: it gets up again
		hp = max_hp

# a guard stops claws, dashes and agents
func blocks(_dx: float, _dy: float, how: String) -> bool:
	return plan_active() and plan.id == "guard" and (how == "swipe" or how == "dash" or how == "agent")

func hit(d: int, dx: float, dy: float, how: String, box = null) -> String:
	if active and blocks(dx, dy, how):
		riposte_to = kit_key_of(room.attacker)
		Audio.sfx("clang")
		room.spark(cx + face * 8.0, y + 8.0, "#ffffff", 8)
		room.stop(0.04)
		plan_cut()
		return "block"
	return super.hit(d, dx, dy, how, box)

func update(dt: float) -> void:
	tick(dt)
	read.update(dt)
	if not active:
		_phys(dt)
		for k in kit_keys():
			if kit_dist(k) < WAKE:
				active = true
				passive = false
				idle_t = 0.6
		return
	if plan.is_empty():
		vx = 0.0
		idle_t -= dt
		plan_clock += dt
		if idle_t <= 0.0:
			_choose()
	else:
		_plan_logic(dt)
	_phys(dt)

# rule 8 first (a greedy player is guarded against), then the riposte that is owed, then the cycle
func _choose() -> void:
	var keys := kit_keys()
	if keys.is_empty():
		idle_t = 0.3
		return
	if riposte_to != "":
		var k := riposte_to
		riposte_to = ""
		if kit_alive(k):
			_start("riposte", k)
			return
	for k in keys:
		if read.greedy(k):
			read.hits[k].clear()
			_start("guard", k)
			return
	var id: String = CYCLE[cycle % CYCLE.size()]
	cycle += 1
	_start(id, kit_pick_target())

func _footprint(id: String, tgt: String) -> Array:
	var ap := kit_aim(tgt)
	match id:
		"lunge", "riposte":
			return [cx + 8.0 if face > 0.0 else cx - 8.0 - LUNGE_DIST, y + 4.0, LUNGE_DIST, h - 4.0]
		"drop":
			return [clampf(ap.x - 32.0, 0.0, room.pw - 64.0), Boss.FLOOR - 96.0, 64.0, 96.0]
	return [0.0, 0.0, 0.0, 0.0]

func _start(id: String, tgt: String) -> void:
	var ap := kit_aim(tgt)
	face = 1.0 if ap.x >= cx else -1.0
	match id:
		"lunge":
			plan_start("lunge", "lunge", tgt, _footprint(id, tgt), 0.40)
		"orbs":
			plan_start("orbs", "proj", tgt, [0.0, 0.0, 0.0, 0.0])
		"drop":
			plan_start("drop", "slam", tgt, _footprint(id, tgt), 0.50)
		"guard":
			plan_start("guard", "guard", tgt, [0.0, 0.0, 0.0, 0.0])
		"riposte":
			plan_start("riposte", "lunge", tgt, _footprint(id, tgt), 0.40, 0.8)
	Game.dlog("%s attack %s on %s (plan %d)" % [boss_name, id, tgt, plan.seq])

func _plan_logic(dt: float) -> void:
	# while the cue is long enough the aim follows the target; in the last `lock` seconds it is fixed
	if plan.ph == "cue" and plan.t > float(plan.lock) and plan.id != "orbs" and plan.id != "guard":
		var ap := kit_aim(plan.tgt)
		face = 1.0 if ap.x >= cx else -1.0
		plan.fp = _footprint(plan.id, plan.tgt)
	if plan.id == "guard":
		var ap2 := kit_aim(plan.tgt)
		face = 1.0 if ap2.x >= cx else -1.0
	vx = 0.0
	if plan.ph == "active" and (plan.id == "lunge" or plan.id == "riposte"):
		vx = face * LUNGE_SPEED
		if hit_wall != 0:
			vx = 0.0
	var ev := plan_step(dt)
	match ev:
		"active":
			match plan.id:
				"lunge", "riposte":
					strike_sid = Game.next_strike_id()
					Audio.sfx("dash", {"vol": 0.7})
				"orbs":
					_throw_orbs()
				"drop":
					strike_sid = Game.next_strike_id()
					Audio.sfx("thud")
					room.shake(0.4)
		"recover":
			strike_sid = 0
			vx = 0.0
		"done":
			strike_sid = 0
			idle_t = 0.9

func _throw_orbs() -> void:
	var ap := kit_aim(plan.tgt)
	var ox: float = cx + face * 6.0
	var oy: float = y + 8.0
	var dist := Vector2(ap.x - ox, ap.y - oy).length()
	if dist < 60.0:                                     # (an orb always travels a little: ≥ 0.45 s to the target)
		ox -= face * (60.0 - dist)
		dist = 60.0
	var base := atan2(ap.y - oy, ap.x - ox)
	var speed := clampf(dist / 0.55, 90.0, 220.0)
	for da in [-0.12, 0.12]:
		var a: float = base + da
		room.shoot(ox, oy, cos(a) * speed, sin(a) * speed, {"kind": "diamond", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 2.5, "dmg": 1})
	Audio.sfx("shoot")

func harmboxes() -> Array:
	var b: Array = []
	if plan_active():
		match plan.id:
			"lunge", "riposte":
				b.append({"x": x + 2, "y": y + 2, "w": w - 4, "h": h - 3})
				b.append({"x": x + w if face > 0.0 else x - 18.0, "y": y + 6, "w": 18.0, "h": 12.0, "sid": strike_sid, "catchable": true})
			"drop":
				var fp: Array = plan.fp
				b.append({"x": fp[0], "y": fp[1], "w": fp[2], "h": fp[3]})
	return b

# ---- drawing ----
func draw_boss_body(ci: CanvasItem) -> void:
	var ink := Color(INK)
	var bx := floorf(x)
	var by := floorf(y)
	var lunging: bool = plan_active() and (plan.id == "lunge" or plan.id == "riposte")
	ci.draw_rect(Rect2(bx, by, w, h), ink)
	ci.draw_rect(Rect2(bx + 1, by + 10, w - 2, h - 11), Color(GREY))          # body
	ci.draw_rect(Rect2(bx + 1, by + 1, w - 2, 10), Color(LIGHT))              # head
	var ex := bx + (10.0 if face > 0.0 else 3.0)
	ci.draw_rect(Rect2(ex, by + 4, 2, 2), ink)
	ci.draw_rect(Rect2(ex + 3, by + 4, 2, 2), ink)
	ci.draw_rect(Rect2(bx + 4, by + 13, w - 8, 2), ink)                      # a target painted on the chest
	ci.draw_rect(Rect2(bx + 7, by + 15, 4, 6), ink)
	ci.draw_rect(Rect2(bx + 8, by + 16, 2, 4), Color("#ff4f6d"))
	if lunging:
		var fx_ := bx + w if face > 0.0 else bx - 16.0
		ci.draw_rect(Rect2(fx_, by + 8, 16, 3), Color("#ffffff"))
	if plan_active() and plan.id == "guard":
		var gx := bx + w if face > 0.0 else bx - 5.0
		ci.draw_rect(Rect2(gx - 1, by + 1, 7, h - 2), ink)
		ci.draw_rect(Rect2(gx, by + 2, 5, h - 4), Color("#7cc4ff"))

func draw_boss_overlay(ci: CanvasItem) -> void:
	if not active:
		PixelText.draw_text(ci, boss_name, cx - PixelText.text_width(boss_name, {"tiny": true}) / 2.0, y - 10.0, Game.COL.dim, {"tiny": true})
	draw_plan(ci)
	if not plan.is_empty() and plan.fam == "guard" and plan.ph != "recover":
		var tw := PixelText.text_width("// nit:", {"tiny": true})
		var bx := clampf(floorf(cx - tw / 2.0 - 3.0), 2.0, Game.W - tw - 8.0)
		Gfx.panel(ci, bx, y - 22.0, tw + 6.0, 12.0, "#f4ede0", INK)
		PixelText.draw_text(ci, "// nit:", bx + 3.0, y - 19.0, INK, {"tiny": true})
	if plan_active() and plan.id == "drop":
		var fp: Array = plan.fp
		ci.draw_rect(Rect2(fp[0], fp[1], fp[2], fp[3]), Color(1, 1, 1, 0.55))

# ---- net ----
func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, strike_sid]
	f.append_array(plan_fields())
	return f

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	strike_sid = int(f[3])
	plan_apply(f.slice(4))

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
