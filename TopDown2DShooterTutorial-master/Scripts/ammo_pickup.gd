extends Area2D

func _on_body_entered(body):
	var pickup_player := get_tree().get_first_node_in_group("pickup_player")
	if pickup_player and pickup_player.has_method("play"):
		pickup_player.play()

	if body.has_method("on_ammo_pickup"):
		body.on_ammo_pickup()

	queue_free()
