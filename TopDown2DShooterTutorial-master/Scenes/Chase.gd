extends State

@onready var navigation_agent_2d = $"../../NavigationAgent2D" as NavigationAgent2D
@onready var sprite_2d = $"../../Sprite2D" as Sprite2D
@onready var random_target_chase_update_timer = $RandomTargetChaseUpdateTimer as RandomTimer
@onready var sounds = $"../../Sounds"
@onready var attack_area = $"../../AttackArea" as Area2D

var texture_chase = preload("res://Assets/zombie_walking.png")
var texture_default = preload("res://Assets/zombie_standing.png")

func _zombie() -> Zombie:
	return state_machine.get_parent() as Zombie

func enter(_msg = {}) -> void:
	var zombie := _zombie()
	if zombie == null or zombie.is_queued_for_deletion():
		return
		
	var random_stream_player = sounds.get_children().pick_random()
	random_stream_player.play()
		
	sprite_2d.texture = texture_chase
	zombie.current_speed = zombie.chasing_speed
	start_chasing()
	
func physics_update(_delta: float):
	var zombie := _zombie()
	if zombie == null:
		return
	# Some overlaps can exist *before* body_entered fires (e.g., spawn close, fast movement, jitter).
	# Proactively switch to Attack when a living player is already overlapping the AttackArea.
	if attack_area != null:
		for b in attack_area.get_overlapping_bodies():
			if b == null or not (b is Node):
				continue
			var n := b as Node
			if not n.is_in_group("players"):
				continue
			if n.has_method("is_dead") and bool(n.call("is_dead")):
				continue
			state_machine.transition_to("Attack")
			return
	var player := _get_nearest_player()
	if player == null:
		state_machine.transition_to("Idle")
		return
	# Keep chasing across the whole map once the player is seen.
	set_next_chasing_target_point()
	
	var next_position = navigation_agent_2d.get_next_path_position()
	zombie.move_to_position(next_position)

func exit():
	var zombie := _zombie()
	random_target_chase_update_timer.stop()
	sprite_2d.texture = texture_default
	if zombie != null:
		zombie.current_speed = zombie.wandering_speed

func _on_random_target_chase_update_timer_timeout():
	start_chasing()

func start_chasing():
	set_next_chasing_target_point()
	random_target_chase_update_timer.setup()

func set_next_chasing_target_point():
	var zombie := _zombie()
	if zombie == null:
		return
	var player := _get_nearest_player()
	if player == null:
		return
	zombie.navigation_target = player
	var player_position = player.global_position
	var navigation_point = NavigationServer2D.map_get_closest_point(navigation_agent_2d.get_navigation_map(), player_position)
	navigation_agent_2d.target_position = navigation_point

func _get_nearest_player() -> Node2D:
	var zombie := _zombie()
	if zombie == null:
		return null
	var players := get_tree().get_nodes_in_group("players")
	var best: Node2D = null
	var best_dist := INF
	for p in players:
		if p is Node2D:
			if (p as Node2D).has_method("is_dead") and bool((p as Node2D).call("is_dead")):
				continue
			var d := zombie.global_position.distance_squared_to((p as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best = p
	return best


func _on_attack_area_body_entered(body):
	if body == null or not (body is Node):
		return
	var n := body as Node
	if not n.is_in_group("players"):
		return
	if n.has_method("is_dead") and bool(n.call("is_dead")):
		return
	state_machine.transition_to("Attack")
