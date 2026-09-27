extends ChimeApp

## Checklist: add things, tick them off, swipe them away. The factory's first app.
##
## One screen: a title, how many are done, a line to add to, the list, and a
## button clearing what is done. The facts live in items.gd; this file
## declares the actions and their words, and arranges the screen.

const Items := preload("res://items.gd")
const Walk := preload("res://probe.gd")
const PhoneLook := preload("res://phone_look.gd")

const LIST := &"list"
## The theme type of the page every part of the screen stands on.
const PAGE := &"ChecklistPage"
## The theme types of a done item's words, and of the tick boxes.
const DONE := &"ChecklistDone"
const TICK := &"ChecklistTick"
## The tick boxes, as words so they grow with the look.
const UNTICKED := "☐"
const TICKED := "☑"
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
	var theme := GdChime.Themes.new(PALETTE)
	# The page: the list kept off the glass's edges.
	theme.set_type_variation(PAGE, &"Control")
	var page := StyleBoxFlat.new()
	page.bg_color = PALETTE[&"ground"]
	page.set_content_margin_all(24)
	theme.set_stylebox(&"panel", PAGE, page)
	# The title reads as one, bigger than the items under it.
	theme.set_font_size(&"font_size", GdChime.Themes.TITLE, 44)
	# A done item's words and tick, quieter than one still to do.
	theme.set_type_variation(DONE, GdChime.Themes.FACE)
	theme.set_color(&"font_color", DONE, PALETTE[&"ink_soft"])
	theme.set_type_variation(TICK, GdChime.Themes.FACE)
	theme.set_color(&"font_color", TICK, PALETTE[&"accent"])
	# The add line: a white field outlined in the quiet ink, in teal while typing.
	var field := _field_box(PALETTE[&"ink_soft"], 2)
	theme.set_stylebox(&"normal", GdChime.Fields.FIELD, field)
	theme.set_stylebox(&"read_only", GdChime.Fields.FIELD, field)
	theme.set_stylebox(&"focus", GdChime.Fields.FIELD, _field_box(PALETTE[&"accent"], 3))
	theme.set_color(&"font_color", GdChime.Fields.FIELD, PALETTE[&"ink"])
	theme.set_color(&"caret_color", GdChime.Fields.FIELD, PALETTE[&"accent"])
	PhoneLook.enlarge(theme, PhoneLook.factor())
	return theme


func _field_box(edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PALETTE[&"raised"]
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	return box


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
		ui.field(Items.ADDS, GdChime.Fields.FIELD).takes_focus(),
		ui.scroll(rows, null, &"down").grow(),
		ui.button(Items.CLEARS),
	])
	return ui.app(&"checklist", [ui.screen(LIST, [ui.surface(PAGE, [screen])], list)])


## One item: its tick box and its words, quieter once done. Tapped, it ticks; swiped left, it is deleted.
## Described once with no item at all, so every read allows for null.
func _row(item: GdChime.Bound) -> GdChime.Desc:
	var carried: GdChime.Bound = item.map(func(one: Variant) -> Dictionary: return {} if one == null else {"id": one["id"]})
	var done: GdChime.Bound = item.map(func(one: Variant) -> bool: return one != null and one["done"])
	var words: GdChime.Bound = item.map(func(one: Variant) -> String: return "" if one == null else one["words"])
	var sides := {GdChime.SwipeRow.LEFT: {"action": Items.DELETES, "words": GdChime.Phrase.of("Delete"), "state": GdChime.Status.FAULT}}
	var content := ui.when(done,
		ui.row([ui.text(TICKED, TICK), ui.text(words, DONE).wraps().grow()]),
		ui.row([ui.text(UNTICKED, TICK), ui.text(words, GdChime.Themes.FACE).wraps().grow()]))
	return GdChime.SwipeRow.make(ui, Items.TOGGLES, carried, content, {"sides": sides})


func probe() -> RefCounted:
	return Walk.new(self)
