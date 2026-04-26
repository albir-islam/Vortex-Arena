extends Camera2D

@export var target_node: Node2D
@export var zoom_level: float = 1.5
@export var vertical_offset: float = 150  # Offset for isometric tilt
@export var follow_smoothing: float = 5.0

func _ready():
	if not target_node:
		target_node = get_tree().current_scene.find_child("Player", true, false)
	
	if target_node:
		global_position = target_node.global_position
	
	zoom = Vector2(zoom_level, zoom_level)
	ignore_rotation = false

func _process(delta):
	if not target_node:
		return
	
	# Smooth follow with offset for isometric tilt
	var target_pos = target_node.global_position
	target_pos.y -= vertical_offset  # Tilt camera up to show more of the "distant" area
	
	global_position = global_position.lerp(target_pos, follow_smoothing * delta)
