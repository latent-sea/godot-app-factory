extends "res://addons/factory_testkit/check.gd"

## The prompts model on its own: add, open, rename and rewrite as typed,
## delete, an empty new prompt dropped when its editor closes, refusals, and
## what it saves and restores. Prints PASS test_prompts.gd, or every claim that did not hold.

const Prompts := preload("res://prompts.gd")


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var model := Prompts.new(chimes)
	root.add_child(model)

	expect(model.prompts.read().is_empty(), "it starts with no prompts")
	expect(model.would(Prompts.RENAMES, {"line": "x"}) != null, "nothing can be typed while no prompt is open")

	model.told(Prompts.ADDS, {})
	var first: int = model.editing.read()
	expect(model.prompts.read().size() == 1 and model.find(first)["text"] == "", "a new prompt starts empty and open")
	model.told(Prompts.RENAMES, {"line": "Adviser"})
	model.told(Prompts.REWRITES, {"text": "Consider {question}."})
	expect(model.find(first)["name"] == "Adviser" and model.find(first)["text"] == "Consider {question}.", "the name and text change as they are typed")
	model.drop_if_empty()
	expect(model.prompts.read().size() == 1 and model.editing.read() == null, "closing a prompt with text keeps it, and closes it")

	model.told(Prompts.ADDS, {})
	var second: int = model.editing.read()
	expect(second != first, "each prompt has its own id")
	model.drop_if_empty()
	expect(model.find(second).is_empty() and model.prompts.read().size() == 1, "closing a new prompt left empty drops it")

	model.told(Prompts.ADDS, {})
	model.told(Prompts.REWRITES, {"text": "Summarise the cast\nin a line"})
	var third: int = model.editing.read()
	model.drop_if_empty()
	expect(Prompts.name_of(model.find(third)) == "Summarise the cast", "a prompt with no name is known by its first line")
	expect(Prompts.name_of({"name": "", "text": ""}) == "New prompt", "an empty one is a new prompt")

	model.told(Prompts.OPENS, {"id": first})
	expect(model.editing.read() == first, "opening a prompt opens it for editing")
	expect(model.would(Prompts.OPENS, {"id": 999}) != null, "opening a prompt that is gone is refused")

	model.told(Prompts.DELETES, {"id": third})
	expect(model.find(third).is_empty() and model.prompts.read().size() == 1, "delete removes the prompt")
	expect(model.would(Prompts.DELETES, {"id": third}) != null, "deleting it again is refused")
	model.told(Prompts.ADDS, {})
	expect(model.editing.read() > third, "ids are never reused")

	# Saved: only prompts with text. Restored: the same, and new ids carry on.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.saved()))
	expect(saved["prompts"].size() == 1, "an empty prompt is never saved")
	var back := Prompts.new(chimes)
	root.add_child(back)
	back.restore(saved)
	expect(back.prompts.read() == [model.find(first)], "saved then restored gives the same prompts: %s" % [back.prompts.read()])
	back.told(Prompts.ADDS, {})
	expect(back.editing.read() > first, "a restored model keeps handing out new ids")

	finish()
