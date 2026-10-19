extends Node2D
## A curtain of held notes.  Closed gates are solid; opening one resolves the
## current phrase and releases the next musical layer.

var gate_x := 0.0
var color := Color("63f5d2")
var is_open := false
var is_animating := false
var _time := 0.0
var _height := 300.0
var _body: StaticBody2D
var _shape: CollisionShape2D


func setup(x: float, p_color: Color, height: float = 300.0, start_open: bool = false) -> void:
	gate_x = x
	color = p_color
	_height = height
	position = Vector2(x, 0)
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24, height)
	_shape.shape = box
	_shape.position = Vector2(0, 610 - height * 0.5)
	_body.add_child(_shape)
	add_child(_body)
	z_index = -1
	is_open = start_open
	if is_open:
		_body.collision_layer = 0
		modulate.a = 0.0


func close_gate() -> void:
	if _body == null:
		return
	is_open = false
	_body.collision_layer = 1
	modulate.a = 1.0


func open() -> void:
	if is_open or is_animating:
		return
	is_animating = true
	is_open = true
	AudioBank.play("unlock", 1.0, -2.0)
	if _body:
		_body.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		is_animating = false)
	var fx := get_tree().get_first_node_in_group("fx")
	if fx:
		fx.spawn_unlock(Vector2(0, 470), color)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if is_open and not is_animating:
		# two dormant posts remain
		draw_rect(Rect2(-16, 308, 7, 302), Color(0.02, 0.045, 0.055, 0.9))
		draw_rect(Rect2(10, 308, 7, 302), Color(0.02, 0.045, 0.055, 0.9))
		draw_line(Vector2(-16, 308), Vector2(-9, 308), Color(color, 0.18), 1.0, true)
		draw_line(Vector2(10, 308), Vector2(17, 308), Color(color, 0.18), 1.0, true)
		return
	var top := 610.0 - _height
	var c := color
	# side posts
	draw_rect(Rect2(-18, top, 9, _height), Color(0.02, 0.045, 0.055, 0.95))
	draw_rect(Rect2(9, top, 9, _height), Color(0.02, 0.045, 0.055, 0.95))
	draw_line(Vector2(-18, top), Vector2(-9, top), Color(c, 0.7), 2.0, true)
	draw_line(Vector2(9, top), Vector2(18, top), Color(c, 0.7), 2.0, true)
	# curtain field
	draw_rect(Rect2(-9, top + 6, 18, _height - 12), Color(c, 0.035))
	for band in 13:
		var y := top + 15 + band * (_height - 28) / 12.0
		var a := 0.055 + 0.035 * (0.5 + 0.5 * sin(_time * 2.0 + band))
		draw_rect(Rect2(-10, y, 20, 2.0), Color(c, a))
	for i in 5:
		var x := -8.0 + i * 4.0
		var pts := PackedVector2Array()
		for j in 12:
			pts.append(Vector2(
				x + sin(_time * 1.8 + j * 0.7 + i) * 3.0,
				top + 18 + j * (_height - 30) / 11.0))
		draw_polyline(pts, Color(c, 0.12 + i * 0.02), 1.0, true)
	# floating held notes
	for i in 10:
		var y := top + 32 + fposmod(i * 37.0 + _time * 16.0, _height - 58)
		var x := sin(_time * 1.2 + i * 2.0) * 10.0
		draw_circle(Vector2(x, y), 2.5, Color(c, 0.7), true)
		draw_line(Vector2(x, y), Vector2(x, y - 10), Color(c, 0.5), 1.2, true)
		draw_line(Vector2(x, y - 10), Vector2(x + 5, y - 7), Color(c, 0.4), 1.0, true)
	# top and bottom bindings
	draw_line(Vector2(-28, top), Vector2(28, top), Color(c, 0.75), 2.5, true)
	draw_line(Vector2(-28, 610), Vector2(28, 610), Color(c, 0.65), 2.0, true)
	draw_circle(Vector2(0, top), 5.0, Color(c, 0.95), true)
	# resonance crest
	draw_arc(Vector2(0, top + 48), 17.0, 0, TAU, 24, Color(c, 0.35), 1.0, true)
