extends SceneTree

## backend.gd with no network: a stand-in answers its requests and carries
## its live messages. Runs inside any app that installs it. Prints PASS
## test_backend.gd, or every claim that did not hold. The same calls against
## a real platform: tests/online.gd.

const Backend := preload("res://addons/factory_backend/backend.gd")
const URL := "https://api.example.test"
const KEY := "sb_publishable_test"
const KEPT := "user://backend_test_session.json"

var _failed: Array[String] = []
var _made: Array[Node] = []


## Stands in for the platform: answers each request from a queue, and remembers what was asked.
class Platform extends RefCounted:
	var asked: Array = []  # [method, url, headers, body]
	var answers: Array = []  # [status, body as a Variant]

	func answer(status: int, body: Variant = null) -> void:
		answers.append([status, body])

	func request(method: String, at: String, headers: PackedStringArray, body: String) -> Array:
		asked.append([method, at, headers, body])
		if answers.is_empty():
			return [0, ""]
		var next: Array = answers.pop_front()
		return [next[0], "" if next[1] == null else JSON.stringify(next[1])]

	func last_header(name: String) -> String:
		for header: String in asked[-1][2]:
			if header.begins_with(name + ": "):
				return header.substr(name.length() + 2)
		return ""


func session(token: String, expires_at: float, id: String = "player-1") -> Dictionary:
	return {"access_token": token, "refresh_token": "refresh-" + token, "expires_at": expires_at, "user": {"id": id}}


func fresh(platform: Platform, now: float = 1000.0) -> Backend:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	var backend := Backend.new(URL + "/", KEY, KEPT)
	_made.append(backend)
	backend.transport = platform.request
	backend.clock = func() -> float: return now
	return backend


func _init() -> void:
	await process_frame
	await _signing_in()
	await _data()
	await _refreshing()
	await _restoring()
	await _live()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	for made: Node in _made:
		made.free()
	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_backend.gd")
	quit(0 if _failed.is_empty() else 1)


func _signing_in() -> void:
	var platform := Platform.new()
	var backend := fresh(platform)
	var heard := [""]
	backend.signed_in.connect(func(id: String) -> void: heard[0] = id)
	_claim(not backend.is_signed_in() and backend.player_id() == "", "a new backend has nobody signed in")
	platform.answer(200, {"access_token": "t1", "refresh_token": "r1", "expires_in": 3600, "user": {"id": "player-1"}})
	var reply: Backend.Reply = await backend.sign_in_anonymously()
	_claim(platform.asked[0][0] == "POST" and platform.asked[0][1] == URL + "/auth/v1/signup", "anonymous sign-in asks the platform's sign-in to sign up")
	_claim(platform.last_header("apikey") == KEY, "every request carries the publishable key")
	_claim(reply.ok and backend.is_signed_in() and backend.player_id() == "player-1", "and the player is signed in")
	_claim(heard[0] == "player-1", "signed_in says who")
	_claim(is_equal_approx(float(backend.session["expires_at"]), 4600.0), "the session's end is kept as a time, from expires_in")
	_claim(FileAccess.file_exists(KEPT), "the session is kept in its file")

	platform.answer(200, {})
	await backend.request_code("someone@example.test")
	_claim(platform.asked[-1][1] == URL + "/auth/v1/otp" and JSON.parse_string(platform.asked[-1][3])["email"] == "someone@example.test", "a code is asked for by email")
	platform.answer(200, {"access_token": "t2", "refresh_token": "r2", "expires_in": 3600, "user": {"id": "player-2"}})
	await backend.verify_code("someone@example.test", "123456")
	var verified: Dictionary = JSON.parse_string(platform.asked[-1][3])
	_claim(verified["type"] == "email" and verified["token"] == "123456" and backend.player_id() == "player-2", "the emailed code signs the player in")
	platform.answer(200, {"access_token": "t3", "refresh_token": "r3", "expires_in": 3600, "user": {"id": "player-3"}})
	await backend.sign_in_with_google_token("google-id-token", "raw-nonce")
	var google: Dictionary = JSON.parse_string(platform.asked[-1][3])
	_claim(platform.asked[-1][1].ends_with("/token?grant_type=id_token") and google["provider"] == "google" and google["nonce"] == "raw-nonce", "Google's token signs the player in, with the raw nonce")

	platform.answer(400, {"msg": "Token has expired or is invalid"})
	var refused: Backend.Reply = await backend.verify_code("someone@example.test", "000000")
	_claim(not refused.ok and refused.error == "Token has expired or is invalid", "a refusal answers the platform's own words")
	_claim(backend.player_id() == "player-3", "and leaves whoever was signed in")
	platform.answer(200, {"user": {"id": "nobody"}})
	var odd: Backend.Reply = await backend.verify_code("someone@example.test", "111111")
	_claim(not odd.ok, "an answer with no session isn't taken as a sign-in")

	platform.answer(200, {"access_token": "t4", "refresh_token": "r4", "expires_in": 3600, "user": {"id": "steam-player"}, "steam_id": "7656"})
	await backend.sign_in_with_steam("14000000aabb")
	_claim(platform.asked[-1][1] == URL + "/functions/v1/steam-signin" and JSON.parse_string(platform.asked[-1][3])["ticket"] == "14000000aabb", "a Steam ticket goes to the platform's steam-signin function")
	_claim(platform.last_header("Authorization") == "", "as nobody, so it signs in rather than links")
	_claim(backend.player_id() == "steam-player", "and its session signs the Steam player in")
	platform.answer(200, {"linked": true})
	var linked: Backend.Reply = await backend.link_steam("14000000ccdd")
	_claim(linked.ok and platform.last_header("Authorization") == "Bearer t4", "linking Steam goes as the signed-in player")
	_claim(backend.player_id() == "steam-player", "and keeps them signed in")
	platform.answer(401, {"msg": "Steam refused the ticket: Invalid ticket"})
	var refused_steam: Backend.Reply = await backend.sign_in_with_steam("deadbeef")
	_claim(not refused_steam.ok and refused_steam.error.begins_with("Steam refused"), "a ticket Steam refuses says so")

	var gone := [false]
	backend.signed_out.connect(func() -> void: gone[0] = true)
	platform.answer(204)
	await backend.sign_out()
	_claim(platform.asked[-1][1] == URL + "/auth/v1/logout", "signing out tells the platform")
	_claim(not backend.is_signed_in() and gone[0] and not FileAccess.file_exists(KEPT), "and forgets the session, file and all")


func _data() -> void:
	var platform := Platform.new()
	var backend := fresh(platform)
	backend.session = session("tok", 99999.0)
	platform.answer(200, [{"id": 1}])
	var rows: Backend.Reply = await backend.select("notes", "order=created_at.desc")
	_claim(platform.asked[-1][0] == "GET" and platform.asked[-1][1] == URL + "/rest/v1/notes?select=*&order=created_at.desc", "select asks for the rows with PostgREST's query")
	_claim(platform.last_header("Authorization") == "Bearer tok", "as the signed-in player")
	_claim(rows.ok and rows.data is Array and rows.data.size() == 1 and rows.data[0]["id"] == 1, "and answers the rows")
	platform.answer(201, [{"id": 2, "body": "hi"}])
	await backend.insert("notes", {"body": "hi"})
	_claim(platform.asked[-1][0] == "POST" and platform.last_header("Prefer") == "return=representation" and JSON.parse_string(platform.asked[-1][3]) == {"body": "hi"}, "insert sends the row and asks for it back")
	platform.answer(200, [])
	await backend.update("notes", "id=eq.2", {"body": "bye"})
	_claim(platform.asked[-1][0] == "PATCH" and platform.asked[-1][1] == URL + "/rest/v1/notes?id=eq.2", "update changes the rows its filter picks")
	platform.answer(204)
	await backend.delete("notes", "id=eq.2")
	_claim(platform.asked[-1][0] == "DELETE" and platform.asked[-1][1] == URL + "/rest/v1/notes?id=eq.2", "delete removes the rows its filter picks")
	var before := platform.asked.size()
	var everything: Backend.Reply = await backend.update("notes", "", {"body": "x"})
	var nothing: Backend.Reply = await backend.delete("notes", "")
	_claim(not everything.ok and not nothing.ok and platform.asked.size() == before, "an update or delete with no filter is refused without asking")
	platform.answer(200, 3)
	var counted: Backend.Reply = await backend.call_rpc("count_mine", {"kind": "note"})
	_claim(platform.asked[-1][1] == URL + "/rest/v1/rpc/count_mine" and counted.data == 3, "call_rpc calls a database function by name")
	platform.answer(200, {"done": true})
	await backend.call_function("steam-signin", {"ticket": "abc"})
	_claim(platform.asked[-1][1] == URL + "/functions/v1/steam-signin", "call_function calls a platform function")
	var unreachable: Backend.Reply = await backend.select("notes")
	_claim(unreachable.status == 0 and unreachable.error == "Couldn't reach the server", "no answer at all says the server couldn't be reached")


func _refreshing() -> void:
	var platform := Platform.new()
	var backend := fresh(platform, 1000.0)
	backend.session = session("old", 1030.0)  # 30 s left: inside the margin
	platform.answer(200, {"access_token": "new", "refresh_token": "r-new", "expires_in": 3600})
	platform.answer(200, [])
	await backend.select("notes")
	_claim(platform.asked.size() == 2 and platform.asked[0][1].ends_with("/token?grant_type=refresh_token"), "a session about to run out is refreshed before the call")
	_claim(JSON.parse_string(platform.asked[0][3])["refresh_token"] == "refresh-old", "with its refresh token")
	_claim(platform.last_header("Authorization") == "Bearer new", "and the call goes with the new token")
	_claim(backend.player_id() == "player-1", "the player stays the same, though the refresh answer didn't repeat them")


func _restoring() -> void:
	var platform := Platform.new()
	var first := fresh(platform, 1000.0)
	first.session = session("kept", 5000.0)
	first._keep(first.session)
	var again := Backend.new(URL, KEY, KEPT)
	_made.append(again)
	again.transport = platform.request
	again.clock = func() -> float: return 1000.0
	_claim(await again.restore() and again.player_id() == "player-1" and platform.asked.is_empty(), "the next run restores the kept session without asking")

	var later := Backend.new(URL, KEY, KEPT)
	_made.append(later)
	later.transport = platform.request
	later.clock = func() -> float: return 9000.0
	var offline := await later.restore()
	_claim(offline and later.is_signed_in(), "a run-out session kept while offline stays, for a refresh later")

	platform.answer(400, {"error_description": "Invalid Refresh Token"})
	var refused := Backend.new(URL, KEY, KEPT)
	_made.append(refused)
	refused.transport = platform.request
	refused.clock = func() -> float: return 9000.0
	_claim(not await refused.restore() and not refused.is_signed_in() and not FileAccess.file_exists(KEPT), "a refresh the platform refuses signs the player out")


func _live() -> void:
	var platform := Platform.new()
	var backend := fresh(platform)
	backend.session = session("live-token", 99999.0)
	var sent: Array = []
	backend.send_text = func(text: String) -> void: sent.append(JSON.parse_string(text))
	backend._want_live = true  # no socket in a test: the stand-in carries the messages
	var room := backend.channel("notes")
	_claim(backend.channel("notes") == room, "a channel's name always gives the same channel")
	var changes: Array = []
	var messages: Array = []
	var joins := [0]
	room.changed.connect(func(change: Dictionary) -> void: changes.append(change))
	room.broadcast_received.connect(func(event: String, payload: Dictionary) -> void: messages.append([event, payload]))
	room.joined.connect(func() -> void: joins[0] += 1)
	room.on_changes("notes", "INSERT").join()
	_claim(sent.is_empty(), "a channel waits for the live socket to open before joining")
	backend.live_opened()
	var join: Dictionary = sent[-1]
	_claim(join["topic"] == "realtime:notes" and join["event"] == "phx_join", "once open, it joins its topic")
	_claim(join["payload"]["access_token"] == "live-token", "as the signed-in player")
	_claim(join["payload"]["config"]["postgres_changes"] == [{"event": "INSERT", "schema": "public", "table": "notes"}], "asking for the changes it listens to")
	_claim(join["ref"] == join["join_ref"], "a join's ref is its join_ref, as Phoenix expects")
	backend.hear_live(JSON.stringify({"topic": "realtime:notes", "event": "phx_reply", "ref": "999", "payload": {"status": "ok"}}))
	_claim(not room.is_joined, "a reply to some other message isn't taken as joining")
	backend.hear_live(JSON.stringify({"topic": "realtime:notes", "event": "phx_reply", "ref": join["ref"], "payload": {"status": "ok", "response": {}}}))
	_claim(room.is_joined and joins[0] == 1, "the server's ok to the join joins it")
	backend.hear_live(JSON.stringify({"topic": "realtime:notes", "event": "postgres_changes", "payload": {"data": {"type": "INSERT", "table": "notes", "record": {"id": 5, "body": "new"}, "old_record": {}}}}))
	_claim(changes.size() == 1 and changes[0]["type"] == "INSERT" and changes[0]["record"]["body"] == "new", "a change arrives with its record")
	backend.hear_live(JSON.stringify({"topic": "realtime:notes", "event": "broadcast", "payload": {"type": "broadcast", "event": "move", "payload": {"x": 3}}}))
	_claim(messages.size() == 1 and messages[0][0] == "move" and messages[0][1]["x"] == 3, "a broadcast arrives with its event and payload")
	backend.hear_live(JSON.stringify({"topic": "realtime:elsewhere", "event": "broadcast", "payload": {"event": "move", "payload": {}}}))
	_claim(messages.size() == 1, "messages for other topics don't reach this channel")
	room.send_broadcast("move", {"x": 4})
	_claim(sent[-1]["event"] == "broadcast" and sent[-1]["payload"]["event"] == "move" and sent[-1]["payload"]["payload"]["x"] == 4 and sent[-1]["join_ref"] == join["ref"], "a broadcast is sent on the channel")

	platform.answer(200, {"access_token": "fresher", "refresh_token": "r", "expires_in": 3600})
	await backend.refresh()
	_claim(sent[-1]["event"] == "access_token" and sent[-1]["payload"]["access_token"] == "fresher", "a refreshed token is handed to joined channels")

	backend.hear_live(JSON.stringify({"topic": "realtime:notes", "event": "phx_error", "payload": {}}))
	_claim(not room.is_joined and sent[-1]["event"] == "phx_join", "a channel the server drops is joined again")
	backend._live_closed()
	_claim(not room.is_joined and backend._reconnect_in == 1.0, "a closed socket is tried again after a second")
	var failed := [""]
	room.join_failed.connect(func(reason: String) -> void: failed[0] = reason)
	backend.live_opened()
	backend.hear_live(JSON.stringify({"topic": "realtime:notes", "event": "phx_reply", "ref": sent[-1]["ref"], "payload": {"status": "error", "response": {"reason": "Unauthorized"}}}))
	_claim(failed[0] == "Unauthorized" and not room.is_joined, "a refused join says why")
	room.leave()
	_claim(not room._wanted, "leaving stops it rejoining")


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
