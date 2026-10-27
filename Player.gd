extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(fighter: Node)

# ============================================================
# Player - Movement + Animations + Effects (Touch-Ready)
# ============================================================

@export var walk_speed: float = 255.0
@export var run_speed: float = 625.0
@export var jump_velocity: float = -500.0
@export var double_jump_velocity: float = -470.0
@export var max_jump_count: int = 2
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
@export var left_hud_safe_margin: float = 80.0
@export var right_hud_safe_margin: float = 80.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_attacking: bool = false
var attack_timer: float = 0.0
var was_running: bool = false
var dash_damage_grace: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: float = 1.0
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
var slam_sound_played: bool = false
var air_attack_sound: AudioStreamPlayer
var base_anim_scale: Vector2
var base_anim_position: Vector2
var transition_tween: Tween
var jump_buffer: float = 0.0
var jumps_used: int = 0
var slide_buffer: float = 0.0
var dodge_buffer: float = 0.0
var attack_buffer: float = 0.0
var arsenal_mode: StringName = &"sword"
var health: float
var is_defeated: bool = false
var hit_invulnerability: float = 0.0
var attack_serial: int = 0
var air_kick_vx: float = 0.0
var is_using_ultimate: bool = false

var ghost_timer: float = 0.0
var ghost_interval: float = 0.06

var dust_timer: float = 0.0
var dust_interval: float = 0.05

var speedline_timer: float = 0.0
var speedline_interval: float = 0.04

var hitbox: Area2D
var hitbox_shape: CollisionShape2D

func _ready():
	add_to_group("fighters")
	add_to_group("player_fighter")
	# Keep the character chosen in the incoming menu.
	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		var char_data: Dictionary = game_state.get_character_data(game_state.selected_character)
		if not char_data.is_empty() and ResourceLoader.exists(char_data["frames_path"]):
			anim.sprite_frames = load(char_data["frames_path"])
	
	base_anim_scale = anim.scale
	base_anim_position = anim.position
	health = max_health
	floor_snap_length = 12.0
	
	if anim.sprite_frames.has_animation("idle_sword"):
		anim.play("idle_sword")
	elif anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
	setup_hitbox()

func setup_hitbox():
	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2 # Enemy hurtbox layer
	add_child(hitbox)
	
	hitbox_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(100, 90)
	hitbox_shape.shape = rect
	hitbox_shape.position = Vector2(60, 0)
	hitbox_shape.disabled = true
	hitbox.add_child(hitbox_shape)
	
	hitbox.area_entered.connect(_on_hitbox_hit)

func _on_hitbox_hit(area: Area2D):
	if area.name == "Hurtbox" and area.get_parent().has_method("take_damage"):
		var dmg = 10 + (combo_step * 5)
		var force = 150 + (combo_step * 100)
		var dir = 1.0 if facing_right else -1.0
		area.get_parent().take_damage(dmg, dir, force)
		if combo_step < 3:
			hit_stop(0.03)

func setup_hurtbox():
	hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 1 # Player hurtbox layer
	hurtbox.collision_mask = 0
	add_child(hurtbox)
	
	hurtbox_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(50, 85)
	hurtbox_shape.shape = rect
	hurtbox_shape.position = Vector2(0, 0)
	hurtbox.add_child(hurtbox_shape)

func take_damage(dmg: float, dir: float = 0.0, force: float = 0.0) -> void:
	if is_invulnerable or current_health <= 0.0:
		return
	
	current_health = max(0.0, current_health - dmg)
	health_changed.emit(current_health, max_health)
	
	if force > 0.0 and dir != 0.0:
		velocity.x = dir * force
		velocity.y = -force * 0.25
	
	# Damage flash
	var orig_mod = anim.modulate
	anim.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tw = create_tween()
	tw.tween_property(anim, "modulate", orig_mod, 0.15)
	
	shake_camera(0.12, 8.0)
	AudioManager.play_hit()
	
	if current_health <= 0.0:
		die()
	else:
		is_invulnerable = true
		get_tree().create_timer(0.2).timeout.connect(func(): is_invulnerable = false)

func die() -> void:
	if current_health > 0.0:
		current_health = 0.0
		health_changed.emit(current_health, max_health)
	is_attacking = false
	if hitbox_shape:
		hitbox_shape.disabled = true
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(0.9, 0.2, 0.2, 0.75), 0.3)
	player_died.emit()

func reset_for_round(start_pos: Vector2, look_right: bool = true) -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	is_invulnerable = false
	is_attacking = false
	is_dashing = false
	is_air_dashing = false
	is_sliding = false
	is_air_sliding = false
	is_air_attacking = false
	is_sword_slamming = false
	velocity = Vector2.ZERO
	global_position = start_pos
	facing_right = look_right
	anim.flip_h = not look_right
	anim.modulate = Color(1, 1, 1, 1)
	if hitbox_shape:
		hitbox_shape.disabled = true
	play_character_anim("idle")

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
	var run_started: bool = is_running and not was_running
	was_running = is_running
	var is_airborne: bool = not is_on_floor()

	# Read one-shot actions once so every state sees the same press.
	var jump_pressed := InputManager.is_action_just_pressed("jump")
	var slide_pressed := InputManager.is_action_just_pressed("slide")
	var dodge_pressed := InputManager.is_action_just_pressed("dodge")
	var attack_pressed := InputManager.is_action_just_pressed("attack_light")
	update_action_buffers(delta, jump_pressed, slide_pressed, dodge_pressed, attack_pressed)
	if is_attacking and is_on_floor() and run_started:
		cancel_ground_attack()
	
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

	# --- Ground dash timer ---
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0
		speedline_timer += delta
		if speedline_timer >= speedline_interval:
			speedline_timer = 0.0
			create_speed_line()
			create_ghost()
		move_and_keep_on_screen()
		if dash_timer <= 0.0:
			end_dash()
		return

	# --- Air dash timer ---
	if is_air_dashing:
		air_dash_timer -= delta
		velocity.x = dash_direction * air_dash_speed
		velocity.y = 0.0
		speedline_timer += delta
		if speedline_timer >= speedline_interval:
			speedline_timer = 0.0
			create_speed_line()
			create_ghost()
		move_and_keep_on_screen()
		if air_dash_timer <= 0.0 or is_on_floor():
			end_air_dash()
		return

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
		# In fist mode, sustain the kick speed captured at launch; otherwise use the
		# slow air-attack drift for sword aerial slashes.
		velocity.x = air_kick_vx if arsenal_mode == &"fists" else move_x * air_attack_move_speed
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
		velocity.x = (1.0 if facing_right else -1.0) * air_slide_speed
		move_and_keep_on_screen()
		return

	# --- Jump / double jump ---
	# Every new tap consumes exactly one jump. Landing resets the counter above,
	# so a second quick tap while airborne always becomes the double jump.
	var can_jump_from_floor := is_on_floor()
	var can_double_jump := not can_jump_from_floor and jumps_used < max_jump_count
	if jump_buffer > 0.0 and (can_jump_from_floor or can_double_jump):
		jump_buffer = 0.0
		jumps_used = 1 if can_jump_from_floor else jumps_used + 1
		# Cancel an attack so the second jump is never swallowed by a combo.
		if is_attacking:
			cancel_ground_attack()
		velocity.y = jump_velocity if jumps_used == 1 else double_jump_velocity
		anim.stop()
		anim.play(get_mode_animation("jump"))
		if jumps_used == 2:
			spawn_double_jump_burst()
			play_transition(Vector2(1.14, 0.88), 0.14)
		else:
			play_transition(Vector2(0.9, 1.12), 0.16)
		move_and_keep_on_screen()
		return
	
	# --- Ground Slide ---
	# Attack no longer blocks slide — slide immediately cancels the attack state.
	if slide_buffer > 0.0 and is_on_floor():
		slide_buffer = 0.0
		if is_attacking:
			cancel_ground_attack()
		do_slide()
		return

	# --- Air Slide ---
	if slide_buffer > 0.0 and is_airborne and not is_attacking:
		slide_buffer = 0.0
		do_air_slide()
		return
	
	# --- Ground Dash ---
	# Same: dash immediately cancels any ongoing attack.
	if dodge_buffer > 0.0 and is_on_floor():
		dodge_buffer = 0.0
		if is_attacking:
			cancel_ground_attack()
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
			velocity.x = air_kick_vx if arsenal_mode == &"fists" else move_x * air_attack_move_speed
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

func cancel_ground_attack() -> void:
	is_attacking = false
	attack_timer = 0.0
	attack_buffer = 0.0
	attack_serial += 1
	anim.speed_scale = 1.0

func get_mode_animation(action: String) -> StringName:
	var sword_animations := {
		"idle": &"idle_sword",
		"walk": &"walk_sword",
		"run": &"run_sword",
		"jump": &"sword_jump",
		"dash": &"dash_sword",
		"slide": &"slide_sword",
		"attack": &"attack",
		"air_attack": &"air_attack_sword",
	}
	var fist_animations := {
		"idle": &"idle",
		"walk": &"walk",
		"run": &"run",
		"jump": &"jump",
		"dash": &"dash",
		"slide": &"slide",
		"attack": &"punch_combo",
		"air_attack": &"air_attack",
	}
	var requested: StringName = sword_animations.get(action, &"idle_sword") if arsenal_mode == &"sword" else fist_animations.get(action, &"idle")
	if anim.sprite_frames.has_animation(requested):
		return requested
	var fallbacks := {
		"idle": [&"idle"],
		"walk": [&"walk"],
		"run": [&"run"],
		"jump": [&"jump"],
		"dash": [&"dash"],
		"slide": [&"slide"],
		"attack": [&"attack_combo", &"punch_combo", &"attack"],
		"air_attack": [&"air_attack", &"jump"],
	}
	for candidate in fallbacks.get(action, [&"idle"]):
		if anim.sprite_frames.has_animation(candidate):
			return candidate
	return &"idle"

func set_arsenal(mode: StringName, with_smoke: bool = true) -> void:
	if mode != &"sword" and mode != &"fists":
		return
	if arsenal_mode == mode:
		return
	arsenal_mode = mode
	attack_serial += 1
	is_attacking = false
	is_air_attacking = false
	is_sword_slamming = false
	anim.speed_scale = 1.0
	anim.scale = base_anim_scale
	anim.position = base_anim_position
	if with_smoke:
		spawn_transform_smoke()
		play_transition(Vector2(0.72, 1.2), 0.22)
	anim.play(get_mode_animation("idle"))

func can_use_getsuga() -> bool:
	return arsenal_mode == &"sword" and anim.sprite_frames.has_animation(&"attack") and is_on_floor() and not is_defeated and not is_attacking and not is_dashing and not is_sliding and not is_using_ultimate

func perform_getsuga_attack() -> void:
	if not can_use_getsuga():
		return
	is_using_ultimate = true
	attack_serial += 1
	velocity = Vector2.ZERO
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	anim.scale = base_anim_scale
	anim.position = base_anim_position
	# The cinematic already owns the downward cut (attack frames 7-10). Back in
	# the arena, resume from the sword-raised pose and release from the first
	# forward arc instead of replaying that downward animation.
	anim.speed_scale = 0.0
	anim.play(get_mode_animation("attack"))
	anim.pause()
	anim.frame = 1
	await get_tree().create_timer(0.16).timeout
	if not is_using_ultimate or is_defeated:
		return
	anim.frame = 2
	spawn_getsuga_wave()
	# Fire the heavy impact exactly when the Getsuga leaves the sword. A slightly
	# lowered pitch gives the launch more weight without delaying the transient.
	play_one_shot_sound("res://effects/sounds/getsuga_unleash.mp3", 0.92, -3.0)
	shake_camera(0.24, 15.0)
	# Hold the release silhouette, then skip the rest of the circular combo and
	# settle directly into its final recovery poses.
	await get_tree().create_timer(0.18).timeout
	if not is_using_ultimate or is_defeated:
		return
	anim.frame = 9
	await get_tree().create_timer(0.12).timeout
	if not is_using_ultimate or is_defeated:
		return
	anim.frame = 10
	await get_tree().create_timer(0.10).timeout
	if is_defeated:
		return
	is_using_ultimate = false
	anim.speed_scale = 1.0
	anim.play(get_mode_animation("idle"))

func spawn_getsuga_wave() -> void:
	var wave_script = preload("res://GetsugaWave.gd")
	var wave: Area2D = wave_script.new()
	var direction := 1.0 if facing_right else -1.0
	wave.configure(direction, self, getsuga_damage)
	get_parent().add_child(wave)
	wave.global_position = global_position + Vector2(direction * 145.0, -125.0)

func resolve_attack_after_delay(serial: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if serial != attack_serial or is_defeated:
		return
	var damage := sword_damage if arsenal_mode == &"sword" else fist_damage
	var attack_range := sword_attack_range if arsenal_mode == &"sword" else fist_attack_range
	apply_attack_hit(damage, attack_range)

func apply_attack_hit(damage: float, attack_range: float) -> void:
	var closest: Node2D
	var closest_distance := INF
	var direction := 1.0 if facing_right else -1.0
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter == self or not fighter is Node2D:
			continue
		if fighter.get("is_defeated") == true:
			continue
		var other := fighter as Node2D
		var offset := other.global_position - global_position
		if offset.x * direction < -20.0:
			continue
		var distance := absf(offset.x)
		if distance <= attack_range and absf(offset.y) < 125.0 and distance < closest_distance:
			closest = other
			closest_distance = distance
	if closest and closest.has_method("apply_damage"):
		closest.apply_damage(damage, self, direction * 250.0)

func resolve_sword_combo_hits(serial: int) -> void:
	var frame_count := anim.sprite_frames.get_frame_count(get_mode_animation("attack"))
	var impact_frames := [mini(2, frame_count - 1), mini(5, frame_count - 1), mini(8, frame_count - 1)]
	var damage_per_strike := sword_damage / float(impact_frames.size())
	for strike_index in range(impact_frames.size()):
		while serial == attack_serial and anim.animation == get_mode_animation("attack") and anim.frame < impact_frames[strike_index]:
			await anim.frame_changed
		if serial != attack_serial or arsenal_mode != &"sword" or is_defeated:
			return
		apply_sword_strike_hit(strike_index, damage_per_strike)

func apply_sword_strike_hit(strike_index: int, damage: float) -> void:
	# These swept rectangles follow the visible blade arcs in sword_combo. They
	# cover the hilt-to-tip path, so contact at either end of the sword counts.
	var centers := [Vector2(23.0, -142.0), Vector2(-13.0, -118.0), Vector2(42.0, -155.0)]
	var sizes := [Vector2(300.0, 245.0), Vector2(380.0, 190.0), Vector2(315.0, 250.0)]
	var direction := 1.0 if facing_right else -1.0
	var center: Vector2 = centers[strike_index]
	center.x *= direction
	var strike_rect := Rect2(global_position + center - sizes[strike_index] * 0.5, sizes[strike_index])
	var closest: Node2D
	var closest_distance := INF
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter == self or not fighter is Node2D or fighter.get("is_defeated") == true:
			continue
		var other := fighter as Node2D
		var hurt_rect := get_fighter_hurtbox_rect(other)
		var distance := global_position.distance_squared_to(other.global_position)
		if strike_rect.intersects(hurt_rect) and distance < closest_distance:
			closest = other
			closest_distance = distance
	if closest and closest.has_method("apply_damage"):
		var knockback: float = float([65.0, 85.0, 165.0][strike_index]) * direction
		closest.apply_damage(damage, self, knockback)

func get_fighter_hurtbox_rect(fighter: Node2D) -> Rect2:
	if fighter.has_method("get_hurtbox_rect"):
		return fighter.get_hurtbox_rect()
	return Rect2(fighter.global_position + Vector2(-75.0, -220.0), Vector2(150.0, 220.0))

func get_hurtbox_rect() -> Rect2:
	return Rect2(global_position + Vector2(-75.0, -220.0), Vector2(150.0, 220.0))

func apply_damage(amount: float, source: Node = null, knockback: float = 0.0) -> void:
	if is_defeated or hit_invulnerability > 0.0 or is_dashing or is_air_dashing or dash_damage_grace > 0.0 or is_using_ultimate:
		return
	hit_invulnerability = 0.16
	health = maxf(0.0, health - amount)
	velocity.x = knockback
	health_changed.emit(health, max_health)
	flash_hit()
	if health <= 0.0:
		defeat(source)

func flash_hit() -> void:
	anim.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color.WHITE, 0.18)

func defeat(_source: Node = null) -> void:
	is_defeated = true
	attack_serial += 1
	InputManager.reset_touch_state()
	anim.pause()
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(anim, "rotation", deg_to_rad(82.0 if facing_right else -82.0), 0.42).set_trans(Tween.TRANS_BACK)
	tween.tween_property(anim, "modulate:a", 0.45, 0.65)
	defeated.emit(self)

func spawn_transform_smoke() -> void:
	for i in range(14):
		var puff := Polygon2D.new()
		var radius := randf_range(10.0, 24.0)
		var points := PackedVector2Array()
		for point_index in range(12):
			var angle := TAU * point_index / 12.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		puff.polygon = points
		puff.color = Color(0.68, 0.58, 0.95, randf_range(0.45, 0.75))
		puff.z_index = 12
		# Add to tree FIRST so global_position assignment is valid,
		# then record local position for the tween target.
		get_parent().add_child(puff)
		puff.global_position = global_position + Vector2(randf_range(-58.0, 58.0), randf_range(-105.0, 28.0))
		var drift := Vector2(randf_range(-55.0, 55.0), randf_range(-75.0, -28.0))
		# Use get_tree().create_tween() so the tween is NOT bound to the player node.
		# This guarantees queue_free always fires even if the player's tweens are killed.
		var tween := get_tree().create_tween().set_parallel(true)
		tween.tween_property(puff, "position", puff.position + drift, 0.48)
		tween.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.48)
		tween.tween_property(puff, "modulate:a", 0.0, 0.48)
		tween.chain().tween_callback(puff.queue_free)

func handle_air_attack_press() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if arsenal_mode == &"sword" and now - last_air_attack_press <= air_attack_double_tap_window:
		start_sword_slam()
		last_air_attack_press = -10.0
		return
	last_air_attack_press = now
	is_air_attacking = true
	air_attack_timer = air_attack_duration
	anim.speed_scale = 1.15
	anim.play("air_attack_sword")
	play_transition(Vector2(1.08, 0.94), 0.12)
	if arsenal_mode == &"sword":
		air_attack_sound = play_one_shot_sound("res://effects/sounds/slash_down.mp3", 1.04)
	# Capture the player's current horizontal speed for the kick duration.
	# Takes whichever is larger: current momentum (running kick = fast) or the
	# baseline so a standing kick still moves a little.
	if arsenal_mode == &"fists":
		var kick_dir := 1.0 if facing_right else -1.0
		air_kick_vx = kick_dir * maxf(absf(velocity.x), air_attack_move_speed)

func play_one_shot_sound(stream_path: String, pitch: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream := load(stream_path) as AudioStream
	if not stream:
		return null
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.bus = "SFX"
	sound.pitch_scale = pitch
	sound.volume_db = volume_db
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	return sound

func start_sword_slam() -> void:
	if arsenal_mode != &"sword":
		return
	# The first tap's aerial slash sound must not overlap the dedicated slam.
	# Stop it as soon as the second tap converts the move into a downward attack.
	if is_instance_valid(air_attack_sound):
		air_attack_sound.stop()
		air_attack_sound.queue_free()
	air_attack_sound = null
	is_air_attacking = false
	is_sword_slamming = true
	slam_wind_timer = 0.0
	slam_sound_played = false
	velocity = Vector2.ZERO
	anim.speed_scale = 1.45
	anim.play("air_attack_sword")
	play_transition(Vector2(0.88, 1.14), 0.1)

func process_sword_slam(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = sword_slam_speed
	# Frame 1 is the actual large downward sword arc. Triggering here keeps the
	# supplied sound locked to the visible cut instead of to the second tap.
	if not slam_sound_played and anim.frame >= 1:
		slam_sound_played = true
		play_one_shot_sound("res://effects/sounds/sword_slam_down.wav", 1.0, -2.0)
	slam_wind_timer += delta
	if slam_wind_timer >= 0.035:
		slam_wind_timer = 0.0
		create_slam_wind()
	move_and_keep_on_screen()
	if is_on_floor():
		finish_sword_slam()

func finish_sword_slam() -> void:
	# Very short jumps can touch the floor before frame 1; keep the sound from
	# being skipped while still avoiding any overlap with the old aerial sound.
	if not slam_sound_played:
		slam_sound_played = true
		play_one_shot_sound("res://effects/sounds/sword_slam_down.wav", 1.0, -2.0)
	is_sword_slamming = false
	velocity = Vector2.ZERO
	anim.speed_scale = 1.0
	is_attacking = true
	attack_timer = 0.28
	if hitbox_shape:
		hitbox_shape.disabled = false
		hitbox_shape.position = Vector2(0, 15)
	spawn_slam_impact()
	apply_attack_hit(sword_damage * 1.6, sword_attack_range * 1.25)
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

func spawn_double_jump_burst() -> void:
	# A short radial wind snap makes the mid-air jump readable without covering
	# the character or fighting with the sword effects.
	for i in range(12):
		var streak := Line2D.new()
		var angle := TAU * float(i) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		streak.points = PackedVector2Array([direction * 18.0, direction * 52.0])
		streak.width = 3.0
		streak.default_color = Color(0.76, 0.66, 1.0, 0.82)
		streak.z_index = 9
		get_parent().add_child(streak)
		streak.global_position = global_position + Vector2(0.0, -42.0)
		var tween := get_tree().create_tween().set_parallel(true)
		tween.tween_property(streak, "scale", Vector2(1.55, 1.55), 0.18)
		tween.tween_property(streak, "modulate:a", 0.0, 0.18)
		tween.chain().tween_callback(streak.queue_free)

# ------------------------------------------------------------
# WHITE SPEED LINES
# ------------------------------------------------------------
func create_speed_line():
	if not is_inside_tree() or get_parent() == null:
		return
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
	combo_step += 1
	if combo_step > 3:
		combo_step = 1
		
	anim.speed_scale = 1.1 + (combo_step * 0.15)
	anim.play("attack")
	
	var anim_length: float = 0.25
	var dash_dir = 1 if facing_right else -1
	
	if combo_step == 1:
		anim.frame = 0
		anim_length = 0.22
		velocity.x = dash_dir * attack_move_speed * 1.5
	elif combo_step == 2:
		anim.frame = 4
		anim_length = 0.22
		velocity.x = dash_dir * attack_move_speed * 2.0
	elif combo_step == 3:
		anim.frame = 7
		anim_length = 0.35
		velocity.x = dash_dir * attack_move_speed * 3.5
		shake_camera(0.15, 6.0)
		spawn_dust_burst(4)
		hit_stop(0.06)
		
	play_transition(Vector2(1.08, 0.96), 0.14)
	
	attack_timer = anim_length
	combo_reset_timer = combo_window

func hit_stop(duration: float) -> void:
	get_tree().paused = true
	# create_timer(time_sec, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

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
	play_character_anim("slide")
	velocity.x = (1.0 if facing_right else -1.0) * air_slide_speed
	spawn_dust_burst(4)

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
	if not is_inside_tree() or get_parent() == null:
		return
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
	if not is_inside_tree() or get_parent() == null:
		return
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
	if not is_inside_tree() or get_parent() == null:
		return
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
	while elapsed < duration and is_instance_valid(camera) and is_inside_tree() and get_tree() != null:
		camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.55, strength * 0.55)
		)
		await get_tree().create_timer(0.025).timeout
		elapsed += 0.025
		strength *= 0.82
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO

# ------------------------------------------------------------
# DUST
# ------------------------------------------------------------
func create_dust():
	if not is_inside_tree() or get_parent() == null:
		return
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
		if not is_inside_tree() or get_tree() == null:
			return
		create_dust()
		await get_tree().create_timer(0.02).timeout

# ------------------------------------------------------------
# GHOST TRAIL
# ------------------------------------------------------------
func create_ghost():
	if not is_inside_tree() or get_parent() == null:
		return
	var ghost: AnimatedSprite2D = anim.duplicate()
	get_parent().add_child(ghost)
	ghost.global_transform = anim.global_transform
	ghost.modulate = Color(0.6, 0.6, 1.0, 0.5)
	ghost.z_index = 3
	ghost.pause()
	
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
