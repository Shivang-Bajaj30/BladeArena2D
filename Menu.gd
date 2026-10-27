extends Control

# ==============================================================================
# AAA CINEMATIC MAIN MENU & BATTLE PREPARATION SYSTEM - BLADE ARENA 2D
# ==============================================================================

# Submenu states
enum MenuState {
	HOME,
	CHARACTER_SELECT,
	BACKGROUND_SELECT,
	RECORDS,
	HOW_TO_PLAY,
	SETTINGS
}

var current_state: MenuState = MenuState.HOME

# --- Node references ---
@onready var bg_texture_rect: TextureRect = $BackgroundLayer/BgTexture
@onready var bg_overlay: ColorRect = $BackgroundLayer/AtmosphericOverlay
@onready var vignette_rect: TextureRect = $BackgroundLayer/Vignette
@onready var particle_container: Control = $BackgroundLayer/ParticleContainer

# Main views
@onready var home_view: Control = $Views/HomeView
@onready var char_select_view: Control = $Views/CharacterSelectView
@onready var bg_select_view: Control = $Views/BackgroundSelectView
@onready var records_view: Control = $Views/RecordsView
@onready var how_to_play_view: Control = $Views/HowToPlayView
@onready var settings_view: Control = $Views/SettingsView

# Records View Nodes
@onready var total_games_val: Label = $Views/RecordsView/Panel/VBox/Grid/CardGames/VBox/Value
@onready var total_wins_val: Label = $Views/RecordsView/Panel/VBox/Grid/CardWins/VBox/Value
@onready var total_losses_val: Label = $Views/RecordsView/Panel/VBox/Grid/CardLosses/VBox/Value
@onready var win_rate_val: Label = $Views/RecordsView/Panel/VBox/Grid/CardWinRate/VBox/Value
@onready var loss_rate_val: Label = $Views/RecordsView/Panel/VBox/Grid/CardLossRate/VBox/Value
@onready var streak_val: Label = $Views/RecordsView/Panel/VBox/Grid/CardStreak/VBox/Value
@onready var ratio_bar: ProgressBar = $Views/RecordsView/Panel/VBox/RatioSection/RatioBar
@onready var reset_stats_btn: Button = $Views/RecordsView/Panel/VBox/Actions/ResetStatsBtn
@onready var return_home_btn: Button = $Views/RecordsView/Panel/VBox/Actions/ReturnHomeBtn
@onready var records_home_btn: Button = $Views/HomeView/MenuContainer/RecordsBtn

# Character preview in home
@onready var hero_preview_sprite: Sprite2D = $BackgroundLayer/HeroStage/HeroSprite
@onready var hero_glow_sprite: Sprite2D = $BackgroundLayer/HeroStage/HeroGlow
@onready var hero_stage: Control = $BackgroundLayer/HeroStage

# Home Screen Warrior Badge
@onready var badge_warrior_name: Label = $Views/HomeView/HeroBadge/VBox/BadgeWarriorName
@onready var badge_weapon: Label = $Views/HomeView/HeroBadge/VBox/BadgeWeapon
@onready var test_strike_btn: Button = $Views/HomeView/HeroBadge/VBox/TestStrikeBtn

# Character Select View Nodes
@onready var char_cards_container: HBoxContainer = $Views/CharacterSelectView/CenterArea/CharacterCards
@onready var char_name_lbl: Label = $Views/CharacterSelectView/DetailsPanel/VBox/CharName
@onready var char_role_lbl: Label = $Views/CharacterSelectView/DetailsPanel/VBox/CharRole
@onready var char_desc_lbl: Label = $Views/CharacterSelectView/DetailsPanel/VBox/CharDesc
@onready var char_weapon_lbl: Label = $Views/CharacterSelectView/DetailsPanel/VBox/CharWeapon
@onready var char_stat_damage: ProgressBar = $Views/CharacterSelectView/DetailsPanel/VBox/StatsGrid/DamageBar
@onready var char_stat_speed: ProgressBar = $Views/CharacterSelectView/DetailsPanel/VBox/StatsGrid/SpeedBar
@onready var char_stat_range: ProgressBar = $Views/CharacterSelectView/DetailsPanel/VBox/StatsGrid/RangeBar
@onready var char_stat_defense: ProgressBar = $Views/CharacterSelectView/DetailsPanel/VBox/StatsGrid/DefenseBar
@onready var char_confirm_btn: Button = $Views/CharacterSelectView/DetailsPanel/VBox/ConfirmCharBtn
@onready var char_preview_large: TextureRect = $Views/CharacterSelectView/PreviewBox/BigPortrait

# Background Select View Nodes
@onready var bg_grid_container: GridContainer = $Views/BackgroundSelectView/Content/Grid
@onready var bg_preview_large: TextureRect = $Views/BackgroundSelectView/Content/PreviewPanel/BigPreview
@onready var bg_name_lbl: Label = $Views/BackgroundSelectView/Content/PreviewPanel/BgName
@onready var bg_tag_lbl: Label = $Views/BackgroundSelectView/Content/PreviewPanel/BgTag
@onready var bg_desc_lbl: Label = $Views/BackgroundSelectView/Content/PreviewPanel/BgDesc
@onready var bg_confirm_btn: Button = $Views/BackgroundSelectView/Content/PreviewPanel/ConfirmBgBtn

# Settings Nodes
@onready var music_slider: HSlider = $Views/SettingsView/Panel/VBox/AudioSection/MusicRow/MusicSlider
@onready var music_val_lbl: Label = $Views/SettingsView/Panel/VBox/AudioSection/MusicRow/MusicValue
@onready var music_toggle_btn: Button = $Views/SettingsView/Panel/VBox/AudioSection/MusicRow/MusicToggle
@onready var sfx_slider: HSlider = $Views/SettingsView/Panel/VBox/AudioSection/SfxRow/SfxSlider
@onready var sfx_val_lbl: Label = $Views/SettingsView/Panel/VBox/AudioSection/SfxRow/SfxValue
@onready var sfx_toggle_btn: Button = $Views/SettingsView/Panel/VBox/AudioSection/SfxRow/SfxToggle
@onready var bloom_check: CheckBox = $Views/SettingsView/Panel/VBox/GraphicsSection/BloomCheck
@onready var particles_check: CheckBox = $Views/SettingsView/Panel/VBox/GraphicsSection/ParticlesCheck

# Audio toggle in Header
@onready var header_music_toggle: Button = $Header/RightControls/QuickMusicToggle

# Intro cover
@onready var intro_overlay: ColorRect = $IntroOverlay

# Animated hero node on hero stage
var hero_anim: AnimatedSprite2D
var is_performing_strike: bool = false

# Dynamic selection caches
var previewing_char_id: String = "blade_master"
var previewing_bg_id: String = "cyberpunk"

# Atmospheric floating particles
var particles: Array[Dictionary] = []
var particle_timer: float = 0.0

# Camera/Parallax
var mouse_parallax: Vector2 = Vector2.ZERO
var target_parallax: Vector2 = Vector2.ZERO
var audio_save_timer: Timer
var button_tweens: Dictionary = {}
# Maps a volume slider to the touch index currently dragging it. The project
# keeps "Emulate Mouse From Touch" off, so HSlider needs the touch events fed
# to it manually (see _on_volume_slider_gui_input).
var volume_slider_touches: Dictionary = {}

func _ready():
	# Seamless audio start without restarting if already playing
	AudioManager.play_menu_music(1.2)
	_setup_settings_view()
	
	# Setup Animated Sprite for Hero Stage
	_setup_hero_stage()
	
	# Apply current persistent state
	previewing_char_id = GameState.selected_character
	previewing_bg_id = GameState.selected_background
	
	_apply_environment(GameState.selected_background, true)
	_update_hero_stage(GameState.selected_character)
	
	_setup_character_selection_view()
	_setup_background_selection_view()
	_setup_button_effects()
	_setup_floating_particles()
	
	# Open immediately on Home Screen
	_switch_view(MenuState.HOME, true)
	
	# Atmospheric intro reveal
	_play_intro_sequence()

func _process(delta: float):
	_update_parallax(delta)
	_update_floating_particles(delta)
	_update_hero_stage_breathing(delta)

# ------------------------------------------------------------------------------
# 1. PARALLAX & ATMOSPHERIC ANIMATIONS
# ------------------------------------------------------------------------------
func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		var vp_size = get_viewport_rect().size
		var norm_pos = (event.position / vp_size) - Vector2(0.5, 0.5)
		target_parallax = norm_pos * Vector2(25.0, 16.0)

func _update_parallax(delta: float):
	mouse_parallax = mouse_parallax.lerp(target_parallax, delta * 3.5)
	if bg_texture_rect:
		bg_texture_rect.position = Vector2(-20, -15) - mouse_parallax * 0.7
	if hero_stage:
		hero_stage.position = get_viewport_rect().size * 0.5 + Vector2(380, -60) + mouse_parallax * 1.2

var breath_time: float = 0.0
func _update_hero_stage_breathing(delta: float):
	breath_time += delta
	var bob_y = sin(breath_time * 1.8) * 6.0
	if hero_anim:
		hero_anim.position.y = bob_y
	elif hero_preview_sprite:
		hero_preview_sprite.position.y = bob_y
		
	if hero_glow_sprite:
		hero_glow_sprite.position.y = bob_y * 0.5
		hero_glow_sprite.modulate.a = 0.45 + sin(breath_time * 2.2) * 0.2

func _setup_floating_particles():
	if not GameState.particles_enabled:
		return
	particles.clear()
	for i in range(40):
		var p_lbl := ColorRect.new()
		var p_size := randf_range(3.0, 6.0)
		p_lbl.size = Vector2(p_size, p_size)
		p_lbl.position = Vector2(randf_range(0, 1920), randf_range(0, 1080))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p_lbl.material = mat
		particle_container.add_child(p_lbl)
		
		particles.append({
			"node": p_lbl,
			"speed": randf_range(25.0, 75.0),
			"sway_freq": randf_range(0.8, 2.5),
			"sway_amp": randf_range(15.0, 45.0),
			"alpha": randf_range(0.4, 0.9),
			"time": randf_range(0.0, 10.0)
		})
	_refresh_particle_colors()

func _refresh_particle_colors():
	var bg_data = GameState.get_background_data(GameState.selected_background)
	var ember_color: Color = bg_data.get("ember_color", Color(0.0, 0.8, 1.0, 0.8))
	for p in particles:
		var col = ember_color
		col.a = p["alpha"]
		p["node"].color = col

func _update_floating_particles(delta: float):
	if not GameState.particles_enabled:
		return
	for p in particles:
		p["time"] += delta
		var node: ColorRect = p["node"]
		node.position.y -= p["speed"] * delta
		node.position.x += sin(p["time"] * p["sway_freq"]) * 0.7
		if node.position.y < -20:
			node.position.y = 1100 + randf_range(0, 40)
			node.position.x = randf_range(0, 1920)

func _play_intro_sequence():
	intro_overlay.visible = true
	intro_overlay.modulate.a = 1.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(intro_overlay, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): intro_overlay.visible = false).set_delay(0.9)

# ------------------------------------------------------------------------------
# 2. VIEW SWITCHING & NAVIGATION
# ------------------------------------------------------------------------------
func _switch_view(new_state: MenuState, immediate: bool = false):
	current_state = new_state
	var views = [home_view, char_select_view, bg_select_view, records_view, how_to_play_view, settings_view]
	var target_view: Control
	match new_state:
		MenuState.HOME:
			target_view = home_view
			hero_stage.visible = true
			_update_hero_stage(GameState.selected_character)
		MenuState.CHARACTER_SELECT:
			target_view = char_select_view
			hero_stage.visible = false
			_select_char_preview(GameState.selected_character)
		MenuState.BACKGROUND_SELECT:
			target_view = bg_select_view
			hero_stage.visible = false
			_select_bg_preview(GameState.selected_background)
		MenuState.RECORDS:
			target_view = records_view
			hero_stage.visible = false
			_sync_records_view()
		MenuState.HOW_TO_PLAY:
			target_view = how_to_play_view
			hero_stage.visible = false
		MenuState.SETTINGS:
			target_view = settings_view
			hero_stage.visible = false
			_sync_settings_controls()
	
	for v in views:
		if v == null:
			continue
		if v == target_view:
			v.visible = true
			if not immediate:
				v.modulate.a = 0.0
				v.position.x = 40.0
				var tw = create_tween().set_parallel(true)
				tw.tween_property(v, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
				tw.tween_property(v, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				v.modulate.a = 1.0
				v.position.x = 0.0
		else:
			v.visible = false

# ------------------------------------------------------------------------------
# 3. ENVIRONMENT & BACKGROUND SELECTION
# ------------------------------------------------------------------------------
func _apply_environment(bg_id: String, immediate: bool = false):
	var data = GameState.get_background_data(bg_id)
	if not data or not ResourceLoader.exists(data["texture_path"]):
		return
	
	var new_tex = load(data["texture_path"])
	if immediate:
		bg_texture_rect.texture = new_tex
		bg_overlay.color = data["ambient_tint"] * Color(1, 1, 1, 0.25)
	else:
		var tw = create_tween()
		tw.tween_property(bg_texture_rect, "modulate:a", 0.2, 0.2)
		tw.tween_callback(func():
			bg_texture_rect.texture = new_tex
			bg_overlay.color = data["ambient_tint"] * Color(1, 1, 1, 0.25)
		)
		tw.tween_property(bg_texture_rect, "modulate:a", 1.0, 0.3)
	
	_refresh_particle_colors()

func _setup_background_selection_view():
	for child in bg_grid_container.get_children():
		child.queue_free()
	
	var all_ids = GameState.get_all_background_ids()
	for id in all_ids:
		var data = GameState.get_background_data(id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(290, 200)
		card.focus_mode = Control.FOCUS_NONE
		
		# Thumbnail
		var tex_rect := TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(data["texture_path"]):
			tex_rect.texture = load(data["texture_path"])
		card.add_child(tex_rect)
		
		# Overlay gradient
		var card_overlay := ColorRect.new()
		card_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_overlay.color = Color(0.02, 0.04, 0.08, 0.45)
		card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(card_overlay)
		
		# Label
		var lbl := Label.new()
		lbl.text = data["name"]
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.offset_top = -52
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lbl)
		
		_style_interactive_card(card, id == GameState.selected_background)
		
		card.pressed.connect(func():
			AudioManager.play_click()
			_select_bg_preview(id)
		)
		card.mouse_entered.connect(AudioManager.play_hover)
		bg_grid_container.add_child(card)

func _select_bg_preview(bg_id: String):
	previewing_bg_id = bg_id
	var data = GameState.get_background_data(bg_id)
	if not data:
		return
	
	if ResourceLoader.exists(data["texture_path"]):
		bg_preview_large.texture = load(data["texture_path"])
	bg_name_lbl.text = data["name"]
	bg_tag_lbl.text = data["tag"]
	bg_desc_lbl.text = data["description"]
	
	_apply_environment(bg_id, false)
	
	var all_ids = GameState.get_all_background_ids()
	var cards = bg_grid_container.get_children()
	for i in range(min(all_ids.size(), cards.size())):
		_style_interactive_card(cards[i], all_ids[i] == previewing_bg_id)
	
	if previewing_bg_id == GameState.selected_background:
		bg_confirm_btn.text = "✓ EQUIPPED"
		bg_confirm_btn.disabled = true
	else:
		bg_confirm_btn.text = "EQUIP ENVIRONMENT"
		bg_confirm_btn.disabled = false

func _on_confirm_bg_pressed():
	AudioManager.play_click()
	GameState.selected_background = previewing_bg_id
	GameState.save_settings()
	_select_bg_preview(previewing_bg_id)

# ------------------------------------------------------------------------------
# 4. CHARACTER SELECTION & ANIMATED HERO STAGE
# ------------------------------------------------------------------------------
func _setup_hero_stage():
	if hero_stage and hero_anim == null:
		hero_anim = AnimatedSprite2D.new()
		hero_anim.scale = Vector2(2.8, 2.8)
		hero_stage.add_child(hero_anim)
	if hero_preview_sprite:
		hero_preview_sprite.visible = false

func _update_hero_stage(char_id: String):
	var data = GameState.get_character_data(char_id)
	if not data:
		return
	
	if hero_anim and ResourceLoader.exists(data["frames_path"]):
		hero_anim.sprite_frames = load(data["frames_path"])
		if char_id == "blade_master":
			if hero_anim.sprite_frames.has_animation("idle_sword"):
				hero_anim.play("idle_sword")
		else:
			if hero_anim.sprite_frames.has_animation("idle"):
				hero_anim.play("idle")
		hero_anim.visible = true
	elif hero_preview_sprite and ResourceLoader.exists(data["preview_texture"]):
		hero_preview_sprite.texture = load(data["preview_texture"])
		hero_preview_sprite.visible = true
	
	var accent: Color = Color(0.0, 0.85, 1.0) if char_id == "blade_master" else Color(1.0, 0.45, 0.1)
	if hero_glow_sprite:
		hero_glow_sprite.modulate = accent * Color(1, 1, 1, 0.5)
	
	_update_home_warrior_badge(char_id)

func _update_home_warrior_badge(char_id: String):
	var data = GameState.get_character_data(char_id)
	if not data:
		return
	if badge_warrior_name:
		badge_warrior_name.text = data["name"]
	if badge_weapon:
		badge_weapon.text = "WEAPON: " + data["weapon"].to_upper()
		var color = Color(0.0, 0.85, 1.0) if char_id == "blade_master" else Color(1.0, 0.55, 0.2)
		badge_weapon.add_theme_color_override("font_color", color)

func _on_test_strike_pressed():
	if is_performing_strike or hero_anim == null or hero_anim.sprite_frames == null:
		return
	is_performing_strike = true
	AudioManager.play_blade_slash()
	
	var anim_name = "attack"
	if GameState.selected_character == "shadow_fighter":
		anim_name = "attack_combo"
	elif not hero_anim.sprite_frames.has_animation("attack"):
		anim_name = "idle_sword"
	
	if hero_anim.sprite_frames.has_animation(anim_name):
		hero_anim.play(anim_name)
		if hero_glow_sprite:
			var tw = create_tween()
			tw.tween_property(hero_glow_sprite, "scale", Vector2(7.2, 7.2), 0.12).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(hero_glow_sprite, "scale", Vector2(5.5, 5.5), 0.25).set_trans(Tween.TRANS_SINE)
		await hero_anim.animation_finished
	
	if not is_instance_valid(hero_anim) or not is_inside_tree():
		is_performing_strike = false
		return
	
	if GameState.selected_character == "blade_master":
		if hero_anim.sprite_frames.has_animation("idle_sword"):
			hero_anim.play("idle_sword")
	else:
		if hero_anim.sprite_frames.has_animation("idle"):
			hero_anim.play("idle")
	is_performing_strike = false

func _setup_character_selection_view():
	for child in char_cards_container.get_children():
		child.queue_free()
	
	var all_chars = GameState.get_all_character_ids()
	for char_id in all_chars:
		var data = GameState.get_character_data(char_id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(320, 470)
		card.focus_mode = Control.FOCUS_NONE
		
		# Portrait image
		var port := TextureRect.new()
		port.set_anchors_preset(Control.PRESET_FULL_RECT)
		port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(data["preview_texture"]):
			port.texture = load(data["preview_texture"])
		port.scale = Vector2(1.2, 1.2)
		port.pivot_offset = Vector2(160, 235)
		card.add_child(port)
		
		# Dark bottom gradient for legible name
		var grad := ColorRect.new()
		grad.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		grad.offset_top = -132
		grad.color = Color(0.02, 0.04, 0.08, 0.85)
		grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(grad)
		
		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -88
		name_label.offset_bottom = -44
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)
		
		var role_label := Label.new()
		role_label.text = data["role"]
		role_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		role_label.offset_top = -46
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 19)
		role_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0) if char_id == "blade_master" else Color(1.0, 0.5, 0.2))
		role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(role_label)
		
		_style_interactive_card(card, char_id == GameState.selected_character)
		
		card.pressed.connect(func():
			AudioManager.play_click()
			_select_char_preview(char_id)
		)
		card.mouse_entered.connect(AudioManager.play_hover)
		char_cards_container.add_child(card)

func _select_char_preview(char_id: String):
	previewing_char_id = char_id
	var data = GameState.get_character_data(char_id)
	if not data:
		return
	
	if ResourceLoader.exists(data["preview_texture"]):
		char_preview_large.texture = load(data["preview_texture"])
	char_name_lbl.text = data["name"]
	char_role_lbl.text = data["role"]
	char_desc_lbl.text = data["description"]
	char_weapon_lbl.text = "WEAPON: " + data["weapon"]
	
	var stats = data["stats"]
	_animate_progress_bar(char_stat_damage, stats.get("Damage", 50))
	_animate_progress_bar(char_stat_speed, stats.get("Speed", 50))
	_animate_progress_bar(char_stat_range, stats.get("Range", 50))
	_animate_progress_bar(char_stat_defense, stats.get("Defense", 50))
	
	var all_chars = GameState.get_all_character_ids()
	var cards = char_cards_container.get_children()
	for i in range(min(all_chars.size(), cards.size())):
		_style_interactive_card(cards[i], all_chars[i] == previewing_char_id)
	
	if previewing_char_id == GameState.selected_character:
		char_confirm_btn.text = "✓ EQUIPPED"
		char_confirm_btn.disabled = true
	else:
		char_confirm_btn.text = "SELECT WARRIOR"
		char_confirm_btn.disabled = false

func _animate_progress_bar(pbar: ProgressBar, target_val: float):
	if pbar == null:
		return
	var tw = create_tween()
	tw.tween_property(pbar, "value", target_val, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_confirm_char_pressed():
	AudioManager.play_blade_slash()
	GameState.selected_character = previewing_char_id
	GameState.save_settings()
	_update_hero_stage(previewing_char_id)
	_select_char_preview(previewing_char_id)

# ------------------------------------------------------------------------------
# 5. SETTINGS
# ------------------------------------------------------------------------------
func _setup_settings_view():
	audio_save_timer = Timer.new()
	audio_save_timer.one_shot = true
	audio_save_timer.wait_time = 0.25
	add_child(audio_save_timer)
	audio_save_timer.timeout.connect(GameState.save_settings)
	_style_volume_slider(music_slider)
	_style_volume_slider(sfx_slider)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	music_slider.drag_ended.connect(_on_audio_slider_drag_ended)
	sfx_slider.drag_ended.connect(_on_sfx_slider_drag_ended)
	# Touch screens never drive HSlider on their own while touch-to-mouse
	# emulation is disabled, so translate the raw touch gestures instead.
	music_slider.gui_input.connect(_on_volume_slider_gui_input.bind(music_slider))
	sfx_slider.gui_input.connect(_on_volume_slider_gui_input.bind(sfx_slider))
	music_toggle_btn.pressed.connect(_on_music_toggle_pressed)
	sfx_toggle_btn.pressed.connect(_on_sfx_toggle_pressed)
	header_music_toggle.pressed.connect(_on_music_toggle_pressed)
	bloom_check.toggled.connect(_on_bloom_toggled)
	particles_check.toggled.connect(_on_particles_toggled)
	_sync_settings_controls()

func _style_volume_slider(slider: HSlider) -> void:
	# Thicker neon track and a glow knob so the slider reads clearly on phones.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.035, 0.075, 0.13, 0.95)
	track.border_color = Color(0.24, 0.55, 0.78, 0.9)
	track.set_border_width_all(2)
	track.set_corner_radius_all(8)
	track.corner_detail = 12
	track.content_margin_top = 8.0
	track.content_margin_bottom = 8.0

	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.0, 0.65, 0.9, 1.0)
	fill.border_color = Color(0.45, 0.95, 1.0, 1.0)
	fill.shadow_color = Color(0.0, 0.7, 1.0, 0.45)
	fill.shadow_size = 6

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.78, 0.98, 1.0, 1.0))
	gradient.set_color(1, Color(0.0, 0.55, 1.0, 0.0))
	gradient.add_point(0.6, Color(0.2, 0.85, 1.0, 1.0))
	var grabber := GradientTexture2D.new()
	grabber.gradient = gradient
	grabber.fill = GradientTexture2D.FILL_RADIAL
	grabber.fill_from = Vector2(0.5, 0.5)
	grabber.fill_to = Vector2(1.0, 0.5)
	grabber.width = 44
	grabber.height = 44
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_icon_override("grabber_disabled", grabber)

func _on_volume_slider_gui_input(event: InputEvent, slider: HSlider) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			volume_slider_touches[slider] = event.index
			slider.drag_started.emit()
			slider.value = _volume_slider_value_at(slider, event.position.x)
			slider.accept_event()
		elif int(volume_slider_touches.get(slider, -1)) == event.index:
			volume_slider_touches.erase(slider)
			# Honour the lifted position so a plain tap lands where it was aimed.
			slider.value = _volume_slider_value_at(slider, event.position.x)
			slider.drag_ended.emit(true)
			slider.accept_event()
	elif event is InputEventScreenDrag and int(volume_slider_touches.get(slider, -1)) == event.index:
		slider.value = _volume_slider_value_at(slider, event.position.x)
		slider.accept_event()

func _volume_slider_value_at(slider: HSlider, local_x: float) -> float:
	var grabber := slider.get_theme_icon("grabber")
	var grabber_width := float(grabber.get_width()) if grabber else 16.0
	var travel := maxf(slider.size.x - grabber_width, 1.0)
	var ratio := clampf((local_x - grabber_width * 0.5) / travel, 0.0, 1.0)
	return lerpf(slider.min_value, slider.max_value, ratio)

func _sync_settings_controls():
	music_slider.set_value_no_signal(GameState.music_volume * 100.0)
	music_val_lbl.text = str(int(music_slider.value)) + "%"
	music_toggle_btn.text = "ON" if GameState.is_music_enabled else "OFF"
	header_music_toggle.text = "🔊 BGM: ON" if GameState.is_music_enabled else "🔇 BGM: OFF"
	
	sfx_slider.set_value_no_signal(GameState.sfx_volume * 100.0)
	sfx_val_lbl.text = str(int(sfx_slider.value)) + "%"
	sfx_toggle_btn.text = "ON" if GameState.is_sfx_enabled else "OFF"
	
	bloom_check.set_pressed_no_signal(GameState.bloom_enabled)
	particles_check.set_pressed_no_signal(GameState.particles_enabled)

func _on_music_slider_changed(value: float):
	GameState.music_volume = value / 100.0
	music_val_lbl.text = str(int(value)) + "%"
	AudioManager.apply_audio_settings()
	audio_save_timer.start()

func _on_sfx_slider_changed(value: float):
	GameState.sfx_volume = value / 100.0
	sfx_val_lbl.text = str(int(value)) + "%"
	AudioManager.apply_audio_settings()
	audio_save_timer.start()

func _on_audio_slider_drag_ended(_value_changed: bool):
	audio_save_timer.stop()
	GameState.save_settings()

func _on_sfx_slider_drag_ended(_value_changed: bool):
	_on_audio_slider_drag_ended(_value_changed)
	AudioManager.play_click()

func _on_music_toggle_pressed():
	AudioManager.play_click()
	GameState.is_music_enabled = !GameState.is_music_enabled
	_sync_settings_controls()
	AudioManager.apply_audio_settings()
	if GameState.is_music_enabled:
		AudioManager.play_menu_music(0.5)
	GameState.save_settings()

func _on_sfx_toggle_pressed():
	if GameState.is_sfx_enabled:
		AudioManager.play_click()
	GameState.is_sfx_enabled = !GameState.is_sfx_enabled
	_sync_settings_controls()
	AudioManager.apply_audio_settings()
	if GameState.is_sfx_enabled:
		AudioManager.play_click()
	GameState.save_settings()

func _on_bloom_toggled(toggled_on: bool):
	AudioManager.play_click()
	GameState.bloom_enabled = toggled_on
	GameState.save_settings()

func _on_particles_toggled(toggled_on: bool):
	AudioManager.play_click()
	GameState.particles_enabled = toggled_on
	particle_container.visible = toggled_on
	GameState.save_settings()

# ------------------------------------------------------------------------------
# 5b. RECORDS / STATS VIEW SYNC
# ------------------------------------------------------------------------------
func _sync_records_view():
	if total_games_val:
		total_games_val.text = str(GameState.total_games)
	if total_wins_val:
		total_wins_val.text = str(GameState.total_wins)
	if total_losses_val:
		total_losses_val.text = str(GameState.total_losses)
	if win_rate_val:
		win_rate_val.text = "%.1f%%" % GameState.get_win_rate()
	if loss_rate_val:
		loss_rate_val.text = "%.1f%%" % GameState.get_loss_rate()
	if streak_val:
		var s_text = GameState.get_streak_display()
		if GameState.best_win_streak > 0:
			s_text += " (BEST: %d)" % GameState.best_win_streak
		streak_val.text = s_text
	if ratio_bar:
		var wr = GameState.get_win_rate()
		ratio_bar.value = wr if GameState.total_games > 0 else 50.0

# ------------------------------------------------------------------------------
# 6. BUTTON ACTIONS & POLISHED HOVER EFFECTS
# ------------------------------------------------------------------------------
func _setup_button_effects():
	var buttons = [
		$Views/HomeView/MenuContainer/PlayBtn,
		$Views/HomeView/PreviousWarrior,
		$Views/HomeView/NextWarrior,
		$Views/HomeView/MenuContainer/BackgroundBtn,
		records_home_btn,
		$Views/HomeView/MenuContainer/GuideBtn,
		$Views/HomeView/MenuContainer/SettingsBtn,
		$Views/HomeView/MenuContainer/ExitBtn,
		test_strike_btn,
		$Views/CharacterSelectView/BackBtn,
		$Views/BackgroundSelectView/BackBtn,
		$Views/RecordsView/BackBtn,
		reset_stats_btn,
		return_home_btn,
		$Views/HowToPlayView/BackBtn,
		$Views/SettingsView/BackBtn,
		char_confirm_btn,
		bg_confirm_btn,
		header_music_toggle
	]
	
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			btn.button_down.connect(_on_btn_down.bind(btn))
			btn.button_up.connect(_on_btn_up.bind(btn))

func _on_btn_hover(btn: Button):
	AudioManager.play_hover()
	_animate_button_scale(btn, 1.025, 0.16)

func _on_btn_unhover(btn: Button):
	_animate_button_scale(btn, 1.0, 0.16)

func _on_btn_down(btn: Button):
	_animate_button_scale(btn, 0.985, 0.09)

func _on_btn_up(btn: Button):
	_animate_button_scale(btn, 1.025 if btn.is_hovered() else 1.0, 0.14)

func _animate_button_scale(btn: Button, target: float, duration: float) -> void:
	btn.pivot_offset = btn.size * 0.5
	var previous: Tween = button_tweens.get(btn)
	if previous and previous.is_valid():
		previous.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2.ONE * target, duration)
	button_tweens[btn] = tween

func _style_interactive_card(btn: Button, is_active: bool):
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.06, 0.09, 0.15, 0.9)
	norm.set_corner_radius_all(16)
	norm.set_border_width_all(2)
	norm.corner_detail = 16
	
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.1, 0.17, 0.27, 0.96)
	hov.set_corner_radius_all(16)
	hov.set_border_width_all(2)
	hov.corner_detail = 16
	
	if is_active:
		norm.border_color = Color(0.2, 0.85, 0.95, 0.95)
		norm.shadow_color = Color(0.0, 0.48, 0.74, 0.26)
		norm.shadow_size = 8
		hov.border_color = Color(0.42, 0.95, 1.0, 1.0)
		hov.shadow_color = Color(0.0, 0.58, 0.8, 0.34)
		hov.shadow_size = 12
	else:
		norm.border_color = Color(0.28, 0.43, 0.6, 0.75)
		hov.border_color = Color(0.52, 0.75, 0.9, 0.9)
	
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", norm)

# ------------------------------------------------------------------------------
# 7. MAIN MENU NAVIGATION SIGNALS
# ------------------------------------------------------------------------------
func _on_play_btn_pressed():
	AudioManager.play_blade_slash()
	
	intro_overlay.visible = true
	var tw = create_tween()
	tw.tween_property(intro_overlay, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://main.tscn")
	)

func _on_previous_warrior_pressed() -> void:
	_cycle_home_character(-1)

func _on_next_warrior_pressed() -> void:
	_cycle_home_character(1)

func _cycle_home_character(direction: int) -> void:
	if is_performing_strike:
		return
	var characters: Array = GameState.get_all_character_ids()
	if characters.is_empty():
		return
	var current_index: int = characters.find(GameState.selected_character)
	var next_index: int = posmod(current_index + direction, characters.size())
	AudioManager.play_click()
	GameState.selected_character = characters[next_index]
	previewing_char_id = GameState.selected_character
	GameState.save_settings()
	_update_hero_stage(GameState.selected_character)
	if hero_anim:
		hero_anim.modulate.a = 0.55
		create_tween().tween_property(hero_anim, "modulate:a", 1.0, 0.2)

func _on_background_btn_pressed():
	AudioManager.play_click()
	_switch_view(MenuState.BACKGROUND_SELECT)

func _on_records_btn_pressed():
	AudioManager.play_click()
	_switch_view(MenuState.RECORDS)

func _on_reset_stats_pressed():
	AudioManager.play_click()
	GameState.reset_records()
	_sync_records_view()

func _on_guide_btn_pressed():
	AudioManager.play_click()
	_switch_view(MenuState.HOW_TO_PLAY)

func _on_settings_btn_pressed():
	AudioManager.play_click()
	_switch_view(MenuState.SETTINGS)

func _on_back_to_home_pressed():
	AudioManager.play_click()
	_apply_environment(GameState.selected_background, false)
	_update_hero_stage(GameState.selected_character)
	_switch_view(MenuState.HOME)

func _on_exit_btn_pressed():
	AudioManager.play_click()
	get_tree().quit()
