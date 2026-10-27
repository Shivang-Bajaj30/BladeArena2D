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
	game_state.selected_character = "blade_master"
	
	if not check(change_scene_to_file("res://main.tscn") == OK, "Main scene failed to load"):
		return
	
	await process_frame
	await physics_frame
	await process_frame
	
	var arena := current_scene
	while arena.round_transitioning:
		await process_frame
		
	var player = arena.get_node("Player")
	var opponent = arena.get_node("Opponent")
	var background = arena.get_node("Background")
	var ultimate = arena.get_node("GetsugaUltimate")
	
	if not check(is_instance_valid(player) and is_instance_valid(opponent) and is_instance_valid(ultimate), "Nodes missing from scene"):
		return
		
	if not check(not opponent.is_special_paused, "Opponent starts in paused state"):
		return
	
	# Let opponent move a little
	for i in range(10):
		await physics_frame
		await process_frame
		
	# Trigger special attack
	ultimate.activate_ultimate()
	await process_frame
	
	if not check(ultimate.active, "Special attack did not activate"):
		return
	if not check(opponent.is_special_paused, "Opponent is not special paused during special attack"):
		return
	if not check(opponent.velocity == Vector2.ZERO, "Opponent velocity not zero during special attack"):
		return
	if not check(not opponent.anim.is_playing(), "Opponent animation not paused during special attack"):
		return
	
	# Wait until overlay animation finishes
	while ultimate.overlay.visible:
		await process_frame
		
	# Now overlay is done, player is performing in-arena attack animation
	await process_frame
	if not check(player.is_using_ultimate, "Player is not performing special attack animation"):
		return
	if not check(opponent.is_special_paused, "Opponent unpaused too early during arena attack animation"):
		return
	if not check(not opponent.anim.is_playing(), "Opponent anim resumed too early during arena attack animation"):
		return
		
	# Wait until special attack completes
	while ultimate.active or player.is_using_ultimate:
		await process_frame
		
	# Check that normal movement is restored
	await process_frame
	await physics_frame
	await process_frame
	
	if not check(not opponent.is_special_paused, "Opponent did not unpause after special attack"):
		return
	if not opponent.is_defeated:
		if not check(opponent.anim.is_playing(), "Opponent animation did not resume"):
			return
			
	print("Special attack pause and resume checks passed!")
	quit()
