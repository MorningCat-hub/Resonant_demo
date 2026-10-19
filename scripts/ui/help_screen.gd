extends Control
## Compact controls and system reference, reachable from the title and pause.

signal closed()

var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("back"):
		AudioBank.play("ui_back", 1.0, -4.0)
		closed.emit()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.005, 0.012, 0.018, 0.76))
	var panel := Rect2(164, 70, 952, 578)
	draw_rect(panel, Color(0.02, 0.04, 0.055, 0.95))
	draw_rect(panel, Color(ResonantUI.GOLD, 0.2), false, 1.0)
	draw_string(ResonantUI.display_font(), Vector2(panel.position.x + 30,
		panel.position.y + 48), "操作与系统", HORIZONTAL_ALIGNMENT_LEFT, 400, 28,
		ResonantUI.INK)
	draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 30,
		panel.position.y + 71), "CONTROLS / RHYTHM / PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 9, Color(ResonantUI.GOLD, 0.65))
	draw_line(Vector2(panel.position.x + 30, panel.position.y + 88),
		Vector2(panel.end.x - 30, panel.position.y + 88),
		Color(ResonantUI.GOLD, 0.12), 1.0, true)

	var left := [
		["A / D", "左右移动"],
		["W", "跳跃（可缓冲）"],
		["SHIFT", "闪避 · 短暂无敌"],
		["K", "快速斩击 · 可三连"],
		["J", "低音重击 · 破甲"],
		["L", "音波突刺 · 拉近距离"],
		["I", "挑空攻击 · 对空"],
		["ESC", "暂停"],
	]
	for i in left.size():
		var row: Array = left[i]
		var y := panel.position.y + 122 + i * 34
		draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 32, y),
			row[0], HORIZONTAL_ALIGNMENT_LEFT, 100, 11, ResonantUI.GOLD)
		draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 142, y),
			row[1], HORIZONTAL_ALIGNMENT_LEFT, 240, 14, Color(ResonantUI.INK, 0.92))
		draw_line(Vector2(panel.position.x + 30, y + 10),
			Vector2(panel.position.x + 398, y + 10), Color(1, 1, 1, 0.035), 1.0, true)

	var tip := Rect2(panel.position.x + 30, panel.position.y + 390, 392, 142)
	draw_rect(tip, Color(ResonantUI.TEAL, 0.045))
	draw_rect(tip, Color(ResonantUI.TEAL, 0.18), false, 1.0)
	draw_string(ResonantUI.body_font(), Vector2(tip.position.x + 16,
		tip.position.y + 25), "第一次玩？", HORIZONTAL_ALIGNMENT_LEFT,
		200, 15, ResonantUI.TEAL)
	draw_string(ResonantUI.body_font(), Vector2(tip.position.x + 16,
		tip.position.y + 52), "菜单 →「玩法教学」，或直接开始演奏。",
		HORIZONTAL_ALIGNMENT_LEFT, 360, 12, Color(ResonantUI.INK, 0.9))
	draw_string(ResonantUI.body_font(), Vector2(tip.position.x + 16,
		tip.position.y + 76), "首次进入会自动开始 6 步互动教学。",
		HORIZONTAL_ALIGNMENT_LEFT, 360, 12, Color(ResonantUI.MUTED, 0.95))
	draw_string(ResonantUI.body_font(), Vector2(tip.position.x + 16,
		tip.position.y + 100), "移动 / W 跳跃 / K J L I 攻击 / Shift 闪避。",
		HORIZONTAL_ALIGNMENT_LEFT, 360, 12, Color(ResonantUI.MUTED, 0.95))
	draw_string(ResonantUI.body_font(), Vector2(tip.position.x + 16,
		tip.position.y + 124), "记住：剑碰到敌人的瞬间才算节拍。",
		HORIZONTAL_ALIGNMENT_LEFT, 360, 12, ResonantUI.GOLD)

	var rx := panel.position.x + 452
	draw_string(ResonantUI.body_font(), Vector2(rx, panel.position.y + 122),
		"核心规则", HORIZONTAL_ALIGNMENT_LEFT, 300, 17, ResonantUI.TEAL)
	var rules := [
		"命中瞬间与最近节拍的偏差决定评价。",
		"PERFECT ≤ 50ms · GREAT ≤ 100ms · GOOD ≤ 180ms。",
		"攻击前摇越长，越需要提前发动。",
		"普通命中保留连击；受击会中断连击。",
		"每个区域清场后，用节拍打开共鸣封印。",
		"封印会找回一个声部，让音乐逐层恢复。",
		"BOSS 的核心只会在节拍窗口中暴露。",
		"终章需要把四种攻击放进四个节拍。",
	]
	for i in rules.size():
		var y := panel.position.y + 154 + i * 34
		draw_circle(Vector2(rx + 5, y - 4), 2.0, Color(ResonantUI.TEAL, 0.7), true)
		draw_string(ResonantUI.body_font(), Vector2(rx + 18, y),
			rules[i], HORIZONTAL_ALIGNMENT_LEFT, 430, 13, Color(ResonantUI.MUTED, 0.96))
	draw_line(Vector2(rx - 18, panel.position.y + 462),
		Vector2(panel.end.x - 30, panel.position.y + 462),
		Color(ResonantUI.TEAL, 0.1), 1.0, true)
	draw_string(ResonantUI.body_font(), Vector2(rx, panel.position.y + 488),
		"完美乐章条件", HORIZONTAL_ALIGNMENT_LEFT, 300, 15, ResonantUI.GOLD)
	draw_string(ResonantUI.body_font(), Vector2(rx, panel.position.y + 512),
		"四声部归位 · 四枚关键音符 · 终章 4/4",
		HORIZONTAL_ALIGNMENT_LEFT, 430, 12, Color(ResonantUI.MUTED, 0.9))
	draw_string(ResonantUI.body_font(), Vector2(rx, panel.position.y + 531),
		"节奏准确度 ≥ 68% · 最大连击 ≥ 12 · 用遍四种攻击",
		HORIZONTAL_ALIGNMENT_LEFT, 430, 12, Color(ResonantUI.MUTED, 0.9))
	draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 30,
		panel.end.y - 20), "ENTER / ESC 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(ResonantUI.DIM, 0.85))
