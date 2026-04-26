extends Node

class_name ZombieSpawner

@export var zombie_scene: PackedScene = preload("res://Scenes/zombie_enemy.tscn")

@export_group("Scaling")
@export var initial_alive_cap: int = 18
@export var max_alive_cap: int = 45
@export var cap_increase_every_sec: float = 20.0
@export var cap_increase_by: int = 5

@export_group("Spawn")
@export var initial_spawn_interval: float = 1.0
@export var min_spawn_interval: float = 0.35
@export var spawn_interval_decay_every_sec: float = 25.0
@export var spawn_interval_decay_by: float = 0.1

@export_group("Spawn Position")
@export var spawn_distance_min: float = 750.0
@export var spawn_distance_max: float = 1050.0

var _alive_cap: int
var _spawn_interval: float

var _spawn_timer: Timer
var _scale_timer: Timer
var _interval_timer: Timer

func _ready() -> void:
	_alive_cap = initial_alive_cap
	_spawn_interval = initial_spawn_interval

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = _spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)
	_spawn_timer.start()

	_scale_timer = Timer.new()
	_scale_timer.one_shot = false
	_scale_timer.wait_time = cap_increase_every_sec
	_scale_timer.timeout.connect(_on_scale_tick)
	add_child(_scale_timer)
	_scale_timer.start()

	_interval_timer = Timer.new()
	_interval_timer.one_shot = false
	_interval_timer.wait_time = spawn_interval_decay_every_sec
	_interval_timer.timeout.connect(_on_interval_tick)
	add_child(_interval_timer)
	_interval_timer.start()

func _on_scale_tick() -> void:
	_alive_cap = min(max_alive_cap, _alive_cap + cap_increase_by)

func _on_interval_tick() -> void:
	_spawn_interval = max(min_spawn_interval, _spawn_interval - spawn_interval_decay_by)
	_spawn_timer.wait_time = _spawn_interval

func _on_spawn_tick() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var alive_now := get_tree().get_nodes_in_group("zombies").size()
	if alive_now >= _alive_cap:
		return

	_spawn_one(player)

func _spawn_one(player: Node2D) -> void:
	if zombie_scene == null:
		return

	var tilemap := get_tree().get_first_node_in_group("tilemap") as TileMap
	var navigation_map := RID()
	if tilemap:
		navigation_map = tilemap.get_navigation_map(0)

	var zombie := zombie_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(zombie)

	# Spawn around the player, but clamp to the navigation mesh so zombies never appear outside
	# the playable area/walls.
	var placed := false
	for _i in range(12):
		var angle := randf_range(-PI, PI)
		var dist := randf_range(spawn_distance_min, spawn_distance_max)
		var intended := player.global_position + Vector2.RIGHT.rotated(angle) * dist
		var spawn_pos := intended
		if navigation_map.is_valid():
			spawn_pos = NavigationServer2D.map_get_closest_point(navigation_map, intended)
		# Ensure it stays reasonably far from the player.
		if spawn_pos.distance_to(player.global_position) >= spawn_distance_min * 0.6:
			zombie.global_position = spawn_pos
			placed = true
			break

	if not placed:
		# Fallback: just place at a safe navigation point near the player.
		var fallback := player.global_position + Vector2.RIGHT * spawn_distance_min
		if navigation_map.is_valid():
			fallback = NavigationServer2D.map_get_closest_point(navigation_map, fallback)
		zombie.global_position = fallback
