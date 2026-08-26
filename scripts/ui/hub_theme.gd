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
const MUTED: Color = Color("B7CBC7")
const BLUE: Color = Color("3187D9")
const PURPLE: Color = Color("8054C7")

static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	theme.set_color("font_color", "SpinBox", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT.lightened(0.08))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD, 18, 2, 18, true))
	theme.set_stylebox("normal", "Button", _box(Color("174F50"), Color("57A9A8"), 10, 2, 10))
	theme.set_stylebox("hover", "Button", _box(Color("206667"), GOLD, 10, 3, 10))
	theme.set_stylebox("pressed", "Button", _box(Color("103F40"), WARNING, 10, 3, 10))
	theme.set_stylebox("disabled", "Button", _box(Color("263b3c"), Color("405152"), 9, 1, 10))
	theme.set_stylebox("normal", "LineEdit", _box(Color("102b32"), Color("39787a"), 8, 1, 9))
	theme.set_stylebox("focus", "LineEdit", _box(Color("102b32"), GOLD, 8, 2, 8))
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return theme

static func apply_to(control: Control) -> void:
	control.theme = build()

static func style_pill(control: Control, color: Color) -> void:
	control.add_theme_color_override("font_color", color)
	control.add_theme_stylebox_override("normal", _box(Color(color, 0.12), Color(color, 0.75), 14, 2, 8))

static func style_title(label: Label) -> void:
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color("351F12"))
	label.add_theme_constant_override("outline_size", 6)

static func style_muted(label: Label) -> void:
	label.add_theme_color_override("font_color", MUTED)

static func style_action(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", _box(color.darkened(0.2), color.lightened(0.2), 12, 2, 10, true))
	button.add_theme_stylebox_override("hover", _box(color, GOLD, 12, 3, 9, true))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.35), TEXT, 12, 3, 9))
	button.add_theme_stylebox_override("focus", _box(color.darkened(0.12), TEXT, 12, 3, 9))

static func style_card(panel: PanelContainer, color: Color = GOLD) -> void:
	panel.add_theme_stylebox_override("panel", _box(Color("0D3339F2"), Color(color, 0.8), 14, 1, 14, true))

static func style_table(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _box(Color("082D31E8"), Color("4E8B83"), 18, 2, 18, true))

static func style_status(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_stylebox_override("normal", _box(Color("061F24D9"), Color("356B6C"), 10, 1, 7))

static func style_exit(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _box(Color("8F343B"), DANGER, 12, 2, 10))
	button.add_theme_stylebox_override("hover", _box(Color("B3444C"), Color("FF9292"), 12, 3, 10))
	button.add_theme_stylebox_override("pressed", _box(Color("6F282E"), DANGER, 12, 3, 10))

static func _box(color: Color, border: Color, radius: int, width: int, padding: int, shadow: bool = false) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(float(padding))
	if shadow:
		box.shadow_color = Color(0, 0, 0, 0.28)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 3)
	return box
