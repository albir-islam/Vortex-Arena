extends Node

const THEME_PATH := "/Users/shadhinnandi/Aoop/p3/theme.mp3"
const EFFECTS_PATH := "/Users/shadhinnandi/Aoop/p3/effects.mp3"
const DEATH_PATH := "/Users/shadhinnandi/Aoop/p3/death.mp3"

const _BUTTON_META_KEY := "__mm_click_sfx_connected"

@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer

var _theme_stream: AudioStream
var _effects_stream: AudioStream
var _death_stream: AudioStream
var _pistol_shot_stream: AudioStream
var _pickup_stream: AudioStream
var _reload_stream: AudioStream

var _music_scale := 1.0

func _ready():
	_theme_stream = _load_stream(THEME_PATH)
	_effects_stream = _load_stream(EFFECTS_PATH)
	_death_stream = _load_stream(DEATH_PATH)

	# Load fallback sounds from project
	_pistol_shot_stream = ResourceLoader.load("res://Assets/Sound/pistol-shot.mp3")
	_pickup_stream = ResourceLoader.load("res://Assets/Sound/pickup.mp3")
	_reload_stream = ResourceLoader.load("res://Assets/gunreload.mp3")
	if _reload_stream == null:
		_reload_stream = ResourceLoader.load("res://Assets/reload.mp3")

	if _theme_stream == null:
		var fallback := ResourceLoader.load("res://Assets/music.mp3")
		if fallback and fallback is AudioStream:
			_theme_stream = fallback
	
	# Use project sounds as fallback if custom files not provided
	if _effects_stream == null:
		_effects_stream = _pickup_stream
		print("MusicManager: Using fallback pickup.mp3 for effects")
	
	if _death_stream == null:
		_death_stream = _pickup_stream
		print("MusicManager: Using fallback pickup.mp3 for death sound")

	if _theme_stream:
		music_player.stream = _theme_stream
	music_player.autoplay = false
	# Enable looping
	if music_player.stream and music_player.stream is AudioStreamMP3:
		music_player.stream.loop = true
	play_theme_full()

	var tree := get_tree()
	if tree:
		tree.node_added.connect(_on_node_added)
		_connect_buttons_in_tree(tree.current_scene)

func play_music():
	play_theme_full()

func stop_music():
	music_player.stop()

func play_theme_full():
	_music_scale = 1.0
	_play_theme()

func set_music_half_volume():
	_music_scale = 0.2
	_apply_music_volume()
	if not music_player.playing:
		_play_theme()

func mute_music():
	_music_scale = 0.0
	_apply_music_volume()
	music_player.stop()

func ensure_theme_playing():
	if _music_scale <= 0.0:
		return
	if not music_player.playing:
		_play_theme()

func play_button_click():
	if _effects_stream:
		_play_segment(_effects_stream, 0.25, 1.0, 1.5)

func play_step():
	if _pickup_stream:
		_play_segment(_pickup_stream, 0.0, 0.15, 0.3)

func play_shoot():
	# Use dedicated pistol shot sound
	if _pistol_shot_stream:
		_play_full_sound(_pistol_shot_stream, 0.8)
	elif _effects_stream:
		_play_segment(_effects_stream, 0.05, 0.3, 0.9)

func play_reload():
	# Play reload sound when the player presses R.
	if _reload_stream:
		_play_full_sound(_reload_stream, 1.0)
	elif _effects_stream:
		_play_segment(_effects_stream, 0.05, 0.25, 0.9)

func play_kill():
	if _pickup_stream:
		_play_segment(_pickup_stream, 0.0, 0.3, 0.7)

func play_death():
	# Play full death sound at maximum volume
	if _death_stream:
		_play_full_sound(_death_stream, 3.5)
	elif _pickup_stream:
		_play_segment(_pickup_stream, 0.0, 0.4, 0.9)

func _play_theme():
	if _theme_stream:
		music_player.stream = _theme_stream
	_apply_music_volume()
	if _music_scale > 0.0:
		music_player.play()

func _apply_music_volume():
	if _music_scale <= 0.0:
		music_player.volume_db = -80.0
		return
	music_player.volume_db = linear_to_db(clamp(_music_scale * 0.6, 0.0, 1.0))

func _play_segment(stream: AudioStream, start_pos: float, length: float, volume: float = 1.0) -> void:
	if stream == null or length <= 0.0:
		print("MusicManager: Cannot play segment - stream is null or length invalid")
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
	var parent_node: Node = self
	var sfx_root := get_node_or_null("SFX")
	if sfx_root:
		parent_node = sfx_root
	parent_node.add_child(player)
	player.play(max(0.0, start_pos))
	var timer := get_tree().create_timer(length)
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	)

func _play_full_sound(stream: AudioStream, volume: float = 1.0) -> void:
	if stream == null:
		print("MusicManager: Cannot play sound - stream is null")
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = linear_to_db(clamp(volume, 0.01, 5.0))
	var parent_node: Node = self
	var sfx_root := get_node_or_null("SFX")
	if sfx_root:
		parent_node = sfx_root
	parent_node.add_child(player)
	player.finished.connect(func():
		if is_instance_valid(player):
			player.queue_free()
	)
	player.play()

func _load_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		push_warning("Audio file not found: %s" % path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("Audio file empty: %s" % path)
		return null
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	return stream

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)

func _connect_buttons_in_tree(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		_connect_button(root)
	for child in root.get_children():
		_connect_buttons_in_tree(child)

func _connect_button(button: BaseButton) -> void:
	if button.has_meta(_BUTTON_META_KEY):
		return
	button.pressed.connect(_on_button_pressed.bind(button))
	button.set_meta(_BUTTON_META_KEY, true)

func _on_button_pressed(_button: BaseButton) -> void:
	play_button_click()
