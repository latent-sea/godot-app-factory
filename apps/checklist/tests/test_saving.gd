extends "res://addons/factory_testkit/check.gd"

## The whole app, stood up twice on one save file: what was added and ticked
## in the first run is there in the second. Prints PASS test_saving.gd, or
## every claim that did not hold. (A broken file starting empty is gd-chime's
## promise, tested in its own tests/test_settings_file.gd.)

const App := preload("res://checklist.gd")
const Items := preload("res://items.gd")
## A file of its own; the app's real save is never touched.
const FILE := "user://checklist_test.json"


func _init() -> void:
	await process_frame
	root.size = Vector2i(720, 1280)
	_forget()

	var first := await _open()
	first.commands.dispatch(App.LIST, Items.ADDS, {"line": "Milk"})
	first.commands.dispatch(App.LIST, Items.ADDS, {"line": "Eggs"})
	await _frames(2)
	first.commands.dispatch(App.LIST, Items.TOGGLES, {"id": first.list.items.read()[1]["id"]})
	await _frames(3)
	_close(first)

	var second := await _open()
	var items: Array = second.list.items.read()
	expect(items.map(func(one: Dictionary) -> String: return one["words"]) == ["Milk", "Eggs"], "items survive a restart: %s" % [items])
	expect(items.size() == 2 and not items[0]["done"] and items[1]["done"], "ticks survive a restart")
	expect(_shows(second, "1 of 2 done"), "the screen shows the restored count")
	_close(second)

	_forget()
	finish()


## The app as its scene would stand it up, saving to the test's own file.
func _open() -> App:
	var app: App = App.new()
	app.saved_at = FILE
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await _frames(3)
	return app


func _close(app: App) -> void:
	root.remove_child(app)
	app.free()


func _forget() -> void:
	for path: String in [FILE, FILE + ".writing", FILE + ".unreadable"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for frame: int in count:
		await process_frame


func _shows(app: Node, said: String) -> bool:
	return app.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).is_visible_in_tree() and (label as Label).text == said)
