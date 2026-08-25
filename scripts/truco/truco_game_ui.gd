extends GameUI

func _ready() -> void:
	super()
	%Play.pressed.connect(func() -> void: submit_selected("PLAY_CARD"))
	%Truco.pressed.connect(func() -> void: submit("REQUEST_TRUCO"))
	%Accept.pressed.connect(func() -> void: submit("ACCEPT"))
	%Run.pressed.connect(func() -> void: submit("RUN"))
	%Raise.pressed.connect(func() -> void: submit("RAISE"))
	%Play.custom_minimum_size = Vector2(170.0, 48.0)
	%Play.tooltip_text = "Confirma a carta selecionada"
	%Truco.tooltip_text = "Propõe o próximo valor permitido"
	%Accept.tooltip_text = "Aceita o valor proposto"

func _render_specific_table() -> void:
	var turn_value: Variant = public_snapshot.get("turn_card", {})
	if turn_value is Dictionary:
		_add_table_card(turn_value as Dictionary, "Vira")
	var played_value: Variant = public_snapshot.get("played", [])
	if played_value is Array:
		for value: Variant in played_value as Array:
			if value is Dictionary:
				var play: Dictionary = value as Dictionary
				var card_value: Variant = play.get("card", {})
				if card_value is Dictionary:
					_add_table_card(card_value as Dictionary, _player_name(int(play.get("peer_id", -1))))
	var scores_value: Variant = public_snapshot.get("scores", [0, 0])
	var scores: Array = scores_value as Array if scores_value is Array else [0, 0]
	%GameDetail.text = "Equipe A %d × %d Equipe B   ·   Manilha: %s   ·   Mão vale %d" % [int(scores[0]), int(scores[1]), String(public_snapshot.get("manilha", "—")), int(public_snapshot.get("accepted_value", 1))]

func _update_actions() -> void:
	if not is_node_ready():
		return
	var waiting: bool = int(public_snapshot.get("phase", 0)) == 2
	var local_team: int = int(SessionState.private_state.get("team", -1))
	var responding: bool = waiting and int(public_snapshot.get("responding_team", -2)) == local_team
	var local_turn: bool = ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id)
	%Play.disabled = not ActionAvailability.truco_can_play(public_snapshot, selected_uid, SessionState.local_peer_id) or pending_action != -1
	var last_team: int = int(public_snapshot.get("last_raise_team", -1))
	%Truco.disabled = waiting or not local_turn or int(public_snapshot.get("accepted_value", 1)) >= 12 or last_team == local_team or pending_action != -1
	%Accept.disabled = not responding or pending_action != -1
	%Run.disabled = not responding or pending_action != -1
	%Raise.disabled = not responding or int(public_snapshot.get("target_value", 0)) >= 12 or pending_action != -1
	if pending_action == -1:
		if waiting:
			_show_message("Responda ao pedido de Truco." if responding else "Aguardando resposta ao pedido de Truco.")
		elif not local_turn:
			_show_message("Não é sua vez.")
		elif selected_uid == -1:
			_show_message("Sua vez — selecione uma carta.")
		else:
			_show_message("Carta selecionada — clique em JOGAR CARTA.")

func _primary_action() -> BaseButton:
	return %Play

func _valid_selection_phases() -> Array[int]:
	return [1]

func _card_playable_hint(_card: Dictionary) -> bool:
	return ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id) and int(public_snapshot.get("phase", -1)) == 1

func _phase_text(phase: int) -> String:
	return ["Distribuindo", "Vaza em andamento", "Pedido de Truco pendente", "Fim da mão", "Partida encerrada"][clampi(phase, 0, 4)]
