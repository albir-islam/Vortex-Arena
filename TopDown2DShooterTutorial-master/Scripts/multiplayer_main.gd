extends Node

# Multiplayer main game scene
# Handles PvP + PvE, respawning, scoreboard, and chat

@onready var player: Player = $Player
@onready var tilemap: TileMap = $TileMap
@onready var multiplayer_network = get_node("/root/MultiplayerNetwork")

var remote_player_scene: PackedScene = preload("res://Scenes/remote_player.tscn")
var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")

var remote_players: Dictionary = {} # player_id -> node
var is_dead: bool = false
var remaining_time: int = 300

# UI References (created dynamically)
var scoreboard_panel: Control
var chat_panel: Control
var respawn_panel: Control
var death_stats_label: Label

# Scoreboard content reference (avoids fragile node-path lookups)
var scoreboard_content: VBoxContainer

# Chat state
var chat_visible: bool = false
var chat_input: LineEdit
var chat_messages: VBoxContainer
var chat_scroll: ScrollContainer

# Scoreboard colors (Valorant-ish accents)
const _SCOREBOARD_ACCENT := Color(0.20, 0.90, 0.85, 1.0)

# Spectator mode
var is_spectating: bool = false
var spectate_target_id: String = ""
var spectate_label: Label
var spectate_target_index: int = 0
const _PLAYER_COLORS := [
	Color(0.36, 0.68, 1.0, 1.0), # blue
	Color(1.0, 0.35, 0.35, 1.0),  # red
	Color(0.98, 0.78, 0.22, 1.0), # yellow
	Color(0.42, 1.0, 0.60, 1.0),  # green
	Color(1.0, 0.55, 0.95, 1.0),  # pink
	Color(1.0, 0.60, 0.20, 1.0),  # orange
]

func _get_player_ui() -> PlayerUI:
	var scene = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("PlayerUI") as PlayerUI

func _ready():
	if MusicManager and MusicManager.has_method("mute_music"):
		MusicManager.mute_music()

	# Setup multiplayer UI
	_setup_multiplayer_ui()
	
	# Connect to multiplayer signals
	multiplayer_network.player_joined.connect(_on_player_joined)
	multiplayer_network.player_left.connect(_on_player_left)
	multiplayer_network.player_moved.connect(_on_player_moved)
	multiplayer_network.player_shot.connect(_on_player_shot)
	multiplayer_network.player_damaged.connect(_on_player_damaged)
	multiplayer_network.player_killed.connect(_on_player_killed)
	multiplayer_network.player_respawned.connect(_on_player_respawned)
	multiplayer_network.scoreboard_updated.connect(_on_scoreboard_updated)
	multiplayer_network.time_updated.connect(_on_time_updated)
	multiplayer_network.chat_received.connect(_on_chat_received)
	multiplayer_network.match_ended.connect(_on_match_ended)
	multiplayer_network.spectate_update.connect(_on_spectate_update)
	
	# Spawn existing players that were in match when we joined
	_spawn_initial_players()
	_sync_from_network_snapshot()
	# If we already have a scoreboard snapshot (JOIN_RESPONSE/STATE_UPDATE), render it.
	_on_scoreboard_updated(multiplayer_network.get_scoreboard_snapshot())
	
	# Connect player signals
	if player:
		player.died.connect(_on_local_player_died)
		player.health_changed.connect(_on_health_changed)
		player.kills_changed.connect(_on_local_kills_score_changed)

	# Render initial scoreboard with zeros.
	_render_scoreboard_from_snapshot()

func _get_local_player_id() -> String:
	# Prefer the network id, but fall back to the player id or GameState user id.
	if multiplayer_network and str(multiplayer_network.my_player_id) != "":
		return str(multiplayer_network.my_player_id)
	if player and player.has_method("get_player_id"):
		var pid := str(player.call("get_player_id"))
		if pid != "":
			return pid
	if GameState and int(GameState.user_id) != 0:
		return str(GameState.user_id)
	return "local"

func _color_for_player_id(player_id: String) -> Color:
	if player_id == "":
		return _PLAYER_COLORS[0]
	var h := int(player_id.hash())
	if h < 0:
		h = -h
	return _PLAYER_COLORS[h % _PLAYER_COLORS.size()]

func _process(delta):
	# Local player movement networking is handled by Player.gd.
	pass

func _sync_from_network_snapshot() -> void:
	if multiplayer_network == null:
		return
	var players: Array = multiplayer_network.get_players_snapshot()
	for p in players:
		var pd: Dictionary = p if p is Dictionary else {}
		var pid := str(pd.get("playerId", ""))
		if pid == "" or pid == multiplayer_network.my_player_id:
			continue
		var username := str(pd.get("username", "Player"))
		var x := float(pd.get("x", 500))
		var y := float(pd.get("y", 500))
		_spawn_remote_player(pid, username, x, y)

func _input(event):
	# Tab to show scoreboard (hold-to-show)
	if not chat_visible:
		if event.is_action_pressed("ui_focus_next"): # Tab key
			if scoreboard_panel:
				_render_scoreboard_from_snapshot()
				scoreboard_panel.visible = true
		elif event.is_action_released("ui_focus_next"):
			if scoreboard_panel:
				scoreboard_panel.visible = false
	
	# Chat open (project input action)
	if event.is_action_pressed("open_chat") and not chat_visible:
		_open_chat()

	if event is InputEventKey:
		# Enter to send chat message
		if event.keycode == KEY_ENTER and event.pressed and chat_visible:
			_send_chat_message()
		
		# Escape to close chat
		if event.keycode == KEY_ESCAPE and event.pressed and chat_visible:
			_close_chat()
		
		# Spectator mode: Arrow keys to switch target
		if is_spectating and event.pressed and not event.echo:
			if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
				var direction = 1 if event.keycode == KEY_RIGHT else -1
				_cycle_spectate_target(direction)

func _setup_multiplayer_ui():
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	# Timer: the base scene already has PlayerUI/MatchTimer (top-center).
	# Avoid adding a second timer here (it causes the overlapping double-timer).
	
	# === SCOREBOARD (center, hidden by default) ===
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.anchor_left = 0.5
	scoreboard_panel.anchor_right = 0.5
	scoreboard_panel.anchor_top = 0.5
	scoreboard_panel.anchor_bottom = 0.5
	scoreboard_panel.offset_left = -320
	scoreboard_panel.offset_right = 320
	scoreboard_panel.offset_top = -240
	scoreboard_panel.offset_bottom = 240
	scoreboard_panel.visible = false
	
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color(0.06, 0.07, 0.10, 0.94)
	sb_style.corner_radius_top_left = 10
	sb_style.corner_radius_top_right = 10
	sb_style.corner_radius_bottom_right = 10
	sb_style.corner_radius_bottom_left = 10
	sb_style.border_width_left = 2
	sb_style.border_width_top = 2
	sb_style.border_width_right = 2
	sb_style.border_width_bottom = 2
	sb_style.border_color = Color(0.20, 0.22, 0.30, 1.0)
	scoreboard_panel.add_theme_stylebox_override("panel", sb_style)
	canvas.add_child(scoreboard_panel)
	
	var sb_vbox := VBoxContainer.new()
	sb_vbox.name = "ScoreboardVBox"
	sb_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb_vbox.add_theme_constant_override("separation", 10)
	scoreboard_panel.add_child(sb_vbox)

	# Accent bar
	var accent := ColorRect.new()
	accent.color = _SCOREBOARD_ACCENT
	accent.custom_minimum_size = Vector2(0, 3)
	accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb_vbox.add_child(accent)
	
	var sb_title := Label.new()
	sb_title.text = "SCOREBOARD"
	sb_title.add_theme_font_size_override("font_size", 28)
	sb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb_title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	sb_vbox.add_child(sb_title)

	var sb_hint := Label.new()
	sb_hint.text = "Hold TAB"
	sb_hint.add_theme_font_size_override("font_size", 14)
	sb_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb_hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.78))
	sb_vbox.add_child(sb_hint)
	
	# Column headers
	var sb_header := GridContainer.new()
	sb_header.columns = 4
	sb_header.add_theme_constant_override("h_separation", 20)
	sb_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb_vbox.add_child(sb_header)
	_add_scoreboard_header(sb_header)
	
	var sb_scroll := ScrollContainer.new()
	sb_scroll.name = "ScoreboardScroll"
	sb_scroll.custom_minimum_size = Vector2(0, 280)
	sb_vbox.add_child(sb_scroll)
	
	var sb_content := VBoxContainer.new()
	sb_content.name = "ScoreboardContent"
	sb_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb_scroll.add_child(sb_content)
	scoreboard_content = sb_content
	
	# === CHAT PANEL (bottom right) ===
	chat_panel = Control.new()
	# Use anchors/offsets so it stays visible for any resolution.
	# (Bottom-left is more "Valorant-like" and avoids minimap overlap in many layouts.)
	chat_panel.anchor_left = 0
	chat_panel.anchor_right = 0
	chat_panel.anchor_top = 1
	chat_panel.anchor_bottom = 1
	chat_panel.offset_left = 15
	chat_panel.offset_right = 15 + 280
	chat_panel.offset_top = -(15 + 190)
	chat_panel.offset_bottom = -15
	canvas.add_child(chat_panel)
	
	var chat_bg := ColorRect.new()
	chat_bg.color = Color(0, 0, 0, 0.5)
	chat_bg.size = Vector2(280, 150)
	chat_panel.add_child(chat_bg)
	
	chat_scroll = ScrollContainer.new()
	chat_scroll.size = Vector2(270, 140)
	chat_scroll.position = Vector2(5, 5)
	chat_panel.add_child(chat_scroll)
	
	chat_messages = VBoxContainer.new()
	chat_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_scroll.add_child(chat_messages)
	
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Press Y to chat..."
	chat_input.size = Vector2(280, 32)
	chat_input.position = Vector2(0, 155)
	# Allow keyboard focus; otherwise grab_focus() may not work.
	chat_input.focus_mode = Control.FOCUS_ALL
	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_input.editable = false
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	chat_input.gui_input.connect(_on_chat_input_gui_input)
	chat_panel.add_child(chat_input)
	
	# === RESPAWN PANEL (center, hidden) ===
	respawn_panel = PanelContainer.new()
	respawn_panel.set_anchors_preset(Control.PRESET_CENTER)
	respawn_panel.custom_minimum_size = Vector2(400, 250)
	respawn_panel.offset_left = -200
	respawn_panel.offset_top = -125
	respawn_panel.offset_right = 200
	respawn_panel.offset_bottom = 125
	respawn_panel.visible = false
	
	var resp_style := StyleBoxFlat.new()
	resp_style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	resp_style.corner_radius_top_left = 10
	resp_style.corner_radius_top_right = 10
	resp_style.corner_radius_bottom_right = 10
	resp_style.corner_radius_bottom_left = 10
	respawn_panel.add_theme_stylebox_override("panel", resp_style)
	canvas.add_child(respawn_panel)
	
	var resp_vbox := VBoxContainer.new()
	resp_vbox.add_theme_constant_override("separation", 15)
	resp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	respawn_panel.add_child(resp_vbox)
	
	var death_title := Label.new()
	death_title.text = "YOU DIED!"
	death_title.add_theme_font_size_override("font_size", 36)
	death_title.add_theme_color_override("font_color", Color.RED)
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resp_vbox.add_child(death_title)
	
	death_stats_label = Label.new()
	death_stats_label.text = "Score: 0\nPlayer Kills: 0\nZombie Kills: 0"
	death_stats_label.add_theme_font_size_override("font_size", 20)
	death_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resp_vbox.add_child(death_stats_label)
	
	var respawn_btn = Button.new()
	respawn_btn.text = "RESPAWN"
	respawn_btn.custom_minimum_size = Vector2(150, 50)
	respawn_btn.add_theme_font_size_override("font_size", 24)
	respawn_btn.pressed.connect(_on_respawn_pressed)
	resp_vbox.add_child(respawn_btn)

	var spectate_btn = Button.new()
	spectate_btn.text = "SPECTATE"
	spectate_btn.custom_minimum_size = Vector2(150, 40)
	spectate_btn.add_theme_font_size_override("font_size", 18)
	spectate_btn.modulate = Color(0.5, 0.8, 1.0)
	spectate_btn.pressed.connect(_on_spectate_pressed)
	resp_vbox.add_child(spectate_btn)


func _add_scoreboard_header(container: Control):
	var headers = ["Player", "Score", "Player Kills", "Zombie Kills"]
	# Must fit inside the panel width (with h_separation).
	var widths = [200, 100, 120, 120]
	
	for i in range(headers.size()):
		var lbl = Label.new()
		lbl.text = headers[i]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.custom_minimum_size.x = widths[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(lbl)

func _spawn_initial_players():
	# Spawn players that were already in the match when we joined
	for p in GameState.multiplayer_players:
		var pid = str(p.get("playerId", ""))
		if pid != multiplayer_network.my_player_id:
			var username = p.get("username", "Player")
			var x = float(p.get("x", 500))
			var y = float(p.get("y", 500))
			_spawn_remote_player(pid, username, x, y)

func _spawn_remote_player(player_id: String, username: String, x: float, y: float):
	if remote_players.has(player_id):
		return
	
	var rp = remote_player_scene.instantiate()
	rp.global_position = Vector2(x, y)
	rp.set_player_id(player_id)
	
	# Disable camera on remote player
	if rp.has_node("Camera2D"):
		rp.get_node("Camera2D").queue_free()
	
	# Add name label
	var lbl := Label.new()
	lbl.text = username
	lbl.position = Vector2(-30, -50)
	lbl.add_theme_font_size_override("font_size", 14)
	rp.add_child(lbl)
	
	add_child(rp)
	remote_players[player_id] = rp
	print("[MP] Spawned remote player: ", username)

func _remove_remote_player(player_id: String):
	if remote_players.has(player_id):
		remote_players[player_id].queue_free()
		remote_players.erase(player_id)

# ==================== Multiplayer Signal Handlers ====================

func _on_player_joined(player_id: String, username: String, x: float, y: float):
	_spawn_remote_player(player_id, username, x, y)
	_add_chat_system_message(username + " joined the game")

func _on_player_left(player_id: String):
	if remote_players.has(player_id):
		_add_chat_system_message("A player left the game")
	_remove_remote_player(player_id)

func _on_player_moved(player_id: String, x: float, y: float, rotation: float):
	if not remote_players.has(player_id):
		# Late-join or missed PLAYER_JOINED: spawn from snapshot.
		var snap: Dictionary = {}
		if multiplayer_network:
			snap = multiplayer_network.get_player_snapshot(player_id)
		var username = str(snap.get("username", "Player"))
		_spawn_remote_player(player_id, username, x, y)
	var rp = remote_players[player_id]
	rp.target_position = Vector2(x, y)
	rp.rotation = rotation

func _on_player_shot(player_id: String, x: float, y: float, direction: float):
	# Spawn bullet from remote player
	if remote_players.has(player_id):
		var bullet = bullet_scene.instantiate()
		bullet.global_position = Vector2(x, y)
		bullet.rotation = direction
		if bullet.has_method("set"):
			bullet.set("move_direction", Vector2.RIGHT.rotated(direction))
		bullet.set("shooter_id", player_id)
		get_tree().current_scene.add_child(bullet)

func _on_player_damaged(player_id: String, damage: int, health: int):
	if player_id == multiplayer_network.my_player_id:
		# We got hit
		if player and player.health_system:
			if player.has_method("is_dead") and bool(player.call("is_dead")):
				return
			if player.has_method("is_invulnerable") and bool(player.call("is_invulnerable")):
				return
			player.health_system.current_health = health
			player.emit_signal("health_changed", health, player.health_system.base_health)
	else:
		# Remote player got hit - show damage feedback
		if not remote_players.has(player_id):
			var snap: Dictionary = {}
			if multiplayer_network:
				snap = multiplayer_network.get_player_snapshot(player_id)
			var username = str(snap.get("username", "Player"))
			var x = float(snap.get("x", 500))
			var y = float(snap.get("y", 500))
			_spawn_remote_player(player_id, username, x, y)
		var rp = remote_players[player_id]
		if rp.has_method("set_health"):
			rp.set_health(health)
		else:
			rp.current_health = health
		if rp.has_method("hit_effect"):
			rp.hit_effect()

func _on_player_killed(killer_id: String, victim_id: String):
	var killer_name = "Someone"
	var victim_name = "Someone"
	
	if killer_id == multiplayer_network.my_player_id:
		killer_name = "You"
		GameState.add_mp_player_kill()
		_render_scoreboard_from_snapshot()
		if MusicManager and MusicManager.has_method("play_kill"):
			MusicManager.play_kill()
	
	if victim_id == multiplayer_network.my_player_id:
		victim_name = "You"
		_show_death_screen()

	if MusicManager and MusicManager.has_method("play_death"):
		MusicManager.play_death()
	
	_add_chat_system_message(killer_name + " killed " + victim_name + "!")

func _on_player_respawned(player_id: String, x: float, y: float):
	if player_id == multiplayer_network.my_player_id:
		# Respawn local player
		_do_respawn(Vector2(x, y))
	else:
		# Remote player respawned
		if remote_players.has(player_id):
			var rp = remote_players[player_id]
			rp.global_position = Vector2(x, y)
			rp.current_health = 100
			rp.modulate = Color.WHITE

func _on_scoreboard_updated(scoreboard: Array):
	_update_scoreboard_ui(_merge_local_stats_into_scoreboard(scoreboard))

func _on_time_updated(time: int):
	remaining_time = time
	var ui := _get_player_ui()
	if ui and ui.has_method("set_match_time_left"):
		ui.set_match_time_left(time)

func _on_chat_received(sender_id: String, username: String, message: String):
	_add_chat_message(username, message)

func _on_match_ended(scoreboard: Array):
	is_spectating = false
	if spectate_label:
		spectate_label.queue_free()
		spectate_label = null
	_show_match_rewards_screen(scoreboard)

func _on_local_player_died():
	is_dead = true
	_show_death_screen()

func _on_health_changed(current: int, max_hp: int):
	pass # UI handled by PlayerUI

# ==================== UI Functions ====================

func _toggle_scoreboard():
	scoreboard_panel.visible = not scoreboard_panel.visible
	if scoreboard_panel.visible:
		_render_scoreboard_from_snapshot()

func _render_scoreboard_from_snapshot() -> void:
	if multiplayer_network == null:
		# Still show local zeros if network isn't available.
		_update_scoreboard_ui(_merge_local_stats_into_scoreboard([]))
		return
	var sb: Array = multiplayer_network.get_scoreboard_snapshot()
	_update_scoreboard_ui(_merge_local_stats_into_scoreboard(sb))

func _get_local_score_values() -> Dictionary:
	# In multiplayer, use the session counters from GameState.
	# In singleplayer/debug, use the Player's own kills/score (matches HUD top-right).
	if GameState and GameState.is_multiplayer:
		return {
			"score": int(GameState.mp_score),
			"playerKills": int(GameState.mp_player_kills),
			"zombieKills": int(GameState.mp_zombie_kills),
		}
	var local_score := 0
	var local_kills := 0
	if player:
		local_score = int(player.score)
		local_kills = int(player.kills)
	return {
		"score": local_score,
		"playerKills": 0,
		"zombieKills": local_kills,
	}

func _merge_local_stats_into_scoreboard(scoreboard: Array) -> Array:
	# Ensure the scoreboard always shows the local client's current MP stats,
	# even if the server doesn't push an updated scoreboard (common in solo MP).
	var my_id: String = _get_local_player_id()
	var local_vals := _get_local_score_values()

	# Helper to read int from many possible backend keys.
	var read_int := func(d: Dictionary, keys: Array, default_value: int = 0) -> int:
		for k in keys:
			if d.has(k):
				return int(d.get(k, default_value))
		return default_value

	var read_pid := func(d: Dictionary) -> String:
		var pid := str(d.get("playerId", ""))
		if pid == "":
			pid = str(d.get("id", ""))
		if pid == "":
			pid = str(d.get("senderId", ""))
		return pid

	# Build a map by playerId so we can merge sources and ensure every player appears.
	var by_id: Dictionary = {}
	for entry in scoreboard:
		var d: Dictionary = entry if entry is Dictionary else {}
		var pid: String = read_pid.call(d)
		if pid == "":
			continue
		var normalized := {
			"playerId": pid,
			"username": str(d.get("username", d.get("name", "Player"))),
			"score": read_int.call(d, ["score", "points", "totalScore"], 0),
			"playerKills": read_int.call(d, ["playerKills", "kills", "pvpKills", "player_kills"], 0),
			"zombieKills": read_int.call(d, ["zombieKills", "zKills", "pveKills", "zombie_kills"], 0),
		}
		by_id[pid] = normalized

	# Ensure all currently known players show up (even if server scoreboard omits them).
	if multiplayer_network:
		for p in multiplayer_network.get_players_snapshot():
			var pd: Dictionary = p if p is Dictionary else {}
			var pid: String = read_pid.call(pd)
			if pid == "":
				continue
			if not by_id.has(pid):
				by_id[pid] = {
					"playerId": pid,
					"username": str(pd.get("username", "Player")),
					"score": 0,
					"playerKills": 0,
					"zombieKills": 0,
				}

	# Overwrite local row with authoritative local counters.
	if not by_id.has(my_id):
		by_id[my_id] = {
			"playerId": my_id,
			"username": GameState.username,
			"score": 0,
			"playerKills": 0,
			"zombieKills": 0,
		}
	by_id[my_id]["username"] = GameState.username
	by_id[my_id]["score"] = local_vals["score"]
	by_id[my_id]["playerKills"] = local_vals["playerKills"]
	by_id[my_id]["zombieKills"] = local_vals["zombieKills"]

	# Convert map to array sorted by score desc, then name.
	var merged: Array = by_id.values()
	merged.sort_custom(func(a, b):
		var sa := int(a.get("score", 0))
		var sb := int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		return str(a.get("username", "")) < str(b.get("username", ""))
	)
	return merged

func _update_scoreboard_ui(scoreboard: Array):
	var content: VBoxContainer = scoreboard_content
	if content == null and scoreboard_panel:
		content = scoreboard_panel.get_node_or_null("ScoreboardVBox/ScoreboardScroll/ScoreboardContent") as VBoxContainer
	if not content:
		return
	
	# Clear existing
	for child in content.get_children():
		child.queue_free()
	
	# Add players
	for idx in range(scoreboard.size()):
		var p = scoreboard[idx]
		var pid: String = str(p.get("playerId", ""))
		if pid == "" and p.has("id"):
			pid = str(p.get("id", ""))
		var row_bg := ColorRect.new()
		row_bg.color = Color(1, 1, 1, 0.05) if idx % 2 == 0 else Color(1, 1, 1, 0.0)
		row_bg.custom_minimum_size = Vector2(0, 30)
		row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(row_bg)

		# Accent strip per player
		var strip := ColorRect.new()
		strip.color = _color_for_player_id(pid)
		strip.custom_minimum_size = Vector2(4, 30)
		strip.size_flags_vertical = Control.SIZE_FILL
		row_bg.add_child(strip)

		var row := GridContainer.new()
		row.columns = 4
		row.add_theme_constant_override("h_separation", 20)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.position = Vector2(8, 0)
		row_bg.add_child(row)
		
		var username: String = str(p.get("username", "Player"))
		var score: int = int(p.get("score", p.get("points", 0)))
		var player_kills: int = int(p.get("playerKills", p.get("kills", 0)))
		var zombie_kills: int = int(p.get("zombieKills", p.get("zKills", p.get("zombie_kills", 0))))
		
		var is_me: bool = pid == _get_local_player_id()
		
		var name_lbl := Label.new()
		name_lbl.text = username + (" (You)" if is_me else "")
		name_lbl.custom_minimum_size.x = 200
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", _color_for_player_id(pid))
		row.add_child(name_lbl)
		
		var score_lbl := Label.new()
		score_lbl.text = str(score)
		score_lbl.custom_minimum_size.x = 100
		score_lbl.add_theme_font_size_override("font_size", 18)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score_lbl)
		
		var pk_lbl := Label.new()
		pk_lbl.text = str(player_kills)
		pk_lbl.custom_minimum_size.x = 120
		pk_lbl.add_theme_font_size_override("font_size", 18)
		pk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pk_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pk_lbl)
		
		var zk_lbl := Label.new()
		zk_lbl.text = str(zombie_kills)
		zk_lbl.custom_minimum_size.x = 120
		zk_lbl.add_theme_font_size_override("font_size", 18)
		zk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zk_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(zk_lbl)

		# Slightly emphasize local row
		if is_me:
			row_bg.color = Color(0.20, 0.25, 0.35, 0.35)

func _update_time_display():
	# Timer is displayed by PlayerUI/MatchTimer.
	pass

func _show_death_screen():
	death_stats_label.text = "Score: %d\nPlayer Kills: %d\nZombie Kills: %d" % [
		GameState.mp_score, GameState.mp_player_kills, GameState.mp_zombie_kills
	]
	respawn_panel.visible = true

func _on_respawn_pressed():
	respawn_panel.visible = false
	multiplayer_network.send_respawn()

func _on_spectate_pressed():
	respawn_panel.visible = false
	_enter_spectator_mode()
	# Tell the server we want to spectate
	if multiplayer_network.current_match_id != "":
		multiplayer_network.send_spectate(multiplayer_network.current_match_id)
	else:
		print("[multiplayer_main] Cannot spectate: no current match id")

func _do_respawn(pos: Vector2):
	is_dead = false
	
	# Respawn player at position using respawn_at method
	if player and player.has_method("respawn_at"):
		player.respawn_at(pos)
	elif player:
		# Fallback manual respawn
		player.global_position = pos
		if player.health_system:
			player.health_system.current_health = player.health_system.base_health
			player.emit_signal("health_changed", player.health_system.base_health, player.health_system.base_health)
		player.visible = true
		player.set_physics_process(true)
		player.set_process(true)
		player.set_process_input(true)

func _show_end_game_screen(scoreboard: Array):
	# Show final scoreboard with back to lobby button
	_update_scoreboard_ui(scoreboard)
	scoreboard_panel.visible = true
	
	# Add back to lobby button
	var sb_vbox = scoreboard_panel.get_node("VBoxContainer") if scoreboard_panel.has_node("VBoxContainer") else scoreboard_panel.get_child(0)
	
	# Check if button already exists
	if not sb_vbox.has_node("BackToLobbyBtn"):
		var btn := Button.new()
		btn.name = "BackToLobbyBtn"
		btn.text = "BACK TO LOBBY"
		btn.custom_minimum_size = Vector2(200, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_back_to_lobby_pressed)
		sb_vbox.add_child(btn)
	
	# Disable player input
	if player:
		player.set_process(false)
		player.set_physics_process(false)

func _on_back_to_lobby_pressed():
	GameState.reset_multiplayer_session()
	multiplayer_network.disconnect_from_server()
	if MusicManager and MusicManager.has_method("play_theme_full"):
		MusicManager.play_theme_full()
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")

# ==================== Chat Functions ====================

func _open_chat():
	chat_visible = true
	chat_input.editable = true
	chat_input.grab_focus()
	chat_input.placeholder_text = "Type message and press Enter..."

func _close_chat():
	chat_visible = false
	chat_input.editable = false
	chat_input.release_focus()
	chat_input.text = ""
	chat_input.placeholder_text = "Press Y to chat..."

func _on_chat_input_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not chat_visible:
			_open_chat()

func _on_chat_text_submitted(_text: String) -> void:
	if chat_visible:
		_send_chat_message()

func _send_chat_message():
	var msg := chat_input.text.strip_edges()
	if not msg.is_empty():
		multiplayer_network.send_chat(msg)
		chat_input.text = ""
	_close_chat()

func _add_chat_message(username: String, message: String):
	var lbl := Label.new()
	lbl.text = username + ": " + message
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_messages.add_child(lbl)
	
	# Scroll to bottom
	await get_tree().process_frame
	chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value

func _add_chat_system_message(message: String):
	var lbl := Label.new()
	lbl.text = "[SYSTEM] " + message
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.YELLOW)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_messages.add_child(lbl)
	
	await get_tree().process_frame
	chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value

# ==================== Combat Integration ====================

# Called when local player shoots another player
func report_player_hit(target_player_id: String, damage: int):
	multiplayer_network.send_hit_player(target_player_id, damage)

# Called when local player kills a zombie
func report_zombie_kill():
	GameState.add_mp_zombie_kill()
	multiplayer_network.send_zombie_kill()
	_render_scoreboard_from_snapshot()

func _on_local_kills_score_changed(_kills: int, _score: int) -> void:
	# Update the scoreboard immediately when local stats change.
	_render_scoreboard_from_snapshot()

# ==================== Spectator Mode ====================

func _enter_spectator_mode():
	is_spectating = true
	# Create spectator overlay label
	if spectate_label == null:
		spectate_label = Label.new()
		spectate_label.add_theme_font_size_override("font_size", 20)
		spectate_label.modulate = Color(1.0, 1.0, 1.0, 0.8)
		spectate_label.anchor_left = 0.5
		spectate_label.anchor_right = 0.5
		spectate_label.anchor_top = 0.0
		spectate_label.anchor_bottom = 0.0
		spectate_label.offset_top = 50
		spectate_label.offset_left = -200
		spectate_label.offset_right = 200
		spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Add to a CanvasLayer so it shows above the game
		var canvas := CanvasLayer.new()
		canvas.layer = 101
		add_child(canvas)
		canvas.add_child(spectate_label)

	# Pick first available target
	var targets := _get_spectate_targets()
	if targets.size() > 0:
		spectate_target_index = 0
		spectate_target_id = targets[0]
		_focus_spectate_target()
	spectate_label.text = "SPECTATING - Use LEFT/RIGHT arrows to switch"

func _get_spectate_targets() -> Array:
	var targets: Array = []
	for pid in remote_players:
		targets.append(pid)
	return targets

func _cycle_spectate_target(direction: int):
	var targets := _get_spectate_targets()
	if targets.is_empty():
		return
	spectate_target_index = (spectate_target_index + direction) % targets.size()
	if spectate_target_index < 0:
		spectate_target_index = targets.size() - 1
	spectate_target_id = targets[spectate_target_index]
	_focus_spectate_target()
	multiplayer_network.send_spectate_switch(spectate_target_id)

func _focus_spectate_target():
	if not remote_players.has(spectate_target_id):
		return
	var target_node = remote_players[spectate_target_id]
	# Move the camera to follow the spectated player
	if player and player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D")
		cam.reparent(target_node)
		cam.position = Vector2.ZERO
	if spectate_label:
		var target_name := "Player"
		if multiplayer_network:
			var snap = multiplayer_network.get_player_snapshot(spectate_target_id)
			target_name = str(snap.get("username", spectate_target_id))
		spectate_label.text = "SPECTATING: %s (LEFT/RIGHT to switch)" % target_name

func _on_spectate_update(players: Array, scoreboard: Array):
	# Update remote player positions from spectator feed
	for p in players:
		var pid := str(p.get("playerId", ""))
		if pid == "" or pid == multiplayer_network.my_player_id:
			continue
		var x := float(p.get("x", 0))
		var y := float(p.get("y", 0))
		var rot := float(p.get("rotation", 0))
		if remote_players.has(pid):
			remote_players[pid].target_position = Vector2(x, y)
			remote_players[pid].rotation = rot
	if not scoreboard.is_empty():
		_update_scoreboard_ui(scoreboard)

# ==================== Match-End Rewards Screen ====================

func _show_match_rewards_screen(scoreboard: Array):
	"""Enhanced end-game screen showing rewards earned."""
	_show_end_game_screen(scoreboard)

	# Refresh GameState data from backend after match ends
	GameState.load_wallet()
	GameState.load_elo()
	GameState.load_achievements()
	GameState.load_match_history()
