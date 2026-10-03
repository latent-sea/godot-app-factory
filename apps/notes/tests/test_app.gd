extends "res://addons/factory_testkit/check.gd"

## Notes stood up headless: it builds and opens on its list.
## Prints PASS test_app.gd, or every claim that did not hold.

const App := preload("res://notes.gd")
## Its own notes file, so a test run never touches the notes of whoever runs it.
const SAVED := "user://test_app_notes.json"


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
	expect(app.driver.get_top() == [&"notes", &"list"], "it opens on its list: %s" % [app.driver.get_top()])
	root.remove_child(app)
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))
	finish()
