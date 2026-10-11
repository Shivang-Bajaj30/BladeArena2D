extends Node

# Global game state & persistent profile data
const SAVE_PATH = "user://game_settings.cfg"

var selected_character: String = "blade_master" # "blade_master" or "shadow_fighter"
var selected_background: String = "cyberpunk" # "cyberpunk", "blood_sunset", "mystic_forest", "abyssal_void", "classic_dojo"

var music_volume: float = 0.85
var sfx_volume: float = 0.90
var is_music_enabled: bool = true
var is_sfx_enabled: bool = true
var bloom_enabled: bool = true
var particles_enabled: bool = true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func get_character_data(char_id: String) -> Dictionary:
	match char_id:
		"blade_master":
			return {
				"id": "blade_master",
				"name": "KAGE • BLADE MASTER",
				"role": "SWORD VANGUARD",
				"description": "Lethal blade warrior executing lightning-fast iaido slashes and devastating aerial descent strikes.",
				"weapon": "Dual Katana & Murasame",
				"difficulty": "Moderate",
				"frames_path": "res://fig_1.tres",
				"preview_texture": "res://Stick Figure Character Sprites 2D/Sword sprites/sword_Idle_0001.png",
				"stats": {
					"Damage": 92,
					"Speed": 85,
					"Range": 78,
					"Defense": 74
				}
			}
		"shadow_fighter":
			return {
				"id": "shadow_fighter",
				"name": "RAIJIN • SHADOW BRAWLER",
				"role": "MARTIAL STRIKER",
				"description": "A relentless close-combat powerhouse with rapid-fire bone-breaking combo flurries and hyper evasion.",
				"weapon": "Shadow Gauntlets & Chi",
				"difficulty": "Easy",
				"frames_path": "res://stick_fig.tres",
				"preview_texture": "res://Stick Figure Character Sprites 2D/Fighter sprites/fighter_Idle_0001.png",
				"stats": {
					"Damage": 86,
					"Speed": 96,
					"Range": 55,
					"Defense": 88
				}
			}
	return get_character_data("blade_master")

func get_background_data(bg_id: String) -> Dictionary:
	match bg_id:
		"cyberpunk":
			return {
				"id": "cyberpunk",
				"name": "NEO-TOKYO 2099",
				"tag": "CYBERPUNK NEON",
				"description": "Rain-slicked skyscrapers drenched in vibrant cyan and magenta holographic glow.",
				"texture_path": "res://background/cyberpunk_city.jpg",
				"ambient_tint": Color(0.2, 0.6, 1.0, 1.0),
				"ember_color": Color(0.0, 0.9, 1.0, 0.9),
				"fog_color": Color(0.12, 0.05, 0.28, 0.35)
			}
		"blood_sunset":
			return {
				"id": "blood_sunset",
				"name": "BLOOD MOON PEAKS",
				"tag": "CRIMSON SUNSET",
				"description": "Ominous twilight cascading golden amber and blood-red light over jagged mountaintops.",
				"texture_path": "res://background/blood_sunset.jpg",
				"ambient_tint": Color(1.0, 0.35, 0.15, 1.0),
				"ember_color": Color(1.0, 0.5, 0.1, 0.9),
				"fog_color": Color(0.35, 0.08, 0.08, 0.32)
			}
		"mystic_forest":
			return {
				"id": "mystic_forest",
				"name": "SPIRIT GROVE",
				"tag": "MYSTIC EMERALD",
				"description": "Ancient colossal roots veiled in spectral emerald fog and tranquil firefly energy.",
				"texture_path": "res://background/mystic_forest.jpg",
				"ambient_tint": Color(0.2, 0.9, 0.5, 1.0),
				"ember_color": Color(0.3, 1.0, 0.6, 0.8),
				"fog_color": Color(0.05, 0.25, 0.15, 0.30)
			}
		"abyssal_void":
			return {
				"id": "abyssal_void",
				"name": "ABYSSAL HORIZON",
				"tag": "COSMIC VORTEX",
				"description": "Dimensional rift pulsing with otherworldly cosmic violet radiation and zero-gravity void shards.",
				"texture_path": "res://background/abyssal_void.jpg",
				"ambient_tint": Color(0.65, 0.2, 0.95, 1.0),
				"ember_color": Color(0.7, 0.3, 1.0, 0.9),
				"fog_color": Color(0.18, 0.04, 0.32, 0.40)
			}
		"classic_dojo":
			return {
				"id": "classic_dojo",
				"name": "OBSIDIAN ARENA",
				"tag": "CLASSIC SHADOW",
				"description": "Minimalist tactical shadow arena bathed in atmospheric rim lighting.",
				"texture_path": "res://background/bg1.jpg",
				"ambient_tint": Color(0.4, 0.4, 0.55, 1.0),
				"ember_color": Color(1.0, 0.7, 0.2, 0.8),
				"fog_color": Color(0.10, 0.08, 0.18, 0.28)
			}
	return get_background_data("cyberpunk")

func get_all_background_ids() -> Array:
	return ["cyberpunk", "blood_sunset", "mystic_forest", "abyssal_void", "classic_dojo"]

func get_all_character_ids() -> Array:
	return ["blade_master", "shadow_fighter"]

func save_settings():
	var config := ConfigFile.new()
	config.set_value("game", "selected_character", selected_character)
	config.set_value("game", "selected_background", selected_background)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "is_music_enabled", is_music_enabled)
	config.set_value("audio", "is_sfx_enabled", is_sfx_enabled)
	config.set_value("graphics", "bloom_enabled", bloom_enabled)
	config.set_value("graphics", "particles_enabled", particles_enabled)
	config.save(SAVE_PATH)

func load_settings():
	var config := ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		selected_character = config.get_value("game", "selected_character", "blade_master")
		selected_background = config.get_value("game", "selected_background", "cyberpunk")
		music_volume = config.get_value("audio", "music_volume", 0.85)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.90)
		is_music_enabled = config.get_value("audio", "is_music_enabled", true)
		is_sfx_enabled = config.get_value("audio", "is_sfx_enabled", true)
		bloom_enabled = config.get_value("graphics", "bloom_enabled", true)
		particles_enabled = config.get_value("graphics", "particles_enabled", true)
