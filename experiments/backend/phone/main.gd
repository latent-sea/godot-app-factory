extends Control

## A throwaway phone test of the hosted Supabase project: sign in, a live
## channel, a write that comes back live, and the privacy checks. Each check
## shows as a line going green or red; "Write a note" sends another and shows
## how long it took to come back.

const Supa := preload("res://supa.gd")
const URL := "https://ygjtfnjydjcfvqvlvgpb.supabase.co"
const KEY := "sb_publishable_3z5na7gdcK6NPhQin16J5g_ewIRAlYX"
const GOOD := Color("#19c3b3")
const BAD := Color("#ff4f7b")
const INK := Color("#eef2fa")

var lines: VBoxContainer
var device_a: Supa
var device_b: Supa
var stranger: Supa
var seen_by_a: Array = []
var seen_by_stranger: Array = []
var write_button: Button


func _ready() -> void:
	var ground := ColorRect.new()
	ground.color = Color("#121829")
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	column.add_child(_label("Backend test", 44, INK))
	column.add_child(_label("Talking to Supabase from this phone", 22, Color("#8e9ab8")))
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 12)
	column.add_child(lines)
	write_button = Button.new()
	write_button.text = "Write a note"
	write_button.add_theme_font_size_override("font_size", 30)
	write_button.custom_minimum_size = Vector2(0, 96)
	write_button.disabled = true
	write_button.pressed.connect(_write_again)
	column.add_child(write_button)
	_run()


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _say(text: String, held: bool) -> void:
	lines.add_child(_label(("✓  " if held else "✗  ") + text, 26, GOOD if held else BAD))


func _run() -> void:
	var make := func() -> Supa:
		var one := Supa.new(URL + "/auth/v1", URL + "/rest/v1", URL.replace("https://", "wss://") + "/realtime/v1/websocket", KEY)
		add_child(one)
		return one
	device_a = make.call()
	device_b = make.call()
	stranger = make.call()
	var signed_in := await device_a.sign_in_anonymously()
	_say("Signed in", signed_in)
	if not signed_in:
		_say("No internet, or Supabase unreachable", false)
		return
	device_b.same_player_as(device_a)
	_say("A stranger signed in too", await stranger.sign_in_anonymously())
	device_a.changed.connect(func(record: Dictionary) -> void: seen_by_a.append([record, Time.get_ticks_msec()]))
	stranger.changed.connect(func(record: Dictionary) -> void: seen_by_stranger.append(record))
	var ready := [0]
	device_a.joined.connect(func() -> void: ready[0] += 1)
	stranger.joined.connect(func() -> void: ready[0] += 1)
	device_a.subscribe("notes")
	stranger.subscribe("notes")
	var started := Time.get_ticks_msec()
	while ready[0] < 2 and Time.get_ticks_msec() - started < 15000:
		await get_tree().process_frame
	_say("Live channel open", ready[0] == 2)
	await get_tree().create_timer(2.0).timeout
	await _write_and_watch("Saved a note, and it came back live")
	await get_tree().create_timer(1.5).timeout
	_say("The stranger didn't receive it", seen_by_stranger.is_empty())
	var theirs: Array = await stranger.select("notes")
	_say("The stranger can't read it", theirs[0] == 200 and (theirs[1] as Array).is_empty())
	var mine: Array = await device_a.select("notes")
	_say("You can read it back", mine[0] == 200 and not (mine[1] as Array).is_empty())
	write_button.disabled = false


## Write a note from "device B" and wait for "device A" to receive it live.
func _write_and_watch(what: String) -> void:
	var before := seen_by_a.size()
	var sent_at := Time.get_ticks_msec()
	var written: Array = await device_b.insert("notes", {"body": "from my phone at %s" % Time.get_time_string_from_system()})
	if written[0] != 201:
		_say("Couldn't save the note (%s)" % written[0], false)
		return
	while seen_by_a.size() == before and Time.get_ticks_msec() - sent_at < 10000:
		await get_tree().process_frame
	if seen_by_a.size() > before:
		_say("%s in %d ms" % [what, seen_by_a[-1][1] - sent_at], true)
	else:
		_say("Saved, but the live update never came", false)


func _write_again() -> void:
	write_button.disabled = true
	await _write_and_watch("Another note came back live")
	write_button.disabled = false
