extends Area2D

@onready var random_timer = $RandomTimer as RandomTimer

var player

func _process(_delta):
	if !random_timer.is_stopped():
		player.update_extract_timer(random_timer.time_left)

func _on_body_entered(body):
	var p := body as Player
	if p and p.has_key:
		player = p
		random_timer.setup()

func _on_body_exited(body):
	random_timer.stop()
	var p := body as Player
	if p:
		p.hide_extract_countdown()
	player = null


func _on_random_timer_timeout():
	random_timer.stop()
	player.extract()
