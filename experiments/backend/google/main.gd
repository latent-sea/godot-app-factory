extends Control

## A throwaway phone test of native Google sign-in: the Android account picker
## (Credential Manager, via the GoogleSignIn plugin) hands us a Google ID token,
## Supabase swaps it for a session, and we write and read a note as that player.

## The OAuth "Web application" client ID from Google Cloud (the one Supabase's
## Google provider is configured with). Paste it here, then re-run build.sh.
const GOOGLE_WEB_CLIENT_ID := "400837578052-jqnhh565es3a92k58u5r2oggdcf7mrkr.apps.googleusercontent.com"
const PLACEHOLDER := "PASTE_WEB_CLIENT_ID"

const Supa := preload("res://supa.gd")
const URL := "https://ygjtfnjydjcfvqvlvgpb.supabase.co"
const KEY := "sb_publishable_3z5na7gdcK6NPhQin16J5g_ewIRAlYX"
const GOOD := Color("#19c3b3")
const BAD := Color("#ff4f7b")
const INK := Color("#eef2fa")

var lines: VBoxContainer
var sign_in_button: Button
var supa: Supa
var google: Object
var raw_nonce := ""


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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	column.add_child(_label("Google sign-in test", 44, INK))
	column.add_child(_label("Native account picker, then a Supabase session", 22, Color("#8e9ab8")))
	sign_in_button = Button.new()
	sign_in_button.text = "Sign in with Google"
	sign_in_button.add_theme_font_size_override("font_size", 34)
	sign_in_button.custom_minimum_size = Vector2(0, 120)
	sign_in_button.pressed.connect(_sign_in)
	column.add_child(sign_in_button)
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 12)
	column.add_child(lines)

	supa = Supa.new(URL + "/auth/v1", URL + "/rest/v1", URL.replace("https://", "wss://") + "/realtime/v1/websocket", KEY)
	add_child(supa)

	if Engine.has_singleton("GoogleSignIn"):
		google = Engine.get_singleton("GoogleSignIn")
		google.connect("signed_in", _on_signed_in)
		google.connect("sign_in_failed", _on_sign_in_failed)
	else:
		_say("Plugin missing (no GoogleSignIn singleton)", false)
		sign_in_button.disabled = true
	if GOOGLE_WEB_CLIENT_ID == PLACEHOLDER:
		_say("GOOGLE_WEB_CLIENT_ID is still the placeholder — paste the Web client ID into main.gd and re-export", false)
		sign_in_button.disabled = true


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _say(text: String, held: bool) -> void:
	lines.add_child(_label(("✓  " if held else "✗  ") + text, 26, GOOD if held else BAD))


func _clear() -> void:
	for child in lines.get_children():
		child.queue_free()


func _sign_in() -> void:
	_clear()
	sign_in_button.disabled = true
	var bytes := Crypto.new().generate_random_bytes(32)
	raw_nonce = bytes.hex_encode()
	var hashed := raw_nonce.sha256_text()  # SHA-256 of the raw nonce, hex
	google.call("signIn", GOOGLE_WEB_CLIENT_ID, hashed)


func _on_sign_in_failed(message: String) -> void:
	_say("Google sign-in failed: " + message, false)
	sign_in_button.disabled = false


func _on_signed_in(id_token: String, email: String) -> void:
	_say("Google gave the app a token (%s)" % email, true)
	var result: Array = await supa.sign_in_with_google_token(id_token, raw_nonce)
	if not result[0]:
		_say("Supabase refused it — status %s: %s" % [result[1], JSON.stringify(result[2])], false)
		sign_in_button.disabled = false
		return
	_say("Supabase accepted it — player %s" % supa.user_id.substr(0, 8), true)
	var body := "google test at %s" % Time.get_datetime_string_from_system()
	var written: Array = await supa.insert("notes", {"body": body})
	if written[0] != 201:
		_say("Couldn't save a note — status %s: %s" % [written[0], JSON.stringify(written[1])], false)
		sign_in_button.disabled = false
		return
	_say("Saved a note as this player", true)
	var mine: Array = await supa.select("notes")
	var found := false
	if mine[0] == 200 and mine[1] is Array:
		for row: Dictionary in mine[1]:
			if row.get("body") == body:
				found = true
	if found:
		_say("Read it back", true)
	else:
		_say("Couldn't read it back — status %s: %s" % [mine[0], JSON.stringify(mine[1])], false)
	sign_in_button.disabled = false
