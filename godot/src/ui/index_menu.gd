class_name IndexMenu
extends Node2D
# IndexMenu: the cartographer `tree`. `tree -L 1 <path>`, then the index of the zone for a price (0 = free); owned: a line that says to rest at a bench.
# Solo and host buy at once; a guest asks the host (`buymap`) and pays only when the answer says it was the buyer. The map is shared, the tokens are not.

const W := 384
const H := 216
signal closed

var active := false
var sel := 0
var room: Room
var npc: Dictionary = {}
var msg := ""
var pending := ""                    # guest: the zone it asked for and has not been answered yet

func _ready() -> void:
	visible = false

func zone() -> String:
	return String(npc.get("zone", ""))

func path() -> String:
	return String(Game.zone_def(zone()).get("path", zone()))

func owned() -> bool:
	return Game.owns_map(zone())

func price() -> int:
	return int(npc.get("price", 0))

func open(r: Room, n: Dictionary) -> void:
	room = r
	npc = n
	active = true
	visible = true
	sel = 0
	msg = ""
	Audio.sfx("uiOk")
	queue_redraw()

func close() -> void:
	active = false
	visible = false
	closed.emit()

# the rows: the offer (when not owned) and Back
func rows() -> Array:
	var o: Array = []
	if not owned():
		o.append("take the index of %s" % path() if price() <= 0 else "index %s — %d tokens" % [path(), price()])
	o.append("Back")
	return o

func update() -> void:
	if not active:
		return
	var n := rows().size()
	sel = mini(sel, n - 1)
	if Controls.pressed.get("up", false):
		sel = (sel + n - 1) % n
		Audio.sfx("uiMove")
	if Controls.pressed.get("down", false):
		sel = (sel + 1) % n
		Audio.sfx("uiMove")
	if Controls.pressed.get("pause", false) or Controls.pressed.get("dash", false):
		close()
		Audio.sfx("uiBack")
	elif Controls.pressed.get("start", false) or Controls.pressed.get("jump", false) or Controls.pressed.get("attack", false):
		choose(sel)
	queue_redraw()

func choose(i: int) -> void:
	if i >= rows().size() - 1:
		close()
		Audio.sfx("uiBack")
		return
	buy()

# true when the index went through (a guest: when it was asked for)
func buy() -> bool:
	if owned():
		msg = "already indexed"
		return false
	if Game.tokens < price():
		msg = "not enough tokens"
		Audio.sfx("thud")
		return false
	if Game.net_role == "guest":
		if pending != "":
			return false
		pending = zone()
		msg = "asking the host..."
		room.net_buymap.emit(zone())
		return true
	Game.tokens -= price()
	_bought()
	if Game.net_role != "guest":
		Game.write_save()
	return true

func _bought() -> void:
	Game.flags["map:" + zone()] = true
	msg = "indexed %s" % path()
	Audio.sfx("checkpoint")
	if room != null and room.player != null:
		room.pop(room.player.x + 5.0, room.player.y - 14.0, "index %s" % path(), "#58f0c8", true)

# the host's answer to the guest's `buymap`: by "p2" it is bought (pay now), by "" somebody else owned it first (no payment)
func answered(zone_id: String, by: String) -> void:
	Game.flags["map:" + zone_id] = true
	if pending != zone_id:
		return
	pending = ""
	if by == "p2":
		Game.tokens = maxi(0, Game.tokens - price())
		Game.save_profile()
		_bought()
	else:
		msg = "already indexed: no charge"

func tap(p: Vector2) -> void:
	if not active:
		return
	var n := rows().size()
	for i in range(n):
		if Rect2(W / 2.0 - 130, 80 + i * 22, 260, 18).has_point(p):
			sel = i
			choose(i)
			return

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.6))
	PixelText.draw_text(self, "tree -L 1 %s" % path(), W / 2.0, 24, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
	var zc: String = String(Game.zone_def(zone()).get("col", "#8d8798"))
	PixelText.draw_text(self, String(Game.zone_def(zone()).get("name", "")), W / 2.0, 46, zc, {"align": "c"})
	var opts := rows()
	if owned():
		var lines := PixelText.wrap("%s is indexed. (rest at a bench to commit what you walked.)" % path(), 240)
		for li in range(lines.size()):
			PixelText.draw_text(self, lines[li], W / 2.0, 62 + li * 10, Game.COL.paper, {"align": "c"})
	elif price() > 0:
		PixelText.draw_text(self, "your tokens: %d" % Game.tokens, W / 2.0, 62, Game.COL.gold, {"align": "c"})
	for i in range(opts.size()):
		var y := 80 + i * 22
		var afford := i != 0 or owned() or Game.tokens >= price()
		Gfx.panel(self, W / 2.0 - 130, y, 260, 18, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, opts[i], W / 2.0, y + 5, (Game.COL.paper if afford else Game.COL.dim) if i == sel else Game.COL.dim, {"align": "c"})
	if msg != "":
		PixelText.draw_text(self, msg, W / 2.0, H - 24, "#58f0c8", {"align": "c"})
