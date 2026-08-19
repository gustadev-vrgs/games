class_name ScreenBase
extends Control
@export var screen_title:String="Hub de Cartas"
@onready var title_label:Label=%Title
@onready var status_label:Label=%Status
func _ready()->void:title_label.text=screen_title
func show_status(message:String)->void:status_label.text=message
