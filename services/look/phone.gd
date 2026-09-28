extends RefCounted

## Makes a gd-chime look big enough for a phone held in the hand.
##
## gd-chime draws its canvas at a base of 1920x1080 (1080x1920 upright),
## stretched to the window, and its looks are sized for a monitor across a
## desk. On a phone, the same canvas spans a screen a few inches wide, so
## every word and target comes out about a third of the size a finger and
## an eye need. This multiplies a look's sizes by how much smaller the
## screen really is: its short side in density-independent pixels against
## the canvas's short side.
##
## Only sizes are scaled: font sizes, panels' padding, corners and borders,
## and the constants named in PIXELS. Durations, shares in thousandths and
## counts are left alone. The one exception is a pressable's least size,
## which is set to FINGER outright because gd-chime ships it at zero.
##
## Part of the factory's look (look.gd), which applies it last.

## The canvas's short side, in base pixels (needed_settings.gd's base, upright).
const CANVAS_SHORT_SIDE := 1080.0
## Android's density-independent pixel: 160 of them to the inch.
const DP_PER_INCH := 160.0
## The least a pressable is each way, in dp: Android's touch target.
const FINGER := 48.0
## Theme constants that are lengths in base pixels.
const PIXELS: Array[StringName] = [
	&"gap", &"pad", &"air", &"rule", &"mark", &"row_gap", &"option_pad",
	&"more_room", &"drag_edge", &"handle_width", &"track_thickness",
	&"least_width", &"least_height", &"least_column", &"least_track",
	&"slop", &"compact_below", &"wide_from", &"dead_band",
	&"line_width", &"marker_radius", &"tick_width", &"outline_width",
	&"picked_width", &"hatch_gap", &"thick", &"step",
]
## How big the look is against gd-chime's monitor sizes once the screen's
## smallness is made up: a share a person chooses in Settings (the settings
## service), 0.65 at first. gd-chime's words at full size came out about
## twice Android's usual 14-16 dp, too chunky in the hand.
const DEFAULT_SIZE := 0.65
## Where Settings keeps it: this file, under this section, as "text_size".
## Read here once, as the first look is made, since the look comes before
## any model; after that Settings sets chosen_size itself.
const SETTINGS_FILE := "user://factory_settings.json"
const SECTION := "factory"
## The share chosen, or below zero until it has been read.
static var chosen_size := -1.0
## Stretch the dp count of a phone's short side can be forced to, for a
## screenshot on a desktop: `-- --phone-dp=411`.
const FORCE_SWITCH := "--phone-dp="


## How many times bigger this screen needs the look: 1 on a desktop,
## about 1.7 on a phone 411 dp across at the first text size (2.6 at full size).
static func factor() -> float:
	return clampf(dp_scale() * text_size(), 1.0, 4.0)


## Base pixels per dp: how much bigger the screen needs anything measured in
## dp, whatever the text size - a finger is the same size at every text size.
## 1 on a desktop, about 2.6 on a phone 411 dp across.
static func dp_scale() -> float:
	var short_dp := _forced_short_dp()
	if short_dp <= 0.0:
		if not OS.has_feature("mobile"):
			return 1.0
		var screen := DisplayServer.screen_get_size()
		var dpi := float(DisplayServer.screen_get_dpi())
		if dpi <= 0.0:
			return 1.0
		short_dp = minf(screen.x, screen.y) / (dpi / DP_PER_INCH)
	return clampf(CANVAS_SHORT_SIDE / short_dp, 1.0, 4.0)


## The share of gd-chime's sizes a person chose, read from Settings' file
## the first time; DEFAULT_SIZE when nothing was chosen or the file won't read.
static func text_size() -> float:
	if chosen_size < 0.0:
		chosen_size = DEFAULT_SIZE
		# JSON.parse, not parse_string: a file that won't read is quietly the first size, not an error.
		var reading := JSON.new()
		var kept: Variant = reading.data if FileAccess.file_exists(SETTINGS_FILE) and reading.parse(FileAccess.get_file_as_string(SETTINGS_FILE)) == OK else null
		if kept is Dictionary and kept.get(SECTION) is Dictionary and (kept[SECTION].get("text_size") is float or kept[SECTION].get("text_size") is int):
			chosen_size = clampf(kept[SECTION]["text_size"], 0.5, 1.0)
	return chosen_size


## The look, every size in it multiplied by `by`.
## A finger's least is FINGER dp at `finger` base pixels per dp (dp_scale()),
## which is `by` unless said: at a small text size, words shrink but a
## finger doesn't.
static func enlarge(theme: Theme, by: float, finger: float = by) -> void:
	theme.set_constant(&"least", &"Touch", roundi(FINGER * finger))
	if is_equal_approx(by, 1.0):
		return
	theme.default_font_size = _times(theme.default_font_size, by)
	# One stylebox can stand under several types; each is enlarged once.
	var enlarged := {}
	for type: StringName in theme.get_type_list():
		for name: StringName in theme.get_font_size_list(type):
			theme.set_font_size(name, type, _times(theme.get_font_size(name, type), by))
		for name: StringName in theme.get_constant_list(type):
			if name in PIXELS:
				theme.set_constant(name, type, _times(theme.get_constant(name, type), by))
		for name: StringName in theme.get_stylebox_list(type):
			var box := theme.get_stylebox(name, type)
			if box != null and not enlarged.has(box.get_instance_id()):
				enlarged[box.get_instance_id()] = true
				_enlarge_box(box, by)


static func _enlarge_box(box: StyleBox, by: float) -> void:
	# A style box of the factory's own (gradient_pill.gd) knows its own sizes.
	if box.has_method(&"enlarge"):
		box.enlarge(by)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var margin := box.get_content_margin(side)
		if margin > 0.0:
			box.set_content_margin(side, margin * by)
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			flat.set_border_width(side, _times(flat.get_border_width(side), by))
			flat.set_expand_margin(side, flat.get_expand_margin(side) * by)
		for corner: int in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT]:
			flat.set_corner_radius(corner, _times(flat.get_corner_radius(corner), by))
		flat.shadow_size = _times(flat.shadow_size, by)
		flat.shadow_offset *= by
	elif box is StyleBoxLine:
		var line := box as StyleBoxLine
		line.thickness = _times(line.thickness, by)
		line.grow_begin *= by
		line.grow_end *= by


static func _times(size: int, by: float) -> int:
	return roundi(size * by)


static func _forced_short_dp() -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(FORCE_SWITCH):
			return arg.trim_prefix(FORCE_SWITCH).to_float()
	return 0.0
