extends Node
## Single source of musical truth.
##
## Every stem is started together on one sample-zero and loops for exactly
## 32 bars at 120 BPM.  Judgement and boss scheduling read this clock, never a
## freshly-created Timer.  Pausing freezes the streams, not the wall clock.

const LEVEL_STEMS := ["level_pulse", "level_bass", "level_melody", "level_harmony"]
const BOSS_STEMS := ["boss_pulse", "boss_lead", "boss_coda"]
const LEVEL_DB := [-12.0, -9.0, -10.0, -14.0]
const BOSS_DB := [-9.0, -9.0, -13.0]
const MUTE_DB := -70.0

var song_id := ""
var playing := false
var paused := false
var master: AudioStreamPlayer
var players: Dictionary = {}
var song_length := 64.0
var boss_phase := 1

var _current_bar := -1
var _pending_layers: Array[int] = []
var _pending_coda := false
var _pause_position := 0.0
var _fallback_started := 0.0
var _has_song := false
var _coda_requested := false
var timeline := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for name: String in LEVEL_STEMS + BOSS_STEMS:
		var p := AudioStreamPlayer.new()
		p.name = "Stem_" + name
		p.stream = AudioBank.music.get(name)
		p.volume_db = MUTE_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		players[name] = p
	GameEvents.layer_unlocked.connect(_on_layer_unlocked)
	GameEvents.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if not playing or paused or not _has_song:
		return
	timeline += delta
	var pos := get_song_time()
	var bar := int(floor(pos / Rhythm.BAR))
	if bar == _current_bar:
		return
	_current_bar = bar
	if not _pending_layers.is_empty():
		for index: int in _pending_layers:
			_fade_stem(LEVEL_STEMS[index], _layer_db(index), 0.55)
		_pending_layers.clear()
	if _pending_coda:
		_pending_coda = false
		_fade_stem("boss_coda", BOSS_DB[2] + Settings.music_db, 1.4)
		var lead := players["boss_lead"] as AudioStreamPlayer
		lead.create_tween().tween_property(lead, "volume_db",
			BOSS_DB[1] + Settings.music_db - 3.0, 1.4)


func play_level() -> void:
	_stop_all()
	song_id = "level"
	_has_song = true
	_fallback_started = Time.get_ticks_msec() / 1000.0
	timeline = 0.0
	paused = false
	_current_bar = -1
	_pending_layers.clear()
	_pending_coda = false
	_coda_requested = false
	for i in LEVEL_STEMS.size():
		var p := players[LEVEL_STEMS[i]] as AudioStreamPlayer
		p.stream = AudioBank.music.get(LEVEL_STEMS[i])
		p.volume_db = _layer_db(i) if GameState.layers[i] else MUTE_DB
		p.stream_paused = false
		p.play(0.0)
	for name: String in BOSS_STEMS:
		var b := players[name] as AudioStreamPlayer
		b.stop()
		b.volume_db = MUTE_DB
	master = players["level_pulse"] as AudioStreamPlayer
	song_length = master.stream.get_length() if master.stream else 64.0
	playing = true


func play_boss() -> void:
	_stop_all()
	song_id = "boss"
	_has_song = true
	_fallback_started = Time.get_ticks_msec() / 1000.0
	timeline = 0.0
	paused = false
	_current_bar = -1
	boss_phase = 1
	_coda_requested = false
	_pending_coda = false
	for name: String in BOSS_STEMS:
		var p := players[name] as AudioStreamPlayer
		p.stream = AudioBank.music.get(name)
		p.volume_db = BOSS_DB[BOSS_STEMS.find(name)] + Settings.music_db
		if name == "boss_coda":
			p.volume_db = MUTE_DB
		p.stream_paused = false
		p.play(0.0)
	for name: String in LEVEL_STEMS:
		var l := players[name] as AudioStreamPlayer
		l.stop()
		l.volume_db = MUTE_DB
	master = players["boss_pulse"] as AudioStreamPlayer
	song_length = master.stream.get_length() if master.stream else 64.0
	playing = true
	_fade_stem("boss_coda", MUTE_DB, 0.01)


func set_boss_phase(phase: int) -> void:
	boss_phase = clampi(phase, 1, 3)
	if song_id != "boss":
		return
	var targets := [-8.0, -9.0, -11.0]
	match boss_phase:
		1:
			targets = [-11.0, -13.0, -70.0]
		2:
			targets = [-10.0, -10.0, -70.0]
		3:
			targets = [-9.0, -8.0, -70.0]
	for i in BOSS_STEMS.size():
		if BOSS_STEMS[i] == "boss_coda":
			continue
		_fade_stem(BOSS_STEMS[i], targets[i] + Settings.music_db, 0.8)


func enable_coda() -> void:
	if not playing or _coda_requested:
		return
	_coda_requested = true
	_pending_coda = true
	GameEvents.coda_unlocked.emit()


func get_song_time() -> float:
	if not playing:
		return fposmod(Time.get_ticks_msec() / 1000.0 - _fallback_started, Rhythm.BAR * 32.0)
	if paused:
		return _pause_position
	if master == null or not master.playing:
		return fposmod(Time.get_ticks_msec() / 1000.0 - _fallback_started, song_length)
	var pos := master.get_playback_position()
	pos += AudioServer.get_time_since_last_mix()
	pos -= AudioServer.get_output_latency()
	if song_length > 0.01:
		pos = fposmod(pos, song_length)
	return pos


func get_judge_time() -> float:
	return get_song_time() + Settings.offset_ms / 1000.0


func get_timeline() -> float:
	return timeline


func judge(window_scale: float = 1.0) -> Dictionary:
	return Rhythm.judge_at(get_judge_time(), window_scale)


func beat_info() -> Dictionary:
	return Rhythm.beat_info(get_song_time())


func get_beat_phase() -> float:
	return fposmod(get_song_time() / Rhythm.BEAT, 1.0)


func time_to_next_beat() -> float:
	var phase := get_beat_phase()
	return (1.0 - phase) * Rhythm.BEAT


func is_on_beat(window: float = 0.10) -> bool:
	return Rhythm.abs_delta_to_beat(get_judge_time()) <= window


func set_paused(value: bool) -> void:
	if paused == value:
		return
	if value:
		_pause_position = get_song_time()
		paused = true
		for p: AudioStreamPlayer in players.values():
			if p.playing:
				p.stream_paused = true
	else:
		paused = false
		for p: AudioStreamPlayer in players.values():
			if p.playing:
				p.stream_paused = false
		if _has_song and master:
			_current_bar = -1


func stop_all() -> void:
	_stop_all()
	playing = false
	song_id = ""


func _stop_all() -> void:
	for p: AudioStreamPlayer in players.values():
		p.stop()
		p.volume_db = MUTE_DB
		p.stream_paused = false


func _layer_db(index: int) -> float:
	return LEVEL_DB[index] + Settings.music_db


func _fade_stem(name: String, target_db: float, duration: float) -> void:
	var p := players.get(name) as AudioStreamPlayer
	if p == null:
		return
	var tween := p.create_tween()
	tween.tween_property(p, "volume_db", target_db, duration)


func _on_layer_unlocked(index: int) -> void:
	if song_id != "level":
		return
	if not _pending_layers.has(index):
		_pending_layers.append(index)


func _on_settings_changed() -> void:
	if not playing:
		return
	if song_id == "level":
		for i in LEVEL_STEMS.size():
			if GameState.layers[i] and players.has(LEVEL_STEMS[i]):
				_fade_stem(LEVEL_STEMS[i], _layer_db(i), 0.25)
	elif song_id == "boss":
		set_boss_phase(boss_phase)
