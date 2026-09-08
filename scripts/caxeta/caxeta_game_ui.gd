extends GameUI

var _local_hand_order: Array[int] = []

func _ready() -> void:
	super()
	%DrawPile.pressed.connect(_draw_from_pile)
	%DrawDiscard.pressed.connect(func() -> void: submit("DRAW_DISCARD"))
	%Discard.pressed.connect(_discard)
	%Knock.pressed.connect(func() -> void: submit("KNOCK"))
	%Discard.custom_minimum_size = Vector2(190.0, 48.0)
	%DrawPile.tooltip_text = "Compra a carta fechada do monte"
	%DrawDiscard.tooltip_text = "Compra a carta visível do descarte"
	%Discard.tooltip_text = "Confirma o descarte selecionado"

func _render_specific_table() -> void:
	var pile_group: VBoxContainer = VBoxContainer.new()
	var pile_label: Label = Label.new()
	pile_label.text = "Monte"
	pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile_group.add_child(pile_label)
	var pile: CardVisual = CARD_SCENE.instantiate() as CardVisual
	pile_group.add_child(pile)
	pile.configure({"game_id": "caxeta"}, false, CardVisual.DisplayMode.TABLE)
	var pile_available: bool = ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id) and int(public_snapshot.get("phase", -1)) == 1 and pending_action == -1
	pile.set_state(false, pile_available, pile_available, pending_action != -1)
	pile.tooltip_text = %DrawPile.tooltip_text
	pile.card_clicked.connect(func(_uid: int) -> void: _draw_from_pile())
	table_cards.add_child(pile_group)
	var discard_value: Variant = public_snapshot.get("discard_top", {})
	if discard_value is Dictionary and not (discard_value as Dictionary).is_empty():
		_add_table_card(discard_value as Dictionary, "Descarte", true, CardVisual.DisplayMode.TABLE)
	%GameDetail.text = "Coringas próprios do baralho   ·   Vidas: %s" % _lives_text()

func _draw_from_pile() -> void:
	if not %DrawPile.disabled:
		submit("DRAW_PILE")

func _discard() -> void:
	submit_selected("DISCARD", {"declare_knock": %KnockNormal.button_pressed})

func _lives_text() -> String:
	var lives_value: Variant = public_snapshot.get("lives", {})
	if not lives_value is Dictionary:
		return "—"
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in (lives_value as Dictionary).keys():
		parts.append("%s %d" % [_player_name(int(key)), int((lives_value as Dictionary).get(key, 0))])
	return " · ".join(parts)

func _update_actions() -> void:
	if not is_node_ready():
		return
	var phase: int = int(public_snapshot.get("phase", 0))
	var local_turn: bool = ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id)
	%DrawPile.disabled = not local_turn or phase != 1 or pending_action != -1
	var discard_value: Variant = public_snapshot.get("discard_top", {})
	var has_discard: bool = discard_value is Dictionary and not (discard_value as Dictionary).is_empty()
	%DrawDiscard.disabled = not local_turn or phase != 1 or not has_discard or pending_action != -1
	%Discard.disabled = not ActionAvailability.caxeta_can_discard(public_snapshot, selected_uid, SessionState.local_peer_id) or pending_action != -1
	%Knock.text = "Bater com 9" if phase == 1 else "Bater com 10"
	%Knock.disabled = not local_turn or phase not in [1, 2] or pending_action != -1
	%KnockNormal.disabled = %Discard.disabled
	if pending_action == -1:
		if not local_turn:
			_show_message("Não é sua vez.")
		elif phase == 1:
			_show_message("Compre uma carta ou bata se as 9 cartas formarem jogos válidos.")
		elif selected_uid == -1:
			_show_message("Selecione uma carta para descartar.")
		else:
			_show_message("Carta selecionada — clique em DESCARTAR CARTA.")

func _primary_action() -> BaseButton:
	return %Discard

func _valid_selection_phases() -> Array[int]:
	return [2]

func _card_playable_hint(_card: Dictionary) -> bool:
	return ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id) and int(public_snapshot.get("phase", -1)) == 2

func _phase_text(phase: int) -> String:
	return ["Distribuindo", "Compre uma carta", "Descarte ou bata", "Fim da rodada", "Partida encerrada"][clampi(phase, 0, 4)]

func _ordered_hand_cards(snapshot_hand: Array) -> Array:
	var by_uid: Dictionary = {}
	for value: Variant in snapshot_hand:
		if value is Dictionary:
			by_uid[int((value as Dictionary).get("uid", -1))] = value
	var reconciled: Array[int] = []
	for uid: int in _local_hand_order:
		if by_uid.has(uid):
			reconciled.append(uid)
	for value: Variant in snapshot_hand:
		var uid: int = int((value as Dictionary).get("uid", -1))
		if uid not in reconciled:
			reconciled.append(uid)
	_local_hand_order = reconciled
	var ordered: Array = []
	for uid: int in _local_hand_order:
		ordered.append(by_uid[uid])
	return ordered

func _configure_hand_visual(visual: CardVisual) -> void:
	visual.enable_local_reordering(true)
	visual.card_reorder_requested.connect(_reorder_local_hand)

func _reorder_local_hand(source_uid: int, target_uid: int) -> void:
	var source_index: int = _local_hand_order.find(source_uid)
	var target_index: int = _local_hand_order.find(target_uid)
	if source_index < 0 or target_index < 0:
		return
	_local_hand_order.remove_at(source_index)
	target_index = _local_hand_order.find(target_uid)
	_local_hand_order.insert(target_index, source_uid)
	for index: int in _local_hand_order.size():
		var card_node: CardVisual = _card_visual_for_uid(_local_hand_order[index])
		if is_instance_valid(card_node):
			hand.move_child(card_node, index)
	_show_message("Ordem da mão ajustada somente neste dispositivo.")

func _card_visual_for_uid(uid: int) -> CardVisual:
	for child: Node in hand.get_children():
		if child is CardVisual and (child as CardVisual).card_uid == uid:
			return child as CardVisual
	return null
