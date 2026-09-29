extends RefCounted

## How a hexagram and the square are drawn. Each takes the control it draws
## on and the value it shows; colours come from the look, under its style.
##
## A hexagram's six places run bottom to top. A cast line is a bar, or two
## with a gap for yin; an old line carries its traditional mark to the right
## - a circle for old yang, a cross for old yin. A place not yet cast is a
## faint outline, so the hexagram's shape is there from the first tap.

const H := preload("res://hexagrams.gd")

## Theme types, with their colours: line, faint and mark for a hexagram,
## caption with its caption_size for its number, and arrow; ground and edge
## for the square.
const HEXAGRAM := &"Hexagram"
const SQUARE := &"CastSquare"
## A hexagram's bars are this wide for its height, and the room each side of
## them this share of its height: the marks stand in the room on the right,
## and the same room is left on the left, so the bars stay in the middle.
const BARS_PER_HEIGHT := 0.95
const ROOM_PER_HEIGHT := 0.16
## The gap between a hexagram and its number, a share of the number's line.
const CAPTION_GAP := 0.35
## The arrow between a hexagram and the one it changes to, in number lines.
const ARROW_LINES := 2.2


## A hexagram: lines as their numbers 6-9, from the bottom; fewer than six leaves the rest faint.
## As large as the space holds, in its middle.
static func hexagram(on: Control, lines: Variant) -> void:
	_figure(on, Rect2(Vector2.ZERO, on.size), lines, "")


## A cast and what it changes to, as [lines, changed lines]; with nothing
## changed, the cast alone. Each is numbered under it, and the two stand side
## by side or one above the other, whichever draws them larger, with an
## arrow between them - all in the middle of the space.
static func cast_and_change(on: Control, pair: Variant) -> void:
	var lines: Variant = pair[0] if pair is Array and pair.size() > 0 else []
	var turned: Variant = pair[1] if pair is Array and pair.size() > 1 else []
	var whole := Rect2(Vector2.ZERO, on.size)
	if not (turned is Array) or turned.is_empty():
		_figure(on, whole, lines, caption(lines))
		return
	var arrow := _words_height(on) * ARROW_LINES
	var across := Vector2((on.size.x - arrow) / 2.0, on.size.y)
	var down := Vector2(on.size.x, (on.size.y - arrow) / 2.0)
	var words := _words_height(on) * (1.0 + CAPTION_GAP)
	var side_by_side := _fitted(across, words) >= _fitted(down, words)
	var cell := across if side_by_side else down
	var second := Vector2(cell.x + arrow, 0.0) if side_by_side else Vector2(0.0, cell.y + arrow)
	_figure(on, Rect2(Vector2.ZERO, cell), lines, caption(lines))
	_figure(on, Rect2(second, cell), turned, caption(turned))
	# the arrow, level with the hexagrams' middles, not their numbers'
	var middle := Vector2(cell.x + arrow / 2.0, (on.size.y - words) / 2.0) if side_by_side else Vector2(on.size.x / 2.0, cell.y + arrow / 2.0)
	var way := Vector2.RIGHT if side_by_side else Vector2.DOWN
	var reach := arrow * 0.3
	var colour := on.get_theme_color(&"arrow", HEXAGRAM)
	var stroke := maxf(2.0, arrow * 0.06)
	var tip := middle + way * reach
	on.draw_line(middle - way * reach, tip, colour, stroke, true)
	on.draw_line(tip, tip - way.rotated(0.6) * reach * 0.6, colour, stroke, true)
	on.draw_line(tip, tip - way.rotated(-0.6) * reach * 0.6, colour, stroke, true)


## The words under a whole hexagram: "Hexagram 47"; nothing under one not yet cast.
static func caption(lines: Variant) -> String:
	return "Hexagram %d" % H.number(H.first(lines)) if lines is Array and lines.size() == H.LINES else ""


static func _words_height(on: Control) -> float:
	return on.get_theme_font(&"font", &"Label").get_height(on.get_theme_constant(&"caption_size", HEXAGRAM))


## A hexagram's height in a space this size with this much under it for its number.
static func _fitted(space: Vector2, words: float) -> float:
	return maxf(0.0, minf(space.y - words, space.x / (BARS_PER_HEIGHT + 2.0 * ROOM_PER_HEIGHT)))


static func _figure(on: Control, area: Rect2, lines: Variant, words: String) -> void:
	var cast: Array = lines if lines is Array else []
	var ink := on.get_theme_color(&"line", HEXAGRAM)
	var marked := on.get_theme_color(&"mark", HEXAGRAM)
	var faint := on.get_theme_color(&"faint", HEXAGRAM)
	var font := on.get_theme_font(&"font", &"Label")
	var font_size := on.get_theme_constant(&"caption_size", HEXAGRAM)
	var words_height := 0.0 if words.is_empty() else _words_height(on) * (1.0 + CAPTION_GAP)
	var height := _fitted(area.size, words_height)
	var bars := height * BARS_PER_HEIGHT
	var room := height * ROOM_PER_HEIGHT
	var left := area.position.x + (area.size.x - bars) / 2.0
	var top := area.position.y + (area.size.y - height - words_height) / 2.0
	var step := height / H.LINES
	var thick := step * 0.5
	var gap := bars * 0.14
	for place: int in H.LINES:
		var y := top + height - (place + 1) * step + (step - thick) / 2.0
		if place >= cast.size():
			on.draw_rect(Rect2(left, y, bars, thick), faint, false, maxf(1.0, thick * 0.08))
			continue
		var line: int = cast[place]
		if H.is_yang(line):
			on.draw_rect(Rect2(left, y, bars, thick), ink)
		else:
			var half := (bars - gap) / 2.0
			on.draw_rect(Rect2(left, y, half, thick), ink)
			on.draw_rect(Rect2(left + half + gap, y, half, thick), ink)
		var mark_at := Vector2(left + bars + room / 2.0, y + thick / 2.0)
		var mark := minf(thick * 0.42, room * 0.4)
		var stroke := maxf(2.0, thick * 0.14)
		if line == H.OLD_YANG:
			on.draw_arc(mark_at, mark, 0.0, TAU, 32, marked, stroke, true)
		elif line == H.OLD_YIN:
			on.draw_line(mark_at + Vector2(-mark, -mark), mark_at + Vector2(mark, mark), marked, stroke, true)
			on.draw_line(mark_at + Vector2(-mark, mark), mark_at + Vector2(mark, -mark), marked, stroke, true)
	if not words.is_empty():
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := top + height + words_height - font.get_descent(font_size)
		on.draw_string(font, Vector2(area.position.x + (area.size.x - width) / 2.0, baseline), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, on.get_theme_color(&"caption", HEXAGRAM))


## The square: one plain surface, the largest square the space holds, in its middle.
static func square(on: Control, _shown: Variant) -> void:
	var side := minf(on.size.x, on.size.y)
	var area := Rect2((on.size - Vector2(side, side)) / 2.0, Vector2(side, side))
	on.draw_rect(area, on.get_theme_color(&"ground", SQUARE))
	on.draw_rect(area, on.get_theme_color(&"edge", SQUARE), false, maxf(1.0, side * 0.004))


## The cell under a point of the unit square: 8 across, 8 down.
static func cell_at(point: Vector2) -> Variant:
	if point.x < 0.0 or point.y < 0.0 or point.x >= 1.0 or point.y >= 1.0:
		return null
	return int(point.y * 8.0) * 8 + int(point.x * 8.0)
