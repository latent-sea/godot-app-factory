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
##   ACTION  a filled button; faded to nearly white while it can't be used
##   LINK    words in the accent that go somewhere: no box around them
##   CARD    a white card, softly outlined, pressed as a whole
##   Field   a white field outlined, in the accent while typing
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

## The theme types this look adds; pass them as a style.
const PAGE := &"FactoryPage"
const QUIET := &"FactoryQuiet"
const MARKED := &"FactoryMarked"
const ACTION := &"FactoryAction"
const LINK := &"FactoryLink"
const CARD := &"FactoryCard"
## Every state gd-chime draws a pressable in (face.gd), and its focus.
const STATES: Array[StringName] = [&"normal", &"hover", &"inert", &"current", &"glowing", &"selected", &"lifted", &"accepting", &"refusing", &"listening"]

## The factory's palette: teal on a cool, quiet ground. The seven keys are
## the ones gd-chime's Themes reads; an app's own palette needs all seven.
const PALETTE := {
	&"ground": Color("#f3f5f7"),
	&"raised": Color("#ffffff"),
	&"lit": Color("#dfe7ec"),
	&"ink": Color("#17212b"),
	&"ink_soft": Color("#4a5866"),
	&"accent": Color("#0e6b70"),
	&"shade": Color(0.09, 0.13, 0.17, 0.55),
}
## A button that can't be used: faded grey, nearly white.
const FADED := Color("#e9edf0")
const FADED_WORDS := Color("#aab4bd")
## The room kept between a screen's content and the glass's edge, in base pixels before phone sizing.
const PAGE_MARGIN := 24
const TITLE_SIZE := 44


## The whole look, sized for the screen it runs on.
static func make(palette: Dictionary = PALETTE) -> Theme:
	var theme := GdChime.Themes.new(palette)
	_page(theme, palette)
	_words(theme, palette)
	_field(theme, palette)
	_action(theme, palette)
	_link(theme, palette)
	_card(theme, palette)
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
	theme.set_color(&"font_color", MARKED, palette[&"accent"])


static func _field(theme: Theme, palette: Dictionary) -> void:
	var resting := _box(palette[&"raised"], 8, 12)
	resting.border_color = palette[&"ink_soft"]
	resting.set_border_width_all(2)
	var typing := _box(palette[&"raised"], 8, 12)
	typing.border_color = palette[&"accent"]
	typing.set_border_width_all(3)
	theme.set_stylebox(&"normal", GdChime.Fields.FIELD, resting)
	theme.set_stylebox(&"read_only", GdChime.Fields.FIELD, resting)
	theme.set_stylebox(&"focus", GdChime.Fields.FIELD, typing)
	theme.set_color(&"font_color", GdChime.Fields.FIELD, palette[&"ink"])
	theme.set_color(&"caret_color", GdChime.Fields.FIELD, palette[&"accent"])


static func _action(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(ACTION, GdChime.Themes.PRESSABLE)
	var accent: Color = palette[&"accent"]
	for state: StringName in [&"normal", &"hover", &"glowing"]:
		theme.set_stylebox(state, ACTION, _box(accent if state == &"normal" else accent.darkened(0.25), 12, 16))
		theme.set_color(StringName("font_color_" + state), ACTION, palette[&"raised"])
	# gd-chime draws a button that can't be used as inert, and flashes refusing when it is pressed anyway.
	for state: StringName in [&"inert", &"refusing"]:
		theme.set_stylebox(state, ACTION, _box(FADED, 12, 16))
		theme.set_color(StringName("font_color_" + state), ACTION, FADED_WORDS)


## Words in the accent with no box. No focus ring: gd-chime puts focus on
## a screen's first press when it opens, and on a phone the ring reads as a
## heavy frame round something nobody chose.
static func _link(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(LINK, &"Control")
	var bare := StyleBoxEmpty.new()
	bare.set_content_margin_all(8)
	for state: StringName in STATES + [&"focus"]:
		theme.set_stylebox(state, LINK, bare)
	for state: StringName in STATES:
		theme.set_color(StringName("font_color_" + state), LINK, palette[&"accent"])
	theme.set_color(&"font_color_inert", LINK, FADED_WORDS)


## A white card outlined in the lit colour, lit a little while pressed.
static func _card(theme: Theme, palette: Dictionary) -> void:
	theme.set_type_variation(CARD, &"Control")
	var resting := _box(palette[&"raised"], 12, 20)
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


static func _box(fill: Color, corner: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(corner)
	box.set_content_margin_all(margin)
	return box
