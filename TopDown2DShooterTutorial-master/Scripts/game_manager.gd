extends Node

var remote_player_scene = preload("res://Scenes/remote_player.tscn")
var zombie_enemy_scene = preload("res://Scenes/zombie_enemy.tscn")
var remote_players := {} # id -> node

# ========== ZOMBIE SPAWNING & DIFFICULTY ==========
var player: CharacterBody2D
var spawn_timer: Timer
var current_zombie_count := 0
var max_zombies := 15  # Start with more zombies
var max_zombies_target := 50  # Way more zombies
var spawn_interval := 1.5  # Faster spawning (1.5 seconds)
var difficulty_timer := 0.0
var difficulty_increase_interval := 20.0  # Increase difficulty every 20 seconds

const SPAWN_DISTANCE := 400.0  # Distance from player to spawn zombies
const VIEWPORT_MARGIN := 100.0

func _ready():
	# If the current scene already provides its own spawner/HUD, don't duplicate.
	if get_tree().current_scene and get_tree().current_scene.has_node("ZombieSpawner"):
		print("GameManager: scene ZombieSpawner found; skipping built-in zombie spawning/HUD.")
		return

	# Find the player node
	player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		print("ERROR: Player not found in scene!")
		return
	
	# Create HUD if not already present
	if not get_tree().current_scene.has_node("GameHUD"):
		var hud = GameHUD.new()
		get_tree().current_scene.add_child(hud)
		print("GameHUD created and added to scene")
	
	# Setup zombie spawn timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	
	print("Zombie spawner initialized. Starting with ", max_zombies, " max zombies")

func _process(delta):
	# Increase difficulty over time
	difficulty_timer += delta
	if difficulty_timer >= difficulty_increase_interval:
		difficulty_timer = 0.0
		if max_zombies < max_zombies_target:
			max_zombies += 5  # Increase by 5 instead of 2
			print("Difficulty increased! Max zombies now: ", max_zombies)

func _on_spawn_timer_timeout():
	# Only spawn if we haven't reached max zombies
	if current_zombie_count < max_zombies:
		_spawn_zombie_at_random_position()

func _spawn_zombie_at_random_position():
	if not player:
		return
	
	# Generate random position around player
	var angle = randf() * TAU  # Full circle
	var distance = SPAWN_DISTANCE + randf_range(-50, 50)
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	
	# Ensure spawn position is on screen edge (outside view)
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_center = viewport_rect.get_center()
	var viewport_size = viewport_rect.get_size()
	
	# Clamp to just outside viewport
	spawn_pos.x = clamp(spawn_pos.x, viewport_center.x - viewport_size.x / 2 - VIEWPORT_MARGIN, viewport_center.x + viewport_size.x / 2 + VIEWPORT_MARGIN)
	spawn_pos.y = clamp(spawn_pos.y, viewport_center.y - viewport_size.y / 2 - VIEWPORT_MARGIN, viewport_center.y + viewport_size.y / 2 + VIEWPORT_MARGIN)
	
	var zombie = zombie_enemy_scene.instantiate()
	zombie.global_position = spawn_pos
	
	# Connect to death signal for tracking
	if zombie.has_node("HealthSystem"):
		var health_system = zombie.get_node("HealthSystem")
		if health_system:
			health_system.died.connect(func(): _on_zombie_died())
	
	get_tree().current_scene.add_child(zombie)
	current_zombie_count += 1
	
func _on_zombie_died():
	current_zombie_count = max(0, current_zombie_count - 1)

func update_remote_player(id: String, x: float, y: float):
	if not remote_players.has(id):
		_spawn_remote_player(id, x, y)

	var p = remote_players[id]
	p.target_position = Vector2(x, y)


func _spawn_remote_player(id, x, y):
	print("Spawning remote player", id)

	var p = remote_player_scene.instantiate()
	p.global_position = Vector2(x, y)
	p.set_player_id(id)  # Set the player ID for hit detection

	# Kill camera on remote players
	if p.has_node("Camera2D"):
		p.get_node("Camera2D").queue_free()

	# Label
	var label := Label.new()
	label.text = "Player " + id
	label.position = Vector2(-20, -50)
	p.add_child(label)

	get_tree().current_scene.add_child(p)
	remote_players[id] = p

func remove_remote_player(id: String):
	if remote_players.has(id):
		remote_players[id].queue_free()
		remote_players.erase(id)
