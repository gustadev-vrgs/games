extends GameUI

const PHASE_PLAYING: int = 1
const PHASE_WAITING: int = 2
const PHASE_REVEAL: int = 3
const VALUE_NAMES: Dictionary = {3:"TRUCO", 6:"SEIS", 9:"NOVE", 12:"DOZE"}
var _face_down_dialog: ConfirmationDialog

func _ready() -> void:
	super()
	%Play.pressed.connect(func() -> void: submit_selected("PLAY_CARD"))
	%FaceDown.pressed.connect(_confirm_face_down)
	%FaceDownPile.pressed.connect(_confirm_face_down)
	%Truco.pressed.connect(func() -> void: submit("REQUEST_TRUCO"))
	%Accept.pressed.connect(func() -> void: submit("ACCEPT"))
	%Run.pressed.connect(func() -> void: submit("RUN"))
	%Raise.pressed.connect(func() -> void: submit("RAISE"))
	%Play.custom_minimum_size = Vector2(170.0, 48.0)
	%FaceDown.custom_minimum_size = Vector2(190.0, 48.0)
	%Truco.custom_minimum_size = Vector2(170.0, 48.0)
	%RequestPanel.visible = false
	HubTheme.style_pill(%ScorePill, HubTheme.GOLD)
	HubTheme.style_pill(%TrickPill, HubTheme.INFO)
	HubTheme.style_pill(%ValuePill, HubTheme.WARNING)
	%ResponderAs.item_selected.connect(_responder_selected)
	%FaceDownPile.icon = TrucoSpanishCardTextures.load_back()
	%FaceDownPile.expand_icon = true
	_create_face_down_dialog()

func _render_specific_table() -> void:
	_clear_children(%ViraCards)
	var turn_value: Variant = public_snapshot.get("turn_card", {})
	if turn_value is Dictionary:
		var vira: CardVisual = CARD_SCENE.instantiate() as CardVisual
		%ViraCards.add_child(vira)
		vira.configure(turn_value as Dictionary, true, CardVisual.DisplayMode.SPANISH_DECK)
		vira.set_state(false, false, false, false)
	%Manilha.text = "Manilha: %s" % CardFormatter.spanish_rank(String(public_snapshot.get("manilha", "—")))
	var reveal: Dictionary = public_snapshot.get("reveal_result", {}) as Dictionary
	var winning_peer: int = int(reveal.get("winning_peer", -1))
	var played_value: Variant = public_snapshot.get("played", [])
	if played_value is Array:
		for value: Variant in played_value as Array:
			var play: Dictionary = value as Dictionary
			var hidden: bool = bool(play.get("face_down", false))
			_add_truco_table_card(play.get("card", {}) as Dictionary, _player_name(int(play.get("peer_id", -1))), hidden, int(play.get("peer_id", -1)) == winning_peer)
	var scores: Array = public_snapshot.get("scores", [0, 0]) as Array
	%ScorePill.text = "EQUIPE A %d × %d EQUIPE B" % [int(scores[0]), int(scores[1])]
	%TrickPill.text = "%dº TURNO" % int(public_snapshot.get("trick_number", 1))
	%ValuePill.text = "VALE %d" % int(public_snapshot.get("accepted_value", 1))
	_render_history()
	if int(public_snapshot.get("phase", -1)) == PHASE_REVEAL:
		_show_message("O %dº turno terminou empatado" % int(reveal.get("trick_number", 1)) if bool(reveal.get("tied", false)) else "Equipe %s venceu o %dº turno" % ["A" if int(reveal.get("winner_team", 0)) == 0 else "B", int(reveal.get("trick_number", 1))])

func _add_truco_table_card(card: Dictionary, caption: String, hidden: bool, winning: bool) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(label)
	var visual: CardVisual = CARD_SCENE.instantiate() as CardVisual
	group.add_child(visual)
	visual.configure(card, not hidden, CardVisual.DisplayMode.FACE_DOWN_PLAY if hidden else CardVisual.DisplayMode.TABLE)
	visual.set_state(false, false, false, false)
	visual.set_winning_card(winning)
	table_cards.add_child(group)

func _render_history() -> void:
	_clear_children(%History)
	var history: Array = public_snapshot.get("trick_history", []) as Array
	if history.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nenhum turno concluído."
		%History.add_child(empty)
		return
	for entry_value: Variant in history:
		var entry: Dictionary = entry_value as Dictionary
		var title: Label = Label.new()
		title.text = "%dº TURNO" % int(entry.get("trick_number", 0))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		%History.add_child(title)
		var miniatures: HBoxContainer = HBoxContainer.new()
		miniatures.alignment = BoxContainer.ALIGNMENT_CENTER
		%History.add_child(miniatures)
		for play_value: Variant in entry.get("plays", []) as Array:
			var play: Dictionary = play_value as Dictionary
			var group: VBoxContainer = VBoxContainer.new()
			group.custom_minimum_size = Vector2(70.0, 0.0)
			group.alignment = BoxContainer.ALIGNMENT_CENTER
			miniatures.add_child(group)
			var name_label: Label = Label.new()
			name_label.text = _player_name(int(play.get("peer_id", -1)))
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			group.add_child(name_label)
			var hidden: bool = bool(play.get("face_down", false))
			var card_center: CenterContainer = CenterContainer.new()
			card_center.custom_minimum_size = Vector2(70.0, 78.0)
			group.add_child(card_center)
			var mini: CardVisual = CARD_SCENE.instantiate() as CardVisual
			mini.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			mini.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card_center.add_child(mini)
			mini.configure(play.get("card", {}) as Dictionary, not hidden, CardVisual.DisplayMode.HISTORY_MINI)
			mini.set_state(false, false, false, false)
			if hidden:
				var hidden_label: Label = Label.new()
				hidden_label.text = "Carta encoberta"
				group.add_child(hidden_label)
		var result: Label = Label.new()
		result.text = "Empate" if bool(entry.get("tied", false)) else "Equipe %s venceu" % ("A" if int(entry.get("winner_team", 0)) == 0 else "B")
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.add_theme_color_override("font_color", HubTheme.WARNING if bool(entry.get("tied", false)) else (HubTheme.SUCCESS if int(entry.get("winner_team", 0)) == int(private_snapshot.get("team", -1)) else HubTheme.DANGER))
		%History.add_child(result)

func _update_actions() -> void:
	if not is_node_ready(): return
	var phase: int = int(public_snapshot.get("phase", 0))
	var waiting: bool = phase == PHASE_WAITING
	var local_team: int = int(private_snapshot.get("team", -1))
	var responding: bool = waiting and int(public_snapshot.get("responding_team", -2)) == local_team
	var local_turn: bool = ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id)
	var blocked: bool = pending_action != -1
	var can_play: bool = ActionAvailability.truco_can_play(public_snapshot, selected_uid, SessionState.local_peer_id) and not blocked
	%Play.visible = true
	%Play.disabled = not can_play
	var later_turn: bool = int(public_snapshot.get("trick_number", 1)) >= 2
	%FaceDown.visible = true
	%FaceDown.disabled = not can_play or not later_turn
	%FaceDown.tooltip_text = "Jogar a carta selecionada encoberta" if later_turn else "Esconder carta — disponível a partir do 2º turno"
	%FaceDownPile.disabled = %FaceDown.disabled
	%FaceDownPile.tooltip_text = %FaceDown.tooltip_text
	%FaceDownPile.modulate = Color(1.2, 1.1, 0.55) if not %FaceDown.disabled else Color.WHITE
	var next_value: int = int(public_snapshot.get("next_raise_value", 0))
	%Truco.visible = true
	%Truco.text = "MÃO VALE 12" if next_value == 0 else ("CHAMAR TRUCO" if next_value == 3 else "PEDIR %s" % String(VALUE_NAMES.get(next_value, "")))
	%Truco.disabled = phase != PHASE_PLAYING or not local_turn or next_value == 0 or int(public_snapshot.get("last_raise_team", -1)) == local_team or blocked
	%Truco.tooltip_text = "Aguarde o resultado do turno." if phase == PHASE_REVEAL else "Aumentar o valor da mão"
	%Accept.visible = waiting and responding
	%Run.visible = waiting and responding
	%Raise.visible = waiting and responding and next_value > 0
	%Accept.text = "Aceitar — vale %d" % int(public_snapshot.get("target_value", 0))
	%Raise.text = "Pedir %s" % String(VALUE_NAMES.get(next_value, ""))
	%Accept.disabled = blocked; %Run.disabled = blocked; %Raise.disabled = blocked
	%RequestPanel.visible = waiting
	_update_responder_selector(waiting)
	if waiting:
		var target: int = int(public_snapshot.get("target_value", 0))
		%RequestText.text = "%s chamou %s!\nA mão passará a valer %d pontos.\n%s" % [_player_name(int(public_snapshot.get("requesting_peer", -1))), String(VALUE_NAMES.get(target, "TRUCO")), target, "Sua equipe deve responder." if responding else "Aguardando resposta adversária…"]
	elif phase == PHASE_REVEAL:
		_show_message("Conferindo o resultado do turno.")
	_update_turn_message(phase, waiting, responding, local_turn)

func _update_turn_message(phase: int, waiting: bool, responding: bool, local_turn: bool) -> void:
	if phase == PHASE_REVEAL:
		_show_message("Conferindo o resultado do turno.")
	elif waiting and responding:
		_show_message("Escolha como responder ao pedido.")
	elif waiting:
		_show_message("Vez de %s." % _player_name(int(public_snapshot.get("current_player", -1))))
	elif phase == PHASE_PLAYING and local_turn:
		_show_message("Sua vez — selecione uma carta.")
	elif phase == PHASE_PLAYING:
		_show_message("Vez de %s." % _player_name(int(public_snapshot.get("current_player", -1))))

func _update_responder_selector(waiting: bool) -> void:
	%ResponderRow.visible = SessionState.is_training and waiting
	if not %ResponderRow.visible: return
	var members: Dictionary = public_snapshot.get("team_members", {}) as Dictionary
	var candidates: Array = members.get(int(public_snapshot.get("responding_team", -1)), []) as Array
	%ResponderAs.clear()
	for value: Variant in candidates:
		var id: int = int(value)
		%ResponderAs.add_item(_player_name(id), id)
		if id == SessionState.local_peer_id: %ResponderAs.select(%ResponderAs.item_count - 1)

func _responder_selected(index: int) -> void:
	if SessionState.is_training and pending_action == -1:
		NetworkManager.set_training_control_peer(%ResponderAs.get_item_id(index))

func _create_face_down_dialog() -> void:
	_face_down_dialog = ConfirmationDialog.new()
	_face_down_dialog.title = "Jogar carta encoberta"
	_face_down_dialog.dialog_text = "Deseja jogar esta carta encoberta?\n\nUma carta encoberta não possui força e não pode vencer este turno."
	_face_down_dialog.ok_button_text = "Jogar encoberta"
	_face_down_dialog.cancel_button_text = "Cancelar"
	_face_down_dialog.confirmed.connect(func() -> void: submit_selected("PLAY_CARD_FACE_DOWN"))
	add_child(_face_down_dialog)

func _confirm_face_down() -> void:
	if not %FaceDown.disabled:
		_face_down_dialog.popup_centered(Vector2i(560, 230))

func _primary_action() -> BaseButton: return %Play
func _valid_selection_phases() -> Array[int]: return [PHASE_PLAYING]
func _card_playable_hint(_card: Dictionary) -> bool: return ActionAvailability.is_local_turn(public_snapshot, SessionState.local_peer_id) and int(public_snapshot.get("phase", -1)) == PHASE_PLAYING
func _phase_text(phase: int) -> String: return ["Distribuindo", "Turno em andamento", "Pedido pendente", "Conferindo turno", "Fim da mão", "Partida encerrada"][clampi(phase, 0, 5)]
