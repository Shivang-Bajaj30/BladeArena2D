extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(fighter: Node)

@export var target_path: NodePath = NodePath("../Player")
@export var walk_speed: float = 165.0
@export var run_speed: float = 350.0
@export var evade_speed: float = 500.0
@export var slide_speed: float = 390.0
@export var jump_velocity: float = -470.0
@export var gravity: float = 980.0
@export var max_health: float = 100.0
@export var sword_damage: float = 11.0
@export var fist_damage: float = 7.0
@export var sword_attack_range: float = 250.0
@export var fist_attack_range: float = 225.0
@export var prediction_time: float = 0.08
@export_range(0.1, 1.5, 0.05) var damage_taken_multiplier: float = 1.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var target: CharacterBody2D
var arsenal_mode: StringName = &"sword"
var health: float
var facing_right: bool = false
var is_attacking: bool = false
var is_evading: bool = false
var is_sliding: bool = false
var is_defeated: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.9
var evade_timer: float = 0.0
var slide_timer: float = 0.0
var reaction_timer: float = 0.55
var decision_timer: float = 0.35
var recovery_timer: float = 0.0
var jump_cooldown: float = 0.0
var hit_invulnerability: float = 0.0
var attack_serial: int = 0
var base_anim_scale: Vector2
var base_anim_position: Vector2
var base_tint: Color = Color(0.88, 0.68, 1.0)
var is_special_paused: bool = false
var pending_knockback: float = 0.0

func set_special_paused(paused: bool) -> void:
	is_special_paused = paused
	if paused:
		velocity = Vector2.ZERO
		if not is_defeated and is_instance_valid(anim):
			anim.pause()
	else:
		if not is_defeated and is_instance_valid(anim):
			anim.play()
		if pending_knockback != 0.0:
			velocity.x = pending_knockback
			pending_knockback = 0.0

func _ready() -> void:
	add_to_group("fighters")
	add_to_group("opponent_fighter")
	target = get_node_or_null(target_path) as CharacterBody2D
	health = max_health
	base_anim_scale = anim.scale
	base_anim_position = anim.position
	floor_snap_length = 12.0
	anim.play(get_mode_animation("idle"))
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if is_special_paused:
		velocity = Vector2.ZERO
		return
	if is_defeated:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
		move_and_slide()
		return
	if not is_instance_valid(target) or target.get("is_defeated") == true:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		play_if_changed(get_mode_animation("idle"))
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	hit_invulnerability = maxf(0.0, hit_invulnerability - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	reaction_timer = maxf(0.0, reaction_timer - delta)
	decision_timer = maxf(0.0, decision_timer - delta)
	recovery_timer = maxf(0.0, recovery_timer - delta)
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	var predicted_x := target.global_position.x + target.velocity.x * prediction_time
	var signed_distance := predicted_x - global_position.x
	var distance := absf(target.global_position.x - global_position.x)
	# Commit to the chosen direction during actions. Constantly mirroring every
	# player flick made the opponent feel psychic and removed punish windows.
	if not is_attacking and not is_evading and not is_sliding:
		facing_right = target.global_position.x >= global_position.x
		anim.flip_h = not facing_right

	if is_attacking:
		attack_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
		if attack_timer <= 0.0:
			is_attacking = false
			anim.speed_scale = 1.0
			recovery_timer = randf_range(0.38, 0.58)
		move_and_slide()
		return

	if is_evading:
		evade_timer -= delta
		if evade_timer <= 0.0:
			is_evading = false
			velocity.x = 0.0
		else:
			create_speed_line()
		move_and_clamp()
		return

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false
			velocity.x = 0.0
			anim.speed_scale = 1.0
		else:
			create_speed_line()
		move_and_clamp()
		return

	# After attacking or evading, pause briefly instead of reading the player's
	# next input immediately. This is the intended opening for a counter-hit.
	if recovery_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		play_if_changed(get_mode_animation("idle"))
		move_and_clamp()
		return

	if not is_on_floor():
		velocity.x = move_toward(velocity.x, signf(signed_distance) * walk_speed * 0.55, 520.0 * delta)
		play_if_changed(get_mode_animation("jump"))
		move_and_clamp()
		return

	var attack_range := sword_attack_range if arsenal_mode == &"sword" else fist_attack_range
	var target_is_attacking: bool = target.get("is_attacking") == true or target.get("is_sword_slamming") == true

	# Only some committed attacks trigger an evade. Running and joystick flicks
	# alone no longer cause an instant response.
	if reaction_timer <= 0.0 and distance < attack_range * 1.25 and target_is_attacking and randf() < 0.28:
		start_evade()
		reaction_timer = randf_range(0.72, 1.05)
		move_and_clamp()
		return

	# Occasionally use the remaining movement animations, with a decision delay
	# so jump and slide are readable choices rather than input-perfect counters.
	if decision_timer <= 0.0:
		decision_timer = randf_range(0.38, 0.62)
		if jump_cooldown <= 0.0 and distance > attack_range * 1.15 and distance < 620.0 and randf() < 0.12:
			start_jump(signf(signed_distance))
			move_and_clamp()
			return
		if distance > attack_range * 1.05 and distance < 520.0 and randf() < 0.14:
			start_slide(signf(signed_distance))
			move_and_clamp()
			return

	if distance > attack_range * 0.92:
		var direction := signf(signed_distance)
		velocity.x = direction * (run_speed if distance > 420.0 else walk_speed)
		play_if_changed(get_mode_animation("run") if distance > 420.0 else get_mode_animation("walk"))
	elif distance < attack_range * 0.55:
		velocity.x = -signf(signed_distance) * walk_speed * 0.72
		play_if_changed(get_mode_animation("walk"))
	elif attack_cooldown <= 0.0:
		start_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		play_if_changed(get_mode_animation("idle"))

	move_and_clamp()

func move_and_clamp() -> void:
	move_and_slide()
	global_position.x = clampf(global_position.x, -1060.0, 1060.0)

func start_attack() -> void:
	is_attacking = true
	velocity.x = (1.0 if facing_right else -1.0) * 75.0
	var attack_animation := get_mode_animation("attack")
	anim.speed_scale = 1.08
	anim.play(attack_animation)
	attack_timer = get_animation_length(attack_animation, 0.55)
	attack_cooldown = randf_range(1.0, 1.4)
	attack_serial += 1
	if arsenal_mode == &"sword":
		spawn_sword_slash_combo(attack_serial)
		resolve_sword_combo_hits(attack_serial)
	else:
		resolve_attack_after_delay(attack_serial, attack_timer * 0.43)

func spawn_sword_slash_combo(serial: int) -> void:
	var slash_script = preload("res://SwordSlashEffect.gd")
	var spawn_frames := [1, 4, 7]
	var styles := [1, 2, 1]
	var anchors := [Vector2(23.0, -142.0), Vector2(-13.0, -118.0), Vector2(42.0, -155.0)]
	var scales := [1.55, 1.82, 1.68]
	for i in range(styles.size()):
		while serial == attack_serial and anim.animation == &"attack" and anim.frame < spawn_frames[i]:
			await anim.frame_changed
		if serial != attack_serial or arsenal_mode != &"sword" or is_defeated:
			return
		var slash: AnimatedSprite2D = slash_script.new()
		slash.slash_style = styles[i]
		slash.facing_right = facing_right
		slash.effect_scale = scales[i]
		slash.anchor_for_right = anchors[i]
		add_child(slash)

func resolve_attack_after_delay(serial: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if serial != attack_serial or is_defeated or is_special_paused or not is_instance_valid(target):
		return
	var attack_range := sword_attack_range if arsenal_mode == &"sword" else fist_attack_range
	var damage := sword_damage if arsenal_mode == &"sword" else fist_damage
	var offset := target.global_position - global_position
	var direction := 1.0 if facing_right else -1.0
	if absf(offset.x) <= attack_range and absf(offset.y) < 125.0 and offset.x * direction >= -20.0:
		if target.has_method("apply_damage"):
			target.apply_damage(damage, self, direction * 230.0)

func resolve_sword_combo_hits(serial: int) -> void:
	var impact_frames := [2, 5, 8]
	var damage_per_strike := sword_damage / float(impact_frames.size())
	for strike_index in range(impact_frames.size()):
		while serial == attack_serial and anim.animation == &"attack" and anim.frame < impact_frames[strike_index]:
			await anim.frame_changed
		if serial != attack_serial or arsenal_mode != &"sword" or is_defeated or not is_instance_valid(target):
			return
		apply_sword_strike_hit(strike_index, damage_per_strike)

func apply_sword_strike_hit(strike_index: int, damage: float) -> void:
	if is_special_paused:
		return
	var centers := [Vector2(23.0, -142.0), Vector2(-13.0, -118.0), Vector2(42.0, -155.0)]
	var sizes := [Vector2(300.0, 245.0), Vector2(380.0, 190.0), Vector2(315.0, 250.0)]
	var direction := 1.0 if facing_right else -1.0
	var center: Vector2 = centers[strike_index]
	center.x *= direction
	var strike_rect := Rect2(global_position + center - sizes[strike_index] * 0.5, sizes[strike_index])
	var target_hurt_rect: Rect2
	if target.has_method("get_hurtbox_rect"):
		target_hurt_rect = target.get_hurtbox_rect()
	else:
		target_hurt_rect = Rect2(target.global_position + Vector2(-75.0, -220.0), Vector2(150.0, 220.0))
	if strike_rect.intersects(target_hurt_rect) and target.has_method("apply_damage"):
		var knockback: float = float([60.0, 80.0, 150.0][strike_index]) * direction
		target.apply_damage(damage, self, knockback)

func get_hurtbox_rect() -> Rect2:
	# Covers the opponent's visible head, torso, and limbs instead of only the
	# small physics shape at their feet.
	return Rect2(global_position + Vector2(-75.0, -220.0), Vector2(150.0, 220.0))

func start_evade() -> void:
	is_evading = true
	evade_timer = randf_range(0.14, 0.2)
	var away := -1.0 if target.global_position.x > global_position.x else 1.0
	velocity.x = away * evade_speed
	velocity.y = 0.0
	anim.speed_scale = 1.25
	anim.play(get_mode_animation("dash"))

func start_jump(direction: float) -> void:
	velocity.x = direction * walk_speed * 0.82
	velocity.y = jump_velocity
	jump_cooldown = randf_range(1.5, 2.2)
	anim.speed_scale = 1.0
	anim.play(get_mode_animation("jump"))

func start_slide(direction: float) -> void:
	is_sliding = true
	slide_timer = randf_range(0.3, 0.4)
	velocity.x = direction * slide_speed
	anim.speed_scale = 1.08
	anim.play(get_mode_animation("slide"))

func get_animation_length(animation_name: StringName, fallback: float) -> float:
	if not anim.sprite_frames.has_animation(animation_name):
		return fallback
	var fps := anim.sprite_frames.get_animation_speed(animation_name) * anim.speed_scale
	return anim.sprite_frames.get_frame_count(animation_name) / fps if fps > 0.0 else fallback

func get_mode_animation(action: String) -> StringName:
	var sword_animations := {
		"idle": &"idle_sword", "walk": &"walk_sword", "run": &"run_sword",
		"jump": &"sword_jump", "slide": &"slide_sword",
		"dash": &"dash_sword", "attack": &"attack",
	}
	var fist_animations := {
		"idle": &"idle", "walk": &"walk", "run": &"run",
		"jump": &"jump", "slide": &"slide",
		"dash": &"dash", "attack": &"attack_combo",
	}
	return sword_animations.get(action, &"idle_sword") if arsenal_mode == &"sword" else fist_animations.get(action, &"idle")

func play_if_changed(animation_name: StringName) -> void:
	if anim.animation != animation_name or not anim.is_playing():
		anim.speed_scale = 1.0
		anim.play(animation_name)

func set_arsenal(mode: StringName, with_smoke: bool = true) -> void:
	if mode != &"sword" and mode != &"fists" or arsenal_mode == mode:
		return
	arsenal_mode = mode
	attack_serial += 1
	is_attacking = false
	is_evading = false
	is_sliding = false
	anim.speed_scale = 1.0
	anim.scale = base_anim_scale
	anim.position = base_anim_position
	if with_smoke:
		spawn_transform_smoke()
	anim.play(get_mode_animation("idle"))

func apply_damage(amount: float, _source: Node = null, knockback: float = 0.0) -> void:
	if is_defeated or hit_invulnerability > 0.0:
		return
	hit_invulnerability = 0.16
	health = maxf(0.0, health - amount * damage_taken_multiplier)
	if is_special_paused:
		pending_knockback = knockback
		velocity = Vector2.ZERO
	else:
		velocity.x = knockback
	health_changed.emit(health, max_health)
	anim.modulate = Color(1.0, 0.3, 0.48, 1.0)
	create_tween().tween_property(anim, "modulate", base_tint, 0.2)
	if health <= 0.0:
		is_special_paused = false
		defeat()

func defeat() -> void:
	is_special_paused = false
	is_defeated = true
	attack_serial += 1
	anim.pause()
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(anim, "rotation", deg_to_rad(-82.0 if facing_right else 82.0), 0.42).set_trans(Tween.TRANS_BACK)
	tween.tween_property(anim, "modulate:a", 0.4, 0.65)
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
		puff.color = Color(0.84, 0.38, 0.76, randf_range(0.45, 0.76))
		puff.global_position = global_position + Vector2(randf_range(-58.0, 58.0), randf_range(-105.0, 28.0))
		puff.z_index = 12
		get_parent().add_child(puff)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(puff, "position", puff.position + Vector2(randf_range(-55.0, 55.0), randf_range(-75.0, -28.0)), 0.48)
		tween.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.48)
		tween.tween_property(puff, "modulate:a", 0.0, 0.48)
		tween.chain().tween_callback(puff.queue_free)

func create_speed_line() -> void:
	var line := ColorRect.new()
	line.size = Vector2(randf_range(28.0, 58.0), randf_range(1.0, 3.0))
	line.color = Color(0.85, 0.55, 1.0, 0.72)
	line.global_position = global_position + Vector2(randf_range(-45.0, 45.0), randf_range(-55.0, 25.0))
	line.z_index = 5
	get_parent().add_child(line)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(line, "position:x", line.position.x - signf(velocity.x) * 80.0, 0.18)
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(line.queue_free)
