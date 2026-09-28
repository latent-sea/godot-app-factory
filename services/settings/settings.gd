extends GdChime.Controller

## Settings every app has, reached by the gear in its first screen's title:
## how big the words are, whether a tap buzzes, wiping the app's data, and
## what the app is.
##
##     const Settings := preload("res://addons/factory_settings/settings.gd")
##
##     func declare(register: GdChime.Actions) -> void:
##         Settings.declare(register)
##         ...
##
##     func describe() -> GdChime.Desc:
##         saving = model(GdChime.SettingsFile.new(chimes, Basics.save_file("notes", saved_at)))
##         settings = Settings.install(self, [saving])
##         ...the gear in the first screen's title row: Settings.gear(ui)
##         return ui.app(&"notes", [ui.stack([list, editor, settings.screen(ui)])])
##
## TEXT SIZE is a share of gd-chime's monitor sizes, 50 to 100 per cent,
## 65 at first (about Android's own 14-16 dp). The look reads it as it is
## made (look/phone.gd), so a change makes the look again and puts it on the
## canvas: every screen changes size at once.
##
## THESE ARE KEPT APART FROM THE APP'S DATA, in user://factory_settings.json,
## so wiping the data keeps them. Wiping deletes each data file the app
## handed in and starts the app again from its opening scene.
##
## Needs the look and basics services.

const Phone := preload("res://addons/factory_look/phone.gd")
const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")

const PLACE := &"settings"
const SIZES := &"sizes_the_words"
const TURNS_HAPTICS := &"turns_haptics"
const RESETS := &"resets_the_data"
## Presses that only go somewhere: no model handles them.
const OPENS := &"opens_settings"
const LEAVES := &"leaves_settings"
const ASKS_RESET := &"asks_to_reset"
## The bell every face rings as a hand presses it (gd-chime's interaction.gd).
const PRESSED := &"pressed"
## How long a tap's buzz is, in milliseconds.
const BUZZ := 12
const LEAST_SIZE := 50
const MOST_SIZE := 100
const GEAR := FactoryLook.GEAR

## How big the words are, in per cent of gd-chime's monitor sizes.
var size := value(roundi(Phone.DEFAULT_SIZE * 100))
var haptics := value(true)
## How many buzzes a tap has asked for, for a test with no motor to feel.
var buzzes := 0
## What starts the app again after its data is wiped; a probe replaces it.
var restart: Callable
var _app: Node
var _data: Array


func _init(chimes: GdChime.Chimes, app: Node = null, data: Array = []) -> void:
	super(chimes)
	_app = app
	_data = data
	restart = func() -> void: _app.get_tree().reload_current_scene.call_deferred()
	listen([[GdChime.Chimes.GLOBAL, PRESSED]])


## The words for the settings' actions; call from the app's declare().
static func declare(register: GdChime.Actions) -> void:
	register.declare_all({
		SIZES: ["Text size"],
		TURNS_HAPTICS: ["Haptics"],
		RESETS: ["Delete"],
		OPENS: ["Settings"],
		LEAVES: ["‹ Back"],
		ASKS_RESET: ["Reset app data"],
	})


## The settings, made, kept in their own file and in the tree, handed the
## app's data files to wipe on a reset.
static func install(app: Node, data: Array) -> Object:
	var made: Object = app.model((load("res://addons/factory_settings/settings.gd") as GDScript).new(app.chimes, app, data))
	var saving: GdChime.SettingsFile = app.model(GdChime.SettingsFile.new(app.chimes, Basics.save_file("factory_settings")))
	saving.keep(Phone.SECTION, made)
	return made


func answers() -> Array[StringName]:
	return [SIZES, TURNS_HAPTICS, RESETS]


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		SIZES:
			size.set_value(clampi(roundi(payload["value"]), LEAST_SIZE, MOST_SIZE))
			_sized()
		TURNS_HAPTICS:
			haptics.set_value(bool(payload["on"]))
		RESETS:
			for kept: GdChime.SettingsFile in _data:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(kept.get_file_path()))
			restart.call()
	return null


## A tap anywhere: a short buzz, if haptics are on.
func heard(what: StringName) -> void:
	if what == PRESSED and haptics.read():
		buzzes += 1
		Input.vibrate_handheld(BUZZ)


## The size chosen, told to the look, and the look made again.
func _sized() -> void:
	Phone.chosen_size = size.read() / 100.0
	if _app != null and _app.get(&"canvas") != null:
		_app.canvas.theme = _app.look()


func saved() -> Dictionary:
	return {"text_size": size.read() / 100.0, "haptics": haptics.read()}


func restore(save: Dictionary) -> void:
	var shape := GdChime.SaveShape as GDScript
	if shape.refused(shape.record({"text_size": shape.number(), "haptics": shape.one_of([true, false])}), save, "the settings"):
		return
	size.set_value(clampi(roundi(float(save["text_size"]) * 100), LEAST_SIZE, MOST_SIZE))
	haptics.set_value(save["haptics"])
	Phone.chosen_size = size.read() / 100.0


## The gear that opens the settings, for the first screen's title row.
static func gear(ui: RefCounted) -> GdChime.Desc:
	return ui.pressable(OPENS, {}, [ui.canvas(_paint_gear, null, GEAR)], FactoryLook.LINK).goes_to(PLACE)


## The settings screen, for the app's stack.
func screen(ui: RefCounted) -> GdChime.Desc:
	var name := str(ProjectSettings.get_setting("application/config/name", ""))
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var reset: GdChime.Desc = GdChime.Confirm.make(ui, GdChime.Phrase.of("Delete everything saved in %s? This can't be undone." % name), RESETS)
	var content: GdChime.Desc = ui.column([
		ui.row([FactoryLook.link(ui, LEAVES).goes_to(GdChime.Driver.BACK)]),
		ui.text(GdChime.Phrase.of("Settings"), GdChime.Themes.TITLE),
		ui.text(GdChime.Phrase.of("Text size"), GdChime.Themes.FACE),
		ui.slider(SIZES, size, {"minimum": LEAST_SIZE, "maximum": MOST_SIZE, "step": 5}),
		GdChime.Setting.row(ui, GdChime.Phrase.of("Haptics"), GdChime.Phrase.of("A small buzz on each tap"), GdChime.Setting.toggle(ui, TURNS_HAPTICS, haptics)),
		ui.row([FactoryLook.link(ui, ASKS_RESET).opens(reset)]),
		ui.column([]).grow(),
		ui.text(GdChime.Phrase.of("%s %s" % [name, version]), FactoryLook.QUIET),
		ui.text(GdChime.Phrase.of("Latensea Productions"), FactoryLook.QUIET),
	])
	return ui.screen(PLACE, [FactoryLook.page(ui, [content])], self)


## A gear: a ring of teeth round a hole, in the words' colour.
static func _paint_gear(on: Control, _nothing: Variant) -> void:
	var side := minf(on.size.x, on.size.y)
	var centre := on.size / 2.0
	var outer := side * 0.46
	var inner := side * 0.34
	var teeth := 8
	var points := PackedVector2Array()
	for step: int in teeth * 4:
		var angle := TAU * step / (teeth * 4.0)
		var radius := outer if step % 4 < 2 else inner
		points.append(centre + Vector2.from_angle(angle) * radius)
	var ink := on.get_theme_color(&"font_color", GEAR)
	on.draw_colored_polygon(points, ink)
	on.draw_circle(centre, side * 0.14, on.get_theme_color(&"hole", GEAR))
