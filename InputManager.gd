extends Node

# ============================================================
# InputManager - Unifies keyboard and touch into one API.
# ============================================================

# --- Touch State ---
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_active: bool = false

# Action buttons (set by touch controls)
var action_pressed: Dictionary = {
	"jump": false,
	"attack_light": false,
	"attack_heavy": false,
	"block": false,
	"dodge": false,
	"slide": false,
	"pause": false,
}

var action_press_count: Dictionary = {
	"jump": 0,
	"attack_light": 0,
	"attack_heavy": 0,
	"block": 0,
	"dodge": 0,
	"slide": 0,
	"pause": 0,
}

# --- Input action maps ---
const KEYBOARD_ACTIONS = {
	"move_right": ["move_right", "ui_right"],
	"move_left": ["move_left", "ui_left"],
	"jump": ["jump", "ui_accept", "ui_up"],
	"attack_light": ["attack_light"],
	"attack_heavy": ["attack_heavy"],
	"block": ["block"],
	"dodge": ["dodge", "dash", "block"],
	"slide": ["slide", "ui_down"],
	"pause": ["pause", "ui_cancel"],
}

func _ready() -> void:
	_ensure_action_key("dodge", KEY_F)
	_ensure_action_key("dodge", KEY_SHIFT)
	_ensure_action_key("slide", KEY_DOWN)
	_ensure_action_key("slide", KEY_S)
	_ensure_action_key("jump", KEY_UP)
	_ensure_action_key("jump", KEY_SPACE)
	_ensure_action_key("attack_light", KEY_J)
	_ensure_action_key("attack_light", KEY_Z)

func _ensure_action_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode):
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)

# ------------------------------------------------------------
# Core API
# ------------------------------------------------------------

func is_action_pressed(action: String) -> bool:
	# Keyboard / Gamepad
	for kb_action in KEYBOARD_ACTIONS.get(action, []):
		if Input.is_action_pressed(kb_action):
			return true
	
	# Touch buttons
	if action in action_pressed:
		return action_pressed[action]
	
	# Joystick movement
	if action == "move_right" or action == "move_left":
		return _is_movement_action(action)
	
	return false


func is_action_just_pressed(action: String) -> bool:
	# Keyboard / Gamepad
	for kb_action in KEYBOARD_ACTIONS.get(action, []):
		if Input.is_action_just_pressed(kb_action):
			return true
	
	# Touch buttons
	if action in action_press_count:
		if action_press_count[action] > 0:
			action_press_count[action] -= 1
			return true
	
	return false


func get_movement_vector() -> Vector2:
	if joystick_active:
		return joystick_vector
	
	var vec := Vector2.ZERO
	if is_action_pressed("move_right"): vec.x += 1
	if is_action_pressed("move_left"): vec.x -= 1
	return vec.normalized()


# ------------------------------------------------------------
# Touch API
# ------------------------------------------------------------

func set_joystick(value: Vector2) -> void:
	joystick_vector = value
	joystick_active = value.length() > 0.1


func press_button(action: String) -> void:
	if action in action_pressed:
		# Ignore duplicate press notifications while the same control is held,
		# but queue every real new tap until gameplay consumes it.
		if action_pressed[action]:
			return
		action_pressed[action] = true
		action_press_count[action] += 1


func release_button(action: String) -> void:
	if action in action_pressed:
		action_pressed[action] = false
		# Do not clear the queued press here. A quick press/release can happen
		# entirely between two physics frames and must still be detected.


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

func _is_movement_action(action: String) -> bool:
	if not joystick_active:
		return false
	match action:
		"move_right": return joystick_vector.x > 0.2
		"move_left": return joystick_vector.x < -0.2
	return false


func reset_touch_state() -> void:
	joystick_vector = Vector2.ZERO
	joystick_active = false
	for key in action_pressed.keys():
		action_pressed[key] = false
	for key in action_press_count.keys():
		action_press_count[key] = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_touch_state()
