class_name Boss
extends Enemy
# Boss: base of the boss fights. Port of `class Boss` (js/bosses.js). The arena floor line FLOOR (176) is shared by every arena.

const FLOOR := 176.0

static var tint_mat: ShaderMaterial

var boss_name := ""
var sub := ""
var max_hp := 1
var hpf := 1.0
var active := false
var phase := 1
var st := "wait"
var st_t := 0.0
var n := 0
var dying := false
var die_t := 0.0
var drop_n := 24
var gone := false
var is_boss := true
var target = null
var body: DrawProxy
var overlay: DrawProxy

func _init(r: Room, bx: float, by: float, bw: float, bh: float, boss_hp: int) -> void:
	super(r, 0, 0, bw, bh)
	x = bx - bw / 2.0
	y = by - bh
	hp = boss_hp
	hpf = float(boss_hp)
	max_hp = boss_hp
	passive = true
	always = true
	stompable = false
	kb = 0.0
	z_index = 2

func _ready() -> void:
	body = DrawProxy.new()
	body.cb = draw_boss_body
	add_child(body)
	overlay = DrawProxy.new()
	overlay.cb = draw_boss_overlay
	add_child(overlay)

# the co-op factor (a second player in the arena); MERGE CONFLICT overrides it (two heads)
func scale_hp(k: float) -> void:
	max_hp = roundi(max_hp * k)
	hpf = float(max_hp)
	hp = max_hp

# who the boss aims at: one target per attack, taken in turns (co-op), so both players get attacked whoever deals the damage; alone: the player
func pick_target():
	var ps: Array = room.players()
	if ps.is_empty():
		return room.player
	if target == null or not (target in ps):
		target = ps[0]
	return target

func next_target() -> void:
	var ps: Array = room.players()
	if ps.is_empty():
		return
	var i: int = ps.find(target)
	target = ps[(i + 1) % ps.size()] if i >= 0 else ps[room.rng.randi() % ps.size()]
	if ps.size() > 1:
		Game.dlog("%s targets %s (hp %.1f)" % [boss_name, "P2" if target.get("is_remote") else "P1", hpf])

# where to aim at a player: the partner is seen late on this page and the guest sees NULL late again, so aim where it will be by then
func aim_point(q) -> Vector2:
	if not q.get("is_remote") or q.samples.is_empty():
		return Vector2(q.x + 5, q.y + 5)
	var last: Array = q.samples[q.samples.size() - 1]
	var lead := clampf(Net.rtt + 0.18, 0.1, 0.45)
	return Vector2(clampf(last[1] + q.vx * lead, 0.0, Game.W - 10.0) + 5, float(last[2]) + 5)

func set_state(s: String, t_ := 0.0) -> void:
	st = s
	st_t = t_
	n = 0

func start() -> void:
	active = true
	passive = false
	set_state("idle", 1.0)

func hit(d: int, _dx: float, _dy: float, how: String, box = null) -> String:
	if not active or dying:
		return ""
	var dmg := float(d)
	if how == "agent" or how == "dash":
		dmg *= 0.5
	hpf -= dmg
	hp = ceili(hpf)
	flash = 0.1
	var b = box if box != null else self
	room.burst(b.x + b.w / 2.0, b.y + b.h / 2.0, 6, [col, "#ffffff"], 120.0, 200.0, {"glow": 1})
	Audio.sfx("bossHit")
	room.boss_damage(self, dmg, how)
	on_damage()
	if hpf <= 0.0 and not dying:
		hp = 0
		hpf = 0.0
		begin_death()
		return "kill"
	return "hit"

func on_damage() -> void:
	pass

func begin_death() -> void:
	dying = true
	die_t = 0.0
	passive = true
	for q in room.projs:
		q.dead = true
	for e in room.ents:
		if e != self and not e.get("is_boss"):
			e.loot = 0
			e.die("")
	room.stop(0.35)
	room.shake(1.0)
	room.flash_screen(0.9)
	room.events.append("bossDying")

# generic "blow up for a while" ending; returns true when finished
func death_rattle(dt: float, dur: float, cols: Array) -> bool:
	die_t += dt
	if room.rng.randf() < 0.35:
		room.explode(x + room.rng.randf_range(0, w), y + room.rng.randf_range(0, h), room.rng.randf_range(8, 16), cols)
		Audio.sfx("explode", {"vol": 0.6})
		room.shake(0.25)
	if die_t >= dur and not gone:
		gone = true
		dead = true
		room.explode(cx, cy, 46, cols)
		room.flash_screen(1.0)
		room.shake(1.0)
		Audio.sfx("bigExplode")
		room.drop(cx, cy, drop_n)
		room.events.append("bossDead")
		return true
	return false

func _process(_dt: float) -> void:
	if flash_mat == null:
		super._process(_dt)
	body.material = flash_mat if flash > 0.0 else null
	body.queue_redraw()
	overlay.queue_redraw()

func draw_body() -> void:
	pass

func draw_boss_body(_ci: CanvasItem) -> void:
	pass

func draw_boss_overlay(_ci: CanvasItem) -> void:
	pass

# dashed danger column (js: warnCol)
func warn_col(ci: CanvasItem, wx: float) -> void:
	var sx := floori(wx + 0.5)
	var col := Color(Game.COL.hazard) if int(t * 12.0) % 2 == 1 else Color(Game.COL.hazardHi)
	var yy: float = room.cam.y + 20 + (int(t * 60.0) % 8)
	while yy < FLOOR:
		ci.draw_rect(Rect2(sx, yy, 1, 4), col)
		yy += 8
	PixelText.draw_text(ci, "!", sx - 1, room.cam.y + 20, Game.COL.hazardHi, {"outline": Game.COL.ink})

static func tint_material() -> ShaderMaterial:
	if tint_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.75, 0.91, 1.0, 1.0);\nvoid fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(tint.rgb, c.a * COLOR.a); }\n"
		tint_mat = ShaderMaterial.new()
		tint_mat.shader = sh
	return tint_mat

# ================================================================ boss kit (docs/PLAN-metroidvania-phase4b0.md MVB0-08/09)
# Opt-in: a boss that never calls plan_start behaves as before. One attack at a time, each announced first (cue), then active, then a
# recovery. The plan is state (it travels in net_fields through plan_fields), so the guest shows what the host does and is hurt only by
# what it was shown: with a guest in the room the host waits until the guest has acknowledged the plan (seen_seq) SEEN_MIN ago.
const FAMILY := {"lunge": [1.0, 0.35, 0.9], "proj": [0.85, 0.6, 1.0], "slam": [1.2, 0.3, 1.2], "sweep": [1.6, 0.6, 1.4],
				 "flood": [2.5, 1.0, 1.75], "dual": [1.6, 0.5, 1.5], "guard": [0.5, 1.2, 0.4]}
const FAM_KEYS := ["lunge", "proj", "slam", "sweep", "flood", "dual", "guard"]
const PLAN_PH := ["cue", "active", "recover"]
const SEEN_MIN := 0.35            # the guest has the plan at least this long before it turns active
const HOLD_MAX := 0.60            # longer than this unseen: the attack is cancelled for everyone (recover, no harm)

var plan := {}                    # {} = no attack. Else seq, id, fam, tgt ("p1" host's player | "p2" guest's), ph, t, fp [x, y, w, h], lock
var plan_seq := 0                 # host counter, never reused in a room
var seen_seq := 0                 # host: the newest plan seq the guest acknowledged (Coop writes it); solo: always plan.seq
var seen_at := 0.0                # host: plan_clock when it learned that
var hold_t := 0.0                 # host: how long the end of this cue has been held for the guest
var plan_clock := 0.0
var read: BossRead = null         # the behaviour reader (rule 8); a kit boss makes one with kit_init()
var kit_hist: Array = []          # host: the targets of the last attacks, newest last
var plan_snap_seq := 0            # host: the newest plan seq a snapshot carried (Coop remembers which snapshot)
var cue_shown := {}               # guest: plan seq -> seconds it was shown in cue (guest time)
var kit_violation := ""           # guest: set when a plan turned active without having been shown (the watchdog rule boss-cue)
var kit_active_seen := {}         # guest: plan seqs that have turned active

func kit_init() -> void:
	read = BossRead.new(self)

func plan_ids() -> Array:
	return []

# who is "p1" / "p2" on this page: the host's player is p1, the guest's p2 (a guest sees them swapped in its room)
func kit_body(key: String):
	var guest := room.mode == "guest"
	var remote = null
	for rp in room.remote_players:
		remote = rp
		break
	if (key == "p1") != guest:
		return room.player
	return remote

func kit_alive(key: String) -> bool:
	var q = kit_body(key)
	if q == null or q.dead:
		return false
	return not (q.get("is_remote") == true and q.lagging)

func kit_keys() -> Array:
	var out: Array = []
	for k in ["p1", "p2"]:
		if kit_alive(k):
			out.append(k)
	return out

func kit_key_of(q) -> String:
	if q == null:
		return ""
	return "p2" if q.get("is_remote") == true else "p1"

func kit_dist(key: String) -> float:
	var q = kit_body(key)
	if q == null:
		return 1e9
	return Vector2(q.x + q.w / 2.0 - cx, q.y + q.h / 2.0 - cy).length()

func _guest_waits() -> bool:
	for rp in room.remote_players:
		if not rp.dead and not rp.lagging:
			return true
	return false

func _tm() -> float:
	return float(Game.dv("telegraph_mult"))

func _pm(base: float) -> float:
	return maxf(0.4, base * float(Game.dv("punish_mult")))

# a recover time set by the boss itself (MVB3-02): x punish_mult, never below 0.4 (a chain's own short gap, under 0.4, is kept)
func _pm_rec(rec: float) -> float:
	return maxf(minf(rec, 0.4), rec * float(Game.dv("punish_mult")))

func _plan_rec(f: Array) -> float:
	return _pm(f[2]) if float(plan.get("rec", -1.0)) < 0.0 else _pm_rec(float(plan.rec))

# a new attack; the target is fixed for the whole attack. cue < 0: the family's own cue; rec >= 0: this recover instead of the family's; act >= 0: this active time
func plan_start(id: String, fam: String, tgt: String, fp: Array, lock := 0.0, cue := -1.0, rec := -1.0, act := -1.0) -> void:
	plan_seq += 1
	var f: Array = FAMILY[fam]
	plan = {"seq": plan_seq, "id": id, "fam": fam, "tgt": tgt, "ph": "cue", "t": (f[0] if cue < 0.0 else cue) * _tm(), "fp": fp.duplicate(), "lock": lock, "rec": rec, "act": act}
	hold_t = 0.0
	if not _guest_waits():
		seen_seq = plan_seq
		seen_at = plan_clock
	kit_hist.append(tgt)
	if kit_hist.size() > 6:
		kit_hist.pop_front()

# the guest's snapshot acknowledgement reached the host
func plan_seen(seq: int) -> void:
	if seq > seen_seq:
		seen_seq = seq
		seen_at = plan_clock

# counts the plan down; returns the phase that just began ("active", "recover", "done") or ""
func plan_step(dt: float) -> String:
	plan_clock += dt
	if plan.is_empty():
		return ""
	plan.t -= dt
	if plan.t > 0.0:
		return ""
	var f: Array = FAMILY[plan.fam]
	match plan.ph:
		"cue":
			if _guest_waits() and not (seen_seq >= int(plan.seq) and plan_clock - seen_at >= SEEN_MIN):
				plan.t = 0.0
				hold_t += dt
				if hold_t > HOLD_MAX:
					Game.dlog("%s plan %d cancelled: the guest did not see it" % [boss_name, plan.seq])
					plan.ph = "recover"
					plan.t = _plan_rec(f)
					return "recover"
				return ""
			plan.ph = "active"
			plan.t = f[1] if float(plan.get("act", -1.0)) < 0.0 else float(plan.act)
			return "active"
		"active":
			plan.ph = "recover"
			plan.t = _plan_rec(f)
			return "recover"
	plan = {}
	return "done"

func plan_phase() -> String:
	return "" if plan.is_empty() else String(plan.ph)

func plan_active() -> bool:
	return not plan.is_empty() and plan.ph == "active"

# the attack goes straight to its recovery (a block, a parry)
func plan_cut() -> void:
	if not plan.is_empty() and plan.ph != "recover":
		plan.ph = "recover"
		plan.t = _plan_rec(FAMILY[plan.fam])

func plan_fields() -> Array:
	if plan.is_empty():
		return [plan_seq, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0]
	var ids := plan_ids()
	var fp: Array = plan.fp
	return [plan.seq, maxi(0, ids.find(plan.id)), FAM_KEYS.find(plan.fam), 0 if plan.tgt == "" else (1 if plan.tgt == "p1" else 2), PLAN_PH.find(plan.ph),
		roundi(maxf(plan.t, 0.0) * 100.0), roundi(fp[0]), roundi(fp[1]), roundi(fp[2]), roundi(fp[3]), roundi(float(plan.lock) * 100.0)]

func plan_apply(a: Array) -> void:
	if int(a[4]) < 0:
		plan = {}
		plan_seq = int(a[0])
		return
	var ids := plan_ids()
	plan_seq = int(a[0])
	plan = {"seq": int(a[0]), "id": ids[clampi(int(a[1]), 0, maxi(0, ids.size() - 1))] if not ids.is_empty() else "", "fam": FAM_KEYS[clampi(int(a[2]), 0, FAM_KEYS.size() - 1)],
		"tgt": ["", "p1", "p2"][clampi(int(a[3]), 0, 2)], "ph": PLAN_PH[clampi(int(a[4]), 0, 2)], "t": a[5] / 100.0, "fp": [float(a[6]), float(a[7]), float(a[8]), float(a[9])], "lock": a[10] / 100.0}

# the guest's side: how long each plan was shown in cue (the watchdog rule boss-cue reads kit_violation)
var kit_age := 0.0
var kit_ignore_seq := -1          # the plan that was already running when this copy was made (the guest came in late)
func kit_puppet_tick(dt: float) -> void:
	if plan.is_empty():
		return
	var s: int = plan.seq
	if kit_age == 0.0:
		kit_ignore_seq = s if plan.ph != "cue" else -1
	kit_age += dt
	if plan.t > 0.0:
		plan.t = maxf(0.0, plan.t - dt)
	if plan.ph == "cue":
		cue_shown[s] = float(cue_shown.get(s, 0.0)) + dt
	elif plan.ph == "active" and not kit_active_seen.has(s):
		kit_active_seen[s] = true
		var shown: float = float(cue_shown.get(s, 0.0))
		if shown < 0.30 and kit_violation == "" and s != kit_ignore_seq:
			kit_violation = "plan %d active after %.2f s of cue" % [s, shown]

# ---- targets (research report 6, 5.3): one per attack, chosen when it starts, never changed during it ----
func kit_pick_target() -> String:
	var keys := kit_keys()
	if keys.is_empty():
		return "p1" if room.mode != "guest" else "p2"
	if keys.size() == 1:
		return keys[0]
	var best := ""
	var best_score := -1
	var nearest := ""
	var nd := 1e18
	for k in keys:
		var d := kit_dist(k)
		if d < nd:
			nd = d
			nearest = k
	var last_hit: String = read.last_hitter() if read != null else ""
	for k in keys:
		var score := 0
		if k == nearest:
			score += 2
		var li := kit_hist.rfind(k)                    # when it was targeted last (-1: never)
		var other: String = "p2" if k == "p1" else "p1"
		if li < kit_hist.rfind(other):
			score += 1                                  # targeted less recently than the other
		if k == last_hit:
			score += 1
		if score > best_score or (score == best_score and kit_hist.size() > 0 and kit_hist[kit_hist.size() - 1] != k):
			best_score = score
			best = k
	# never three attacks in a row on the same player while the other one is here
	if kit_hist.size() >= 2 and kit_hist[kit_hist.size() - 1] == best and kit_hist[kit_hist.size() - 2] == best:
		best = "p2" if best == "p1" else "p1"
	return best

# the point to aim at on a player (the partner is seen late: led by the ping)
func kit_aim(key: String) -> Vector2:
	var q = kit_body(key)
	if q == null:
		return Vector2(cx, cy)
	return aim_point(q)

# ---- drawing: the announcement of the attack ----
func draw_plan(ci: CanvasItem) -> void:
	if plan.is_empty() or plan.ph != "cue":
		return
	var fp: Array = plan.fp
	var hot := int(t * 12.0) % 2 == 0
	var c1 := Color(Game.COL.hazardHi) if hot else Color(Game.COL.hazard)
	var c2 := Color(Game.COL.hazard)
	var catchable: bool = plan.fam == "proj"
	if plan.fam != "proj" and plan.fam != "guard" and fp[2] > 0.0:
		var rx: float = floorf(fp[0])
		var ry: float = floorf(fp[1])
		ci.draw_rect(Rect2(rx, ry, fp[2], fp[3]), Color(c2.r, c2.g, c2.b, 0.18))
		var yy: float = 0.0
		while yy < fp[3]:                                # stripes: the hazard is a hatched shape, not just a colour
			ci.draw_rect(Rect2(rx, ry + yy, fp[2], 1), Color(c1.r, c1.g, c1.b, 0.7))
			yy += 4.0
		ci.draw_rect(Rect2(rx, ry, fp[2], 1), c1)
		ci.draw_rect(Rect2(rx, ry + fp[3] - 1, fp[2], 1), c1)
		ci.draw_rect(Rect2(rx, ry, 1, fp[3]), c1)
		ci.draw_rect(Rect2(rx + fp[2] - 1, ry, 1, fp[3]), c1)
		PixelText.draw_text(ci, "!", rx + fp[2] / 2.0 - 1.0, ry + fp[3] / 2.0 - 3.0, Game.COL.hazardHi, {"outline": Game.COL.ink})
	if plan.fam == "proj":                               # the boss glows; the diamonds that come are yellow (catchable)
		ci.draw_arc(Vector2(cx, cy), 16.0 + sin(t * 20.0) * 2.0, 0.0, TAU, 20, Color("#ffd23f"), 2.0)
		_diamond(ci, cx + face * 14.0, cy - 14.0, 4.0, Color("#ffd23f"))
	_target_marker(ci, String(plan.tgt))

# over the target: a circle with "1" for P1, a diamond with "2" for P2 (the shapes the map will use); never colour alone
func _target_marker(ci: CanvasItem, key: String) -> void:
	var q = kit_body(key)
	if q == null:
		return
	var mx: float = floorf(q.x + q.w / 2.0 + 0.5)
	var my: float = floorf(q.y - 13.0 - absf(sin(t * 8.0)) * 2.0)
	var ink := Color(Game.COL.ink)
	if key == "p1":
		Fx._disc(ci, mx, my, 6, ink)
		Fx._disc(ci, mx, my, 5, Color("#ffffff"))
		PixelText.draw_text(ci, "1", mx - 2.0, my - 3.0, Game.COL.ink, {"tiny": true})
	else:
		_diamond(ci, mx, my, 7.0, ink)
		_diamond(ci, mx, my, 6.0, Color("#ffffff"))
		PixelText.draw_text(ci, "2", mx - 2.0, my - 3.0, Game.COL.ink, {"tiny": true})

func _diamond(ci: CanvasItem, px: float, py: float, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px, py - r), Vector2(px + r, py), Vector2(px, py + r), Vector2(px - r, py)]), col)

# ================================================================ arena hazards (docs/PLAN-metroidvania-phase4b3.md MVB3-02)
# A boss's environment, beside its one attack plan: strands, deny walls, comments on the floor. A hazard is {k, t0, warn, v}: its kind, the
# room time it was made, its warning (>= 0.6 s: it is drawn from t0 and hurts only after t0 + warn) and numbers. Its harm boxes are a pure
# function of those fields and the room time (hz_boxes), so the guest, who gets the fields in net_fields and the time in the snapshot (`rt`),
# builds the same boxes. Damage is contact damage: each page checks its own body. On the guest a hazard hurts only after it has been on
# screen HZ_SEEN_MIN seconds; the watchdog rule arena-tell reads arena_violation if one ever did without that.
const HZ_WARN_MIN := 0.6
const HZ_SEEN_MIN := 0.5          # the guest is hurt only by a hazard it has been looking at for this long
const HZ_TELL_MIN := 0.45         # ... and the watchdog complains below this
var hz: Array = []
var hz_seen := {}                 # guest: hazard key -> seconds it has been in the list
var arena_violation := ""         # guest: set when a hazard hurt without having been shown (the watchdog rule arena-tell)
var hz_gate := HZ_SEEN_MIN        # (a test lowers it to prove the rule)

func hz_kinds() -> Array:
	return []

func hz_add(kind: String, warn: float, v: Array = []) -> Dictionary:
	var h := {"k": kind, "t0": snappedf(room.time, 0.01), "warn": snappedf(maxf(warn, HZ_WARN_MIN), 0.01), "v": v}
	hz.append(h)
	return h

func hz_live(h: Dictionary, now: float) -> bool:
	return now - float(h.t0) >= float(h.warn)

# the harm boxes of one hazard at room time `now` (only called once it is live); override. Each box may carry its own "dmg".
func hz_boxes(_h: Dictionary, _now: float) -> Array:
	return []

# every live hazard's boxes: a pure function of the hazard fields and `now`
func hz_all_boxes(now: float) -> Array:
	var out: Array = []
	for h in hz:
		if hz_live(h, now):
			out.append_array(hz_boxes(h, now))
	return out

func hz_key(h: Dictionary) -> String:
	return "%s:%d" % [h.k, roundi(float(h.t0) * 100.0)]

# what the room's contact check uses: on the guest only the hazards it has been looking at
func hz_harm() -> Array:
	if not puppet:
		return hz_all_boxes(room.time)
	var out: Array = []
	for h in hz:
		if not hz_live(h, room.time):
			continue
		var seen := float(hz_seen.get(hz_key(h), 0.0))
		if seen >= hz_gate:
			var bx := hz_boxes(h, room.time)
			if not bx.is_empty() and seen < HZ_TELL_MIN and arena_violation == "":
				arena_violation = "%s %s after %.2f" % [boss_name, h.k, seen]
			out.append_array(bx)
	return out

func hz_puppet_tick(dt: float) -> void:
	var keep := {}
	for h in hz:
		var k := hz_key(h)
		keep[k] = float(hz_seen.get(k, 0.0)) + dt
	hz_seen = keep

func hz_pack() -> Array:
	var kinds := hz_kinds()
	var out: Array = []
	for h in hz:
		var a: Array = [maxi(0, kinds.find(h.k)), roundi(float(h.t0) * 100.0), roundi(float(h.warn) * 100.0)]
		a.append_array(h.v)
		out.append(a)
	return out

func hz_unpack(list: Array) -> void:
	var kinds := hz_kinds()
	var fresh: Array = []
	for a in list:
		var h := {"k": kinds[clampi(int(a[0]), 0, maxi(0, kinds.size() - 1))] if not kinds.is_empty() else "", "t0": float(a[1]) / 100.0, "warn": float(a[2]) / 100.0, "v": a.slice(3)}
		fresh.append(h)
	hz = fresh
