extends RefCounted

## The factory's look: one Theme every app wears, built on gd-chime's.
##
## An app preloads this as FactoryLook (ChimeApp already has a member named
## Look) and its look() returns FactoryLook.make(), or FactoryLook.make(palette) with a palette
## of its own. On top of gd-chime's Themes this dresses what gd-chime leaves
## as placeholders, and then sizes it all for a phone (phone.gd):
##   PAGE    the ground a screen stands on: navy deepening to violet, two pools of light drifting (backdrop.gd)
##   Title   a screen's title, bigger than what is under it
##   QUIET   words that matter less: a done item, a note
##   MARKED  words in the accent: a tick, a small mark
##   QUIET and MARKED: MARKED is in the second accent
##   ACTION  a pill in the accent's gradient, softly glowing: the main button
##   LINK    the same in the second accent's gradient: a lesser button, or one that goes somewhere
##   DANGER  the same in red: a button that deletes
##   CARD    a card deepening downwards, its edge from the accent to the second accent
##   GEAR    the round glowing button that opens settings
##   (every button is faded while it can't be used)
##   Field   a field (and a TextArea) on the raised ground, outlined in the accent while typing
##
## THE RULES, from using the apps on a phone (docs/look-backlog.md):
## - A control that can't be used looks faded and says nothing more. Use
##   button() rather than gd-chime's ui.button, which always prints the
##   reason under the button, where it reads as a second button.
## - Every button looks like one: a glowing gradient pill (ACTION, LINK,
##   DANGER, GEAR), never words alone.
##
## The builder is taken untyped, as gd-chime's own recipes take it, so a
## test can hand in a stand-in.
##
## Installed into each app as res://addons/factory_look/ by tooling/install.py.

const Phone := preload("phone.gd")
const GradientPill := preload("gradient_pill.gd")
const GradientCard := preload("gradient_card.gd")
const Backdrop := preload("backdrop.gd")
const GearButton := preload("gear_button.gd")
## Manrope, a geometric sans (SIL Open Font License, fonts/OFL.txt), in its variable form.
const FONT := preload("fonts/Manrope.ttf")
## Its weights: words, and titles.
const WEIGHT := 500
const TITLE_WEIGHT := 750

## The theme types this look adds; pass them as a style.
const PAGE := &"FactoryPage"
const QUIET := &"FactoryQuiet"
const MARKED := &"FactoryMarked"
const ACTION := &"FactoryAction"
const LINK := &"FactoryLink"
const CARD := &"FactoryCard"
## A button that deletes: red, glowing.
const DANGER := &"FactoryDanger"
## The gear that opens an app's settings (the settings service draws it).
const GEAR := &"FactoryGear"
## Every state gd-chime draws a pressable in (face.gd), and its focus.
const STATES: Array[StringName] = [&"normal", &"hover", &"inert", &"current", &"glowing", &"selected", &"lifted", &"accepting", &"refusing", &"listening"]

## The factory's palette: dark navy glass - navy ground, cards a shade
## lighter with thin cool outlines, light words, teal as the one strong
## accent and violet as the second. The seven keys gd-chime's Themes reads
## come first; an app's own palette needs those seven, and may add
## accent_2 (a second accent) and accent_end (where a button's gradient ends).
const PALETTE := {
	&"ground": Color("#121829"),
	&"raised": Color("#1b2339"),
	&"lit": Color("#34426a"),
	&"ink": Color("#eef2fa"),
	&"ink_soft": Color("#8e9ab8"),
	&"accent": Color("#19c3b3"),
	&"shade": Color(0.02, 0.03, 0.08, 0.7),
	&"accent_2": Color("#7c5cff"),
	&"accent_end": Color("#2fd6e8"),
	&"accent_2_end": Color("#c46bff"),
	&"ground_deep": Color("#1c1540"),
	&"danger": Color("#ff4f7b"),
	&"danger_end": Color("#ff8f5a"),
}
## Rounded throughout: cards and fields, and buttons as pills.
const CORNER := 16
const PILL := 40
## The room kept between a screen's content and the glass's edge, in base pixels before phone sizing.
const PAGE_MARGIN := 24
const TITLE_SIZE := 44


## The whole look, sized for the screen it runs on and the text size asked
## for (a share of gd-chime's sizes: Phone.DEFAULT_SIZE unless the app hands
## in what a person chose).
static func make(palette: Dictionary = PALETTE, text_size: float = Phone.DEFAULT_SIZE) -> Theme:
	var theme := GdChime.Themes.new(palette)
	_type(theme)
	_page(theme, palette)
	_words(theme, palette)
	_field(theme, palette)
	_action(theme, palette)
	_link(theme, palette)
	_danger(theme, palette)
	_card(theme, palette)
	_motion(theme)
	_settings_parts(theme, palette)
	_sheets(theme, palette)
	_scroll_bars(theme)
	Phone.enlarge(theme, Phone.factor(text_size), Phone.dp_scale())
	for state: StringName in STATES:
		(theme.get_stylebox(state, GEAR) as GearButton).side = theme.get_constant(&"least", &"Touch")
	return theme


## A screen's content on the page: margins from the glass, the ground behind.
static func page(ui: RefCounted, content: Array) -> GdChime.Desc:
	return ui.surface(PAGE, content)


## A filled button with the action's words and nothing else: faded while it
## can't be used, never a reason printed under it.
static func button(ui: RefCounted, action: StringName, payload: Variant = {}) -> GdChime.Desc:
	return ui.pressable(action, payload, [ui.text(ui.words(action), GdChime.Themes.FACE)], ACTION)


static func _page(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(PAGE, &"Control")
	var page_box := Backdrop.new()
	page_box.top = palette[&"ground"]
	page_box.bottom = palette.get(&"ground_deep", palette[&"ground"])
	page_box.glow_a = Color(palette[&"accent"], 0.10)
	page_box.glow_b = Color(second_accent(palette), 0.16)
	page_box.set_content_margin_all(PAGE_MARGIN)
	theme.set_stylebox(&"panel", PAGE, page_box)


static func _words(theme: Theme, palette: Dictionary) -> void:
	theme.set_font_size(&"font_size", GdChime.Themes.TITLE, TITLE_SIZE)
	theme.set_type_variation(QUIET, GdChime.Themes.FACE)
	theme.set_color(&"font_color", QUIET, palette[&"ink_soft"])
	theme.set_type_variation(MARKED, GdChime.Themes.FACE)
	theme.set_color(&"font_color", MARKED, second_accent(palette))


static func _field(theme: Theme, palette: Dictionary) -> void:
	var resting := _box(palette[&"raised"], CORNER, 14)
	resting.border_color = palette[&"lit"]
	resting.set_border_width_all(2)
	var typing := _box(palette[&"raised"], CORNER, 14)
	typing.border_color = palette[&"accent"]
	typing.set_border_width_all(3)
	# A typed line and words typed over many lines, dressed alike.
	for kind: StringName in [GdChime.Fields.FIELD, GdChime.Fields.TEXT_AREA]:
		theme.set_stylebox(&"normal", kind, resting)
		theme.set_stylebox(&"read_only", kind, resting)
		theme.set_stylebox(&"focus", kind, typing)
		theme.set_color(&"font_color", kind, palette[&"ink"])
		theme.set_color(&"caret_color", kind, palette[&"accent"])


static func _action(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(ACTION, GdChime.Themes.PRESSABLE)
	var accent: Color = palette[&"accent"]
	var end: Color = gradient_end(palette)
	for state: StringName in [&"normal", &"hover", &"glowing"]:
		var pressed := state != &"normal"
		var lit_up := GradientPill.new()
		lit_up.from_color = accent.darkened(0.2) if pressed else accent
		lit_up.to_color = end.darkened(0.2) if pressed else end
		lit_up.radius = PILL
		# A soft glow of the accent around it, as light through glass.
		lit_up.glow = Color(accent, 0.45)
		lit_up.glow_size = 10
		lit_up.set_content_margin_all(18)
		theme.set_stylebox(state, ACTION, lit_up)
		theme.set_color(StringName("font_color_" + state), ACTION, Color.WHITE)
	# gd-chime draws a button that can't be used as inert, and flashes refusing when it is pressed anyway.
	for state: StringName in [&"inert", &"refusing"]:
		var off := _box(faded(palette), PILL, 18)
		off.border_color = palette[&"lit"]
		off.set_border_width_all(1)
		theme.set_stylebox(state, ACTION, off)
		theme.set_color(StringName("font_color_" + state), ACTION, faded_words(palette))


## A second kind of button - going somewhere, or a lesser action beside the
## main one: a pill in the second accent's gradient, softly glowing, its
## words white; faded while it can't be used. Never bare words: a button
## looks like one.
static func _link(theme: Theme, palette: Dictionary) -> void:
	_glowing(theme, LINK, palette, second_accent(palette), palette.get(&"accent_2_end", second_accent(palette)), Vector2(20, 10))


## A button that deletes: the same pill in red.
static func _danger(theme: Theme, palette: Dictionary) -> void:
	_glowing(theme, DANGER, palette, palette.get(&"danger", Color.RED), palette.get(&"danger_end", Color.ORANGE_RED), Vector2(24, 14))


## A pill of this gradient with a glow of its first colour, brighter while
## pressed; faded while it can't be used. Each faded state has a box of its
## own: gd-chime re-inks a press's words only when its box changes (face.gd's
## _blend), so a button built faded - a screen's Back before it is shown -
## would otherwise keep its faded words once it could be used.
static func _glowing(theme: Theme, type: StringName, palette: Dictionary, from: Color, to: Color, margin: Vector2) -> void:
	theme.set_type_variation(type, GdChime.Themes.PRESSABLE)
	for state: StringName in STATES:
		var faded_now := state in [&"inert", &"refusing"]
		var box: StyleBox
		if faded_now:
			var off := _box(faded(palette), PILL, 0)
			off.border_color = palette[&"lit"]
			off.set_border_width_all(1)
			box = off
		else:
			var lit := state in [&"hover", &"glowing", &"selected", &"accepting"]
			var pill := GradientPill.new()
			pill.from_color = from.lightened(0.12) if lit else from
			pill.to_color = to.lightened(0.12) if lit else to
			pill.radius = PILL
			pill.glow = Color(from, 0.6 if lit else 0.4)
			pill.glow_size = 12 if lit else 8
			box = pill
		box.content_margin_left = margin.x
		box.content_margin_right = margin.x
		box.content_margin_top = margin.y
		box.content_margin_bottom = margin.y
		theme.set_stylebox(state, type, box)
		theme.set_color(StringName("font_color_" + state), type, faded_words(palette) if faded_now else Color.WHITE)
	theme.set_stylebox(&"focus", type, StyleBoxEmpty.new())


## A card: a fill a shade lighter than the ground, deepening downwards, with
## an edge running from the accent to the second accent; lit while pressed.
static func _card(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(CARD, &"Control")
	var resting := GradientCard.new()
	resting.edge_from = Color(palette[&"accent"], 0.55)
	resting.edge_to = Color(second_accent(palette), 0.55)
	resting.edge = 2
	resting.fill_top = (palette[&"raised"] as Color).lightened(0.04)
	resting.fill_bottom = palette[&"raised"]
	resting.radius = CORNER
	resting.set_content_margin_all(22)
	var pressed := resting.duplicate() as GradientCard
	pressed.fill_top = palette[&"lit"]
	pressed.fill_bottom = (palette[&"lit"] as Color).darkened(0.2)
	pressed.edge_from = palette[&"accent"]
	pressed.edge_to = second_accent(palette)
	for state: StringName in STATES:
		theme.set_stylebox(state, CARD, pressed if state in [&"hover", &"glowing", &"selected", &"accepting"] else resting)
		theme.set_color(StringName("font_color_" + state), CARD, palette[&"ink"])
	theme.set_stylebox(&"focus", CARD, StyleBoxEmpty.new())


## What a settings screen is made of (the settings service): the slider,
## the on/off toggle as a pill, and the gear that opens settings.
static func _settings_parts(theme: Theme, palette: Dictionary) -> void:
	var slider: StringName = GdChime.Fields.SLIDER
	theme.set_stylebox(&"track", slider, _box(palette[&"raised"], PILL, 0))
	theme.set_stylebox(&"fill", slider, _box(palette[&"accent"], PILL, 0))
	theme.set_stylebox(&"handle", slider, _box(palette[&"ink"], PILL, 0))
	theme.set_constant(&"handle_width", slider, 26)
	theme.set_constant(&"track_thickness", slider, 10)
	# No box round the whole slider: the track is the only ground it needs.
	for state: StringName in STATES + [&"focus"]:
		theme.set_stylebox(state, slider, StyleBoxEmpty.new())
	var on := GradientPill.new()
	on.from_color = palette[&"accent"]
	on.to_color = gradient_end(palette)
	on.radius = PILL
	on.content_margin_left = 22
	on.content_margin_right = 22
	on.content_margin_top = 8
	on.content_margin_bottom = 8
	var off := _box(faded(palette), PILL, 0)
	off.border_color = palette[&"lit"]
	off.set_border_width_all(1)
	off.content_margin_left = 22
	off.content_margin_right = 22
	off.content_margin_top = 8
	off.content_margin_bottom = 8
	for state: StringName in STATES:
		theme.set_stylebox(state, GdChime.Setting.TOGGLE_ON, on)
		theme.set_color(StringName("font_color_" + state), GdChime.Setting.TOGGLE_ON, Color.WHITE)
		theme.set_stylebox(state, GdChime.Setting.TOGGLE_OFF, off)
		theme.set_color(StringName("font_color_" + state), GdChime.Setting.TOGGLE_OFF, palette[&"ink_soft"])
	for toggle: StringName in [GdChime.Setting.TOGGLE_ON, GdChime.Setting.TOGGLE_OFF]:
		theme.set_stylebox(&"focus", toggle, StyleBoxEmpty.new())
	# The gear: a round glowing button, the gear drawn by its box (gear_button.gd).
	theme.set_type_variation(GEAR, GdChime.Themes.PRESSABLE)
	for state: StringName in STATES:
		var lit := state in [&"hover", &"glowing", &"selected", &"accepting"]
		var gear := GearButton.new()
		gear.from_color = second_accent(palette).lightened(0.12 if lit else 0.0)
		gear.to_color = palette[&"accent"].lightened(0.12 if lit else 0.0)
		gear.radius = 200
		gear.glow = Color(second_accent(palette), 0.6 if lit else 0.4)
		gear.glow_size = 12 if lit else 8
		gear.ink = Color.WHITE
		gear.hole = second_accent(palette).lerp(palette[&"accent"], 0.5)
		# an empty button: a finger's least each way (phone.gd) is its size
		gear.set_content_margin_all(8)
		theme.set_stylebox(state, GEAR, gear)
	theme.set_stylebox(&"focus", GEAR, StyleBoxEmpty.new())


## A question asked over everything (gd-chime's Confirm, and a setting's
## choices): a raised card, and its buttons as outlined pills with no focus
## frame - the question opens with the focus on its cancel.
static func _sheets(theme: Theme, palette: Dictionary) -> void:
	var sheet := _box(palette[&"raised"], CORNER, 28)
	sheet.border_color = palette[&"lit"]
	sheet.set_border_width_all(2)
	theme.set_stylebox(&"panel", GdChime.Setting.SHEET, sheet)
	var button: StringName = GdChime.Pressables.BUTTON
	var resting := _box(palette[&"raised"], PILL, 16)
	resting.border_color = palette[&"lit"]
	resting.set_border_width_all(2)
	resting.content_margin_left = 26
	resting.content_margin_right = 26
	var pressed := resting.duplicate() as StyleBoxFlat
	pressed.bg_color = palette[&"lit"]
	for state: StringName in STATES:
		theme.set_stylebox(state, button, pressed if state in [&"hover", &"glowing", &"selected", &"accepting"] else resting)
		theme.set_color(StringName("font_color_" + state), button, palette[&"ink"])
	theme.set_stylebox(&"focus", button, StyleBoxEmpty.new())
	# A menu's items (a long press on a row opens one): rows on the card, lit while pressed.
	var item: StringName = &"MenuItem"
	var quiet := _box(Color(palette[&"lit"], 0.0), CORNER, 14)
	quiet.content_margin_left = 24
	quiet.content_margin_right = 40
	var lit_item := quiet.duplicate() as StyleBoxFlat
	lit_item.bg_color = palette[&"lit"]
	for state: StringName in STATES:
		theme.set_stylebox(state, item, lit_item if state in [&"hover", &"glowing", &"selected", &"accepting"] else quiet)
		theme.set_color(StringName("font_color_" + state), item, palette[&"ink"])
	theme.set_stylebox(&"focus", item, StyleBoxEmpty.new())


## A second button (LINK): the second accent's glowing pill, with the action's words.
static func link(ui: RefCounted, action: StringName, payload: Variant = {}) -> GdChime.Desc:
	return ui.pressable(action, payload, [ui.text(ui.words(action), GdChime.Themes.FACE)], LINK)


## A button that deletes: red and glowing, with the action's words.
static func danger(ui: RefCounted, action: StringName, payload: Variant = {}) -> GdChime.Desc:
	return ui.pressable(action, payload, [ui.text(ui.words(action), GdChime.Themes.FACE)], DANGER)


## A card holding content, pressed as a whole.
static func card(ui: RefCounted, action: StringName, content: Array, payload: Variant = {}) -> GdChime.Desc:
	return ui.pressable(action, payload, [ui.column(content)], CARD)


## A button that can't be used: barely lifted from the ground, its words dim.
static func faded(palette: Dictionary) -> Color:
	return (palette[&"raised"] as Color).lerp(palette[&"ground"], 0.3)


static func faded_words(palette: Dictionary) -> Color:
	return (palette[&"ink_soft"] as Color).lerp(palette[&"ground"], 0.45)


## Where a button's gradient ends: the palette's accent_end, or its accent (no gradient) when it has none.
static func gradient_end(palette: Dictionary) -> Color:
	return palette.get(&"accent_end", palette[&"accent"])


## How the apps move, longer than gd-chime's own so a move is seen: a
## screen pushes the last one out over a third of a second, and a row of a
## list slides in from the right and out again (gd-chime's Motion tokens).
static func _motion(theme: Theme) -> void:
	theme.set_constant(&"quick", &"Motion", 120)
	theme.set_constant(&"normal", &"Motion", 320)
	theme.set_constant(&"slow", &"Motion", 520)
	theme.set_constant(&"stagger", &"Motion", 50)
	GdChime.Transition.defaults(theme, {&"each": GdChime.Transition.FROM_RIGHT})


## Manrope for every word, bolder for titles and headings.
static func _type(theme: Theme) -> void:
	theme.default_font = weighted(WEIGHT)
	for heading: StringName in [GdChime.Themes.TITLE, GdChime.Themes.WORDS]:
		theme.set_font(&"font", heading, weighted(TITLE_WEIGHT))


## Manrope at a weight from 200 to 800.
static func weighted(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = FONT
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {wght: weight}
	return font


## No scroll bars: on a phone a list is swiped, and a bar's reserved strip
## made a list's right margin wider than its left (gd-chime's scroll always
## reserves one).
static func _scroll_bars(theme: Theme) -> void:
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		for part: StringName in [&"scroll", &"scroll_focus", &"grabber", &"grabber_highlight", &"grabber_pressed"]:
			theme.set_stylebox(part, bar, StyleBoxEmpty.new())


## The second accent: the palette's accent_2, or the first accent when it has none.
static func second_accent(palette: Dictionary) -> Color:
	return palette.get(&"accent_2", palette[&"accent"])


static func _box(fill: Color, corner: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(corner)
	box.set_content_margin_all(margin)
	return box
