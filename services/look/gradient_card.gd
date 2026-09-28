extends StyleBox

## A card: a rounded fill a shade lighter than the ground, edged by a thin
## line that runs from the accent to the second accent - light caught on the
## edge of glass. Drawn as two rounded shapes (gradient_pill.gd's outline):
## the edge's gradient, and the fill over it, inset by the edge's width.

const GradientPill := preload("gradient_pill.gd")

## The edge: its colour at the left and at the right, and how wide it is.
@export var edge_from := Color.WHITE
@export var edge_to := Color.WHITE
@export var edge := 2.0
## The fill, from its top to its bottom.
@export var fill_top := Color.BLACK
@export var fill_bottom := Color.BLACK
@export var radius := 16.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var outer := GradientPill.outline(rect, radius)
	var colours := PackedColorArray()
	for point: Vector2 in outer:
		colours.append(edge_from.lerp(edge_to, clampf((point.x - rect.position.x) / maxf(rect.size.x, 1.0), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, colours)
	var inside := rect.grow(-edge)
	var inner := GradientPill.outline(inside, maxf(radius - edge, 0.0))
	colours = PackedColorArray()
	for point: Vector2 in inner:
		colours.append(fill_top.lerp(fill_bottom, clampf((point.y - inside.position.y) / maxf(inside.size.y, 1.0), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, inner, colours)


## Every size in it multiplied by `by` (the factory's phone sizing calls this).
func enlarge(by: float) -> void:
	radius *= by
	edge = maxf(1.0, edge * by)
