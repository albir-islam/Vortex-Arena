extends CharacterBody2D

class_name Player

const SPEED = 400.0  # Increased from 200
const ACCELERATION = 1000.0  # Increased from 600
const FOOTSTEP_INTERVAL := 0.35

signal health_changed(current_health: int, max_health: int)
signal kills_changed(kills: int, score: int)
signal died

@onready var health_system: HealthSystem = $HealthSystem as HealthSystem
@onready var shooting_system: ShootingSystem = $ShootingSystem as ShootingSystem
@onready var multiplayer_network = get_node("/root/MultiplayerNetwork")

@onready var player_ui: PlayerUI = null

var player_name: String = "Player"
var kills: int = 0
var score: int = 0

var player_id: String = "" # Multiplayer id (matches MultiplayerNetwork.my_player_id)

var has_key: bool = false

var last_position_sync_time = 0.0
var position_sync_interval = 0.05  # Sync position every 50ms
var current_velocity := Vector2.ZERO  # Smooth velocity for acceleration

var _dead: bool = false
var _invulnerable_until_ms: int = 0
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0
var _respawn_token: int = 0
var _footstep_timer := 0.0

func _ready():
	# Add to player group for detection
	add_to_group("player")
	add_to_group("players")
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	player_ui = _get_player_ui()
	
	# Create input actions if they don't exist
	_setup_input_actions()
	
	if GameState and GameState.username != "":
		player_name = GameState.username

	if GameState.is_multiplayer and multiplayer_network:
		player_id = str(multiplayer_network.my_player_id)

	if not GameState.is_multiplayer and MusicManager:
		if MusicManager.has_method("set_music_half_volume"):
			MusicManager.set_music_half_volume()

	if health_system:
		health_system.damage_taken.connect(_on_local_health_changed)
		health_system.died.connect(_on_local_died)
		emit_signal("health_changed", health_system.current_health, health_system.base_health)

	emit_signal("kills_changed", kills, score)

func get_player_id() -> String:
	return player_id

func set_player_id(id: String) -> void:
	player_id = str(id)

func _get_player_ui() -> PlayerUI:
	if is_instance_valid(player_ui):
		return player_ui
	var scene := get_tree().current_scene
	if scene:
		player_ui = scene.get_node_or_null("PlayerUI") as PlayerUI
	return player_ui

func on_key_pickup() -> void:
	has_key = true
	var ui := _get_player_ui()
	if ui and ui.has_method("on_key_pickup"):
		ui.on_key_pickup()

func update_extract_timer(time_left: float) -> void:
	var ui := _get_player_ui()
	if ui and ui.has_method("update_extract_timer"):
		ui.update_extract_timer(time_left)

func hide_extract_countdown() -> void:
	var ui := _get_player_ui()
	if ui and ui.has_method("hide_extract_countdown"):
		ui.hide_extract_countdown()

func extract() -> void:
	var ui := _get_player_ui()
	if ui and ui.has_method("on_game_over"):
		ui.on_game_over(false)

func _physics_process(delta):
	# ========== WASD MOVEMENT (Independent from mouse) ==========
	var input_direction := Vector2.ZERO
	
	# Get WASD input (new input actions)
	if Input.is_action_pressed("move_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		input_direction.y += 1
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1
	
	# Normalize for diagonal movement
	input_direction = input_direction.normalized()
	
	# Direct movement (no excessive smoothing)
	if input_direction.length() > 0:
		current_velocity = input_direction * SPEED
	else:
		current_velocity = Vector2.ZERO
	
	velocity = current_velocity
	move_and_slide()
	
	# ========== MOUSE AIMING (Independent from movement) ==========
	var mouse_pos = get_global_mouse_position()
	look_at(mouse_pos)  # Rotate to face mouse cursor

	if input_direction.length() > 0 and not _dead:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0 and MusicManager and MusicManager.has_method("play_step"):
			MusicManager.play_step()
			_footstep_timer = FOOTSTEP_INTERVAL
	else:
		_footstep_timer = 0.0
	
	# Send position to server periodically (not every frame)
	last_position_sync_time += delta
	if last_position_sync_time >= position_sync_interval:
		# Use MultiplayerNetwork in multiplayer mode
		if GameState.is_multiplayer and multiplayer_network:
			multiplayer_network.send_move(global_position, rotation)
		else:
			Network.send_move(global_position)
		last_position_sync_time = 0.0

func _input(event):
	# Weapon swap (E key)
	if Input.is_action_just_pressed("weapon_swap"):
		if GameState and GameState.has_method("swap_weapon"):
			GameState.swap_weapon()
	
	# Use healing items (Q key)
	if Input.is_action_just_pressed("use_healing"):
		if GameState and GameState.has_method("use_healing_item"):
			GameState.use_healing_item("first_aid")

func _setup_input_actions():
	"""Auto-create input actions if they don't exist"""
	var actions = {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"weapon_swap": KEY_E,
		"use_healing": KEY_Q
	}
	
	for action_name in actions.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var event = InputEventKey.new()
			event.keycode = actions[action_name]
			InputMap.action_add_event(action_name, event)
			print("Created input action: ", action_name)

# Called by health pickup areas
func on_health_pickup(amount: int):
	if health_system and health_system.has_method("heal"):
		health_system.heal(amount)

# Called by zombie attacks
func take_damage(damage: int):
	if _dead:
		return
	if Time.get_ticks_msec() < _invulnerable_until_ms:
		return
	if health_system:
		health_system.take_damage(damage)

func is_dead() -> bool:
	return _dead

func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_until_ms

func _set_collisions_enabled(enabled: bool) -> void:
	if enabled:
		# Restore whatever the scene configured (typically player layer 2 and a mask including world/zombies/pickups).
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
	else:
		# Remove from physics so zombies/other bodies stop overlapping and triggering damage.
		collision_layer = 0
		collision_mask = 0

# Called when bullet hits another player
func register_hit_on_enemy(enemy_id: String, damage: int):
	if Network and Network.has_method("send_hit"):
		Network.send_hit(enemy_id, damage)

func on_ammo_pickup():
	if shooting_system and shooting_system.has_method("add_reserve_ammo"):
		shooting_system.add_reserve_ammo(shooting_system.magazine_size)

func add_kill(points: int = 100) -> void:
	kills += 1
	score += points
	emit_signal("kills_changed", kills, score)
	if MusicManager and MusicManager.has_method("play_kill"):
		MusicManager.play_kill()

func _on_local_health_changed(current_health: int) -> void:
	emit_signal("health_changed", current_health, health_system.base_health)

func _on_local_died() -> void:
	if MusicManager and MusicManager.has_method("play_death"):
		MusicManager.play_death()
	emit_signal("died")
	_dead = true
	_invulnerable_until_ms = Time.get_ticks_msec() + 2000
	# Make sure zombies stop targeting / overlapping the dead body.
	if is_in_group("players"):
		remove_from_group("players")
	_set_collisions_enabled(false)
	# In multiplayer, don't destroy player - let multiplayer_main handle respawn
	if GameState.is_multiplayer:
		# Hide and disable player instead of destroying
		visible = false
		set_physics_process(false)
		set_process(false)
		set_process_input(false)
		# Notify multiplayer main scene about death
		var mp_main = get_tree().current_scene
		if mp_main and mp_main.has_method("_on_local_player_died"):
			mp_main._on_local_player_died()
	else:
		queue_free()

# Respawn the player at a given position (multiplayer only)
func respawn_at(spawn_position: Vector2) -> void:
	_respawn_token += 1
	var token := _respawn_token
	_dead = false
	global_position = spawn_position
	visible = true
	set_physics_process(true)
	set_process(true)
	set_process_input(true)
	if not is_in_group("players"):
		add_to_group("players")
	# Reset health
	if health_system:
		health_system.current_health = health_system.base_health
		emit_signal("health_changed", health_system.current_health, health_system.base_health)
	# Brief spawn protection + avoid immediate zombie overlap/attack.
	_invulnerable_until_ms = Time.get_ticks_msec() + 900
	_set_collisions_enabled(false)
	await get_tree().create_timer(0.9).timeout
	if token != _respawn_token:
		return
	if not _dead:
		_set_collisions_enabled(true)
