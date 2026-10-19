extends Control
## Pause card.  The game tree and the audio stems are frozen by Main.

signal resume_requested()
signal calibration_requested()
signal restart_requested()
signal title_requested()

const ITEMS := ["继续演奏", "音频校准", "重新开始", "返回标题"]

var index := 0
var _time := 0.0
var _rects: Array[Rect2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in ITEMS.size():
		_rects.append(Rect2(492, 324 + i * 52, 296, 40))


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if Input.is_action_just_pressed("ui_up"):
		index = posmod(index - 1, ITEMS.size())
		AudioBank.play("ui_move", 1.0, -7.0)
	if Input.is_action_just_pressed("ui_down"):
		index = posmod(index + 1, ITEMS.size())
		AudioBank.play("ui_move", 1.0, -7.0)
	if Input.is_action_just_pressed("confirm"):
		_activate(index)
	if Input.is_action_just_pressed("back"):
		resume_requested.emit()
	queue_redraw()


func _activate(i: int) -> void:
	AudioBank.play("ui_confirm", 1.0, -3.0)
	match i:
		0:
			resume_requested.emit()
		1:
			calibration_requested.emit()
		2:
			restart_requested.emit()
		3:
			title_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mp: Vector2 = event.position
		for i in _rects.size():
			if _rects[i].has_point(mp):
				index = i
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i in _rects.size():
				if _rects[i].has_point(mb.position):
					index = i
					_activate(i)
					return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.005, 0.01, 0.016, 0.72))
	var card := Rect2(414, 136, 452, 456)
	draw_rect(card, Color(0.02, 0.04, 0.055, 0.96))
	draw_rect(card, Color(ResonantUI.GOLD, 0.22), false, 1.0)
	draw_line(Vector2(card.position.x, card.position.y),
		Vector2(card.position.x + 92, card.position.y),
		Color(ResonantUI.GOLD, 0.8), 1.5, true)
	draw_string(ResonantUI.display_font(), Vector2(card.position.x + 30,
		card.position.y + 46), "暂停", HORIZONTAL_ALIGNMENT_LEFT, 300, 30,
		ResonantUI.INK)
	draw_string(ResonantUI.mono_font(), Vector2(card.position.x + 30,
		card.position.y + 68), "PAUSED · THE PHRASE HOLDS ITS BREATH",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ResonantUI.GOLD, 0.58))
	draw_string(ResonantUI.body_font(), Vector2(card.position.x + 30,
		card.position.y + 104), "第一乐章 · 失序回廊",
		HORIZONTAL_ALIGNMENT_LEFT, 380, 14, Color(ResonantUI.MUTED, 0.9))
	draw_string(ResonantUI.body_font(), Vector2(card.position.x + 30,
		card.position.y + 126), "声部 %d / 4   准确度 %d%%   最大连击 %d" %
		[GameState.layer_count(), GameState.accuracy_percent(),
		GameState.max_combo], HORIZONTAL_ALIGNMENT_LEFT, 390, 11,
		Color(ResonantUI.MUTED, 0.8))
	draw_line(Vector2(card.position.x + 30, card.position.y + 146),
		Vector2(card.end.x - 30, card.position.y + 146),
		Color(1, 1, 1, 0.06), 1.0, true)
	for i in ITEMS.size():
		var rect := _rects[i]
		var active := i == index
		if active:
			draw_rect(Rect2(rect.position.x - 6, rect.position.y, 304, 38),
				Color(ResonantUI.GOLD, 0.06))
			draw_line(Vector2(rect.position.x - 6, rect.position.y),
				Vector2(rect.position.x - 6, rect.position.y + 38),
				ResonantUI.GOLD, 2.0, true)
		draw_string(ResonantUI.body_font(), Vector2(rect.position.x, rect.position.y + 25),
			ITEMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20 if active else 18,
			ResonantUI.INK if active else Color(ResonantUI.MUTED, 0.85))
		if active:
			draw_string(ResonantUI.mono_font(), Vector2(rect.end.x - 20,
				rect.position.y + 24), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				ResonantUI.GOLD)
	draw_string(ResonantUI.mono_font(), Vector2(card.position.x + 30,
		card.end.y - 22), "ESC 继续  ·  ↑ ↓ 选择  ·  ENTER 确认",
		HORIZONTAL_ALIGNMENT_LEFT, 400, 9, Color(ResonantUI.DIM, 0.8))
