extends RefCounted

## What every app needs and gd-chime leaves to it: Android's Back button,
## and where the app's saved data lives.
##
##     const Basics := preload("res://addons/factory_basics/basics.gd")
##
##     func describe() -> GdChime.Desc:
##         Basics.answer_back(self)
##         saving = Basics.keep(self, "checklist", list, saved_at)
##
## An app also needs `config/quit_on_go_back=false` in project.godot, so
## Back reaches it instead of closing it; tooling/create_app.py writes that.

## What `-- --probe` is on the command line (ChimeApp's own switch).
const PROBE_SWITCH := "--probe"


## Where an app keeps its data: the file a test chose, or user://<name>.json.
## A probe always gets its own file, emptied first, so walking the app never
## touches real data and always starts from nothing.
static func save_file(name: String, chosen: String = "", probing: bool = OS.get_cmdline_user_args().has(PROBE_SWITCH)) -> String:
	if probing:
		var probed := "user://%s_probe.json" % name
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probed))
		return probed
	return chosen if not chosen.is_empty() else "user://%s.json" % name


## A model's facts kept in the app's file for `name` (save_file), under the
## same name: the app's model that saves and restores them, ready for
## Settings to reset.
static func keep(app: Node, name: String, kept: Object, chosen: String = "") -> GdChime.SettingsFile:
	var saving: GdChime.SettingsFile = app.model(GdChime.SettingsFile.new(app.chimes, save_file(name, chosen)))
	saving.keep(name, kept)
	return saving


## Android's Back goes back a screen - closing a pop-up first - or, with
## nothing behind, leaves the app. gd-chime doesn't wire Back itself.
## Safe to call on every describe(): the app keeps one.
static func answer_back(app: Node) -> Node:
	var kept: Node = app.get_node_or_null("AndroidBack")
	if kept is Back:
		kept._commands = app.commands
		return kept
	var back := Back.new(app.commands, func() -> void: app.get_tree().quit())
	back.name = "AndroidBack"
	app.add_child(back)
	return back


## Hears the Back request the OS sends every node, and goes back through the app's commands.
class Back extends Node:
	var _commands: Object
	var _leave: Callable

	func _init(commands: Object, leave: Callable) -> void:
		_commands = commands
		_leave = leave

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()

	## Back one step, or leave when there is no step to take.
	func go_back() -> void:
		if _commands.dispatch(GdChime.Chimes.GLOBAL, GdChime.Driver.GOES_BACK, {}) != null:
			_leave.call()
