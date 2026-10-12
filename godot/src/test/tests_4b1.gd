extends RefCounted
class_name Tests4b1
# Unit tests of phase 4B-1 (the map, the cartographer and the small systems). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["worlddigest", "mapdata"]

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String) -> bool:
	match name:
		"worlddigest": return t_worlddigest()
		"mapdata": return t_mapdata()
	return report(name, false, "unknown test")

# one small checker: chk.call(label, cond)
func checker() -> Dictionary:
	return {"ok": true, "info": ""}

func fail(res: Dictionary, label: String) -> void:
	res.ok = false
	res.info += " BAD:" + label

func t_worlddigest() -> bool:
	Game.persist = false
	Game.flags = {}
	var res := checker()
	var e0 := Game.world_digest()
	Game.flags["boss:NULL"] = true
	Game.flags["log:R08:0"] = true
	Game.flags["mapped:R01"] = true
	var a := Game.world_digest()
	if a == e0:
		fail(res, "adding changes")
	Game.flags = {}
	Game.flags["mapped:R01"] = true
	Game.flags["boss:NULL"] = true
	Game.flags["log:R08:0"] = true
	if Game.world_digest() != a:
		fail(res, "order")
	Game.flags["room:R01:visited"] = true
	Game.flags["item:R01:3"] = true
	Game.flags["bench:R01"] = true
	if Game.world_digest() != a:
		fail(res, "a non-world flag changed it")
	Game.flags["log:R08:1"] = true
	if Game.world_digest() == a:
		fail(res, "a world flag did not change it")
	Game.flags["log:R08:1"] = false
	if Game.world_digest() != a:
		fail(res, "a cleared flag counts")
	var wf := Game.world_flags()
	if wf != ["boss:NULL", "log:R08:0", "mapped:R01"]:
		fail(res, "list " + str(wf))
	Game.flags = {}
	return report("worlddigest", res.ok, res.info)

func new_manager() -> RoomManager:
	var m := RoomManager.new(main.world, null)
	main.add_child(m)
	m.start_game()
	return m

func t_mapdata() -> bool:
	Game.persist = false
	Game.fresh()
	Game.load_meta()
	var res := checker()
	# zones and secrets (MVB1-02)
	var zones := {}
	for z in Game.ZONES:
		zones[z.id] = true
	var secrets: Array = []
	for id in Game.rooms_meta.rooms:
		var m: Dictionary = Game.rooms_meta.rooms[id]
		if not zones.has(Game.zone_of(id)):
			fail(res, "zone of " + id)
		if bool(m.get("secret", false)):
			secrets.append(id)
		if Game.is_lab(id) and Game.zone_of(id) == "src":
			fail(res, "lab room in src " + id)
	secrets.sort()
	if secrets != ["D07", "H12", "H13", "H14", "H15", "H16", "R06", "R12", "R13", "R15"]:
		fail(res, "secrets " + str(secrets))
	# staged vs committed
	var mgr := new_manager()
	mgr.swap_to("R02")
	if Game.is_mapped("R01") or Game.is_mapped("R02"):
		fail(res, "committed before a rest")
	if not (Game.staged_rooms().has("R01") and Game.staged_rooms().has("R02")):
		fail(res, "staged " + str(Game.staged_rooms()))
	mgr.swap_to("R08")
	mgr.rest(mgr.room, 0)
	if not (Game.is_mapped("R01") and Game.is_mapped("R02") and Game.is_mapped("R08")):
		fail(res, "rest commits the walked rooms")
	if not Game.staged_rooms().is_empty():
		fail(res, "nothing stays staged")
	# the view needs the index
	var v: Dictionary = Game.map_view("src")
	if not (v.outline.is_empty() and v.filled.is_empty()):
		fail(res, "no map without the index")
	Game.flags["map:src"] = true
	v = Game.map_view("src")
	var want_outline: Array = []
	for id in Game.rooms_meta.rooms:
		if Game.zone_of(id) == "src" and not Game.is_secret(id) and not Game.is_lab(id):
			want_outline.append(id)
	want_outline.sort()
	var got_outline: Array = v.outline.duplicate()
	got_outline.sort()
	if got_outline != want_outline:
		fail(res, "outline " + str(got_outline))
	var got_filled: Array = v.filled.duplicate()
	got_filled.sort()
	if got_filled != ["R01", "R02", "R08"]:
		fail(res, "filled " + str(got_filled))
	if Game.map_view("dep").outline.size() != 0:
		fail(res, "another zone stays empty")
	# secret rooms: only once found
	if v.outline.has("R06") or v.filled.has("R06"):
		fail(res, "uncommitted secret shown")
	Game.flags["mapped:R06"] = true
	v = Game.map_view("src")
	if not v.filled.has("R06") or v.outline.has("R06"):
		fail(res, "committed secret: in filled, not in outline")
	if Game.zone_counts("src")[0] != 3:
		fail(res, "a secret never counts: %s" % str(Game.zone_counts("src")))
	# a lab room is never staged or committed
	if Game.commit_rooms(["Z01"]) != 0:
		fail(res, "lab committed")
	mgr.queue_free()
	# migration of an old save
	Game.fresh()
	var path := "user://t_mapdata_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "flags": {"room:H01:visited": true, "room:H02:visited": true, "room:H04:visited": true, "room:H03:visited": true, "room:Z01:visited": true}}))
	f.close()
	var old_path := Game.save_path
	Game.save_path = path
	Game.load_save()
	Game.save_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for id in ["H01", "H02", "H03", "H04"]:
		if not Game.is_mapped(id):
			fail(res, "migrated " + id)
	if not Game.owns_map("heap") or Game.owns_map("lab") or Game.is_mapped("Z01") or not Game.flag("map:migrated"):
		fail(res, "migration flags")
	var heap: Dictionary = Game.map_view("heap")
	if heap.filled.size() != 4:
		fail(res, "migrated view " + str(heap.filled))
	Game.fresh()
	return report("mapdata", res.ok, res.info)
