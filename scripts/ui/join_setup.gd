extends ScreenBase
func _ready()->void:
	super();%Connect.pressed.connect(_connect);%Back.pressed.connect(_cancel);NetworkManager.connection_status.connect(show_status)
	HubTheme.style_action(%Connect, HubTheme.SUCCESS); HubTheme.style_card(%ConnectionSection, HubTheme.SUCCESS); HubTheme.style_muted(%Hint)
func _connect()->void:
	var address: String = %Address.text
	var port: int = int(%Port.value)
	var result: String = NetworkManager.create_client(SessionState.nickname, address, port)
	show_status(result)
func _cancel()->void:NetworkManager.clean_session();SceneRouter.request_transition("menu")
