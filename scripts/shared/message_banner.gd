class_name MessageBanner
extends PanelContainer
func show_message(message:String)->void:%Message.text=message;visible=true
func clear()->void:visible=false
