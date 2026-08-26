extends ScreenBase

func _ready() -> void:
	super()
	%Game.item_selected.connect(_game_changed)
	%TrucoMode.item_selected.connect(func(_index: int) -> void: _sync_limits())
	%Start.pressed.connect(_start)
	%Back.pressed.connect(func() -> void: SceneRouter.request_transition("menu"))
	_game_changed(0)

func _game_changed(_index: int) -> void:
	var game_id: String = _game_id()
	%CaxetaLives.visible = game_id == "caxeta"
	%LivesLabel.visible = game_id == "caxeta"
	%TrucoMode.visible = game_id == "truco"
	%TrucoLabel.visible = game_id == "truco"
	%Players.visible = game_id != "truco"
	%PlayersLabel.visible = game_id != "truco"
	_sync_limits()

func _sync_limits() -> void:
	if _game_id() == "uno":
		%Players.min_value = 2; %Players.max_value = 8
	elif _game_id() == "caxeta":
		%Players.min_value = 2; %Players.max_value = 5

func _game_id() -> String:
	return ["uno", "caxeta", "truco"][%Game.selected]

func _start() -> void:
	var game_id: String = _game_id()
	var settings: Dictionary = {"game_id": game_id}
	var count: int = int(%Players.value)
	if game_id == "uno": settings["max_players"] = count
	elif game_id == "caxeta": settings["lives"] = 7 if %CaxetaLives.selected == 0 else 10
	else:
		settings["truco_mode"] = "1v1" if %TrucoMode.selected == 0 else "2v2"
		count = 2 if settings.truco_mode == "1v1" else 4
	var result: String = NetworkManager.start_training(game_id, count, settings)
	if result != "OK": show_status("Configuração inválida: %s" % result)
