extends Node
## One run's mutable performance state.  No gameplay nodes write UI directly.

const LAYER_NAMES := ["节拍", "低音 / 鼓组", "主旋律", "和声 / 高音"]
const LAYER_NAMES_SHORT := ["节拍", "低音", "旋律", "和声"]
const LAYER_COLORS := [
	Color("8fb8ff"),
	Color("ff8a6b"),
	Color("ffd166"),
	Color("63f5d2"),
]
const COMBO_TIMEOUT := 4.0

var layers: Array[bool] = [true, false, false, false]
var layers_queued: Array[bool] = [false, false, false, false]
var coda_restored := false

var hits := 0
var perfect := 0
var great := 0
var good := 0
var off := 0
var whiffs := 0
var combo := 0
var max_combo := 0
var damage_taken := 0.0
var hits_taken := 0
var dodges := 0
var deaths := 0
var kills := 0
var kills_by_kind := {}
var key_notes := 0
var used_attacks := {}
var stage := 0
var tutorial_mode := false
var checkpoint_x := 140.0
var boss_defeated := false
var finale_hits := 0
var finale_success := false
var finale_start_time := 0.0
var finale_results: Array = [0, 0, 0, 0]
var run_finished := false
var elapsed := 0.0

var _last_hit_time := -100.0
var _run_started := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset_run()


func _process(delta: float) -> void:
	if run_finished:
		return
	elapsed += delta
	if combo > 0 and (Time.get_ticks_msec() / 1000.0) - _last_hit_time > COMBO_TIMEOUT:
		combo = 0
		GameEvents.combo_changed.emit(combo)


func reset_run() -> void:
	layers = [true, false, false, false]
	layers_queued = [false, false, false, false]
	coda_restored = false
	hits = 0
	perfect = 0
	great = 0
	good = 0
	off = 0
	whiffs = 0
	combo = 0
	max_combo = 0
	damage_taken = 0.0
	hits_taken = 0
	dodges = 0
	deaths = 0
	kills = 0
	kills_by_kind = {}
	key_notes = 0
	used_attacks = {}
	stage = 0
	tutorial_mode = false
	checkpoint_x = 140.0
	boss_defeated = false
	finale_hits = 0
	finale_success = false
	finale_start_time = 0.0
	finale_results = [0, 0, 0, 0]
	run_finished = false
	elapsed = 0.0
	_last_hit_time = -100.0
	_run_started = Time.get_ticks_msec() / 1000.0


func register_hit(attack_id: String, grade: int, delta_ms: float) -> void:
	hits += 1
	match grade:
		Rhythm.Grade.PERFECT:
			perfect += 1
		Rhythm.Grade.GREAT:
			great += 1
		Rhythm.Grade.GOOD:
			good += 1
		_:
			off += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	used_attacks[attack_id] = true
	_last_hit_time = Time.get_ticks_msec() / 1000.0
	GameEvents.judgement.emit(grade, delta_ms, combo,
		Rhythm.ATTACK_NAMES.get(attack_id, "命中"))
	GameEvents.combo_changed.emit(combo)


func register_whiff(attack_id: String) -> void:
	whiffs += 1
	used_attacks[attack_id] = true
	# A whiff does not break the phrase, but it makes the phrase cool down faster.
	_last_hit_time -= 0.7


func register_hurt(amount: float) -> void:
	damage_taken += amount
	hits_taken += 1
	combo = 0
	GameEvents.combo_changed.emit(combo)
	GameEvents.player_hurt.emit(amount)


func register_dodge() -> void:
	dodges += 1
	GameEvents.player_dodged.emit()


func register_kill(kind: String) -> void:
	kills += 1
	kills_by_kind[kind] = int(kills_by_kind.get(kind, 0)) + 1
	GameEvents.enemy_killed.emit(kind)


func recover_note(amount: int = 1) -> void:
	key_notes = mini(4, key_notes + amount)
	GameEvents.note_recovered.emit(key_notes)


func queue_layer(index: int) -> bool:
	if index < 0 or index >= layers.size():
		return false
	if layers[index] or layers_queued[index]:
		return false
	layers_queued[index] = true
	GameEvents.layer_queued.emit(index)
	return true


func unlock_layer(index: int) -> bool:
	if index < 0 or index >= layers.size():
		return false
	layers_queued[index] = false
	if layers[index]:
		return false
	layers[index] = true
	GameEvents.layer_unlocked.emit(index)
	return true


func has_all_layers() -> bool:
	for value: bool in layers:
		if not value:
			return false
	return true


func layer_count() -> int:
	var n := 0
	for value: bool in layers:
		if value:
			n += 1
	return n


func music_fraction() -> float:
	# Four performance voices plus the coda that only a 4/4 finale restores.
	var units := float(layer_count())
	if coda_restored:
		units += 1.0
	return clampf(units / 5.0, 0.0, 1.0)


func accuracy() -> float:
	if hits <= 0:
		return 0.0
	var score := perfect * 1.0 + great * 0.78 + good * 0.5 + off * 0.08
	return clampf(score / float(hits), 0.0, 1.0)


func accuracy_percent() -> int:
	return int(round(accuracy() * 100.0))


func used_all_attacks() -> bool:
	return used_attacks.has("light") and used_attacks.has("heavy") \
		and used_attacks.has("thrust") and used_attacks.has("launcher")


func is_perfect() -> bool:
	return boss_defeated and has_all_layers() and key_notes >= 4 \
		and finale_hits >= 4 and finale_success \
		and accuracy() >= 0.68 and max_combo >= 12 and used_all_attacks()


func rank_data() -> Dictionary:
	if is_perfect():
		return {
			"code": "S",
			"title": "完美乐章",
			"subtitle": "所有声部归位，失序回廊重新歌唱。",
			"color": Color("ffd166"),
		}
	if boss_defeated and accuracy() >= 0.72 and layer_count() >= 3:
		return {
			"code": "A",
			"title": "重奏者",
			"subtitle": "战斗已经结束，仍有几个音符悬而未决。",
			"color": Color("63f5d2"),
		}
	if boss_defeated:
		return {
			"code": "B",
			"title": "归位",
			"subtitle": "乐章得以继续，但它还称不上完整。",
			"color": Color("8fb8ff"),
		}
	return {
		"code": "C",
		"title": "中断的乐句",
		"subtitle": "回廊仍在等待下一次调律。",
		"color": Color("ff8a6b"),
	}


func summary() -> Dictionary:
	return {
		"victory": boss_defeated,
		"perfect": is_perfect(),
		"rank": rank_data(),
		"accuracy": accuracy(),
		"hits": hits,
		"perfect_hits": perfect,
		"great_hits": great,
		"good_hits": good,
		"off_hits": off,
		"whiffs": whiffs,
		"max_combo": max_combo,
		"damage_taken": damage_taken,
		"hits_taken": hits_taken,
		"dodges": dodges,
		"deaths": deaths,
		"kills": kills,
		"layers": layers.duplicate(),
		"key_notes": key_notes,
		"finale_hits": finale_hits,
		"finale_success": finale_success,
		"coda_restored": coda_restored,
		"elapsed": elapsed,
	}


func finish(victory: bool) -> void:
	run_finished = true
	boss_defeated = victory
	GameEvents.run_finished.emit(victory)
