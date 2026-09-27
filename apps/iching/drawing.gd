extends RefCounted

## How a hexagram and the square are drawn. Each takes the control it draws
## on and the value it shows; colours come from the look, under its style.
##
## A hexagram's six places run bottom to top. A cast line is a bar, or two
## with a gap for yin; an old line carries its traditional mark to the right
## - a circle for old yang, a cross for old yin. A place not yet cast is a
## faint outline, so the hexagram's shape is there from the first tap.

const H := preload("res://hexagrams.gd")

## Theme types, with their colours: line and faint for a hexagram, ground and edge for the square.
const HEXAGRAM := &"Hexagram"
const SQUARE := &"CastSquare"
## The hexagram's width, as a share of its height; its bars take this share of that, the marks the rest.
const WIDTH_PER_HEIGHT := 1.25
const BARS_SHARE := 0.78


## A hexagram: lines as their numbers 6-9, from the bottom; fewer than six leaves the rest faint.
static func hexagram(on: Control, lines: Variant) -> void:
	var cast: Array = lines if lines is Array else []
	var ink := on.get_theme_color(&"line", HEXAGRAM)
	var faint := on.get_theme_color(&"faint", HEXAGRAM)
	var height := on.size.y
	var width := minf(on.size.x, height * WIDTH_PER_HEIGHT)
	var left := (on.size.x - width) / 2.0
	var bars := width * BARS_SHARE
	var step := height / H.LINES
	var thick := step * 0.5
	var gap := bars * 0.14
	for place: int in H.LINES:
		var top := height - (place + 1) * step + (step - thick) / 2.0
		if place >= cast.size():
			on.draw_rect(Rect2(left, top, bars, thick), faint, false, maxf(1.0, thick * 0.08))
			continue
		var line: int = cast[place]
		if H.is_yang(line):
			on.draw_rect(Rect2(left, top, bars, thick), ink)
		else:
			var half := (bars - gap) / 2.0
			on.draw_rect(Rect2(left, top, half, thick), ink)
			on.draw_rect(Rect2(left + half + gap, top, half, thick), ink)
		var mark_at := Vector2(left + bars + (width - bars) / 2.0, top + thick / 2.0)
		var mark := thick * 0.42
		var stroke := maxf(2.0, thick * 0.14)
		if line == H.OLD_YANG:
			on.draw_arc(mark_at, mark, 0.0, TAU, 32, ink, stroke, true)
		elif line == H.OLD_YIN:
			on.draw_line(mark_at + Vector2(-mark, -mark), mark_at + Vector2(mark, mark), ink, stroke, true)
			on.draw_line(mark_at + Vector2(-mark, mark), mark_at + Vector2(mark, -mark), ink, stroke, true)


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
