extends ScreenBase

func _ready() -> void:
	super()
	%Back.pressed.connect(func() -> void: SceneRouter.request_transition("menu"))
