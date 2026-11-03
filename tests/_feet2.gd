extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func lowest_row(res: SpriteFrames, anim_name: String) -> int:
	if not res.has_animation(anim_name):
		return -1
	var tex: Texture2D = res.get_frame_texture(anim_name, 0)
	if tex == null:
		return -1
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var lowest: int = -1
	for y in range(img.get_height()):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a > 0.1:
				lowest = y
				break
	return lowest

func run() -> void:
	var fig: SpriteFrames = load("res://fig_1.tres")
	var stick: SpriteFrames = load("res://stick_fig.tres")
	for pair in [[fig, "fig_1", ["idle_sword", "idle", "punch_combo", "run", "walk", "attack", "jump"]],
			[stick, "stick_fig", ["idle", "walk", "run", "attack_combo", "jump"]]]:
		var res: SpriteFrames = pair[0]
		var label: String = pair[1]
		for a in pair[2]:
			var h: int = 1
			if res.has_animation(a):
				var t: Texture2D = res.get_frame_texture(a, 0)
				if t:
					h = t.get_height()
			var low: int = lowest_row(res, a)
			if low == -1:
				print(label, "/", a, " MISSING")
				continue
			# sprite node offset is (-400, -300); feet local = offset.y - h/2 + row
			var feet_local: float = -300.0 - h * 0.5 + float(low)
			print(label, "/", a, " h=", h, " lowest_row=", low, " feet_sprite=", feet_local,
				" feet_player_local=", 132.0 + feet_local, " implied_shape_pos=", 132.0 + feet_local - 40.0)
	quit()
