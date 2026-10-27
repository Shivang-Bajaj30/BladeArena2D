extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false

func push_touch(position: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	root.push_input(event, true)

func push_drag(position: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	root.push_input(event, true)

func slider_value_for_local_x(slider: HSlider, local_x: float) -> float:
	var grabber: Texture2D = slider.get_theme_icon("grabber")
	var grabber_width: float = float(grabber.get_width()) if grabber else 16.0
	var travel: float = maxf(slider.size.x - grabber_width, 1.0)
	var ratio: float = clampf((local_x - grabber_width * 0.5) / travel, 0.0, 1.0)
	return lerpf(slider.min_value, slider.max_value, ratio)

func run_checks() -> void:
	# Pin the viewport so layout checks use the real 1920x1080 design space.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	await process_frame
	var game_state = root.get_node("GameState")
	var audio_manager = root.get_node("AudioManager")
	var stored_music_enabled: bool = game_state.is_music_enabled
	var stored_music_volume: float = game_state.music_volume
	game_state.is_music_enabled = true
	if not check(change_scene_to_file("res://menu.tscn") == OK, "Menu scene failed to load"):
		return
	for frame in range(12):
		await process_frame
	var menu := current_scene
	var menu_buttons: VBoxContainer = menu.get_node("Views/HomeView/MenuContainer")
	var play_button: Button = menu_buttons.get_node("PlayBtn")
	var button_style: StyleBoxFlat = play_button.get_theme_stylebox("normal")
	var previous_warrior: Button = menu.get_node("Views/HomeView/PreviousWarrior")
	var next_warrior: Button = menu.get_node("Views/HomeView/NextWarrior")
	if not check(audio_manager.bgm_stream is AudioStreamOggVorbis and audio_manager.bgm_stream.loop, "New menu music is missing or does not loop"):
		return
	if not check(audio_manager.bgm_player.playing, "Menu music did not start"):
		return
	if not check(audio_manager.hover_stream is AudioStreamWAV and audio_manager.click_stream is AudioStreamWAV, "Soft UI sounds were not loaded"):
		return
	if not check(audio_manager.hover_stream.get_length() < 0.12 and audio_manager.click_stream.get_length() < 0.17, "UI cues are too long"):
		return
	if not check(button_style.corner_radius_top_left >= 14 and button_style.border_width_left == button_style.border_width_right, "Button corners or borders are uneven"):
		return
	if not check(play_button.size.x >= 420.0 and play_button.get_theme_font_size("font_size") >= 26, "Main buttons were not enlarged"):
		return
	var bottom_button: Button = menu_buttons.get_node("ExitBtn")
	if not check(bottom_button.position.y + bottom_button.size.y <= menu_buttons.size.y + 1.0, "Home buttons overflow their menu container"):
		return
	if not check(not menu_buttons.has_node("CharacterBtn"), "Old warrior selection button is still on the home screen"):
		return
	var hero_x: float = menu.hero_stage.global_position.x
	var left_rect := previous_warrior.get_global_rect()
	var right_rect := next_warrior.get_global_rect()
	if not check(left_rect.end.x < hero_x - 310.0 and right_rect.position.x > hero_x + 160.0, "Warrior arrows overlap the preview"):
		return
	if not check(not left_rect.intersects(menu_buttons.get_global_rect()) and not right_rect.intersects(menu.get_node("Views/HomeView/HeroBadge").get_global_rect()), "Warrior arrows overlap home controls"):
		return
	var original_character: String = game_state.selected_character
	next_warrior.emit_signal("pressed")
	if not check(game_state.selected_character != original_character and menu.badge_warrior_name.text == game_state.get_character_data(game_state.selected_character)["name"], "Next arrow did not select and show the other warrior"):
		return
	previous_warrior.emit_signal("pressed")
	if not check(game_state.selected_character == original_character, "Previous arrow did not return to the original warrior"):
		return
	menu._switch_view(1, true)
	await process_frame
	var character_cards: HBoxContainer = menu.get_node("Views/CharacterSelectView/CenterArea/CharacterCards")
	var last_character: Control = character_cards.get_child(character_cards.get_child_count() - 1)
	if not check(last_character.position.x + last_character.size.x <= character_cards.size.x + 1.0, "Larger warrior cards overflow their row"):
		return
	var details_panel: Control = menu.get_node("Views/CharacterSelectView/DetailsPanel")
	var details_content: VBoxContainer = menu.get_node("Views/CharacterSelectView/DetailsPanel/VBox")
	var details_rect := details_panel.get_global_rect()
	if not check(details_rect.position.y >= 174.0 and details_rect.end.y <= 1080.0, "Warrior details panel leaves the screen"):
		return
	if not check(details_rect.encloses(details_content.get_global_rect()), "Warrior details text overflows its panel"):
		return
	var preview_rect: Rect2 = menu.get_node("Views/CharacterSelectView/PreviewBox").get_global_rect()
	if not check(preview_rect.position.y == details_rect.position.y and preview_rect.size.y == details_rect.size.y, "Warrior preview and details panels are misaligned"):
		return
	menu._switch_view(3, true)
	await process_frame
	var guide_cards: Control = menu.get_node("Views/HowToPlayView/Content")
	for card in guide_cards.get_children():
		var card_vbox: VBoxContainer = card.get_node("VBox")
		if not check(card.get_global_rect().encloses(card_vbox.get_global_rect()), "Guide text overflows the %s card" % card.name):
			return
	menu._switch_view(2, true)
	await process_frame
	var background_grid: GridContainer = menu.get_node("Views/BackgroundSelectView/Content/Grid")
	var last_background: Control = background_grid.get_child(background_grid.get_child_count() - 1)
	if not check(last_background.position.x + last_background.size.x <= background_grid.size.x + 1.0, "Larger environment cards overflow their grid"):
		return
	menu._switch_view(4, true)
	await process_frame
	var settings_content: VBoxContainer = menu.get_node("Views/SettingsView/Panel/VBox")
	var last_section: Control = settings_content.get_child(settings_content.get_child_count() - 1)
	if not check(last_section.position.y + last_section.size.y <= settings_content.size.y + 1.0, "Larger settings text overflows its panel"):
		return
	# Touch must drive the volume slider even though touch-to-mouse emulation is off.
	var music_slider: HSlider = menu.get_node("Views/SettingsView/Panel/VBox/AudioSection/MusicRow/MusicSlider")
	var stored_volume: float = game_state.music_volume
	var slider_rect := music_slider.get_global_rect()
	var grabber_width: float = float(music_slider.get_theme_icon("grabber").get_width())
	push_touch(slider_rect.position + Vector2(grabber_width * 0.5, slider_rect.size.y * 0.5), true)
	await process_frame
	if not check(absf(music_slider.value - slider_value_for_local_x(music_slider, grabber_width * 0.5)) <= 1.0, "Touch tap did not set the music slider"):
		return
	var drag_x: float = slider_rect.size.x * 0.72
	var drag_position := slider_rect.position + Vector2(drag_x, slider_rect.size.y * 0.5 + 260.0)
	push_drag(drag_position)
	await process_frame
	if not check(absf(music_slider.value - slider_value_for_local_x(music_slider, drag_x)) <= 1.0, "Touch drag did not move the music slider"):
		return
	push_touch(drag_position, false)
	await process_frame
	if not check(absf(music_slider.value - slider_value_for_local_x(music_slider, drag_x)) <= 1.0, "Music slider jumped on touch release"):
		return
	game_state.music_volume = stored_volume
	music_slider.set_value_no_signal(stored_volume * 100.0)
	await create_timer(0.6).timeout
	audio_manager.bgm_player.stop()
	# Slider drags persist settings, so put the player's saved values back.
	game_state.music_volume = stored_music_volume
	game_state.is_music_enabled = stored_music_enabled
	game_state.save_settings()
	menu.queue_free()
	await process_frame
	print("Menu audio and layout checks passed")
	quit()
