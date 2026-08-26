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
	if String(card_data.get("game_id", "")) == "truco":
		_card_texture = TrucoSpanishCardTextures.load_face(String(card_data.get("rank", "")), String(card_data.get("suit", ""))) if face_up else TrucoSpanishCardTextures.load_back()
	else:
		_card_texture = null
	if display_mode == DisplayMode.HISTORY_MINI:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = _tooltip()
	_refresh()

func _apply_display_size() -> void:
	match display_mode:
		DisplayMode.HAND:
			custom_minimum_size = Vector2(88.0, 126.0)
		DisplayMode.TABLE, DisplayMode.SPANISH_DECK, DisplayMode.FACE_DOWN_PLAY:
			custom_minimum_size = Vector2(76.0, 108.0)
		DisplayMode.OPPONENT_BACK:
			custom_minimum_size = Vector2(38.0, 54.0)
		DisplayMode.HISTORY_MINI:
			custom_minimum_size = Vector2(50.0, 70.0)
	pivot_offset = Vector2(custom_minimum_size.x * 0.5, custom_minimum_size.y - 8.0)

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
	# Always fit a 5:7 rectangle inside the allocated control. Containers may grow,
	# but the card itself must never inherit that distortion.
	var available: Vector2 = Vector2(maxf(1.0, size.x - 8.0), maxf(1.0, size.y - 8.0))
	var card_size: Vector2 = Vector2(minf(available.x, available.y * 5.0 / 7.0), 0.0)
	card_size.y = card_size.x * 7.0 / 5.0
	var bounds: Rect2 = Rect2(Vector2((size.x - card_size.x) * 0.5, (size.y - card_size.y) * 0.5 - _visual_lift), card_size)
	var shadow: Rect2 = Rect2(bounds.position + Vector2(3.0, 4.0), bounds.size)
	draw_style_box(_box(Color(0.0, 0.0, 0.0, 0.35), Color.TRANSPARENT, 12), shadow)
	var background: Color = _background_color()
	var border: Color = Color("ffd45a") if winning_card or selected or recently_played else Color("d9d5c8")
	if playable_hint and face_up and not pending and not selected:
		border = Color("55d98b")
	draw_style_box(_box(background, border, 12, 5 if winning_card else (4 if selected else 3)), bounds)
	if is_instance_valid(_card_texture):
		draw_texture_rect(_card_texture, bounds.grow(-2.0), false)
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

func _draw_back(bounds: Rect2) -> void:
	var inner: Rect2 = bounds.grow(-8.0)
	draw_style_box(_box(Color("173d50"), Color("d8b45b"), 8, 2), inner)
	for y_value in range(int(inner.position.y) + 7, int(inner.end.y), 12):
		for x_value in range(int(inner.position.x) + 7, int(inner.end.x), 12):
			draw_circle(Vector2(x_value, y_value), 2.2, Color(0.85, 0.7, 0.35, 0.72))
	_draw_centered("TRUCO" if display_mode in [DisplayMode.SPANISH_DECK, DisplayMode.FACE_DOWN_PLAY, DisplayMode.HISTORY_MINI] else "HC", 13, Color("f1d783"), bounds)

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
	modulate = Color(0.62, 0.66, 0.68) if disabled and display_mode == DisplayMode.HAND else Color.WHITE
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
