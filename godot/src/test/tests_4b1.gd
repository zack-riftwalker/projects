extends RefCounted
class_name Tests4b1
# Unit tests of phase 4B-1 (the map, the cartographer and the small systems). run_tests.gd hands names it does not know to run().

var main

const NAMES := ["worlddigest"]

func _init(m) -> void:
	main = m

func report(name: String, ok: bool, info: String) -> bool:
	print("TEST %s %s %s" % [name, "PASS" if ok else "FAIL", info])
	return ok

func run(name: String) -> bool:
	match name:
		"worlddigest": return t_worlddigest()
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
