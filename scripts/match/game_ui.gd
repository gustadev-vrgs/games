class_name GameUI
extends Control
var pending_action:int=-1
var cards_by_uid:Dictionary={}
@onready var hand:HBoxContainer=%Hand
func _ready()->void:
	NetworkManager.public_snapshot_received.connect(_public);NetworkManager.private_snapshot_received.connect(_private);NetworkManager.action_answered.connect(_answer);NetworkManager.session_interrupted.connect(_message);%Leave.pressed.connect(_leave);NetworkManager.notify_scene_ready()
	if not SessionState.public_state.is_empty():_public(SessionState.public_state)
	if not SessionState.private_state.is_empty():_private(SessionState.private_state)
func _public(snapshot:Dictionary)->void:%Info.text=str(snapshot);if snapshot.get("winner",-1)!=-1:%Banner.text="Partida encerrada — vencedor: %s"%snapshot.winner
func _private(snapshot:Dictionary)->void:
	cards_by_uid.clear()
	for child in hand.get_children():child.queue_free()
	for card in snapshot.get("hand",[]):
		cards_by_uid[card.uid]=card
		var visual:CardVisual=preload("res://scenes/shared/card_visual.tscn").instantiate() as CardVisual;hand.add_child(visual);visual.configure(card);visual.card_clicked.connect(_card)
func _card(uid:int)->void:
	if pending_action!=-1:return
	var card:Dictionary=cards_by_uid.get(uid,{})
	var game:String=SessionState.game_id
	var type:String="PLAY_CARD"
	var payload:Dictionary={"card_uid":uid}
	if game=="uno":
		payload.declared_uno=%DeclareUno.button_pressed
		payload.chosen_color=%Color.get_item_text(%Color.selected) if card.get("action","") in ["wild","wild_draw_four"] else ""
	elif game=="caxeta":
		type="DISCARD";payload.declare_knock=%KnockNormal.button_pressed
	pending_action=NetworkManager.submit_action(type,payload)
func send(type:String)->void:if pending_action==-1:pending_action=NetworkManager.submit_action(type)
func _answer(answer:Dictionary)->void:
	if answer.client_action_id!=pending_action:return
	pending_action=-1;if not answer.accepted:_message(answer.reason_code)
func _message(value:String)->void:%Banner.text=value
func _leave()->void:NetworkManager.abort_match() if multiplayer.is_server() else NetworkManager.clean_session();SceneRouter.request_transition("lobby" if multiplayer.is_server() else "menu")
