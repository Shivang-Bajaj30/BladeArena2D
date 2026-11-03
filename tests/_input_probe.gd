extends Node

# Regression probe for:
#  1. Fighters spawn/rest exactly on the arena floor.
#  2. The joystick keeps tracking a fast, far flick (no "slipping").
#  3. Rapid attack taps chain combo steps while the joystick is held.

var fails := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		fails += 1
		print("FAIL: ", label)

func push_touch(pos: Vector2, pressed: bool, index: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	get_tree().root.push_input(ev, true)

func push_drag(pos: Vector2, index: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	get_tree().root.push_input(ev, true)

func _ready() -> void:
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	GameState.selected_background = "cyberpunk"
	GameState.selected_character = "blade_master"

	var arena = load("res://main.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame

	var controls = arena.get_node("TouchControls")
	var joystick = controls.get_node("Joystick")
	var attack = controls.get_node("ActionButtons/Attack")
	var player = arena.get_node("Player")
	var opponent = arena.get_node("Opponent")

	var floor_top = arena._floor_top_y()
	print("floor_top=", floor_top)

	# The painted ground line of the selected background must sit on the floor
	# as well, otherwise the fighters still read as floating in front of the art.
	var bg = arena.get_node("Background")
	var bg_sprite: Sprite2D = null
	for child in bg.get_children():
		if child is Sprite2D and child.texture:
			bg_sprite = child
			break
	var bg_data = GameState.get_background_data(GameState.selected_background)
	var ground_ratio: float = float(bg_data["ground_ratio"])
	var image_h: float = bg_sprite.texture.get_height() * absf(bg_sprite.global_scale.y)
	var painted_ground_y: float = bg_sprite.global_position.y - image_h * 0.5 + ground_ratio * image_h
	# The artwork is deliberately dropped a touch below the collider so the
	# fighters read as standing on top of the land instead of sunk into it.
	check(absf(painted_ground_y - (floor_top + 20.0)) < 0.5,
		"painted background ground sits just below the feet (%.2f vs %.2f)" % [painted_ground_y, floor_top + 20.0])

	# ---- 1. Standing on the floor, even before physics runs ----
	check(absf(player.global_position.y - arena._fighter_ground_y(player)) < 0.01,
		"player spawns at floor-aligned height (%s)" % player.global_position)
	check(absf(opponent.global_position.y - arena._fighter_ground_y(opponent)) < 0.01,
		"opponent spawns at floor-aligned height (%s)" % opponent.global_position)

	while arena.round_transitioning:
		await get_tree().process_frame
	await get_tree().physics_frame
	check(absf(player.global_position.y - arena._fighter_ground_y(player)) < 0.5,
		"player stays grounded after FIGHT (%s)" % player.global_position)

	# Keep the duel still so the probe only measures input.
	opponent.set_physics_process(false)
	opponent.global_position = Vector2(1500, 600)

	# ---- 2. Far, fast joystick flick ----
	var stick_center: Vector2 = (joystick as Control).get_global_rect().get_center()
	print("joystick center=", stick_center)
	push_touch(stick_center, true, 0)
	await get_tree().physics_frame
	# 500 px to the right in one drag event: far beyond the old 240 px gate and
	# past the screen midline, but still a perfectly legitimate flick.
	push_drag(stick_center + Vector2(500.0, 0.0), 0)
	await get_tree().physics_frame
	print("joystick vector after far flick=", InputManager.joystick_vector)
	check(InputManager.joystick_active and InputManager.joystick_vector.x > 0.9,
		"joystick tracks a fast 500 px flick instead of slipping")
	check(player.facing_right, "player faces the flick direction")

	# A second finger tapping/dragging on the right side (where the action
	# buttons live) must never move, steal or release the stick.
	push_touch(Vector2(1100, 1000), true, 2)
	await get_tree().physics_frame
	push_drag(Vector2(1120, 1010), 2)
	await get_tree().physics_frame
	check(InputManager.joystick_active and InputManager.joystick_vector.x > 0.9,
		"a second finger on the action side never disturbs the stick")
	push_touch(Vector2(1120, 1010), false, 2)
	await get_tree().physics_frame

	# ---- 3. Rapid attack taps while the stick is held ----
	var attack_xf = attack.get_global_transform_with_canvas()
	var attack_center: Vector2 = attack_xf * (attack.texture_normal.get_size() * 0.5)
	print("attack center=", attack_center, " size=", attack.texture_normal.get_size())

	var max_combo := 0
	var taps := 0
	for i in range(6):
		var index := 10 + i
		push_touch(attack_center, true, index)
		await get_tree().physics_frame
		await get_tree().process_frame
		taps += 1
		max_combo = maxi(max_combo, player.combo_step)
		push_touch(attack_center, false, index)
		await get_tree().physics_frame
		max_combo = maxi(max_combo, player.combo_step)
		# Watch a few frames so a queued swing can start.
		for f in range(4):
			await get_tree().physics_frame
			max_combo = maxi(max_combo, player.combo_step)
		if not InputManager.joystick_active:
			break

	print("taps=", taps, " max_combo_step=", max_combo)
	check(max_combo >= 3, "rapid taps chained the full 3-step grounded combo")
	check(InputManager.joystick_active and InputManager.joystick_vector.x > 0.9,
		"joystick keeps its direction through the combo taps")

	# ---- 4. Held action button: stays clicked, does not disturb the stick ----
	push_touch(attack_center, true, 20)
	await get_tree().physics_frame
	check(InputManager.action_pressed["attack_light"], "holding the attack button keeps it pressed")
	# Slide the action thumb far off the button; it must remain held until it lifts.
	push_drag(attack_center + Vector2(260.0, 40.0), 20)
	await get_tree().physics_frame
	check(InputManager.action_pressed["attack_light"],
		"an action touch stays pressed while held even if it slides off the button")
	check(InputManager.joystick_active,
		"holding an action button never releases the joystick")
	# Move the stick finger far left: the stick must keep tracking its owner.
	push_drag(stick_center + Vector2(-500.0, 0.0), 0)
	await get_tree().physics_frame
	check(InputManager.joystick_active and InputManager.joystick_vector.x < -0.9,
		"joystick keeps tracking while the action button is held")
	push_touch(attack_center, false, 20)
	await get_tree().physics_frame
	check(not InputManager.action_pressed["attack_light"],
		"an action button releases exactly when its finger lifts")

	push_touch(stick_center, false, 0)
	await get_tree().physics_frame
	check(not InputManager.joystick_active, "releasing the stick stops movement")

	# ---- 5. A dropped release must not swallow the next tap ----
	InputManager.reset_touch_state()
	push_touch(attack_center, true, 9)
	push_touch(attack_center, true, 9) # same index down again: release was lost
	print("queued attacks after duplicate press=", InputManager.action_press_count["attack_light"])
	check(InputManager.action_press_count["attack_light"] >= 2,
		"a press after a dropped release still queues a tap")
	push_touch(attack_center, false, 9)

	# ---- 6. Side walls are hard boundaries ----
	var limits: Vector2 = player.get_arena_center_limits()
	print("arena center limits=", limits)
	check(limits.x > -1100.0 and limits.y < 1100.0, "wall limits were derived from the side-wall sprites")
	player.global_position.x = 5000.0
	player.move_and_keep_on_screen()
	check(player.global_position.x <= limits.y + 0.01,
		"player cannot pass the right wall (%s)" % player.global_position.x)
	player.global_position.x = -5000.0
	player.move_and_keep_on_screen()
	check(player.global_position.x >= limits.x - 0.01,
		"player cannot pass the left wall (%s)" % player.global_position.x)
	opponent.global_position.x = 5000.0
	opponent.move_and_clamp()
	check(opponent.global_position.x <= opponent.get_arena_center_limits().y + 0.01,
		"opponent cannot pass the right wall (%s)" % opponent.global_position.x)

	print("RESULT: ", "FAIL" if fails > 0 else "ALL PASS")
	get_tree().quit(1 if fails > 0 else 0)
