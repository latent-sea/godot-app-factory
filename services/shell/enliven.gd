extends Node

## What a Theme can't do alone, done for every app the opening scene opens
## (opening.gd puts this beside the app):
## - TITLES in a gradient, from the accent's end to the second accent: a
##   shader on each title's words, sized to the words as they change.
## - A PRESS answers the finger: a button shrinks a little as it is touched
##   and springs back as it is let go.
## - THE GROUND DRIFTS: every page's backdrop (backdrop.gd) is drawn again
##   each frame, so its pools of light move.
## - WORDS ON A BUTTON SIT IN ITS MIDDLE. A button is at least a finger
##   tall (48 dp), taller than its words, and gd-chime sets words at the top.
## - A LONG PRESS opens a row's menu. gd-chime opens a row's menu on a right
##   press and has no long press; a finger held still here becomes one,
##   and the lifting of that finger is kept from pressing the row too.

const FactoryLook := preload("res://addons/factory_look/look.gd")
const TITLE := GdChime.Themes.TITLE
const PAGE := FactoryLook.PAGE
## How long a finger is held still before it is a long press, in seconds,
## and how far it may wander, in pixels of the window, and still be held still.
const HOLD := 0.5
const SLOP := 24.0
## How far a pressed button shrinks, and how long it takes each way.
const PRESSED_SCALE := 0.94
const SHRINK := 0.08
const SPRING := 0.25

const SHADER := """
shader_type canvas_item;
uniform vec4 from_color : source_color;
uniform vec4 to_color : source_color;
uniform float width = 100.0;
varying float across;
void vertex() {
	across = VERTEX.x;
}
void fragment() {
	COLOR.rgb = mix(from_color.rgb, to_color.rgb, clamp(across / max(width, 1.0), 0.0, 1.0));
}
"""

## The app this lives beside.
var app: Node
## The title's two colours: the accent's end to the second accent, lightened.
var from_color: Color = FactoryLook.gradient_end(FactoryLook.PALETTE)
var to_color: Color = FactoryLook.second_accent(FactoryLook.PALETTE).lightened(0.3)
## How many long presses became a row's menu, for a test.
var long_presses := 0
## Titles and pages found so far; freed ones are dropped as they are met.
var _titles: Array = []
var _pages: Array = []
var _shader: Shader
var _held_at := Vector2.ZERO
var _held_for := -1.0
var _swallow := 0
## The button a finger is on, shrunk, until it lifts.
var _pressing: Control


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = SHADER
	get_tree().node_added.connect(_added)
	for node: Node in app.find_children("*", "", true, false):
		_added(node)


func _added(node: Node) -> void:
	if app == null or not app.is_ancestor_of(node):
		return
	if node is Label and (node as Label).theme_type_variation == TITLE:
		var words := node as Label
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter(&"from_color", from_color)
		material.set_shader_parameter(&"to_color", to_color)
		words.material = material
		_titles.append(words)
	elif node is Label and _on_button(node):
		(node as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif node is Control and (node as Control).theme_type_variation == PAGE:
		_pages.append(node as Control)
	elif node is GdChime.Pressable:
		(node as Control).gui_input.connect(_touched.bind(node))


## Whether these words are on a button, and the button's only words: a
## card or a row holds lines of words, which stay where they are.
func _on_button(words: Node) -> bool:
	var above := words.get_parent()
	while above != null and above != app:
		if above is GdChime.Pressable:
			return above.find_children("*", "Label", true, false).size() <= 1
		above = above.get_parent()
	return false


func _process(delta: float) -> void:
	_titles = _titles.filter(func(words: Variant) -> bool: return is_instance_valid(words))
	for words: Label in _titles:
		var font := words.get_theme_font(&"font")
		var wide := font.get_string_size(words.text, HORIZONTAL_ALIGNMENT_LEFT, -1, words.get_theme_font_size(&"font_size")).x
		(words.material as ShaderMaterial).set_shader_parameter(&"width", wide)
	_pages = _pages.filter(func(page: Variant) -> bool: return is_instance_valid(page))
	for page: Control in _pages:
		if page.is_visible_in_tree():
			page.queue_redraw()
	if _held_for >= 0.0:
		_held_for += delta
		if _held_for >= HOLD:
			_held_for = -1.0
			_long_press(_held_at)


## A press of a button, as the finger (or mouse) lands and lifts: shrink, then spring back.
func _touched(event: InputEvent, button: Control) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	button.pivot_offset = button.size / 2.0
	if (event as InputEventMouseButton).pressed:
		_pressing = button
		button.create_tween().tween_property(button, "scale", Vector2.ONE * PRESSED_SCALE, SHRINK)
	else:
		_pressing = null
		_spring(button)


## A shrunk button back to its size, overshooting a little.
func _spring(button: Control) -> void:
	if is_instance_valid(button):
		button.create_tween().tween_property(button, "scale", Vector2.ONE, SPRING).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A finger landing, moving or lifting, before anything else hears it.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_held_at = touch.position
			_held_for = 0.0
		else:
			_held_for = -1.0
			if _swallow > 0:
				_swallow -= 1
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0:
		if (event as InputEventScreenDrag).position.distance_to(_held_at) > SLOP:
			_held_for = -1.0
	elif event is InputEventMouseButton and _swallow > 0 and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# the mouse the engine makes of the same finger lifting
		_swallow -= 1
		get_viewport().set_input_as_handled()


## A finger held still: a right press there, which opens the menu of the row under it.
func _long_press(at: Vector2) -> void:
	long_presses += 1
	# its lifting is kept from the row below, so the row is sprung back here
	if _pressing != null:
		_spring(_pressing)
		_pressing = null
	# the finger's own lifting - as a touch, and as the mouse made of it - must not also press the row
	_swallow = 2 if ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true) else 1
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = down
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
