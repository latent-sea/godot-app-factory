extends SceneTree

## phone_look.gd: sizes grow by the factor, everything else stays, and a
## desktop is left alone. Prints PASS test_phone_look.gd, or every claim that did not hold.

const PhoneLook := preload("res://phone_look.gd")
const App := preload("res://checklist.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	_claim(is_equal_approx(PhoneLook.factor(), 1.0), "a desktop run is not enlarged: %s" % PhoneLook.factor())

	var plain := GdChime.Themes.new(App.PALETTE)
	var big := GdChime.Themes.new(App.PALETTE)
	# One stylebox under two types, to check it grows once, not twice.
	var shared := StyleBoxFlat.new()
	shared.set_content_margin_all(10)
	shared.set_corner_radius_all(4)
	big.set_stylebox(&"panel", &"SharedA", shared)
	big.set_stylebox(&"panel", &"SharedB", shared)
	PhoneLook.enlarge(big, 2.5)

	_claim(big.get_font_size(&"font_size", &"Face") == roundi(plain.get_font_size(&"font_size", &"Face") * 2.5), "font sizes grow by the factor")
	_claim(big.default_font_size == roundi(plain.default_font_size * 2.5), "the default font size grows")
	_claim(big.get_constant(&"gap", &"Cells") == roundi(plain.get_constant(&"gap", &"Cells") * 2.5), "a gap grows")
	_claim(big.get_constant(&"glide", &"Motion") == plain.get_constant(&"glide", &"Motion"), "a duration does not")
	_claim(big.get_constant(&"swipe_commit", &"Touch") == plain.get_constant(&"swipe_commit", &"Touch"), "a share in thousandths does not")
	_claim(big.get_constant(&"least", &"Touch") == roundi(PhoneLook.FINGER * 2.5), "a pressable is at least a finger each way")
	_claim(is_equal_approx(shared.get_content_margin(SIDE_LEFT), 25.0) and shared.get_corner_radius(CORNER_TOP_LEFT) == 10, "a stylebox shared by two types grows once: %s" % shared.get_content_margin(SIDE_LEFT))

	var untouched := GdChime.Themes.new(App.PALETTE)
	PhoneLook.enlarge(untouched, 1.0)
	_claim(untouched.get_font_size(&"font_size", &"Face") == plain.get_font_size(&"font_size", &"Face"), "a factor of one changes nothing")

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_phone_look.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
