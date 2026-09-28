extends Control

## An app's first scene: the loading screen at once, the app loaded behind
## it, then the screen faded away. project.godot names this scene
## (res://addons/factory_look/opening.tscn) as the main scene; the app itself
## stays res://main.tscn.
##
## THE ORDER A PHONE SEES: Godot's boot splash (the name, splash.png) while
## the engine starts, then this - the same name in the same place with the
## wave moving - while main.tscn loads on another thread, then the app. The
## app's own build (describe) runs on the main thread, so the wave holds
## still for that last moment.
##
## A probe (`-- --probe`) gets the app at once and no loading screen.

const Splash := preload("splash.gd")
## The app this opens.
const APP := "res://main.tscn"
## The least the wave shows, even if the app loads sooner; then the fade.
const LEAST := 0.6
const FADE := 0.3

var probing := OS.get_cmdline_user_args().has("--probe")
## The app once it stands, and the screen over it until it fades.
var app: Node
var cover: Control
var _waited := 0.0
var _faded := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if probing:
		_open((load(APP) as PackedScene).instantiate())
		return
	cover = Splash.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# While it shows, a tap lands on it, not on the app beneath.
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	ResourceLoader.load_threaded_request(APP)


func _process(delta: float) -> void:
	if probing or _faded:
		return
	_waited += delta
	if app == null and ResourceLoader.load_threaded_get_status(APP) == ResourceLoader.THREAD_LOAD_LOADED:
		_open((ResourceLoader.load_threaded_get(APP) as PackedScene).instantiate())
		# under the cover, which still shows
		move_child(app, 0)
	if app != null and _waited >= LEAST:
		_faded = true
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var going := cover.create_tween()
		going.tween_property(cover, "modulate:a", 0.0, FADE)
		going.tween_callback(cover.queue_free)


func _open(made: Node) -> void:
	app = made
	add_child(app)
