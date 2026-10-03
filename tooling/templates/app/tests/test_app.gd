extends "res://addons/factory_testkit/check.gd"

## {{title}} stood up headless: it builds and opens on its home screen.
## Prints PASS test_app.gd, or every claim that did not hold.

const App := preload("res://{{name}}.gd")


func _init() -> void:
	await process_frame
	root.size = Vector2i(720, 1280)
	var app: App = App.new()
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	for frame: int in 3:
		await process_frame
	expect(app.driver.get_top() == [&"{{name}}", &"home"], "it opens on its home screen: %s" % [app.driver.get_top()])
	root.remove_child(app)
	app.free()
	finish()
