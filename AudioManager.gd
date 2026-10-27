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
var menu_fade_gain: float = 0.0
var last_hover_ms: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")
	
	# Load AudioStreams safely
	if ResourceLoader.exists("res://audio/menu_theme.ogg"):
		bgm_stream = load("res://audio/menu_theme.ogg")
		if bgm_stream is AudioStreamOggVorbis:
			bgm_stream.loop = true
	if ResourceLoader.exists("res://audio/ui_hover.wav"):
		hover_stream = load("res://audio/ui_hover.wav")
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		click_stream = load("res://audio/ui_click.wav")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	bgm_player.stream = bgm_stream
	bgm_player.volume_db = -80.0
	add_child(bgm_player)
	
	sfx_hover_player = AudioStreamPlayer.new()
	sfx_hover_player.bus = "SFX"
	sfx_hover_player.stream = hover_stream
	sfx_hover_player.volume_db = -3.0
	add_child(sfx_hover_player)
	
	sfx_click_player = AudioStreamPlayer.new()
	sfx_click_player.bus = "SFX"
	sfx_click_player.stream = click_stream
	sfx_click_player.volume_db = -1.5
	add_child(sfx_click_player)
	
	apply_audio_settings()

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var bus_index := AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")

func _vol_to_db(linear_vol: float) -> float:
	if linear_vol <= 0.005:
		return -80.0
	return linear_to_db(clampf(linear_vol, 0.001, 1.0))

func _set_menu_fade_gain(value: float) -> void:
	menu_fade_gain = value
	if bgm_player:
		bgm_player.volume_db = _vol_to_db(menu_fade_gain)

func play_menu_music(fade_in_duration: float = 1.0):
	if is_playing_bgm and bgm_player and bgm_player.playing:
		return # Already playing continuously! No reset or restart
	
	if bgm_player == null or bgm_stream == null:
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
	if not bgm_player.playing:
		_set_menu_fade_gain(0.0)
		bgm_player.play()
	fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_method(Callable(self, "_set_menu_fade_gain"), menu_fade_gain, 1.0, fade_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_menu_music(fade_out_duration: float = 0.8):
	is_playing_bgm = false
	if bgm_player == null or not bgm_player.playing:
		return
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_method(Callable(self, "_set_menu_fade_gain"), menu_fade_gain, 0.0, fade_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_callback(Callable(bgm_player, "stop"))

func play_hover():
	if not GameState.is_sfx_enabled or hover_stream == null or sfx_hover_player == null:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - last_hover_ms < 80:
		return
	last_hover_ms = now_ms
	sfx_hover_player.pitch_scale = randf_range(0.97, 1.02)
	sfx_hover_player.play()

func play_click():
	if not GameState.is_sfx_enabled or click_stream == null or sfx_click_player == null:
		return
	sfx_click_player.pitch_scale = randf_range(0.98, 1.02)
	sfx_click_player.play()

func play_blade_slash():
	# Plays dynamic sharp slash sound
	play_click()

func play_hit():
	play_click()

func apply_audio_settings():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _vol_to_db(GameState.music_volume))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_bus, _vol_to_db(GameState.sfx_volume))
	AudioServer.set_bus_mute(sfx_bus, not GameState.is_sfx_enabled)
	if bgm_player:
		_set_menu_fade_gain(menu_fade_gain)
		if not GameState.is_music_enabled and is_playing_bgm:
			stop_menu_music(0.5)
