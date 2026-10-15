class_name IndexHall
extends RefCounted
# IndexHall: the furniture of N09, the hall of CRAWLER OF THE WEB (docs/metroidvania/14-crawler.md, step 3). The room owns it, not the boss, so
# the hall is still there after the fight. It owns some one-way cells of the room file (the web net over the pit, the card-catalogue drawers,
# the two web strands): their tiles follow its masks, it draws them itself (RoomView skips them), and the boss changes the masks (a leap tears
# the net, a drawer falls, CAPTCHA drops squares). The masks are state: the host's boss writes them, the guest's boss copy writes them from
# its net fields, and apply() turns them into tiles on each page. The back wall screen shows what the boss asks for (`screen`).

const T := 16
const NET_ROW := 21
const NET_C0 := 5
const NET_N := 14                         # net cells: columns 5..18 of row 21
const DRAWERS := [[1, 18], [20, 18], [1, 15], [20, 15], [1, 12], [20, 12], [1, 9], [20, 9], [1, 6], [20, 6]]     # [first column, row], 3 cells
const STRANDS := [[7, 13, 10], [6, 7, 12]]          # [first column, row, length]
const ZONES := [56.0, 136.0, 248.0, 328.0]           # the neon tubes on the back wall (one per quarter of the hall)
const SCREEN := Rect2(132, 34, 120, 70)              # the old homepage on the back wall
const COCOONS := [[40.0, 58.0], [100.0, 44.0], [290.0, 50.0], [350.0, 66.0], [214.0, 30.0]]
const BEIGE := "#c9b98f"
const BEIGE_D := "#8f7f5a"
const INK := "#1b1226"
const GREEN := "#57ff8a"
const ALL_NET := (1 << NET_N) - 1
const ALL_DRAWERS := (1 << 10) - 1

var room
var net := ALL_NET                         # bit i: net cell (NET_C0 + i) is there
var hide := 0                              # bit i: net cell hidden for now (CAPTCHA picked its square)
var drawers := ALL_DRAWERS
var strands := 3
var zones := 15                            # bit i: neon tube i is lit
var dark := 0.0                            # 0 lit .. 1 the blackout (the screen and the tubes die with it)
var screen := {"mode": "home", "text": "", "t0": 0.0, "sel": 0}
var rattle := {}                           # drawer index -> room time it started to shake (a drawer about to fall)
var owned := {}                            # cell index -> true: the cells this hall owns

func _init(r) -> void:
	room = r
	for i in range(NET_N):
		owned[_idx(NET_C0 + i, NET_ROW)] = true
	for d in DRAWERS:
		for k in range(3):
			owned[_idx(int(d[0]) + k, int(d[1]))] = true
	for s in STRANDS:
		for k in range(int(s[2])):
			owned[_idx(int(s[0]) + k, int(s[1]))] = true

static func wanted(def: Dictionary) -> bool:
	return String(def.get("hall", "")) == "index"

func _idx(tx: int, ty: int) -> int:
	return ty * room.grid.w + tx

func owns(tx: int, ty: int) -> bool:
	return owned.has(_idx(tx, ty))

# the masks as tiles (every frame, both pages; only changed cells are written)
func apply() -> void:
	var g = room.grid
	for i in range(NET_N):
		_put(g, NET_C0 + i, NET_ROW, (net >> i) & 1 == 1 and (hide >> i) & 1 == 0)
	for di in range(DRAWERS.size()):
		var d: Array = DRAWERS[di]
		for k in range(3):
			_put(g, int(d[0]) + k, int(d[1]), (drawers >> di) & 1 == 1)
	for si in range(STRANDS.size()):
		var s: Array = STRANDS[si]
		for k in range(int(s[2])):
			_put(g, int(s[0]) + k, int(s[1]), (strands >> si) & 1 == 1)

func _put(g, tx: int, ty: int, on: bool) -> void:
	var want: int = TileGrid.ONEWAY if on else TileGrid.E
	var i: int = ty * g.w + tx
	if g.tiles[i] != want:
		g.tiles[i] = want

func reset() -> void:
	net = ALL_NET
	hide = 0
	drawers = ALL_DRAWERS
	strands = 3
	zones = 15
	dark = 0.0
	rattle = {}

func drawer_rect(di: int) -> Rect2:
	var d: Array = DRAWERS[di]
	return Rect2(float(d[0]) * T, float(d[1]) * T, 3.0 * T, T)

func drawers_left() -> int:
	var n := 0
	for di in range(DRAWERS.size()):
		if (drawers >> di) & 1 == 1:
			n += 1
	return n

func net_x(i: int) -> float:
	return float(NET_C0 + i) * T

# after the fight the screen keeps the crawler's last search, unanswered (step 5)
func step(_dt: float) -> void:
	if room.boss == null and Game.flag("boss:CRAWLER"):
		screen = {"mode": "last", "text": "is anyone there", "t0": 0.0, "sel": 0}
		dark = 0.55
	apply()

# ---------------------------------------------------------------- drawing
# the back wall: a tall dark room of panels, with the hall's name up high (static)
func draw_wall(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, float(room.pw), float(room.ph)), Color("#0c0a10"))     # behind the outer walls too: the city never shows, and the walls stand out from the dark
	var r := Rect2(16.0, 16.0, float(room.pw) - 32.0, float(NET_ROW * T) - 16.0)
	ci.draw_rect(r, Color("#17141d"))
	var xx := r.position.x
	while xx < r.end.x:
		ci.draw_rect(Rect2(xx, r.position.y, 1.0, r.size.y), Color("#221d2a"))
		xx += 32.0
	var yy := r.position.y + 40.0
	while yy < r.end.y:
		ci.draw_rect(Rect2(r.position.x, yy, r.size.x, 2.0), Color("#1f1a26"))
		yy += 60.0
	PixelText.draw_text(ci, "INDEX", r.get_center().x, 116.0, "#262030", {"align": "c", "scale": 3})
	ci.draw_rect(Rect2(r.position.x, float(NET_ROW * T) - 6.0, r.size.x, 6.0), Color("#100e14"))
# shaded: wood, web and paper (the lighting darkens them); glow: what gives light (the screen, the tubes, the drawer lamps, the cocoons)
func draw_shaded(ci: CanvasItem) -> void:
	var now: float = room.time
	var beige := Color(BEIGE)
	var beige_d := Color(BEIGE_D)
	var ink := Color(INK)
	# the card catalogue behind the side drawers: rows of small drawer fronts up the walls
	for side in [16.0, float(room.pw) - 64.0]:
		ci.draw_rect(Rect2(side, 80.0, 48.0, 256.0), Color("#3a3226"))
		var yy := 84.0
		while yy < 332.0:
			var xx: float = side + 2.0
			while xx < side + 46.0:
				ci.draw_rect(Rect2(xx, yy, 13.0, 9.0), Color("#5b4d36"))
				ci.draw_rect(Rect2(xx + 5.0, yy + 4.0, 3.0, 1.0), Color("#a8946a"))
				xx += 15.0
			yy += 11.0
	# the drawers that stick out (platforms); a missing one leaves a dark slot
	for di in range(DRAWERS.size()):
		var r := drawer_rect(di)
		if (drawers >> di) & 1 == 0:
			ci.draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, 10.0), Color("#120e14"))
			continue
		var shake := 0.0
		if rattle.has(di):
			shake = sin(now * 60.0) * 1.0
		var rx: float = r.position.x + shake
		ci.draw_rect(Rect2(rx - 1.0, r.position.y - 1.0, r.size.x + 2.0, 13.0), ink)
		ci.draw_rect(Rect2(rx, r.position.y, r.size.x, 11.0), beige)
		ci.draw_rect(Rect2(rx, r.position.y, r.size.x, 2.0), Color("#e2d6b0"))
		ci.draw_rect(Rect2(rx, r.position.y + 9.0, r.size.x, 2.0), beige_d)
		ci.draw_rect(Rect2(rx + 18.0, r.position.y + 3.0, 12.0, 5.0), Color("#efe6c8"))        # the label card
		ci.draw_rect(Rect2(rx + 19.0, r.position.y + 5.0, 10.0, 1.0), Color("#8a7a60"))
	# the web net over the pit
	var ny := float(NET_ROW * T)
	for i in range(NET_N):
		var x0 := net_x(i)
		var here := (net >> i) & 1 == 1
		var hidden := (hide >> i) & 1 == 1
		if here and not hidden:
			var sag := 1.5 + sin(now * 1.3 + float(i)) * 0.5
			ci.draw_line(Vector2(x0, ny + 1.0), Vector2(x0 + T, ny + 1.0 + sag * 0.3), Color("#e8eef2"), 1.0)
			ci.draw_line(Vector2(x0, ny + 5.0 + sag), Vector2(x0 + T, ny + 5.0 + sag), Color("#b9c4cc"), 1.0)
			ci.draw_line(Vector2(x0, ny + 1.0), Vector2(x0 + T, ny + 5.0 + sag), Color("#cfd8de"), 1.0)
			ci.draw_line(Vector2(x0 + T, ny + 1.0), Vector2(x0, ny + 5.0 + sag), Color("#cfd8de"), 1.0)
		elif here and hidden:
			ci.draw_rect(Rect2(x0 + 1.0, ny, T - 2.0, 1.0), Color(0.9, 0.93, 0.95, 0.25))
		else:                                                              # torn: frayed ends hanging into the pit
			var lft := i > 0 and (net >> (i - 1)) & 1 == 1
			var rgt := i < NET_N - 1 and (net >> (i + 1)) & 1 == 1
			if lft:
				ci.draw_line(Vector2(x0, ny + 2.0), Vector2(x0 + 3.0, ny + 12.0), Color("#b9c4cc"), 1.0)
			if rgt:
				ci.draw_line(Vector2(x0 + T, ny + 2.0), Vector2(x0 + T - 4.0, ny + 10.0), Color("#b9c4cc"), 1.0)
	# the two strands across the hall: they sag a little
	for si in range(STRANDS.size()):
		if (strands >> si) & 1 == 0:
			continue
		var s: Array = STRANDS[si]
		var a := Vector2(float(s[0]) * T, float(s[1]) * T + 2.0)
		var b := Vector2(float(int(s[0]) + int(s[2])) * T, float(s[1]) * T + 2.0)
		var pts := PackedVector2Array()
		for k in range(9):
			var f := float(k) / 8.0
			pts.append(a.lerp(b, f) + Vector2(0.0, sin(f * PI) * 3.0))
		ci.draw_polyline(pts, Color("#e8eef2"), 1.0)
		for k in range(1, 8, 2):
			var p: Vector2 = pts[k]
			ci.draw_line(p, p + Vector2(-3.0, -5.0), Color("#b9c4cc"), 1.0)
		ci.draw_line(a, a + Vector2(-8.0, -10.0), Color("#b9c4cc"), 1.0)
		ci.draw_line(b, b + Vector2(8.0, -10.0), Color("#b9c4cc"), 1.0)
	# cocoons: old pages wrapped in web, hanging from the ceiling
	for c in COCOONS:
		var cxp: float = c[0] + sin(now * 0.7 + c[0]) * 1.0
		ci.draw_line(Vector2(c[0], 16.0), Vector2(cxp, c[1] - 9.0), Color("#9aa4ac"), 1.0)
		ci.draw_rect(Rect2(cxp - 5.0, c[1] - 9.0, 10.0, 18.0), ink)
		ci.draw_rect(Rect2(cxp - 4.0, c[1] - 8.0, 8.0, 16.0), Color("#d9dccf"))
		for k in range(4):
			ci.draw_line(Vector2(cxp - 4.0, c[1] - 6.0 + k * 4.0), Vector2(cxp + 4.0, c[1] - 4.0 + k * 4.0), Color("#a9ad9f"), 1.0)
	# the back wall screen's frame (the picture is in the glow layer)
	var sr := SCREEN
	ci.draw_rect(Rect2(sr.position.x - 6.0, sr.position.y - 6.0, sr.size.x + 12.0, sr.size.y + 14.0), ink)
	ci.draw_rect(Rect2(sr.position.x - 5.0, sr.position.y - 5.0, sr.size.x + 10.0, sr.size.y + 12.0), Color("#a89a74"))
	ci.draw_rect(Rect2(sr.position.x - 2.0, sr.position.y - 2.0, sr.size.x + 4.0, sr.size.y + 4.0), Color("#2a2a24"))
	ci.draw_rect(Rect2(sr.position.x + sr.size.x - 10.0, sr.position.y + sr.size.y + 3.0, 4.0, 2.0), Color("#3b5b3b"))
	# the neon tubes' fittings
	for i in range(ZONES.size()):
		var zx: float = ZONES[i]
		ci.draw_rect(Rect2(zx - 3.0, 128.0, 6.0, 3.0), Color("#4a4458"))
		ci.draw_rect(Rect2(zx - 3.0, 297.0, 6.0, 3.0), Color("#4a4458"))
		if (zones >> i) & 1 == 0:                                           # broken: a few shards left in the fittings
			ci.draw_line(Vector2(zx, 131.0), Vector2(zx - 1.0, 150.0), Color("#5a5468"), 2.0)
			ci.draw_line(Vector2(zx, 297.0), Vector2(zx + 1.0, 282.0), Color("#5a5468"), 2.0)

func draw_glow(ci: CanvasItem) -> void:
	var now: float = room.time
	var lit := 1.0 - dark
	for i in range(ZONES.size()):
		if (zones >> i) & 1 == 1 and lit > 0.05:
			var flick := 1.0 if int(now * 23.0 + i * 7) % 37 != 0 else 0.4
			var zx: float = ZONES[i]
			var c := Color("#ff4fd8") if i % 2 == 0 else Color("#4ff0ff")
			c.a = lit * flick
			ci.draw_rect(Rect2(zx - 1.0, 131.0, 2.0, 166.0), c)
			ci.draw_rect(Rect2(zx, 131.0, 1.0, 166.0), Color(1, 1, 1, 0.6 * lit * flick))
	# the drawer lamps: a tiny pilot light on each drawer still there (so the platforms can be found in the dark)
	for di in range(DRAWERS.size()):
		if (drawers >> di) & 1 == 1:
			var r := drawer_rect(di)
			ci.draw_rect(Rect2(r.position.x + 23.0, r.position.y + 1.0, 2.0, 1.0), Color("#ffcf6a"))
	for c in COCOONS:
		ci.draw_rect(Rect2(c[0] - 1.0, c[1] - 2.0, 2.0, 3.0), Color(0.85, 0.95, 0.8, 0.25 + 0.15 * sin(now * 1.7 + c[0])))
	_draw_screen(ci, now)

func _draw_screen(ci: CanvasItem, now: float) -> void:
	var sr := SCREEN
	var mode := String(screen.get("mode", "home"))
	if mode == "off":
		ci.draw_rect(sr, Color("#06080a"))
		return
	var on := 1.0 - dark * 0.8
	ci.draw_rect(sr, Color("#dfe6da"))
	if mode == "zero":                                                      # the blackout: the counter alone, then nothing
		ci.draw_rect(sr, Color("#0a0d0b"))
		PixelText.draw_text(ci, "0", sr.position.x + sr.size.x / 2.0, sr.position.y + 26.0, GREEN, {"align": "c", "scale": 2})
		return
	if mode == "last":                                                      # after the fight: its last search, no results
		ci.draw_rect(sr, Color("#0e120f"))
		var txt := String(screen.text)
		ci.draw_rect(Rect2(sr.position.x + 8.0, sr.position.y + 28.0, sr.size.x - 16.0, 11.0), Color("#1c241e"))
		PixelText.draw_text(ci, txt, sr.position.x + 11.0, sr.position.y + 30.0, "#8fdca0", {"tiny": true})
		if int(now * 2.0) % 2 == 0:
			ci.draw_rect(Rect2(sr.position.x + 12.0 + PixelText.text_width(txt, {"tiny": true}), sr.position.y + 30.0, 1.0, 6.0), Color("#8fdca0"))
		return
	# the homepage: a colourful logo, the search box, the counter
	var lx := sr.position.x + sr.size.x / 2.0
	var cols := ["#3a6ff0", "#e8463a", "#f2c12e", "#3a6ff0", "#2fa84f", "#e8463a", "#3a6ff0"]
	var word := "Crawler"
	var wx := lx - PixelText.text_width(word) / 2.0
	for k in range(word.length()):
		var ch := word[k]
		PixelText.draw_text(ci, ch, wx, sr.position.y + 8.0, cols[k % cols.size()], {})
		wx += PixelText.text_width(ch) + 1.0
	var box := Rect2(sr.position.x + 10.0, sr.position.y + 24.0, sr.size.x - 20.0, 11.0)
	ci.draw_rect(Rect2(box.position.x - 1.0, box.position.y - 1.0, box.size.x + 2.0, box.size.y + 2.0), Color("#7d8a96"))
	ci.draw_rect(box, Color("#ffffff"))
	var typed := ""
	if mode == "query" or mode == "results":
		var full := String(screen.text)
		var n := clampi(floori((now - float(screen.t0)) * 14.0), 0, full.length())
		typed = full.substr(0, n) if mode == "query" else full
	PixelText.draw_text(ci, typed, box.position.x + 3.0, box.position.y + 3.0, "#222222", {"tiny": true})
	if int(now * 2.5) % 2 == 0 and mode != "results":
		ci.draw_rect(Rect2(box.position.x + 4.0 + PixelText.text_width(typed, {"tiny": true}), box.position.y + 2.0, 1.0, 7.0), Color("#222222"))
	if mode == "found":                                                     # its search found one result: a picture of Clawd
		PixelText.draw_text(ci, "who replaced me", box.position.x + 3.0, box.position.y + 3.0, "#222222", {"tiny": true})
		PixelText.draw_text(ci, "1 result", box.position.x, box.position.y + 15.0, "#5a6470", {"tiny": true})
		var cxp := box.position.x + 4.0
		var cyp := box.position.y + 25.0
		ci.draw_rect(Rect2(cxp - 1.0, cyp - 1.0, 18.0, 14.0), Color("#7d8a96"))
		ci.draw_rect(Rect2(cxp, cyp, 16.0, 12.0), Color("#1b1226"))
		ci.draw_rect(Rect2(cxp + 3.0, cyp + 3.0, 10.0, 6.0), Color("#e8875a"))           # the little orange one
		ci.draw_rect(Rect2(cxp + 5.0, cyp + 5.0, 1.0, 1.0), Color("#1b1226"))
		ci.draw_rect(Rect2(cxp + 10.0, cyp + 5.0, 1.0, 1.0), Color("#1b1226"))
		ci.draw_rect(Rect2(cxp + 4.0, cyp + 9.0, 1.0, 2.0), Color("#e8875a"))
		ci.draw_rect(Rect2(cxp + 11.0, cyp + 9.0, 1.0, 2.0), Color("#e8875a"))
		ci.draw_rect(Rect2(cxp + 20.0, cyp + 2.0, 50.0, 2.0), Color("#3a5ad8"))
		PixelText.draw_text(ci, "agent", cxp + 20.0, cyp + 6.0, "#5a6470", {"tiny": true})
	elif mode == "results":
		var y0 := box.position.y + 15.0
		PixelText.draw_text(ci, String(screen.get("sub", "results")), box.position.x, y0, "#5a6470", {"tiny": true})
		for k in range(3):
			ci.draw_rect(Rect2(box.position.x, y0 + 9.0 + k * 6.0, 46.0 + (k * 13) % 30, 2.0), Color("#3a5ad8"))
	elif mode == "captcha":                                                  # "I'm not a robot" and a row of seven squares, the picked ones marked
		ci.draw_rect(Rect2(box.position.x, box.position.y + 14.0, 9.0, 9.0), Color("#7d8a96"))
		ci.draw_rect(Rect2(box.position.x + 1.0, box.position.y + 15.0, 7.0, 7.0), Color("#ffffff"))
		PixelText.draw_text(ci, "I'm not a robot", box.position.x + 12.0, box.position.y + 16.0, "#222222", {"tiny": true})
		var sel := int(screen.get("sel", 0))
		for k in range(7):
			var q := Rect2(sr.position.x + 8.0 + k * 15.0, sr.position.y + sr.size.y - 14.0, 13.0, 11.0)
			ci.draw_rect(q, Color("#6f8a5a") if k % 2 == 0 else Color("#58744a"))
			if (sel >> k) & 1 == 1:
				ci.draw_rect(Rect2(q.position.x, q.position.y, q.size.x, q.size.y), Color(0.25, 0.45, 0.95, 0.55))
				ci.draw_rect(Rect2(q.position.x + 4.0, q.position.y + 3.0, 5.0, 5.0), Color("#ffffff"))
	else:
		PixelText.draw_text(ci, "0 searches today", lx, sr.position.y + sr.size.y - 12.0, "#5a6470", {"tiny": true, "align": "c"})
	if on < 1.0:
		ci.draw_rect(sr, Color(0, 0, 0, 1.0 - on))
	# scanlines
	var yy := sr.position.y
	while yy < sr.position.y + sr.size.y:
		ci.draw_rect(Rect2(sr.position.x, yy, sr.size.x, 1.0), Color(0, 0, 0, 0.08))
		yy += 2.0
