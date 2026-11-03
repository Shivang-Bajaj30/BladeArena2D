extends Node

func _ready() -> void:
	var arena = load("res://main.tscn").instantiate()
	add_child(arena)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/_spawn_banner.png")
	var player = arena.get_node("Player")
	var opp = arena.get_node_or_null("Opponent")
	print("SPAWN player=", player.global_position, " opp=", opp.global_position if opp else null)
	for f in [player, opp]:
		if f:
			var s: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
			var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
			print("  ", f.name, " tex=", tex.get_size(), " sprite_pos=", s.global_position, " offset=", s.offset,
				" feet_y=", s.global_position.y + s.global_scale.y * (s.offset.y + tex.get_size().y * 0.5))
	for i in range(360):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/_spawn_rest.png")
	print("REST player=", player.global_position, " opp=", opp.global_position if opp else null)
	get_tree().quit()
