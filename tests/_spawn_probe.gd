extends Node

func _ready() -> void:
	var arena = load("res://main.tscn").instantiate()
	add_child(arena)
	var player = arena.get_node("Player")
	var opp = arena.get_node_or_null("Opponent")
	if opp == null:
		opp = arena.get_node_or_null("Enemy")
	for i in range(5):
		await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout
	for f in [player, opp]:
		if f:
			print("EARLY ", f.name, " pos=", f.global_position, " on_floor=", f.is_on_floor(), " phys=", f.is_physics_processing())
	for i in range(300):
		await get_tree().physics_frame
	for f in [player, opp]:
		if f == null:
			continue
		print("REST ", f.name, " pos=", f.global_position, " on_floor=", f.is_on_floor(), " vel=", f.velocity)
		var s: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
		var rect: Rect2 = s.get_rect()
		var xf: Transform2D = s.get_global_transform()
		print("     sprite rect=", xf * rect.position, " -> ", xf * (rect.position + rect.size), " anim=", s.animation)
	get_tree().quit()
