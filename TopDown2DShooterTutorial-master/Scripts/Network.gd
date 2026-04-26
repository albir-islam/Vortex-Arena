extends Node

signal login_completed(profile_data)
signal login_failed(error)
signal match_joined(match_id)
signal player_moved(player_id, position)
signal player_shot(player_id, position, direction)
signal player_hit(target_id, damage)
signal join_failed(error_msg)
signal player_died(player_id)

func _ws_base_url() -> String:
	return APIService.get_ws_url("/ws/game")

var ws := WebSocketPeer.new()
var my_id := ""
var my_username := ""
var connected := false
var current_match_id := ""
var auth_token := ""

# =========================
# LOGIN & MATCH JOIN
# =========================
func login(username: String, password: String):
	# Use APIService for login
	APIService.login(username, password, func(success, data):
		if success:
			my_username = data["username"]
			my_id = str(data["userId"])
			auth_token = username
			
			# Store player data in GameState
			GameState.set_player_profile(data)
			
			print("Logged in as:", my_username, "ID:", my_id)
			emit_signal("login_completed", data)
			
			# Don't join match automatically
			# _join_match()
		else:
			emit_signal("login_failed", data)
	)

func _join_match():
	APIService.join_match(func(success, data):
		if success:
			current_match_id = data["matchId"]
			print("Joined match:", current_match_id)
			emit_signal("match_joined", current_match_id)
			
			# Connect to WebSocket (backend doesn't use matchId in URL path)
			var ws_url := _ws_base_url()
			print("Connecting to WebSocket:", ws_url)
			ws.connect_to_url(ws_url)
			connected = true
			
			# Send LOGIN message after connection
			await get_tree().create_timer(0.5).timeout
			_send_login_message()
		else:
			emit_signal("join_failed", "Failed to join match")
	)

func join_match():
	_join_match()

func _send_login_message():
	var login_msg = {
		"type": "LOGIN",
		"senderId": my_username,
		"payload": {
			"token": auth_token
		}
	}
	_send_message(login_msg)

# =========================
# GODOT LOOP
# =========================
func _process(_delta):
	if not connected:
		return

	ws.poll()
	
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var packet = ws.get_packet()
			var msg_str = packet.get_string_from_utf8()
			_handle_message(msg_str)
	elif state == WebSocketPeer.STATE_CLOSED:
		print("WebSocket closed")
		connected = false


# =========================
# SEND TO SERVER
# =========================
func _send_message(data: Dictionary):
	if not connected or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var json_str = JSON.stringify(data)
	ws.send_text(json_str)

func send_move(pos: Vector2):
	var move_msg = {
		"type": "MOVE",
		"senderId": my_username,
		"payload": {
			"x": pos.x,
			"y": pos.y
		}
	}
	_send_message(move_msg)

func send_shoot(position: Vector2, direction: float):
	var shoot_msg = {
		"type": "SHOOT",
		"senderId": my_username,
		"payload": {
			"x": position.x,
			"y": position.y,
			"direction": direction
		}
	}
	_send_message(shoot_msg)
	emit_signal("player_shot", my_username, position, direction)

func send_hit(target_id: String, damage: int):
	var hit_msg = {
		"type": "HIT",
		"senderId": my_username,
		"payload": {
			"targetId": target_id,
			"damage": damage
		}
	}
	_send_message(hit_msg)


# =========================
# RECEIVE FROM SERVER
# =========================
func _handle_message(msg: String):
	var data = JSON.parse_string(msg)
	if data == null:
		print("Failed to parse message:", msg)
		return

	var msg_type = data.get("type", "")
	
	match msg_type:
		"STATE":
			_handle_state_update(data)
		"MOVE":
			_handle_move(data)
		"SHOOT":
			_handle_shoot(data)
		"HIT":
			_handle_hit(data)
		"PLAYER_DIED":
			_handle_player_died(data)
		"PLAYER_JOINED":
			print("Player joined:", data.get("senderId"))
		"PLAYER_LEFT":
			print("Player left:", data.get("senderId"))
		_:
			print("Unknown message type:", msg_type)

func _handle_state_update(_data: Dictionary):
	var players = _data.get("payload", {}).get("players", [])
	for player_data in players:
		var player_id = str(player_data.get("id", ""))
		var x = float(player_data.get("x", 0))
		var y = float(player_data.get("y", 0))
		
		if player_id != my_username:
			GameManager.update_remote_player(player_id, x, y)

func _handle_move(_data: Dictionary):
	var sender_id = _data.get("senderId", "")
	if sender_id == my_username:
		return
	
	var payload = _data.get("payload", {})
	var x = float(payload.get("x", 0))
	var y = float(payload.get("y", 0))
	
	GameManager.update_remote_player(sender_id, x, y)
	emit_signal("player_moved", sender_id, Vector2(x, y))

func _handle_shoot(_data: Dictionary):
	var sender_id = _data.get("senderId", "")
	var payload = _data.get("payload", {})
	var x = float(payload.get("x", 0))
	var y = float(payload.get("y", 0))
	var direction = float(payload.get("direction", 0))
	
	emit_signal("player_shot", sender_id, Vector2(x, y), direction)

func _handle_hit(_data: Dictionary):
	var payload = _data.get("payload", {})
	var target_id = payload.get("targetId", "")
	var damage = int(payload.get("damage", 0))
	
	emit_signal("player_hit", target_id, damage)
	
	# If we are the target, update our health
	if target_id == my_username:
		GameState.take_damage(damage)

func _handle_player_died(_data: Dictionary):
	var sender_id = _data.get("senderId", "")
	emit_signal("player_died", sender_id)
	print("Player died:", sender_id)

# =========================
# CLEANUP
# =========================
func disconnect_from_match():
	if connected:
		ws.close()
		connected = false
	
	if current_match_id:
		APIService.leave_match(func(success, data):
			print("Left match:", current_match_id)
		)
		current_match_id = ""
