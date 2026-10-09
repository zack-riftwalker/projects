class_name DrawProxy
extends Node2D
# DrawProxy: a child node that draws through a callback, so one entity can have parts with their own material (the white hit flash on the body only).

var cb: Callable

func _draw() -> void:
	if cb.is_valid():
		cb.call(self)
