extends ScreenBase
@onready var nickname:LineEdit=%Nickname
func _ready()->void:
	super();%Host.pressed.connect(_host);%Join.pressed.connect(_join);%Training.pressed.connect(func()->void:SceneRouter.request_transition("training"));%Help.pressed.connect(func()->void:SceneRouter.request_transition("help"));%Quit.pressed.connect(func()->void:get_tree().quit())
	HubTheme.style_action(%Host, HubTheme.BLUE); HubTheme.style_action(%Join, HubTheme.SUCCESS)
	HubTheme.style_action(%Training, HubTheme.PURPLE); HubTheme.style_action(%Help, HubTheme.GOLD.darkened(0.12)); HubTheme.style_exit(%Quit)
	HubTheme.style_muted(%Subtitle); HubTheme.style_muted(%Version)
func _save()->bool:
	var clean:String=GameConstants.sanitize_nickname(nickname.text)
	if clean.is_empty():show_status("Informe um apelido.");return false
	SessionState.nickname=clean;return true
func _host()->void:if _save():SceneRouter.request_transition("host")
func _join()->void:if _save():SceneRouter.request_transition("join")
