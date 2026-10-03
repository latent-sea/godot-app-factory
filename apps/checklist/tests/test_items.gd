extends "res://addons/factory_testkit/check.gd"

## The checklist model on its own, with no screen: every action, every
## refusal, and what it saves and restores. (Refusing a save of the wrong
## shape is gd-chime's SaveShape, and reports itself as an error by design.) Prints PASS test_items.gd, or
## every claim that did not hold.

const Items := preload("res://items.gd")


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var list := Items.new(chimes)
	root.add_child(list)

	expect(list.would(Items.ADDS, {"line": "   "}) != null, "a blank line is refused")
	expect(str(list.would(Items.ADDS, {"line": ""})) == "Type something to add", "the refusal says why")
	expect(str(list.would(Items.CLEARS, {})) == "Nothing is ticked yet", "clearing with nothing ticked is refused")

	list.told(Items.ADDS, {"line": "  Buy tape  "})
	list.told(Items.ADDS, {"line": "Book the van"})
	var items: Array = list.items.read()
	expect(items.size() == 2 and items[0]["words"] == "Buy tape", "adding trims the words: %s" % [items])
	expect(items[0]["id"] != items[1]["id"], "each item gets its own id")
	expect(items.all(func(one: Dictionary) -> bool: return not one["done"]), "new items start unticked")

	var first: int = items[0]["id"]
	list.told(Items.TOGGLES, {"id": first})
	expect(list.items.read()[0]["done"] and list.done_count() == 1, "ticking marks it done")
	list.told(Items.TOGGLES, {"id": first})
	expect(not list.items.read()[0]["done"], "ticking again unticks it")

	expect(str(list.would(Items.TOGGLES, {"id": 999})) == "That item is gone", "an unknown id is refused")
	expect(list.would(Items.DELETES, {}) != null, "a delete with no id is refused")

	list.told(Items.TOGGLES, {"id": first})
	list.told(Items.CLEARS, {})
	expect(_words(list) == ["Book the van"], "clear done removes only ticked items: %s" % [_words(list)])

	var second: int = list.items.read()[0]["id"]
	list.told(Items.DELETES, {"id": second})
	expect(list.items.read().is_empty(), "delete removes the item")

	list.told(Items.ADDS, {"line": "After delete"})
	expect(list.items.read()[0]["id"] > second, "ids are never reused after a delete")

	# Round trip through what SettingsFile writes, including JSON's floats.
	list.told(Items.TOGGLES, {"id": list.items.read()[0]["id"]})
	var as_json: Dictionary = JSON.parse_string(JSON.stringify(list.saved()))
	var back := Items.new(chimes)
	root.add_child(back)
	back.restore(as_json)
	expect(back.items.read() == list.items.read(), "saved then restored gives the same items: %s" % [back.items.read()])
	expect(typeof(back.items.read()[0]["id"]) == TYPE_INT, "restored ids are whole numbers again")
	back.told(Items.ADDS, {"line": "Next"})
	expect(back.items.read()[1]["id"] > back.items.read()[0]["id"], "a restored list keeps handing out new ids")

	finish()


func _words(list: Items) -> Array:
	return list.items.read().map(func(one: Dictionary) -> String: return one["words"])
