extends Node

@export var canvas_modulate_path: NodePath = NodePath("../CanvasModulate")
@export var player_light_path: NodePath = NodePath("../Player/PointLight2D")

func _ready() -> void:
	_apply()

func _apply() -> void:
	# Only affects singleplayer, per spec.
	if GameState == null:
		return
	if GameState.is_multiplayer:
		return

	var is_easy: bool = false
	if GameState.has_method("is_singleplayer_easy"):
		is_easy = GameState.is_singleplayer_easy()

	# Easy: remove visibility limitation (no darkness + no spotlight masking)
	if is_easy:
		var canvas_modulate := get_node_or_null(canvas_modulate_path)
		if canvas_modulate and canvas_modulate is CanvasModulate:
			(canvas_modulate as CanvasModulate).color = Color(1, 1, 1, 1)

		var light := get_node_or_null(player_light_path)
		if light and light is PointLight2D:
			(light as PointLight2D).visible = false
