extends SceneTree

## opening.gd and splash.gd: the loading screen is up at once, the app loads
## under it, then the screen fades away; a probe gets the app with no loading
## screen; and the name lands where Godot's boot splash put it.
## Prints PASS test_splash.gd, or every claim that did not hold.

const Opening := preload("res://addons/factory_look/opening.gd")
const Splash := preload("res://addons/factory_look/splash.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	_claim(Splash.fit(Vector2(1080, 1080), Vector2(1080, 2400)) == Rect2(0, 660, 1080, 1080), "on a tall phone the name fills the width, centred as Godot's Keep does")
	_claim(Splash.fit(Vector2(1080, 1080), Vector2(1920, 1080)) == Rect2(420, 0, 1080, 1080), "on a wide screen it fills the height")

	root.size = Vector2i(720, 1280)
	var opening := Opening.new()
	opening.probing = false
	root.add_child(opening)
	await process_frame
	_claim(opening.cover != null and opening.cover.get_parent() == opening, "the loading screen is up at once")
	_claim(opening.cover.find_children("*", "Label", true, false).is_empty(), "its words are an image, so a probe never reads them")
	var waited := 0
	while opening.app == null and waited < 600:
		await process_frame
		waited += 1
	_claim(opening.app is ChimeApp, "the app loads: %s" % [opening.app])
	_claim(opening.get_child(0) == opening.app and opening.get_child(-1) == opening.cover, "under the loading screen, which still shows")
	_claim(opening.get_node_or_null("Enliven") != null, "and livened (enliven.gd)")
	await create_timer(Opening.LEAST + Opening.FADE + 0.3).timeout
	_claim(not is_instance_valid(opening.cover), "then the loading screen fades away")
	_claim(opening.app.size == Vector2(root.size), "the app fills the screen: %s" % opening.app.size)
	root.remove_child(opening)
	opening.free()

	var probed := Opening.new()
	probed.probing = true
	root.add_child(probed)
	_claim(probed.cover == null and probed.app is ChimeApp and probed.find_children("*", "Control", false, false).size() == 1, "a probe gets the app at once, and no loading screen")
	for frame: int in 3:
		await process_frame
	root.remove_child(probed)
	probed.free()

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_splash.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
