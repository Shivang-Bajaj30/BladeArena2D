extends Control

@onready var bg = $ColorRect
@onready var sound_btn = $VBoxContainer/SoundButton

var bg_colors = [
	Color(0.12, 0.12, 0.12, 1),
	Color(0.08, 0.15, 0.20, 1),
	Color(0.15, 0.08, 0.08, 1),
	Color(0.10, 0.15, 0.10, 1)
]
var current_bg_index = 0
var is_sound_on = true

func _ready():
	_update_sound_button()
	_apply_button_animations()

func _apply_button_animations():
	# Allow a frame to pass so control sizes are calculated
	await get_tree().process_frame
	for btn in $VBoxContainer.get_children():
		if btn is Button:
			btn.pivot_offset = btn.size / 2.0
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			btn.button_down.connect(_on_btn_down.bind(btn))
			btn.button_up.connect(_on_btn_up.bind(btn))

func _on_btn_hover(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)

func _on_btn_unhover(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _on_btn_down(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1).set_trans(Tween.TRANS_SINE)

func _on_btn_up(btn: Button):
	var tween = create_tween()
	# If mouse is still over it, pop back to hover scale, otherwise normal scale
	var target = Vector2(1.05, 1.05) if btn.is_hovered() else Vector2(1.0, 1.0)
	tween.tween_property(btn, "scale", target, 0.1).set_trans(Tween.TRANS_SINE)

func _on_home_button_pressed():
	# In a main menu, Home might just reset state or show a message
	print("Home Pressed")

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

func _on_settings_button_pressed():
	print("Settings Pressed")

func _on_bg_button_pressed():
	current_bg_index = (current_bg_index + 1) % bg_colors.size()
	var tween = create_tween()
	tween.tween_property(bg, "color", bg_colors[current_bg_index], 0.3)

func _on_sound_button_pressed():
	is_sound_on = !is_sound_on
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, !is_sound_on)
	_update_sound_button()

func _update_sound_button():
	if is_sound_on:
		sound_btn.text = "🔊 Sound: On"
	else:
		sound_btn.text = "🔇 Sound: Off"

func _on_about_button_pressed():
	print("About Pressed")

func _on_quit_button_pressed():
	get_tree().quit()
