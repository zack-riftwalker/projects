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

static func x4(v: float) -> int:
	return roundi(v * 4.0)
