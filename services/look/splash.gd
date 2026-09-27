extends RefCounted

## The loading screen every app opens on: "Latensea Productions" on the navy
## ground, a gentle wave flowing under it from the accent to the second
## accent, held a moment and then faded away to the app beneath.
##
##     FactoryLook.splash(self)   # in describe(), once
##
## Godot's own boot splash is the plain navy ground (project.godot), so the
## phone goes navy, then the name and the wave, then the app. The words are
## drawn, not Labels, so a probe reading the screen never finds them; and a
## probe (`-- --probe`) gets no splash at all, since it walks the app at once.

const Phone := preload("phone.gd")
const NAME := "Latensea"
const LINE := "PRODUCTIONS"
## How long it stays, then how long it takes to fade, in seconds.
const HOLD := 1.6
const FADE := 0.4
## Base-pixel sizes before phone sizing.
const NAME_SIZE := 50
const LINE_SIZE := 15
const WAVE_WIDTH := 240
const WAVE_HEIGHT := 12
const WAVE_THICKNESS := 3.0
## How far the wave travels each second, in waves.
const SPEED := 0.6

## Put a splash over the app, on a layer above it, and let it go by itself.
## Returns the layer, or null when probing.
static func over(app: Node, colours: Dictionary, title_font: Font, font: Font, hold: float = HOLD, probing: bool = OS.get_cmdline_user_args().has("--probe")) -> CanvasLayer:
	if probing or app.has_node("Splash"):
		return null
	var layer := CanvasLayer.new()
	layer.name = "Splash"
	layer.layer = 100
	var shown := Drawn.new()
	shown.palette = colours
	shown.name_font = title_font
	shown.line_font = font
	shown.grow = Phone.factor()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	# While it shows, a tap lands on it, not on the app beneath.
	shown.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shown)
	app.add_child(layer)
	var going := shown.create_tween()
	going.tween_interval(hold)
	going.tween_callback(func() -> void: shown.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	going.tween_property(shown, "modulate:a", 0.0, FADE)
	going.tween_callback(layer.queue_free)
	return layer


## The splash as drawn: the ground, the words, the wave.
class Drawn extends Control:
	var palette: Dictionary
	var name_font: Font
	var line_font: Font
	var grow := 1.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), palette[&"ground"])
		var middle := size / 2.0
		var name_size := roundi(NAME_SIZE * grow)
		var line_size := roundi(LINE_SIZE * grow)
		var name_width := name_font.get_string_size(NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var name_base := middle.y - 6.0 * grow
		draw_string(name_font, Vector2(middle.x - name_width / 2.0, name_base), NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, palette[&"ink"])
		# The second line spaced out, letter by letter.
		var spacing := 4.0 * grow
		var letters := PackedFloat32Array()
		var across := 0.0
		for letter: String in LINE:
			letters.append(across)
			across += line_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x + spacing
		across -= spacing
		var line_base := name_base + line_size * 2.0
		for at: int in LINE.length():
			draw_string(line_font, Vector2(middle.x - across / 2.0 + letters[at], line_base), LINE[at], HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, palette[&"ink_soft"])
		_wave(Vector2(middle.x, line_base + 36.0 * grow))


	## The wave: a sine flowing sideways, still at its ends, the accent turning to the second accent.
	func _wave(centre: Vector2) -> void:
		var width := WAVE_WIDTH * grow
		var height := WAVE_HEIGHT * grow
		var steps := 64
		var points := PackedVector2Array()
		var colours := PackedColorArray()
		var from: Color = palette[&"accent"]
		var to: Color = palette.get(&"accent_2", from)
		for step: int in steps + 1:
			var along := float(step) / steps
			var calm := sin(along * PI)
			var rise := sin((along * 2.0 - _time * SPEED) * TAU) * height * calm
			points.append(Vector2(centre.x - width / 2.0 + along * width, centre.y + rise))
			colours.append(Color(from.lerp(to, along), 0.35 + 0.65 * calm))
		draw_polyline_colors(points, colours, WAVE_THICKNESS * grow, true)
