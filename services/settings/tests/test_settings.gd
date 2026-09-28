extends SceneTree

## settings.gd: text size is kept in bounds and told to the look, which is
## made again; haptics buzz on a press only while on; a reset deletes the
## app's data files, keeps the settings, and starts the app again; and what
## is saved comes back. Prints PASS test_settings.gd, or every claim that did not hold.

const Settings := preload("res://addons/factory_settings/settings.gd")
const Phone := preload("res://addons/factory_look/phone.gd")

var _failed: Array[String] = []


## Hangs the press bell gd-chime's sounds hang in an app, so the settings can hear it.
class Hand extends GdChime.Controller:
	func _init(chimes: GdChime.Chimes) -> void:
		super(chimes, [], GdChime.Chimes.GLOBAL)
		register_bell(Settings.PRESSED)

	func press() -> void:
		strike(GdChime.Chimes.GLOBAL, Settings.PRESSED)


## Stands in for an app: a canvas, and a look that counts how often it was made.
class App extends Node:
	var canvas := Control.new()
	var looks := 0

	func look() -> Theme:
		looks += 1
		var theme := Theme.new()
		theme.default_font_size = roundi(100 * Phone.text_size())
		return theme


## Stands in for a data file: only its path is read.
class Kept extends GdChime.SettingsFile:
	pass


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var hand := Hand.new(chimes)
	root.add_child(hand)
	var app := App.new()
	root.add_child(app)
	var data_path := "user://settings_test_data.json"
	var kept := FileAccess.open(data_path, FileAccess.WRITE)
	kept.store_string("{}")
	kept.close()
	var data := GdChime.SettingsFile.new(chimes, data_path)
	root.add_child(data)
	var settings := Settings.new(chimes, app, [data])
	root.add_child(settings)
	var restarted := [0]
	settings.restart = func() -> void: restarted[0] += 1

	_claim(settings.size.read() == 65 and settings.haptics.read(), "text size starts at 65 per cent, haptics on")
	settings.told(Settings.SIZES, {"value": 80.0})
	_claim(settings.size.read() == 80 and is_equal_approx(Phone.chosen_size, 0.8), "a size chosen is told to the look")
	_claim(app.looks == 1 and app.canvas.theme.default_font_size == 80, "and the look is made again and worn")
	settings.told(Settings.SIZES, {"value": 20.0})
	_claim(settings.size.read() == Settings.LEAST_SIZE, "a size below the least is the least")
	settings.told(Settings.SIZES, {"value": 400.0})
	_claim(settings.size.read() == Settings.MOST_SIZE, "and above the most, the most")

	hand.press()
	await process_frame
	_claim(settings.buzzes == 1, "a press buzzes while haptics are on")
	settings.told(Settings.TURNS_HAPTICS, {"on": false})
	hand.press()
	await process_frame
	_claim(settings.buzzes == 1 and not settings.haptics.read(), "and not once they are off")

	settings.told(Settings.SIZES, {"value": 70.0})
	var saved: Dictionary = JSON.parse_string(JSON.stringify(settings.saved()))
	var back := Settings.new(chimes)
	root.add_child(back)
	Phone.chosen_size = -1.0
	back.restore(saved)
	_claim(back.size.read() == 70 and not back.haptics.read() and is_equal_approx(Phone.chosen_size, 0.7), "saved then restored: the same size and haptics, told to the look")

	settings.told(Settings.RESETS, {})
	_claim(not FileAccess.file_exists(data_path), "a reset deletes the app's data")
	_claim(restarted[0] == 1, "and starts the app again")

	# The look reads the chosen size from Settings' file before any model is made.
	var file := FileAccess.open(Phone.SETTINGS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({Phone.SECTION: {"text_size": 0.85, "haptics": true}}))
	file.close()
	Phone.chosen_size = -1.0
	_claim(is_equal_approx(Phone.text_size(), 0.85), "the look reads the size kept in Settings' file")
	file = FileAccess.open(Phone.SETTINGS_FILE, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	Phone.chosen_size = -1.0
	_claim(is_equal_approx(Phone.text_size(), Phone.DEFAULT_SIZE), "an unreadable file gives the first size")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Phone.SETTINGS_FILE))
	Phone.chosen_size = -1.0
	_claim(is_equal_approx(Phone.text_size(), Phone.DEFAULT_SIZE), "and so does no file")

	app.canvas.free()
	for node: Node in [hand, app, data, settings, back]:
		root.remove_child(node)
		node.free()
	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_settings.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
