extends StyleBox

## A rounded box filled with a gradient from left to right, with an
## optional soft glow around it - the factory's filled button. Godot's own
## StyleBoxFlat has rounded corners but no gradient, and a texture can't
## keep its corners round at every width, so this draws the shape itself:
## one polygon, each point coloured by where it lies across the box.

## The colour at the left edge and at the right.
@export var from_color := Color.WHITE
@export var to_color := Color.WHITE
## The corners' radius, in pixels; capped at half the box's height, which makes a pill.
@export var radius := 40.0
## A glow of this colour around the box, fading out over glow_size pixels. None while clear.
@export var glow := Color(0, 0, 0, 0)
@export var glow_size := 0.0

## How many points make each corner's quarter circle.
const CORNER_POINTS := 10
## How many rings the glow is drawn in, each fainter and wider than the last.
const GLOW_RINGS := 4


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# too small to have a shape: nothing to draw
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	if glow.a > 0.0 and glow_size > 0.0:
		for ring: int in range(GLOW_RINGS, 0, -1):
			var grown := rect.grow(glow_size * ring / GLOW_RINGS)
			var faint := Color(glow, glow.a / (GLOW_RINGS + 1) * (GLOW_RINGS - ring + 1) / GLOW_RINGS)
			var points := outline(grown, radius + glow_size * ring / GLOW_RINGS)
			RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([faint]))
	var shape := outline(rect, radius)
	var colours := PackedColorArray()
	for point: Vector2 in shape:
		colours.append(from_color.lerp(to_color, clampf((point.x - rect.position.x) / maxf(rect.size.x, 1.0), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, shape, colours)


## Every size in it multiplied by `by` (the factory's phone sizing calls this).
func enlarge(by: float) -> void:
	radius *= by
	glow_size *= by


## The rounded box's outline, clockwise from its top left corner.
static func outline(rect: Rect2, corner: float) -> PackedVector2Array:
	var r := minf(corner, minf(rect.size.x, rect.size.y) / 2.0)
	var points := PackedVector2Array()
	# Each corner: its centre, and the angle its quarter circle starts at.
	var corners := [
		[rect.position + Vector2(r, r), PI],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5],
		[rect.end - Vector2(r, r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
	]
	for corner_at: Array in corners:
		for step: int in CORNER_POINTS + 1:
			var angle: float = corner_at[1] + PI * 0.5 * step / CORNER_POINTS
			var point: Vector2 = corner_at[0] + Vector2(cos(angle), sin(angle)) * r
			# where a side has no length (a circle, a pill's ends) two corners meet
			# at one point: the same point twice is no polygon the engine can fill
			if points.is_empty() or not point.is_equal_approx(points[-1]):
				points.append(point)
	if points.size() > 1 and points[0].is_equal_approx(points[-1]):
		points.remove_at(points.size() - 1)
	return points
