class_name ScreenBase
extends Control
@export var screen_title:String="Hub de Cartas"
@onready var title_label:Label=%Title
@onready var status_label:Label=%Status
func _ready()->void:
	HubTheme.apply_to(self)
	title_label.text=screen_title
	HubTheme.style_title(title_label)
	for button: Button in find_children("*", "Button", true, false):
		button.mouse_entered.connect(_animate_button.bind(button, Vector2(1.025, 1.025)))
		button.mouse_exited.connect(_animate_button.bind(button, Vector2.ONE))
		button.button_down.connect(_animate_button.bind(button, Vector2(0.98, 0.98)))
		button.button_up.connect(_animate_button.bind(button, Vector2.ONE))
func show_status(message:String)->void:status_label.text=message

func _animate_button(button: Button, target: Vector2) -> void:
	button.pivot_offset = button.size * 0.5
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(button, "scale", target, 0.1)
