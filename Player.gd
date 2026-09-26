extends CharacterBody2D

# ============================================================
# Player - Movement + Animations + Effects (Touch-Ready)
# ============================================================

@export var walk_speed: float = 200.0
@export var run_speed: float = 520.0
@export var jump_velocity: float = -500.0
@export var gravity: float = 980.0
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.25
@export var air_dash_speed: float = 700.0
@export var air_dash_duration: float = 0.2
@export var slide_speed: float = 500.0
@export var slide_duration: float = 0.5
@export var air_slide_speed: float = 300.0
@export var air_slide_duration: float = 0.6
@export var attack_move_speed: float = 110.0
@export var air_attack_move_speed: float = 80.0
@export var air_attack_duration: float = 0.48
@export var sword_slam_speed: float = 1250.0
@export var air_attack_double_tap_window: float = 0.36
@export var action_buffer_time: float = 0.34
@export var left_hud_safe_margin: float = 470.0
@export var right_hud_safe_margin: float = 450.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_attacking: bool = false
var attack_timer: float = 0.0
var is_dashing: bool = false
var is_air_dashing: bool = false
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_direction: float = 1.0
var is_air_sliding: bool = false
var air_slide_timer: float = 0.0
var facing_right: bool = true
var is_air_attacking: bool = false
var is_sword_slamming: bool = false
var air_attack_timer: float = 0.0
var last_air_attack_press: float = -10.0
var slam_wind_timer: float = 0.0
var base_anim_scale: Vector2
var base_anim_position: Vector2
var transition_tween: Tween
var jump_buffer: float = 0.0
var slide_buffer: float = 0.0
var dodge_buffer: float = 0.0
var attack_buffer: float = 0.0

var ghost_timer: float = 0.0
var ghost_interval: float = 0.06

var dust_timer: float = 0.0
var dust_interval: float = 0.05

var speedline_timer: float = 0.0
var speedline_interval: float = 0.04

func _ready():
	base_anim_scale = anim.scale
	base_anim_position = anim.position
	floor_snap_length = 12.0
	anim.play("idle_sword")

func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor() and not is_air_dashing and not is_sword_slamming:
		velocity.y += gravity * delta
	
	# --- Input (keyboard + touch via InputManager) ---
	var move_x := 0.0
	if InputManager.is_action_pressed("move_right"):
		move_x += 1.0
		facing_right = true
		anim.flip_h = false
	if InputManager.is_action_pressed("move_left"):
		move_x -= 1.0
		facing_right = false
		anim.flip_h = true
	
	# Running: Shift on keyboard, OR joystick pushed near max on touch
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
	var joystick_pushed: bool = InputManager.joystick_active and InputManager.joystick_vector.length() > 0.85
	var is_moving: bool = abs(move_x) > 0.1
	var is_running: bool = (shift_held or joystick_pushed) and is_moving
	var is_airborne: bool = not is_on_floor()

	# Read one-shot actions once so every state sees the same press.
	var jump_pressed := InputManager.is_action_just_pressed("jump")
	var slide_pressed := InputManager.is_action_just_pressed("slide")
	var dodge_pressed := InputManager.is_action_just_pressed("dodge")
	var attack_pressed := InputManager.is_action_just_pressed("attack_light")
	update_action_buffers(delta, jump_pressed, slide_pressed, dodge_pressed, attack_pressed)
	
	# --- Attack timer ---
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			anim.speed_scale = 1.0
	
	# --- Air slide timer ---
	if is_air_sliding:
		air_slide_timer -= delta
		if air_slide_timer <= 0.0 or is_on_floor():
			end_air_slide()

	# --- Sword slam ---
	if is_sword_slamming:
		process_sword_slam(delta)
		return

	# --- Aerial sword slash; a second quick attack converts it to a slam. ---
	if is_air_attacking:
		if attack_pressed:
			attack_buffer = 0.0
			handle_air_attack_press()
			if is_sword_slamming:
				process_sword_slam(delta)
				return
		air_attack_timer -= delta
		velocity.x = move_x * air_attack_move_speed
		move_and_keep_on_screen()
		if is_on_floor() or air_attack_timer <= 0.0:
			is_air_attacking = false
			anim.speed_scale = 1.0
		return
	
	# --- Ground slide ---
	# Keep the move in the regular physics loop so it stays grounded and can
	# immediately follow a changed joystick direction.
	if is_sliding:
		slide_timer -= delta
		if absf(move_x) > 0.1:
			slide_direction = signf(move_x)
		velocity.x = slide_direction * slide_speed
		velocity.y = 0.0
		dust_timer += delta
		if dust_timer >= dust_interval:
			dust_timer = 0.0
			create_dust()
		move_and_keep_on_screen()
		if slide_timer <= 0.0 or not is_on_floor():
			end_slide()
		return

	# --- Locked states ---
	if is_dashing or is_air_dashing:
		move_and_keep_on_screen()
		return
	
	# --- Air sliding ---
	if is_air_sliding:
		velocity.x = (1 if facing_right else -1) * air_slide_speed
		move_and_keep_on_screen()
		return

	# --- Jump ---
	if jump_buffer > 0.0 and is_on_floor():
		jump_buffer = 0.0
		velocity.y = jump_velocity
		play_transition(Vector2(0.9, 1.12), 0.16)
		move_and_keep_on_screen()
		return
	
	# --- Ground Slide ---
	if slide_buffer > 0.0 and is_on_floor() and not is_attacking:
		slide_buffer = 0.0
		do_slide()
		return
	
	# --- Ground Dash ---
	if dodge_buffer > 0.0 and is_on_floor() and not is_attacking:
		dodge_buffer = 0.0
		do_dash()
		return
	
	# --- Air Dash ---
	if dodge_buffer > 0.0 and is_airborne:
		dodge_buffer = 0.0
		do_air_dash()
		return
	
	# --- Ground Attack ---
	if attack_buffer > 0.0 and is_on_floor() and not is_attacking:
		attack_buffer = 0.0
		do_attack()
	
	# --- Aerial sword attack / double-tap sword slam ---
	if attack_pressed and is_airborne:
		attack_buffer = 0.0
		handle_air_attack_press()
		if is_sword_slamming:
			process_sword_slam(delta)
		else:
			velocity.x = move_x * air_attack_move_speed
			move_and_keep_on_screen()
		return
	
	# --- Movement ---
	if is_attacking:
		velocity.x = move_x * attack_move_speed
	elif is_moving:
		if is_running:
			velocity.x = move_x * run_speed
		else:
			velocity.x = move_x * walk_speed
	else:
		velocity.x = 0
	
	# --- Speed lines while running ---
	if is_running and not is_attacking:
		speedline_timer += delta
		if speedline_timer >= speedline_interval:
			speedline_timer = 0.0
			create_speed_line()
	else:
		speedline_timer = 0.0
	
	# --- Ghost trail while running ---
	if is_running and not is_attacking:
		ghost_timer += delta
		if ghost_timer >= ghost_interval:
			ghost_timer = 0.0
			create_ghost()
	else:
		ghost_timer = 0.0
	
	# --- Animation ---
	if not is_attacking:
		if is_moving:
			if is_on_floor():
				if is_running:
					anim.play("run_sword")
				else:
					anim.play("walk_sword")
			else:
				anim.play("sword_jump")
		else:
			if is_on_floor():
				anim.play("idle_sword")
			else:
				anim.play("sword_jump")
	
	move_and_keep_on_screen()

func update_action_buffers(
	delta: float,
	jump_pressed: bool,
	slide_pressed: bool,
	dodge_pressed: bool,
	attack_pressed: bool
) -> void:
	jump_buffer = action_buffer_time if jump_pressed else maxf(0.0, jump_buffer - delta)
	slide_buffer = action_buffer_time if slide_pressed else maxf(0.0, slide_buffer - delta)
	dodge_buffer = action_buffer_time if dodge_pressed else maxf(0.0, dodge_buffer - delta)
	attack_buffer = action_buffer_time if attack_pressed else maxf(0.0, attack_buffer - delta)

func handle_air_attack_press() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - last_air_attack_press <= air_attack_double_tap_window:
		start_sword_slam()
		last_air_attack_press = -10.0
		return
	last_air_attack_press = now
	is_air_attacking = true
	air_attack_timer = air_attack_duration
	anim.speed_scale = 1.15
	anim.play("air_attack_sword")
	play_transition(Vector2(1.08, 0.94), 0.12)

func start_sword_slam() -> void:
	is_air_attacking = false
	is_sword_slamming = true
	slam_wind_timer = 0.0
	velocity = Vector2.ZERO
	anim.speed_scale = 1.45
	anim.play("air_attack_sword")
	play_transition(Vector2(0.88, 1.14), 0.1)

func process_sword_slam(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = sword_slam_speed
	slam_wind_timer += delta
	if slam_wind_timer >= 0.035:
		slam_wind_timer = 0.0
		create_slam_wind()
	move_and_keep_on_screen()
	if is_on_floor():
		finish_sword_slam()

func finish_sword_slam() -> void:
	is_sword_slamming = false
	velocity = Vector2.ZERO
	anim.speed_scale = 1.0
	is_attacking = true
	attack_timer = 0.28
	anim.pause()
	spawn_slam_impact()
	shake_camera(0.22, 13.0)

func play_transition(stretch: Vector2, duration: float) -> void:
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	anim.scale = base_anim_scale * stretch
	transition_tween = create_tween()
	transition_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	transition_tween.tween_property(anim, "scale", base_anim_scale, duration)

# Moves the player and keeps their collision shape inside the visible screen.
# This is shared by every movement state so dashes and slides cannot escape too.
func move_and_keep_on_screen() -> void:
	move_and_slide()

	var visible_rect := get_viewport().get_visible_rect()
	var screen_to_world := get_viewport().get_canvas_transform().affine_inverse()
	var safe_left_x := visible_rect.position.x + left_hud_safe_margin
	var safe_right_x := visible_rect.end.x - right_hud_safe_margin
	var world_left := screen_to_world * Vector2(safe_left_x, visible_rect.position.y)
	var world_right := screen_to_world * Vector2(safe_right_x, visible_rect.position.y)
	var half_width := get_collision_half_width()
	var min_x := minf(world_left.x, world_right.x) + half_width
	var max_x := maxf(world_left.x, world_right.x) - half_width

	var clamped_x := clampf(global_position.x, min_x, max_x)
	if not is_equal_approx(global_position.x, clamped_x):
		global_position.x = clamped_x
		velocity.x = 0.0

func get_collision_half_width() -> float:
	if collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		return rectangle.size.x * absf(collision_shape.global_scale.x) * 0.5
	if collision_shape.shape is CapsuleShape2D:
		var capsule := collision_shape.shape as CapsuleShape2D
		return capsule.radius * absf(collision_shape.global_scale.x)
	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		return circle.radius * absf(collision_shape.global_scale.x)
	return 0.0

# ------------------------------------------------------------
# WHITE SPEED LINES
# ------------------------------------------------------------
func create_speed_line():
	var line := ColorRect.new()
	var length := randf_range(30, 70)
	var thickness := randf_range(1, 3)
	line.size = Vector2(length, thickness)
	line.color = Color(1, 1, 1, randf_range(0.5, 0.9))
	
	var dir := 1 if facing_right else -1
	var offset_x := -dir * randf_range(30, 60)
	var offset_y := randf_range(-40, 40)
	line.global_position = global_position + Vector2(offset_x, offset_y)
	line.rotation_degrees = randf_range(-15, 15)
	line.z_index = 5
	get_parent().add_child(line)
	
	var tween := create_tween()
	tween.parallel().tween_property(line, "position:x", line.position.x - dir * randf_range(60, 120), 0.2)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

# ------------------------------------------------------------
# GROUND ATTACK
# ------------------------------------------------------------
func do_attack():
	is_attacking = true
	anim.speed_scale = 1.08
	anim.play("attack")
	play_transition(Vector2(1.08, 0.96), 0.14)
	
	var anim_length: float = 0.4
	if anim.sprite_frames.has_animation("attack"):
		var frame_count := anim.sprite_frames.get_frame_count("attack")
		var fps := anim.sprite_frames.get_animation_speed("attack") * anim.speed_scale
		if fps > 0:
			anim_length = frame_count / fps
	
	attack_timer = anim_length

# ------------------------------------------------------------
# GROUND DASH
# ------------------------------------------------------------
func do_dash():
	is_dashing = true
	anim.play("dash_sword")
	play_transition(Vector2(1.12, 0.9), 0.12)
	
	var dash_dir := 1 if facing_right else -1
	velocity.x = dash_dir * dash_speed
	velocity.y = 0
	
	var elapsed := 0.0
	while elapsed < dash_duration:
		create_speed_line()
		create_speed_line()
		create_ghost()
		await get_tree().create_timer(0.03).timeout
		elapsed += 0.03
		move_and_keep_on_screen()
	
	velocity.x = 0
	is_dashing = false
	anim.play("idle_sword")

# ------------------------------------------------------------
# AIR DASH
# ------------------------------------------------------------
func do_air_dash():
	is_air_dashing = true
	anim.play("dash_sword")
	anim.speed_scale = 1.3
	
	var dash_dir := 1 if facing_right else -1
	velocity.x = dash_dir * air_dash_speed
	velocity.y = -100
	
	var elapsed := 0.0
	while elapsed < air_dash_duration:
		create_speed_line()
		create_ghost()
		await get_tree().create_timer(0.03).timeout
		elapsed += 0.03
		move_and_keep_on_screen()
	
	anim.speed_scale = 1.0
	is_air_dashing = false

# ------------------------------------------------------------
# GROUND SLIDE
# ------------------------------------------------------------
func do_slide():
	is_sliding = true
	slide_timer = slide_duration
	slide_direction = 1.0 if facing_right else -1.0
	dust_timer = 0.0
	anim.position = base_anim_position
	anim.scale = base_anim_scale
	anim.speed_scale = 1.15
	anim.play("slide_sword")
	velocity = Vector2(slide_direction * slide_speed, 0.0)
	spawn_dust_burst(5)

func end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	slide_timer = 0.0
	velocity.x = 0.0
	anim.speed_scale = 1.0
	anim.scale = base_anim_scale
	anim.position = base_anim_position
	spawn_dust_burst(3)
	anim.play("idle_sword")

# ------------------------------------------------------------
# AIR SLIDE
# ------------------------------------------------------------
func do_air_slide():
	is_air_sliding = true
	air_slide_timer = air_slide_duration
	anim.play("slide_sword")
	anim.scale = base_anim_scale * Vector2(1.1, 0.85)
	anim.position = base_anim_position
	velocity.x = (1 if facing_right else -1) * air_slide_speed

func end_air_slide():
	is_air_sliding = false
	anim.scale = base_anim_scale
	anim.position = base_anim_position
	anim.play("idle_sword")
	spawn_dust_burst(6)

# ------------------------------------------------------------
# SWORD SLAM EFFECTS
# ------------------------------------------------------------
func create_slam_wind() -> void:
	var streak := ColorRect.new()
	streak.size = Vector2(randf_range(3.0, 6.0), randf_range(35.0, 75.0))
	streak.color = Color(0.8, 0.9, 1.0, randf_range(0.35, 0.7))
	streak.global_position = global_position + Vector2(
		randf_range(-75.0, 75.0),
		randf_range(-95.0, 10.0)
	)
	streak.rotation = randf_range(-0.12, 0.12)
	streak.z_index = 4
	get_parent().add_child(streak)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(streak, "position:y", streak.position.y - 90.0, 0.16)
	tween.tween_property(streak, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(streak.queue_free)

func spawn_slam_impact() -> void:
	spawn_dust_burst(12)
	create_impact_shockwave()
	for i in range(14):
		create_slam_stone()

func create_impact_shockwave() -> void:
	var wave := Line2D.new()
	wave.width = 7.0
	wave.default_color = Color(0.85, 0.9, 1.0, 0.9)
	wave.points = PackedVector2Array([Vector2(-28, 0), Vector2(28, 0)])
	wave.global_position = global_position + Vector2(0, 38)
	wave.z_index = 7
	get_parent().add_child(wave)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(7.0, 1.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(wave.queue_free)

func create_slam_stone() -> void:
	var stone := Polygon2D.new()
	var size := randf_range(5.0, 13.0)
	stone.polygon = PackedVector2Array([
		Vector2(-size, size * 0.4),
		Vector2(-size * 0.45, -size),
		Vector2(size * 0.75, -size * 0.65),
		Vector2(size, size * 0.6)
	])
	stone.color = Color(
		randf_range(0.24, 0.38),
		randf_range(0.19, 0.29),
		randf_range(0.12, 0.2),
		1.0
	)
	stone.global_position = global_position + Vector2(randf_range(-32.0, 32.0), 34.0)
	stone.z_index = 8
	get_parent().add_child(stone)

	var target := stone.position + Vector2(randf_range(-125.0, 125.0), randf_range(-125.0, -55.0))
	var duration := randf_range(0.38, 0.62)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(stone, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(stone, "rotation", randf_range(-5.0, 5.0), duration)
	tween.tween_property(stone, "modulate:a", 0.0, duration).set_delay(duration * 0.55)
	tween.chain().tween_callback(stone.queue_free)

func shake_camera(duration: float, strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var elapsed := 0.0
	while elapsed < duration:
		camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.55, strength * 0.55)
		)
		await get_tree().create_timer(0.025).timeout
		elapsed += 0.025
		strength *= 0.82
	camera.offset = Vector2.ZERO

# ------------------------------------------------------------
# DUST
# ------------------------------------------------------------
func create_dust():
	var dust := ColorRect.new()
	dust.color = Color(
		randf_range(0.6, 0.8),
		randf_range(0.5, 0.6),
		randf_range(0.3, 0.4),
		randf_range(0.7, 0.9)
	)
	var size_x := randf_range(8, 16)
	var size_y := randf_range(4, 8)
	dust.size = Vector2(size_x, size_y)
	
	var offset_x := -40 if facing_right else 40
	var offset_y := 30
	dust.global_position = global_position + Vector2(offset_x, offset_y)
	dust.z_index = 6
	get_parent().add_child(dust)
	
	var dir := 1 if facing_right else -1
	var vel_x := -dir * randf_range(30, 80)
	var vel_y := randf_range(-60, -20)
	
	var tween := create_tween()
	tween.parallel().tween_property(dust, "position", dust.position + Vector2(vel_x * 0.4, vel_y * 0.4), 0.4)
	tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(dust, "scale", Vector2(1.5, 1.5), 0.4)
	tween.tween_callback(dust.queue_free)

func spawn_dust_burst(count: int):
	for i in range(count):
		create_dust()
		await get_tree().create_timer(0.02).timeout

# ------------------------------------------------------------
# GHOST TRAIL
# ------------------------------------------------------------
func create_ghost():
	var ghost: AnimatedSprite2D = anim.duplicate()
	get_parent().add_child(ghost)
	ghost.global_transform = anim.global_transform
	ghost.modulate = Color(0.6, 0.6, 1.0, 0.5)
	ghost.z_index = 3
	ghost.pause()
	
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
