extends Control

@onready var main_menu_vbox: Control = $VBoxContainer

@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_character_image: TextureRect = %PlayerCharacterImage

@onready var single_player_button = %SinglePlayerButton
@onready var multiplayer_button = %MultiplayerButton
@onready var stats_button: Button = %StatsButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var exit_button = %ExitButton
@onready var status_label = %StatusLabel

@onready var stats_panel: Control = %StatsPanel
@onready var stats_kills_value: Label = %KillsValue
@onready var stats_high_score_value: Label = %HighScoreValue
@onready var stats_matches_played_value: Label = %MatchesPlayedValue
@onready var stats_matches_won_value: Label = %MatchesWonValue
@onready var stats_elo_value: Label = %EloValue
@onready var exit_stats_button: Button = %ExitStatsButton

@onready var leaderboard_panel: Control = %LeaderboardPanel
@onready var leaderboard_list: VBoxContainer = %LeaderboardList
@onready var exit_leaderboard_button: Button = %ExitLeaderboardButton

# Difficulty picker (singleplayer)
@onready var difficulty_panel: Control = %DifficultyPanel
@onready var easy_button: Button = %EasyButton
@onready var hard_button: Button = %HardButton
@onready var exit_difficulty_button: Button = %ExitDifficultyButton

# Multiplayer lobby controls (initially hidden)
@onready var multiplayer_panel = %MultiplayerPanel
@onready var ready_button = %ReadyButton
@onready var back_button = %BackButton
@onready var players_list = %PlayersList
@onready var multiplayer_network = get_node("/root/MultiplayerNetwork")

var is_ready := false
var in_multiplayer_lobby := false
var connected_players := {} # player_id -> {username, ready}
var is_leaving := false
var match_started := false
var auto_start_timer: SceneTreeTimer

const FALLBACK_MATCH_DURATION := 300

# ========== LOBBY PANELS (dynamically created) ==========
var profile_panel: PanelContainer
var tab_container: HBoxContainer
var content_panel: PanelContainer
var content_scroll: ScrollContainer
var content_vbox: VBoxContainer
var active_tab: String = ""

# Profile labels
var profile_username_label: Label
var profile_elo_label: Label
var profile_coins_label: Label
var profile_gems_label: Label
var profile_stats_label: Label

func _scene_tree() -> SceneTree:
	# get_tree() can be null if this node is temporarily detached while a scene
	# transition is already in progress (e.g., local fallback start + server MATCH_START).
	var tree := get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	return tree

func _change_to_multiplayer_game_scene() -> void:
	# Single authoritative exit path from lobby -> game.
	var tree := _scene_tree()
	if tree == null:
		push_error("Lobby: no SceneTree available for scene change")
		return
	var err := tree.change_scene_to_file("res://Scenes/multiplayer_main.tscn")
	if err != OK:
		status_label.text = "Failed to load game scene (err=%s)" % str(err)
		push_error("Lobby: change_scene_to_file failed (err=%s)" % str(err))

func _trigger_match_start() -> void:
	if match_started or is_leaving:
		return
	match_started = true
	_cancel_auto_start()
	# Fallback: start locally so lobby never deadlocks.
	GameState.match_duration = FALLBACK_MATCH_DURATION
	GameState.is_multiplayer = true
	GameState.multiplayer_players = []
	_change_to_multiplayer_game_scene()

func _my_roster_id() -> String:
	if multiplayer_network and str(multiplayer_network.my_player_id) != "":
		return str(multiplayer_network.my_player_id)
	if GameState.user_id:
		return str(GameState.user_id)
	return ""

func _set_local_ready_in_roster(ready: bool) -> void:
	var my_id := _my_roster_id()
	if my_id == "":
		return
	if connected_players.has(my_id):
		connected_players[my_id]["ready"] = ready

func _all_players_ready() -> bool:
	if connected_players.is_empty():
		return false
	for pid in connected_players:
		if not connected_players[pid].get("ready", false):
			return false
	return true

func _connected_player_count_estimate() -> int:
	# Treat the local player as present even if the roster hasn't populated yet.
	if not connected_players.is_empty():
		return connected_players.size()
	return 1 if _my_roster_id() != "" else 0

func _should_start_match() -> bool:
	if match_started or is_leaving:
		return false
	# Temporary deadlock-proof behavior: if the local player presses READY and
	# at least one player is present, start immediately (no server gating).
	return is_ready and _connected_player_count_estimate() >= 1

func _maybe_start_match() -> void:
	if _should_start_match():
		_trigger_match_start()

func _ready():
	if MusicManager and MusicManager.has_method("play_theme_full"):
		MusicManager.play_theme_full()

	if player_name_label:
		player_name_label.text = GameState.username if GameState.username != "" else "Guest"

	single_player_button.pressed.connect(_on_single_player_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	exit_stats_button.pressed.connect(_on_exit_stats_pressed)
	exit_leaderboard_button.pressed.connect(_on_exit_leaderboard_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	back_button.pressed.connect(_on_back_pressed)
	if easy_button:
		easy_button.pressed.connect(_on_easy_pressed)
	if hard_button:
		hard_button.pressed.connect(_on_hard_pressed)
	if exit_difficulty_button:
		exit_difficulty_button.pressed.connect(_on_exit_difficulty_pressed)
	
	# Hide multiplayer panel initially
	if multiplayer_panel:
		multiplayer_panel.hide()
	# Avoid pressing READY before we actually join a match
	if ready_button:
		ready_button.disabled = true
	
	# Connect multiplayer signals
	multiplayer_network.connected.connect(_on_mp_connected)
	multiplayer_network.disconnected.connect(_on_mp_disconnected)
	multiplayer_network.connection_error.connect(_on_mp_error)
	multiplayer_network.match_joined.connect(_on_mp_match_joined)
	multiplayer_network.match_started.connect(_on_mp_match_started)
	multiplayer_network.player_joined.connect(_on_mp_player_joined)
	multiplayer_network.player_left.connect(_on_mp_player_left)
	multiplayer_network.player_ready_changed.connect(_on_mp_player_ready_changed)

	# NOTE: Old “feature panels” (profile/shop/tabs) are intentionally not built.
	# The lobby UI is now centered and navigates via the Stats/Leaderboard buttons.

func _on_single_player_pressed():
	# Store game mode
	GameState.is_multiplayer = false
	status_label.text = "Select difficulty:"
	# Show difficulty picker (requested)
	if difficulty_panel:
		difficulty_panel.show()
		if main_menu_vbox:
			main_menu_vbox.hide()
		single_player_button.disabled = true
		multiplayer_button.disabled = true
		stats_button.disabled = true
		leaderboard_button.disabled = true
		exit_button.disabled = true
		if easy_button:
			easy_button.grab_focus()
	else:
		# Fallback: if panel missing, behave like old flow.
		_start_singleplayer(GameState.Difficulty.HARD)


func _on_exit_difficulty_pressed() -> void:
	if difficulty_panel:
		difficulty_panel.hide()
	status_label.text = ""
	_show_main_menu()


func _on_easy_pressed() -> void:
	_start_singleplayer(GameState.Difficulty.EASY)


func _on_hard_pressed() -> void:
	_start_singleplayer(GameState.Difficulty.HARD)


func _start_singleplayer(diff: int) -> void:
	if GameState:
		GameState.set_singleplayer_difficulty(diff)
	if MusicManager and MusicManager.has_method("set_music_half_volume"):
		MusicManager.set_music_half_volume()
	status_label.text = "Starting Single Player..."
	# Go to game
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_multiplayer_pressed():
	status_label.text = "Connecting to server..."
	single_player_button.disabled = true
	multiplayer_button.disabled = true
	stats_button.disabled = true
	leaderboard_button.disabled = true
	exit_button.disabled = true
	if main_menu_vbox:
		main_menu_vbox.hide()
	if multiplayer_panel:
		multiplayer_panel.show()
	if ready_button:
		ready_button.disabled = true
	_update_players_list()
	
	# Store game mode
	GameState.is_multiplayer = true
	
	# Connect to multiplayer server
	var player_id = str(GameState.user_id) if GameState.user_id else str(randi())
	var username = GameState.username if GameState.username else "Player"
	multiplayer_network.connect_to_server(player_id, username)

func _on_exit_pressed():
	get_tree().quit()


func _show_main_menu() -> void:
	if stats_panel:
		stats_panel.hide()
	if leaderboard_panel:
		leaderboard_panel.hide()
	if difficulty_panel:
		difficulty_panel.hide()
	if main_menu_vbox:
		main_menu_vbox.show()
	# Ensure main menu buttons are re-enabled (safe default)
	single_player_button.disabled = false
	multiplayer_button.disabled = false
	stats_button.disabled = false
	leaderboard_button.disabled = false
	exit_button.disabled = false


func _on_stats_pressed() -> void:
	if not stats_panel:
		return
	# Fill values from GameState
	stats_kills_value.text = str(GameState.total_kills)
	stats_high_score_value.text = str(GameState.high_score)
	stats_matches_played_value.text = str(GameState.matches_played)
	stats_matches_won_value.text = str(GameState.matches_won)
	stats_elo_value.text = str(GameState.elo_rating)

	if main_menu_vbox:
		main_menu_vbox.hide()
	stats_panel.show()


func _on_exit_stats_pressed() -> void:
	_show_main_menu()


func _on_leaderboard_pressed() -> void:
	if not leaderboard_panel:
		return
	if main_menu_vbox:
		main_menu_vbox.hide()
	leaderboard_panel.show()
	_load_leaderboard()


func _on_exit_leaderboard_pressed() -> void:
	_show_main_menu()


func _clear_leaderboard_list() -> void:
	if not leaderboard_list:
		return
	for child in leaderboard_list.get_children():
		child.queue_free()


func _add_leaderboard_row(rank: int, username: String, kills: int) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard_list.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size.x = 760
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.add_theme_font_size_override("font_size", 28)
	rank_lbl.custom_minimum_size.x = 120
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = username
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.custom_minimum_size.x = 520
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var kills_lbl := Label.new()
	kills_lbl.text = str(kills)
	kills_lbl.add_theme_font_size_override("font_size", 28)
	kills_lbl.custom_minimum_size.x = 120
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(kills_lbl)


func _load_leaderboard() -> void:
	_clear_leaderboard_list()
	var loading := Label.new()
	loading.text = "Loading..."
	loading.add_theme_font_size_override("font_size", 26)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_list.add_child(loading)

	APIService.get_leaderboard(func(success: bool, data):
		if not is_instance_valid(leaderboard_panel) or not leaderboard_panel.visible:
			return
		_clear_leaderboard_list()
		if not success:
			var err_lbl := Label.new()
			err_lbl.text = str(data)
			err_lbl.add_theme_font_size_override("font_size", 26)
			err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			leaderboard_list.add_child(err_lbl)
			return

		var entries: Array = data if data is Array else []
		entries.sort_custom(func(a, b):
			return int(a.get("totalKills", 0)) > int(b.get("totalKills", 0))
		)

		var header_center := CenterContainer.new()
		header_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leaderboard_list.add_child(header_center)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 18)
		header.custom_minimum_size.x = 760
		header.alignment = BoxContainer.ALIGNMENT_CENTER
		header_center.add_child(header)

		var h_rank := Label.new()
		h_rank.text = "RANK"
		h_rank.add_theme_font_size_override("font_size", 22)
		h_rank.custom_minimum_size.x = 120
		h_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(h_rank)
		var h_name := Label.new()
		h_name.text = "PLAYER"
		h_name.add_theme_font_size_override("font_size", 22)
		h_name.custom_minimum_size.x = 520
		h_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(h_name)
		var h_kills := Label.new()
		h_kills.text = "KILLS"
		h_kills.add_theme_font_size_override("font_size", 22)
		h_kills.custom_minimum_size.x = 120
		h_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(h_kills)

		var rank := 1
		for entry in entries:
			var username := str(entry.get("username", "Player"))
			var kills := int(entry.get("totalKills", 0))
			_add_leaderboard_row(rank, username, kills)
			rank += 1
	)

func _on_ready_pressed():
	is_ready = not is_ready
	ready_button.text = "CANCEL READY" if is_ready else "READY"
	ready_button.modulate = Color.YELLOW if is_ready else Color.WHITE
	multiplayer_network.send_ready(is_ready)
	_set_local_ready_in_roster(is_ready)
	_update_players_list()
	if is_ready:
		# Deadlock-proof: start immediately on READY press.
		if _connected_player_count_estimate() >= 1:
			_trigger_match_start()
	else:
		_cancel_auto_start()

func _on_back_pressed():
	# Disconnect from multiplayer and go back to main lobby
	_cancel_auto_start()
	is_leaving = true
	multiplayer_network.disconnect_from_server()
	_reset_lobby_ui()

# ==================== Multiplayer Callbacks ====================

func _on_mp_connected():
	status_label.text = "Connected! Joining match..."

func _on_mp_disconnected():
	status_label.text = "Disconnected from server"
	if not is_leaving:
		_reset_lobby_ui()

func _on_mp_error(error: String):
	status_label.text = "Error: " + error
	if multiplayer_panel:
		multiplayer_panel.hide()
	_show_main_menu()

func _on_mp_match_joined(match_id: String, players: Array):
	in_multiplayer_lobby = true
	status_label.text = "Joined match: " + match_id
	if ready_button:
		ready_button.disabled = false
	
	# Store existing players
	for p in players:
		var pid = str(p.get("playerId", ""))
		connected_players[pid] = {
			"username": p.get("username", "Player"),
			"ready": p.get("ready", false)
		}
	
	# Show multiplayer panel
	if multiplayer_panel:
		multiplayer_panel.show()
	# Hide the centered menu
	if main_menu_vbox:
		main_menu_vbox.hide()
	
	_update_players_list()
	_maybe_start_match()

func _on_mp_match_started(duration: int, players: Array):
	if match_started or is_leaving:
		return
	status_label.text = "Match starting!"
	match_started = true
	
	# Store match info in GameState
	GameState.match_duration = duration
	GameState.is_multiplayer = true
	
	# Store other players for spawning
	GameState.multiplayer_players = players
	
	# Change to multiplayer game scene
	_change_to_multiplayer_game_scene()

func _schedule_auto_start():
	# Re-check start conditions shortly after READY changes.
	if match_started:
		return
	_cancel_auto_start()
	auto_start_timer = get_tree().create_timer(0.35)
	await auto_start_timer.timeout
	if auto_start_timer == null:
		return
	auto_start_timer = null
	if match_started or not in_multiplayer_lobby or is_leaving:
		return
	_maybe_start_match()

func _cancel_auto_start():
	if auto_start_timer:
		auto_start_timer = null

func _force_start_match():
	# Back-compat: if any old code calls this, route through the new trigger.
	_trigger_match_start()

func _reset_lobby_ui():
	in_multiplayer_lobby = false
	is_ready = false
	match_started = false
	connected_players.clear()
	is_leaving = false
	_cancel_auto_start()
	
	if multiplayer_panel:
		multiplayer_panel.hide()
	if ready_button:
		ready_button.disabled = true

	_show_main_menu()
	status_label.text = ""

func _on_mp_player_joined(player_id: String, username: String, x: float, y: float):
	connected_players[player_id] = {
		"username": username,
		"ready": false
	}
	_update_players_list()
	status_label.text = username + " joined the lobby"

func _on_mp_player_left(player_id: String):
	if connected_players.has(player_id):
		var username = connected_players[player_id].get("username", "Player")
		connected_players.erase(player_id)
		_update_players_list()
		status_label.text = username + " left the lobby"

func _on_mp_player_ready_changed(player_id: String, ready: bool):
	if connected_players.has(player_id):
		connected_players[player_id]["ready"] = ready
		_update_players_list()
		_maybe_start_match()

func _update_players_list():
	if not players_list:
		return
	
	# Clear existing items
	for child in players_list.get_children():
		child.queue_free()
	
	# Add players
	for pid in connected_players:
		var info = connected_players[pid]
		var label = Label.new()
		var ready_text = " [READY]" if info.get("ready", false) else ""
		var is_me = " (You)" if pid == str(GameState.user_id) or pid == multiplayer_network.my_player_id else ""
		label.text = info.get("username", "Player") + is_me + ready_text
		label.add_theme_font_size_override("font_size", 20)
		if info.get("ready", false):
			label.modulate = Color.GREEN
		players_list.add_child(label)
	
	# Add empty slots
	var empty_slots = 3 - connected_players.size()
	for i in range(empty_slots):
		var label = Label.new()
		label.text = "[ Waiting for player... ]"
		label.add_theme_font_size_override("font_size", 20)
		label.modulate = Color(1, 1, 1, 0.4)
		players_list.add_child(label)

# ===================================================================
# LOBBY FEATURE PANELS (Profile, Shop, Achievements, History, Leaderboard)
# ===================================================================

func _make_panel_style(bg_color: Color = Color(0.08, 0.08, 0.12, 0.92)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 14
	sb.content_margin_top = 10
	sb.content_margin_right = 14
	sb.content_margin_bottom = 10
	return sb

func _tier_color(tier: String) -> Color:
	match tier:
		"BRONZE": return Color(0.8, 0.5, 0.2)
		"SILVER": return Color(0.75, 0.75, 0.8)
		"GOLD": return Color(1.0, 0.84, 0.0)
		"PLATINUM": return Color(0.3, 0.8, 0.8)
		"DIAMOND": return Color(0.4, 0.7, 1.0)
		"MASTER": return Color(1.0, 0.3, 0.3)
		_: return Color.WHITE

func _build_lobby_panels():
	_build_profile_panel()
	_build_tab_buttons()
	_build_content_panel()
	_refresh_profile_display()

func _build_profile_panel():
	profile_panel = PanelContainer.new()
	profile_panel.add_theme_stylebox_override("panel", _make_panel_style())
	profile_panel.anchor_left = 0.0
	profile_panel.anchor_right = 0.35
	profile_panel.anchor_top = 0.0
	profile_panel.anchor_bottom = 0.0
	profile_panel.offset_left = 20
	profile_panel.offset_top = 20
	profile_panel.offset_right = -10
	profile_panel.offset_bottom = 180
	add_child(profile_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	profile_panel.add_child(vbox)

	profile_username_label = Label.new()
	profile_username_label.text = GameState.username if GameState.username != "" else "Guest"
	profile_username_label.add_theme_font_size_override("font_size", 24)
	profile_username_label.modulate = Color(0.95, 0.95, 0.95)
	vbox.add_child(profile_username_label)

	profile_elo_label = Label.new()
	profile_elo_label.text = "ELO: %d | Rank: %s" % [GameState.elo_rating, GameState.elo_tier]
	profile_elo_label.add_theme_font_size_override("font_size", 16)
	profile_elo_label.modulate = _tier_color(GameState.elo_tier)
	vbox.add_child(profile_elo_label)

	var economy_row := HBoxContainer.new()
	economy_row.add_theme_constant_override("separation", 20)
	vbox.add_child(economy_row)

	profile_coins_label = Label.new()
	profile_coins_label.text = "Coins: %d" % GameState.coins
	profile_coins_label.add_theme_font_size_override("font_size", 16)
	profile_coins_label.modulate = Color(1.0, 0.84, 0.0)
	economy_row.add_child(profile_coins_label)

	profile_gems_label = Label.new()
	profile_gems_label.text = "Gems: %d" % GameState.gems
	profile_gems_label.add_theme_font_size_override("font_size", 16)
	profile_gems_label.modulate = Color(0.6, 0.3, 1.0)
	economy_row.add_child(profile_gems_label)

	profile_stats_label = Label.new()
	profile_stats_label.text = "W: %d / P: %d | Kills: %d" % [GameState.matches_won, GameState.matches_played, GameState.total_kills]
	profile_stats_label.add_theme_font_size_override("font_size", 14)
	profile_stats_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(profile_stats_label)

func _build_tab_buttons():
	tab_container = HBoxContainer.new()
	tab_container.anchor_left = 0.0
	tab_container.anchor_right = 1.0
	tab_container.anchor_top = 1.0
	tab_container.anchor_bottom = 1.0
	tab_container.offset_left = 20
	tab_container.offset_right = -20
	tab_container.offset_top = -70
	tab_container.offset_bottom = -30
	tab_container.add_theme_constant_override("separation", 8)
	add_child(tab_container)

	var tabs = ["Shop", "Achievements", "History", "Leaderboard"]
	var tab_colors = [
		Color(1.0, 0.84, 0.0),  # Gold
		Color(0.3, 0.85, 0.4),  # Green
		Color(0.5, 0.7, 1.0),   # Blue
		Color(1.0, 0.5, 0.2),   # Orange
	]
	for i in range(tabs.size()):
		var btn := Button.new()
		btn.text = tabs[i]
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(140, 36)
		btn.modulate = tab_colors[i]
		btn.pressed.connect(_on_tab_pressed.bind(tabs[i]))
		tab_container.add_child(btn)

func _build_content_panel():
	content_panel = PanelContainer.new()
	content_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.06, 0.10, 0.95)))
	content_panel.anchor_left = 0.38
	content_panel.anchor_right = 1.0
	content_panel.anchor_top = 0.0
	content_panel.anchor_bottom = 1.0
	content_panel.offset_left = 0
	content_panel.offset_top = 20
	content_panel.offset_right = -20
	content_panel.offset_bottom = -80
	content_panel.visible = false
	add_child(content_panel)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(content_scroll)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content_vbox)

func _on_tab_pressed(tab_name: String):
	if active_tab == tab_name and content_panel.visible:
		content_panel.visible = false
		active_tab = ""
		return
	active_tab = tab_name
	content_panel.visible = true
	_clear_content()
	match tab_name:
		"Shop":
			_populate_shop()
		"Achievements":
			_populate_achievements()
		"History":
			_populate_history()
		"Leaderboard":
			_populate_leaderboard()

func _clear_content():
	for child in content_vbox.get_children():
		child.queue_free()

# ========== SHOP TAB ==========
func _populate_shop():
	var title := Label.new()
	title.text = "COSMETIC SHOP"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(1.0, 0.84, 0.0)
	content_vbox.add_child(title)

	if GameState.cosmetics.is_empty():
		var loading := Label.new()
		loading.text = "Loading cosmetics..."
		loading.add_theme_font_size_override("font_size", 16)
		content_vbox.add_child(loading)
		GameState.load_cosmetics()
		# Reconnect to refresh when data arrives
		if not GameState.cosmetics_updated.is_connected(_on_cosmetics_loaded):
			GameState.cosmetics_updated.connect(_on_cosmetics_loaded)
		return

	for item in GameState.cosmetics:
		_add_cosmetic_row(item)

func _on_cosmetics_loaded(_cosmetics):
	if active_tab == "Shop":
		_clear_content()
		_populate_shop()

func _add_cosmetic_row(item: Dictionary):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content_vbox.add_child(row)

	var info := VBoxContainer.new()
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "Unknown"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.custom_minimum_size.x = 180
	info.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = str(item.get("type", ""))
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.modulate = Color(0.6, 0.6, 0.6)
	info.add_child(type_lbl)

	var owned: bool = item.get("owned", false)
	var equipped: bool = item.get("equipped", false)
	var price: int = item.get("price", 0)
	var cosmetic_id: int = item.get("id", 0)

	if equipped:
		var equipped_lbl := Label.new()
		equipped_lbl.text = "EQUIPPED"
		equipped_lbl.add_theme_font_size_override("font_size", 16)
		equipped_lbl.modulate = Color(0.3, 1.0, 0.4)
		row.add_child(equipped_lbl)
		var unequip_btn := Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.add_theme_font_size_override("font_size", 14)
		unequip_btn.pressed.connect(func(): GameState.unequip_cosmetic(cosmetic_id))
		row.add_child(unequip_btn)
	elif owned:
		var equip_btn := Button.new()
		equip_btn.text = "Equip"
		equip_btn.add_theme_font_size_override("font_size", 14)
		equip_btn.modulate = Color(0.3, 0.85, 1.0)
		equip_btn.pressed.connect(func(): GameState.equip_cosmetic(cosmetic_id))
		row.add_child(equip_btn)
	else:
		var buy_btn := Button.new()
		buy_btn.text = "Buy (%d coins)" % price
		buy_btn.add_theme_font_size_override("font_size", 14)
		buy_btn.modulate = Color(1.0, 0.84, 0.0)
		buy_btn.pressed.connect(func(): GameState.unlock_cosmetic(cosmetic_id))
		row.add_child(buy_btn)

# ========== ACHIEVEMENTS TAB ==========
func _populate_achievements():
	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.3, 0.85, 0.4)
	content_vbox.add_child(title)

	if GameState.achievements.is_empty():
		var loading := Label.new()
		loading.text = "Loading achievements..."
		loading.add_theme_font_size_override("font_size", 16)
		content_vbox.add_child(loading)
		GameState.load_achievements()
		if not GameState.achievements_updated.is_connected(_on_achievements_loaded):
			GameState.achievements_updated.connect(_on_achievements_loaded)
		return

	var unlocked_count := 0
	for ach in GameState.achievements:
		if ach.get("unlocked", false):
			unlocked_count += 1

	var progress := Label.new()
	progress.text = "Progress: %d / %d" % [unlocked_count, GameState.achievements.size()]
	progress.add_theme_font_size_override("font_size", 16)
	progress.modulate = Color(0.7, 0.7, 0.7)
	content_vbox.add_child(progress)

	for ach in GameState.achievements:
		_add_achievement_row(ach)

func _on_achievements_loaded(_achievements):
	if active_tab == "Achievements":
		_clear_content()
		_populate_achievements()

func _add_achievement_row(ach: Dictionary):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content_vbox.add_child(row)

	var unlocked: bool = ach.get("unlocked", false)
	var icon := Label.new()
	icon.text = "[*]" if unlocked else "[ ]"
	icon.add_theme_font_size_override("font_size", 18)
	icon.modulate = Color(1.0, 0.84, 0.0) if unlocked else Color(0.4, 0.4, 0.4)
	row.add_child(icon)

	var info := VBoxContainer.new()
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(ach.get("name", "Unknown"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.5)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(ach.get("description", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.modulate = Color(0.6, 0.6, 0.6)
	info.add_child(desc_lbl)

	var reward_coins: int = ach.get("rewardCoins", 0)
	var reward_gems: int = ach.get("rewardGems", 0)
	if reward_coins > 0 or reward_gems > 0:
		var reward_lbl := Label.new()
		var parts := []
		if reward_coins > 0:
			parts.append("+%d coins" % reward_coins)
		if reward_gems > 0:
			parts.append("+%d gems" % reward_gems)
		reward_lbl.text = " | ".join(parts)
		reward_lbl.add_theme_font_size_override("font_size", 12)
		reward_lbl.modulate = Color(1.0, 0.84, 0.0)
		info.add_child(reward_lbl)

# ========== HISTORY TAB ==========
func _populate_history():
	var title := Label.new()
	title.text = "MATCH HISTORY"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.5, 0.7, 1.0)
	content_vbox.add_child(title)

	if GameState.match_history.is_empty():
		var loading := Label.new()
		loading.text = "Loading match history..."
		loading.add_theme_font_size_override("font_size", 16)
		content_vbox.add_child(loading)
		GameState.load_match_history()
		# Need a one-shot callback. We'll use a small timer to re-check.
		get_tree().create_timer(2.0).timeout.connect(func():
			if active_tab == "History":
				_clear_content()
				_populate_history()
		)
		return

	if GameState.match_history.is_empty():
		var empty := Label.new()
		empty.text = "No matches played yet."
		empty.add_theme_font_size_override("font_size", 16)
		empty.modulate = Color(0.5, 0.5, 0.5)
		content_vbox.add_child(empty)
		return

	for match_data in GameState.match_history:
		_add_history_row(match_data)

func _add_history_row(m: Dictionary):
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_panel_style(Color(0.1, 0.1, 0.15, 0.8)))
	content_vbox.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	row.add_child(hbox)

	var result: String = str(m.get("result", "UNKNOWN"))
	var result_lbl := Label.new()
	result_lbl.text = result
	result_lbl.add_theme_font_size_override("font_size", 18)
	result_lbl.custom_minimum_size.x = 80
	match result:
		"WIN": result_lbl.modulate = Color(0.3, 1.0, 0.4)
		"LOSS": result_lbl.modulate = Color(1.0, 0.3, 0.3)
		"MVP": result_lbl.modulate = Color(1.0, 0.84, 0.0)
		_: result_lbl.modulate = Color(0.7, 0.7, 0.7)
	hbox.add_child(result_lbl)

	var stats := Label.new()
	stats.text = "K:%d D:%d DMG:%d" % [m.get("kills", 0), m.get("deaths", 0), m.get("damage", 0)]
	stats.add_theme_font_size_override("font_size", 14)
	hbox.add_child(stats)

	var match_id_lbl := Label.new()
	match_id_lbl.text = str(m.get("matchId", ""))
	match_id_lbl.add_theme_font_size_override("font_size", 12)
	match_id_lbl.modulate = Color(0.4, 0.4, 0.4)
	hbox.add_child(match_id_lbl)

# ========== LEADERBOARD TAB ==========
func _populate_leaderboard():
	var title := Label.new()
	title.text = "ELO LEADERBOARD"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(1.0, 0.5, 0.2)
	content_vbox.add_child(title)

	var loading := Label.new()
	loading.text = "Loading leaderboard..."
	loading.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(loading)

	APIService.get_elo_leaderboard(func(success, data):
		if not is_instance_valid(loading):
			return
		loading.queue_free()
		if success and data is Array:
			_render_leaderboard(data)
		else:
			var err := Label.new()
			err.text = "Failed to load leaderboard"
			err.modulate = Color.RED
			content_vbox.add_child(err)
	)

	# Also show season info
	if GameState.current_season_name != "":
		var season_lbl := Label.new()
		season_lbl.text = "Season: %s" % GameState.current_season_name
		season_lbl.add_theme_font_size_override("font_size", 14)
		season_lbl.modulate = Color(0.6, 0.8, 1.0)
		content_vbox.add_child(season_lbl)

func _render_leaderboard(entries: Array):
	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	content_vbox.add_child(header)

	for col in ["#", "Player", "ELO", "Tier", "W/L"]:
		var lbl := Label.new()
		lbl.text = col
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.modulate = Color(0.6, 0.6, 0.6)
		lbl.custom_minimum_size.x = 80
		header.add_child(lbl)

	var rank := 1
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		content_vbox.add_child(row)

		var is_me: bool = int(entry.get("userId", 0)) == GameState.user_id
		var row_color: Color = Color(1.0, 0.84, 0.0) if is_me else Color.WHITE

		var rank_lbl := Label.new()
		rank_lbl.text = str(rank)
		rank_lbl.add_theme_font_size_override("font_size", 16)
		rank_lbl.custom_minimum_size.x = 80
		rank_lbl.modulate = row_color
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("username", "???"))
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.custom_minimum_size.x = 80
		name_lbl.modulate = row_color
		row.add_child(name_lbl)

		var elo_lbl := Label.new()
		elo_lbl.text = str(entry.get("eloRating", 0))
		elo_lbl.add_theme_font_size_override("font_size", 16)
		elo_lbl.custom_minimum_size.x = 80
		elo_lbl.modulate = row_color
		row.add_child(elo_lbl)

		var tier_str: String = str(entry.get("tier", "BRONZE"))
		var tier_lbl := Label.new()
		tier_lbl.text = tier_str
		tier_lbl.add_theme_font_size_override("font_size", 16)
		tier_lbl.custom_minimum_size.x = 80
		tier_lbl.modulate = _tier_color(tier_str)
		row.add_child(tier_lbl)

		var wl_lbl := Label.new()
		wl_lbl.text = "%d/%d" % [entry.get("matchesWon", 0), entry.get("matchesPlayed", 0)]
		wl_lbl.add_theme_font_size_override("font_size", 16)
		wl_lbl.custom_minimum_size.x = 80
		wl_lbl.modulate = row_color
		row.add_child(wl_lbl)

		rank += 1

# ========== LIVE UPDATE HANDLERS ==========
func _refresh_profile_display():
	if profile_username_label:
		profile_username_label.text = GameState.username if GameState.username != "" else "Guest"
	if profile_elo_label:
		profile_elo_label.text = "ELO: %d | Rank: %s" % [GameState.elo_rating, GameState.elo_tier]
		profile_elo_label.modulate = _tier_color(GameState.elo_tier)
	if profile_coins_label:
		profile_coins_label.text = "Coins: %d" % GameState.coins
	if profile_gems_label:
		profile_gems_label.text = "Gems: %d" % GameState.gems
	if profile_stats_label:
		profile_stats_label.text = "W: %d / P: %d | Kills: %d" % [GameState.matches_won, GameState.matches_played, GameState.total_kills]

func _on_wallet_changed(_coins: int, _gems: int):
	_refresh_profile_display()

func _on_elo_changed(_elo: int, _tier: String):
	_refresh_profile_display()
