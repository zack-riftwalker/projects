class_name RaceBoss
extends Boss
# RACE CONDITION v3 (T06): TICK and TOCK, two bronze bell-strikers (docs/metroidvania/17-race-build.md). M1: the arena only; the two automata come
# with M2, so the boss is inert here (it carries the hall's state to the guest and nothing else).

const IDS := ["strike", "slam", "double", "clapper", "rope", "switch", "drop", "triple", "combo"]

func _init(r: Room, bx: float, by: float, base_hp := 90) -> void:
	super(r, bx, by, 32, 48, base_hp)
	boss_name = "RACE CONDITION"
	sub = "two threads, one variable"
	kit_init()

func plan_ids() -> Array:
	return IDS

func hz_kinds() -> Array:
	return ["ring", "slambox", "clapper", "rope", "bellfall", "corrupt", "hole"]

func _hall() -> BelfryHall:
	return room.belfry

func hurtboxes() -> Array:
	return []

# ---------------------------------------------------------------- net
func net_fields() -> Array:
	var hl := _hall()
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0, 1 if dying else 0, hl.net_pack() if hl != null else []]
	f.append_array(plan_fields())
	f.append(hz_pack())
	return f

const NF := 5

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	dying = int(f[3]) == 1
	var hl := _hall()
	if hl != null and not (f[4] as Array).is_empty():
		hl.net_unpack(f[4])
	plan_apply(f.slice(NF, NF + 11))
	hz_unpack(f[NF + 11] if f.size() > NF + 11 else [])

func puppet_tick(dt: float) -> void:
	kit_puppet_tick(dt)
	hz_puppet_tick(dt)
