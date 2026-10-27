extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false

func run_checks() -> void:
	await process_frame
	var game_state = root.get_node("GameState")
	var input_manager = root.get_node("InputManager")
	for character_id in ["blade_master", "shadow_fighter"]:
		game_state.selected_character = character_id
		if not check(change_scene_to_file("res://main.tscn") == OK, "Arena scene failed to load"):
			return
		await process_frame
		await physics_frame
		await process_frame
		var arena := current_scene
		while arena.round_transitioning:
			await process_frame
		var player = arena.get_node("Player")
		var opponent = arena.get_node("Opponent")
		if not check(player.anim.sprite_frames == load(game_state.get_character_data(character_id)["frames_path"]), "Selected fighter frames were replaced"):
			return
		if not check(not arena.get_node("TouchControls").has_node("ArsenalSwitch"), "Arena weapon switch still exists"):
			return
		if not check(player.walk_speed >= 250.0 and player.run_speed >= 600.0, "Movement speed was not raised"):
			return
		if not check(arena.pause_button.text == "❚❚" and absf(arena.pause_button.get_global_rect().get_center().x - 960.0) < 5.0, "Centered pause icon is missing"):
			return
		if not check(arena.get_node("TouchControls/BattleHUD").player_bar.size.y >= 40.0, "Health bars were not enlarged"):
			return
		arena.toggle_pause()
		if not check(paused and arena.pause_button.text == "▶", "Pause button did not enter pause mode"):
			return
		arena.toggle_pause()
		if not check(not paused and arena.pause_button.text == "❚❚", "Pause button did not resume play"):
			return
		if not check(player.get_mode_animation("attack") != &"idle", "Selected fighter has no attack animation"):
			return
		opponent.set_physics_process(false)
		opponent.global_position = player.global_position + Vector2(165.0, 0.0)
		var opponent_health: float = opponent.health
		player.do_attack()
		for frame in range(35):
			await physics_frame
			await process_frame
		if not check(opponent.health < opponent_health, "Attack did not damage the opponent"):
			return
		player.do_attack()
		input_manager.set_joystick(Vector2.RIGHT)
		await physics_frame
		await process_frame
		if not check(not player.is_attacking, "Starting a run did not cancel the attack"):
			return
		input_manager.set_joystick(Vector2.ZERO)
		player.do_air_dash()
		var dash_y: float = player.global_position.y
		for frame in range(8):
			await physics_frame
			await process_frame
		if not check(is_equal_approx(player.global_position.y, dash_y), "Dash changed player height"):
			return
		player.is_air_dashing = false
		player.end_dash_phase()
		player.do_air_dash()
		for frame in range(8):
			await physics_frame
			await process_frame
		if not check(is_equal_approx(player.global_position.y, dash_y), "Repeated dash accumulated height"):
			return
		player.is_air_dashing = false
		player.end_dash_phase()
		player.begin_dash_phase()
		player.is_dashing = true
		var starting_health: float = player.health
		player.apply_damage(15.0, opponent)
		if not check(player.health == starting_health and player.collision_mask == 1, "Dash did not protect the player or preserve arena collision"):
			return
		player.is_dashing = false
		player.end_dash_phase()
		player.apply_damage(15.0, opponent)
		if not check(player.health == starting_health, "Dash exit grace did not protect the player"):
			return
		player.global_position.x = 10000.0
		player.move_and_keep_on_screen()
		if not check(player.global_position.x < 10000.0, "Arena bounds did not clamp the player"):
			return
		if character_id == "blade_master":
			for next_round in [2, 3]:
				opponent.defeat()
				while arena.current_round < next_round or arena.round_transitioning:
					await process_frame
				opponent = arena.get_node("Opponent")
				if not check(opponent.health == opponent.max_health and arena.get_node("TouchControls/BattleHUD").round_label.text == "ROUND %d / 3" % next_round, "Round transition did not spawn and label the next opponent"):
					return
				if next_round == 2 and not check(opponent.arsenal_mode == &"fists", "Second opponent did not use fists"):
					return
				if next_round == 2 and not check(opponent.anim.sprite_frames == load("res://stick_fig.tres"), "Second opponent did not use its own fighter sprites"):
					return
				if next_round == 3 and not check(opponent.arsenal_mode == &"sword", "Final opponent did not use a sword"):
					return
			opponent.defeat()
			await process_frame
			if not check(arena.get_node("TouchControls/BattleHUD").result_label.text == "VICTORY", "Final round did not finish the match"):
				return
		input_manager.reset_touch_state()
	print("Arena movement, HUD, and round checks passed")
	quit()
