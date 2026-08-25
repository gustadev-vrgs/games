extends GameUI

func _ready() -> void:
	super()
	%Play.pressed.connect(_play)
	%Draw.pressed.connect(func() -> void: submit("DRAW_ONE"))
	%Pass.pressed.connect(func() -> void: submit("PASS"))

func _render_specific_table() -> void:
	_add_table_card({}, "Compra · %d" % int(public_snapshot.get("draw_count", 0)), false)
	var top_value: Variant = public_snapshot.get("top_card", {})
	if top_value is Dictionary:
		_add_table_card(top_value as Dictionary, "Descarte")
	var direction: int = int(public_snapshot.get("direction", 1))
	%GameDetail.text = "Cor ativa: %s   ·   Direção: %s" % [String(public_snapshot.get("active_color", "—")).capitalize(), "horária" if direction == 1 else "anti-horária"]

func _play() -> void:
	var card: Dictionary = cards_by_uid.get(selected_uid, {}) as Dictionary
	var action: String = String(card.get("action", ""))
	var payload: Dictionary = {"declared_uno": %DeclareUno.button_pressed}
	if action in ["wild", "wild_draw_four"]:
		payload["chosen_color"] = String(%Color.get_item_metadata(%Color.selected))
	submit_selected("PLAY_CARD", payload)

func _update_actions() -> void:
	if not is_node_ready():
		return
	%Play.disabled = selected_uid == -1 or pending_action != -1
	%Pass.disabled = pending_action != -1
	%Draw.disabled = pending_action != -1

func _phase_text(phase: int) -> String:
	return ["Distribuindo", "Jogando", "Carta comprada: jogue ou passe", "Resolvendo efeito", "Encerrada"][clampi(phase, 0, 4)]
