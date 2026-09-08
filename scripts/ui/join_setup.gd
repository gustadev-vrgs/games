extends ScreenBase

const ERROR_MESSAGES: Dictionary = {
	"INVALID_CONFIG": "Informe um endereço válido para a partida.",
	"CLIENT_CREATE_FAILED": "Não foi possível conectar à partida.",
	"PROTOCOL_MISMATCH": "A versão da partida é incompatível.",
	"MATCH_ALREADY_STARTED": "A partida já começou.",
	"ROOM_FULL": "A sala está cheia.",
}

func _ready()->void:
	super();%Connect.pressed.connect(_connect);%Back.pressed.connect(_cancel);NetworkManager.connection_status.connect(_show_network_status)
	HubTheme.style_action(%Connect, HubTheme.SUCCESS); HubTheme.style_card(%ConnectionSection, HubTheme.SUCCESS); HubTheme.style_muted(%Hint)
func _connect()->void:
	var address: String = %Address.text
	var port: int = int(%Port.value)
	var result: String = NetworkManager.create_client(SessionState.nickname, address, port)
	if result == "OK":
		show_status("Conectando...")
	else:
		_show_network_status(result)

func _show_network_status(status: String) -> void:
	show_status(String(ERROR_MESSAGES.get(status, status)))
func _cancel()->void:NetworkManager.clean_session();SceneRouter.request_transition("menu")
