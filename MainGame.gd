extends Node2D

# Handles in-game pausing, pause menu, and returning to the main menu
var pause_canvas: CanvasLayer
var pause_panel: PanelContainer
var is_game_paused: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_pause_ui()
	_create_hud_buttons()

func _input(event: InputEvent):
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()

func toggle_pause():
	is_game_paused = !is_game_paused
	get_tree().paused = is_game_paused
	pause_canvas.visible = is_game_paused
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
	pause_canvas.layer = 20
	pause_canvas.visible = false
	add_child(pause_canvas)
	
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.size = Vector2(1920, 1080)
	pause_canvas.add_child(backdrop)
	
	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(460, 480)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(1920/2 - 230, 1080/2 - 240)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	panel_style.border_color = Color(0.0, 0.85, 1.0, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0.0, 0.6, 1.0, 0.35)
	panel_style.shadow_size = 28
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	pause_canvas.add_child(pause_panel)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	pause_panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(title)
	
	var resume_btn := _create_menu_button("RESUME COMBAT", Color(0.0, 0.8, 1.0))
	resume_btn.pressed.connect(toggle_pause)
	vbox.add_child(resume_btn)
	
	var restart_btn := _create_menu_button("RESTART MATCH", Color(0.8, 0.8, 0.8))
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)
	
	var exit_btn := _create_menu_button("RETURN TO MAIN MENU", Color(1.0, 0.4, 0.4))
	exit_btn.pressed.connect(_on_return_to_menu_pressed)
	vbox.add_child(exit_btn)

func _create_menu_button(btn_text: String, accent_color: Color) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(360, 56)
	btn.add_theme_font_size_override("font_size", 20)
	
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.10, 0.14, 0.22, 0.9)
	norm.border_color = accent_color * 0.7
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(8)
	
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.16, 0.24, 0.38, 1.0)
	hov.border_color = accent_color
	hov.set_border_width_all(2)
	hov.set_corner_radius_all(8)
	
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.mouse_entered.connect(AudioManager.play_hover)
	return btn

func _on_restart_pressed():
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_return_to_menu_pressed():
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")
