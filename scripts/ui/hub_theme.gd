class_name HubTheme
extends RefCounted

const FELT: Color = Color("0b3b3a")
const PANEL: Color = Color(0.035, 0.09, 0.11, 0.92)
const GOLD: Color = Color("d8b45b")
const TEXT: Color = Color("f4f1e8")

static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD, 12, 1, 14))
	theme.set_stylebox("normal", "Button", _box(Color("174f50"), Color("39787a"), 9, 1, 10))
	theme.set_stylebox("hover", "Button", _box(Color("206667"), GOLD, 9, 2, 10))
	theme.set_stylebox("pressed", "Button", _box(Color("0f3c3d"), GOLD, 9, 2, 10))
	theme.set_stylebox("disabled", "Button", _box(Color("263b3c"), Color("405152"), 9, 1, 10))
	theme.set_stylebox("normal", "LineEdit", _box(Color("102b32"), Color("39787a"), 8, 1, 9))
	return theme

static func apply_to(control: Control) -> void:
	control.theme = build()

static func _box(color: Color, border: Color, radius: int, width: int, padding: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(float(padding))
	return box
