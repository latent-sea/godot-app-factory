extends ChimeApp

## {{title}}: one screen to build on. Made by tooling/create_app.py.
##
## An app declares its actions and their words (declare), says what its
## screens hold (describe), and keeps its facts in models - controllers made
## in describe and handed to the screen that reads them. See apps/checklist
## for a whole app, and gd-chime's README for the vocabulary.

const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")
const Walk := preload("res://probe.gd")

const HOME := &"home"


## The factory's look. Pass a palette of your own to make() to change its colours.
func look() -> Theme:
	return FactoryLook.make()


func declare(_register: GdChime.Actions) -> void:
	pass


func describe() -> GdChime.Desc:
	# Android's Back goes back a screen, or out from the first. For saved
	# data: model(GdChime.SettingsFile.new(chimes, Basics.save_file("{{name}}")))
	Basics.answer_back(self)
	var screen := ui.column([
		ui.text(GdChime.Phrase.of("{{title}}"), GdChime.Themes.TITLE),
		ui.text(GdChime.Phrase.of("A new app, ready to build."), FactoryLook.QUIET),
	])
	return ui.app(&"{{name}}", [ui.screen(HOME, [FactoryLook.page(ui, [screen])])])


func probe() -> RefCounted:
	return Walk.new(self)
