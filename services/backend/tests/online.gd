extends SceneTree

## backend.gd against a real platform, over the internet. Not run by
## check_app (its name doesn't start with test_): run it by hand, in an app
## that installs the backend service, with the platform's address and
## publishable key:
##
##   BACKEND_URL=https://... BACKEND_KEY=sb_publishable_... \
##     godot --headless --path apps/<app> --script res://addons/factory_backend/tests/online.gd
##
## The platform needs anonymous sign-in on, and the notes table of
## experiments/backend/app.sql. Prints PASS online.gd, or every claim that
## did not hold.

const Backend := preload("res://addons/factory_backend/backend.gd")
const KEPT := "user://backend_online_session.json"

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	var url := OS.get_environment("BACKEND_URL")
	var key := OS.get_environment("BACKEND_KEY")
	if url.is_empty() or key.is_empty():
		print("set BACKEND_URL and BACKEND_KEY")
		quit(2)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))

	var phone := Backend.new(url, key, KEPT)
	root.add_child(phone)
	var signed: Backend.Reply = await phone.sign_in_anonymously()
	_claim(signed.ok and not phone.player_id().is_empty(), "a new player signs in: %s" % signed.error)

	# A second device of the same player listens live.
	var tablet := Backend.new(url, key, "user://backend_online_tablet.json")
	root.add_child(tablet)
	await tablet.use_session(phone.session)
	var live := tablet.channel("online-check")
	var arrived: Array = []
	live.changed.connect(func(change: Dictionary) -> void: arrived.append([change, Time.get_ticks_msec()]))
	live.on_changes("notes", "INSERT").join()
	var started := Time.get_ticks_msec()
	while not live.is_joined and Time.get_ticks_msec() - started < 15000:
		await process_frame
	_claim(live.is_joined, "the second device joins a live channel")
	await create_timer(2.0).timeout

	var body := "online check %d" % Time.get_ticks_msec()
	var sent_at := Time.get_ticks_msec()
	var saved: Backend.Reply = await phone.insert("notes", {"body": body})
	_claim(saved.ok and saved.data is Array and saved.data[0]["body"] == body, "a note is saved: %s" % saved.error)
	while arrived.is_empty() and Time.get_ticks_msec() - sent_at < 10000:
		await process_frame
	_claim(not arrived.is_empty() and arrived[0][0]["record"]["body"] == body, "the other device receives it live")
	if not arrived.is_empty():
		print("live update in %d ms" % (arrived[0][1] - sent_at))

	var mine: Backend.Reply = await phone.select("notes", "body=eq." + body.uri_encode())
	_claim(mine.ok and mine.data is Array and mine.data.size() == 1, "and reads it back")

	var refreshed: Backend.Reply = await phone.refresh()
	_claim(refreshed.ok and phone.is_signed_in(), "the session refreshes: %s" % refreshed.error)
	var next_run := Backend.new(url, key, KEPT)
	root.add_child(next_run)
	_claim(await next_run.restore() and next_run.player_id() == phone.player_id(), "the next run is still the same player")

	var stranger := Backend.new(url, key, "user://backend_online_stranger.json")
	root.add_child(stranger)
	await stranger.sign_in_anonymously()
	var theirs: Backend.Reply = await stranger.select("notes", "body=eq." + body.uri_encode())
	_claim(theirs.ok and theirs.data is Array and theirs.data.is_empty(), "a stranger can't read it")

	live.leave()
	await phone.sign_out()
	await stranger.sign_out()
	_claim(not phone.is_signed_in(), "signing out forgets the player")
	for file: String in [KEPT, "user://backend_online_tablet.json", "user://backend_online_stranger.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS online.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	print(("ok   " if held else "FAIL ") + what)
	if not held:
		_failed.append(what)
