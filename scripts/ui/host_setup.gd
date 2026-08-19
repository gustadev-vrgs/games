extends ScreenBase
func _ready()->void:super();%Create.pressed.connect(_create);%Back.pressed.connect(func()->void:SceneRouter.request_transition("menu"))
func _create()->void:
	var games:=["uno","caxeta","truco"];var game_id:String=games[%Game.selected];var result:=NetworkManager.create_server(SessionState.nickname,game_id,{"lives":%Lives.value},%Port.value)
	if result=="OK":SessionState.is_host=true;SessionState.game_id=game_id;SessionState.session_id=NetworkManager.session_id;SceneRouter.request_transition("lobby")
	else:show_status(result)
