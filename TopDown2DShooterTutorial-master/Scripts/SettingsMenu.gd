extends Control

@onready var main_menu = $Panel/MainMenu
@onready var audio_menu = $Panel/AudioMenu
@onready var video_menu = $Panel/VideoMenu
@onready var control_menu = $Panel/ControlMenu

# Audio Sliders
@onready var master_slider = $Panel/AudioMenu/MasterSlider
@onready var music_slider = $Panel/AudioMenu/MusicSlider
@onready var sfx_slider = $Panel/AudioMenu/SFXSlider

# Video Sliders
@onready var brightness_slider = $Panel/VideoMenu/VBoxContainer2/BrightnessSlider

# Control List Container
@onready var keybind_list_container = $Panel/ControlMenu/ScrollContainer/VBoxContainer

func _ready():
	# Connect Main Menu Buttons
	$Panel/MainMenu/Resume.pressed.connect(_on_resume_pressed)
	$Panel/MainMenu/Audio.pressed.connect(_on_audio_pressed)
	$Panel/MainMenu/Video.pressed.connect(_on_video_pressed)
	$Panel/MainMenu/Controls.pressed.connect(_on_controls_pressed)
	$Panel/MainMenu/Exit.pressed.connect(_on_exit_pressed)

	# Connect Back Buttons
	$Panel/AudioMenu/Button.pressed.connect(_on_back_pressed)
	$Panel/VideoMenu/Button.pressed.connect(_on_back_pressed)
	$Panel/VideoMenu/Button.pressed.connect(_on_back_pressed)
	$Panel/ControlMenu/Button.pressed.connect(_on_back_pressed)
	
	# Connect Sliders
	if master_slider:
		master_slider.value = SettingsManager.master_volume
		master_slider.value_changed.connect(_on_master_val_changed)
	
	if music_slider:
		music_slider.value = SettingsManager.music_volume
		music_slider.value_changed.connect(_on_music_val_changed)
		
	if sfx_slider:
		sfx_slider.value = SettingsManager.sfx_volume
		sfx_slider.value_changed.connect(_on_sfx_val_changed)
		
	if brightness_slider:
		brightness_slider.value = SettingsManager.brightness
		brightness_slider.value_changed.connect(_on_brightness_val_changed)

	# Populate Keybinds
	_populate_keybinds()
	
	# Initial State
	_show_panel(main_menu)

func show_menu():
	show()
	get_tree().paused = true
	_show_panel(main_menu)

func hide_menu():
	hide()
	get_tree().paused = false

func _show_panel(panel_to_show):
	main_menu.visible = false
	audio_menu.visible = false
	video_menu.visible = false
	control_menu.visible = false
	
	panel_to_show.visible = true

func _on_resume_pressed():
	hide_menu()

func _on_audio_pressed():
	_show_panel(audio_menu)

func _on_video_pressed():
	_show_panel(video_menu)

func _on_controls_pressed():
	_show_panel(control_menu)

func _on_back_pressed():
	_show_panel(main_menu)
	# Save settings when going back
	SettingsManager.save_settings()

func _on_exit_pressed():
	get_tree().quit()

func _on_master_val_changed(value):
	SettingsManager.master_volume = value
	SettingsManager.apply_audio()

func _on_music_val_changed(value):
	SettingsManager.music_volume = value
	SettingsManager.apply_audio()

func _on_sfx_val_changed(value):
	SettingsManager.sfx_volume = value
	SettingsManager.apply_audio()

func _on_brightness_val_changed(value):
	SettingsManager.brightness = value
	SettingsManager.apply_brightness()

func _populate_keybinds():
	# Clear existing if any (except the back button which is outside the container we'll use)
	for child in keybind_list_container.get_children():
		child.queue_free()
		
	var actions = InputMap.get_actions()
	for action in actions:
		if action.begins_with("ui_"): continue # Skip internal UI actions
		
		var label = Label.new()
		label.text = action.capitalize() + ": "
		
		var events = InputMap.action_get_events(action)
		var event_text = ""
		if events.size() > 0:
			var event = events[0]
			if event is InputEventKey:
				event_text = OS.get_keycode_string(event.physical_keycode)
			elif event is InputEventMouseButton:
				event_text = "Mouse Button " + str(event.button_index)
		
		label.text += event_text
		keybind_list_container.add_child(label)
