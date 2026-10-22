extends Node

# Continuous background music & UI SFX player across scene switches
var bgm_player: AudioStreamPlayer
var sfx_hover_player: AudioStreamPlayer
var sfx_click_player: AudioStreamPlayer

var bgm_stream: AudioStream
var hover_stream: AudioStream
var click_stream: AudioStream

var is_playing_bgm: bool = false
var fade_tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load AudioStreams safely
	if ResourceLoader.exists("res://audio/menu_bgm.wav"):
		bgm_stream = load("res://audio/menu_bgm.wav")
	if ResourceLoader.exists("res://audio/ui_hover.wav"):
		hover_stream = load("res://audio/ui_hover.wav")
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		click_stream = load("res://audio/ui_click.wav")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.stream = bgm_stream
	bgm_player.volume_db = _vol_to_db(GameState.music_volume)
	add_child(bgm_player)
	
	# Ensure music loops
	bgm_player.finished.connect(_on_bgm_finished)
	
	sfx_hover_player = AudioStreamPlayer.new()
	sfx_hover_player.bus = "Master"
	sfx_hover_player.stream = hover_stream
	sfx_hover_player.volume_db = _vol_to_db(GameState.sfx_volume)
	add_child(sfx_hover_player)
	
	sfx_click_player = AudioStreamPlayer.new()
	sfx_click_player.bus = "Master"
	sfx_click_player.stream = click_stream
	sfx_click_player.volume_db = _vol_to_db(GameState.sfx_volume)
	add_child(sfx_click_player)
	
	apply_audio_settings()

func _vol_to_db(linear_vol: float) -> float:
	if linear_vol <= 0.005:
		return -80.0
	return linear_to_db(clampf(linear_vol, 0.001, 1.0))

func _on_bgm_finished():
	if is_playing_bgm and GameState.is_music_enabled and bgm_player:
		bgm_player.play()

func play_menu_music(fade_in_duration: float = 1.0):
	if is_playing_bgm and bgm_player and bgm_player.playing:
		return # Already playing continuously! No reset or restart
	
	if bgm_player == null:
		return
	if bgm_stream and bgm_player.stream == null:
		bgm_player.stream = bgm_stream
		
	is_playing_bgm = true
	
	if not GameState.is_music_enabled:
		bgm_player.volume_db = -80.0
		return

	var target_volume_db = _vol_to_db(GameState.music_volume)
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	bgm_player.volume_db = -60.0
	bgm_player.play()
	
	fade_tween = create_tween()
	fade_tween.tween_property(bgm_player, "volume_db", target_volume_db, fade_in_duration)

func stop_menu_music(fade_out_duration: float = 0.8):
	is_playing_bgm = false
	if bgm_player == null or not bgm_player.playing:
		return
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(bgm_player, "volume_db", -60.0, fade_out_duration)
	fade_tween.tween_callback(Callable(bgm_player, "stop"))

func play_hover():
	if not GameState.is_sfx_enabled or hover_stream == null or sfx_hover_player == null:
		return
	sfx_hover_player.pitch_scale = randf_range(0.95, 1.08)
	sfx_hover_player.play()

func play_click():
	if not GameState.is_sfx_enabled or click_stream == null or sfx_click_player == null:
		return
	sfx_click_player.pitch_scale = randf_range(0.97, 1.04)
	sfx_click_player.play()

func play_blade_slash():
	# Plays dynamic sharp slash sound
	play_click()

func play_hit():
	play_click()

func apply_audio_settings():
	if bgm_player:
		if GameState.is_music_enabled:
			bgm_player.volume_db = _vol_to_db(GameState.music_volume)
			if is_playing_bgm and not bgm_player.playing:
				bgm_player.play()
		else:
			bgm_player.volume_db = -80.0
	
	if sfx_hover_player:
		sfx_hover_player.volume_db = _vol_to_db(GameState.sfx_volume) if GameState.is_sfx_enabled else -80.0
	if sfx_click_player:
		sfx_click_player.volume_db = _vol_to_db(GameState.sfx_volume) if GameState.is_sfx_enabled else -80.0
