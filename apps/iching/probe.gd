extends "res://addons/factory_testkit/walk.gd"

## The I Ching walked as a person would: casts by tapping the square, reads
## the result, copies with and without a prompt, writes and edits a prompt,
## and goes back. The walking itself is the factory's testkit.

const H := preload("res://hexagrams.gd")
const Cast := preload("res://cast.gd")
const PromptList := preload("res://prompts.gd")
const Copying := preload("res://copying.gd")
const Drawing := preload("res://drawing.gd")


func run() -> void:
	await begin()
	app.cast.seed_with(7)
	await walk_settings()
	claim("it opens on the cast screen", top() == &"cast")
	claim("the first tap is line 1", shows("Tap the square: line 1 of 6"))

	# The question stays as typed.
	type_into(fields()[0], "Should I move?")
	await frames()
	claim("the question is kept as typed", app.cast.question.read() == "Should I move?" and fields()[0].text == "Should I move?")

	# Six real taps on the square, each in a different cell.
	var square := _square()
	for tap: int in 6:
		await tap(square, in_square(square, Vector2(0.1 + tap * 0.15, 0.2 + tap * 0.1)))
		if tap == 2:
			claim("three taps give three lines", app.cast.lines.read().size() == 3 and shows("Tap the square: line 4 of 6"))
	var lines: Array = app.cast.lines.read()
	claim("six taps give six lines, each 6-9", lines.size() == 6 and lines.all(func(line: int) -> bool: return line >= 6 and line <= 9))
	claim("the sixth tap opens the result", top() == &"result")
	var sentence := H.sentence(lines)
	claim("the result says the cast in one sentence", shows(sentence))
	claim("the result shows the question", shows("Should I move?"))
	claim("the first hexagram is drawn, numbered", _hexagrams().size() >= 1 and Drawing.caption(lines) == "Hexagram %d" % H.number(H.first(lines)))
	claim("it fills its room: each hexagram at least a third of the screen's width", _hexagrams().all(func(part: Control) -> bool: return part.size.x >= app.get_viewport().get_visible_rect().size.x / 3.0))

	# Copy with no prompt: the question, then the cast.
	await _open_copy()
	claim("the copy drawer offers no prompt, chosen", app.copying.picked.read() == Copying.NO_PROMPT and shows("No prompt"))
	await press(Copying.COPIES)
	claim("copying with no prompt gives the question then the cast", app.copying.last_copied == "Should I move?\n\n" + sentence)
	claim("the result then says it was copied", shows("Copied"))
	claim("and the drawer has closed", top() == &"result")

	# Write a prompt with two placeholders.
	app.commands.dispatch(&"global", GdChime.Driver.GO, {"place": &"prompts"})
	await frames()
	claim("prompts start empty", app.prompt_list.prompts.read().is_empty() and shows_part("No prompts yet"))
	await press(PromptList.ADDS)
	claim("a new prompt opens its editor", top() == &"edit_prompt")
	type_into(fields()[0], "Adviser")
	type_into_area("As an adviser: {question}\nMy situation: {situation}")
	await frames()
	var written: Dictionary = app.prompt_list.prompts.read()[0]
	claim("the name and text are kept as typed", written["name"] == "Adviser" and written["text"] == "As an adviser: {question}\nMy situation: {situation}")
	await _press_link(&"goes_back")
	claim("back from the editor returns to the list", top() == &"prompts")
	claim("the list shows the prompt by name", shows("Adviser"))

	# An empty new prompt is dropped when its editor closes.
	await press(PromptList.ADDS)
	await _press_link(&"goes_back")
	claim("an empty new prompt is dropped", app.prompt_list.prompts.read().size() == 1)

	# Edit the saved one: its editor opens holding what was written.
	await press(PromptList.OPENS)
	claim("tapping a prompt opens it", top() == &"edit_prompt")
	claim("the editor holds its name", fields()[0].text == "Adviser")

	# A long prompt scrolls under a finger, and the swipe selects nothing.
	var kept: String = written["text"]
	var long := ""
	for line: int in 40:
		long += "Line %d of a long prompt about {question}.\n" % line
	type_into_area(long)
	await frames()
	var area := _area()
	await swipe_up(area)
	claim("a swipe up a long prompt scrolls it", area.scroll_vertical > 0.0)
	claim("and selects nothing", not area.has_selection())
	type_into_area(kept)
	await frames()
	await _press_link(&"goes_back")
	await _press_link(&"goes_back")
	claim("back from the list returns to the result", top() == &"result")

	# Copy with the prompt: Copy waits for every placeholder.
	await _open_copy()
	app.commands.dispatch(&"global", Copying.PICKS, {"value": written["id"]})
	await frames()
	claim("the prompt's placeholders are offered", app.copying.blanks.read() == ["question", "situation"])
	claim("{question} arrives filled", str(app.copying.filled.read().get("question", "")) == "Should I move?")
	claim("Copy is faded while a placeholder is empty", not pressable(Copying.COPIES).is_usable())
	app.commands.dispatch(&"global", Copying.FILLS, {"name": "situation", "line": "A job offer abroad"})
	await frames()
	claim("Copy is usable once every placeholder is filled", pressable(Copying.COPIES).is_usable())
	await press(Copying.COPIES)
	claim("the prompt places the question, and it isn't repeated", app.copying.last_copied == "As an adviser: Should I move?\nMy situation: A job offer abroad\n\n" + sentence)

	# Cast again: a fresh cast, and Back doesn't return to the old result.
	await press(Cast.CASTS_AGAIN)
	claim("cast again opens a fresh cast", top() == &"cast" and app.cast.lines.read().is_empty() and app.cast.question.read() == "")
	claim("the question box is empty again", fields()[0].text == "")
	claim("and the prompt is still saved", app.prompt_list.prompts.read().size() == 1)
	finish()


func _open_copy() -> void:
	await press(&"opens_the_copy_drawer")
	await frames(4)


## The prompt's text area, as the engine draws it.
func _area() -> TextEdit:
	for part: Node in app.find_children("*", "TextEdit", true, false):
		if (part as Control).is_visible_in_tree():
			return part
	return null


## The hexagrams drawn on the result.
func _hexagrams() -> Array:
	return app.find_children("*", "Control", true, false).filter(func(part: Node) -> bool:
		return part.get_script() != null and part.theme_type_variation == Drawing.HEXAGRAM and (part as Control).is_visible_in_tree())


func _square() -> Control:
	for part: Node in app.find_children("*", "Control", true, false):
		if part.get_script() != null and part.theme_type_variation == &"CastSquare" and (part as Control).is_visible_in_tree():
			return part
	return null


## A link that goes somewhere: it must be usable, then it is pressed.
func _press_link(action: StringName) -> void:
	var part := pressable(action)
	claim("%s can be pressed" % action, part != null and part.is_usable())
	if part != null:
		part.pressed()
	await frames(4)
