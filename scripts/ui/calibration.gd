extends Control
## Eight-tap audio latency calibration.  The metronome is driven by a local
## monotonic clock; the median tap phase becomes a judgement offset.

signal closed(apply: bool)

var taps: Array[float] = []
var candidate := 0.0
var suggested := 0.0
var _elapsed := 0.0
var _next_click := Rhythm.BEAT
var _pulse := 0.0
var _last_tap_beat := -1
var _time := 0.0
var _measuring := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	candidate = Settings.offset_ms
	suggested = Settings.offset_ms


func _process(delta: float) -> void:
	_time += delta
	_elapsed += delta
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	while _elapsed >= _next_click:
		AudioBank.play("click", 1.0, -4.0)
		_pulse = 1.0
		_next_click += Rhythm.BEAT
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack_light"):
		_tap()
	if Input.is_action_just_pressed("ui_left"):
		candidate = clampf(candidate - 5.0, Settings.OFFSET_MIN, Settings.OFFSET_MAX)
	if Input.is_action_just_pressed("ui_right"):
		candidate = clampf(candidate + 5.0, Settings.OFFSET_MIN, Settings.OFFSET_MAX)
	if Input.is_action_just_pressed("restart"):
		taps.clear()
		_last_tap_beat = -1
		suggested = 0.0
		candidate = 0.0
		_measuring = true
	if Input.is_action_just_pressed("confirm"):
		Settings.set_offset(candidate, true)
		AudioBank.play("ui_confirm", 1.0, -3.0)
		closed.emit(true)
	if Input.is_action_just_pressed("back"):
		AudioBank.play("ui_back", 1.0, -4.0)
		closed.emit(false)
	queue_redraw()


func _tap() -> void:
	if not _measuring:
		return
	var beat_index := int(round(_elapsed / Rhythm.BEAT))
	if beat_index == _last_tap_beat:
		return
	var offset := (_elapsed - beat_index * Rhythm.BEAT) * 1000.0
	if absf(offset) > 245.0:
		return
	_last_tap_beat = beat_index
	taps.append(offset)
	AudioBank.play("ui_move", 1.45, -10.0)
	if taps.size() >= 8:
		_measuring = false
		var sorted := taps.duplicate()
		sorted.sort()
		var median: float = sorted[int(sorted.size() / 2)]
		# A tap that lands late means the audible beat is late for this setup.
		suggested = clampf(-median, Settings.OFFSET_MIN, Settings.OFFSET_MAX)
		candidate = suggested


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.005, 0.012, 0.018, 0.72))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.18))
	var panel := Rect2(340, 74, 600, 572)
	draw_rect(panel, Color(0.02, 0.04, 0.055, 0.94))
	draw_rect(panel, Color(ResonantUI.TEAL, 0.2), false, 1.0)
	draw_line(Vector2(panel.position.x, panel.position.y),
		Vector2(panel.position.x + 90, panel.position.y),
		Color(ResonantUI.TEAL, 0.8), 1.5, true)
	draw_string(ResonantUI.display_font(), Vector2(panel.position.x + 28,
		panel.position.y + 44), "音频校准", HORIZONTAL_ALIGNMENT_LEFT, 300, 28,
		ResonantUI.INK)
	draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 28,
		panel.position.y + 68), "LATENCY CALIBRATION", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 9, Color(ResonantUI.TEAL, 0.65))
	draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 28,
		panel.position.y + 100), "戴上耳机，跟随点击轻按 W，共 8 次。",
		HORIZONTAL_ALIGNMENT_LEFT, 540, 14, Color(ResonantUI.MUTED, 0.95))
	draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 28,
		panel.position.y + 122), "系统会取中位数，自动补偿声音输出延迟。",
		HORIZONTAL_ALIGNMENT_LEFT, 540, 14, Color(ResonantUI.MUTED, 0.95))

	# metronome
	var c := Vector2(640, 322)
	var pulse := _pulse
	for i in 4:
		var r := 92.0 + i * 17.0 + pulse * 16.0
		draw_arc(c, r, 0, TAU, 48, Color(ResonantUI.TEAL, 0.10 - i * 0.02), 1.0, true)
	draw_circle(c, 74.0, Color(0.02, 0.08, 0.09, 0.48), true)
	draw_arc(c, 74.0, 0, TAU, 40, Color(ResonantUI.TEAL, 0.55), 1.5, true)
	# pendulum based on local beat
	var phase := fposmod(_elapsed / Rhythm.BEAT, 1.0)
	var swing := sin(phase * TAU) * 0.62
	var pivot := c + Vector2(0, -12)
	var tip := pivot + Vector2.from_angle(PI * 0.5 - swing) * 54.0
	draw_line(pivot, tip, Color(ResonantUI.INK, 0.35), 2.0, true)
	draw_line(pivot, tip, Color(ResonantUI.TEAL, 0.85), 1.0, true)
	draw_circle(tip, 5.0, Color(ResonantUI.TEAL, 0.9), true)
	draw_circle(c, 4.0, Color(ResonantUI.TEAL, 0.8), true)
	# pulse caption
	draw_string(ResonantUI.mono_font(), Vector2(c.x - 80, c.y + 106),
		"BEAT  %d / 8" % mini(taps.size(), 8), HORIZONTAL_ALIGNMENT_CENTER, 160,
		11, Color(ResonantUI.TEAL, 0.85))

	# taps
	for i in 8:
		var x := 436 + i * 58.0
		var y := 466.0
		var filled := i < taps.size()
		draw_circle(Vector2(x, y), 13.0,
			Color(ResonantUI.TEAL, 0.18) if filled else Color(1, 1, 1, 0.035), true)
		draw_arc(Vector2(x, y), 13.0, 0, TAU, 20,
			Color(ResonantUI.TEAL, 0.65) if filled else Color(1, 1, 1, 0.1), 1.0, true)
		if filled:
			draw_string(ResonantUI.mono_font(), Vector2(x - 20, y + 4),
				"%+d" % int(round(taps[i])), HORIZONTAL_ALIGNMENT_CENTER, 40, 9,
				ResonantUI.INK)

	# result / offset
	var measured := taps.size() >= 8
	var label := "已采样 · 建议偏移" if measured else "当前偏移"
	var color := ResonantUI.GOLD if measured else ResonantUI.INK
	draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 28,
		panel.position.y + 528), label, HORIZONTAL_ALIGNMENT_LEFT, 300, 13,
		Color(ResonantUI.MUTED, 0.9))
	draw_string(ResonantUI.display_font(), Vector2(panel.position.x + 248,
		panel.position.y + 532), "%+d ms" % int(round(candidate)),
		HORIZONTAL_ALIGNMENT_LEFT, 180, 28, color)
	if measured:
		draw_string(ResonantUI.body_font(), Vector2(panel.position.x + 412,
			panel.position.y + 528), "自动测得 %+d ms" % int(round(suggested)),
			HORIZONTAL_ALIGNMENT_LEFT, 170, 11, Color(ResonantUI.GOLD, 0.8))
	draw_string(ResonantUI.mono_font(), Vector2(panel.position.x + 28,
		panel.position.y + 556), "← → 微调  ·  R 重测  ·  ENTER 应用  ·  ESC 返回",
		HORIZONTAL_ALIGNMENT_LEFT, 540, 9, Color(ResonantUI.DIM, 0.9))
	# output latency readout
	draw_string(ResonantUI.mono_font(), Vector2(28, 700),
		"OUTPUT LATENCY  %.1f ms   ·   OFFSET  %+d ms" %
		[AudioServer.get_output_latency() * 1000.0, int(round(Settings.offset_ms))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ResonantUI.DIM, 0.85))
