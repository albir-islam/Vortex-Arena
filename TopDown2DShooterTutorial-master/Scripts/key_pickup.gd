extends Area2D

func _on_body_entered(body):
	get_tree().get_first_node_in_group("pickup_player").play()
	var p := body as Player
	if p:
		p.on_key_pickup()
	queue_free()
