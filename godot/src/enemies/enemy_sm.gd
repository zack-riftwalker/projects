class_name EnemySM
extends Enemy
# EnemySM: the small state machine the new enemies share (phase 1's Bug and Typo are plain ports and do not use it).
# States: idle chase telegraph attack recover dead (each enemy uses the ones it needs).

var state := "idle"
var state_t := 0.0

func set_state(s: String, t := 0.0) -> void:
	state = s
	state_t = t

# the nearest player is within the box (max_dx, max_dy) and no solid tile is on the line between the centres
func sees_player(max_dx: float, max_dy: float) -> bool:
	var tp := to_player()
	if tp.p == null or absf(tp.dx) > max_dx or absf(tp.dy) > max_dy:
		return false
	var p = tp.p
	var x0 := cx
	var y0 := cy
	var x1: float = p.x + 5
	var y1: float = p.y + 5
	var n := maxi(1, int(ceilf(maxf(absf(x1 - x0), absf(y1 - y0)) / 8.0)))
	for i in range(1, n):
		var k := float(i) / n
		if room.grid.solid_at(lerpf(x0, x1, k), lerpf(y0, y1, k)):
			return false
	return true
