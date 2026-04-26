extends Control

@onready var username_input = %UsernameInput
@onready var password_input = %PasswordInput
@onready var login_button = %LoginButton
@onready var create_account_button = %CreateAccountButton
@onready var status_label = %StatusLabel

func _ready():
	login_button.pressed.connect(_on_login_pressed)
	create_account_button.pressed.connect(_on_create_account_pressed)
	Network.login_completed.connect(_on_login_success)
	Network.login_failed.connect(_on_login_failed)
	_apply_bold_fonts()

func _apply_bold_fonts() -> void:
	# Use a bold-ish system font without bundling external font files.
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "Sans Serif"])
	font.font_weight = 800

	for ctrl in [username_input, password_input, login_button, create_account_button, status_label]:
		if ctrl:
			ctrl.add_theme_font_override("font", font)

func _on_login_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		_set_status("Please enter username and password")
		return
		
	_set_status("Logging in...")
	login_button.disabled = true
	create_account_button.disabled = true
	Network.login(username, password)

func _on_create_account_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		_set_status("Please enter username and password")
		return

	_set_status("Creating account...")
	login_button.disabled = true
	create_account_button.disabled = true
	APIService.register(username, password, func(success, data):
		if success:
			# Mirror login success behavior.
			Network.my_username = data.get("username", username)
			Network.my_id = str(data.get("userId", ""))
			Network.auth_token = username
			GameState.set_player_profile(data)
			_on_login_success(data)
		else:
			_on_login_failed(data)
	)

func _on_login_success(profile_data):
	print("Login Success! Username:", profile_data["username"])
	print("Health:", profile_data["stats"]["health"])
	print("Weapons:", profile_data["inventory"]["primaryWeapon"], "/", profile_data["inventory"]["secondaryWeapon"])
	_set_status("")
	
	# Load all backend data (economy, ELO, achievements, cosmetics, match history)
	GameState.load_all_profile_data()
	
	# Wait a moment for match join
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")

func _on_login_failed(error_msg):
	print("Login Error:", error_msg)
	login_button.disabled = false
	create_account_button.disabled = false
	_set_status(str(error_msg))

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
