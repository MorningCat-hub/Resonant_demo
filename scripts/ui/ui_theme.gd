class_name ResonantUI
extends RefCounted
## Shared palette, CJK-capable system fonts and tiny drawing helpers.
## No external art or font files are shipped with the demo.

const BG := Color("071019")
const BG_DEEP := Color("04090e")
const PANEL := Color("0c1a26")
const PANEL_2 := Color("112535")
const INK := Color("f4f0e6")
const MUTED := Color("8496a8")
const DIM := Color("4e6274")
const TEAL := Color("63f5d2")
const GOLD := Color("ffd166")
const CORAL := Color("ff8a6b")
const BLUE := Color("8fb8ff")
const VIOLET := Color("b28dff")
const RED := Color("ff5f6d")

static var _body: SystemFont
static var _display: SystemFont
static var _mono: SystemFont


static func body_font() -> SystemFont:
	if _body == null:
		_body = SystemFont.new()
		_body.font_names = PackedStringArray([
			"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
			"Source Han Sans SC", "PingFang SC", "SimHei",
		])
		_body.font_weight = 500
		_body.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _body


static func display_font() -> SystemFont:
	if _display == null:
		_display = SystemFont.new()
		_display.font_names = PackedStringArray([
			"FZSong", "STZhongsong", "SimSun", "Songti SC",
			"Noto Serif CJK SC", "Microsoft YaHei",
		])
		_display.font_weight = 700
		_display.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _display


static func mono_font() -> SystemFont:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray([
			"JetBrains Mono", "Cascadia Mono", "Consolas", "Courier New",
		])
		_mono.font_weight = 600
	return _mono


static func text_width(text: String, size: int, display: bool = false) -> float:
	var font := display_font() if display else body_font()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func label(text: String, size: int = 18, color: Color = INK,
		display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font() if display else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size: int = 22, accent: Color = GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", body_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("hover", _button_style(Color(1, 1, 1, 0.035), Color(accent, 0.35), 1))
	b.add_theme_stylebox_override("pressed", _button_style(Color(accent, 0.12), accent, 1))
	b.add_theme_stylebox_override("focus", _button_style(Color(accent, 0.06), accent, 1))
	return b


static func _button_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func panel_style(bg: Color = Color(0.04, 0.08, 0.11, 0.92),
		border: Color = Color(1, 1, 1, 0.08), radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s


static func draw_text(ci: CanvasItem, text: String, pos: Vector2, size: int,
		color: Color = INK, display: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0) -> void:
	ci.draw_string(display_font() if display else body_font(), pos, text,
		align, width, size, color)


static func draw_text_mono(ci: CanvasItem, text: String, pos: Vector2, size: int,
		color: Color = MUTED) -> void:
	ci.draw_string(mono_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func draw_text_center(ci: CanvasItem, text: String, center_x: float,
		y: float, size: int, color: Color = INK, display: bool = false) -> void:
	var w := text_width(text, size, display)
	draw_text(ci, text, Vector2(center_x - w * 0.5, y), size, color, display)


static func draw_line_glow(ci: CanvasItem, a: Vector2, b: Vector2,
		color: Color, width: float = 2.0, glow: float = 4.0) -> void:
	ci.draw_line(a, b, Color(color, 0.10), width + glow, true)
	ci.draw_line(a, b, Color(color, 0.26), width + glow * 0.5, true)
	ci.draw_line(a, b, color, width, true)


static func draw_arc_glow(ci: CanvasItem, center: Vector2, radius: float,
		start: float, end: float, color: Color, width: float = 3.0,
		glow: float = 6.0, points: int = 32) -> void:
	ci.draw_arc(center, radius, start, end, points, Color(color, 0.10), width + glow, true)
	ci.draw_arc(center, radius, start, end, points, Color(color, 0.25), width + glow * 0.5, true)
	ci.draw_arc(center, radius, start, end, points, color, width, true)


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
