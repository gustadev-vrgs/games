extends GameUI

const PHASE_PLAYING: int = 1
const PHASE_WAITING: int = 2
const PHASE_REVEAL: int = 3
const VALUE_NAMES: Dictionary = {3:"TRUCO", 6:"SEIS", 9:"NOVE", 12:"DOZE"}

func _ready() -> void:
	super()
	%Play.pressed.connect(func() -> void: submit_selected("PLAY_CARD"))
	%Truco.pressed.connect(func() -> void: submit("REQUEST_TRUCO"))
	%Accept.pressed.connect(func() -> void: submit("ACCEPT"))
	%Run.pressed.connect(func() -> void: submit("RUN"))
	%Raise.pressed.connect(func() -> void: submit("RAISE"))
	%Play.custom_minimum_size = Vector2(170.0, 48.0)
	%RequestPanel.visible = false

func _render_specific_table() -> void:
	var turn_value: Variant = public_snapshot.get("turn_card", {})
	if turn_value is Dictionary:
		_add_table_card(turn_value as Dictionary, "Vira")
	var reveal: Dictionary = public_snapshot.get("reveal_result", {}) as Dictionary
	var winning_peer: int = int(reveal.get("winning_peer", -1))
	var played_value: Variant = public_snapshot.get("played", [])
	if played_value is Array:
		for value: Variant in played_value as Array:
			if value is Dictionary:
				var play: Dictionary = value as Dictionary
				_add_table_card_with_state(play.get("card", {}) as Dictionary, _player_name(int(play.get("peer_id", -1))), int(play.get("peer_id", -1)) == winning_peer)
	var scores: Array = public_snapshot.get("scores", [0, 0]) as Array
	%GameDetail.text = "Equipe A %d × %d Equipe B   ·   Manilha: %s   ·   Mão vale %d" % [int(scores[0]), int(scores[1]), String(public_snapshot.get("manilha", "—")), int(public_snapshot.get("accepted_value", 1))]
	_render_history()
	if int(public_snapshot.get("phase", -1)) == PHASE_REVEAL:
		if bool(reveal.get("tied", false)):
			_show_message("A vaza empatou.")
		else:
			_show_message("Equipe %s venceu a %dª vaza." % ["A" if int(reveal.get("winner_team", 0)) == 0 else "B", int(reveal.get("trick_number", 1))])

func _render_history() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for entry_value: Variant in public_snapshot.get("trick_history", []):
		var entry: Dictionary = entry_value as Dictionary
		lines.append("%dª vaza" % int(entry.get("trick_number", 0)))
		for play_value: Variant in entry.get("plays", []):
			var play: Dictionary = play_value as Dictionary
			lines.append("%s — %s" % [_player_name(int(play.get("peer_id", -1))), _card_name(play.get("card", {}) as Dictionary)])
		lines.append("Empate" if bool(entry.get("tied", false)) else "Equipe %s venceu" % ("A" if int(entry.get("winner_team", 0)) == 0 else "B"))
	%History.text = "\n".join(lines) if not lines.is_empty() else "Nenhuma vaza concluída."

func _update_actions() -> void:
	if not is_node_ready():
		return
	var phase: int = int(public_snapshot.get("phase", 0))
	var waiting: bool = phase == PHASE_WAITING
	var local_team: int = int(private_snapshot.get("team", -1))
	var responding: bool = waiting and int(public_snapshot.get("responding_team", -2)) == local_team
	var local_turn: bool = ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id)
	var blocked: bool = pending_action != -1
	%Play.visible = phase == PHASE_PLAYING
	%Play.disabled = not ActionAvailability.truco_can_play(public_snapshot, selected_uid, SessionState.local_peer_id) or blocked
	var next_value: int = int(public_snapshot.get("next_raise_value", 0))
	%Truco.visible = phase == PHASE_PLAYING and local_turn and next_value > 0 and int(public_snapshot.get("last_raise_team", -1)) != local_team
	%Truco.text = "Pedir %s" % String(VALUE_NAMES.get(next_value, "Truco")).capitalize()
	%Truco.disabled = blocked
	%Accept.visible = waiting and responding
	%Run.visible = waiting and responding
	%Raise.visible = waiting and responding and next_value > 0
	%Accept.text = "Aceitar — vale %d" % int(public_snapshot.get("target_value", 0))
	%Raise.text = "Pedir %s" % String(VALUE_NAMES.get(next_value, "")).capitalize()
	%Accept.disabled = blocked
	%Run.disabled = blocked
	%Raise.disabled = blocked
	%RequestPanel.visible = waiting
	if waiting:
		var requesting_name: String = _player_name(int(public_snapshot.get("requesting_peer", -1)))
		var target: int = int(public_snapshot.get("target_value", 0))
		%RequestText.text = "%s pediu %s. A mão passará a valer %d pontos.\n%s" % [requesting_name, String(VALUE_NAMES.get(target, "TRUCO")), target, "Sua equipe deve responder." if responding else "Aguardando resposta da Equipe %s…" % ("A" if int(public_snapshot.get("responding_team", 0)) == 0 else "B")]
	elif phase == PHASE_REVEAL:
		_show_message("Conferindo o resultado da vaza…")

func _primary_action() -> BaseButton:
	return %Play

func _valid_selection_phases() -> Array[int]:
	return [PHASE_PLAYING]

func _card_playable_hint(_card: Dictionary) -> bool:
	return ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id) and int(public_snapshot.get("phase", -1)) == PHASE_PLAYING

func _phase_text(phase: int) -> String:
	return ["Distribuindo", "Vaza em andamento", "Pedido pendente", "Conferindo vaza", "Fim da mão", "Partida encerrada"][clampi(phase, 0, 5)]
