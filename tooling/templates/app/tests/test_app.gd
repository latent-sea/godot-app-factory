extends SceneTree

## {{title}} stood up headless: it builds and opens on its home screen.
## Prints PASS test_app.gd, or every claim that did not hold.

const App := preload("res://{{name}}.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	root.size = Vector2i(720, 1280)
	var app: App = App.new()
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	for frame: int in 3:
		await process_frame
	_claim(app.driver.get_top() == [&"{{name}}", &"home"], "it opens on its home screen: %s" % [app.driver.get_top()])
	root.remove_child(app)
	app.free()
	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_app.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
