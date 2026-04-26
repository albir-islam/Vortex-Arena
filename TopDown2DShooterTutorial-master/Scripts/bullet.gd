extends Area2D

class_name Bullet
var speed = 900
var move_direction: Vector2 = Vector2.ZERO
var damage = 25
var shooter_id: String = ""
@onready var multiplayer_network = get_node("/root/MultiplayerNetwork")

func _process(delta):
	global_position += move_direction * delta * speed

func _on_body_entered(body):
	# Local PvE: damage zombies.
	if body is Zombie:
		body.take_damage(damage, shooter_id)
		if body.has_method("hit_effect"):
			body.hit_effect()
		queue_free()
		return

	# Multiplayer PvP: hit players (local/remote)
	if body != null and body.has_method("get_player_id"):
		var hit_player_id = body.get_player_id()
		if hit_player_id != shooter_id:
			# Use new MultiplayerNetwork if in multiplayer mode
			if GameState.is_multiplayer and multiplayer_network:
				multiplayer_network.send_hit_player(hit_player_id, damage)
			# Fallback to old Network for legacy support
			elif Network and Network.has_method("send_hit"):
				Network.send_hit(hit_player_id, damage)
		queue_free()
		return

	# Other PvE hitboxes that aren't Zombie but still have take_damage (e.g., destructibles)
	if body != null and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return
	
	# Visual effect
	if body != null and body.has_method("hit_effect"):
		body.hit_effect()
	
	queue_free()

func _on_area_entered(area):
	# Hit detection for Area2D hitboxes.
	if area is Zombie:
		area.take_damage(damage, shooter_id)
		queue_free()
		return
	if area != null and area.has_method("get_player_id"):
		var hit_player_id = area.get_player_id()
		if hit_player_id != shooter_id:
			if GameState.is_multiplayer and multiplayer_network:
				multiplayer_network.send_hit_player(hit_player_id, damage)
			elif Network and Network.has_method("send_hit"):
				Network.send_hit(hit_player_id, damage)
		queue_free()
		return
	if area != null and area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
		return
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
