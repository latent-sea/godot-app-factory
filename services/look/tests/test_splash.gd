extends SceneTree

## splash.gd: it covers the app, takes taps while it shows, draws no Label
## a probe could read, goes by itself, comes only once, and never comes to a
## probe. Prints PASS test_splash.gd, or every claim that did not hold.

const Look := preload("res://addons/factory_look/look.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	var app := Node.new()
	root.add_child(app)
	var layer := Look.Splash.over(app, Look.PALETTE, Look.weighted(Look.TITLE_WEIGHT), Look.weighted(Look.WEIGHT), 0.2, false)
	_claim(layer != null and layer.get_parent() == app and layer.layer > 1, "it is put over the app, above it")
	var shown := layer.get_child(0) as Control
	for frame: int in 3:
		await process_frame
	_claim(shown.size == Vector2(root.size), "it covers the whole screen: %s" % shown.size)
	_claim(shown.mouse_filter == Control.MOUSE_FILTER_STOP, "while it shows, a tap lands on it")
	_claim(layer.find_children("*", "Label", true, false).is_empty(), "its words are drawn, so a probe never reads them")
	_claim(Look.Splash.over(app, Look.PALETTE, Look.weighted(Look.WEIGHT), Look.weighted(Look.WEIGHT), 0.2, false) == null, "it comes only once")
	await create_timer(0.2 + Look.Splash.FADE + 0.3).timeout
	_claim(not is_instance_valid(layer), "it goes by itself, once held and faded")

	var probed := Node.new()
	root.add_child(probed)
	_claim(Look.Splash.over(probed, Look.PALETTE, Look.weighted(Look.WEIGHT), Look.weighted(Look.WEIGHT), 0.2, true) == null and probed.get_child_count() == 0, "a probe gets no splash")
	app.free()
	probed.free()

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_splash.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
