extends ScreenBase
@onready var nickname:LineEdit=%Nickname
func _ready()->void:
	super();%Host.pressed.connect(_host);%Join.pressed.connect(_join);%Quit.pressed.connect(func()->void:get_tree().quit())
func _save()->bool:
	var clean:=GameConstants.sanitize_nickname(nickname.text)
	if clean.is_empty():show_status("Informe um apelido.");return false
	SessionState.nickname=clean;return true
func _host()->void:if _save():SceneRouter.request_transition("host")
func _join()->void:if _save():SceneRouter.request_transition("join")
