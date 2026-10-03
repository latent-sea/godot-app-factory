extends SceneTree

## What every test is made of: expectations, then one line saying how it
## went. A test extends this, makes its expectations, then finishes:
##
##     extends "res://addons/factory_testkit/check.gd"
##
##     func _init() -> void:
##         await process_frame
##         expect(Items.new(chimes).items.read().is_empty(), "a new list is empty")
##         finish()
##
## finish() prints PASS and the test's file name, or NOT TRUE and every
## expectation that did not hold, and quits with that, as
## tooling/check_app.py expects. (A probe's claims are walk.gd's.)

var _failed: Array[String] = []


## Records `what` as not true unless it held.
func expect(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)


func finish() -> void:
	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS %s" % (get_script() as Script).resource_path.get_file())
	quit(0 if _failed.is_empty() else 1)
