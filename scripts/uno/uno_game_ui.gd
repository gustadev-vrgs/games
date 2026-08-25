extends GameUI

var _color_popup: PopupPanel

func _ready() -> void:
	super()
	%Play.pressed.connect(_play)
	%Draw.pressed.connect(func() -> void: submit("DRAW_ONE"))
	%DrawPile.pressed.connect(func() -> void: submit("DRAW_ONE"))
	%Pass.pressed.connect(func() -> void: submit("PASS"))
	%Color.visible = false
	%Play.custom_minimum_size = Vector2(170.0, 48.0)
	%Play.tooltip_text = "Confirma a carta selecionada"
	%Draw.tooltip_text = "Compra uma carta do monte"
	%Pass.tooltip_text = "Encerra o turno depois da compra"
	_create_color_popup()

func _render_specific_table() -> void:
	var top_value: Variant = public_snapshot.get("top_card", {})
	if top_value is Dictionary:
		_add_table_card(top_value as Dictionary, "Descarte")
	var direction: int = int(public_snapshot.get("direction", 1))
	%GameDetail.text = "Cor ativa: %s   ·   Direção: %s" % [String(public_snapshot.get("active_color", "—")).capitalize(), "horária" if direction == 1 else "anti-horária"]
	var active_color: String = String(public_snapshot.get("active_color", "—"))
	var names: Dictionary = {"red":"VERMELHO", "yellow":"AMARELO", "green":"VERDE", "blue":"AZUL"}
	%ActiveColor.text = "● Cor atual: %s" % String(names.get(active_color, active_color.to_upper()))
	%ActiveColor.modulate = CardVisual.UNO_COLORS.get(active_color, Color.WHITE)
	%DrawPile.text = "▣ Comprar uma carta · %d no monte" % int(public_snapshot.get("draw_count", 0))
	var last_play: Dictionary = public_snapshot.get("last_play", {}) as Dictionary
	if not last_play.is_empty() and not String(last_play.get("chosen_color", "")).is_empty():
		_show_message("%s jogou um Curinga e escolheu %s." % [_player_name(int(last_play.get("peer_id", -1))), String(names.get(last_play.get("chosen_color", ""), ""))])

func _play() -> void:
	var card: Dictionary = cards_by_uid.get(selected_uid, {}) as Dictionary
	var action: String = String(card.get("action", ""))
	if action in ["wild", "wild_draw_four"]:
		_color_popup.popup_centered(Vector2i(390, 190))
		_show_message("Escolha a cor do curinga.")
		return
	_submit_play("")

func _submit_play(chosen_color: String) -> void:
	var payload: Dictionary = {"declared_uno": %DeclareUno.button_pressed}
	if not chosen_color.is_empty():
		payload["chosen_color"] = chosen_color
	submit_selected("PLAY_CARD", payload)

func _create_color_popup() -> void:
	_color_popup = PopupPanel.new()
	_color_popup.title = "Escolha a cor"
	add_child(_color_popup)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_color_popup.add_child(column)
	var instruction: Label = Label.new()
	instruction.text = "Escolha a cor ativa do curinga"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(instruction)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	for color_name: String in ["red", "yellow", "green", "blue"]:
		var button: Button = Button.new()
		button.text = {"red":"Vermelho", "yellow":"Amarelo", "green":"Verde", "blue":"Azul"}[color_name]
		button.custom_minimum_size = Vector2(86.0, 64.0)
		button.pressed.connect(func() -> void:
			_color_popup.hide()
			_submit_play(color_name)
		)
		row.add_child(button)
	var cancel: Button = Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(_color_popup.hide)
	column.add_child(cancel)

func _update_actions() -> void:
	if not is_node_ready():
		return
	var local_turn: bool = ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id)
	var phase: int = int(public_snapshot.get("phase", -1))
	var selected: Dictionary = cards_by_uid.get(selected_uid, {}) as Dictionary
	var legal: bool = ActionAvailability.uno_card_playable(public_snapshot, private_snapshot, selected, SessionState.local_peer_id)
	%Play.disabled = not legal or pending_action != -1
	%Draw.disabled = not local_turn or phase != 1 or pending_action != -1
	%DrawPile.disabled = %Draw.disabled or not bool(public_snapshot.get("can_draw", false))
	%Pass.disabled = not local_turn or phase != 2 or pending_action != -1
	%DeclareUno.visible = selected_uid != -1 and cards_by_uid.size() == 2
	%DeclareUno.disabled = %Play.disabled
	%Draw.visible = local_turn and phase == 1
	%Pass.visible = local_turn and phase == 2
	%DrawPile.modulate = Color(1.12, 1.12, 0.72) if local_turn and phase == 1 and not _has_playable_card() else Color.WHITE
	if pending_action == -1:
		if not local_turn:
			_show_message("Não é sua vez.")
		elif selected_uid == -1:
			if not _has_playable_card() and phase == 1:
				_show_message("Você não possui uma carta válida. Compre uma carta.")
			elif phase == 2:
				_show_message("Você comprou uma carta jogável. Jogue essa carta ou passe.")
			else:
				_show_message("Sua vez — selecione uma carta.")
		elif legal:
			_show_message("Carta selecionada — clique em JOGAR CARTA.")
		else:
			_show_message("Esta carta não combina com a cor, número ou símbolo atual.")

func _primary_action() -> BaseButton:
	return %Play

func _valid_selection_phases() -> Array[int]:
	return [1, 2]

func _selection_can_survive(uid: int) -> bool:
	if not super(uid):
		return false
	return int(public_snapshot.get("phase", -1)) != 2 or uid == int(private_snapshot.get("drawn_uid", -2))

func _card_playable_hint(card: Dictionary) -> bool:
	return ActionAvailability.uno_card_playable(public_snapshot, private_snapshot, card, SessionState.local_peer_id)

func _has_playable_card() -> bool:
	for card_value: Variant in cards_by_uid.values():
		if _card_playable_hint(card_value as Dictionary):
			return true
	return false

func _phase_text(phase: int) -> String:
	return ["Distribuindo", "Jogando", "Carta comprada: jogue ou passe", "Resolvendo efeito", "Encerrada"][clampi(phase, 0, 4)]
