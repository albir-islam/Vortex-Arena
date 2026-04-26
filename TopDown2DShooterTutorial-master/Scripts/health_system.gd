extends Area2D

class_name HealthSystem

const HEALTH_AMOUNT_RESTORED = 3
const base_health = 100

var current_health: int = base_health

signal damage_taken(current_health)
signal died

func _ready():
	current_health = base_health

func take_damage(damage: int):
	current_health -= damage
	if current_health < 0:
		current_health = 0
	emit_signal("damage_taken", current_health)
	if current_health <= 0:
		emit_signal("died")

func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_health = min(base_health, current_health + amount)
	emit_signal("damage_taken", current_health)

func _on_body_entered(body):
	var pickup_player := get_tree().get_first_node_in_group("pickup_player")
	if pickup_player and pickup_player.has_method("play"):
		pickup_player.play()

	if body.has_method("on_health_pickup"):
		body.on_health_pickup(HEALTH_AMOUNT_RESTORED)

	queue_free()
