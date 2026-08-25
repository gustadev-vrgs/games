extends GameUI

func _ready() -> void:
	super()
	%DrawPile.pressed.connect(func() -> void: submit("DRAW_PILE"))
	%DrawDiscard.pressed.connect(func() -> void: submit("DRAW_DISCARD"))
	%Discard.pressed.connect(_discard)
	%Knock.pressed.connect(func() -> void: submit("KNOCK_TEN"))
	%Discard.custom_minimum_size = Vector2(190.0, 48.0)
	%DrawPile.tooltip_text = "Compra a carta fechada do monte"
	%DrawDiscard.tooltip_text = "Compra a carta visível do descarte"
	%Discard.tooltip_text = "Confirma o descarte selecionado"

func _render_specific_table() -> void:
	_add_table_card({}, "Monte", false)
	var discard_value: Variant = public_snapshot.get("discard_top", {})
	if discard_value is Dictionary and not (discard_value as Dictionary).is_empty():
		_add_table_card(discard_value as Dictionary, "Descarte")
	var turn_value: Variant = public_snapshot.get("turn_card", {})
	if turn_value is Dictionary:
		_add_table_card(turn_value as Dictionary, "Vira")
	var wild_value: Variant = public_snapshot.get("wild", {})
	var wild: Dictionary = wild_value as Dictionary if wild_value is Dictionary else {}
	%GameDetail.text = "Curinga: %s de %s   ·   Vidas: %s" % [String(wild.get("rank", "—")), String(wild.get("suit", "—")), _lives_text()]

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
	%Knock.disabled = not local_turn or phase != 2 or pending_action != -1
	%KnockNormal.disabled = %Discard.disabled
	if pending_action == -1:
		if not local_turn:
			_show_message("Não é sua vez.")
		elif phase == 1:
			_show_message("Primeiro compre uma carta.")
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
