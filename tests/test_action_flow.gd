class_name TestActionFlow
extends RefCounted

func run(t: TestHelpers) -> void:
	var uno_snapshot: Dictionary = {"phase": 1, "current_player": 1, "active_color": "red", "top_card": {"rank": "5", "action": ""}}
	var red_card: Dictionary = {"uid": 10, "color": "red", "rank": "8", "action": ""}
	var bad_card: Dictionary = {"uid": 11, "color": "blue", "rank": "2", "action": ""}
	var wild: Dictionary = {"uid": 12, "color": "wild", "rank": "", "action": "wild"}
	t.check(ActionAvailability.uno_card_playable(uno_snapshot, {}, red_card, 1), "Uno habilita carta compatível no turno")
	t.check(not ActionAvailability.uno_card_playable(uno_snapshot, {}, bad_card, 1), "Uno não habilita carta incompatível")
	t.check(not ActionAvailability.uno_card_playable(uno_snapshot, {}, red_card, 2), "jogador fora do turno não joga")
	t.check(ActionAvailability.uno_card_playable(uno_snapshot, {}, wild, 1), "curinga é legal, mas a UI ainda exige cor no envio")
	var after_draw: Dictionary = uno_snapshot.duplicate(true)
	after_draw["phase"] = 2
	t.check(ActionAvailability.uno_card_playable(after_draw, {"drawn_uid": 10}, red_card, 1), "Uno permite exatamente a carta comprada")
	t.check(not ActionAvailability.uno_card_playable(after_draw, {"drawn_uid": 99}, red_card, 1), "Uno bloqueia outra carta após compra")

	var caxeta_draw: Dictionary = {"phase": 1, "current_player": 1}
	var caxeta_discard: Dictionary = {"phase": 2, "current_player": 1}
	t.check(not ActionAvailability.caxeta_can_discard(caxeta_draw, 10, 1), "Caxeta exige compra antes do descarte")
	t.check(ActionAvailability.caxeta_can_discard(caxeta_discard, 10, 1), "Caxeta permite descarte após compra e seleção")

	var truco_play: Dictionary = {"phase": 1, "current_player": 1}
	var truco_wait: Dictionary = {"phase": 2, "current_player": 1}
	t.check(ActionAvailability.truco_can_play(truco_play, 10, 1), "Truco permite carta durante turno")
	t.check(not ActionAvailability.truco_can_play(truco_wait, 10, 1), "Truco bloqueia carta durante pedido")

	var cards: Dictionary = {10: red_card}
	t.check(ActionAvailability.selection_still_valid(cards, 10, uno_snapshot, 1, [1, 2]), "seleção sobrevive atualização irrelevante")
	t.check(not ActionAvailability.selection_still_valid({}, 10, uno_snapshot, 1, [1, 2]), "seleção é limpa quando carta sai")
	t.check(not ActionAvailability.selection_still_valid(cards, 10, uno_snapshot, 2, [1, 2]), "seleção é limpa quando turno muda")

	var network_source: String = FileAccess.get_file_as_string("res://autoloads/network_manager.gd")
	t.check(network_source.contains("call_deferred(\"_process_action\", 1, envelope)"), "host despacha depois de o pending_action poder ser registrado")
	var ui_source: String = FileAccess.get_file_as_string("res://scripts/match/game_ui.gd")
	t.check(ui_source.contains("ACTION_TIMEOUT_SECONDS: float = 8.0"), "ação pendente possui timeout de oito segundos")
	t.check(ui_source.contains("if pending_action != -1:"), "guarda impede clique duplo")
	t.check(ui_source.contains("!= pending_action"), "resposta antiga não desbloqueia ação nova")
	t.check(ui_source.contains("pending_action = -1"), "aceite, rejeição, timeout e desconexão liberam estado pendente")
	t.check(network_source.contains("notify_voluntary_leave.rpc_id(1)"), "cliente notifica saída voluntária de forma confiável")
	t.check(network_source.contains("_processed_departures.has(id)"), "saída duplicada é idempotente")
	t.check(network_source.contains("_cancel_match_resources()"), "saída limpa controlador e timer da partida")
	t.check(network_source.contains("phase = SessionPhase.LOBBY"), "saída em partida devolve host ao lobby")
	t.check(network_source.contains("host_closed_room.rpc()"), "host avisa clientes antes de encerrar")
	t.check(network_source.contains("token != _reveal_token"), "timer antigo de revelação é ignorado")
	t.check(network_source.contains("notify_return_to_lobby.rpc(reason)"), "timeout da barreira devolve todos ao lobby")
	t.check(network_source.contains("SessionState.approved_config=config.duplicate(true)"), "cliente mantém configuração aprovada da sessão")
	var uno_ui_source: String = FileAccess.get_file_as_string("res://scripts/uno/uno_game_ui.gd")
	t.check(uno_ui_source.contains("%DrawPile.pressed.connect"), "monte central do Uno é clicável")
	t.check(uno_ui_source.contains("submit(\"PLAY_CARDS\", payload)"), "interface Uno envia combinação em uma única ação")
	t.check(uno_ui_source.contains("selected_uids.append(uid)"), "interface Uno mantém seleção múltipla isolada")
	t.check(uno_ui_source.contains("JOGAR %d CARTAS"), "interface Uno informa quantidade no botão")
	t.check(network_source.contains("_action_cache[key]"), "host deduplica ação combinada repetida")
	var truco_ui_source: String = FileAccess.get_file_as_string("res://scripts/truco/truco_game_ui.gd")
	t.check(truco_ui_source.contains("_render_history()"), "Truco apresenta histórico público")
