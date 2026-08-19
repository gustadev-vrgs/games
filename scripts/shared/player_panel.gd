class_name PlayerPanel
extends PanelContainer
func render(player:Dictionary,count:int,current:bool)->void:%Name.text=player.get("display_name","Jogador");%Count.text="%d cartas"%count;modulate=Color(1,1,0.7) if current else Color.WHITE
