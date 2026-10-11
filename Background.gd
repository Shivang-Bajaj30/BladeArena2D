extends Node2D

# ============================================================
# Living Background — Black void with atmospheric effects
# ============================================================

@export_group("Colors")
@export var base_color: Color = Color(0.03, 0.03, 0.06)
@export var fog_color: Color = Color(0.15, 0.10, 0.20, 0.15)

@export_group("Ember Particles")
@export var ember_count: int = 60
@export var ember_color: Color = Color(1.0, 0.6, 0.2, 0.8)
@export var ember_area: Vector2 = Vector2(800, 500)

@export_group("Glowing Orbs")
@export var orb_count: int = 10
@export var orb_color: Color = Color(0.4, 0.6, 1.0, 0.4)

@export_group("Fog Layers")
@export var fog_layer_count: int = 3

@export_group("Background Pulse")
@export var enable_pulse: bool = true

func _ready():
	print("=== Background script starting ===")
	if GameState:
		var bg_data = GameState.get_background_data(GameState.selected_background)
		if bg_data:
			if "ember_color" in bg_data:
				ember_color = bg_data["ember_color"]
			if "fog_color" in bg_data:
				fog_color = bg_data["fog_color"]
	create_base_background()
	create_fog_layers()
	create_embers()
	create_orbs()
	if enable_pulse:
		start_pulse()
	print("=== Background setup complete ===")

# ------------------------------------------------------------
# 1. Base dark background
# ------------------------------------------------------------
func create_base_background():
	var bg := ColorRect.new()
	bg.color = base_color
	bg.size = Vector2(4000, 3000)
	bg.position = Vector2(-2000, -1500)
	bg.z_index = -100
	add_child(bg)
	
	if GameState:
		var bg_data = GameState.get_background_data(GameState.selected_background)
		if bg_data and ResourceLoader.exists(bg_data["texture_path"]):
			var sprite := Sprite2D.new()
			sprite.texture = load(bg_data["texture_path"])
			sprite.position = Vector2(0, 0)
			# Scale to comfortably cover arena bounds
			sprite.scale = Vector2(2.4, 2.4)
			sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)
			sprite.z_index = -90
			add_child(sprite)

# ------------------------------------------------------------
# 2. Fog layers
# ------------------------------------------------------------
func create_fog_layers():
	for i in range(fog_layer_count):
		var fog := ColorRect.new()
		fog.color = fog_color
		fog.size = Vector2(ember_area.x * 2, 400)
		fog.position = Vector2(
			-ember_area.x,
			randf_range(-300, 300)
		)
		fog.z_index = -50 + i
		add_child(fog)
		
		var tween := create_tween()
		tween.set_loops()
		var speed := randf_range(20, 40)
		tween.tween_property(fog, "position:x", fog.position.x + speed, 12.0 + i * 3)
		tween.tween_property(fog, "position:x", fog.position.x, 12.0 + i * 3)

# ------------------------------------------------------------
# 3. Ember particles
# ------------------------------------------------------------
func create_embers():
	for i in range(ember_count):
		create_ember()

func create_ember():
	var ember := ColorRect.new()
	var size := randf_range(2, 5)
	ember.size = Vector2(size, size)
	ember.color = ember_color
	ember.position = Vector2(
		randf_range(-ember_area.x / 2, ember_area.x / 2),
		randf_range(-ember_area.y / 2, ember_area.y / 2)
	)
	
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ember.material = mat
	
	ember.z_index = -20
	add_child(ember)
	
	var duration := randf_range(4.0, 10.0)
	var drift_x := randf_range(-30, 30)
	var rise := randf_range(200, 500)
	
	var tween := create_tween()
	tween.set_loops()
	tween.parallel().tween_property(ember, "position:x", ember.position.x + drift_x, duration)
	tween.parallel().tween_property(ember, "position:y", ember.position.y - rise, duration)
	tween.parallel().tween_property(ember, "modulate:a", 0.0, duration)
	tween.tween_callback(func():
		ember.position = Vector2(
			randf_range(-ember_area.x / 2, ember_area.x / 2),
			ember_area.y / 2 + 20
		)
		ember.modulate.a = 1.0
	)

# ------------------------------------------------------------
# 4. Glowing orbs
# ------------------------------------------------------------
func create_orbs():
	for i in range(orb_count):
		create_orb()

func create_orb():
	var orb := ColorRect.new()
	var size := randf_range(6, 14)
	orb.size = Vector2(size, size)
	orb.color = orb_color
	orb.position = Vector2(
		randf_range(-ember_area.x / 2, ember_area.x / 2),
		randf_range(-ember_area.y / 2, ember_area.y / 2)
	)
	
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	orb.material = mat
	
	orb.z_index = -15
	add_child(orb)
	
	var duration := randf_range(6.0, 12.0)
	var drift_x := randf_range(-150, 150)
	var drift_y := randf_range(-100, 100)
	
	var tween := create_tween()
	tween.set_loops()
	tween.parallel().tween_property(orb, "position:x", orb.position.x + drift_x, duration)
	tween.parallel().tween_property(orb, "position:y", orb.position.y + drift_y, duration)
	
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(orb, "modulate:a", 0.3, 1.5)
	pulse.tween_property(orb, "modulate:a", 1.0, 1.5)

# ------------------------------------------------------------
# 5. Global pulse
# ------------------------------------------------------------
func start_pulse():
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", Color(1.05, 1.05, 1.1), 3.0)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 3.0)
