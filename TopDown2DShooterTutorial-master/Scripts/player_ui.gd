extends CanvasLayer

class_name PlayerUI

@onready var life_bar = $MarginContainer/LifeBar
@onready var ammo_container = %AmmoContainer
@onready var ammo_left_label = %AmmoLeftLabel
@onready var key_icon = %KeyIcon
@onready var extract_counter_label = $MarginContainer/ExtractCounterLabel
@onready var match_timer_label: Label = $MatchTimer/MatchTimerLabel
@onready var game_over_label = %GameOverLabel
@onready var game_over_container = $GameOverContainer
@onready var settings_menu: Control = $SettingsMenu


var bullet_texture = preload("res://Assets/bullet_icon.png")
var kill_feed_container
var minimap_camera

var player: Player
var shooting_system: ShootingSystem
var name_label: Label

@export var match_duration_sec: float = 300.0
var _time_left_sec: float = 300.0
var _game_over: bool = false
var _cached_kills: int = 0
var _cached_score: int = 0

# Stats display labels
var weapon_icon_rect: TextureRect
var weapon_icon_label: Label
var _life_fill_style: StyleBoxFlat
var weapon_label: Label
var kills_label: Label
var ammo_text_label: Label
var ammo_mag_label: Label
var ammo_reserve_label: Label
const AMMO_SEGMENTS := 3

# Reuse the same HUD background color already used in PlayerUI scene (MatchTimer/Bg).
const HUD_BG_COLOR := Color(0, 0, 0, 0.5)


func _make_hud_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HUD_BG_COLOR
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	return sb



func _ready():
	_time_left_sec = match_duration_sec
	if GameState.is_multiplayer:
		# Multiplayer uses the respawn panel in multiplayer_main.gd.
		# Keep the singleplayer GameOverContainer hidden to avoid overlapping UI.
		_game_over = false
		if game_over_container:
			game_over_container.hide()
	setup_kill_feed()
	setup_stats_display()
	# Call deferred to ensure world is ready for minimap
	call_deferred("setup_minimap")

	# Bind after the Player has entered the scene tree.
	call_deferred("_bind_to_player")
	_update_stats_display()
	build_ammo_segments()
	


func _bind_to_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	player.health_changed.connect(_on_local_health_changed)
	player.kills_changed.connect(_on_local_kills_changed)
	player.died.connect(_on_local_player_died)
	if player.health_system:
		_on_local_health_changed(player.health_system.current_health, player.health_system.base_health)
		_on_local_kills_changed(player.kills, player.score)
	shooting_system = player.get_node_or_null("ShootingSystem") as ShootingSystem
	if shooting_system:
		shooting_system.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(shooting_system.ammo_in_magazine, shooting_system.reserve_ammo)
	_update_stats_display()


func _make_akm_icon_texture() -> Texture2D:
	var w := 128
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # transparent

	# Colors
	var c_main := Color(0.12, 0.12, 0.12, 1.0)     # gun body
	var c_wood := Color(0.38, 0.22, 0.12, 1.0)     # mag/wood
	var c_outline := Color(0, 0, 0, 0.35)          # soft outline

	# --- Outline pass (draw slightly bigger shapes behind) ---
	_fill_rect(img, Rect2i(20-1, 22-1, 56+2, 8+2), c_outline)  # receiver outline
	_fill_rect(img, Rect2i(76-1, 24-1, 38+2, 3+2), c_outline)  # barrel outline
	_fill_rect(img, Rect2i(10-1, 20-1, 16+2, 10+2), c_outline) # stock outline
	_fill_rect(img, Rect2i(44-1, 30-1, 14+2, 16+2), c_outline) # mag outline
	_fill_rect(img, Rect2i(36-1, 30-1, 6+2, 10+2), c_outline)  # grip outline

	# --- Main silhouette ---
	# stock
	_fill_rect(img, Rect2i(10, 20, 16, 10), c_main)
	# receiver
	_fill_rect(img, Rect2i(20, 22, 56, 8), c_main)
	# barrel
	_fill_rect(img, Rect2i(76, 24, 38, 3), c_main)
	# front sight
	_fill_rect(img, Rect2i(112, 22, 3, 6), c_main)

	# grip
	_fill_rect(img, Rect2i(36, 30, 6, 10), c_main)

	# magazine (slightly “curved” using stepped rectangles)
	_fill_rect(img, Rect2i(44, 30, 14, 4), c_wood)
	_fill_rect(img, Rect2i(45, 34, 13, 4), c_wood)
	_fill_rect(img, Rect2i(46, 38, 12, 4), c_wood)
	_fill_rect(img, Rect2i(47, 42, 11, 4), c_wood)

	# small wood handguard
	_fill_rect(img, Rect2i(66, 30, 10, 4), c_wood)

	var tex := ImageTexture.create_from_image(img)
	return tex

func _fill_rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, c)







func setup_kill_feed():
	kill_feed_container = VBoxContainer.new()
	# Anchor to top right
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_WIDTH, 20)
	kill_feed_container.add_theme_constant_override("separation", 6)
	add_child(kill_feed_container)

func setup_stats_display():

	life_bar.get_parent().remove_child(life_bar)
	add_child(life_bar)

	# Bottom-center health bar (resolution independent)
	life_bar.custom_minimum_size = Vector2(420, 32)
	life_bar.anchor_left = 0.5
	life_bar.anchor_right = 0.5
	life_bar.anchor_top = 1.0
	life_bar.anchor_bottom = 1.0
	life_bar.offset_left = -life_bar.custom_minimum_size.x * 0.5
	life_bar.offset_right = life_bar.custom_minimum_size.x * 0.5
	# 12px above bottom edge
	life_bar.offset_bottom = -12.0
	life_bar.offset_top = life_bar.offset_bottom - life_bar.custom_minimum_size.y
	life_bar.show_percentage = false
	life_bar.z_index = 50

	name_label = Label.new()
	var display_name = GameState.username if GameState and GameState.username != "" else "Player"
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.modulate = Color(0.95, 0.95, 0.95)

	name_label.custom_minimum_size.x = life_bar.custom_minimum_size.x
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.anchor_left = 0.5
	name_label.anchor_right = 0.5
	name_label.anchor_top = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = -life_bar.custom_minimum_size.x * 0.5
	name_label.offset_right = life_bar.custom_minimum_size.x * 0.5
	name_label.offset_bottom = life_bar.offset_top - 4.0
	name_label.offset_top = name_label.offset_bottom - 28.0


	name_label.z_index = life_bar.z_index + 1
	add_child(name_label)

	_life_fill_style = StyleBoxFlat.new()
	_life_fill_style.bg_color = Color(0.2, 0.85, 0.3)
	life_bar.add_theme_stylebox_override("fill", _life_fill_style)
	# Make the health bar sit on a consistent HUD background.
	life_bar.add_theme_stylebox_override("background", _make_hud_panel_style())


	
	# STATS PANEL (Kills/Weapon)
	
	var stats_panel = PanelContainer.new()
	stats_panel.anchor_left = 1.0
	stats_panel.anchor_right = 1.0
	stats_panel.anchor_top = 0.0
	stats_panel.anchor_bottom = 0.0
	stats_panel.offset_right = -12.0
	stats_panel.offset_left = stats_panel.offset_right - 420.0
	stats_panel.offset_top = 12.0
	stats_panel.offset_bottom = 150.0
	stats_panel.scale = Vector2(1.35, 1.35)
	stats_panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	add_child(stats_panel)

	var stats_vbox = VBoxContainer.new()
	stats_panel.add_child(stats_vbox)

	kills_label = Label.new()
	kills_label.add_theme_font_size_override("font_size", 26)
	stats_vbox.add_child(kills_label)

	weapon_label = Label.new()
	weapon_label.add_theme_font_size_override("font_size", 22)
	stats_vbox.add_child(weapon_label)

	
	# AMMO PANEL (Bullets UI)
	
	var ammo_panel = PanelContainer.new()
	ammo_panel.anchor_left = 0.0
	ammo_panel.anchor_right = 0.0
	ammo_panel.anchor_top = 0.5
	ammo_panel.anchor_bottom = 0.5
	ammo_panel.offset_left = 12.0
	ammo_panel.offset_right = 452.0
	ammo_panel.offset_top = -110.0
	ammo_panel.offset_bottom = 110.0
	ammo_panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	add_child(ammo_panel)

	var ammo_vbox = VBoxContainer.new()
	ammo_panel.add_child(ammo_vbox)


	# --- Weapon icon above bullets ---
	weapon_icon_rect = TextureRect.new()
	weapon_icon_rect.texture = _make_akm_icon_texture()
	weapon_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP
	weapon_icon_rect.custom_minimum_size = Vector2(220, 80)
	ammo_vbox.add_child(weapon_icon_rect)

	# (Optional small text under icon, looks like game HUD)
	weapon_icon_label = Label.new()
	weapon_icon_label.text = "AKM"
	weapon_icon_label.add_theme_font_size_override("font_size", 18)
	weapon_icon_label.modulate = Color(0.85, 0.85, 0.85)
	ammo_vbox.add_child(weapon_icon_label)

	var ammo_row = HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 10)
	ammo_vbox.add_child(ammo_row)

	# move AmmoContainer into our row (icons)
	if ammo_container and ammo_container.get_parent():
		ammo_container.get_parent().remove_child(ammo_container)
	ammo_row.add_child(ammo_container)

	ammo_container.visible = true
	ammo_container.add_theme_constant_override("separation", -6)
	ammo_container.custom_minimum_size = Vector2(AMMO_SEGMENTS * 34, 32)

	build_ammo_segments()

	ammo_mag_label = Label.new()
	ammo_mag_label.add_theme_font_size_override("font_size", 26)
	ammo_mag_label.modulate = Color(0.95, 0.95, 0.95)
	ammo_row.add_child(ammo_mag_label)

	ammo_reserve_label = Label.new()
	ammo_reserve_label.add_theme_font_size_override("font_size", 20)
	ammo_reserve_label.modulate = Color(0.85, 0.85, 0.85)
	ammo_row.add_child(ammo_reserve_label)

	ammo_left_label.visible = false


func build_ammo_segments() -> void:
	if ammo_container == null:
		return

	for child in ammo_container.get_children():
		ammo_container.remove_child(child)
		child.free()

	ammo_container.custom_minimum_size = Vector2(AMMO_SEGMENTS * 34, 32)

	for i in range(AMMO_SEGMENTS):
		var icon := TextureRect.new()
		icon.texture = bullet_texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(28, 28)
		icon.modulate = Color(1, 1, 1, 1.0)
		ammo_container.add_child(icon)


func _update_stats_display():
	if name_label:
		var display_name = GameState.username if GameState and GameState.username != "" else "Player"
		name_label.text = display_name

	if kills_label:
		if player:
			kills_label.text = "Kills: %d | Score: %d" % [player.kills, player.score]
		else:
			kills_label.text = "Kills: 0 | Score: 0"

	if weapon_icon_label:
		weapon_icon_label.text = GameState.current_weapon if GameState else "AKM"



func _update_life_bar_color() -> void:
	if _life_fill_style == null:
		return

	var max_hp: float = float(life_bar.max_value)
	if max_hp <= 0.0:
		max_hp = 1.0

	var cur_hp: float = float(life_bar.value)
	var ratio: float = cur_hp / max_hp

	if ratio > 0.5:
		_life_fill_style.bg_color = Color(0.2, 0.85, 0.3)
	elif ratio > 0.25:
		_life_fill_style.bg_color = Color(0.95, 0.85, 0.2)
	else:
		_life_fill_style.bg_color = Color(0.95, 0.25, 0.25)

	life_bar.queue_redraw()


func _on_local_health_changed(new_health: int, max_health: int) -> void:
	life_bar.max_value = max_health
	life_bar.value = new_health
	_update_life_bar_color()
	_update_stats_display()


func _on_local_kills_changed(_kills: int, _score: int) -> void:
	_cached_kills = _kills
	_cached_score = _score
	_update_stats_display()

func _on_ammo_changed(mag: int, reserve: int) -> void:
	if ammo_container.get_child_count() == 0:
		build_ammo_segments()

	# Hide old legacy UI
	ammo_left_label.visible = false

	# Ensure icon count matches mag size (try common property names, fallback 30)
	var mag_size := 30
	if shooting_system:
		var v = shooting_system.get("mag_size")
		if v != null:
			mag_size = int(v)
		else:
			v = shooting_system.get("magazine_size")
			if v != null:
				mag_size = int(v)

	var ratio := float(mag) / float(max(1, mag_size))
	var filled := int(ceil(ratio * AMMO_SEGMENTS))
	filled = clamp(filled, 0, AMMO_SEGMENTS)

	for i in range(ammo_container.get_child_count()):
		var icon := ammo_container.get_child(i) as TextureRect
		if icon:
			icon.modulate = Color(1, 1, 1, 1.0) if i < filled else Color(1, 1, 1, 0.25)

	# Numbers on the right (hybrid)
	if ammo_mag_label:
		ammo_mag_label.text = str(mag)
	if ammo_reserve_label:
		ammo_reserve_label.text = "/ %d" % reserve


func _on_local_player_died() -> void:
	if GameState.is_multiplayer:
		return
	on_game_over(true)

func setup_minimap():
	var map_panel = Panel.new()
	map_panel.size = Vector2(270, 270)
	map_panel.position = Vector2(10, 10)
	add_child(map_panel)

	# Simple minimap using SubViewport sharing world_2d
	var map_container = SubViewportContainer.new()
	map_container.size = Vector2(260, 260)
	map_container.position = Vector2(5, 5)
	map_panel.add_child(map_container)
	
	var sub_vp = SubViewport.new()
	sub_vp.size = Vector2(260, 260)
	sub_vp.handle_input_locally = false
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Getting the main viewport's world_2d to see the same things
	sub_vp.world_2d = get_viewport().get_world_2d()
	
	map_container.add_child(sub_vp)
	
	minimap_camera = Camera2D.new()
	# Slightly zoomed out so the larger minimap shows a similar area.
	minimap_camera.zoom = Vector2(0.17, 0.17)
	sub_vp.add_child(minimap_camera)

func _process(_delta):
	if minimap_camera and player:
		minimap_camera.global_position = player.global_position
	_update_match_timer(_delta)

func _update_match_timer(delta: float) -> void:
	if _game_over:
		return
	_time_left_sec = max(0.0, _time_left_sec - delta)
	if match_timer_label:
		var total := int(ceil(_time_left_sec))
		var mm := total / 60
		var ss := total % 60
		match_timer_label.text = "%02d:%02d" % [mm, ss]
		if total <= 10:
			match_timer_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		else:
			match_timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _time_left_sec <= 0.0:
		_game_over = true
		on_game_over(true)

func set_match_time_left(seconds_left: int) -> void:
	# For multiplayer: allow the server to correct/synchronize the countdown.
	_time_left_sec = max(0.0, float(seconds_left))

func _on_network_player_died(id):
	add_kill_feed_msg("Player " + str(id) + " died")



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_menu.visible:
			settings_menu.hide_menu()
		else:
			settings_menu.show_menu()


func add_kill_feed_msg(msg):
	var label = Label.new()
	label.text = msg
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 20)
	kill_feed_container.add_child(label)
	
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(label):
		label.queue_free()

func set_life_bar_max_value(max_value: int):
	life_bar.max_value = max_value

func update_life_bar_value(life: int) -> void:
	life_bar.value = life
	_update_life_bar_color()


func set_max_ammo(max_ammo: int):
	# Remove old ammo
	for child in ammo_container.get_children():
		child.queue_free()

	for i in max_ammo:
		var ammo_texture_rect = TextureRect.new()
		ammo_texture_rect.texture = bullet_texture
		ammo_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
		ammo_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ammo_container.add_child(ammo_texture_rect)

func set_ammo_left(ammo_left: int):
	ammo_left_label.text = " /%d" % ammo_left

func bullet_shot(bullet_number: int):
	var bullet_count = ammo_container.get_child_count()
	if bullet_number < bullet_count:
		var bullet_texture_rect = ammo_container.get_child(bullet_count - 1 - bullet_number)
		bullet_texture_rect.modulate = Color(Color.WHITE, .5)

func gun_reloaded(ammo_in_magazine: int, total_ammo_left: int):
	var bullet_count = ammo_container.get_child_count()
	
	for i in ammo_in_magazine:
		if i < bullet_count:
			var bullet_texture_rect = ammo_container.get_child(bullet_count - 1 - i)
			bullet_texture_rect.modulate = Color(Color.WHITE)
	
	set_ammo_left(total_ammo_left)

func on_key_pickup():
	key_icon.show()
	
func update_extract_timer(time_left: float):
	if extract_counter_label.hidden:
		extract_counter_label.show()
	extract_counter_label.text = "%.2f" % time_left

func hide_extract_countdown():
	extract_counter_label.hide()

func on_game_over(is_game_lost: bool):
	if GameState.is_multiplayer:
		return
	_game_over = true
	if is_game_lost:
		game_over_label.text = "YOU HAVE DIED!!!\nScore: %d\nZombies killed: %d" % [_cached_score, _cached_kills]
	else:
		game_over_label.text = "You have extracted :)\nScore: %d\nZombies killed: %d" % [_cached_score, _cached_kills]
	game_over_container.show()

func _on_play_again_button_pressed():
	get_tree().reload_current_scene()
