class_name NetworkManager
extends Node

# NetworkManager — wraps all Firebase Cloud Function calls
# In PROTOTYPE stage all methods return instant mock data (no network)

var _id_token: String = ""

func _ready() -> void:
	ServiceLocator.register(&"NetworkManager", self)

func set_auth_token(token: String) -> void:
	_id_token = token

# ── Version Check ─────────────────────────────────────────────────────────

func check_version() -> Dictionary:
	if GameConfig.is_prototype():
		return { "status": "ok" }
	return await _call("config_versionCheck", {
		"gameId":   GameConfig.GAME_ID,
		"platform": PlatformUtils.get_platform(),
		"version":  GameConfig.APP_VERSION,
	})

# ── Player ────────────────────────────────────────────────────────────────

func get_profile() -> Dictionary:
	if GameConfig.is_prototype():
		return { "uid": "proto-uid", "displayName": "Prototype Player" }
	return await _call("player_getProfile", {
		"gameId": GameConfig.GAME_ID,
	})

func sync_progress(progress: Dictionary) -> Dictionary:
	if GameConfig.is_prototype():
		return { "version": 1, "accepted": true }
	return await _call("player_syncProgress", {
		"gameId":   GameConfig.GAME_ID,
		"progress": progress,
	})

# ── Internal HTTP ─────────────────────────────────────────────────────────

func _call(fn_name: String, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var url     := GameConfig.get_functions_url() + "/" + fn_name
	var body    := JSON.stringify({ "data": payload })
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + _id_token,
	])

	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		# Logger.error("NetworkManager: request error", { "fn": fn_name, "err": err })
		GameBus.sync_failed.emit("request error")
		return {}

	var result: Array = await http.request_completed
	http.queue_free()

	var status: int    = result[1]
	var raw:    String = result[3].get_string_from_utf8()

	if status != 200:
		# Logger.error("NetworkManager: HTTP error", { "fn": fn_name, "status": status })
		GameBus.sync_failed.emit("HTTP " + str(status))
		return {}

	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed.get("result", {})

	# Logger.error("NetworkManager: bad response", { "fn": fn_name })
	return {}
