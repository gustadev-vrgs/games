extends ScreenBase
func _ready()->void:
	super();%Connect.pressed.connect(_connect);%Back.pressed.connect(_cancel);NetworkManager.connection_status.connect(show_status)
func _connect()->void:show_status(NetworkManager.create_client(SessionState.nickname,%Address.text,%Port.value))
func _cancel()->void:NetworkManager.clean_session();SceneRouter.request_transition("menu")
