extends ScreenBase
func _ready()->void:
	super();%Start.pressed.connect(_start);%Leave.pressed.connect(_leave);NetworkManager.lobby_updated.connect(_render);_render(NetworkManager.players.values())
	%Start.visible=multiplayer.is_server();%Details.text="Jogo: %s | Porta UDP: %s\nIPs LAN: %s"%[NetworkManager.config.get("game_id",SessionState.game_id),NetworkManager.config.get("port",7000),", ".join(NetworkManager.get_lan_addresses())]
	%Leave.text = "Encerrar sala" if multiplayer.is_server() else "Sair da sala"
func _render(players:Array)->void:
	%Players.text="\n".join(players.map(func(player:Dictionary)->String:return "%d. %s%s"%[player.seat+1,player.display_name," (host)" if player.peer_id==1 else ""]))
func _start()->void:show_status(NetworkManager.request_start())
func _leave()->void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "Deseja encerrar a sala? Todos os jogadores serão desconectados." if multiplayer.is_server() else "Deseja sair da sala? A partida atual será interrompida."
	dialog.ok_button_text = "Encerrar sala" if multiplayer.is_server() else "Sair da sala"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(func() -> void:
		if multiplayer.is_server():
			NetworkManager.close_room()
		else:
			NetworkManager.leave_room()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 180))
