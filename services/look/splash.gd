extends Control

## The loading screen as drawn: the boot image (splash.png: "Latensea" over
## "PRODUCTIONS" on the navy ground) fitted to the screen exactly as Godot
## fits it while the engine starts (boot_splash/stretch_mode Keep), and a
## gentle wave flowing under it from the accent to the second accent.
##
## Because the image lands in the same place, the change from Godot's boot
## screen to this one shows only as the wave beginning to move.
## opening.gd puts this over the app as it loads, then fades it away.
## The words are an image, so a probe reading the screen never finds them.

const IMAGE := preload("splash.png")
const PALETTE := {
	&"ground": Color("#121829"),
	&"accent": Color("#19c3b3"),
	&"accent_2": Color("#7c5cff"),
}
## Where the wave is, in the image's own pixels: its centre, width and height.
const WAVE_AT := Vector2(540, 660)
const WAVE_WIDTH := 520.0
const WAVE_HEIGHT := 26.0
const WAVE_THICKNESS := 7.0
## How far the wave travels each second, in waves.
const SPEED := 0.6

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE[&"ground"])
	var fitted := fit(IMAGE.get_size(), size)
	draw_texture_rect(IMAGE, fitted, false)
	var scale := fitted.size.x / IMAGE.get_size().x
	_wave(fitted.position + WAVE_AT * scale, scale)


## Where an image of this size is drawn on a screen of that size, kept whole
## and centred: Godot's boot splash Keep.
static func fit(image: Vector2, screen: Vector2) -> Rect2:
	var scale := minf(screen.x / image.x, screen.y / image.y)
	var drawn := image * scale
	return Rect2((screen - drawn) / 2.0, drawn)


## The wave: a sine flowing sideways, still at its ends, the accent turning to the second accent.
func _wave(centre: Vector2, scale: float) -> void:
	var width := WAVE_WIDTH * scale
	var height := WAVE_HEIGHT * scale
	var steps := 64
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var from: Color = PALETTE[&"accent"]
	var to: Color = PALETTE[&"accent_2"]
	for step: int in steps + 1:
		var along := float(step) / steps
		var calm := sin(along * PI)
		var rise := sin((along * 2.0 - _time * SPEED) * TAU) * height * calm
		points.append(Vector2(centre.x - width / 2.0 + along * width, centre.y + rise))
		colours.append(Color(from.lerp(to, along), 0.35 + 0.65 * calm))
	draw_polyline_colors(points, colours, WAVE_THICKNESS * scale, true)
