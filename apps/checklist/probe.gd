extends "res://addons/factory_testkit/walk.gd"

## The Checklist walked as a person would: typing, tapping rows, a real
## finger swipe, clearing. The walking itself is the factory's testkit.

const Items := preload("res://items.gd")


func run() -> void:
	await begin()

	await walk_settings()
	var line: LineEdit = fields()[0]
	claim("starts empty", shows("0 of 0 done") and _rows().is_empty())

	line.text_submitted.emit("")
	await frames()
	claim("an empty line is refused with a reason", shows("Type something to add") and _rows().is_empty())

	var clear: Node = pressables(Items.CLEARS)[0]
	claim("Clear done is unusable while nothing is ticked", not clear.is_usable())
	clear.pressed()
	await frames()
	claim("and pressing it says nothing: no reason is shown", not shows("Nothing is ticked yet"))

	for words: String in ["Buy tape", "Call the landlord", "Book the van"]:
		line.text = words
		line.text_submitted.emit(words)
		await frames()
	claim("three items added, in order", _row_words() == ["Buy tape", "Call the landlord", "Book the van"])
	claim("the line clears after adding", line.text == "")
	claim("the count follows", shows("0 of 3 done"))

	_rows()[2].pressed()
	await frames()
	claim("tapping a row ticks it", shows("1 of 3 done"))
	claim("Clear done is usable once something is ticked", clear.is_usable())

	_rows()[2].pressed()
	await frames()
	claim("tapping again unticks it", shows("0 of 3 done"))
	claim("and unusable again once nothing is", not clear.is_usable())

	_rows()[0].pressed()
	await frames()
	await swipe_left(_rows()[1])
	claim("swiping left deletes that row", _row_words() == ["Buy tape", "Book the van"])

	clear.pressed()
	await frames()
	claim("clear done removes only ticked items", _row_words() == ["Book the van"] and shows("0 of 1 done"))

	await frames(2)
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(app.saving.get_file_path()))
	var saved_words: Array = [] if kept == null else kept.get("checklist", {}).get("items", []).map(func(one: Dictionary) -> String: return one["words"])
	claim("the list is saved as it changes", saved_words == ["Book the van"])

	finish()


func _rows() -> Array:
	return pressables(Items.TOGGLES)


func _row_words() -> Array:
	return app.list.items.read().map(func(one: Dictionary) -> String: return one["words"])
