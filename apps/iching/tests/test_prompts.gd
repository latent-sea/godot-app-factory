extends SceneTree

## The prompts model on its own: add, edit, delete, refusals, and what it
## saves and restores. Prints PASS test_prompts.gd, or every claim that did not hold.

const Prompts := preload("res://prompts.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var model := Prompts.new(chimes)
	root.add_child(model)

	_claim(model.prompts.read().is_empty(), "it starts with no prompts")
	_claim(model.would(Prompts.ADDS, {"name": "Empty", "text": "  "}) != null, "a prompt with no text is refused")

	model.told(Prompts.ADDS, {"name": " Advisor ", "text": " Think about {question}. \n"})
	model.told(Prompts.ADDS, {"name": "", "text": "A prompt with no name given\nand a second line"})
	var list: Array = model.prompts.read()
	_claim(list.size() == 2, "two prompts added")
	_claim(list[0]["name"] == "Advisor" and list[0]["text"] == "Think about {question}.", "names and text are trimmed: %s" % [list[0]])
	_claim(list[1]["name"] == "A prompt with no name given", "a prompt with no name is named by its first line: %s" % list[1]["name"])
	_claim(list[0]["id"] != list[1]["id"], "each prompt has its own id")

	var first: int = list[0]["id"]
	model.told(Prompts.SAVES, {"id": first, "name": "Adviser", "text": "Consider {question} and {context}."})
	_claim(model.find(first)["name"] == "Adviser" and model.find(first)["text"] == "Consider {question} and {context}.", "editing saves the new name and text")
	_claim(model.would(Prompts.SAVES, {"id": 999, "text": "x"}) != null, "editing a prompt that is gone is refused")
	_claim(model.find(999).is_empty(), "finding a prompt that is gone finds nothing")

	var second: int = list[1]["id"]
	model.told(Prompts.DELETES, {"id": second})
	_claim(model.prompts.read().size() == 1 and model.find(second).is_empty(), "delete removes the prompt")
	model.told(Prompts.ADDS, {"name": "New", "text": "New one"})
	_claim(model.prompts.read()[1]["id"] > second, "ids are never reused")

	var back := Prompts.new(chimes)
	root.add_child(back)
	back.restore(JSON.parse_string(JSON.stringify(model.saved())))
	_claim(back.prompts.read() == model.prompts.read(), "saved then restored gives the same prompts")
	back.told(Prompts.ADDS, {"name": "After", "text": "After restore"})
	_claim(back.prompts.read()[-1]["id"] > back.prompts.read()[-2]["id"], "a restored model keeps handing out new ids")

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_prompts.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
