extends Node
## Loads the generated audio and provides a small polyphonic SFX pool.
## Attack sounds never wait for the beat.

const SFX_NAMES := [
	"ui_move", "ui_confirm", "ui_back", "click", "metronome_hi",
	"swing_light", "swing_heavy", "swing_thrust", "swing_launch",
	"hit_light", "hit_heavy", "hit_thrust", "hit_launch", "hit_armor",
	"perfect", "great", "good", "dodge", "hurt",
	"death_note", "death_guard", "death_sprite", "death_dissonant",
	"note_pickup", "checkpoint", "seal_hit", "seal_complete", "unlock",
	"boss_telegraph", "boss_slam", "boss_shot", "boss_hurt",
	"finale_hit", "finale_success", "finale_fail",
	"telegraph", "resonance",
]

const MUSIC_NAMES := [
	"level_pulse", "level_bass", "level_melody", "level_harmony",
	"boss_pulse", "boss_lead", "boss_coda",
]

const POOL_SIZE := 22

var sfx: Dictionary = {}
var music: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name: String in SFX_NAMES:
		var path := "res://assets/audio/%s.wav" % name
		var stream: AudioStream = load(path)
		if stream:
			sfx[name] = stream
		else:
			push_warning("Missing SFX: " + path)
	for name: String in MUSIC_NAMES:
		var path := "res://assets/audio/%s.wav" % name
		var stream: AudioStream = load(path)
		if stream:
			_prepare_loop(stream)
			music[name] = stream
		else:
			push_warning("Missing music stem: " + path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.max_polyphony = 2
		add_child(p)
		_pool.append(p)


func _prepare_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stop()
	p.stream = sfx[name]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = clampf(Settings.sfx_db + volume_db, -60.0, 12.0)
	p.play()


func play_varied(name: String, volume_db: float = 0.0, spread: float = 0.05) -> void:
	play(name, 1.0 + randf_range(-spread, spread), volume_db)


func stop_all_sfx() -> void:
	for p: AudioStreamPlayer in _pool:
		p.stop()
