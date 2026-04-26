extends CharacterBody2D

var target_position = Vector2.ZERO
var player_id: String = ""
var current_health: int = 100

@onready var life_bar := get_node_or_null("LifeBar") as ProgressBar

@export var speed = 300

func _ready():
	add_to_group("players")
	var ss := get_node_or_null("ShootingSystem")
	if ss:
		ss.set_process(false)
		ss.set_physics_process(false)
		ss.set_process_input(false)
	_update_life_bar()

func set_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, 100)
	_update_life_bar()

func _update_life_bar() -> void:
	if life_bar == null:
		return
	life_bar.max_value = 100
	life_bar.value = current_health

func _physics_process(delta):
	if target_position != Vector2.ZERO:
		var direction = (target_position - global_position)
		if direction.length() > 5:
			velocity = direction.normalized() * speed
			move_and_slide()
			# Simple rotation towards movement
			if direction.length() > 0:
				rotation = lerp_angle(rotation, direction.angle(), 10 * delta)
		else:
			global_position = target_position

func get_player_id() -> String:
	return player_id

func set_player_id(id: String):
	player_id = id

func take_damage(damage: int):
	current_health = max(current_health - damage, 0)
	_update_life_bar()
	print("Remote player", player_id, "took", damage, "damage. Health:", current_health)
	
	# Visual feedback for damage
	if has_method("hit_effect"):
		hit_effect()

func is_dead() -> bool:
	return current_health <= 0

func hit_effect():
	# Flash red or show damage effect
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
