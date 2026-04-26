extends CanvasLayer

# Debug overlay for testing backend integration
# Press F12 to toggle

var debug_panel: PanelContainer
var debug_label: RichTextLabel
var visible_debug = false

func _ready():
	# Create debug panel
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(400, 10)
	debug_panel.size = Vector2(350, 300)
	debug_panel.visible = false
	add_child(debug_panel)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 290)
	debug_panel.add_child(scroll)
	
	debug_label = RichTextLabel.new()
	debug_label.bbcode_enabled = true
	debug_label.fit_content = true
	scroll.add_child(debug_label)
	
	# Connect to all relevant signals
	_connect_signals()
	
	# Initial debug info
	_update_debug_info()

func _connect_signals():
	# APIService signals
	if APIService:
		APIService.profile_loaded.connect(_on_profile_loaded)
		APIService.stats_updated.connect(_on_stats_updated)
		APIService.inventory_synced.connect(_on_inventory_synced)
		APIService.api_error.connect(_on_api_error)
	
	# GameState signals
	if GameState:
		GameState.health_changed.connect(_on_health_changed)
		GameState.stats_changed.connect(_on_stats_changed)
		GameState.inventory_changed.connect(_on_inventory_changed)
		GameState.player_died.connect(_on_player_died)
	
	# Network signals
	if Network:
		Network.login_completed.connect(_on_login_completed)
		Network.login_failed.connect(_on_login_failed)
		Network.match_joined.connect(_on_match_joined)
		Network.player_moved.connect(_on_player_moved)
		Network.player_shot.connect(_on_player_shot)
		Network.player_hit.connect(_on_player_hit)
		Network.player_died.connect(_on_network_player_died)

func _input(event):
	if Input.is_action_just_pressed("ui_f12") or (event is InputEventKey and event.keycode == KEY_F12 and event.pressed):
		visible_debug = !visible_debug
		debug_panel.visible = visible_debug
		if visible_debug:
			_update_debug_info()

func _update_debug_info():
	var info = "[b]Backend Integration Debug[/b]\n\n"
	
	# Connection Status
	info += "[color=yellow]Connection:[/color]\n"
	info += "  Backend: " + APIService.get_http_base_url() + "\n"
	info += "  WebSocket: " + ("Connected" if Network.connected else "Disconnected") + "\n"
	info += "  Match ID: " + (Network.current_match_id if Network.current_match_id else "None") + "\n\n"
	
	# Player Info
	info += "[color=yellow]Player Profile:[/color]\n"
	info += "  User ID: " + str(GameState.user_id) + "\n"
	info += "  Username: " + GameState.username + "\n"
	info += "  Dress: " + GameState.current_dress + "\n\n"
	
	# Stats
	info += "[color=yellow]Stats:[/color]\n"
	info += "  Health: %d/%d\n" % [GameState.current_health, GameState.max_health]
	info += "  Kills: " + str(GameState.total_kills) + "\n"
	info += "  High Score: " + str(GameState.high_score) + "\n\n"
	
	# Inventory
	info += "[color=yellow]Inventory:[/color]\n"
	info += "  Primary: " + GameState.primary_weapon + "\n"
	info += "  Secondary: " + GameState.secondary_weapon + "\n"
	info += "  Current: " + GameState.current_weapon + "\n"
	info += "  First Aids: " + str(GameState.first_aid_count) + "\n"
	info += "  Medkits: " + str(GameState.medkit_count) + "\n"
	info += "  Boosts: " + str(GameState.boost_count) + "\n"
	info += "  Helmet: Lvl " + str(GameState.helmet_level) + "\n"
	info += "  Vest: Lvl " + str(GameState.vest_level) + "\n\n"
	
	# Weapon Stats
	var weapon_stats = GameState.get_current_weapon_stats()
	info += "[color=yellow]Weapon Stats:[/color]\n"
	info += "  Damage: " + str(weapon_stats.get("damage", 0)) + "\n"
	info += "  Fire Rate: " + str(weapon_stats.get("fireRate", 0)) + "\n"
	info += "  Mag Size: " + str(weapon_stats.get("magSize", 0)) + "\n"
	info += "  Reload Time: " + str(weapon_stats.get("reloadTime", 0)) + "\n\n"
	
	# Controls
	info += "[color=cyan]Controls:[/color]\n"
	info += "  F12: Toggle Debug\n"
	info += "  WASD: Move\n"
	info += "  Mouse: Aim/Shoot\n"
	info += "  R: Reload\n"
	info += "  PgUp/PgDn: Swap Weapon\n"
	info += "  Home: First Aid\n"
	info += "  End: Medkit\n"
	
	debug_label.text = info

# Signal Handlers
func _on_profile_loaded(data):
	_log("[color=green]✓ Profile Loaded[/color]")
	_update_debug_info()

func _on_stats_updated(data):
	_log("[color=green]✓ Stats Updated[/color]")
	_update_debug_info()

func _on_inventory_synced(data):
	_log("[color=green]✓ Inventory Synced[/color]")
	_update_debug_info()

func _on_api_error(error):
	_log("[color=red]✗ API Error: " + error + "[/color]")

func _on_health_changed(health):
	_log("Health: %d/%d" % [health, GameState.max_health])
	_update_debug_info()

func _on_stats_changed(stats):
	_log("Stats Changed - Kills: " + str(stats.get("totalKills", 0)))
	_update_debug_info()

func _on_inventory_changed(inventory):
	_log("Inventory Changed")
	_update_debug_info()

func _on_player_died():
	_log("[color=red]YOU DIED[/color]")

func _on_login_completed(data):
	_log("[color=green]✓ Login Success: " + data.get("username", "") + "[/color]")
	_update_debug_info()

func _on_login_failed(error):
	_log("[color=red]✗ Login Failed: " + error + "[/color]")

func _on_match_joined(match_id):
	_log("[color=green]✓ Joined Match: " + match_id + "[/color]")
	_update_debug_info()

func _on_player_moved(player_id, position):
	pass  # Too spammy

func _on_player_shot(player_id, position, direction):
	_log("Shot by: " + player_id)

func _on_player_hit(target_id, damage):
	_log("[color=orange]Hit on " + target_id + " for " + str(damage) + " damage[/color]")

func _on_network_player_died(player_id):
	_log("[color=red]Player died: " + player_id + "[/color]")

func _log(message: String):
	print(message)  # Also log to console
	# Could add to scrolling log in debug panel
