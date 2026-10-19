extends Control
## End-of-run performance card.  The music keeps breathing under this screen.

signal replay_requested()
signal title_requested()

var data: Dictionary = {}
var rank: Dictionary = {}
var index := 0
var _time := 0.0
var _particles: Array[Dictionary] = []
var _rects: Array[Rect2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	data = GameState.summary()
	rank = data.rank
	_rects = [Rect2(168, 574, 250, 44), Rect2(438, 574, 250, 44)]
	if data.perfect:
		_seed_particles()


func _seed_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x60D
	for i in 70:
		_particles.append({
			"x": rng.randf_range(0, 1280),
			"y": rng.randf_range(-200, 720),
			"v": rng.randf_range(8, 28),
			"sway": rng.randf_range(0.5, 1.8),
			"phase": rng.randf_range(0, TAU),
			"size": rng.randf_range(1, 3.5),
		})


func _process(delta: float) -> void:
	_time += delta
	for p: Dictionary in _particles:
		p.y += p.v * delta
		p.x += sin(_time * p.sway + p.phase) * 8.0 * delta
		if p.y > 760:
			p.y = -20
			p.x = fposmod(p.x + 317.0, 1280)
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
		index = 1 - index
		AudioBank.play("ui_move", 1.0, -7.0)
	if Input.is_action_just_pressed("confirm"):
		_activate(index)
	if Input.is_action_just_pressed("back"):
		title_requested.emit()
	queue_redraw()


func _activate(i: int) -> void:
	AudioBank.play("ui_confirm", 1.0, -3.0)
	if i == 0:
		replay_requested.emit()
	else:
		title_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i in _rects.size():
				if _rects[i].has_point(mb.position):
					index = i
					_activate(i)
					return
	elif event is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point((event as InputEventMouseMotion).position):
				index = i


func _draw() -> void:
	var perfect: bool = data.get("perfect", false)
	var accent: Color = rank.get("color", ResonantUI.GOLD)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.005, 0.01, 0.016, 0.82))
	# atmosphere
	for i in 8:
		var r := 220.0 + i * 60.0
		draw_arc(Vector2(330, 330), r, -2.8, 0.8, 64,
			Color(accent, 0.035 - i * 0.003), 1.0, true)
	if perfect:
		for i in 18:
			var a := i * TAU / 18.0 + _time * 0.05
			draw_line(Vector2(330, 330),
				Vector2(330, 330) + Vector2.from_angle(a) * 780.0,
				Color(accent, 0.025), 1.0, true)
		for p: Dictionary in _particles:
			draw_circle(Vector2(p.x, p.y), p.size, Color(accent, 0.25), true)
		draw_string(ResonantUI.mono_font(), Vector2(904, 678),
			"PERFECT PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(accent, 0.7))

	# header
	draw_string(ResonantUI.mono_font(), Vector2(80, 78),
		"FIRST MOVEMENT · RESULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(accent, 0.72))
	draw_string(ResonantUI.display_font(), Vector2(80, 118),
		"演奏结束", HORIZONTAL_ALIGNMENT_LEFT, 420, 34, ResonantUI.INK)
	draw_line(Vector2(80, 136), Vector2(1200, 136), Color(accent, 0.15), 1.0, true)

	# rank
	var code: String = rank.get("code", "C")
	draw_string_outline(ResonantUI.display_font(), Vector2(76, 342), code,
		HORIZONTAL_ALIGNMENT_LEFT, 300, 190, 14, Color(0, 0, 0, 0.55))
	draw_string(ResonantUI.display_font(), Vector2(76, 342), code,
		HORIZONTAL_ALIGNMENT_LEFT, 300, 190, accent)
	draw_string(ResonantUI.display_font(), Vector2(300, 242),
		rank.get("title", ""), HORIZONTAL_ALIGNMENT_LEFT, 380, 42, accent)
	draw_string(ResonantUI.body_font(), Vector2(302, 272),
		rank.get("subtitle", ""), HORIZONTAL_ALIGNMENT_LEFT, 380, 13,
		Color(ResonantUI.MUTED, 0.95))
	draw_line(Vector2(302, 292), Vector2(562, 292), Color(accent, 0.22), 1.0, true)

	# score summary
	var rows := [
		["乐章完整度", "%d%%" % int(round(GameState.music_fraction() * 100.0))],
		["节奏准确度", "%d%%" % GameState.accuracy_percent()],
		["最大连击", str(data.max_combo)],
		["PERFECT / GREAT", "%d / %d" % [data.perfect_hits, data.great_hits]],
		["受击 / 死亡", "%d / %d" % [data.hits_taken, data.deaths]],
		["关键音符", "%d / 4" % data.key_notes],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var y := 352.0 + i * 27.0
		draw_string(ResonantUI.body_font(), Vector2(120, y), row[0],
			HORIZONTAL_ALIGNMENT_LEFT, 240, 12, Color(ResonantUI.MUTED, 0.9))
		draw_string(ResonantUI.mono_font(), Vector2(364, y), row[1],
			HORIZONTAL_ALIGNMENT_RIGHT, 190, 12, ResonantUI.INK)
		draw_line(Vector2(120, y + 9), Vector2(554, y + 9),
			Color(1, 1, 1, 0.035), 1.0, true)

	# right card: voices + finale
	var card := Rect2(682, 172, 518, 382)
	draw_rect(card, Color(0.02, 0.04, 0.055, 0.72))
	draw_rect(card, Color(accent, 0.15), false, 1.0)
	draw_string(ResonantUI.mono_font(), Vector2(card.position.x + 22,
		card.position.y + 26), "RESTORED VOICES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(accent, 0.72))
	for i in 4:
		var x := card.position.x + 24 + i * 120.0
		var y := card.position.y + 66
		var on: bool = data.layers[i]
		draw_circle(Vector2(x + 8, y - 4), 8.0,
			Color(GameState.LAYER_COLORS[i], 0.85) if on else Color(1, 1, 1, 0.05), true)
		draw_arc(Vector2(x + 8, y - 4), 12.0, 0, TAU, 20,
			Color(GameState.LAYER_COLORS[i], 0.5) if on else Color(1, 1, 1, 0.08),
			1.0, true)
		draw_string(ResonantUI.body_font(), Vector2(x + 26, y),
			GameState.LAYER_NAMES_SHORT[i], HORIZONTAL_ALIGNMENT_LEFT, 80, 11,
			Color(ResonantUI.INK, 0.9) if on else Color(ResonantUI.DIM, 0.8))
	draw_line(Vector2(card.position.x + 22, card.position.y + 94),
		Vector2(card.end.x - 22, card.position.y + 94), Color(accent, 0.1), 1.0, true)

	draw_string(ResonantUI.body_font(), Vector2(card.position.x + 24,
		card.position.y + 124), "终章演奏", HORIZONTAL_ALIGNMENT_LEFT, 200, 16,
		ResonantUI.GOLD)
	var hits: int = data.finale_hits
	draw_string(ResonantUI.mono_font(), Vector2(card.end.x - 140,
		card.position.y + 124), "%d / 4" % hits, HORIZONTAL_ALIGNMENT_RIGHT,
		120, 16, ResonantUI.GOLD)
	for i in 4:
		var x := card.position.x + 24 + i * 118.0
		var rect := Rect2(x, card.position.y + 142, 104, 62)
		var ok := i < hits
		draw_rect(rect, Color(ResonantUI.GOLD, 0.055 if ok else 0.015))
		draw_rect(rect, Color(ResonantUI.GOLD, 0.5) if ok else Color(1, 1, 1, 0.06),
			false, 1.0)
		var item: Dictionary = GameConfig.FINALE_SEQUENCE[i]
		draw_string(ResonantUI.mono_font(), Vector2(x + 10, rect.position.y + 34),
			item.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			ResonantUI.GOLD if ok else Color(ResonantUI.MUTED, 0.55))
		draw_string(ResonantUI.body_font(), Vector2(x + 40, rect.position.y + 29),
			item.label, HORIZONTAL_ALIGNMENT_LEFT, 60, 10,
			Color(ResonantUI.INK, 0.9) if ok else Color(ResonantUI.DIM, 0.8))
		draw_string(ResonantUI.mono_font(), Vector2(x + 10, rect.position.y + 51),
			"BEAT %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(ResonantUI.DIM, 0.75))
		if ok:
			draw_string(ResonantUI.body_font(), Vector2(x + 80, rect.position.y + 51),
				"✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ResonantUI.GOLD)
	draw_line(Vector2(card.position.x + 24, card.position.y + 230),
		Vector2(card.end.x - 24, card.position.y + 230), Color(accent, 0.1), 1.0, true)

	var metrics := [
		["完美命中", str(data.perfect_hits)],
		["精彩命中", str(data.great_hits)],
		["良好命中", str(data.good_hits)],
		["闪避成功", str(data.dodges)],
		["用时", ResonantUI.format_time(data.elapsed)],
		["最大连击", str(data.max_combo)],
	]
	for i in metrics.size():
		var col := i % 2
		var row := int(i / 2)
		var x := card.position.x + 26 + col * 244
		var y := card.position.y + 262 + row * 36
		draw_string(ResonantUI.body_font(), Vector2(x, y), metrics[i][0],
			HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color(ResonantUI.MUTED, 0.85))
		draw_string(ResonantUI.mono_font(), Vector2(x + 150, y), metrics[i][1],
			HORIZONTAL_ALIGNMENT_LEFT, 70, 12, ResonantUI.INK)

	# buttons
	for i in 2:
		var rect := _rects[i]
		var active := i == index
		var label := "再次演奏" if i == 0 else "返回标题"
		draw_rect(rect, Color(accent, 0.10 if active else 0.025))
		draw_rect(rect, Color(accent, 0.8) if active else Color(1, 1, 1, 0.08),
			false, 1.0 if active else 1.0)
		draw_string(ResonantUI.body_font(), Vector2(rect.position.x, rect.position.y + 27),
			label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17,
			ResonantUI.INK if active else Color(ResonantUI.MUTED, 0.85))
	draw_string(ResonantUI.mono_font(), Vector2(714, 602),
		"ENTER 确认  ·  ESC 返回标题", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(ResonantUI.DIM, 0.85))
	draw_string(ResonantUI.mono_font(), Vector2(80, 688),
		"弦刃 RESONANT  ·  第一乐章  ·  %s" % ("完美乐章" if perfect else "演奏记录"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ResonantUI.DIM, 0.65))
