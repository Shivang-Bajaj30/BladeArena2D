extends Node2D

@export var particle_count: int = 50

func _ready():
	position = Vector2.ZERO
	scale = Vector2.ONE
	# Get the screen size
	var screen_size := get_viewport().get_visible_rect().size
	
	# Dark background that fills the screen
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08)  # Very dark
	bg.size = screen_size
	bg.position = -screen_size / 2  # Center it
	add_child(bg)
	
	# Create embers
	for i in range(particle_count):
		create_ember(screen_size)
	
	# Create glow orbs
	for i in range(5):
		create_glow_orb(screen_size)

func create_ember(screen_size: Vector2):
	var ember := Sprite2D.new()
	ember.texture = create_glow_texture(4)
	ember.modulate = Color(1, randf_range(0.3, 0.8), randf_range(0, 0.2), 0.8)
	ember.position = Vector2(
		randf_range(-screen_size.x/2, screen_size.x/2),
		randf_range(-screen_size.y/2, screen_size.y/2)
	)
	add_child(ember)
	
	var tween := create_tween()
	tween.set_loops()
	var duration := randf_range(3, 6)
	var target_y := ember.position.y - randf_range(50, 150)
	tween.tween_property(ember, "position:y", target_y, duration)
	tween.tween_property(ember, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.tween_callback(ember.queue_free)

func create_glow_texture(radius: float) -> ImageTexture:
	var image := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(radius, radius)
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist := Vector2(x, y).distance_to(center)
			if dist < radius:
				var alpha := 1.0 - (dist / radius)
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func create_glow_orb(screen_size: Vector2):
	var orb := Sprite2D.new()
	orb.texture = create_glow_texture(randi_range(20, 60))
	orb.modulate = Color(randf_range(0.5, 1), randf_range(0, 0.3), randf_range(0, 0.3), 0.15)
	orb.position = Vector2(
		randf_range(-screen_size.x/2, screen_size.x/2),
		randf_range(-screen_size.y/2, screen_size.y/2)
	)
	orb.scale = Vector2(randf_range(1, 3), randf_range(1, 3))
	add_child(orb)
	
	var tween := create_tween()
	tween.set_loops()
	var duration := randf_range(8, 15)
	tween.tween_property(orb, "position:y", orb.position.y + randf_range(20, 60), duration).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(orb, "position:y", orb.position.y, duration).set_ease(Tween.EASE_IN_OUT)
