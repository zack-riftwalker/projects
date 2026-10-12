class_name Spyware
extends EnemySM
# SPYWARE (`e`): an eye fixed on its cell. It watches; a player within 160 px with a clear line makes it track (a dotted red line that follows),
# lock (the line stops, turns solid and blinks), fire a thin beam along the locked line, and cool down. Move off the locked line and the beam misses.

const STATES := ["watch", "track", "lock", "fire", "cool"]
const BEAM_MAX := 200.0

var angle := 0.0
var beam_len := 0.0
var tracked = null                # the player it is tracking (host / solo): kept in sight for the whole track, it is tagged (MVB3-04)

func _init(r: Room, px: float, py: float) -> void:
	super(r, px, py, 10, 10)
	x = px + 3.0
	y = py + 3.0
	hp = 4
	loot = 3
	col = "#f4ede0"
	stompable = false
	state = "watch"

func _aim_at(p) -> float:
	return atan2(p.y + 5.0 - cy, p.x + 5.0 - cx)

# is there a clear line from the eye to this body (sampled every 8 px) and is it within 160 px?
func _los(q) -> bool:
	if q == null or not is_instance_valid(q) or q.dead:
		return false
	var x1: float = q.x + 5.0
	var y1: float = q.y + 5.0
	if Vector2(x1 - cx, y1 - cy).length() > 160.0:
		return false
	var n := maxi(1, int(ceilf(maxf(absf(x1 - cx), absf(y1 - cy)) / 8.0)))
	for i in range(1, n):
		var k := float(i) / n
		if room.grid.solid_at(lerpf(cx, x1, k), lerpf(cy, y1, k)):
			return false
	return true

func _beam_length() -> float:
	var d := Vector2(cos(angle), sin(angle))
	var l := 0.0
	while l < BEAM_MAX:
		l += 4.0
		if room.grid.solid_at(cx + d.x * l, cy + d.y * l):
			return maxf(0.0, l - 4.0)
	return BEAM_MAX

func update(dt: float) -> void:
	tick(dt)
	state_t -= dt
	match state:
		"watch":
			if sees_player(160.0, 160.0) and to_player().d <= 160.0:
				tracked = to_player().p
				set_state("track", 1.2 * float(Game.dv("telegraph_mult")))
				angle = _aim_at(tracked)
				Audio.sfx("warn", {"vol": 0.5})
		"track":
			if not _los(tracked):                         # the line broke: the track starts over, no tag and no shot
				tracked = null
				set_state("cool", 0.5)
			else:
				angle = _aim_at(tracked)
				if state_t <= 0.0:
					room.tag_player(tracked, 4.0)          # kept in sight for the whole track: tagged, whether or not the beam then hits
					room.pop(tracked.x + 5.0, tracked.y - 12.0, "TAGGED", "#ff5a5a", true)
					Audio.sfx("warn", {"vol": 0.7})
					set_state("lock", 0.4)
		"lock":
			if state_t <= 0.0:
				beam_len = _beam_length()
				set_state("fire", 0.25)
				Audio.sfx("laser", {"vol": 0.6})
		"fire":
			if state_t <= 0.0:
				set_state("cool", 1.2)
		"cool":
			if state_t <= 0.0:
				set_state("watch")

func beam_boxes() -> Array:
	var out: Array = []
	var d := Vector2(cos(angle), sin(angle))
	var l := 6.0
	while l <= beam_len:
		out.append({"x": cx + d.x * l - 4.0, "y": cy + d.y * l - 4.0, "w": 8.0, "h": 8.0})          # 8 px thick
		l += 4.0
	return out

func harmboxes() -> Array:
	return beam_boxes() if state == "fire" else []

func draw_body() -> void:
	var px := floori(cx + 0.5)
	var py := floori(cy + 0.5)
	var d := Vector2(cos(angle), sin(angle))
	if state == "track":
		var l := 8.0
		while l < 160.0:
			if int(l / 4.0) % 2 == 0:
				draw_rect(Rect2(px + d.x * l, py + d.y * l, 1, 1), Color(Game.COL.hazard))
			l += 4.0
	elif state == "lock":
		if int(t * 20.0) % 2 == 0:
			draw_line(Vector2(px, py), Vector2(px + d.x * 160.0, py + d.y * 160.0), Color(Game.COL.hazard), 1.0)
	elif state == "fire":
		draw_line(Vector2(px, py), Vector2(px + d.x * beam_len, py + d.y * beam_len), Color("#ffd0d6"), 8.0)
		draw_line(Vector2(px, py), Vector2(px + d.x * beam_len, py + d.y * beam_len), Color(Game.COL.hazard), 5.0)
	# the eye: white, a red iris toward the target, a blink every 3 s while it only watches
	var lid := state == "watch" and fposmod(t, 3.0) < 0.12
	draw_circle(Vector2(px, py), 6.0, Color(Game.COL.ink))
	if lid:
		draw_rect(Rect2(px - 5, py - 1, 10, 2), Color("#f4ede0"))
	else:
		draw_circle(Vector2(px, py), 5.0, Color("#f4ede0"))
		var look := d * 2.0 if state != "watch" else Vector2(0, 0)
		draw_circle(Vector2(px, py) + look, 2.5, Color(Game.COL.hazard))
		draw_rect(Rect2(px + look.x - 1, py + look.y - 1, 1, 1), Color.BLACK)

func net_fields() -> Array:
	return [STATES.find(state), roundi(state_t * 100.0), roundi(angle * 100.0), roundi(beam_len)]

func net_apply(f: Array) -> void:
	state = STATES[clampi(int(f[0]), 0, 4)]
	state_t = f[1] / 100.0
	angle = f[2] / 100.0
	beam_len = float(f[3])
