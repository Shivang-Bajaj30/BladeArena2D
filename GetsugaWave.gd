extends Area2D

const SLASH_J2_FRAME_COUNT: int = 16
const BLACK_FLAME_FRAME_COUNT: int = 8

var direction: float = 1.0
var owner_fighter: Node
var damage: float = 32.0
var speed: float = 980.0
var lifetime: float = 1.15
var trail_timer: float = 0.0
var wind_timer: float = 0.0
var age: float = 0.0
var hit_fighters: Dictionary = {}
var main_sprite: AnimatedSprite2D
var black_flame_sprite: AnimatedSprite2D
var hit_shape: RectangleShape2D

func configure(new_direction: float, new_owner: Node, new_damage: float) -> void:
	direction = 1.0 if new_direction >= 0.0 else -1.0
	owner_fighter = new_owner
	damage = new_damage

func _ready() -> void:
	z_index = 18
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	# A separate animated black core grows out from the sword beneath the bright
	# cutting rim. Rotating the tall source frames turns them into a long-range
	# horizontal blast while preserving their smoky, irregular edge.
	black_flame_sprite = AnimatedSprite2D.new()
	black_flame_sprite.sprite_frames = make_black_flame_animation()
	black_flame_sprite.centered = true
	black_flame_sprite.flip_h = direction < 0.0
	black_flame_sprite.rotation = -PI * 0.5 * direction
	black_flame_sprite.scale = Vector2(0.30, 0.24)
	black_flame_sprite.modulate = Color(0.18, 0.08, 0.3, 0.92)
	black_flame_sprite.z_index = -2
	add_child(black_flame_sprite)
	black_flame_sprite.play(&"black_flame")

	main_sprite = AnimatedSprite2D.new()
	main_sprite.sprite_frames = make_wave_animation()
	main_sprite.flip_h = direction < 0.0
	main_sprite.centered = true
	main_sprite.offset = Vector2.ZERO
	main_sprite.rotation = -0.16 * direction
	main_sprite.scale = Vector2(0.30, 0.28)
	main_sprite.modulate = Color(0.96, 0.88, 1.0, 1.0)
	add_child(main_sprite)
	main_sprite.play(&"wave")

	var glow := AnimatedSprite2D.new()
	glow.sprite_frames = main_sprite.sprite_frames
	glow.flip_h = main_sprite.flip_h
	glow.centered = true
	glow.offset = Vector2.ZERO
	glow.rotation = main_sprite.rotation
	glow.scale = Vector2(0.34, 0.31)
	glow.modulate = Color(0.7, 0.28, 1.0, 0.42)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.z_index = -1
	add_child(glow)
	glow.play(&"wave")

	var shape_node := CollisionShape2D.new()
	hit_shape = RectangleShape2D.new()
	hit_shape.size = Vector2(250.0, 170.0)
	shape_node.shape = hit_shape
	add_child(shape_node)
	body_entered.connect(_on_body_entered)

	# Grow for most of the flight instead of popping to full size immediately.
	# The dark flame leads the expansion and the luminous edge follows it.
	var growth := create_tween().set_parallel(true)
	growth.tween_property(main_sprite, "scale", Vector2(0.88, 0.77), 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	growth.tween_property(glow, "scale", Vector2(0.97, 0.86), 0.88).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	growth.tween_property(black_flame_sprite, "scale", Vector2(0.98, 0.74), 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	growth.tween_property(hit_shape, "size", Vector2(500.0, 340.0), 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	age += delta
	global_position.x += direction * speed * delta
	check_swept_hits()
	lifetime -= delta
	trail_timer += delta
	if trail_timer >= 0.055:
		trail_timer = 0.0
		spawn_afterimage()
	wind_timer += delta
	if wind_timer >= 0.038:
		wind_timer = 0.0
		spawn_wind_streak()
	if lifetime <= 0.0:
		fade_out()

func _on_body_entered(body: Node) -> void:
	if body == owner_fighter or not body.has_method("apply_damage"):
		return
	var identity := body.get_instance_id()
	if hit_fighters.has(identity):
		return
	hit_fighters[identity] = true
	body.apply_damage(damage, owner_fighter, direction * 420.0)

func check_swept_hits() -> void:
	# Use the same visible-body hurtboxes as sword combat. This also prevents a
	# fast projectile from tunneling through the opponent between physics frames.
	var growth_ratio := clampf(age / 0.82, 0.0, 1.0)
	var half_extents := Vector2(125.0, 85.0).lerp(Vector2(250.0, 170.0), growth_ratio)
	var wave_rect := Rect2(global_position - half_extents, half_extents * 2.0)
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter == owner_fighter or not fighter is Node2D or fighter.get("is_defeated") == true:
			continue
		var hurt_rect: Rect2
		if fighter.has_method("get_hurtbox_rect"):
			hurt_rect = fighter.get_hurtbox_rect()
		else:
			hurt_rect = Rect2(fighter.global_position + Vector2(-75.0, -220.0), Vector2(150.0, 220.0))
		if wave_rect.intersects(hurt_rect):
			_on_body_entered(fighter)

func spawn_afterimage() -> void:
	if not is_instance_valid(main_sprite) or not get_parent():
		return
	var echo := Sprite2D.new()
	echo.texture = main_sprite.sprite_frames.get_frame_texture(&"wave", main_sprite.frame)
	echo.flip_h = direction < 0.0
	echo.centered = true
	echo.offset = main_sprite.offset
	echo.rotation = main_sprite.rotation
	echo.scale = main_sprite.scale
	echo.modulate = Color(0.4, 0.18, 0.75, 0.22)
	echo.z_index = z_index - 1
	get_parent().add_child(echo)
	echo.global_position = global_position - Vector2(direction * 22.0, 0.0)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(echo, "modulate:a", 0.0, 0.2)
	tween.tween_property(echo, "scale", echo.scale * 1.08, 0.2)
	tween.chain().tween_callback(echo.queue_free)

func spawn_wind_streak() -> void:
	if not get_parent():
		return
	var streak := Line2D.new()
	var streak_length := randf_range(105.0, 235.0) * (0.7 + clampf(age / 0.82, 0.0, 1.0) * 0.5)
	var bend := randf_range(-28.0, 28.0)
	streak.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(-direction * streak_length * 0.48, bend),
		Vector2(-direction * streak_length, bend * 0.35)
	])
	streak.width = randf_range(7.0, 16.0)
	streak.default_color = Color(0.012, 0.006, 0.025, randf_range(0.48, 0.78))
	streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
	streak.end_cap_mode = Line2D.LINE_CAP_ROUND
	streak.joint_mode = Line2D.LINE_JOINT_ROUND
	streak.z_index = z_index - 3
	get_parent().add_child(streak)
	streak.global_position = global_position + Vector2(
		-direction * randf_range(35.0, 90.0),
		randf_range(-145.0, 145.0) * clampf(0.45 + age, 0.45, 1.0)
	)
	var wind_fade := get_tree().create_tween().set_parallel(true)
	wind_fade.tween_property(streak, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wind_fade.tween_property(streak, "position:x", streak.position.x - direction * 70.0, 0.28).set_trans(Tween.TRANS_SINE)
	wind_fade.tween_property(streak, "width", 1.0, 0.28)
	wind_fade.chain().tween_callback(streak.queue_free)

func make_wave_animation() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"wave")
	# The user's slash_j2 sequence forms, peaks, fragments, and fades once while
	# travelling. It never loops back into a circular swipe.
	frames.set_animation_loop(&"wave", false)
	frames.set_animation_speed(&"wave", 16.0)
	for frame_number in SLASH_J2_FRAME_COUNT:
		var path := "res://effects/SLASH/getsuga/slash_j2_frames/slash_j2_%02d.png" % frame_number
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(&"wave", texture)
		else:
			push_error("Missing Getsuga wave frame: " + path)
	return frames

func make_black_flame_animation() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"black_flame")
	frames.set_animation_loop(&"black_flame", false)
	frames.set_animation_speed(&"black_flame", 8.0)
	for frame_number in BLACK_FLAME_FRAME_COUNT:
		var path := "res://effects/SLASH/getsuga/black_slash_frames/black_slash_%02d.png" % frame_number
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(&"black_flame", texture)
		else:
			push_error("Missing Getsuga black-flame frame: " + path)
	return frames

func fade_out() -> void:
	set_physics_process(false)
	monitoring = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.2)
	tween.chain().tween_callback(queue_free)
