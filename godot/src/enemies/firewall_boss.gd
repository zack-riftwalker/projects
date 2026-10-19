class_name FirewallBoss
extends Boss
# THE FIREWALL (docs/metroidvania/16-firewall.md, 16-firewall-build.md): a honeypot. M1 of the build has only the arena (HoneypotHall, owned by the room);
# the body is a door that stands in the lobby and does nothing yet: no attacks, no contact damage, hurt like any boss so the fight can end.
# The net fields already carry the hall's masks and the packets' clock, so the guest builds the same arena as the host (state, never events).

const GREEN := "#57ff8a"
const DOOR := Rect2(304.0, 80.0, 64.0, 96.0)             # the door on the east wall, cols 19-22, rows 5-10

func _init(r: Room, bx: float, by: float, base_hp := 82) -> void:
	super(r, bx, by, 64, 96, base_hp)
	boss_name = "GUEST SERVICES"
	sub = "welcome, guest"
	col = GREEN
	face = -1.0
	x = DOOR.position.x
	y = DOOR.position.y
	kit_init()

func plan_ids() -> Array:
	return []

func hz_kinds() -> Array:
	return ["note", "bite", "heat", "wave", "pdrop", "dropall"]

func _hall() -> HoneypotHall:
	return room.hpot

func start() -> void:
	super()
	var hl := _hall()
	if hl != null and room.mode != "guest":
		hl.seed = room.rng.randi() % 1000000                 # the fight's seed: which packets get inspected

func hurtboxes() -> Array:
	return [self]

func harmboxes() -> Array:
	return []                                                # a door has no contact damage

func update(dt: float) -> void:
	tick(dt)
	if dying:
		hz.clear()
		death_rattle(dt, 1.0, ["#ffffff", GREEN, "#2e9a52"])

# ---------------------------------------------------------------- drawing (a plain door until the body is built)
func draw_boss_body(ci: CanvasItem) -> void:
	var r := Rect2(x - global_position.x, y - global_position.y, w, h)
	ci.draw_rect(Rect2(r.position.x - 2.0, r.position.y - 2.0, r.size.x + 4.0, r.size.y + 2.0), Color("#143a26"))
	ci.draw_rect(r, Color("#2e9a52"))
	ci.draw_rect(Rect2(r.position.x + 6.0, r.position.y + 10.0, r.size.x - 12.0, r.size.y - 10.0), Color("#3fbf68"))
	ci.draw_rect(Rect2(r.position.x + 6.0, r.position.y + 10.0, r.size.x - 12.0, 2.0), Color("#7affa0"))
	PixelText.draw_text(ci, "EXIT", r.position.x + r.size.x / 2.0, r.position.y + 2.0, "#e8ffee", {"align": "c", "tiny": true})

# ---------------------------------------------------------------- the net (the guest sees the same arena)
func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0]
	if hl != null:
		f.append_array([hl.stage, 1 if hl.floor_on else 0, hl.furniture, hl.body_c0, hl.west_c1, hl.stairs, roundi(hl.burn_t0 * 100.0),
			roundi(hl.fist.position.x), roundi(hl.fist.position.y), roundi(hl.fist.size.x), roundi(hl.fist.size.y),
			roundi(hl.pk_t0 * 100.0), hl.seed, roundi(hl.green_t0 * 100.0), hl.pk_dir])
	else:
		f.append_array([0, 1, 7, 0, 0, 0, -100, 0, 0, 0, 0, roundi(HoneypotHall.NO_PK * 100.0), 0, -100, 0])
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 19

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	dying = int(f[3]) == 1
	var hl := _hall()
	if hl != null:
		hl.stage = int(f[4])
		hl.floor_on = int(f[5]) == 1
		hl.furniture = int(f[6])
		hl.body_c0 = int(f[7])
		hl.west_c1 = int(f[8])
		hl.stairs = int(f[9])
		hl.burn_t0 = f[10] / 100.0
		hl.fist = Rect2(float(f[11]), float(f[12]), float(f[13]), float(f[14])) if int(f[13]) > 0 else Rect2()
		hl.pk_t0 = f[15] / 100.0
		hl.seed = int(f[16])
		hl.green_t0 = f[17] / 100.0
		hl.pk_dir = int(f[18])
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
