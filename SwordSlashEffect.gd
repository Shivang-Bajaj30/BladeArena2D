extends AnimatedSprite2D

var slash_style: int = 1
var facing_right: bool = true
var effect_scale: float = 1.0
var anchor_for_right: Vector2 = Vector2(0.0, -140.0)

func _ready() -> void:
	z_index = 14
	centered = true
	update_fighter_alignment()
	scale = Vector2.ONE * effect_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"slash")
	frames.set_animation_loop(&"slash", false)
	frames.set_animation_speed(&"slash", 27.0)
	var first_frame := (clampi(slash_style, 1, 5) - 1) * 6 + 1
	for frame_number in range(first_frame, first_frame + 6):
		var folder := int((frame_number - 1) / 6) + 1
		var path := "res://effects/SLASH/purple_sword/%d/Alternative_1_%02d.png" % [folder, frame_number]
		var texture := load(path) as Texture2D
		if texture:
			frames.add_frame(&"slash", texture)
	sprite_frames = frames

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	modulate = Color(1.0, 0.72, 1.0, 0.98)

	animation_finished.connect(queue_free)
	play(&"slash")
	var punch := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch.tween_property(self, "scale", Vector2.ONE * effect_scale * 1.16, 0.11)
	punch.tween_property(self, "scale", Vector2.ONE * effect_scale, 0.11)
	
	# Fallback to ensure it's removed if the animation gets interrupted or hangs
	get_tree().create_timer(0.3).timeout.connect(queue_free)

func _process(_delta: float) -> void:
	# Stay locked to the fighter when an attack moves or changes direction.
	var parent_facing = get_parent().get("facing_right") if get_parent() else null
	if parent_facing is bool:
		facing_right = parent_facing
	update_fighter_alignment()

func update_fighter_alignment() -> void:
	flip_h = not facing_right
	position = Vector2(anchor_for_right.x if facing_right else -anchor_for_right.x, anchor_for_right.y)
