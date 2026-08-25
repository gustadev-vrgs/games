class_name GameUI
extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/shared/card_visual.tscn")
const ERROR_MESSAGES: Dictionary = {
	"NOT_YOUR_TURN": "Aguarde sua vez.",
	"CARD_NOT_OWNED": "Essa carta não está mais na sua mão.",
	"CARD_NOT_PLAYABLE": "Essa carta não pode ser jogada agora.",
	"STALE_STATE": "O estado mudou. Tente novamente.",
	"INVALID_PHASE": "Essa ação não está disponível nesta fase.",
	"INVALID_COLOR": "Escolha uma cor válida.",
	"ILLEGAL_WILD_DRAW_FOUR": "O +4 só vale quando você não possui a cor ativa.",
	"MUST_DRAW_FIRST": "Compre uma carta antes de continuar.",
	"INVALID_KNOCK": "Sua mão ainda não forma combinações válidas.",
}

var pending_action: int = -1
var selected_uid: int = -1
var cards_by_uid: Dictionary = {}
var public_snapshot: Dictionary = {}

@onready var hand: HBoxContainer = %Hand
@onready var opponents: HBoxContainer = %Opponents
@onready var table_cards: HBoxContainer = %TableCards

func _ready() -> void:
	HubTheme.apply_to(self)
	_connect_once(NetworkManager.public_snapshot_received, _on_public_snapshot)
	_connect_once(NetworkManager.private_snapshot_received, _on_private_snapshot)
	_connect_once(NetworkManager.action_answered, _on_action_answered)
	_connect_once(NetworkManager.session_interrupted, _show_message)
	_connect_once(%Leave.pressed, _leave)
	NetworkManager.notify_scene_ready()
	if not SessionState.public_state.is_empty():
		_on_public_snapshot(SessionState.public_state)
	if not SessionState.private_state.is_empty():
		_on_private_snapshot(SessionState.private_state)

func _connect_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)

func _on_public_snapshot(snapshot: Dictionary) -> void:
	public_snapshot = snapshot.duplicate(true)
	_render_header()
	_render_opponents()
	_render_table()
	_update_actions()
	var winner_value: Variant = snapshot.get("winner", -1)
	if typeof(winner_value) == TYPE_INT and int(winner_value) != -1:
		_show_message("Partida encerrada. Confira o resultado.")

func _on_private_snapshot(snapshot: Dictionary) -> void:
	cards_by_uid.clear()
	selected_uid = -1
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
		visual.set_state(false, true, pending_action != -1)
		visual.card_clicked.connect(_select_card)
	%HandCount.text = "%d cartas na sua mão" % cards_by_uid.size()
	_update_actions()

func _render_header() -> void:
	var current_player: int = int(public_snapshot.get("current_player", -1))
	%Turn.text = "Sua vez" if current_player == SessionState.local_peer_id else "Vez de %s" % _player_name(current_player)
	%Connection.text = "● LAN conectada"
	%Phase.text = _phase_text(int(public_snapshot.get("phase", 0)))

func _render_opponents() -> void:
	_clear_children(opponents)
	var counts_value: Variant = public_snapshot.get("card_counts", {})
	var counts: Dictionary = counts_value as Dictionary if counts_value is Dictionary else {}
	for player: Dictionary in SessionState.players:
		var peer_id: int = int(player.get("peer_id", -1))
		if peer_id == SessionState.local_peer_id:
			continue
		var panel: VBoxContainer = VBoxContainer.new()
		panel.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_label: Label = Label.new()
		name_label.text = "%s · assento %d" % [String(player.get("display_name", "Jogador")), int(player.get("seat", 0)) + 1]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(name_label)
		var backs: HBoxContainer = HBoxContainer.new()
		backs.alignment = BoxContainer.ALIGNMENT_CENTER
		var count: int = int(counts.get(peer_id, 0))
		for index: int in mini(count, 5):
			var back: CardVisual = CARD_SCENE.instantiate() as CardVisual
			back.custom_minimum_size = Vector2(35.0, 50.0)
			backs.add_child(back)
			back.configure({}, false)
			back.playable = false
		panel.add_child(backs)
		var count_label: Label = Label.new()
		count_label.text = "%d carta(s)" % count
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(count_label)
		opponents.add_child(panel)

func _render_table() -> void:
	_clear_children(table_cards)
	_render_specific_table()

func _render_specific_table() -> void:
	pass

func _add_table_card(card: Dictionary, caption: String, face_up: bool = true) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(label)
	var visual: CardVisual = CARD_SCENE.instantiate() as CardVisual
	group.add_child(visual)
	visual.configure(card, face_up)
	visual.playable = false
	table_cards.add_child(group)

func _select_card(uid: int) -> void:
	if pending_action != -1:
		return
	selected_uid = uid
	for child: Node in hand.get_children():
		if child is CardVisual:
			var visual: CardVisual = child as CardVisual
			visual.set_state(visual.card_uid == uid, true, false)
	%Selection.text = "Carta selecionada: %s" % _card_name(cards_by_uid.get(uid, {}) as Dictionary)
	_update_actions()

func submit(type: String, payload: Dictionary = {}) -> void:
	if pending_action != -1:
		return
	pending_action = NetworkManager.submit_action(type, payload)
	_set_pending(true)
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
	pending_action = -1
	_set_pending(false)
	if bool(answer.get("accepted", false)):
		_show_message("Jogada confirmada.")
	else:
		_show_message(_friendly_error(String(answer.get("reason_code", ""))))

func _set_pending(value: bool) -> void:
	for child: Node in hand.get_children():
		if child is CardVisual:
			var visual: CardVisual = child as CardVisual
			visual.set_state(visual.card_uid == selected_uid, true, value)
	for button: Node in %Actions.get_children():
		if button is BaseButton:
			(button as BaseButton).disabled = value

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
	var action: String = String(card.get("action", ""))
	if not action.is_empty():
		return action.replace("_", " ")
	return "%s %s" % [String(card.get("rank", "")), String(card.get("suit", card.get("color", "")))]

func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()

func _leave() -> void:
	if multiplayer.is_server():
		NetworkManager.abort_match()
	else:
		NetworkManager.clean_session()
	SceneRouter.request_transition("lobby" if multiplayer.is_server() else "menu")
