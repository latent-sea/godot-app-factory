extends Node

## A throwaway Supabase client in plain GDScript: email-code sign-in, reading
## and writing a table, and realtime over a WebSocket speaking Phoenix
## channels (the protocol Supabase Realtime uses). One of these is one device.

signal changed(record: Dictionary)
signal joined

var auth_url: String
var rest_url: String
var realtime_url: String
var anon_key: String
var access_token := ""
var user_id := ""

var _socket := WebSocketPeer.new()
var _ref := 0
var _open := false
var _pending_join: Dictionary = {}
var _heartbeat := 0.0


func _init(auth: String, rest: String, realtime: String, anon: String) -> void:
	auth_url = auth
	rest_url = rest
	realtime_url = realtime
	anon_key = anon


## POST JSON; returns [status, parsed body].
func _call(method: HTTPClient.Method, url: String, body: Variant = null, extra: PackedStringArray = []) -> Array:
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json"]) + extra
	if not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	request.request(url, headers, method, "" if body == null else JSON.stringify(body))
	var done: Array = await request.request_completed
	request.queue_free()
	var text: String = (done[3] as PackedByteArray).get_string_from_utf8()
	return [done[1], JSON.parse_string(text) if not text.is_empty() else null]


## Sign in with no email at all: a new anonymous player (Supabase's anonymous sign-ins).
func sign_in_anonymously() -> bool:
	var result := await _call(HTTPClient.METHOD_POST, auth_url + "/signup", {})
	if result[0] != 200:
		push_warning("anonymous sign-in failed: %s" % [result])
		return false
	access_token = result[1]["access_token"]
	user_id = result[1]["user"]["id"]
	return true


## The same player on another device: this session's token, shared.
func same_player_as(other: Node) -> void:
	access_token = other.access_token
	user_id = other.user_id


## Step 1: ask for a code to be emailed.
func request_code(email: String) -> int:
	var result := await _call(HTTPClient.METHOD_POST, auth_url + "/otp", {"email": email, "create_user": true})
	return result[0]


## Step 2: exchange the code for a session.
func verify_code(email: String, code: String) -> bool:
	var result := await _call(HTTPClient.METHOD_POST, auth_url + "/verify", {"type": "email", "email": email, "token": code})
	if result[0] != 200:
		return false
	access_token = result[1]["access_token"]
	user_id = result[1]["user"]["id"]
	return true


func insert(table: String, row: Dictionary) -> Array:
	return await _call(HTTPClient.METHOD_POST, rest_url + "/" + table, row, PackedStringArray(["Prefer: return=representation"]))


func select(table: String) -> Array:
	return await _call(HTTPClient.METHOD_GET, rest_url + "/" + table + "?select=*")


## Open the realtime socket and subscribe to inserts on a table.
func subscribe(table: String) -> void:
	_socket.connect_to_url(realtime_url + "?apikey=" + anon_key + "&vsn=1.0.0")
	_pending_join = {
		"topic": "realtime:" + table,
		"event": "phx_join",
		"payload": {
			"config": {"postgres_changes": [{"event": "INSERT", "schema": "public", "table": table}]},
			"access_token": access_token,
		},
	}


func _send(message: Dictionary) -> void:
	_ref += 1
	message["ref"] = str(_ref)
	if message["event"] == "phx_join":
		message["join_ref"] = str(_ref)
	_socket.send_text(JSON.stringify(message))


func _process(delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _open:
		_open = true
		_send(_pending_join)
	if _open:
		_heartbeat += delta
		if _heartbeat > 25.0:
			_heartbeat = 0.0
			_send({"topic": "phoenix", "event": "heartbeat", "payload": {}})
	while _socket.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
		if not (message is Dictionary):
			continue
		match message.get("event"):
			"phx_reply":
				if message.get("payload", {}).get("status") == "ok" and str(message.get("topic")).begins_with("realtime:"):
					joined.emit()
			"postgres_changes":
				changed.emit(message["payload"]["data"]["record"])
