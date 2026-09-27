extends ChimeApp

## Notes: write notes, find them again by searching, by #tag and by month,
## pin the ones that matter, and copy one to paste elsewhere.
##
## Two screens: the list and a note's editor. The facts live in notebook.gd;
## what is said about a note - its title, its month, its tags, its place in
## the list - in note_text.gd. This file declares the actions and their
## words, and arranges the screens.

const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")
const T := preload("res://note_text.gd")
const Notebook := preload("res://notebook.gd")
const Walk := preload("res://probe.gd")

const LIST := &"list"
const EDIT := &"edit"

## A press that only goes somewhere: no model handles it.
const GOES_BACK := &"goes_back"

## A tag to choose, and the tag chosen.
const TAG := &"NoteTag"
const TAG_CHOSEN := &"NoteTagChosen"
const HEADING := &"NoteHeading"
## A note in the list: a card, a gap between each; under its title, its
## first line and its time smaller - a press inks all its words alike, so
## size, not colour, says what matters less.
const NOTE := &"NoteCard"
const NOTE_LIST := &"NoteList"
const SMALLER := &"NoteSmaller"
const SMALLEST := &"NoteSmallest"

## Where the notes are kept: user://notes.json, unless a test chooses a
## file of its own (a probe always has its own - see the basics service).
var saved_at := ""
var notebook: Notebook
var menu: GdChime.OpenMenu
var saving: GdChime.SettingsFile


## The factory's look, with a tag's chip and a month's heading.
func look() -> Theme:
	var theme := FactoryLook.make()
	var palette := FactoryLook.PALETTE
	var grow := FactoryLook.Phone.factor()
	var resting := StyleBoxFlat.new()
	resting.bg_color = palette[&"raised"]
	resting.border_color = palette[&"lit"]
	resting.set_border_width_all(maxi(1, roundi(2 * grow)))
	resting.set_corner_radius_all(roundi(FactoryLook.PILL * grow))
	resting.content_margin_left = roundi(18 * grow)
	resting.content_margin_right = roundi(18 * grow)
	resting.content_margin_top = roundi(8 * grow)
	resting.content_margin_bottom = roundi(8 * grow)
	var chosen := resting.duplicate() as StyleBoxFlat
	chosen.bg_color = FactoryLook.second_accent(palette)
	chosen.border_color = FactoryLook.second_accent(palette)
	for type: StringName in [TAG, TAG_CHOSEN]:
		theme.set_type_variation(type, GdChime.Themes.PRESSABLE)
		for state: StringName in FactoryLook.STATES:
			theme.set_stylebox(state, type, chosen if type == TAG_CHOSEN else resting)
			theme.set_color(StringName("font_color_" + state), type, Color.WHITE if type == TAG_CHOSEN else palette[&"ink_soft"])
		theme.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	theme.set_type_variation(HEADING, FactoryLook.MARKED)
	theme.set_font(&"font", HEADING, FactoryLook.weighted(FactoryLook.TITLE_WEIGHT))
	theme.set_type_variation(NOTE, &"SwipeRow")
	for state: StringName in FactoryLook.STATES:
		theme.set_stylebox(state, NOTE, theme.get_stylebox(state, FactoryLook.CARD))
		theme.set_color(StringName("font_color_" + state), NOTE, palette[&"ink"])
	theme.set_stylebox(&"focus", NOTE, StyleBoxEmpty.new())
	theme.set_type_variation(NOTE_LIST, &"Column")
	theme.set_constant(&"gap", NOTE_LIST, roundi(12 * grow))
	theme.set_type_variation(SMALLER, GdChime.Themes.FACE)
	theme.set_font_size(&"font_size", SMALLER, roundi(22 * grow))
	theme.set_type_variation(SMALLEST, GdChime.Themes.FACE)
	theme.set_font_size(&"font_size", SMALLEST, roundi(18 * grow))
	return theme


func declare(register: GdChime.Actions) -> void:
	register.declare_all({
		Notebook.ADDS: ["New note"],
		Notebook.OPENS: ["Open"],
		Notebook.RETITLES: ["Title"],
		Notebook.REWRITES: ["Note"],
		Notebook.PINS: ["Pin"],
		Notebook.COPIES: ["Copy"],
		Notebook.DELETES: ["Delete"],
		Notebook.SEARCHES: ["Search"],
		Notebook.PICKS_TAG: ["Tag"],
		GOES_BACK: ["‹ Notes", GdChime.Actions.keys(KEY_ESCAPE)],
		GdChime.OpenMenu.OPENS: ["More", GdChime.Actions.keys(KEY_MENU), GdChime.Actions.pad(JOY_BUTTON_BACK)],
		GdChime.OpenMenu.PICKS: ["Pick"],
	})


func describe() -> GdChime.Desc:
	notebook = Notebook.new(chimes, commands, EDIT)
	Basics.answer_back(self)
	saving = model(GdChime.SettingsFile.new(chimes, Basics.save_file("notes", saved_at)))
	saving.keep("notes", notebook)
	menu = model(GdChime.OpenMenu.new(chimes, commands, actions))
	# The rows' menus need this in place before the first row is described.
	GdChime.ContextMenu.make(ui, menu)
	return ui.app(&"notes", [ui.stack([_list_screen(), _edit_screen()])])


func _list_screen() -> GdChime.Desc:
	var rows: GdChime.Bound = GdChime.Bound.all([notebook.notes, notebook.search, notebook.tag], func(all: Variant, search: Variant, tag: Variant) -> Array:
		return T.arranged(all, search, tag))
	var tags: GdChime.Bound = notebook.notes.map(func(all: Variant) -> Array: return T.all_tags(all))
	# Nothing to show: say why, or nothing while there is a list.
	var empty: GdChime.Bound = GdChime.Bound.both(notebook.notes, rows, func(all: Variant, shown: Variant) -> String:
		if all.is_empty():
			return "No notes yet. Words written as #word become tags to find a note by."
		return "No notes match." if shown.is_empty() else "")
	# The title's row starts with a link, so the screen's first focus lands
	# there and not in the search - which on a phone would raise the keyboard.
	var head := ui.row([
		ui.text(GdChime.Phrase.of("Notes"), GdChime.Themes.TITLE).grow(),
		FactoryLook.link(ui, Notebook.ADDS),
	])
	var content := ui.column([
		head,
		ui.text(GdChime.Phrase.of("Search"), FactoryLook.QUIET),
		ui.field(Notebook.SEARCHES, GdChime.Fields.FIELD, {"changes": Notebook.SEARCHES, "shows": notebook.search}),
		ui.each_across(tags, _tag, func(name: String) -> String: return name, GdChime.Themes.TILES),
		ui.row([ui.text(empty, FactoryLook.QUIET).wraps().hides_empty().grow()]),
		ui.scroll(ui.each(rows, _row, func(row: Dictionary) -> String: return row["key"], NOTE_LIST), null, &"down").grow(),
	])
	return ui.screen(LIST, [FactoryLook.page(ui, [content])], notebook)


## A tag to choose: pressed, only its notes show; pressed again, every note.
func _tag(name: GdChime.Bound) -> GdChime.Desc:
	var carried: GdChime.Bound = name.map(func(n: Variant) -> Dictionary: return {"tag": "" if n == null else n})
	var words: GdChime.Bound = name.map(func(n: Variant) -> String: return "" if n == null else "#" + n)
	var style: GdChime.Bound = GdChime.Bound.both(name, notebook.tag, func(n: Variant, chosen: Variant) -> StringName:
		return TAG_CHOSEN if n != null and n == chosen else TAG)
	return ui.pressable(Notebook.PICKS_TAG, carried, [ui.text(words, SMALLER)], style)


## A row of the list: a heading - Pinned, or a month - or a note, which is
## its title, its first line and when it was written. Tapped, a note opens;
## swiped left, it is deleted. Described once with no row at all, so every
## read allows for null.
func _row(row: GdChime.Bound) -> GdChime.Desc:
	var heading: GdChime.Bound = row.map(func(one: Variant) -> bool: return one != null and one.has("heading"))
	var note: GdChime.Bound = row.map(func(one: Variant) -> Dictionary: return {} if one == null or not one.has("note") else one["note"])
	var carried: GdChime.Bound = note.map(func(one: Variant) -> Dictionary: return {} if one.is_empty() else {"id": one["id"], "parameter": one["id"]})
	var title: GdChime.Bound = note.map(func(one: Variant) -> String: return "" if one.is_empty() else T.title_of(one))
	var snippet: GdChime.Bound = note.map(func(one: Variant) -> String: return "" if one.is_empty() else T.snippet(one))
	var stamp: GdChime.Bound = note.map(func(one: Variant) -> String: return "" if one.is_empty() else T.stamp(one["created"]))
	var words: GdChime.Bound = row.map(func(one: Variant) -> String: return "" if one == null else str(one.get("heading", "")))
	var sides := {GdChime.SwipeRow.LEFT: {"action": Notebook.DELETES, "words": GdChime.Phrase.of("Delete"), "state": GdChime.Status.FAULT}}
	var content := ui.column([
		ui.row([ui.text(title, GdChime.Themes.FACE).wraps().grow()]),
		ui.row([ui.text(snippet, SMALLER).wraps().hides_empty().grow()]),
		ui.text(stamp, SMALLEST),
	])
	return ui.when(heading,
		ui.text(words, HEADING),
		GdChime.SwipeRow.make(ui, Notebook.OPENS, carried, content, {"sides": sides, "goes_to": EDIT, "style": NOTE}))


func _edit_screen() -> GdChime.Desc:
	var open: GdChime.Bound = GdChime.Bound.both(notebook.editing, notebook.notes, func(_id: Variant, _all: Variant) -> Dictionary: return notebook.open_note())
	var title: GdChime.Bound = open.map(func(one: Variant) -> String: return "" if one.is_empty() else str(one["title"]))
	var text: GdChime.Bound = open.map(func(one: Variant) -> String: return "" if one.is_empty() else str(one["text"]))
	var stamp: GdChime.Bound = open.map(func(one: Variant) -> String: return "" if one.is_empty() else T.stamp(one["created"]))
	var pin_words: GdChime.Bound = open.map(func(one: Variant) -> String: return "Unpin" if not one.is_empty() and one["pinned"] else "Pin")
	var copy_words: GdChime.Bound = notebook.copied.map(func(done: Variant) -> String: return "Copied" if done else "Copy")
	var head := ui.row([
		FactoryLook.link(ui, GOES_BACK).goes_to(GdChime.Driver.BACK),
		ui.column([]).grow(),
		ui.pressable(Notebook.PINS, {}, [ui.text(pin_words, FactoryLook.MARKED)], FactoryLook.LINK),
		ui.pressable(Notebook.COPIES, {}, [ui.text(copy_words, FactoryLook.MARKED)], FactoryLook.LINK),
	])
	var content := ui.column([
		head,
		ui.text(stamp, FactoryLook.QUIET),
		ui.field(Notebook.RETITLES, GdChime.Fields.FIELD, {"changes": Notebook.RETITLES, "shows": title}),
		ui.area(Notebook.REWRITES, text).grow(),
	])
	var closing := func() -> void: notebook.drop_if_empty()
	return ui.screen(EDIT, [FactoryLook.page(ui, [content])], notebook, {"on_empty": closing})


func probe() -> RefCounted:
	return Walk.new(self)
