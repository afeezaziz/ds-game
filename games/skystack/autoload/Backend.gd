extends Node
## Shared platform client. Template file: copy unchanged to every game.
##
## Talks to the Dream Studio FastAPI backend. Every call degrades gracefully:
## if the server is unreachable the game keeps working offline and returns
## empty results — a game must NEVER depend on the network to be playable.

signal authenticated

const BASE_URL := "http://127.0.0.1:8000/v1"  # <-- point at production URL when deployed
const TOKEN_PATH := "user://session.cfg"

var token := ""
var player_id := ""
var online := false
var remote_config: Dictionary = {}

func _ready() -> void:
	_load_token()
	call_deferred("_boot")

func _boot() -> void:
	await authenticate()
	await fetch_config()

# ---------- core HTTP ----------

func _request(method: int, path: String, body: Variant = null, use_auth: bool = true) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if use_auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var data := ""
	if body != null:
		data = JSON.stringify(body)
	var err := http.request(BASE_URL + path, headers, method, data)
	if err != OK:
		http.queue_free()
		return {"_ok": false, "_status": 0}
	var result: Array = await http.request_completed
	http.queue_free()
	var status: int = result[1]
	var text := ""
	if result[3] is PackedByteArray:
		text = (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else {}
	var out: Dictionary = parsed if parsed is Dictionary else {}
	out["_ok"] = result[0] == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	out["_status"] = status
	return out

# ---------- auth ----------

func authenticate() -> bool:
	var res := await _request(HTTPClient.METHOD_POST, "/auth/device",
		{"device_id": GameState.device_id}, false)
	if res.get("_ok", false):
		token = res.get("token", "")
		player_id = res.get("player_id", "")
		online = true
		_save_token()
		authenticated.emit()
	else:
		online = false
	return online

# ---------- remote config ----------

func fetch_config() -> void:
	var res := await _request(HTTPClient.METHOD_GET, "/config/" + GameState.game_id, null, false)
	if res.get("_ok", false) and res.get("data") is Dictionary:
		remote_config = res["data"]

func cfg(key: String, default_value: Variant) -> Variant:
	return remote_config.get(key, default_value)

# ---------- gameplay services ----------

func submit_score(score: int) -> Dictionary:
	if not online:
		return {}
	return await _request(HTTPClient.METHOD_POST, "/scores/" + GameState.game_id, {"score": score})

func get_leaderboard(limit: int = 10) -> Dictionary:
	if not online:
		return {}
	return await _request(HTTPClient.METHOD_GET,
		"/leaderboards/%s?limit=%d" % [GameState.game_id, limit])

func push_save(data: Dictionary, version: int) -> Dictionary:
	if not online:
		return {}
	return await _request(HTTPClient.METHOD_PUT, "/saves/" + GameState.game_id,
		{"data": data, "version": version})

func pull_save() -> Dictionary:
	if not online:
		return {}
	return await _request(HTTPClient.METHOD_GET, "/saves/" + GameState.game_id)

func send_events(events: Array) -> void:
	if not online or events.is_empty():
		return
	await _request(HTTPClient.METHOD_POST, "/events",
		{"game_id": GameState.game_id, "events": events})

func get_crosspromo() -> Array:
	if not online:
		return []
	var res := await _request(HTTPClient.METHOD_GET, "/crosspromo/" + GameState.game_id, null, false)
	var games: Variant = res.get("games", [])
	return games if games is Array else []

# ---------- token persistence ----------

func _save_token() -> void:
	var cfg_file := ConfigFile.new()
	cfg_file.set_value("session", "token", token)
	cfg_file.set_value("session", "player_id", player_id)
	cfg_file.save(TOKEN_PATH)

func _load_token() -> void:
	var cfg_file := ConfigFile.new()
	if cfg_file.load(TOKEN_PATH) == OK:
		token = cfg_file.get_value("session", "token", "")
		player_id = cfg_file.get_value("session", "player_id", "")
