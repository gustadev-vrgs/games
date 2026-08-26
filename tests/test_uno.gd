class_name TestUno
extends RefCounted
func run(t:TestHelpers)->void:
	var rules: UnoRules = UnoRules.new();var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed=7;var state: Dictionary=rules.create_initial_state([1,2],rng)
	t.equal(state.hands[1].size(),7,"sete cartas");t.equal(rules.validate_invariants(state),"OK","conservação Uno");t.check(state.discard.back().action.is_empty(),"descarte numérico")
	var top: Dictionary = state.discard.back() as Dictionary
	var same: Dictionary = CardData.make(999,"uno",String(top.get("rank", "")),"", "blue" if String(top.get("color", ""))!="blue" else "red")
	t.check(rules.is_playable(same,top,state.active_color),"mesmo número");t.check(rules.is_playable(CardData.make(998,"uno","","","","wild"),top,state.active_color),"wild")
	t.equal(rules.validate_action(state,2,{"type":"DRAW_ONE"}).reason_code,"NOT_YOUR_TURN","fora do turno")
	var version:int=state.state_version;rules.apply_action(state,1,{"type":"DRAW_ONE"},rng);t.equal(state.state_version,version+1,"versão incrementa")
	var recycle_state: Dictionary = rules.create_initial_state([1,2], rng)
	recycle_state.discard.append_array(recycle_state.draw_pile)
	recycle_state.draw_pile = []
	var recycle_top: Dictionary = recycle_state.discard.back()
	var total_before: int = recycle_state.discard.size()
	rules.apply_action(recycle_state, 1, {"type":"DRAW_ONE"}, rng)
	t.equal(recycle_state.discard.size(), 1, "reciclagem preserva somente o topo")
	t.equal(recycle_state.discard[0].uid, recycle_top.uid, "carta superior não é reciclada")
	t.equal(rules.validate_invariants(recycle_state), "OK", "reciclagem conserva UIDs")
	t.check(total_before > 1 and not recycle_state.draw_pile.is_empty(), "monte reciclável não entra em deadlock")
	var wild_state: Dictionary = rules.create_initial_state([1,2], rng)
	var wild_card: Dictionary = {}
	for candidate: Dictionary in wild_state.draw_pile:
		if candidate.action == "wild":
			wild_card = candidate
			break
	wild_state.draw_pile.erase(wild_card)
	wild_state.hands[1].append(wild_card)
	var missing_color: Dictionary = rules.validate_action(wild_state, 1, {"type":"PLAY_CARD","card_uid":wild_card.uid})
	t.equal(missing_color.reason_code, "INVALID_COLOR", "curinga sem cor é rejeitado")
	rules.apply_action(wild_state, 1, {"type":"PLAY_CARD","card_uid":wild_card.uid,"chosen_color":"blue"}, rng)
	t.equal(wild_state.active_color, "blue", "curinga atualiza cor ativa")
	var public: Dictionary = rules.build_public_snapshot(wild_state)
	t.equal(public.last_play.chosen_color, "blue", "snapshot público sincroniza cor escolhida")
	t.check(not public.last_play.has("hand"), "última jogada não contém mão privada")
	var eight_ids: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var eight: Dictionary = rules.create_initial_state(eight_ids, rng)
	var dealt: int = 0
	var private_uids: Dictionary = {}
	for peer_id: int in eight_ids:
		t.equal(eight.hands[peer_id].size(), 7, "Uno 8: sete cartas por pessoa")
		dealt += eight.hands[peer_id].size()
		var private_snapshot: Dictionary = rules.build_private_snapshot(eight, peer_id)
		private_uids[peer_id] = private_snapshot.hand.map(func(card: Dictionary) -> int: return int(card.uid))
	t.equal(dealt, 56, "Uno 8: 56 cartas distribuídas")
	t.equal(rules.validate_invariants(eight), "OK", "Uno 8 conserva 108 cartas e UIDs")
	t.equal(rules.build_public_snapshot(eight).card_counts.size(), 8, "snapshot possui oito contadores")
	t.equal(private_uids.size(), 8, "oito snapshots privados separados")
	eight.current_index = 7
	rules._advance(eight)
	t.equal(eight.current_index, 0, "turno fecha ciclo 8 para 1")
	eight.direction = -1
	eight.current_index = 0
	rules._advance(eight)
	t.equal(eight.current_index, 7, "sentido inverso fecha ciclo 1 para 8")
	_test_numeric_combinations(t, rules, rng)

func _test_numeric_combinations(t: TestHelpers, rules: UnoRules, rng: RandomNumberGenerator) -> void:
	var state: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["4", "blue", ""], ["9", "green", ""]])
	var red_uid: int = state.hands[1][0].uid; var blue_uid: int = state.hands[1][1].uid
	var version: int = state.state_version; var discard_count: int = state.discard.size()
	var result: Dictionary = rules.apply_action(state, 1, {"type":"PLAY_CARDS", "card_uids":[red_uid, blue_uid]}, rng)
	t.check(result.accepted, "topo 4 amarelo aceita 4 vermelho e 4 azul")
	t.equal(state.discard.size(), discard_count + 2, "duas cartas descartadas em uma jogada")
	t.equal(state.discard[-2].uid, red_uid, "descarte preserva a primeira posição")
	t.equal(state.discard.back().uid, blue_uid, "última selecionada fica no topo")
	t.equal(state.active_color, "blue", "última selecionada define a cor")
	t.equal(state.current_index, 1, "combinação avança o turno somente uma vez")
	t.equal(state.state_version, version + 1, "combinação incrementa a versão somente uma vez")
	t.equal(state.last_play.cards.size(), 2, "snapshot registra todas as cartas em ordem")
	t.equal(rules.validate_invariants(state), "OK", "combinação conserva as 108 cartas")

	var three: Dictionary = _combination_state("7", "yellow", [["7", "red", ""], ["7", "blue", ""], ["7", "green", ""], ["2", "yellow", ""]])
	var three_uids: Array = three.hands[1].slice(0, 3).map(func(card: Dictionary) -> int: return card.uid)
	t.check(rules.apply_action(three, 1, {"type":"PLAY_CARDS", "card_uids":three_uids}, rng).accepted, "três cartas do mesmo número são aceitas")

	_assert_atomic_rejection(t, rules, rng, _combination_state("4", "yellow", [["4", "red", ""], ["5", "blue", ""]]), "COMBINATION_NUMBER_MISMATCH", "números diferentes")
	_assert_atomic_rejection(t, rules, rng, _combination_state("4", "yellow", [["4", "red", ""], ["", "blue", "skip"]]), "COMBINATION_NUMBERS_ONLY", "carta especial")
	var duplicate: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["8", "blue", ""]])
	var duplicate_uid: int = duplicate.hands[1][0].uid
	_assert_action_atomic(t, rules, rng, duplicate, {"type":"PLAY_CARDS", "card_uids":[duplicate_uid, duplicate_uid]}, "DUPLICATE_CARD_UID", "UID repetido")
	var foreign: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["8", "blue", ""]])
	_assert_action_atomic(t, rules, rng, foreign, {"type":"PLAY_CARDS", "card_uids":[foreign.hands[1][0].uid, foreign.hands[2][0].uid]}, "CARD_NOT_OWNED", "carta alheia")
	_assert_atomic_rejection(t, rules, rng, _combination_state("4", "yellow", [["6", "red", ""], ["6", "blue", ""]]), "CARD_NOT_PLAYABLE", "primeira carta incompatível")
	var after_draw: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["4", "blue", ""]])
	after_draw.phase = UnoRules.Phase.AFTER_DRAW_CHOICE; after_draw.drawn_uid = after_draw.hands[1][0].uid
	_assert_action_atomic(t, rules, rng, after_draw, {"type":"PLAY_CARDS", "card_uids":[after_draw.hands[1][0].uid, after_draw.hands[1][1].uid]}, "CANNOT_COMBINE_AFTER_DRAW", "combinação após compra")

	var one_left: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["4", "blue", ""], ["8", "green", ""]])
	var combo: Array = [one_left.hands[1][0].uid, one_left.hands[1][1].uid]
	rules.apply_action(one_left, 1, {"type":"PLAY_CARDS", "card_uids":combo}, rng)
	t.equal(one_left.hands[1].size(), 3, "sem UNO, combinação que deixaria uma carta aplica penalidade de duas")
	var declared: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["4", "blue", ""], ["8", "green", ""]])
	combo = [declared.hands[1][0].uid, declared.hands[1][1].uid]
	rules.apply_action(declared, 1, {"type":"PLAY_CARDS", "card_uids":combo, "declared_uno":true}, rng)
	t.equal(declared.hands[1].size(), 1, "com UNO, combinação deixa exatamente uma carta")
	var win: Dictionary = _combination_state("4", "yellow", [["4", "red", ""], ["4", "blue", ""]])
	combo = [win.hands[1][0].uid, win.hands[1][1].uid]
	rules.apply_action(win, 1, {"type":"PLAY_CARDS", "card_uids":combo}, rng)
	t.equal(win.winner, 1, "combinação que esvazia a mão vence sem penalidade")
	t.equal(win.phase, UnoRules.Phase.MATCH_END, "vitória encerra a partida")

	var controller := BaseMatchController.new(); controller.rules = rules; controller.state = _combination_state("4", "yellow", [["4", "red", ""], ["4", "blue", ""], ["8", "green", ""]]); controller.rng.seed = 3
	combo = [controller.state.hands[1][0].uid, controller.state.hands[1][1].uid]
	t.check(controller.process_action(1, {"type":"PLAY_CARDS", "card_uids":combo, "declared_uno":true}).accepted, "host autoritativo aceita a combinação usada por cliente e treino")
	var after_host: Dictionary = controller.state.duplicate(true)
	t.check(not controller.process_action(1, {"type":"PLAY_CARDS", "card_uids":combo}).accepted, "ação repetida não descarta o conjunto novamente")
	t.equal(controller.state, after_host, "deduplicação lógica mantém estado após repetição")

func _assert_atomic_rejection(t: TestHelpers, rules: UnoRules, rng: RandomNumberGenerator, state: Dictionary, reason: String, label: String) -> void:
	var uids: Array = state.hands[1].slice(0, 2).map(func(card: Dictionary) -> int: return card.uid)
	_assert_action_atomic(t, rules, rng, state, {"type":"PLAY_CARDS", "card_uids":uids}, reason, label)

func _assert_action_atomic(t: TestHelpers, rules: UnoRules, rng: RandomNumberGenerator, state: Dictionary, action: Dictionary, reason: String, label: String) -> void:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = rules.apply_action(state, 1, action, rng)
	t.equal(result.reason_code, reason, "%s é rejeitada" % label)
	t.equal(state, before, "%s não altera parcialmente o estado" % label)

func _combination_state(top_rank: String, top_color: String, hand_specs: Array) -> Dictionary:
	var deck: Array[Dictionary] = DeckBuilder.build_uno(); var top: Dictionary = _take_card(deck, top_rank, top_color, "")
	var hand: Array[Dictionary] = []
	for spec: Array in hand_specs: hand.append(_take_card(deck, String(spec[0]), String(spec[1]), String(spec[2])))
	var opponent: Dictionary = deck.pop_back()
	return {"game_id":"uno", "phase":UnoRules.Phase.PLAYER_TURN, "players":[1,2], "hands":{1:hand, 2:[opponent]}, "draw_pile":deck, "discard":[top], "active_color":top_color, "current_index":0, "direction":1, "drawn_uid":-1, "winner":-1, "last_play":{}, "last_draw":{}, "state_version":0, "total_cards":108}

func _take_card(deck: Array[Dictionary], rank: String, color: String, action: String) -> Dictionary:
	for index: int in deck.size():
		var card: Dictionary = deck[index]
		if card.rank == rank and card.color == color and card.action == action: return deck.pop_at(index)
	return {}
