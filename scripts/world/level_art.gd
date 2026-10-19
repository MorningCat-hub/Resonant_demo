extends Node2D
## Terraced side-scrolling level.  Geometry is data; collision and all visuals
## are generated from it.  The floor line sits at y=610.

const FLOORS := [
	Rect2(-320, 610, 2360, 220),
	Rect2(2170, 610, 1930, 220),
	Rect2(4210, 610, 1590, 220),
	Rect2(5900, 610, 720, 220),
	Rect2(6680, 610, 1780, 220),
]

const PLATFORMS := [
	Rect2(560, 520, 190, 20),
	Rect2(980, 490, 176, 20),
	Rect2(1320, 534, 198, 20),
	Rect2(2260, 522, 184, 20),
	Rect2(2580, 496, 166, 20),
	Rect2(2960, 540, 176, 20),
	Rect2(3330, 500, 196, 20),
	Rect2(3700, 536, 170, 20),
	Rect2(4320, 514, 166, 20),
	Rect2(4680, 486, 182, 20),
	Rect2(5050, 540, 154, 20),
	Rect2(5480, 500, 164, 20),
	Rect2(6120, 518, 176, 20),
	Rect2(7010, 510, 170, 20),
	Rect2(8060, 510, 176, 20),
]

const GATES := [1800.0, 3950.0, 6470.0, 6810.0]

var _time := 0.0
var _note_marks: Array[Vector3] = []


func _ready() -> void:
	z_index = -5
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xA11CE
	for i in 36:
		_note_marks.append(Vector3(rng.randf_range(0, 8400), rng.randf_range(0, 1), rng.randf_range(0, TAU)))
	for rect: Rect2 in FLOORS + PLATFORMS:
		_add_collision(rect)


func _add_collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for rect: Rect2 in FLOORS:
		_draw_floor(rect)
	for rect: Rect2 in PLATFORMS:
		_draw_platform(rect)
	_draw_note_marks()
	_draw_foreground()


func _stage_color(x: float) -> Color:
	if x < 1900.0:
		return Color("63f5d2")
	if x < 4100.0:
		return Color("8fb8ff")
	if x < 6600.0:
		return Color("ff8a6b")
	return Color("ffd166")


func _draw_floor(rect: Rect2) -> void:
	var col := _stage_color(rect.get_center().x)
	var top := rect.position.y
	var body_col := Color(0.035, 0.075, 0.085, 0.99)
	draw_rect(Rect2(rect.position.x, top, rect.size.x, rect.size.y), body_col)
	draw_rect(Rect2(rect.position.x, top, rect.size.x, 26), Color(0.055, 0.12, 0.13, 1.0))
	# light spilling up off the edge
	for i in 7:
		draw_line(Vector2(rect.position.x, top - 4 - i * 5),
			Vector2(rect.end.x, top - 4 - i * 5),
			Color(col, 0.07 - i * 0.009), 3.0, true)
	draw_line(Vector2(rect.position.x, top), Vector2(rect.end.x, top),
		Color(col, 0.55), 4.0, true)
	draw_line(Vector2(rect.position.x, top + 3), Vector2(rect.end.x, top + 3),
		Color(col, 0.16), 12.0, true)
	# floor inlay: staff lines and note engravings
	for i in 5:
		var y := top + 32 + i * 9
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y),
			Color(col, 0.06), 1.0, true)
	var start_x: float = ceil(rect.position.x / 140.0) * 140.0
	var x: float = start_x
	while x < rect.end.x:
		draw_line(Vector2(x, top + 12), Vector2(x + 18, top + 12),
			Color(col, 0.12), 1.0, true)
		draw_circle(Vector2(x + 23, top + 12), 2.0, Color(col, 0.18), true)
		x += 140.0
	# cracks
	for i in 4:
		var cx := rect.position.x + fposmod(i * 317.0 + 90.0, rect.size.x)
		var pts := PackedVector2Array([
			Vector2(cx, top + 18), Vector2(cx + 12, top + 34),
			Vector2(cx - 8, top + 54), Vector2(cx + 5, top + 76),
		])
		draw_polyline(pts, Color(col, 0.08), 1.0, true)
	# supports under the ground
	var sx := rect.position.x + 80.0
	while sx < rect.end.x:
		draw_line(Vector2(sx, top + 60), Vector2(sx + 14, rect.end.y),
			Color(0.02, 0.04, 0.05, 0.9), 8.0, true)
		draw_line(Vector2(sx + 5, top + 60), Vector2(sx + 18, rect.end.y),
			Color(col, 0.04), 1.0, true)
		sx += 170.0


func _draw_platform(rect: Rect2) -> void:
	var col := _stage_color(rect.get_center().x)
	# underside wedge
	var under := PackedVector2Array([
		Vector2(rect.position.x + 8, rect.position.y + 14),
		Vector2(rect.end.x - 8, rect.position.y + 14),
		Vector2(rect.end.x - 36, rect.position.y + 58),
		Vector2(rect.position.x + 28, rect.position.y + 58),
	])
	draw_colored_polygon(under, Color(0.025, 0.06, 0.07, 0.98))
	draw_rect(rect, Color(0.04, 0.085, 0.095, 1.0))
	for i in 5:
		draw_line(Vector2(rect.position.x, rect.position.y - 3 - i * 5),
			Vector2(rect.end.x, rect.position.y - 3 - i * 5),
			Color(col, 0.09 - i * 0.014), 2.5, true)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y),
		Color(col, 0.78), 3.0, true)
	draw_line(rect.position + Vector2(0, 3), Vector2(rect.end.x, rect.position.y + 3),
		Color(col, 0.18), 9.0, true)
	draw_line(Vector2(rect.position.x + 4, rect.position.y + 18),
		Vector2(rect.end.x - 4, rect.position.y + 18), Color(col, 0.10), 1.0, true)
	# hanging resonators
	var x := rect.position.x + 28.0
	var i := 0
	while x < rect.end.x - 16.0:
		var length := 16.0 + sin(_time * 1.3 + i + rect.position.x) * 6.0
		draw_line(Vector2(x, rect.position.y + 58),
			Vector2(x + sin(_time + i) * 3.0, rect.position.y + 58 + length),
			Color(col, 0.22), 1.0, true)
		draw_circle(Vector2(x + sin(_time + i) * 3.0,
			rect.position.y + 59 + length), 2.0, Color(col, 0.45), true)
		x += 34.0
		i += 1
	# small number of glyphs
	var n := int(rect.size.x / 62.0)
	for k in n:
		var p := Vector2(rect.position.x + 34 + k * 62, rect.position.y - 9)
		_draw_note(p, Color(col, 0.20), 2.0)


func _draw_note_marks() -> void:
	for v: Vector3 in _note_marks:
		var x := v.x
		var col := _stage_color(x)
		var y := 575.0 + sin(x * 0.01) * 4.0
		_draw_note(Vector2(x, y), Color(col, 0.07), 3.0 + v.z * 2.0)


func _draw_note(pos: Vector2, color: Color, r: float) -> void:
	draw_circle(pos, r, color)
	draw_line(pos, pos + Vector2(0, -r * 3.0), color, maxf(1.0, r * 0.32), true)
	draw_line(pos + Vector2(0, -r * 3.0), pos + Vector2(r * 1.5, -r * 2.3),
		color, maxf(1.0, r * 0.28), true)


func _draw_foreground() -> void:
	# nearby cables and hanging notes, drawn behind the actors but above terrain
	for i in 8:
		var gx: float = float(GATES[i % GATES.size()])
		var col := _stage_color(gx)
		var x: float = gx + 34.0
		var pts := PackedVector2Array()
		for j in 8:
			pts.append(Vector2(x + sin(j * 1.3 + _time * 0.7) * 9.0,
				180.0 + j * 48.0))
		draw_polyline(pts, Color(col, 0.07), 1.0, true)
	# glow pools beneath gates
	for gx: float in GATES:
		var col := _stage_color(gx)
		draw_set_transform(Vector2(gx, 606), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, 42.0, Color(col, 0.08), true)
		draw_set_transform(Vector2.ZERO)
