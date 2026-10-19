extends Control
## In-run HUD.  Everything here is presentation only; the game never waits on it.

var objective := "清除失序音符"
var objective_sub := "让每一次命中落在节拍上"
var hint_text := ""
var hint_timer := 0.0
var toast_text := ""
var toast_color := ResonantUI.GOLD
var toast_timer := 0.0
var judge_grade := -1
var judge_delta := 0.0
var judge_timer := 0.0
var judge_combo := 0
var combo_pop := 0.0
var hp := 100.0
var max_hp := 100.0
var boss_active := false
var boss_hp := 0.0
var boss_max := 1.0
var boss_phase := 1
var title_timer := 0.0
var title_text := ""
var title_sub := ""
var title_index := 0
var death_timer := 0.0
var flash_color := Color(1, 1, 1, 0)
var flash_timer := 0.0
var flash_duration := 0.2
var finale_active := false
var finale_finished := false
var _time := 0.0
var _layer_flash := [0.0, 0.0, 0.0, 0.0]
var _combo := 0
var _max_combo := 0
var _accuracy := 0
var _keys := {"light": "K", "heavy": "J", "thrust": "L", "launcher": "I"}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp = GameConfig.PLAYER_MAX_HP
	max_hp = GameConfig.PLAYER_MAX_HP
	GameEvents.judgement.connect(_on_judgement)
	GameEvents.combo_changed.connect(_on_combo)
	GameEvents.player_health_changed.connect(_on_health)
	GameEvents.layer_unlocked.connect(_on_layer)
	GameEvents.objective_changed.connect(_on_objective)
	GameEvents.toast.connect(_on_toast)
	GameEvents.hint.connect(_on_hint)
	GameEvents.stage_changed.connect(_on_stage)
	GameEvents.boss_started.connect(_on_boss_started)
	GameEvents.boss_health_changed.connect(_on_boss_health)
	GameEvents.boss_phase_changed.connect(_on_boss_phase)
	GameEvents.finale_started.connect(_on_finale_started)
	GameEvents.finale_hit.connect(_on_finale_hit)
	GameEvents.finale_finished.connect(_on_finale_finished)
	GameEvents.player_died.connect(_on_died)
	GameEvents.player_respawned.connect(_on_respawned)
	GameEvents.flash.connect(_on_flash)
	GameEvents.note_recovered.connect(_on_note)
	GameEvents.coda_unlocked.connect(_on_coda)


func _process(delta: float) -> void:
	_time += delta
	hint_timer = maxf(0.0, hint_timer - delta)
	toast_timer = maxf(0.0, toast_timer - delta)
	judge_timer = maxf(0.0, judge_timer - delta)
	title_timer = maxf(0.0, title_timer - delta)
	death_timer = maxf(0.0, death_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	combo_pop = maxf(0.0, combo_pop - delta * 3.5)
	for i in 4:
		_layer_flash[i] = maxf(0.0, _layer_flash[i] - delta)
	_combo = GameState.combo
	_max_combo = GameState.max_combo
	_accuracy = GameState.accuracy_percent()
	if finale_active and GameState.finale_results.size() == 4:
		finale_finished = GameState.finale_success
	queue_redraw()


func _on_judgement(grade: int, delta_ms: float, combo: int, _attack: String) -> void:
	judge_grade = grade
	judge_delta = delta_ms
	judge_timer = 0.62
	judge_combo = combo


func _on_combo(combo: int) -> void:
	_combo = combo
	combo_pop = 1.0


func _on_health(value: float, maximum: float) -> void:
	hp = value
	max_hp = maximum


func _on_layer(layer: int) -> void:
	_layer_flash[layer] = 1.2
	toast_text = GameState.LAYER_NAMES[layer] + " 声部归位"
	toast_color = GameState.LAYER_COLORS[layer]
	toast_timer = 2.4


func _on_objective(text: String, sub: String) -> void:
	objective = text
	objective_sub = sub


func _on_toast(text: String, color: Color) -> void:
	toast_text = text
	toast_color = color
	toast_timer = 2.5


func _on_hint(text: String, duration: float) -> void:
	hint_text = text
	hint_timer = duration


func _on_stage(index: int, title: String, sub: String) -> void:
	title_index = index
	title_text = title
	title_sub = sub
	title_timer = 3.4


func _on_boss_started() -> void:
	boss_active = true
	boss_phase = 1
	finale_active = false
	finale_finished = false


func _on_boss_health(value: float, maximum: float) -> void:
	boss_hp = value
	boss_max = maximum
	boss_active = true


func _on_boss_phase(phase: int) -> void:
	boss_phase = phase
	if phase == 2:
		_on_toast("第二乐章 · 变奏", ResonantUI.CORAL)
	elif phase == 3:
		_on_toast("第三乐章 · 终章", ResonantUI.GOLD)


func _on_finale_started() -> void:
	finale_active = true
	finale_finished = false
	_on_toast("终章演奏 · 四击归位", ResonantUI.GOLD)


func _on_finale_hit(_index: int, _success: bool, _count: int) -> void:
	combo_pop = 1.0


func _on_finale_finished(success: bool, _count: int) -> void:
	finale_finished = true
	if success:
		_on_toast("完美乐章", ResonantUI.GOLD)
		flash_color = Color(1.0, 0.9, 0.6, 0.25)
		flash_duration = 0.8
		flash_timer = 0.8


func _on_died() -> void:
	death_timer = 1.55
	combo_pop = 1.0


func _on_respawned() -> void:
	death_timer = 0.0
	hp = max_hp
	finale_active = false


func _on_flash(color: Color, duration: float) -> void:
	flash_color = color
	flash_duration = maxf(duration, 0.05)
	flash_timer = flash_duration


func _on_note(_total: int) -> void:
	toast_text = "关键音符 +1"
	toast_color = ResonantUI.GOLD
	toast_timer = 1.8


func _on_coda() -> void:
	toast_text = "所有声部汇合"
	toast_color = ResonantUI.GOLD
	toast_timer = 2.6


func _draw() -> void:
	var beat := Conductor.beat_info() if Conductor.playing else {
		"beat_in_bar": 0, "phase": 0.0, "bar": 0,
	}
	_draw_top_left(beat)
	_draw_layers()
	_draw_combo()
	if boss_active:
		_draw_boss()
	_draw_health()
	_draw_attack_hints()
	_draw_beat_indicator(beat)
	if hint_timer > 0.0:
		_draw_hint()
	if toast_timer > 0.0 and not finale_active:
		_draw_toast()
	if judge_timer > 0.0:
		_draw_judgement()
	if title_timer > 0.0:
		_draw_title()
	if finale_active:
		_draw_finale()
	if death_timer > 0.0:
		_draw_death()
	if hp / maxf(1.0, max_hp) < 0.32 and hp > 0.0:
		_draw_low_health()
	if flash_timer > 0.0:
		var a := flash_color.a * (flash_timer / maxf(0.01, flash_duration))
		draw_rect(Rect2(0, 0, 1280, 720),
			Color(flash_color.r, flash_color.g, flash_color.b, a))


func _draw_top_left(_beat: Dictionary) -> void:
	var stage_info: Dictionary = GameConfig.STAGES[GameState.stage]
	var col: Color = stage_info.color
	var subtitle: String = stage_info.subtitle
	if GameState.tutorial_mode:
		col = ResonantUI.TEAL
		subtitle = "TUTORIAL · 第一次调律"
	draw_line(Vector2(34, 24), Vector2(82, 24), Color(col, 0.6), 1.5, true)
	draw_string(ResonantUI.mono_font(), Vector2(34, 43),
		subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, 0.82))
	draw_string_outline(ResonantUI.body_font(), Vector2(34, 72), objective,
		HORIZONTAL_ALIGNMENT_LEFT, 530, 22, 5, Color(0, 0, 0, 0.55))
	draw_string(ResonantUI.body_font(), Vector2(34, 72), objective,
		HORIZONTAL_ALIGNMENT_LEFT, 530, 22, ResonantUI.INK)
	draw_string(ResonantUI.body_font(), Vector2(34, 92), objective_sub,
		HORIZONTAL_ALIGNMENT_LEFT, 560, 12, Color(ResonantUI.MUTED, 0.9))


func _draw_layers() -> void:
	var base_x := 402.0
	var y := 35.0
	draw_string(ResonantUI.mono_font(), Vector2(base_x - 52, y + 4),
		"VOICES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ResonantUI.DIM, 0.9))
	for i in 4:
		var bx := base_x + i * 86.0
		var active: bool = GameState.layers[i]
		var queued: bool = GameState.layers_queued[i]
		var col: Color = GameState.LAYER_COLORS[i]
		var flicker := 0.5 + 0.5 * sin(_time * 6.0 + i)
		var label: String = GameState.LAYER_NAMES_SHORT[i]
		draw_string(ResonantUI.body_font(), Vector2(bx, y - 3), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(col, 0.9) if active else Color(ResonantUI.DIM, 0.65))
		draw_rect(Rect2(bx, y + 5, 64, 4), Color(1, 1, 1, 0.06))
		if active:
			draw_rect(Rect2(bx, y + 5, 64, 4), Color(col, 0.22 + flicker * 0.1))
			draw_rect(Rect2(bx, y + 5, 64, 2), Color(col, 0.95))
			draw_line(Vector2(bx, y + 14), Vector2(bx + 64, y + 14),
				Color(col, 0.16), 1.0, true)
		elif queued:
			draw_rect(Rect2(bx, y + 5, 20 + flicker * 30, 4),
				Color(col, 0.35))
		if _layer_flash[i] > 0.0:
			var a: float = _layer_flash[i] / 1.2
			draw_rect(Rect2(bx - 3, y - 14, 70, 35),
				Color(col, 0.06 * a), true)
			draw_rect(Rect2(bx - 3, y - 14, 70, 35),
				Color(col, 0.4 * a), false, 1.0)
	# note pips
	for i in 4:
		var p := Vector2(758 + i * 14, 67)
		draw_circle(p, 3.0, Color(ResonantUI.GOLD, 0.9) if i < GameState.key_notes
			else Color(1, 1, 1, 0.1), true)


func _draw_combo() -> void:
	var right := 1246.0
	var combo_alpha := 0.35 if _combo <= 0 else 1.0
	var scale := 1.0 + combo_pop * 0.22
	var num := str(_combo)
	var size := int(40 * scale)
	draw_string(ResonantUI.mono_font(), Vector2(right - 170, 31), "CHAIN",
		HORIZONTAL_ALIGNMENT_RIGHT, 170, 9, Color(ResonantUI.MUTED, 0.8))
	draw_string_outline(ResonantUI.display_font(), Vector2(right - 170, 72),
		num, HORIZONTAL_ALIGNMENT_RIGHT, 170, size, 6, Color(0, 0, 0, 0.55))
	draw_string(ResonantUI.display_font(), Vector2(right - 170, 72), num,
		HORIZONTAL_ALIGNMENT_RIGHT, 170, size,
		Color(ResonantUI.GOLD if _combo > 0 else ResonantUI.DIM, combo_alpha))
	draw_string(ResonantUI.body_font(), Vector2(right - 250, 94),
		"准确度 %d%%   MAX %d" % [_accuracy, _max_combo],
		HORIZONTAL_ALIGNMENT_RIGHT, 250, 11, Color(ResonantUI.MUTED, 0.85))


func _draw_boss() -> void:
	var w := 630.0
	var x := 325.0
	var y := 82.0
	var phase_color := ResonantUI.GOLD
	if boss_phase == 2:
		phase_color = ResonantUI.CORAL
	elif boss_phase == 3:
		phase_color = Color("ff5f6d")
	draw_string(ResonantUI.mono_font(), Vector2(x, y - 5), "THE DISSONANT CONDUCTOR",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(phase_color, 0.8))
	draw_string(ResonantUI.display_font(), Vector2(x + 270, y - 3), "失序指挥家",
		HORIZONTAL_ALIGNMENT_LEFT, 360, 18, ResonantUI.INK)
	draw_rect(Rect2(x, y + 5, w, 8), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(x, y + 5, w, 8), Color(1, 1, 1, 0.05), true)
	var ratio := clampf(boss_hp / maxf(1.0, boss_max), 0.0, 1.0)
	draw_rect(Rect2(x, y + 5, w * ratio, 8), Color(phase_color, 0.16))
	draw_rect(Rect2(x, y + 5, w * ratio, 2), phase_color)
	for i in 3:
		var px := x + w * (0.34 + i * 0.33)
		draw_line(Vector2(px, y + 4), Vector2(px, y + 14), Color(0, 0, 0, 0.55), 2.0)
	# phase pips
	for i in 3:
		var p := Vector2(x + w + 10 + i * 12, y + 9)
		draw_circle(p, 3.0, Color(phase_color, 0.9) if boss_phase > i
			else Color(1, 1, 1, 0.12), true)
	# finale state label
	if finale_active:
		draw_string(ResonantUI.body_font(), Vector2(x, y + 30),
			"终章演奏", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(ResonantUI.GOLD, 0.95))


func _draw_health() -> void:
	var x := 36.0
	var y := 676.0
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	draw_string(ResonantUI.mono_font(), Vector2(x, y - 8), "VITALITY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ResonantUI.DIM, 0.9))
	draw_rect(Rect2(x, y, 216, 8), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(x, y, 216, 8), Color(1, 1, 1, 0.05), true)
	var col := ResonantUI.TEAL if ratio > 0.3 else ResonantUI.RED
	draw_rect(Rect2(x, y, 216 * ratio, 8), col)
	draw_rect(Rect2(x, y, 216 * ratio, 2), Color(1, 1, 1, 0.55))
	draw_string(ResonantUI.body_font(), Vector2(x + 224, y + 8),
		"%d" % int(ceil(hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ResonantUI.INK)


func _draw_attack_hints() -> void:
	var items := [
		["K", "快速斩击", "light"],
		["J", "低音重击", "heavy"],
		["L", "音波突刺", "thrust"],
		["I", "挑空攻击", "launcher"],
	]
	var x := 848.0
	var y := 664.0
	for i in items.size():
		var item: Array = items[i]
		var bx := x + i * 100.0
		var active_attack := false
		var current := _finale_current()
		if finale_active and current >= 0:
			active_attack = item[2] == GameConfig.FINALE_SEQUENCE[current].action
		draw_rect(Rect2(bx, y, 18, 18), Color(1, 1, 1, 0.035))
		draw_rect(Rect2(bx, y, 18, 18),
			Color(ResonantUI.GOLD, 0.8) if active_attack else Color(1, 1, 1, 0.12),
			false, 1.0)
		draw_string(ResonantUI.mono_font(), Vector2(bx + 4, y + 14), item[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			ResonantUI.GOLD if active_attack else ResonantUI.INK)
		draw_string(ResonantUI.body_font(), Vector2(bx + 23, y + 13), item[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ResonantUI.MUTED, 0.9))


func _draw_beat_indicator(beat: Dictionary) -> void:
	var cx := 640.0
	var y := 690.0
	var in_bar: int = int(beat.get("beat_in_bar", 0))
	var phase: float = float(beat.get("phase", 0.0))
	for i in 4:
		var p := Vector2(cx - 24 + i * 16, y)
		var is_current := i == in_bar
		var r := 4.5 if is_current else 2.6
		if is_current:
			r += (1.0 - phase) * 2.0
			draw_circle(p, r + 4.0, Color(ResonantUI.GOLD, 0.10), true)
		draw_circle(p, r, Color(ResonantUI.GOLD, 0.9) if is_current
			else Color(1, 1, 1, 0.18), true)
	draw_string(ResonantUI.mono_font(), Vector2(cx - 58, y + 4), "%02d" % int(beat.get("bar", 0)),
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color(ResonantUI.DIM, 0.8))


func _draw_judgement() -> void:
	var t := judge_timer / 0.62
	var alpha := clampf(t * 2.4, 0.0, 1.0)
	var grade := judge_grade
	var col := Rhythm.grade_color(grade)
	var text := Rhythm.grade_name(grade)
	if grade == Rhythm.Grade.OFF:
		text = "普通"
	var size := 42 if grade <= Rhythm.Grade.GREAT else 32
	if grade == Rhythm.Grade.PERFECT:
		size = 48
	var pop := 1.0 + (1.0 - t) * 0.10
	var font := ResonantUI.display_font()
	var y := 238.0 - (1.0 - t) * 10.0
	draw_string_outline(font, Vector2(440, y), text, HORIZONTAL_ALIGNMENT_CENTER,
		400, int(size * pop), 8, Color(0, 0, 0, alpha * 0.55))
	draw_string(font, Vector2(440, y), text, HORIZONTAL_ALIGNMENT_CENTER,
		400, int(size * pop), Color(col, alpha))
	draw_string(ResonantUI.mono_font(), Vector2(440, y + 20),
		"%s  ·  %d CHAIN" % [Rhythm.signed_ms(judge_delta / 1000.0), judge_combo],
		HORIZONTAL_ALIGNMENT_CENTER, 400, 10, Color(col, alpha * 0.7))


func _draw_hint() -> void:
	var alpha := clampf(hint_timer, 0.0, 1.0)
	var w := minf(620.0, ResonantUI.text_width(hint_text, 15) + 46.0)
	var rect := Rect2(34, 112, w, 32)
	draw_rect(rect, Color(0.02, 0.04, 0.055, 0.78 * alpha))
	draw_rect(rect, Color(ResonantUI.TEAL, 0.24 * alpha), false, 1.0)
	draw_line(Vector2(rect.position.x, rect.position.y),
		Vector2(rect.position.x + 28, rect.position.y),
		Color(ResonantUI.TEAL, 0.8 * alpha), 1.5, true)
	draw_string(ResonantUI.body_font(), Vector2(rect.position.x + 16,
		rect.position.y + 21), hint_text, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 15,
		Color(ResonantUI.INK, alpha))


func _draw_toast() -> void:
	var alpha := clampf(toast_timer * 1.6, 0.0, 1.0)
	var w := minf(540.0, ResonantUI.text_width(toast_text, 17) + 52.0)
	var y := 148.0
	draw_rect(Rect2(640 - w * 0.5, y, w, 32), Color(0.02, 0.035, 0.05, 0.72 * alpha))
	draw_line(Vector2(640 - w * 0.5, y), Vector2(640 + w * 0.5, y),
		Color(toast_color, 0.6 * alpha), 1.0, true)
	draw_circle(Vector2(640 - w * 0.5 + 13, y + 16), 3.0, Color(toast_color, alpha), true)
	draw_string(ResonantUI.body_font(), Vector2(640 - w * 0.5, y + 21),
		toast_text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(toast_color, alpha))


func _draw_title() -> void:
	var t := title_timer
	var alpha := clampf(minf((3.4 - t) * 2.2, t * 1.5), 0.0, 1.0)
	var col: Color = GameConfig.STAGES[title_index].color
	draw_line(Vector2(490, 196), Vector2(790, 196), Color(col, 0.22 * alpha), 1.0, true)
	draw_string(ResonantUI.mono_font(), Vector2(390, 184),
		title_sub, HORIZONTAL_ALIGNMENT_CENTER, 500, 11, Color(col, 0.85 * alpha))
	draw_string_outline(ResonantUI.display_font(), Vector2(300, 240),
		title_text, HORIZONTAL_ALIGNMENT_CENTER, 680, 34,
		7, Color(0, 0, 0, 0.55 * alpha))
	draw_string(ResonantUI.display_font(), Vector2(300, 240),
		title_text, HORIZONTAL_ALIGNMENT_CENTER, 680, 34, Color(ResonantUI.INK, alpha))
	draw_line(Vector2(490, 256), Vector2(790, 256), Color(col, 0.18 * alpha), 1.0, true)


func _draw_finale() -> void:
	var panel := Rect2(186, 112, 908, 150)
	draw_rect(panel, Color(0.015, 0.025, 0.035, 0.82))
	draw_rect(panel, Color(ResonantUI.GOLD, 0.25), false, 1.0)
	draw_line(Vector2(panel.position.x, panel.position.y + 33),
		Vector2(panel.end.x, panel.position.y + 33), Color(ResonantUI.GOLD, 0.12), 1.0)
	draw_string(ResonantUI.display_font(), Vector2(panel.position.x + 20,
		panel.position.y + 25), "终章演奏", HORIZONTAL_ALIGNMENT_LEFT, 160, 19,
		ResonantUI.GOLD)
	draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 126,
		panel.position.y + 24), "把四次攻击放进四个节拍",
		HORIZONTAL_ALIGNMENT_LEFT, 340, 12, Color(ResonantUI.MUTED, 0.9))
	var current := _finale_current()
	if current >= 0:
		var target_time := GameState.finale_start_time + current * 2.0 * Rhythm.BEAT
		var remain := target_time - Conductor.get_timeline()
		var timing := "现在" if absf(remain) < 0.12 else "%.1f s" % remain
		draw_string(ResonantUI.mono_font(), Vector2(panel.end.x - 30,
			panel.position.y + 24), timing, HORIZONTAL_ALIGNMENT_RIGHT, -1, 13,
			ResonantUI.INK)
	var start_x := panel.position.x + 22
	for i in GameConfig.FINALE_SEQUENCE.size():
		var item: Dictionary = GameConfig.FINALE_SEQUENCE[i]
		var x := start_x + i * 218.0
		var rect := Rect2(x, panel.position.y + 47, 202, 84)
		var status: int = GameState.finale_results[i] if GameState.finale_results.size() == 4 else 0
		var is_current := i == current and not finale_finished
		var border := Color(1, 1, 1, 0.08)
		var bg := Color(1, 1, 1, 0.018)
		if status == 1:
			border = Color(ResonantUI.GOLD, 0.7)
			bg = Color(ResonantUI.GOLD, 0.06)
		elif status == 2:
			border = Color(ResonantUI.RED, 0.55)
			bg = Color(ResonantUI.RED, 0.04)
		elif is_current:
			var pulse := 0.5 + 0.5 * sin(_time * 8.0)
			border = Color(ResonantUI.GOLD, 0.55 + pulse * 0.35)
			bg = Color(ResonantUI.GOLD, 0.045)
		draw_rect(rect, bg)
		draw_rect(rect, border, false, 1.0)
		draw_string(ResonantUI.mono_font(), Vector2(x + 16, rect.position.y + 34),
			item.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			ResonantUI.GOLD if is_current or status == 1 else Color(ResonantUI.INK, 0.6))
		draw_string(ResonantUI.body_font(), Vector2(x + 52, rect.position.y + 30),
			item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ResonantUI.INK)
		draw_string(ResonantUI.mono_font(), Vector2(x + 16, rect.position.y + 59),
			"BEAT %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(ResonantUI.MUTED, 0.8))
		if status == 1:
			draw_string(ResonantUI.body_font(), Vector2(x + 154, rect.position.y + 62),
				"✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ResonantUI.GOLD)
		elif status == 2:
			draw_string(ResonantUI.body_font(), Vector2(x + 154, rect.position.y + 62),
				"×", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ResonantUI.RED)
	# beat lane
	var lane_y := panel.position.y + 142
	draw_line(Vector2(panel.position.x + 22, lane_y),
		Vector2(panel.end.x - 22, lane_y), Color(1, 1, 1, 0.06), 1.0, true)
	for i in range(8):
		var p := Vector2(panel.position.x + 30 + i * 108, lane_y)
		draw_circle(p, 2.0, Color(ResonantUI.GOLD, 0.25), true)


func _finale_current() -> int:
	if GameState.finale_results.size() != 4:
		return -1
	for i in 4:
		if GameState.finale_results[i] == 0:
			return i
	return -1


func _draw_death() -> void:
	var alpha := clampf(death_timer * 1.8, 0.0, 0.62)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.005, 0.008, alpha))
	draw_string(ResonantUI.display_font(), Vector2(340, 344), "乐章中断",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 46, Color(ResonantUI.INK, alpha * 1.4))
	draw_string(ResonantUI.body_font(), Vector2(340, 380), "正在回到最近的检查点",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 16, Color(ResonantUI.MUTED, alpha * 1.4))


func _draw_low_health() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 6.5)
	var a := (0.05 + pulse * 0.06) * (1.0 - hp / maxf(1.0, max_hp) / 0.32)
	draw_rect(Rect2(0, 0, 1280, 56), Color(0.55, 0.02, 0.04, a))
	draw_rect(Rect2(0, 664, 1280, 56), Color(0.55, 0.02, 0.04, a))
