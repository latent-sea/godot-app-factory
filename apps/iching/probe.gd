extends RefCounted

## The walk that stands in for a person: run with `-- --probe`, it checks the
## screen and prints PROBE OK, or PROBE FAILED and each claim that did not
## hold, then quits with that. Add a claim for everything the app does.

var _app: Node
var _said := {}


func _init(app: Node) -> void:
	_app = app


func run() -> void:
	await _frames(4)
	_app.ui.motion.still = true
	_claim("the home screen is open", _app.driver.get_top() == [&"iching", &"home"])
	_claim("the title shows", _shows("I Ching"))
	_finish()


func _frames(count: int = 3) -> void:
	for frame: int in count:
		await _app.get_tree().process_frame


func _shows(said: String) -> bool:
	return _app.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).is_visible_in_tree() and (label as Label).text == said)


func _claim(what: String, held: bool) -> void:
	_said[what] = held


func _finish() -> void:
	var failed: Array = _said.keys().filter(func(what: String) -> bool: return not _said[what])
	if failed.is_empty():
		print("PROBE OK")
	else:
		print("PROBE FAILED")
		for what: String in failed:
			print("NOT TRUE: %s" % what)
	_app.get_tree().quit(0 if failed.is_empty() else 1)
