class_name CardVisual
extends Button
signal card_clicked(card_uid:int)
var card_uid:=-1;var face_up:=true;var selected:=false;var playable:=true;var pending:=false
func _ready()->void:pressed.connect(_clicked)
func configure(card:Dictionary,up:bool=true)->void:
	card_uid=card.get("uid",-1);face_up=up;text=_label(card) if up else "🂠";tooltip_text=text;_refresh()
func set_state(new_selected:bool,new_playable:bool,new_pending:bool)->void:selected=new_selected;playable=new_playable;pending=new_pending;_refresh()
func _label(card:Dictionary)->String:return "%s\n%s"%[card.get("action",card.get("rank","?")),card.get("color",card.get("suit",""))]
func _refresh()->void:disabled=not playable or pending;modulate=Color(1.15,1.15,0.7) if selected else (Color(0.65,0.65,0.65) if disabled else Color.WHITE)
func _clicked()->void:if not disabled:card_clicked.emit(card_uid)
