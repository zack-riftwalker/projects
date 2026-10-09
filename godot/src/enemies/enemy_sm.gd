class_name EnemySM
extends Enemy
# EnemySM: the small state machine the new enemies share (phase 1's Bug and Typo are plain ports and do not use it).
# States: idle chase telegraph attack recover dead (each enemy uses the ones it needs).

var state := "idle"
var state_t := 0.0

func set_state(s: String, t := 0.0) -> void:
	state = s
	state_t = t
