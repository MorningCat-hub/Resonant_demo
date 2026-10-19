extends Control
## Title screen.  Custom-drawn to keep the whole demo asset-free.

signal start_requested()
signal tutorial_requested()
signal calibration_requested()
signal help_requested()
signal quit_requested()

const ITEMS := ["开始演奏", "玩法教学", "音频校准", "操作说明", "退出"]
const ITEM_KEYS := ["ENTER", "ENTER", "ENTER", "ENTER", "ESC"]

var index := 0
var _time := 0.0
var _item_rects: Array[Rect2] = []
var _hover := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_rects.clear()
	for i in ITEMS.size():
		_item_rects.append(Rect2(112, 410 + i * 48, 390, 40))


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if Input.is_action_just_pressed("ui_up"):
		_move(-1)
	if Input.is_action_just_pressed("ui_down"):
		_move(1)
	if Input.is_action_just_pressed("confirm"):
		_activate(index)
	queue_redraw()


func _move(dir: int) -> void:
	index = posmod(index + dir, ITEMS.size())
	_hover = index
	AudioBank.play("ui_move", 1.0, -6.0)


func _activate(i: int) -> void:
	AudioBank.play("ui_confirm", 1.0, -2.0)
	match i:
		0:
			start_requested.emit()
		1:
			tutorial_requested.emit()
		2:
			calibration_requested.emit()
		3:
			help_requested.emit()
		4:
			quit_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mp: Vector2 = event.position
		_hover = -1
		for i in _item_rects.size():
			if _item_rects[i].has_point(mp):
				_hover = i
				index = i
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i in _item_rects.size():
				if _item_rects[i].has_point(mb.position):
					index = i
					_activate(i)
					return


func _draw() -> void:
	# left veil
	draw_rect(Rect2(0, 0, 710, 720), Color(0.01, 0.02, 0.03, 0.38))
	draw_rect(Rect2(0, 0, 6, 720), Color(ResonantUI.GOLD, 0.45))
	for i in 8:
		var y := 80.0 + i * 78.0
		draw_line(Vector2(82, y), Vector2(82 + fposmod(i * 13.0, 38.0), y),
			Color(ResonantUI.GOLD, 0.10), 1.0, true)

	# title
	draw_string(ResonantUI.mono_font(), Vector2(112, 176), "A RHYTHM-ACTION DEMO",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ResonantUI.GOLD, 0.72))
	draw_string_outline(ResonantUI.display_font(), Vector2(96, 306), "弦刃",
		HORIZONTAL_ALIGNMENT_LEFT, 500, 118, 12, Color(0, 0, 0, 0.6))
	draw_string(ResonantUI.display_font(), Vector2(96, 306), "弦刃",
		HORIZONTAL_ALIGNMENT_LEFT, 500, 118, ResonantUI.INK)
	draw_line(Vector2(112, 326), Vector2(604, 326), Color(ResonantUI.GOLD, 0.5), 1.5, true)
	# letterspaced latin title
	var rx := 116.0
	var letters := "RESONANT"
	for i in letters.length():
		var ch := letters.substr(i, 1)
		draw_string(ResonantUI.mono_font(), Vector2(rx, 354), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ResonantUI.GOLD)
		rx += 24.0
	draw_string(ResonantUI.body_font(), Vector2(112, 380),
		"以剑为乐器，以敌人为音符，以战斗谱写乐章。",
		HORIZONTAL_ALIGNMENT_LEFT, 540, 13, Color(ResonantUI.MUTED, 0.95))
	draw_string(ResonantUI.body_font(), Vector2(112, 404),
		"首次游玩自动进入互动教学 · 也可在菜单重玩",
		HORIZONTAL_ALIGNMENT_LEFT, 560, 11, Color(ResonantUI.TEAL, 0.72))

	# menu
	for i in ITEMS.size():
		var rect := _item_rects[i]
		var active := i == index
		if active:
			draw_rect(Rect2(rect.position.x - 10, rect.position.y + 4, 370, 36),
				Color(ResonantUI.GOLD, 0.06), true)
			draw_rect(Rect2(rect.position.x - 10, rect.position.y + 4, 370, 36),
				Color(ResonantUI.GOLD, 0.18), false, 1.0)
			draw_line(Vector2(rect.position.x - 20, rect.position.y + 10),
				Vector2(rect.position.x - 20, rect.position.y + 34),
				ResonantUI.GOLD, 2.0, true)
		draw_string(ResonantUI.body_font(), Vector2(rect.position.x, rect.position.y + 25),
			ITEMS[i], HORIZONTAL_ALIGNMENT_LEFT, 300, 23 if active else 20,
			ResonantUI.INK if active else Color(ResonantUI.MUTED, 0.82))
		if active:
			draw_string(ResonantUI.mono_font(), Vector2(rect.end.x - 16,
				rect.position.y + 25), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				ResonantUI.GOLD)

	# controls / concept card
	var card := Rect2(760, 222, 456, 356)
	draw_rect(card, Color(0.02, 0.045, 0.06, 0.72))
	draw_rect(card, Color(ResonantUI.TEAL, 0.14), false, 1.0)
	draw_line(Vector2(card.position.x, card.position.y),
		Vector2(card.position.x + 82, card.position.y),
		Color(ResonantUI.TEAL, 0.65), 1.5, true)
	draw_string(ResonantUI.mono_font(), Vector2(card.position.x + 18,
		card.position.y + 24), "HOW TO PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(ResonantUI.TEAL, 0.8))
	var rows := [
		["A / D", "移动"],
		["W", "跳跃"],
		["SHIFT", "闪避 · 无敌帧"],
		["K", "快速斩击"],
		["J", "低音重击 · 破防"],
		["L", "音波突刺"],
		["I", "挑空攻击"],
		["ESC", "暂停"],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var y := card.position.y + 56 + i * 30
		draw_string(ResonantUI.mono_font(), Vector2(card.position.x + 20, y),
			row[0], HORIZONTAL_ALIGNMENT_LEFT, 76, 11, ResonantUI.GOLD)
		draw_string(ResonantUI.body_font(), Vector2(card.position.x + 110, y),
			row[1], HORIZONTAL_ALIGNMENT_LEFT, 280, 13, Color(ResonantUI.INK, 0.9))
		draw_line(Vector2(card.position.x + 20, y + 8),
			Vector2(card.end.x - 20, y + 8), Color(1, 1, 1, 0.035), 1.0, true)
	draw_string(ResonantUI.body_font(), Vector2(card.position.x + 18,
		card.end.y - 18), "命中瞬间才计入节拍 · 推荐佩戴耳机",
		HORIZONTAL_ALIGNMENT_LEFT, 420, 11, Color(ResonantUI.MUTED, 0.9))

	# footer
	draw_string(ResonantUI.mono_font(), Vector2(112, 678),
		"DEMO V1.0  /  120 BPM  /  第一乐章", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(ResonantUI.DIM, 0.9))
	draw_string(ResonantUI.mono_font(), Vector2(806, 678),
		"↑ ↓ SELECT     ENTER CONFIRM", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(ResonantUI.DIM, 0.75))

	# resonating corner marks
	var beat_phase := fposmod(_time / Rhythm.BEAT, 1.0)
	var r := 18.0 + beat_phase * 10.0
	draw_arc(Vector2(1180, 610), r, 0, TAU, 28, Color(ResonantUI.GOLD, 0.14), 1.0, true)
	draw_arc(Vector2(1180, 610), r * 0.6, 0, TAU, 24, Color(ResonantUI.GOLD, 0.22), 1.0, true)
	draw_circle(Vector2(1180, 610), 2.0, Color(ResonantUI.GOLD, 0.6), true)
