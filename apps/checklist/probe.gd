extends RefCounted

## The walk that stands in for a person: run with `-- --probe`, it uses the
## real screen the way a finger and a keyboard would, and prints PROBE OK, or
## PROBE FAILED and every claim that did not hold, then quits with that.
##
## It saves to its own file (checklist.gd's PROBED_AT), never to real items.

const Items := preload("res://items.gd")

var _app: Node
var _said := {}


func _init(app: Node) -> void:
	_app = app


func run() -> void:
	await _frames(4)
	_app.ui.motion.still = true

	var line: LineEdit = _app.find_children("*", "LineEdit", true, false)[0]
	_claim("starts empty", _shows("0 of 0 done") and _rows().is_empty())

	line.text_submitted.emit("")
	await _frames()
	_claim("an empty line is refused with a reason", _shows("Type something to add") and _rows().is_empty())

	var clear: Node = _pressables(Items.CLEARS)[0]
	_claim("Clear done is unusable while nothing is ticked", not clear.is_usable())
	clear.pressed()
	await _frames()
	_claim("and pressing it says nothing: no reason is shown", not _shows("Nothing is ticked yet"))

	for words: String in ["Buy tape", "Call the landlord", "Book the van"]:
		line.text = words
		line.text_submitted.emit(words)
		await _frames()
	_claim("three items added, in order", _row_words() == ["Buy tape", "Call the landlord", "Book the van"])
	_claim("the line clears after adding", line.text == "")
	_claim("the count follows", _shows("0 of 3 done"))

	_rows()[2].pressed()
	await _frames()
	_claim("tapping a row ticks it", _shows("1 of 3 done"))
	_claim("Clear done is usable once something is ticked", clear.is_usable())

	_rows()[2].pressed()
	await _frames()
	_claim("tapping again unticks it", _shows("0 of 3 done"))
	_claim("and unusable again once nothing is", not clear.is_usable())

	_rows()[0].pressed()
	await _frames()
	await _swipe_left(_rows()[1])
	_claim("swiping left deletes that row", _row_words() == ["Buy tape", "Book the van"])

	clear.pressed()
	await _frames()
	_claim("clear done removes only ticked items", _row_words() == ["Book the van"] and _shows("0 of 1 done"))

	await _frames(2)
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(_app.saving.get_file_path()))
	var saved_words: Array = [] if kept == null else kept.get("checklist", {}).get("items", []).map(func(one: Dictionary) -> String: return one["words"])
	_claim("the list is saved as it changes", saved_words == ["Book the van"])

	_finish()


## A finger drawn from the row's right edge towards its left, most of its width.
func _swipe_left(row: Control) -> void:
	var area := row.get_global_rect()
	var y := area.get_center().y
	var from := Vector2(area.end.x - 8.0, y)
	var to := Vector2(area.position.x + area.size.x * 0.2, y)
	_touch(from, true)
	await _frames(1)
	var steps := 12
	var last := from
	for step: int in range(1, steps + 1):
		var at := from.lerp(to, float(step) / steps)
		var drag := InputEventScreenDrag.new()
		drag.position = _window_point(at)
		drag.relative = at - last
		drag.index = 0
		Input.parse_input_event(drag)
		last = at
		await _frames(1)
	_touch(to, false)
	await _frames(4)


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = _window_point(at)
	touch.pressed = down
	touch.index = 0
	Input.parse_input_event(touch)


## A point on the app's canvas, as the window sees it.
func _window_point(at: Vector2) -> Vector2:
	return _app.get_global_rect().position + _app.viewport.get_final_transform() * at


func _frames(count: int = 3) -> void:
	for frame: int in count:
		await _app.get_tree().process_frame


func _pressables(action: StringName) -> Array:
	return _app.find_children("*", "Control", true, false).filter(func(part: Node) -> bool: return part is GdChime.Pressable and part.action == action and part.is_visible_in_tree())


func _rows() -> Array:
	return _pressables(Items.TOGGLES)


func _row_words() -> Array:
	return _app.list.items.read().map(func(one: Dictionary) -> String: return one["words"])


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
