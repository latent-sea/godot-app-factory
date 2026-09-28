extends RefCounted

## The factory's look: one Theme every app wears, built on gd-chime's.
##
## An app preloads this as FactoryLook (ChimeApp already has a member named
## Look) and its look() returns FactoryLook.make(), or FactoryLook.make(palette) with a palette
## of its own. On top of gd-chime's Themes this dresses what gd-chime leaves
## as placeholders, and then sizes it all for a phone (phone.gd):
##   PAGE    the ground a screen stands on, kept off the glass's edges
##   Title   a screen's title, bigger than what is under it
##   QUIET   words that matter less: a done item, a note
##   MARKED  words in the accent: a tick, a small mark
##   QUIET and MARKED: MARKED is in the second accent
##   ACTION  a filled pill in the accent, softly glowing; faded while it can't be used
##   LINK    words in the accent that go somewhere: no box around them
##   CARD    a card a shade lighter than the ground, thinly outlined, pressed as a whole
##   Field   a field (and a TextArea) on the raised ground, outlined in the accent while typing
##
## THE RULES, from using the apps on a phone (docs/look-backlog.md):
## - A control that can't be used looks faded and says nothing more. Use
##   button() rather than gd-chime's ui.button, which always prints the
##   reason under the button, where it reads as a second button.
##
## The builder is taken untyped, as gd-chime's own recipes take it, so a
## test can hand in a stand-in.
##
## Installed into each app as res://addons/factory_look/ by tooling/install.py.

const Phone := preload("phone.gd")
const GradientPill := preload("gradient_pill.gd")
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
}
## Rounded throughout: cards and fields, and buttons as pills.
const CORNER := 16
const PILL := 40
## The room kept between a screen's content and the glass's edge, in base pixels before phone sizing.
const PAGE_MARGIN := 24
const TITLE_SIZE := 44


## The whole look, sized for the screen it runs on.
static func make(palette: Dictionary = PALETTE) -> Theme:
	var theme := GdChime.Themes.new(palette)
	_type(theme)
	_page(theme, palette)
	_words(theme, palette)
	_field(theme, palette)
	_action(theme, palette)
	_link(theme, palette)
	_card(theme, palette)
	_scroll_bars(theme)
	Phone.enlarge(theme, Phone.factor())
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
	var page_box := StyleBoxFlat.new()
	page_box.bg_color = palette[&"ground"]
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


## Words in the accent with no box. No focus ring: gd-chime puts focus on
## a screen's first press when it opens, and on a phone the ring reads as a
## heavy frame round something nobody chose.
static func _link(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(LINK, &"Control")
	var bare := StyleBoxEmpty.new()
	bare.set_content_margin_all(8)
	for state: StringName in STATES + [&"focus"]:
		theme.set_stylebox(state, LINK, bare)
	# gd-chime re-inks a press's words only when its box changes (face.gd's
	# _blend), so the faded states need a box of their own - with one box for
	# every state, a link built faded (a screen's Back before it is shown) kept
	# its faded words after it could be used.
	for state: StringName in [&"inert", &"refusing"]:
		theme.set_stylebox(state, LINK, bare.duplicate())
	for state: StringName in STATES:
		theme.set_color(StringName("font_color_" + state), LINK, palette[&"accent"])
	theme.set_color(&"font_color_inert", LINK, faded_words(palette))


## A card a shade lighter than the ground, outlined in the lit colour, lit a little while pressed.
static func _card(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(CARD, &"Control")
	var resting := _box(palette[&"raised"], CORNER, 22)
	resting.border_color = palette[&"lit"]
	resting.set_border_width_all(2)
	var pressed := resting.duplicate() as StyleBoxFlat
	pressed.bg_color = palette[&"lit"]
	for state: StringName in STATES:
		theme.set_stylebox(state, CARD, pressed if state in [&"hover", &"glowing", &"selected", &"accepting"] else resting)
		theme.set_color(StringName("font_color_" + state), CARD, palette[&"ink"])
	theme.set_stylebox(&"focus", CARD, StyleBoxEmpty.new())


## Words in the accent that act when pressed, with no box: for going somewhere.
static func link(ui: RefCounted, action: StringName, payload: Variant = {}) -> GdChime.Desc:
	return ui.pressable(action, payload, [ui.text(ui.words(action), MARKED)], LINK)


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
