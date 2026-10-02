extends SceneTree

## Notes stood up headless: it builds and opens on its list.
## Prints PASS test_app.gd, or every claim that did not hold.

const App := preload("res://notes.gd")
## Its own notes file, so a test run never touches the notes of whoever runs it.
const SAVED := "user://test_app_notes.json"

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	root.size = Vector2i(720, 1280)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))
	var app: App = App.new()
	app.saved_at = SAVED
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	for frame: int in 3:
		await process_frame
	_claim(app.driver.get_top() == [&"notes", &"list"], "it opens on its list: %s" % [app.driver.get_top()])
	root.remove_child(app)
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))
	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_app.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
