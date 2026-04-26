extends CanvasLayer
## Professional in-game HUD with health bar, ammo display, kill counter, and kill feed

class_name GameHUD

# ========== UI REFERENCES ==========
var health_bar: ProgressBar
var health_label: Label
var weapon_name_label: Label
var ammo_label: Label
var kills_label: Label
var score_label: Label
var player_name_label: Label
var kill_feed_container: VBoxContainer
var crosshair: Node2D
var coins_label: Label
var gems_label: Label
var elo_label: Label

# ========== CONFIGURATION ==========
const HUD_MARGIN = 15
const HEALTH_BAR_WIDTH = 200
const HEALTH_BAR_HEIGHT = 30
const FONT_SIZE_LARGE = 18
const FONT_SIZE_NORMAL = 14
const FONT_SIZE_SMALL = 12

func _ready():
	# Create UI structure
	_setup_health_display()
	_setup_weapon_display()
	_setup_stats_display()
	_setup_economy_display()
	_setup_kill_feed()
	
	# Connect to GameState signals
	GameState.health_changed.connect(_on_health_changed)
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.player_died.connect(_on_player_died)
	GameState.wallet_changed.connect(_on_wallet_changed)
	GameState.elo_changed.connect(_on_elo_changed)
	
	# Connect to Network signals if available
	if Network:
		Network.player_died.connect(_on_remote_player_died)
	
	# Initial update
	_update_all_displays()
	_update_economy_display()
	
	print("Game HUD initialized")

# ========== HEALTH DISPLAY (Top-Left) ==========
func _setup_health_display():
	var health_panel := MarginContainer.new()
	health_panel.anchor_left = 0
	health_panel.anchor_top = 0
	health_panel.anchor_right = 0
	health_panel.anchor_bottom = 0
	health_panel.offset_left = HUD_MARGIN
	health_panel.offset_top = HUD_MARGIN
	health_panel.offset_right = HUD_MARGIN + 260
	health_panel.offset_bottom = HUD_MARGIN + 70
	add_child(health_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	health_panel.add_child(vbox)

	player_name_label = Label.new()
	player_name_label.text = GameState.username
	player_name_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	player_name_label.modulate = Color(0.95, 0.95, 0.95)
	vbox.add_child(player_name_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar.min_value = 0
	health_bar.max_value = GameState.max_health
	health_bar.value = GameState.current_health
	health_bar.show_percentage = false
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.modulate = Color(0.2, 0.85, 0.3)
	vbox.add_child(health_bar)


# ========== WEAPON DISPLAY (Top-Right) ==========
func _setup_weapon_display():
	var weapon_panel = PanelContainer.new()
	weapon_panel.anchor_left = 1
	weapon_panel.anchor_top = 0
	weapon_panel.anchor_right = 1
	weapon_panel.anchor_bottom = 0
	weapon_panel.offset_left = -(HUD_MARGIN + 200)
	weapon_panel.offset_top = HUD_MARGIN
	weapon_panel.offset_right = -HUD_MARGIN
	weapon_panel.offset_bottom = HUD_MARGIN + 120
	add_child(weapon_panel)
	
	var vbox = VBoxContainer.new()
	weapon_panel.add_child(vbox)
	
	# Weapon name
	weapon_name_label = Label.new()
	weapon_name_label.text = "Weapon: AKM"
	weapon_name_label.add_theme_font_size_override("font_size", FONT_SIZE_LARGE)
	weapon_name_label.modulate = Color.YELLOW
	vbox.add_child(weapon_name_label)
	
	# Ammo display
	ammo_label = Label.new()
	ammo_label.text = "Ammo: 30/120"
	ammo_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	vbox.add_child(ammo_label)

# ========== STATS DISPLAY (Bottom-Left) ==========
func _setup_stats_display():
	var stats_panel = PanelContainer.new()
	stats_panel.anchor_left = 0
	stats_panel.anchor_top = 1
	stats_panel.anchor_right = 0
	stats_panel.anchor_bottom = 1
	stats_panel.offset_left = HUD_MARGIN
	stats_panel.offset_top = -(HUD_MARGIN + 80)
	stats_panel.offset_right = HUD_MARGIN + 200
	stats_panel.offset_bottom = -HUD_MARGIN
	add_child(stats_panel)
	
	var vbox = VBoxContainer.new()
	stats_panel.add_child(vbox)
	
	# Kills
	kills_label = Label.new()
	kills_label.text = "Kills: 0"
	kills_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	kills_label.modulate = Color.RED
	vbox.add_child(kills_label)
	
	# Score
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	score_label.modulate = Color.CYAN
	vbox.add_child(score_label)

# ========== ECONOMY / ELO DISPLAY (Bottom-Right) ==========
func _setup_economy_display():
	var eco_panel = PanelContainer.new()
	eco_panel.anchor_left = 1
	eco_panel.anchor_top = 1
	eco_panel.anchor_right = 1
	eco_panel.anchor_bottom = 1
	eco_panel.offset_left = -(HUD_MARGIN + 200)
	eco_panel.offset_top = -(HUD_MARGIN + 100)
	eco_panel.offset_right = -HUD_MARGIN
	eco_panel.offset_bottom = -HUD_MARGIN
	add_child(eco_panel)

	var vbox = VBoxContainer.new()
	eco_panel.add_child(vbox)

	# ELO / Tier
	elo_label = Label.new()
	elo_label.text = "ELO: %d (%s)" % [GameState.elo_rating, GameState.elo_tier]
	elo_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	elo_label.modulate = _tier_color(GameState.elo_tier)
	vbox.add_child(elo_label)

	# Coins
	coins_label = Label.new()
	coins_label.text = "Coins: %d" % GameState.coins
	coins_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	coins_label.modulate = Color(1.0, 0.84, 0.0)  # Gold
	vbox.add_child(coins_label)

	# Gems
	gems_label = Label.new()
	gems_label.text = "Gems: %d" % GameState.gems
	gems_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	gems_label.modulate = Color(0.6, 0.3, 1.0)  # Purple
	vbox.add_child(gems_label)

func _tier_color(tier: String) -> Color:
	match tier:
		"BRONZE": return Color(0.8, 0.5, 0.2)
		"SILVER": return Color(0.75, 0.75, 0.8)
		"GOLD": return Color(1.0, 0.84, 0.0)
		"PLATINUM": return Color(0.3, 0.8, 0.8)
		"DIAMOND": return Color(0.4, 0.7, 1.0)
		"MASTER": return Color(1.0, 0.3, 0.3)
		_: return Color.WHITE

# ========== KILL FEED (Top-Right, Below Weapon) ==========
func _setup_kill_feed():
	kill_feed_container = VBoxContainer.new()
	kill_feed_container.anchor_left = 1
	kill_feed_container.anchor_top = 0
	kill_feed_container.anchor_right = 1
	kill_feed_container.anchor_bottom = 0
	kill_feed_container.offset_left = -(HUD_MARGIN + 250)
	kill_feed_container.offset_top = HUD_MARGIN + 140
	kill_feed_container.offset_right = -HUD_MARGIN
	kill_feed_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(kill_feed_container)

# ========== SIGNAL HANDLERS ==========
func _on_health_changed(new_health: int):
	if health_bar:
		health_bar.value = new_health
	_update_health_bar_color()


func _on_stats_changed(_stats):
	_update_all_displays()

func _on_inventory_changed(_inventory):
	_update_weapon_display()

func _on_player_died():
	print("Player died!")
	_show_game_over()

func _on_remote_player_died(player_id: String):
	_add_kill_feed_message("Player " + player_id + " died", Color.ORANGE)

func _on_wallet_changed(new_coins: int, new_gems: int):
	_update_economy_display()

func _on_elo_changed(new_elo: int, new_tier: String):
	_update_economy_display()

# ========== UPDATE FUNCTIONS ==========
func _update_all_displays():
	_update_health_bar_color()
	_update_weapon_display()
	_update_stats_display()

func _update_health_label():
	pass


func _update_health_bar_color():
	if not health_bar:
		return
	
	var health_percent = float(GameState.current_health) / float(GameState.max_health)
	
	if health_percent > 0.5:
		health_bar.modulate = Color.GREEN
	elif health_percent > 0.25:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func _update_weapon_display():
	if weapon_name_label:
		weapon_name_label.text = "Weapon: " + GameState.current_weapon
	
	if ammo_label and GameState.weapon_stats:
		var weapon_data = GameState.weapon_stats.get(GameState.current_weapon, {})
		var mag_size = weapon_data.get("mag_size", 30)
		var ammo_in_mag = weapon_data.get("ammo_in_mag", 0)
		ammo_label.text = "Ammo: %d / Reserve" % ammo_in_mag

func _update_stats_display():
	if kills_label:
		kills_label.text = "Kills: %d" % GameState.total_kills
	if score_label:
		score_label.text = "Score: %d" % GameState.high_score

func _update_economy_display():
	if coins_label:
		coins_label.text = "Coins: %d" % GameState.coins
	if gems_label:
		gems_label.text = "Gems: %d" % GameState.gems
	if elo_label:
		elo_label.text = "ELO: %d (%s)" % [GameState.elo_rating, GameState.elo_tier]
		elo_label.modulate = _tier_color(GameState.elo_tier)

# ========== KILL FEED ==========
func _add_kill_feed_message(message: String, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	label.modulate = color
	kill_feed_container.add_child(label)
	
	# Auto-remove after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(label):
		label.queue_free()

# ========== GAME OVER SCREEN ==========
func _show_game_over():
	var game_over_panel = ColorRect.new()
	game_over_panel.color = Color.BLACK
	game_over_panel.color.a = 0.7
	game_over_panel.anchor_left = 0
	game_over_panel.anchor_top = 0
	game_over_panel.anchor_right = 1
	game_over_panel.anchor_bottom = 1
	add_child(game_over_panel)
	
	var center_container = CenterContainer.new()
	center_container.anchor_left = 0
	center_container.anchor_top = 0
	center_container.anchor_right = 1
	center_container.anchor_bottom = 1
	game_over_panel.add_child(center_container)
	
	var vbox = VBoxContainer.new()
	center_container.add_child(vbox)
	
	var game_over_label = Label.new()
	game_over_label.text = "YOU DIED"
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.modulate = Color.RED
	vbox.add_child(game_over_label)
	
	var stats_label = Label.new()
	stats_label.text = "Final Stats:\nKills: %d\nScore: %d" % [GameState.total_kills, GameState.high_score]
	stats_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(stats_label)

# ========== PROCESS (Optional: Smooth transitions) ==========
func _process(_delta):
	# Can add smooth animations here if needed
	pass
