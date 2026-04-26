extends State

@onready var sprite_2d = $"../../Sprite2D"
@onready var sounds = $"../../Sounds"
@onready var attack_area = $"../../AttackArea" as Area2D
@onready var attack_poly = $"../../AttackArea/CollisionPolygon2D" as CollisionPolygon2D


var attack_speed
var attack_damage
var time_elapsed: float = 0
var time_between_attacks

var _no_contact_elapsed: float = 0.0
const NO_CONTACT_GRACE_SEC := 0.15

var _melee_range_sq: float = -1.0

func _get_melee_range_sq() -> float:
	if _melee_range_sq >= 0.0:
		return _melee_range_sq
	# Derive a range from the AttackArea polygon, then tighten it.
	var max_sq := 0.0
	if attack_poly != null:
		for p in attack_poly.polygon:
			max_sq = max(max_sq, p.length_squared())
	# Fallback if polygon missing.
	if max_sq <= 0.0:
		max_sq = 45.0 * 45.0
	# Tighten melee distance so health only drops when "absolutely close".
	# (The raw polygon can be a bit forgiving due to movement/interpolation.)
	_melee_range_sq = max_sq * 0.75
	return _melee_range_sq

func _zombie() -> Zombie:
	return state_machine.get_parent() as Zombie

func _ready():
	var zombie := _zombie()
	if zombie == null:
		return
	attack_damage = zombie.attack_damage
	# Treat attack_speed as a 0..1 "faster" scalar.
	# 0.1 -> ~0.93s between hits, 1.0 -> 0.25s between hits.
	var t: float = clampf(float(zombie.attack_speed), 0.0, 1.0)
	time_between_attacks = lerpf(1.0, 0.25, t)

func enter(_msg = {}):
	time_elapsed = 0
	_no_contact_elapsed = 0
	var overlapping_players: Array = _get_overlapping_living_players_in_melee_range()
	if not overlapping_players.is_empty():
		attack(overlapping_players)

func physics_update(delta):
	# Only attack while a living player is overlapping the AttackArea AND truly close.
	# Uses a short grace window to avoid flicker between Attack/Chase from physics jitter.
	var overlapping_players: Array = _get_overlapping_living_players_in_melee_range()
	if overlapping_players.is_empty():
		_no_contact_elapsed += delta
		if _no_contact_elapsed >= NO_CONTACT_GRACE_SEC:
			state_machine.transition_to("Chase")
		return
	_no_contact_elapsed = 0.0

	time_elapsed += delta
	if time_elapsed >= time_between_attacks:
		attack(overlapping_players)
		time_elapsed = 0


func _get_overlapping_living_players_in_melee_range() -> Array:
	var overlapping_players: Array = []
	if attack_area == null:
		return overlapping_players
	for b in attack_area.get_overlapping_bodies():
		if b == null or not (b is Node):
			continue
		var n := b as Node
		if not n.is_in_group("players"):
			continue
		if n.has_method("is_dead") and bool(n.call("is_dead")):
			continue
		overlapping_players.append(n)
	return overlapping_players


func attack(overlapping_players: Array):
	var target := _get_attack_target(overlapping_players)
	if target and target.has_method("take_damage"):
		target.take_damage(int(attack_damage))
		
		var random_stream_player = sounds.get_children().pick_random()
		random_stream_player.play()
		
		var attack_tween = get_tree().create_tween()
		attack_tween.tween_property(sprite_2d, "modulate", Color(1, 0, 0, 1), .3)
		attack_tween.chain().tween_property(sprite_2d, "modulate", Color.WHITE, .3)

func exit():
	time_elapsed = 0


func _on_attack_area_body_exited(body):
	# Don't instantly exit Attack on body_exited; physics_update handles exit with a grace period.
	pass

func _get_attack_target(overlapping_players: Array) -> Node2D:
	var zombie := _zombie()
	if zombie == null:
		return null
	# Prefer a player that's actually in the attack area right now.
	for p in overlapping_players:
		if p is Node2D:
			return p as Node2D
	# Prefer the chase target if still valid.
	if zombie.navigation_target != null and zombie.navigation_target is Node2D:
		var nt := zombie.navigation_target as Node2D
		if nt.is_in_group("players") and (not nt.has_method("is_dead") or not bool(nt.call("is_dead"))):
			return nt
	# Fallback: nearest player.
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
