extends ChimeApp

## Checklist: add things, tick them off, swipe them away. The factory's first app.
##
## One screen: a title, how many are done, a line to add to, the list, and a
## button clearing what is done. The facts live in items.gd; this file
## declares the actions and their words, and arranges the screen.

const Items := preload("res://items.gd")
const Walk := preload("res://probe.gd")

const LIST := &"list"
const SAVED_AT := "user://checklist.json"
## The probe keeps its own file, so walking the app never touches real items.
const PROBED_AT := "user://checklist_probe.json"

## The app's own look: the factory's teal on a cool, quiet ground.
const PALETTE := {
	&"ground": Color("#f3f5f7"),
	&"raised": Color("#ffffff"),
	&"lit": Color("#dfe7ec"),
	&"ink": Color("#17212b"),
	&"ink_soft": Color("#4a5866"),
	&"accent": Color("#0e6b70"),
	&"shade": Color(0.09, 0.13, 0.17, 0.55),
}

## Where the items are kept; a test points this at a file of its own.
var saved_at := SAVED_AT
var list: Items
var menu: GdChime.OpenMenu
var saving: GdChime.SettingsFile


func look() -> Theme:
	return GdChime.Themes.new(PALETTE)


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
	var file := saved_at
	if OS.get_cmdline_user_args().has(PROBE_SWITCH):
		file = PROBED_AT
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBED_AT))
	saving = model(GdChime.SettingsFile.new(chimes, file))
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
		ui.field(Items.ADDS).takes_focus(),
		ui.scroll(rows, null, &"down").grow(),
		ui.button(Items.CLEARS),
	])
	return ui.app(&"checklist", [ui.screen(LIST, [screen], list)])


## One item: its tick and its words. Tapped, it ticks; swiped left, it is deleted.
## Described once with no item at all, so every read allows for null.
func _row(item: GdChime.Bound) -> GdChime.Desc:
	var carried: GdChime.Bound = item.map(func(one: Variant) -> Dictionary: return {} if one == null else {"id": one["id"]})
	var tick: GdChime.Bound = item.map(func(one: Variant) -> Variant:
		if one == null:
			return null
		return GdChime.Status.WELL if one["done"] else GdChime.Status.STILL)
	var words: GdChime.Bound = item.map(func(one: Variant) -> String: return "" if one == null else one["words"])
	var sides := {GdChime.SwipeRow.LEFT: {"action": Items.DELETES, "words": GdChime.Phrase.of("Delete"), "state": GdChime.Status.FAULT}}
	var content := ui.row([GdChime.Status.mark(ui, tick), ui.text(words, GdChime.Themes.FACE).wraps().grow()])
	return GdChime.SwipeRow.make(ui, Items.TOGGLES, carried, content, {"sides": sides})


func probe() -> RefCounted:
	return Walk.new(self)
