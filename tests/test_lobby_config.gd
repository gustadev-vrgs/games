class_name TestLobbyConfig
extends RefCounted

func run(t: TestHelpers) -> void:
	var uno: Dictionary = {"game_id":"uno", "max_players":8}
	t.equal(GameConstants.maximum_players_for(uno), 8, "Uno permite oito")
	t.check(GameConstants.player_count_valid("uno", 2, uno), "Uno aceita dois")
	t.check(GameConstants.player_count_valid("uno", 8, uno), "Uno aceita oito")
	t.check(not GameConstants.player_count_valid("uno", 9, uno), "Uno rejeita nove")
	t.equal(GameConstants.maximum_players_for({"game_id":"uno", "max_players":5}), 5, "limite do host é respeitado")
	t.equal(GameConstants.maximum_players_for({"game_id":"caxeta"}), 5, "Caxeta permanece em cinco")
	t.equal(GameConstants.maximum_players_for({"game_id":"truco", "truco_mode":"1v1"}), 2, "Truco 1v1 tem dois")
	t.equal(GameConstants.maximum_players_for({"game_id":"truco", "truco_mode":"2v2"}), 4, "Truco 2v2 tem quatro")
	var players: Array[Dictionary] = []
	for index: int in 4:
		players.append({"peer_id":index + 1,"display_name":"P%d" % index,"seat":index,"team":index % 2,"ready":true,"connected":true})
	t.equal(GameConstants.lobby_configuration_valid("truco", {"truco_mode":"2v2"}, players), "OK", "duplas completas iniciam")
	players[3].team = -1
	t.equal(GameConstants.lobby_configuration_valid("truco", {"truco_mode":"2v2"}, players), "TEAM_REQUIRED", "sem equipe não inicia")
	players[3].team = 1
	players[3].ready = false
	t.equal(GameConstants.lobby_configuration_valid("truco", {"truco_mode":"2v2"}, players), "PLAYER_NOT_READY", "não pronto impede início")
	t.equal(GameConstants.PROTOCOL_VERSION, 3, "protocolo v3 preservado")
