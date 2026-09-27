extends RefCounted

## The walk that stands in for a person: run with `-- --probe`, it casts by
## tapping the square, reads the result, copies with and without a prompt,
## writes and edits a prompt, and goes back; then prints PROBE OK, or PROBE
## FAILED and each claim that did not hold, and quits with that.
##
## It saves to its own file (iching.gd's PROBED_AT), never to real prompts.

const H := preload("res://hexagrams.gd")
const Cast := preload("res://cast.gd")
const PromptList := preload("res://prompts.gd")
const Copying := preload("res://copying.gd")

var _app: Node
var _said := {}


func _init(app: Node) -> void:
	_app = app


func run() -> void:
	await _frames(6)
	_app.ui.motion.still = true
	_app.cast.seed_with(7)
	_claim("it opens on the cast screen", _top() == &"cast")
	_claim("the first tap is line 1", _shows("Tap the square: line 1 of 6"))

	# The question stays as typed.
	_typed(_fields()[0], "Should I move?")
	await _frames()
	_claim("the question is kept as typed", _app.cast.question.read() == "Should I move?" and _fields()[0].text == "Should I move?")

	# Six real taps on the square, each in a different cell.
	var square := _square()
	for tap: int in 6:
		await _tap(square, Vector2(0.1 + tap * 0.15, 0.2 + tap * 0.1))
		if tap == 2:
			_claim("three taps give three lines", _app.cast.lines.read().size() == 3 and _shows("Tap the square: line 4 of 6"))
	var lines: Array = _app.cast.lines.read()
	_claim("six taps give six lines, each 6-9", lines.size() == 6 and lines.all(func(line: int) -> bool: return line >= 6 and line <= 9))
	_claim("the sixth tap opens the result", _top() == &"result")
	var sentence := H.sentence(lines)
	_claim("the result says the cast in one sentence", _shows(sentence))
	_claim("the result shows the question", _shows("Should I move?"))
	_claim("the first hexagram is numbered", _shows("Hexagram %d" % H.number(H.first(lines))))

	# Copy with no prompt: the question, then the cast.
	await _open_copy()
	_claim("the copy drawer offers no prompt, chosen", _app.copying.picked.read() == Copying.NO_PROMPT and _shows("No prompt"))
	await _press(Copying.COPIES)
	_claim("copying with no prompt gives the question then the cast", _app.copying.last_copied == "Should I move?\n\n" + sentence)
	_claim("the result then says it was copied", _shows("Copied"))
	_claim("and the drawer has closed", _top() == &"result")

	# Write a prompt with two placeholders.
	_app.commands.dispatch(&"global", GdChime.Driver.GO, {"place": &"prompts"})
	await _frames()
	_claim("prompts start empty", _app.prompt_list.prompts.read().is_empty() and _shows_part("No prompts yet"))
	await _press(PromptList.ADDS)
	_claim("a new prompt opens its editor", _top() == &"edit_prompt")
	_typed(_fields()[0], "Adviser")
	_typed_area("As an adviser: {question}\nMy situation: {situation}")
	await _frames()
	var written: Dictionary = _app.prompt_list.prompts.read()[0]
	_claim("the name and text are kept as typed", written["name"] == "Adviser" and written["text"] == "As an adviser: {question}\nMy situation: {situation}")
	await _press_link(&"goes_back")
	_claim("back from the editor returns to the list", _top() == &"prompts")
	_claim("the list shows the prompt by name", _shows("Adviser"))

	# An empty new prompt is dropped when its editor closes.
	await _press(PromptList.ADDS)
	await _press_link(&"goes_back")
	_claim("an empty new prompt is dropped", _app.prompt_list.prompts.read().size() == 1)

	# Edit the saved one: its editor opens holding what was written.
	await _press(PromptList.OPENS)
	_claim("tapping a prompt opens it", _top() == &"edit_prompt")
	_claim("the editor holds its name", _fields()[0].text == "Adviser")
	await _press_link(&"goes_back")
	await _press_link(&"goes_back")
	_claim("back from the list returns to the result", _top() == &"result")

	# Copy with the prompt: Copy waits for every placeholder.
	await _open_copy()
	_app.commands.dispatch(&"global", Copying.PICKS, {"value": written["id"]})
	await _frames()
	_claim("the prompt's placeholders are offered", _app.copying.blanks.read() == ["question", "situation"])
	_claim("{question} arrives filled", str(_app.copying.filled.read().get("question", "")) == "Should I move?")
	_claim("Copy is faded while a placeholder is empty", not _pressable(Copying.COPIES).is_usable())
	_app.commands.dispatch(&"global", Copying.FILLS, {"name": "situation", "line": "A job offer abroad"})
	await _frames()
	_claim("Copy is usable once every placeholder is filled", _pressable(Copying.COPIES).is_usable())
	await _press(Copying.COPIES)
	_claim("the prompt places the question, and it isn't repeated", _app.copying.last_copied == "As an adviser: Should I move?\nMy situation: A job offer abroad\n\n" + sentence)

	# Cast again: a fresh cast, and Back doesn't return to the old result.
	await _press(Cast.CASTS_AGAIN)
	_claim("cast again opens a fresh cast", _top() == &"cast" and _app.cast.lines.read().is_empty() and _app.cast.question.read() == "")
	_claim("the question box is empty again", _fields()[0].text == "")
	_claim("and the prompt is still saved", _app.prompt_list.prompts.read().size() == 1)
	_finish()


func _top() -> StringName:
	var path: Array = _app.driver.get_top()
	return path[-1] if not path.is_empty() else &""


func _open_copy() -> void:
	await _press(&"opens_the_copy_drawer")
	await _frames(4)


## A tap at a point of the square's unit square, as a finger's emulated mouse.
func _tap(square: Control, at: Vector2) -> void:
	var side := minf(square.size.x, square.size.y)
	var corner := (square.size - Vector2(side, side)) / 2.0
	var local := corner + at * side
	var window: Vector2 = _app.get_global_rect().position + _app.viewport.get_final_transform() * (square.get_global_transform() * local)
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = window
		click.global_position = window
		Input.parse_input_event(click)
		await _frames(1)
	await _frames(2)


func _square() -> Control:
	for part: Node in _app.find_children("*", "Control", true, false):
		if part.get_script() != null and part.theme_type_variation == &"CastSquare" and (part as Control).is_visible_in_tree():
			return part
	return null


func _typed(line: LineEdit, words: String) -> void:
	line.text = words
	line.text_changed.emit(words)


func _typed_area(words: String) -> void:
	for area: Node in _app.find_children("*", "TextEdit", true, false):
		if (area as Control).is_visible_in_tree():
			(area as TextEdit).text = words
			(area as TextEdit).text_changed.emit()
			return


func _fields() -> Array:
	return _app.find_children("*", "LineEdit", true, false).filter(func(line: Node) -> bool: return (line as Control).is_visible_in_tree())


func _pressable(action: StringName) -> Node:
	for part: Node in _app.find_children("*", "Control", true, false):
		if part is GdChime.Pressable and part.action == action and (part as Control).is_visible_in_tree():
			return part
	return null


func _press(action: StringName) -> void:
	var part := _pressable(action)
	if part == null:
		_claim("there is something to press for %s" % action, false)
		return
	part.pressed()
	await _frames(4)


func _press_link(action: StringName) -> void:
	var part := _pressable(action)
	_claim("%s can be pressed" % action, part != null and part.is_usable())
	if part != null:
		part.pressed()
	await _frames(4)


func _frames(count: int = 3) -> void:
	for frame: int in count:
		await _app.get_tree().process_frame


func _labels() -> Array:
	return _app.find_children("*", "Label", true, false).filter(func(label: Node) -> bool: return (label as Label).is_visible_in_tree()).map(func(label: Node) -> String: return (label as Label).text)


func _shows(said: String) -> bool:
	return _labels().has(said)


func _shows_part(part: String) -> bool:
	return _labels().any(func(text: String) -> bool: return text.contains(part))


func _claim(what: String, held: bool) -> void:
	if _said.has(what) and not _said[what]:
		return
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
