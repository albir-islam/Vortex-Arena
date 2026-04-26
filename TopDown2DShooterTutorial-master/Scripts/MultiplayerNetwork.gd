extends Node

# Multiplayer Network Manager
# Handles WebSocket communication with Spring Boot multiplayer server

signal connected()
signal disconnected()
signal connection_error(error: String)

signal match_joined(match_id: String, players: Array)
signal match_started(duration: int, players: Array)
signal match_ended(scoreboard: Array)

signal player_joined(player_id: String, username: String, x: float, y: float)
signal player_left(player_id: String)
signal player_ready_changed(player_id: String, ready: bool)
signal player_moved(player_id: String, x: float, y: float, rotation: float)
signal player_shot(player_id: String, x: float, y: float, direction: float)
signal player_damaged(player_id: String, damage: int, health: int)
signal player_killed(killer_id: String, victim_id: String)
signal player_respawned(player_id: String, x: float, y: float)

signal scoreboard_updated(scoreboard: Array)
signal time_updated(remaining_time: int)
signal chat_received(sender_id: String, username: String, message: String)
signal spectate_response(match_id: String, players: Array)
signal spectate_update(players: Array, scoreboard: Array)

func _ws_multiplayer_url() -> String:
	return APIService.get_ws_url("/ws/multiplayer")

var ws := WebSocketPeer.new()
var is_connected := false
var my_player_id := ""
var my_username := ""
var current_match_id := ""
var match_status := "WAITING" # WAITING, IN_PROGRESS, FINISHED

# Latest server snapshots for reliable client-side spawning/UI.
var _players_snapshot: Array = []
var _scoreboard_snapshot: Array = []
var _remaining_time_snapshot: int = 0

func get_players_snapshot() -> Array:
	return _players_snapshot

func get_scoreboard_snapshot() -> Array:
	return _scoreboard_snapshot

func get_remaining_time_snapshot() -> int:
	return _remaining_time_snapshot

func get_player_snapshot(player_id: String) -> Dictionary:
	for p in _players_snapshot:
		if str(p.get("playerId", "")) == str(player_id):
			return p
	return {}

# Position sync
var last_position_sync := 0.0
var position_sync_interval := 0.05 # 50ms

func _ready():
	set_process(false) # Disabled until connected

func connect_to_server(player_id: String, username: String) -> void:
	my_player_id = player_id
	my_username = username
	
	var ws_url := _ws_multiplayer_url()
	print("[MultiplayerNetwork] Connecting to ", ws_url)
	var err := ws.connect_to_url(ws_url)
	if err != OK:
		emit_signal("connection_error", "Failed to initiate connection")
		return
	
	set_process(true)

func disconnect_from_server() -> void:
	if is_connected:
		send_leave()
	ws.close()
	is_connected = false
	current_match_id = ""
	match_status = "WAITING"
	set_process(false)
	emit_signal("disconnected")

func _process(delta):
	ws.poll()
	
	var state := ws.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			if not is_connected:
				is_connected = true
				print("[MultiplayerNetwork] Connected!")
				emit_signal("connected")
				# Automatically send join message
				send_join()
			
			# Process incoming messages
			while ws.get_available_packet_count() > 0:
				var packet := ws.get_packet()
				var msg_str := packet.get_string_from_utf8()
				_handle_message(msg_str)
		
		WebSocketPeer.STATE_CLOSED:
			if is_connected:
				is_connected = false
				print("[MultiplayerNetwork] Disconnected")
				emit_signal("disconnected")
			set_process(false)
		
		WebSocketPeer.STATE_CLOSING:
			pass # Wait for close to complete

# ==================== Send Messages ====================

func _send_message(data: Dictionary) -> void:
	if not is_connected or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var json_str := JSON.stringify(data)
	ws.send_text(json_str)

func send_join() -> void:
	var msg := {
		"type": "JOIN",
		"senderId": my_player_id,
		"payload": {
			"username": my_username
		}
	}
	_send_message(msg)

func send_leave() -> void:
	var msg := {
		"type": "LEAVE",
		"senderId": my_player_id
	}
	_send_message(msg)

func send_ready(ready: bool = true) -> void:
	var msg := {
		"type": "READY",
		"senderId": my_player_id,
		"payload": {
			"ready": ready
		}
	}
	_send_message(msg)

func send_start_match_request() -> void:
	# Optional: if the backend supports it, this requests a match start.
	# Lobby.gd still has a local fallback to avoid deadlocks.
	var msg := {
		"type": "START_MATCH",
		"senderId": my_player_id
	}
	_send_message(msg)

func send_move(position: Vector2, rotation: float) -> void:
	var msg := {
		"type": "MOVE",
		"senderId": my_player_id,
		"payload": {
			"x": position.x,
			"y": position.y,
			"rotation": rotation
		}
	}
	_send_message(msg)

func send_shoot(position: Vector2, direction: float) -> void:
	var msg := {
		"type": "SHOOT",
		"senderId": my_player_id,
		"payload": {
			"x": position.x,
			"y": position.y,
			"direction": direction
		}
	}
	_send_message(msg)

func send_hit_player(target_id: String, damage: int) -> void:
	var msg := {
		"type": "HIT_PLAYER",
		"senderId": my_player_id,
		"payload": {
			"targetId": target_id,
			"damage": damage
		}
	}
	_send_message(msg)

func send_zombie_kill() -> void:
	var msg := {
		"type": "ZOMBIE_KILL",
		"senderId": my_player_id
	}
	_send_message(msg)

func send_respawn() -> void:
	var msg := {
		"type": "RESPAWN",
		"senderId": my_player_id
	}
	_send_message(msg)

func send_chat(message: String) -> void:
	if message.strip_edges().is_empty():
		return
	var msg := {
		"type": "CHAT",
		"senderId": my_player_id,
		"payload": {
			"message": message
		}
	}
	_send_message(msg)

func send_spectate(match_id: String) -> void:
	var msg := {
		"type": "SPECTATE",
		"senderId": my_player_id,
		"payload": {
			"matchId": match_id
		}
	}
	_send_message(msg)

func send_spectate_switch(target_player_id: String) -> void:
	var msg := {
		"type": "SPECTATE_SWITCH",
		"senderId": my_player_id,
		"payload": {
			"targetPlayerId": target_player_id
		}
	}
	_send_message(msg)

# ==================== Handle Messages ====================

func _handle_message(msg_str: String) -> void:
	var data = JSON.parse_string(msg_str)
	if data == null:
		print("[MultiplayerNetwork] Failed to parse: ", msg_str)
		return
	
	var msg_type: String = data.get("type", "")
	
	match msg_type:
		"JOIN_RESPONSE":
			_handle_join_response(data)
		"PLAYER_JOINED":
			_handle_player_joined(data)
		"PLAYER_LEFT":
			_handle_player_left(data)
		"PLAYER_READY":
			_handle_player_ready(data)
		"MATCH_START":
			_handle_match_start(data)
		"START_MATCH":
			# Alias for servers that use START_MATCH instead of MATCH_START.
			_handle_match_start(data)
		"MATCH_END":
			_handle_match_end(data)
		"STATE_UPDATE":
			_handle_state_update(data)
		"PLAYER_MOVED":
			_handle_player_moved(data)
		"PLAYER_SHOT":
			_handle_player_shot(data)
		"PLAYER_DAMAGED":
			_handle_player_damaged(data)
		"PLAYER_KILLED":
			_handle_player_killed(data)
		"PLAYER_RESPAWNED":
			_handle_player_respawned(data)
		"CHAT_MESSAGE":
			_handle_chat_message(data)
		"SCOREBOARD":
			_handle_scoreboard(data)
		"TIME_UPDATE":
			_handle_time_update(data)
		"SPECTATE_RESPONSE":
			_handle_spectate_response(data)
		"SPECTATE_UPDATE":
			_handle_spectate_update(data)
		"MATCH_REWARDS":
			_handle_match_rewards(data)
		"ERROR":
			print("[MultiplayerNetwork] Server error: ", data.get("error", "Unknown"))
		_:
			print("[MultiplayerNetwork] Unknown message type: ", msg_type)

func _handle_join_response(data: Dictionary) -> void:
	var success: bool = data.get("success", false)
	if not success:
		emit_signal("connection_error", "Failed to join match")
		return
	
	current_match_id = data.get("matchId", "")
	match_status = data.get("matchStatus", "WAITING")
	var players: Array = data.get("players", [])
	_players_snapshot = players
	if data.has("remainingTime"):
		_remaining_time_snapshot = int(data.get("remainingTime", 0))
	
	print("[MultiplayerNetwork] Joined match: ", current_match_id, " Status: ", match_status)
	emit_signal("match_joined", current_match_id, players)
	
	# If match is already in progress, we joined mid-game
	if match_status == "IN_PROGRESS":
		var remaining: int = int(data.get("remainingTime", 300))
		_remaining_time_snapshot = remaining
		emit_signal("match_started", remaining, players)

func _handle_player_joined(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	var username: String = data.get("username", "Player")
	var x: float = float(data.get("x", 0))
	var y: float = float(data.get("y", 0))
	
	if player_id != my_player_id:
		print("[MultiplayerNetwork] Player joined: ", username)
		emit_signal("player_joined", player_id, username, x, y)

func _handle_player_left(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	if player_id != my_player_id:
		print("[MultiplayerNetwork] Player left: ", player_id)
		emit_signal("player_left", player_id)

func _handle_player_ready(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	var ready: bool = data.get("ready", false)
	emit_signal("player_ready_changed", player_id, ready)

func _handle_match_start(data: Dictionary) -> void:
	match_status = "IN_PROGRESS"
	var duration: int = data.get("duration", 300)
	var players: Array = data.get("players", [])
	_players_snapshot = players
	_remaining_time_snapshot = duration
	print("[MultiplayerNetwork] Match started! Duration: ", duration, "s")
	emit_signal("match_started", duration, players)

func _handle_match_end(data: Dictionary) -> void:
	match_status = "FINISHED"
	var scoreboard: Array = data.get("scoreboard", [])
	print("[MultiplayerNetwork] Match ended!")
	emit_signal("match_ended", scoreboard)

func _handle_state_update(data: Dictionary) -> void:
	var players: Array = data.get("players", [])
	var remaining_time: int = data.get("remainingTime", 0)
	_players_snapshot = players
	_remaining_time_snapshot = remaining_time
	var has_scoreboard := data.has("scoreboard")
	var scoreboard: Array = []
	if has_scoreboard:
		scoreboard = data.get("scoreboard", [])
		_scoreboard_snapshot = scoreboard
	
	# Update remote players
	for p in players:
		var pid: String = str(p.get("playerId", ""))
		if pid != my_player_id:
			var x: float = float(p.get("x", 0))
			var y: float = float(p.get("y", 0))
			var rot: float = float(p.get("rotation", 0))
			emit_signal("player_moved", pid, x, y, rot)
	
	emit_signal("time_updated", remaining_time)
	# Always re-emit the cached scoreboard so the UI can refresh rows for
	# newly joined players and keep remote rows visible even when the server
	# omits the scoreboard field on some state updates.
	emit_signal("scoreboard_updated", _scoreboard_snapshot)

func _handle_player_moved(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	if player_id == my_player_id:
		return
	var x: float = float(data.get("x", 0))
	var y: float = float(data.get("y", 0))
	var rotation: float = float(data.get("rotation", 0))
	emit_signal("player_moved", player_id, x, y, rotation)

func _handle_player_shot(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	if player_id == my_player_id:
		return
	var x: float = float(data.get("x", 0))
	var y: float = float(data.get("y", 0))
	var direction: float = float(data.get("direction", 0))
	emit_signal("player_shot", player_id, x, y, direction)

func _handle_player_damaged(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	var damage: int = int(data.get("damage", 0))
	var health: int = int(data.get("health", 0))
	emit_signal("player_damaged", player_id, damage, health)

func _handle_player_killed(data: Dictionary) -> void:
	var killer_id: String = data.get("killerId", "")
	var victim_id: String = data.get("victimId", "")
	emit_signal("player_killed", killer_id, victim_id)

func _handle_player_respawned(data: Dictionary) -> void:
	var player_id: String = data.get("playerId", "")
	var x: float = float(data.get("x", 0))
	var y: float = float(data.get("y", 0))
	emit_signal("player_respawned", player_id, x, y)

func _handle_chat_message(data: Dictionary) -> void:
	var sender_id: String = data.get("senderId", "")
	var username: String = data.get("username", "Player")
	var message: String = data.get("message", "")
	emit_signal("chat_received", sender_id, username, message)

func _handle_scoreboard(data: Dictionary) -> void:
	var scoreboard: Array = data.get("scoreboard", [])
	_scoreboard_snapshot = scoreboard
	emit_signal("scoreboard_updated", scoreboard)

func _handle_time_update(data: Dictionary) -> void:
	var remaining: int = int(data.get("remainingTime", 0))
	_remaining_time_snapshot = remaining
	emit_signal("time_updated", remaining)

func _handle_spectate_response(data: Dictionary) -> void:
	var match_id: String = data.get("matchId", "")
	var players: Array = data.get("players", [])
	emit_signal("spectate_response", match_id, players)

func _handle_spectate_update(data: Dictionary) -> void:
	var players: Array = data.get("players", [])
	var scoreboard: Array = data.get("scoreboard", [])
	emit_signal("spectate_update", players, scoreboard)

func _handle_match_rewards(data: Dictionary) -> void:
	# Update local wallet/ELO when server sends post-match rewards
	var rewards = data.get("rewards", {})
	if rewards.has("coinsEarned"):
		GameState.coins += int(rewards.get("coinsEarned", 0))
	if rewards.has("gemsEarned"):
		GameState.gems += int(rewards.get("gemsEarned", 0))
	if rewards.has("newElo"):
		GameState.elo_rating = int(rewards.get("newElo", GameState.elo_rating))
	if rewards.has("newTier"):
		GameState.elo_tier = str(rewards.get("newTier", GameState.elo_tier))
	GameState.emit_signal("wallet_changed", GameState.coins, GameState.gems)
	GameState.emit_signal("elo_changed", GameState.elo_rating, GameState.elo_tier)
	print("[MultiplayerNetwork] Match rewards received: ", rewards)
