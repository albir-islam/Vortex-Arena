extends Node
class_name Settings

# --- Defaults ---
var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var brightness := 1.0  # 0.3..1.5 feels okay in 2D

const SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	load_settings()
	apply_all()

# ---------------------------
# Apply
# ---------------------------
func apply_all() -> void:
	apply_audio()
	apply_brightness()
	apply_window()

func apply_window() -> void:
	# Make the window match the current screen usable size (good default on MacBooks).
	# This keeps the game filling the screen area without forcing exclusive fullscreen.
	var window := get_window()
	if window == null:
		return
	var rect := DisplayServer.screen_get_usable_rect(0)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	window.position = rect.position
	window.size = rect.size

func apply_audio() -> void:
	_set_bus_linear("Master", master_volume)
	_set_bus_linear("Music", music_volume)
	_set_bus_linear("SFX", sfx_volume)

func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		# If you didn't create the bus yet, don't crash.
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(linear, 0.0, 1.0)))

func apply_brightness() -> void:
	# Your main.tscn has a CanvasModulate node already.
	var scene := get_tree().current_scene
	if scene == null:
		return

	var cm := scene.find_child("CanvasModulate", true, false)
	if cm and cm is CanvasModulate:
		var b := float(clamp(brightness, 0.3, 1.5))
		cm.color = Color(b, b, b, 1.0)

# ---------------------------
# Save/Load
# ---------------------------
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "brightness", brightness)

	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	brightness = float(cfg.get_value("video", "brightness", brightness))
