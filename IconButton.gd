extends TouchScreenButton

# ============================================================
# IconButton - Only fires when the button itself is pressed
# ============================================================

@export var action_name: String = "jump"

var resting_scale: Vector2

func _ready() -> void:
	resting_scale = scale
	# Allows one finger to glide directly from one action button to another.
	# Godot will release the old button and press the new one during the drag.
	passby_press = true
	pressed.connect(press_action)
	released.connect(release_action)

func press_action() -> void:
	InputManager.press_button(action_name)
	scale = resting_scale * 0.9
	modulate = Color(1.15, 1.15, 1.15, 1.0)

func release_action() -> void:
	InputManager.release_button(action_name)
	scale = resting_scale
	modulate = Color.WHITE

func _exit_tree() -> void:
	InputManager.release_button(action_name)
