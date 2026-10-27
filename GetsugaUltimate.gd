extends CanvasLayer

const ULTIMATE_VOICE: AudioStream = preload("uid://c2owbtnsr6j3w")
const SPECIAL_ICON: Texture2D = preload("res://effects/ui/getsuga_special_icon.png")
const VOICE_START_SECONDS: float = 0.03
const OVERLAY_END_SECONDS: float = 1.60
const VOICE_END_SECONDS: float = 3.05
const FRONT_BACK_FRAME_COUNT: int = 16

@export var player_path: NodePath = NodePath("../Player")
@export var cooldown_seconds: float = 6.0

var player: CharacterBody2D
var ultimate_button: Button
var cooldown_label: Label
var overlay: Control
var darkness: ColorRect
var cutin_character: AnimatedSprite2D
var cutin_transition_character: AnimatedSprite2D
var front_back_vfx: AnimatedSprite2D
var impact_flash: ColorRect
var active: bool = false
var cooldown_remaining: float = 0.0
var ultimate_voice: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	player = get_node_or_null(player_path) as CharacterBody2D
	create_button()
	create_overlay()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_Q or event.keycode == KEY_R:
			if not active and cooldown_remaining <= 0.0 and is_instance_valid(player):
				activate_ultimate()

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0 and not active:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		cooldown_label.text = "%.1f" % cooldown_remaining
		if cooldown_remaining <= 0.0:
			ultimate_button.disabled = false
			cooldown_label.text = ""

func create_button() -> void:
	ultimate_button = Button.new()
	ultimate_button.name = "GetsugaButton"
	# Circular special button on the left, below the arsenal switch and safely
	# above the joystick's expanded capture region.
	ultimate_button.position = Vector2(92.0, 166.0)
	ultimate_button.size = Vector2(158.0, 158.0)
	ultimate_button.text = ""
	ultimate_button.tooltip_text = "Getsuga Tenshou"
	ultimate_button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.018, 0.012, 0.042, 0.94)
	normal.border_color = Color(0.63, 0.34, 0.96, 0.98)
	normal.set_border_width_all(5)
	normal.set_corner_radius_all(79)
	normal.shadow_color = Color(0.38, 0.08, 0.72, 0.72)
	normal.shadow_size = 13
	normal.content_margin_left = 18.0
	normal.content_margin_top = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_bottom = 18.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.045, 0.22, 0.98)
	hover.border_color = Color(0.82, 0.62, 1.0, 1.0)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.28, 0.09, 0.47, 1.0)
	pressed_style.border_color = Color(0.94, 0.82, 1.0, 1.0)
	pressed_style.shadow_size = 5
	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.025, 0.02, 0.045, 0.82)
	disabled_style.border_color = Color(0.29, 0.22, 0.4, 0.8)
	ultimate_button.add_theme_stylebox_override("normal", normal)
	ultimate_button.add_theme_stylebox_override("hover", hover)
	ultimate_button.add_theme_stylebox_override("pressed", pressed_style)
	ultimate_button.add_theme_stylebox_override("disabled", disabled_style)
	ultimate_button.pressed.connect(activate_ultimate)
	add_child(ultimate_button)

	var special_icon := TextureRect.new()
	special_icon.position = Vector2(23.0, 20.0)
	special_icon.size = Vector2(112.0, 112.0)
	special_icon.texture = SPECIAL_ICON
	special_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	special_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	special_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_button.add_child(special_icon)

	cooldown_label = Label.new()
	cooldown_label.position = Vector2(0.0, 111.0)
	cooldown_label.size = Vector2(158.0, 34.0)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.add_theme_font_size_override("font_size", 19)
	cooldown_label.add_theme_color_override("font_color", Color(0.96, 0.9, 1.0))
	cooldown_label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.08, 1.0))
	cooldown_label.add_theme_constant_override("outline_size", 5)
	ultimate_button.add_child(cooldown_label)

func create_overlay() -> void:
	overlay = Control.new()
	overlay.name = "GetsugaCutIn"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	darkness = ColorRect.new()
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness.color = Color(0.0, 0.0, 0.025, 0.0)
	darkness.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(darkness)

	cutin_character = AnimatedSprite2D.new()
	cutin_character.centered = true
	cutin_character.offset = Vector2.ZERO
	cutin_character.z_index = 2
	overlay.add_child(cutin_character)

	# A second copy lets adjacent sword poses cross-fade while both continue a
	# small rotational/positional arc. That removes the three-frame snap which
	# made the front-to-back movement look laggy.
	cutin_transition_character = AnimatedSprite2D.new()
	cutin_transition_character.centered = true
	cutin_transition_character.offset = Vector2.ZERO
	cutin_transition_character.z_index = 2
	overlay.add_child(cutin_transition_character)

	front_back_vfx = AnimatedSprite2D.new()
	front_back_vfx.sprite_frames = make_numbered_animation(
		"res://effects/SLASH/getsuga/front_back_frames/front_back_%02d.png",
		FRONT_BACK_FRAME_COUNT,
		25.0
	)
	front_back_vfx.z_index = 3
	var front_back_additive := CanvasItemMaterial.new()
	front_back_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	front_back_vfx.material = front_back_additive
	overlay.add_child(front_back_vfx)

	impact_flash = ColorRect.new()
	impact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	impact_flash.color = Color(0.72, 0.55, 1.0, 0.0)
	impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_flash.z_index = 4
	overlay.add_child(impact_flash)

func set_entities_paused(paused: bool) -> void:
	# 1. Pause/unpause all opponent characters ("bg chars" / bad guy characters)
	for opponent in get_tree().get_nodes_in_group("opponent_fighter"):
		if is_instance_valid(opponent) and opponent.has_method("set_special_paused"):
			opponent.set_special_paused(paused)
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if is_instance_valid(fighter) and fighter != player and fighter.has_method("set_special_paused"):
			fighter.set_special_paused(paused)

	# 2. Pause/unpause background elements (fog, embers, orbs, ambient elements)
	for bg in get_tree().get_nodes_in_group("background"):
		if is_instance_valid(bg) and bg.has_method("set_background_paused"):
			bg.set_background_paused(paused)
	var bg_node := get_node_or_null("../Background")
	if is_instance_valid(bg_node) and bg_node.has_method("set_background_paused"):
		bg_node.set_background_paused(paused)

func activate_ultimate() -> void:
	if active or cooldown_remaining > 0.0 or not is_instance_valid(player):
		return
	if not player.has_method("can_use_getsuga") or not player.can_use_getsuga():
		show_unavailable()
		return
	active = true
	ultimate_button.disabled = true
	InputManager.reset_touch_state()
	
	# Freeze opponent(s) and background elements for the entire special attack
	set_entities_paused(true)
	
	prepare_overlay()
	overlay.visible = true
	get_tree().paused = true
	await play_overlay_animation()
	get_tree().paused = false
	overlay.visible = false
	
	# Play arena attack animation and wait until the full attack animation finishes
	await player.perform_getsuga_attack()
	
	# Special attack animation is completely finished -> resume normal movement!
	set_entities_paused(false)
	
	cooldown_remaining = cooldown_seconds
	active = false

func prepare_overlay() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	darkness.color = Color(0.0, 0.0, 0.025, 0.0)
	impact_flash.color.a = 0.0
	cutin_character.sprite_frames = player.anim.sprite_frames
	cutin_character.flip_h = not player.facing_right
	cutin_character.position = viewport_size * Vector2(0.43, 0.55)
	cutin_character.scale = Vector2.ONE * 1.65
	cutin_character.modulate = Color(0.72, 0.62, 0.9, 0.0)
	cutin_character.play(&"attack")
	cutin_character.pause()
	# Start low. The cut-in only raises the blade into frame 1's overhead-ready
	# stance; the downward strike is deliberately reserved for gameplay.
	cutin_character.frame = 10
	cutin_character.speed_scale = 1.0
	cutin_character.rotation = 0.0

	cutin_transition_character.sprite_frames = player.anim.sprite_frames
	cutin_transition_character.flip_h = cutin_character.flip_h
	cutin_transition_character.position = cutin_character.position
	cutin_transition_character.scale = cutin_character.scale
	cutin_transition_character.rotation = 0.0
	cutin_transition_character.modulate = Color(0.72, 0.62, 0.9, 0.0)
	cutin_transition_character.play(&"attack")
	cutin_transition_character.pause()
	cutin_transition_character.frame = 0

	var direction := 1.0 if player.facing_right else -1.0
	front_back_vfx.flip_h = direction < 0.0
	# Begin at the low/front sword pose. The source effect has a large transparent
	# canvas, so its node origin must sit below the hand for the visible flame rim
	# to wrap around the blade instead of floating above the character.
	front_back_vfx.position = cutin_character.position + Vector2(direction * 24.0, 68.0)
	front_back_vfx.rotation = -0.12 * direction
	# Match the flame to the final 1.88x cut-in size. The previous 0.46 scale made
	# this 720px effect look like a small spark beside the enlarged 512px fighter.
	# At 0.92 it covers the full sword sweep while keeping the face readable.
	var blade_effect_scale := 0.92
	front_back_vfx.scale = Vector2(blade_effect_scale, blade_effect_scale * 0.94)
	front_back_vfx.modulate = Color(1.0, 0.88, 0.94, 0.0)
	front_back_vfx.stop()
	front_back_vfx.frame = 0

func play_overlay_animation() -> void:
	var sequence_started_msec := Time.get_ticks_msec()
	play_ultimate_voice()
	var reveal := create_tween().set_parallel(true)
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(darkness, "color:a", 0.72, 0.22)
	reveal.tween_property(cutin_character, "modulate:a", 0.96, 0.24)
	reveal.tween_property(cutin_character, "scale", Vector2.ONE * 1.88, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished

	# The GIF-derived rim is visible only while the sword travels from its front
	# pose to the back pose. Two cross-fades plus small transform arcs provide
	# smooth motion despite the source character having only three usable poses.
	front_back_vfx.modulate.a = 0.9
	front_back_vfx.play(&"default")
	animate_front_back_blade_vfx()
	await crossfade_cutin_pose(0, 0.56, Vector2(-8.0, -4.0), 0.045)
	await crossfade_cutin_pose(1, 0.36, Vector2(5.0, -8.0), -0.035)
	front_back_vfx.modulate.a = 0.0

	var elapsed := (Time.get_ticks_msec() - sequence_started_msec) * 0.001
	var hold_time := maxf(0.0, OVERLAY_END_SECONDS - elapsed - 0.18)
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time, true).timeout

	var impact := create_tween()
	impact.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	impact.tween_property(impact_flash, "color:a", 0.72, 0.035)
	impact.tween_property(impact_flash, "color:a", 0.0, 0.12)
	impact.parallel().tween_property(cutin_character, "modulate:a", 0.0, 0.18)
	impact.parallel().tween_property(darkness, "color:a", 0.0, 0.2)
	await impact.finished
	elapsed = (Time.get_ticks_msec() - sequence_started_msec) * 0.001
	if elapsed < OVERLAY_END_SECONDS:
		await get_tree().create_timer(OVERLAY_END_SECONDS - elapsed, true).timeout

func animate_front_back_blade_vfx() -> void:
	var direction := 1.0 if player.facing_right else -1.0
	var base_scale := front_back_vfx.scale
	var blade_follow := create_tween().set_parallel(true)
	blade_follow.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Follow the sword from its low/front pose to the overhead/back pose. This
	# endpoint places the hottest orange rim along the raised blade in frame 1.
	blade_follow.tween_property(
		front_back_vfx,
		"position",
		cutin_character.position + Vector2(-74.0 * direction, -72.0),
		0.56
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blade_follow.tween_property(front_back_vfx, "rotation", 0.18 * direction, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blade_follow.tween_property(front_back_vfx, "scale", base_scale * 1.10, 0.56).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func crossfade_cutin_pose(next_frame: int, duration: float, travel: Vector2, rotation_delta: float) -> void:
	var direction := 1.0 if player.facing_right else -1.0
	var target_position := cutin_character.position + Vector2(travel.x * direction, travel.y)
	var target_rotation := cutin_character.rotation + rotation_delta * direction
	cutin_transition_character.frame = next_frame
	cutin_transition_character.position = target_position
	cutin_transition_character.scale = cutin_character.scale
	cutin_transition_character.rotation = target_rotation - 0.035 * direction
	cutin_transition_character.modulate = Color(cutin_character.modulate.r, cutin_character.modulate.g, cutin_character.modulate.b, 0.0)
	var blend := create_tween().set_parallel(true)
	blend.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	blend.tween_property(cutin_character, "modulate:a", 0.16, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blend.tween_property(cutin_character, "position", target_position - Vector2(4.0 * direction, -2.0), duration).set_trans(Tween.TRANS_SINE)
	blend.tween_property(cutin_character, "rotation", target_rotation + 0.025 * direction, duration).set_trans(Tween.TRANS_SINE)
	blend.tween_property(cutin_transition_character, "modulate:a", 0.96, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blend.tween_property(cutin_transition_character, "position", target_position, duration).set_trans(Tween.TRANS_SINE)
	blend.tween_property(cutin_transition_character, "rotation", target_rotation, duration).set_trans(Tween.TRANS_SINE)
	await blend.finished
	cutin_character.frame = next_frame
	cutin_character.position = target_position
	cutin_character.rotation = target_rotation
	cutin_character.modulate.a = 0.96
	cutin_transition_character.modulate.a = 0.0

func make_numbered_animation(pattern: String, frame_count: int, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default", false)
	frames.set_animation_speed(&"default", fps)
	for frame_number in frame_count:
		var path := pattern % frame_number
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(&"default", texture)
		else:
			push_error("Missing Getsuga animation frame: " + path)
	return frames
func play_ultimate_voice() -> void:
	if is_instance_valid(ultimate_voice):
		ultimate_voice.stop()
		ultimate_voice.queue_free()
	ultimate_voice = AudioStreamPlayer.new()
	ultimate_voice.stream = ULTIMATE_VOICE
	ultimate_voice.bus = "SFX"
	ultimate_voice.volume_db = 1.5
	ultimate_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ultimate_voice)
	ultimate_voice.play(VOICE_START_SECONDS)
	stop_ultimate_voice_after_trim(ultimate_voice)

func stop_ultimate_voice_after_trim(voice: AudioStreamPlayer) -> void:
	await get_tree().create_timer(VOICE_END_SECONDS - VOICE_START_SECONDS, true).timeout
	if is_instance_valid(voice):
		voice.stop()
		voice.queue_free()

func show_unavailable() -> void:
	var original_text := cooldown_label.text
	cooldown_label.text = "SWORD ONLY"
	ultimate_button.modulate = Color(1.0, 0.38, 0.5)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ultimate_button, "scale", Vector2(1.06, 1.06), 0.08)
	tween.tween_property(ultimate_button, "scale", Vector2.ONE, 0.12)
	await tween.finished
	ultimate_button.modulate = Color.WHITE
	cooldown_label.text = original_text
