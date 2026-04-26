extends Node

# Singleton for handling all REST API calls to Vortex Arena backend

signal profile_loaded(profile_data)
signal stats_updated(stats_data)
signal inventory_synced(inventory_data)
signal api_error(error_message)

const DEFAULT_SERVER_HOST := "localhost"
const DEFAULT_SERVER_PORT := 7320

var server_host: String = DEFAULT_SERVER_HOST
var server_port: int = DEFAULT_SERVER_PORT
var _config_loaded := false

var http_client: HTTPRequest = null
var current_token: String = ""
var current_user_id: int = 0

func _load_server_config() -> void:
	if _config_loaded:
		return
	_config_loaded = true

	var env_host := OS.get_environment("VORTEX_ARENA_HOST")
	if env_host != "":
		server_host = env_host
	else:
		server_host = str(ProjectSettings.get_setting("vortex_arena/server_host", DEFAULT_SERVER_HOST))

	var env_port := OS.get_environment("VORTEX_ARENA_PORT")
	if env_port != "" and env_port.is_valid_int():
		server_port = int(env_port)
	else:
		server_port = int(ProjectSettings.get_setting("vortex_arena/server_port", DEFAULT_SERVER_PORT))

func get_http_base_url() -> String:
	_load_server_config()
	return "http://%s:%d" % [server_host, server_port]

func get_ws_url(path: String) -> String:
	_load_server_config()
	return "ws://%s:%d%s" % [server_host, server_port, path]

func _ready():
	_load_server_config()
	# Create persistent HTTP client
	http_client = HTTPRequest.new()
	add_child(http_client)

func _http_result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "BODY_DECOMPRESS_FAILED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "REQUEST_FAILED"
		_:
			return str(result)

# =========================
# AUTHENTICATION
# =========================
func login(username: String, password: String, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"username": username,
		"password": password
	})
	
	var url := get_http_base_url() + "/auth/login"
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			if data:
				current_user_id = data["userId"]
				current_token = username  # Store for later use
				callback.call(true, data)
		else:
			var error_msg := "Login failed: HTTP %s" % str(code)
			if code == 0:
				error_msg = "Login failed: cannot reach %s (result=%s)" % [url, _http_result_name(result)]
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)

	req.request(url, headers, HTTPClient.METHOD_POST, body)

func register(username: String, password: String, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"username": username,
		"password": password
	})
	
	var url := get_http_base_url() + "/auth/register"
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			if data:
				current_user_id = data["userId"]
				current_token = username
				callback.call(true, data)
		else:
			var error_msg := "Register failed: HTTP %s" % str(code)
			if code == 0:
				error_msg = "Register failed: cannot reach %s (result=%s)" % [url, _http_result_name(result)]
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)

	req.request(url, headers, HTTPClient.METHOD_POST, body)

# =========================
# PLAYER PROFILE
# =========================
func get_player_profile(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			emit_signal("profile_loaded", data)
			callback.call(true, data)
		else:
			var error_msg = "Failed to load profile: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)

	req.request(get_http_base_url() + "/api/player/profile?userId=" + str(user_id))

# =========================
# MATCH MANAGEMENT
# =========================
func join_match(callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + current_token
	]
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			var error_msg = "Failed to join match: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)

	req.request(get_http_base_url() + "/api/match/join", headers, HTTPClient.METHOD_POST)

func leave_match(callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + current_token
	]
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			callback.call(true, null)
		else:
			var error_msg = "Failed to leave match: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)
	
	req.request(get_http_base_url() + "/api/match/leave", headers, HTTPClient.METHOD_POST)

# =========================
# GAME STATS
# =========================
func update_stats(user_id: int, kills: int, score: int, health: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"userId": user_id,
		"kills": kills,
		"score": score,
		"health": health
	})
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			emit_signal("stats_updated", data)
			callback.call(true, data)
		else:
			var error_msg = "Failed to update stats: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)
	
	req.request(get_http_base_url() + "/api/update-stats", headers, HTTPClient.METHOD_POST, body)

func handle_kill(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"userId": user_id
	})
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			var error_msg = "Failed to handle kill: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)
	
	req.request(get_http_base_url() + "/api/handle-kill", headers, HTTPClient.METHOD_POST, body)

# =========================
# INVENTORY
# =========================
func sync_inventory(user_id: int, inventory_data: Dictionary, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = ["Content-Type: application/json"]
	var payload = {
		"userId": user_id,
		"primaryWeapon": inventory_data.get("primaryWeapon", "AKM"),
		"secondaryWeapon": inventory_data.get("secondaryWeapon", "UZI"),
		"firstAidCount": inventory_data.get("firstAidCount", 0),
		"medkitCount": inventory_data.get("medkitCount", 0),
		"boostCount": inventory_data.get("boostCount", 0),
		"helmetLevel": inventory_data.get("helmetLevel", 0),
		"vestLevel": inventory_data.get("vestLevel", 0)
	}
	var body = JSON.stringify(payload)
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			emit_signal("inventory_synced", data)
			callback.call(true, data)
		else:
			var error_msg = "Failed to sync inventory: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)
	
	req.request(get_http_base_url() + "/api/sync-inventory", headers, HTTPClient.METHOD_POST, body)

func use_healing(user_id: int, heal_amount: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"userId": user_id,
		"healAmount": heal_amount
	})
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			var error_msg = "Failed to heal: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)
	
	req.request(get_http_base_url() + "/api/heal", headers, HTTPClient.METHOD_POST, body)

# =========================
# LEADERBOARD
# =========================
func get_leaderboard(callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			var error_msg = "Failed to load leaderboard: HTTP " + str(code)
			emit_signal("api_error", error_msg)
			callback.call(false, error_msg)
		req.queue_free()
	)
	
	req.request(get_http_base_url() + "/api/leaderboard")

# =========================
# ECONOMY (Coins & Gems)
# =========================
func get_wallet(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load wallet: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/economy/wallet?userId=" + str(user_id))

func spend_coins(user_id: int, amount: int, callback: Callable):
	_post_json("/api/economy/spend-coins", {"userId": user_id, "amount": amount}, callback)

func spend_gems(user_id: int, amount: int, callback: Callable):
	_post_json("/api/economy/spend-gems", {"userId": user_id, "amount": amount}, callback)

# =========================
# COSMETICS (Skins & Effects)
# =========================
func get_cosmetics(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load cosmetics: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/cosmetics?userId=" + str(user_id))

func unlock_cosmetic(user_id: int, cosmetic_id: int, callback: Callable):
	_post_json("/api/cosmetics/unlock", {"userId": user_id, "cosmeticId": cosmetic_id}, callback)

func equip_cosmetic(user_id: int, cosmetic_id: int, callback: Callable):
	_post_json("/api/cosmetics/equip", {"userId": user_id, "cosmeticId": cosmetic_id}, callback)

func unequip_cosmetic(user_id: int, cosmetic_id: int, callback: Callable):
	_post_json("/api/cosmetics/unequip", {"userId": user_id, "cosmeticId": cosmetic_id}, callback)

# =========================
# ACHIEVEMENTS
# =========================
func get_achievements(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load achievements: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/achievements?userId=" + str(user_id))

func check_achievements(user_id: int, callback: Callable):
	_post_json("/api/achievements/check", {"userId": user_id}, callback)

# =========================
# MATCH HISTORY
# =========================
func get_match_history(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load match history: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/history?userId=" + str(user_id))

# =========================
# ELO RANKING
# =========================
func get_elo(user_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load ELO: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/elo?userId=" + str(user_id))

func get_elo_leaderboard(callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load ELO leaderboard: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/elo/leaderboard")

# =========================
# SEASONS
# =========================
func get_current_season(callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load current season: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/seasons/current")

func get_season_leaderboard(season_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load season leaderboard: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/seasons/" + str(season_id) + "/leaderboard")

# =========================
# TOURNAMENTS
# =========================
func get_tournaments(callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load tournaments: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/tournaments")

func join_tournament(tournament_id: int, user_id: int, callback: Callable):
	_post_json("/api/tournaments/" + str(tournament_id) + "/join?userId=" + str(user_id), {}, callback)

func get_tournament_bracket(tournament_id: int, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load bracket: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/tournaments/" + str(tournament_id) + "/bracket")

# =========================
# REPLAYS
# =========================
func get_replay(match_id: String, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			callback.call(false, "Failed to load replay: HTTP " + str(code))
		req.queue_free()
	)
	req.request(get_http_base_url() + "/api/replays/" + match_id)

# =========================
# HELPER: Generic POST with JSON body
# =========================
func _post_json(endpoint: String, body_dict: Dictionary, callback: Callable):
	var req := HTTPRequest.new()
	add_child(req)
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(body_dict)
	req.request_completed.connect(func(result, code, _headers, response_body):
		if code == 200:
			var data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(true, data)
		else:
			var err_text = response_body.get_string_from_utf8() if response_body.size() > 0 else ""
			callback.call(false, "HTTP " + str(code) + ": " + err_text)
		req.queue_free()
	)
	req.request(get_http_base_url() + endpoint, headers, HTTPClient.METHOD_POST, body)
