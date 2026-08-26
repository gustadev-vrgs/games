extends ScreenBase

const ERROR_MESSAGES: Dictionary = {
	"TEAM_FULL": "Essa equipe está cheia.",
	"TEAM_REQUIRED": "Escolha uma equipe antes de ficar pronto.",
	"INVALID_TEAM": "Equipe inválida.",
	"TEAMS_UNBALANCED": "As equipes precisam ter a mesma quantidade de jogadores.",
	"WRONG_PLAYER_COUNT": "A quantidade de jogadores não atende ao modo escolhido.",
	"PLAYER_NOT_READY": "Aguardando todos ficarem prontos.",
	"LOBBY_LOCKED": "A organização da sala foi alterada ou já foi bloqueada.",
	"ROOM_FULL": "A sala atingiu o limite de jogadores.",
	"INVALID_TRUCO_MODE": "Modo de Truco inválido.",
}

func _ready() -> void:
	super()
	%Start.pressed.connect(_start)
	%Ready.pressed.connect(_toggle_ready)
	%TeamA.pressed.connect(func() -> void: _team(0))
	%TeamB.pressed.connect(func() -> void: _team(1))
	%LeaveTeam.pressed.connect(func() -> void: _team(-1))
	%Leave.pressed.connect(_leave)
	NetworkManager.lobby_updated.connect(_render)
	NetworkManager.connection_status.connect(_show_result)
	%Start.visible = multiplayer.is_server()
	%Leave.text = "Sair para o menu"
	%Leave.custom_minimum_size = Vector2(140.0, 40.0)
	_render(NetworkManager.players.values())

func _render(raw_players: Array) -> void:
	var players: Array[Dictionary] = []
	players.assign(raw_players)
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seat) < int(b.seat))
	var game_id: String = String(NetworkManager.config.get("game_id", SessionState.game_id))
	var maximum: int = GameConstants.maximum_players_for(NetworkManager.config)
	%Details.text = "%s\n%s de %d · vagas: %d\nPorta UDP: %s" % [game_id.to_upper(), CardFormatter.players(players.size()), maximum, maximum - players.size(), NetworkManager.config.get("port", 7000)]
	var lines: PackedStringArray = []
	for player: Dictionary in players:
		lines.append("%d. %s%s · %s · %s" % [int(player.seat) + 1, String(player.display_name), " (host)" if int(player.peer_id) == 1 else "", "Pronto" if bool(player.ready) else "Não pronto", "Conectado" if bool(player.connected) else "Desconectado"])
	%Players.text = "\n".join(lines)
	%Teams.visible = game_id == "truco"
	if game_id == "truco":
		_render_teams(players)
	var local: Dictionary = _local_player(players)
	%Ready.text = "Cancelar pronto" if bool(local.get("ready", false)) else "Estou pronto"
	%Ready.disabled = local.is_empty() or (game_id == "truco" and int(local.get("team", -1)) == -1)
	var validation: String = GameConstants.lobby_configuration_valid(game_id, NetworkManager.config, players)
	%Start.disabled = validation != "OK"
	%Status.text = "Configuração pronta para iniciar." if validation == "OK" else _friendly(validation)

func _render_teams(players: Array[Dictionary]) -> void:
	var teams: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray()]
	var unassigned: PackedStringArray = []
	var capacity: int = 1 if String(NetworkManager.config.get("truco_mode", "2v2")) == "1v1" else 2
	for player: Dictionary in players:
		var label: String = "%s%s%s" % [String(player.display_name), " (host)" if int(player.peer_id) == 1 else "", " · Pronto" if bool(player.ready) else ""]
		var team: int = int(player.team)
		if team in [0, 1]:
			teams[team].append(label)
		else:
			unassigned.append(label)
	for team: int in 2:
		while teams[team].size() < capacity:
			teams[team].append("— vaga livre —")
	%TeamAList.text = "\n".join(teams[0])
	%TeamBList.text = "\n".join(teams[1])
	%Unassigned.text = "Sem equipe: %s" % (", ".join(unassigned) if not unassigned.is_empty() else "ninguém")

func _local_player(players: Array[Dictionary]) -> Dictionary:
	for player: Dictionary in players:
		if int(player.peer_id) == SessionState.local_peer_id:
			return player
	return {}

func _friendly(code: String) -> String:
	return String(ERROR_MESSAGES.get(code, code))

func _show_result(result: String) -> void:
	if result not in ["OK", "PENDING"]:
		show_status(_friendly(result))

func _team(team: int) -> void:
	_show_result(NetworkManager.request_team_change(team))

func _toggle_ready() -> void:
	var local: Dictionary = _local_player(SessionState.players)
	_show_result(NetworkManager.request_lobby_ready(not bool(local.get("ready", false))))

func _start() -> void:
	_show_result(NetworkManager.request_start())

func _leave() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "Deseja encerrar a sala? Todos os jogadores voltarão ao menu principal." if multiplayer.is_server() else "Deseja sair da sala e voltar ao menu principal?"
	dialog.ok_button_text = "Encerrar sala" if multiplayer.is_server() else "Sair da sala"
	dialog.confirmed.connect(NetworkManager.leave_session)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 180))
