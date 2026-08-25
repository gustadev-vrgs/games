extends ScreenBase
func _ready()->void:super();%Create.pressed.connect(_create);%Back.pressed.connect(func()->void:SceneRouter.request_transition("menu"))
func _create()->void:
	var games: PackedStringArray = ["uno", "caxeta", "truco"]
	var selected_index: int = %Game.selected
	if selected_index < 0 or selected_index >= games.size():
		show_status("INVALID_CONFIG")
		return
	var game_id: String = games[selected_index]
	var lives: int = int(%Lives.value)
	var port: int = int(%Port.value)
	var settings: Dictionary = {"lives": lives}
	var result: String = NetworkManager.create_server(SessionState.nickname, game_id, settings, port)
	if result=="OK":SessionState.is_host=true;SessionState.game_id=game_id;SessionState.session_id=NetworkManager.session_id;SceneRouter.request_transition("lobby")
	else:show_status(result)
