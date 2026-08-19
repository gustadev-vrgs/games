extends ScreenBase
func _ready()->void:
	super();%Result.text="Vencedor: %s\n%s"%[SessionState.public_state.get("winner","—"),str(SessionState.public_state)];%Back.pressed.connect(func()->void:NetworkManager.return_to_lobby());%Close.pressed.connect(func()->void:NetworkManager.clean_session();SceneRouter.request_transition("menu"));%Back.visible=multiplayer.is_server()
