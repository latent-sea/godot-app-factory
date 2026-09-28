extends "gradient_pill.gd"

## The button that opens settings: a glowing gradient circle with a gear in
## it. The gear is drawn by the box, not by a drawing inside the button - a
## drawing laid over a button takes the taps meant for it.

## The gear's colour.
@export var ink := Color.WHITE
## The ground showing through the gear's middle.
@export var hole := Color.BLACK
## How wide and tall it is at least: a finger's target (look.gd sets it to
## the Touch least once the look is sized). An empty button asks its box for
## its size, and a box that asks for nothing made the gear a sliver.
@export var side := 48.0


func _get_minimum_size() -> Vector2:
	return Vector2(side, side)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# always a circle, in the middle of whatever room it is given
	var side := minf(rect.size.x, rect.size.y)
	var centre := rect.get_center()
	super(to_canvas_item, Rect2(centre - Vector2(side, side) / 2.0, Vector2(side, side)))
	var outer := side * 0.3
	var inner := side * 0.22
	var teeth := 8
	var points := PackedVector2Array()
	for step: int in teeth * 4:
		var angle := TAU * step / (teeth * 4.0)
		points.append(centre + Vector2.from_angle(angle) * (outer if step % 4 < 2 else inner))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([ink]))
	RenderingServer.canvas_item_add_circle(to_canvas_item, centre, side * 0.09, hole)
