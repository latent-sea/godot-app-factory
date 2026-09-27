extends SceneTree

## basics.gd: where data is saved, and Android's Back. Runs inside any app
## that installs it. Prints PASS test_basics.gd, or every claim that did not hold.

const Basics := preload("res://addons/factory_basics/basics.gd")

var _failed: Array[String] = []


## Stands in for an app's commands: records what was dispatched, and refuses Back when told to.
class Door extends RefCounted:
	var sent: Array = []
	var nothing_behind := false

	func dispatch(region: StringName, action: StringName, payload: Dictionary) -> Variant:
		sent.append([region, action, payload])
		return GdChime.Phrase.of("Nowhere to go back to") if nothing_behind else null


func _init() -> void:
	await process_frame
	_claim(Basics.save_file("tally", "", false) == "user://tally.json", "an app saves to user://<name>.json")
	_claim(Basics.save_file("tally", "user://test.json", false) == "user://test.json", "a test may choose its own file")
	var kept := FileAccess.open("user://tally_probe.json", FileAccess.WRITE)
	kept.store_string("{}")
	kept.close()
	_claim(Basics.save_file("tally", "user://test.json", true) == "user://tally_probe.json", "a probe always saves to its own file")
	_claim(not FileAccess.file_exists("user://tally_probe.json"), "and starts it empty")

	var door := Door.new()
	var left := [false]
	var back := Basics.Back.new(door, func() -> void: left[0] = true)
	root.add_child(back)
	back.go_back()
	_claim(door.sent.size() == 1 and door.sent[0][1] == GdChime.Driver.GOES_BACK, "Back goes back through the app's commands")
	_claim(not left[0], "and stays in the app while there is somewhere to go back to")
	door.nothing_behind = true
	back.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_claim(door.sent.size() == 2, "the OS's Back request is heard")
	_claim(left[0], "with nothing behind, Back leaves the app")

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_basics.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
