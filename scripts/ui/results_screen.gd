extends ScreenBase

func _ready() -> void:
	super()
	%Result.text = _result_summary(SessionState.public_state)
	%Back.pressed.connect(func() -> void: NetworkManager.return_to_lobby())
	%Close.pressed.connect(_close_room)
	%Back.visible = multiplayer.is_server()
	%Close.visible = multiplayer.is_server()

func _result_summary(snapshot: Dictionary) -> String:
	var winner: int = int(snapshot.get("winner", -1))
	var game_id: String = String(snapshot.get("game_id", SessionState.game_id))
	if winner == -1:
		return "Partida encerrada sem vencedor."
	if game_id == "truco":
		var team_name: String = "Equipe A" if winner == 0 else "Equipe B"
		var scores_value: Variant = snapshot.get("scores", [0, 0])
		var scores: Array = scores_value as Array if scores_value is Array else [0, 0]
		return "%s venceu!\nPlacar final: %d × %d" % [team_name, int(scores[0]), int(scores[1])]
	return "%s venceu a partida!\nObrigado por jogar." % _player_name(winner)

func _player_name(peer_id: int) -> String:
	for player: Dictionary in SessionState.players:
		if int(player.get("peer_id", -1)) == peer_id:
			return String(player.get("display_name", "Jogador"))
	return "Jogador"

func _close_room() -> void:
	NetworkManager.clean_session()
	SceneRouter.request_transition("menu")
