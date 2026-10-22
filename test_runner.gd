extends Node

func _ready() -> void:
	print("==================================================")
	print("STARTING BLADE ARENA 2D COMPREHENSIVE VERIFICATION")
	print("==================================================")
	
	var results := {"fails": 0, "passes": 0}
	
	var assert_test = func(condition: bool, test_name: String):
		if condition:
			print("  [PASS] " + test_name)
			results["passes"] += 1
		else:
			print("  [FAIL] " + test_name)
			results["fails"] += 1
	
	# Scenario 6 & 7 & 8: Historical records & statistics accuracy & persistence & no double counting
	print("\n--- Testing Requirements 5 & 6 & 7: Win/Loss Records & Stats Accuracy ---")
	GameState.reset_records()
	assert_test.call(GameState.total_games == 0, "Initial total_games == 0")
	assert_test.call(GameState.total_wins == 0, "Initial total_wins == 0")
	assert_test.call(GameState.total_losses == 0, "Initial total_losses == 0")
	assert_test.call(GameState.get_win_rate() == 0.0, "Initial win rate == 0.0%")
	assert_test.call(GameState.get_loss_rate() == 0.0, "Initial loss rate == 0.0%")
	
	# Simulate Match 1: Win
	GameState.record_match_result(true)
	assert_test.call(GameState.total_games == 1 and GameState.total_wins == 1, "Match 1 Win: total_games=1, total_wins=1")
	assert_test.call(GameState.current_streak == 1 and GameState.best_win_streak == 1, "Streak is 1 win, best is 1")
	assert_test.call(is_equal_approx(GameState.get_win_rate(), 100.0), "Win rate is 100.0%")
	assert_test.call(is_equal_approx(GameState.get_loss_rate(), 0.0), "Loss rate is 0.0%")
	
	# Simulate Match 2: Win
	GameState.record_match_result(true)
	assert_test.call(GameState.total_games == 2 and GameState.total_wins == 2, "Match 2 Win: total_games=2, total_wins=2")
	assert_test.call(GameState.current_streak == 2 and GameState.best_win_streak == 2, "Streak is 2 wins, best is 2")
	
	# Simulate Match 3: Loss
	GameState.record_match_result(false)
	assert_test.call(GameState.total_games == 3 and GameState.total_losses == 1, "Match 3 Loss: total_games=3, total_losses=1")
	assert_test.call(GameState.current_streak == -1 and GameState.best_win_streak == 2, "Streak is -1 loss, best remains 2")
	assert_test.call(is_equal_approx(GameState.get_win_rate(), 66.66666), "Win rate is 66.7%")
	assert_test.call(is_equal_approx(GameState.get_loss_rate(), 33.33333), "Loss rate is 33.3%")
	
	# Save and verify reload
	GameState.save_settings()
	var prev_g = GameState.total_games
	var prev_w = GameState.total_wins
	var prev_l = GameState.total_losses
	var prev_s = GameState.current_streak
	var prev_b = GameState.best_win_streak
	GameState.load_settings()
	assert_test.call(GameState.total_games == prev_g and GameState.total_wins == prev_w and GameState.total_losses == prev_l, "Records persist across reloads from disk")
	assert_test.call(GameState.current_streak == prev_s and GameState.best_win_streak == prev_b, "Streaks persist across reloads from disk")
	
	# Requirement 1 & 5: Menu UI Enlargement & Records View
	print("\n--- Testing Requirement 1 & 5: Enlarged UI & Records Screen ---")
	var menu_scene = load("res://menu.tscn")
	assert_test.call(menu_scene != null, "menu.tscn loaded successfully")
	var menu = menu_scene.instantiate()
	add_child(menu)
	
	var records_btn: Button = menu.get_node_or_null("Views/HomeView/MenuContainer/RecordsBtn")
	assert_test.call(records_btn != null, "RecordsBtn exists in HomeView")
	assert_test.call(records_btn.custom_minimum_size.x >= 400.0, "Records button is enlarged (>= 400px)")
	
	var play_btn: Button = menu.get_node_or_null("Views/HomeView/MenuContainer/PlayBtn")
	assert_test.call(play_btn.custom_minimum_size.x >= 400.0, "Play button is enlarged (>= 400px)")
	
	var records_view: Control = menu.get_node_or_null("Views/RecordsView")
	assert_test.call(records_view != null, "RecordsView screen exists")
	
	# Open Records
	records_btn.emit_signal("pressed")
	assert_test.call(menu.current_state == menu.MenuState.RECORDS, "Menu state is RECORDS")
	assert_test.call(records_view.visible == true, "Records screen is visible")
	
	# Check values on Records screen
	var games_lbl: Label = records_view.get_node("Panel/VBox/Grid/CardGames/VBox/Value")
	var wins_lbl: Label = records_view.get_node("Panel/VBox/Grid/CardWins/VBox/Value")
	var losses_lbl: Label = records_view.get_node("Panel/VBox/Grid/CardLosses/VBox/Value")
	var win_rate_lbl: Label = records_view.get_node("Panel/VBox/Grid/CardWinRate/VBox/Value")
	var loss_rate_lbl: Label = records_view.get_node("Panel/VBox/Grid/CardLossRate/VBox/Value")
	var streak_lbl: Label = records_view.get_node("Panel/VBox/Grid/CardStreak/VBox/Value")
	assert_test.call(games_lbl.text == str(GameState.total_games), "CardGames label shows correct total")
	assert_test.call(wins_lbl.text == str(GameState.total_wins), "CardWins label shows correct wins")
	assert_test.call(losses_lbl.text == str(GameState.total_losses), "CardLosses label shows correct losses")
	assert_test.call(win_rate_lbl.text == "%.1f%%" % GameState.get_win_rate(), "CardWinRate label is accurate")
	assert_test.call(loss_rate_lbl.text == "%.1f%%" % GameState.get_loss_rate(), "CardLossRate label is accurate")
	assert_test.call(streak_lbl.text != "", "CardStreak label shows active streak info")
	
	# Back to Home
	var back_btn: Button = records_view.get_node("BackBtn")
	back_btn.emit_signal("pressed")
	assert_test.call(menu.current_state == menu.MenuState.HOME, "Back button returns to Home state")
	assert_test.call(menu.get_node("Views/HomeView").visible == true, "HomeView is visible")
	
	menu.queue_free()
	
	# Requirement 4: Pause System
	print("\n--- Testing Requirement 4: Centered Pause System & Activity Halt ---")
	var main_scene = load("res://main.tscn")
	assert_test.call(main_scene != null, "main.tscn loaded successfully")
	var main_game = main_scene.instantiate()
	add_child(main_game)
	
	var player = main_game.get_node_or_null("Player")
	var enemy = main_game.get_node_or_null("Enemy")
	assert_test.call(player != null, "Player exists in main arena")
	assert_test.call(enemy != null, "Enemy exists in main arena")
	
	# Test Pause
	assert_test.call(get_tree().paused == false, "Gameplay running initially")
	main_game.toggle_pause()
	assert_test.call(get_tree().paused == true, "All gameplay stopped (get_tree().paused == true)")
	assert_test.call(main_game.pause_canvas.visible == true, "Pause menu overlay visible")
	assert_test.call(main_game.pause_panel.anchors_preset == Control.PRESET_CENTER, "Pause menu appears exactly in the center of the screen")
	
	# Resume
	main_game.toggle_pause()
	assert_test.call(get_tree().paused == false, "Gameplay resumed (get_tree().paused == false)")
	assert_test.call(main_game.pause_canvas.visible == false, "Pause menu overlay hidden on resume")
	
	# Requirement 3 & 8: Lose any round -> immediate defeat -> no round 2 -> record loss without double count
	print("\n--- Testing Requirement 3 & 8: Defeat on Any Round & Anti-Duplicate Recording ---")
	var pre_losses = GameState.total_losses
	player.take_damage(200.0)
	assert_test.call(player.current_health <= 0.0, "Player defeated")
	assert_test.call(main_game.match_ended == true, "Match ended immediately upon losing round")
	assert_test.call(main_game.is_round_active == false, "Round progression stopped")
	assert_test.call(GameState.total_losses == pre_losses + 1, "Loss recorded in persistent statistics")
	
	# Anti-duplicate test: repeated damage or death signals
	player.take_damage(100.0)
	main_game._on_player_died()
	assert_test.call(GameState.total_losses == pre_losses + 1, "Loss NOT counted twice for same game session")
	
	main_game.queue_free()
	
	# Requirement 2 & 8: Win all rounds -> Victory -> record win without double count
	print("\n--- Testing Requirement 2 & 8: Win All Rounds -> Victory & Single Count ---")
	var main_game2 = main_scene.instantiate()
	add_child(main_game2)
	
	var pre_wins = GameState.total_wins
	var enemy2 = main_game2.get_node("Enemy")
	
	# Win Round 1
	enemy2.take_damage(200.0)
	assert_test.call(main_game2.player_wins == 1, "Player won Round 1")
	assert_test.call(main_game2.match_ended == false, "Match not yet ended (requires winning all rounds)")
	assert_test.call(GameState.total_wins == pre_wins, "Win not yet recorded (round 1 of 2)")
	
	# Advance to Round 2
	main_game2.current_round = 2
	main_game2.is_round_active = true
	enemy2.current_health = 100.0
	
	# Win Round 2 (All rounds won!)
	enemy2.take_damage(200.0)
	assert_test.call(main_game2.player_wins == 2, "Player won Round 2 (all required rounds won)")
	assert_test.call(main_game2.match_ended == true, "Match ended with full victory")
	assert_test.call(GameState.total_wins == pre_wins + 1, "Win recorded in persistent statistics")
	
	# Anti-duplicate test
	enemy2.take_damage(100.0)
	main_game2._on_enemy_died()
	assert_test.call(GameState.total_wins == pre_wins + 1, "Win NOT counted twice for same game session")
	
	main_game2.queue_free()
	
	print("\n==================================================")
	if results["fails"] > 0:
		print("FAILED: %d tests failed, %d passed." % [results["fails"], results["passes"]])
		get_tree().quit(1)
	else:
		print("ALL %d VERIFICATION TESTS PASSED SUCCESSFULLY!" % results["passes"])
		print("==================================================")
		get_tree().quit(0)
