extends ScreenBase

func _ready() -> void:
	super()
	%Game.item_selected.connect(_game_changed)
	%Players.value_changed.connect(func(_value: float) -> void: _update_start_state())
	%CaxetaLives.item_selected.connect(func(_index: int) -> void: _update_start_state())
	%TrucoMode.item_selected.connect(func(_index: int) -> void: _update_start_state())
	%Start.pressed.connect(_start_training)
	%Back.pressed.connect(func() -> void: SceneRouter.request_transition("menu"))
	%Game.select(0)
	_reset_game_specific_options()
	_game_changed(0)
	HubTheme.style_action(%Start, HubTheme.PURPLE); HubTheme.style_card(%GameSection, HubTheme.INFO); HubTheme.style_card(%OptionsSection, HubTheme.SECONDARY); HubTheme.style_muted(%Intro)

func _game_changed(_index: int) -> void:
	var game_id: String = _game_id()
	_reset_game_specific_options()
	%OptionsSection.visible = not game_id.is_empty()
	%CaxetaLives.visible = game_id == "caxeta"
	%LivesLabel.visible = game_id == "caxeta"
	%TrucoMode.visible = game_id == "truco"
	%TrucoLabel.visible = game_id == "truco"
	%Players.visible = game_id in ["uno", "caxeta"]
	%PlayersLabel.visible = game_id in ["uno", "caxeta"]
	_sync_limits()
	_update_start_state()

func _reset_game_specific_options() -> void:
	%Players.value = 2
	%CaxetaLives.select(0)
	%TrucoMode.select(0)

func _sync_limits() -> void:
	if _game_id() == "uno":
		%Players.min_value = 2; %Players.max_value = 8
	elif _game_id() == "caxeta":
		%Players.min_value = 2; %Players.max_value = 5

func _game_id() -> String:
	return ["", "uno", "caxeta", "truco"][%Game.selected]

func _can_start_training() -> bool:
	var game_id: String = _game_id()
	if game_id.is_empty():
		return false
	if game_id == "uno":
		return GameConstants.player_count_valid(game_id, int(%Players.value), {"game_id": game_id, "max_players": int(%Players.value)})
	if game_id == "caxeta":
		return GameConstants.player_count_valid(game_id, int(%Players.value), {"game_id": game_id}) and %CaxetaLives.selected in [1, 2]
	if game_id == "truco":
		return %TrucoMode.selected in [1, 2]
	return false

func _validation_message() -> String:
	match _game_id():
		"": return "Selecione um jogo para continuar."
		"caxeta": return "Pronto para iniciar." if _can_start_training() else "Escolha jogadores e vidas."
		"truco": return "Pronto para iniciar." if _can_start_training() else "Escolha o formato da partida."
		"uno": return "Pronto para iniciar." if _can_start_training() else "Escolha uma quantidade válida de jogadores."
	return "Selecione um jogo para continuar."

func _update_start_state() -> void:
	%Start.disabled = not _can_start_training()
	%Status.text = _validation_message()

func _start_training() -> void:
	if not _can_start_training():
		show_status(_validation_message())
		_update_start_state()
		return
	var game_id: String = _game_id()
	var settings: Dictionary = {"game_id": game_id}
	var count: int = int(%Players.value)
	if game_id == "uno": settings["max_players"] = count
	elif game_id == "caxeta": settings["lives"] = 7 if %CaxetaLives.selected == 1 else 10
	else:
		settings["truco_mode"] = "1v1" if %TrucoMode.selected == 1 else "2v2"
		count = 2 if settings.truco_mode == "1v1" else 4
	var result: String = NetworkManager.start_training(game_id, count, settings)
	if result != "OK": show_status("Configuração inválida: %s" % result)
