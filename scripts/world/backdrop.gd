extends Control
## Full-screen procedural backdrop.  Screen-space so it can stay soft while the
## gameplay camera moves; parallax is driven from the camera's x coordinate.

const W := 1280.0
const H := 720.0

var mode := "menu"
var stage := 0
var camera_x := 0.0
var target_camera_x := 0.0
var title_intro := 0.0
var _time := 0.0
var _stars: Array[Vector3] = []   # x, y, depth
var _motes: Array[Vector4] = []   # x, y, depth, phase


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	for i in 90:
		_stars.append(Vector3(rng.randf_range(0, W), rng.randf_range(0, H),
			rng.randf_range(0.05, 0.6)))
	for i in 36:
		_motes.append(Vector4(rng.randf_range(0, W), rng.randf_range(0, H),
			rng.randf_range(0.15, 0.7), rng.randf_range(0, TAU)))


func set_mode(value: String) -> void:
	mode = value


func set_stage(value: int) -> void:
	stage = clampi(value, 0, 3)


func set_camera_x(value: float) -> void:
	target_camera_x = value


func _process(delta: float) -> void:
	_time += delta
	camera_x = lerpf(camera_x, target_camera_x, 1.0 - pow(0.0001, delta))
	title_intro += delta
	queue_redraw()


func _draw() -> void:
	var palette := _palette()
	var top: Color = palette[0]
	var bottom: Color = palette[1]
	var accent: Color = palette[2]
	for i in 24:
		var t := float(i) / 23.0
		var c := top.lerp(bottom, pow(t, 0.82))
		draw_rect(Rect2(0, t * H, W, H / 23.0 + 1.5), c)
	# central atmospheric bloom
	for i in 7:
		var r := 620.0 - i * 72.0
		draw_circle(Vector2(W * 0.5, H * 0.42), r, Color(accent, 0.008 + i * 0.004), true)
	_draw_stars(accent)
	_draw_staff(accent)
	if mode == "menu":
		_draw_menu(accent)
	elif mode == "boss":
		_draw_boss(accent)
	else:
		match stage:
			0:
				_draw_forest(accent)
			1:
				_draw_organ(accent)
			2:
				_draw_disorder(accent)
			_:
				_draw_boss(accent)
	_draw_motes(accent)
	_draw_vignette()


func _palette() -> Array:
	if mode == "menu":
		return [Color("050c14"), Color("101f2d"), Color("ffd166")]
	match stage:
		0:
			return [Color("06131a"), Color("102b2c"), Color("63f5d2")]
		1:
			return [Color("07111b"), Color("172a3c"), Color("8fb8ff")]
		2:
			return [Color("120811"), Color("2a101e"), Color("ff6b81")]
		_:
			return [Color("09070a"), Color("241609"), Color("ffd166")]


func _draw_stars(accent: Color) -> void:
	for s: Vector3 in _stars:
		var x := fposmod(s.x - camera_x * s.z * 0.22 + _time * (2.0 + s.z * 6.0), W)
		var y := s.y + sin(_time * 0.3 + s.x) * 3.0
		var a := 0.10 + s.z * 0.34
		draw_circle(Vector2(x, y), 0.7 + s.z * 1.5,
			Color(accent.lerp(Color.WHITE, 0.45), a), true)


func _draw_staff(accent: Color) -> void:
	var offset := -fposmod(camera_x * 0.04, 24.0)
	for line in 5:
		var y := 238.0 + line * 13.0
		var pts := PackedVector2Array()
		for i in 33:
			var x := i * 40.0 + offset - 20.0
			pts.append(Vector2(x, y + sin(x * 0.007 + _time * 0.25 + line) * 1.5))
		draw_polyline(pts, Color(accent, 0.028), 1.0, true)


func _draw_menu(accent: Color) -> void:
	var cx := 640.0
	var cy := 342.0
	# enormous resonant circle
	for i in 4:
		draw_arc(Vector2(cx, cy), 236.0 + i * 3.0, -2.5, 1.2, 84,
			Color(accent, 0.16 - i * 0.035), 1.4, true)
	draw_arc(Vector2(cx, cy), 206.0, -2.8, 1.0, 72, Color(accent, 0.25), 1.2, true)
	# strings descending from the circle
	for i in 14:
		var x := 300.0 + i * 45.0
		var top_y := cy - sqrt(maxf(0.0, 210.0 * 210.0 - pow(x - cx, 2)))
		draw_line(Vector2(x, top_y), Vector2(x, H + 30.0),
			Color(accent, 0.045), 1.0, true)
	# floating notation
	for i in 9:
		var t := _time * 0.23 + i * 0.73
		var p := Vector2(
			fposmod(210.0 + i * 121.0 + sin(t) * 36.0 - camera_x * 0.1, W),
			180.0 + fposmod(i * 83.0 + _time * (8 + i), 420.0)
		)
		draw_note_glyph(p, Color(accent, 0.15 + 0.1 * sin(t)), 3.5, -0.35)
	# horizon
	draw_line(Vector2(0, 590), Vector2(W, 590), Color(accent, 0.13), 1.0, true)
	draw_rect(Rect2(0, 590, W, 130), Color(0.01, 0.02, 0.025, 0.42))


func _draw_forest(accent: Color) -> void:
	# aurora ribbons
	for k in 5:
		var pts := PackedVector2Array()
		for i in 45:
			var x := i * 30.0 - 20.0
			var y := 120.0 + k * 35.0 + sin(x * 0.004 + _time * 0.22 + k * 0.9) * 56.0
			pts.append(Vector2(x - fposmod(camera_x * 0.08, 60.0), y))
		draw_polyline(pts, Color(accent, 0.03 + k * 0.008), 2.0 + k * 1.2, true)
	# giant strings / trunks
	for i in 8:
		var base_x := i * 210.0 - fposmod(camera_x * 0.24, 210.0) - 80.0
		var height := 340.0 + fposmod(i * 93.0, 140.0)
		var sway := sin(_time * 0.25 + i) * 12.0
		var a := Vector2(base_x, H)
		var b := Vector2(base_x + sway, H - height)
		draw_line(a, b, Color(accent, 0.055), 10.0, true)
		draw_line(a, b, Color(accent, 0.09), 2.0, true)
		# small glowing leaves
		for j in 4:
			var p := b.lerp(a, 0.22 + j * 0.18)
			draw_circle(p + Vector2(14, 0), 2.0, Color(accent, 0.18), true)
	# distant hills
	var hills := PackedVector2Array([Vector2(0, H)])
	for i in 17:
		var x := i * 80.0
		var y := 500.0 + sin(i * 0.9 + camera_x * 0.001) * 26.0
		hills.append(Vector2(x, y))
	hills.append(Vector2(W, H))
	draw_colored_polygon(hills, Color(0.015, 0.065, 0.065, 0.55))
	# central light shaft
	draw_colored_polygon(PackedVector2Array([
		Vector2(520, 0), Vector2(760, 0), Vector2(830, H), Vector2(450, H)
	]), Color(accent, 0.012))


func _draw_organ(accent: Color) -> void:
	var scroll := fposmod(camera_x * 0.18, 320.0)
	for i in 11:
		var x := i * 118.0 - scroll - 90.0
		var h := 180.0 + fposmod(i * 67.0, 260.0)
		var rect := Rect2(x, H - 120 - h, 58, h)
		draw_rect(rect, Color(0.02, 0.05, 0.075, 0.55))
		draw_rect(rect, Color(accent, 0.09), false, 1.5)
		draw_line(Vector2(x + 16, rect.position.y + 16), Vector2(x + 16, H - 120),
			Color(accent, 0.055), 1.0, true)
		draw_line(Vector2(x + 43, rect.position.y + 30), Vector2(x + 43, H - 120),
			Color(accent, 0.045), 1.0, true)
	# horizontal beams
	for k in 3:
		var y := 250.0 + k * 72.0
		draw_line(Vector2(0, y), Vector2(W, y), Color(accent, 0.035), 2.0, true)
	for i in 8:
		var x := fposmod(i * 190.0 - camera_x * 0.32, W)
		draw_rect(Rect2(x, 0, 2, H), Color(accent, 0.025))
	# luminous rose
	var c := Vector2(W * 0.72, 210)
	for i in 3:
		draw_arc(c, 70 + i * 17, 0, TAU, 64, Color(accent, 0.08), 1.2, true)


func _draw_disorder(accent: Color) -> void:
	# broken arches
	for i in 5:
		var x := i * 310.0 - fposmod(camera_x * 0.16, 310.0) - 100.0
		draw_arc(Vector2(x, 520), 150, PI, TAU, 42, Color(accent, 0.075), 3.0, true)
		draw_arc(Vector2(x, 520), 118, PI, TAU, 36, Color(accent, 0.045), 1.0, true)
	# corrupted glitch columns
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in 23:
		var x := fposmod(rng.randf_range(0, W) - camera_x * 0.08, W)
		var y := rng.randf_range(40, 600)
		var w := rng.randf_range(2, 22)
		var h := rng.randf_range(2, 9)
		var flicker := 0.04 + 0.07 * maxf(0.0, sin(_time * 3.0 + i * 2.1))
		draw_rect(Rect2(x, y, w, h), Color(accent, flicker))
	# dissonant wave
	var pts := PackedVector2Array()
	for i in 65:
		var x := i * 20.0
		var y := 330.0 + sin(x * 0.02 + _time * 1.5) * 12.0 \
			+ sin(x * 0.071 - _time * 2.3) * 7.0
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(accent, 0.14), 1.0, true)


func _draw_boss(accent: Color) -> void:
	var c := Vector2(W * 0.5, 330)
	# rose window
	for ring in 5:
		var r := 130.0 + ring * 44.0
		var alpha := 0.13 - ring * 0.018
		draw_arc(c, r, 0, TAU, 96, Color(accent, alpha), 1.2, true)
	for i in 16:
		var a := i * TAU / 16.0 + _time * 0.015
		draw_line(c + Vector2.from_angle(a) * 110.0,
			c + Vector2.from_angle(a) * 306.0, Color(accent, 0.045), 1.0, true)
		draw_circle(c + Vector2.from_angle(a) * 326.0, 3.0, Color(accent, 0.11), true)
	draw_arc(c, 105, -2.9, 0.9, 64, Color(accent, 0.35), 2.0, true)
	# hanging organ pipes
	for i in 10:
		var x := 180.0 + i * 96.0
		var h := 110.0 + fposmod(i * 57.0, 170.0)
		draw_rect(Rect2(x, 0, 28, h), Color(0.01, 0.008, 0.008, 0.5))
		draw_line(Vector2(x, h), Vector2(x + 28, h), Color(accent, 0.12), 1.5, true)
	# stage floor glow
	draw_line(Vector2(0, 602), Vector2(W, 602), Color(accent, 0.16), 2.0, true)
	draw_rect(Rect2(0, 604, W, 116), Color(0.01, 0.007, 0.006, 0.5))


func _draw_motes(accent: Color) -> void:
	for m: Vector4 in _motes:
		var x := fposmod(m.x - camera_x * m.z * 0.13 + sin(_time * 0.3 + m.w) * 18.0, W)
		var y := fposmod(m.y - _time * (4.0 + m.z * 12.0), H)
		draw_circle(Vector2(x, y), 0.8 + m.z * 1.2,
			Color(accent.lerp(Color.WHITE, 0.5), 0.10 + m.z * 0.18), true)


func _draw_vignette() -> void:
	for i in 6:
		var a := 0.035 + i * 0.015
		var inset := i * 13.0
		draw_rect(Rect2(inset, inset, W - inset * 2, H - inset * 2),
			Color(0.0, 0.0, 0.0, 0.0), false, 34.0)
		draw_line(Vector2(0, inset), Vector2(W, inset), Color(0, 0, 0, a), 26.0)
		draw_line(Vector2(0, H - inset), Vector2(W, H - inset), Color(0, 0, 0, a), 26.0)
		draw_line(Vector2(inset, 0), Vector2(inset, H), Color(0, 0, 0, a), 26.0)
		draw_line(Vector2(W - inset, 0), Vector2(W - inset, H), Color(0, 0, 0, a), 26.0)


func draw_note_glyph(pos: Vector2, color: Color, r: float, rot: float) -> void:
	var dir := Vector2.from_angle(rot)
	var side := Vector2(-dir.y, dir.x)
	draw_circle(pos, r, color)
	draw_line(pos, pos + dir * r * 3.0, color, maxf(1.2, r * 0.3), true)
	draw_line(pos + dir * r * 3.0,
		pos + dir * r * 2.5 + side * r * 1.5, color, maxf(1.2, r * 0.26), true)
