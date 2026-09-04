class_name UnoDrawPile
extends Button

## Compact, UNO-only draw-pile control. The control remains a Button so its
## pressed signal follows the same input and accessibility path as before.

const CARD_SIZE := Vector2(74.0, 106.0)
const CARD_OFFSETS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(4.0, -3.0), Vector2(8.0, -6.0)]

var emphasized: bool = false
var _hovered: bool = false
var _pressed: bool = false
var _lift: float = 0.0
var _motion_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(94.0, 126.0)
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Comprar uma carta do monte"
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_set_pressed.bind(true))
	button_up.connect(_set_pressed.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	queue_redraw()

func set_emphasized(value: bool) -> void:
	emphasized = value
	queue_redraw()

func set_available(value: bool) -> void:
	disabled = not value
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if disabled else Control.CURSOR_POINTING_HAND
	if disabled:
		_hovered = false
		_pressed = false
		_animate_lift(0.0)
	queue_redraw()

func _set_hovered(value: bool) -> void:
	if disabled:
		return
	_hovered = value
	_animate_lift(3.0 if value else 0.0)
	queue_redraw()

func _set_pressed(value: bool) -> void:
	if disabled:
		return
	_pressed = value
	_animate_lift(1.0 if value else (3.0 if _hovered else 0.0))
	queue_redraw()

func _animate_lift(target: float) -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	_motion_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_method(_set_lift, _lift, target, 0.1)

func _set_lift(value: float) -> void:
	_lift = value
	queue_redraw()

func _draw() -> void:
	var opacity: float = 0.42 if disabled else 1.0
	var base_position := Vector2(6.0, 13.0 - _lift)
	for index: int in CARD_OFFSETS.size():
		var bounds := Rect2(base_position + CARD_OFFSETS[index], CARD_SIZE)
		_draw_card_back(bounds, index == CARD_OFFSETS.size() - 1, opacity)

	if emphasized and not disabled:
		var glow_bounds := Rect2(base_position + CARD_OFFSETS.back(), CARD_SIZE).grow(4.0)
		draw_style_box(_box(Color(0.96, 0.79, 0.36, 0.08), Color("f4c95d80"), 12, 2), glow_bounds)
	if has_focus() and not disabled:
		var focus_bounds := Rect2(base_position + CARD_OFFSETS.back(), CARD_SIZE).grow(3.0)
		draw_style_box(_box(Color.TRANSPARENT, Color("f5f1e6"), 12, 2), focus_bounds)

func _draw_card_back(bounds: Rect2, main_card: bool, opacity: float) -> void:
	var shadow_offset := Vector2(4.0, 6.0) if main_card else Vector2(3.0, 4.0)
	draw_style_box(_box(Color(0.0, 0.0, 0.0, 0.3 * opacity), Color.TRANSPARENT, 11, 0), Rect2(bounds.position + shadow_offset, bounds.size))
	var border := Color("f1d783") if main_card else Color("9c854c")
	draw_style_box(_box(Color("eee9dc", opacity), Color(border, opacity), 11, 2), bounds)
	var inner := bounds.grow(-7.0)
	var back_color := Color("9d2933", opacity)
	if _hovered and main_card:
		back_color = Color("bd3843", opacity)
	if _pressed and main_card:
		back_color = Color("7f202a", opacity)
	draw_style_box(_box(back_color, Color("f1d783", opacity), 7, 2), inner)

	# A restrained diamond weave gives the pile the same illustrated, physical
	# card character as the project's existing card backs.
	for y_value: int in range(int(inner.position.y) + 8, int(inner.end.y) - 4, 12):
		for x_value: int in range(int(inner.position.x) + 8, int(inner.end.x) - 4, 12):
			var center := Vector2(x_value, y_value)
			var diamond := PackedVector2Array([center + Vector2(0, -3), center + Vector2(3, 0), center + Vector2(0, 3), center + Vector2(-3, 0)])
			draw_colored_polygon(diamond, Color(0.96, 0.79, 0.36, 0.55 * opacity))
	if main_card:
		var badge := Rect2(inner.get_center() - Vector2(18.0, 11.0), Vector2(36.0, 22.0))
		draw_style_box(_box(Color("173d50", opacity), Color("f1d783", opacity), 11, 2), badge)
		draw_string(ThemeDB.fallback_font, badge.position + Vector2(7.0, 16.0), "UNO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("f5f1e6", opacity))

func _box(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
