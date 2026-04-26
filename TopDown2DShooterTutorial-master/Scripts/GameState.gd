extends Node
# Global singleton to store player profile data across scenes

signal health_changed(new_health)
signal stats_changed(stats)
signal inventory_changed(inventory)
signal player_died()
signal wallet_changed(coins, gems)
signal elo_changed(elo, tier)
signal achievements_updated(achievements)
signal cosmetics_updated(cosmetics)

# Player Profile
var user_id: int = 0
var username: String = ""
var current_dress: String = "Default"

# Stats
var total_kills: int = 0
var high_score: int = 0
var current_health: int = 100
var max_health: int = 100

# Economy
var coins: int = 0
var gems: int = 0

# ELO / Ranking
var elo_rating: int = 1000
var elo_tier: String = "BRONZE"
var matches_won: int = 0
var matches_played: int = 0

# Achievements cache
var achievements: Array = []  # Array of { name, description, unlocked, rewardCoins, rewardGems, ... }

# Cosmetics cache
var cosmetics: Array = []  # Array of { id, name, type, price, owned, equipped, assetPath }

# Match History cache
var match_history: Array = []  # Array of { matchId, kills, deaths, damage, result, ... }

# Season info
var current_season_id: int = 0
var current_season_name: String = ""

# Inventory
var primary_weapon: String = "AKM"
var secondary_weapon: String = "UZI"
var current_weapon: String = "AKM"
var first_aid_count: int = 1
var medkit_count: int = 0
var boost_count: int = 1
var helmet_level: int = 1
var vest_level: int = 1

# Multiplayer State
var is_multiplayer: bool = false
var match_duration: int = 300
var multiplayer_players: Array = [] # Players received from match start

# Singleplayer difficulty
enum Difficulty { EASY, HARD }
var singleplayer_difficulty: int = Difficulty.HARD

func set_singleplayer_difficulty(diff: int) -> void:
	singleplayer_difficulty = diff

func is_singleplayer_easy() -> bool:
	return (not is_multiplayer) and singleplayer_difficulty == Difficulty.EASY

# Multiplayer Scores (for current session)
var mp_score: int = 0
var mp_player_kills: int = 0
var mp_zombie_kills: int = 0

# Weapon Data (matching backend expectations)
var weapon_stats = {
	"AKM": {"damage": 25, "fireRate": 0.1, "magSize": 30, "reloadTime": 2.5},
	"UZI": {"damage": 15, "fireRate": 0.08, "magSize": 25, "reloadTime": 1.8},
	"M16A4": {"damage": 22, "fireRate": 0.09, "magSize": 30, "reloadTime": 2.3},
	"SCAR-L": {"damage": 24, "fireRate": 0.1, "magSize": 30, "reloadTime": 2.4},
	"Groza": {"damage": 28, "fireRate": 0.08, "magSize": 30, "reloadTime": 2.2}
}

# =========================
# INITIALIZATION
# =========================
func set_player_profile(data: Dictionary):
	user_id = data.get("userId", 0)
	username = data.get("username", "")
	current_dress = data.get("currentDress", "Default")
	
	# Stats
	var stats = data.get("stats", {})
	total_kills = stats.get("totalKills", 0)
	high_score = stats.get("highScore", 0)
	current_health = stats.get("health", 100)
	
	# Inventory
	var inventory = data.get("inventory", {})
	primary_weapon = inventory.get("primaryWeapon", "AKM")
	secondary_weapon = inventory.get("secondaryWeapon", "UZI")
	first_aid_count = inventory.get("firstAidCount", 1)
	medkit_count = inventory.get("medkitCount", 0)
	boost_count = inventory.get("boostCount", 1)
	helmet_level = inventory.get("helmetLevel", 1)
	vest_level = inventory.get("vestLevel", 1)
	
	current_weapon = primary_weapon
	
	print("GameState initialized for:", username, "HP:", current_health)
	emit_signal("stats_changed", stats)
	emit_signal("inventory_changed", inventory)

# =========================
# HEALTH MANAGEMENT
# =========================
func take_damage(damage: int):
	# Apply armor reduction
	var armor_reduction = (helmet_level + vest_level) * 0.05  # 5% per level
	var actual_damage = int(damage * (1.0 - armor_reduction))
	
	current_health = max(0, current_health - actual_damage)
	emit_signal("health_changed", current_health)
	
	print("Took", actual_damage, "damage. Health:", current_health)
	
	if current_health <= 0:
		_handle_death()
	else:
		# Sync health with backend
		_sync_stats()

func heal(amount: int):
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if current_health > old_health:
		emit_signal("health_changed", current_health)
		print("Healed", current_health - old_health, "HP. Health:", current_health)
		_sync_stats()

func use_healing_item(item_type: String):
	var heal_amount = 0
	
	match item_type:
		"first_aid":
			if first_aid_count > 0:
				first_aid_count -= 1
				heal_amount = 30
		"medkit":
			if medkit_count > 0:
				medkit_count -= 1
				heal_amount = 50
		"boost":
			if boost_count > 0:
				boost_count -= 1
				heal_amount = 10
	
	if heal_amount > 0:
		# Call backend to validate healing
		APIService.use_healing(user_id, heal_amount, func(success, data):
			if success:
				var new_health = data.get("stats", {}).get("health", current_health)
				current_health = new_health
				emit_signal("health_changed", current_health)
				emit_signal("inventory_changed", get_inventory_dict())
		)

func _handle_death():
	print("Player died!")
	emit_signal("player_died")
	# Could sync final stats with backend here

# =========================
# STATS MANAGEMENT
# =========================
func add_kill():
	total_kills += 1
	
	# Report kill to backend
	APIService.handle_kill(user_id, func(success, data):
		if success:
			var stats = data.get("stats", {})
			total_kills = stats.get("totalKills", total_kills)
			high_score = stats.get("highScore", high_score)
			emit_signal("stats_changed", stats)
			print("Kill confirmed! Total kills:", total_kills)
	)

func add_score(points: int):
	high_score += points
	_sync_stats()

func _sync_stats():
	APIService.update_stats(user_id, total_kills, high_score, current_health, func(success, data):
		if success:
			print("Stats synced with backend")
	)

# =========================
# INVENTORY MANAGEMENT
# =========================
func get_current_weapon_stats() -> Dictionary:
	return weapon_stats.get(current_weapon, weapon_stats["AKM"])

func swap_weapon():
	if current_weapon == primary_weapon:
		current_weapon = secondary_weapon
	else:
		current_weapon = primary_weapon
	
	print("Switched to:", current_weapon)
	emit_signal("inventory_changed", get_inventory_dict())

func get_inventory_dict() -> Dictionary:
	return {
		"primaryWeapon": primary_weapon,
		"secondaryWeapon": secondary_weapon,
		"firstAidCount": first_aid_count,
		"medkitCount": medkit_count,
		"boostCount": boost_count,
		"helmetLevel": helmet_level,
		"vestLevel": vest_level
	}

func sync_inventory():
	var inventory_data = get_inventory_dict()
	APIService.sync_inventory(user_id, inventory_data, func(success, data):
		if success:
			print("Inventory synced with backend")
	)

# =========================
# UTILITY
# =========================
func reset():
	user_id = 0
	username = ""
	total_kills = 0
	high_score = 0
	current_health = 100
	first_aid_count = 1
	medkit_count = 0
	boost_count = 1
	helmet_level = 1
	vest_level = 1
	coins = 0
	gems = 0
	elo_rating = 1000
	elo_tier = "BRONZE"
	matches_won = 0
	matches_played = 0
	achievements = []
	cosmetics = []
	match_history = []
	current_season_id = 0
	current_season_name = ""

func reset_multiplayer_session():
	is_multiplayer = false
	match_duration = 300
	multiplayer_players.clear()
	mp_score = 0
	mp_player_kills = 0
	mp_zombie_kills = 0

func add_mp_zombie_kill():
	mp_zombie_kills += 1
	mp_score += 100

func add_mp_player_kill():
	mp_player_kills += 1
	mp_score += 200  # 2x points for player kill

# =========================
# ECONOMY
# =========================
func load_wallet():
	if user_id == 0:
		return
	APIService.get_wallet(user_id, func(success, data):
		if success:
			coins = data.get("coins", 0)
			gems = data.get("gems", 0)
			emit_signal("wallet_changed", coins, gems)
	)

func spend_coins(amount: int, callback: Callable = Callable()):
	APIService.spend_coins(user_id, amount, func(success, data):
		if success:
			coins = data.get("coins", coins)
			gems = data.get("gems", gems)
			emit_signal("wallet_changed", coins, gems)
		if callback.is_valid():
			callback.call(success, data)
	)

func spend_gems(amount: int, callback: Callable = Callable()):
	APIService.spend_gems(user_id, amount, func(success, data):
		if success:
			coins = data.get("coins", coins)
			gems = data.get("gems", gems)
			emit_signal("wallet_changed", coins, gems)
		if callback.is_valid():
			callback.call(success, data)
	)

# =========================
# ELO / RANKING
# =========================
func load_elo():
	if user_id == 0:
		return
	APIService.get_elo(user_id, func(success, data):
		if success:
			elo_rating = data.get("eloRating", 1000)
			elo_tier = data.get("tier", "BRONZE")
			matches_won = data.get("matchesWon", 0)
			matches_played = data.get("matchesPlayed", 0)
			emit_signal("elo_changed", elo_rating, elo_tier)
	)

# =========================
# ACHIEVEMENTS
# =========================
func load_achievements():
	if user_id == 0:
		return
	APIService.get_achievements(user_id, func(success, data):
		if success and data is Array:
			achievements = data
			emit_signal("achievements_updated", achievements)
	)

# =========================
# COSMETICS
# =========================
func load_cosmetics():
	if user_id == 0:
		return
	APIService.get_cosmetics(user_id, func(success, data):
		if success and data is Array:
			cosmetics = data
			emit_signal("cosmetics_updated", cosmetics)
	)

func unlock_cosmetic(cosmetic_id: int, callback: Callable = Callable()):
	APIService.unlock_cosmetic(user_id, cosmetic_id, func(success, data):
		if success:
			load_cosmetics()  # Refresh cosmetics list
			load_wallet()     # Refresh wallet after purchase
		if callback.is_valid():
			callback.call(success, data)
	)

func equip_cosmetic(cosmetic_id: int, callback: Callable = Callable()):
	APIService.equip_cosmetic(user_id, cosmetic_id, func(success, data):
		if success:
			load_cosmetics()
		if callback.is_valid():
			callback.call(success, data)
	)

func unequip_cosmetic(cosmetic_id: int, callback: Callable = Callable()):
	APIService.unequip_cosmetic(user_id, cosmetic_id, func(success, data):
		if success:
			load_cosmetics()
		if callback.is_valid():
			callback.call(success, data)
	)

# =========================
# MATCH HISTORY
# =========================
func load_match_history():
	if user_id == 0:
		return
	APIService.get_match_history(user_id, func(success, data):
		if success and data is Array:
			match_history = data
	)

# =========================
# LOAD ALL PROFILE DATA
# =========================
func load_all_profile_data():
	"""Call after login to fetch all backend data for profile panels."""
	load_wallet()
	load_elo()
	load_achievements()
	load_cosmetics()
	load_match_history()
	APIService.get_current_season(func(success, data):
		if success:
			current_season_id = data.get("id", 0)
			current_season_name = data.get("name", "")
	)
