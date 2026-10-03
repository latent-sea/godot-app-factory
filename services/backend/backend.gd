extends Node

## The shared platform from an app (D-010, D-011): signing in, the player's
## data, and live updates, in plain GDScript over HTTPS and one WebSocket.
## The platform is Supabase; this speaks its sign-in (GoTrue), data
## (PostgREST) and live (Realtime, Phoenix channels) protocols.
##
##     const Backend := preload("res://addons/factory_backend/backend.gd")
##
##     var backend := Backend.new(URL, PUBLISHABLE_KEY)
##     add_child(backend)
##     await backend.restore()                      # the player signed in last time, if any
##     if not backend.is_signed_in():
##         await backend.sign_in_anonymously()
##     var saved := await backend.insert("notes", {"body": "hello"})
##     var mine := await backend.select("notes", "order=created_at.desc")
##     var live := backend.channel("notes")
##     live.on_changes("notes")
##     live.changed.connect(func(change: Dictionary) -> void: print(change["record"]))
##     live.join()
##
## Every call answers a Reply: ok, status, data (the parsed body) and error
## (words a person can read). Nothing here throws.
##
## The session - who is signed in - is kept in a file (user://backend_session.json
## unless told otherwise), so the player stays signed in between runs, and is
## refreshed before it runs out, both for calls and for live channels.
##
## Deliberately absent: file storage, and presence.

const SESSION_FILE := "user://backend_session.json"
## A session is refreshed when it has less than this long left, in seconds.
const REFRESH_MARGIN := 60.0
## Phoenix's heartbeat: the server drops a socket silent for longer than about 60 s.
const HEARTBEAT := 25.0
## Waits before trying the live socket again, in seconds, growing to the last.
const RECONNECT_WAITS: Array[float] = [1.0, 2.0, 5.0, 10.0, 30.0]

signal signed_in(player_id: String)
signal signed_out
# A refresh finished, with its Reply: calls made while it ran wait for it.
signal _refresh_done(reply: Reply)

var url: String
var key: String
var session_file: String
## Who is signed in: Supabase's session ({access_token, refresh_token, expires_at, user}), or {}.
var session: Dictionary = {}

## How a request is made: (method, url, headers, body) -> [status, text]. Tests swap it.
var transport: Callable = _http
## Seconds since 1970, as the platform counts. Tests swap it.
var clock: Callable = func() -> float: return Time.get_unix_time_from_system()
## How a live message leaves. Tests swap it to read what would be sent.
var send_text: Callable = _socket_send

var _socket := WebSocketPeer.new()
var _want_live := false
var _live_open := false
var _ref := 0
var _heartbeat_in := HEARTBEAT
var _reconnect_in := -1.0
var _reconnects := 0
var _channels: Dictionary = {}  # topic -> Channel
var _refreshing: bool = false
var _heartbeat_ref := ""  # the heartbeat the server hasn't answered yet


## What a call answers.
class Reply extends RefCounted:
	var ok: bool
	var status: int
	var data: Variant
	var error: String

	func _init(status_code: int, body: Variant, words: String = "") -> void:
		status = status_code
		data = body
		ok = status_code >= 200 and status_code < 300 and words.is_empty()
		error = words if not words.is_empty() else ("" if ok else Reply.words_of(status_code, body))

	## The words the platform gave for a failure, or the status.
	static func words_of(status_code: int, body: Variant) -> String:
		if status_code == 0:
			return "Couldn't reach the server"
		if body is Dictionary:
			for field: String in ["msg", "message", "error_description", "error"]:
				if body.has(field) and body[field] is String:
					return body[field]
		return "The server answered %d" % status_code


func _init(platform_url: String, publishable_key: String, kept_in: String = SESSION_FILE) -> void:
	url = platform_url.trim_suffix("/")
	key = publishable_key
	session_file = kept_in


# --- who is signed in ---------------------------------------------------------

func is_signed_in() -> bool:
	return session.has("access_token")


## The signed-in player's id (a UUID, the same in every app and game), or "".
func player_id() -> String:
	return str(session.get("user", {}).get("id", "")) if is_signed_in() else ""


## The session kept from last time, refreshed if it has run out. Answers whether someone is signed in.
func restore() -> bool:
	if not FileAccess.file_exists(session_file):
		return false
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_file))
	if not (kept is Dictionary and kept.has("refresh_token")):
		return false
	session = kept
	if _expiring():
		# a refresh the server refuses signs the player out; a network failure keeps the session for later
		await refresh()
		if not is_signed_in():
			return false
	signed_in.emit(player_id())
	return true


## A new player with no email or password, kept on this device until linked to one.
func sign_in_anonymously() -> Reply:
	return await _start_session(await _auth("POST", "/signup", {}))


## Step 1 of signing in by email: a six-digit code is emailed to this address.
func request_code(email: String) -> Reply:
	return await _auth("POST", "/otp", {"email": email, "create_user": true})


## Step 2: the code from the email signs the player in.
func verify_code(email: String, code: String) -> Reply:
	return await _start_session(await _auth("POST", "/verify", {"type": "email", "email": email, "token": code}))


## Google's ID token (from the phone's account picker) signs the player in.
## `nonce` is the raw nonce whose SHA-256 the account picker was given.
func sign_in_with_google_token(id_token: String, nonce: String) -> Reply:
	return await _start_session(await _auth("POST", "/token?grant_type=id_token", {"provider": "google", "id_token": id_token, "nonce": nonce}))


## A Steam web API ticket (Steamworks' GetAuthTicketForWebApi, with the
## platform's Steam identity, "latensea") signs in that Steam account's
## player, made the first time. The platform's steam-signin function checks
## the ticket with Steam.
func sign_in_with_steam(ticket: String) -> Reply:
	var made := await _call("POST", url + "/functions/v1/steam-signin", {"ticket": ticket}, [], false)
	if not made.ok:
		return made
	return await _start_session(made)


## The signed-in player's Steam account, from a ticket as above: afterwards
## Steam alone signs in as this player, on any device.
func link_steam(ticket: String) -> Reply:
	if not is_signed_in():
		return Reply.new(401, null, "Sign in first, then link Steam")
	return await call_function("steam-signin", {"ticket": ticket})


## A session made elsewhere - by a platform function - becomes this one.
func use_session(made: Dictionary) -> Reply:
	return await _start_session(Reply.new(200, made))


## A fresh access token for the session, before the old one runs out. One
## at a time: asked again while one runs, it answers that one's Reply. A
## refresh the server refuses (the session was revoked) signs the player out;
## no answer at all keeps the session, to try again later.
func refresh() -> Reply:
	if _refreshing:
		return await _refresh_done
	if not session.has("refresh_token"):
		return Reply.new(401, null, "Nobody is signed in")
	_refreshing = true
	var reply := await _auth("POST", "/token?grant_type=refresh_token", {"refresh_token": session["refresh_token"]}, false)
	_refreshing = false
	if reply.ok and reply.data is Dictionary and reply.data.has("access_token"):
		_keep(reply.data)
		_tell_channels()
	elif reply.status >= 400 and reply.status < 500:
		_forget()
	_refresh_done.emit(reply)
	return reply


func sign_out() -> void:
	if is_signed_in():
		await _call("POST", url + "/auth/v1/logout", null)
	_forget()


func _start_session(reply: Reply) -> Reply:
	if reply.ok and reply.data is Dictionary and reply.data.has("access_token"):
		_keep(reply.data)
		_tell_channels()
		signed_in.emit(player_id())
	elif reply.ok:
		return Reply.new(reply.status, reply.data, "The server didn't sign anyone in")
	return reply


func _keep(made: Dictionary) -> void:
	var kept := made.duplicate(true)
	if not kept.has("expires_at") and kept.has("expires_in"):
		kept["expires_at"] = clock.call() + float(kept["expires_in"])
	if not kept.has("user") and session.has("user"):
		kept["user"] = session["user"]
	session = kept
	# written whole, then put in place, so a run killed mid-write keeps the last good session
	var writing := session_file + ".tmp"
	var file := FileAccess.open(writing, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session))
		file.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(writing), ProjectSettings.globalize_path(session_file))


func _forget() -> void:
	var was := is_signed_in()
	session = {}
	if FileAccess.file_exists(session_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(session_file))
	if was:
		_tell_channels()
		signed_out.emit()


# Joined channels go on as whoever is signed in now.
func _tell_channels() -> void:
	for channel: Channel in _channels.values():
		channel._token_changed()


func _expiring() -> bool:
	return is_signed_in() and float(session.get("expires_at", 0.0)) - clock.call() < REFRESH_MARGIN


# --- data ---------------------------------------------------------------------

## Rows of a table the player may see. `query` is PostgREST's: "done=eq.false&order=created_at".
func select(table: String, query: String = "") -> Reply:
	return await _call("GET", _rest(table, "select=*" + ("&" + query if not query.is_empty() else "")), null)


## One row (a Dictionary) or several (an Array); answers them as saved.
func insert(table: String, rows: Variant) -> Reply:
	return await _call("POST", _rest(table, ""), rows, ["Prefer: return=representation"])


## Changes to the rows `filter` picks ("id=eq.7"); answers them as saved.
func update(table: String, filter: String, changes: Dictionary) -> Reply:
	if filter.is_empty():
		return Reply.new(400, null, "An update needs a filter, so it can't change every row")
	return await _call("PATCH", _rest(table, filter), changes, ["Prefer: return=representation"])


## Removes the rows `filter` picks.
func delete(table: String, filter: String) -> Reply:
	if filter.is_empty():
		return Reply.new(400, null, "A delete needs a filter, so it can't remove every row")
	return await _call("DELETE", _rest(table, filter), null)


## A database function, by name, with named arguments.
func call_rpc(function: String, args: Dictionary = {}) -> Reply:
	return await _call("POST", url + "/rest/v1/rpc/" + function.uri_encode(), args)


## A platform function (an Edge Function), by name, with a JSON body.
func call_function(function: String, body: Variant = {}) -> Reply:
	return await _call("POST", url + "/functions/v1/" + function.uri_encode(), body)


func _rest(table: String, query: String) -> String:
	return url + "/rest/v1/" + table.uri_encode() + ("?" + query if not query.is_empty() else "")


# --- requests -----------------------------------------------------------------

func _auth(method: String, path: String, body: Variant, with_session: bool = true) -> Reply:
	return await _call(method, url + "/auth/v1" + path, body, [], with_session)


func _call(method: String, at: String, body: Variant, extra: Array = [], with_session: bool = true) -> Reply:
	if with_session and (_refreshing or _expiring()):
		await refresh()
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json"])
	if with_session and is_signed_in():
		headers.append("Authorization: Bearer " + str(session["access_token"]))
	for header: String in extra:
		headers.append(header)
	var answered: Array = await transport.call(method, at, headers, "" if body == null else JSON.stringify(body))
	var status: int = answered[0]
	var text: String = answered[1]
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return Reply.new(status, parsed)


func _http(method: String, at: String, headers: PackedStringArray, body: String) -> Array:
	var methods := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PATCH": HTTPClient.METHOD_PATCH, "DELETE": HTTPClient.METHOD_DELETE}
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	if request.request(at, headers, methods[method], body) != OK:
		request.queue_free()
		return [0, ""]
	var done: Array = await request.request_completed
	request.queue_free()
	if done[0] != HTTPRequest.RESULT_SUCCESS:
		return [0, ""]
	return [done[1], (done[3] as PackedByteArray).get_string_from_utf8()]


# --- live ---------------------------------------------------------------------

## A live channel by name: changes to tables, and messages players send each
## other. Say what it listens to, then join it.
func channel(name: String) -> Channel:
	var topic := "realtime:" + name
	if not _channels.has(topic):
		_channels[topic] = Channel.new(self, topic)
	return _channels[topic]


## One live channel.
class Channel extends RefCounted:
	## A row changed: {type: INSERT/UPDATE/DELETE, table, record, old_record}.
	signal changed(change: Dictionary)
	## A player sent a message on this channel.
	signal broadcast_received(event: String, payload: Dictionary)
	signal joined
	## The server refused the channel (not signed in, or not allowed): its words.
	signal join_failed(reason: String)

	var topic: String
	var is_joined := false
	var _backend: Node
	var _changes: Array = []
	var _wanted := false
	var _join_ref := ""
	var _rejoin_in := -1.0  # seconds until joining again after the server dropped it
	var _rejoins := 0

	func _init(backend: Node, named: String) -> void:
		_backend = backend
		topic = named

	## Listen for changes to a table the player may read: event is INSERT, UPDATE, DELETE or *.
	## `filter` is Realtime's, such as "room_id=eq.7".
	func on_changes(table: String, event: String = "*", filter: String = "", schema: String = "public") -> Channel:
		var wanted := {"event": event, "schema": schema, "table": table}
		if not filter.is_empty():
			wanted["filter"] = filter
		_changes.append(wanted)
		return self

	func join() -> void:
		if not is_instance_valid(_backend):
			return
		_wanted = true
		_backend._channels[topic] = self
		_backend._live_wanted()
		if _backend._live_open:
			_send_join()

	## Stops listening. The live socket closes once no channel is wanted.
	func leave() -> void:
		_wanted = false
		_rejoin_in = -1.0
		if not is_instance_valid(_backend):
			return
		if is_joined:
			_backend._send(topic, "phx_leave", {})
		is_joined = false
		if _backend._channels.get(topic) == self:
			_backend._channels.erase(topic)
		_backend._live_unwanted()

	## A message to everyone else on this channel.
	func send_broadcast(event: String, payload: Dictionary) -> void:
		if is_instance_valid(_backend):
			_backend._send(topic, "broadcast", {"type": "broadcast", "event": event, "payload": payload}, _join_ref)

	func _send_join() -> void:
		var config := {"broadcast": {"self": false}, "presence": {"key": ""}, "postgres_changes": _changes}
		var payload := {"config": config}
		if _backend.is_signed_in():
			payload["access_token"] = _backend.session["access_token"]
		_join_ref = _backend._send(topic, "phx_join", payload, "", true)

	func _token_changed() -> void:
		if not is_joined:
			return
		if _backend.is_signed_in():
			_backend._send(topic, "access_token", {"access_token": _backend.session["access_token"]}, _join_ref)
		else:
			# signed out: the channel can't go on as the player, so it joins again as nobody
			_backend._send(topic, "phx_leave", {}, _join_ref)
			is_joined = false
			_send_join()

	func _heard(message: Dictionary) -> void:
		var payload: Dictionary = message.get("payload", {}) if message.get("payload") is Dictionary else {}
		match message.get("event"):
			"phx_reply":
				if str(message.get("ref", "")) != _join_ref:
					return
				if payload.get("status") == "ok":
					is_joined = true
					_rejoins = 0
					_backend._reconnects = 0
					joined.emit()
				else:
					is_joined = false
					var response: Variant = payload.get("response", {})
					join_failed.emit(str(response.get("reason", "refused")) if response is Dictionary else "refused")
			"postgres_changes":
				if not (payload.get("data") is Dictionary):
					return
				var data: Dictionary = payload["data"]
				changed.emit({"type": data.get("type", ""), "table": data.get("table", ""), "record": data.get("record", {}), "old_record": data.get("old_record", {})})
			"broadcast":
				broadcast_received.emit(str(payload.get("event", "")), payload.get("payload", {}) if payload.get("payload") is Dictionary else {})
			"phx_error", "phx_close":
				is_joined = false
				if _wanted:
					_rejoin_in = RECONNECT_WAITS[mini(_rejoins, RECONNECT_WAITS.size() - 1)]
					_rejoins += 1


func _live_wanted() -> void:
	if _want_live:
		return
	_want_live = true
	_connect_live()


## No channel is wanted any more: the live socket closes, and isn't tried again.
func _live_unwanted() -> void:
	for channel: Channel in _channels.values():
		if channel._wanted:
			return
	_want_live = false
	_live_open = false
	_reconnect_in = -1.0
	_socket.close()


func _connect_live() -> void:
	var live_url := url.replace("https://", "wss://").replace("http://", "ws://") + "/realtime/v1/websocket?apikey=" + key.uri_encode() + "&vsn=1.0.0"
	_socket = WebSocketPeer.new()
	if _socket.connect_to_url(live_url) != OK:
		_live_closed()


## The live socket is open: every wanted channel joins.
func live_opened() -> void:
	_live_open = true
	_heartbeat_in = HEARTBEAT
	_heartbeat_ref = ""
	for channel: Channel in _channels.values():
		if channel._wanted:
			channel._send_join()


func _live_closed() -> void:
	_live_open = false
	for channel: Channel in _channels.values():
		channel.is_joined = false
	if _want_live:
		_reconnect_in = RECONNECT_WAITS[mini(_reconnects, RECONNECT_WAITS.size() - 1)]
		_reconnects += 1


## One message from the live socket, as text.
func hear_live(text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not (message is Dictionary):
		return
	if message.get("topic") == "phoenix" and str(message.get("ref", "")) == _heartbeat_ref:
		_heartbeat_ref = ""
		_reconnects = 0
		return
	var channel: Channel = _channels.get(str(message.get("topic", "")))
	if channel != null:
		channel._heard(message)


## Sends one Phoenix message; answers its ref. A join's ref is also its join_ref.
func _send(topic: String, event: String, payload: Dictionary, join_ref: String = "", is_join: bool = false) -> String:
	_ref += 1
	var ref := str(_ref)
	var message := {"topic": topic, "event": event, "payload": payload, "ref": ref}
	if is_join:
		message["join_ref"] = ref
	elif not join_ref.is_empty():
		message["join_ref"] = join_ref
	send_text.call(JSON.stringify(message))
	return ref


func _socket_send(text: String) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(text)


# Channels the server dropped join again once their wait is up.
func _tick_rejoins(delta: float) -> void:
	for channel: Channel in _channels.values():
		if channel._rejoin_in < 0.0:
			continue
		channel._rejoin_in -= delta
		if channel._rejoin_in < 0.0 and channel._wanted and not channel.is_joined:
			channel._send_join()


func _process(delta: float) -> void:
	if not _want_live:
		# a socket told to close is polled until it has
		if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_socket.poll()
		return
	if _reconnect_in >= 0.0:
		_reconnect_in -= delta
		if _reconnect_in < 0.0:
			_connect_live()
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _live_open:
				live_opened()
			while _socket.get_available_packet_count() > 0:
				hear_live(_socket.get_packet().get_string_from_utf8())
			_tick_rejoins(delta)
			_heartbeat_in -= delta
			if _heartbeat_in <= 0.0:
				_heartbeat_in = HEARTBEAT
				if not _heartbeat_ref.is_empty():
					# the last heartbeat went unanswered: the connection is dead though the socket looks open
					_socket.close()
					_live_closed()
					return
				_heartbeat_ref = _send("phoenix", "heartbeat", {})
				# keep the live token fresh too, without waiting for a call to need it
				if _expiring() and not _refreshing:
					refresh()
		WebSocketPeer.STATE_CLOSED:
			_live_closed()
