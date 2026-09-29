extends SceneTree

## The experiment: two devices of one player and a stranger. Device A listens
## live; device B writes a note; A must see it within a moment, the stranger
## must not, and neither must a signed-out read. Codes are read from the
## local mail catcher, as a person would read them from their inbox.

const Supa := preload("res://supa.gd")
const MAIL := "mail"  # run from this folder

var failed: Array[String] = []


func _init() -> void:
	var env := {}
	for line: String in FileAccess.get_file_as_string(OS.get_environment("SPIKE_ENV")).split("\n", false):
		env[line.get_slice("=", 0)] = line.substr(line.find("=") + 1)
	var make := func() -> Supa:
		var one := Supa.new("http://localhost:9999", "http://localhost:3000", "ws://realtime-dev.supabase-realtime:4000", env["ANON_KEY"])
		root.add_child(one)
		return one
	var device_a: Supa = make.call()
	var device_b: Supa = make.call()
	var stranger: Supa = make.call()
	var signed_out: Supa = make.call()
	await process_frame

	claim(await sign_in(device_a, "ian@example.com"), "device A signs in with an emailed code")
	# auth refuses a second code to one address within its send interval (1 s here)
	await create_timer(1.5).timeout
	claim(await sign_in(device_b, "ian@example.com"), "device B signs in as the same player")
	claim(await sign_in(stranger, "someone.else@example.com"), "a stranger signs in")
	claim(device_a.user_id == device_b.user_id and device_a.user_id != stranger.user_id, "same player on both devices; the stranger is someone else")

	var seen_by_a: Array = []
	var seen_by_stranger: Array = []
	device_a.changed.connect(func(record: Dictionary) -> void: seen_by_a.append([record, Time.get_ticks_msec()]))
	stranger.changed.connect(func(record: Dictionary) -> void: seen_by_stranger.append(record))
	device_a.subscribe("notes")
	stranger.subscribe("notes")
	var ready := [0]
	device_a.joined.connect(func() -> void: ready[0] += 1)
	stranger.joined.connect(func() -> void: ready[0] += 1)
	var waited := 0
	while ready[0] < 2 and waited < 600:
		await process_frame
		waited += 1
	claim(ready[0] == 2, "both listeners joined the live channel")
	# realtime needs a moment after joining before changes flow
	await create_timer(2.0).timeout

	var sent_at := Time.get_ticks_msec()
	var written: Array = await device_b.insert("notes", {"body": "written on device B"})
	claim(written[0] == 201, "device B writes a note: %s" % [written])
	waited = 0
	while seen_by_a.is_empty() and waited < 600:
		await process_frame
		waited += 1
	claim(not seen_by_a.is_empty() and seen_by_a[0][0]["body"] == "written on device B", "device A sees it live")
	if not seen_by_a.is_empty():
		print("LIVE UPDATE ARRIVED %d ms after the write was sent" % (seen_by_a[0][1] - sent_at))
	await create_timer(1.5).timeout
	claim(seen_by_stranger.is_empty(), "the stranger never receives it: %s" % [seen_by_stranger])

	var theirs: Array = await stranger.select("notes")
	claim(theirs[0] == 200 and (theirs[1] as Array).is_empty(), "the stranger can't read it either")
	var nobody: Array = await signed_out.select("notes")
	claim(nobody[0] == 200 and (nobody[1] as Array).is_empty(), "nor can someone signed out")
	var mine: Array = await device_a.select("notes")
	claim(mine[0] == 200 and (mine[1] as Array).any(func(row: Dictionary) -> bool: return row["body"] == "written on device B"), "device A reads it back")

	for sentence: String in failed:
		print("NOT TRUE: %s" % sentence)
	print("SPIKE PASSED" if failed.is_empty() else "SPIKE FAILED")
	quit(0 if failed.is_empty() else 1)


func sign_in(device: Supa, email: String) -> bool:
	var before := DirAccess.get_files_at(MAIL).size()
	if await device.request_code(email) != 200:
		return false
	var waited := 0
	while DirAccess.get_files_at(MAIL).size() <= before and waited < 300:
		await process_frame
		waited += 1
	var files := Array(DirAccess.get_files_at(MAIL))
	files.sort_custom(func(a: String, b: String) -> bool: return a.to_int() < b.to_int())
	var mail := FileAccess.get_file_as_string(MAIL + "/" + files[-1])
	var found := RegEx.create_from_string("code is <strong>(\\d{6})</strong>").search(mail)
	return found != null and await device.verify_code(email, found.get_string(1))


func claim(held: bool, what: String) -> void:
	print(("ok   " if held else "FAIL ") + what)
	if not held:
		failed.append(what)
