class_name BossRead
extends RefCounted
# BossRead: the behaviour reader of the boss kit (rule 8: the boss answers what a player DID, not which button it pressed). Host only.
# Per player key ("p1" the host's player, "p2" the guest): a sample every 0.1 s for the last second (distance to the boss, on the
# ground, under the boss, focusing) and the claw hits it landed. The guest is read from its reports, which are late by design.

const SAMPLE_DT := 0.1
const KEEP := 1.0

var boss
var clock := 0.0
var acc := 0.0
var samples := {"p1": [], "p2": []}      # key -> [{t, d, g, u, f}]
var hits := {"p1": [], "p2": []}         # key -> [{t, how, d}]
var last_key := ""
var last_hows := {}

func _init(b) -> void:
	boss = b

func update(dt: float) -> void:
	clock += dt
	acc += dt
	if acc < SAMPLE_DT:
		return
	acc = 0.0
	for key in ["p1", "p2"]:
		var q = boss.kit_body(key)
		var s: Array = samples[key]
		if q == null or q.dead:
			s.clear()
			continue
		var focusing: bool = (q.focus_t >= 0.0) if q.get("focus_t") != null else bool(q.get("focusing"))
		s.append({"t": clock, "d": boss.kit_dist(key), "g": bool(q.on_ground), "u": absf(q.x + q.w / 2.0 - boss.cx) < 20.0 and q.y > boss.y + boss.h - 2.0, "f": focusing})
		while not s.is_empty() and clock - float(s[0].t) > KEEP + 0.01:
			s.pop_front()
	for key in hits:
		var hs: Array = hits[key]
		while not hs.is_empty() and clock - float(hs[0].t) > 3.0:
			hs.pop_front()

# Room.boss_damage calls this for every damage a player did to a kit boss
func note_hit(key: String, how: String) -> void:
	if not hits.has(key):
		return
	hits[key].append({"t": clock, "how": how, "d": boss.kit_dist(key)})
	last_key = key
	last_hows[key] = how

func dist(key: String) -> float:
	var s: Array = samples.get(key, [])
	return float(s[s.size() - 1].d) if not s.is_empty() else boss.kit_dist(key)

# at least n swipes within secs, each landed while within `near` px of the boss
func greedy(key: String, n := 3, secs := 1.2, near := 48.0) -> bool:
	var c := 0
	for hh in hits.get(key, []):
		if hh.how == "swipe" and clock - float(hh.t) <= secs and float(hh.d) <= near:
			c += 1
	return c >= n

# focusing (turning context into hit points) for most of the last half second
func healing(key: String) -> bool:
	var s: Array = samples.get(key, [])
	var c := 0
	for i in range(maxi(0, s.size() - 5), s.size()):
		if s[i].f:
			c += 1
	return c >= 3

func under(key: String) -> bool:
	var s: Array = samples.get(key, [])
	return not s.is_empty() and bool(s[s.size() - 1].u)

func last_hitter() -> String:
	return last_key

func last_how(key: String) -> String:
	return String(last_hows.get(key, ""))
