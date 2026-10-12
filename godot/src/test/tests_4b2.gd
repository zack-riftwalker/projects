extends RefCounted
class_name Tests4b2
# Unit tests of phase 4B-2 (THE NETWORK). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["rooms4b"]

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String):
	match name:
		"rooms4b": return await t_rooms4b()
	return report(name, false, "unknown test")

func checker() -> Dictionary:
	return {"ok": true, "info": ""}

func fail(res: Dictionary, label: String) -> void:
	res.ok = false
	res.info += " BAD:" + label

func frames(n := 2) -> void:
	for i in range(n):
		await main.get_tree().process_frame

func new_room(room_id: String) -> Room:
	var room := Room.new()
	main.world.add_child(room)
	room.load_room(room_id)
	room.build_nodes()
	return room

func new_manager() -> RoomManager:
	var m := RoomManager.new(main.world, null)
	main.add_child(m)
	m.start_game()
	return m

# every N room (22): loads, doors point back, the closed ones are closed, the end doors exist, D07:E is open
func t_rooms4b() -> bool:
	Game.persist = false
	Game.net_role = ""
	Game.fresh()
	Game.load_meta()
	var res := checker()
	var n := 0
	for id in Game.rooms_meta.rooms:
		if not String(id).begins_with("N"):
			continue
		n += 1
		var m: Dictionary = Game.rooms_meta.rooms[id]
		if Game.zone_of(id) != "net" or int(m.get("world", 0)) != 6:
			fail(res, "%s zone/world" % id)
		for d in m.doors:
			var to_room := String(d.to).get_slice(":", 0)
			if not Game.rooms_meta.rooms.has(to_room):
				continue
			var back := false
			for td in Game.rooms_meta.rooms[to_room].doors:
				if td.id == d.to and td.to == d.id:
					back = true
			if not back:
				fail(res, "%s does not point back" % d.id)
		var r := new_room(id)
		await frames(1)
		r.queue_free()
	if n != 22:
		fail(res, "%d N rooms" % n)
	var n01 := new_room("N01")
	var d1 = n01.grid.door_at("N", int(Game.rooms_meta.rooms.N01.doors.filter(func(d): return d.id == "N01:N")[0].a))
	if d1 == null or d1.open:
		fail(res, "N01:N is not closed")
	n01.queue_free()
	var h11 := new_room("H11")
	var dh = h11.grid.door_at("N", 192)
	if dh == null or dh.open:
		fail(res, "H11:N2 is not closed")
	h11.queue_free()
	for rid in ["N11", "N17"]:
		var rr := new_room(rid)
		if rr.end_door == null or String(rr.def.get("end", "")) == "":
			fail(res, "%s has no end door" % rid)
		rr.queue_free()
	var d07 := new_room("D07")
	var de = d07.grid.door_at("E", 10)
	if de == null or not de.open:
		fail(res, "D07:E is not open")
	d07.queue_free()
	Game.fresh()
	return report("rooms4b", res.ok, res.info)
