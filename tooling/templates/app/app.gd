extends ChimeApp

## {{title}}: one screen to build on. Made by tooling/create_app.py.
##
## An app declares its actions and their words (declare), says what its
## screens hold (describe), and keeps its facts in models - controllers made
## in describe and handed to the screen that reads them. See apps/checklist
## for a whole app, and gd-chime's README for the vocabulary.

const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")
const Settings := preload("res://addons/factory_settings/settings.gd")
const Walk := preload("res://probe.gd")

const HOME := &"home"

var settings: Settings


## The factory's look. Pass a palette of your own to make() to change its colours.
func look() -> Theme:
	return FactoryLook.make()


func declare(register: GdChime.Actions) -> void:
	Settings.declare(register)


func describe() -> GdChime.Desc:
	# Android's Back goes back a screen, or out from the first. For saved
	# data: model(GdChime.SettingsFile.new(chimes, Basics.save_file("{{name}}")))
	Basics.answer_back(self)
	# Settings, reached by the gear: hand it every SettingsFile of the app's
	# data, so Reset app data can wipe them.
	settings = Settings.install(self, [])
	var screen := ui.column([
		ui.row([ui.text(GdChime.Phrase.of("{{title}}"), GdChime.Themes.TITLE).grow(), Settings.gear(ui)]),
		ui.text(GdChime.Phrase.of("A new app, ready to build."), FactoryLook.QUIET),
	])
	return ui.app(&"{{name}}", [ui.stack([ui.screen(HOME, [FactoryLook.page(ui, [screen])]), settings.screen(ui)])])


func probe() -> RefCounted:
	return Walk.new(self)
