extends RefCounted

## What every app's probe is made of: the walk that stands in for a person,
## run with `-- --probe`. An app's probe.gd extends this and writes only run(),
## its own claims about its own screens:
##
##     extends "res://addons/factory_testkit/walk.gd"
##
##     func run() -> void:
##         await begin()
##         claim("the title shows", shows("Checklist"))
##         await press(Items.ADDS)
##         ...
##         finish()
##
## It presses the way a person would where it can - a pressable's own press,
## a finger's touch and drag, a mouse click on a drawing - and reads what is
## on the screen, not what a model says, unless a claim is about the model.
## finish() prints PROBE OK, or PROBE FAILED and every claim that did not
## hold, and quits with that, as tooling/check_app.py expects.

## The app being walked: a ChimeApp.
var app: Node
var _said := {}


func _init(walked: Node) -> void:
	app = walked


## Wait for the app to stand, and stop its motion so every frame is settled.
func begin() -> void:
	await frames(4)
	app.ui.motion.still = true


func frames(count: int = 3) -> void:
	for frame: int in count:
		await app.get_tree().process_frame


## The last place on the driver's path: the screen, or the pop-up over it.
func top() -> StringName:
	var path: Array = app.driver.get_top()
	return path[-1] if not path.is_empty() else &""


## Every visible pressable for this action.
func pressables(action: StringName) -> Array:
	return app.find_children("*", "Control", true, false).filter(func(part: Node) -> bool:
		return part is GdChime.Pressable and part.action == action and (part as Control).is_visible_in_tree())


## The first visible pressable for this action, or null.
func pressable(action: StringName) -> Node:
	var found := pressables(action)
	return null if found.is_empty() else found[0]


## Press the first pressable for this action, as a person would, and let it settle.
## A missing one is a failed claim, not a crash.
func press(action: StringName) -> void:
	var part := pressable(action)
	claim("there is something to press for %s" % action, part != null)
	if part != null:
		part.pressed()
	await frames(4)


## Every visible line of words on the screen.
func labels() -> Array:
	return app.find_children("*", "Label", true, false).filter(func(label: Node) -> bool:
		return (label as Label).is_visible_in_tree()).map(func(label: Node) -> String: return (label as Label).text)


## Whether these exact words are on the screen.
func shows(words: String) -> bool:
	return labels().has(words)


## Whether any words on the screen contain these.
func shows_part(part: String) -> bool:
	return labels().any(func(text: String) -> bool: return text.contains(part))


## Every visible one-line field.
func fields() -> Array:
	return app.find_children("*", "LineEdit", true, false).filter(func(line: Node) -> bool: return (line as Control).is_visible_in_tree())


## Type into a one-line field, as the keyboard would.
func type_into(line: LineEdit, words: String) -> void:
	line.text = words
	line.text_changed.emit(words)


## Type into the first visible text area.
func type_into_area(words: String) -> void:
	for area: Node in app.find_children("*", "TextEdit", true, false):
		if (area as Control).is_visible_in_tree():
			(area as TextEdit).text = words
			(area as TextEdit).text_changed.emit()
			return
	claim("there is a text area to type into", false)


## A tap - a finger's emulated mouse, down and up - at a point in a control's own coordinates.
func tap(on: Control, local: Vector2) -> void:
	var at := window_point(on.get_global_transform() * local)
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await frames(1)
	await frames(2)


## The point of the largest square a control holds, centred, at this share of each side:
## where gd-chime's pinned drawings draw.
static func in_square(on: Control, share: Vector2) -> Vector2:
	var side := minf(on.size.x, on.size.y)
	return (on.size - Vector2(side, side)) / 2.0 + share * side


## A finger drawn from a control's right edge towards its left, most of its width: a swipe left.
func swipe_left(on: Control) -> void:
	var area := on.get_global_rect()
	var from := Vector2(area.end.x - 8.0, area.get_center().y)
	var to := Vector2(area.position.x + area.size.x * 0.2, from.y)
	_touch(from, true)
	await frames(1)
	var steps := 12
	var last := from
	for step: int in range(1, steps + 1):
		var at := from.lerp(to, float(step) / steps)
		var drag := InputEventScreenDrag.new()
		drag.position = window_point(at)
		drag.relative = at - last
		drag.index = 0
		Input.parse_input_event(drag)
		last = at
		await frames(1)
	_touch(to, false)
	await frames(4)


## A point on the app's canvas, as the window sees it.
func window_point(at: Vector2) -> Vector2:
	return app.get_global_rect().position + app.viewport.get_final_transform() * at


## Settings, walked from the screen that has the gear: it opens, the text
## size changes and the look is made again, haptics turn off and on, and
## Reset app data asks first - cancelled here, since a reset starts the app
## again (the settings service's own test deletes and restarts). Leaves the
## settings as found, back on the screen it started from.
func walk_settings() -> void:
	var from := top()
	var gear := pressable(&"opens_settings")
	claim("there is a gear for settings", gear != null)
	if gear == null:
		return
	var finger: int = app.canvas.theme.get_constant(&"least", &"Touch")
	claim("the gear is a finger's size each way", gear.size.x >= finger and gear.size.y >= finger)
	# A real tap in the middle, as a finger lands: a drawing laid over the gear once took these.
	await tap(gear, gear.size / 2.0)
	await frames(4)
	claim("a tap in the middle of the gear opens settings", top() == &"settings")
	claim("settings say what the app is", shows_part(str(ProjectSettings.get_setting("application/config/name"))) and shows("Latensea Productions"))
	var worn: Theme = app.canvas.theme
	app.commands.dispatch(&"settings", &"sizes_the_words", {"value": 80.0})
	await frames()
	claim("a text size is kept", app.settings.size.read() == 80)
	claim("and the look is made again", app.canvas.theme != worn)
	app.commands.dispatch(&"settings", &"sizes_the_words", {"value": 65.0})
	await press(&"turns_haptics")
	claim("haptics turn off", not app.settings.haptics.read() and shows("Off"))
	await press(&"turns_haptics")
	claim("and on again", app.settings.haptics.read() and shows("On"))
	await press(&"asks_to_reset")
	claim("Reset app data asks first", shows_part("can't be undone"))
	await press(&"closes_the_overlay")
	claim("and can be cancelled", top() == &"settings")
	await press(&"leaves_settings")
	claim("back leaves settings", top() == from)


## Record a claim. A claim that failed once stays failed.
func claim(what: String, held: bool) -> void:
	if _said.has(what) and not _said[what]:
		return
	_said[what] = held


## Every claim that did not hold, in the order first made.
func failures() -> Array:
	return _said.keys().filter(func(what: String) -> bool: return not _said[what])


## Report and quit: PROBE OK, or PROBE FAILED and each claim that did not hold.
func finish() -> void:
	var failed := failures()
	if failed.is_empty():
		print("PROBE OK")
	else:
		print("PROBE FAILED")
		for what: String in failed:
			print("NOT TRUE: %s" % what)
	app.get_tree().quit(0 if failed.is_empty() else 1)


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = window_point(at)
	touch.pressed = down
	touch.index = 0
	Input.parse_input_event(touch)
