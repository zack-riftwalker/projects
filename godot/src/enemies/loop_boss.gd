class_name LoopBoss
extends Boss
# INFINITE LOOP v3 (T10, docs/metroidvania/18-loop-build.md). M1: the shaft (LoopHall) only; the snake comes in M2. Until then the boss is an inert
# stub that carries the hall's state to the guest (its net fields) and lets the fight flow run (the fake loop, the intro, the locked doors).

func _init(r: Room, bx: float, by: float, base_hp := 126) -> void:
	super(r, 192.0, 464.0, 40, 32, base_hp)
	boss_name = "INFINITE LOOP"
	sub = "while (true)"
	col = "#2f7f6a"
	kit_init()

func _hall() -> LoopHall:
	return room.shaft

func intro_len() -> float:
	return 2.0

func update(dt: float) -> void:
	tick(dt)

func hurtboxes() -> Array:
	return []

func harmboxes() -> Array:
	return []

func net_fields() -> Array:
	var f: Array = [roundi(hpf * 10.0), max_hp, 1 if active else 0]
	f.append(_hall().net_pack() if _hall() != null else [])
	return f

const NF := 4

func net_apply(f: Array) -> void:
	hpf = f[0] / 10.0
	hp = ceili(hpf)
	max_hp = int(f[1])
	active = int(f[2]) == 1
	passive = not active
	if _hall() != null and f.size() > 3:
		_hall().net_unpack(f[3])

func puppet_tick(_dt: float) -> void:
	pass
