extends Node2D
## The end-of-phrase challenge.  It cannot be brute-forced: every hit must be
## clean, and later seals demand a specific attack or a varied phrase.

var requirement := "clean3"
var target := 3
var progress := 0
var color := Color("63f5d2")
var index := 0
var completed := false
var _time := 0.0
var _used_attacks: Array[String] = []
var _flash := 0.0
var world: Node


func setup(p_index: int, p_requirement: String, x: float, p_color: Color, p_world: Node) -> void:
	index = p_index
	requirement = p_requirement
	color = p_color
	world = p_world
	position = Vector2(x, 610)
	match requirement:
		"heavy2":
			target = 2
		"variety3":
			target = 3
		_:
			target = 3
	add_to_group("hurtable")
	z_index = 7
	GameEvents.seal_progress.emit(progress, target, requirement_text())


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	queue_redraw()


func requirement_text() -> String:
	match requirement:
		"heavy2":
			return "在节拍上用 J 低音重击 ×2"
		"variety3":
			return "在节拍上使用 3 种不同攻击"
		_:
			return "在节拍上命中封印 ×3"
	


func receive_attack(info: Dictionary) -> Dictionary:
	if completed:
		return {"hit": false}
	var attack_id: String = info.get("attack_id", "light")
	var judged := Conductor.judge()
	var clean := int(judged.grade) <= Rhythm.Grade.GOOD
	var valid := clean
	if requirement == "heavy2" and attack_id != "heavy":
		valid = false
		AudioBank.play("ui_back", 0.9, -6.0)
		GameEvents.toast.emit("封印需要低音重击 · 按 J", ResonantUI.CORAL)
	elif requirement == "variety3":
		if _used_attacks.has(attack_id):
			valid = false
			GameEvents.toast.emit("音色重复 · 换一种攻击", ResonantUI.CORAL)
		elif clean:
			_used_attacks.append(attack_id)
	if not clean:
		GameEvents.toast.emit("节拍偏移 · 等下一拍再试", ResonantUI.MUTED)
	if not valid:
		AudioBank.play("hit_armor", 0.9, -5.0)
		_flash = 0.4
		return {
			"hit": true, "blocked": true, "damage": 0.0, "killed": false,
			"count_rhythm": clean,
			"fx_pos": get_center(),
			"color": Color("d9e2ff"),
		}
	progress += 1
	_flash = 1.0
	AudioBank.play("seal_hit", 0.9 + progress * 0.06, -2.0)
	GameEvents.shake.emit(2.8)
	GameEvents.seal_progress.emit(progress, target, requirement_text())
	if world and world.has_method("on_seal_progress"):
		world.on_seal_progress(index, progress, target)
	var fx := get_tree().get_first_node_in_group("fx")
	if fx:
		fx.spawn_hit(get_center(), 1, color, 1.0, Rhythm.Grade.PERFECT)
		fx.spawn_glyph(get_center() + Vector2(0, -30), "%d / %d" % [progress, target],
			color, 20)
	if progress >= target:
		_complete()
	return {
		"hit": true, "blocked": false, "damage": 0.0, "killed": completed,
		"count_rhythm": true, "fx_pos": get_center(), "color": color,
	}


func _complete() -> void:
	if completed:
		return
	completed = true
	AudioBank.play("seal_complete", 1.0, 0.0)
	GameEvents.flash.emit(Color(color, 0.18), 0.35)
	GameEvents.shake.emit(7.0)
	GameEvents.seal_completed.emit()
	var fx := get_tree().get_first_node_in_group("fx")
	if fx:
		fx.spawn_unlock(get_center(), color)
		for i in 8:
			fx.spawn_note_trail(get_center() + Vector2(randf_range(-40, 40), randf_range(-60, 20)),
				color)
	if world and world.has_method("on_seal_completed"):
		world.on_seal_completed(index)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.55)
	tween.tween_callback(queue_free)


func get_hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-44, -160), Vector2(88, 172))


func get_center() -> Vector2:
	return global_position + Vector2(0, -88)


func _draw() -> void:
	var bob := sin(_time * 2.0) * 5.0
	var c := color
	# base rings on the floor
	for i in 3:
		var r := 48.0 + i * 20.0
		draw_arc(Vector2(0, 0), r, PI, TAU, 32, Color(c, 0.14 - i * 0.03), 1.5, true)
	# standing metronome body
	var body := PackedVector2Array([
		Vector2(0, -150 + bob), Vector2(34, -42 + bob),
		Vector2(-34, -42 + bob),
	])
	draw_colored_polygon(body, Color(0.025, 0.06, 0.07, 0.94))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(c, 0.7), 2.0, true)
	draw_line(Vector2(-30, -42 + bob), Vector2(30, -42 + bob), Color(c, 0.45), 2.0, true)
	# pendulum keyed to the conductor
	var phase := Conductor.get_beat_phase() if Conductor.playing else 0.0
	var swing := sin(phase * TAU) * 0.65
	var pivot := Vector2(0, -128 + bob)
	var tip := pivot + Vector2.from_angle(PI * 0.5 - swing) * 72.0
	draw_line(pivot, tip, Color(c, 0.3), 2.0, true)
	draw_line(pivot, tip, Color(1, 1, 1, 0.55), 0.8, true)
	draw_circle(tip, 4.5, Color(c, 0.9), true)
	# crystal at top
	var crystal := Vector2(0, -166 + bob)
	var pts := PackedVector2Array([
		crystal + Vector2(0, -20), crystal + Vector2(15, 0),
		crystal + Vector2(0, 20), crystal + Vector2(-15, 0),
	])
	draw_colored_polygon(pts, Color(c, 0.16 + _flash * 0.2))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(c, 0.9), 1.5, true)
	draw_circle(crystal, 4.0 + sin(_time * 5.0) * 0.8, Color(c, 0.8), true)
	# progress pips
	for i in target:
		var px := (i - (target - 1) * 0.5) * 16.0
		draw_circle(Vector2(px, -24 + bob), 3.5,
			Color(c, 0.9) if i < progress else Color(c, 0.16), true)
	# label
	var font := ResonantUI.body_font()
	var text := requirement_text()
	draw_string_outline(font, Vector2(-150, -204 + bob), text,
		HORIZONTAL_ALIGNMENT_CENTER, 300, 14, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-150, -204 + bob), text,
		HORIZONTAL_ALIGNMENT_CENTER, 300, 14, Color(c, 0.85))
