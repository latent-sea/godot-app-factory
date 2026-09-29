extends SceneTree

## look.gd: the factory's types are dressed, a disabled button is faded and
## says nothing, and an app's own palette is worn. Runs inside any app that
## installs the look. Prints PASS test_look.gd, or every claim that did not hold.

const Look := preload("res://addons/factory_look/look.gd")

var _failed: Array[String] = []


## Stands in for gd-chime's builder, making the descriptions it would.
class Builder extends RefCounted:
	func words(action: StringName) -> String:
		return str(action)

	func text(content: Variant, style: Variant = &"") -> GdChime.Desc:
		return GdChime.Desc.new(&"text", {"content": content, "style": style})

	func reason(style: Variant = &"") -> GdChime.Desc:
		return GdChime.Desc.new(&"reason", {"style": style})

	func pressable(action: StringName, payload: Variant, content: Array, style: Variant) -> GdChime.Desc:
		return GdChime.Desc.new(&"pressable", {"action": action, "payload": payload, "style": style}, content)

	func column(content: Array, style: Variant = &"Column") -> GdChime.Desc:
		return GdChime.Desc.new(&"column", {"style": style}, content)


func _init() -> void:
	await process_frame
	var theme := Look.make()
	_claim(theme.has_stylebox(&"panel", Look.PAGE), "the page has a ground")
	_claim(theme.get_font_size(&"font_size", GdChime.Themes.TITLE) == Look.TITLE_SIZE, "a title is the title size on a desktop")
	_claim(theme.get_color(&"font_color", Look.QUIET) == Look.PALETTE[&"ink_soft"], "quiet words are in the soft ink")
	_claim(theme.get_color(&"font_color", Look.MARKED) == Look.PALETTE[&"accent_2"], "marked words are in the second accent")

	var usable := theme.get_stylebox(&"normal", Look.ACTION)
	_claim(usable is Look.GradientPill and usable.from_color == Look.PALETTE[&"accent"] and usable.to_color == Look.PALETTE[&"accent_end"], "a usable button is a gradient from the accent to its end")
	_claim(theme.default_font is FontVariation and (theme.default_font as FontVariation).base_font == Look.FONT, "every word is in the factory's font")
	_claim(theme.get_font(&"font", GdChime.Themes.TITLE) != theme.default_font, "titles have a font of their own, bolder")
	var room := theme.get_stylebox(&"panel", &"Scroll")
	_claim(room != null and room.content_margin_left == room.content_margin_right, "a list keeps equal room either side")
	_claim(theme.get_constant(&"thickness", &"ScrollIndicator") > 0, "where the reader is in a list shows")
	var pill := Look.GradientPill.new()
	pill.radius = 10.0
	pill.glow_size = 4.0
	pill.enlarge(2.5)
	_claim(is_equal_approx(pill.radius, 25.0) and is_equal_approx(pill.glow_size, 10.0), "a gradient pill grows with phone sizing")
	var shape: PackedVector2Array = Look.GradientPill.outline(Rect2(0, 0, 200, 60), 100.0)
	var inside := shape.size() > 0
	for point: Vector2 in shape:
		inside = inside and point.x >= -0.01 and point.x <= 200.01 and point.y >= -0.01 and point.y <= 60.01
	_claim(inside, "a pill's outline stays inside its box, its radius capped at half its height")
	for state: StringName in [&"inert", &"refusing"]:
		var faded := theme.get_stylebox(state, Look.ACTION) as StyleBoxFlat
		_claim(faded != null and faded.bg_color == Look.faded(Look.PALETTE), "a button that can't be used is faded while %s" % state)
		_claim(theme.get_color(StringName("font_color_" + state), Look.ACTION) == Look.faded_words(Look.PALETTE), "and its words are faded while %s" % state)

	var focus := theme.get_stylebox(&"focus", GdChime.Fields.FIELD) as StyleBoxFlat
	_claim(focus != null and focus.border_color == Look.PALETTE[&"accent"], "a field being typed in is outlined in the accent")

	_claim(theme.get_stylebox(&"focus", Look.LINK) is StyleBoxEmpty and theme.get_stylebox(&"focus", Look.CARD) is StyleBoxEmpty, "links and cards draw no focus frame")
	for kind: StringName in [Look.LINK, Look.DANGER]:
		var lesser := theme.get_stylebox(&"normal", kind) as Look.GradientPill
		_claim(lesser != null and lesser.glow.a > 0.0 and lesser.from_color != lesser.to_color, "a %s is a glowing gradient pill, never bare words" % kind)
		_claim(theme.get_stylebox(&"inert", kind) is StyleBoxFlat, "and faded while it can't be used")
	_claim((theme.get_stylebox(&"normal", Look.LINK) as Look.GradientPill).from_color == Look.PALETTE[&"accent_2"], "a lesser button is in the second accent")
	_claim(theme.get_stylebox(&"normal", Look.GEAR) is Look.GearButton, "the gear is a round button that draws its gear itself")
	var backdrop := theme.get_stylebox(&"panel", Look.PAGE) as Look.Backdrop
	_claim(backdrop != null and backdrop.top == Look.PALETTE[&"ground"] and backdrop.bottom == Look.PALETTE[&"ground_deep"], "the page deepens from navy to violet")
	_claim(theme.get_stylebox(&"inert", Look.LINK) != theme.get_stylebox(&"normal", Look.LINK), "a faded link has a box of its own, so its words are inked again once it can be used")
	var card := theme.get_stylebox(&"normal", Look.CARD) as Look.GradientCard
	_claim(card != null and card.fill_bottom == Look.PALETTE[&"raised"] and card.edge_from.to_html(false) == Look.PALETTE[&"accent"].to_html(false) and card.edge_to.to_html(false) == Look.PALETTE[&"accent_2"].to_html(false), "a card is raised, its edge from the accent to the second accent")
	_claim(theme.get_constant(&"press_scale", &"Motion") < 1000, "a button gives under a finger (gd-chime's press scale)")
	_claim(theme.get_constant(&"moves", Look.PAGE) != 0, "the page's ground moves on gd-chime's clock")
	_claim(theme.get_color(&"gradient_from", GdChime.Themes.TITLE) != theme.get_color(&"gradient_to", GdChime.Themes.TITLE), "a title's words are graded between two colours")
	_claim(theme.get_constant(&"normal", &"Motion") >= 300 and theme.get_constant(&"each", &"Motion") == GdChime.Transition.KINDS.find(GdChime.Transition.FROM_RIGHT), "moves last long enough to be seen, and a list's rows slide")
	# Faded must read as off: dimmer than a usable button's words, whatever the palette.
	var usable_words: Color = theme.get_color(&"font_color_normal", Look.ACTION)
	var off_words: Color = Look.faded_words(Look.PALETTE)
	var ground: Color = Look.PALETTE[&"ground"]
	_claim(absf(off_words.get_luminance() - ground.get_luminance()) < absf(usable_words.get_luminance() - ground.get_luminance()), "faded words stand out less from the ground than a usable button's")
	var no_second := Look.PALETTE.duplicate()
	no_second.erase(&"accent_2")
	_claim(Look.second_accent(no_second) == Look.PALETTE[&"accent"], "a palette with one accent uses it for marks too")

	var own := Look.PALETTE.duplicate()
	own[&"accent"] = Color("#8a3ffc")
	var worn := Look.make(own)
	_claim(worn.get_stylebox(&"normal", Look.ACTION).from_color == Color("#8a3ffc"), "an app's own palette is worn")
	var flat := Look.PALETTE.duplicate()
	flat.erase(&"accent_end")
	_claim(Look.gradient_end(flat) == Look.PALETTE[&"accent"], "a palette with no gradient end fills buttons with its accent alone")

	# button(): the action's words and no reason line, whatever the action's refusal says.
	var described: GdChime.Desc = Look.button(Builder.new(), &"does_a_thing")
	var kinds: Array = _kinds(described)
	_claim(kinds == [&"pressable", &"text"], "a button is its words and no reason line: %s" % [kinds])
	_claim(_kinds(Look.link(Builder.new(), &"goes")) == [&"pressable", &"text"], "a link is its words and no reason line")
	_claim(Look.link(Builder.new(), &"goes").props["style"] == Look.LINK, "a link wears the link style")
	_claim(Look.card(Builder.new(), &"opens", []).props["style"] == Look.CARD, "a card wears the card style")

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_look.gd")
	quit(0 if _failed.is_empty() else 1)


## Every kind in a description, depth first.
func _kinds(desc: GdChime.Desc) -> Array:
	var found: Array = [desc.kind]
	for child: Variant in desc.children:
		if child is GdChime.Desc:
			found += _kinds(child)
	return found


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
