extends Node2D

class_name DamagePopup

@export var lifetime_sec: float = 0.8
@export var float_speed: float = 70.0
@export var drift_x: float = 25.0

@onready var label: Label = $Label

var _time := 0.0
var _velocity := Vector2.ZERO

func _ready() -> void:
	_time = 0.0
	_velocity = Vector2(randf_range(-drift_x, drift_x), -float_speed)
	z_index = 100

func set_damage(amount: int) -> void:
	if label:
		label.text = str(amount)
		label.modulate = Color(1.0, 0.35, 0.25, 1.0)

func _process(delta: float) -> void:
	_time += delta
	global_position += _velocity * delta

	var t := 0.0
	if lifetime_sec > 0.001:
		t = clampf(_time / lifetime_sec, 0.0, 1.0)

	if label:
		var c := label.modulate
		c.a = 1.0 - t
		label.modulate = c

	if _time >= lifetime_sec:
		queue_free()
