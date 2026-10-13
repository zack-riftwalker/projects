extends Tests4b3
class_name Tests5a
# Unit tests of phase 5A (THREAD TOWER). run_tests.gd hands names it does not know to run().

const NAMES5 := ["rooms5a", "w4assets"]

func run(name: String):
	match name:
		"rooms5a": return await t_rooms5a()
		"w4assets": return await t_w4assets()
	return await super.run(name)

func tower_ids() -> Array:
	var out: Array = []
	for id in Game.rooms_meta.rooms:
		if String(id).begins_with("T"):
			out.append(String(id))
	return out

# MV5A-01: the 19 tower rooms load, their doors point back (the loop room's wrap door points at its own room),
# N11's west door is open and its end door is gone, H11's hatch waits for the T02 lever
func t_rooms5a() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var ids := tower_ids()
	if ids.size() != 19:
		fail(res, "%d T rooms, want 19" % ids.size())
	for id in ids:
		var m: Dictionary = Game.rooms_meta.rooms[id]
		if Game.zone_of(id) != "tower" or int(m.get("world", 0)) != 4 or String(m.get("music", "")) != "w4":
			fail(res, "%s zone/world/music" % id)
		for d in m.doors:
			var to_room := String(d.to).get_slice(":", 0)
			if to_room == "P01" and m.has("end"):
				continue                                       # T11's end door ("to be continued in /var/prod")
			if not Game.rooms_meta.rooms.has(to_room):
				fail(res, "%s leads to the missing room %s" % [d.id, to_room])
				continue
			var back := false
			for td in Game.rooms_meta.rooms[to_room].doors:
				if td.id == d.to and (td.to == d.id or td.get("wrap", false)):
					back = true                                # (T10:W leads to the loop room's wrap door, which leads to its own W)
			if d.get("wrap", false):
				back = String(d.to) == String(d.id).get_slice(":", 0) + ":W"
			if not back:
				fail(res, "%s does not point back" % d.id)
		var r := new_room(id)
		await frames(1)
		if r.w != int(m.size[0]) or r.h != int(m.size[1]):
			fail(res, "%s size" % id)
		r.queue_free()
	var n11 := new_room("N11")
	var dw = n11.grid.door_at("W", int(Game.rooms_meta.rooms.N11.doors.filter(func(d): return d.id == "N11:W")[0].a))
	if dw == null or not dw.open:
		fail(res, "N11:W is not open")
	if n11.end_door != null or Game.rooms_meta.rooms.N11.has("end"):
		fail(res, "N11 still has an end door")
	n11.queue_free()
	var h11 := new_room("H11")
	var dh = h11.grid.door_at("N", 60)
	if dh == null or dh.open:
		fail(res, "H11:N is open without the lever")
	h11.queue_free()
	Game.flags["lever:T02"] = true
	var h11b := new_room("H11")
	var dh2 = h11b.grid.door_at("N", 60)
	if dh2 == null or not dh2.open:
		fail(res, "H11:N stays closed with the lever")
	h11b.queue_free()
	Game.fresh()
	return report("rooms5a", res.ok, "%d tower rooms%s" % [ids.size(), res.info])

# MV5A-02: world 4's art, theme and music exist and a tower room builds its view from them
func t_w4assets() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	for path in ["res://assets/tiles/w4_tiles.png", "res://assets/bg/w4.png", "res://assets/theme/w4.json", "res://assets/sprites/platform_w4.png", "res://assets/music/w4.ogg", "res://assets/music/w4_hi.ogg"]:
		if not ResourceLoader.exists(path):
			fail(res, path)
	if String(Game.theme(4).name) != "THREAD TOWER":
		fail(res, "theme name " + String(Game.theme(4).name))
	var r := new_room("T04")
	await frames(2)
	if r.view == null or r.view.tiles == null or r.world != 4:
		fail(res, "T04 builds no view")
	if main.song_for(r) != "w4":
		fail(res, "T04 plays " + String(main.song_for(r)))
	r.queue_free()
	Game.fresh()
	return report("w4assets", res.ok, res.info)
