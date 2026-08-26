extends ScreenBase

func _ready() -> void:
	super()
	%Back.pressed.connect(func() -> void: SceneRouter.request_transition("menu"))
	var colors: Array[Color] = [HubTheme.BLUE, HubTheme.SUCCESS, HubTheme.PURPLE, HubTheme.GOLD]
	var cards: Array[Node] = find_children("*Card", "PanelContainer", true, false)
	for index: int in cards.size(): HubTheme.style_card(cards[index], colors[index % colors.size()])
