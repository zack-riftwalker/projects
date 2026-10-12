class_name LogsView
extends Node2D
# LogsView: the Logs page (MVB1-10). Every sign the players have read, by zone (the finding is shared, the reading is local), then the memory
# fragments, the logbook pages and the changelog lines. Normal font wrapped to 340 px; up and down scroll, a drag scrolls, [dash] or [pause] go back.

const W := 384
const H := 216
const TOP := 22.0
const BOTTOM := 198.0
const LINE := 12.0
const WRAP := 340

signal back_requested

var active := false
var scroll := 0.0
var content_h := 0.0
var lines: Array = []            # [{text, col, tiny, y}] built by rebuild()
var drag_ok := false
var hold_t := 0.0
var buttons: Array = []

func _ready() -> void:
	visible = false
	buttons = [
		{"id": "up", "label": "up", "rect": Rect2(8, 202, 30, 12)},
		{"id": "down", "label": "down", "rect": Rect2(43, 202, 38, 12)},
		{"id": "back", "label": "back", "rect": Rect2(336, 202, 40, 12)},
	]

func open() -> void:
	active = true
	visible = true
	scroll = 0.0
	hold_t = 0.0
	rebuild()
	queue_redraw()

func close() -> void:
	active = false
	visible = false

var _y := 0.0

func _add_head(text: String, col, sub := "") -> void:
	lines.append({"text": text, "col": Color(col), "tiny": false, "y": _y, "sub": sub})
	_y += LINE + 2.0

func _add_text(text: String, col, tiny := false) -> void:
	for l in PixelText.wrap(text, WRAP):
		lines.append({"text": l, "col": Color(col), "tiny": tiny, "y": _y, "sub": ""})
		_y += LINE if not tiny else 8.0
	_y += 2.0

# the text lines of the whole page, top to bottom
func rebuild() -> void:
	lines = []
	_y = 0.0
	var ids: Array = Game.rooms_meta.rooms.keys()
	ids.sort()
	var any := false
	for z in Game.ZONES:
		if z.id == "lab":
			continue
		var section: Array = []
		for id in ids:
			if Game.zone_of(id) != z.id or Game.is_offmap(id):
				continue
			var texts: Array = []
			var n_signs: int = Game.rooms_meta.rooms[id].get("signs", []).size()
			for n in range(n_signs):
				if Game.flag("log:%s:%d" % [id, n]):
					texts.append(Game.sign_text_of(id, n))
			if not texts.is_empty():
				section.append([id, texts])
		if section.is_empty():
			continue
		any = true
		_add_head(String(z.name), z.col, String(z.path))
		for sec in section:
			_add_text(String(Game.rooms_meta.rooms[sec[0]].get("title", sec[0])), Game.COL.dim, true)
			for tx in sec[1]:
				_add_text(String(tx), Game.COL.paper)
		_y += 4.0
	var mem: Array = Game.memories_found()
	if not mem.is_empty():
		any = true
		_add_head("memories", Game.COL.clawdHi, "%d" % mem.size())
		for id in mem:
			_add_text(String(Game.MEMORIES[id]), "#fff3e4")
		_y += 4.0
	var pages: Array = []
	for n in range(1, 7):
		if Game.flag("page:%d" % n):
			pages.append(n)
	if not pages.is_empty():
		any = true
		_add_head("logbook", Game.COL.gold, "%d/6" % pages.size())
		for n in pages:
			_add_text(String(Game.LOGBOOK[n]), Game.COL.paper)
		_y += 4.0
	if not Game.changelog_lines.is_empty():
		any = true
		_add_head("changelog", "#58f0c8")
		for cl in Game.changelog_lines:
			_add_text(String(cl), Game.COL.paper)
	if not any:
		_add_text("nothing logged yet. read the signs you find.", Game.COL.dim)
	content_h = _y

func max_scroll() -> float:
	return maxf(0.0, content_h - (BOTTOM - TOP))

func scroll_by(d: float) -> void:
	scroll = clampf(scroll + d, 0.0, max_scroll())

func update() -> void:
	if not active:
		return
	var c := Controls.pressed
	if c.get("dash", false) or c.get("pause", false) or c.get("map", false):
		Audio.sfx("uiBack")
		back_requested.emit()
		return
	if c.get("up", false):
		scroll_by(-LINE * 3.0)
	elif c.get("down", false):
		scroll_by(LINE * 3.0)
	elif Controls.down.get("up", false) or Controls.down.get("down", false):
		hold_t += Game.STEP
		if hold_t > 0.3:
			scroll_by((-3.0 if Controls.down.get("up", false) else 3.0))
	else:
		hold_t = 0.0
	queue_redraw()

func tap(p: Vector2) -> void:
	if not active:
		return
	for b in buttons:
		if b.rect.grow(2.0).has_point(p):
			match String(b.id):
				"up": scroll_by(-LINE * 3.0)
				"down": scroll_by(LINE * 3.0)
				"back":
					Audio.sfx("uiBack")
					back_requested.emit()
			queue_redraw()
			return

func press_at(p: Vector2) -> void:
	drag_ok = p.y > TOP - 4.0 and p.y < BOTTOM

func drag(rel: Vector2) -> void:
	if active and drag_ok:
		scroll_by(-rel.y)
		queue_redraw()

func drag_end() -> void:
	drag_ok = false

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.07, 0.9))
	PixelText.draw_text(self, "LOGS", 8, 4, Game.COL.paper, {"outline": Game.COL.ink})
	PixelText.draw_text(self, "what you have read", 8 + 4 * 7 + 8, 5, Game.COL.dim, {"tiny": true})
	for l in lines:
		var y: float = TOP + float(l.y) - scroll
		var h := 9.0 if not l.tiny else 5.0
		if y < TOP - 1.0 or y + h > BOTTOM + 1.0:
			continue
		var x := 22.0 if String(l.sub) == "" and not l.tiny and false else 10.0
		var w := PixelText.draw_text(self, String(l.text), x, y, l.col, {"tiny": l.tiny})
		if String(l.sub) != "":
			PixelText.draw_text(self, String(l.sub), x + w + 6.0, y, Game.COL.dim)
	# a scroll bar
	if max_scroll() > 0.0:
		var bh := (BOTTOM - TOP) * (BOTTOM - TOP) / content_h
		var by := TOP + (BOTTOM - TOP - bh) * (scroll / max_scroll())
		draw_rect(Rect2(W - 5, TOP, 2, BOTTOM - TOP), Color("#231d2e"))
		draw_rect(Rect2(W - 5, by, 2, bh), Color("#8d8798"))
	for b in buttons:
		Gfx.panel(self, b.rect.position.x, b.rect.position.y, b.rect.size.x, b.rect.size.y, "#17131f", "#3a3346")
		PixelText.draw_text(self, String(b.label), b.rect.position.x + b.rect.size.x / 2.0, b.rect.position.y + 4, Game.COL.paper, {"align": "c", "tiny": true})
