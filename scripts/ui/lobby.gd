extends ScreenBase
func _ready()->void:
	super();%Start.pressed.connect(_start);%Leave.pressed.connect(_leave);NetworkManager.lobby_updated.connect(_render);_render(NetworkManager.players.values())
	%Start.visible=multiplayer.is_server();%Details.text="Jogo: %s | Porta UDP: %s\nIPs LAN: %s"%[NetworkManager.config.get("game_id",SessionState.game_id),NetworkManager.config.get("port",7000),", ".join(NetworkManager.get_lan_addresses())]
func _render(players:Array)->void:
	%Players.text="\n".join(players.map(func(player:Dictionary)->String:return "%d. %s%s"%[player.seat+1,player.display_name," (host)" if player.peer_id==1 else ""]))
func _start()->void:show_status(NetworkManager.request_start())
func _leave()->void:NetworkManager.clean_session();SceneRouter.request_transition("menu")
