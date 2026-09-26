extends TouchScreenButton

# ============================================================
# TouchJoystick - Image-based on-screen joystick
# ============================================================

@export var max_radius: float = 50.0
@export var dead_zone: float = 0.2
@export var base_texture: Texture2D
@export var knob_texture: Texture2D
@export var base_scale: float = 0.4
@export var knob_scale: float = 0.4

var knob: Sprite2D
var base_sprite: Sprite2D
var _touch_index: int = -1
var _active: bool = false

func _ready():
	create_visuals()

func create_visuals():
	# Base sprite (outer ring)
	if base_texture:
		base_sprite = Sprite2D.new()
		base_sprite.texture = base_texture
		base_sprite.scale = Vector2(base_scale, base_scale)
		base_sprite.z_index = 10
		add_child(base_sprite)

	# Knob sprite (inner circle)
	if knob_texture:
		knob = Sprite2D.new()
		knob.texture = knob_texture
		knob.scale = Vector2(knob_scale, knob_scale)
		knob.z_index = 11
		add_child(knob)

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and is_inside_area(event.position) and not _active:
			_active = true
			_touch_index = event.index
			update_joystick(event.position)
		elif not event.pressed and event.index == _touch_index:
			# Touch indices belong to one contact for its whole lifetime. Always
			# release only the joystick's own finger, wherever it ended up.
			reset_joystick()
			_active = false
			_touch_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			update_joystick(event.position)

func is_inside_area(pos: Vector2) -> bool:
	var local_pos = get_global_transform_with_canvas().affine_inverse() * pos
	return local_pos.length() < max_radius * 1.5

func update_joystick(screen_pos: Vector2):
	var local_pos = get_global_transform_with_canvas().affine_inverse() * screen_pos
	var clamped = local_pos
	if clamped.length() > max_radius:
		clamped = clamped.normalized() * max_radius

	if knob:
		knob.position = clamped

	var norm = clamped / max_radius
	if norm.length() < dead_zone:
		norm = Vector2.ZERO

	InputManager.set_joystick(norm)

func reset_joystick():
	if knob:
		knob.position = Vector2.ZERO
	InputManager.set_joystick(Vector2.ZERO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_active = false
		_touch_index = -1
		reset_joystick()

func _exit_tree() -> void:
	_active = false
	_touch_index = -1
	reset_joystick()
