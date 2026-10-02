extends ChimeApp

## Hello: a site of one screen, saying hello. Made by tooling/create_site.py.
##
## A site is an app that is exported for the web (tooling/export_web.py)
## and opened in a browser. It is described exactly as an app is: it
## declares its actions and their words (declare), says what its screens
## hold (describe), and keeps its facts in models - controllers made in
## describe and handed to the screen that reads them. See apps/checklist
## for a whole app, and gd-chime's README for the vocabulary.

const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")
const Settings := preload("res://addons/factory_settings/settings.gd")

const HOME := &"home"

var settings: Settings


## The factory's look. Pass a palette of your own to make() to change its colours.
func look() -> Theme:
	# the text size a person chose in Settings, handed to the look
	return FactoryLook.make(FactoryLook.PALETTE, Settings.text_size())


func declare(register: GdChime.Actions) -> void:
	Settings.declare(register)


func describe() -> GdChime.Desc:
	# A go-back request (Android's Back, when a phone wraps the site) goes
	# back a screen, or out from the first; a browser sends none. For saved
	# data, kept by the browser: model(GdChime.SettingsFile.new(chimes, Basics.save_file("hello")))
	Basics.answer_back(self)
	# Settings, reached by the gear: hand it every SettingsFile of the site's
	# data, so Reset app data can wipe them.
	settings = Settings.install(self, [])
	var screen := ui.column([
		ui.row([ui.text(GdChime.Phrase.of("Hello"), GdChime.Themes.TITLE).grow(), Settings.gear(ui)]),
		ui.text(GdChime.Phrase.of("Hello, world."), GdChime.Themes.WORDS),
		ui.text(GdChime.Phrase.of("A new site, ready to build."), FactoryLook.QUIET),
	])
	return ui.app(&"hello", [ui.stack([ui.screen(HOME, [FactoryLook.page(ui, [screen])]), settings.screen(ui)])])


func probe() -> RefCounted:
	# loaded only when walked, so an export leaves the probe and the testkit out
	return (load("res://probe.gd") as GDScript).new(self)
