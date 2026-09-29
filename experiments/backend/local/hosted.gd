extends SceneTree

## The experiment against the hosted project, as the phone will run it:
## anonymous sign-in, two connections of one player, and a stranger.

const Supa := preload("res://supa.gd")
const URL := "https://ygjtfnjydjcfvqvlvgpb.supabase.co"
const KEY := "sb_publishable_3z5na7gdcK6NPhQin16J5g_ewIRAlYX"

var failed: Array[String] = []


func _init() -> void:
	var make := func() -> Supa:
		var one := Supa.new(URL + "/auth/v1", URL + "/rest/v1", URL.replace("https://", "wss://") + "/realtime/v1/websocket", KEY)
		root.add_child(one)
		return one
	var device_a: Supa = make.call()
	var device_b: Supa = make.call()
	var stranger: Supa = make.call()
	await process_frame
	claim(await device_a.sign_in_anonymously(), "device A signs in")
	device_b.same_player_as(device_a)
	claim(await stranger.sign_in_anonymously(), "a stranger signs in")
	var seen_by_a: Array = []
	var seen_by_stranger: Array = []
	device_a.changed.connect(func(record: Dictionary) -> void: seen_by_a.append([record, Time.get_ticks_msec()]))
	stranger.changed.connect(func(record: Dictionary) -> void: seen_by_stranger.append(record))
	var ready := [0]
	device_a.joined.connect(func() -> void: ready[0] += 1)
	stranger.joined.connect(func() -> void: ready[0] += 1)
	device_a.subscribe("notes")
	stranger.subscribe("notes")
	var waited := 0
	while ready[0] < 2 and waited < 900:
		await process_frame
		waited += 1
	claim(ready[0] == 2, "both listeners joined the live channel")
	await create_timer(2.0).timeout
	var sent_at := Time.get_ticks_msec()
	var written: Array = await device_b.insert("notes", {"body": "written on device B"})
	claim(written[0] == 201, "device B writes a note: %s" % [written])
	waited = 0
	while seen_by_a.is_empty() and waited < 900:
		await process_frame
		waited += 1
	claim(not seen_by_a.is_empty(), "device A sees it live")
	if not seen_by_a.is_empty():
		print("LIVE UPDATE ARRIVED %d ms after the write was sent" % (seen_by_a[0][1] - sent_at))
	await create_timer(1.5).timeout
	claim(seen_by_stranger.is_empty(), "the stranger never receives it")
	var theirs: Array = await stranger.select("notes")
	claim(theirs[0] == 200 and (theirs[1] as Array).is_empty(), "the stranger can't read it")
	for sentence: String in failed:
		print("NOT TRUE: %s" % sentence)
	print("HOSTED PASSED" if failed.is_empty() else "HOSTED FAILED")
	quit(0 if failed.is_empty() else 1)


func claim(held: bool, what: String) -> void:
	print(("ok   " if held else "FAIL ") + what)
	if not held:
		failed.append(what)
