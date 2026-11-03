extends VirtualJoystick

# ============================================================
# NativeJoystick - Combo-safe touch stick.
#
# Uses Godot's built-in VirtualJoystick (Control + per-touch tracking) instead
# of a hand-rolled TouchScreenButton. The engine owns finger ownership, so
# tapping action buttons can never reset, steal or re-index the stick.
# Movement is published through the InputMap actions configured on the node.
# ============================================================

const PAD_DIAMETER: float = 280.0
const TIP_DIAMETER: float = 136.0

func _ready() -> void:
	_style_pad()
	_style_tip()
	pressed.connect(_on_pressed)
	released.connect(_on_released)
	tapped.connect(_on_tapped)
	flick_canceled.connect(_on_canceled)

func _style_pad() -> void:
	for state_name in ["normal_joystick", "pressed_joystick"]:
		var pad := StyleBoxFlat.new()
		pad.bg_color = Color(0.42, 0.42, 0.45, 0.72)
		pad.border_color = Color(0.64, 0.64, 0.68, 0.85)
		pad.set_border_width_all(4)
		pad.set_corner_radius_all(int(PAD_DIAMETER * 0.5))
		pad.corner_detail = 24
		pad.anti_aliasing = true
		add_theme_stylebox_override(state_name, pad)
		# Pressed variant is a touch brighter.
		if state_name == "pressed_joystick":
			pad.bg_color = Color(0.48, 0.48, 0.52, 0.8)

func _style_tip() -> void:
	for state_name in ["normal_tip", "pressed_tip"]:
		var tip := StyleBoxFlat.new()
		tip.bg_color = Color(0.80, 0.80, 0.83, 0.95)
		tip.set_corner_radius_all(int(TIP_DIAMETER * 0.5))
		tip.corner_detail = 24
		tip.anti_aliasing = true
		add_theme_stylebox_override(state_name, tip)
		if state_name == "pressed_tip":
			tip.bg_color = Color(0.9, 0.9, 0.95, 1.0)

func _on_pressed() -> void:
	InputManager.begin_joystick_touch()

func _on_released(_input_vector: Vector2) -> void:
	InputManager.end_joystick_touch()

func _on_tapped() -> void:
	InputManager.end_joystick_touch()

func _on_canceled() -> void:
	InputManager.end_joystick_touch()
