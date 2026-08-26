extends ScreenBase

func _ready() -> void:
	super()
	%Create.pressed.connect(_create)
	%Back.pressed.connect(func() -> void: SceneRouter.request_transition("menu"))
	%Game.item_selected.connect(_game_changed)
	_game_changed(%Game.selected)
	HubTheme.style_action(%Create, HubTheme.BLUE)
	HubTheme.style_card(%GameSection, HubTheme.INFO); HubTheme.style_card(%SettingsSection, HubTheme.SECONDARY); HubTheme.style_card(%ConnectionSection, HubTheme.GOLD)

func _game_changed(index: int) -> void:
	%UnoMaximum.visible = index == 0
	%UnoMaximumLabel.visible = index == 0
	%Lives.visible = index == 1
	%LivesLabel.visible = index == 1
	%TrucoMode.visible = index == 2
	%TrucoModeLabel.visible = index == 2

func _create() -> void:
	var games: PackedStringArray = ["uno", "caxeta", "truco"]
	var selected_index: int = %Game.selected
	if selected_index < 0 or selected_index >= games.size():
		show_status("INVALID_CONFIG")
		return
	var game_id: String = games[selected_index]
	var settings: Dictionary = {"lives": int(%Lives.value)}
	if game_id == "uno":
		settings["max_players"] = int(%UnoMaximum.value)
	if game_id == "truco":
		settings["truco_mode"] = "2v2" if %TrucoMode.selected == 0 else "1v1"
	var result: String = NetworkManager.create_server(SessionState.nickname, game_id, settings, int(%Port.value))
	if result == "OK":
		SessionState.is_host = true
		SessionState.game_id = game_id
		SessionState.session_id = NetworkManager.session_id
		SceneRouter.request_transition("lobby")
	else:
		show_status(result)
