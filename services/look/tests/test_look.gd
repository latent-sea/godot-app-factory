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


func _init() -> void:
	await process_frame
	var theme := Look.make()
	_claim(theme.has_stylebox(&"panel", Look.PAGE), "the page has a ground")
	_claim(theme.get_font_size(&"font_size", GdChime.Themes.TITLE) == Look.TITLE_SIZE, "a title is the title size on a desktop")
	_claim(theme.get_color(&"font_color", Look.QUIET) == Look.PALETTE[&"ink_soft"], "quiet words are in the soft ink")
	_claim(theme.get_color(&"font_color", Look.MARKED) == Look.PALETTE[&"accent"], "marked words are in the accent")

	var usable := theme.get_stylebox(&"normal", Look.ACTION) as StyleBoxFlat
	_claim(usable != null and usable.bg_color == Look.PALETTE[&"accent"], "a usable button is filled with the accent")
	for state: StringName in [&"inert", &"refusing"]:
		var faded := theme.get_stylebox(state, Look.ACTION) as StyleBoxFlat
		_claim(faded != null and faded.bg_color == Look.FADED, "a button that can't be used is faded while %s" % state)
		_claim(theme.get_color(StringName("font_color_" + state), Look.ACTION) == Look.FADED_WORDS, "and its words are faded while %s" % state)

	var focus := theme.get_stylebox(&"focus", GdChime.Fields.FIELD) as StyleBoxFlat
	_claim(focus != null and focus.border_color == Look.PALETTE[&"accent"], "a field being typed in is outlined in the accent")

	var own := Look.PALETTE.duplicate()
	own[&"accent"] = Color("#8a3ffc")
	var worn := Look.make(own)
	_claim((worn.get_stylebox(&"normal", Look.ACTION) as StyleBoxFlat).bg_color == Color("#8a3ffc"), "an app's own palette is worn")

	# button(): the action's words and no reason line, whatever the action's refusal says.
	var described: GdChime.Desc = Look.button(Builder.new(), &"does_a_thing")
	var kinds: Array = _kinds(described)
	_claim(kinds == [&"pressable", &"text"], "a button is its words and no reason line: %s" % [kinds])

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
