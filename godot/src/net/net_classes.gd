class_name NetClasses
extends RefCounted
# NetClasses: the creature classes the snapshot can name (index in `en` records), and how to build the guest's puppet of each.

const NAMES := ["bug", "bug_spiky", "typo", "guard", "zombie", "null"]

static func cls_of(e) -> int:
	if e is NullBoss:
		return 5
	if e is Guard:
		return 3
	if e is Zombie:
		return 4
	if e is Typo:
		return 2
	if e is Bug:
		return 1 if e.spiky else 0
	return -1

static func make(cls: int, room: Room):
	var e
	match cls:
		0: e = Bug.new(room, 0, 0, false)
		1: e = Bug.new(room, 0, 0, true)
		2: e = Typo.new(room, 0, 0)
		3: e = Guard.new(room, 0, 0)
		4: e = Zombie.new(room, 0, 0)
		5: e = NullBoss.new(room, 0, 0)
		_: return null
	e.puppet = true
	return e

# one creature in a snapshot: [nid, class, x4, y4, vx, vy, hp, face, flash, ...its own net_fields()]. The host writes it, the
# guest's puppet reads it (the position goes through the interpolation buffer, so apply() leaves x/y alone). The parity test
# (run_tests: parity) uses the same two functions, so it checks exactly what the game sends.
static func record(e) -> Array:
	var rec: Array = [e.nid, cls_of(e), x4(e.x), x4(e.y), roundi(e.vx), roundi(e.vy), e.hp, int(e.face), roundi(maxf(e.flash, 0.0) * 100.0)]
	rec.append_array(e.net_fields())
	return rec

static func apply(e, rec: Array) -> void:
	e.vx = float(rec[4])
	e.vy = float(rec[5])
	e.hp = int(rec[6])
	e.face = float(rec[7])
	if int(rec[8]) > 0:
		e.flash = rec[8] / 100.0
	e.net_apply(rec.slice(9))

static func x4(v: float) -> int:
	return roundi(v * 4.0)
