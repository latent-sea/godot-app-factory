extends SceneTree

## The prompts model on its own: add, open, rename and rewrite as typed,
## delete, an empty new prompt dropped when its editor closes, refusals, and
## what it saves and restores. Prints PASS test_prompts.gd, or every claim that did not hold.

const Prompts := preload("res://prompts.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var model := Prompts.new(chimes)
	root.add_child(model)

	_claim(model.prompts.read().is_empty(), "it starts with no prompts")
	_claim(model.would(Prompts.RENAMES, {"line": "x"}) != null, "nothing can be typed while no prompt is open")

	model.told(Prompts.ADDS, {})
	var first: int = model.editing.read()
	_claim(model.prompts.read().size() == 1 and model.find(first)["text"] == "", "a new prompt starts empty and open")
	model.told(Prompts.RENAMES, {"line": "Adviser"})
	model.told(Prompts.REWRITES, {"text": "Consider {question}."})
	_claim(model.find(first)["name"] == "Adviser" and model.find(first)["text"] == "Consider {question}.", "the name and text change as they are typed")
	model.drop_if_empty()
	_claim(model.prompts.read().size() == 1 and model.editing.read() == null, "closing a prompt with text keeps it, and closes it")

	model.told(Prompts.ADDS, {})
	var second: int = model.editing.read()
	_claim(second != first, "each prompt has its own id")
	model.drop_if_empty()
	_claim(model.find(second).is_empty() and model.prompts.read().size() == 1, "closing a new prompt left empty drops it")

	model.told(Prompts.ADDS, {})
	model.told(Prompts.REWRITES, {"text": "Summarise the cast\nin a line"})
	var third: int = model.editing.read()
	model.drop_if_empty()
	_claim(Prompts.name_of(model.find(third)) == "Summarise the cast", "a prompt with no name is known by its first line")
	_claim(Prompts.name_of({"name": "", "text": ""}) == "New prompt", "an empty one is a new prompt")

	model.told(Prompts.OPENS, {"id": first})
	_claim(model.editing.read() == first, "opening a prompt opens it for editing")
	_claim(model.would(Prompts.OPENS, {"id": 999}) != null, "opening a prompt that is gone is refused")

	model.told(Prompts.DELETES, {"id": third})
	_claim(model.find(third).is_empty() and model.prompts.read().size() == 1, "delete removes the prompt")
	_claim(model.would(Prompts.DELETES, {"id": third}) != null, "deleting it again is refused")
	model.told(Prompts.ADDS, {})
	_claim(model.editing.read() > third, "ids are never reused")

	# Saved: only prompts with text. Restored: the same, and new ids carry on.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.saved()))
	_claim(saved["prompts"].size() == 1, "an empty prompt is never saved")
	var back := Prompts.new(chimes)
	root.add_child(back)
	back.restore(saved)
	_claim(back.prompts.read() == [model.find(first)], "saved then restored gives the same prompts: %s" % [back.prompts.read()])
	back.told(Prompts.ADDS, {})
	_claim(back.editing.read() > first, "a restored model keeps handing out new ids")

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_prompts.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
