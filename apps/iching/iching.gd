extends ChimeApp

## I Ching: cast a hexagram by tapping a blank square six times, see what it
## is and what it changes to, and copy the cast - with a prompt of your own,
## if you like - to paste elsewhere. No interpretation: numbers only.
##
## Four screens: cast, result, prompts, and a prompt's editor; and a drawer
## from the foot for copying. The facts live in cast.gd, prompts.gd and
## copying.gd; hexagrams.gd is the arithmetic, drawing.gd the pictures.

const FactoryLook := preload("res://addons/factory_look/look.gd")
const Basics := preload("res://addons/factory_basics/basics.gd")
const H := preload("res://hexagrams.gd")
const Cast := preload("res://cast.gd")
const PromptList := preload("res://prompts.gd")
const Copying := preload("res://copying.gd")
const Drawing := preload("res://drawing.gd")
const Walk := preload("res://probe.gd")

const CAST := &"cast"
const RESULT := &"result"
const PROMPTS := &"prompts"
const EDIT := &"edit_prompt"

## Presses that only go somewhere: no model handles them.
const GOES_TO_PROMPTS := &"goes_to_the_prompts"
const GOES_BACK := &"goes_back"
const OPENS_COPY := &"opens_the_copy_drawer"

## Base-pixel sizes before phone sizing.
const HEXAGRAM_HEIGHT := 180
const SMALL_HEXAGRAM_HEIGHT := 120
const SQUARE_LEAST := 320

## Where the prompts are kept: user://iching.json, unless a test chooses a
## file of its own (a probe always has its own - see the basics service).
var saved_at := ""
var cast: Cast
var prompt_list: PromptList
var copying: Copying
var menu: GdChime.OpenMenu
var saving: GdChime.SettingsFile


func look() -> Theme:
	var theme := FactoryLook.make()
	var palette := FactoryLook.PALETTE
	var grow := FactoryLook.Phone.factor()
	theme.set_type_variation(Drawing.HEXAGRAM, &"Control")
	theme.set_color(&"line", Drawing.HEXAGRAM, palette[&"ink"])
	theme.set_color(&"faint", Drawing.HEXAGRAM, palette[&"lit"])
	theme.set_color(&"mark", Drawing.HEXAGRAM, FactoryLook.second_accent(palette))
	theme.set_constant(&"least_height", Drawing.HEXAGRAM, roundi(HEXAGRAM_HEIGHT * grow))
	theme.set_type_variation(&"SmallHexagram", Drawing.HEXAGRAM)
	theme.set_constant(&"least_height", &"SmallHexagram", roundi(SMALL_HEXAGRAM_HEIGHT * grow))
	theme.set_type_variation(Drawing.SQUARE, &"Control")
	theme.set_color(&"ground", Drawing.SQUARE, palette[&"raised"])
	theme.set_color(&"edge", Drawing.SQUARE, palette[&"lit"])
	theme.set_constant(&"least_height", Drawing.SQUARE, roundi(SQUARE_LEAST * grow))
	return theme


func declare(register: GdChime.Actions) -> void:
	register.declare_all({
		Cast.ASKS: ["Question"],
		Cast.CASTS: ["Cast a line"],
		Cast.CASTS_AGAIN: ["Cast again"],
		PromptList.ADDS: ["New prompt"],
		PromptList.OPENS: ["Edit"],
		PromptList.RENAMES: ["Name"],
		PromptList.REWRITES: ["Prompt"],
		PromptList.DELETES: ["Delete"],
		Copying.PICKS: ["Choose a prompt"],
		Copying.FILLS: ["Fill in"],
		Copying.COPIES: ["Copy"],
		GOES_TO_PROMPTS: ["Prompts"],
		GOES_BACK: ["‹ Back", GdChime.Actions.keys(KEY_ESCAPE)],
		OPENS_COPY: ["Copy the cast"],
		GdChime.OpenMenu.OPENS: ["More", GdChime.Actions.keys(KEY_MENU), GdChime.Actions.pad(JOY_BUTTON_BACK)],
		GdChime.OpenMenu.PICKS: ["Pick"],
	})


func describe() -> GdChime.Desc:
	cast = Cast.new(chimes, commands, CAST, RESULT)
	prompt_list = PromptList.new(chimes, commands, EDIT)
	# The copy drawer takes no model of its own, so copying answers app-wide.
	copying = model(Copying.new(chimes, cast, prompt_list))
	FactoryLook.splash(self)
	Basics.answer_back(self)
	saving = model(GdChime.SettingsFile.new(chimes, Basics.save_file("iching", saved_at)))
	saving.keep("iching", prompt_list)
	menu = model(GdChime.OpenMenu.new(chimes, commands, actions))
	# The prompt rows' menus need this in place before the first row is described.
	GdChime.ContextMenu.make(ui, menu)
	var drawer := _copy_drawer()
	var screens := ui.stack([_cast_screen(), _result_screen(drawer), _prompts_screen(), _edit_screen()])
	return ui.app(&"iching", [screens])


func _cast_screen() -> GdChime.Desc:
	var progress: GdChime.Bound = cast.lines.map(func(lines: Variant) -> String:
		var count: int = lines.size() if lines is Array else 0
		return "Tap the square: line %d of 6" % mini(count + 1, H.LINES))
	var head := ui.row([
		ui.text(GdChime.Phrase.of("I Ching"), GdChime.Themes.TITLE).grow(),
		FactoryLook.link(ui, GOES_TO_PROMPTS).goes_to(PROMPTS),
	])
	var content := ui.column([
		head,
		ui.text(GdChime.Phrase.of("Question (optional)"), FactoryLook.QUIET),
		ui.field(Cast.ASKS, GdChime.Fields.FIELD, {"changes": Cast.ASKS, "shows": cast.question}),
		ui.text(progress, GdChime.Themes.FACE),
		ui.canvas(Drawing.hexagram, cast.lines, &"SmallHexagram"),
		ui.pinned(Drawing.square, null, [], {"points": [], "picks": Cast.CASTS, "hit": Drawing.cell_at, "style": Drawing.SQUARE}).grow(),
	])
	return ui.screen(CAST, [FactoryLook.page(ui, [content])], cast)


func _result_screen(drawer: GdChime.Desc) -> GdChime.Desc:
	var changes: GdChime.Bound = cast.lines.map(func(lines: Variant) -> bool: return lines is Array and not H.changing_positions(lines).is_empty())
	var turned: GdChime.Bound = cast.lines.map(func(lines: Variant) -> Array:
		return [] if not (lines is Array) or lines.size() < H.LINES else H.changed(lines).map(func(yang: bool) -> int: return H.YOUNG_YANG if yang else H.YOUNG_YIN))
	var sentence: GdChime.Bound = cast.lines.map(func(_lines: Variant) -> String: return cast.sentence())
	var first_number: GdChime.Bound = cast.lines.map(func(lines: Variant) -> String:
		return "" if not (lines is Array) or lines.size() < H.LINES else "Hexagram %d" % H.number(H.first(lines)))
	var turned_number: GdChime.Bound = turned.map(func(lines: Variant) -> String:
		return "" if not (lines is Array) or lines.size() < H.LINES else "Hexagram %d" % H.number(H.first(lines)))
	var original := ui.column([ui.canvas(Drawing.hexagram, cast.lines, Drawing.HEXAGRAM), ui.text(first_number, GdChime.Themes.REASON)])
	var becomes := ui.column([ui.canvas(Drawing.hexagram, turned, Drawing.HEXAGRAM), ui.text(turned_number, GdChime.Themes.REASON)])
	var pictures := ui.when(changes,
		ui.row([original.grow(), ui.text("→", GdChime.Themes.TITLE), becomes.grow()]),
		ui.row([original.grow()]))
	# Long words wrap only in a row that gives them the width to grow into.
	var copy_card := FactoryLook.card(ui, OPENS_COPY, [
		ui.row([ui.text(sentence, GdChime.Themes.FACE).wraps().grow()]),
		ui.text(copying.copied.map(func(done: Variant) -> String: return "Copied" if done else "Tap to copy"), FactoryLook.MARKED),
	]).opens(drawer)
	var content := ui.column([
		ui.text(GdChime.Phrase.of("I Ching"), GdChime.Themes.TITLE),
		ui.row([ui.text(cast.question, FactoryLook.QUIET).wraps().hides_empty().grow()]),
		pictures,
		copy_card,
		ui.column([]).grow(),
		FactoryLook.button(ui, Cast.CASTS_AGAIN),
	])
	var fresh := func(_token: Variant) -> void: copying.start(cast.question.read())
	return ui.screen(RESULT, [FactoryLook.page(ui, [content])], cast, {"on_fill": fresh})


func _prompts_screen() -> GdChime.Desc:
	var rows := ui.each(prompt_list.prompts, _prompt_row, func(one: Dictionary) -> int: return one["id"])
	var none: GdChime.Bound = prompt_list.prompts.map(func(all: Variant) -> bool: return all is Array and all.is_empty())
	var content := ui.column([
		_back_row(),
		ui.text(GdChime.Phrase.of("Prompts"), GdChime.Themes.TITLE),
		ui.when(none, ui.row([ui.text(GdChime.Phrase.of("No prompts yet. Write one, using {question} for your question and any {name} for something to fill in when you copy."), FactoryLook.QUIET).wraps().grow()])),
		ui.scroll(rows, null, &"down").grow(),
		FactoryLook.button(ui, PromptList.ADDS),
	])
	return ui.screen(PROMPTS, [FactoryLook.page(ui, [content])], prompt_list)


## One saved prompt: its name over its first line. Tapped, it opens; swiped left, it is deleted.
func _prompt_row(item: GdChime.Bound) -> GdChime.Desc:
	var carried: GdChime.Bound = item.map(func(one: Variant) -> Dictionary: return {} if one == null else {"id": one["id"], "parameter": one["id"]})
	var name: GdChime.Bound = item.map(func(one: Variant) -> String: return "" if one == null else PromptList.name_of(one))
	# Under a name, the prompt's first line; an unnamed prompt is already shown by it.
	var text: GdChime.Bound = item.map(func(one: Variant) -> String:
		if one == null or str(one["name"]).strip_edges().is_empty():
			return ""
		return str(one["text"]).strip_edges().get_slice("\n", 0))
	var sides := {GdChime.SwipeRow.LEFT: {"action": PromptList.DELETES, "words": GdChime.Phrase.of("Delete"), "state": GdChime.Status.FAULT}}
	var content := ui.column([ui.row([ui.text(name, GdChime.Themes.FACE).wraps().grow()]), ui.row([ui.text(text, FactoryLook.QUIET).wraps().hides_empty().grow()])])
	return GdChime.SwipeRow.make(ui, PromptList.OPENS, carried, content, {"sides": sides, "goes_to": EDIT})


func _edit_screen() -> GdChime.Desc:
	var open: GdChime.Bound = GdChime.Bound.both(prompt_list.editing, prompt_list.prompts, func(id: Variant, _all: Variant) -> Dictionary: return prompt_list.find(id))
	var name: GdChime.Bound = open.map(func(one: Variant) -> String: return "" if one == null or one.is_empty() else str(one["name"]))
	var text: GdChime.Bound = open.map(func(one: Variant) -> String: return "" if one == null or one.is_empty() else str(one["text"]))
	var content := ui.column([
		_back_row(),
		ui.text(GdChime.Phrase.of("Prompt"), GdChime.Themes.TITLE),
		ui.text(GdChime.Phrase.of("Name"), FactoryLook.QUIET),
		ui.field(PromptList.RENAMES, GdChime.Fields.FIELD, {"changes": PromptList.RENAMES, "shows": name}),
		ui.row([ui.text(GdChime.Phrase.of("Prompt: {question} is your question; any other {name} is filled in when you copy."), FactoryLook.QUIET).wraps().grow()]),
		ui.area(PromptList.REWRITES, text),
	])
	var closing := func() -> void: prompt_list.drop_if_empty()
	return ui.screen(EDIT, [FactoryLook.page(ui, [content])], prompt_list, {"on_empty": closing})


func _back_row() -> GdChime.Desc:
	return ui.row([FactoryLook.link(ui, GOES_BACK).goes_to(GdChime.Driver.BACK)])


## The drawer from the foot: choose a prompt, fill its placeholders, copy.
func _copy_drawer() -> GdChime.Desc:
	var body := func(_which: GdChime.Bound) -> GdChime.Desc:
		var blanks := ui.each(copying.blanks, _blank, func(name: String) -> String: return name)
		return ui.scroll(ui.column([
			GdChime.InlineChoice.radios(ui, Copying.PICKS, copying.offers, copying.picked),
			blanks,
		]), null, &"down")
	var foot := FactoryLook.button(ui, Copying.COPIES).goes_to(GdChime.Driver.BACK)
	return GdChime.Drawer.over(ui, GdChime.Phrase.of("Copy the cast"), body, {"foot": foot, "from": GdChime.Drawer.FROM_BOTTOM})


## One placeholder to fill: its name, and a line for what goes in it.
func _blank(name: GdChime.Bound) -> GdChime.Desc:
	var shown: GdChime.Bound = GdChime.Bound.both(name, copying.filled, func(n: Variant, all: Variant) -> String:
		return "" if n == null or not (all is Dictionary) else str(all.get(n, "")))
	var label: GdChime.Bound = name.map(func(n: Variant) -> String: return "" if n == null else "{%s}" % n)
	return ui.column([
		ui.text(label, FactoryLook.QUIET),
		ui.field(Copying.FILLS, GdChime.Fields.FIELD, {"changes": Copying.FILLS, "shows": shown,
			"carries": func(line: String) -> Dictionary: return {"name": name.read(), "line": line}}),
	])


func probe() -> RefCounted:
	return Walk.new(self)
