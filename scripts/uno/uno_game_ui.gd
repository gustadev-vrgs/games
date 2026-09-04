extends GameUI

var _color_popup: PopupPanel
var _uno_declared: bool = false
var _uno_warning: ConfirmationDialog
var selected_uids: Array[int] = []

func _ready() -> void:
	super()
	%Play.pressed.connect(_play)
	%Draw.pressed.connect(func() -> void: submit("DRAW_ONE"))
	%DrawPile.pressed.connect(func() -> void: submit("DRAW_ONE"))
	%Pass.pressed.connect(func() -> void: submit("PASS"))
	%DeclareUno.pressed.connect(_declare_uno)
	%Color.visible = false
	%Play.custom_minimum_size = Vector2(170.0, 48.0)
	%Play.tooltip_text = "Confirma a carta selecionada"
	%Draw.tooltip_text = "Compra uma carta do monte"
	%DrawPile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	%Pass.tooltip_text = "Encerra o turno depois da compra"
	_create_color_popup()
	_create_uno_warning()

func _render_specific_table() -> void:
	var top_value: Variant = public_snapshot.get("top_card", {})
	if top_value is Dictionary:
		_add_table_card(top_value as Dictionary, "Descarte", true, CardVisual.DisplayMode.TABLE)
	var direction: int = int(public_snapshot.get("direction", 1))
	%GameDetail.text = "Cor ativa: %s   ·   Direção: %s" % [CardFormatter.uno_color(String(public_snapshot.get("active_color", "—"))), "horária" if direction == 1 else "anti-horária"]
	var active_color: String = String(public_snapshot.get("active_color", "—"))
	%ActiveColor.text = "● Cor atual: %s" % CardFormatter.uno_color(active_color).to_upper()
	%ActiveColor.modulate = CardVisual.UNO_COLORS.get(active_color, Color.WHITE)
	var last_play: Dictionary = public_snapshot.get("last_play", {}) as Dictionary
	if not last_play.is_empty() and not String(last_play.get("chosen_color", "")).is_empty():
		_show_message("%s jogou um Curinga e escolheu %s." % [_player_name(int(last_play.get("peer_id", -1))), CardFormatter.uno_color(String(last_play.get("chosen_color", "")))])

func _play() -> void:
	if cards_by_uid.size() - selected_uids.size() == 1 and not _uno_declared:
		_uno_warning.popup_centered(Vector2i(570, 220))
		return
	_play_confirmed()

func _play_confirmed() -> void:
	var card: Dictionary = cards_by_uid.get(selected_uid, {}) as Dictionary
	var action: String = String(card.get("action", ""))
	if action in ["wild", "wild_draw_four"]:
		_color_popup.popup_centered(Vector2i(390, 190))
		_show_message("Escolha a cor do curinga.")
		return
	_submit_play("")

func _submit_play(chosen_color: String) -> void:
	var payload: Dictionary = {"declared_uno": _uno_declared}
	if not chosen_color.is_empty():
		payload["chosen_color"] = chosen_color
	payload["card_uids"] = selected_uids.duplicate()
	submit("PLAY_CARDS", payload)

func _declare_uno() -> void:
	if cards_by_uid.size() - selected_uids.size() != 1 or selected_uids.is_empty():
		return
	_uno_declared = true
	%DeclareUno.text = "UNO DECLARADO ✓"
	_show_message("UNO declarado. Jogue sua penúltima carta!")

func _create_uno_warning() -> void:
	_uno_warning = ConfirmationDialog.new()
	_uno_warning.title = "Declarar UNO"
	_uno_warning.dialog_text = "Você ficará com uma carta sem declarar UNO e receberá a penalidade. Deseja continuar?"
	_uno_warning.ok_button_text = "Jogar sem declarar"
	_uno_warning.cancel_button_text = "Voltar e declarar UNO"
	_uno_warning.confirmed.connect(_play_confirmed)
	add_child(_uno_warning)

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
	var validation_uid: int = selected_uids[0] if not selected_uids.is_empty() else selected_uid
	var selected: Dictionary = cards_by_uid.get(validation_uid, {}) as Dictionary
	var legal: bool = ActionAvailability.uno_card_playable(public_snapshot, private_snapshot, selected, SessionState.local_peer_id)
	if selected_uids.size() > 1:
		legal = legal and int(public_snapshot.get("phase", -1)) == 1
	%Play.disabled = not legal or pending_action != -1
	%Play.text = "JOGAR %d CARTAS" % selected_uids.size() if selected_uids.size() > 1 else "JOGAR CARTA"
	%Draw.disabled = not local_turn or phase != 1 or pending_action != -1
	%DrawPile.set_available(not %Draw.disabled and bool(public_snapshot.get("can_draw", false)))
	%Pass.disabled = not local_turn or phase != 2 or pending_action != -1
	%DeclareUno.visible = true
	%DeclareUno.disabled = %Play.disabled
	%DeclareUno.text = "UNO DECLARADO ✓" if _uno_declared else "GRITAR UNO!"
	%Draw.visible = true
	%Pass.visible = true
	%DrawPile.set_emphasized(local_turn and phase == 1 and not _has_playable_card())
	if pending_action == -1:
		if not local_turn:
			_show_message("Não é sua vez.")
		elif selected_uids.is_empty():
			if not _has_playable_card() and phase == 1:
				_show_message("Você não possui uma carta válida. Compre uma carta.")
			elif phase == 2:
				_show_message("Você comprou uma carta jogável. Jogue essa carta ou passe.")
			else:
				_show_message("Sua vez — selecione uma carta.")
		elif legal:
			if cards_by_uid.size() - selected_uids.size() == 1 and not _uno_declared:
				_show_message("Você ficará com uma carta. Declare UNO antes de jogar.")
			elif selected_uids.size() > 1:
				_show_message("%d cartas selecionadas. A última selecionada ficará no topo." % selected_uids.size())
			else:
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

func _on_private_snapshot(snapshot: Dictionary) -> void:
	selected_uids.clear()
	super(snapshot)

func _select_card(uid: int) -> void:
	if pending_action != -1:
		return
	var existing: int = selected_uids.find(uid)
	if existing != -1:
		selected_uids.remove_at(existing)
	else:
		var candidate: Dictionary = cards_by_uid.get(uid, {}) as Dictionary
		if not selected_uids.is_empty():
			var first: Dictionary = cards_by_uid.get(selected_uids[0], {}) as Dictionary
			if int(public_snapshot.get("phase", -1)) == 2:
				_show_message("Depois da compra, somente a carta comprada pode ser jogada e não pode ser combinada.")
				return
			if not _is_numeric_card(first) or not _is_numeric_card(candidate):
				_show_message("A combinação aceita somente cartas numéricas de 0 a 9.")
				return
			if String(candidate.get("rank", "")) != String(first.get("rank", "")):
				_show_message("Essa carta não entrou: escolha outra carta com o mesmo número da primeira.")
				return
		selected_uids.append(uid)
	selected_uid = selected_uids.back() if not selected_uids.is_empty() else -1
	_refresh_hand_states()
	if selected_uids.is_empty():
		%Selection.text = "Selecione uma carta"
	elif selected_uids.size() == 1:
		%Selection.text = "1 carta selecionada · ordem: 1"
	else:
		%Selection.text = "%d cartas selecionadas · ordem: %s · a última ficará no topo" % [selected_uids.size(), _selection_order_text()]
	_update_actions()

func _refresh_hand_states() -> void:
	for child: Node in hand.get_children():
		if child is CardVisual:
			var visual: CardVisual = child as CardVisual
			var card: Dictionary = cards_by_uid.get(visual.card_uid, {}) as Dictionary
			visual.set_state(visual.card_uid in selected_uids, true, _card_playable_hint(card), pending_action != -1)

func _selection_order_text() -> String:
	var values: PackedStringArray = []
	for index: int in selected_uids.size(): values.append(str(index + 1))
	return " → ".join(values)

func _is_numeric_card(card: Dictionary) -> bool:
	return String(card.get("action", "")).is_empty() and String(card.get("rank", "")) in ["0","1","2","3","4","5","6","7","8","9"]

func _card_playable_hint(card: Dictionary) -> bool:
	return ActionAvailability.uno_card_playable(public_snapshot, private_snapshot, card, SessionState.local_peer_id)

func _has_playable_card() -> bool:
	for card_value: Variant in cards_by_uid.values():
		if _card_playable_hint(card_value as Dictionary):
			return true
	return false

func _phase_text(phase: int) -> String:
	return ["Distribuindo", "Jogando", "Carta comprada: jogue ou passe", "Resolvendo efeito", "Encerrada"][clampi(phase, 0, 4)]

func _on_action_answered(answer: Dictionary) -> void:
	var was_pending: bool = int(answer.get("client_action_id", -1)) == pending_action
	var accepted: bool = bool(answer.get("accepted", false))
	super(answer)
	if was_pending and accepted:
		_uno_declared = false
		selected_uids.clear()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.is_action("ui_cancel") and not selected_uids.is_empty() and pending_action == -1:
		selected_uids.clear()
		selected_uid = -1
		_refresh_hand_states()
		%Selection.text = "Selecione uma carta"
		_update_actions()
		get_viewport().set_input_as_handled()
		return
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_U and not %DeclareUno.disabled:
		_declare_uno()
		get_viewport().set_input_as_handled()
		return
	super(event)
