class_name CardVisual
extends Button

signal card_clicked(card_uid: int)

enum DisplayMode { HAND, TABLE, OPPONENT_BACK, HISTORY_MINI, SPANISH_DECK, FACE_DOWN_PLAY }

const UNO_COLORS: Dictionary = {
	"red": Color("d83a3a"),
	"yellow": Color("f2c94c"),
	"green": Color("299e65"),
	"blue": Color("2878c8"),
}
const SUITS: Dictionary = {
	"clubs": "♣",
	"hearts": "♥",
	"spades": "♠",
	"diamonds": "♦",
	"paus": "♣",
	"copas": "♥",
	"espadas": "♠",
	"ouros": "♦",
}
const CAXETA_TEXTURE_FALLBACK_SIZE := Vector2(500.0, 726.0)
const HAND_CARD_SIZE := Vector2(90.0, 131.0)
const TABLE_CARD_SIZE := Vector2(78.0, 113.0)
const OPPONENT_CARD_SIZE := Vector2(46.0, 67.0)
const HISTORY_CARD_SIZE := Vector2(48.0, 70.0)
const HAND_TOP_RESERVE: float = 17.0
const CARD_SIDE_RESERVE: float = 4.0
const CARD_BOTTOM_RESERVE: float = 6.0

var card_uid: int = -1
var card_data: Dictionary = {}
var face_up: bool = true
var selected: bool = false
var interactable: bool = true
var playable_hint: bool = false
var pending: bool = false
var recently_played: bool = false
var winning_card: bool = false
var display_mode: DisplayMode = DisplayMode.HAND
var _hovered: bool = false
var _visual_lift: float = 0.0:
	set(value):
		_visual_lift = value
		queue_redraw()
var _motion_tween: Tween
var _card_texture: Texture2D

func _ready() -> void:
	_apply_display_size()
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_refresh()

func configure(card: Dictionary, up: bool = true, mode: DisplayMode = DisplayMode.HAND) -> void:
	card_data = card.duplicate(true)
	card_uid = int(card_data.get("uid", -1))
	face_up = up
	display_mode = mode
	_apply_display_size()
	match String(card_data.get("game_id", "")):
		"truco":
			_card_texture = TrucoSpanishCardTextures.load_face(String(card_data.get("rank", "")), String(card_data.get("suit", ""))) if face_up else TrucoSpanishCardTextures.load_back()
		"caxeta":
			_card_texture = CaxetaCardTextures.load_face(String(card_data.get("rank", "")), String(card_data.get("suit", ""))) if face_up else null
		_:
			_card_texture = null
	if display_mode == DisplayMode.HISTORY_MINI:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = _tooltip()
	_refresh()

func _apply_display_size() -> void:
	var card_size: Vector2 = _display_card_size()
	var top_reserve: float = HAND_TOP_RESERVE if display_mode == DisplayMode.HAND else 3.0
	match display_mode:
		DisplayMode.OPPONENT_BACK, DisplayMode.HISTORY_MINI:
			custom_minimum_size = card_size + Vector2(CARD_SIDE_RESERVE * 2.0, CARD_BOTTOM_RESERVE + 3.0)
		_:
			custom_minimum_size = card_size + Vector2(CARD_SIDE_RESERVE * 2.0, top_reserve + CARD_BOTTOM_RESERVE)
	pivot_offset = Vector2(custom_minimum_size.x * 0.5, top_reserve + card_size.y)

func _display_card_size() -> Vector2:
	match display_mode:
		DisplayMode.HAND:
			return HAND_CARD_SIZE
		DisplayMode.OPPONENT_BACK:
			return OPPONENT_CARD_SIZE
		DisplayMode.HISTORY_MINI:
			return HISTORY_CARD_SIZE
		_:
			return TABLE_CARD_SIZE

func _card_bounds() -> Rect2:
	var card_size: Vector2 = _display_card_size()
	var top_reserve: float = HAND_TOP_RESERVE if display_mode == DisplayMode.HAND else 3.0
	return Rect2(Vector2((size.x - card_size.x) * 0.5, top_reserve - _visual_lift), card_size)

func set_state(new_selected: bool, new_interactable: bool, new_playable_hint: bool, new_pending: bool) -> void:
	var animate: bool = selected != new_selected
	selected = new_selected
	interactable = new_interactable
	playable_hint = new_playable_hint
	pending = new_pending
	if animate:
		_animate_transform()
	_refresh()

func set_recently_played(value: bool) -> void:
	recently_played = value
	_refresh()

func set_winning_card(value: bool) -> void:
	winning_card = value
	if winning_card:
		scale = Vector2(1.06, 1.06)
		var pulse: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "modulate", Color(1.0, 0.9, 0.55), 0.35)
		pulse.tween_property(self, "modulate", Color.WHITE, 0.35)
	_refresh()

func _draw() -> void:
	if _is_caxeta_face_texture():
		_draw_caxeta_texture_card()
		return
	if not face_up and String(card_data.get("game_id", "")) == "caxeta":
		var back_area := _card_bounds()
		_draw_caxeta_back(_fit_texture_preserving_aspect(null, back_area))
		return
	var bounds: Rect2 = _card_bounds()
	var shadow: Rect2 = Rect2(bounds.position + Vector2(3.0, 4.0), bounds.size)
	draw_style_box(_box(Color(0.0, 0.0, 0.0, 0.35), Color.TRANSPARENT, 12), shadow)
	var background: Color = _background_color()
	var border: Color = Color("ffd45a") if winning_card or selected or recently_played else Color("d9d5c8")
	if playable_hint and face_up and not pending and not selected:
		border = Color("55d98b")
	draw_style_box(_box(background, border, 12, 5 if winning_card else (4 if selected else 3)), bounds)
	if is_instance_valid(_card_texture):
		# Spanish artwork remains the card face; interaction treatments stay outside it.
		var art_bounds: Rect2 = _fit_texture_rect(_card_texture, bounds.grow(-1.0))
		draw_texture_rect(_card_texture, art_bounds, false)
		var texture_highlight: Color = Color.TRANSPARENT
		if winning_card or selected or recently_played:
			texture_highlight = Color("ffd45a")
		elif playable_hint and not pending:
			texture_highlight = Color("55d98b")
		if texture_highlight.a > 0.0:
			draw_style_box(_box(Color.TRANSPARENT, texture_highlight, 12, 2), bounds.grow(2.0))
		if pending:
			draw_style_box(_box(Color(0.02, 0.04, 0.05, 0.58), Color.TRANSPARENT, 12), bounds)
		return
	if not face_up:
		_draw_back(bounds)
		return
	if String(card_data.get("game_id", "")) == "uno":
		_draw_uno(bounds)
	elif String(card_data.get("game_id", "")) == "truco":
		_draw_spanish(bounds)
	else:
		_draw_standard(bounds)
	if pending:
		draw_style_box(_box(Color(0.02, 0.04, 0.05, 0.58), Color.TRANSPARENT, 12), bounds)
		_draw_centered("…", 30, HubTheme.TEXT, bounds)

func _is_caxeta_face_texture() -> bool:
	return face_up and String(card_data.get("game_id", "")) == "caxeta" and is_instance_valid(_card_texture)

func _draw_caxeta_texture_card() -> void:
	# Caxeta's PNG is the card itself. Only reserve enough room for a quiet shadow;
	# never place the artwork inside the shared decorative card frame.
	var area := _card_bounds()
	var texture_bounds := _fit_texture_preserving_aspect(_card_texture, area)
	var shadow_bounds := Rect2(texture_bounds.position + Vector2(2.0, 3.0), texture_bounds.size)
	draw_style_box(_box(Color(0.0, 0.0, 0.0, 0.22), Color.TRANSPARENT, 6), shadow_bounds)
	draw_texture_rect(_card_texture, texture_bounds, false)

	# Interaction rings sit outside the PNG and therefore never shrink or tint it.
	var highlight: Color = Color.TRANSPARENT
	if winning_card or selected or recently_played:
		highlight = Color("ffd45a")
	elif playable_hint and not pending:
		highlight = Color("55d98b")
	if highlight.a > 0.0:
		draw_style_box(_box(Color.TRANSPARENT, highlight, 6, 2), texture_bounds.grow(2.0))
	if pending:
		draw_style_box(_box(Color(0.02, 0.04, 0.05, 0.58), Color.TRANSPARENT, 5), texture_bounds)

func _fit_texture_preserving_aspect(texture: Texture2D, area: Rect2) -> Rect2:
	var texture_size := texture.get_size() if is_instance_valid(texture) else CAXETA_TEXTURE_FALLBACK_SIZE
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		texture_size = CAXETA_TEXTURE_FALLBACK_SIZE
	var texture_aspect: float = texture_size.x / texture_size.y
	var fitted_size := Vector2(area.size.x, area.size.x / texture_aspect)
	if fitted_size.y > area.size.y:
		fitted_size = Vector2(area.size.y * texture_aspect, area.size.y)
	return Rect2(area.get_center() - fitted_size * 0.5, fitted_size)

func _fit_texture_rect(texture: Texture2D, bounds: Rect2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds
	var scale_factor: float = minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var fitted_size: Vector2 = texture_size * scale_factor
	return Rect2(bounds.get_center() - fitted_size * 0.5, fitted_size)

func _draw_uno(bounds: Rect2) -> void:
	var value: String = _uno_value()
	var ellipse_center: Vector2 = bounds.get_center()
	draw_set_transform(ellipse_center, -0.35, Vector2.ONE)
	if String(card_data.get("action", "")) in ["wild", "wild_draw_four"]:
		for index: int in 4:
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(index * PI * 0.5) * 34.0, Vector2.from_angle((index + 1) * PI * 0.5) * 34.0]), UNO_COLORS.values()[index] as Color)
	else:
		draw_circle(Vector2.ZERO, minf(bounds.size.x, bounds.size.y) * 0.39, Color(1.0, 1.0, 1.0, 0.88))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_centered(value, 29, Color("172229"), bounds)
	_draw_text(value, bounds.position + Vector2(9.0, 24.0), 16, HubTheme.TEXT)
	_draw_text(value, bounds.end - Vector2(10.0 + value.length() * 7.0, 9.0), 16, HubTheme.TEXT)

func _draw_standard(bounds: Rect2) -> void:
	var rank: String = CardFormatter.caxeta_face_rank(String(card_data.get("rank", "?")))
	var suit: String = _suit_symbol(String(card_data.get("suit", "")))
	var ink: Color = Color("bd3038") if suit in ["♥", "♦"] else Color("172229")
	_draw_text(rank, bounds.position + Vector2(9.0, 23.0), 17, ink)
	_draw_text(suit, bounds.position + Vector2(9.0, 42.0), 18, ink)
	_draw_centered(suit, 39, ink, bounds)
	_draw_text(rank, bounds.end - Vector2(11.0 + rank.length() * 7.0, 12.0), 17, ink)

func _draw_spanish(bounds: Rect2) -> void:
	var rank: String = String(card_data.get("rank", "?"))
	var suit: String = String(card_data.get("suit", ""))
	var ink: Color = Color("a82e28") if suit in ["copas", "ouros"] else Color("234b3b")
	var gold: Color = Color("c99b2e")
	var short_rank: String = CardFormatter.spanish_rank(rank).left(3) if rank in ["1", "10", "11", "12"] else rank
	_draw_text(short_rank, bounds.position + Vector2(8.0, 22.0), 14, ink)
	var center: Vector2 = bounds.get_center()
	match suit:
		"ouros":
			draw_circle(center, 20.0, gold); draw_circle(center, 12.0, Color("f7d56b")); draw_circle(center, 5.0, ink)
		"copas":
			draw_polygon(PackedVector2Array([center + Vector2(-18,-18), center + Vector2(18,-18), center + Vector2(10,7), center + Vector2(-10,7)]), PackedColorArray([gold])); draw_line(center + Vector2(0,7), center + Vector2(0,25), ink, 4.0); draw_line(center + Vector2(-12,25), center + Vector2(12,25), ink, 4.0)
		"espadas":
			draw_line(center + Vector2(-18,25), center + Vector2(14,-25), Color("80909a"), 7.0); draw_line(center + Vector2(-24,12), center + Vector2(-5,24), gold, 5.0); draw_colored_polygon(PackedVector2Array([center + Vector2(14,-25), center + Vector2(9,-11), center + Vector2(20,-15)]), Color("d9e1e5"))
		"paus":
			draw_line(center + Vector2(-13,27), center + Vector2(12,-27), Color("79512f"), 10.0); draw_line(center + Vector2(-7,8), center + Vector2(-21,-2), Color("477a43"), 5.0); draw_line(center + Vector2(5,-8), center + Vector2(20,-17), Color("477a43"), 5.0)
	if rank in ["10", "11", "12"]:
		_draw_text(CardFormatter.spanish_rank(rank), bounds.position + Vector2(8.0, bounds.size.y - 9.0), 11, ink)

func _draw_spanish_corners(bounds: Rect2) -> void:
	var rank: String = CardFormatter.spanish_rank(String(card_data.get("rank", "?")))
	var suit: String = String(card_data.get("suit", ""))
	var ink: Color = Color("A52E2A") if suit in ["copas", "ouros"] else Color("24483B")
	var badge: Rect2 = Rect2(bounds.position + Vector2(5.0, 5.0), Vector2(29.0, 23.0))
	draw_style_box(_box(Color("FFF9E9E8"), Color("CBAA62"), 6, 1), badge)
	var short_rank: String = rank.left(2).to_upper()
	_draw_text(short_rank, badge.position + Vector2(5.0, 16.0), 12, ink)

func _draw_back(bounds: Rect2) -> void:
	if String(card_data.get("game_id", "")) == "caxeta":
		_draw_caxeta_back(bounds)
		return
	var inset: float = 6.0 if display_mode == DisplayMode.OPPONENT_BACK else 8.0
	var inner: Rect2 = bounds.grow(-inset)
	draw_style_box(_box(Color("173d50"), Color("d8b45b"), 8, 2), inner)
	var pattern_step: int = 10 if display_mode == DisplayMode.OPPONENT_BACK else 12
	for y_value in range(int(inner.position.y) + 6, int(inner.end.y), pattern_step):
		for x_value in range(int(inner.position.x) + 6, int(inner.end.x), pattern_step):
			draw_circle(Vector2(x_value, y_value), 1.8 if display_mode == DisplayMode.OPPONENT_BACK else 2.2, Color(0.85, 0.7, 0.35, 0.72))
	var back_label_size: int = 11 if display_mode == DisplayMode.OPPONENT_BACK else 13
	_draw_centered("TRUCO" if display_mode in [DisplayMode.SPANISH_DECK, DisplayMode.FACE_DOWN_PLAY, DisplayMode.HISTORY_MINI] else "HC", back_label_size, Color("f1d783"), bounds)

func _draw_caxeta_back(bounds: Rect2) -> void:
	var mini_back: bool = display_mode == DisplayMode.OPPONENT_BACK
	var outer := bounds.grow(-2.0)
	var shadow := Rect2(outer.position + Vector2(2.0, 3.0), outer.size)
	draw_style_box(_box(Color(0.0, 0.0, 0.0, 0.2), Color.TRANSPARENT, 6), shadow)
	draw_style_box(_box(Color("102f3d"), Color("d8b45b"), 6, 1), outer)
	var inner := outer.grow(-5.0 if mini_back else -7.0)
	draw_style_box(_box(Color("173d50"), Color("9f8243"), 4, 1), inner)
	# Mini backs favor one readable emblem over the dense pattern used on the pile.
	if not mini_back:
		for y_value in range(int(inner.position.y) + 7, int(inner.end.y), 13):
			for x_value in range(int(inner.position.x) + 7, int(inner.end.x), 13):
				draw_circle(Vector2(x_value, y_value), 1.7, Color(0.85, 0.7, 0.35, 0.58))
	var emblem_radius: float = 12.0 if mini_back else 17.0
	draw_circle(inner.get_center(), emblem_radius, Color("d8b45b"))
	draw_circle(inner.get_center(), emblem_radius - 3.0, Color("173d50"))
	_draw_centered("HC", 13 if mini_back else 16, Color("f1d783"), inner)

func _background_color() -> Color:
	if not face_up:
		return Color("102b38")
	if String(card_data.get("game_id", "")) == "uno":
		var color_name: String = String(card_data.get("color", ""))
		return UNO_COLORS.get(color_name, Color("222831")) as Color
	return Color("fff9e9")

func _uno_value() -> String:
	var action: String = String(card_data.get("action", ""))
	match action:
		"draw_two":
			return "+2"
		"skip":
			return "⊘"
		"reverse":
			return "↻"
		"wild":
			return "✦"
		"wild_draw_four":
			return "+4"
		_:
			return String(card_data.get("rank", "?"))

func _tooltip() -> String:
	if not face_up:
		return "Carta encoberta" if display_mode in [DisplayMode.FACE_DOWN_PLAY, DisplayMode.HISTORY_MINI] else "Carta virada para baixo"
	if String(card_data.get("game_id", "")) == "uno":
		var action: String = String(card_data.get("action", ""))
		return "Carta de %s" % CardFormatter.uno_action(action) if not action.is_empty() else "Carta Uno %s" % String(card_data.get("rank", ""))
	return CardFormatter.card_name(card_data)

func _suit_symbol(suit: String) -> String:
	return String(SUITS.get(suit.to_lower(), suit))

func _box(color: Color, border: Color, radius: int, width: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box

func _draw_text(value: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered(value: String, font_size: int, color: Color, bounds: Rect2) -> void:
	var width: float = ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var position: Vector2 = Vector2(bounds.get_center().x - width * 0.5, bounds.get_center().y + font_size * 0.35)
	_draw_text(value, position, font_size, color)

func _refresh() -> void:
	disabled = not interactable or pending
	modulate = Color(0.62, 0.66, 0.68) if disabled and not pending and display_mode == DisplayMode.HAND else Color.WHITE
	queue_redraw()

func _animate_transform() -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	_motion_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "_visual_lift", 11.0 if selected else 0.0, 0.14)
	_motion_tween.tween_property(self, "scale", Vector2(1.045, 1.045) if selected else Vector2.ONE, 0.14)

func _on_mouse_entered() -> void:
	_hovered = true
	if not selected and not disabled:
		_visual_lift = 4.0
		queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	if not selected:
		_visual_lift = 0.0
		queue_redraw()

func _on_pressed() -> void:
	if not disabled:
		card_clicked.emit(card_uid)
