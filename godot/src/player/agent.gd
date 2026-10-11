class_name Agent
extends RefCounted
# Agent: one of the two helpers `special` sends out when the context meter is full (port of `class Agent`, js/player.js). It floats around
# its owner for 11 s, picks the nearest target within 150 px of the owner (a creature that can be hit, or a slot key) whenever its
# cooldown allows, flies at it and hits for 1 (`how = "agent"`; bosses halve it). The host's Room simulates every agent, the guest's too.

var owner_p                         # a Player, or the RemotePlayer the host keeps for the guest
var i := 0
var x := 0.0
var y := 0.0
var cd := 0.3
var life := 11.0
var t := 0.0
var target = null                   # {"e": creature | null, "key": slot key | null}
var trail: Array = []               # x, y, x, y ... (the last five points)

func _init(p, idx: int) -> void:
	owner_p = p
	i = idx
	x = p.x
	y = p.y - 10.0
	t = idx * 2.0

func _alive(tg) -> bool:
	if tg.e != null:
		return is_instance_valid(tg.e) and not tg.e.dead
	return not Game.flag("key:%s:%d" % [owner_p.room.id, tg.key.i])

func _boxes(tg) -> Array:
	if tg.e != null:
		return tg.e.hurtboxes()
	return [tg.key]

func update(dt: float, room: Room) -> void:
	var p = owner_p
	t += dt
	life -= dt
	cd -= dt
	var tx: float = p.x + p.w / 2.0 + cos(t * 2.4 + i * PI) * 20.0
	var ty: float = p.y - 12.0 + sin(t * 3.1 + i * 2.0) * 6.0
	if target != null and (not _alive(target) or cd > 0.5):
		target = null
	if target == null and cd <= 0.0:
		var best := 150.0
		for e in room.ents:
			if e.dead or e.no_hit or e.no_agent:
				continue
			for b in e.hurtboxes():
				var d := Vector2(p.x - (b.x + b.w / 2.0), p.y - (b.y + b.h / 2.0)).length()
				if d < best:
					best = d
					target = {"e": e, "key": null}
		for k in room.keys:
			if Game.flag("key:%s:%d" % [room.id, k.i]):
				continue
			var dk := Vector2(p.x - (k.x + k.w / 2.0), p.y - (k.y + k.h / 2.0)).length()
			if dk < best:
				best = dk
				target = {"e": null, "key": k}
	var speed := 5.0
	if target != null:
		var bs := _boxes(target)
		var b = bs[0]
		var bd := 1e9
		for cand in bs:                                       # (the box nearest to this agent: MERGE CONFLICT has two heads)
			var dd := Vector2(x - (cand.x + cand.w / 2.0), y - (cand.y + cand.h / 2.0)).length()
			if dd < bd:
				bd = dd
				b = cand
		tx = b.x + b.w / 2.0
		ty = b.y + b.h / 2.0
		speed = 11.0
		if Vector2(x - tx, y - ty).length() < 9.0 and cd <= 0.0:
			var res := ""
			var by_remote: bool = p.get("is_remote") == true
			var c0 := room.ctx
			room.ctx = "p2" if by_remote else "p1"
			if target.e != null:
				room.attacker = p
				res = target.e.hit(1, Game.sign_of(tx - p.x) if Game.sign_of(tx - p.x) != 0.0 else 1.0, 0.0, "agent", b)
			else:
				room.press_key(int(target.key.i))
				res = "hit"
			cd = 0.85
			if res != "":
				room.spark(x, y, "#ffe2c4", 6)
				Audio.sfx("agentHit")
				room.stop(0.02)
			room.ctx = c0
			target = null
	x = Game.damp(x, tx, speed, dt)
	y = Game.damp(y, ty, speed, dt)
	trail.append(x)
	trail.append(y)
	if trail.size() > 10:
		trail.remove_at(0)
		trail.remove_at(0)

func draw(ci: CanvasItem) -> void:
	_draw_at(ci, x, y, t, life, trail)

static func _draw_at(ci: CanvasItem, ax: float, ay: float, at: float, alife: float, atrail: Array) -> void:
	var k := 0
	while k < atrail.size():
		ci.draw_rect(Rect2(floori(atrail[k] + 0.5) - 2, floori(atrail[k + 1] + 0.5) - 1, 4, 2), Color(0.94, 0.72, 0.6, 0.12 + k * 0.03))
		k += 2
	if alife < 2.0 and int(alife * 10.0) % 2 == 1:
		return
	ci.draw_texture(Gfx.tex("agent_%d" % (int(at * 10.0) % 2)), Vector2(floori(ax + 0.5) - 5, floori(ay + 0.5) - 4))
