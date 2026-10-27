extends Node2D

# ==============================================================================
# MainGame - Arena Combat Manager, Round State, HUD, Pause & Win/Loss Flow
# ==============================================================================

const ROUND_TIME: float = 60.0
const ROUNDS_TO_WIN: int = 2

var player_node: Node2D
var enemy_node: Node2D

# Match State
var current_round: int = 1
var player_wins: int = 0
var enemy_wins: int = 0
var time_left: float = ROUND_TIME
var is_round_active: bool = false
var match_ended: bool = false

# UI references
var hud_canvas: CanvasLayer
var pause_canvas: CanvasLayer
var banner_canvas: CanvasLayer

# HUD elements
var player_hp_bar: ProgressBar
var player_hp_lbl: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_lbl: Label
var timer_lbl: Label
var round_lbl: Label
var round_dots_lbl: Label
var pause_btn: Button

# Pause Menu
var pause_panel: PanelContainer
var is_game_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.play_menu_music(0.8)
	
	_setup_combatants()
	_create_combat_hud()
	_create_banner_ui()
	_create_pause_ui()
	_create_hud_buttons()

func _input(event: InputEvent):
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()

# ------------------------------------------------------------------------------
# 1. SETUP COMBATANTS
# ------------------------------------------------------------------------------
func _setup_combatants() -> void:
	player_node = get_node_or_null("Player")
	if player_node:
		player_node.global_position = Vector2(-350, 512)
		if player_node.has_signal("health_changed"):
			player_node.health_changed.connect(_on_player_health_changed)
		if player_node.has_signal("player_died"):
			player_node.player_died.connect(_on_player_died)
	
	# Spawn or locate Enemy
	enemy_node = get_node_or_null("Enemy")
	if enemy_node == null:
		var enemy_script = load("res://Enemy.gd")
		enemy_node = CharacterBody2D.new()
		enemy_node.name = "Enemy"
		enemy_node.set_script(enemy_script)
		add_child(enemy_node)
	
	enemy_node.global_position = Vector2(350, 512)
	if enemy_node.has_signal("health_changed"):
		enemy_node.health_changed.connect(_on_enemy_health_changed)
	if enemy_node.has_signal("enemy_died"):
		enemy_node.enemy_died.connect(_on_enemy_died)

# ------------------------------------------------------------------------------
# 2. ROUND MANAGEMENT & MATCH FLOW
# ------------------------------------------------------------------------------
func _start_round(round_idx: int) -> void:
	current_round = round_idx
	time_left = ROUND_TIME
	is_round_active = false
	
	# Reset combatant states
	if player_node and player_node.has_method("reset_for_round"):
		player_node.reset_for_round(Vector2(-350, 512), true)
	if enemy_node and enemy_node.has_method("reset_for_round"):
		enemy_node.reset_for_round(Vector2(350, 512), false)
	
	_update_hud_display()
	
	# Display round announcement banner
	_show_round_start_banner("ROUND %d" % current_round, "FIGHT!")

func _show_round_start_banner(title: String, subtitle: String) -> void:
	var banner_box: Control = banner_canvas.get_node("BannerBox")
	var title_lbl: Label = banner_box.get_node("Title")
	var sub_lbl: Label = banner_box.get_node("Subtitle")
	
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	sub_lbl.text = subtitle
	
	banner_canvas.visible = true
	banner_box.scale = Vector2(0.6, 0.6)
	banner_box.modulate.a = 0.0
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner_box, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.35)
	
	await get_tree().create_timer(1.2).timeout
	
	var fade_tw = create_tween()
	fade_tw.tween_property(banner_box, "modulate:a", 0.0, 0.3)
	fade_tw.tween_callback(func():
		banner_canvas.visible = false
		if not match_ended:
			is_round_active = true
	)

func _on_player_died() -> void:
	if match_ended:
		return
	is_round_active = false
	# Per Requirement 3: Losing ANY round immediately ends match with defeat
	_trigger_match_defeat("DEFEAT", "ROUND LOST — ELIMINATED")

func _on_enemy_died() -> void:
	if match_ended:
		return
	is_round_active = false
	player_wins += 1
	_update_hud_display()
	
	# Per Requirement 2: Winning all rounds returns home with victory
	if player_wins >= ROUNDS_TO_WIN:
		_trigger_match_victory("VICTORY!", "CHAMPION OF THE ARENA")
	else:
		# Won intermediate round - prepare next round
		_show_round_end_announcement("ROUND %d WON!" % current_round, "NEXT ROUND INCOMING", Color(0.2, 0.9, 1.0))
		await get_tree().create_timer(2.0).timeout
		if not match_ended:
			_start_round(current_round + 1)

func _on_round_timer_expired() -> void:
	if match_ended:
		return
	is_round_active = false
	
	var p_hp: float = player_node.get("current_health") if player_node else 0.0
	var e_hp: float = enemy_node.get("current_health") if enemy_node else 0.0
	
	if p_hp > e_hp:
		# Player had more HP, wins round
		_on_enemy_died()
	else:
		# Enemy had equal or more HP, player loses round -> immediate match defeat
		_trigger_match_defeat("TIME EXPIRED", "DEFEAT — ROUND LOST")

func _trigger_match_victory(title: String, subtitle: String) -> void:
	if match_ended:
		return
	match_ended = true
	is_round_active = false
	
	# Persistent stats update - single record
	GameState.record_match_result(true)
	
	_show_match_end_banner(title, subtitle, Color(1.0, 0.88, 0.2), Color(0.1, 0.8, 1.0))
	
	# Return to Home Screen after clear celebration
	await get_tree().create_timer(2.6).timeout
	_return_to_home_screen()

func _trigger_match_defeat(title: String, subtitle: String) -> void:
	if match_ended:
		return
	match_ended = true
	is_round_active = false
	
	# Persistent stats update - single record
	GameState.record_match_result(false)
	
	_show_match_end_banner(title, subtitle, Color(1.0, 0.25, 0.25), Color(0.8, 0.1, 0.1))
	
	# Return to Home Screen after clear defeat message
	await get_tree().create_timer(2.6).timeout
	_return_to_home_screen()

func _return_to_home_screen() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

# ------------------------------------------------------------------------------
# 3. COMBAT HUD (ENLARGED & PROFESSIONAL)
# ------------------------------------------------------------------------------
func _create_combat_hud() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.layer = 15
	add_child(hud_canvas)
	
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_canvas.add_child(root)
	
	# Top combat bar container
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 40
	top_bar.offset_top = 22
	top_bar.offset_right = -40
	top_bar.offset_bottom = 100
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", 24)
	root.add_child(top_bar)
	
	# --- PLAYER CARD (Left) ---
	var player_box := VBoxContainer.new()
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_box.add_theme_constant_override("separation", 4)
	top_bar.add_child(player_box)
	
	var p_header := HBoxContainer.new()
	p_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_box.add_child(p_header)
	
	var p_name_lbl := Label.new()
	var char_data = GameState.get_character_data(GameState.selected_character)
	p_name_lbl.text = "YOU: " + char_data.get("name", "BLADE MASTER")
	p_name_lbl.add_theme_font_size_override("font_size", 18)
	p_name_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	p_header.add_child(p_name_lbl)
	
	var p_spacer := Control.new()
	p_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_header.add_child(p_spacer)
	
	player_hp_lbl = Label.new()
	player_hp_lbl.text = "100 / 100"
	player_hp_lbl.add_theme_font_size_override("font_size", 16)
	player_hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	p_header.add_child(player_hp_lbl)
	
	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(0, 26)
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = 100
	player_hp_bar.value = 100
	player_hp_bar.show_percentage = false
	
	var p_bg := StyleBoxFlat.new()
	p_bg.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	p_bg.border_color = Color(0.2, 0.4, 0.6, 0.7)
	p_bg.set_border_width_all(2)
	p_bg.set_corner_radius_all(6)
	
	var p_fill := StyleBoxFlat.new()
	p_fill.bg_color = Color(0.0, 0.85, 1.0)
	p_fill.set_corner_radius_all(4)
	
	player_hp_bar.add_theme_stylebox_override("background", p_bg)
	player_hp_bar.add_theme_stylebox_override("fill", p_fill)
	player_box.add_child(player_hp_bar)
	
	# --- CENTER ROUND & TIMER PANEL ---
	var center_panel := VBoxContainer.new()
	center_panel.custom_minimum_size = Vector2(220, 75)
	center_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_panel.add_theme_constant_override("separation", 2)
	top_bar.add_child(center_panel)
	
	round_lbl = Label.new()
	round_lbl.text = "ROUND 1"
	round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_lbl.add_theme_font_size_override("font_size", 16)
	round_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	center_panel.add_child(round_lbl)
	
	timer_lbl = Label.new()
	timer_lbl.text = "60"
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.add_theme_font_size_override("font_size", 34)
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	center_panel.add_child(timer_lbl)
	
	round_dots_lbl = Label.new()
	round_dots_lbl.text = "○ ○   VS   ○ ○"
	round_dots_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_dots_lbl.add_theme_font_size_override("font_size", 14)
	round_dots_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	center_panel.add_child(round_dots_lbl)
	
	# --- ENEMY CARD (Right) ---
	var enemy_box := VBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_box.add_theme_constant_override("separation", 4)
	top_bar.add_child(enemy_box)
	
	var e_header := HBoxContainer.new()
	e_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_box.add_child(e_header)
	
	enemy_hp_lbl = Label.new()
	enemy_hp_lbl.text = "100 / 100"
	enemy_hp_lbl.add_theme_font_size_override("font_size", 16)
	enemy_hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	e_header.add_child(enemy_hp_lbl)
	
	var e_spacer := Control.new()
	e_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e_header.add_child(e_spacer)
	
	var e_name_lbl := Label.new()
	var rival_id: String = "shadow_fighter" if GameState.selected_character == "blade_master" else "blade_master"
	var rival_data = GameState.get_character_data(rival_id)
	e_name_lbl.text = "RIVAL: " + rival_data.get("name", "SHADOW BRAWLER")
	e_name_lbl.add_theme_font_size_override("font_size", 18)
	e_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	e_header.add_child(e_name_lbl)
	
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(0, 26)
	enemy_hp_bar.min_value = 0
	enemy_hp_bar.max_value = 100
	enemy_hp_bar.value = 100
	enemy_hp_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	enemy_hp_bar.show_percentage = false
	
	var e_bg := StyleBoxFlat.new()
	e_bg.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	e_bg.border_color = Color(0.6, 0.25, 0.25, 0.7)
	e_bg.set_border_width_all(2)
	e_bg.set_corner_radius_all(6)
	
	var e_fill := StyleBoxFlat.new()
	e_fill.bg_color = Color(1.0, 0.35, 0.25)
	e_fill.set_corner_radius_all(4)
	
	enemy_hp_bar.add_theme_stylebox_override("background", e_bg)
	enemy_hp_bar.add_theme_stylebox_override("fill", e_fill)
	enemy_box.add_child(enemy_hp_bar)
	
	# --- PAUSE BUTTON (Prominent & User-Friendly) ---
	pause_btn = Button.new()
	pause_btn.text = "❚❚ PAUSE"
	pause_btn.custom_minimum_size = Vector2(140, 52)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -170
	pause_btn.offset_right = -30
	pause_btn.offset_top = 112
	pause_btn.offset_bottom = 164
	pause_btn.focus_mode = Control.FOCUS_NONE
	
	var p_btn_style := StyleBoxFlat.new()
	p_btn_style.bg_color = Color(0.08, 0.12, 0.20, 0.88)
	p_btn_style.border_color = Color(0.25, 0.7, 1.0, 0.8)
	p_btn_style.set_border_width_all(2)
	p_btn_style.set_corner_radius_all(8)
	
	var p_btn_hov := StyleBoxFlat.new()
	p_btn_hov.bg_color = Color(0.16, 0.26, 0.44, 0.95)
	p_btn_hov.border_color = Color(0.4, 0.9, 1.0, 1.0)
	p_btn_hov.set_border_width_all(2)
	p_btn_hov.set_corner_radius_all(8)
	
	pause_btn.add_theme_stylebox_override("normal", p_btn_style)
	pause_btn.add_theme_stylebox_override("hover", p_btn_hov)
	pause_btn.add_theme_stylebox_override("pressed", p_btn_hov)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(toggle_pause)
	pause_btn.mouse_entered.connect(AudioManager.play_hover)
	root.add_child(pause_btn)

func _update_hud_display() -> void:
	if round_lbl:
		round_lbl.text = "ROUND %d" % current_round
	if round_dots_lbl:
		var p_dots = "● ".repeat(player_wins) + "○ ".repeat(max(0, ROUNDS_TO_WIN - player_wins))
		var e_dots = "● ".repeat(enemy_wins) + "○ ".repeat(max(0, ROUNDS_TO_WIN - enemy_wins))
		round_dots_lbl.text = "%s  VS   %s" % [p_dots.strip_edges(), e_dots.strip_edges()]

func _on_player_health_changed(hp: float, max_hp: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = hp
	if player_hp_lbl:
		player_hp_lbl.text = "%d / %d" % [int(ceil(hp)), int(max_hp)]

func _on_enemy_health_changed(hp: float, max_hp: float) -> void:
	if enemy_hp_bar:
		enemy_hp_bar.max_value = max_hp
		enemy_hp_bar.value = hp
	if enemy_hp_lbl:
		enemy_hp_lbl.text = "%d / %d" % [int(ceil(hp)), int(max_hp)]

# ------------------------------------------------------------------------------
# 4. BANNER & ANNOUNCEMENTS
# ------------------------------------------------------------------------------
func _create_banner_ui() -> void:
	banner_canvas = CanvasLayer.new()
	banner_canvas.layer = 25
	banner_canvas.visible = false
	add_child(banner_canvas)
	
	var box := VBoxContainer.new()
	box.name = "BannerBox"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_left = -400
	box.offset_right = 400
	box.offset_top = -120
	box.offset_bottom = 120
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.pivot_offset = Vector2(400, 120)
	banner_canvas.add_child(box)
	
	var title := Label.new()
	title.name = "Title"
	title.text = "ROUND 1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 6)
	box.add_child(title)
	
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "FIGHT!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	subtitle.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(subtitle)

func _show_round_end_announcement(title: String, subtitle: String, title_col: Color) -> void:
	var box: Control = banner_canvas.get_node("BannerBox")
	var t: Label = box.get_node("Title")
	var s: Label = box.get_node("Subtitle")
	t.text = title
	t.add_theme_color_override("font_color", title_col)
	s.text = subtitle
	
	banner_canvas.visible = true
	box.scale = Vector2(0.6, 0.6)
	box.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(box, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	
	await get_tree().create_timer(1.4).timeout
	var fade_tw = create_tween()
	fade_tw.tween_property(box, "modulate:a", 0.0, 0.25)
	fade_tw.tween_callback(func(): banner_canvas.visible = false)

func _show_match_end_banner(title: String, subtitle: String, title_col: Color, glow_col: Color) -> void:
	var box: Control = banner_canvas.get_node("BannerBox")
	var t: Label = box.get_node("Title")
	var s: Label = box.get_node("Subtitle")
	t.text = title
	t.add_theme_color_override("font_color", title_col)
	t.add_theme_color_override("font_shadow_color", glow_col)
	s.text = subtitle
	
	banner_canvas.visible = true
	box.scale = Vector2(0.5, 0.5)
	box.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(box, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.4)

# ------------------------------------------------------------------------------
# 5. PAUSE SYSTEM (EXACT CENTER, PROPER PAUSE, RESUME/RESTART/HOME)
# ------------------------------------------------------------------------------
func toggle_pause() -> void:
	if match_ended:
		return
	is_game_paused = !is_game_paused
	get_tree().paused = is_game_paused
	pause_canvas.visible = is_game_paused
	pause_button.text = "▶" if is_game_paused else "❚❚"
	if is_game_paused:
		AudioManager.play_hover()

func _create_hud_buttons():
	var hud := CanvasLayer.new()
	hud.layer = 15
	add_child(hud)
	
	# Pause button at top-right
	var pause_btn := Button.new()
	pause_btn.text = "❚❚ MENU"
	pause_btn.size = Vector2(130, 48)
	pause_btn.position = Vector2(1920 - 160, 24)
	pause_btn.focus_mode = Control.FOCUS_NONE
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.12, 0.20, 0.85)
	style_normal.border_color = Color(0.25, 0.65, 1.0, 0.7)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.14, 0.22, 0.38, 0.95)
	style_hover.border_color = Color(0.4, 0.8, 1.0, 0.95)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(8)
	
	pause_btn.add_theme_stylebox_override("normal", style_normal)
	pause_btn.add_theme_stylebox_override("hover", style_hover)
	pause_btn.add_theme_stylebox_override("pressed", style_hover)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(toggle_pause)
	pause_btn.mouse_entered.connect(AudioManager.play_hover)
	hud.add_child(pause_btn)

func _create_pause_ui():
	pause_canvas = CanvasLayer.new()
	pause_canvas.layer = 30
	pause_canvas.visible = false
	add_child(pause_canvas)
	
	# Dark semi-transparent background overlay
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.84)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.size = Vector2(1920, 1080)
	pause_canvas.add_child(backdrop)
	
	# Centered pause panel exactly in screen center
	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(460, 480)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(1920/2 - 230, 1080/2 - 240)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	panel_style.border_color = Color(0.0, 0.85, 1.0, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0.0, 0.6, 1.0, 0.35)
	panel_style.shadow_size = 28
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	pause_canvas.add_child(pause_panel)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	pause_panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0.8, 1, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	
	var sub := Label.new()
	sub.text = "COMBAT SUSPENDED"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(sub)
	
	# Resume Button
	var resume_btn := _create_pause_menu_btn("▶  RESUME COMBAT", Color(0.0, 0.85, 1.0))
	resume_btn.pressed.connect(toggle_pause)
	vbox.add_child(resume_btn)
	
	# Restart Button
	var restart_btn := _create_pause_menu_btn("↺  RESTART MATCH", Color(0.85, 0.85, 0.85))
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)
	
	# Home Button
	var home_btn := _create_pause_menu_btn("⌂  RETURN TO HOME", Color(1.0, 0.45, 0.45))
	home_btn.pressed.connect(_on_return_to_menu_pressed)
	vbox.add_child(home_btn)

func _create_pause_menu_btn(btn_text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(360, 56)
	btn.add_theme_font_size_override("font_size", 20)
	
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.10, 0.14, 0.22, 0.92)
	norm.border_color = accent * 0.75
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(10)
	
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.16, 0.24, 0.38, 1.0)
	hov.border_color = accent
	hov.set_border_width_all(2)
	hov.set_corner_radius_all(8)
	
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.mouse_entered.connect(AudioManager.play_hover)
	return btn

func _on_restart_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_return_to_menu_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")
