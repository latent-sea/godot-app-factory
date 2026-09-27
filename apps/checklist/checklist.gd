extends ChimeApp

## Checklist: add things, tick them off, swipe them away. The factory's first app.
##
## One screen: a title, how many are done, a line to add to, the list, and a
## button clearing what is done, faded until something is. The facts live in items.gd; this file
## declares the actions and their words, and arranges the screen.

const Items := preload("res://items.gd")
const Walk := preload("res://probe.gd")
const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")

const LIST := &"list"
## The tick boxes, as words so they grow with the look.
const UNTICKED := "☐"
const TICKED := "☑"
## Where the items are kept: user://checklist.json, unless a test chooses a
## file of its own (a probe always has its own - see the basics service).
var saved_at := ""
var list: Items
var menu: GdChime.OpenMenu
var saving: GdChime.SettingsFile


## The factory's look, as it is: the Checklist asks nothing of its own.
func look() -> Theme:
	return FactoryLook.make()


func declare(register: GdChime.Actions) -> void:
	register.declare_all({
		Items.ADDS: ["Add"],
		Items.TOGGLES: ["Tick or untick"],
		Items.DELETES: ["Delete"],
		Items.CLEARS: ["Clear done"],
		GdChime.OpenMenu.OPENS: ["More", GdChime.Actions.keys(KEY_MENU), GdChime.Actions.pad(JOY_BUTTON_BACK)],
		GdChime.OpenMenu.PICKS: ["Pick"],
	})


func describe() -> GdChime.Desc:
	list = Items.new(chimes)
	FactoryLook.splash(self)
	Basics.answer_back(self)
	saving = model(GdChime.SettingsFile.new(chimes, Basics.save_file("checklist", saved_at)))
	saving.keep("checklist", list)
	menu = model(GdChime.OpenMenu.new(chimes, commands, actions))
	# The rows' menus need this in place before the first row is described.
	GdChime.ContextMenu.make(ui, menu)

	var counted: GdChime.Bound = list.items.map(func(all: Variant) -> GdChime.Phrase:
		var done: int = all.filter(func(one: Dictionary) -> bool: return one["done"]).size()
		return GdChime.Phrase.with("%d of %d done", [done, all.size()]))
	var rows := ui.each(list.items, _row, func(one: Dictionary) -> int: return one["id"])
	var screen := ui.column([
		ui.text(GdChime.Phrase.of("Checklist"), GdChime.Themes.TITLE),
		ui.text(counted, GdChime.Themes.REASON),
		ui.field(Items.ADDS, GdChime.Fields.FIELD).takes_focus(),
		ui.scroll(rows, null, &"down").grow(),
		FactoryLook.button(ui, Items.CLEARS),
	])
	return ui.app(&"checklist", [ui.screen(LIST, [FactoryLook.page(ui, [screen])], list)])


## One item: its tick box and its words, quieter once done. Tapped, it ticks; swiped left, it is deleted.
## Described once with no item at all, so every read allows for null.
func _row(item: GdChime.Bound) -> GdChime.Desc:
	var carried: GdChime.Bound = item.map(func(one: Variant) -> Dictionary: return {} if one == null else {"id": one["id"]})
	var done: GdChime.Bound = item.map(func(one: Variant) -> bool: return one != null and one["done"])
	var words: GdChime.Bound = item.map(func(one: Variant) -> String: return "" if one == null else one["words"])
	var sides := {GdChime.SwipeRow.LEFT: {"action": Items.DELETES, "words": GdChime.Phrase.of("Delete"), "state": GdChime.Status.FAULT}}
	var content := ui.when(done,
		ui.row([ui.text(TICKED, FactoryLook.MARKED), ui.text(words, FactoryLook.QUIET).wraps().grow()]),
		ui.row([ui.text(UNTICKED, FactoryLook.MARKED), ui.text(words, GdChime.Themes.FACE).wraps().grow()]))
	return GdChime.SwipeRow.make(ui, Items.TOGGLES, carried, content, {"sides": sides})


func probe() -> RefCounted:
	return Walk.new(self)
