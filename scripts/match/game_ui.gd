class_name GameUI
extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/shared/card_visual.tscn")
const ACTION_TIMEOUT_SECONDS: float = 8.0
const ERROR_MESSAGES: Dictionary = {
	"NOT_YOUR_TURN": "Aguarde sua vez.",
	"CARD_NOT_OWNED": "Essa carta não está mais na sua mão.",
	"CARD_NOT_PLAYABLE": "Essa carta não pode ser jogada agora.",
	"DUPLICATE_CARD_UID": "A mesma carta não pode aparecer duas vezes na jogada.",
	"COMBINATION_NUMBERS_ONLY": "Combine somente cartas numéricas de 0 a 9.",
	"COMBINATION_NUMBER_MISMATCH": "Todas as cartas combinadas devem ter o mesmo número.",
	"CANNOT_COMBINE_AFTER_DRAW": "Depois da compra, a carta comprada deve ser jogada sozinha.",
	"STALE_STATE": "O estado mudou. Tente novamente.",
	"INVALID_PHASE": "Essa ação não está disponível nesta fase.",
	"INVALID_COLOR": "Escolha uma cor válida.",
	"ILLEGAL_WILD_DRAW_FOUR": "O +4 só vale quando você não possui a cor ativa.",
	"MUST_DRAW_FIRST": "Compre uma carta antes de continuar.",
	"FACE_DOWN_FIRST_TRICK": "A carta só pode ser encoberta a partir do 2º turno.",
	"INVALID_KNOCK": "Sua mão ainda não forma combinações válidas.",
}

var pending_action: int = -1
var selected_uid: int = -1
var cards_by_uid: Dictionary = {}
var public_snapshot: Dictionary = {}
var private_snapshot: Dictionary = {}
var _pending_timer: Timer
var _leave_dialog: ConfirmationDialog

@onready var hand: HBoxContainer = %Hand
@onready var opponents: HFlowContainer = %Opponents
@onready var table_cards: HBoxContainer = %TableCards

func _ready() -> void:
	HubTheme.apply_to(self)
	_polish_shared_layout()
	_connect_once(NetworkManager.public_snapshot_received, _on_public_snapshot)
	_connect_once(NetworkManager.private_snapshot_received, _on_private_snapshot)
	_connect_once(NetworkManager.action_answered, _on_action_answered)
	_connect_once(NetworkManager.session_interrupted, _on_session_interrupted)
	_connect_once(%Leave.pressed, _leave)
	%Leave.text = "← SAIR"
	%Leave.custom_minimum_size = Vector2(112.0, 42.0)
	HubTheme.style_exit(%Leave)
	%Title.add_theme_color_override("font_color", HubTheme.GOLD)
	%Title.add_theme_color_override("font_outline_color", Color("382A16"))
	%Title.add_theme_constant_override("outline_size", 5)
	HubTheme.style_pill(%Connection, HubTheme.SECONDARY)
	HubTheme.style_pill(%Phase, HubTheme.INFO)
	HubTheme.style_pill(%Turn, HubTheme.SUCCESS)
	_create_leave_dialog()
	_pending_timer = Timer.new()
	_pending_timer.one_shot = true
	_pending_timer.wait_time = ACTION_TIMEOUT_SECONDS
	_pending_timer.timeout.connect(_on_action_timeout)
	add_child(_pending_timer)
	NetworkManager.notify_scene_ready()
	if not SessionState.public_state.is_empty():
		_on_public_snapshot(SessionState.public_state)
	if not SessionState.private_state.is_empty():
		_on_private_snapshot(SessionState.private_state)

func _polish_shared_layout() -> void:
	# Keep the three game screens on the same visual grid.  These overrides live
	# here instead of being copied into every scene, so future game modes inherit
	# the same spacing and information hierarchy.
	var main: VBoxContainer = get_node_or_null("Margin/Main") as VBoxContainer
	if is_instance_valid(main):
		main.add_theme_constant_override("separation", 12)
	var table: PanelContainer = get_node_or_null("Margin/Main/Table") as PanelContainer
	if is_instance_valid(table):
		HubTheme.style_table(table)
	var actions: HFlowContainer = get_node_or_null("Margin/Main/Actions") as HFlowContainer
	if is_instance_valid(actions):
		actions.add_theme_constant_override("h_separation", 10)
		actions.add_theme_constant_override("v_separation", 8)
	var banner: Label = get_node_or_null("Margin/Main/Banner") as Label
	if is_instance_valid(banner):
		HubTheme.style_status(banner)
	var hand_count: Label = get_node_or_null("Margin/Main/HandCount") as Label
	if is_instance_valid(hand_count):
		hand_count.add_theme_font_size_override("font_size", 18)
		hand_count.add_theme_color_override("font_color", HubTheme.GOLD)

func _connect_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)

func _on_public_snapshot(snapshot: Dictionary) -> void:
	public_snapshot = snapshot.duplicate(true)
	if selected_uid != -1 and not _selection_can_survive(selected_uid):
		selected_uid = -1
		%Selection.text = "Selecione uma carta"
		_refresh_hand_states()
	_render_header()
	_render_opponents()
	_render_table()
	_update_actions()
	var winner_value: Variant = snapshot.get("winner", -1)
	if typeof(winner_value) == TYPE_INT and int(winner_value) != -1:
		_show_message("Partida encerrada. Confira o resultado.")

func _on_private_snapshot(snapshot: Dictionary) -> void:
	selected_uid = -1
	%Selection.text = "Selecione uma carta"
	private_snapshot = snapshot.duplicate(true)
	cards_by_uid.clear()
	_clear_children(hand)
	var hand_value: Variant = snapshot.get("hand", [])
	if not hand_value is Array:
		_show_message("Não foi possível atualizar sua mão.")
		return
	for value: Variant in hand_value as Array:
		if not value is Dictionary:
			continue
		var card: Dictionary = (value as Dictionary).duplicate(true)
		var uid: int = int(card.get("uid", -1))
		cards_by_uid[uid] = card
		var visual: CardVisual = CARD_SCENE.instantiate() as CardVisual
		hand.add_child(visual)
		visual.configure(card, true)
		visual.set_state(false, true, true, pending_action != -1)
		visual.card_clicked.connect(_select_card)
	selected_uid = -1
	_refresh_hand_states()
	%HandCount.text = "%s na sua mão" % CardFormatter.cards(cards_by_uid.size())
	_update_actions()
	_render_header()
	_render_opponents()

func _render_header() -> void:
	var current_player: int = int(public_snapshot.get("current_player", -1))
	%Turn.text = "SUA VEZ" if current_player == SessionState.local_peer_id else "VEZ: %s" % _player_name(current_player).to_upper()
	%Connection.text = "TREINO" if SessionState.is_training else "LAN"
	%Phase.text = ("JOGADOR %d" % (SessionState.local_peer_id + 1)) if SessionState.is_training else _phase_text(int(public_snapshot.get("phase", 0))).to_upper()

func _render_opponents() -> void:
	_clear_children(opponents)
	var is_caxeta: bool = String(public_snapshot.get("game_id", "")) == "caxeta"
	var counts_value: Variant = public_snapshot.get("card_counts", {})
	var counts: Dictionary = counts_value as Dictionary if counts_value is Dictionary else {}
	for player: Dictionary in SessionState.players:
		var peer_id: int = int(player.get("peer_id", -1))
		if peer_id == SessionState.local_peer_id:
			continue
		var panel: VBoxContainer = VBoxContainer.new()
		panel.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_theme_constant_override("separation", 8 if is_caxeta else 4)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var name_label: Label = Label.new()
		var backs: HBoxContainer = HBoxContainer.new()
		backs.alignment = BoxContainer.ALIGNMENT_CENTER
		backs.add_theme_constant_override("separation", 10 if is_caxeta else -8)
		backs.tooltip_text = "Representação compacta da mão oculta"
		var back_parent: HBoxContainer = backs
		if is_caxeta:
			var cards_strip := HBoxContainer.new()
			cards_strip.alignment = BoxContainer.ALIGNMENT_CENTER
			cards_strip.add_theme_constant_override("separation", 7)
			backs.add_child(cards_strip)
			back_parent = cards_strip
		var count: int = int(counts.get(peer_id, 0))
		name_label.text = "%s · assento %d · %s" % [String(player.get("display_name", "Jogador")), int(player.get("seat", 0)) + 1, CardFormatter.cards(count)]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", HubTheme.MUTED)
		panel.add_child(name_label)
		for index: int in mini(count, 5):
			var back: CardVisual = CARD_SCENE.instantiate() as CardVisual
			back_parent.add_child(back)
			var back_data: Dictionary = {"game_id":String(public_snapshot.get("game_id", ""))}
			back.configure(back_data, false, CardVisual.DisplayMode.OPPONENT_BACK)
			back.set_state(false, false, false, false)
		var count_badge: Label = Label.new()
		count_badge.custom_minimum_size = Vector2(36.0, 0.0)
		count_badge.text = "×%d" % count
		count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_badge.add_theme_font_size_override("font_size", 16 if is_caxeta else 13)
		count_badge.add_theme_color_override("font_color", HubTheme.GOLD)
		count_badge.tooltip_text = "%s na mão oculta; são exibidas no máximo 5 miniaturas" % CardFormatter.cards(count)
		backs.add_child(count_badge)
		panel.add_child(backs)
		opponents.add_child(panel)

func _render_table() -> void:
	_clear_children(table_cards)
	_render_specific_table()

func _render_specific_table() -> void:
	pass

func _add_table_card(card: Dictionary, caption: String, face_up: bool = true, mode: CardVisual.DisplayMode = CardVisual.DisplayMode.HAND) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(label)
	var visual: CardVisual = CARD_SCENE.instantiate() as CardVisual
	group.add_child(visual)
	visual.configure(card, face_up, mode)
	visual.set_state(false, false, false, false)
	table_cards.add_child(group)

func _add_table_card_with_state(card: Dictionary, caption: String, winning: bool) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(label)
	var visual: CardVisual = CARD_SCENE.instantiate() as CardVisual
	group.add_child(visual)
	visual.configure(card, true)
	visual.set_state(false, false, false, false)
	visual.set_winning_card(winning)
	table_cards.add_child(group)

func _select_card(uid: int) -> void:
	if pending_action != -1:
		return
	selected_uid = -1 if selected_uid == uid else uid
	_refresh_hand_states()
	%Selection.text = "Selecione uma carta" if selected_uid == -1 else "Carta selecionada: %s" % _card_name(cards_by_uid.get(uid, {}) as Dictionary)
	_update_actions()

func submit(type: String, payload: Dictionary = {}) -> void:
	if pending_action != -1:
		return
	pending_action = NetworkManager.submit_action(type, payload)
	_set_pending(true)
	_pending_timer.start()
	_show_message("Aguardando confirmação do host…")

func submit_selected(type: String, extras: Dictionary = {}) -> void:
	if selected_uid == -1:
		_show_message("Selecione uma carta primeiro.")
		return
	var payload: Dictionary = extras.duplicate(true)
	payload["card_uid"] = selected_uid
	submit(type, payload)

func _on_action_answered(answer: Dictionary) -> void:
	if int(answer.get("client_action_id", -1)) != pending_action:
		return
	_pending_timer.stop()
	pending_action = -1
	_set_pending(false)
	if bool(answer.get("accepted", false)):
		selected_uid = -1
		_refresh_hand_states()
		_show_message("Carta jogada com sucesso.")
	else:
		_show_message(_friendly_error(String(answer.get("reason_code", ""))))

func _set_pending(_value: bool) -> void:
	_refresh_hand_states()
	_update_actions()

func _on_action_timeout() -> void:
	if pending_action == -1:
		return
	pending_action = -1
	_set_pending(false)
	_show_message("A confirmação da jogada demorou. Verifique a conexão e tente novamente.")

func _on_session_interrupted(reason: String) -> void:
	if is_instance_valid(_pending_timer):
		_pending_timer.stop()
	pending_action = -1
	_set_pending(false)
	_show_message(reason if not reason.is_empty() else "Conexão perdida. Voltando ao lobby…")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel") and selected_uid != -1 and pending_action == -1:
		selected_uid = -1
		_refresh_hand_states()
		%Selection.text = "Selecione uma carta"
		_update_actions()
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_accept"):
		var primary: BaseButton = _primary_action()
		if is_instance_valid(primary) and not primary.disabled and pending_action == -1:
			primary.pressed.emit()
			get_viewport().set_input_as_handled()

func _primary_action() -> BaseButton:
	return null

func _valid_selection_phases() -> Array[int]:
	return []

func _selection_can_survive(uid: int) -> bool:
	return ActionAvailability.selection_still_valid(cards_by_uid, uid, public_snapshot, SessionState.local_peer_id, _valid_selection_phases())

func _card_playable_hint(_card: Dictionary) -> bool:
	return false

func _refresh_hand_states() -> void:
	for child: Node in hand.get_children():
		if child is CardVisual:
			var visual: CardVisual = child as CardVisual
			var card: Dictionary = cards_by_uid.get(visual.card_uid, {}) as Dictionary
			visual.set_state(visual.card_uid == selected_uid, true, _card_playable_hint(card), pending_action != -1)

func _update_actions() -> void:
	pass

func _show_message(value: String) -> void:
	%Banner.text = value

func _friendly_error(code: String) -> String:
	return String(ERROR_MESSAGES.get(code, "A ação não pôde ser concluída."))

func _phase_text(phase: int) -> String:
	return "Fase %d" % phase

func _player_name(peer_id: int) -> String:
	for player: Dictionary in SessionState.players:
		if int(player.get("peer_id", -1)) == peer_id:
			return String(player.get("display_name", "Jogador"))
	return "outro jogador"

func _card_name(card: Dictionary) -> String:
	return CardFormatter.card_name(card)

func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()

func _leave() -> void:
	_leave_dialog.popup_centered(Vector2i(520, 180))

func _create_leave_dialog() -> void:
	_leave_dialog = ConfirmationDialog.new()
	_leave_dialog.title = "Sair do modo treino" if SessionState.is_training else ("Encerrar sala" if multiplayer.is_server() else "Sair da sala")
	_leave_dialog.dialog_text = "Deseja encerrar o treino e voltar ao menu principal?" if SessionState.is_training else ("Deseja encerrar a sala? Todos os jogadores voltarão ao menu principal." if multiplayer.is_server() else "Deseja sair da sala e voltar ao menu principal?")
	_leave_dialog.ok_button_text = "Sair do modo treino" if SessionState.is_training else ("Encerrar sala" if multiplayer.is_server() else "Sair da sala")
	_leave_dialog.cancel_button_text = "Cancelar"
	_leave_dialog.confirmed.connect(func() -> void:
		if is_instance_valid(_pending_timer):
			_pending_timer.stop()
		pending_action = -1
		selected_uid = -1
		NetworkManager.leave_session()
	)
	add_child(_leave_dialog)
