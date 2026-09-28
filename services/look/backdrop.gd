extends StyleBox

## The ground every screen stands on: navy deepening to violet down the
## screen, and two soft pools of light - the accent and the second accent -
## drifting slowly across it. gd-chime draws a ground whose style sets the
## moves constant again as its one clock moves on, handing it the clock's
## time: so it holds still under reduced motion, over the frame budget, and
## in a test or screenshot that steps the clock by hand.

## The ground at the top and at the bottom.
@export var top := Color.BLACK
@export var bottom := Color.BLACK
## The two pools' colours; their alpha is how strong they are.
@export var glow_a := Color.TRANSPARENT
@export var glow_b := Color.TRANSPARENT
## How many seconds one drift round takes.
@export var period := 24.0
## The clock's time as gd-chime draws it, in seconds (surface.gd sets it).
var time := 0.0

static var _pool: GradientTexture2D


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	RenderingServer.canvas_item_add_polygon(to_canvas_item, corners, PackedColorArray([top, top, bottom, bottom]))
	var turn := TAU * fmod(time, period) / period
	var reach := maxf(rect.size.x, rect.size.y) * 0.45
	_glow(to_canvas_item, rect, Vector2(0.25 + 0.15 * sin(turn), 0.2 + 0.08 * cos(turn * 2.0)), reach, glow_a)
	_glow(to_canvas_item, rect, Vector2(0.8 + 0.12 * cos(turn), 0.75 + 0.1 * sin(turn)), reach * 1.1, glow_b)


## A soft pool of light: the radial texture, tinted, centred at this share of the rect.
func _glow(to_canvas_item: RID, rect: Rect2, at: Vector2, reach: float, colour: Color) -> void:
	if colour.a <= 0.0:
		return
	var centre := rect.position + rect.size * at
	var square := Rect2(centre - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	RenderingServer.canvas_item_add_texture_rect(to_canvas_item, square, pool().get_rid(), false, colour)


## White at the middle fading to nothing at the edge, made once.
static func pool() -> GradientTexture2D:
	if _pool == null:
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.5, Color(1, 1, 1, 0.35))
		_pool = GradientTexture2D.new()
		_pool.gradient = fade
		_pool.fill = GradientTexture2D.FILL_RADIAL
		_pool.fill_from = Vector2(0.5, 0.5)
		_pool.fill_to = Vector2(1.0, 0.5)
		_pool.width = 128
		_pool.height = 128
	return _pool
