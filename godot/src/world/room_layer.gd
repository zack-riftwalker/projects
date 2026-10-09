class_name RoomLayer
extends Node2D
# RoomLayer: a node that lets the room draw things that are not entities (furniture, items, particles).

var room: Room
var kind := ""

func _draw() -> void:
	room.draw_layer(kind, self)
