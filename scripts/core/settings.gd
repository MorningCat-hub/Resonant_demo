extends Node
## Persistent, deliberately tiny settings surface: latency offset + two volumes.

const PATH := "user://resonant_settings.cfg"
const OFFSET_MIN := -200.0
const OFFSET_MAX := 200.0

var offset_ms: float = 0.0
var music_db: float = 0.0
var sfx_db: float = 0.0
var tutorial_seen := false
var _can_write := true


func _ready() -> void:
	load_settings()
	_can_write = DirAccess.open("user://") != null
	if not _can_write:
		push_warning("user:// is not writable; settings will not persist this session")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	offset_ms = clampf(float(cfg.get_value("audio", "offset_ms", 0.0)), OFFSET_MIN, OFFSET_MAX)
	music_db = clampf(float(cfg.get_value("audio", "music_db", 0.0)), -30.0, 6.0)
	sfx_db = clampf(float(cfg.get_value("audio", "sfx_db", 0.0)), -30.0, 6.0)
	tutorial_seen = bool(cfg.get_value("progress", "tutorial_seen", false))


func save_settings() -> void:
	if not _can_write:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "offset_ms", offset_ms)
	cfg.set_value("audio", "music_db", music_db)
	cfg.set_value("audio", "sfx_db", sfx_db)
	cfg.set_value("progress", "tutorial_seen", tutorial_seen)
	cfg.save(PATH)


func set_offset(value: float, persist: bool = true) -> void:
	offset_ms = clampf(value, OFFSET_MIN, OFFSET_MAX)
	if persist:
		save_settings()
	if GameEvents:
		GameEvents.settings_changed.emit()


func nudge_offset(delta: float) -> void:
	set_offset(offset_ms + delta)


func set_music_db(value: float) -> void:
	music_db = clampf(value, -30.0, 6.0)
	save_settings()
	if GameEvents:
		GameEvents.settings_changed.emit()


func set_sfx_db(value: float) -> void:
	sfx_db = clampf(value, -30.0, 6.0)
	save_settings()
	if GameEvents:
		GameEvents.settings_changed.emit()


func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	save_settings()


func reset() -> void:
	offset_ms = 0.0
	music_db = 0.0
	sfx_db = 0.0
	save_settings()
	if GameEvents:
		GameEvents.settings_changed.emit()
