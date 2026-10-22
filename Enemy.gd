extends CharacterBody2D

# ============================================================
# Enemy - AI Rival Combatant (Opposite Character of Player)
# ============================================================

signal health_changed(current_hp: float, max_hp: float)
signal enemy_died()

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_invulnerable: bool = false

@export var move_speed: float = 230.0
@export var gravity: float = 980.0
@export var attack_range: float = 110.0

var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 1.2
var time_since_last_attack: float = 0.0
var facing_right: bool = false
var is_blade_user: bool = false

var anim: AnimatedSprite2D
var collision_shape: CollisionShape2D
var hurtbox: Area2D
var hurtbox_shape: CollisionShape2D
var hitbox: Area2D
var hitbox_shape: CollisionShape2D

var player_ref: Node2D = null

func _ready() -> void:
	# Determine rival character (opposite of player)
	var player_char: String = "blade_master"
	if GameState != null:
		player_char = GameState.selected_character
	is_blade_user = (player_char != "blade_master")
	
	_setup_nodes()
	_setup_sprite_frames()
	_setup_hurtbox()
	_setup_hitbox()
	
	current_health = max_health
	play_anim("idle")

func _setup_nodes() -> void:
	# Collision shape
	collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(50, 80)
	collision_shape.shape = rect
	add_child(collision_shape)
	
	# Animated Sprite
	anim = AnimatedSprite2D.new()
	anim.name = "AnimatedSprite2D"
	anim.position = Vector2(383, 132)
	anim.scale = Vector2(0.957, 1.0)
	anim.offset = Vector2(-400, -300)
	add_child(anim)

func _setup_sprite_frames() -> void:
	var frames_path := "res://fig_1.tres" if is_blade_user else "res://stick_fig.tres"
	if ResourceLoader.exists(frames_path):
		anim.sprite_frames = load(frames_path)

func _setup_hurtbox() -> void:
	hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2 # Enemy hurtbox layer
	hurtbox.collision_mask = 0
	add_child(hurtbox)
	
	hurtbox_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(55, 85)
	hurtbox_shape.shape = rect
	hurtbox.add_child(hurtbox_shape)

func _setup_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "EnemyHitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1 # Hits Player hurtbox (layer 1)
	add_child(hitbox)
	
	hitbox_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 85)
	hitbox_shape.shape = rect
	hitbox_shape.position = Vector2(-55, 0)
	hitbox_shape.disabled = true
	hitbox.add_child(hitbox_shape)
	
	hitbox.area_entered.connect(_on_hitbox_hit)

func _on_hitbox_hit(area: Area2D) -> void:
	if area.name == "Hurtbox" and area.get_parent().has_method("take_damage"):
		var dir = 1.0 if facing_right else -1.0
		area.get_parent().take_damage(16.0, dir, 220.0)

func play_anim(action: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var target_anim: String = ""
	match action:
		"idle":
			if is_blade_user and anim.sprite_frames.has_animation("idle_sword"):
				target_anim = "idle_sword"
			elif anim.sprite_frames.has_animation("idle"):
				target_anim = "idle"
		"run", "walk":
			if is_blade_user and anim.sprite_frames.has_animation("run_sword"):
				target_anim = "run_sword"
			elif anim.sprite_frames.has_animation("run"):
				target_anim = "run"
			elif anim.sprite_frames.has_animation("walk"):
				target_anim = "walk"
		"attack":
			if is_blade_user and anim.sprite_frames.has_animation("air_attack_sword"):
				target_anim = "air_attack_sword"
			elif anim.sprite_frames.has_animation("attack_combo"):
				target_anim = "attack_combo"
			elif anim.sprite_frames.has_animation("idle"):
				target_anim = "idle"
	
	if target_anim == "":
		target_anim = action
	if anim.sprite_frames.has_animation(target_anim):
		if anim.animation != target_anim or not anim.is_playing():
			anim.play(target_anim)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Death state
	if current_health <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return
	
	# Acquire player reference
	if not is_instance_valid(player_ref):
		player_ref = get_parent().get_node_or_null("Player")
	
	# Attack timer handling
	time_since_last_attack += delta
	if is_attacking:
		attack_timer -= delta
		if attack_timer > 0.08 and attack_timer < 0.28:
			hitbox_shape.disabled = false
			hitbox_shape.position.x = 55 if facing_right else -55
		else:
			hitbox_shape.disabled = true
			
		if attack_timer <= 0.0:
			is_attacking = false
			time_since_last_attack = 0.0
		
		# Decelerate during attack
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return
	
	# AI movement & decision making
	if is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
		var p_hp: float = player_ref.get("current_health") if "current_health" in player_ref else 100.0
		if p_hp <= 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			play_anim("idle")
			move_and_slide()
			return
		
		var dx: float = player_ref.global_position.x - global_position.x
		facing_right = (dx > 0.0)
		anim.flip_h = not facing_right
		
		var dist: float = abs(dx)
		if dist > attack_range:
			# Move toward player
			var dir = 1.0 if dx > 0 else -1.0
			velocity.x = dir * move_speed
			play_anim("run")
		else:
			# In range - stop and attack if cooldown ready
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if time_since_last_attack >= attack_cooldown:
				_perform_attack()
			else:
				play_anim("idle")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		play_anim("idle")
	
	move_and_slide()

func _perform_attack() -> void:
	is_attacking = true
	attack_timer = 0.45
	play_anim("attack")
	AudioManager.play_blade_slash()

func take_damage(dmg: float, dir: float = 0.0, force: float = 0.0) -> void:
	if is_invulnerable or current_health <= 0.0:
		return
	
	current_health = max(0.0, current_health - dmg)
	health_changed.emit(current_health, max_health)
	
	if force > 0.0 and dir != 0.0:
		velocity.x = dir * force
		velocity.y = -force * 0.25
	
	# Flash red
	var orig_mod = anim.modulate
	anim.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tw = create_tween()
	tw.tween_property(anim, "modulate", orig_mod, 0.15)
	
	AudioManager.play_hit()
	
	if current_health <= 0.0:
		die()
	else:
		is_invulnerable = true
		get_tree().create_timer(0.18).timeout.connect(func(): is_invulnerable = false)

func die() -> void:
	if current_health > 0.0:
		current_health = 0.0
		health_changed.emit(current_health, max_health)
	is_attacking = false
	if hitbox_shape:
		hitbox_shape.disabled = true
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color(0.9, 0.2, 0.2, 0.75), 0.3)
	enemy_died.emit()

func reset_for_round(start_pos: Vector2, look_right: bool = false) -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	is_invulnerable = false
	is_attacking = false
	time_since_last_attack = 0.0
	velocity = Vector2.ZERO
	global_position = start_pos
	facing_right = look_right
	anim.flip_h = not look_right
	anim.modulate = Color(1, 1, 1, 1)
	if hitbox_shape:
		hitbox_shape.disabled = true
	play_anim("idle")
