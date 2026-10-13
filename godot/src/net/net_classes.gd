class_name NetClasses
extends RefCounted
# NetClasses: the creature classes the snapshot can name (index in `en` records), and how to build the guest's puppet of each.

const NAMES := ["bug", "bug_spiky", "typo", "guard", "zombie", "null", "exception", "reviewer", "mimic", "log", "noodle", "flaky", "fork", "merge", "slime", "slime_s", "lint", "lint_v", "dripper", "pendulum", "drone", "segfault", "stackover", "leak", "gcdrone", "kitdummy", "scraper", "worm", "ddos", "spyware", "crawler", "firewall", "reviewer2", "sniffer", "mitm", "botnet", "pinger", "wormegg", "heisenbug", "datarace", "deadlockguard", "spinlock", "ticker", "orphan", "orphanchild", "priority", "raceboss"]

static func cls_of(e) -> int:
	if e is RaceBoss:
		return 46
	if e is Heisenbug:
		return 38
	if e is DataRace:
		return 39
	if e is DeadlockGuard:
		return 40
	if e is Spinlock:
		return 41
	if e is Ticker:
		return 42
	if e is OrphanChild:
		return 44
	if e is Orphan:
		return 43
	if e is PriorityInversion:
		return 45
	if e is NullBoss:
		return 5
	if e is KitDummy:
		return 25
	if e is CrawlerBoss:
		return 30
	if e is FirewallBoss:
		return 31
	if e is Reviewer2:
		return 32
	if e is WormEgg:
		return 37
	if e is Sniffer:
		return 33
	if e is Mitm:
		return 34
	if e is Botnet:
		return 35
	if e is Pinger:
		return 36
	if e is Scraper:
		return 26
	if e is Worm:
		return 27
	if e is DdosBit:
		return 28
	if e is Spyware:
		return 29
	if e is Reviewer:
		return 7
	if e is Mimic:
		return 8
	if e is LogEnemy:
		return 9
	if e is Noodle:
		return 10
	if e is Flaky:
		return 11
	if e is Fork:
		return 12
	if e is MergeBoss:
		return 13
	if e is Slime:
		return 15 if e.small else 14
	if e is Lint:
		return 17 if e.vertical else 16
	if e is Dripper:
		return 18
	if e is Pendulum:
		return 19
	if e is Drone:
		return 20
	if e is LeakBoss:
		return 23
	if e is GcDrone:
		return 24
	if e is Segfault:
		return 21
	if e is StackOverflow:
		return 22
	if e is ExceptionFoe:
		return 6
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
		6: e = ExceptionFoe.new(room, 0, 0)
		7: e = Reviewer.new(room, 0, 0)
		8: e = Mimic.new(room, 0, 0)
		9: e = LogEnemy.new(room, 0, 0)
		10: e = Noodle.new(room, 0, 0)
		11: e = Flaky.new(room, 0, 0)
		12: e = Fork.new(room, 0, 0)
		13: e = MergeBoss.new(room, 0, 0)
		14: e = Slime.new(room, 0, 0, false)
		15: e = Slime.new(room, 0, 0, true)
		16: e = Lint.new(room, 0, 0, false)
		17: e = Lint.new(room, 0, 0, true)
		18: e = Dripper.new(room, 0, 0)
		19: e = Pendulum.new(room, 0, 0)
		20: e = Drone.new(room, 0, 0)
		21: e = Segfault.new(room, 0, 0)
		22: e = StackOverflow.new(room, 0, 0)
		23: e = LeakBoss.new(room, 0, 0)
		24: e = GcDrone.new(room, 0, 0)
		25: e = KitDummy.new(room, 0, 0)
		26: e = Scraper.new(room, 0, 0)
		27: e = Worm.new(room, 0, 0)
		28: e = DdosBit.new(room, 0, 0)
		29: e = Spyware.new(room, 0, 0)
		30: e = CrawlerBoss.new(room, 0, 0)
		31: e = FirewallBoss.new(room, 0, 0)
		32: e = Reviewer2.new(room, 0, 0)
		33: e = Sniffer.new(room, 0, 0)
		34: e = Mitm.new(room, 0, 0)
		35: e = Botnet.new(room, 0, 0)
		36: e = Pinger.new(room, 0, 0)
		37: e = WormEgg.new(room, 0, 0)
		38: e = Heisenbug.new(room, 0, 0)
		39: e = DataRace.new(room, 0, 0)
		40: e = DeadlockGuard.new(room, 0, 0)
		41: e = Spinlock.new(room, 0, 0)
		42: e = Ticker.new(room, 0, 0)
		43: e = Orphan.new(room, 0, 0)
		44: e = OrphanChild.new(room, 0, 0)
		45: e = PriorityInversion.new(room, 0, 0)
		46: e = RaceBoss.new(room, 0, 0)
		_: return null
	e.puppet = true
	return e

# one creature in a snapshot: [nid, class, x4, y4, vx, vy, hp, face, flash, ...its own net_fields()]. The host writes it, the
# guest's puppet reads it (the position goes through the interpolation buffer, so apply() leaves x/y alone). The parity test
# (run_tests: parity) uses the same two functions, so it checks exactly what the game sends.
static func record(e) -> Array:
	var rec: Array = [e.nid, cls_of(e), x4(e.x), x4(e.y), roundi(e.vx), roundi(e.vy), e.hp, int(e.face), roundi(maxf(e.flash, 0.0) * 100.0)]
	rec.append_array(e.net_fields())
	rec.append(roundi(e.bp_t * 100.0))          # the breakpoint state of every creature rides at the end of its record
	rec.append(roundi(e.bp_off * 100.0))
	rec.append(e.bp_k)
	return rec

static func apply(e, rec: Array) -> void:
	e.vx = float(rec[4])
	e.vy = float(rec[5])
	e.hp = int(rec[6])
	e.face = float(rec[7])
	if int(rec[8]) > 0:
		e.flash = rec[8] / 100.0
	e.bp_t = float(rec[rec.size() - 3]) / 100.0
	e.bp_off = float(rec[rec.size() - 2]) / 100.0
	e.bp_k = int(rec[rec.size() - 1])
	e.net_apply(rec.slice(9, rec.size() - 3))

static func x4(v: float) -> int:
	return roundi(v * 4.0)
