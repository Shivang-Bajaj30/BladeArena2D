extends TouchScreenButton

# ============================================================
# TouchJoystick - Image-based on-screen joystick
# ============================================================

@export var max_radius: float = 50.0
@export var dead_zone: float = 0.12
@export var activation_radius_multiplier: float = 2.2
@export var handoff_radius_multiplier: float = 3.0
@export var max_owner_jump_pixels: float = 240.0
@export var base_texture: Texture2D
@export var knob_texture: Texture2D
@export var base_scale: float = 0.4
@export var knob_scale: float = 0.4

var knob: Sprite2D
var base_sprite: Sprite2D
var _touch_index: int = -1
var _active: bool = false
var _touch_positions: Dictionary = {}
var _owner_screen_position: Vector2 = Vector2.ZERO
var _owner_last_event_ms: int = 0

# After this long without a single event from the owner, a press reusing its
# index far from the stick is treated as a recycled Android pointer rather than
# as the live owner. Keeps a live stick from being reset by a spurious event.
const STALE_OWNER_MS: int = 250

func _ready():
	add_to_group("touch_joystick")
	set_process_input(true)
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
		if event.pressed:
			# A press is always a brand-new finger. If it reuses the owner's index
			# but lands away from the stick AND the owner has been silent, the OS
			# recycled the index after the real owner was lifted and its release
			# was lost. While the owner is still reporting, ignore such a spurious
			# event instead of resetting a live stick.
			if _active and event.index == _touch_index and not can_recover_touch(event.position) \
					and Time.get_ticks_msec() - _owner_last_event_ms >= STALE_OWNER_MS:
				_active = false
				_touch_index = -1
				_owner_screen_position = Vector2.ZERO
				reset_joystick()
			_touch_positions[event.index] = event.position
			if not _active and can_claim_touch(event.position):
				claim_touch(event.index, event.position)
			elif _active and event.index != _touch_index and is_inside_core_area(event.position):
				# Re-grip: a new finger planted right on the stick takes over.
				claim_touch(event.index, event.position)
		else:
			_touch_positions.erase(event.index)
			if event.index == _touch_index:
				# Always release/hand off on the owner's release. Bailing out on a
				# suspicious position used to leave the joystick stuck active.
				handoff_or_release()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			# The owning finger is identified by its touch index, so its motion
			# never needs a position sanity check. The old distance/side filters
			# rejected real fast flicks (a thumb can jump far between frames or
			# cross the screen midline), which froze the stick mid-sweep and felt
			# exactly like the joystick "slipping". Only discard Android's bogus
			# zero-coordinate event.
			if is_zero_position_glitch(event.position):
				return
			_touch_positions[event.index] = event.position
			_owner_screen_position = event.position
			_owner_last_event_ms = Time.get_ticks_msec()
			update_joystick(event.position)
		else:
			_touch_positions[event.index] = event.position
			if not _active:
				# Android occasionally delivers a drag before the matching press.
				if can_claim_touch(event.position):
					claim_touch(event.index, event.position)
			elif can_recover_touch(event.position):
				# Android reassigns pointer indices when another finger lifts, so
				# the joystick's finger can suddenly report under a new index. The
				# drag is on the stick side, so let the surviving finger take over
				# immediately instead of freezing the stick. Action-button fingers
				# (right side) can never satisfy this test.
				claim_touch(event.index, event.position)

func is_inside_area(pos: Vector2) -> bool:
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * pos
	return local_pos.length() < max_radius * activation_radius_multiplier

func is_inside_core_area(pos: Vector2) -> bool:
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * pos
	return local_pos.length() < max_radius * 1.5

func is_inside_handoff_area(pos: Vector2) -> bool:
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * pos
	return local_pos.length() < max_radius * handoff_radius_multiplier

func is_on_joystick_side(pos: Vector2) -> bool:
	var visible_rect := get_viewport().get_visible_rect()
	return pos.x < visible_rect.position.x + visible_rect.size.x * 0.5

func can_claim_touch(pos: Vector2) -> bool:
	return is_on_joystick_side(pos) and is_inside_area(pos)

func can_recover_touch(pos: Vector2) -> bool:
	return is_on_joystick_side(pos) and is_inside_handoff_area(pos)

func is_zero_position_glitch(pos: Vector2) -> bool:
	return pos.length_squared() < 64.0 and _owner_screen_position.length_squared() > 4096.0

func is_plausible_owner_touch(pos: Vector2) -> bool:
	# Reject Android's occasional zero-position release and distant events from
	# the action side, while accepting a genuine release anywhere on the stick side.
	if is_zero_position_glitch(pos):
		return false
	return is_on_joystick_side(pos) or pos.distance_to(_owner_screen_position) <= max_owner_jump_pixels

func is_plausible_owner_motion(pos: Vector2) -> bool:
	# A same-finger flick can legitimately travel hundreds of pixels between
	# frames. Never throttle that motion while it remains on the joystick side.
	if is_zero_position_glitch(pos):
		return false
	return is_on_joystick_side(pos) or pos.distance_to(_owner_screen_position) <= max_owner_jump_pixels

func is_plausible_owner_event(pos: Vector2) -> bool:
	# Kept as a compatibility alias for older tests and scene scripts.
	if pos.length_squared() < 64.0 and _owner_screen_position.length_squared() > 4096.0:
		return false
	return is_plausible_owner_touch(pos)

func claim_touch(index: int, pos: Vector2) -> void:
	if _active and _touch_index != index:
		_touch_positions.erase(_touch_index)
	_touch_index = index
	_active = true
	_owner_screen_position = pos
	_owner_last_event_ms = Time.get_ticks_msec()
	update_joystick(pos)

func handoff_or_release() -> void:
	var best_index := -1
	var best_distance := INF
	var inverse_canvas := get_global_transform_with_canvas().affine_inverse()

	for index in _touch_positions.keys():
		if index == _touch_index:
			continue
		var pos: Vector2 = _touch_positions[index]
		if not is_on_joystick_side(pos) or not is_inside_handoff_area(pos):
			continue
		var distance := (inverse_canvas * pos).length_squared()
		if distance < best_distance:
			best_distance = distance
			best_index = index

	if best_index >= 0:
		claim_touch(best_index, _touch_positions[best_index])
	else:
		_active = false
		_touch_index = -1
		_owner_screen_position = Vector2.ZERO
		reset_joystick()

func update_joystick(screen_pos: Vector2) -> void:
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_pos
	var clamped: Vector2 = local_pos
	if clamped.length() > max_radius:
		clamped = clamped.normalized() * max_radius

	if knob:
		knob.position = clamped

	var norm: Vector2 = clamped / max_radius
	if norm.length() < dead_zone:
		norm = Vector2.ZERO
	else:
		# Rescale the live range after the dead zone, preserving immediate
		# direction changes without a sticky low-speed ring.
		var strength := inverse_lerp(dead_zone, 1.0, minf(norm.length(), 1.0))
		norm = norm.normalized() * strength

	InputManager.set_joystick(norm)

func reset_joystick():
	if knob:
		knob.position = Vector2.ZERO
	InputManager.set_joystick(Vector2.ZERO)

func release_all() -> void:
	# Called when the game pauses: releases that happen while input is suspended
	# never reach _input(), so clear ownership explicitly to avoid a stuck stick.
	_active = false
	_touch_index = -1
	_touch_positions.clear()
	_owner_screen_position = Vector2.ZERO
	reset_joystick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_active = false
		_touch_index = -1
		_touch_positions.clear()
		_owner_screen_position = Vector2.ZERO
		reset_joystick()

func _exit_tree() -> void:
	_active = false
	_touch_index = -1
	_touch_positions.clear()
	_owner_screen_position = Vector2.ZERO
	reset_joystick()
