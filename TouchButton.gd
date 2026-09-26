extends TouchScreenButton

# ============================================================
# TouchButton - Circular button with icon
# ============================================================

@export var action_name: String = "jump"
@export var button_texture: Texture2D
@export var icon_texture: Texture2D
@export var button_size: float = 120.0
@export var icon_size: float = 50.0
@export var button_tint: Color = Color(1, 1, 1, 1)

var _bg: Sprite2D
var _icon: Sprite2D
var _is_pressed: bool = false

func _ready():
	create_visuals()
	pressed.connect(_on_pressed)
	released.connect(_on_released)

func create_visuals():
	if button_texture:
		_bg = Sprite2D.new()
		_bg.texture = button_texture
		_bg.scale = Vector2(button_size / button_texture.get_width(),
							 button_size / button_texture.get_height())
		_bg.modulate = button_tint
		_bg.z_index = 10
		add_child(_bg)

	if icon_texture:
		_icon = Sprite2D.new()
		_icon.texture = icon_texture
		_icon.scale = Vector2(icon_size / icon_texture.get_width(),
							   icon_size / icon_texture.get_height())
		_icon.z_index = 11
		add_child(_icon)

func _on_pressed():
	_is_pressed = true
	InputManager.press_button(action_name)
	if _bg:
		_bg.modulate = button_tint * 1.4
	if _icon:
		_icon.scale *= 0.85

func _on_released():
	_is_pressed = false
	InputManager.release_button(action_name)
	if _bg:
		_bg.modulate = button_tint
	if _icon:
		_icon.scale /= 0.85
