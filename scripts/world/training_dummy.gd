extends Node2D
## Indestructible practice post used by the interactive tutorial.
## It registers rhythm hits exactly like an enemy, but never dies.

var fx: Node
var world: Node
var flash := 0.0
var _time := 0.0
var _last_hit_grade := -1


func setup(world_node: Node, fx_node: Node) -> void:
	world = world_node
	fx = fx_node
	z_index = 6
	add_to_group("hurtable")
	position = Vector2(430, 610)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(50, 110)
	shape.shape = box
	shape.position = Vector2(0, -55)
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	_time += delta
	flash = maxf(0.0, flash - delta * 4.5)
	queue_redraw()


func receive_attack(info: Dictionary) -> Dictionary:
	var judged := Conductor.judge()
	_last_hit_grade = int(judged.grade)
	flash = 1.0
	if fx:
		fx.spawn_hit(get_center(), int(info.get("direction", 1)),
			ResonantUI.GOLD if _last_hit_grade <= Rhythm.Grade.GOOD else ResonantUI.MUTED,
			0.7, _last_hit_grade)
		fx.spawn_glyph(get_center() + Vector2(0, -46),
			Rhythm.grade_name(_last_hit_grade), Rhythm.grade_color(_last_hit_grade), 17)
	return {
		"hit": true,
		"blocked": false,
		"damage": 0.0,
		"killed": false,
		"crit": false,
		"count_rhythm": true,
		"fx_pos": get_center(),
		"color": ResonantUI.GOLD if _last_hit_grade <= Rhythm.Grade.GOOD
			else ResonantUI.MUTED,
	}


func get_hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-38, -136), Vector2(76, 140))


func get_center() -> Vector2:
	return global_position + Vector2(0, -72)


func _draw() -> void:
	var c := ResonantUI.GOLD
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	# base
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.25))
	draw_circle(Vector2(0, 8), 38.0, Color(0, 0, 0, 0.35), true)
	draw_set_transform(Vector2.ZERO)
	# body
	draw_line(Vector2(0, 0), Vector2(0, -116), Color(0.08, 0.065, 0.045), 18.0, true)
	draw_line(Vector2(0, 0), Vector2(0, -116), Color(c, 0.22), 2.0, true)
	draw_rect(Rect2(-30, -8, 60, 12), Color(0.06, 0.055, 0.045, 0.95))
	draw_line(Vector2(-30, -8), Vector2(30, -8), Color(c, 0.55), 1.5, true)
	# target rings
	var center := Vector2(0, -78)
	for i in 3:
		draw_arc(center, 18.0 + i * 9.0, 0, TAU, 30,
			Color(c, 0.26 - i * 0.06 + flash * 0.15), 1.3, true)
	draw_circle(center, 8.0, Color(c, 0.85), true)
	draw_circle(center, 3.0, Color(0.03, 0.03, 0.03), true)
	# metronome pendulum responding to the conductor
	var phase := Conductor.get_beat_phase() if Conductor.playing else 0.0
	var swing := sin(phase * TAU) * 0.55
	var pivot := Vector2(0, -116)
	var tip := pivot + Vector2.from_angle(PI * 0.5 - swing) * 42.0
	draw_line(pivot, tip, Color(c, 0.35), 1.5, true)
	draw_circle(tip, 3.0, Color(c, 0.8), true)
	# label
	draw_string_outline(ResonantUI.body_font(), Vector2(-72, -158), "练习木桩",
		HORIZONTAL_ALIGNMENT_CENTER, 144, 12, 3, Color(0, 0, 0, 0.7))
	draw_string(ResonantUI.body_font(), Vector2(-72, -158), "练习木桩",
		HORIZONTAL_ALIGNMENT_CENTER, 144, 12, Color(ResonantUI.MUTED, 0.95))
	draw_circle(Vector2(0, -196), 2.0 + pulse * 1.5, Color(c, 0.5), true)
