class_name HubTheme
extends RefCounted

const FELT: Color = Color("0B3B3A")
const PANEL: Color = Color("092A30E8")
const GOLD: Color = Color("F4C95D")
const INFO: Color = Color("57C7FF")
const SUCCESS: Color = Color("64E572")
const WARNING: Color = Color("FF9F43")
const DANGER: Color = Color("FF6666")
const SECONDARY: Color = Color("BFA8FF")
const TEXT: Color = Color("F5F1E6")

static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT.lightened(0.08))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD, 14, 2, 12))
	theme.set_stylebox("normal", "Button", _box(Color("174F50"), Color("57A9A8"), 10, 2, 10))
	theme.set_stylebox("hover", "Button", _box(Color("206667"), GOLD, 10, 3, 10))
	theme.set_stylebox("pressed", "Button", _box(Color("103F40"), WARNING, 10, 3, 10))
	theme.set_stylebox("disabled", "Button", _box(Color("263b3c"), Color("405152"), 9, 1, 10))
	theme.set_stylebox("normal", "LineEdit", _box(Color("102b32"), Color("39787a"), 8, 1, 9))
	return theme

static func apply_to(control: Control) -> void:
	control.theme = build()

static func style_pill(control: Control, color: Color) -> void:
	control.add_theme_color_override("font_color", color)
	control.add_theme_stylebox_override("normal", _box(Color(color, 0.12), Color(color, 0.75), 14, 2, 8))

static func style_exit(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _box(Color("8F343B"), DANGER, 12, 2, 10))
	button.add_theme_stylebox_override("hover", _box(Color("B3444C"), Color("FF9292"), 12, 3, 10))
	button.add_theme_stylebox_override("pressed", _box(Color("6F282E"), DANGER, 12, 3, 10))

static func _box(color: Color, border: Color, radius: int, width: int, padding: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(float(padding))
	return box
