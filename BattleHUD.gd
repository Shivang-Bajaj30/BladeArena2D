extends Control

var player_bar: ProgressBar
var opponent_bar: ProgressBar
var player_label: Label
var opponent_label: Label
var result_label: Label
var player_value_label: Label
var opponent_value_label: Label
var round_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_hud()
	call_deferred("bind_fighters")

func create_hud() -> void:
	player_bar = create_health_bar(Color(0.25, 0.8, 1.0), Color(0.05, 0.15, 0.24, 0.92))
	player_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_bar.position = Vector2(240, 60)
	player_bar.size = Vector2(540, 54)
	add_child(player_bar)
	player_value_label = create_bar_value_label()
	player_bar.add_child(player_value_label)

	opponent_bar = create_health_bar(Color(0.9, 0.28, 0.62), Color(0.24, 0.04, 0.15, 0.92))
	opponent_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	opponent_bar.position = Vector2(-780, 60)
	opponent_bar.size = Vector2(540, 54)
	add_child(opponent_bar)
	opponent_value_label = create_bar_value_label()
	opponent_bar.add_child(opponent_value_label)

	player_label = create_label("PLAYER", HORIZONTAL_ALIGNMENT_LEFT)
	player_label.position = Vector2(240, 12)
	player_label.size = Vector2(540, 42)
	add_child(player_label)

	opponent_label = create_label("SHADOW RIVAL", HORIZONTAL_ALIGNMENT_RIGHT)
	opponent_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	opponent_label.position = Vector2(-780, 12)
	opponent_label.size = Vector2(540, 42)
	add_child(opponent_label)

	round_label = create_label("ROUND 1 / 3", HORIZONTAL_ALIGNMENT_CENTER)
	round_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	round_label.position = Vector2(-170, 110)
	round_label.size = Vector2(340, 42)
	round_label.add_theme_font_size_override("font_size", 24)
	round_label.add_theme_color_override("font_color", Color(0.58, 0.78, 0.94))
	add_child(round_label)

	result_label = create_label("", HORIZONTAL_ALIGNMENT_CENTER)
	result_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	result_label.position = Vector2(-360, 160)
	result_label.size = Vector2(720, 92)
	result_label.add_theme_font_size_override("font_size", 58)
	result_label.modulate.a = 0.0
	add_child(result_label)

func create_health_bar(fill_color: Color, background_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = background_color
	background.border_color = fill_color.darkened(0.28)
	background.set_border_width_all(4)
	background.set_corner_radius_all(16)
	background.corner_detail = 16
	background.shadow_color = Color(0, 0, 0, 0.55)
	background.shadow_size = 9
	var fill := background.duplicate() as StyleBoxFlat
	fill.bg_color = fill_color
	fill.border_color = fill_color.lightened(0.34)
	fill.shadow_size = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func create_label(label_text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.94, 0.9, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.1, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func create_bar_value_label() -> Label:
	var label := create_label("100 / 100", HORIZONTAL_ALIGNMENT_CENTER)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func bind_fighters() -> void:
	var players := get_tree().get_nodes_in_group("player_fighter")
	if not players.is_empty():
		var player = players[0]
		player_label.text = GameState.get_character_data(GameState.selected_character)["name"]
		player.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(player.health, player.max_health)

func bind_opponent(opponent: Node, fighter_name: String, round_number: int, total_rounds: int) -> void:
	opponent_label.text = fighter_name
	round_label.text = "ROUND %d / %d" % [round_number, total_rounds]
	opponent.health_changed.connect(_on_opponent_health_changed)
	_on_opponent_health_changed(opponent.health, opponent.max_health)

func _on_player_health_changed(current: float, maximum: float) -> void:
	player_bar.max_value = maximum
	create_tween().tween_property(player_bar, "value", current, 0.18)
	player_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]

func _on_opponent_health_changed(current: float, maximum: float) -> void:
	opponent_bar.max_value = maximum
	create_tween().tween_property(opponent_bar, "value", current, 0.18)
	opponent_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]

func show_result(message: String, color: Color) -> void:
	result_label.text = message
	result_label.modulate = Color(color, 0.0)
	result_label.scale = Vector2(0.65, 0.65)
	result_label.pivot_offset = result_label.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(result_label, "modulate:a", 1.0, 0.28)
	tween.tween_property(result_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK)

func clear_result() -> void:
	var tween := create_tween()
	tween.tween_property(result_label, "modulate:a", 0.0, 0.2)
