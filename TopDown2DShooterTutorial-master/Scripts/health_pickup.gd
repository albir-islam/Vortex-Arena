extends Area2D

const HEAL_PERCENT = 0.05
const MIN_HEAL_AMOUNT = 1

func _on_body_entered(body):
	var pickup_player := get_tree().get_first_node_in_group("pickup_player")
	if pickup_player and pickup_player.has_method("play"):
		pickup_player.play()

	if body.has_method("on_health_pickup"):
		var max_hp = 100
		# Prefer the body's health system if present.
		if body.has_node("HealthSystem"):
			var hs = body.get_node_or_null("HealthSystem")
			if hs != null and hs.has_method("get"):
				var bh = hs.get("base_health")
				if bh != null:
					max_hp = int(bh)
		var amount = int(round(float(max_hp) * HEAL_PERCENT))
		amount = maxi(MIN_HEAL_AMOUNT, amount)
		body.on_health_pickup(amount)

	queue_free()
