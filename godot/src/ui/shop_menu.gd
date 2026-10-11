class_name ShopMenu
extends Node2D
# ShopMenu: the npm registry stall (`$`). Every plugin with a price that is not owned yet: `name - cost - price`, and your tokens.
# JUMP / tap buys. Solo and host buy at once; a guest asks the host (`buy`) and pays only when the host's answer arrives (Coop).

const W := 384
const H := 216
signal closed

var active := false
var sel := 0
var room: Room
var ids: Array = []
var msg := ""
var pending := ""                    # guest: the plugin it asked for and has not been answered yet

func _ready() -> void:
	visible = false

func stock() -> Array:
	var out: Array = []
	for d in Game.PLUGINS:
		if int(d.price) > 0 and not Game.owns_plugin(d.id):
			out.append(d.id)
	return out

func open(r: Room) -> void:
	room = r
	active = true
	visible = true
	sel = 0
	msg = ""
	ids = stock()
	Audio.sfx("uiOk")
	queue_redraw()

func close() -> void:
	active = false
	visible = false
	closed.emit()

func rows() -> int:
	return ids.size() + 1                 # the plugins and Back

func update() -> void:
	if not active:
		return
	ids = stock() if pending == "" else ids
	var n := rows()
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
	if i >= ids.size():
		close()
		Audio.sfx("uiBack")
		return
	buy(String(ids[i]))

# the purchase; returns true when it went through (a guest: when it was asked for)
func buy(id: String) -> bool:
	var d := Game.plugin_def(id)
	if d.is_empty() or Game.owns_plugin(id):
		return false
	if Game.tokens < int(d.price):
		msg = "not enough tokens"
		Audio.sfx("thud")
		return false
	if Game.net_role == "guest":
		if pending != "":
			return false
		pending = id
		msg = "asking the host..."
		room.net_buy.emit(id)
		return true
	pay(id)
	return true

# the money leaves, the plugin is yours
func pay(id: String) -> void:
	var d := Game.plugin_def(id)
	Game.tokens -= int(d.price)
	Game.flags["plugin:" + id] = true
	room.plugin_bought(id, "p1" if Game.net_role != "guest" else "p2")
	msg = "npm install %s" % d.name
	if Game.net_role == "guest":
		Game.save_profile()
	else:
		Game.write_save()
	for k in range(3):
		get_tree().create_timer(0.09 * k).timeout.connect(func(): Audio.sfx("token", {"force": true}))

# the host's answer to the guest's `buy`: by "p2" it is bought (pay now), by "" somebody else owned it first (no payment)
func answered(id: String, by: String) -> void:
	if pending != id:
		return
	pending = ""
	if by == "p2":
		var d := Game.plugin_def(id)
		Game.tokens = maxi(0, Game.tokens - int(d.price))
		Game.save_profile()
		msg = "npm install %s" % d.name
		if room != null:
			room.pop(room.player.x + 5.0, room.player.y - 14.0, "npm install " + String(d.name), "#58f0c8", true)
		for k in range(3):
			get_tree().create_timer(0.09 * k).timeout.connect(func(): Audio.sfx("token", {"force": true}))
	else:
		msg = "already owned: it is yours, no charge"

func tap(p: Vector2) -> void:
	if not active:
		return
	for i in range(rows()):
		if Rect2(W / 2.0 - 120, 70 + i * 22, 240, 18).has_point(p):
			sel = i
			choose(i)
			return

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.6))
	PixelText.draw_text(self, "NPM REGISTRY", W / 2.0, 20, Game.COL.paper, {"align": "c", "scale": 2, "outline": Game.COL.ink})
	PixelText.draw_text(self, "tokens %d" % Game.tokens, W / 2.0, 46, Game.COL.gold, {"align": "c"})
	var n := rows()
	for i in range(n):
		var y := 70 + i * 22
		var back := i >= ids.size()
		var label := "Back"
		var afford := true
		if not back:
			var d := Game.plugin_def(String(ids[i]))
			label = "%s - %d - %d" % [d.name, d.cost, d.price]
			afford = Game.tokens >= int(d.price)
		Gfx.panel(self, W / 2.0 - 120, y, 240, 18, "#2a2236" if i == sel else "#17131f", Game.COL.clawd if i == sel else "#3a3346")
		PixelText.draw_text(self, label, W / 2.0, y + 5, (Game.COL.paper if afford else Game.COL.dim) if i == sel else Game.COL.dim, {"align": "c"})
	if ids.is_empty():
		PixelText.draw_text(self, "sold out: you own everything", W / 2.0, 100, Game.COL.dim, {"align": "c"})
	PixelText.draw_text(self, "name - context cost - price", W / 2.0, H - 30, Game.COL.dim, {"align": "c", "tiny": true})
	if msg != "":
		PixelText.draw_text(self, msg, W / 2.0, H - 18, "#58f0c8", {"align": "c"})
