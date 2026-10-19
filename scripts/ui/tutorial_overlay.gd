extends Control
## Interactive first-run tutorial.  It teaches in the real combat arena:
## movement, W jump, the four attacks, the hit-frame rhythm rule and dodge.

signal finished(skipped: bool)

const STEPS := [
	{
		"title": "移动",
		"keys": ["A", "D"],
		"lines": ["用 A / D 左右移动。", "先走到练习木桩前。"],
		"goal": "移动 90 像素",
	},
	{
		"title": "跳跃",
		"keys": ["W"],
		"lines": ["按 W 跳跃。", "跳跃可以越过平台，也能接空中攻击。"],
		"goal": "完成一次跳跃",
	},
	{
		"title": "快速斩击",
		"keys": ["K"],
		"lines": ["按 K 挥出快速斩击。", "让剑真正碰到木桩，而不是空挥。"],
		"goal": "用 K 命中木桩",
	},
	{
		"title": "踩住节拍",
		"keys": ["K", "♪"],
		"lines": ["只有剑碰到敌人的瞬间，才结算节拍。", "听鼓点、看底部拍灯；提前一点按 K。"],
		"goal": "GOOD 以上命中一次",
	},
	{
		"title": "其余三种音色",
		"keys": ["J", "L", "I"],
		"lines": ["J 低音重击：破防、强冲击。", "L 音波突刺：中距离突进。", "I 挑空攻击：把敌人击飞。"],
		"goal": "三种攻击各命中一次",
	},
	{
		"title": "闪避",
		"keys": ["SHIFT"],
		"lines": ["按 Shift 闪避，获得短暂无敌。", "Boss 的红圈攻击可以用无敌帧穿过。"],
		"goal": "完成一次闪避",
	},
	{
		"title": "训练完成",
		"keys": ["ENTER"],
		"lines": ["你已经掌握移动、W 跳跃、", "四种攻击、命中判定与闪避。", "前方的回廊会真正开始。"],
		"goal": "进入第一乐章",
	},
]

var world: Node
var player: Node2D
var dummy: Node2D
var step := 0
var last_grade := -1
var last_grade_age := 99.0
var _time := 0.0
var _start_x := 0.0
var _clean_baseline := 0
var _dodge_baseline := 0
var _advance_timer := 0.0
var _finished := false
var _step_flash := 0.0
var _pulse := 0.0


func setup(world_node: Node) -> void:
	world = world_node
	player = world.player
	dummy = world.tutorial_dummy
	_start_x = player.global_position.x


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameEvents.judgement.connect(_on_judgement)
	_enter_step(0)


func _enter_step(index: int) -> void:
	step = index
	_advance_timer = 0.0
	_step_flash = 1.0
	_clean_baseline = _clean_count()
	_dodge_baseline = player.dodge_actions if player else 0
	if index == STEPS.size() - 1:
		_advance_timer = 1.9
	if index > 0:
		AudioBank.play("ui_confirm", 1.0, -10.0)


func _process(delta: float) -> void:
	if _finished:
		return
	_time += delta
	last_grade_age += delta
	_step_flash = maxf(0.0, _step_flash - delta * 2.5)
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	if player == null:
		return
	if Input.is_action_just_pressed("confirm"):
		_finish(true)
		return
	if _advance_timer > 0.0:
		_advance_timer -= delta
		if _advance_timer <= 0.0:
			if step >= STEPS.size() - 1:
				_finish(false)
			else:
				_enter_step(step + 1)
		queue_redraw()
		return
	if step < STEPS.size() - 1 and _step_complete():
		_step_flash = 1.0
		_pulse = 1.0
		_advance_timer = 0.5
		AudioBank.play("perfect", 1.0, -13.0)
	queue_redraw()


func _step_complete() -> bool:
	match step:
		0:
			return player.global_position.x > _start_x + 90.0
		1:
			return player.state == "Jump" and player.velocity.y < -80.0
		2:
			return GameState.used_attacks.has("light")
		3:
			return _clean_count() > _clean_baseline
		4:
			return GameState.used_attacks.has("heavy") \
				and GameState.used_attacks.has("thrust") \
				and GameState.used_attacks.has("launcher")
		5:
			return player.dodge_actions > _dodge_baseline
		_:
			return false


func _clean_count() -> int:
	return GameState.perfect + GameState.great + GameState.good


func _finish(skipped: bool) -> void:
	if _finished:
		return
	_finished = true
	finished.emit(skipped)


func _on_judgement(grade: int, _delta_ms: float, _combo: int, _attack: String) -> void:
	last_grade = grade
	last_grade_age = 0.0


func _draw() -> void:
	if _finished:
		return
	var panel := Rect2(718, 146, 512, 474)
	draw_rect(panel, Color(0.015, 0.03, 0.042, 0.93))
	draw_rect(panel, Color(ResonantUI.TEAL, 0.22), false, 1.0)
	draw_line(Vector2(panel.position.x, panel.position.y),
		Vector2(panel.position.x + 96, panel.position.y),
		Color(ResonantUI.TEAL, 0.8), 1.5, true)
	# header
	draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 24,
		panel.position.y + 25), "TUNER'S FIELD MANUAL", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 9, Color(ResonantUI.TEAL, 0.7))
	draw_string(ResonantUI.display_font(), Vector2(panel.position.x + 24,
		panel.position.y + 57), "调律者手册", HORIZONTAL_ALIGNMENT_LEFT,
		300, 25, ResonantUI.INK)
	draw_string(ResonantUI.mono_font(), Vector2(panel.end.x - 92,
		panel.position.y + 52), "%02d / %02d" % [step + 1, STEPS.size()],
		HORIZONTAL_ALIGNMENT_RIGHT, 68, 11, Color(ResonantUI.MUTED, 0.9))
	# progress chips
	for i in STEPS.size():
		var x := panel.position.x + 24 + i * 30
		draw_rect(Rect2(x, panel.position.y + 70, 22, 4),
			Color(ResonantUI.TEAL, 0.9) if i <= step else Color(1, 1, 1, 0.08))
	# current step
	var data: Dictionary = STEPS[step]
	draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 24,
		panel.position.y + 114), data.title, HORIZONTAL_ALIGNMENT_LEFT,
		420, 27, ResonantUI.INK)
	# keycaps
	var key_x := panel.position.x + 24
	for key: String in data.keys:
		var w := maxf(42.0, 22.0 + key.length() * 13.0)
		draw_rect(Rect2(key_x, panel.position.y + 130, w, 30), Color(1, 1, 1, 0.04))
		draw_rect(Rect2(key_x, panel.position.y + 130, w, 30),
			Color(ResonantUI.GOLD, 0.35), false, 1.0)
		draw_string(ResonantUI.mono_font(), Vector2(key_x, panel.position.y + 151),
			key, HORIZONTAL_ALIGNMENT_CENTER, w, 14, ResonantUI.GOLD)
		key_x += w + 8.0
	# body
	var y := panel.position.y + 192
	for line: String in data.lines:
		draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 24, y),
			line, HORIZONTAL_ALIGNMENT_LEFT, 455, 14,
			Color(ResonantUI.INK, 0.9))
		y += 25.0
	# persistent rhythm mini-diagram (checklist pages use this space instead)
	if step != 3 and step != 4:
		var lane_y := panel.position.y + 334
		draw_line(Vector2(panel.position.x + 28, lane_y),
			Vector2(panel.end.x - 28, lane_y), Color(ResonantUI.TEAL, 0.12), 1.0, true)
		for i in 4:
			var bx := panel.position.x + 70 + i * 90.0
			draw_circle(Vector2(bx, lane_y), 4.0,
				Color(ResonantUI.TEAL, 0.65), true)
			draw_string(ResonantUI.mono_font(), Vector2(bx - 12, lane_y + 19),
				"%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, 24, 8,
				Color(ResonantUI.DIM, 0.8))
		var phase := Conductor.get_beat_phase() if Conductor.playing else 0.0
		var px := panel.position.x + 70 + phase * 270.0
		draw_line(Vector2(px, lane_y - 20), Vector2(px, lane_y + 9),
			Color(ResonantUI.GOLD, 0.55), 1.0, true)
		draw_circle(Vector2(px, lane_y), 2.0, Color(ResonantUI.GOLD, 0.9), true)
		draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 24,
			lane_y + 45), "攻击 → 剑命中 → 与最近拍点比较",
			HORIZONTAL_ALIGNMENT_LEFT, 430, 12, Color(ResonantUI.MUTED, 0.9))
	# rhythm feedback box
	if step == 3:
		var box := Rect2(panel.position.x + 24, panel.position.y + 278, 452, 58)
		draw_rect(box, Color(ResonantUI.TEAL, 0.05))
		draw_rect(box, Color(ResonantUI.TEAL, 0.16), false, 1.0)
		if last_grade >= 0 and last_grade_age < 3.0:
			draw_string(ResonantUI.display_font(), Vector2(box.position.x + 14,
				box.position.y + 37), Rhythm.grade_name(last_grade),
				HORIZONTAL_ALIGNMENT_LEFT, 200, 24, Rhythm.grade_color(last_grade))
			draw_string(ResonantUI.body_font(), Vector2(box.position.x + 185,
				box.position.y + 35), "命中时间与拍点的偏差",
				HORIZONTAL_ALIGNMENT_LEFT, 250, 12, ResonantUI.MUTED)
		else:
			draw_string(ResonantUI.body_font(), Vector2(box.position.x + 14,
				box.position.y + 35), "等待一次命中 · 看底部拍灯",
				HORIZONTAL_ALIGNMENT_LEFT, 420, 13, Color(ResonantUI.MUTED, 0.9))
	# three-technique checklist
	if step == 4:
		var items := [["J", "低音重击", "heavy"], ["L", "音波突刺", "thrust"],
			["I", "挑空攻击", "launcher"]]
		for i in items.size():
			var item: Array = items[i]
			var done: bool = GameState.used_attacks.has(item[2])
			var bx := panel.position.x + 24 + i * 150
			draw_rect(Rect2(bx, panel.position.y + 284, 138, 44),
				Color(ResonantUI.TEAL, 0.07) if done else Color(1, 1, 1, 0.02))
			draw_rect(Rect2(bx, panel.position.y + 284, 138, 44),
				Color(ResonantUI.TEAL, 0.5) if done else Color(1, 1, 1, 0.07),
				false, 1.0)
			draw_string(ResonantUI.mono_font(), Vector2(bx + 10,
				panel.position.y + 311), item[0], HORIZONTAL_ALIGNMENT_LEFT,
				-1, 16, ResonantUI.GOLD if not done else ResonantUI.TEAL)
			draw_string(ResonantUI.body_font(), Vector2(bx + 34,
				panel.position.y + 310), item[1], HORIZONTAL_ALIGNMENT_LEFT,
				90, 10, Color(ResonantUI.INK, 0.8))
			if done:
				draw_string(ResonantUI.body_font(), Vector2(bx + 112,
					panel.position.y + 313), "✓", HORIZONTAL_ALIGNMENT_LEFT,
					-1, 15, ResonantUI.TEAL)
	# goal
	var goal_box := Rect2(panel.position.x + 24, panel.end.y - 88, 452, 30)
	draw_rect(goal_box, Color(1, 1, 1, 0.025))
	draw_circle(Vector2(goal_box.position.x + 11, goal_box.position.y + 15),
		3.0, Color(ResonantUI.TEAL, 0.9), true)
	draw_string(ResonantUI.body_font(), Vector2(goal_box.position.x + 22,
		goal_box.position.y + 20), "目标：" + str(data.goal),
		HORIZONTAL_ALIGNMENT_LEFT, 410, 12, Color(ResonantUI.MUTED, 0.95))
	# skip
	draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 26,
		panel.end.y - 20), "ENTER 跳过教学  ·  ESC 暂停", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 9, Color(ResonantUI.DIM, 0.9))
	# a pointer over the dummy while teaching attacks
	if step >= 2 and step <= 4 and dummy != null and is_instance_valid(dummy):
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() \
			* (dummy.global_position + Vector2(0, -218))
		var bounce := sin(_time * 4.0) * 5.0
		draw_circle(screen_pos + Vector2(0, bounce), 8.0,
			Color(ResonantUI.GOLD, 0.15), true)
		draw_arc(screen_pos + Vector2(0, bounce), 14.0, 0, TAU,
			24, Color(ResonantUI.GOLD, 0.65), 1.0, true)
		draw_string(ResonantUI.body_font(), screen_pos + Vector2(-60, 28 + bounce),
			"打这里", HORIZONTAL_ALIGNMENT_CENTER, 120, 12,
			Color(ResonantUI.GOLD, 0.9))
