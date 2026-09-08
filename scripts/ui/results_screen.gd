extends ScreenBase

func _ready() -> void:
	super()
	var snapshot: Dictionary = SessionState.public_state
	%Mode.text = _mode_name(String(snapshot.get("game_id", SessionState.game_id)))
	%Result.text = _result_summary(snapshot)
	_configure_result_style(snapshot)
	if SessionState.is_training:
		%Back.pressed.connect(NetworkManager.replay_training)
	else:
		%Back.pressed.connect(func() -> void: NetworkManager.return_to_lobby())
	%Close.pressed.connect(_close_room)
	%Back.visible = multiplayer.is_server() or SessionState.is_training
	%Back.text = "Jogar novamente"
	%Back.tooltip_text = "Volta ao lobby com os mesmos participantes para iniciar outra partida."
	%Close.visible = not SessionState.session_id.is_empty() or SessionState.is_training
	%Close.text = "Voltar ao menu"
	_animate_entrance()

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
