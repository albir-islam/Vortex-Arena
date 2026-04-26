extends CharacterBody2D

class_name Zombie

var ammo_pickup_scene = preload("res://Scenes/ammo_pickup.tscn")
var health_pickup_scene = preload("res://Scenes/health_pickup.tscn")
var damage_popup_scene = preload("res://Scenes/damage_popup.tscn")


@onready var navigation_agent_2d = $NavigationAgent2D
@onready var vision_ray_cast_2d = $VisionRayCast2D as RayCast2D
@onready var state_machine = $StateMachine as StateMachine
@onready var health_system = $HealthSystem as HealthSystem
@onready var multiplayer_network = get_node("/root/MultiplayerNetwork")


@export_group("Locomotion")
@export var rotation_speed: float = 2
@export var wandering_speed = 150
@export var navigation_target: Node2D
@export var chasing_speed = 200

@export_group("Scanning for player")
@export var angle_cone_of_vision: float = 90
@export var max_vision_distance: float = 250
@export var angle_between_rays: float = 30

@export_group("Attack")
@export_range(0.1, 1) var attack_speed: float = 1
@export_range(1, 10) var attack_damage: float = 3

@export_group("Pickups")
@export var chance_to_drop_pickup = .6
@export var ammo_to_health_pickup_ratio = .75

var current_speed

var has_seen_player: bool = false

var last_hit_by_player_id: String = ""

func _ready():
	add_to_group("zombies")
	# Raycast must be able to see players (layer 2). If this mask is wrong,
	# zombies will never enter Chase.
	if vision_ray_cast_2d:
		vision_ray_cast_2d.collide_with_bodies = true
		vision_ray_cast_2d.collision_mask = 2

	var navigation_map = get_tree().get_first_node_in_group("tilemap").get_navigation_map(0)
	NavigationServer2D.agent_set_map(navigation_agent_2d.get_rid(), navigation_map)
	navigation_agent_2d.set_navigation_map(navigation_map)
	current_speed = wandering_speed
	
	health_system.died.connect(on_died)
	
func _process(_delta):
	search_for_player_with_raycast()

func _is_living_player(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method("is_dead"):
		return not bool(node.call("is_dead"))
	# If no explicit API exists, assume it's a valid target.
	return true

func _get_nearest_living_player(max_distance: float = INF) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	var max_dist_sq := max_distance * max_distance
	for p in get_tree().get_nodes_in_group("players"):
		if not (p is Node2D):
			continue
		if not _is_living_player(p as Node):
			continue
		var d := global_position.distance_squared_to((p as Node2D).global_position)
		if d < best_dist and d <= max_dist_sq:
			best_dist = d
			best = p as Node2D
	return best

func move_to_position(target_position: Vector2):
	var motion = position.direction_to(target_position) * current_speed
	navigation_agent_2d.set_velocity(motion)
	look_at(target_position)
	velocity = motion
	move_and_slide()

func search_for_player_with_raycast():
	# If we have previously seen a player, keep chasing as long as *any* living player exists.
	if has_seen_player:
		var any_player := _get_nearest_living_player()
		if any_player == null:
			has_seen_player = false
			navigation_target = null
			return
		if state_machine.state_name != "Chase" and state_machine.state_name != "Attack":
			state_machine.transition_to("Chase")
			return
	if state_machine.state_name != "Idle" and state_machine.state_name != "Wandering":
		return

	# Reliable detection: if a living player is close enough, chase even if the zombie isn't facing them.
	var nearest := _get_nearest_living_player(max_vision_distance)
	if nearest != null:
		has_seen_player = true
		navigation_target = nearest
		state_machine.transition_to("Chase")
		return
		
	var cast_count = int(angle_cone_of_vision / angle_between_rays) + 1
	
	for index in range(cast_count):
		var cast_vector = max_vision_distance * Vector2.UP.rotated(deg_to_rad(angle_between_rays) * (index - (cast_count - 1) / 2.0))
		vision_ray_cast_2d.target_position = cast_vector
		vision_ray_cast_2d.force_raycast_update()
		
		if vision_ray_cast_2d.is_colliding():
			var collider := vision_ray_cast_2d.get_collider()
			if collider != null and collider is Node and (collider as Node).is_in_group("players") and _is_living_player(collider as Node):
				has_seen_player = true
				if collider is Node2D:
					navigation_target = collider
				state_machine.transition_to("Chase")

func take_damage(damage: int, attacker_id: String = ""):
	if attacker_id != "":
		last_hit_by_player_id = str(attacker_id)
	_show_damage_popup(damage)
	health_system.take_damage(damage)

func _show_damage_popup(damage: int) -> void:
	if damage_popup_scene == null:
		return
	var popup := damage_popup_scene.instantiate()
	get_tree().current_scene.add_child(popup)
	if popup is Node2D:
		(popup as Node2D).global_position = global_position + Vector2(0, -30)
	if popup.has_method("set_damage"):
		popup.set_damage(damage)

func on_died():
	var player := get_tree().get_first_node_in_group("player")

	# Singleplayer: always award local kill.
	if not GameState.is_multiplayer:
		if player and player.has_method("add_kill"):
			player.add_kill()
		try_to_drop_pickup.call_deferred()
		queue_free()
		return

	# Multiplayer: only the shooter reports the kill to prevent double counting.
	var local_id := str(multiplayer_network.my_player_id) if multiplayer_network else ""
	if local_id != "" and last_hit_by_player_id == local_id:
		if player and player.has_method("add_kill"):
			player.add_kill()
		GameState.add_mp_zombie_kill()
		if multiplayer_network:
			multiplayer_network.send_zombie_kill()

	try_to_drop_pickup.call_deferred()
	queue_free()

func try_to_drop_pickup():
	var current_pickup_drop_chance = randf()
	if current_pickup_drop_chance > chance_to_drop_pickup:
		if randf() < ammo_to_health_pickup_ratio:
			var ammo_pickup = ammo_pickup_scene.instantiate()
			get_tree().current_scene.add_child(ammo_pickup)
			ammo_pickup.global_position = global_position
		else:
			var health_pickup = health_pickup_scene.instantiate()
			get_tree().current_scene.add_child(health_pickup)
			health_pickup.global_position = global_position
