extends TouchScreenButton

# ============================================================
# IconButton - Only fires when the button itself is pressed
# ============================================================

@export var action_name: String = "jump"
@export var capture_padding: float = 18.0

var resting_scale: Vector2
var active_touches: Dictionary = {}

func _ready() -> void:
	resting_scale = scale
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			set_touch_inside(event.index, contains_screen_position(event.position))
		else:
			set_touch_inside(event.index, false)
	elif event is InputEventScreenDrag:
		# Checking every drag endpoint makes a fast swipe from one action button
		# to another release the old action and press the new one in the same event.
		set_touch_inside(event.index, contains_screen_position(event.position))

func contains_screen_position(screen_position: Vector2) -> bool:
	if not texture_normal:
		return false
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	var texture_size := texture_normal.get_size()
	var hit_rect := Rect2(
		Vector2(-capture_padding, -capture_padding),
		texture_size + Vector2.ONE * capture_padding * 2.0
	)
	return hit_rect.has_point(local_position)

func set_touch_inside(index: int, inside: bool) -> void:
	var was_pressed := not active_touches.is_empty()
	if inside:
		active_touches[index] = true
	else:
		active_touches.erase(index)
	var is_pressed_now := not active_touches.is_empty()
	if is_pressed_now and not was_pressed:
		press_action()
	elif was_pressed and not is_pressed_now:
		release_action()

func press_action() -> void:
	InputManager.press_button(action_name)
	scale = resting_scale * 0.9
	modulate = Color(1.15, 1.15, 1.15, 1.0)

func release_action() -> void:
	InputManager.release_button(action_name)
	scale = resting_scale
	modulate = Color.WHITE

func _exit_tree() -> void:
	active_touches.clear()
	InputManager.release_button(action_name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not active_touches.is_empty():
		active_touches.clear()
		release_action()
