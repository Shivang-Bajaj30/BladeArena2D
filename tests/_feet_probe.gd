extends Node

func _ready() -> void:
	var arena = load("res://main.tscn").instantiate()
	add_child(arena)
	await get_tree().create_timer(0.4).timeout
	var player = arena.get_node("Player")
	var opp = arena.get_node_or_null("Opponent")
	for f in [player, opp]:
		if f == null:
			continue
		var s: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
		var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var h: int = img.get_height()
		var w: int = img.get_width()
		var lowest: int = -1
		var top: int = -1
		for y in range(h):
			for x in range(0, w, 4):
				if img.get_pixel(x, y).a > 0.1:
					if top == -1:
						top = y
					lowest = y
					break
		var sc: Vector2 = s.global_scale
		var local_bottom: float = s.offset.y - h * 0.5 + float(lowest)
		var world_feet: float = s.global_position.y + sc.y * local_bottom
		var local_top: float = s.offset.y - h * 0.5 + float(top)
		var world_top: float = s.global_position.y + sc.y * local_top
		print(f.name, " box_center_y=", f.global_position.y, " visual_head_y=", world_top, " visual_feet_y=", world_feet,
			" floor_top=515.0  gap_to_floor=", 515.0 - world_feet)
	for i in range(360):
		await get_tree().physics_frame
	for f in [player, opp]:
		if f == null:
			continue
		var s: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
		var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var h: int = img.get_height()
		var lowest: int = -1
		for y in range(h):
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a > 0.1:
					lowest = y
					break
		var world_feet: float = s.global_position.y + s.global_scale.y * (s.offset.y - h * 0.5 + float(lowest))
		print("REST ", f.name, " box_y=", f.global_position.y, " visual_feet_y=", world_feet, " gap_to_floor=", 515.0 - world_feet)
	get_tree().quit()
