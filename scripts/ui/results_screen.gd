extends ScreenBase

var _game_dialog: ConfirmationDialog

func _ready() -> void:
	super()
	var snapshot: Dictionary = SessionState.public_state
	%Mode.text = _mode_name(String(snapshot.get("game_id", SessionState.game_id)))
	%Result.text = _result_summary(snapshot)
	_configure_result_style(snapshot)
	if SessionState.is_training:
		%Back.pressed.connect(NetworkManager.replay_training)
	else:
		%Back.pressed.connect(_replay_match)
	%ChangeGame.pressed.connect(_show_game_picker)
	%Close.pressed.connect(_close_room)
	var is_host: bool = SessionState.is_host and multiplayer.is_server()
	%Back.visible = is_host or SessionState.is_training
	%ChangeGame.visible = is_host and not SessionState.is_training
	%Back.text = "Jogar novamente"
	%Back.tooltip_text = "Inicia outra partida com os participantes conectados."
	%Close.visible = not SessionState.session_id.is_empty() or SessionState.is_training
	%Close.text = "Voltar ao menu"
	%Status.text = "Escolha o próximo passo para a sala." if is_host else "Aguardando o host decidir o próximo jogo..."
	HubTheme.style_action(%ChangeGame, HubTheme.BLUE)
	_create_game_dialog()
	_animate_entrance()

func _replay_match() -> void:
	_show_start_result(NetworkManager.restart_match())

func _create_game_dialog() -> void:
	_game_dialog = ConfirmationDialog.new()
	_game_dialog.title = "Escolha o próximo jogo"
	_game_dialog.dialog_text = "O grupo permanecerá conectado na mesma sala."
	_game_dialog.ok_button_text = "Cancelar"
	_game_dialog.get_ok_button().pressed.connect(_game_dialog.hide)
	for game: Dictionary in [{"id":"uno", "label":"UNO"}, {"id":"truco", "label":"Truco"}, {"id":"caxeta", "label":"Caxeta"}]:
		var button: Button = _game_dialog.add_button(String(game.label), false, String(game.id))
		button.pressed.connect(_choose_game.bind(String(game.id)))
	add_child(_game_dialog)

func _choose_game(game_id: String) -> void:
	_game_dialog.hide()
	_show_start_result(NetworkManager.change_game(game_id))

func _show_game_picker() -> void:
	if SessionState.is_host and multiplayer.is_server():
		_game_dialog.popup_centered(Vector2i(540, 260))

func _show_start_result(result: String) -> void:
	if result != "OK":
		var message: String = String({
			"WRONG_PLAYER_COUNT":"não há jogadores suficientes para esse modo.",
			"NOT_HOST":"somente o host pode decidir o próximo jogo.",
			"INVALID_PHASE":"a decisão já foi processada.",
		}.get(result, result))
		%Status.text = "Não foi possível iniciar: %s" % message

func _result_summary(snapshot: Dictionary) -> String:
	var winner: int = int(snapshot.get("winner", -1))
	var game_id: String = String(snapshot.get("game_id", SessionState.game_id))
	if winner == -1:
		%Title.text = "PARTIDA ENCERRADA"
		return "A partida terminou sem vencedor."
	if game_id == "truco":
		var team_name: String = "Equipe A" if winner == 0 else "Equipe B"
		var scores_value: Variant = snapshot.get("scores", [0, 0])
		var scores: Array = scores_value as Array if scores_value is Array else [0, 0]
		var names: String = _truco_team_names(snapshot, winner)
		%Title.text = "SUA DUPLA VENCEU!" if _local_truco_team(snapshot) == winner else "DUPLA VENCEDORA"
		return "%s\n%s\nPlacar final  %d × %d" % [names if not names.is_empty() else team_name, team_name, int(scores[0]), int(scores[1])]
	if winner == SessionState.local_peer_id:
		%Title.text = "VOCÊ VENCEU!"
		return "Parabéns!\nUma partida memorável."
	%Title.text = "%s VENCEU!" % _player_name(winner).to_upper()
	return "%s venceu a partida.\nObrigado por jogar!" % _player_name(winner)

func _mode_name(game_id: String) -> String:
	return String({"uno": "UNO", "truco": "TRUCO", "caxeta": "CAXETA"}.get(game_id, "JOGO"))

func _local_truco_team(snapshot: Dictionary) -> int:
	var mapping_value: Variant = snapshot.get("team_by_peer", {})
	return int((mapping_value as Dictionary).get(SessionState.local_peer_id, -1)) if mapping_value is Dictionary else -1

func _truco_team_names(snapshot: Dictionary, winner: int) -> String:
	var members_value: Variant = snapshot.get("team_members", {})
	if not members_value is Dictionary:
		return ""
	var names: PackedStringArray = PackedStringArray()
	for peer_value: Variant in (members_value as Dictionary).get(winner, []) as Array:
		names.append(_player_name(int(peer_value)))
	return " e ".join(names)

func _configure_result_style(snapshot: Dictionary) -> void:
	var winner: int = int(snapshot.get("winner", -1))
	var local_won: bool = winner == SessionState.local_peer_id
	if String(snapshot.get("game_id", "")) == "truco":
		local_won = winner == _local_truco_team(snapshot)
	%Trophy.text = "★" if local_won else "◆"
	%Trophy.add_theme_color_override("font_color", HubTheme.GOLD if local_won else HubTheme.SECONDARY)
	HubTheme.style_title(%Title)
	HubTheme.style_action(%Back, HubTheme.SUCCESS)
	HubTheme.style_exit(%Close)

func _animate_entrance() -> void:
	%VictoryPanel.modulate = Color(1, 1, 1, 0)
	%VictoryPanel.scale = Vector2(0.9, 0.9)
	%VictoryPanel.pivot_offset = %VictoryPanel.size * 0.5
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(%VictoryPanel, "modulate", Color.WHITE, 0.28)
	tween.tween_property(%VictoryPanel, "scale", Vector2.ONE, 0.36)

func _player_name(peer_id: int) -> String:
	for player: Dictionary in SessionState.players:
		if int(player.get("peer_id", -1)) == peer_id:
			return String(player.get("display_name", "Jogador"))
	return "Jogador"

func _close_room() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "Deseja sair e voltar ao menu principal?"
	dialog.ok_button_text = "Voltar ao menu"
	dialog.confirmed.connect(NetworkManager.leave_session)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 180))
