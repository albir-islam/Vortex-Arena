extends Marker2D

class_name ShootingSystem

signal shot(ammo_in_magazine: int)
signal gun_reload(ammo_in_magazine: int, ammo_left: int)
signal ammo_added(total_ammo: int)

signal ammo_changed(ammo_in_magazine: int, reserve_ammo: int)

@export var max_reserve_ammo: int = 210
@export var reserve_ammo: int = 210

@onready var bullet_scene = preload("res://Scenes/bullet.tscn")

@export var magazine_size: int = 30
var ammo_in_magazine: int = 0
var crosshair_texture = preload("res://Assets/crosshair_white-export.png")

var can_shoot = true
var fire_rate = 0.1
var reload_time = 2.5
var current_damage = 25

var _cursor_applied := false

const _CROSSHAIR_CURSOR_SHAPES := [
	Input.CURSOR_ARROW,
	Input.CURSOR_CROSS,
	Input.CURSOR_IBEAM,
	Input.CURSOR_POINTING_HAND,
]

func _ready():
	_apply_crosshair_cursor()
	var win := get_window()
	if win:
		# Ensure cursor resets when user alt-tabs / clicks outside the window.
		if not win.focus_exited.is_connected(_on_window_focus_exited):
			win.focus_exited.connect(_on_window_focus_exited)
		if not win.focus_entered.is_connected(_on_window_focus_entered):
			win.focus_entered.connect(_on_window_focus_entered)
	_update_weapon_stats()
	ammo_in_magazine = magazine_size
	emit_signal("ammo_changed", ammo_in_magazine, reserve_ammo)
	
	# Listen to weapon changes
	GameState.inventory_changed.connect(_on_inventory_changed)

func _exit_tree() -> void:
	_reset_cursor()

func _apply_crosshair_cursor() -> void:
	if crosshair_texture == null:
		return
	var hotspot := Vector2.ZERO
	if crosshair_texture is Texture2D:
		hotspot = Vector2((crosshair_texture as Texture2D).get_size()) * 0.5
	for shape in _CROSSHAIR_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(crosshair_texture, shape, hotspot)
	_cursor_applied = true

func _reset_cursor() -> void:
	if not _cursor_applied:
		return
	# Passing null restores default OS cursor.
	for shape in _CROSSHAIR_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(null, shape)
	_cursor_applied = false

func _on_window_focus_exited() -> void:
	_reset_cursor()

func _on_window_focus_entered() -> void:
	_apply_crosshair_cursor()

func _update_weapon_stats():
	var weapon_data = GameState.get_current_weapon_stats()
	current_damage = weapon_data.get("damage", 25)
	fire_rate = weapon_data.get("fireRate", 0.1)
	reload_time = weapon_data.get("reloadTime", 2.5)
	print("Weapon stats updated:", GameState.current_weapon, "Damage:", current_damage)

func _on_inventory_changed(inventory):
	_update_weapon_stats()
	# Keep the strict ammo system (30 / 210) regardless of weapon.
	ammo_in_magazine = min(ammo_in_magazine, magazine_size)
	emit_signal("ammo_changed", ammo_in_magazine, reserve_ammo)

func _process(_delta):
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()
	if Input.is_action_just_pressed("reload"):
		reload()
	
func reload():
	if reserve_ammo <= 0 or ammo_in_magazine == magazine_size:
		return
	if MusicManager and MusicManager.has_method("play_reload"):
		MusicManager.play_reload()
	
	can_shoot = false
	var bullet_missing_in_magazine = magazine_size - ammo_in_magazine
	var reloaded_amount = min(bullet_missing_in_magazine, reserve_ammo)
	
	reserve_ammo -= reloaded_amount
	ammo_in_magazine += reloaded_amount
	gun_reload.emit(ammo_in_magazine, reserve_ammo)
	emit_signal("ammo_changed", ammo_in_magazine, reserve_ammo)
	
	# Wait for reload animation
	await get_tree().create_timer(reload_time).timeout
	can_shoot = true
	
func shoot():
	if ammo_in_magazine == 0:
		return
	
	ammo_in_magazine -= 1
	can_shoot = false

	if MusicManager and MusicManager.has_method("play_shoot"):
		MusicManager.play_shoot()
	
	# Create bullet locally
	var bullet = bullet_scene.instantiate() as Bullet
	bullet.damage = current_damage
	var mpn := get_node_or_null("/root/MultiplayerNetwork")
	if GameState.is_multiplayer and mpn:
		bullet.shooter_id = str(mpn.my_player_id)
	else:
		bullet.shooter_id = GameState.username
	get_tree().current_scene.add_child(bullet)
	
	var move_direction = (get_global_mouse_position() - global_position).normalized()
	bullet.move_direction = move_direction
	# Spawn slightly in front of the muzzle so we don't overlap our own collider.
	bullet.global_position = global_position + move_direction * 18.0
	bullet.rotation = move_direction.angle()
	
	shot.emit(ammo_in_magazine)
	emit_signal("ammo_changed", ammo_in_magazine, reserve_ammo)
	
	# Send shoot message to server
	var direction_angle = move_direction.angle()
	if GameState.is_multiplayer and mpn:
		mpn.send_shoot(global_position, direction_angle)
	elif Network and Network.current_match_id != "" and Network.has_method("send_shoot"):
		Network.send_shoot(global_position, direction_angle)
	
	# Fire rate cooldown
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

func add_reserve_ammo(amount: int) -> void:
	if amount <= 0:
		return
	reserve_ammo = min(max_reserve_ammo, reserve_ammo + amount)
	ammo_added.emit(reserve_ammo)
	emit_signal("ammo_changed", ammo_in_magazine, reserve_ammo)

func on_ammo_pickup() -> void:
	add_reserve_ammo(magazine_size)
