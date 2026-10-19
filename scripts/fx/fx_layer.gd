extends Node2D
## Lightweight pooled-ish vector FX.  One node draws every spark, ring, slash
## and damage number, keeping the scene tree small and the timing exact.

const MAX_PARTICLES := 420

var particles: Array[Dictionary] = []


func _ready() -> void:
	z_index = 40
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.life -= delta
		if p.life <= 0.0:
			particles.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel *= pow(p.drag, delta * 60.0)
		p.vel.y += p.gravity * delta
		p.rot += p.spin * delta
		particles[i] = p
	queue_redraw()


func _draw() -> void:
	for p: Dictionary in particles:
		var life_ratio: float = clampf(p.life / p.max_life, 0.0, 1.0)
		var col: Color = p.color
		col.a *= p.fade_in if p.fade_in < 1.0 and p.life > p.max_life - 0.08 else life_ratio
		match p.kind:
			"spark":
				var tail: Vector2 = p.vel.normalized() * p.length
				draw_line(p.pos, p.pos - tail, Color(col, col.a * 0.25), p.width + 3.0, true)
				draw_line(p.pos, p.pos - tail, col, p.width, true)
			"dot":
				draw_circle(p.pos, p.radius * (0.3 + 0.7 * life_ratio), Color(col, col.a * 0.18), true)
				draw_circle(p.pos, p.radius * (0.2 + 0.6 * life_ratio), col, true)
			"ring":
				var r: float = p.radius + (1.0 - life_ratio) * p.grow
				draw_arc(p.pos, r, 0.0, TAU, 48, Color(col, col.a * 0.18), p.width + 5.0, true)
				draw_arc(p.pos, r, 0.0, TAU, 48, Color(col, col.a * 0.6), p.width + 2.0, true)
				draw_arc(p.pos, r, 0.0, TAU, 48, col, p.width, true)
			"arc":
				var r: float = p.radius
				draw_arc(p.pos, r, p.angle_from, p.angle_to, 30,
					Color(col, col.a * 0.12), p.width + 9.0, true)
				draw_arc(p.pos, r, p.angle_from, p.angle_to, 30,
					Color(col, col.a * 0.35), p.width + 4.0, true)
				draw_arc(p.pos, r, p.angle_from, p.angle_to, 30,
					Color(col, col.a), p.width, true)
			"shard":
				var d: Vector2 = Vector2.from_angle(p.rot) * p.length
				draw_line(p.pos, p.pos + d, col, p.width, true)
			"text":
				var pos: Vector2 = p.pos
				var txt: String = p.text
				var f: Font = ResonantUI.body_font()
				var size: int = p.size
				draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_CENTER,
					p.width, size, 4, Color(0.02, 0.03, 0.05, col.a * 0.85))
				draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_CENTER,
					p.width, size, col)
			"note":
				_draw_note(p.pos, col, p.radius, p.rot)
			"glyph":
				var font: Font = ResonantUI.display_font()
				draw_string(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_CENTER,
					p.width, p.size, Color(col, col.a))
			"line":
				draw_line(p.pos, p.end, Color(col, col.a * 0.2), p.width + 6.0, true)
				draw_line(p.pos, p.end, col, p.width, true)
			"diamond":
				var s: float = p.radius * (0.5 + 0.5 * life_ratio)
				var pts := PackedVector2Array([
					p.pos + Vector2(0, -s), p.pos + Vector2(s, 0),
					p.pos + Vector2(0, s), p.pos + Vector2(-s, 0),
				])
				draw_colored_polygon(pts, Color(col, col.a * 0.25))
				draw_polyline(pts + PackedVector2Array([pts[0]]), col, p.width, true)


func _draw_note(pos: Vector2, color: Color, r: float, rot: float) -> void:
	var dir := Vector2.from_angle(rot)
	var side := Vector2(-dir.y, dir.x)
	var head := pos
	var stem_end := pos + dir * r * 3.0
	draw_circle(head, r, color)
	draw_line(head, stem_end, color, maxf(1.5, r * 0.32), true)
	draw_line(stem_end, stem_end + side * r * 1.4 - dir * r * 0.5,
		color, maxf(1.5, r * 0.28), true)


func _add(p: Dictionary) -> void:
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	particles.append(p)


func _base(pos: Vector2, lifetime: float, color: Color) -> Dictionary:
	return {
		"pos": pos, "vel": Vector2.ZERO, "life": lifetime, "max_life": lifetime,
		"color": color, "kind": "dot", "radius": 3.0, "width": 2.0,
		"length": 10.0, "grow": 40.0, "angle_from": 0.0, "angle_to": TAU,
		"rot": 0.0, "spin": 0.0, "gravity": 0.0, "drag": 0.86,
		"text": "", "size": 16, "fade_in": 0.0, "end": Vector2.ZERO,
	}


func spawn_hit(pos: Vector2, direction: float, color: Color, power: float = 1.0,
		grade: int = Rhythm.Grade.GREAT) -> void:
	var n := int(7 + power * 5)
	if grade == Rhythm.Grade.PERFECT:
		n += 6
	for i in n:
		var p := _base(pos, randf_range(0.16, 0.38), color)
		p.kind = "spark"
		p.pos = pos + Vector2(randf_range(-8, 8), randf_range(-10, 10))
		p.vel = Vector2(randf_range(120, 460) * direction, randf_range(-320, 240))
		p.length = randf_range(8, 28) * (0.7 + power * 0.3)
		p.width = randf_range(1.0, 2.6)
		p.gravity = 900.0
		p.drag = 0.88
		_add(p)
	var ring := _base(pos, 0.26, color)
	ring.kind = "ring"
	ring.radius = 6.0
	ring.grow = 40.0 + 26.0 * power
	ring.width = 2.2 + power * 0.8
	_add(ring)
	var flash := _base(pos, 0.11, Color.WHITE)
	flash.kind = "dot"
	flash.radius = 8.0 + power * 5.0
	_add(flash)


func spawn_heal(pos: Vector2) -> void:
	for i in 8:
		var p := _base(pos, randf_range(0.4, 0.8), ResonantUI.TEAL)
		p.kind = "dot"
		p.radius = randf_range(2, 4)
		p.pos = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		p.vel = Vector2(randf_range(-25, 25), randf_range(-90, -35))
		_add(p)


func spawn_dust(pos: Vector2, color: Color = Color(0.6, 0.7, 0.72, 0.35)) -> void:
	for i in 5:
		var p := _base(pos, randf_range(0.2, 0.4), color)
		p.kind = "dot"
		p.radius = randf_range(1.5, 3.5)
		p.pos += Vector2(randf_range(-10, 10), 0)
		p.vel = Vector2(randf_range(-55, 55), randf_range(-35, -5))
		p.gravity = 180.0
		_add(p)


func spawn_slash(pos: Vector2, facing: int, color: Color, radius: float,
		wide: bool = false) -> void:
	var p := _base(pos, 0.22, color)
	p.kind = "arc"
	p.radius = radius
	p.width = 4.0 if wide else 2.5
	var base := 0.0 if facing > 0 else PI
	var spread := 1.9 if wide else 1.35
	p.angle_from = base - spread * 0.55
	p.angle_to = base + spread * 0.45
	_add(p)
	for i in 4:
		var s := _base(pos, 0.18, color)
		s.kind = "spark"
		s.pos = pos + Vector2(facing * radius * randf_range(0.4, 0.8),
			randf_range(-30, 30))
		s.vel = Vector2(facing * randf_range(160, 380), randf_range(-80, 80))
		s.length = randf_range(8, 18)
		_add(s)


func spawn_shockwave(pos: Vector2, color: Color, radius: float = 120.0) -> void:
	var p := _base(pos, 0.5, color)
	p.kind = "ring"
	p.radius = 8.0
	p.grow = radius
	p.width = 3.5
	_add(p)
	for i in 10:
		var s := _base(pos, randf_range(0.3, 0.6), color)
		s.kind = "spark"
		s.pos += Vector2(randf_range(-16, 16), 0)
		s.vel = Vector2(randf_range(-1, 1) * radius * 1.6, randf_range(-120, -20))
		s.length = randf_range(10, 24)
		s.width = 2.0
		_add(s)


func spawn_damage(pos: Vector2, amount: float, color: Color,
		crit: bool = false) -> void:
	var p := _base(pos, 0.8, color)
	p.kind = "text"
	p.text = str(int(round(amount)))
	p.size = 26 if crit else 20
	p.width = 150.0
	p.pos = pos + Vector2(-75, -18)
	p.vel = Vector2(randf_range(-18, 18), -86)
	p.gravity = 55.0
	p.drag = 0.96
	_add(p)


func spawn_judgement_text(pos: Vector2, text: String, color: Color,
		size: int = 26) -> void:
	var p := _base(pos, 0.65, color)
	p.kind = "text"
	p.text = text
	p.size = size
	p.width = 220.0
	p.pos = pos + Vector2(-110, 0)
	p.vel = Vector2(0, -60)
	p.gravity = 0.0
	p.drag = 0.92
	_add(p)


func spawn_death(pos: Vector2, color: Color, kind: String) -> void:
	var count := 18 if kind != "guard" else 26
	for i in count:
		var p := _base(pos, randf_range(0.35, 0.9), color)
		p.kind = "note" if i % 3 == 0 else "spark"
		p.radius = randf_range(2.5, 5.5)
		p.pos = pos + Vector2(randf_range(-26, 26), randf_range(-40, 14))
		p.vel = Vector2(randf_range(-260, 260), randf_range(-420, -80))
		p.length = randf_range(8, 20)
		p.gravity = 420.0
		p.rot = randf_range(-0.8, 0.8)
		p.spin = randf_range(-4, 4)
		p.drag = 0.97
		_add(p)
	var ring := _base(pos, 0.55, color)
	ring.kind = "ring"
	ring.radius = 4.0
	ring.grow = 88.0
	ring.width = 2.6
	_add(ring)


func spawn_note_trail(pos: Vector2, color: Color) -> void:
	var p := _base(pos, 1.0, color)
	p.kind = "note"
	p.radius = 4.0
	p.pos = pos
	p.vel = Vector2(randf_range(-20, 20), -140)
	p.rot = -0.8
	p.spin = 0.8
	p.gravity = -15.0
	_add(p)


func spawn_unlock(pos: Vector2, color: Color) -> void:
	var ring := _base(pos, 1.0, color)
	ring.kind = "ring"
	ring.radius = 10.0
	ring.grow = 260.0
	ring.width = 3.0
	_add(ring)
	for i in 26:
		var p := _base(pos, randf_range(0.7, 1.5), color)
		p.kind = "note" if i % 2 == 0 else "dot"
		p.radius = randf_range(2.5, 5.0)
		p.pos = pos + Vector2(randf_range(-60, 60), randf_range(-20, 20))
		p.vel = Vector2(randf_range(-160, 160), randf_range(-420, -90))
		p.gravity = 220.0
		p.rot = randf_range(-1, 1)
		p.spin = randf_range(-2, 2)
		_add(p)


func spawn_beam(a: Vector2, b: Vector2, color: Color) -> void:
	var p := _base(a, 0.35, color)
	p.kind = "line"
	p.end = b
	p.width = 5.0
	_add(p)
	for i in 14:
		var s := _base(a.lerp(b, randf()), 0.25, color)
		s.kind = "spark"
		s.vel = Vector2(randf_range(-160, 160), randf_range(-160, 160))
		s.length = randf_range(5, 14)
		_add(s)


func spawn_glyph(pos: Vector2, text: String, color: Color, size: int = 24) -> void:
	var p := _base(pos, 0.9, color)
	p.kind = "glyph"
	p.text = text
	p.size = size
	p.width = 300.0
	p.pos = pos + Vector2(-150, 0)
	p.vel = Vector2(0, -28)
	_add(p)


func spawn_glitch(pos: Vector2, color: Color) -> void:
	for i in 8:
		var p := _base(pos, randf_range(0.1, 0.35), color)
		p.kind = "shard"
		p.pos = pos + Vector2(randf_range(-40, 40), randf_range(-50, 30))
		p.length = randf_range(8, 28)
		p.rot = randf_range(-PI, PI)
		p.width = randf_range(1, 3)
		_add(p)


func clear() -> void:
	particles.clear()
