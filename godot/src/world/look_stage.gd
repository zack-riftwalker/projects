class_name LookStage
extends CanvasModulate
# LookStage (MVGN-05): the one CanvasModulate of the game's canvas, owned by neither room. A CanvasModulate inside a room would reset the canvas to white
# whenever that room is freed or hidden (a door swap frees the old room after the new one built its own), so the rooms' Looks only *claim* the stage:
# the local NETWORK room pushes its ambient colour every frame, and when nobody has claimed it for a few frames (worlds 1-5, the title) it goes white,
# which renders exactly as before. Unshaded items (CanvasItemMaterial LIGHT_MODE_UNSHADED) ignore it.

var claimed := -100

static func of(room: Node) -> LookStage:
	var host := room.get_parent()
	if host == null:
		return null
	var st := host.get_node_or_null("LookStage") as LookStage
	if st == null:
		st = LookStage.new()
		st.name = "LookStage"
		host.add_child(st)
	return st

func claim(c: Color) -> void:
	color = c
	claimed = Engine.get_process_frames()

func _process(_dt: float) -> void:
	if color != Color.WHITE and Engine.get_process_frames() - claimed > 3:
		color = Color.WHITE
