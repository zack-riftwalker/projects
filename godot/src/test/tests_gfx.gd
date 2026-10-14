extends RefCounted
class_name TestsGfx
# GFX-N (the NETWORK's look, docs/PLAN-metroidvania-gfx-network.md). Tests marked (render) need a real renderer: tools/godot/gfx-tests.sh runs them
# under xvfb with --rendering-driver opengl3; the others run headless like the rest.

const NAMES := ["moods", "gfxtier"]
const RENDER := []                                # the names that need a renderer (test-all runs them through gfx-tests.sh)
var main

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String):
	match name:
		"moods": return t_moods()
		"gfxtier": return t_gfxtier()

func new_room(room_id: String) -> Room:
	var room := Room.new()
	main.world.add_child(room)
	room.load_room(room_id)
	room.build_nodes()
	return room

# MVGN-02: every N room resolves to a mood, the look reaches its target in 1.2 s, worlds 1-5 have no Look
func t_moods() -> bool:
	Game.persist = false
	Game.fresh()
	Game.load_meta()
	var ok := true
	var info := ""
	var pal := Look.palettes()
	for want in ["stable", "loss", "lair", "heat", "heat_p3", "review", "stable_clean"]:
		if not pal.has(want):
			ok = false
			info += " palette %s missing;" % want
	var n := 0
	for id in Game.rooms_meta.rooms:
		if not id.begins_with("N") or not id.substr(1).is_valid_int():
			continue
		n += 1
		var def: Dictionary = Game.rooms_meta.rooms[id]
		var mm := Look.resolve(def)
		if not pal.has(mm[0]) or float(mm[1]) <= 0.0 or float(mm[1]) > 1.0:
			ok = false
			info += " %s has no mood;" % id
		if not def.has("mood"):
			ok = false
			info += " %s: no mood in rooms.json;" % id
	if n != 22:
		ok = false
		info += " %d N rooms;" % n
	# the table of the plan
	for pair in [["N09", "lair", 1.0], ["N12", "loss", 1.0], ["N15", "heat", 1.0], ["N22", "review", 1.0], ["N08", "lair", 0.6], ["N20", "loss", 0.5], ["N01", "stable", 1.0]]:
		var mm := Look.resolve(Game.rooms_meta.rooms[pair[0]])
		if mm[0] != pair[1] or not is_equal_approx(float(mm[1]), float(pair[2])):
			ok = false
			info += " %s is %s;" % [pair[0], str(mm)]
	# after the FIREWALL the stable rooms are clean, the others unchanged
	Game.flags["boss:FIREWALL"] = true
	if Look.resolve(Game.rooms_meta.rooms["N01"])[0] != "stable_clean" or Look.resolve(Game.rooms_meta.rooms["N12"])[0] != "loss":
		ok = false
		info += " stable_clean;"
	Game.flags.erase("boss:FIREWALL")
	# a blend takes 1.2 s (+- 0.1) and ends exactly on the mixed palette
	var look := Look.new()
	look.set_target("stable", 1.0, true)
	look.set_target("heat", 1.0, false)
	var t := 0.0
	while not look.reached() and t < 3.0:
		look.step(1.0 / 60.0)
		t += 1.0 / 60.0
	if absf(t - 1.2) > 0.1:
		ok = false
		info += " blend took %.2f s;" % t
	if not (look.out.ambient as Color).is_equal_approx(Look.mixed("heat", 1.0).ambient):
		ok = false
		info += " blend does not end on the target;"
	# a half way mood is a mix (k 0.5: halfway between stable and heat)
	var half := Look.mixed("heat", 0.5)
	var mid: Color = (pal.stable.ambient as Color).lerp(pal.heat.ambient as Color, 0.5)
	if not (half.ambient as Color).is_equal_approx(mid):
		ok = false
		info += " k mix;"
	look.free()
	# rooms: a NETWORK room has a Look in its mood, a room of another world has none
	var r1 := new_room("N09")
	if r1.look == null or r1.look.mood != "lair":
		ok = false
		info += " N09 look;"
	r1.queue_free()
	for id in ["R01", "D05", "H05", "T04"]:
		var r2 := new_room(id)
		if r2.look != null:
			ok = false
			info += " %s has a Look;" % id
		r2.queue_free()
	return report("moods", ok, info if info != "" else "%d rooms" % n)

func t_gfxtier() -> bool:
	return report("gfxtier", false, "todo")
